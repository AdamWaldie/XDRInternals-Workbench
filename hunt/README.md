# NetScaler hunt: WHIPSHOT / SLAPSHOT and nsaaad username injection

Hunted on 2026-10-07 over 45 days. The only NetScaler source we found was ASOS:
subscription AsosSecurityAuditNonProd, workspace `SecurityAuditLogAnalyticsTest`,
table `Netscaler_CL`, workspace ID `d20fd9e2-c143-4ac6-a7ba-e130b75b3c04`.
It holds two appliances: `pdeunctxns00` and `pdeuwctxns00`.

## Run

```bash
az monitor log-analytics query -w <workspaceId> --analytics-query "$(cat 09_username_command_injection.kql)" --timespan P46D -o json
```

To list every workspace before running `00_discover_netscaler_sources.kql` on each one:

```bash
az graph query -q "resources | where type =~ 'microsoft.operationalinsights/workspaces' | project name, subscriptionId, customerId=properties.customerId" --first 500
```

## Queries

| File | Purpose | Result on 2026-10-07 |
|---|---|---|
| 00 | Find where NetScaler logs are stored | Only ASOS `Netscaler_CL` |
| 01 | WHIPSHOT campaign IOC IPs | None |
| 02 | WHIPSHOT/SLAPSHOT strings, httpd handler changes, plugin and theme paths | One `cp AGEE_setup.exe` into `vpns/scripts/vista` on 10-06; confirm with ASOS |
| 03 / 03b | SSL handshake failures, DTLSv1.0 | No DTLSv1.0 |
| 04 | Pitboss crashes and HA changes | Found the injection and the nsaaad crashes on 10-03 |
| 05 | Admin command history | Plugin replacement, backup, forced failover, interactive shells |
| 09 | Command injection through the username field | **598 attempts** between 10-03 and 10-07; still ongoing |
| 10 | nsaaad crash timeline | Crashes and nCore restarts on 10-03 (pdeuwctxns00) |
| 12 / 14 | Source IPs | 213.209.159.55 directly; later attempts arrive through proxied 20.105.0.122 |

## IOCs found in this hunt
- 213.209.159.55 (`fetch` stager on port 443)
- 45.137.99.92:8080 (`wget` callback)
- v5v.in (`curl | sh`)
- `/var/netscaler/logon/LogonPoint/a` (packed copy of `/flash/nsconfig` that the web server can serve)

## Query tips
- `last` and `first` are reserved words in KQL. Don't use them as column aliases.
- `has "NSPPE"` misses the `diedNSPPE` variant because `has` matches whole terms. Use `contains`.

## Did the injected commands run? (checked 2026-10-07)
| File | Purpose | Result |
|---|---|---|
| 15 | Outbound connections from NetScaler IPs to public addresses | None to 213.209.159.55 or 45.137.99.92 |
| 16 | IOC search across every table in the ASOS workspaces | Hits only in `Netscaler_CL` (inbound attempts) and one Teams message from an ASOS user |

Execution is not confirmed. It needs checking on the appliances themselves: `/var/netscaler/logon/LogonPoint/a`, `/v`, `httpaccess.log`, the core files from 10-03, and egress firewall logs.

## Post-exploitation log checks (2026-10-07)
| File | Purpose | Result |
|---|---|---|
| 17 | nsaaad response to injection attempts vs normal logins | Identical (`aaad-resp 8`, flags 0) |
| 18 | Commands since the attack | Only admin/IR activity; failed `login nsroot` from 127.0.0.1 happens at every restart or failover |
| 19 | New VPN user/IP pairs | All asos.com accounts from UK IPs; explained by traffic moving to the North node |

`onbox_triage.sh` is a read-only script for ASOS to run on each node. It confirms or rules out execution.

## DNS hunt for v5v.in (2026-10-07, 45 days, all 34 workspaces)
- `20` found no DNS or URL hits for `v5v.in` or any subdomain in any workspace.
- `21` shows where DNS or URL logs exist: ASOS Prod (Defender for Endpoint), ASOS Test (FortiGate CEF), CX, FTH, Elkjop, ERM (Zscaler), CPL and HL. Other workspaces have no DNS logs, so a clean result there means nothing.
- `22` (ASOS FortiGate) found no traffic to or from 213.209.159.55 or 45.137.99.92. The FortiGate sees the NetScaler SNIPs (.165) but **not** the management IPs (.150), so callbacks from the management side would not be visible here.

## Assessment-report IOCs in ASOS (2026-10-07)
- **SIEM coverage:** only `pdeuwctxns00` (10.82.0.150, since 23 Aug) and `pdeunctxns00` (10.81.0.150, since **6 Oct 10:03**). `pdeunctxns01` and `pdeuwctxns01` (.151) send nothing. `httpaccess` and DTLS records are not forwarded.
- **23:** polling IPs, scanners and 194.127.166.0/24 seen inbound. 194.127.166.0/24 goes back to **24 Aug**, a month before the report's 24 Sep. 45.137.99.92 was the source of its own `wget` injection on 10-06 23:16. No forged-SAML, q8k1vi or vadmv1 strings in the SIEM.
- **24 and 25:** zero hits. No traffic to or from any IOC IP in FortiGate, Defender, Entra or email, including 81.94.239.8:8877.
- **27 and 28:** no DTLS in the feed. EUW restarts on 30 Sep, 1 Oct and 5–6 Oct match the upgrades. Restarts on 3 Oct follow nsaaad crashes, with no NSPPE crash.

## Correction (2026-10-08): coverage over full retention
- All four nodes have sent logs to Sentinel at some point. `pdeuwctxns01` stopped on **27 Mar 2026** and `pdeunctxns01` on **15 Apr 2026**. `pdeunctxns00` had a **173-day gap** (15 Apr to 6 Oct 2026). `pdeuwctxns00` is missing **29 Sep** and **4 Oct**.
- Build history from the SIEM (`30`) only exists for `pdeuwctxns00`: 63.18 (14 Jul), 64.24 (30 Sep), 64.28 (5 Oct). EUN's build cannot be confirmed from the SIEM.
