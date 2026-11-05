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
        The port to listen on. When omitted, the first free port from 8787 to 8796 is used, and
        extension 1.3+ finds it on its own. Inside a container only 8787 is tried, because that
        is the port `docker compose` publishes. When given, only that port is used; it must then
        match the port published by `docker run`/`docker compose`.

    .PARAMETER AllowCloudSession
        Start the listener even inside a Claude Code cloud session. The extension can only reach
        127.0.0.1 on the analyst's own machine, so a listener in a cloud container never receives
        the relay; without this switch the cmdlet refuses to start there.

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

        Listens on the first free port from 8787, prints a pairing code, and waits up to 5
        minutes for the XDR Docker Relay extension to relay a session.

    .EXAMPLE
        Connect-XdrByBrowserExtension -Port 9191 -TimeoutSeconds 120

        Listens on a non-default port with a shorter timeout.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    param(
        [ValidateRange(1024, 65535)]
        [int]$Port = 8787,

        [switch]$AllowCloudSession,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 300,

        [string]$TenantId,

        [string]$UserAgent
    )

    process {
        # The extension posts to 127.0.0.1 on the analyst's own machine. In a Claude Code cloud
        # session this process runs in a remote container, so the relay could never arrive here;
        # refuse up front rather than print a pairing code that ends in "Failed to fetch".
        if ($env:CLAUDE_CODE_REMOTE -eq 'true' -and -not $AllowCloudSession) {
            throw ("This is a Claude Code cloud session. The browser extension relays to 127.0.0.1 on your own computer, " +
                "so a listener here would never receive it. Run tools/agent/Start-XdrWorkbench.ps1 in PowerShell 7 on " +
                "the computer with Chrome, and use Claude Code on that computer (or connect its repo folder to this " +
                "session through Remote Control).")
        }

        $inContainer = (Test-Path '/.dockerenv') -or (Test-Path '/run/.containerenv')
        $candidatePorts = if ($PSBoundParameters.ContainsKey('Port') -or $inContainer) { @($Port) } else { 8787..8796 }

        # Binds to all interfaces ("+") first. In Docker, `-p 127.0.0.1:<port>:<port>` delivers
        # published traffic to the container's bridge interface, not its loopback, so a listener
        # bound only to 127.0.0.1 would never see it; the "loopback only" guarantee comes from that
        # `-p` binding on the host side. On Windows, "+" needs an HTTP.sys URL reservation
        # (netsh http add urlacl); without one, fall back to "localhost", which HTTP.sys lets any
        # user register and which still only answers local requests. Extension 1.3+ tries both
        # 127.0.0.1 and localhost, so either binding is found.
        $listener = $null
        $boundPrefix = $null
        $bindErrors = [System.Collections.Generic.List[string]]::new()
        foreach ($candidatePort in $candidatePorts) {
            $prefixes = @("http://+:$candidatePort/")
            if ($IsWindows -or $null -eq $IsWindows) { $prefixes += "http://localhost:$candidatePort/" }
            foreach ($prefix in $prefixes) {
                $attempt = [System.Net.HttpListener]::new()
                $attempt.Prefixes.Add($prefix)
                try {
                    $attempt.Start()
                    $listener = $attempt
                    $boundPrefix = $prefix
                    $Port = $candidatePort
                    break
                } catch {
                    $bindErrors.Add("${prefix}: $($_.Exception.Message)")
                    try { $attempt.Close() } catch { Write-Verbose "Ignoring listener cleanup error: $($_.Exception.Message)" }
                }
            }
            if ($listener) { break }
        }
        if (-not $listener) {
            $tried = ($candidatePorts | ForEach-Object { "$_" }) -join ', '
            throw ("Failed to listen on port(s) $tried. Another Connect-XdrByBrowserExtension or program may hold the port; close it, " +
                "or on Windows add the URL reservation once from an elevated PowerShell: netsh http add urlacl url=http://+:$($candidatePorts[0])/ " +
                "user=`"$env:USERDOMAIN\$env:USERNAME`". Details: $($bindErrors -join ' | ')")
        }
        Write-Verbose "Relay listener bound to $boundPrefix"

        $pairingCode = [guid]::NewGuid().ToString('N').Substring(0, 12)
        $expectedAuthHeader = "Bearer $pairingCode"
        $expiresAt = (Get-Date).AddSeconds($TimeoutSeconds)

        Write-Host "Waiting for the XDR Docker Relay browser extension."
        Write-Host "  1. Open the extension's popup in Chrome, in the window signed in to Microsoft Defender XDR."
        Write-Host "  2. Paste this pairing code: $pairingCode"
        Write-Host "  3. Click 'Relay session to container'. Extension 1.3+ finds port $Port by itself; older versions need the port set to $Port."
        Write-Host ("Listening on port {0}. Relay before {1:HH:mm:ss} ({2} seconds); after that, rerun for a new code." -f $Port, $expiresAt, $TimeoutSeconds)

        $deadline = $expiresAt
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
                    # Extension 1.3+ fetches with host permissions and needs no CORS; older
                    # versions, or a fetch to "localhost" before the extension is reloaded, go
                    # through CORS. Allow only extension origins, never web pages.
                    $origin = $request.Headers['Origin']
                    if ($origin -and $origin -match '^(chrome|moz|ms-browser)-extension://') {
                        $response.AddHeader('Access-Control-Allow-Origin', $origin)
                        $response.AddHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                        $response.AddHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type')
                        $response.AddHeader('Access-Control-Allow-Private-Network', 'true')
                        $response.AddHeader('Vary', 'Origin')
                    }

                    if ($request.HttpMethod -eq 'OPTIONS') {
                        $response.StatusCode = 204
                        continue
                    }

                    # Unauthenticated liveness probe for the extension, so it can find the
                    # listener's port and say "nothing is listening" instead of "Failed to fetch".
                    # Reveals nothing but that a relay is waiting and until when.
                    if ($request.HttpMethod -eq 'GET' -and $request.Url.AbsolutePath -eq '/health') {
                        $health = [ordered]@{
                            service    = 'xdr-workbench-relay'
                            version    = 2
                            port       = $Port
                            expiresUtc = $expiresAt.ToUniversalTime().ToString('o')
                            secondsLeft = [int][Math]::Max(0, ($expiresAt - (Get-Date)).TotalSeconds)
                        } | ConvertTo-Json -Compress
                        $healthBytes = [System.Text.Encoding]::UTF8.GetBytes($health)
                        $response.ContentType = 'application/json'
                        $response.ContentLength64 = $healthBytes.Length
                        $response.OutputStream.Write($healthBytes, 0, $healthBytes.Length)
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
            throw "Timed out after $TimeoutSeconds seconds waiting for the browser extension to relay a session. The pairing code has expired; run again for a new one."
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

        # The multi-tenant portal keeps its own sign-in; extension 1.2+ relays it when the analyst
        # has mto.security.microsoft.com open in the same window. Without it, MTO hunting may
        # answer "440 Session timeout" while every single-tenant call works.
        $mtoSccAuthCookieValue = if ($relayPayload.mtoSccAuthCookieValue) { [string]$relayPayload.mtoSccAuthCookieValue } else { $null }
        $mtoXsrfToken = if ($relayPayload.mtoXsrfToken) { [string]$relayPayload.mtoXsrfToken } else { $null }
        Initialize-XdrMtoSession -SccAuth $mtoSccAuthCookieValue -Xsrf $mtoXsrfToken
        if ($mtoSccAuthCookieValue) {
            Write-Host "Multi-tenant portal session received as well."
        } else {
            Write-Host "No multi-tenant portal session in the relay (mto.security.microsoft.com not signed in, or extension older than 1.2)."
        }

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
