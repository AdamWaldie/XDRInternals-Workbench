<#
    .SYNOPSIS
        Tears down a hunt or IR session: removes the saved portal session, purges module temp
        data, checks no customer data is staged in git, and optionally removes the URL
        reservation.

    .DESCRIPTION
        Safe to run more than once. It never deletes anything under investigations/, because
        that is case evidence. It reports what is there so you can move it to the case store.

    .PARAMETER RemoveUrlAcl
        Also remove the HTTP.sys reservation for the relay port (Windows, elevated window).

    .PARAMETER Port
        Relay port whose reservation to remove. Default 8787.

    .EXAMPLE
        ./tools/agent/Stop-XdrWorkbench.ps1
#>
[CmdletBinding()]
param(
    [switch]$RemoveUrlAcl,
    [int]$Port = 8787
)
$ErrorActionPreference = 'Continue'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
function Step([string]$m) { Write-Host "`n== $m" -ForegroundColor Cyan }

Step 'Saved agent sessions'
& (Join-Path $PSScriptRoot 'Save-XdrAgentSession.ps1') -Clear -InRepo
& (Join-Path $PSScriptRoot 'Save-XdrAgentSession.ps1') -Clear
$caseFile = Join-Path $repoRoot '.xdr-agent/case.json'
if (Test-Path $caseFile) { Remove-Item -LiteralPath $caseFile -Force; Write-Host "Removed case lock $caseFile" }
if ($env:XDR_SESSION_PATH -and (Test-Path $env:XDR_SESSION_PATH)) {
    Remove-Item -LiteralPath $env:XDR_SESSION_PATH -Force; Write-Host "Removed $env:XDR_SESSION_PATH"
}

Step 'In-memory session'
if (Get-Module XDRInternals) {
    $m = Get-Module XDRInternals
    & $m { $script:session = $null }
    Remove-Module XDRInternals -Force
    Write-Host 'Cleared the module session in this window and unloaded the module.'
} else { Write-Host 'Module not loaded in this window.' }

Step 'Module temp data'
$tmp = [System.IO.Path]::GetTempPath()
$paths = @('XdrTimeline', 'XdrIdentityTimeline', 'XdrCloudAppsTimeline', 'XdrAzureDataExplorer') | ForEach-Object { Join-Path $tmp $_ }
$paths += @(Get-ChildItem -Path $tmp -Directory -Filter 'xdr-browser-signin-*' -ErrorAction SilentlyContinue | ForEach-Object FullName)
$removed = 0
foreach ($p in $paths) { if (Test-Path $p) { Remove-Item -LiteralPath $p -Recurse -Force; $removed++; Write-Host "Removed $p" } }
if (-not $removed) { Write-Host 'Nothing to purge.' }

Step 'Git check'
Push-Location $repoRoot
try {
    $leak = @(git status --porcelain --ignored=no 2>$null | Where-Object { $_ -match 'investigations/|\.xdr-agent/|tenants\.local\.csv' })
    if ($leak) { Write-Host "Customer data is visible to git. Check .gitignore before committing:" -ForegroundColor Red; $leak | ForEach-Object { Write-Host "  $_" } }
    else { Write-Host 'No case data or session files visible to git.' }
} finally { Pop-Location }

Step 'Case evidence'
$inv = Join-Path $repoRoot 'investigations'
if (Test-Path $inv) {
    Get-ChildItem $inv -Directory | ForEach-Object {
        $files = Get-ChildItem $_.FullName -Recurse -File
        "{0}  {1} files, {2:N1} MB" -f $_.Name, $files.Count, (($files | Measure-Object Length -Sum).Sum / 1MB)
    } | Write-Host
    Write-Host 'Left in place. Move closed cases to the case store, then delete them here. This folder syncs to OneDrive when the repo lives there.'
} else { Write-Host 'No investigations folder.' }

if ($RemoveUrlAcl -and $IsWindows) {
    Step "URL reservation (port $Port)"
    netsh http delete urlacl url=http://+:$Port/
}
Write-Host "`nTeardown done."
