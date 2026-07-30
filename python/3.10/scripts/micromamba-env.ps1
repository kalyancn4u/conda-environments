<#
.SYNOPSIS
    Create + verify an environment with ZERO prior install, via micromamba.

.DESCRIPTION
    For CI, Docker, and throwaway/automation use. If micromamba isn't on PATH,
    downloads the small static binary into a local, gitignored folder and uses it
    in place - nothing is installed system-wide, and the tree can be deleted after.

    Version-agnostic: resolves paths/env-name from its own location (3.10 / 3.12).

.EXAMPLE
    .\micromamba-env.ps1 01-core               # env <pytag>-core, then verify
.EXAMPLE
    .\micromamba-env.ps1 ..\templates\llm.yml  # explicit path (no verify)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Env
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verRoot   = Split-Path -Parent $scriptDir
$pyver     = Split-Path -Leaf $verRoot
$pytag     = 'py' + ($pyver -replace '\.', '')
$envDir    = Join-Path $verRoot 'environments'

# --- Resolve the YAML and (for numbered envs) the verify key ---------------
if (Test-Path $Env) { $yml = (Resolve-Path $Env).Path }
elseif (Test-Path (Join-Path $envDir "$Env.yml")) { $yml = (Resolve-Path (Join-Path $envDir "$Env.yml")).Path }
elseif (Test-Path (Join-Path $envDir $Env)) { $yml = (Resolve-Path (Join-Path $envDir $Env)).Path }
else { Write-Error "Could not find an environment file for '$Env'"; exit 1 }

$keyMap = @{
    '01-core.yml' = 'core'; '02-ml.yml' = 'ml'; '03-deep-learning.yml' = 'dl'; '04-web.yml' = 'web'
    '05-tools.yml' = 'tools'; '06-tensorflow.yml' = 'tf'; '07-geospatial.yml' = 'geo'; '08-timeseries.yml' = 'ts'
}
$verifyKey = $keyMap[(Split-Path -Leaf $yml)]

$envName = (Select-String -Path $yml -Pattern '^name:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
if (-not $envName) { $envName = "$pytag-adhoc" }

# --- Ensure micromamba is available ----------------------------------------
if (-not $env:MAMBA_ROOT_PREFIX) { $env:MAMBA_ROOT_PREFIX = (Join-Path $verRoot '.micromamba') }

if (Get-Command micromamba -ErrorAction SilentlyContinue) {
    $mm = 'micromamba'
}
else {
    $binDir = Join-Path $env:MAMBA_ROOT_PREFIX 'bin'
    $mm = Join-Path $binDir 'micromamba.exe'
    if (-not (Test-Path $mm)) {
        Write-Host ">> micromamba not found - downloading a local copy into $binDir"
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'win-arm64' } else { 'win-64' }
        $url  = "https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-$arch"
        Invoke-WebRequest -Uri $url -OutFile $mm
    }
}

Write-Host ">> Using micromamba  (root prefix: $($env:MAMBA_ROOT_PREFIX))"
Write-Host ">> Creating env '$envName' from $yml"
& $mm create --yes --name $envName --file $yml
if ($LASTEXITCODE -ne 0) { Write-Error 'Environment creation failed.'; exit $LASTEXITCODE }

if ($verifyKey) {
    Write-Host ">> Verifying imports (--env $verifyKey)"
    & $mm run --name $envName python (Join-Path $verRoot 'scripts\verify-env.py') --env $verifyKey
    if ($LASTEXITCODE -ne 0) { Write-Error 'Verification failed.'; exit $LASTEXITCODE }
}

Write-Host ">> Done. Run tools with:  $mm run --name $envName <command>"
Write-Host "   (env lives under $($env:MAMBA_ROOT_PREFIX)\envs\$envName; delete that tree to remove it)"
