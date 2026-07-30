<#
.SYNOPSIS
    Create a venv and install a pinned requirements set into it (PyPI/production).

.DESCRIPTION
    The PyPI counterpart to create-env.ps1. Builds a slim, Python-only virtual
    environment from the repo's pinned lockfiles\requirements\*.txt - the artifact
    CI/CD deploys. Prefers uv (fast; also creates the venv), falls back to
    'python -m venv' + pip. Always targets the venv interpreter explicitly, so it
    can never install into an active conda environment.

    Version-agnostic: resolves the requirements dir from its own path (3.10 / 3.12).

.EXAMPLE
    .\setup-venv.ps1 04-web                # -> requirements\04-web.txt into .\.venv
.EXAMPLE
    .\setup-venv.ps1 04-web .venv-web      # custom venv directory
.EXAMPLE
    .\setup-venv.ps1 04-web -System        # container mode: system python, no venv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Requirements,

    [Parameter(Position = 1)]
    [string]$VenvDir = '.venv',

    [switch]$System
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verRoot   = Split-Path -Parent $scriptDir
$reqDir    = Join-Path $verRoot 'lockfiles\requirements'

# --- Resolve the requirements file -----------------------------------------
if (Test-Path $Requirements) {
    $req = (Resolve-Path $Requirements).Path
}
elseif (Test-Path (Join-Path $reqDir "$Requirements.txt")) {
    $req = (Resolve-Path (Join-Path $reqDir "$Requirements.txt")).Path
}
else {
    Write-Error "Could not find a requirements file for '$Requirements' (looked in $reqDir and as a literal path)"
    exit 1
}

function Test-Tool([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# --- Safety: warn if a named conda env is active ---------------------------
if ($env:CONDA_PREFIX -and $env:CONDA_DEFAULT_ENV -and $env:CONDA_DEFAULT_ENV -ne 'base') {
    Write-Warning "conda env '$($env:CONDA_DEFAULT_ENV)' is active."
    if ($System) {
        Write-Error "-System would install into the conda env. Run 'conda deactivate' first."
        exit 1
    }
    Write-Warning 'Proceeding, but installing into a dedicated venv (never the conda env).'
}

Write-Host ">> Requirements: $req"

# --- Container / CI mode ----------------------------------------------------
if ($System) {
    Write-Host '>> Mode: -System (installing into the current interpreter)'
    if (Test-Tool uv) { uv pip install --system --no-cache -r $req }
    else { python -m pip install --no-cache-dir -r $req }
    if ($LASTEXITCODE -ne 0) { Write-Error 'Install failed.'; exit $LASTEXITCODE }
    Write-Host '>> Done (system install).'
    return
}

# --- venv mode --------------------------------------------------------------
if (Test-Tool uv) {
    Write-Host ">> Creating venv with uv at: $VenvDir"
    uv venv $VenvDir
}
else {
    Write-Host ">> uv not found; creating venv with python -m venv at: $VenvDir"
    python -m venv $VenvDir
}
if ($LASTEXITCODE -ne 0) { Write-Error 'venv creation failed.'; exit $LASTEXITCODE }

# Locate the venv interpreter (Windows: Scripts\, POSIX: bin/).
$vpy = Join-Path $VenvDir 'Scripts\python.exe'
$activate = "$VenvDir\Scripts\Activate.ps1"
if (-not (Test-Path $vpy)) {
    $vpy = Join-Path $VenvDir 'bin/python'
    $activate = "source $VenvDir/bin/activate"
}
if (-not (Test-Path $vpy)) { Write-Error "Could not find the venv interpreter under $VenvDir"; exit 1 }

Write-Host ">> Installing into: $vpy"
if (Test-Tool uv) {
    uv pip install --python $vpy -r $req
}
else {
    & $vpy -m pip install --upgrade pip | Out-Null
    & $vpy -m pip install -r $req
}
if ($LASTEXITCODE -ne 0) { Write-Error 'Install failed.'; exit $LASTEXITCODE }

Write-Host '>> Done. Activate with:'
Write-Host "     $activate"
