---
name: xdrinternals
description: Query and investigate Microsoft Defender XDR through the XDRInternals PowerShell module in this repo - first-time setup, standup and teardown on request, tenant selection, case locks and multi-tenant sweeps that keep customers apart, setup troubleshooting, incidents, alerts, devices, timelines, Advanced Hunting KQL, Defender for Identity, Cloud Apps, vulnerability and exposure data. Use whenever the user asks to start or end a Defender hunt or IR session, triage an incident or alert, investigate a device, user, IP, hash or domain in Defender, run an Advanced Hunting query, check a tenant's Defender configuration or coverage, or pull Defender evidence, including when they don't name the module.
---

# XDRInternals Workbench

The Workbench repo (GitHub `AdamWaldie/XDRInternals-Workbench`) drives the Defender XDR portal's own APIs through the XDRInternals PowerShell module. These APIs are unofficial and can change without notice. The analyst signs in and relays a portal session; every call then goes through `tools/agent/Invoke-XdrAgent.ps1`, which restores that session, enforces the write guard, tenant pinning and case lock, and returns JSON.

In this skill, `<repo>` is the root of whichever clone is in use (section 0), and every command runs from there. The scripts find their own paths from where they sit, so the clone can live anywhere.

Usage for all 133 cmdlets (syntax, every parameter with defaults and allowed values, examples, guard class) is in `<repo>/.claude/skills/xdrinternals/reference/usage/`. Start at `INDEX.md`, then open the one group file you need. Don't guess parameters.

Related skills: `defender-data-access` is the umbrella for every access path and lists this one as path W, with its case-folder layout and `xdr_hunt.ps1` helper (which runs inside this wrapper); `ir-case-workspace` owns the evidence-grade case folder and query register; `defender-log-sources` owns per-tenant table and field maps. In Claude Code, delegate deep or multi-step investigations to the `xdr-investigator` agent (`<repo>/.claude/agents/xdr-investigator.md`).

This skill exists twice with the same body: as the account skill `xdrinternals-workbench` and as the repo's own `.claude/skills/xdrinternals/SKILL.md`. Change both together (section 10).

## 0. Locating the repo

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

## 1. First-time setup (once per machine)

Walk the analyst through these when the Workbench is new on a machine, or when diagnostics (section 3) point at one of them. Each step is theirs to run.

1. Clone the repo anywhere: `gh repo clone AdamWaldie/XDRInternals-Workbench` (or `git clone`). A folder synced to OneDrive works, but case evidence in `investigations/` then syncs too.
2. Install PowerShell 7: `winget install Microsoft.PowerShell`. The module doesn't load in Windows PowerShell 5.1.
3. Load the relay extension in Chrome: `chrome://extensions` > Developer mode > Load unpacked > `<repo>/chrome-ext`, then Details > **Allow in Incognito**.
4. Reserve the relay port once, in an elevated PowerShell: `netsh http add urlacl url=http://+:8787/ user="$env:USERDOMAIN\$env:USERNAME"`. The standup adds it itself when run elevated.
5. For a desktop session, connect the repo folder to it, so the device shell can reach it.
6. Check: `./tools/agent/Test-XdrWorkbench.ps1` on the analyst's machine, and `bash tools/agent/setup.sh` from the device shell (installs PowerShell 7 there if missing).
7. After the first standup, refresh the tenant list: run `Get-XdrMtoTenantList` through the wrapper with `-OutFile`, and write `Name,TenantId` rows to `<repo>/tenants.local.csv` (git-ignored). The MTO section of `tenants.txt` is the tracked copy.
8. Optional container route: `docker compose build` from `<repo>`, then `docker compose run --rm --service-ports xdrinternals`. Rebuild after any code change.

## 2. Standup (on request)

When the user asks to start, set up or connect a session, run this section. The user does the sign-in. Claude never handles credentials, cookies or MFA, and never runs `Connect-Xdr*`.

