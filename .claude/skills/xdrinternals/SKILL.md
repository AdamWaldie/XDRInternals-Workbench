---
name: xdrinternals
description: Setup helper and go-between for Microsoft Defender XDR through the XDRInternals module in this repo - Claude finds the repo, works out the customer, gives the user the standup and relay steps, verifies the session (direct or MTO), runs Advanced Hunting queries and cmdlets (incidents, alerts, devices, timelines, identity, Cloud Apps, exposure) from other skills or the user, and tears down. Use whenever the user asks to start or end a Defender session, run a Defender hunt or query, triage an incident or alert, or investigate a device, user, IP, hash or domain in Defender, including when they don't name the module.
---

# XDRInternals Workbench

The Workbench repo (GitHub `AdamWaldie/XDRInternals-Workbench`) lets Claude query Microsoft Defender XDR through the analyst's own portal session. This skill is the setup helper and the go-between: it gets a working session in place with the user, then carries Defender queries from other skills and from the user into the tenant, and the results back.

Two roles, never mixed:

- **The user** sets up the session on their own machine: one standup command in PowerShell 7, a portal sign-in, and a click on the relay extension. Installing PowerShell 7 and the extension is a one-time part of that.
- **Claude** does everything else from the device shell: finds the repo, prepares its own tools, works out the customer and case, gives the user the exact commands, verifies the session, runs the queries, and tears down when asked. Claude never reads or prints cookies or session files, and never runs `Connect-Xdr*`. Claude doesn't drive the browser either, with one exception: the portal hunting fallback in `reference/hunting-outage.md`, and only after the analyst has allowed it for that case.

## The flow

### Step 0. Check where Claude runs (Claude)

The Workbench works only where Claude runs on the analyst's own computer: Claude Code or Codex in the repo folder. The relay posts to 127.0.0.1 on that computer, and the saved session and every query stay in that checkout. Check first:

```bash
echo "${CLAUDE_CODE_REMOTE:-local}"
```

If it prints `true`, this is a Claude Code cloud session. Stop here and say, in one message: this conversation runs in the cloud, so it can't reach the relay, the session or the portal; open the Claude desktop app, start a new Claude Code session set to **Local** on the `XDRInternals-Workbench` folder, and ask again there. Don't give the standup steps, don't list commands for the user to run and paste back, and don't ask for the session file. That manual loop is what this check prevents. The agent scripts enforce the same thing: the wrapper exits `9`, and the standup, `Import-XdrSessionDrop.ps1` and `Test-XdrWorkbench.ps1` (`where` row) refuse.

### Step 1. Find the repo (Claude)

Look through the folders connected to this session (`get_device_info`); each mounts at `$HOME/mnt/<folder name>` in the device shell. The repo is the folder holding both `tools/agent/Invoke-XdrAgent.ps1` and `XDRInternals/XDRInternals.psd1`:

```bash
for d in "$HOME"/mnt/*/; do find "$d" -maxdepth 4 -path '*/tools/agent/Invoke-XdrAgent.ps1' 2>/dev/null; done | sed 's|/tools/agent/Invoke-XdrAgent.ps1||'
```

When the agent runs inside the repo itself (Claude Code, or Codex), `<repo>` is `git rev-parse --show-toplevel`, provided both marker files are there; skip the search.

If nothing turns up, ask the user to connect the repo folder to this session. The usual location is `C:\Users\AdamW\OneDrive\Documents\GitHub\XDRInternals-Workbench`; if it's cloned elsewhere, use the path they give. Call the found folder `<repo>` from here on.

### Step 2. Prepare Claude's side (Claude)

```bash
cd "<repo>" && bash tools/agent/setup.sh
```

It installs PowerShell 7 for Claude's shell if missing, loads the module and checks network access to the portal. Use the `pwsh` path it prints. On Windows (Claude Code or Codex running on the analyst's machine), skip `setup.sh` and use `pwsh` directly; if `pwsh` is missing, the user installs it with `winget install Microsoft.PowerShell`. If a previous session or another customer's case lock is still there, clear it now with `pwsh -NoProfile -File tools/agent/Stop-XdrWorkbench.ps1`; the standup replaces both anyway.

### Step 3. Work out the customer and case from context (Claude)

Don't ask for what is already known. Take the customer and case reference from, in order: the user's message; a document or ticket in the chat (tenant IDs, customer names, case or SR numbers); a connected case folder (`case.json` from ir-case-workspace, `.env` with `DEFENDER_TENANT_ID_*` from defender-data-access, or an `investigations/<date>-<customer>-<case>/` folder); a portal link's `tid=`. Resolve the name against `<repo>/tenants.local.csv` or the MTO section of `<repo>/tenants.txt`. State the result in one line ("Customer: <name> (<tenant ID>), case <ref>") and ask only if nothing names a customer or two candidates conflict. Never carry a customer over from an earlier case.

