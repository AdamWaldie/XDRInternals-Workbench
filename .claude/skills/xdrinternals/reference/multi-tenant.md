# Multi-tenant hunting and keeping customers apart

Read this before any hunt that names more than one tenant, when the session tenant differs from the case customer, or when the wrapper exits 7.

## Tenant discipline (MSSP)

- `-ExpectTenantId <session tenant>` on every call pins the session.
- Hunts are held to the case tenant by the case lock the standup records in `.xdr-agent/case.json`; pass `-CaseTenantId` explicitly when there's no standup lock.
- Resolve customer names to IDs from `tenants.local.csv` or the MTO section of `tenants.txt` (`Start-XdrWorkbench.ps1 -ListTenants`). Refresh both from `Get-XdrMtoTenantList` when a customer is onboarded.


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
