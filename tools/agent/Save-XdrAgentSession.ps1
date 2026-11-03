<#
    .SYNOPSIS
        Hands the current XDRInternals session to Claude's agent wrapper.

    .DESCRIPTION
        Every call Claude makes through Invoke-XdrAgent.ps1 runs in a fresh PowerShell
        process, so it can't see the session you created interactively. Run this script in
        the PowerShell session where you ran a Connect-Xdr* cmdlet. It saves the portal
        session cookie (sccauth), the XSRF token and the tenant identity to a file that only
        your user can read. Invoke-XdrAgent.ps1 restores the session from that file on
        each call.

        The file holds a live portal session token. Remove it with -Clear when you finish.

    .PARAMETER Path
        Where to write the session file. Defaults to ~/.xdr-agent/session.json.

    .PARAMETER InRepo
        Saves to <repo>/.xdr-agent/session.json instead (git- and docker-ignored). Use this
        when Claude runs in Cowork with access to this folder, because Cowork can't see your
        home directory. Takes priority over ~/.xdr-agent when present.

    .PARAMETER Clear
        Deletes the saved session file instead of writing one. Combine with -InRepo to clear
        the in-repo copy.

    .EXAMPLE
        Connect-XdrByBrowserExtension
        ./tools/agent/Save-XdrAgentSession.ps1

    .EXAMPLE
        ./tools/agent/Save-XdrAgentSession.ps1 -Clear
#>
[CmdletBinding()]
param (
    [string]$Path = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.xdr-agent/session.json'),

    [switch]$InRepo,

    [switch]$Clear
)

$ErrorActionPreference = 'Stop'

if ($InRepo) {
    $Path = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path '.xdr-agent/session.json'
}

if ($Clear) {
    if (Test-Path -LiteralPath $Path) {
        try {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            Write-Host "Removed saved agent session: $Path"
        } catch {
            # Some shells (such as Claude's sandbox over a mounted folder) can write but not delete.
            Set-Content -LiteralPath $Path -Value '{}' -Encoding utf8
            Write-Host "Cleared saved agent session (file emptied, not deleted): $Path"
        }
    } else {
        Write-Host "No saved agent session at $Path"
    }
    return
}

# The file holds a live portal token. Refuse any location git would track.
. (Join-Path $PSScriptRoot 'XdrWorkbench.Common.ps1')
if ((Test-XdrPathGitIgnored -Path $Path) -eq $false) {
    throw "Refusing to save the session to $Path because git would track it. Add its folder to .gitignore, or save with -InRepo (<repo>/.xdr-agent is ignored) or to the default ~/.xdr-agent."
}

$module = Get-Module XDRInternals
if (-not $module) {
    throw "XDRInternals isn't loaded in this session. Connect with a Connect-Xdr* cmdlet first, then run this script in the same session."
}

$session = & $module { $script:session }
if (-not $session) {
    throw "No XDR session found. Connect with a Connect-Xdr* cmdlet first."
}

$cookies = $session.Cookies.GetCookies('https://security.microsoft.com')
$sccAuth = $cookies['sccauth'].Value
$xsrf = $cookies['xsrf-token'].Value
if (-not $sccAuth) {
    throw "The current session has no sccauth cookie, so it can't be handed off. Reconnect and try again."
}

# Forced fetch so the saved identity reflects the live session, not a cached tenant.
$tenantContext = Get-XdrTenantContext -Force
$record = [ordered]@{
    SccAuth    = $sccAuth
    Xsrf       = $xsrf
    TenantId   = $tenantContext.AuthInfo.TenantId
    TenantName = $tenantContext.AuthInfo.TenantName
    Account    = $tenantContext.AuthInfo.UserName
    SavedAt    = (Get-Date).ToUniversalTime().ToString('o')
}

$directory = Split-Path -Parent $Path
if (-not (Test-Path -LiteralPath $directory)) {
    $null = New-Item -ItemType Directory -Path $directory -Force
}

# Create the file empty and lock it down before the token is written to it.
Set-Content -LiteralPath $Path -Value '' -Encoding utf8
if ($IsLinux -or $IsMacOS) {
    chmod 700 $directory
    chmod 600 $Path
} else {
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) { $null = $acl.RemoveAccessRule($rule) }
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'Allow')))
    Set-Acl -LiteralPath $Path -AclObject $acl
}
$record | ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding utf8

Write-Host "Saved agent session for Claude:"
Write-Host "  Tenant:    $($record.TenantName)"
Write-Host "  Account:   $($record.Account)"
Write-Host "  Tenant ID: $($record.TenantId)"
Write-Host "  File:      $Path"
Write-Host "Run this script with -Clear when the investigation is done."