**Pick the tenant.** Ask which customer if the user hasn't said. `./tools/agent/Start-XdrWorkbench.ps1 -ListTenants` (or reading `tenants.local.csv`) shows the choices. The script accepts a full name, a unique part of a name, or a tenant ID, and lists the candidates when a name is ambiguous. Never carry a tenant over from an earlier case or example.

**User side** (PowerShell 7 on the machine with Chrome, from `<repo>`):

```powershell
./tools/agent/Start-XdrWorkbench.ps1 -Tenant <name, partial name or tenant ID> -Case <ref>
```

It checks pwsh 7 and the module, resolves the tenant, checks the Windows URL reservation and that the relay port is free, opens a **Chrome incognito window** on that tenant's Advanced Hunting page, checks the relay extension is enabled and allowed in incognito, starts `Connect-XdrByBrowserExtension -TenantId`, compares the live tenant with the target, saves the session to `<repo>/.xdr-agent/session.json`, and creates `investigations/<date>-<tenant>-<case>/` with `case-notes.md`. The relay reads the portal cookie from the window the extension is clicked in, so the user signs in and clicks Relay inside that incognito window. Options: `-NoBrowser` (container, or window already open), `-NoCaseFolder` (case already has an ir-case-workspace folder), `-AllowMto` (portal landed in another tenant that has the target in its MTO list; hunting only).

**Claude side** (Cowork device shell, Claude Code, or the container):

1. `cd "<repo>"`, then `bash tools/agent/setup.sh`. It installs PowerShell 7 for the user if missing (`~/.local/powershell/pwsh`), loads the module, and checks for a session and network access. Use the pwsh path it prints.
2. `Get-XdrTenantContext -Force` through the wrapper. Tell the user the tenant name, ID and account (`AuthInfo`), and confirm it's the session they meant.
3. Pass `-ExpectTenantId <session tenant>` on every later call.

**Where the token lives.** `Save-XdrAgentSession.ps1` writes `<repo>/.xdr-agent/session.json` with `-InRepo`, or `~/.xdr-agent/session.json` by default. `.xdr-agent` is in `.gitignore` and `.dockerignore`, the file is locked to the current user, and the script refuses any path git would track. Never print, copy or commit its contents.

## 3. Setup assistance and bug hunting

When standup fails, a call misbehaves, or the user asks for help with setup, run the diagnostics before guessing:

```bash
pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json
```

It checks pwsh and the module, the tenant list, the relay port and URL reservation, Chrome and the relay extension (installed, enabled, allowed in incognito), both extension copies, each saved session (tenant, age against the 12-hour limit, git-ignore status, permissions), `.dockerignore`, tracked case data, reachability of security.microsoft.com and mto.security.microsoft.com, and with `-Live` one read-only call through the wrapper. Each failure carries its fix. Run it on the user's machine for the Chrome and Windows checks; in a Linux shell those are skipped. Exit 1 means at least one FAIL.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Failed to listen on port 8787 ... Access is denied` | Windows HTTP.sys refuses `http://+:8787/` for non-admins | `netsh http add urlacl url=http://+:8787/ user="$env:USERDOMAIN\$env:USERNAME"` once, elevated |
| `Failed to listen on port 8787` with the reservation present | An earlier listener still holds the port | Close that window, or use `-Port` with the same port in the extension |
| Extension "Failed to fetch" | Container without `--service-ports`, or ports differ | `docker compose run --rm --service-ports xdrinternals`; same port everywhere |
| Relay sends nothing, or a session for the wrong account | Extension clicked outside the incognito window, or not allowed in incognito | chrome://extensions > XDR Docker Relay > Details > Allow in Incognito; click Relay from the incognito window |
| Banner shows the wrong customer | Portal opens in the last-used tenant; `?tid=` doesn't travel with the cookie | Hunt through MTO with `-TenantIds`, or switch tenant in the incognito window and rerun |
| AADSTS50058 | Only the Entra cookie relayed | Sign in to security.microsoft.com again in the incognito window, relay again |
| Wrapper can't find a session the standup saved | Standup and wrapper ran from different clones | Use the clone the standup ran in (section 0), or set `XDR_SESSION_PATH` |
| Wrapper exit 4 | No session, or older than 12 hours | Rerun the standup |
| Wrapper exit 7, `TENANT GUARD` | Hunt named a tenant other than the case lock, several tenants without `-AllowMultiTenant`, an entity cmdlet in an MTO case, or rows from an unnamed tenant | Stop and confirm the tenant with the user (5a) |
| `TENANT NOT SEARCHED`, exit 2 | That customer refused the hunt (MFA or Conditional Access challenge, missing role, quota) | Report it as not searched; the user satisfies the challenge for that tenant in the portal, then rerun |
| 403 on one cmdlet, others fine | The analyst's role in that customer tenant doesn't cover that API (the AH schema call is a common one) | Use the KQL fallback in section 7, or ask the customer for the role |
| `Argument types do not match` from the wrapper | Older wrapper on PowerShell 7.4 (`@()` around a generic List) | Update `tools/agent/Invoke-XdrAgent.ps1`; this checkout emits with `.ToArray()` |

