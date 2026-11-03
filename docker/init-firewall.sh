#!/usr/bin/env bash
# Locks this container's outbound network access down to the Microsoft
# endpoints XDRInternals actually calls: Defender XDR, Entra ID sign-in,
# Microsoft Graph, Azure Resource Manager, Key Vault (passkey auth), the
# My Sign-Ins API (Temporary Access Pass), Azure Data Explorer/Kusto
# (Export-XdrAzureDataExplorer / Invoke-XdrAzureDataExplorerQuery), and
# Azure Monitor's Log Analytics ingestion (Export-XdrToSentinel), and the Log Analytics
# query endpoint (api.loganalytics.io) for enumerating Sentinel workspace footprint.
#
# Several of those are tenant-specific subdomains that don't exist until
# a customer configures them (a Key Vault name, an ADX cluster, a Sentinel
# workspace ID), so a static IP allowlist can't cover them. Instead this
# runs a local dnsmasq that recognizes the allowed domains *and any of
# their subdomains* and adds whatever IP they resolve to into an ipset in
# real time; iptables then only allows outbound HTTPS/HTTP to that ipset.
#
# Requires: --cap-add=NET_ADMIN --cap-add=NET_RAW at `docker run` time.
# Extend the allowlist without editing this file via XDR_ALLOWED_DOMAINS
# (space-separated domains/subdomains, e.g. a private DNS zone).

set -euo pipefail

SET_NAME="xdr-allowed"
UPSTREAM_DNS=(1.1.1.1 8.8.8.8)

# Apex domains. dnsmasq's ipset= directive matches the domain itself and
# every subdomain, which is exactly what's needed for things like
# mto.security.microsoft.com, <cluster>.<region>.kusto.windows.net,
# ingest-<cluster>.<region>.kusto.windows.net, <vault>.vault.azure.net,
# and <workspaceId>.ods.opinsights.azure.com.
ALLOWED_DOMAINS=(
    security.microsoft.com
    login.microsoftonline.com
    login.microsoft.com
    graph.microsoft.com
    management.azure.com
    management.core.windows.net
    vault.azure.net
    mysignins.microsoft.com
    kusto.windows.net
    ods.opinsights.azure.com
    api.loganalytics.io
    api.loganalytics.azure.com
)

# Claude Code ships in this image (see Dockerfile), so it needs Anthropic's
# endpoints too. Set XDR_ALLOW_CLAUDE_CODE=0 to fall back to the Microsoft-only
# allowlist above - the CLI then cannot reach the API and will not start a session.
# The subdomain matching noted above does the heavy lifting here: claude.ai also
# covers downloads.claude.ai, and claude.com covers both platform.claude.com
# (OAuth token exchange and refresh) and code.claude.com (documentation lookups).
if [ "${XDR_ALLOW_CLAUDE_CODE:-1}" != "0" ]; then
    ALLOWED_DOMAINS+=(
        api.anthropic.com   # model requests, feature flags, WebFetch safety check
        claude.ai           # claude.ai sign-in; + downloads.claude.ai for plugins
        claude.com          # sign-in redirect, platform.claude.com, code.claude.com
        registry.npmjs.org  # plugin installs and npx-launched MCP servers
    )
fi

# Deliberately absent: the two Datadog intake hosts Claude Code uses for optional
# operational telemetry and error reports. Those requests are fire-and-forget, so
# letting them hit the default-DROP rule costs nothing functionally. Set
# DISABLE_TELEMETRY=1 (see docker-compose.yml) to stop them being attempted,
# bearing in mind it also turns off feature-flag fetching.

# Attaching VS Code (Dev Containers) makes the container download the VS Code
# Server into itself, which the default-deny rule above would otherwise drop -
# the attach then hangs on "Installing server" rather than failing cleanly.
# Off by default so the plain `docker compose run` path keeps the tighter
# allowlist; .devcontainer/docker-compose.devcontainer.yml turns it on, so this
# widening applies only while you are actually attached with VS Code.
if [ "${XDR_ALLOW_VSCODE:-0}" != "0" ]; then
    ALLOWED_DOMAINS+=(
        update.code.visualstudio.com        # server build lookup
        vscode.download.prss.microsoft.com  # server download CDN
        download.visualstudio.microsoft.com # dependencies for some extensions
        marketplace.visualstudio.com        # installing extensions in-container
        vsassets.io                         # + *.gallery / *.gallerycdn marketplace assets
        vscode-cdn.net                      # *.vscode-cdn.net
    )
fi

if [ -n "${XDR_ALLOWED_DOMAINS:-}" ]; then
    # shellcheck disable=SC2206
    ALLOWED_DOMAINS+=(${XDR_ALLOWED_DOMAINS})
fi

echo "[init-firewall] allowing: ${ALLOWED_DOMAINS[*]} (+ subdomains), and Azure IMDS 169.254.169.254"

# --- ipset the allowlisted IPs land in, filled dynamically by dnsmasq ---
ipset destroy "$SET_NAME" 2>/dev/null || true
ipset create "$SET_NAME" hash:ip
# Azure Instance Metadata Service: only reachable when this container
# actually runs on Azure infrastructure with a managed identity attached
# (Get-XdrAzureAccessToken's managed-identity path); harmless elsewhere.
ipset add "$SET_NAME" 169.254.169.254

# --- local resolver: DNS-triggered ipset population ---
mkdir -p /etc/dnsmasq.d
{
    echo "no-resolv"
    for ns in "${UPSTREAM_DNS[@]}"; do
        echo "server=${ns}"
    done
    echo "listen-address=127.0.0.1"
    echo "bind-interfaces"
    echo "cache-size=1000"
    for domain in "${ALLOWED_DOMAINS[@]}"; do
        echo "ipset=/${domain}/${SET_NAME}"
    done
} > /etc/dnsmasq.d/xdr-allowlist.conf

pkill -x dnsmasq 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.d/xdr-allowlist.conf --pid-file=/run/dnsmasq.pid

# Route this container's own DNS lookups through the local resolver above.
echo "nameserver 127.0.0.1" > /etc/resolv.conf

# --- iptables: default-deny egress, carve out DNS + the allowlist ---
iptables -F OUTPUT
iptables -P OUTPUT DROP

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

for ns in "${UPSTREAM_DNS[@]}"; do
    iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
done

iptables -A OUTPUT -m set --match-set "$SET_NAME" dst -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -m set --match-set "$SET_NAME" dst -p tcp --dport 80 -j ACCEPT

# No IPv6 egress at all - it would otherwise bypass the IPv4-only allowlist above.
if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -F OUTPUT 2>/dev/null || true
    ip6tables -P OUTPUT DROP 2>/dev/null || true
fi

echo "[init-firewall] egress lockdown active"
