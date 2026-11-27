# Troubleshooting

Read this when the verify step (SKILL.md step 4) reports a FAIL, or a wrapper call or relay misbehaves.


When standup fails, a call misbehaves, or the user asks for help with setup, run the diagnostics before guessing:

```bash
pwsh -NoProfile -File tools/agent/Test-XdrWorkbench.ps1 -Live -Json
```

It checks pwsh and the module, the tenant list, the relay port and URL reservation, Chrome and the relay extension (installed, enabled; incognito access only matters with `-Incognito`), both extension copies, each saved session (tenant, age against the 12-hour limit, git-ignore status, permissions), `.dockerignore`, tracked case data, reachability of security.microsoft.com and mto.security.microsoft.com, and with `-Live` one read-only call through the wrapper. Each failure carries its fix. Run it on the user's machine for the Chrome and Windows checks; in a Linux shell those are skipped. Exit 1 means at least one FAIL.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `CLOUD SESSION` (wrapper exit 9), or `Test-XdrWorkbench` row `where` FAIL | Claude runs in a Claude Code cloud container, which can't reach the relay, the session or the portal | Stop. The analyst opens a Local Claude Code session on the repo folder. Don't hand them commands to run instead |
| `Failed to listen on port(s) 8787, ...` | Every port in 8787-8796 is held, or `-Port` was given and that port is held | Close stale standup windows; leave out `-Port` |
| Extension "No standup is waiting" or "Failed to fetch" (1.2) | Standup not running or closed, cloud session, or for Docker a container without `--service-ports` | Run the standup on this computer and relay from its window; Docker: `docker compose run --rm --service-ports xdrinternals` |
| Standup waiting, extension (1.4+) says "no answer within 1.5 s" (2.5 s from 1.5) or "connection refused or blocked" | The listener isn't answering, or Chrome blocks the extension | Read `%TEMP%\xdr-relay-listener.log` first (rewritten by each standup; never holds the code or cookies): it logs every connection and request, a heartbeat every 15 s, and `listener stopping: <reason>`. No `request GET /health` lines means the probes never reached it. A standup window started before a fix still runs the old code: close it and rerun. Otherwise open the health URL the standup prints (`http://127.0.0.1:<port>/health`) in a Chrome tab. Shows `xdr-workbench-relay`: Chrome blocks the extension (policy, proxy); reload it at `chrome://extensions`. Doesn't: check `Get-NetTCPConnection -LocalPort <port> -State Listen` shows the standup's pwsh PID. Standups before the TCP listener used HTTP.sys, which could intermittently stall (suspected third-party firewall, e.g. Norton 360): requests reached HTTP.sys and never the queue |
| Relay sends nothing, or a session for the wrong account | Extension clicked from a different window than the one signed in to the customer, or (with `-Incognito`) not allowed in Incognito | Click the extension from the window the standup opened; for `-Incognito`, turn on chrome://extensions > XDR Docker Relay > Details > Allow in Incognito |
| Banner shows the wrong customer | Portal opens in the last-used tenant; `?tid=` doesn't travel with the cookie | The standup sets an MTO case lock when the customer is reachable; otherwise switch tenant in the portal window and rerun |
| Hunting fails with `440 Session timeout` (wrapper exit 8, `HUNT SESSION TIMEOUT`) while tenant context and other cmdlets work | The MTO endpoint (mto.security.microsoft.com) has no session it accepts. Before extension 1.2 the relay never carried one | Direct mode: the wrapper already routes hunts to `Invoke-XdrAdvancedHunting` when the module has it. MTO mode: reload the extension (1.2+), open the MTO tab in the portal window, and relay again. The full method is in `hunting-outage.md` |
| `PORTAL SESSION TIMEOUT (440)`, wrapper exit 4 | The portal rejected the saved session on a non-hunting call | Rerun the standup |
| Standup ends with `Hunting: FAILED` and a `Fix:` line (exit 2) | The control hunt failed after up to three automatic retries | The user applies the `Fix`, then runs the relay-again command the standup printed; `hunting-outage.md` explains each `HuntCheck` value |
| `Test-XdrWorkbench.ps1` says "No problems found" but hunts fail | Run without `-Live`, so no hunting endpoint was called | Rerun with `-Live`: the control hunt runs on the case's route, and in direct mode a separate `mto hunt` row probes MTO |
| Hunting fails with 403 and `AADSTS53000` (device not compliant), while other calls work | The session was relayed from Incognito, which carries no device identity; the account's Conditional Access requires a compliant device for the MTO hunting endpoint | Rerun the standup without `-Incognito`, signing in from the normal Chrome profile |
| AADSTS50058 | Only the Entra cookie relayed, because the portal hadn't finished loading | Wait for Advanced Hunting to load in the portal window, then relay again |
| Wrapper can't find a session the standup saved | Standup and wrapper ran from different clones | Use the clone the standup ran in (Locating the repo, above), or set `XDR_SESSION_PATH` |
| Wrapper exit 4 | No session, or older than 12 hours | Rerun the standup |
| Wrapper exit 7, `TENANT GUARD` | Hunt named a tenant other than the case lock, several tenants without `-AllowMultiTenant`, an entity cmdlet in an MTO case, or rows from an unnamed tenant | Stop and confirm the tenant with the user (`multi-tenant.md`) |
| `TENANT NOT SEARCHED`, exit 2 | That customer refused the hunt (MFA or Conditional Access challenge, missing role, quota) | Report it as not searched; the user satisfies the challenge for that tenant in the portal, then rerun |
| 403 on one cmdlet, others fine | The analyst's role in that customer tenant doesn't cover that API (the AH schema call is a common one) | Use the KQL fallback in `hunting.md`, or ask the customer for the role |
| `Argument types do not match` from the wrapper | Older wrapper on PowerShell 7.4 (`@()` around a generic List) | Update `tools/agent/Invoke-XdrAgent.ps1`; this checkout emits with `.ToArray()` |

If the cause isn't listed: reproduce with the smallest command through the wrapper, read stderr and the exit code, check the cmdlet's page in `usage/`, then read the module function before changing anything. Tell the user what failed, the evidence, and the fix.
