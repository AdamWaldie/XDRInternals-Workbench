# Session, tenant and MTO

13 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Connect-XdrByBrowser

Guard: `blocked`

Authenticates to Microsoft Defender XDR using an interactive browser sign-in.

Launches a dedicated Chromium-based browser profile, waits for you to complete the
browser sign-in flow, captures the resulting authentication cookies, and establishes
the Defender XDR session.

This browser-driven flow is intended for interactive authentication branches such as
FIDO2/passkeys and Temporary Access Pass.

By default the cmdlet uses a dedicated secondary Chromium profile named XDRInternals so
browser and device state can participate in authentication without reusing the user's
primary profile. That dedicated profile is configured to open cleanly instead of restoring
tabs from previous runs.

On macOS and Linux, this cmdlet remains interactive. Complete any browser prompts until
Microsoft Defender XDR finishes loading so the cmdlet can capture the final session cookies.

```powershell
Connect-XdrByBrowser [-Username <String>] [-TenantId <String>] [-TimeoutSeconds <Int32>] [-BrowserPath <String>] [-ProfilePath <String>] [-ResetProfile] [-PrivateSession] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Username | String |  |  | Optional username to display while completing the browser sign-in. If omitted, the browser sign-in flow lets you choose an account interactively. |
| -TenantId | String |  |  | Optional tenant ID to use when bootstrapping the Defender XDR session. |
| -TimeoutSeconds | Int32 |  | 300 | Maximum time to wait for the browser sign-in to complete. |
| -BrowserPath | String |  |  | Optional browser executable path or command name. When omitted, a supported Chromium-based browser is auto-discovered. |
| -ProfilePath | String |  |  | Optional dedicated browser user data directory. When omitted, a default secondary profile location is used for the XDRInternals profile. |
| -ResetProfile | SwitchParameter |  | False | Clears the dedicated browser profile before launching the sign-in flow. |
| -PrivateSession | SwitchParameter |  | False | Uses a temporary private/incognito browser session instead of the default dedicated profile. |
| -UserAgent | String |  |  | Optional User-Agent override for the launched browser. |

Example 1:

```powershell
Connect-XdrByBrowser -Username 'admin@contoso.com'
```

Launches the browser sign-in flow and connects to Defender XDR.

## Connect-XdrByBrowserExtension

Guard: `blocked`

Authenticates to Microsoft Defender XDR by relaying a session from the XDR Docker Relay browser extension.

Starts a short-lived HTTP listener and waits for the XDR Docker Relay Chrome
extension (docker/browser-extension in this repo) to POST the browser's Defender
session artifacts to it, then establishes the Defender XDR session from them.

The extension sends whichever it can read: the Defender portal session cookie
(sccauth, plus XSRF-TOKEN) from security.microsoft.com and/or the ESTSAUTH cookie
from login.microsoftonline.com. These are routed through the module's shared
Connect-XdrAuthArtifactSet handler, which prefers the portal session cookie - that
one is replayed directly and avoids Entra's silent SSO re-exchange (and the
"session information is not sufficient for single-sign-on" / 50058 failure it often
raises) - and falls back to the ESTS bootstrap when only that cookie is available.

On success it prints the connected tenant (organization name, signed-in account, and
tenant ID) so switch-heavy workflows, such as an MSSP moving between customer
tenants, can confirm the intended tenant before running further cmdlets.

This exists so a locked-down container (for example one whose outbound network is
restricted to Defender XDR/Entra ID endpoints, as with this repo's Dockerfile) never
has to perform the interactive sign-in itself. The sign-in happens in your normal,
already-authenticated Chrome profile on the host; only the resulting session cookie
crosses into the container.

Each call generates a random one-time pairing code that must be entered in the
extension's popup. The listener accepts exactly one correctly-paired request and then
stops, so a leaked or reused code has a single, short window in which it is valid.

The listener itself binds to all interfaces inside the container; the "only reachable
from this machine" guarantee comes from publishing the port to the host's loopback
interface only when starting the container, e.g. `-p 127.0.0.1:8787:8787` (a bind
address of 127.0.0.1 inside the container would not receive Docker's published
traffic, which arrives via the container's bridge interface).

```powershell
Connect-XdrByBrowserExtension [-Port <Int32>] [-TimeoutSeconds <Int32>] [-TenantId <String>] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Port | Int32 |  | 8787 | The port to listen on. Must match the port configured in the browser extension's popup and the port published by `docker run`/`docker compose`. |
| -TimeoutSeconds | Int32 |  | 300 | Maximum time to wait for the browser extension to relay a session. |
| -TenantId | String |  |  | Optional tenant ID to use when bootstrapping the Defender XDR session. |
| -UserAgent | String |  |  | The User-Agent string to use for the web requests. This only matters on the ESTS bootstrap fallback path, where Entra can tie session validity to the browser fingerprint that issued the cookie. By default, uses whatever navigator.userAgent the relayed browser sent, falling back to Get-XdrDefaultUserAgent if the extension didn't send one. Pass this explicitly to override either. |

