<#
    .SYNOPSIS
        Diagnoses the Workbench setup and the current session, and says how to fix each problem.

    .DESCRIPTION
        Read-only. Checks PowerShell, the module, tenant lists, the relay port and URL
        reservation, Chrome and the relay extension (installed, enabled, allowed in incognito),
        the saved session (where, how old, which tenant, file permissions, git and docker
        ignore status), portal reachability, and git hygiene for case data. With -Live it also
        makes one read-only call through the agent wrapper to prove the session works.

        Runs on the analyst's machine (full checks) or in a Linux shell such as the Cowork device
        VM or the container (Chrome and URL reservation checks are skipped there).

    .PARAMETER Port
        Relay port to check. Default 8787.

    .PARAMETER Live
        Also run Get-XdrTenantContext through tools/agent/Invoke-XdrAgent.ps1, and a control hunt
        against the case tenant on the route the case mode uses: direct mode hunts with
        Invoke-XdrAdvancedHunting (security.microsoft.com) when the module has it and probes the
        MTO route separately; MTO mode hunts with Invoke-XdrMtoAdvancedHunting. Without -Live no
        hunting endpoint is called, so a clean result says nothing about hunting.

    .PARAMETER Json
        Emit results as JSON (for an agent to parse) instead of a table.

    .EXAMPLE
        ./tools/agent/Test-XdrWorkbench.ps1 -Live
#>
[CmdletBinding()]
param([int]$Port = 8787, [switch]$Live, [switch]$Json)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'XdrWorkbench.Common.ps1')
$repoRoot = Get-XdrWorkbenchRoot
$results = [System.Collections.Generic.List[object]]::new()
function Add-Check([string]$Area, [string]$Status, [string]$Detail, [string]$Fix = '') {
    $results.Add([pscustomobject]@{ Area = $Area; Status = $Status; Detail = $Detail; Fix = $Fix })
}

# PowerShell and module
if ($PSVersionTable.PSVersion.Major -ge 7) { Add-Check 'pwsh' 'OK' "$($PSVersionTable.PSVersion) on $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)" }
else { Add-Check 'pwsh' 'FAIL' "$($PSVersionTable.PSVersion)" 'Install PowerShell 7 (winget install Microsoft.PowerShell) and run scripts with pwsh, not powershell.exe.' }
try {
    Import-Module (Join-Path $repoRoot 'XDRInternals/XDRInternals.psd1') -Force -WarningAction SilentlyContinue -ErrorAction Stop
    Add-Check 'module' 'OK' "XDRInternals $((Get-Module XDRInternals).Version), $((Get-Command -Module XDRInternals).Count) cmdlets"
} catch { Add-Check 'module' 'FAIL' $_.Exception.Message 'Check the checkout is complete and you are in pwsh 7.' }

# Tenants
$list = @(Get-XdrTenantList -RepoRoot $repoRoot)
if ($list.Count) { Add-Check 'tenants' 'OK' "$($list.Count) tenants known ($(if (Test-Path (Join-Path $repoRoot 'tenants.local.csv')) { 'tenants.local.csv' } else { 'tenants.txt' }))" }
else { Add-Check 'tenants' 'WARN' 'No tenant list found' 'After a standup, export Get-XdrMtoTenantList to tenants.local.csv (Name,TenantId).' }