## 4. Running commands

```bash
pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -ExpectTenantId <id> -Command "Get-XdrIncident -IncidentId 12345"
```

- stdout is JSON, always an array. stderr has the tenant banner and `[info]`, `[warning]`, `[error]` lines.
- KQL and multi-line scripts go in a `.ps1` file (KQL as a here-string) passed with `-CommandFile`. This avoids quoting problems with `|`, `"` and `$`, and the file is the record of what ran.
- Large results (timelines, `-All`, hunting): `-OutFile <path>.json`. Stdout then carries only `{Count, OutFile, Properties}`. Without it stdout shows at most `-MaxItems` (default 100).
- `-Format Table` or `-Format List` for quick looks.
- Each call is a fresh process. Do fetch, filter and project in one script.
- Exit codes: `0` ok, `1` threw, `2` partial (non-terminating errors, or a tenant not searched), `3` refused by the write guard, `4` no or stale session, `5` session tenant mismatch, `6` not PowerShell 7, `7` tenant guard (see 5a). On `4`, or a 401/403, stop and ask the user to rerun the standup. Don't retry in a loop.

## 5. Tenant discipline (MSSP)

- `-ExpectTenantId <session tenant>` on every call pins the session.
- Hunts are held to the case tenant by the case lock the standup records in `.xdr-agent/case.json`; pass `-CaseTenantId` explicitly when there's no standup lock.
- Resolve customer names to IDs from `tenants.local.csv` or the MTO section of `tenants.txt` (`Start-XdrWorkbench.ps1 -ListTenants`). Refresh both from `Get-XdrMtoTenantList` when a customer is onboarded.

## 5a. Multi-tenant hunting and keeping customers apart

**How it works.** A relayed session is the analyst's identity, not a customer. It can reach every tenant in the analyst's MTO list (`Get-XdrMtoTenantList`): each customer where the analyst holds a Defender role. A hunt is one request to `mto.security.microsoft.com` that names tenant IDs. The service runs the KQL separately inside each named tenant, then appends the rows, each tagged with `TenantId` and `TenantName`. Single-tenant cmdlets (incidents, alerts, devices, timelines, identity, Cloud Apps, posture) ignore all of this and answer only for the session's own tenant.

What follows from that:

- KQL never sees two tenants at once. A `join` matches only inside one tenant, and an aggregate without `by` returns one row per tenant: `summarize count()` across three customers gives three rows, not one total. Correlate across customers afterwards, from the split per-tenant files, never by eye in a mixed table.
- Each tenant can fail on its own (Conditional Access, MFA challenge, missing role, quota) while the others return rows. Seen in practice: `MfaChallengeRequired (Status: 588)` for one customer in a three-tenant sweep, with the other two answering normally.
- Retention, onboarded tables and licensing differ by customer, so the same query has different reach in each.
- Without `-TenantIds`, the module takes its tenant list from cache, which can be every tenant the analyst can reach.
- Hostnames, UPN formats, private IPs and names like `DC01` repeat across customers. `DeviceId`, incident and alert IDs are only unique inside a tenant.