If the case already has a folder, note its path for step 5 (`-CaseFolder`). Otherwise the import creates `<repo>/investigations/<date>-<customer>-<case>/`.

### Step 4. The user sets up the session (user)

Send this, filled in with the repo path, customer and case:

1. Open **PowerShell 7**, not Windows PowerShell. Start menu > "PowerShell 7", or type `pwsh` in any terminal. The first line of the window reads `PowerShell 7.x`; if it says `Windows PowerShell` (version 5.1), close it, because the module and scripts don't run there.
2. Paste this one line. It changes to the repo folder and starts the standup:
   ```powershell
   cd "<repo>"; ./tools/agent/Start-XdrWorkbench.ps1 -Tenant "<customer>" -Case "<ref>"
   ```
   It opens a new Chrome window with two tabs, the customer's Advanced Hunting page and the multi-tenant portal (`mto.security.microsoft.com`), and prints a pairing code.
3. In that window, sign in if asked and wait for both tabs to load (the multi-tenant tab shows a tenant list).
4. Click the **XDR Docker Relay** extension icon (version 1.3 or later), paste the pairing code, and click **Relay session to container**. The popup shows whether it can see the standup and how long the code has left; leave the port blank and it finds it. If the 5 minutes run out, the standup offers a new code. The popup says whether the multi-tenant session came too.
5. The script then runs a control hunt. If it fails, it names the cause and the fix (sign in again, complete an MFA prompt, open the multi-tenant tab), waits for Enter, and relays or retries itself, up to three times.
6. At **Ready** it prints the session, case and hunt-check result, then copy-paste commands for when something goes wrong: check the session (`Test-XdrWorkbench.ps1 -Live`), relay again into the open portal window (`-NoBrowser`), start again with a fresh window, and end the session (`Stop-XdrWorkbench.ps1`). The user tells Claude it's ready; there is nothing to paste back. If it ends with `Hunting: FAILED`, it prints a `Fix:` line and exits 2: the user applies the fix and runs the relay-again command before anything is queried.

**Always send step 2 as that single line, with `cd "<repo>"; ` at the front and the real repo path filled in** (for example `cd "C:\Users\AdamW\OneDrive\Documents\GitHub\XDRInternals-Workbench"; ./tools/agent/Start-XdrWorkbench.ps1 -Tenant "Contoso" -Case "INC123"`). Never send the script part on its own, and never split the `cd` into a separate step: a missed `cd` is the most common reason the standup fails with "not recognized as a name of a cmdlet". Every other PowerShell command for the user follows the same rule. The commands the standup prints itself use full paths and work from any folder.

Use the normal Chrome profile, not Incognito. Cybanetix analyst accounts are under a Conditional Access policy that requires a compliant device, and an Incognito window carries no device identity. A session relayed from Incognito can read the portal but fails multi-tenant hunting with `AADSTS53000`. `-Incognito` exists for accounts without that policy.

First time on a machine, add before step 1:
- **PowerShell 7:** `winget install Microsoft.PowerShell`.
- **Relay extension:** in Chrome open `chrome://extensions`, turn on Developer mode, click **Load unpacked**, pick `<repo>\chrome-ext`, and pin the icon. If it's already loaded, click its reload arrow after a repo update.
- **Port reservation** (optional, in an elevated PowerShell, once): `netsh http add urlacl url=http://+:8787/ user="$env:USERDOMAIN\$env:USERNAME"`. Without it the listener binds to localhost, which the extension also finds. "Error: 183" means it already exists.

The script checks the session's tenant against the customer. If the portal landed in another tenant that has the customer in its MTO list, it sets an MTO case lock automatically: hunting works, and single-tenant cmdlets are refused because they would answer for the other tenant. If the customer isn't reachable, nothing is saved; the user switches to the customer in the portal and reruns.

**Alternative: file handoff.** When the user would rather not run PowerShell, they can click **Save session for Claude** in the extension instead, saving the file in `<repo>\.xdr-agent`. Claude then runs `pwsh -NoProfile -File tools/agent/Import-XdrSessionDrop.ps1 -Tenant "<customer>" -Case "<ref>"`, which does the same tenant checks and empties the file. Details are in `reference/setup.md`.

### Step 5. Verify (Claude)

```bash
cd "<repo>" && pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json
```

The standup stores its hunt check (`HuntRoute`, `HuntCheck`, `MtoRoute`) and the case folder (`CaseFolder`) in the case lock, which the `case lock` row reports; this run confirms it live. The session is working when `control hunt` is OK: the session, the case lock and the customer's data all line up. Always pass `-Live`: without it no hunting endpoint is called, so "No problems found" says nothing about hunting. In direct mode the control hunt uses the direct route, and a separate `mto hunt` row says whether estate sweeps would work. Tell the user in one line: account, session tenant, customer, mode, device count. Any FAIL: give the user the fix it prints, or see `reference/troubleshooting.md`.

