# When hunting fails but the session works

Read this when a hunt fails while `Get-XdrTenantContext -Force` still returns the right tenant and account. That includes the wrapper exiting 8 (`HUNT SESSION TIMEOUT`), the control hunt in `Test-XdrWorkbench.ps1 -Live` failing, and an HTTP `440 Session timeout` anywhere in stderr.

## The two hunting routes

| Route | Cmdlet | Endpoint | Use it when |
| --- | --- | --- | --- |
| Direct | `Invoke-XdrAdvancedHunting` | `security.microsoft.com`, single-tenant query executor (the one the Advanced Hunting page calls) | The case is in **direct** mode: the session tenant is the case tenant (`Mode: direct` in `.xdr-agent/case.json` and the `case lock` row of `Test-XdrWorkbench.ps1`) |
| MTO | `Invoke-XdrMtoAdvancedHunting` | `mto.security.microsoft.com`, multi-tenant fan-out | The case is in **MTO** mode (the session tenant differs from the case tenant), or an estate sweep the analyst asked for |

The relayed session is the `security.microsoft.com` portal session (`sccauth` and `XSRF-TOKEN`); the relay extension captures nothing for `mto.security.microsoft.com`. A session can therefore be valid for every single-tenant cmdlet and still get `440 Session timeout` from the MTO endpoint.

The direct route doesn't depend on the MTO endpoint, so in direct mode it is the default for hunting. It answers only for the session tenant. In an MTO case it would return the session tenant's data, so the wrapper refuses it there just as it refuses every other single-tenant cmdlet.

If `Get-Command Invoke-XdrAdvancedHunting` finds nothing, the checkout is older than the direct route. Every hunt then goes through MTO, and a 440 leaves only the portal fallback (below).

## First seen (November 2026)

A direct-mode case. Every MTO hunt failed with `440 Session timeout` after each fresh relay, while `Get-XdrTenantContext` named the right tenant and account. `Test-XdrWorkbench.ps1` without `-Live` reported "No problems found", because it never calls a hunting endpoint. Opening `https://mto.security.microsoft.com` in the same Chrome profile and relaying again didn't help. While the API route was down, four leads were closed with portal exports (`DX0001` to `DX0004`). The fix was the direct route: a control hunt through `Invoke-XdrAdvancedHunting` returned the customer's onboarded devices, and the 45 remaining lower-priority leads went through it.

**Not yet proven:** that MTO needs its own session cookie, which the extension can't relay. That reading comes from the code (the extension, `Set-XdrConnectionSettings` and `Update-XdrConnectionSettings` only handle `security.microsoft.com` cookies), not from a test. See "Proving the MTO cause" below before building on it.

## Step 1. Classify the error

Read the wrapper's stderr and exit code. Don't guess from a summary.

| What you see | Meaning | Go to |
| --- | --- | --- |
| `440` or `Session timeout` on an MTO hunt; tenant context fine | The MTO endpoint has no valid session for this relay | Step 2 |
| `440`, 401 or 403 on the direct route **and** on `Get-XdrTenantContext -Force` | The portal session itself has expired | Rerun the standup (SKILL.md step 4) |
| 403 with `AADSTS53000` | Relayed from a window with no device identity (usually Incognito) | Standup without `-Incognito` (`troubleshooting.md`) |
| `TENANT NOT SEARCHED`, e.g. `MfaChallengeRequired (Status: 588)` | That one tenant refused; the session is fine | The analyst satisfies the challenge for that tenant in the portal, then rerun (`multi-tenant.md`) |
| 403 on one cmdlet, the rest fine | The analyst's role doesn't cover that API | KQL fallback in `hunting.md`, or ask for the role |
| 429 or a quota message | Throttled | Wait, then batch (see "Back on the API route") |

## Step 2. Diagnose in this order

One command per step. Stop at the first step that settles it.

1. **Run the diagnostics with `-Live`.**
   ```bash
   pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json
   ```
   Without `-Live`, the script checks the module, the network and the saved session, but calls no hunting endpoint, so "No problems found" says nothing about hunting. With `-Live`, it runs the control hunt on the route the case mode uses. In direct mode it also probes the MTO route and reports it separately as `mto hunt`.
2. **Confirm the session and the mode.** The `live call` row should show the expected tenant and account, and the `case lock` row the mode. If the tenant is wrong, stop (`multi-tenant.md`).
3. **Direct mode:** run the control hunt on the direct route:
   ```powershell
   Invoke-XdrAdvancedHunting -QueryText 'DeviceInfo | where Timestamp > ago(1d) | summarize Devices = dcount(DeviceId)'
   ```
   Put it in a `-CommandFile` and run it through the wrapper. Check `Get-Help Invoke-XdrAdvancedHunting` for its tenant parameter; it refuses to run when the session is signed in to a different tenant from the one named.
   - Rows come back: hunt the case on the direct route. Write in the case notes that hunting used the direct route and that MTO returned 440 at that time.
   - The direct route fails too: the portal session has expired. Rerun the standup.
