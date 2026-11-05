# Agent instructions

This repo is the XDRInternals Workbench: a PowerShell module (`XDRInternals/`) and agent tooling (`tools/agent/`) for querying Microsoft Defender XDR through an analyst's own portal session.

For any Defender work (starting or ending a session, hunting, incidents, alerts, devices, users, IOCs), read `.claude/skills/xdrinternals/SKILL.md` first and follow it, with its `reference/` files. It applies to every agent (Claude Code, Codex and others), not just Claude.

The essentials, in case nothing else is read:

- Run every Defender command through `tools/agent/Invoke-XdrAgent.ps1` (PowerShell 7). Never call the module directly, never run `Connect-Xdr*`, and never open, print or commit `.xdr-agent/session.json`.
- The analyst starts the session with `./tools/agent/Start-XdrWorkbench.ps1 -Tenant <customer> -Case <ref>` and pastes back its JSON line. Check it with `./tools/agent/Test-XdrWorkbench.ps1 -Live -Json` before querying.
- One customer per case. The wrapper enforces the case lock (exit 7), refuses state changes without the analyst's approval (exit 3), and names hunting failures (exit 8; see `.claude/skills/xdrinternals/reference/hunting-outage.md`).
- Case data stays under `investigations/` (git-ignored).

Keep the skill in one place: edit `.claude/skills/xdrinternals/`, then rebuild the packaged copies with `pwsh -NoProfile -File claude-desktop/build-workbench-skill.ps1 [-InstallCodex]`.