**What the Workbench enforces** (`tools/agent/Invoke-XdrAgent.ps1`):

| Guard | Behaviour |
| --- | --- |
| Case lock | The standup records the case tenant in `.xdr-agent/case.json` (git-ignored). Every hunt must then name exactly that tenant. `-CaseTenantId` sets it per call. Banner: `Case lock: hunts limited to ...` |
| One tenant per hunt | A hunt naming more than one tenant needs `-AllowMultiTenant`, which can't be combined with a case lock |
| No tenant-less hunts | Refused, including splatted calls and calls from scripts such as `xdr_hunt.ps1` |
| Row check | Any row whose `TenantId` no hunt named discards the whole result |
| MTO case | When the case tenant differs from the session tenant, every non-hunting Xdr cmdlet is refused, because it would return the session tenant's data |
| Not searched | A tenant that errors prints `TENANT NOT SEARCHED`, sets exit 2, and is listed in the `-OutFile` sidecar `<file>.tenants.json` |

Tenant guard refusals exit 7. Treat 7 as a stop: confirm the tenant with the analyst, never work around it.

**Rules.**

1. One case, one customer. Case work hunts only the case tenant, under the case lock. Hunt more than one customer only when the analyst asks for an estate sweep and names the tenants (or says all of them), and run it from a sweep folder, not a customer's case folder.
2. Keep `TenantId` and `TenantName` in every multi-tenant result. Don't `project` them away; aggregate `by TenantName` plus the entity.
3. Split before reading: `Split-XdrMtoResult.ps1 -InputFile <sweep>.json -OutDir <sweep folder>` writes one folder per customer and `sweep-summary.json`. Findings for a customer are written from that customer's file only, and copied into that customer's case.
4. Qualify every entity with its customer in notes and findings: "Customer A / DC01", never "DC01".
5. Report each tenant in a sweep as one of: hits, searched with no rows (with the coverage that makes that meaningful), or not searched (with the error). Never fold a not-searched tenant into "no hits".
6. Never add up, rank or compare customers in anything a client sees. A client deliverable holds only that client's data and never names another customer. Cross-customer summaries are internal.
7. Log, per query, the session tenant, the tenants named, the tenants that returned rows, and any not searched. The sidecar file records this.
8. Changing customer means a new standup and a new case lock. Never reuse a session, case lock or case folder across customers, and never carry a tenant over from an earlier chat or example.

## 6. Write guard and response actions

The wrapper refuses, with exit code 3: `New-`, `Set-`, `Remove-`, `Merge-`, `Move-`, `Stop-`, `Update-`, `Export-`, `Disconnect-`, `Connect-` Xdr cmdlets; every `Invoke-XdrEndpointDevice*` (isolate, AV scan, investigation package, restrict execution, AIR, policy sync, Live Response); `Invoke-XdrRestMethod` with any method but GET; dynamic invocation and `Invoke-Expression`; and tenant-less MTO hunts. Sign-in and connection cmdlets are refused even with `-AllowWrite`.

To take a containment or change action, propose it to the user with the exact command, the target (device name and ID, alert or incident ID), the tenant and the reason. Run it with `-AllowWrite` only after the user approves that specific action. One approval covers one action. Record it in the case actions log against the approving analyst.

The guard is a safety net, not a sandbox. Don't route around it.

## 7. Hunt and IR workflow

**Case folder.** For an IR case, use the `ir-case-workspace` standard (bootstrap there, log every query with `irc.py query log`, cite query IDs in findings) or the `defender-data-access` layout, whose `xdr_hunt.ps1` runs inside this wrapper: put `& '<case>/tools/xdr_hunt.ps1' -CaseRoot '<case>' -Id Qnn -Purpose '...' -Author '<analyst name>' -Query '...'` in a `.ps1` file and pass it with `-CommandFile`. Run the standup with `-NoCaseFolder` and write query files and `-OutFile` results into that case's working folder. For an ad hoc hunt, the standup's `investigations/` folder is enough: keep each `.ps1` under `queries/`, each result under `evidence/`, and a row per run in the `case-notes.md` query log. Table and field maps for each environment come from `defender-log-sources`.

