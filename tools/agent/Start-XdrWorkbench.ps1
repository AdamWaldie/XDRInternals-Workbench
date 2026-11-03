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
          4. Opens a Chrome incognito window on the target tenant's Advanced Hunting page and checks
             the relay extension is allowed in incognito. The relay reads the portal cookie from
             the window you click it in, so sign in there.
          5. Starts Connect-XdrByBrowserExtension and prints the pairing code.
          6. Compares the live tenant with the target. On a match it saves the agent session to
             <repo>/.xdr-agent/session.json (git- and docker-ignored). On a mismatch it checks
             whether the target is reachable through MTO and tells you which way to go.
          7. Creates investigations/<date>-<tenant-short>-<case>/ with a case notes file.

        Run tools/agent/Test-XdrWorkbench.ps1 when a step fails. Tear down with
        tools/agent/Stop-XdrWorkbench.ps1 when you choose to.

    .PARAMETER Tenant
        Tenant name (exact or unique partial match) or tenant ID.

    .PARAMETER Case
        Short case or hunt reference used in the folder name, e.g. INC12345 or edge-device-hunt.

    .PARAMETER Port
        Relay port. Must match the extension popup. Default 8787.

    .PARAMETER AllowMto
        Save the session even when the signed-in tenant differs from the target, provided the
        target is in that tenant's MTO list. Hunting then passes -TenantIds <target>; entity
        cmdlets still act on the signed-in tenant.

    .PARAMETER NoBrowser
        Don't launch Chrome (use inside the container, or when the incognito window is already open).

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
    [Parameter(ParameterSetName = 'Start')][switch]$NoCaseFolder,
    [Parameter(Mandatory, ParameterSetName = 'List')][switch]$ListTenants
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'XdrWorkbench.Common.ps1')
$repoRoot = Get-XdrWorkbenchRoot
function Step([string]$m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Fail([string]$m) { Write-Host $m -ForegroundColor Red; Write-Host "Diagnose with: ./tools/agent/Test-XdrWorkbench.ps1 -Port $Port" -ForegroundColor DarkGray; exit 1 }

if ($ListTenants) {
    Get-XdrTenantList | Sort-Object Name | Format-Table Name, TenantId -AutoSize | Out-Host
    return
}

Step 'PowerShell and module'
if ($PSVersionTable.PSVersion.Major -lt 7) { Fail "This needs PowerShell 7 (pwsh). You're in $($PSVersionTable.PSVersion). Install it with: winget install Microsoft.PowerShell" }
Import-Module (Join-Path $repoRoot 'XDRInternals/XDRInternals.psd1') -Force -WarningAction SilentlyContinue
Write-Host "pwsh $($PSVersionTable.PSVersion), XDRInternals $((Get-Module XDRInternals).Version) ($((Get-Command -Module XDRInternals).Count) cmdlets)"

Step 'Resolve tenant'
try { $target = Resolve-XdrTenant -Tenant $Tenant } catch { Fail $_.Exception.Message }
Write-Host "Target: $($target.Name) | $($target.TenantId)"
$url = "https://security.microsoft.com/v2/advanced-hunting?tid=$($target.TenantId)"

if ($IsWindows) {
    Step "Relay listener URL reservation (port $Port)"
    $reserved = (netsh http show urlacl url=http://+:$Port/ | Out-String) -match "http://\+:$Port/"
    if ($reserved) { Write-Host 'Reserved.' }
    else {
        $elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($elevated) { netsh http add urlacl url=http://+:$Port/ user="$env:USERDOMAIN\$env:USERNAME" | Out-Null; Write-Host 'Added.' }
        else { Fail "The relay listener can't bind without a URL reservation. Run this once in an elevated PowerShell, then rerun:`n  netsh http add urlacl url=http://+:$Port/ user=`"$env:USERDOMAIN\$env:USERNAME`"" }
    }
    $busy = @(Get-XdrPortListener -Port $Port)
    if ($busy) { Fail "Port $Port is already in use by $($busy.Process -join ', ') (PID $($busy.Pid -join ', ')). Close the earlier Connect-XdrByBrowserExtension window, or pick another port with -Port (and the same port in the extension)." }
}

Step 'Incognito sign-in window'
$ext = @(Get-XdrRelayExtensionState)
if ($ext) {
    foreach ($e in $ext) {
        $flag = if ($e.Disabled) { 'DISABLED' } elseif ($e.Incognito) { 'allowed in incognito' } else { 'NOT allowed in incognito' }
        Write-Host "Relay extension ($($e.Profile)): $flag"
    }
    if (-not ($ext | Where-Object { $_.Incognito -and -not $_.Disabled })) {
        Write-Host "Turn on 'Allow in Incognito' for XDR Docker Relay: chrome://extensions > Details." -ForegroundColor Yellow
    }
} elseif (-not $NoBrowser) {
    Write-Host "Relay extension not found in Chrome profiles. Load it unpacked from $(Join-Path $repoRoot 'chrome-ext') and allow it in incognito." -ForegroundColor Yellow
}
$chrome = if ($NoBrowser) { $null } else { Find-XdrChrome }
if ($chrome) {
    Start-Process -FilePath $chrome -ArgumentList '--incognito', $url
    Write-Host "Opened an incognito window on $($target.Name). Sign in there with your Cybanetix account."
} else {
    Write-Host "Open a Chrome incognito window (Ctrl+Shift+N) at:`n  $url"
}
Write-Host "In that incognito window, open the XDR Docker Relay extension, paste the code printed below, keep port $Port, and click Relay."

Step 'Sign-in relay'
Connect-XdrByBrowserExtension -Port $Port -TenantId $target.TenantId

Step 'Confirm tenant'
$ctx = Get-XdrTenantContext -Force
$liveId = $ctx.AuthInfo.TenantId; $liveName = $ctx.AuthInfo.TenantName
Write-Host "Signed in: $liveName | $liveId | as $($ctx.AuthInfo.UserName)"
$mode = 'direct'
if ($liveId -ne $target.TenantId) {
    $mto = @(Get-XdrMtoTenantList -ErrorAction SilentlyContinue)
    $inMto = $mto | Where-Object tenantId -eq $target.TenantId
    if ($inMto -and $AllowMto) {
        $mode = 'mto'
        Write-Host "The session is for $liveName, but $($target.Name) is in its MTO list. Saving for MTO hunting." -ForegroundColor Yellow
    } elseif ($inMto) {
        Fail "The session is for $liveName, not $($target.Name). $($target.Name) is reachable through MTO from here: rerun with -AllowMto for hunting only, or switch tenant in the incognito window and rerun. Nothing was saved."
    } else {
        Fail "The session is for $liveName, not $($target.Name), and $($target.Name) isn't in its MTO list. Switch tenant in the incognito window and rerun. Nothing was saved."
    }
}

Step 'Hand session to the agent'
& (Join-Path $PSScriptRoot 'Save-XdrAgentSession.ps1') -InRepo
# Default case lock for every wrapper call until teardown or the next standup.
[ordered]@{ CaseTenantId = $target.TenantId; CaseTenantName = $target.Name; SessionTenantId = $liveId; Case = $Case; SetUtc = (Get-Date).ToUniversalTime().ToString('o') } |
    ConvertTo-Json | Set-Content -Path (Join-Path $repoRoot '.xdr-agent/case.json') -Encoding utf8
Write-Host "Case lock: $($target.Name) ($($target.TenantId))"

if (-not $NoCaseFolder) {
    Step 'Case folder'
    $short = (($target.Name -replace '(?i)\b(ltd|limited|plc|llp|group)\b', '') -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLower()
    $caseSafe = ($Case -replace '[^A-Za-z0-9_-]+', '-').Trim('-')
    $folder = Join-Path $repoRoot ("investigations/{0}-{1}-{2}" -f (Get-Date -Format 'yyyy-MM-dd'), $short, $caseSafe)
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
Write-Host "Agent calls:  -ExpectTenantId $liveId (hunts are locked to $($target.Name) by .xdr-agent/case.json)"
Write-Host "Hunting:      Invoke-XdrMtoAdvancedHunting -TenantIds '$($target.TenantId)' ..."
Write-Host "The session stays saved until you clear it: ./tools/agent/Stop-XdrWorkbench.ps1"
