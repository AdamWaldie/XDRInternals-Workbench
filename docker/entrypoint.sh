#!/usr/bin/env bash
set -euo pipefail

if [ "${XDR_DISABLE_FIREWALL:-0}" = "1" ]; then
    echo "[entrypoint] XDR_DISABLE_FIREWALL=1 set, skipping egress lockdown" >&2
else
    # Fails closed: if the firewall can't be established (e.g. missing
    # --cap-add=NET_ADMIN/NET_RAW), refuse to start rather than run this
    # security tooling with unrestricted network access.
    /usr/local/sbin/init-firewall.sh
fi

exec "$@"
