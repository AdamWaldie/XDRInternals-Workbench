# Running commands and hunting

Read this before the first query of a case: wrapper options, the write guard, case folders, the case order, the incident-class table, IOC sweeps and KQL habits.

## Running commands

```bash
pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -ExpectTenantId <id> -Command "Get-XdrIncident -IncidentId 12345"
```

- stdout is JSON, always an array. stderr has the tenant banner and `[info]`, `[warning]`, `[error]` lines.
- KQL and multi-line scripts go in a `.ps1` file (KQL as a here-string) passed with `-CommandFile`. This avoids quoting problems with `|`, `"` and `$`, and the file is the record of what ran.
- Large results (timelines, `-All`, hunting): `-OutFile <path>.json`. Stdout then carries only `{Count, OutFile, Properties}`. Without it stdout shows at most `-MaxItems` (default 100).
- `-Format Table` or `-Format List` for quick looks.
- Each call is a fresh process. Do fetch, filter and project in one script.
- Exit codes: `0` ok, `1` threw, `2` partial (non-terminating errors, or a tenant not searched), `3` refused by the write guard, `4` no or stale session, `5` session tenant mismatch, `6` not PowerShell 7, `7` tenant guard (see `multi-tenant.md`), `8` hunt session timeout (HTTP 440 from a hunting endpoint; see `hunting-outage.md`). On `4`, or a 401/403, stop and ask the user to rerun the standup. On `8`, switch route as `hunting-outage.md` says. Don't retry in a loop.

## Write guard and response actions

The wrapper refuses, with exit code 3: `New-`, `Set-`, `Remove-`, `Merge-`, `Move-`, `Stop-`, `Update-`, `Export-`, `Disconnect-`, `Connect-` Xdr cmdlets; every `Invoke-XdrEndpointDevice*` (isolate, AV scan, investigation package, restrict execution, AIR, policy sync, Live Response); `Invoke-XdrRestMethod` with any method but GET; dynamic invocation and `Invoke-Expression`; and tenant-less MTO hunts. Sign-in and connection cmdlets are refused even with `-AllowWrite`.

To take a containment or change action, propose it to the user with the exact command, the target (device name and ID, alert or incident ID), the tenant and the reason. Run it with `-AllowWrite` only after the user approves that specific action. One approval covers one action. Record it in the case actions log against the approving analyst.

The guard is a safety net, not a sandbox. Don't route around it.

## Hunt and IR workflow

**Case folder.** For an IR case, use the `ir-case-workspace` standard (bootstrap there, log every query with `irc.py query log`, cite query IDs in findings) or the `defender-data-access` layout, whose `xdr_hunt.ps1` runs inside this wrapper: put `& '<case>/tools/xdr_hunt.ps1' -CaseRoot '<case>' -Id Qnn -Purpose '...' -Author '<analyst name>' -Query '...'` in a `.ps1` file and pass it with `-CommandFile`. Run the standup with `-NoCaseFolder` and write query files and `-OutFile` results into that case's working folder. For an ad hoc hunt, the standup's `investigations/` folder is enough: keep each `.ps1` under `queries/`, each result under `evidence/`, and a row per run in the `case-notes.md` query log. Table and field maps for each environment come from `defender-log-sources`.

**Every case, in order.**

1. Control: `Get-XdrTenantContext -Force`, then a scoped count that proves the tenant has the data the question needs, e.g. `DeviceInfo | where Timestamp > ago(1d) | summarize Devices = dcount(DeviceId)` with `-TenantIds <case tenant>` on the MTO route. In direct mode, run it with `Invoke-XdrAdvancedHunting` (`hunting-outage.md`).
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

## Evidence and reporting

- Raw output stays in the case folder. `investigations/`, `.xdr-agent/` and `tenants.local.csv` are git-ignored. Don't copy evidence elsewhere or paste customer data into external services.
- Every finding keeps the exact command, `.ps1` file or query ID that produced it.
- State what the data shows. A verdict needs evidence that leaves no doubt; keep hunting until it does.
- Results are bounded by page size, `-MaxItems`, `MaxRecordCount` and retention. Check coverage before treating "no rows" as absence.
- Attribute queries, actions and findings to the analyst who asked for them.
