# Troubleshooting

Read this when the verify step (SKILL.md step 4) reports a FAIL, or a wrapper call or relay misbehaves.


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
| Relay sends nothing, or a session for the wrong account | Extension clicked from a different window than the one signed in to the customer, or (with `-Incognito`) not allowed in Incognito | Click the extension from the window the standup opened; for `-Incognito`, turn on chrome://extensions > XDR Docker Relay > Details > Allow in Incognito |
| Banner shows the wrong customer | Portal opens in the last-used tenant; `?tid=` doesn't travel with the cookie | The standup sets an MTO case lock when the customer is reachable; otherwise switch tenant in the portal window and rerun |
| Hunting fails with 403 and `AADSTS53000` (device not compliant), while other calls work | The session was relayed from Incognito, which carries no device identity; the account's Conditional Access requires a compliant device for the MTO hunting endpoint | Rerun the standup without `-Incognito`, signing in from the normal Chrome profile |
| AADSTS50058 | Only the Entra cookie relayed, because the portal hadn't finished loading | Wait for Advanced Hunting to load in the portal window, then relay again |
| Wrapper can't find a session the standup saved | Standup and wrapper ran from different clones | Use the clone the standup ran in (Locating the repo, above), or set `XDR_SESSION_PATH` |
| Wrapper exit 4 | No session, or older than 12 hours | Rerun the standup |
| Wrapper exit 7, `TENANT GUARD` | Hunt named a tenant other than the case lock, several tenants without `-AllowMultiTenant`, an entity cmdlet in an MTO case, or rows from an unnamed tenant | Stop and confirm the tenant with the user (`multi-tenant.md`) |
| `TENANT NOT SEARCHED`, exit 2 | That customer refused the hunt (MFA or Conditional Access challenge, missing role, quota) | Report it as not searched; the user satisfies the challenge for that tenant in the portal, then rerun |
| 403 on one cmdlet, others fine | The analyst's role in that customer tenant doesn't cover that API (the AH schema call is a common one) | Use the KQL fallback in `hunting.md`, or ask the customer for the role |
| `Argument types do not match` from the wrapper | Older wrapper on PowerShell 7.4 (`@()` around a generic List) | Update `tools/agent/Invoke-XdrAgent.ps1`; this checkout emits with `.ToArray()` |

If the cause isn't listed: reproduce with the smallest command through the wrapper, read stderr and the exit code, check the cmdlet's page in `usage/`, then read the module function before changing anything. Tell the user what failed, the evidence, and the fix.