**Every case, in order.**

1. Control: `Get-XdrTenantContext -Force`, then a scoped count that proves the tenant has the data the question needs, e.g. `DeviceInfo | where Timestamp > ago(1d) | summarize Devices = dcount(DeviceId)` with `-TenantIds <case tenant>`.
2. Coverage: `Get-XdrTenantWorkloadStatus`, `Get-XdrEndpointDeviceTotals`, and `Get-XdrAdvancedHuntingTableSchema` (tables, `HasData`, retention). The schema call returns 403 for guest analysts in some customer tenants. Fall back to a row-count probe through MTO hunting, which works on the same session:
   ```kql
   union withsource=T isfuzzy=true EntraIdSignInEvents, IdentityLogonEvents, IdentityDirectoryEvents, CloudAppEvents, EmailEvents, UrlClickEvents, DeviceProcessEvents, DeviceFileEvents, DeviceNetworkEvents, DeviceLogonEvents
   | where Timestamp > ago(1d)
   | summarize Rows = count() by T
   ```
   A table missing from the output is absent or empty for that window; say which you can't tell apart. Write what is and isn't onboarded into the case before hunting. A negative result means nothing without this.
3. Entry point: pull the incident, alert, host, user or IOC set the case starts from.
4. Pivot: each entity in turn, sizing with `summarize` before pulling rows, and with absolute `datetime()` bounds or `-StartTime`/`-EndTime` so the logged window is exact.
5. Response state: `Get-XdrActionsCenterHistory` and `Get-XdrActionsCenterPending`, to report what has already been done.

**By incident class.** Record the IR playbook ID in the case notes. IR-002 (BEC) runs the email and identity rows together.

| Class | Entry cmdlets | Primary AH tables |
| --- | --- | --- |
| Identity compromise | `Get-XdrIdentityUser -Upn`, `Get-XdrIdentityUserTimeline -Upn -LastNDays` | `EntraIdSignInEvents`, `IdentityLogonEvents`, `IdentityDirectoryEvents`, `CloudAppEvents` |
| Email, phishing, BEC | `Get-XdrIncident`, `Get-XdrIncidentAssociatedAlert` | `EmailEvents`, `EmailUrlInfo`, `EmailAttachmentInfo`, `EmailPostDeliveryEvents`, `UrlClickEvents`, `CloudAppEvents` (inbox rules, MailItemsAccessed) |
| Endpoint, malware | `Get-XdrEndpointDevice -MachineSearchPrefix`, `Get-XdrEndpointDeviceTimeline -EventType` | `DeviceProcessEvents`, `DeviceFileEvents`, `DeviceNetworkEvents`, `DeviceRegistryEvents`, `DeviceImageLoadEvents` |
| Ransomware | Endpoint row, plus `Get-XdrIdentityDomainControllerCoverage`, `Get-XdrXspmChokePoint` | `DeviceFileEvents` (mass rename and write), `DeviceProcessEvents` (vssadmin, wbadmin, bcdedit), `IdentityLogonEvents` (lateral movement), `DeviceLogonEvents` |
| Network, edge device | `Get-XdrEndpointDevice` for the hosts it talks to | `DeviceNetworkEvents`, Sentinel tables onboarded to Defender (see `hunt/` for NetScaler and FortiGate) |
| Cloud and SaaS | `Get-XdrCloudAppsActivityTimeline -LastNDays`, `Get-XdrCloudAppsPolicy`, `Get-XdrCloudAppsApp` | `CloudAppEvents`, `EntraIdSignInEvents`, `OAuthAppInfo` |
| Data exposure, insider | `Get-XdrIdentityUserTimeline`, `Get-XdrCloudAppsActivityTimeline` | `CloudAppEvents` (FileDownloaded, FileSyncDownloadedFull, sharing), `DeviceFileEvents` (USB, archives), `EmailEvents` (external sends) |
| Vulnerability, exposure | `Get-XdrVulnerabilityManagementVulnerabilities`, `Get-XdrXspmAttackPath -Top 50`, `Get-XdrExposureManagementRecommendations` | `DeviceTvmSoftwareVulnerabilities`, `ExposureGraphNodes`, `ExposureGraphEdges` |
| Generic or unclear | Queue: `Get-XdrIncident -LookBackInDays 1 -SortByField CreatedDate -SortOrder Descending -PageSize 50`, `Get-XdrAlert -DaysAgo 1 -Severity High` | IOC sweep below |

