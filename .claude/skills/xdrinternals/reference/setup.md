# Setup detail

Read this when SKILL.md steps 1 to 5 need more than the short version: a new machine, the extension, an unusual repo location, or a fallback.

## Routes for getting the session to Claude

1. **PowerShell relay (default).** The user runs `Start-XdrWorkbench.ps1` in PowerShell 7 on their machine and clicks **Relay session to container** in the extension with the pairing code. The script checks the tenant, writes `session.json` and the case lock, and creates the case folder. Covered below.
2. **File handoff (alternative).** The user clicks **Save session for Claude** in the extension and saves `xdr-session-drop.json` in `<repo>/.xdr-agent`. Claude runs `tools/agent/Import-XdrSessionDrop.ps1`, which does the same checks and empties the drop file. Needs extension version 1.1 or later. The import also runs the control hunt and reports `HuntRoute`, `HuntCheck` and `Fix` in its Ready record (exit 2 when hunting failed).

Both routes also carry the multi-tenant portal session (`mto.security.microsoft.com`) when extension 1.2 or later is installed and that tab is signed in in the same window. Without it, multi-tenant hunting answers `440 Session timeout` (`hunting-outage.md`). After a `git pull` that changes `chrome-ext`, reload the extension in `chrome://extensions`, or the old version keeps running. Useful when the user can't run PowerShell, or the relay port is blocked.

Both routes carry the same portal session, so both hit the same Conditional Access rules. Sign in from the normal Chrome profile: an Incognito session has no device identity and fails multi-tenant hunting with `AADSTS53000` for accounts under a compliant-device policy.

Popup messages for the Save button:

| Popup says | Meaning | Fix |
| --- | --- | --- |
| `Session from this window offered for saving` | Save dialog opened | Save into `<repo>\.xdr-agent` |
| `Session from an Incognito window` or `a regular window` | Saved a different window's session | Close the other window, sign in again in one window, save again |
| `No Defender portal session found` | Not signed in, portal not loaded, or (Incognito only) the extension isn't allowed in incognito | Sign in, wait for Advanced Hunting; in Incognito, check Allow in Incognito |

The drop file goes to whichever folder the user picks. If it lands in Downloads or anywhere outside `<repo>/.xdr-agent`, the import won't see it. Ask the user to move it, and point out that it holds a live portal session.

The repo usually lives in OneDrive, so `.xdr-agent` and `investigations/` sync to the user's OneDrive along with the rest of the folder. Raise it with the user if their OneDrive policy doesn't allow live session tokens or case evidence.


## Locating the repo

Find the clone before anything else, and say which one you're using.

1. If the analyst gave a path, use it.
2. Otherwise check the folders connected to this session (`get_device_info` lists them; each mounts at `$HOME/mnt/<folder name>` in the device shell). The repo is the folder, or a subfolder a few levels down, that holds both `tools/agent/Invoke-XdrAgent.ps1` and `XDRInternals/XDRInternals.psd1`:
   ```bash
   for d in "$HOME"/mnt/*/; do find "$d" -maxdepth 4 -path '*/tools/agent/Invoke-XdrAgent.ps1' 2>/dev/null; done | sed 's|/tools/agent/Invoke-XdrAgent.ps1||'
   ```
   A fork or second clone may have a different folder name; the markers decide, not the name.
3. The usual location is `C:\Users\AdamW\OneDrive\Documents\GitHub\XDRInternals-Workbench`. If it isn't connected, ask for access to it (or to the path the analyst names) with the folder access request; if the analyst doesn't know where it is, the names-only listing of their home folder helps find it. Don't search their whole disk.
4. In Claude Code, the repo is the working directory's git root (`git rev-parse --show-toplevel`) when it has the markers. Inside the container, it's `/workspace`.
5. If more than one clone turns up, ask which one. The saved session and case lock live in `<repo>/.xdr-agent/`, so the standup and every wrapper call must use the same clone; a different clone has no session.

