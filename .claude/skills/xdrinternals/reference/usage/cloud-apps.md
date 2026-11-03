# Defender for Cloud Apps

8 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Get-XdrCloudAppsActivityTimeline

Guard: `read`

Retrieves Microsoft Defender for Cloud Apps activity timeline data.

Retrieves Cloud Apps activity events with reliable chunking, retry handling,
recent/archived API routing, export support, and typed admin-friendly output.

```powershell
Get-XdrCloudAppsActivityTimeline [-FromDate <DateTime>] [-ToDate <DateTime>] [-LastNDays <Int32>] [-PageSize <Int32>] [-Filters <Hashtable>] [-IncludeThreatScores] [-ThrottleLimit <Int32>] [-ChunkHours <Int32>] [-Aggressive] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-RequestTimeoutSeconds <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-ExportPath <String>] [-ExportFormat <String>] [-PassThru] [-Compress] [-AllowPartial] [-Force]
Get-XdrCloudAppsActivityTimeline -Metadata [-Raw] [-Force]
Get-XdrCloudAppsActivityTimeline -ArchivedMetadata [-Raw] [-Force]
Get-XdrCloudAppsActivityTimeline -CountOnly [-FromDate <DateTime>] [-ToDate <DateTime>] [-LastNDays <Int32>] [-Filters <Hashtable>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Metadata | SwitchParameter | yes | False | Returns filter metadata for the recent activities API. |
| -ArchivedMetadata | SwitchParameter | yes | False | Returns filter metadata for the archived activities API. |
| -Raw | SwitchParameter |  | False | Returns raw API metadata or response data when supported. |
| -CountOnly | SwitchParameter | yes | False | Returns activity counts without retrieving full activity records. |
| -FromDate | DateTime |  |  | Start of the timeline range. |
| -ToDate | DateTime |  |  | End of the timeline range. |
| -LastNDays | Int32 |  | 0 | Retrieves activity from the last specified number of days. |
| -PageSize | Int32 |  | 250 | Number of activities to request per page. |
| -Filters | Hashtable |  | @{} | Cloud Apps activity filters to include in the query body. |
| -IncludeThreatScores | SwitchParameter |  | False | Adds threat score data for recent activities when available. |
| -ThrottleLimit | Int32 |  | 8 | Maximum number of chunks to retrieve concurrently. |
| -ChunkHours | Int32 |  | 6 | Maximum hours represented by each activity chunk. |
| -Aggressive | SwitchParameter |  | False | Uses higher concurrency and smaller chunks for incident response investigations. |
| -TimeoutSeconds | Int32 |  | 3600 | Maximum total runtime for chunk retrieval. |
| -MaxRetries | Int32 |  | 5 | Maximum retry attempts for each page request. |
| -RetryDelaySeconds | Int32 |  | 5 | Base delay used for retry backoff. |
| -RequestTimeoutSeconds | Int32 |  | 60 | Timeout for each individual HTTP request. |
| -OutputPath | String |  |  | Directory used for temporary chunk files. |
| -KeepTempFiles | SwitchParameter |  | False | Keeps temporary chunk files after the command completes. |
| -ExportPath | String |  |  | Writes retrieved activity events to a JSON file. |
| -ExportFormat | String |  | Json | Export file format. Json preserves the existing array output; Ndjson streams one event per line and is preferred for large incident response exports. Values: Json, Ndjson |
| -PassThru | SwitchParameter |  | False | Returns activity events after writing ExportPath. |
| -Compress | SwitchParameter |  | False | Writes compressed JSON when ExportPath is used. |
| -AllowPartial | SwitchParameter |  | False | Returns completed chunks instead of terminating when one or more chunks fail. |
| -Force | SwitchParameter |  | False | Bypasses cache-backed metadata requests. |

Example 1:

```powershell
Get-XdrCloudAppsActivityTimeline -LastNDays 1
```

Retrieves the last day of Cloud Apps activity.

Example 2:

```powershell
Get-XdrCloudAppsActivityTimeline -LastNDays 7 -Aggressive -ExportPath .\cloud-apps-activity.json
```

Retrieves seven days of activity using aggressive incident response settings and exports to JSON.

## Get-XdrCloudAppsApp

Guard: `read`

Retrieves app-focused Microsoft Defender for Cloud Apps data.

Retrieves app catalog, discovered app, OAuth app permission, file, service,
and tag data through one grouped command.

```powershell
Get-XdrCloudAppsApp [-Type <String>] [-Metadata] [-CountOnly] [-AppId <String>] [-StreamId <String>] [-StreamName <String>] [-Timeframe <Int32>] [-Limit <Int32>] [-Skip <Int32>] [-SortField <String>] [-SortDirection <String>] [-Filters <Hashtable>] [-Raw] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Type | String |  | Discovered | App data surface to retrieve. Defaults to Discovered. Values: Discovered, Catalog, CatalogCategory, OAuth, File, Service, Tag |
| -Metadata | SwitchParameter |  | False | Retrieves metadata for surfaces that expose filter or table metadata. |
| -CountOnly | SwitchParameter |  | False | Retrieves only a count for surfaces that expose count endpoints. |
| -AppId | String |  |  | App identifier used by app-specific data types. |
| -StreamId | String |  |  | Discovery stream identifier for discovered app queries. |
| -StreamName | String |  |  | Discovery stream display name pattern for discovered app queries. |
| -Timeframe | Int32 |  | 30 | Discovery timeframe in days. |
| -Limit | Int32 |  | 100 | Maximum number of records to request. |
| -Skip | Int32 |  | 0 | Number of records to skip. |
| -SortField | String |  | score | Field used to sort grid results. |
| -SortDirection | String |  | desc | Sort direction for grid results. Values: asc, desc |
| -Filters | Hashtable |  | @{} | Cloud Apps filters to include in the query body. |
| -Raw | SwitchParameter |  | False | Returns the API response shape instead of typed admin-friendly objects. |
| -Force | SwitchParameter |  | False | Bypasses cache-backed requests. |

