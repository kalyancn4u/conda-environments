<#
.SYNOPSIS
    Expose a conda environment as a Jupyter kernel.

.DESCRIPTION
    The modular environments are separate on disk, but you often want ONE
    JupyterLab that can open notebooks against any of them. Registering each env
    as a named kernel does that: launch Lab from your core env, then pick the
    kernel ("Python (py312-ml)", ...) per notebook.

    Requires ipykernel in the target env (01-core/04-web already have it via
    jupyterlab; leaner envs may not - the script installs it if missing).

.EXAMPLE
    .\register-kernel.ps1 py312-ml
.EXAMPLE
    .\register-kernel.ps1 py312-ml "ML (py3.12)"
.EXAMPLE
    .\register-kernel.ps1 -Remove py312-ml
.EXAMPLE
    .\register-kernel.ps1 -List
#>
[CmdletBinding(DefaultParameterSetName = 'Register')]
param(
    [Parameter(ParameterSetName = 'Register', Mandatory = $true, Position = 0)][string]$Env,
    [Parameter(ParameterSetName = 'Register', Position = 1)][string]$DisplayName,
    [Parameter(ParameterSetName = 'Remove', Mandatory = $true)][string]$Remove,
    [Parameter(ParameterSetName = 'List')][switch]$List
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command conda -ErrorAction SilentlyContinue)) { Write-Error 'conda not found on PATH'; exit 1 }

if ($PSCmdlet.ParameterSetName -eq 'List') {
    jupyter kernelspec list 2>$null
    if ($LASTEXITCODE -ne 0) { conda run -n base jupyter kernelspec list }
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Remove') {
    Write-Host ">> Removing kernel '$Remove' ..."
    jupyter kernelspec remove -f $Remove 2>$null
    if ($LASTEXITCODE -ne 0) { conda run -n base jupyter kernelspec remove -f $Remove }
    Write-Host '>> Removed.'
    return
}

if (-not $DisplayName) { $DisplayName = "Python ($Env)" }

$envs = conda env list | ForEach-Object { ($_ -split '\s+')[0] }
if ($envs -notcontains $Env) { Write-Error "conda env '$Env' not found (see: conda env list)"; exit 1 }

conda run -n $Env python -c "import ipykernel" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host ">> ipykernel not in '$Env' - installing it (conda-forge) ..."
    $solver = if (Get-Command mamba -ErrorAction SilentlyContinue) { 'mamba' } else { 'conda' }
    & $solver install --yes -n $Env -c conda-forge ipykernel
}

Write-Host ">> Registering kernel: name='$Env'  display='$DisplayName'  (user scope)"
conda run -n $Env python -m ipykernel install --user --name $Env --display-name $DisplayName
if ($LASTEXITCODE -ne 0) { Write-Error 'Kernel registration failed.'; exit $LASTEXITCODE }

Write-Host ">> Done. In JupyterLab, choose the '$DisplayName' kernel."
Write-Host "   List:   .\register-kernel.ps1 -List"
Write-Host "   Remove: .\register-kernel.ps1 -Remove $Env"