Example 1:

```powershell
Connect-XdrByBrowserExtension
```

Listens on 127.0.0.1:8787, prints a pairing code, and waits up to 5 minutes for the XDR Docker Relay extension to relay a session.

Example 2:

```powershell
Connect-XdrByBrowserExtension -Port 9191 -TimeoutSeconds 120
```

Listens on a non-default port with a shorter timeout.

## Connect-XdrByCredential

Guard: `blocked`

Authenticates to Microsoft Defender XDR using username, password, and optional TOTP MFA.

Performs a full Entra ID web login flow programmatically (no browser required),
handling password submission and MFA challenges, then establishes an authenticated
session to the Defender XDR portal.

Supported MFA methods:
  - PhoneAppOTP: Authenticator app TOTP code (computed automatically from -TotpSecret)
  - PhoneAppNotification: Push notification (polls for user approval, displays number match)
  - OneWaySMS: SMS code (prompts user to enter code from phone)

The authentication chain is:
  1. Submit credentials to Entra ID web login endpoints
  2. Handle MFA via SAS (Server Authentication State) endpoints
  3. Extract ESTSAUTH cookie from the completed login
  4. Pass ESTSAUTH cookie to Connect-XdrByEstsCookie to get sccauth + XSRF-TOKEN

Note: This method may be blocked by Conditional Access policies that require
device compliance or a specific client application. It will work with MFA-only policies.

