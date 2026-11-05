---
name: xdrinternals
description: Investigate Microsoft Defender XDR with the XDRInternals module from Claude Chat or Cowork - incidents, alerts, devices, device and user timelines, Advanced Hunting KQL, IOC sweeps, identity, Cloud Apps and tenant posture. Use whenever the user asks to triage a Defender incident or alert, look up a device, user, IP, hash or domain in Defender, run Advanced Hunting, or check a tenant's Defender coverage or configuration, even if they don't name XDRInternals.
---

# XDRInternals for Claude Chat and Cowork

XDRInternals drives the Defender XDR portal's own (unofficial) APIs. The user signs in; Claude never handles credentials, cookies or MFA. Claude reaches Defender in one of two ways. Pick the first one available:

1. **MCP tools.** If tools named `xdr_session_status`, `xdr_run`, `xdr_hunt`, `xdr_read_evidence` and `xdr_response_action` are available, use them. They run on the user's machine.
2. **Folder access (Cowork).** If the user gave you a folder containing the XDRInternals repo (it has `XDRInternals/`, `tools/agent/Invoke-XdrAgent.ps1` and `tools/agent/setup.sh`), set it up and run it yourself. See "Folder route" below.

If neither is available, tell the user what's needed: either the MCP server in Claude Desktop, or a Cowork task with the repo folder. Point them to `docs/claude-desktop.md` in the repo.

## Start of every investigation

1. Check the session: call `xdr_session_status`, or on the folder route run `Get-XdrTenantContext -Force`.
2. Tell the user the tenant name and ID and the account. Ask them to confirm it's the customer they mean, unless they already named that exact tenant.
3. After that, pass the tenant ID on every call: `expect_tenant_id` (MCP) or `-ExpectTenantId` (folder). A mismatch stops the call.
4. If there's no session, the session is stale, or a call returns 401/403, stop. Ask the user to sign in again and save the session:
   - On their PowerShell 7 machine: `Connect-XdrByBrowser` (or `Connect-XdrByBrowserExtension` with the extension in `chrome-ext/`).
   - Then `./tools/agent/Save-XdrAgentSession.ps1`. Add `-InRepo` for the folder route.
   - Don't retry in a loop.
5. Standup and teardown are scripted, and both run only when the user asks:
   - Standup: `./tools/agent/Start-XdrWorkbench.ps1 -Tenant <name, partial name or ID> -Case <ref>` (`-ListTenants` shows the choices). Ask which customer if the user hasn't said; never reuse a tenant from an earlier case. It opens a normal Chrome window (not Incognito, which fails compliant-device Conditional Access) with Advanced Hunting and the multi-tenant portal for that tenant. The user signs in there and clicks Relay from that window. The script runs a control hunt, then at **Ready** prints copy-paste commands for when something goes wrong (check the session, relay again with `-NoBrowser`, start again) and for ending the session. The user just says it's ready; nothing is pasted back. If it ends with `Hunting: FAILED`, give the user its `Fix:` line and don't query until the relay-again command succeeds.
   - Teardown and token clearance: `./tools/agent/Stop-XdrWorkbench.ps1`. The saved session stays until the user asks for this.
   - The token is saved to `<repo>/.xdr-agent/session.json` (git- and docker-ignored; the save script refuses any path git would track).
