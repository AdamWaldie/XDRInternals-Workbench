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
