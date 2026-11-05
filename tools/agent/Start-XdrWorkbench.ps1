<#
    .SYNOPSIS
        Stands up a hunt or IR session for one customer tenant: checks, incognito sign-in relay,
        tenant confirmation, session handoff and the case folder.

    .DESCRIPTION
        Run this yourself in PowerShell 7 on the machine with Chrome (or inside the container,
        with -NoBrowser). It does every step that doesn't need your hands, and stops with a
        clear instruction at each step that does:

          1. Checks PowerShell 7 and loads the module from this checkout.
          2. Resolves -Tenant (name, partial name or tenant ID) against tenants.local.csv or the
             MTO section of tenants.txt. Run with -ListTenants to see the choices.
          3. On Windows, checks the HTTP.sys URL reservation the relay listener needs, and adds it
             when the window is elevated.
          4. Opens a normal Chrome window (Incognito with -Incognito) with the target tenant's
             Advanced Hunting page and the multi-tenant portal. The relay reads the portal cookie
             from the window you click it in, so sign in there.
          5. Starts Connect-XdrByBrowserExtension and prints the pairing code.
          6. Compares the live tenant with the target. On a match it saves the agent session to
             <repo>/.xdr-agent/session.json (git- and docker-ignored). On a mismatch it checks
             whether the target is reachable through MTO and tells you which way to go.
          7. Runs a control hunt, retrying what it can, and records the result in the case lock.
          8. Creates investigations/<date>-<tenant-short>-<case>/ with a case notes file, and at
             Ready prints copy-paste commands to check the session, relay again, start again and
             end the session. Nothing needs pasting into the agent: it reads the case lock.

        Run tools/agent/Test-XdrWorkbench.ps1 when a step fails. Tear down with
        tools/agent/Stop-XdrWorkbench.ps1 when you choose to.

    .PARAMETER Tenant
        Tenant name (exact or unique partial match) or tenant ID.

    .PARAMETER Case
        Short case or hunt reference used in the folder name, e.g. INC12345 or edge-device-hunt.

    .PARAMETER Port
        Relay port. When omitted, the listener takes the first free port from 8787 to 8796 and
        extension 1.3+ finds it. When given, only that port is used.

    .PARAMETER AllowMto
        Kept for compatibility; MTO is now automatic. When the signed-in tenant differs from the
        target but has it in its MTO list, the case lock is set in MTO mode (hunting only).

    .PARAMETER NoBrowser
        Don't launch Chrome (use inside the container, or when the portal window is already open).

    .PARAMETER Incognito
        Open the portal in an Incognito window instead of a normal one. Incognito sends no device
        identity to Entra, so accounts under a compliant-device Conditional Access policy (the
        Cybanetix analyst accounts) get AADSTS53000 on multi-tenant hunting. Use it only for accounts
        without that policy.

    .PARAMETER NoCaseFolder
        Skip creating the investigation folder (the case already has an ir-case-workspace folder).

    .PARAMETER ListTenants
        Print the known tenants and exit.

    .EXAMPLE
        ./tools/agent/Start-XdrWorkbench.ps1 -ListTenants

    .EXAMPLE
        ./tools/agent/Start-XdrWorkbench.ps1 -Tenant "<customer name>" -Case INC12345
