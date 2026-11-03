# XDRInternals — local container & mapping notes

Private working notes for the Dockerised XDRInternals setup + the Defender/Sentinel
"what logs are where" mapping work. **Local only — never commit/push this or the related
files to `MSCloudInternals/XDRInternals`.** (See "Git safety" below.)

Last updated: 2026-09-25

---

## 1. What this is

A self-contained way to run the XDRInternals PowerShell module (unofficial Microsoft
Defender XDR API) inside Docker, with:

- **Egress firewall** — the container can only talk to the Microsoft endpoints it needs;
  everything else is dropped (fail-closed).
- **Browser relay** — a Chrome extension + `Connect-XdrByBrowserExtension` cmdlet that
  hand your signed-in Defender session into the locked-down container (no interactive
  browser needed inside it).
- **Azure CLI** — baked in, for enumerating Sentinel / Log Analytics workspaces + tables
  (for customers who log to Sentinel instead of Defender).

End goal: build a per-customer map of **what telemetry lives where** (Defender advanced-
hunting tables vs Sentinel/Log Analytics tables), with volume/recency.

---

## 2. Git safety (how "don't leak" is enforced)

`origin` is the **public** `https://github.com/MSCloudInternals/XDRInternals/`. To keep our
work out of it:

- New files (Dockerfile, `docker/`, the cmdlet, this file, `*.csv`, `*.local.md`) are listed
  in **`.git/info/exclude`** — a local ignore file that is itself never pushed.
- The two upstream files we edited are flagged **skip-worktree** so git ignores our local
  changes:
  - `README.md`
  - `XDRInternals/XDRInternals.psd1` (adds `Connect-XdrByBrowserExtension` to
    `FunctionsToExport` — needed for the module to export the cmdlet)

**Check it's still safe:** `git status` should be empty. If our files ever show up, re-run:

```bash
git update-index --skip-worktree README.md XDRInternals/XDRInternals.psd1
# and confirm .git/info/exclude still lists our files
```

**To see the "hidden" tracked edits again:** `git ls-files -v | grep '^S'`
**To undo skip-worktree** (e.g. if a future `git pull` conflicts on those files):
`git update-index --no-skip-worktree README.md XDRInternals/XDRInternals.psd1`

Caveat: if upstream later changes `README.md` or the psd1, a `git pull` may complain about
the skip-worktree files. Resolve by temporarily `--no-skip-worktree`, stashing our edits,
pulling, reapplying.

---

## 3. Build & run the container

```bash
# from repo root: C:\Users\benjamin.saxon\XDRInternals
docker compose build                                   # rebuild after ANY code change
docker compose run --rm --service-ports xdrinternals   # interactive pwsh session
```

**Gotchas (learned the hard way):**

- `docker compose run` does **NOT** rebuild — run `docker compose build` first whenever
  code changed, or you'll run a stale image (symptom: old log messages / old behaviour).
- `docker compose run` does **NOT** publish ports by default — you must pass
  `--service-ports` (compose file maps `127.0.0.1:8787:8787`). Without it the browser relay
  can't reach the container ("Failed to fetch").
- The container needs `NET_ADMIN` + `NET_RAW` (already in compose `cap_add`) to build the
  firewall. Without them it **refuses to start** (fail-closed). Override only for debugging
  with `-e XDR_DISABLE_FIREWALL=1`.

---

## 4. Defender XDR auth — browser relay

The interactive/CDN-heavy sign-in happens in your **host** Chrome; only the session cookie
crosses into the container. One-time extension setup:

1. `chrome://extensions` → Developer mode → **Load unpacked** →
   `C:\Users\benjamin.saxon\XDRInternals\docker\browser-extension`
2. On its card → **Details** → enable **"Allow in Incognito"**.

Each session:

1. Container: `Connect-XdrByBrowserExtension` → prints a one-time pairing code, waits.
2. Chrome: sign in to `security.microsoft.com` (Incognito is more reliable — see below),
   click the extension, paste the code, port `8787`, **Relay session to container**.
3. Container establishes the session and prints the connected tenant:
   ```
   Connected tenant context:
     Tenant:    Cybanetix Ltd
     Account:   you@cybanetix.com
     Tenant ID: 5f6cb372-...
   ```

