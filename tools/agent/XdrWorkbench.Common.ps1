# Shared helpers for Start-, Stop- and Test-XdrWorkbench. Dot-source; no side effects.

function Get-XdrWorkbenchRoot { (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }

function Get-XdrTenantList {
    # Returns Name/TenantId rows from tenants.local.csv, else the MTO section of tenants.txt.
    param([string]$RepoRoot = (Get-XdrWorkbenchRoot))
    $csv = Join-Path $RepoRoot 'tenants.local.csv'
    $txt = Join-Path $RepoRoot 'tenants.txt'
    if (Test-Path $csv) {
        return @(Get-Content $csv | Where-Object { $_ -and $_ -notmatch '^#' } | ConvertFrom-Csv)
    }
    if (Test-Path $txt) {
        return @(Get-Content $txt | ForEach-Object {
            if ($_ -match '^(?<n>[^-\s].*?)\s{2,}(?<t>[0-9a-f]{8}-[0-9a-f-]{27})\s*$') { [pscustomobject]@{ Name = $Matches.n; TenantId = $Matches.t } }
        })
    }
    @()
}

function Resolve-XdrTenant {
    # Name (exact, then unique partial, case-insensitive) or GUID. Throws with the candidates on ambiguity.
    param([Parameter(Mandatory)][string]$Tenant, [object[]]$List = (Get-XdrTenantList))
    if ($Tenant -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
        $hit = $List | Where-Object TenantId -eq $Tenant | Select-Object -First 1
        if ($hit) { return $hit }
        return [pscustomobject]@{ Name = $Tenant; TenantId = $Tenant }
    }
    $hit = @($List | Where-Object Name -eq $Tenant)
    if (-not $hit) { $hit = @($List | Where-Object Name -like "*$Tenant*") }
    if ($hit.Count -eq 1) { return $hit[0] }
    if ($hit.Count -gt 1) { throw "'$Tenant' matches more than one tenant: $($hit.Name -join ', '). Be more specific or pass the tenant ID." }
    throw "No tenant matching '$Tenant'. Known: $(($List.Name | Sort-Object) -join ', '). Pass the tenant ID, or refresh tenants.local.csv from Get-XdrMtoTenantList."
}

function Find-XdrChrome {
    $candidates = @()
    if ($IsWindows) {
        $candidates = @(
            (Join-Path $env:ProgramFiles 'Google/Chrome/Application/chrome.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Google/Chrome/Application/chrome.exe'),
            (Join-Path $env:LOCALAPPDATA 'Google/Chrome/Application/chrome.exe'))
    } elseif ($IsMacOS) {
        $candidates = @('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
    } else {
        $candidates = @((Get-Command google-chrome, google-chrome-stable, chromium, chromium-browser -ErrorAction SilentlyContinue).Source)
    }
    $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

function Get-XdrChromeUserDataDir {
    if ($IsWindows) { return Join-Path $env:LOCALAPPDATA 'Google/Chrome/User Data' }
    if ($IsMacOS) { return Join-Path $HOME 'Library/Application Support/Google/Chrome' }
    Join-Path $HOME '.config/google-chrome'
}

function Get-XdrRelayExtensionState {
    # Best effort: finds the unpacked relay extension in each Chrome profile and whether incognito is
    # allowed. Chrome's preference files vary by version and some extension records are partial, so
    # every lookup is null-safe and any failure returns nothing rather than stopping the caller.
    try {
        $root = Get-XdrChromeUserDataDir
        if (-not $root -or -not (Test-Path $root)) { return @() }
        foreach ($profileDir in Get-ChildItem $root -Directory | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' }) {
            $settings = @{}
            foreach ($file in 'Preferences', 'Secure Preferences') {
                $p = Join-Path $profileDir.FullName $file
                if (-not (Test-Path $p)) { continue }
                try { $json = Get-Content $p -Raw | ConvertFrom-Json -AsHashtable -Depth 64 } catch { continue }
                if ($json -isnot [hashtable]) { continue }
                $ext = $json['extensions']; if ($ext -isnot [hashtable]) { continue }
                $s = $ext['settings']; if ($s -isnot [hashtable]) { continue }
                foreach ($id in $s.Keys) {
                    $rec = $s[$id]; if ($rec -isnot [hashtable]) { continue }
                    if (-not $settings.ContainsKey($id)) { $settings[$id] = @{} }
                    foreach ($k in $rec.Keys) { $settings[$id][$k] = $rec[$k] }
                }
            }
            foreach ($id in $settings.Keys) {
                $e = $settings[$id]
                $path = "$($e['path'])"
                $manifest = $e['manifest']
                $name = if ($manifest -is [hashtable]) { "$($manifest['name'])" } else { '' }
                if ($path -match '(chrome-ext|browser-extension)[\\/]?$' -or $name -eq 'XDR Docker Relay') {
                    [pscustomobject]@{
                        Profile   = $profileDir.Name
                        Id        = $id
                        Path      = $path
                        Incognito = [bool]$e['incognito']
                        Disabled  = ($e['state'] -eq 0) -or (@($e['disable_reasons'] | Where-Object { $_ -and $_ -ne 0 }).Count -gt 0)
                    }
                }
            }
        }
    } catch {
        Write-Verbose "Extension check skipped: $($_.Exception.Message)"
        return @()
    }
}

function Test-XdrPathGitIgnored {
    # $true if git ignores the path, $false if it would be tracked, $null outside a repo or without git.
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    $dir = Split-Path -Parent ([System.IO.Path]::GetFullPath($Path))
    while ($dir -and -not (Test-Path $dir)) { $dir = Split-Path -Parent $dir }
    if (-not $dir) { return $null }
    $top = git -C $dir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $top) { return $null }
    git -C $dir check-ignore -q -- ([System.IO.Path]::GetFullPath($Path)) 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-XdrPortListener {
    param([int]$Port)
    if ($IsWindows) {
        Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [pscustomobject]@{ Pid = $_.OwningProcess; Process = $proc.ProcessName }
        }
    } elseif (Get-Command ss -ErrorAction SilentlyContinue) {
        ss -ltnpH "sport = :$Port" 2>$null | ForEach-Object { [pscustomobject]@{ Pid = ($_ -replace '.*pid=(\d+).*', '$1'); Process = ($_ -replace '.*users:\(\("([^"]+)".*', '$1') } }
    }
}

function Get-XdrTenantShortName {
    param([Parameter(Mandatory)][string]$Name)
    (($Name -replace '(?i)\b(ltd|limited|plc|llp|group)\b', '') -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLower()
}

function Invoke-XdrHuntCheck {
    # Runs the control hunt through the wrapper against the saved session and says, in one object,
    # whether hunting works, on which route, and if not: the kind of failure, the reason and the fix.
    # The wrapper routes the hunt (direct endpoint in direct mode when the module has it); -ForceMto
    # probes the multi-tenant endpoint instead.
    param(
        [Parameter(Mandatory)][string]$CaseTenantId,
        [string]$CaseTenantName,
        [switch]$ForceMto
    )
    $kql = 'DeviceInfo | where Timestamp > ago(1d) | summarize Devices = dcount(DeviceId)'
    $command = "Invoke-XdrMtoAdvancedHunting -TenantIds '$CaseTenantId' -DaysAgo 1 -QueryText '$kql'"
    $pw = (Get-Process -Id $PID).Path
    $errFile = [System.IO.Path]::GetTempFileName()
    $previousRoute = $env:XDR_HUNT_ROUTE
    if ($ForceMto) { $env:XDR_HUNT_ROUTE = 'mto' }
    try { $out = & $pw -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-XdrAgent.ps1') -Command $command 2>$errFile; $code = $LASTEXITCODE }
    finally { $env:XDR_HUNT_ROUTE = $previousRoute }
    $err = "$(Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)"; Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue
    $rows = @(); try { $rows = @(($out | Out-String) | ConvertFrom-Json) } catch { $rows = @() }
    $hit = $rows | Where-Object { "$($_.TenantId)" -eq $CaseTenantId -and $null -ne $_.Devices } | Select-Object -First 1
    $route = if ($err -match 'Direct mode: hunt sent') { 'direct' } else { 'mto' }
    $name = if ($hit.TenantName) { $hit.TenantName } elseif ($CaseTenantName) { $CaseTenantName } else { $CaseTenantId }
    $firstError = (($err -split "`n") | Where-Object { $_ -match '^\[error\]|GUARD|NOT SEARCHED|TIMEOUT|REFUSED|SESSION' } | Select-Object -First 1)
    $result = [ordered]@{ Ok = $false; Route = $route; Kind = 'unknown'; Devices = $null; Reason = ''; Fix = ''; ExitCode = $code; Error = "$firstError".Trim() }
    if ($code -eq 0 -and $hit) {
        $result.Ok = $true; $result.Devices = $hit.Devices
        if ($hit.Devices -gt 0) { $result.Kind = 'ok'; $result.Reason = "$name answered on the $route route: $($hit.Devices) devices reporting in the last day" }
        else { $result.Kind = 'no-devices'; $result.Reason = "$name answered on the $route route, but no devices reported in the last day"; $result.Fix = 'Check Defender for Endpoint onboarding for this customer before relying on endpoint hunts.' }
    }
    elseif ($err -match 'AADSTS53000') { $result.Kind = 'device-compliance'; $result.Reason = 'Conditional Access requires a compliant device, and the relayed session came from a window without device identity (usually Incognito).'; $result.Fix = 'Sign in from the normal Chrome profile (not Incognito) and relay again.' }
    elseif ($code -eq 7) { $result.Kind = 'tenant-guard'; $result.Reason = 'The case lock and the session disagree about the tenant.'; $result.Fix = 'Rerun the standup for the case customer.' }
    elseif ($code -eq 4) { $result.Kind = 'no-session'; $result.Reason = 'No saved session, or it is older than 12 hours.'; $result.Fix = 'Rerun the standup.' }
    elseif ($err -match 'TENANT NOT SEARCHED|MfaChallenge|\b588\b') { $result.Kind = 'tenant-challenge'; $result.Reason = "$name refused the hunt with an MFA or Conditional Access challenge."; $result.Fix = "In the portal window, open $name, complete the MFA prompt, then retry." }
    elseif ($code -eq 8 -or $err -match '\b440\b|Session ?timeout') {
        if ($route -eq 'direct') { $result.Kind = 'session-expired'; $result.Reason = 'The single-tenant hunting endpoint answered 440: the portal session has expired.'; $result.Fix = 'Sign in again in the portal window and relay again.' }
        elseif ($err -match 'MTO portal session') { $result.Kind = 'mto-rejected'; $result.Reason = 'The multi-tenant endpoint answered 440 even with the multi-tenant portal session the relay carried.'; $result.Fix = 'Reload https://mto.security.microsoft.com in the portal window until the tenant list shows, then relay again. If it still fails, MTO hunting needs something the relay does not carry: use the portal fallback (reference/hunting-outage.md).' }
        else { $result.Kind = 'mto-no-session'; $result.Reason = 'The multi-tenant endpoint answered 440: the relay carried no multi-tenant portal session.'; $result.Fix = 'In the portal window open https://mto.security.microsoft.com, wait for the tenant list, then relay again (relay extension 1.2 or later).' }
    }
    elseif ($err -match '\b401\b|\b403\b|Unauthorized|Forbidden') { $result.Kind = 'unauthorized'; $result.Reason = 'The hunting endpoint refused the session (401/403): expired, or the role does not cover hunting in this tenant.'; $result.Fix = 'Sign in again and relay. If it persists, check the analyst role for Advanced Hunting in this tenant.' }
    else { $result.Reason = "Control hunt failed (exit $code). $firstError".Trim(); $result.Fix = 'Run the control hunt through the wrapper directly to see the full error.' }
    [pscustomobject]$result
}