```powershell
Connect-XdrByCredential [-TotpSecret <String>] [-MfaMethod <String>] [-TenantId <String>] [-UserAgent <String>]
Connect-XdrByCredential [-Credential <PSCredential>] [-TotpSecret <String>] [-MfaMethod <String>] [-TenantId <String>] [-UserAgent <String>]
Connect-XdrByCredential [-Username <String>] [-Password <SecureString>] [-TotpSecret <String>] [-MfaMethod <String>] [-TenantId <String>] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Credential | PSCredential |  |  | A PSCredential object containing username and password. When provided, -Username and -Password are ignored. If no parameters are provided at all, you will be prompted interactively for credentials. |
| -Username | String |  |  | The user principal name (e.g., admin@contoso.com). Not needed if -Credential is used. |
| -Password | SecureString |  |  | The password as a SecureString. Not needed if -Credential is used. If you have a plain string, convert it: $pw = ConvertTo-SecureString "MyPassword" -AsPlainText -Force |
| -TotpSecret | String |  |  | Base32-encoded TOTP secret for automatic MFA code generation. This is the secret from the QR code when setting up Microsoft Authenticator (otpauth://totp/...?secret=JBSWY3DPEHPK3PXP). If not provided and MFA is required, the function will attempt push notification or prompt for a code. |
| -MfaMethod | String |  |  | Preferred MFA method. Valid values: PhoneAppOTP, PhoneAppNotification, OneWaySMS. If not specified, the function auto-selects PhoneAppOTP only when -TotpSecret is provided and that method is actually offered. When multiple supported inline methods are available, you are prompted to choose. Values: PhoneAppOTP, PhoneAppNotification, OneWaySMS |
| -TenantId | String |  |  | The Defender XDR tenant ID to connect to. If not provided, the default tenant is used. |
| -UserAgent | String |  | (Get-XdrDefaultUserAgent) | User-Agent string for HTTP requests. Defaults to a browser-compatible Edge user agent. |

Example 1:

```powershell
Connect-XdrByCredential
```

Prompts interactively for username and password, then authenticates. If MFA is required, push notification or SMS prompt will be used.

Example 2:

```powershell
Connect-XdrByCredential -TotpSecret "JBSWY3DPEHPK3PXP"
```

Prompts interactively for username and password, then handles MFA automatically via TOTP.

Example 3:

```powershell
Connect-XdrByCredential -Credential (Get-Credential) -TotpSecret "JBSWY3DPEHPK3PXP"
```

Uses the Get-Credential dialog for username/password, then auto-completes TOTP MFA.

Example 4:

```powershell
$pw = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
Connect-XdrByCredential -Username "admin@contoso.com" -Password $pw -TotpSecret "JBSWY3DPEHPK3PXP"
```

Fully non-interactive: all credentials and MFA passed as parameters.

Example 5:

```powershell
Connect-XdrByCredential -Credential (Get-Credential) -TotpSecret "JBSWY3DPEHPK3PXP" -TenantId "8612f621-73ca-4c12-973c-0da732bc44c2"
```

Authenticates and connects to a specific XDR tenant.

## Connect-XdrByEstsCookie

Guard: `blocked`

Establishes an authenticated session to the Microsoft Defender XDR portal.

Connects to security.microsoft.com using an ESTSAUTH cookie value to establish
an authenticated web session. This function creates global session and headers variables
that can be used by other XDR cmdlets to interact with the portal APIs.

You can provide the cookie value as either a plain string or as a secure string.

```powershell
Connect-XdrByEstsCookie -EstsAuthCookieValue <String> [-TenantId <String>] [-UserAgent <String>]
Connect-XdrByEstsCookie -SecureEstsAuthCookieValue <SecureString> [-TenantId <String>] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -EstsAuthCookieValue | String | yes |  | The ESTSAUTH cookie value from an authenticated browser session as a plain string. Use this parameter set when you have the cookie as a plain text value. |
| -SecureEstsAuthCookieValue | SecureString | yes |  | The ESTSAUTH cookie value from an authenticated browser session as a secure string. Use this parameter set when you want to pass the cookie value securely (e.g., from credential object). |
| -TenantId | String |  |  | The Tenant ID to use for the connection. If not provided, the default tenant will be used. |
| -UserAgent | String |  | (Get-XdrDefaultUserAgent) | The User-Agent string to use for the web requests. By default, uses the value returned by Get-XdrDefaultUserAgent. |

Example 1:

```powershell
Connect-XdrByEstsCookie -EstsAuthCookieValue "your_cookie_value_here"
```

Connects to the XDR portal using the provided authentication cookie as plain text.

Example 2:

```powershell
$secureCookie = ConvertTo-SecureString -String "your_cookie_value_here" -AsPlainText -Force
Connect-XdrByEstsCookie -SecureEstsAuthCookieValue $secureCookie
```

Connects to the XDR portal using the provided authentication cookie as a secure string.

Example 3:

```powershell
Read-Host -AsSecureString "Enter ESTSAUTH cookie" | Connect-XdrByEstsCookie
```

Prompts for the cookie value securely via pipeline and connects to the XDR portal.

## Connect-XdrByPhoneSignIn

Guard: `blocked`

Authenticates to Microsoft Defender XDR using Microsoft Authenticator phone sign-in.

Starts the Defender portal phone sign-in flow without launching a browser, shows the
number returned by Entra ID when available, waits for Microsoft Authenticator approval,
captures the resulting ESTSAUTH cookie, and then passes it to Connect-XdrByEstsCookie
to establish the Defender XDR session.