**Why it works (and the 50058 saga):** the module has two credentials —
`ESTSAUTH` (login.microsoftonline.com) is only a *bootstrap* that re-runs silent SSO and
often fails with **AADSTS50058 "session information is not sufficient for single-sign-on"**;
`sccauth` (security.microsoft.com) is the *actual portal session*, replayed directly with no
silent SSO. The extension grabs `sccauth` + `XSRF-TOKEN` (falls back to `ESTSAUTH`) and the
cmdlet routes through `Connect-XdrAuthArtifactSet -ConnectionPreference PreferPortal`, i.e.
the module's own working path (same as `Connect-XdrByBrowser`).

**MSSP tenant switching:** switch customer in the browser → re-run
`Connect-XdrByBrowserExtension` → relay again. Session/headers are fully replaced each time
and the cache is tenant-scoped (`<tenantId>_<key>`), so no cross-customer bleed. Always
eyeball the printed **Tenant:** line to confirm the right customer. For parallel customers,
run multiple containers on different ports (`--service-ports` + change
`Connect-XdrByBrowserExtension -Port` and the compose `ports:` / extension port field).

`Connect-XdrByBrowser` (spawns its own Chromium) is **not** supported in the container — use
the relay, or `Connect-XdrByEstsCookie` / `-BySoftwarePasskey` / `-ByTemporaryAccessPass`.

---

## 5. Defender table mapping

```powershell
$tables = Get-XdrAdvancedHuntingTableSchema

# name / retention / desc / schema (+ HasData flag)
$tables | Select-Object Name, HasData,
    @{N='Retention';E={ if ($_.TableRetention) { "Hot:$($_.TableRetention.HotDays)/Cold:$($_.TableRetention.ColdDays)/Total:$($_.TableRetention.TotalInteractiveDays)" } }},
    Description,
    @{N='Schema';E={ $_.Schema.Name -join ', ' }} | Format-Table -Wrap
```

Live row-count probe (definitive "has data", per table). Runs one advanced-hunting query
each — mind AH rate limits; the `Start-Sleep` throttles it:

```powershell
$probe = foreach ($t in $tables) {
    $rows = $null
    try {
        $r = Invoke-XdrMtoAdvancedHunting -QueryText "$($t.Name) | summarize Rows = count()" `
             -DaysAgo 30 -ErrorAction Stop -WarningAction SilentlyContinue
        $rows = [int64]$r.Rows
    } catch { $rows = "error" }
    [pscustomobject]@{ Name=$t.Name; HasDataFlag=$t.HasData; Rows30d=$rows }
    Start-Sleep -Milliseconds 500
}
$probe | Where-Object { ($_.Rows30d -as [int64]) -gt 0 } | Sort-Object { $_.Rows30d -as [int64] } -Descending | Format-Table -Auto
```

Note: `Invoke-XdrMtoAdvancedHunting` is the only query executor exported; it defaults to the
current cached tenant (prints a benign "No tenant list found in cache" warning on a single
tenant) and uses `mto.security.microsoft.com` (allowlisted). Use `summarize Rows = count()`
not `| count` — PowerShell's intrinsic `.Count` collides with a `Count` column.

---

## 6. Sentinel / Log Analytics mapping (az)

**Auth:** `az login --use-device-code` (headless — plain `az login` won't work in the
container). Visit the URL in host browser, enter the code. Picks up Lighthouse-delegated
customer subs too.

**Discover workspaces across all customers (control plane, free):**

```powershell
$wsResult = az graph query --first 1000 -o json -q @"
resources
| where type =~ 'microsoft.operationalinsights/workspaces'
| join kind=leftouter (resourcecontainers | where type=~'microsoft.resources/subscriptions' | project subscriptionId, subName=name) on subscriptionId
| project subName, name, resourceGroup, location, id
| order by subName asc, name asc
"@ | ConvertFrom-Json
$workspaces = $wsResult.data
$workspaces | Format-Table subName, name, resourceGroup, location -Auto
```

(`az graph query -o table` shows only `count/total_records` — reach into `.data`.)

**List a workspace's tables + metadata (control plane, free):**

```powershell
$uri = "https://management.azure.com$($ws.id)/tables?api-version=2022-10-01"
$tables = (az rest --method get --url $uri -o json | ConvertFrom-Json).value
$tables | Select-Object @{N='Name';E={$_.name}}, @{N='Plan';E={$_.properties.plan}},
    @{N='RetentionD';E={$_.properties.retentionInDays}},
    @{N='Columns';E={@($_.properties.schema.columns).Count}},
    @{N='TableType';E={$_.properties.schema.tableType}} | Sort-Object Name | Format-Table -Auto