#>
[CmdletBinding(DefaultParameterSetName = 'Start')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Start')][string]$Tenant,
    [Parameter(ParameterSetName = 'Start')][string]$Case = 'hunt',
    [Parameter(ParameterSetName = 'Start')][int]$Port = 8787,
    [Parameter(ParameterSetName = 'Start')][switch]$AllowMto,
    [Parameter(ParameterSetName = 'Start')][switch]$NoBrowser,
    [Parameter(ParameterSetName = 'Start')][switch]$Incognito,
    [Parameter(ParameterSetName = 'Start')][switch]$NoCaseFolder,
    [Parameter(ParameterSetName = 'Start')][switch]$NoHuntCheck,
    [Parameter(Mandatory, ParameterSetName = 'List')][switch]$ListTenants
)
$ErrorActionPreference = 'Stop'
$script:PortGiven = $PSBoundParameters.ContainsKey('Port')
. (Join-Path $PSScriptRoot 'XdrWorkbench.Common.ps1')
$repoRoot = Get-XdrWorkbenchRoot
function Step([string]$m) { Write-Host "`n== $m" -ForegroundColor Cyan }
# Every command printed for the analyst calls its script by full path, so it works from whatever
# folder the PowerShell window is in. A relative ./tools/... line fails as soon as the cd is missed.
function Get-XdrScriptCall([string]$Name) { "& '" + ((Join-Path $repoRoot "tools/agent/$Name") -replace "'", "''") + "'" }
function Fail([string]$m) { Write-Host $m -ForegroundColor Red; Write-Host "Diagnose with: $(Get-XdrScriptCall 'Test-XdrWorkbench.ps1')" -ForegroundColor DarkGray; exit 1 }

if ($ListTenants) {
    Get-XdrTenantList | Sort-Object Name | Format-Table Name, TenantId -AutoSize | Out-Host
    return
}

Step 'Where this runs'
# The relay posts to 127.0.0.1 on this computer and the agent reads the session from this checkout,
# so a cloud container can never complete the standup.
$cloudMessage = Get-XdrCloudSessionMessage
if ($cloudMessage) { Fail $cloudMessage }
Write-Host "Local: $([Environment]::MachineName)"

Step 'PowerShell and module'
if ($PSVersionTable.PSVersion.Major -lt 7) { Fail "This needs PowerShell 7 (pwsh). You're in $($PSVersionTable.PSVersion). Install it with: winget install Microsoft.PowerShell" }
Import-Module (Join-Path $repoRoot 'XDRInternals/XDRInternals.psd1') -Force -WarningAction SilentlyContinue
Write-Host "pwsh $($PSVersionTable.PSVersion), XDRInternals $((Get-Module XDRInternals).Version) ($((Get-Command -Module XDRInternals).Count) cmdlets)"

Step 'Resolve tenant'
try { $target = Resolve-XdrTenant -Tenant $Tenant } catch { Fail $_.Exception.Message }
Write-Host "Target: $($target.Name) | $($target.TenantId)"
$url = "https://security.microsoft.com/v2/advanced-hunting?tid=$($target.TenantId)"
# The multi-tenant portal keeps its own sign-in. Opening it in the same window lets the relay carry
# that session too, so MTO hunting doesn't answer "440 Session timeout".
$mtoUrl = 'https://mto.security.microsoft.com/'