6. When setup fails or a call misbehaves, run `pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json` (on the user's machine for the Chrome and Windows checks) and relay each FAIL with its fix.

## MCP route

- `xdr_run`: any read-only XDRInternals PowerShell. Each call is a fresh process, so do fetch, filter and projection in one script.
- `xdr_hunt`: Advanced Hunting KQL, passed as-is.
- `out_file`: saves large results under the repo's `investigations/` folder. Page through them with `xdr_read_evidence`, using `properties` to keep only the fields you need.
- `xdr_response_action`: only after the user explicitly approves that exact action on that exact target. Quote their approval in `user_approval`.

## Folder route (Cowork with the repo folder)

1. From the repo root, run `bash tools/agent/setup.sh`. It installs PowerShell 7 for the user if missing, loads the module, and checks for a session and for network access to security.microsoft.com. Report anything it says is missing.
2. If security.microsoft.com isn't reachable from your environment, the folder route can't work there. Tell the user, and suggest the MCP route instead, which runs on their machine.
3. Run commands like this:
   - `pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -ExpectTenantId <id> -Command "<PowerShell>"`
   - For KQL or multi-line scripts, write a `.ps1` file under `investigations/<case>/` and use `-CommandFile` instead.
   - For large results add `-OutFile investigations/<case>/<name>.json`.
4. stdout is JSON; stderr has the tenant banner and messages. Exit codes: `0` ok, `1` error, `2` partial, `3` refused by the write guard, `4` no or stale session, `5` tenant mismatch, `6` not PowerShell 7, `7` tenant guard (stop and confirm the customer), `8` hunt session timeout (HTTP 440 from a hunting endpoint while the session works: in direct mode hunt with `Invoke-XdrAdvancedHunting`; otherwise the portal fallback, run by the analyst; don't re-relay in a loop).
5. The wrapper refuses state-changing cmdlets and response actions unless `-AllowWrite` is passed. Only pass it after the user approves that exact action. Never run `Connect-Xdr*` yourself.

## Playbooks

Use exact IDs. Times are UTC.

- **Incident:** `Get-XdrIncident -IncidentId N`, then `Get-XdrIncidentAssociatedAlert -IncidentId N`. Pivot on every device, user, IP, hash and URL in the alerts.
- **Queue:**
  - `Get-XdrIncident -LookBackInDays 1 -SortByField CreatedDate -SortOrder Descending -PageSize 50`
  - `Get-XdrAlert -DaysAgo 1 -Severity High`
- **Device:**
  1. `Get-XdrEndpointDevice -MachineSearchPrefix host` to get the ID.
  2. `Get-XdrEndpointDeviceTimeline -DeviceId <id> -FromDate <utc> -ToDate <utc>`. Narrow it with `-EventType` (Processes, Network, Files, Registry, AlertsRelatedEvents) and always save it to a file.
  3. Context: `Get-XdrActionsCenterHistory`, `Get-XdrEndpointDeviceTag`.
- **User:** `Get-XdrIdentityUser -Upn x`, `Get-XdrIdentityUserTimeline -Upn x -LastNDays 7` (save to a file), and `Get-XdrCloudAppsActivityTimeline -LastNDays 1`.
- **Advanced Hunting:** start with `summarize` or `count` to size the data, then `project` and `take`. Check columns with `Get-XdrAdvancedHuntingTableSchema`. Hunting is rate limited.
- **IOC sweep:** one query with `let iocs = dynamic([...]);` across `DeviceNetworkEvents`, `DeviceFileEvents`, `DeviceProcessEvents`, `EmailEvents`, `IdentityLogonEvents`, `CloudAppEvents` and `EntraIdSignInEvents` (never `AADSignInEventsBeta`). `summarize` first and last seen per table and entity.
- **Posture:** `Get-XdrTenantWorkloadStatus`, `Get-XdrEndpointDeviceTotals`, `Get-XdrIdentityDomainControllerCoverage`, `Get-XdrEndpointAdvancedFeatures`, `Get-XdrSuppressionRule`, `Get-XdrXspmChokePoint`.
- **Unknown parameters:** look the cmdlet up in [reference/usage/INDEX.md](reference/usage/INDEX.md), which links to full syntax, parameters, allowed values and examples for all 133 cmdlets. Fall back to `Get-Help <cmdlet> -Full | Out-String`.

## Rules

- **Read-only by default.** For containment or changes, propose the exact command, target, tenant and reason, then wait for an explicit yes for that one action.
- **One customer per case.** A hunt runs separately inside each tenant it names and the rows come back tagged `TenantId`/`TenantName`; KQL never joins or totals across tenants, and an aggregate returns one row per tenant. Incidents, devices, timelines and identity cmdlets answer only for the session tenant. On the folder route the wrapper enforces a case lock (`.xdr-agent/case.json` from the standup, or `-CaseTenantId`), refuses multi-tenant hunts without `-AllowMultiTenant`, refuses entity cmdlets when the case tenant isn't the session tenant, discards rows from tenants no hunt named (exit 7), and flags tenants that errored as `TENANT NOT SEARCHED` (exit 2). For an estate sweep the user asked for, keep `TenantId`/`TenantName` in the output, split it with `tools/agent/Split-XdrMtoResult.ps1`, report each tenant as hits, searched with no rows, or not searched, and never put one customer's data or name in another customer's material. Qualify entities with their customer ("Customer A / DC01").
- **Customer data stays local.** Keep evidence in `investigations/`. Don't paste customer data into web searches or other external tools.
- **Report** scope, the answer with a confidence level, a UTC timeline, entities and IOCs, and findings, each with the exact command or KQL behind it. Also report gaps (missing telemetry, retention, truncated results, errors) and recommended actions, which you don't execute. "No results" means not observed in that window and those tables, never "didn't happen".
