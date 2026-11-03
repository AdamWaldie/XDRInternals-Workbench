---
name: xdrinternals
description: Query and investigate Microsoft Defender XDR through the XDRInternals PowerShell module in this repo - incidents, alerts, devices, device and user timelines, Advanced Hunting KQL, Defender for Identity, Cloud Apps, vulnerability and exposure data, and multi-tenant (MTO) hunting. Use whenever the user asks to triage an incident or alert, investigate a device, user, IP, hash or domain in Defender, run an Advanced Hunting query, check a tenant's Defender configuration or coverage, or pull Defender evidence, including when they don't name the module.
---

# XDRInternals

XDRInternals drives the Defender XDR portal's own APIs from PowerShell. These APIs are unofficial and undocumented, so they can change without notice. Claude can't sign in, so the user signs in and hands Claude their session. Every call Claude makes then goes through a wrapper script that restores that session, guards against writes, and returns JSON.

For deep or multi-step investigations, delegate to the `xdr-investigator` agent (`.claude/agents/xdr-investigator.md`). Do quick lookups yourself with the wrapper below.

## 1. Session handoff (the user does this)

The user signs in. Claude never handles credentials, cookies or MFA, and never runs `Connect-Xdr*`.

**In the Docker container** (recommended; it has pwsh, an egress firewall and Claude Code):

```bash
docker compose build
docker compose run --rm --service-ports xdrinternals
```

Inside the container's pwsh:

```powershell
Connect-XdrByBrowserExtension          # prints a pairing code; relay from Chrome
./tools/agent/Save-XdrAgentSession.ps1 # hands the session to Claude
```

The relay extension is in `chrome-ext/`, an identical copy of `docker/browser-extension/`. To install it, open `chrome://extensions`, turn on Developer mode, click **Load unpacked** and select `chrome-ext/`. Then open its **Details** and turn on **Allow in Incognito**. In Chrome, sign in to security.microsoft.com, open the extension, paste the code, keep port `8787`, and click **Relay session to container**.

**On a host with PowerShell 7** (`pwsh`): `Import-Module ./XDRInternals/XDRInternals.psd1`, run any `Connect-XdrBy*` cmdlet, then run `./tools/agent/Save-XdrAgentSession.ps1`. The module doesn't load in Windows PowerShell 5.1 (`powershell.exe`), so check that `pwsh` exists first. Without it, use the container.

If the wrapper exits with code 4 (no or stale session) or reports a 401/403 error, stop and ask the user to reconnect and save again. Don't retry in a loop.

When the investigation is done, remind the user to run `./tools/agent/Save-XdrAgentSession.ps1 -Clear`.

## 2. Running commands

```bash
pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -Command "Get-XdrIncident -IncidentId 12345"
```

- **stdout** is the JSON result, always an array. **stderr** shows the tenant banner (`[xdr-agent] Tenant: …`), `[info]`, `[warning]` and `[error]` lines.
- **Multi-line scripts or KQL:** write a `.ps1` file in the scratchpad or investigation folder and pass `-CommandFile <path>`. This avoids shell-quoting problems with KQL `|`, `"` and `$`.
- **Large results** (timelines, `-All`, hunting): pass `-OutFile <path>.json`. Stdout then gets only `{Count, OutFile, Properties}`. Read or filter the file afterwards (`jq` works in the container). Without `-OutFile`, stdout shows at most `-MaxItems` items (default 100).
- `-Format Table` or `-Format List` gives readable output for quick looks.
- `-ExpectTenantId <guid>` refuses to run if the session belongs to another tenant. Pass it on every call once the tenant is confirmed (see section 4).
- Each call is a fresh process: variables don't carry over between calls. Do the whole fetch-filter-project chain in one script, and save intermediate data with `-OutFile`.
- Exit codes: `0` ok, `1` the command threw, `2` non-terminating errors (partial results), `3` refused by the write guard, `4` no or stale session, `5` tenant mismatch, `6` not PowerShell 7.

Discover parameters before guessing them: `Get-Help Get-XdrEndpointDeviceTimeline -Full | Out-String`, or `(Get-Command X).Parameters.Keys`. The full cmdlet list, with each cmdlet's guard class, is in [reference/cmdlets.md](reference/cmdlets.md).

## 3. Write guard and response actions

Investigation is read-only by default. The wrapper refuses, with exit code 3:

- `New-`, `Set-`, `Remove-`, `Merge-`, `Move-`, `Stop-`, `Update-`, `Export-`, `Disconnect-` and `Connect-` Xdr cmdlets
- `Invoke-XdrEndpointDevice*`: isolate, AV scan, collect package, restrict app execution, AIR, policy sync, Live Response
- `Invoke-XdrRestMethod` with any method other than GET
- dynamic invocation and `Invoke-Expression`

Sign-in and connection cmdlets are refused even with `-AllowWrite`.

