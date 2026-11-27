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

        The listener is a minimal HTTP server on a plain TCP socket, not HTTP.sys/HttpListener:
        on some Windows machines HTTP.sys accepts the connection but never hands the request to
        a queue owned by a user PowerShell process, so the extension saw nothing listening. On
        the host it binds to 127.0.0.1 only, which needs no URL reservation. Inside a container
        it binds to all interfaces, because Docker delivers published traffic via the bridge
        interface; the "only reachable from this machine" guarantee then comes from publishing
        the port to the host's loopback only, e.g. `-p 127.0.0.1:8787:8787`. Either way it only
        answers requests whose Host is 127.0.0.1, localhost or [::1], so a web page cannot reach
        it through DNS rebinding.

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

        # A plain TCP listener rather than HttpListener: HTTP.sys can accept a connection and then
        # never deliver it to a request queue owned by a user PowerShell process (seen with a
        # third-party firewall), which left the extension reporting "nothing is waiting". On the
        # host bind 127.0.0.1 only. In Docker, `-p 127.0.0.1:<port>:<port>` delivers published
        # traffic to the container's bridge interface, so bind all interfaces there; the
        # "loopback only" guarantee then comes from that `-p` binding on the host side.
        $bindAddress = if ($inContainer) { [System.Net.IPAddress]::Any } else { [System.Net.IPAddress]::Loopback }
        $listener = $null
        $bindErrors = [System.Collections.Generic.List[string]]::new()
        foreach ($candidatePort in $candidatePorts) {
            if ($IsWindows -and (Get-NetTCPConnection -LocalPort $candidatePort -State Listen -ErrorAction SilentlyContinue)) {
                $bindErrors.Add("${candidatePort}: already in use")
                continue
            }
            $attempt = [System.Net.Sockets.TcpListener]::new($bindAddress, $candidatePort)
            if ($IsWindows) { $attempt.ExclusiveAddressUse = $true }
            try {
                $attempt.Start()
                $listener = $attempt
                $Port = $candidatePort
                break
            } catch {
                $bindErrors.Add("${candidatePort}: $($_.Exception.Message)")
                try { $attempt.Stop() } catch { Write-Verbose "Ignoring listener cleanup error: $($_.Exception.Message)" }
            }
        }
        if (-not $listener) {
            $tried = ($candidatePorts | ForEach-Object { "$_" }) -join ', '
            throw ("Failed to listen on port(s) $tried. Another Connect-XdrByBrowserExtension or program holds the port; close it, " +
                "or leave out -Port so the next free port is used. Details: $($bindErrors -join ' | ')")
        }

        $pairingCode = [guid]::NewGuid().ToString('N').Substring(0, 12)
        $expectedAuthHeader = "Bearer $pairingCode"
        $expiresAt = (Get-Date).AddSeconds($TimeoutSeconds)

        $healthUrl = "http://127.0.0.1:$Port/health"
        if ($inContainer) {
            Write-Host "Relay listener bound to 0.0.0.0:$Port inside the container (publish it to the host's loopback only: -p 127.0.0.1:${Port}:$Port)."
        } else {
            Write-Host "Relay listener bound to 127.0.0.1:$Port (loopback only)."
        }
        Write-Host "The extension checks $healthUrl and relays to http://127.0.0.1:$Port/relay. Opening $healthUrl in Chrome should show xdr-workbench-relay."
        Write-Host "Waiting for the XDR Docker Relay browser extension."
        Write-Host "  1. Open the extension's popup in Chrome, in the window signed in to Microsoft Defender XDR."
        Write-Host "  2. Paste this pairing code: $pairingCode"
        Write-Host "  3. Click 'Relay session to container'. Extension 1.3+ finds port $Port by itself; older versions need the port set to $Port."
        Write-Host ("Listening on port {0}. Relay before {1:HH:mm:ss} ({2} seconds); after that, rerun for a new code." -f $Port, $expiresAt, $TimeoutSeconds)

        # Reads one HTTP/1.1 request (request line, headers, Content-Length body) from the stream.
        $readRequest = {
            param([System.IO.Stream]$Stream)
            $buffer = [System.IO.MemoryStream]::new()
            $chunk = [byte[]]::new(8192)
            $headerEnd = -1
            $text = ''
            while ($headerEnd -lt 0) {
                $read = $Stream.Read($chunk, 0, $chunk.Length)
                if ($read -le 0) { return $null }
                $buffer.Write($chunk, 0, $read)
                if ($buffer.Length -gt 32KB) { throw 'Request headers are too large.' }
                # Latin-1 maps each byte to one char, so char offsets are byte offsets.
                $text = [System.Text.Encoding]::GetEncoding(28591).GetString($buffer.GetBuffer(), 0, [int]$buffer.Length)
                $headerEnd = $text.IndexOf("`r`n`r`n")
            }
            $lines = $text.Substring(0, $headerEnd) -split "`r`n"
            $requestLine = $lines[0] -split ' '
            if ($requestLine.Count -lt 3) { throw 'Malformed request line.' }
            $headers = @{}
            foreach ($line in ($lines | Select-Object -Skip 1)) {
                $colon = $line.IndexOf(':')
                if ($colon -gt 0) { $headers[$line.Substring(0, $colon).Trim()] = $line.Substring($colon + 1).Trim() }
            }
            $contentLength = 0
            if ($headers['Content-Length'] -and -not [int]::TryParse($headers['Content-Length'], [ref]$contentLength)) { throw 'Invalid Content-Length.' }
            if ($contentLength -lt 0 -or $contentLength -gt 1MB) { throw 'Request body is too large.' }
            $bodyStart = $headerEnd + 4
            while (($buffer.Length - $bodyStart) -lt $contentLength) {
                $read = $Stream.Read($chunk, 0, $chunk.Length)
                if ($read -le 0) { throw 'Connection closed before the request body arrived.' }
                $buffer.Write($chunk, 0, $read)
            }
            [pscustomobject]@{
                Method  = $requestLine[0].ToUpperInvariant()
                Path    = ($requestLine[1] -split '\?', 2)[0]
                Headers = $headers
                Body    = [System.Text.Encoding]::UTF8.GetString($buffer.GetBuffer(), $bodyStart, $contentLength)
            }
        }

        $reasons = @{ 200 = 'OK'; 204 = 'No Content'; 400 = 'Bad Request'; 401 = 'Unauthorized'; 404 = 'Not Found'; 500 = 'Internal Server Error' }
        $sendResponse = {
            param([System.IO.Stream]$Stream, [int]$Status, [string]$Body, [hashtable]$Extra)
            $bodyBytes = if ($Body) { [System.Text.Encoding]::UTF8.GetBytes($Body) } else { [byte[]]::new(0) }
            $head = [System.Text.StringBuilder]::new()
            [void]$head.Append("HTTP/1.1 $Status $($reasons[$Status])`r`n")
            if ($Body) { [void]$head.Append("Content-Type: application/json`r`n") }
            [void]$head.Append("Content-Length: $($bodyBytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n")
            if ($Extra) { foreach ($k in $Extra.Keys) { [void]$head.Append("${k}: $($Extra[$k])`r`n") } }
            [void]$head.Append("`r`n")
            $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head.ToString())
            $Stream.Write($headBytes, 0, $headBytes.Length)
            if ($bodyBytes.Length) { $Stream.Write($bodyBytes, 0, $bodyBytes.Length) }
            $Stream.Flush()
        }

        $deadline = $expiresAt
        $relayPayload = $null
        $seenByExtension = $false

        # Connections are served one at a time, but only once they have sent data. Chrome opens
        # spare sockets (preconnects, backup connects, localhost tried on ::1 and 127.0.0.1) that
        # may never carry a request. Blocking on one of those starved every real /health probe
        # and the popup reported "No standup is waiting" until a retry happened to slip through.
        $pending = [System.Collections.Generic.List[object]]::new()

        # Diagnostic log of the listener's own events (never the pairing code or cookies), so a
        # listener that stops early can be explained: %TEMP%\xdr-relay-listener.log.
        $logPath = Join-Path ([System.IO.Path]::GetTempPath()) 'xdr-relay-listener.log'
        $log = {
            param([string]$Message)
            try { Add-Content -LiteralPath $logPath -Value ('{0:HH:mm:ss.fff} {1}' -f (Get-Date), $Message) -Encoding utf8 } catch { Write-Verbose "Relay log write failed: $($_.Exception.Message)" }
        }
        try { Set-Content -LiteralPath $logPath -Value "Relay listener log, process $PID" -Encoding utf8 } catch { Write-Verbose "Relay log reset failed: $($_.Exception.Message)" }
        & $log "Listening on $($listener.LocalEndpoint), expires $($expiresAt.ToString('HH:mm:ss'))"
        $lastBeat = Get-Date
        $exitReason = 'stopped from outside the loop (Ctrl+C, window closed, or pipeline stopped)'

        try {
            while ((Get-Date) -lt $deadline) {
                if (((Get-Date) - $lastBeat).TotalSeconds -ge 15) {
                    $lastBeat = Get-Date
                    & $log "alive: bound=$($listener.Server.IsBound) pending=$($pending.Count)"
                }
                # A connection the browser resets or abandons must never end the standup, so socket
                # errors here only drop that one connection.
                try {
                    while ($listener.Pending()) {
                        $accepted = $listener.AcceptTcpClient()
                        & $log "accept from $($accepted.Client.RemoteEndPoint)"
                        $pending.Add([pscustomobject]@{ Client = $accepted; Since = Get-Date })
                    }
                } catch {
                    & $log "accept failed: $($_.Exception.Message)"
                }

                $client = $null
                foreach ($entry in @($pending)) {
                    try {
                        $socket = $entry.Client.Client
                        if ($socket.Available -gt 0) {
                            $client = $entry.Client
                            [void]$pending.Remove($entry)
                            break
                        }
                        $closedByPeer = $socket.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead) -and $socket.Available -eq 0
                    } catch {
                        & $log "socket check failed: $($_.Exception.Message)"
                        $closedByPeer = $true
                    }
                    if ($closedByPeer -or ((Get-Date) - $entry.Since).TotalSeconds -gt 10) {
                        & $log ("drop idle socket ({0})" -f $(if ($closedByPeer) { 'closed by client' } else { 'no request in 10 s' }))
                        [void]$pending.Remove($entry)
                        try { $entry.Client.Close() } catch { Write-Verbose "Ignoring idle socket cleanup error: $($_.Exception.Message)" }
                    }
                }
                if (-not $client) {
                    # Short sleep so Ctrl+C still stops the standup and the loop stays cheap.
                    Start-Sleep -Milliseconds 20
                    continue
                }

                $stream = $null
                try {
                    # The request has started arriving; the rest follows within milliseconds.
                    $client.ReceiveTimeout = 3000
                    $client.SendTimeout = 5000
                    $stream = $client.GetStream()
                    try {
                        $request = & $readRequest $stream
                    } catch {
                        & $log "malformed request: $($_.Exception.Message)"
                        & $sendResponse $stream 400
                        continue
                    }
                    if (-not $request) { & $log 'connection closed without a request'; continue }
                    & $log "request $($request.Method) $($request.Path) host=$($request.Headers['Host']) extension=$([bool]($request.Headers['Origin'] -match '-extension://'))"

                    # Only loopback host names: a web page that rebinds its own DNS name to
                    # 127.0.0.1 would send its own name here.
                    $hostName = ($request.Headers['Host'] -replace ':\d+$', '').ToLowerInvariant()
                    if ($hostName -notin @('127.0.0.1', 'localhost', '[::1]')) {
                        Write-Verbose "Rejected a request for host '$($request.Headers['Host'])'."
                        & $sendResponse $stream 400
                        continue
                    }

                    # Extension 1.3+ fetches with host permissions and needs no CORS; older
                    # versions go through CORS. Allow only extension origins, never web pages.
                    $cors = @{}
                    $origin = $request.Headers['Origin']
                    if ($origin -and $origin -match '^(chrome|moz|ms-browser)-extension://[A-Za-z0-9-]+$') {
                        $cors['Access-Control-Allow-Origin'] = $origin
                        $cors['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
                        $cors['Access-Control-Allow-Headers'] = 'Authorization, Content-Type'
                        $cors['Access-Control-Allow-Private-Network'] = 'true'
                        $cors['Vary'] = 'Origin'
                    }

                    if ($request.Method -eq 'OPTIONS') {
                        & $sendResponse $stream 204 $null $cors
                        continue
                    }

                    # Unauthenticated liveness probe for the extension, so it can find the
                    # listener's port and say "nothing is listening" instead of "Failed to fetch".
                    # Reveals nothing but that a relay is waiting and until when.
                    if ($request.Method -eq 'GET' -and $request.Path -eq '/health') {
                        $health = [ordered]@{
                            service     = 'xdr-workbench-relay'
                            version     = 2
                            port        = $Port
                            expiresUtc  = $expiresAt.ToUniversalTime().ToString('o')
                            secondsLeft = [int][Math]::Max(0, ($expiresAt - (Get-Date)).TotalSeconds)
                        } | ConvertTo-Json -Compress
                        & $sendResponse $stream 200 $health $cors
                        if (-not $seenByExtension -and $origin -match '-extension://') {
                            $seenByExtension = $true
                            Write-Host "The extension can see this standup (it reached $healthUrl)."
                        }
                        continue
                    }

                    if ($request.Method -ne 'POST' -or $request.Path -ne '/relay') {
                        & $sendResponse $stream 404 $null $cors
                        continue
                    }

                    if ($request.Headers['Authorization'] -cne $expectedAuthHeader) {
                        Write-Host "Rejected a relay with the wrong pairing code. Paste the code shown above." -ForegroundColor Yellow
                        & $sendResponse $stream 401 $null $cors
                        continue
                    }

                    $payload = $request.Body | ConvertFrom-Json -ErrorAction Stop
                    if (-not $payload.sccAuthCookieValue -and -not $payload.estsAuthCookieValue) {
                        & $sendResponse $stream 400 $null $cors
                        continue
                    }

                    $relayPayload = $payload
                    & $sendResponse $stream 200 '{"status":"ok"}' $cors
                } catch {
                    & $log "request handling failed: $($_.Exception.Message)"
                    try { if ($stream) { & $sendResponse $stream 500 } } catch { Write-Verbose "Could not send the error response: $($_.Exception.Message)" }
                } finally {
                    $client.Close()
                }

                if ($relayPayload) { break }
            }
            $exitReason = if ($relayPayload) { 'relay received' } else { 'deadline reached' }
        } catch {
            $exitReason = "error: $($_.Exception.GetType().Name): $($_.Exception.Message) at $($_.InvocationInfo.ScriptLineNumber)"
            throw
        } finally {
            # Also reached on Ctrl+C or when the window closes, which no catch block sees.
            & $log "listener stopping: $exitReason"
            foreach ($entry in $pending) { try { $entry.Client.Close() } catch { Write-Verbose "Ignoring socket cleanup error: $($_.Exception.Message)" } }
            $listener.Stop()
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