if ($IsWindows) {
    Step "Relay listener URL reservation (port $Port)"
    $reserved = (netsh http show urlacl url=http://+:$Port/ | Out-String) -match "http://\+:$Port/"
    if ($reserved) { Write-Host 'Reserved.' }
    else {
        $elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($elevated) { netsh http add urlacl url=http://+:$Port/ user="$env:USERDOMAIN\$env:USERNAME" | Out-Null; Write-Host 'Added.' }
        else { Write-Host "Not reserved; the listener will bind to localhost instead, which extension 1.3+ finds. (To reserve it, once, elevated: netsh http add urlacl url=http://+:$Port/ user=`"$env:USERDOMAIN\$env:USERNAME`")" -ForegroundColor Yellow }
    }
}
$busy = @(Get-XdrPortListener -Port $Port)
if ($busy) {
    $owner = "$($busy.Process -join ', ') (PID $($busy.Pid -join ', '))"
    if ($PSBoundParameters.ContainsKey('Port')) { Fail "Port $Port is already in use by $owner. Close that window (a stale standup?), or leave out -Port so the next free port is used." }
    Write-Host "Port $Port is in use by $owner; the listener will take the next free port, and the extension finds it. Close it if it is a stale standup." -ForegroundColor Yellow
}

Step 'Portal window'
$ext = @(try { Get-XdrRelayExtensionState } catch { })
if ($ext) {
    foreach ($e in $ext) {
        $flag = if ($e.Disabled) { 'DISABLED' } elseif ($e.Incognito) { 'enabled, allowed in incognito' } else { 'enabled' }
        Write-Host "Relay extension ($($e.Profile)): $flag"
    }
    if ($Incognito -and -not ($ext | Where-Object { $_.Incognito -and -not $_.Disabled })) {
        Write-Host "Turn on 'Allow in Incognito' for XDR Docker Relay: chrome://extensions > Details." -ForegroundColor Yellow
    }
} elseif (-not $NoBrowser) {
    Write-Host "Relay extension not found in Chrome profiles. Load it unpacked from $(Join-Path $repoRoot 'chrome-ext')." -ForegroundColor Yellow
}
$chrome = if ($NoBrowser) { $null } else { Find-XdrChrome }
$kind = if ($Incognito) { 'an Incognito' } else { 'a new Chrome' }
if ($chrome) {
    $chromeArgs = if ($Incognito) { @('--incognito', $url, $mtoUrl) } else { @('--new-window', $url, $mtoUrl) }
    Start-Process -FilePath $chrome -ArgumentList $chromeArgs
    Write-Host "Opened $kind window on $($target.Name) with two tabs: Advanced Hunting and the multi-tenant portal. Sign in if asked, and wait for both to load (the multi-tenant tab shows a tenant list)."
} else {
    Write-Host "Open $kind window with these two tabs, and wait for both to load:`n  $url`n  $mtoUrl"
}
Write-Host "In that window, click the XDR Docker Relay extension (1.3 or later), paste the pairing code printed below, and click 'Relay session to container'. The popup shows whether it can see this standup."

function Invoke-Relay {
    # One relay: listener, tenant check, saved session. Returns the tenant context, or stops the script.
    Step 'Sign-in relay'
    $relayArgs = @{ TenantId = $target.TenantId }
    if ($script:PortGiven) { $relayArgs.Port = $Port }
    # A pairing code lasts 5 minutes. When it runs out, offer a fresh one here rather than ending the
    # standup, so a slow sign-in or MFA prompt never means starting again from the top.
    while ($true) {
        try {
            $null = Connect-XdrByBrowserExtension @relayArgs
            break
        } catch {
            if ($_.Exception.Message -notmatch 'Timed out') { throw }
            Write-Host 'No relay arrived in time, so that pairing code has expired.' -ForegroundColor Yellow
            $answer = Read-Host 'Press Enter for a new pairing code (S to stop)'
            if ($answer -match '^[sS]') { Fail 'Stopped before a relay arrived. Nothing was saved.' }
        }
    }
    Step 'Confirm tenant'
    $c = Get-XdrTenantContext -Force
    Write-Host "Signed in: $($c.AuthInfo.TenantName) | $($c.AuthInfo.TenantId) | as $($c.AuthInfo.UserName)"
    $c
}
# The case folder path goes in the case lock, so the agent finds it without being told.
$folder = $null
if (-not $NoCaseFolder) {
    $short = (($target.Name -replace '(?i)\b(ltd|limited|plc|llp|group)\b', '') -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLower()
    $caseSafe = ($Case -replace '[^A-Za-z0-9_-]+', '-').Trim('-')
    $folder = Join-Path $repoRoot ("investigations/{0}-{1}-{2}" -f (Get-Date -Format 'yyyy-MM-dd'), $short, $caseSafe)
}
function Write-CaseLock([hashtable]$Extra = @{}) {
    $lock = [ordered]@{ CaseTenantId = $target.TenantId; CaseTenantName = $target.Name; SessionTenantId = $liveId; Case = $Case; CaseFolder = $folder; Mode = $mode; SetUtc = (Get-Date).ToUniversalTime().ToString('o') }
    foreach ($k in $Extra.Keys) { $lock[$k] = $Extra[$k] }
    $lock | ConvertTo-Json | Set-Content -Path (Join-Path $repoRoot '.xdr-agent/case.json') -Encoding utf8
}

$ctx = Invoke-Relay
$liveId = $ctx.AuthInfo.TenantId; $liveName = $ctx.AuthInfo.TenantName
$mode = 'direct'
if ($liveId -ne $target.TenantId) {
    $mto = @(Get-XdrMtoTenantList -ErrorAction SilentlyContinue)
    $inMto = $mto | Where-Object tenantId -eq $target.TenantId
    if ($inMto) {
        $mode = 'mto'
        Write-Host "The session is for $liveName, and $($target.Name) is in its MTO list. Case lock set in MTO mode: hunting works; incidents, devices and timelines would answer for $liveName, so the wrapper refuses them." -ForegroundColor Yellow
    } else {
        Fail "The session is for $liveName, not $($target.Name), and $($target.Name) isn't in its MTO list. Switch to $($target.Name) in the portal and rerun. Nothing was saved."
    }
}

Step 'Hand session to the agent'
& (Join-Path $PSScriptRoot 'Save-XdrAgentSession.ps1') -InRepo
# Default case lock for every wrapper call until teardown or the next standup.
Write-CaseLock
Write-Host "Case lock: $($target.Name) ($($target.TenantId))"

# Prove hunting works before calling the session ready. Fix what can be fixed here (relay again,
# retry after an MFA prompt); otherwise stop on the reason and the fix, so nothing downstream
# discovers it one failed query at a time.
$hunt = $null; $mtoProbe = $null
if (-not $NoHuntCheck) {
    Step 'Hunting check'
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $hunt = Invoke-XdrHuntCheck -CaseTenantId $target.TenantId -CaseTenantName $target.Name
        if ($hunt.Ok) { Write-Host $hunt.Reason -ForegroundColor $(if ($hunt.Kind -eq 'ok') { 'Green' } else { 'Yellow' }); if ($hunt.Fix) { Write-Host $hunt.Fix -ForegroundColor Yellow }; break }
        Write-Host "Hunting failed ($($hunt.Kind)): $($hunt.Reason)" -ForegroundColor Red
        Write-Host "Fix: $($hunt.Fix)" -ForegroundColor Yellow
        if ($hunt.Kind -in 'tenant-guard', 'no-session', 'unknown' -or $attempt -eq 3) { break }
        $answer = Read-Host "Do that now, then press Enter to retry (S to stop here)"
        if ($answer -match '^[sS]') { break }
        if ($hunt.Kind -eq 'device-compliance' -and $Incognito -and $chrome) {
            # A fresh normal-profile window carries the device identity Conditional Access wants.
            $Incognito = $false
            Start-Process -FilePath $chrome -ArgumentList @('--new-window', $url, $mtoUrl)
            Write-Host 'Opened a normal Chrome window. Sign in there, wait for both tabs, then relay from that window.'
        }
        if ($hunt.Kind -ne 'tenant-challenge') {
            $ctx = Invoke-Relay
            if ($ctx.AuthInfo.TenantId -ne $liveId) { Fail "The new relay is for $($ctx.AuthInfo.TenantName) ($($ctx.AuthInfo.TenantId)), not $liveName. Rerun the standup." }
            & (Join-Path $PSScriptRoot 'Save-XdrAgentSession.ps1') -InRepo
        }
    }
    # Direct-mode cases don't need MTO; probe it anyway so estate sweeps aren't a surprise later.
    if ($hunt.Ok -and $hunt.Route -eq 'direct') {
        $mtoProbe = Invoke-XdrHuntCheck -CaseTenantId $target.TenantId -CaseTenantName $target.Name -ForceMto
        if ($mtoProbe.Ok) { Write-Host 'Multi-tenant endpoint: also working (estate sweeps available).' }
        else { Write-Host "Multi-tenant endpoint: $($mtoProbe.Reason) Case hunting is unaffected." -ForegroundColor Yellow }
    }
    Write-CaseLock @{
        HuntRoute = $(if ($hunt.Ok) { $hunt.Route } else { 'none' })
        HuntCheck = $hunt.Kind
        MtoRoute  = $(if ($hunt.Route -eq 'mto') { $hunt.Kind } elseif ($mtoProbe) { $mtoProbe.Kind } else { 'not checked' })
        CheckedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

if (-not $NoCaseFolder) {
    Step 'Case folder'
    $null = New-Item -ItemType Directory -Path (Join-Path $folder 'queries'), (Join-Path $folder 'evidence') -Force
    $notes = Join-Path $folder 'case-notes.md'
    if (-not (Test-Path $notes)) {
        @"
# $($target.Name): $Case

Tenant: $($target.Name) ($($target.TenantId))
Session tenant: $liveName ($liveId), mode $mode
Analyst: $($ctx.AuthInfo.UserName)
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
    Write-Host $folder
}

Step 'Ready'
$huntState = if ($NoHuntCheck) { 'not checked (-NoHuntCheck)' } elseif ($hunt.Ok) { "$($hunt.Route) route OK ($($hunt.Devices) devices in the last day)" } else { "FAILED: $($hunt.Kind)" }
Write-Host "Session:  $liveName ($liveId) as $($ctx.AuthInfo.UserName)"
Write-Host "Case:     $($target.Name) ($($target.TenantId)), mode $mode, case $Case"
if ($folder) { Write-Host "Folder:   $folder" }
Write-Host "Hunting:  $huntState" -ForegroundColor $(if ($hunt.Ok) { 'Green' } elseif ($NoHuntCheck) { 'Gray' } else { 'Red' })
if ($hunt -and -not $hunt.Ok) { Write-Host "Fix:      $($hunt.Fix)" -ForegroundColor Yellow }

# Commands for when something goes wrong, and for ending the session. Each line is complete,
# so it can be copied as it stands into PowerShell 7 in this folder.
$rerun = "$(Get-XdrScriptCall 'Start-XdrWorkbench.ps1') -Tenant '$($target.TenantId)' -Case '$($Case -replace "'", "''")'"
if ($Port -ne 8787) { $rerun += " -Port $Port" }
if ($Incognito) { $rerun += ' -Incognito' }
$portArg = if ($Port -ne 8787) { " -Port $Port" } else { '' }
function Cmd([string]$Label, [string]$Line) { [pscustomobject]@{ Label = $Label; Line = $Line } }
$commands = @(
    Cmd 'Check the session, and print a fix for anything wrong:' "$(Get-XdrScriptCall 'Test-XdrWorkbench.ps1') -Live$portArg"
    Cmd 'Session expired or hunting stopped, portal window still open (relay again):' "$rerun -NoBrowser"
    Cmd 'Start again with a fresh portal window:' $rerun
    Cmd 'End the session (clears the saved session and case lock; keeps investigations/):' (Get-XdrScriptCall 'Stop-XdrWorkbench.ps1')
    if ($IsWindows) { Cmd 'End the session and remove the relay port reservation (elevated window):' "$(Get-XdrScriptCall 'Stop-XdrWorkbench.ps1') -RemoveUrlAcl$portArg" }
)
Write-Host ''
Write-Host 'If something goes wrong (PowerShell 7, any folder):' -ForegroundColor Cyan
# Labels print as PowerShell comments, so copying several lines at once is harmless too.
foreach ($cmd in $commands) { Write-Host "# $($cmd.Label)" -ForegroundColor DarkGray; Write-Host $cmd.Line }
Write-Host ''
if ($NoHuntCheck -or $hunt.Ok) {
    Write-Host 'Back in Claude, say the session is ready. Claude reads the session and case lock itself; there is nothing to paste.' -ForegroundColor Cyan
} else {
    Write-Host 'Hunting is not working yet. Apply the fix above, then run the relay-again command.' -ForegroundColor Yellow
}
Write-Host 'The session stays saved until you run the end-the-session command.'
if ($hunt -and -not $hunt.Ok) { exit 2 }
