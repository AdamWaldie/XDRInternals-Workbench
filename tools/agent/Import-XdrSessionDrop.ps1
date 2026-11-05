<#
    .SYNOPSIS
        Claude-side standup: turns the session file the relay extension saved into a working,
        tenant-checked Workbench session, with the case lock and case folder.

    .DESCRIPTION
        The analyst's only manual step is signing in to the Defender portal in an Incognito window
        and clicking "Save session for Claude" in the XDR Docker Relay extension, saving the file
        in <repo>/.xdr-agent. This script, run by Claude from the repo root, does the rest:

          1. Finds the newest xdr-session-drop*.json in <repo>/.xdr-agent (or -DropPath).
          2. Loads the portal session and asks the portal which tenant and account it belongs to.
          3. Resolves -Tenant against tenants.local.csv / tenants.txt. If the session tenant isn't
             the case customer, checks the session's MTO list: a reachable customer gets an MTO
             case lock (hunting only); an unreachable one stops the import.
          4. Writes <repo>/.xdr-agent/session.json and case.json, and the case folder unless
             -NoCaseFolder or -CaseFolder is given.
          5. Empties the drop file so the token exists in one place only.
          6. Prints a JSON "Ready" record.

        Exit codes: 0 ready, 4 no usable drop or the portal rejected it, 7 customer not reachable.

    .EXAMPLE
        pwsh -NoProfile -File tools/agent/Import-XdrSessionDrop.ps1 -Tenant "<customer>" -Case INC12345
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Tenant,
    [string]$Case = 'hunt',
    [string]$DropPath,
    [string]$CaseFolder,
    [switch]$NoCaseFolder
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'XdrWorkbench.Common.ps1')
$repoRoot = Get-XdrWorkbenchRoot
$agentDir = Join-Path $repoRoot '.xdr-agent'
function Out-Ready($obj) { $obj | ConvertTo-Json -Depth 4 }
function Stop-With([int]$Code, [string]$Message) { [Console]::Error.WriteLine($Message); exit $Code }

