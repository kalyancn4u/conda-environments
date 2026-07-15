<#
.SYNOPSIS
    Update an existing Conda environment to match its YAML definition (--prune).
.EXAMPLE
    .\update-env.ps1 01-core
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Env
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envDir    = Join-Path $scriptDir '..\environments'

if (Test-Path $Env) {
    $yml = (Resolve-Path $Env).Path
}
elseif (Test-Path (Join-Path $envDir "$Env.yml")) {
    $yml = (Resolve-Path (Join-Path $envDir "$Env.yml")).Path
}
else {
    Write-Error "Environment file for '$Env' not found"
    exit 1
}

$solver = if (Get-Command mamba -ErrorAction SilentlyContinue) { 'mamba' } else { 'conda' }

Write-Host ">> Updating environment from: $yml (with --prune)"
& $solver env update --file $yml --prune
if ($LASTEXITCODE -ne 0) { Write-Error "Update failed."; exit $LASTEXITCODE }
Write-Host ">> Update complete."