```

**IMPORTANT — the catalog trap:** ARM `/tables` returns the *entire* Log Analytics table
catalog (~600 Microsoft tables, mostly empty), not just what the workspace uses. Don't treat
that list as the footprint.

**Real footprint = the `Usage` metering table (cheap; does NOT scan data):**

```powershell
az monitor log-analytics query `
  --workspace <workspace CustomerId GUID> `
  --analytics-query "Usage | where TimeGenerated > ago(30d) | summarize GB = round(sum(Quantity)/1000.0, 2), LastSeen = max(TimeGenerated) by DataType | order by GB desc" `
  -o table
```

- Use the workspace **CustomerId** GUID (from `az monitor log-analytics workspace list`), not
  the resource name.
- **NEVER** run `search *` / `union *` across a workspace — *those* scan everything and burn
  CPU/cost. `Usage` is the safe signal.
- If empty, add `--timespan P30D`.

---

## 7. Firewall allowlist (docker/init-firewall.sh)

Egress is default-DROP; only these (and their subdomains, via a local dnsmasq→ipset) are
allowed, plus DNS to 1.1.1.1/8.8.8.8. IPv6 is dropped entirely.

```
security.microsoft.com        login.microsoftonline.com   login.microsoft.com
graph.microsoft.com           management.azure.com        management.core.windows.net
vault.azure.net               mysignins.microsoft.com     kusto.windows.net
ods.opinsights.azure.com      api.loganalytics.io         api.loganalytics.azure.com
(+ 169.254.169.254 Azure IMDS)
```

Add more at runtime without editing the file: `-e XDR_ALLOWED_DOMAINS="host1 host2"`
(e.g. a customer's private DNS zone / specific ADX cluster). `mto.security.microsoft.com`
is covered by the `security.microsoft.com` suffix match.

---

## 8. Cybanetix reference IDs (own tenant)

- Tenant: **Cybanetix Ltd** — `5f6cb372-3153-4b59-b2ab-e833d35c6b61`
- Subscription: **CX-Main-Sub** — `dd143828-655a-4880-b477-ecbfebc81076`
- Sentinel workspace: **SIEM** (RG `SecurityRG`, uksouth, 30d) —
  CustomerId `a7ebc4c4-cc68-46bf-9cbe-2c7a20beaa6a`
  - (`llama5524220209` in the same sub looks like an auto-generated default — ignore.)

**Do not put other customers' IDs (from the 71-workspace Lighthouse list) into any file that
could be committed.** This file is excluded, so it's fine here.

---

## 9. Next steps / TODO

- [ ] Build the combined collector: per customer → platform (Defender/Sentinel) → table →
      metadata (plan/retention) + volume/recency (`Rows30d` for Defender, `Usage` GB for
      Sentinel), exported per-customer to CSV/JSON. (Decide output shape first.)
- [ ] Decide how to tell which of the 71 workspaces are actually Sentinel-enabled (tell:
      presence of `SecurityIncident`/`SecurityAlert`, or the SecurityInsights solution).
- [ ] Optional: persist `az login` / relay session across container restarts via a mounted
      volume (writes tokens to disk — left off by default for safety).
- [ ] Optional: have the mapper iterate Lighthouse-delegated subs and roll up a single map.

## 10. Files we added (all local-only)

```
Dockerfile                                        # PS7 + firewall tooling + az CLI + module
.dockerignore
docker-compose.yml                                # cap_add, 127.0.0.1:8787 port, XDR_ALLOWED_DOMAINS
docker/init-firewall.sh                           # egress allowlist (iptables/ipset/dnsmasq)
docker/entrypoint.sh                              # runs firewall then the CMD (fail-closed)
docker/browser-extension/{manifest.json,popup.html,popup.js}   # XDR Docker Relay (Chrome)
XDRInternals/functions/Connect-XdrByBrowserExtension.ps1        # relay listener cmdlet
NOTES.local.md                                    # this file
# edited (skip-worktree): README.md, XDRInternals/XDRInternals.psd1
```