4. **MTO mode:** the direct route isn't available, because it would answer for the session tenant. In order:
   1. Ask once whether the analyst can sign in to the customer's own tenant (a guest account in it, say). If so, a new standup there gives a direct-mode case.
   2. Otherwise use the portal fallback for the leads that can't wait.
   3. Try opening `https://mto.security.microsoft.com` in the same Chrome profile and relaying again at most once. It didn't help the first time this happened, so don't keep repeating it.
5. **Estate sweeps** need the MTO route. If it returns 440, tell the analyst the sweep can't run on the API right now. Don't break it into per-tenant direct hunts: each direct hunt answers only for the session tenant.

## Proving the MTO cause

Do this before changing the extension or how the session is stored. Record cookie and header **names** only, never values.

1. Have the analyst open `https://mto.security.microsoft.com` in the normal Chrome profile and wait for the tenant list to load.
2. In DevTools > Application > Cookies > `https://mto.security.microsoft.com`, they note which cookies exist, and whether each is set on `mto.security.microsoft.com` alone or on a parent domain.
3. In the XDRay panel (`XDRay/`), or the DevTools Network tab, they run any hunt from the MTO portal and note the request headers sent to `.../mtoapi/mtp/huntingService/queryExecutor`, again by name.
4. If MTO uses its own `sccauth` or XSRF token, the fix is credential handling: the extension reads the MTO cookies as well, `session.json` stores them, and `Set-XdrConnectionSettings` and `Invoke-XdrMtoAdvancedHunting` use them for that host. That widens what the relay carries, so build it only after the analyst agrees.

## Portal fallback

Use it only when no API route works and the lead can't wait. Results must be exported, hashed and registered, so that portal evidence is as traceable as wrapper evidence.

**Who runs it.** The analyst, or Claude through a browser tool, but only after the analyst has allowed it for this case, in the chat, and that permission is written in the case notes. When Claude runs it:
- Use only the Advanced Hunting page in the window the analyst has already signed in to. Never sign in, never complete MFA, never open DevTools, and never read cookies, storage or tokens.
- Read-only queries only. No custom detections, no saved functions, no actions from the results page.
- Before each query, check that the tenant the portal shows (top right, and `tid=` in the URL) is the case tenant. If it isn't, stop and tell the analyst.
- Use the next evidence ID and the same file layout as below.

**For each query:**

1. Write the KQL to `<case>/queries/<ID>-<slug>.kql` before running it. Put the time window in the query itself (`where Timestamp between (datetime(...) .. datetime(...))`), and set the portal's time picker to cover it. Record both.
2. Run the query in Advanced Hunting and note the row count the portal shows.
3. Export the results to CSV with the portal's **Export** button. Don't copy from the results grid: that truncates long fields and drops columns. Save the file as `<case>/evidence/<ID>-<slug>.csv`.
4. Hash it: `Get-FileHash -Algorithm SHA256 <file>`.
5. Register it in the case evidence register (`ir-case-workspace`, or the case's own register) with: ID, source `Defender portal Advanced Hunting (manual export)`, tenant name and ID, query file, window (UTC), run time (UTC), rows, who ran it (analyst, or Claude with the analyst's permission), SHA256, and notes.
6. Add a row to the query log in `case-notes.md`.

**Watch for these:**
- **Row cap.** The portal limits how many rows it shows and exports. If the row count equals the cap, the result is truncated: narrow the query and run it again, and say so in the notes.
- **Time zone.** The portal shows times in the time zone set in its settings, which may not be UTC. Check whether the export is in UTC, record which, and convert to UTC before building a timeline.
- **No rows.** That counts as "searched, no rows" only when a control query on the same tables and window, run the same way, returns data.

## Back on the API route

1. Run `Test-XdrWorkbench.ps1 -Live -Json`, and note in the case which route hunting now uses.
2. **Reconcile once.** Run one of the portal-fallback queries through the wrapper again, with the same fixed window (not `ago()`), into `-OutFile`. Compare the row counts. If they match, the fallback evidence and the API agree; record that. If they don't, find out why (time zone, window, row cap) before relying on either.
3. Fallback evidence keeps its ID. Don't register it again, and cite it by ID in findings.
4. **Leads in bulk.** Group the leads by table and entity type, and run one query per group with a `dynamic([...])` list, never one query per lead. Send each group to its own `-OutFile`, and close each lead against a named evidence file. Throttling comes from many small queries, not from one large one.