# Relay port and URL reservation
$busy = @(Get-XdrPortListener -Port $Port)
if ($busy) { Add-Check 'relay port' 'WARN' "Port $Port in use by $($busy.Process -join ', ') (PID $($busy.Pid -join ', '))" 'Close the earlier listener or use another -Port, set to match in the extension.' }
else { Add-Check 'relay port' 'OK' "Port $Port free" }
if ($IsWindows) {
    if ((netsh http show urlacl url=http://+:$Port/ | Out-String) -match "http://\+:$Port/") { Add-Check 'url reservation' 'OK' "http://+:$Port/ reserved" }
    else { Add-Check 'url reservation' 'FAIL' "No reservation for http://+:$Port/ (listener fails with 'Access is denied')" "Elevated, once: netsh http add urlacl url=http://+:$Port/ user=`"$env:USERDOMAIN\$env:USERNAME`"" }
}

# Chrome and the relay extension
if ($IsWindows -or $IsMacOS) {
    $chrome = Find-XdrChrome
    if ($chrome) { Add-Check 'chrome' 'OK' $chrome } else { Add-Check 'chrome' 'WARN' 'Chrome not found in the usual locations' 'Install Chrome, or open the incognito window yourself.' }
    $ext = @(Get-XdrRelayExtensionState)
    if (-not $ext) { Add-Check 'relay extension' 'FAIL' 'XDR Docker Relay not found in any Chrome profile' "chrome://extensions > Developer mode > Load unpacked > $(Join-Path $repoRoot 'chrome-ext'), then Details > Allow in Incognito." }
    foreach ($e in $ext) {
        if ($e.Disabled) { Add-Check 'relay extension' 'FAIL' "$($e.Profile): disabled ($($e.Path))" 'Enable it in chrome://extensions.' }
        elseif (-not $e.Incognito) { Add-Check 'relay extension' 'FAIL' "$($e.Profile): not allowed in incognito" "chrome://extensions > XDR Docker Relay > Details > Allow in Incognito. The relay reads the cookie from the incognito window you sign in to." }
        else { Add-Check 'relay extension' 'OK' "$($e.Profile): enabled, allowed in incognito ($($e.Path))" }
    }
}
$a = Join-Path $repoRoot 'chrome-ext'; $b = Join-Path $repoRoot 'docker/browser-extension'
if ((Test-Path $a) -and (Test-Path $b)) {
    $ha = Get-ChildItem $a -File -Recurse | Sort-Object Name | Get-FileHash | ForEach-Object Hash
    $hb = Get-ChildItem $b -File -Recurse | Sort-Object Name | Get-FileHash | ForEach-Object Hash
    if (($ha -join '') -eq ($hb -join '')) { Add-Check 'extension copies' 'OK' 'chrome-ext matches docker/browser-extension' }
    else { Add-Check 'extension copies' 'WARN' 'chrome-ext and docker/browser-extension differ' 'Copy the updated one over the other, reload the extension in Chrome.' }
}

# Saved sessions
$maxAge = 12
$sessions = @(@($env:XDR_SESSION_PATH, (Join-Path $repoRoot '.xdr-agent/session.json'), (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.xdr-agent/session.json')) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
if (-not $sessions) { Add-Check 'session' 'WARN' 'No saved session' 'Save a session from the relay extension into <repo>/.xdr-agent, then run Import-XdrSessionDrop.ps1 (or Start-XdrWorkbench.ps1 on the user machine).' }
foreach ($s in $sessions) {
    try {
        $j = Get-Content $s -Raw | ConvertFrom-Json
        if (-not $j.SccAuth) { Add-Check 'session' 'WARN' "$s is cleared" 'Run the standup.'; continue }
        $age = ((Get-Date).ToUniversalTime() - ([datetime]::Parse($j.SavedAt, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)).ToUniversalTime()).TotalHours
        $st = if ($age -gt $maxAge) { 'FAIL' } else { 'OK' }
        Add-Check 'session' $st ("{0}: {1} ({2}) as {3}, saved {4:N1} h ago" -f $s, $j.TenantName, $j.TenantId, $j.Account, $age) $(if ($st -eq 'FAIL') { "Older than the wrapper's $maxAge h limit. Rerun the standup." })
    } catch { Add-Check 'session' 'FAIL' "$s unreadable: $($_.Exception.Message)" 'Clear it with Save-XdrAgentSession.ps1 -Clear -InRepo and rerun the standup.' }
    $ig = Test-XdrPathGitIgnored -Path $s
    if ($ig -eq $false) { Add-Check 'session ignore' 'FAIL' "$s would be tracked by git" 'Add its folder to .gitignore now, and clear the session.' }
    elseif ($ig) { Add-Check 'session ignore' 'OK' "$s is git-ignored" }
    if ($IsLinux -or $IsMacOS) {
        $mode = (stat -c '%a' $s 2>$null); if (-not $mode) { $mode = (stat -f '%Lp' $s 2>$null) }
        # Only group/other bits matter; folders mounted from Windows report 700 and enforce NTFS ACLs instead.
        if ($mode -and $mode.Length -ge 3 -and $mode.Substring($mode.Length - 2) -ne '00') { Add-Check 'session perms' 'WARN' "$s mode $mode" "chmod 600 '$s'" }
    }
}
$caseFile = Join-Path $repoRoot '.xdr-agent/case.json'
if (Test-Path $caseFile) {
    try { $c = Get-Content $caseFile -Raw | ConvertFrom-Json
        if ($c.CaseTenantId) { Add-Check 'case lock' 'OK' "Hunts locked to $($c.CaseTenantName) ($($c.CaseTenantId)), mode $($c.Mode); estate sweeps need -AllowMultiTenant" }
        else { Add-Check 'case lock' 'WARN' 'Case lock cleared' 'Run the standup for the case customer.' } }
    catch { Add-Check 'case lock' 'FAIL' "$caseFile unreadable" 'Rerun the standup, or remove the file with Stop-XdrWorkbench.ps1.' }
} else { Add-Check 'case lock' 'WARN' 'No case lock recorded; hunts are only held to one tenant per call' 'Run the standup for the case tenant, or pass -CaseTenantId on every call.' }
$dockerIgnore = Join-Path $repoRoot '.dockerignore'
if ((Test-Path $dockerIgnore) -and -not (Select-String -Path $dockerIgnore -Pattern '^\.xdr-agent' -Quiet)) { Add-Check 'docker ignore' 'FAIL' '.xdr-agent is not in .dockerignore' 'Add .xdr-agent to .dockerignore so the token never enters an image.' }

# Git hygiene for case data
if (Get-Command git -ErrorAction SilentlyContinue) {
    $tracked = @(git -C $repoRoot ls-files -- '.xdr-agent' 'investigations' 'tenants.local.csv' 2>$null)
    if ($tracked) { Add-Check 'git' 'FAIL' "Tracked case or session files: $($tracked -join ', ')" 'git rm --cached them and commit; consider purging history.' }
    else { Add-Check 'git' 'OK' 'No session, case or local tenant files tracked' }
}

# Network
foreach ($h in 'security.microsoft.com', 'mto.security.microsoft.com') {
    try { $r = Invoke-WebRequest -Uri "https://$h" -Method Head -TimeoutSec 15 -SkipHttpErrorCheck -ErrorAction Stop; Add-Check 'network' 'OK' "$h reachable (HTTP $($r.StatusCode))" }
    catch { Add-Check 'network' 'FAIL' "$h not reachable: $($_.Exception.Message)" 'Check proxy/VPN, or the container egress allowlist (XDR_ALLOWED_DOMAINS).' }
}

# Live call
if ($Live) {
    $pw = (Get-Process -Id $PID).Path
    $out = & $pw -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-XdrAgent.ps1') -Format List -Command '(Get-XdrTenantContext -Force).AuthInfo | Select-Object TenantName, TenantId, UserName' 2>&1
    $code = $LASTEXITCODE
    $meaning = @{ 0 = 'ok'; 1 = 'command threw'; 2 = 'partial'; 4 = 'no or stale session'; 5 = 'tenant mismatch'; 6 = 'not PowerShell 7'; 7 = 'tenant guard'; 8 = 'hunt session timeout' }[$code]
    $text = ($out | Out-String).Trim() -replace '\s+', ' '
    if ($code -eq 0) { Add-Check 'live call' 'OK' $text }
    else { Add-Check 'live call' 'FAIL' "exit $code ($meaning): $($text.Substring(0, [Math]::Min(300, $text.Length)))" $(if ($text -match '401|403') { 'Session expired or no portal access in that tenant. Rerun the standup.' } else { 'See the wrapper message.' }) }
}

# Control hunt: proves the whole chain (session, relay, route, case lock) returns data for the case tenant.
# Direct mode (session tenant = case tenant) hunts on security.microsoft.com with Invoke-XdrAdvancedHunting
# when the module has it, and probes the MTO route on its own row; MTO mode can only use the MTO route.
$caseLock = if (Test-Path $caseFile) { try { Get-Content $caseFile -Raw | ConvertFrom-Json } catch { $null } }
$controlKql = 'DeviceInfo | where Timestamp > ago(1d) | summarize Devices = dcount(DeviceId)'
function Invoke-ControlHunt([string]$Command) {
    $pw = (Get-Process -Id $PID).Path
    $errFile = [System.IO.Path]::GetTempFileName()
    $out = & $pw -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-XdrAgent.ps1') -Command $Command 2>$errFile
    $code = $LASTEXITCODE
    $errText = Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue
    $rows = @(); try { $rows = @(($out | Out-String) | ConvertFrom-Json) } catch { }
    [pscustomobject]@{ Code = $code; Err = "$errText"; Rows = $rows }
}
function Get-DirectHuntCommand([string]$TenantId) {
    # Built from the cmdlet's own parameters, because the direct route is newer than this script.
    $cmd = Get-Command -Module XDRInternals -Name Invoke-XdrAdvancedHunting -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    $qp = @('QueryText', 'Query', 'Kql') | Where-Object { $cmd.Parameters.ContainsKey($_) } | Select-Object -First 1
    if (-not $qp) { return $null }
    $text = "Invoke-XdrAdvancedHunting -$qp '$controlKql'"
    $tp = @('TenantId', 'TenantIds') | Where-Object { $cmd.Parameters.ContainsKey($_) } | Select-Object -First 1
    if ($tp) { $text += " -$tp '$TenantId'" }
    if ($cmd.Parameters.ContainsKey('DaysAgo')) { $text += ' -DaysAgo 1' }
    $text
}
function Test-Is440([object]$Run) { $Run.Code -eq 8 -or $Run.Err -match '\b440\b|Session ?timeout' }

if ($caseLock.CaseTenantId -and -not $Live) {
    Add-Check 'hunting' 'SKIP' 'Not tested: without -Live no hunting endpoint is called' 'Run ./tools/agent/Test-XdrWorkbench.ps1 -Live before hunting; it runs a control hunt on the route this case uses.'
}
if ($Live -and $caseLock.CaseTenantId) {
    $case = $caseLock
    $direct = $case.Mode -eq 'direct' -or ($case.SessionTenantId -and $case.SessionTenantId -eq $case.CaseTenantId)
    $directCmd = if ($direct) { Get-DirectHuntCommand -TenantId $case.CaseTenantId } else { $null }
    $mtoCmd = "Invoke-XdrMtoAdvancedHunting -TenantIds '$($case.CaseTenantId)' -DaysAgo 1 -QueryText '$controlKql'"
    $route = if ($directCmd) { 'direct' } else { 'MTO' }
    $run = Invoke-ControlHunt $(if ($directCmd) { $directCmd } else { $mtoCmd })
    $code = $run.Code; $errText = $run.Err
    # MTO rows carry TenantId; direct rows answer for the session tenant only and may not.
    $hit = if ($route -eq 'MTO') { $run.Rows | Where-Object { "$($_.TenantId)" -eq $case.CaseTenantId } | Select-Object -First 1 } else { $run.Rows | Where-Object { $null -ne $_.Devices } | Select-Object -First 1 }
    $label = if ($hit.TenantName) { $hit.TenantName } else { $case.CaseTenantName }
    if ($code -eq 0 -and $hit -and $hit.Devices -gt 0) { Add-Check 'control hunt' 'OK' "$label ($route route): $($hit.Devices) devices reporting in the last day" }
    elseif ($code -eq 0 -and $hit) { Add-Check 'control hunt' 'WARN' "$label ($route route) answered but no devices reported in the last day" 'Check Defender for Endpoint onboarding for this customer before relying on endpoint hunts.' }
    elseif ($errText -match 'AADSTS53000') { Add-Check 'control hunt' 'FAIL' "Hunting refused: AADSTS53000 (Conditional Access requires a compliant device)" 'The session came from a window without device identity (usually Incognito). Rerun the standup without -Incognito, signing in from your normal Chrome profile.' }
    elseif (Test-Is440 $run) {
        $fix = if ($route -eq 'direct') { 'The direct route timed out too, so the portal session has expired: rerun the standup.' }
        elseif ($direct) { 'MTO endpoint rejected the relayed session. This case is direct mode but the module has no Invoke-XdrAdvancedHunting: update the checkout, or use the portal fallback (reference/hunting-outage.md).' }
        else { 'MTO endpoint rejected the relayed session, and an MTO case cannot use the direct route. See reference/hunting-outage.md: direct-mode standup in the customer tenant, or the portal fallback.' }
        Add-Check 'control hunt' 'FAIL' "440 Session timeout on the $route route for $($case.CaseTenantName) ($($case.CaseTenantId))" $fix
    }
    else { Add-Check 'control hunt' 'FAIL' "exit $code ($route route), no rows for case tenant $($case.CaseTenantName) ($($case.CaseTenantId))" $(switch ($code) { 2 { 'Tenant not searched: satisfy the MFA or Conditional Access challenge for this customer in the portal, then rerun.' } 4 { 'No or stale session: rerun the standup.' } 7 { 'Tenant guard: the case lock and the session disagree. Rerun the standup for the case customer.' } default { 'Rerun with the wrapper directly to see the error.' } }) }

    # In direct mode the MTO route is only needed for estate sweeps; report it, but don't fail on it.
    if ($directCmd) {
        $mto = Invoke-ControlHunt $mtoCmd
        if ($mto.Code -eq 0) { Add-Check 'mto hunt' 'OK' 'MTO route answers (estate sweeps available)' }
        elseif (Test-Is440 $mto) { Add-Check 'mto hunt' 'WARN' 'MTO route: 440 Session timeout (the relay carries no mto.security.microsoft.com session)' 'Case hunting is unaffected: use Invoke-XdrAdvancedHunting. Estate sweeps need the MTO route; see reference/hunting-outage.md.' }
        else { Add-Check 'mto hunt' 'WARN' "MTO route: exit $($mto.Code)" 'Case hunting is unaffected. Rerun the MTO control through the wrapper to see the error.' }
    }
}

if ($Json) { $results | ConvertTo-Json -Depth 3 }
else {
    $results | Format-Table Status, Area, Detail -AutoSize -Wrap | Out-Host
    $fixes = $results | Where-Object { $_.Fix -and $_.Status -ne 'OK' }
    if ($fixes) { Write-Host 'Fixes:'; $fixes | ForEach-Object { Write-Host "  [$($_.Area)] $($_.Fix)" } }
    else { Write-Host 'No problems found.' }
}
if ($results | Where-Object Status -eq 'FAIL') { exit 1 }
