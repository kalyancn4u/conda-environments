<#
.SYNOPSIS
    Diff installed packages of two Conda environments, or list outdated packages.

.EXAMPLE
    .\compare-envs.ps1 py312-core py312-ds
.EXAMPLE
    .\compare-envs.ps1 -Outdated py312-core
#>
[CmdletBinding(DefaultParameterSetName = 'Diff')]
param(
    [Parameter(ParameterSetName = 'Outdated')]
    [switch]$Outdated,

    [Parameter(ParameterSetName = 'Outdated', Mandatory = $true, Position = 0)]
    [string]$Env,

    [Parameter(ParameterSetName = 'Diff', Mandatory = $true, Position = 0)]
    [string]$EnvA,

    [Parameter(ParameterSetName = 'Diff', Mandatory = $true, Position = 1)]
    [string]$EnvB
)

$ErrorActionPreference = 'Stop'

if ($PSCmdlet.ParameterSetName -eq 'Outdated') {
    Write-Host ">> Checking for outdated packages in '$Env' (dry run)..."
    conda update --all --name $Env --dry-run
    return
}

function Get-PkgTable([string]$name) {
    # Returns a hashtable of package -> version.
    $tbl = @{}
    conda list --name $name |
        Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() } |
        ForEach-Object {
            $cols = ($_ -split '\s+')
            if ($cols.Length -ge 2) { $tbl[$cols[0]] = $cols[1] }
        }
    return $tbl
}

$a = Get-PkgTable $EnvA
$b = Get-PkgTable $EnvB
$allKeys = ($a.Keys + $b.Keys) | Sort-Object -Unique

Write-Host ">> Comparing '$EnvA' vs '$EnvB':`n"
$identical = $true
foreach ($k in $allKeys) {
    $va = $a[$k]; $vb = $b[$k]
    if ($va -ne $vb) {
        $identical = $false
        $left  = if ($va) { $va } else { '-' }
        $right = if ($vb) { $vb } else { '-' }
        "{0,-30} {1,-20} | {2,-20}" -f $k, $left, $right | Write-Host
    }
}
if ($identical) { Write-Host ">> Environments are identical." }
