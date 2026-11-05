function Initialize-XdrMtoSession {
    <#
    .SYNOPSIS
        Holds the multi-tenant portal (mto.security.microsoft.com) session apart from the main one.

    .DESCRIPTION
        The MTO portal keeps its own sign-in. A relay that carries only the security.microsoft.com
        cookies can be valid for every single-tenant call while the MTO hunting endpoint answers
        "440 Session timeout". When the relay also carries the MTO portal's sccauth (and
        XSRF-TOKEN), this stores them in a separate web session that Invoke-XdrMtoAdvancedHunting
        uses first. Called with no SccAuth, it clears that session.

    .PARAMETER SccAuth
        The sccauth cookie value from mto.security.microsoft.com.

    .PARAMETER Xsrf
        The XSRF-TOKEN cookie value from mto.security.microsoft.com.

    .EXAMPLE
        Initialize-XdrMtoSession -SccAuth $relayPayload.mtoSccAuthCookieValue -Xsrf $relayPayload.mtoXsrfToken
        Stores the multi-tenant portal session the relay extension sent.

    .EXAMPLE
        Initialize-XdrMtoSession
        Clears it, so MTO hunting uses the main portal session.
    #>
    [CmdletBinding()]
    param (
        [string]$SccAuth,
        [string]$Xsrf
    )

    if ([string]::IsNullOrWhiteSpace($SccAuth)) {
        $script:mtoSession = $null
        $script:mtoXsrf = $null
        Write-Verbose 'No MTO portal session supplied; MTO hunting uses the main portal session.'
        return
    }

    $mtoHost = 'mto.security.microsoft.com'
    $script:mtoSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $script:mtoSession.Cookies.Add((New-Object System.Net.Cookie('sccauth', $SccAuth, '/', $mtoHost)))
    $script:mtoXsrf = $null
    if (-not [string]::IsNullOrWhiteSpace($Xsrf)) {
        $script:mtoSession.Cookies.Add((New-Object System.Net.Cookie('XSRF-TOKEN', $Xsrf, '/', $mtoHost)))
        $script:mtoXsrf = [System.Net.WebUtility]::UrlDecode($Xsrf)
    }
    Write-Verbose 'MTO portal session set; MTO hunting tries it before the main portal session.'
}
