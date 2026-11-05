<#
    .SYNOPSIS
        Splits a multi-tenant hunt result into one file per tenant, so no customer's rows sit
        beside another's.

    .DESCRIPTION
        Reads a JSON array written by Invoke-XdrAgent.ps1 -OutFile (or Invoke-XdrMtoAdvancedHunting
        output saved as JSON), groups rows by TenantId, and writes
        <OutDir>/<tenant-short>/<input name>.json for each tenant, plus <OutDir>/sweep-summary.json
        with the row count per tenant, the tenants that returned nothing, and (from the wrapper's
        <file>.tenants.json sidecar) the tenants that weren't searched at all. Rows without a
        TenantId are refused, because they can't be attributed to a customer.

        Point each tenant's file at that customer's own case before anyone writes findings from it.

    .PARAMETER InputFile
        The multi-tenant result JSON.

    .PARAMETER OutDir
        Folder for the per-tenant files, e.g. investigations/2026-11-03-estate-ioc-sweep.

    .PARAMETER ExpectedTenantIds
        The tenants the sweep named. Tenants with no rows are listed in the summary, and rows from a
        tenant not in this list stop the split.

    .EXAMPLE
        ./tools/agent/Split-XdrMtoResult.ps1 -InputFile ./investigations/sweep/raw.json -OutDir ./investigations/sweep -ExpectedTenantIds $ids
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputFile,
    [Parameter(Mandatory)][string]$OutDir,
    [string[]]$ExpectedTenantIds
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'XdrWorkbench.Common.ps1')

# pwsh -File passes a comma list as one string; accept both forms.
$ExpectedTenantIds = @($ExpectedTenantIds | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ })
$rows = @(Get-Content -LiteralPath $InputFile -Raw | ConvertFrom-Json)
$unattributed = @($rows | Where-Object { -not $_.PSObject.Properties['TenantId'] -or -not $_.TenantId })
if ($unattributed) { throw "$($unattributed.Count) row(s) have no TenantId, so they can't be attributed to a customer. Keep TenantId and TenantName in the query's output (don't project them away)." }

$groups = $rows | Group-Object TenantId
if ($ExpectedTenantIds) {
    $extra = @($groups.Name | Where-Object { $_ -notin $ExpectedTenantIds })
    if ($extra) { throw "Rows from tenants the sweep didn't name: $($extra -join ', '). Nothing written." }
}

$known = @{}; foreach ($t in Get-XdrTenantList) { $known[$t.TenantId] = $t.Name }
$base = [System.IO.Path]::GetFileName($InputFile)
$summary = foreach ($g in $groups) {
    $name = "$(@($g.Group)[0].TenantName)"; if (-not $name) { $name = $known[$g.Name] }; if (-not $name) { $name = $g.Name }
    $dir = Join-Path $OutDir (Get-XdrTenantShortName -Name $name)
    $null = New-Item -ItemType Directory -Path $dir -Force
    $path = Join-Path $dir $base
    ConvertTo-Json -InputObject @($g.Group) -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
    [pscustomobject]@{ TenantName = $name; TenantId = $g.Name; Rows = $g.Count; File = $path }
}
$sidecar = "$InputFile.tenants.json"
$notSearched = @()
if (Test-Path -LiteralPath $sidecar) {
    $side = Get-Content -LiteralPath $sidecar -Raw | ConvertFrom-Json
    $notSearched = @($side.NotSearched | ForEach-Object { [pscustomobject]@{ TenantId = $_.TenantId; TenantName = $(if ($known[$_.TenantId]) { $known[$_.TenantId] } else { $_.TenantId }); Error = $_.Error } })
    if (-not $ExpectedTenantIds) { $ExpectedTenantIds = @($side.Named) }
}
$silent = @($ExpectedTenantIds | Where-Object { $_ -notin $groups.Name -and $_ -notin $notSearched.TenantId } | ForEach-Object { [pscustomobject]@{ TenantId = $_; TenantName = $(if ($known[$_]) { $known[$_] } else { $_ }) } })
$null = New-Item -ItemType Directory -Path $OutDir -Force
[ordered]@{
    Source      = (Resolve-Path -LiteralPath $InputFile).Path
    SplitUtc    = (Get-Date).ToUniversalTime().ToString('o')
    Tenants     = @($summary)
    NotSearched = $notSearched
    NoRows      = $silent
    NoRowsMeans = 'No rows returned for that tenant in this window. Check its warnings, coverage and retention before calling it clean.'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutDir 'sweep-summary.json') -Encoding utf8
$summary | Format-Table TenantName, Rows, File -AutoSize | Out-Host
if ($notSearched) { Write-Host "NOT SEARCHED (report as such, not as clean): $(($notSearched | ForEach-Object { "$($_.TenantName) [$($_.Error)]" }) -join ', ')" -ForegroundColor Yellow }
if ($silent) { Write-Host "Searched, no rows: $($silent.TenantName -join ', ')" }