### Step 6. Run queries (Claude)

Every call goes through the wrapper from `<repo>`:

```bash
cd "<repo>" && pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -ExpectTenantId <session tenant> -CommandFile <case folder>/queries/<name>.ps1 -OutFile <case folder>/evidence/<name>.json
```

- KQL goes in a `.ps1` file as a here-string: `Invoke-XdrMtoAdvancedHunting -TenantIds '<case tenant>' -DaysAgo 30 -QueryText @'...'@`. Every hunt names the case tenant; the wrapper refuses anything else.
- The wrapper picks the endpoint. In **direct mode** (session tenant = case tenant), it sends the hunt to `Invoke-XdrAdvancedHunting`, the single-tenant endpoint on security.microsoft.com, when the module has that cmdlet and it supports the parameters used, and says so on stderr. Rows still carry `TenantId` and `TenantName`. In **MTO mode**, it uses the multi-tenant endpoint with the relayed multi-tenant session, then the main session. `XDR_HUNT_ROUTE=mto` forces the multi-tenant endpoint.
- Queries can come from the user, a document, or other skills (`kql-engineer`, `threat-hunting`, `defender-log-sources` for table and field maps). Adapt them to Defender Advanced Hunting tables. `Timestamp`, not `TimeGenerated`, and `EntraIdSignInEvents`, not `AADSignInEventsBeta`. Sentinel-only tables need a workspace (`-SelectedWorkspaces`).
- Before hunting, run a control and coverage check, so a "no results" means something. Afterwards, record each query, its window and row count in the case notes.
- Exit codes: `0` ok, `2` partial or a tenant not searched, `3` write guard, `4` session missing, stale or rejected by the portal (repeat step 4), `5` wrong session tenant, `7` tenant guard (stop and confirm the customer), `8` hunt session timeout (HTTP 440 from a hunting endpoint while the session still works), `9` cloud session (go back to step 0). On `8`, follow `reference/hunting-outage.md`: switch route, or use the portal fallback. Don't re-relay in a loop.
- Cmdlet usage for everything other than hunting: `reference/usage/INDEX.md`. Wrapper options, case order, incident-class table and KQL habits: `reference/hunting.md`. Hunting more than one customer: `reference/multi-tenant.md`. A hunt fails but the session works: `reference/hunting-outage.md`.

### Step 7. Tear down (Claude, only when asked)

The session stays until the user asks to end it (the wrapper refuses one older than 12 hours). Then run `pwsh -NoProfile -File tools/agent/Stop-XdrWorkbench.ps1` from `<repo>`: it clears the saved session, the case lock and any unused session file, purges module temp files in Claude's shell, and leaves case evidence in place. The user can also run it themselves in PowerShell 7 to purge temp files on their machine.

## Rules

- **Local only.** Never run the Workbench by proxy: if Claude can't run the wrapper itself (cloud session, repo not reachable), say why and where to work instead, rather than giving the analyst commands to run and paste back.
- **One customer per case.** The standup locks hunts to the case customer, directly or through MTO. Hunting several customers happens only when the user asks for an estate sweep; read `reference/multi-tenant.md` first.
- **Read-only.** The wrapper refuses state changes and response actions. For containment, propose the exact command, target, tenant and reason, and run it with `-AllowWrite` only after the user approves that one action.
- **The token.** It lives in `<repo>/.xdr-agent/session.json`, git- and docker-ignored. Never open, print, copy or commit it.
- **Evidence.** Raw results stay in the case folder under `investigations/` (git-ignored). Findings cite the query that produced them. A verdict needs evidence that leaves no doubt, and a tenant that wasn't searched isn't clean. Attribute work to the analyst who asked for it.

## Keeping it current

The source of truth is `<repo>/.claude/skills/xdrinternals/` (this file and `reference/`). The account skill `xdrinternals-workbench` (Claude) and the Codex skill of the same name are built from it, never edited by hand:

```powershell
pwsh -NoProfile -File build/Sync-CmdletDocumentation.ps1        # after adding a public function: README, psd1 exports, XDRay mappings
pwsh -NoProfile -File tools/agent/Build-XdrUsageIndex.ps1        # after a module update
pwsh -NoProfile -File claude-desktop/build-workbench-skill.ps1   # dist/xdrinternals-workbench-skill.zip
pwsh -NoProfile -File claude-desktop/build-workbench-skill.ps1 -InstallCodex   # also into ~/.codex/skills
```

Upload the zip in Claude under Settings > Capabilities > Skills, replacing the old `xdrinternals-workbench`. Codex also reads `<repo>/AGENTS.md`, which points here.