Example 1:

```powershell
Get-XdrCloudAppsApp -Type Discovered -Limit 50
```

Retrieves discovered cloud apps.

Example 2:

```powershell
Get-XdrCloudAppsApp -Type OAuth -Metadata
```

Retrieves OAuth app permission metadata.

## Get-XdrCloudAppsConfiguration

Guard: `read`

Retrieves grouped Microsoft Defender for Cloud Apps configuration data.

Retrieves settings, about information, discovery streams, and other
live-validated configuration data through a single grouped command.

```powershell
Get-XdrCloudAppsConfiguration [-Type <String>] [-Metadata] [-Limit <Int32>] [-Skip <Int32>] [-SortField <String>] [-SortDirection <String>] [-Filters <Hashtable>] [-Raw] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Type | String |  | Settings | Configuration data type to retrieve. Values: About, Settings, MailSettings, TenantConfig, LCNC, Notifications, ApiToken, DiscoveryDataSource, DiscoveryStream, Location, LogCollector, ScopedProfile, Subnet |
| -Metadata | SwitchParameter |  | False | Retrieves metadata for configuration surfaces that expose metadata. |
| -Limit | Int32 |  | 100 | Maximum number of grid records to request. |
| -Skip | Int32 |  | 0 | Number of grid records to skip. |
| -SortField | String |  | name | Field used to sort grid results. |
| -SortDirection | String |  | asc | Sort direction for grid results. Values: asc, desc |
| -Filters | Hashtable |  | @{} | Cloud Apps filters to include in the query body. |
| -Raw | SwitchParameter |  | False | Returns the raw API response shape. |
| -Force | SwitchParameter |  | False | Bypasses cache-backed requests. |

Example 1:

```powershell
Get-XdrCloudAppsConfiguration -Type DiscoveryStream
```

Retrieves Cloud Discovery streams.

Example 2:

```powershell
Get-XdrCloudAppsConfiguration -Type Settings
```

Retrieves tenant-wide Cloud Apps settings.

## Get-XdrCloudAppsDiscovery

Guard: `read`

Retrieves Cloud Discovery data from Microsoft Defender for Cloud Apps.

Gets Cloud Discovery data from Microsoft Defender for Cloud Apps. This consolidated
cmdlet provides access to discovery data types including categories, entities,
top rankings, locations, constants, unsanctioned apps, and user deanonymization
through a single interface. This function includes caching support to reduce API calls.

When no StreamId or StreamName is specified for types that require streams, queries
ALL available discovery streams and includes StreamId/StreamName properties on each result.

```powershell
Get-XdrCloudAppsDiscovery -Type <String> [-StreamId <String>] [-StreamName <String>] [-EntityType <String>] [-TopType <String>] [-TopEntityField <String>] [-Timeframe <Int32>] [-AppId <Int32>] [-Limit <Int32>] [-Skip <Int32>] [-Offset <Int32>] [-SortField <String>] [-SortDirection <String>] [-Filters <Hashtable>] [-CategoryFilter <String>] [-Metric <String>] [-LocationType <String>] [-Search <String>] [-LocationId <String>] [-ExcludeSanctioned] [-ExcludeUnsanctioned] [-ExcludeOther] [-Force]
Get-XdrCloudAppsDiscovery -ListStreams [-Force]
Get-XdrCloudAppsDiscovery -DeanonymizeUser -Usernames <String[]> -Justification <String> [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Type | String | yes |  | The type of discovery data to retrieve. Valid values are: - Category: App category definitions (no StreamId required) - CategoryStat: Category statistics with traffic/user data - Constant: Discovery constants and enumerations (no StreamId required) - Entity: Entities (IP, Machine, User, Resource) - use with -EntityType - Location: Discovery service locations (no StreamId required) - Top: Top apps, categories, or entities - use with -TopType - UnsanctionedApp: Apps marked as unsanctioned/blocked Values: Category, CategoryStat, Constant, Entity, Location, Top, UnsanctionedApp |
| -ListStreams | SwitchParameter | yes | False | When specified, lists all available discovery streams. Useful for discovering stream IDs and names before querying data. |
| -DeanonymizeUser | SwitchParameter | yes | False | When specified, deanonymizes Cloud Discovery usernames using the provided justification text. |
| -Usernames | String[] | yes |  | One or more anonymized Cloud Discovery usernames to deanonymize. |
| -Justification | String | yes |  | Required justification for deanonymizing Cloud Discovery usernames. |
| -StreamId | String |  |  | The ID of the discovery stream to query. If not specified for types that require it, queries all available streams. Accepts pipeline input from Get-XdrCloudAppsConfiguration -Type DiscoveryStream via the _id property. |
| -StreamName | String |  |  | The name of the discovery stream to query. Supports wildcards (e.g., "Defender*"). If not specified along with StreamId, queries all available streams for types that require it. |
| -EntityType | String |  |  | Required when Type is Entity. Specifies the entity type to retrieve. Valid values are: IP, Machine, User, Resource Values: IP, Machine, User, Resource |
| -TopType | String |  |  | Required when Type is Top. Specifies what top data to retrieve. Valid values are: App, Category, Entity (use with -TopEntityField) Values: App, Category, Entity |
| -TopEntityField | String |  |  | Required when Type is Top and TopType is Entity. Specifies the entity field. Valid values are: users, machines, ipAddresses Values: users, machines, ipAddresses |
| -Timeframe | Int32 |  | 30 | The number of days to include in the results. Default is 30 days. Applies to CategoryStat, Entity, Top, and UnsanctionedApp types. |
| -AppId | Int32 |  | 0 | Optional app ID to filter entities by a specific application. Only applies to Entity type (not Resource EntityType). |
| -Limit | Int32 |  | 0 | Maximum number of results to return. Applies to Entity and Top types. |
| -Skip | Int32 |  | 0 | Number of results to skip for pagination. Applies to Entity type. |
| -Offset | Int32 |  | 0 | Number of results to skip for pagination. Applies to Top type. |
| -SortField | String |  | lastSeen | The field to sort results by. Applies to Entity type. Default is "lastSeen". |
| -SortDirection | String |  | desc | The sort direction. Valid values are "asc" or "desc". Default is "desc". Values: asc, desc |
| -Filters | Hashtable |  | @{} | A hashtable of filters to apply to the query. Applies to Entity type. |
| -CategoryFilter | String |  | all | Filter top apps to a specific category. Only applies to Top type with TopType App. |
| -Metric | String |  | traffic | The metric used to rank results. Valid values are traffic, users, transactions, upload. Applies to Top type with TopType App or Category. Default is traffic. Values: traffic, users, transactions, upload |
| -LocationType | String |  | hq | The type of location to retrieve. Valid values are "hq", "branch", or "". Only applies to Location type. Default is "hq". Values: hq, branch, |
| -Search | String |  |  | A search string to filter locations. Only applies to Location type. |
| -LocationId | String |  |  | A specific location ID to retrieve. Only applies to Location type. |
| -ExcludeSanctioned | SwitchParameter |  | False | Excludes sanctioned apps. Only applies to Top type with TopType Category. |
| -ExcludeUnsanctioned | SwitchParameter |  | False | Excludes unsanctioned apps. Only applies to Top type with TopType Category. |
| -ExcludeOther | SwitchParameter |  | False | Excludes apps with no sanction status. Only applies to Top type with TopType Category. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrCloudAppsDiscovery -ListStreams
```

Lists all available discovery streams.

Example 2:

```powershell
Get-XdrCloudAppsDiscovery -DeanonymizeUser -Usernames "User_aaaaaabbbbb=" -Justification "Incident response investigation"
```

Deanonymizes a Cloud Discovery username.

Example 3:

```powershell
Get-XdrCloudAppsDiscovery -Type Category
```

Retrieves all app category definitions.

Example 4:

```powershell
Get-XdrCloudAppsDiscovery -Type Constant
```

Retrieves discovery constants and enumerations.

Example 5:

```powershell
Get-XdrCloudAppsDiscovery -Type Location -LocationType branch
```

Retrieves branch office locations.

Example 6:

```powershell
Get-XdrCloudAppsDiscovery -Type CategoryStat
Retrieves category statistics from ALL streams (includes stream context on results).
```

Example 7:

```powershell
Get-XdrCloudAppsDiscovery -Type CategoryStat -StreamName "Defender*"
```

Retrieves category statistics from streams matching the wildcard pattern.

Example 8:

```powershell
Get-XdrCloudAppsDiscovery -Type Entity -EntityType IP
```

Retrieves discovered IP addresses from ALL streams.

Example 9:

```powershell
Get-XdrCloudAppsDiscovery -Type Entity -StreamId "64a75731967076e7d6bd00ea" -EntityType User -Limit 50
```

Retrieves up to 50 discovered users from a specific stream.

Example 10:

```powershell
Get-XdrCloudAppsDiscovery -Type Top -TopType App
```

Retrieves top discovered apps from ALL streams.

Example 11:

```powershell
Get-XdrCloudAppsDiscovery -Type Top -StreamName "Defender-managed endpoints" -TopType Entity -TopEntityField users
```

Retrieves top users by app usage from a specific stream.

Example 12:

```powershell
Get-XdrCloudAppsDiscovery -Type UnsanctionedApp
```

Retrieves apps marked as unsanctioned from ALL streams.

Example 13:

```powershell
Get-XdrCloudAppsConfiguration -Type DiscoveryStream | Get-XdrCloudAppsDiscovery -Type Entity -EntityType Machine
```

Retrieves discovered machines from all streams via pipeline.

## Get-XdrCloudAppsGeneralSetting

Guard: `read`

Retrieves general settings from Microsoft Defender for Cloud Apps (Cloud Apps).

Compatibility wrapper for the legacy Cloud Apps general settings cmdlet.
Calls the grouped configuration cmdlet and returns the settings object with
the legacy output shape so existing scripts do not break.

```powershell
Get-XdrCloudAppsGeneralSetting [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses cache-backed requests. |

Example 1:

```powershell
Get-XdrCloudAppsGeneralSetting
```

Retrieves the Cloud Apps general settings.

Example 2:

```powershell
Get-XdrCloudAppsGeneralSetting -Force
```

Forces a fresh retrieval of the Cloud Apps general settings.

## Get-XdrCloudAppsGovernance

Guard: `read`

Retrieves governance data from Microsoft Defender for Cloud Apps and App Governance.

Retrieves live-validated App Governance summary, app, policy, label,
user profile, and tenant metric data.

```powershell
Get-XdrCloudAppsGovernance [-Type <String>] [-Id <String>] [-Raw] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Type | String |  | Summary | Governance data type to retrieve. Values: Summary, App, Label, Policy, PolicyInsight, UserProfile, TenantStatus, TenantMetric, TenantDataTraffic, InsightsReady |
| -Id | String |  |  | Identifier for item-specific governance queries. |
| -Raw | SwitchParameter |  | False | Returns the raw API response shape. |
| -Force | SwitchParameter |  | False | Bypasses cache-backed requests. |

Example 1:

```powershell
Get-XdrCloudAppsGovernance
```

Retrieves an App Governance summary.

Example 2:

```powershell
Get-XdrCloudAppsGovernance -Type App
```

Retrieves App Governance app data.

## Get-XdrCloudAppsPolicy

Guard: `read`

Retrieves policies from Microsoft Defender for Cloud Apps.

The Get-XdrCloudAppsPolicy cmdlet retrieves policies from Microsoft Defender for Cloud Apps.
Policies help control and govern cloud application usage and data protection within your
organization. You can filter, sort, and paginate the results using the available parameters.

Use -Type to retrieve specific policy types (ConditionalAccess, File, InformationProtection,
OAuth, ShadowIT, Template, ThreatDetection). Use -Metadata with -Type to get filter and field
definitions for that policy type. Use -Setting to retrieve policy settings.

For File and OAuth policies, additional options are available:
- Use -PolicyId with -Type to retrieve a specific policy by ID
- Use -Action with -Type File or -Type OAuth to get available actions
- Use -PolicyLimit with -Type File to get file policy limits

```powershell
Get-XdrCloudAppsPolicy [-Limit <Int32>] [-Skip <Int32>] [-SortField <String>] [-SortDirection <String>] [-Filters <Hashtable>] [-Force]
Get-XdrCloudAppsPolicy -Type <String> -PolicyId <String> [-Force]
Get-XdrCloudAppsPolicy -Type <String> -PolicyLimit [-Force]
Get-XdrCloudAppsPolicy -Type <String> -Action [-Force]
Get-XdrCloudAppsPolicy -Type <String> -Metadata [-Force]
Get-XdrCloudAppsPolicy -Type <String> [-Limit <Int32>] [-Skip <Int32>] [-SortField <String>] [-SortDirection <String>] [-Filters <Hashtable>] [-Force]
Get-XdrCloudAppsPolicy -PolicyId <String> [-Force]
Get-XdrCloudAppsPolicy -Setting [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Type | String | yes |  | The type of policies to retrieve. Valid values are: - ConditionalAccess: Policies controlling access based on conditions - File: File policies for data protection - InformationProtection: Policies protecting sensitive data - OAuth: OAuth app policies for third-party app governance - ShadowIT: Policies detecting unsanctioned cloud app usage - Template: Pre-configured policy templates - ThreatDetection: Policies identifying security threats Values: ConditionalAccess, File, InformationProtection, OAuth, ShadowIT, Template, ThreatDetection |
| -PolicyId | String | yes |  | The unique identifier of a specific policy to retrieve. If -Type is specified, retrieves from that policy type's endpoint. If -Type is not specified, attempts to discover the policy type automatically. |
| -Metadata | SwitchParameter | yes | False | When specified with -Type, retrieves metadata including available filters, fields, and configuration options instead of the policies themselves. |
| -Action | SwitchParameter | yes | False | When specified with -Type File or -Type OAuth, retrieves available actions that can be configured for those policy types. |
| -PolicyLimit | SwitchParameter | yes | False | When specified with -Type File, retrieves file policy limits and constraints. |
| -Setting | SwitchParameter | yes | False | When specified, retrieves policy settings configuration. |
| -Limit | Int32 |  | 20 | The maximum number of policies to return. Default is 20. |
| -Skip | Int32 |  | 0 | The number of policies to skip for pagination. Default is 0. |
| -SortField | String |  | severity | The field to sort results by. Default is "severity". |
| -SortDirection | String |  | desc | The sort direction. Valid values are "asc" or "desc". Default is "desc". Values: asc, desc |
| -Filters | Hashtable |  | @{} | A hashtable of filters to apply to the policies query. |
| -Force | SwitchParameter |  | False | Bypasses the cache and retrieves fresh data from the API. |

Example 1:

```powershell
Get-XdrCloudAppsPolicy
```

Retrieves all policies sorted by severity (highest first).

Example 2:

```powershell
Get-XdrCloudAppsPolicy -Type ConditionalAccess
```

Retrieves conditional access policies.

Example 3:

```powershell
Get-XdrCloudAppsPolicy -Type File
```

Retrieves file policies.

Example 4:

```powershell
Get-XdrCloudAppsPolicy -Type OAuth
```

Retrieves OAuth app policies.

Example 5:

```powershell
Get-XdrCloudAppsPolicy -Type File -PolicyId "abc123"
```

Retrieves a specific file policy by ID.

Example 6:

```powershell
Get-XdrCloudAppsPolicy -PolicyId "abc123"
```

Retrieves a policy by ID, automatically discovering the policy type.

Example 7:

```powershell
Get-XdrCloudAppsPolicy -Type ThreatDetection -Metadata
```

Retrieves metadata for threat detection policies including available filters.

Example 8:

```powershell
Get-XdrCloudAppsPolicy -Type OAuth -Metadata
```

Retrieves metadata for OAuth policies including available filters.

Example 9:

```powershell
Get-XdrCloudAppsPolicy -Type File -Action
```

Retrieves available actions for file policies.

Example 10:

```powershell
Get-XdrCloudAppsPolicy -Type OAuth -Action
```

Retrieves available actions for OAuth policies.

Example 11:

```powershell
Get-XdrCloudAppsPolicy -Type File -PolicyLimit
```

Retrieves file policy limits and constraints.

Example 12:

```powershell
Get-XdrCloudAppsPolicy -Type ShadowIT -Limit 50 -SortField "name" -SortDirection "asc"
```

Retrieves 50 Shadow IT policies sorted by name ascending.

Example 13:

```powershell
Get-XdrCloudAppsPolicy -Type Template
```

Retrieves policy templates.

Example 14:

```powershell
$filters = @{ "enabled" = @{ "eq" = @($true) } }
Get-XdrCloudAppsPolicy -Type InformationProtection -Filters $filters
```

Retrieves enabled information protection policies.

Example 15:

```powershell
Get-XdrCloudAppsPolicy -Setting
```

Retrieves policy settings configuration.

Example 16:

```powershell
Get-XdrCloudAppsPolicy -Force
```

Forces a fresh retrieval of all policies, bypassing the cache.

## Set-XdrCloudAppsDiscoveredApp

Guard: `write`

Updates a discovered app note in Microsoft Defender for Cloud Apps.

Updates the admin note for a discovered Cloud Apps application. This is
the only live-validated discovered-app write surface currently exposed.

```powershell
Set-XdrCloudAppsDiscoveredApp -AppId <String> -Note <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -AppId | String | yes |  | The unique identifier of the discovered app to update. |
| -Note | String | yes |  | The note text to set for the discovered app. |

Example 1:

```powershell
Set-XdrCloudAppsDiscoveredApp -AppId "12345" -Note "Approved for marketing team use"
```

Sets a note on the discovered app.

