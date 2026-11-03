#!/usr/bin/env bash
# Prepares a Linux or macOS environment (e.g. a Claude Cowork VM that was given this folder)
# to run XDRInternals through tools/agent/Invoke-XdrAgent.ps1, then reports what's missing.
#
# - Uses pwsh if it's already installed; otherwise installs PowerShell 7 for this user only,
#   from Microsoft's official GitHub release, into ~/.local/powershell.
# - Checks that the module loads, that a saved session exists, and that the Defender portal
#   is reachable.
#
# It never signs in. The user signs in on a machine with a browser and saves the session with
# tools/agent/Save-XdrAgentSession.ps1 -InRepo, which puts it in this folder.
set -euo pipefail

PWSH_VERSION="7.4.6"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

find_pwsh() {
  if command -v pwsh >/dev/null 2>&1; then command -v pwsh; return; fi
  if [ -x "$HOME/.local/powershell/pwsh" ]; then echo "$HOME/.local/powershell/pwsh"; return; fi
  return 1
}

if pwsh_path="$(find_pwsh)"; then
  echo "pwsh: $pwsh_path"
else
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) asset="linux-x64" ;;
    Linux-aarch64 | Linux-arm64) asset="linux-arm64" ;;
    Darwin-x86_64) asset="osx-x64" ;;
    Darwin-arm64) asset="osx-arm64" ;;
    *) echo "Unsupported platform $(uname -s)-$(uname -m); install PowerShell 7 manually." >&2; exit 1 ;;
  esac
  url="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-${asset}.tar.gz"
  echo "Installing PowerShell ${PWSH_VERSION} for this user from ${url}"
  mkdir -p "$HOME/.local/powershell" "$HOME/.local/bin"
  curl -fsSL "$url" | tar -xz -C "$HOME/.local/powershell"
  chmod +x "$HOME/.local/powershell/pwsh"
  ln -sf "$HOME/.local/powershell/pwsh" "$HOME/.local/bin/pwsh"
  pwsh_path="$HOME/.local/powershell/pwsh"
  echo "pwsh: $pwsh_path (add ~/.local/bin to PATH, or call it by full path)"
fi

echo
echo "Module check:"
"$pwsh_path" -NoProfile -Command "Import-Module '$repo_root/XDRInternals/XDRInternals.psd1' -WarningAction SilentlyContinue; 'XDRInternals loaded: ' + (Get-Command -Module XDRInternals).Count + ' cmdlets'"

echo
if [ -n "${XDR_SESSION_PATH:-}" ] && [ -f "$XDR_SESSION_PATH" ]; then
  echo "Session: $XDR_SESSION_PATH"
elif [ -f "$repo_root/.xdr-agent/session.json" ]; then
  echo "Session: $repo_root/.xdr-agent/session.json"
elif [ -f "$HOME/.xdr-agent/session.json" ]; then
  echo "Session: $HOME/.xdr-agent/session.json"
else
  echo "Session: none. The user must sign in (PowerShell 7 with a browser) and run"
  echo "  ./tools/agent/Save-XdrAgentSession.ps1 -InRepo"
  echo "in this folder."
fi

echo
if curl -s -o /dev/null --max-time 10 https://security.microsoft.com; then
  echo "Network: security.microsoft.com is reachable."
else
  echo "Network: security.microsoft.com is NOT reachable from here. Queries will fail until this"
  echo "environment is allowed to reach it (check the sandbox's network settings)."
fi

echo
echo "Run commands with:"
echo "  $pwsh_path -NoProfile -File $repo_root/tools/agent/Invoke-XdrAgent.ps1 -Command \"Get-XdrTenantContext -Force\""
