<#
.SYNOPSIS
    Create a Conda environment from a YAML in ..\environments\.

.DESCRIPTION
    Resolves a bare name (e.g. "01-core") to environments\01-core.yml, or accepts
    an explicit path. Prefers mamba when available for faster solves.

.EXAMPLE
    .\create-env.ps1 01-core
.EXAMPLE
    .\create-env.ps1 ..\templates\llm.yml
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Env
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envDir    = Join-Path $scriptDir '..\environments'

# Resolve the argument to a YAML file.
if (Test-Path $Env) {
    $yml = (Resolve-Path $Env).Path
}
elseif (Test-Path (Join-Path $envDir "$Env.yml")) {
    $yml = (Resolve-Path (Join-Path $envDir "$Env.yml")).Path
}
else {
    Write-Error "Could not find an environment file for '$Env'"
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
