# Agent instructions

This repo is the XDRInternals Workbench: a PowerShell module (`XDRInternals/`) and agent tooling (`tools/agent/`) for querying Microsoft Defender XDR through an analyst's own portal session.

For any Defender work (starting or ending a session, hunting, incidents, alerts, devices, users, IOCs), read `.claude/skills/xdrinternals-workbench/SKILL.md` first and follow it, with its `reference/` files. It applies to every agent (Claude Code, Codex and others), not just Claude.

The essentials, in case nothing else is read:

- Local only: the Workbench runs where the agent runs on the analyst's computer. In a Claude Code cloud session (`CLAUDE_CODE_REMOTE=true`; the wrapper exits 9), stop and tell the analyst to open a Local Claude Code session on this folder. Never hand them commands to run and paste back instead.
- Run every Defender command through `tools/agent/Invoke-XdrAgent.ps1` (PowerShell 7). Never call the module directly, never run `Connect-Xdr*`, and never open, print or commit `.xdr-agent/session.json`.
- The analyst starts the session with `./tools/agent/Start-XdrWorkbench.ps1 -Tenant <customer> -Case <ref>` and tells you when it reaches Ready (nothing is pasted back; the session and case lock are on disk). Check it with `./tools/agent/Test-XdrWorkbench.ps1 -Live -Json` before querying.
- One customer per case. The wrapper enforces the case lock (exit 7), refuses state changes without the analyst's approval (exit 3), and names hunting failures (exit 8; see `.claude/skills/xdrinternals-workbench/reference/hunting-outage.md`).
- Case data stays under `investigations/` (git-ignored).

After adding or renaming a public function in `XDRInternals/functions/`, run `pwsh -NoProfile -File build/Sync-CmdletDocumentation.ps1` and commit its output (README cmdlet table, `XDRInternals.psd1` exports, XDRay API mappings), and save the new file as UTF-8 with BOM. CI fails on either, and the sync workflow can't open its own fix PR in this repo.

Keep the skill in one place: edit `.claude/skills/xdrinternals-workbench/`, then rebuild the packaged copies with `pwsh -NoProfile -File claude-desktop/build-workbench-skill.ps1 [-InstallCodex]`.