```powershell
Connect-XdrByPhoneSignIn [-Username <String>] [-TenantId <String>] [-TimeoutSeconds <Int32>] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Username | String |  |  | Optional username to use for phone sign-in. If omitted, you are prompted interactively. |
| -TenantId | String |  |  | Optional tenant ID to use when bootstrapping the Defender XDR session. |
| -TimeoutSeconds | Int32 |  | 300 | Maximum time to wait for the phone sign-in approval to complete. |
| -UserAgent | String |  | (Get-XdrDefaultUserAgent) | User-Agent string for HTTP requests. Defaults to a browser-compatible Edge user agent. |

Example 1:

```powershell
Connect-XdrByPhoneSignIn -Username 'admin@contoso.com'
```

Starts the headless phone sign-in flow and connects to Defender XDR.

Example 2:

```powershell
Connect-XdrByPhoneSignIn -Username 'admin@contoso.com' -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2'
```

Starts the headless phone sign-in flow and connects to the specified tenant.

## Connect-XdrBySoftwarePasskey

Guard: `blocked`

Authenticates to Microsoft Defender XDR using a software passkey.

Performs passkey (FIDO2/WebAuthn) authentication against Microsoft Entra ID using a credential
stored in a JSON file, then establishes an authenticated session to the Defender XDR portal.

Two passkey types are supported, auto-detected from the credential file:

**Local passkey**  -  the JSON file contains a privateKey field (PEM-encoded EC private key).
No additional parameters are needed.

**Azure Key Vault passkey**  -  the JSON file contains a keyVault object (vaultName, keyName).
The private key never leaves the HSM. A Key Vault access token is obtained automatically
by trying (in order):
  1. Az module: Get-AzAccessToken (if Az.Accounts is loaded and you are signed in)
  2. Azure CLI: az account get-access-token (if az is on PATH and you are signed in)
  3. IMDS managed identity: system-assigned (default) or user-assigned (-KeyVaultClientId)

Requires PowerShell 7.0 or later for ECDsa PEM key support.

```powershell
Connect-XdrBySoftwarePasskey -KeyFilePath <String> [-TenantId <String>] [-KeyVaultTenantId <String>] [-KeyVaultClientId <String>] [-KeyVaultApiVersion <String>] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -KeyFilePath | String | yes |  | Path to a JSON credential file. For local passkeys, the file must contain: credentialId, privateKey, relyingParty, url, userHandle, username For Key Vault passkeys, the file must contain: credentialId, keyVault.vaultName, keyVault.keyName, relyingParty, url, userHandle, username |
| -TenantId | String |  |  | The Defender XDR tenant ID to connect to. If not provided, the default tenant is used. This is passed to Connect-XdrByEstsCookie and does not affect Key Vault authentication. |
| -KeyVaultTenantId | String |  |  | Azure AD tenant ID used when scoping the Key Vault access token. Applicable when using Az module or Azure CLI for Key Vault authentication. Not required when using IMDS managed identity. |
| -KeyVaultClientId | String |  |  | Client ID of a user-assigned managed identity for Key Vault access via IMDS. When not provided and IMDS is used, the system-assigned managed identity is used. |
| -KeyVaultApiVersion | String |  | 7.4 | Azure Key Vault REST API version to use for the Sign operation. Defaults to '7.4'. |
| -UserAgent | String |  | (Get-XdrDefaultUserAgent) | User-Agent string for HTTP requests. Defaults to a browser-compatible Edge user agent. |

Example 1:

```powershell
Connect-XdrBySoftwarePasskey -KeyFilePath ".github\secadmin.passkey"
```

Authenticates using a local passkey stored in a JSON file.

Example 2:

```powershell
Connect-XdrBySoftwarePasskey -KeyFilePath ".\kv-passkey.json" -TenantId "8612f621-73ca-4c12-973c-0da732bc44c2"
```

Authenticates using an Azure Key Vault passkey and connects to a specific XDR tenant. Key Vault access is obtained automatically via Az module or Azure CLI.

Example 3:

```powershell
Connect-AzAccount
Connect-XdrBySoftwarePasskey -KeyFilePath ".\kv-passkey.json" -KeyVaultTenantId "8612f621-73ca-4c12-973c-0da732bc44c2"
```

Signs in to Azure first, then authenticates with a Key Vault passkey scoped to that tenant.

Example 4:

```powershell
Connect-XdrBySoftwarePasskey -KeyFilePath ".\kv-passkey.json" -KeyVaultClientId "12345678-abcd-efgh-ijkl-123456789012"
```

Authenticates using a Key Vault passkey with a user-assigned managed identity (IMDS). For use from Azure resources (VMs, Azure Functions, etc.).

## Connect-XdrBySSO

Guard: `blocked`

Authenticates to Microsoft Defender XDR using browser-based single sign-on.

