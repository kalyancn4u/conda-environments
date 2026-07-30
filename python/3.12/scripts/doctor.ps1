<#
.SYNOPSIS
    Inspect the local toolchain and report readiness (read-only preflight).

.DESCRIPTION
    Installs nothing and changes nothing. Reports which environment tools are
    present (conda/mamba/micromamba/uv/pip/docker/git/conda-lock), whether
    conda-forge + strict priority are configured, and whether the current shell
    is in a safe state to run uv/pip. Run it first on a new machine or in CI.

    Version-agnostic: derives its Python-version context (3.10 / 3.12) from its
    own path, so the same file works in every python\<ver>\scripts.

.EXAMPLE
    .\doctor.ps1
.EXAMPLE
    .\doctor.ps1 -Strict     # exit non-zero if no conda-family solver AND no uv
#>
[CmdletBinding()]
param([switch]$Strict)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verRoot   = Split-Path -Parent $scriptDir
$pyver     = Split-Path -Leaf $verRoot                 # e.g. 3.12
$pytag     = 'py' + ($pyver -replace '\.', '')          # e.g. py312

function Test-Tool([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Get-Ver([string]$name) {
    try { (& $name --version 2>&1 | Select-Object -First 1) -replace "`r", '' } catch { '' }
}
function Ok([string]$m)   { Write-Host "  OK   $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "  !!   $m" -ForegroundColor Yellow }
function Miss([string]$m) { Write-Host "  --   $m" -ForegroundColor Red }

Write-Host "conda-environments doctor - context: python/$pyver ($pytag-*)"
Write-Host "==========================================================="

Write-Host "`nSolvers & installers"
if (Test-Tool conda)      { Ok "conda        $(Get-Ver conda)" }      else { Miss 'conda        (not found)' }
if (Test-Tool mamba)      { Ok "mamba        $(Get-Ver mamba)" }      else { Warn 'mamba        (not found - optional, but far faster than conda)' }
if (Test-Tool micromamba) { Ok "micromamba   $(Get-Ver micromamba)" } else { Warn 'micromamba   (not found - needed only for the zero-install path)' }
if (Test-Tool uv)         { Ok "uv           $(Get-Ver uv)" }         else { Warn 'uv           (not found - needed for the venv/production path)' }
if (Test-Tool pip)        { Ok "pip          $(Get-Ver pip)" }        else { Warn 'pip          (not found on this interpreter)' }
if (Test-Tool conda-lock) { Ok "conda-lock   $(Get-Ver conda-lock)" } else { Warn 'conda-lock   (not found - needed only to generate lockfiles locally)' }

Write-Host "`nInterpreters & tooling"
if (Test-Tool python)     { Ok "python   $(Get-Ver python)" }
elseif (Test-Tool python3){ Ok "python3  $(Get-Ver python3)" }
else                      { Miss 'python   (not found)' }
if (Test-Tool docker)     { Ok "docker   $(Get-Ver docker)" } else { Warn 'docker   (not found - needed only for containerized builds/tests)' }
if (Test-Tool git)        { Ok "git      $(Get-Ver git)" }    else { Warn 'git      (not found)' }

Write-Host "`nconda channel configuration"
if (Test-Tool conda) {
    $channels = (conda config --show channels 2>$null | Out-String)
    $priority = (conda config --show channel_priority 2>$null | Out-String)
    if ($channels -match 'conda-forge') { Ok 'conda-forge is in your channel list' }
    else { Warn 'conda-forge not found in channels - run: conda config --add channels conda-forge' }
    if ($priority -match 'strict') { Ok 'channel_priority is strict' }
    else { Warn 'channel_priority is not strict - run: conda config --set channel_priority strict' }
} else { Warn 'conda not installed - skipping channel checks' }

Write-Host "`nCurrent shell state (matters before running uv/pip)"
$condaActive = $env:CONDA_PREFIX
$venvActive  = $env:VIRTUAL_ENV
if ($condaActive -and $venvActive) {
    Warn "BOTH a conda env ($(Split-Path -Leaf $condaActive)) and a venv are active - deactivate one"
} elseif ($condaActive) {
    if ($env:CONDA_DEFAULT_ENV -eq 'base') { Ok "conda 'base' is active (fine); activate a project env for conda work" }
    else {
        Warn "conda env '$($env:CONDA_DEFAULT_ENV)' is ACTIVE - do NOT run uv/pip now (it would install into it)."
        Warn '    For PyPI/venv work run ''conda deactivate'' first. See docs/conda-vs-uv.md section 5.'
    }
} elseif ($venvActive) {
    Ok "a venv is active ($venvActive) - safe target for uv/pip"
} else {
    Ok 'no conda env or venv active - clean shell'
}

Write-Host "`n==========================================================="
$solverOk = (Test-Tool conda) -or (Test-Tool mamba) -or (Test-Tool micromamba)
if ($solverOk) { Write-Host 'Ready for the conda/mamba path. Next: .\scripts\create-env.ps1 01-core' }
else { Write-Host 'No conda-family solver found. Install Miniforge (conda+mamba) for the dev path.' }
if ((Test-Tool uv) -or (Test-Tool pip)) { Write-Host 'Ready for the venv/uv path.   Next: .\scripts\setup-venv.ps1 04-web' }

if ($Strict -and -not $solverOk -and -not (Test-Tool uv)) {
    Write-Error 'strict: no solver and no uv - failing.'
    exit 1
}
exit 0
