---
name: xdrinternals
description: Setup helper and go-between for Microsoft Defender XDR through the XDRInternals module in this repo - Claude finds the repo, works out the customer, gives the user the standup and relay steps, verifies the session (direct or MTO), runs Advanced Hunting queries and cmdlets (incidents, alerts, devices, timelines, identity, Cloud Apps, exposure) from other skills or the user, and tears down. Use whenever the user asks to start or end a Defender session, run a Defender hunt or query, triage an incident or alert, or investigate a device, user, IP, hash or domain in Defender, including when they don't name the module.
---

# XDRInternals Workbench

The Workbench repo (GitHub `AdamWaldie/XDRInternals-Workbench`) lets Claude query Microsoft Defender XDR through the analyst's own portal session. This skill is the setup helper and the go-between: it gets a working session in place with the user, then carries Defender queries from other skills and from the user into the tenant, and the results back.

Two roles, never mixed:

- **The user** sets up the session on their own machine: one standup command in PowerShell 7, a portal sign-in, and a click on the relay extension. Installing PowerShell 7 and the extension is a one-time part of that.
- **Claude** does everything else from the device shell: finds the repo, prepares its own tools, works out the customer and case, gives the user the exact commands, verifies the session, runs the queries, and tears down when asked. Claude never drives the browser, never reads or prints cookies or session files, and never runs `Connect-Xdr*`.

## The flow

### Step 1. Find the repo (Claude)

Look through the folders connected to this session (`get_device_info`); each mounts at `$HOME/mnt/<folder name>` in the device shell. The repo is the folder holding both `tools/agent/Invoke-XdrAgent.ps1` and `XDRInternals/XDRInternals.psd1`:

```bash
for d in "$HOME"/mnt/*/; do find "$d" -maxdepth 4 -path '*/tools/agent/Invoke-XdrAgent.ps1' 2>/dev/null; done | sed 's|/tools/agent/Invoke-XdrAgent.ps1||'
```

If nothing turns up, ask the user to connect the repo folder to this session. The usual location is `C:\Users\AdamW\OneDrive\Documents\GitHub\XDRInternals-Workbench`; if it's cloned elsewhere, use the path they give. Call the found folder `<repo>` from here on.

### Step 2. Prepare Claude's side (Claude)

```bash
cd "<repo>" && bash tools/agent/setup.sh
```

It installs PowerShell 7 for Claude's shell if missing, loads the module and checks network access to the portal. Use the `pwsh` path it prints. If a previous session or another customer's case lock is still there, clear it now with `pwsh -NoProfile -File tools/agent/Stop-XdrWorkbench.ps1`; the standup replaces both anyway.

### Step 3. Work out the customer and case from context (Claude)

Don't ask for what is already known. Take the customer and case reference from, in order: the user's message; a document or ticket in the chat (tenant IDs, customer names, case or SR numbers); a connected case folder (`case.json` from ir-case-workspace, `.env` with `DEFENDER_TENANT_ID_*` from defender-data-access, or an `investigations/<date>-<customer>-<case>/` folder); a portal link's `tid=`. Resolve the name against `<repo>/tenants.local.csv` or the MTO section of `<repo>/tenants.txt`. State the result in one line ("Customer: <name> (<tenant ID>), case <ref>") and ask only if nothing names a customer or two candidates conflict. Never carry a customer over from an earlier case.

If the case already has a folder, note its path for step 5 (`-CaseFolder`). Otherwise the import creates `<repo>/investigations/<date>-<customer>-<case>/`.

### Step 4. The user sets up the session (user)

Send this, filled in with the repo path, customer and case:

1. Open **PowerShell 7**, not Windows PowerShell. Start menu > "PowerShell 7", or type `pwsh` in any terminal. The first line of the window reads `PowerShell 7.x`; if it says `Windows PowerShell` (version 5.1), close it, because the module and scripts don't run there. Then `cd "<repo>"` (for example `cd "C:\Users\AdamW\OneDrive\Documents\GitHub\XDRInternals-Workbench"`).
2. Run `./tools/agent/Start-XdrWorkbench.ps1 -Tenant "<customer>" -Case "<ref>"`. It opens a new Chrome window on the customer's Advanced Hunting page and prints a pairing code.
3. In that window, sign in if asked and wait for Advanced Hunting to load.
4. Click the **XDR Docker Relay** extension icon, paste the pairing code, keep port 8787, and click **Relay session to container**. Do this within 5 minutes of the code appearing.
5. Paste the script's final **Ready** block back to Claude.