To take a containment or change action, first propose it to the user with the exact command, the target (device name and ID, alert or incident ID), the tenant, and the reason. Run it with `-AllowWrite` only after the user approves that specific action. One approval covers one action. Record the action and the approval in the case notes.

The guard is a safety net, not a sandbox. Don't try to route around it.

## 4. Tenant discipline (MSSP)

This repo is used across many customer tenants. A query run against the wrong tenant can leak data or cause harm.

1. The first call of every investigation is `Get-XdrTenantContext -Force`. Show the user the tenant name and ID, and confirm they match the customer under investigation.
2. Then pass `-ExpectTenantId` on every call.
3. If the user switches customer, they reconnect and save again. Confirm the new tenant afresh.
4. `Invoke-XdrMtoAdvancedHunting -TenantIds` can query several tenants at once. Only include tenants the user named for this task.

## 5. Investigation playbooks

Quote IDs exactly as returned. Times are UTC.

**Incident triage**

```powershell
Get-XdrIncident -IncidentId 12345
Get-XdrIncidentAssociatedAlert -IncidentId 12345
```

Then pivot on every entity in the alerts: devices, users, IPs, file hashes, URLs and processes.

**Recent queue**

```powershell
Get-XdrIncident -LookBackInDays 1 -SortByField CreatedDate -SortOrder Descending -PageSize 50
Get-XdrAlert -DaysAgo 1 -Severity High
```

**Device**

1. Resolve the device: `Get-XdrEndpointDevice -MachineSearchPrefix 'host'` (or `-DeviceId`).
2. Get its timeline: `Get-XdrEndpointDeviceTimeline -DeviceId <id> -FromDate <utc> -ToDate <utc>`, always with `-OutFile`.
3. Narrow the timeline with `-EventType` (e.g. `Processes`, `Network`, `Files`, `Registry`, `AlertsRelatedEvents`) or a short window. Full timelines are large.
4. Context: tags (`Get-XdrEndpointDeviceTag`), pending and historical actions (`Get-XdrActionsCenterPending`, `Get-XdrActionsCenterHistory`).

**User**

```powershell
Get-XdrIdentityUser -Upn 'user@contoso.com'
Get-XdrIdentityUserTimeline -Upn 'user@contoso.com' -LastNDays 7   # use -OutFile
```

Cloud activity: `Get-XdrCloudAppsActivityTimeline -LastNDays 1` (use `-OutFile`).

**Advanced Hunting (KQL)**

```powershell
Invoke-XdrMtoAdvancedHunting -QueryText $kql -DaysAgo 7 -MaxRecordCount 1000
```

Without `-TenantIds` it runs against the current tenant. Use `-StartTime`/`-EndTime` for an exact window.

- Write the KQL in a `.ps1` file as a here-string and pass the file with `-CommandFile`.
- Start with `summarize` or `count` to size the data, then pull rows with `project` and `take`.
- Check tables and columns first with `Get-XdrAdvancedHuntingTableSchema`.
- Hunting is rate limited. Space out loops (`Start-Sleep`) and never fan out a query per row.
- Reusable NetScaler/FortiGate hunts are in `hunt/`. Those `.kql` files are for Sentinel/Log Analytics (`az monitor log-analytics query`), not Defender AH, unless their tables exist in Defender.

**IOC sweep (IP, hash, domain)**: one KQL query across the relevant tables (`DeviceNetworkEvents`, `DeviceFileEvents`, `DeviceProcessEvents`, `EmailEvents`, `IdentityLogonEvents`, `CloudAppEvents`, `AADSignInEventsBeta`). Use `has_any` or `in~` against a `dynamic([...])` IOC list, and `summarize` by table, entity and first/last seen.

**Posture and coverage**: `Get-XdrTenantWorkloadStatus`, `Get-XdrEndpointDeviceTotals`, `Get-XdrIdentityDomainControllerCoverage`, `Get-XdrIdentityOnboardingStatus`, `Get-XdrEndpointAdvancedFeatures`, `Get-XdrSuppressionRule`, `Get-XdrVulnerabilityManagementVulnerabilities`, `Get-XdrXspmAttackPath -Top 50`, `Get-XdrXspmChokePoint`.

**Anything without a cmdlet**: `Invoke-XdrRestMethod -Uri 'https://security.microsoft.com/apiproxy/...'` (GET only).

## 6. Evidence and reporting

- Save raw output under `investigations/<YYYY-MM-DD>-<tenant-short>-<case>/` with descriptive file names (e.g. `incident-12345-alerts.json`). This folder is git-ignored because it holds customer data. Don't copy evidence anywhere else, and don't paste customer data into external services.
- For every finding, keep the exact command or KQL that produced it, so the user can reproduce it.
- Separate what the data shows from what you infer. Label gaps explicitly: missing telemetry, retention limits, truncated results, rate-limit errors.
- Results are capped by page size, `-MaxItems`, `MaxRecordCount` and retention. Say so whenever a result could be incomplete, and never treat "no rows" as proof of absence without checking the window and table coverage.
