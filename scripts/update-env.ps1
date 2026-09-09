<#
.SYNOPSIS
    Update an existing Conda environment to match its YAML definition (--prune).
.DESCRIPTION
    The Python version is passed explicitly with -Python / -p (required).
.EXAMPLE
    .\update-env.ps1 -p 3.12 01-core
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

if (Test-Path $Env) {
    $yml = (Resolve-Path $Env).Path
}
elseif (Test-Path (Join-Path $envDir "$Env.yml")) {
    $yml = (Resolve-Path (Join-Path $envDir "$Env.yml")).Path
}
else {
    Write-Error "Environment file for '$Env' not found in $envDir"
    exit 1
}

$solver = if (Get-Command mamba -ErrorAction SilentlyContinue) { 'mamba' } else { 'conda' }

Write-Host ">> Updating environment from: $yml (with --prune)"
& $solver env update --file $yml --prune
if ($LASTEXITCODE -ne 0) { Write-Error "Update failed."; exit $LASTEXITCODE }
Write-Host ">> Update complete."
