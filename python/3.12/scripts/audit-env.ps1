<#
.SYNOPSIS
    Security & hygiene audit of an environment or a requirements set.

.DESCRIPTION
    Two independent, CI-friendly checks (non-zero exit on findings):
      1. VULNERABILITIES - runs pip-audit against the resolved package set to
         report known CVEs (PyPI Advisory DB / OSV).
      2. HYGIENE - for a conda env, detects conda/pip package CLASHES (the same
         ABI-risk check the test-environments workflow enforces).

    pip-audit is run without installing it into your target, using the first
    available runner: uvx, then 'uv tool run', then 'pipx run', then a local
    pip-audit. For live envs/venvs the script freezes the package list to a temp
    file and audits that.

.EXAMPLE
    .\audit-env.ps1 -Name py312-web
.EXAMPLE
    .\audit-env.ps1 -Venv .venv
.EXAMPLE
    .\audit-env.ps1 04-web            # shorthand -> requirements\04-web.txt
#>
[CmdletBinding(DefaultParameterSetName = 'Req')]
param(
    [Parameter(ParameterSetName = 'Conda', Mandatory = $true)][string]$Name,
    [Parameter(ParameterSetName = 'Venv',  Mandatory = $true)][string]$Venv,
    [Parameter(ParameterSetName = 'ReqFile', Mandatory = $true)][string]$Requirements,
    [Parameter(ParameterSetName = 'Req', Position = 0)][string]$Target,
    [switch]$NoVulns,
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verRoot   = Split-Path -Parent $scriptDir
$reqDir    = Join-Path $verRoot 'lockfiles\requirements'

function Test-Tool([string]$n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }

# --- Resolve target ---------------------------------------------------------
$kind = $PSCmdlet.ParameterSetName
$auditSrc = $null
$tmp = $null

switch ($kind) {
    'ReqFile' { if (-not (Test-Path $Requirements)) { Write-Error "not found: $Requirements"; exit 1 }; $auditSrc = (Resolve-Path $Requirements).Path; Write-Host ">> Target: requirements file  $auditSrc" }
    'Req' {
        if (-not $Target) { Write-Error 'Provide a target: -Name / -Venv / -Requirements, or a requirements shorthand.'; exit 2 }
        if (Test-Path $Target) { $auditSrc = (Resolve-Path $Target).Path }
        elseif (Test-Path (Join-Path $reqDir "$Target.txt")) { $auditSrc = (Resolve-Path (Join-Path $reqDir "$Target.txt")).Path }
        else { Write-Error "could not resolve target '$Target'"; exit 2 }
        Write-Host ">> Target: requirements file  $auditSrc"
    }
    'Conda' {
        if (-not (Test-Tool conda)) { Write-Error 'conda not found'; exit 1 }
        $tmp = [System.IO.Path]::GetTempFileName(); $auditSrc = $tmp
        Write-Host ">> Target: conda env  $Name  (freezing installed packages)"
        (conda run --no-capture-output -n $Name python -m pip freeze) 2>$null |
            Where-Object { $_ -and $_ -notmatch ' @ ' } | Set-Content -Encoding utf8 $tmp
    }
    'Venv' {
        $vpy = Join-Path $Venv 'Scripts\python.exe'
        if (-not (Test-Path $vpy)) { $vpy = Join-Path $Venv 'bin/python' }
        if (-not (Test-Path $vpy)) { Write-Error "no interpreter under $Venv"; exit 1 }
        $tmp = [System.IO.Path]::GetTempFileName(); $auditSrc = $tmp
        Write-Host ">> Target: venv  $Venv  (freezing installed packages)"
        (& $vpy -m pip freeze) 2>$null |
            Where-Object { $_ -and $_ -notmatch ' @ ' } | Set-Content -Encoding utf8 $tmp
    }
}

$rc = 0

# --- 1) Vulnerability scan --------------------------------------------------
if (-not $NoVulns) {
    Write-Host "`n== Vulnerability scan (pip-audit) =========================="
    $paArgs = @('-r', $auditSrc, '--progress-spinner', 'off')
    if ($Json) { $paArgs += @('-f', 'json') }

    if     (Test-Tool uvx)  { uvx pip-audit @paArgs }
    elseif (Test-Tool uv)   { uv tool run pip-audit @paArgs }
    elseif (Test-Tool pipx) { pipx run pip-audit @paArgs }
    elseif (Test-Tool pip-audit) { pip-audit @paArgs }
    else {
        Write-Warning "pip-audit not runnable: install uv (recommended) or pipx.  e.g.  uvx pip-audit -r $auditSrc"
        $rc = 1
    }
    if ($LASTEXITCODE -ne 0) { $rc = 1 }
}
else { Write-Host '>> Skipping vulnerability scan (-NoVulns).' }

# --- 2) Hygiene: conda/pip clash (conda targets only) ----------------------
if ($kind -eq 'Conda') {
    Write-Host "`n== Hygiene: conda/pip package clashes ======================"
    $py = @"
import json, os, subprocess, sys
name = os.environ['ENV_NAME']
data = json.loads(subprocess.check_output(['conda', 'list', '-n', name, '--json']))
pip_pkgs   = {p['name'].lower() for p in data if p.get('channel') == 'pypi'}
conda_pkgs = {p['name'].lower() for p in data if p.get('channel') != 'pypi'}
clash = sorted(pip_pkgs & conda_pkgs)
if clash:
    print('conda/pip clash detected (same package from both sources):', clash)
    sys.exit(1)
print('no conda/pip clashes')
"@
    $env:ENV_NAME = $Name
    $py | python -
    if ($LASTEXITCODE -ne 0) { $rc = 1 }
}

if ($tmp -and (Test-Path $tmp)) { Remove-Item -Force $tmp }

Write-Host "`n==========================================================="
if ($rc -eq 0) { Write-Host 'PASS: no vulnerabilities or clashes detected.' }
else { Write-Host 'FINDINGS: review the report above.' }
exit $rc