**IOC sweep.** One query, not one per indicator: `let iocs = dynamic([...]);` across `DeviceNetworkEvents`, `DeviceFileEvents`, `DeviceProcessEvents`, `EmailEvents`, `UrlClickEvents`, `IdentityLogonEvents`, `CloudAppEvents` and `EntraIdSignInEvents`, matching with `has_any` or `in~`, summarised by table and entity with first and last seen. Use `EntraIdSignInEvents`, never `AADSignInEventsBeta`.

**KQL habits.** `summarize Rows = count()`, not `| count` (a `Count` column collides with PowerShell's `.Count`). Booleans are `True`/`False` since February 2026. Hunting is rate limited and quota is per tenant: space loops with `Start-Sleep`, never fan out a query per row, and narrow the window rather than retrying on 429. The `hunt/*.kql` files target Sentinel/Log Analytics unless their tables exist in Defender.

**Anything without a cmdlet.** `Invoke-XdrRestMethod -Uri 'https://security.microsoft.com/apiproxy/...'`, GET only.

## 8. Evidence and reporting

- Raw output stays in the case folder. `investigations/`, `.xdr-agent/` and `tenants.local.csv` are git-ignored. Don't copy evidence elsewhere or paste customer data into external services.
- Every finding keeps the exact command, `.ps1` file or query ID that produced it.
- State what the data shows. A verdict needs evidence that leaves no doubt; keep hunting until it does.
- Results are bounded by page size, `-MaxItems`, `MaxRecordCount` and retention. Check coverage before treating "no rows" as absence.
- Attribute queries, actions and findings to the analyst who asked for them.

## 9. Teardown and clearance (on request only)

The saved session stays until the user asks to clear it, so they can come back to a case within the 12-hour window. Don't clear it unprompted. When they ask to end the session, tear down, clear the token or log out:

```powershell
./tools/agent/Stop-XdrWorkbench.ps1            # add -RemoveUrlAcl in an elevated window to drop the port reservation
```

It deletes the saved session and case lock from `<repo>/.xdr-agent/` and the profile copy, clears the in-memory session, purges module temp data (`XdrTimeline`, `XdrIdentityTimeline`, `XdrCloudAppsTimeline`, `XdrAzureDataExplorer`, browser sign-in profiles), checks that git can't see case data or session files, and lists case folders still in `investigations/`. It never deletes evidence. If only the token should go, or the user can't run the script, run `pwsh -NoProfile -File tools/agent/Save-XdrAgentSession.ps1 -Clear -InRepo` from `<repo>` and say the temp purge is still outstanding. Closing the incognito window ends the browser side. Container sessions also hold `az` tokens in the `claude-home` volume; `az logout` there when Lighthouse was used.

## 10. Keeping this skill current

After any module change, regenerate the usage index and repackage the desktop skill:

```powershell
pwsh -NoProfile -File tools/agent/Build-XdrUsageIndex.ps1
pwsh -NoProfile -File claude-desktop/build-skill.ps1
```

The account skill `xdrinternals-workbench` and `<repo>/.claude/skills/xdrinternals/SKILL.md` share this body; only the frontmatter differs. When one changes, copy the body to the other. `<repo>/claude-desktop/xdrinternals/SKILL.md` is a shorter variant for Claude Chat and Cowork with the MCP route; keep its rules in line.