Starts a dedicated browser profile, attempts silent sign-in using the local browser and
operating-system account state, captures Defender portal cookies, and configures the
XDR session. This cmdlet is intended for Windows-first SSO scenarios, but it can also
reuse existing Chromium browser session state on macOS and Linux when that browser state
is already available.

Use -Visible when validating or troubleshooting the flow so you can confirm the browser
reaches the Defender portal before the cmdlet captures the resulting session cookies.

```powershell
Connect-XdrBySSO [-TenantId <String>] [-Visible] [-SkipTenantSelection] [-TimeoutSeconds <Int32>] [-BrowserPath <String>] [-ProfilePath <String>] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -TenantId | String |  |  | Optional tenant ID (GUID) to select from the authenticated SSO session. If only an ESTS cookie is captured, the requested tenant ID is passed to the ESTS bootstrap step. |
| -Visible | SwitchParameter |  | False | Shows the browser window instead of using the default headless launch. |
| -SkipTenantSelection | SwitchParameter |  | False | Automatically uses the selected tenant or the first available tenant when multiple tenants are available. |
| -TimeoutSeconds | Int32 |  | 180 | Maximum time to wait for SSO authentication to complete. |
| -BrowserPath | String |  |  | Optional browser executable path or command name. |
| -ProfilePath | String |  |  | Optional persistent browser profile path used for SSO. |
| -UserAgent | String |  |  | Optional User-Agent override for the launched browser. |

Example 1:

```powershell
Connect-XdrBySSO
```

Attempts browser-based SSO using the default dedicated profile.

Example 2:

```powershell
Connect-XdrBySSO -Visible
```

Shows the browser window while the SSO flow completes.

## Connect-XdrByTemporaryAccessPass

Guard: `blocked`

Authenticates to Microsoft Defender XDR using a Temporary Access Pass (TAP).

Performs the Entra ID TAP web sign-in flow programmatically (no browser required),
extracts the ESTSAUTH cookie, and then passes it to Connect-XdrByEstsCookie to
establish an authenticated Defender XDR session.

TAP sign-in is tenant-scoped. If TenantId is omitted, the cmdlet attempts to resolve the
tenant automatically from the supplied username before starting the Entra authorize flow.

```powershell
Connect-XdrByTemporaryAccessPass [-Username <String>] [-TemporaryAccessPass <SecureString>] [-TenantId <String>] [-UserAgent <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Username | String |  |  | The user principal name (e.g., admin@contoso.com). If omitted, you are prompted interactively. |
| -TemporaryAccessPass | SecureString |  |  | The Temporary Access Pass as a SecureString. If omitted, you are prompted interactively. |
| -TenantId | String |  |  | The Entra tenant ID used for TAP authentication and the Defender XDR connection. If omitted, the cmdlet resolves the tenant from Username. |
| -UserAgent | String |  | (Get-XdrDefaultUserAgent) | User-Agent string for HTTP requests. Defaults to a browser-compatible Edge user agent. |

Example 1:

```powershell
$tap = ConvertTo-SecureString '+&YZuead' -AsPlainText -Force
Connect-XdrByTemporaryAccessPass -Username 'admin@contoso.com' -TemporaryAccessPass $tap -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2'
```

Authenticates using the supplied TAP and connects to Defender XDR.

Example 2:

```powershell
Connect-XdrByTemporaryAccessPass -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2'
```

Prompts for username and TAP, then authenticates and connects.

Example 3:

```powershell
Connect-XdrByTemporaryAccessPass -Username 'admin@contoso.com'
```

Prompts for the TAP, resolves the tenant automatically from the username, then authenticates and connects.

## Get-XdrMtoTenantList

Guard: `read`

Retrieves the list of accessible tenants from Microsoft Defender XDR.

Gets the list of tenants that the current user has access to in the Microsoft Defender XDR portal,
including tenant information such as name, tenant ID, environment, and access status.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrMtoTenantList [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrMtoTenantList
```

Retrieves the list of accessible tenants using cached data if available.

Example 2:

```powershell
Get-XdrMtoTenantList -Force
```

Forces a fresh retrieval of the tenant list, bypassing the cache.

Example 3:

```powershell
Get-XdrMtoTenantList | Where-Object { $_.selected }
```

Retrieves the currently selected tenant.

Example 4:

```powershell
Get-XdrMtoTenantList | Where-Object { -not $_.lostAccess }
```

Retrieves only tenants where access has not been lost.

## Get-XdrTenantContext

Guard: `read`

Retrieves the tenant context information from Microsoft Defender XDR.

Gets the tenant context information from the Microsoft Defender XDR portal,
including tenant settings and configuration details.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrTenantContext [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrTenantContext
```

Retrieves the tenant context using cached data if available.

Example 2:

```powershell
Get-XdrTenantContext -Force
```

Forces a fresh retrieval of the tenant context, bypassing the cache.

## Get-XdrTenantWorkloadStatus

Guard: `read`

Retrieves and evaluates the workload status from Microsoft Defender XDR tenant context.

Gets the tenant context information and evaluates all properties named "Is*Active" to determine which
Microsoft Defender workloads are active in the tenant. Provides friendly names and descriptions for known workloads.

```powershell
Get-XdrTenantWorkloadStatus [-Workload <String>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Workload | String |  |  | Filter results to a specific workload. Can match either the OriginalProperty or WorkloadName. Supports wildcards. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrTenantWorkloadStatus
```

Retrieves and evaluates all workload statuses using cached data if available.

Example 2:

```powershell
Get-XdrTenantWorkloadStatus -Workload "IsMdeActive"
```

Retrieves only the Microsoft Defender for Endpoint workload status.

Example 3:

```powershell
Get-XdrTenantWorkloadStatus -Workload "IsMdatpActive"
```

Retrieves the workload status using the original property name.

Example 4:

```powershell
Get-XdrTenantWorkloadStatus -Workload "*Sentinel*"
```

Retrieves workload statuses that match the Sentinel pattern.

Example 5:

```powershell
Get-XdrTenantWorkloadStatus -Force
```

Forces a fresh retrieval of the tenant context and evaluates workload statuses.

## Set-XdrConnectionSettings

Guard: `blocked`

Creates XDR connection settings using authentication cookies.

Creates global session and headers variables for XDR API calls using the provided
sccauth value and optionally an XSRF token value. If xsrf is not provided, the
function will bootstrap the session against security.microsoft.com to obtain
XSRF-TOKEN automatically.

```powershell
Set-XdrConnectionSettings -SccAuth <Object> [-Xsrf <Object>] [-TenantId <Object>]
Set-XdrConnectionSettings [-TenantId <Object>] -WebSession <Object>
Set-XdrConnectionSettings [-TenantId <Object>] -ResetWebSession
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -SccAuth | Object | yes |  | The sccauth cookie value from an authenticated session to security.microsoft.com. |
| -Xsrf | Object |  |  | The XSRF-TOKEN cookie value from an authenticated session to security.microsoft.com. If not provided, XSRF-TOKEN is obtained automatically using the provided sccauth and an initial request to security.microsoft.com. |
| -TenantId | Object |  |  | The Tenant ID to use for XDR API requests. If not provided, the Tenant ID will be determined automatically from the XDR portal. |
| -WebSession | Object | yes |  | An optional WebRequestSession object to use for the requests. If not provided, a new session will be created. |
| -ResetWebSession | SwitchParameter | yes | False | If specified, resets the existing WebSession by creating a new one while retaining the existing authentication cookies. |

Example 1:

```powershell
Set-XdrConnectionSettings -sccauth "your_sccauth_value" -xsrf "your_xsrf_value"
```

Creates XDR connection settings using the provided authentication cookies.

Example 2:

```powershell
Set-XdrConnectionSettings -sccauth "your_sccauth_value" -TenantId "your_tenant_id"
```

Creates XDR connection settings and automatically obtains XSRF-TOKEN.

## Update-XdrConnectionSettings

Guard: `blocked`

Updates XDR connection session cookies and authentication tokens.

Refreshes the web session cookies and XSRF tokens for Microsoft Defender XDR by making a request to the portal.
This function is called automatically by other XDR cmdlets to ensure the session remains valid.

```powershell
Update-XdrConnectionSettings
```

Example 1:

```powershell
Update-XdrConnectionSettings
```

Updates the XDR session cookies and headers.