`XDR_SESSION_PATH` points the wrapper at a session file elsewhere, for a clone where the analyst saved without `-InRepo`. The cloud workspace can't reach the analyst's machine or session file, so never run hunts there.

## First-time setup (once per machine)

**Setup is user-driven.** Everything on the user's machine (installing software, loading the extension, signing in, relaying the session, running the standup and teardown scripts) is done by the user, by hand. Claude's part is to give exact steps with real paths filled in, wait for the user to report back, then verify and diagnose from the device shell. Claude doesn't drive Chrome or the extension, doesn't read cookies or tokens, doesn't open the portal for the user, and doesn't run the user-side scripts on their behalf.

Walk the user through these when the Workbench is new on a machine, or when diagnostics (`troubleshooting.md`) point at one of them.

1. Clone the repo anywhere: `gh repo clone AdamWaldie/XDRInternals-Workbench` (or `git clone`). A folder synced to OneDrive works, but case evidence in `investigations/` then syncs too.
2. Install PowerShell 7: `winget install Microsoft.PowerShell`. The module doesn't load in Windows PowerShell 5.1.
3. Install the relay extension from the repo (it isn't in the Chrome Web Store). The extension is the folder `<repo>\chrome-ext`; on the usual clone that is `C:\Users\AdamW\OneDrive\Documents\GitHub\XDRInternals-Workbench\chrome-ext`. `<repo>\docker\browser-extension` is an identical copy. If the repo isn't cloned on this machine, step 1 comes first.
   1. In Chrome, open `chrome://extensions`.
   2. Turn on **Developer mode** (toggle, top right).
   3. Click **Load unpacked** and select the `chrome-ext` folder itself (the one holding `manifest.json`), not the repo root.
   4. On the new **XDR Docker Relay** card, click **Details** and turn on **Allow in Incognito**. Without it the extension can't see the incognito sign-in.
   5. Pin it: puzzle-piece icon in the toolbar > pin XDR Docker Relay, so it shows in incognito windows too.
   6. After the repo's extension files change (a `git pull` that touches `chrome-ext`), click the reload arrow on the card. Chrome doesn't pick up changes to an unpacked extension on its own.
4. Reserve the relay port once, in an elevated PowerShell: `netsh http add urlacl url=http://+:8787/ user="$env:USERDOMAIN\$env:USERNAME"`. The standup adds it itself when run elevated.
5. For a desktop session, connect the repo folder to it, so the device shell can reach it.
6. Check: `./tools/agent/Test-XdrWorkbench.ps1` on the analyst's machine, and `bash tools/agent/setup.sh` from the device shell (installs PowerShell 7 there if missing).
7. After the first standup, refresh the tenant list: run `Get-XdrMtoTenantList` through the wrapper with `-OutFile`, and write `Name,TenantId` rows to `<repo>/tenants.local.csv` (git-ignored). The MTO section of `tenants.txt` is the tracked copy.
8. Optional container route: `docker compose build` from `<repo>`, then `docker compose run --rm --service-ports xdrinternals`. Rebuild after any code change.

## Standup (on request)

When the user asks to start, set up or connect a session, run this section. The user does the sign-in. Claude never handles credentials, cookies or MFA, and never runs `Connect-Xdr*`.

**What working operation needs.** These seven conditions, and nothing else. The module import and the case folder are handled by the scripts. The standup is finished only when condition 7 passes.

| # | Condition | Who sets it up | How it's checked |
| --- | --- | --- | --- |
| 1 | Claude has found the repo clone | Claude (Locating the repo, above) | Both marker files present |
| 2 | Claude's shell has PowerShell 7 and the module loads | Claude | `bash tools/agent/setup.sh` |
| 3 | Claude's shell reaches security.microsoft.com and mto.security.microsoft.com | Claude, or the user's network settings | `setup.sh`, or the network rows of `Test-XdrWorkbench.ps1` |
| 4 | The user's machine has PowerShell 7, the relay extension loaded, and the port reservation | User, once (First-time setup, above) | `./tools/agent/Test-XdrWorkbench.ps1` on their machine |
| 5 | A portal session for the user, relayed from the standup's normal Chrome window, saved at `<repo>/.xdr-agent/session.json` and under 12 hours old | User, with `Start-XdrWorkbench.ps1` | Wrapper exits 4 without it |
| 6 | The case customer is the case lock in `<repo>/.xdr-agent/case.json`, and the session tenant is that customer or has it in its MTO list | User, with `Start-XdrWorkbench.ps1`; Claude confirms | `Get-XdrTenantContext -Force` and the `Case lock:` banner |
| 7 | A control hunt against the case tenant returns rows | Claude | `Test-XdrWorkbench.ps1 -Live` reports `control hunt OK` |

**Order.**

1. Claude checks conditions 1 to 3 first, before asking the user for anything: find the repo, `cd "<repo>"`, run `bash tools/agent/setup.sh`, and use the pwsh path it prints. Fix what can be fixed from the shell; report the rest.
2. Claude settles the customer (below) and the case reference.
3. Claude gives the user the runbook (below), which covers conditions 4 to 6.
4. When the user says the standup reached "Ready" (nothing is pasted back), Claude runs `pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json` from `<repo>`. Every FAIL goes to `troubleshooting.md`. When the control hunt passes, Claude reports in one line: account, session tenant, case lock (customer and ID), devices in the control hunt, and session age. The `case lock` row names the case folder. Then it passes `-ExpectTenantId <session tenant>` on every later call.

**Pick the tenant.** Ask which customer if the user hasn't said. `./tools/agent/Start-XdrWorkbench.ps1 -ListTenants` (or reading `tenants.local.csv`) shows the choices. The script accepts a full name, a unique part of a name, or a tenant ID, and lists the candidates when a name is ambiguous. Never carry a tenant over from an earlier case or example.

**User side** (PowerShell 7 on the machine with Chrome, from `<repo>`):

```powershell
./tools/agent/Start-XdrWorkbench.ps1 -Tenant <name, partial name or tenant ID> -Case <ref>
```

It checks pwsh 7 and the module, resolves the tenant, checks the Windows URL reservation and that the relay port is free, opens a **normal Chrome window** with two tabs, the tenant's Advanced Hunting page and the multi-tenant portal, checks the relay extension is enabled, starts `Connect-XdrByBrowserExtension -TenantId`, compares the live tenant with the target, saves the session to `<repo>/.xdr-agent/session.json`, and creates `investigations/<date>-<tenant>-<case>/` with `case-notes.md`. The relay reads the portal cookie from the window the extension is clicked in, so the user signs in and clicks Relay inside that window. It then runs a control hunt and, at Ready, prints copy-paste commands for checking the session, relaying again, starting again and ending the session. Options: `-NoBrowser` (container, or window already open; also how to relay again into the same window), `-NoCaseFolder` (case already has an ir-case-workspace folder), `-Incognito` (accounts without the compliant-device policy only). MTO mode is automatic when the portal lands in another tenant that has the target in its MTO list.

**Getting the token with the relay extension (user).** The "token" is the Defender portal session cookie from the user's own sign-in. The extension reads it from Chrome and posts it, with a single-use pairing code, to the listener on `127.0.0.1:<port>`; the standup then saves it to `<repo>/.xdr-agent/session.json`. Give the user these steps:

1. Close any other Chrome window signed in to security.microsoft.com as a different customer, or sign out there. The extension prefers the window it's clicked from, but an older copy took the first signed-in window it found, which is how a session can land in the wrong customer.
2. Run the standup (runbook step 5). It opens a normal Chrome window at `https://security.microsoft.com/v2/advanced-hunting?tid=<customer tenant ID>`, with the multi-tenant portal in a second tab, and prints `Paste this pairing code: <12 characters>`. The code is single-use and the listener waits 5 minutes (`-TimeoutSeconds` on the cmdlet changes that).
3. In that window, sign in with the analyst account and complete MFA. Wait until both tabs have loaded (the multi-tenant tab shows a tenant list) and the tenant shown top right is the customer. If it shows another customer, switch tenant there before relaying.
4. Still in that window, click the **XDR Docker Relay** icon. Paste the pairing code into **Pairing code**, check **Container relay port** matches the standup (8787 by default; the popup remembers the last value), and click **Relay session to container**.
5. The popup should say `Session relayed from this window`. "an Incognito window" or "a regular window" means it took a different window's session: stop, close the other window, and relay again with a fresh standup.
6. Back in PowerShell, the standup prints the signed-in tenant, compares it with the target, saves the session and case lock, and runs a control hunt. At Ready the user tells Claude; nothing is pasted back.

Popup messages and what they mean:

| Popup says | Meaning | Fix |
| --- | --- | --- |
| `Enter the pairing code shown by Connect-XdrByBrowserExtension.` | Code box empty | Paste the code from PowerShell |
| `No Defender XDR or Entra sign-in cookies found in any cookie store` | Not signed in, or the extension isn't allowed in incognito | Sign in in the standup's window and wait for the portal; with `-Incognito`, turn on Allow in Incognito |
| `Found Entra sign-in cookie ... (portal cookie not present)` | Signed in to Entra but the Defender portal hasn't loaded | Open security.microsoft.com in that window, wait for it to load, relay again |
| `Failed: Failed to fetch` | Nothing listening on that port: standup not running, timed out, wrong port, or the container started without `--service-ports` | Rerun the standup and relay within 5 minutes, with matching ports |
| `Failed: Container rejected the relay (HTTP 401)` or similar | Wrong or reused pairing code | Rerun the standup for a new code |
| `Session relayed from a regular window` | Another window's session was used | Close that window, rerun the standup, relay again from the window it opened |

 Assume a fresh window. Fill in the repo path, customer and case reference, and send it as numbered steps:

1. Open PowerShell 7 (Start menu > PowerShell 7, or a PowerShell 7 tab in Windows Terminal) and check `$PSVersionTable.PSVersion` shows major version 7. Windows PowerShell 5.1 can't load the module.
2. `cd "<repo>"`. If a script fails with "running scripts is disabled on this system": `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` (this window only), then rerun it.
3. Clean slate when a previous session or another customer's case lock may exist: `./tools/agent/Stop-XdrWorkbench.ps1`.
4. Check the machine: `./tools/agent/Test-XdrWorkbench.ps1`, fixing anything marked FAIL.
5. `./tools/agent/Start-XdrWorkbench.ps1 -Tenant <customer> -Case <ref>`. The script imports the module itself. Then follow the token steps above: sign in in the window it opens, and relay from that same window with the pairing code. If the session landed in another tenant that has the customer in its MTO list, the script sets MTO mode itself.
6. At **Ready**, tell Claude; nothing is pasted back. Keep the commands it prints: they check the session, relay again (`-NoBrowser`), start again, and end the session. If it shows `Hunting: FAILED`, apply its `Fix:` line and run the relay-again command.

Manual fallback if the script route fails: `Import-Module ./XDRInternals/XDRInternals.psd1`, then `Connect-XdrByBrowserExtension -TenantId <customer tenant ID>` (relay from the signed-in portal window), then `./tools/agent/Save-XdrAgentSession.ps1 -InRepo`. That records no case lock, so pass `-CaseTenantId <customer tenant ID>` on every wrapper call.

**Where the token lives.** `Save-XdrAgentSession.ps1` writes `<repo>/.xdr-agent/session.json` with `-InRepo`, or `~/.xdr-agent/session.json` by default. `.xdr-agent` is in `.gitignore` and `.dockerignore`, the file is locked to the current user, and the script refuses any path git would track. Never print, copy or commit its contents.
