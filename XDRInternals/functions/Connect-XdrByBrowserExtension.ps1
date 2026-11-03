function Connect-XdrByBrowserExtension {
    <#
    .SYNOPSIS
        Authenticates to Microsoft Defender XDR by relaying a session from the XDR Docker Relay browser extension.

    .DESCRIPTION
        Starts a short-lived HTTP listener and waits for the XDR Docker Relay Chrome
        extension (docker/browser-extension in this repo) to POST the browser's Defender
        session artifacts to it, then establishes the Defender XDR session from them.

        The extension sends whichever it can read: the Defender portal session cookie
        (sccauth, plus XSRF-TOKEN) from security.microsoft.com and/or the ESTSAUTH cookie
        from login.microsoftonline.com. These are routed through the module's shared
        Connect-XdrAuthArtifactSet handler, which prefers the portal session cookie - that
        one is replayed directly and avoids Entra's silent SSO re-exchange (and the
        "session information is not sufficient for single-sign-on" / 50058 failure it often
        raises) - and falls back to the ESTS bootstrap when only that cookie is available.

        On success it prints the connected tenant (organization name, signed-in account, and
        tenant ID) so switch-heavy workflows, such as an MSSP moving between customer
        tenants, can confirm the intended tenant before running further cmdlets.

        This exists so a locked-down container (for example one whose outbound network is
        restricted to Defender XDR/Entra ID endpoints, as with this repo's Dockerfile) never
        has to perform the interactive sign-in itself. The sign-in happens in your normal,
        already-authenticated Chrome profile on the host; only the resulting session cookie
        crosses into the container.

        Each call generates a random one-time pairing code that must be entered in the
        extension's popup. The listener accepts exactly one correctly-paired request and then
        stops, so a leaked or reused code has a single, short window in which it is valid.

        The listener itself binds to all interfaces inside the container; the "only reachable
        from this machine" guarantee comes from publishing the port to the host's loopback
        interface only when starting the container, e.g. `-p 127.0.0.1:8787:8787` (a bind
        address of 127.0.0.1 inside the container would not receive Docker's published
        traffic, which arrives via the container's bridge interface).

    .PARAMETER Port
        The port to listen on. Must match the port configured in the browser extension's
        popup and the port published by `docker run`/`docker compose`.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the browser extension to relay a session.

    .PARAMETER TenantId
        Optional tenant ID to use when bootstrapping the Defender XDR session.

    .PARAMETER UserAgent
        The User-Agent string to use for the web requests. This only matters on the ESTS
        bootstrap fallback path, where Entra can tie session validity to the browser
        fingerprint that issued the cookie. By default, uses whatever navigator.userAgent
        the relayed browser sent, falling back to Get-XdrDefaultUserAgent if the extension
        didn't send one. Pass this explicitly to override either.

    .EXAMPLE
        Connect-XdrByBrowserExtension

        Listens on 127.0.0.1:8787, prints a pairing code, and waits up to 5 minutes for the
        XDR Docker Relay extension to relay a session.

    .EXAMPLE
        Connect-XdrByBrowserExtension -Port 9191 -TimeoutSeconds 120

        Listens on a non-default port with a shorter timeout.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    param(
        [ValidateRange(1024, 65535)]
        [int]$Port = 8787,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 300,

        [string]$TenantId,

        [string]$UserAgent
    )

    process {
        # Binds to all interfaces inside the container rather than literally 127.0.0.1: when
        # this runs in Docker, `-p 127.0.0.1:<port>:<port>` delivers published traffic to the
        # container's bridge interface, not its loopback, so a listener bound only to 127.0.0.1
        # would never see it. The actual "loopback only" guarantee comes from that `-p` binding
        # on the host side, not from the bind address in here.
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add("http://+:$Port/")

        try {
            $listener.Start()
        } catch {
            throw "Failed to listen on port $Port. Is another Connect-XdrByBrowserExtension already running, or is the port already in use? $($_.Exception.Message)"
        }

        $pairingCode = [guid]::NewGuid().ToString('N').Substring(0, 12)
        $expectedAuthHeader = "Bearer $pairingCode"

        Write-Host "Waiting for the XDR Docker Relay browser extension."
        Write-Host "  1. Open the extension's popup in Chrome (make sure you're signed into Microsoft Defender XDR there)."
        Write-Host "  2. Paste this pairing code: $pairingCode"
        Write-Host "  3. Set the port to $Port if it isn't already, then click 'Relay session to container'."
        Write-Host "Listening on port $Port. Timeout in $TimeoutSeconds seconds."

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $relayPayload = $null

        try {
            while ((Get-Date) -lt $deadline) {
                $asyncResult = $listener.BeginGetContext($null, $null)
                $remainingMs = [Math]::Max(500, ($deadline - (Get-Date)).TotalMilliseconds)

                if (-not $asyncResult.AsyncWaitHandle.WaitOne([int]$remainingMs)) {
                    break
                }

                $context = $listener.EndGetContext($asyncResult)
                $request = $context.Request
                $response = $context.Response

                try {
                    if ($request.HttpMethod -eq 'OPTIONS') {
                        $response.StatusCode = 204
                        continue
                    }

                    if ($request.HttpMethod -ne 'POST' -or $request.Url.AbsolutePath -ne '/relay') {
                        $response.StatusCode = 404
                        continue
                    }

                    if ($request.Headers['Authorization'] -ne $expectedAuthHeader) {
                        Write-Verbose "Rejected relay attempt with an invalid or missing pairing code."
                        $response.StatusCode = 401
                        continue
                    }

                    $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
                    try {
                        $body = $reader.ReadToEnd()
                    } finally {
                        $reader.Close()
                    }

                    $payload = $body | ConvertFrom-Json -ErrorAction Stop
                    if (-not $payload.sccAuthCookieValue -and -not $payload.estsAuthCookieValue) {
                        $response.StatusCode = 400
                        continue
                    }

                    $relayPayload = $payload

                    $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
                    $response.ContentType = 'application/json'
                    $response.ContentLength64 = $responseBytes.Length
                    $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
                } catch {
                    Write-Verbose "Error handling relay request: $($_.Exception.Message)"
                    $response.StatusCode = 500
                } finally {
                    $response.Close()
                }

                if ($relayPayload) { break }
            }
        } finally {
            $listener.Stop()
            $listener.Close()
        }

        if (-not $relayPayload) {
            throw "Timed out after $TimeoutSeconds seconds waiting for the browser extension to relay a session."
        }

        $sccAuthCookieValue = if ($relayPayload.sccAuthCookieValue) { [string]$relayPayload.sccAuthCookieValue } else { $null }
        $xsrfToken = if ($relayPayload.xsrfToken) { [string]$relayPayload.xsrfToken } else { $null }
        $estsAuthCookieValue = if ($relayPayload.estsAuthCookieValue) { [string]$relayPayload.estsAuthCookieValue } else { $null }

        if ($PSBoundParameters.ContainsKey('UserAgent')) {
            $effectiveUserAgent = $UserAgent
        } elseif ($relayPayload.userAgent) {
            Write-Verbose "Using the User-Agent relayed from the browser: $($relayPayload.userAgent)"
            $effectiveUserAgent = [string]$relayPayload.userAgent
        } else {
            $effectiveUserAgent = Get-XdrDefaultUserAgent
        }

        if ($sccAuthCookieValue) {
            Write-Host "Defender portal session received from browser extension. Establishing session."
        } else {
            Write-Host "Entra sign-in cookie received from browser extension (no portal cookie); attempting ESTS bootstrap."
        }

        # Route through the module's shared artifact handler: it prefers the direct portal
        # session cookie (sccauth), which avoids Entra's silent SSO re-exchange and the
        # "session information is not sufficient for single-sign-on" (50058) failure, and
        # falls back to the ESTS bootstrap when only that cookie is available.
        $connectResult = Connect-XdrAuthArtifactSet `
            -EstsAuthCookieValue $estsAuthCookieValue `
            -SccAuthCookieValue $sccAuthCookieValue `
            -XsrfToken $xsrfToken `
            -TenantId $TenantId `
            -UserAgent $effectiveUserAgent `
            -ConnectionPreference PreferPortal `
            -FailureLabel 'Browser extension relay'

        # Surface the tenant this session actually landed on, so switch-heavy workflows
        # (e.g. an MSSP moving between customers) can confirm the intended tenant before
        # acting. Forced fetch so it reflects the live session rather than any cache.
        try {
            $tenantContext = Get-XdrTenantContext -Force
            $connectedTenantName = $tenantContext.AuthInfo.TenantName
            $connectedTenantId = $tenantContext.AuthInfo.TenantId
            $connectedAccount = $tenantContext.AuthInfo.UserName

            Write-Host "Connected tenant context:"
            if ($connectedTenantName) {
                Write-Host "  Tenant:    $connectedTenantName"
            }
            if ($connectedAccount) {
                Write-Host "  Account:   $connectedAccount"
            }
            if ($connectedTenantId) {
                Write-Host "  Tenant ID: $connectedTenantId"
            }
            Write-Host "Confirm this is the intended tenant before running further cmdlets."
        } catch {
            Write-Warning "Connected, but could not read the tenant context to confirm the active tenant: $($_.Exception.Message)"
        }

        return $connectResult
    }
}