Use the normal Chrome profile, not Incognito. Cybanetix analyst accounts are under a Conditional Access policy that requires a compliant device, and an Incognito window carries no device identity. A session relayed from Incognito can read the portal but fails multi-tenant hunting with `AADSTS53000`. `-Incognito` exists for accounts without that policy.

First time on a machine, add before step 1:
- **PowerShell 7:** `winget install Microsoft.PowerShell`.
- **Relay extension:** in Chrome open `chrome://extensions`, turn on Developer mode, click **Load unpacked**, pick `<repo>\chrome-ext`, and pin the icon. If it's already loaded, click its reload arrow after a repo update.
- **Port reservation** (in an elevated PowerShell, once): `netsh http add urlacl url=http://+:8787/ user="$env:USERDOMAIN\$env:USERNAME"`.

The script checks the session's tenant against the customer. If the portal landed in another tenant that has the customer in its MTO list, it sets an MTO case lock automatically: hunting works, and single-tenant cmdlets are refused because they would answer for the other tenant. If the customer isn't reachable, nothing is saved; the user switches to the customer in the portal and reruns.

**Alternative: file handoff.** When the user would rather not run PowerShell, they can click **Save session for Claude** in the extension instead, saving the file in `<repo>\.xdr-agent`. Claude then runs `pwsh -NoProfile -File tools/agent/Import-XdrSessionDrop.ps1 -Tenant "<customer>" -Case "<ref>"`, which does the same tenant checks and empties the file. Details are in `reference/setup.md`.

### Step 5. Verify (Claude)

```bash
pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json
```

The session is working when `control hunt` is OK: the session, the case lock and the customer's data all line up. Tell the user in one line: account, session tenant, customer, mode, device count. Any FAIL: give the user the fix it prints, or see `reference/troubleshooting.md`.

### Step 6. Run queries (Claude)

Every call goes through the wrapper from `<repo>`:

```bash
pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -ExpectTenantId <session tenant> -CommandFile <case folder>/queries/<name>.ps1 -OutFile <case folder>/evidence/<name>.json
```

- KQL goes in a `.ps1` file as a here-string: `Invoke-XdrMtoAdvancedHunting -TenantIds '<case tenant>' -DaysAgo 30 -QueryText @'...'@`. Every hunt names the case tenant; the wrapper refuses anything else.
- Queries can come from the user, a document, or other skills (`kql-engineer`, `threat-hunting`, `defender-log-sources` for table and field maps). Adapt them to Defender Advanced Hunting tables. `Timestamp`, not `TimeGenerated`, and `EntraIdSignInEvents`, not `AADSignInEventsBeta`. Sentinel-only tables need a workspace (`-SelectedWorkspaces`).
- Before hunting, run a control and coverage check, so a "no results" means something. Afterwards, record each query, its window and row count in the case notes.
- Exit codes: `0` ok, `2` partial or a tenant not searched, `3` write guard, `4` session missing or stale (repeat step 4), `5` wrong session tenant, `7` tenant guard (stop and confirm the customer).
- Cmdlet usage for everything other than hunting: `reference/usage/INDEX.md`. Wrapper options, case order, incident-class table and KQL habits: `reference/hunting.md`. Hunting more than one customer: `reference/multi-tenant.md`.

### Step 7. Tear down (Claude, only when asked)

The session stays until the user asks to end it (the wrapper refuses one older than 12 hours). Then run `pwsh -NoProfile -File tools/agent/Stop-XdrWorkbench.ps1` from `<repo>`: it clears the saved session, the case lock and any unused session file, purges module temp files in Claude's shell, and leaves case evidence in place. The user can also run it themselves in PowerShell 7 to purge temp files on their machine.

## Rules

- **One customer per case.** The standup locks hunts to the case customer, directly or through MTO. Hunting several customers happens only when the user asks for an estate sweep; read `reference/multi-tenant.md` first.
- **Read-only.** The wrapper refuses state changes and response actions. For containment, propose the exact command, target, tenant and reason, and run it with `-AllowWrite` only after the user approves that one action.
- **The token.** It lives in `<repo>/.xdr-agent/session.json`, git- and docker-ignored. Never open, print, copy or commit it.
- **Evidence.** Raw results stay in the case folder under `investigations/` (git-ignored). Findings cite the query that produced them. A verdict needs evidence that leaves no doubt, and a tenant that wasn't searched isn't clean. Attribute work to the analyst who asked for it.

## Keeping it current

This skill exists as the account skill `xdrinternals-workbench` and as `<repo>/.claude/skills/xdrinternals/SKILL.md`, with the same body and the same `reference/` files. Change both together. After a module update: `pwsh -NoProfile -File tools/agent/Build-XdrUsageIndex.ps1`, then `pwsh -NoProfile -File claude-desktop/build-skill.ps1`.
