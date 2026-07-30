<#
.SYNOPSIS
    Build and verify environment(s) in the same Miniforge container CI uses,
    reproducing the `test-environments` workflow locally. Requires Docker.

.EXAMPLE
    .\test-env.ps1 01-core
.EXAMPLE
    .\test-env.ps1 -All
#>
[CmdletBinding(DefaultParameterSetName = 'One')]
param(
    [Parameter(ParameterSetName = 'All')]
    [switch]$All,

    [Parameter(ParameterSetName = 'One', Mandatory = $true, Position = 0)]
    [string]$Env
)

$ErrorActionPreference = 'Stop'
$image    = 'condaforge/miniforge3:latest'
$cacheVol = 'conda_envs_pkgcache'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path

# env-file stem -> verify-env.py key (env name is always py310-<key>)
$order = '01-core','02-ml','03-deep-learning','04-web','05-tools','06-tensorflow','07-geospatial','08-timeseries'
$key = @{
    '01-core' = 'core'; '02-ml' = 'ml'; '03-deep-learning' = 'dl'; '04-web' = 'web'
    '05-tools' = 'tools'; '06-tensorflow' = 'tf'; '07-geospatial' = 'geo'; '08-timeseries' = 'ts'
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error 'docker is not installed / not on PATH'; exit 1
}

$targets = if ($All) { $order } else { , $Env }

$fail = 0
foreach ($e in $targets) {
    if (-not $key.ContainsKey($e)) { Write-Error "unknown environment '$e'"; exit 1 }
    $k = $key[$e]
    $name = "py310-$k"
    Write-Host "==================== $e  ($name) ===================="
    $inner = @"
set -e
mamba env create --yes --file python/3.10/environments/$e.yml
conda run --no-capture-output -n $name python python/3.10/scripts/verify-env.py --env $k
"@
    docker run --rm `
        -v "${repoRoot}:/repo" -w /repo `
        -v "${cacheVol}:/opt/conda/pkgs" `
        $image bash -lc $inner
    if ($LASTEXITCODE -eq 0) { Write-Host ">> PASS: $e" } else { Write-Host ">> FAIL: $e"; $fail = 1 }
}

if ($fail -eq 0) { Write-Host 'All requested environments passed.' } else { Write-Host 'One or more environments failed.' }
exit $fail
