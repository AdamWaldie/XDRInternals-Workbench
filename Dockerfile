# XDRInternals is a pure PowerShell module (no compiled dependencies) for
# interacting with the Microsoft Defender XDR portal API. This image gives
# it a self-contained PowerShell 7 environment with the module pre-loaded
# and the repo's Pester test suite ready to run.
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

# iptables/ipset/dnsmasq: build the runtime egress allowlist (see
# docker/init-firewall.sh) that restricts this container to only the
# Microsoft endpoints XDRInternals talks to.
RUN apt-get update && apt-get install -y --no-install-recommends \
        iptables \
        ipset \
        dnsmasq \
        dnsutils \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Test/lint tooling used by tests/pester.ps1 and tests/pester.live.ps1.
RUN pwsh -NoLogo -NonInteractive -Command \
    "Install-Module Pester -MinimumVersion 5.5.0 -Force -SkipPublisherCheck -Scope AllUsers; \
     Install-Module PSScriptAnalyzer -Force -SkipPublisherCheck -Scope AllUsers"

# Azure CLI - for enumerating Sentinel / Log Analytics workspaces and tables over ARM
# (control plane, no query cost), used for customers who log to Sentinel rather than
# Defender. Installed from Microsoft's apt repo. The resource-graph extension is baked in
# at build time because the runtime egress firewall blocks the blob store it downloads from.
RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg lsb-release \
    && mkdir -p /etc/apt/keyrings \
    && curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && chmod go+r /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends azure-cli \
    && az extension add --name resource-graph --system --only-show-errors \
    && az extension add --name log-analytics --system --only-show-errors \
    && rm -rf /var/lib/apt/lists/*

# Azure CLI otherwise reaches telemetry endpoints the runtime firewall drops, which just
# adds latency; turn it off.
ENV AZURE_CORE_COLLECT_TELEMETRY=0

# Claude Code, so an agent can drive the module and its Pester suite from inside
# the egress-locked container instead of from the host. git comes along for the
# diff/history features it leans on. Node is just its runtime; it is installed
# from NodeSource's "nodistro" repo, which tracks the latest 22.x LTS, so there
# is no patch version pinned here to go stale.
#
# Deliberately a *system-wide* npm install (/usr/bin/claude): docker-compose
# persists /root on a named volume, which would shadow the per-user layout the
# native installer uses (~/.local/bin).
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && curl -sLS https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && chmod go+r /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# The CLI version is pinned by the image, so `docker compose build` is what
# upgrades it. Without this the background updater would re-download an update
# into /usr/local on every `docker compose run --rm`, since that path is not on
# the persisted volume. `claude update` still works if you want it in-session.
ENV DISABLE_AUTOUPDATER=1

WORKDIR /workspace
COPY . .

# Install the module itself so `Import-Module XDRInternals` works without a
# full path, from any working directory.
RUN cp -r ./XDRInternals /usr/local/share/powershell/Modules/XDRInternals

RUN cp docker/init-firewall.sh /usr/local/sbin/init-firewall.sh \
    && cp docker/entrypoint.sh /usr/local/sbin/entrypoint.sh \
    && chmod 750 /usr/local/sbin/init-firewall.sh /usr/local/sbin/entrypoint.sh

ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
CMD ["pwsh", "-NoExit", "-Command", "Import-Module XDRInternals; Write-Host 'XDRInternals module loaded. Use one of the Connect-Xdr* cmdlets to authenticate.'"]
