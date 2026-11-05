# Defender for Identity

13 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Get-XdrIdentityAlertThreshold

Guard: `read`

Retrieves alert threshold configuration for Microsoft Defender for Identity.

Gets the alert threshold settings for Microsoft Defender for Identity detections.
Alert thresholds determine the sensitivity level (High/Medium/Low) for various security alerts.
The function maps internal alert names to user-friendly titles for better readability.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityAlertThreshold [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityAlertThreshold
```

Retrieves the alert threshold configuration using cached data if available.

Example 2:

```powershell
Get-XdrIdentityAlertThreshold -Force
```

Forces a fresh retrieval of the alert threshold configuration, bypassing the cache.

Example 3:

```powershell
$thresholds = Get-XdrIdentityAlertThreshold
$thresholds | Where-Object { $_.Threshold -eq "Low" }
```

Retrieves all alerts configured with Low threshold.

Example 4:

```powershell
Get-XdrIdentityAlertThreshold | Format-Table AlertTitle, Threshold, AvailableThresholds -AutoSize
```

Displays alert thresholds in a formatted table.

## Get-XdrIdentityConfigurationDirectoryServiceAccount

Guard: `read`

Retrieves directory service accounts for Microsoft Defender for Identity.

Gets the directory service accounts (gMSA) configured for Microsoft Defender for Identity sensors.
These accounts are used by MDI sensors to query Active Directory.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityConfigurationDirectoryServiceAccount [-PageSize <Int32>] [-Skip <Int32>] [-Force]
Get-XdrIdentityConfigurationDirectoryServiceAccount -All [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -PageSize | Int32 |  | 20 | The number of accounts to retrieve per page. Default is 20. |
| -Skip | Int32 |  | 0 | The number of accounts to skip. Used for pagination. Default is 0. |
| -All | SwitchParameter | yes | False | Retrieves all directory service accounts by automatically paging through all results. When specified, PageSize and Skip parameters are ignored. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityConfigurationDirectoryServiceAccount
```

Retrieves the first 20 directory service accounts using cached data if available.

Example 2:

```powershell
Get-XdrIdentityConfigurationDirectoryServiceAccount -PageSize 50 -Skip 20
Retrieves 50 accounts, skipping the first 20 (for pagination).
```

Example 3:

```powershell
Get-XdrIdentityConfigurationDirectoryServiceAccount -All
```

Retrieves all directory service accounts by automatically paging through all results.

Example 4:

```powershell
Get-XdrIdentityConfigurationDirectoryServiceAccount -Force
```

Forces a fresh retrieval of directory service accounts, bypassing the cache.

Example 5:

```powershell
Get-XdrIdentityConfigurationDirectoryServiceAccount -All |
    Where-Object { $_.IsGroupManagedServiceAccount -eq $true }
```

Retrieves all directory service accounts and filters for gMSAs.

## Get-XdrIdentityConfigurationRemediationActionAccount

Guard: `read`

Retrieves the remediation action account configuration for Microsoft Defender for Identity.

Gets the remediation action account configuration from Microsoft Defender for Identity.
If remediation is configured to use Local System, returns the configuration status.
If remediation uses a dedicated account, returns both the configuration status and the account details.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityConfigurationRemediationActionAccount [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityConfigurationRemediationActionAccount
```

Retrieves the remediation action account configuration using cached data if available.

Example 2:

```powershell
Get-XdrIdentityConfigurationRemediationActionAccount -Force
```

Forces a fresh retrieval of the remediation action account configuration, bypassing the cache.

Example 3:

```powershell
$config = Get-XdrIdentityConfigurationRemediationActionAccount
if ($config.IsRemediationWithLocalSystemEnabled) {
    Write-Host "Using Local System account for remediation"
} else {
    Write-Host "Using dedicated account: $($config.RemediationAccounts[0].AccountName)"
}
```

Retrieves the configuration and checks which account type is being used.

## Get-XdrIdentityDomainControllerCoverage

Guard: `read`

Retrieves domain controller coverage from Microsoft Defender for Identity.

Gets the domain controller coverage information from Microsoft Defender for Identity.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityDomainControllerCoverage [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityDomainControllerCoverage
```

Retrieves the domain controller coverage using cached data if available.

Example 2:

```powershell
Get-XdrIdentityDomainControllerCoverage -Force
```

Forces a fresh retrieval of the domain controller coverage, bypassing the cache.

## Get-XdrIdentityIdentity

Guard: `read`

Retrieves identities from Microsoft Defender for Identity.

Gets identities from Microsoft Defender for Identity with support for pagination,
sorting, and search filtering.
This function includes caching support with a 10-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityIdentity [-SortByField <String>] [-SortDirection <String>] [-PageSize <Int32>] [-Skip <Int32>] [-SearchText <String>] [-IdentityProvider <String[]>] [-IdentityEnvironment <String[]>] [-Force]
Get-XdrIdentityIdentity [-SortByField <String>] [-SortDirection <String>] [-SearchText <String>] [-IdentityProvider <String[]>] [-IdentityEnvironment <String[]>] -All [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -SortByField | String |  | RepresentableName | The field to sort results by. Valid values are "RepresentableName", "AccountDomain", and "CreatedDateTime". Default is "RepresentableName". Values: RepresentableName, AccountDomain, CreatedDateTime |
| -SortDirection | String |  | Asc | The sort direction. Valid values are "Asc" (ascending) and "Dsc" (descending). Default is "Asc". Values: Asc, Dsc |
| -PageSize | Int32 |  | 20 | The number of identities to retrieve per page. Default is 20. Maximum is 100. |
| -Skip | Int32 |  | 0 | The number of identities to skip. Used for pagination. Default is 0. |
| -SearchText | String |  |  | Text to search for in identities. Only non-special characters are allowed. |
| -IdentityProvider | String[] |  |  | Filters identities by identity provider. Valid values are "ActiveDirectory", "EntraID", and "Hybrid". Multiple values can be specified. Values: ActiveDirectory, EntraID, Hybrid |
| -IdentityEnvironment | String[] |  |  | Filters identities by primary identity provider. Valid values are "ActiveDirectory", "EntraID", and "Hybrid". Multiple values can be specified. Values: ActiveDirectory, EntraID, Hybrid |
| -All | SwitchParameter | yes | False | Retrieves all identities by automatically paging through all results. When specified, PageSize and Skip parameters are ignored. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityIdentity
```

Retrieves the first 20 identities sorted by RepresentableName in ascending order.

Example 2:

```powershell
Get-XdrIdentityIdentity -SortByField CreatedDateTime -SortDirection Dsc
Retrieves identities sorted by creation date in descending order (newest first).
```

Example 3:

```powershell
Get-XdrIdentityIdentity -PageSize 50 -Skip 100
Retrieves 50 identities, skipping the first 100 (for pagination).
```

Example 4:

```powershell
Get-XdrIdentityIdentity -SearchText "admin"
```

Retrieves identities matching the search text "admin".

Example 5:

```powershell
Get-XdrIdentityIdentity -SortByField AccountDomain -PageSize 100 -SearchText "contoso"
```

Retrieves up to 100 identities containing "contoso", sorted by account domain.

Example 6:

```powershell
Get-XdrIdentityIdentity -IdentityProvider ActiveDirectory
```

Retrieves identities from Active Directory only.

Example 7:

```powershell
Get-XdrIdentityIdentity -IdentityProvider ActiveDirectory, EntraID
```

Retrieves identities from both Active Directory and Entra ID.

Example 8:

```powershell
Get-XdrIdentityIdentity -IdentityEnvironment ActiveDirectory
```

Retrieves identities with Active Directory as primary identity provider.

Example 9:

```powershell
Get-XdrIdentityIdentity -IdentityEnvironment ActiveDirectory, EntraID
```

Retrieves identities with Active Directory or Entra ID as primary identity provider.

Example 10:

```powershell
Get-XdrIdentityIdentity -SearchText "bob" -IdentityEnvironment ActiveDirectory
```

Retrieves identities matching "bob" from Active Directory only.

Example 11:

```powershell
Get-XdrIdentityIdentity -Force
```

Forces a fresh retrieval of identities, bypassing the cache.

Example 12:

```powershell
Get-XdrIdentityIdentity -All
```

Retrieves all identities by automatically paging through all results.

Example 13:

```powershell
Get-XdrIdentityIdentity -All -SearchText "admin"
```

Retrieves all identities matching "admin" by paging through all results.

## Get-XdrIdentityOnboardingStatus

Guard: `read`

Retrieves the onboarding status of Microsoft Defender for Identity.

Gets the onboarding status of Microsoft Defender for Identity (MDI) for the current tenant.
Returns a boolean value indicating whether MDI is onboarded or not.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityOnboardingStatus [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityOnboardingStatus
```

Retrieves the MDI onboarding status using cached data if available.

Example 2:

```powershell
Get-XdrIdentityOnboardingStatus -Force
```

Forces a fresh retrieval of the MDI onboarding status, bypassing the cache.

Example 3:

```powershell
if (Get-XdrIdentityOnboardingStatus) {
    Write-Host "Microsoft Defender for Identity is onboarded"
}
```

Checks if MDI is onboarded and displays a message.

## Get-XdrIdentityServiceAccount

Guard: `read`

Retrieves service accounts from Microsoft Defender for Identity.

Gets service accounts from Microsoft Defender for Identity, including account activity information.
Supports filtering by service account type (gMSA, sMSA, User).
This function includes caching support with a 10-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityServiceAccount [-AccountType <String[]>] [-PageSize <Int32>] [-Skip <Int32>] [-IncludeAccountActivity <Boolean>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -AccountType | String[] |  |  | Filters service accounts by type. Valid values are "gMSA", "sMSA", and "User". Multiple values can be specified. If not specified, all service account types are returned. Values: gMSA, sMSA, User |
| -PageSize | Int32 |  | 20 | The number of service accounts to retrieve per page. Default is 20. Maximum is 100. |
| -Skip | Int32 |  | 0 | The number of service accounts to skip. Used for pagination. Default is 0. |
| -IncludeAccountActivity | Boolean |  | True | Whether to include account activity information. Default is $true. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityServiceAccount
```

Retrieves all service accounts using cached data if available.

Example 2:

```powershell
Get-XdrIdentityServiceAccount -AccountType gMSA
Retrieves only group Managed Service Accounts (gMSA).
```

Example 3:

```powershell
Get-XdrIdentityServiceAccount -AccountType sMSA, User
Retrieves standalone Managed Service Accounts (sMSA) and User accounts.
```

Example 4:

```powershell
Get-XdrIdentityServiceAccount -PageSize 50 -Skip 20
Retrieves 50 service accounts, skipping the first 20 (for pagination).
```

Example 5:

```powershell
Get-XdrIdentityServiceAccount -IncludeAccountActivity $false
```

Retrieves service accounts without account activity information.

Example 6:

```powershell
Get-XdrIdentityServiceAccount -Force
```

Forces a fresh retrieval of service accounts, bypassing the cache.

## Get-XdrIdentityStatistic

Guard: `read`

Retrieves aggregated identity statistics from Microsoft Defender for Identity.

Gets aggregated identity data and statistics from Microsoft Defender for Identity,
including counts and metrics across all identities.
This function includes caching support with a 10-minute TTL to reduce API calls.

```powershell
Get-XdrIdentityStatistic [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIdentityStatistic
```

Retrieves identity statistics using cached data if available.

Example 2:

```powershell
Get-XdrIdentityStatistic -Force
```

Forces a fresh retrieval of identity statistics, bypassing the cache.

## Get-XdrIdentityUser

Guard: `read`

Retrieves detailed user identity information from Microsoft Defender for Identity.

Gets comprehensive user identity information by resolving identifiers across multiple
workloads including Microsoft Graph, RADIUS, MCAS, MTP, MDI, and Sentinel.

This cmdlet calls the user/resolve API to get full identity details including:
- All user identifiers (AAD ID, SID, UPN, radiusUserId, complexId, armId)
- User profile information (displayName, email, phone, department, jobTitle)
- Security information (riskLevel, status, PIM roles)
- Activity timestamps (firstSeen, lastSeen, created)
- Cloud app accounts, activity period, devices count, and manager details when available

The returned object can be piped to Get-XdrIdentityUserTimeline for timeline retrieval.

```powershell
Get-XdrIdentityUser -Upn <String> [-Force]
Get-XdrIdentityUser -AadId <String> [-Force]
Get-XdrIdentityUser -Sid <String> [-Force]
Get-XdrIdentityUser -RadiusUserId <String> [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -AadId | String | yes |  | The Azure AD object ID of the user. |
| -Upn | String | yes |  | The User Principal Name (email address) of the user. |
| -Sid | String | yes |  | The Security Identifier (SID) of the user. |
| -RadiusUserId | String | yes |  | The RADIUS user ID in format "User_{tenantId}_{userId}". |
| -Force | SwitchParameter |  | False | Bypass cache and force a fresh API call. |

Example 1:

```powershell
Get-XdrIdentityUser -Upn "nathan@contoso.com"
```

Retrieves user identity information by UPN.

Example 2:

```powershell
Get-XdrIdentityUser -AadId "a2307c5a-76df-4513-b575-0537842c1d8b"
```

Retrieves user identity information by Azure AD object ID.

Example 3:

```powershell
Get-XdrIdentityUser -Upn "nathan@contoso.com"
```

Retrieves user identity including enrichment data (accounts, activity period, devices count, manager when available).

Example 4:

```powershell
Get-XdrIdentityUser -Upn "nathan@contoso.com" | Get-XdrIdentityUserTimeline -LastNDays 7
```

Retrieves user identity and pipes to timeline cmdlet.

## Get-XdrIdentityUserTimeline

Guard: `read`

Retrieves the timeline of events for a specific user from Microsoft Defender for Identity.

Gets the timeline of security events for a user from Microsoft Defender for Identity with
options to filter by date range, event types, and other parameters.

Uses parallel chunked requests (1-day intervals) to improve performance and support longer
date ranges up to 180 days.

Supports two levels of parallelism:
- Parallel day chunks for a single user
- Parallel users when processing multiple users via pipeline

Final merged results are strictly filtered to the requested [FromDate, ToDate) range.

```powershell
Get-XdrIdentityUserTimeline -Upn <String> [-FromDate <DateTime>] [-ToDate <DateTime>] [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -AadId <String> -LastNDays <Int32> [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -AadId <String> [-FromDate <DateTime>] [-ToDate <DateTime>] [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -Upn <String> -LastNDays <Int32> [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -Sid <String> -LastNDays <Int32> [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -Sid <String> [-FromDate <DateTime>] [-ToDate <DateTime>] [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -RadiusUserId <String> -LastNDays <Int32> [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -RadiusUserId <String> [-FromDate <DateTime>] [-ToDate <DateTime>] [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -InputObject <PSObject> -LastNDays <Int32> [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -InputObject <PSObject> [-FromDate <DateTime>] [-ToDate <DateTime>] [-EventType <String[]>] [-ListEventTypes] [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline [-FromDate <DateTime>] [-ToDate <DateTime>] [-EventType <String[]>] -ListEventTypes [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
Get-XdrIdentityUserTimeline -LastNDays <Int32> [-EventType <String[]>] -ListEventTypes [-PageSize <Int32>] [-IncludeSentinelEvents] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkSizeHours <Int32>] [-DisableAdaptiveChunking] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -AadId | String | yes |  | The Entra (Azure AD) object ID of the user. |
| -Upn | String | yes |  | The User Principal Name of the user. |
| -Sid | String | yes |  | The Security Identifier (SID) of the user. |
| -RadiusUserId | String | yes |  | The RADIUS user ID in format "User_{tenantId}_{userId}". |
| -InputObject | PSObject | yes |  | A user object from Get-XdrIdentityUser containing resolved identifiers. Accepts pipeline input. |
| -FromDate | DateTime |  | ((Get-Date).AddDays(-1)) | The start date for the timeline. Defaults to 1 day before current time. |
| -ToDate | DateTime |  | (Get-Date) | The end date for the timeline. Defaults to current time. |
| -LastNDays | Int32 | yes | 0 | Specifies the number of days to look back from current time. Cannot be used with FromDate or ToDate parameters. Maximum is 180 days. |
| -EventType | String[] |  |  | Filter events by type. Available types are retrieved dynamically from the FilterOptions API. Use -ListEventTypes to see available options. |
| -ListEventTypes | SwitchParameter |  | False | Lists available event types for filtering for the specified user and time range. Returns pipeline objects with EventType, Scope, and User properties. If no user identifier is supplied, returns global event types for the selected time range. |
| -PageSize | Int32 |  | 1000 | The number of events to return per page. Defaults to 1000. |
| -IncludeSentinelEvents | SwitchParameter |  | False | Include Microsoft Sentinel UEBA anomaly events in the timeline results. Requires the user to have an armId (Sentinel entity ID) which is auto-detected from the resolved user identifiers. |
| -ThrottleLimit | Int32 |  | 32 | The maximum number of concurrent requests. Defaults to 32. |
| -TimeoutSeconds | Int32 |  | 3600 | Maximum time in seconds to wait for all requests to complete. Defaults to 3600 (1 hour). |
| -MaxRetries | Int32 |  | 3 | Maximum number of retry attempts for failed API requests. Defaults to 3. |
| -RetryDelaySeconds | Int32 |  | 5 | Base delay in seconds between retry attempts (uses exponential backoff). Defaults to 5. |
| -ChunkSizeHours | Int32 |  | 72 | Maximum size of each time chunk in hours (1-168). Defaults to 72 hours. By default, adaptive chunking may reduce this value based on the requested range to improve throughput and avoid oversized identity timeline windows. |
| -DisableAdaptiveChunking | SwitchParameter |  | False | Disables adaptive chunk sizing and forces fixed-size chunks based on ChunkSizeHours. |
| -RequestTimeoutSeconds | Int32 |  | 30 | Timeout in seconds for individual HTTP requests (10-120). Defaults to 30. If a single API call takes longer than this, it will timeout and retry. |
| -OutputPath | String |  |  | Optional. The path to store temporary JSON files. Defaults to a temp folder. |
| -KeepTempFiles | SwitchParameter |  | False | If specified, keeps the temporary JSON files after merging. |
| -ExportPath | String |  |  | Optional. Export results directly to a JSON file at the specified path. |

Example 1:

```powershell
Get-XdrIdentityUserTimeline -Upn "user@domain.com"
```

Retrieves the last day of timeline events for the specified user.

Example 2:

```powershell
Get-XdrIdentityUserTimeline -AadId "a2307c5a-76df-4513-b575-0537842c1d8b" -LastNDays 7
```

Retrieves 7 days of timeline events.

Example 3:

```powershell
Get-XdrIdentityUser -Upn "user@domain.com" | Get-XdrIdentityUserTimeline -LastNDays 30
```

Retrieves user identity and pipes to timeline cmdlet for 30 days of events.

Example 4:

```powershell
Get-XdrIdentityUserTimeline -Upn "user@domain.com" -LastNDays 7 -IncludeSentinelEvents
```

Retrieves timeline events including Sentinel UEBA anomalies.

Example 5:

```powershell
Get-XdrIdentityUserTimeline -Upn "user@domain.com" -LastNDays 7 -ListEventTypes
```

Lists available event types for filtering for the specified user and time range.

Example 6:

```powershell
Get-XdrIdentityUserTimeline -LastNDays 7 -ListEventTypes
```

Lists global event types for the selected time range.

Example 7:

```powershell
Get-XdrIdentityUserTimeline -LastNDays 7 -ListEventTypes | Select-Object -ExpandProperty EventType
```

Returns only event type names for automation or downstream filtering.

Example 8:

```powershell
Get-XdrIdentityUserTimeline -Upn "user@domain.com" -LastNDays 90 -ExportPath "C:\Reports\user_timeline.json"
```

Retrieves 90 days of timeline events and exports to JSON file.

## New-XdrIdentityConfigurationRemediationActionAccount

Guard: `write`

Registers a new remediation action account for Microsoft Defender for Identity.

Creates a new Group Managed Service Account (gMSA) registration for Microsoft Defender for Identity
remediation actions. This account will be used by MDI to perform automatic remediation actions
when the system is configured to use a dedicated account instead of Local System.

```powershell
New-XdrIdentityConfigurationRemediationActionAccount -AccountName <String> -DomainDnsName <String> [-IsSingleLabelAccountDomainName]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -AccountName | String | yes |  | The name of the Group Managed Service Account (without domain suffix). |
| -DomainDnsName | String | yes |  | The fully qualified domain name (FQDN) where the account exists. |
| -IsSingleLabelAccountDomainName | SwitchParameter |  | False | Switch parameter indicating if the domain is a single-label domain name. Use this for non-standard domain configurations. |

Example 1:

```powershell
New-XdrIdentityConfigurationRemediationActionAccount -AccountName "MDIRemediation" -DomainDnsName "contoso.com"
```

Registers a gMSA account named "MDIRemediation" in the contoso.com domain for MDI remediation actions.

Example 2:

```powershell
New-XdrIdentityConfigurationRemediationActionAccount -AccountName "DefenderRemediator" -DomainDnsName "corp.contoso.com" -IsSingleLabelAccountDomainName
```

Registers a gMSA account with single-label domain name configuration.

## Remove-XdrIdentityConfigurationRemediationActionAccount

Guard: `write`

Removes a remediation action account from Microsoft Defender for Identity.

Deletes a registered Group Managed Service Account (gMSA) from Microsoft Defender for Identity
remediation actions. The account will no longer be used for automatic remediation actions.

```powershell
Remove-XdrIdentityConfigurationRemediationActionAccount -Id <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Id | String | yes |  | The User Principal Name (UPN) of the remediation account to remove. Must be in the format: accountname@domain.com Accepts pipeline input. |

Example 1:

```powershell
Remove-XdrIdentityConfigurationRemediationActionAccount -Id "MDIRemediation@contoso.com"
```

Removes the specified remediation action account.

Example 2:

```powershell
"DefenderRemediator@corp.contoso.com" | Remove-XdrIdentityConfigurationRemediationActionAccount
```

Removes the remediation account using pipeline input.

Example 3:

```powershell
$accounts = Get-XdrIdentityConfigurationRemediationActionAccount
$accounts.RemediationAccounts | ForEach-Object {
    Remove-XdrIdentityConfigurationRemediationActionAccount -Id $_.Id
}
```

Removes all registered remediation accounts.

Example 4:

```powershell
Get-XdrIdentityConfigurationRemediationActionAccount |
    Select-Object -ExpandProperty RemediationAccounts |
    Remove-XdrIdentityConfigurationRemediationActionAccount
```

Removes all remediation accounts using pipeline input.

## Set-XdrIdentityConfigurationRemediationActionAccount

Guard: `write`

Configures the remediation action account type for Microsoft Defender for Identity.

Sets whether Microsoft Defender for Identity uses the Local System account or a dedicated
account for remediation actions. This configuration determines which account type is used
when MDI performs automatic remediation actions on identified threats.

```powershell
Set-XdrIdentityConfigurationRemediationActionAccount [-UseLocalSystem <Boolean>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -UseLocalSystem | Boolean |  | True | Boolean parameter that controls whether remediation actions use the Local System account. Defaults to $true. Use -UseLocalSystem:$false to configure a dedicated remediation account. |

Example 1:

```powershell
Set-XdrIdentityConfigurationRemediationActionAccount -UseLocalSystem:$true
```

Configures MDI to use the Local System account for remediation actions.

Example 2:

```powershell
Set-XdrIdentityConfigurationRemediationActionAccount -UseLocalSystem:$false
```

Configures MDI to use a dedicated account for remediation actions.

