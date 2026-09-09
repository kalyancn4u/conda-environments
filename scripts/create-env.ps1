<#
.SYNOPSIS
    Create a Conda environment from a YAML under python\<ver>\environments\.

.DESCRIPTION
    Resolves a bare name (e.g. "01-core") to python\<ver>\environments\01-core.yml,
    or accepts an explicit path. The Python version is passed explicitly with
    -Python / -p (required) — this script lives in the shared top-level scripts\
    and is not tied to any one tree. Prefers mamba when available for faster solves.

.EXAMPLE
    .\create-env.ps1 -p 3.12 01-core
.EXAMPLE
    .\create-env.ps1 -p 3.10 ..\python\3.10\templates\llm.yml
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('p')]
    [string]$Python,

    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Env
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
$verRoot   = Join-Path $repoRoot "python\$Python"
$envDir    = Join-Path $verRoot 'environments'
if (-not (Test-Path $verRoot)) {
    Write-Error "No such Python tree: python/$Python (expected $verRoot)"; exit 1
}

# Resolve the argument to a YAML file.
if (Test-Path $Env) {
    $yml = (Resolve-Path $Env).Path
}
elseif (Test-Path (Join-Path $envDir "$Env.yml")) {
    $yml = (Resolve-Path (Join-Path $envDir "$Env.yml")).Path
}
else {
    Write-Error "Could not find an environment file for '$Env' in $envDir"
    exit 1
}

# Prefer mamba if present.
$solver = if (Get-Command mamba -ErrorAction SilentlyContinue) { 'mamba' } else { 'conda' }

Write-Host ">> Creating environment from: $yml"
Write-Host ">> Using solver: $solver"

& $solver env create --yes --file $yml
if ($LASTEXITCODE -ne 0) { Write-Error "Environment creation failed."; exit $LASTEXITCODE }

$name = (Select-String -Path $yml -Pattern '^name:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
Write-Host ">> Done. Activate with:  conda activate $name"