# 1. Find the drop
$drops = if ($DropPath) { @(Get-Item -LiteralPath $DropPath) } else { @(Get-ChildItem -Path $agentDir -Filter 'xdr-session-drop*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
$drop = $null; $dropFile = $null
foreach ($f in $drops) {
    try { $d = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json } catch { continue }
    if ($d.kind -eq 'xdr-session-drop' -and $d.sccAuth) { $drop = $d; $dropFile = $f; break }
}
if (-not $drop) {
    Stop-With 4 "NO DROP: no saved session in $agentDir. In an Incognito window signed in to the Defender portal, click the XDR Docker Relay extension > 'Save session for Claude' and save xdr-session-drop.json into that folder."
}
if ((Test-XdrPathGitIgnored -Path $dropFile.FullName) -eq $false) { Stop-With 4 "REFUSED: $($dropFile.FullName) would be tracked by git. Move it into $agentDir." }

# 2. Ask the portal who this is
try { $target = Resolve-XdrTenant -Tenant $Tenant } catch { Stop-With 7 $_.Exception.Message }
Import-Module (Join-Path $repoRoot 'XDRInternals/XDRInternals.psd1') -Force -WarningAction SilentlyContinue
Set-XdrConnectionSettings -SccAuth $drop.sccAuth -Xsrf $drop.xsrf 6>$null
try { $ctx = Get-XdrTenantContext -Force } catch { Stop-With 4 "REJECTED: the portal didn't accept the saved session ($($_.Exception.Message)). Sign in again in the Incognito window and save a fresh session." }
$liveId = "$($ctx.AuthInfo.TenantId)"; $liveName = "$($ctx.AuthInfo.TenantName)"; $account = "$($ctx.AuthInfo.UserName)"
if (-not $liveId) { Stop-With 4 'REJECTED: the portal returned no tenant for this session. Sign in again and save a fresh session.' }

# 3. Direct or MTO
$mode = 'direct'
if ($liveId -ne $target.TenantId) {
    $mto = @(Get-XdrMtoTenantList -ErrorAction SilentlyContinue)
    if ($mto | Where-Object tenantId -eq $target.TenantId) { $mode = 'mto' }
    else { Stop-With 7 "NOT REACHABLE: the session is for $liveName ($liveId) and $($target.Name) isn't in its MTO list. Switch to $($target.Name) in the portal, save the session again, and rerun." }
}

# 4. Session, case lock, case folder
$module = Get-Module XDRInternals
$xsrfNow = (& $module { $script:session }).Cookies.GetCookies('https://security.microsoft.com')['xsrf-token'].Value
$sessionPath = Join-Path $agentDir 'session.json'
if ((Test-XdrPathGitIgnored -Path $sessionPath) -eq $false) { Stop-With 4 "REFUSED: $sessionPath would be tracked by git." }
[ordered]@{
    SccAuth = $drop.sccAuth; Xsrf = $(if ($xsrfNow) { $xsrfNow } else { $drop.xsrf })
    TenantId = $liveId; TenantName = $liveName; Account = $account
    SavedAt = (Get-Date).ToUniversalTime().ToString('o'); Source = "relay extension file ($($drop.source))"
} | ConvertTo-Json | Set-Content -LiteralPath $sessionPath -Encoding utf8
if ($IsLinux -or $IsMacOS) { chmod 600 $sessionPath 2>$null }
[ordered]@{ CaseTenantId = $target.TenantId; CaseTenantName = $target.Name; SessionTenantId = $liveId; Case = $Case; Mode = $mode; SetUtc = (Get-Date).ToUniversalTime().ToString('o') } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $agentDir 'case.json') -Encoding utf8

$folder = $null
if ($CaseFolder) { $folder = (Resolve-Path -LiteralPath $CaseFolder).Path }
elseif (-not $NoCaseFolder) {
    $caseSafe = ($Case -replace '[^A-Za-z0-9_-]+', '-').Trim('-')
    $folder = Join-Path $repoRoot ("investigations/{0}-{1}-{2}" -f (Get-Date -Format 'yyyy-MM-dd'), (Get-XdrTenantShortName -Name $target.Name), $caseSafe)
    $null = New-Item -ItemType Directory -Path (Join-Path $folder 'queries'), (Join-Path $folder 'evidence') -Force
    $notes = Join-Path $folder 'case-notes.md'
    if (-not (Test-Path $notes)) {
        @"
# $($target.Name): $Case

Tenant: $($target.Name) ($($target.TenantId))
Session tenant: $liveName ($liveId), mode $mode
Analyst: $account
Opened (UTC): $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm'))
IR playbook:
Window (UTC):

## Question

## Query log

| Time (UTC) | File | Table(s) | Rows | Purpose |
| --- | --- | --- | --- | --- |

## Actions log

| Time (UTC) | Action | Target | Approved by | Result |
| --- | --- | --- | --- | --- |

## Findings

## Gaps
"@ | Set-Content -Path $notes -Encoding utf8
    }
}

# 5. One copy of the token only
foreach ($f in $drops) {
    try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop } catch { Set-Content -LiteralPath $f.FullName -Value '{}' -Encoding utf8 }
}

# 6. Ready
Out-Ready ([ordered]@{
    Status = 'ready'; Account = $account
    SessionTenant = "$liveName ($liveId)"; CaseTenant = "$($target.Name) ($($target.TenantId))"; Mode = $mode
    MtoNote = $(if ($mode -eq 'mto') { 'Hunting only: incidents, devices, timelines and other entity cmdlets are refused, because they would answer for the session tenant.' } else { $null })
    DropSource = $drop.source; DropSavedUtc = $drop.savedAtUtc
    CaseFolder = $folder; ExpectTenantId = $liveId
    Next = 'pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json'
})
