# Endpoint devices, timelines, response actions and Live Response

30 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Connect-XdrEndpointDeviceLiveResponse

Guard: `write`

Opens a Live Response session to an endpoint device in Microsoft Defender XDR.

Creates a Live Response session to the specified device. By default, the cmdlet
provides an interactive command-line interface where you can type Live Response
commands and see results.

When -NonInteractive is specified, the cmdlet establishes the session, loads
command definitions, and returns a session object without entering the prompt loop.

Type 'disconnect' or 'exit' to close the session and return to PowerShell.
Type 'help' to see available Live Response commands.

Available Live Response commands include:
analyze, cd, cls, connect, connections, dir, drivers, fg, fileinfo, findfile,
getfile, help, jobs, library, log, persistence, prefetch, processes, putfile,
registry, remediate, run, scheduledtasks, services, startupfolders, status,
trace, undo

Command aliases (e.g. ls, process, download) are supported and resolved automatically.
Use 'help <command>' for detailed syntax and flags for a specific command.

```powershell
Connect-XdrEndpointDeviceLiveResponse -DeviceId <String> [-DeviceName <String>] [-LastSeen <Object>] [-OsPlatform <String>] [-NonInteractive] [-NoStatusTable]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The device ID (SenseMachineId) of the target device. |
| -DeviceName | String |  |  | Optional device name used for progress display and to avoid an extra lookup when device metadata is already available from pipeline input. |
| -LastSeen | Object |  |  | Optional last seen timestamp from pipeline input. When provided together with other device metadata, the cmdlet can reuse it during non-interactive session creation. |
| -OsPlatform | String |  |  | Optional operating system platform from pipeline input. Used to determine the initial working directory without requiring an additional device metadata lookup. |
| -NonInteractive | SwitchParameter |  | False | Connects to Live Response and returns a session object without starting the interactive prompt loop. |
| -NoStatusTable | SwitchParameter |  | False | Suppresses the live status table shown during multi-device non-interactive session creation. Returned session objects are unchanged. |

Example 1:

```powershell
Connect-XdrEndpointDeviceLiveResponse -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2"
```

Opens an interactive Live Response session to the specified device.

Example 2:

```powershell
$lr = Connect-XdrEndpointDeviceLiveResponse -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -NonInteractive
```

Connects to the device and returns a session object for script-driven command execution.

Example 3:

```powershell
$devices | Connect-XdrEndpointDeviceLiveResponse -NonInteractive -NoStatusTable
```

Connects to multiple devices without rendering the live status table.

Example 4:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -LiveResponse
```

Opens a Live Response session via the unified action cmdlet.

## Disconnect-XdrEndpointDeviceLiveResponse

Guard: `write`

Closes an active Live Response session in Microsoft Defender XDR.

Closes an active Live Response session by calling the close_session API.
This should be called when done with a Live Response session to free resources.
Also clears the script-scoped LiveResponseSession variable if it matches.

```powershell
Disconnect-XdrEndpointDeviceLiveResponse -SessionId <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -SessionId | String | yes |  | The Live Response session ID to close (starts with CLR prefix). |

Example 1:

```powershell
Disconnect-XdrEndpointDeviceLiveResponse -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb"
```

Closes the specified Live Response session.

Example 2:

```powershell
$sessions | Disconnect-XdrEndpointDeviceLiveResponse
```

Closes Live Response sessions passed through the pipeline.

## Get-XdrActionsCenterHistory

Guard: `read`

Retrieves historical actions from the Microsoft Defender XDR Action Center.

Gets a list of historical actions from the Microsoft Defender XDR Action Center with options to filter by date range, sort, and paginate the results.

```powershell
Get-XdrActionsCenterHistory [-SortByField <String>] [-SortOrder <String>] [-PageIndex <Int32>] [-PageSize <Int32>] [-ToDate <DateTime>] [-Months <Int32>] [-UseMtpApi <Boolean>]
Get-XdrActionsCenterHistory [-SortByField <String>] [-SortOrder <String>] [-PageIndex <Int32>] [-PageSize <Int32>] [-ToDate <DateTime>] [-FromDate <DateTime>] [-UseMtpApi <Boolean>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -SortByField | String |  | ActionUpdateTime | The field to sort actions by. Valid values are: InvestigationId, ApprovalId, ActionType, EntityType, Asset, Decision, DecidedBy, ActionSource, Status, ActionUpdateTime. Defaults to 'ActionUpdateTime'. Values: InvestigationId, ApprovalId, ActionType, EntityType, Asset, Decision, DecidedBy, ActionSource, Status, ActionUpdateTime |
| -SortOrder | String |  | Descending | The sort order for results. Valid values are 'Ascending' or 'Descending'. Defaults to 'Descending'. Values: Ascending, Descending |
| -PageIndex | Int32 |  | 1 | The page index for pagination. Defaults to 1. |
| -PageSize | Int32 |  | 100 | The number of actions to return per page. Defaults to 100. |
| -ToDate | DateTime |  | (Get-Date) | The end date for the history query. Defaults to current time. |
| -FromDate | DateTime |  |  | The start date for the history query. Defaults to 6 months before ToDate. |
| -Months | Int32 |  | 6 | The number of months to look back from the current date. Cannot be used together with FromDate parameter. Defaults to 6 months if neither FromDate nor Months is specified. |
| -UseMtpApi | Boolean |  | True | Whether to use the MTP API. Defaults to $true. |

Example 1:

```powershell
Get-XdrActionsCenterHistory
```

Retrieves the last 6 months of action center history with default settings.

Example 2:

```powershell
Get-XdrActionsCenterHistory -PageSize 50 -PageIndex 2
```

Retrieves the second page of 50 historical actions.

Example 3:

```powershell
Get-XdrActionsCenterHistory -Months 3
```

Retrieves the last 3 months of action center history.

Example 4:

```powershell
Get-XdrActionsCenterHistory -FromDate (Get-Date).AddDays(-30) -ToDate (Get-Date)
```

Retrieves the last 30 days of action center history.

Example 5:

```powershell
Get-XdrActionsCenterHistory -SortByField "ActionUpdateTime" -SortOrder "Ascending"
```

Retrieves actions sorted by action update time in ascending order.

## Get-XdrActionsCenterPending

Guard: `read`

Retrieves pending actions from the Microsoft Defender XDR Action Center.

Gets a list of pending actions from the Microsoft Defender XDR Action Center with options to sort and paginate the results.

```powershell
Get-XdrActionsCenterPending [-SortByField <String>] [-SortOrder <String>] [-PageIndex <Int32>] [-PageSize <Int32>] [-UseMtpApi <Boolean>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -SortByField | String |  | ActionUpdateTime | The field to sort actions by. Valid values are: InvestigationId, ApprovalId, ActionType, EntityType, Asset, Decision, DecidedBy, ActionSource, Status, ActionUpdateTime. Defaults to 'ActionUpdateTime'. Values: InvestigationId, ApprovalId, ActionType, EntityType, Asset, Decision, DecidedBy, ActionSource, Status, ActionUpdateTime |
| -SortOrder | String |  | Descending | The sort order for results. Valid values are 'Ascending' or 'Descending'. Defaults to 'Descending'. Values: Ascending, Descending |
| -PageIndex | Int32 |  | 1 | The page index for pagination. Defaults to 1. |
| -PageSize | Int32 |  | 100 | The number of actions to return per page. Defaults to 100. |
| -UseMtpApi | Boolean |  | True | Whether to use the MTP API. Defaults to $true. |

Example 1:

```powershell
Get-XdrActionsCenterPending
```

Retrieves pending actions from the Action Center with default settings.

Example 2:

```powershell
Get-XdrActionsCenterPending -PageSize 50 -PageIndex 2
```

Retrieves the second page of 50 pending actions.

Example 3:

```powershell
Get-XdrActionsCenterPending -SortByField "ActionUpdateTime" -SortOrder "Ascending"
```

Retrieves pending actions sorted by action update time in ascending order.

## Get-XdrEndpointDevice

Guard: `read`

Retrieves endpoint devices from Microsoft Defender XDR.

Gets endpoint devices from the Microsoft Defender XDR portal. Supports two modes:
- List (default): Retrieves devices with options to filter, sort, and paginate results.
- DeviceId: Retrieves detailed information for a single device by its identifier.
  Uses the getMachine API and caches results for 5 minutes.

```powershell
Get-XdrEndpointDevice [-MachineSearchPrefix <String>] [-LookingBackInDays <Int32>] [-PageIndex <Int32>] [-PageSize <Int32>] [-SortByField <String>] [-SortOrder <String>] [-HideLowFidelityDevices <Boolean>]
Get-XdrEndpointDevice -DeviceId <String> [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The device identifier (also known as MachineId or SenseMachineId). When specified, retrieves detailed information for a single device. Results are cached for 5 minutes. |
| -Force | SwitchParameter |  | False | Bypasses the cache when using -DeviceId and forces a fresh retrieval from the API. |
| -MachineSearchPrefix | String |  |  | Optional. Search for devices by name prefix. Use this to filter devices whose names start with the specified string. |
| -LookingBackInDays | Int32 |  | 30 | The number of days to look back for device data. Defaults to 30 days. |
| -PageIndex | Int32 |  | 1 | The page index for pagination. Defaults to 1. |
| -PageSize | Int32 |  | 25 | The number of devices to return per page. Defaults to 25. |
| -SortByField | String |  | riskscore | The field to sort devices by. Defaults to 'riskscore'. |
| -SortOrder | String |  | Descending | The sort order for results. Valid values are 'Ascending' or 'Descending'. Defaults to 'Descending'. Values: Ascending, Descending |
| -HideLowFidelityDevices | Boolean |  | True | Whether to hide low fidelity devices from the results. Defaults to $true. |

Example 1:

```powershell
Get-XdrEndpointDevice
```

Retrieves the first 25 devices sorted by risk score in descending order using default settings.

Example 2:

```powershell
Get-XdrEndpointDevice -PageSize 100 -PageIndex 2
```

Retrieves the second page of 100 devices.

Example 3:

```powershell
Get-XdrEndpointDevice -SortByField "lastSeen" -SortOrder "Ascending"
```

Retrieves devices sorted by last seen date in ascending order.

Example 4:

```powershell
Get-XdrEndpointDevice -HideLowFidelityDevices $false -LookingBackInDays 90
```

Retrieves devices including low fidelity devices with a 90-day lookback period.

Example 5:

```powershell
Get-XdrEndpointDevice -MachineSearchPrefix "DESKTOP"
```

Retrieves devices whose names start with "DESKTOP".

Example 6:

```powershell
Get-XdrEndpointDevice -DeviceId "abc123def456"
```

Retrieves detailed information for a single device by its identifier.

## Get-XdrEndpointDeviceActionResult

Guard: `read`

Gets device action results and download URIs from Microsoft Defender XDR.

Retrieves the latest device action results for a device, or downloads completed
investigation package or support log collection results.

When called with just -DeviceId, returns the latest action results for each action type
including status, requestor, timestamps, and request GUIDs.

When called with -DownloadInvestigationPackage or -DownloadSupportLogs, retrieves the
download URI for completed collection results. You can provide either a DeviceId (which
auto-resolves the latest RequestGuid from machine state) or a RequestGuid directly.

```powershell
Get-XdrEndpointDeviceActionResult -DeviceId <String> [-RequestGuid <String>]
Get-XdrEndpointDeviceActionResult -DeviceId <String> -DownloadSupportLogs
Get-XdrEndpointDeviceActionResult -DeviceId <String> -DownloadInvestigationPackage
Get-XdrEndpointDeviceActionResult -DownloadInvestigationPackage -RequestGuid <String>
Get-XdrEndpointDeviceActionResult -DownloadSupportLogs -RequestGuid <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The device identifier (SenseMachineId) to query action results for. Accepts pipeline input by property name and supports MachineId/SenseMachineId aliases. |
| -DownloadInvestigationPackage | SwitchParameter | yes | False | Retrieve the download URI for the latest investigation package (forensics) collection. |
| -DownloadSupportLogs | SwitchParameter | yes | False | Retrieve the download URI for the latest support logs collection. |
| -RequestGuid | String |  |  | The GUID of a specific request. When used with -DeviceId (List mode), filters the results to the matching request. When used with -DownloadInvestigationPackage or -DownloadSupportLogs, specifies the completed request to download results for. |

Example 1:

```powershell
Get-XdrEndpointDeviceActionResult -DeviceId "55a5db7b474470725e0131dec38c07b2f54bf2ad"
```

Gets the latest action results for the specified device.

Example 2:

```powershell
Get-XdrEndpointDeviceActionResult -DeviceId "55a5db7b474470725e0131dec38c07b2f54bf2ad" -RequestGuid "1b2010b8-143e-441b-b5e9-c0b56c090a24"
```

Gets the action result for a specific request on the device.

Example 3:

```powershell
Get-XdrEndpointDevice -DeviceId $deviceId | Get-XdrEndpointDeviceActionResult
```

Gets action results for a device using pipeline input.

Example 4:

```powershell
Get-XdrEndpointDeviceActionResult -DownloadInvestigationPackage -DeviceId "55a5db7b474470725e0131dec38c07b2f54bf2ad"
```

Auto-resolves the latest investigation package request and returns its download URI.

Example 5:

```powershell
Get-XdrEndpointDevice -DeviceId $deviceId | Get-XdrEndpointDeviceActionResult -DownloadSupportLogs
```

Gets the download URI for the latest support logs collection using pipeline input.

Example 6:

```powershell
Get-XdrEndpointDeviceActionResult -DownloadInvestigationPackage -RequestGuid "b28b630c-d1a1-4b1d-9676-680c15366a52"
```

Downloads the investigation package for a specific request to the current working directory.

Example 7:

```powershell
Get-XdrEndpointDeviceActionResult -DownloadSupportLogs -RequestGuid "abc12345-6789-0123-4567-890abcdef012"
```

Downloads the support logs for a specific request to the current working directory.

## Get-XdrEndpointDeviceLiveResponseLibrary

Guard: `read`

Retrieves the Live Response library files from Microsoft Defender XDR.

Gets the list of files available in the Live Response library.
These files can be used with the 'putfile' and 'run' commands during Live Response sessions.
Results are cached for 15 minutes.

```powershell
Get-XdrEndpointDeviceLiveResponseLibrary [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceLiveResponseLibrary
```

Lists all files in the Live Response library.

Example 2:

```powershell
Get-XdrEndpointDeviceLiveResponseLibrary -Force
```

Forces a fresh retrieval of the library file list.

## Get-XdrEndpointDeviceLiveResponseLibraryFile

Guard: `read`

Downloads a script file from the Live Response library.

Retrieves the content of a specific file from the Microsoft Defender XDR Live Response library.
Accepts pipeline input from Get-XdrEndpointDeviceLiveResponseLibrary.
If -OutputPath is specified, the file is saved to disk. Otherwise the decoded content is returned as a string.

```powershell
Get-XdrEndpointDeviceLiveResponseLibraryFile -FileName <String> [-OutputPath <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -FileName | String | yes |  | The name of the file to download from the library (e.g. 'PasskeyLogin.ps1'). Accepts ValueFromPipelineByPropertyName, so objects from Get-XdrEndpointDeviceLiveResponseLibrary pipe directly using the file_name property. |
| -OutputPath | String |  |  | Optional file path to save the downloaded content. If omitted, the content is returned as a string. |

Example 1:

```powershell
Get-XdrEndpointDeviceLiveResponseLibraryFile -FileName 'PasskeyLogin.ps1'
```

Returns the content of PasskeyLogin.ps1 as a string.

Example 2:

```powershell
Get-XdrEndpointDeviceLiveResponseLibraryFile -FileName 'PasskeyLogin.ps1' -OutputPath 'C:\Temp\PasskeyLogin.ps1'
```

Downloads and saves the file to disk.

Example 3:

```powershell
Get-XdrEndpointDeviceLiveResponseLibrary | Where-Object file_name -eq 'PasskeyLogin.ps1' | Get-XdrEndpointDeviceLiveResponseLibraryFile
```

Downloads a library file using pipeline input.

## Get-XdrEndpointDeviceModel

Guard: `read`

Retrieves all device models from Microsoft Defender for Endpoint.

Gets a list of all device models (hardware models) from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointDeviceModel [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceModel
```

Retrieves all device models using cached data if available.

Example 2:

```powershell
Get-XdrEndpointDeviceModel -Force
```

Forces a fresh retrieval of device models, bypassing the cache.

## Get-XdrEndpointDeviceOsVersionFriendlyName

Guard: `read`

Retrieves all OS version friendly names from Microsoft Defender for Endpoint.

Gets a list of all operating system version friendly names from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointDeviceOsVersionFriendlyName [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceOsVersionFriendlyName
```

Retrieves all OS version friendly names using cached data if available.

Example 2:

```powershell
Get-XdrEndpointDeviceOsVersionFriendlyName -Force
```

Forces a fresh retrieval of OS version friendly names, bypassing the cache.

## Get-XdrEndpointDeviceRbacGroup

Guard: `read`

Retrieves device groups for Defender for Endpoint.

Retrieves device groups for Defender for Endpoint.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointDeviceRbacGroup [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceRbacGroup
```

Retrieves device groups for Defender for Endpoint.

Example 2:

```powershell
Get-XdrEndpointDeviceRbacGroup -Force
```

Forces a fresh retrieval, bypassing the cache.

## Get-XdrEndpointDeviceRbacGroupScope

Guard: `read`

Retrieves all RBAC groups from Microsoft Defender for Endpoint.

Gets a list of all Role-Based Access Control (RBAC) device groups from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointDeviceRbacGroupScope [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceRbacGroupScope
```

Retrieves all RBAC groups using cached data if available.

Example 2:

```powershell
Get-XdrEndpointDeviceRbacGroupScope -Force
```

Forces a fresh retrieval of RBAC groups, bypassing the cache.

## Get-XdrEndpointDeviceTag

Guard: `read`

Retrieves all device tags from Microsoft Defender for Endpoint.

Gets device tags from the Microsoft Defender XDR portal. Supports two modes:
- All (default): Retrieves all device tags in the tenant.
- DeviceId: Retrieves tags for a single device via the machineTags API.
  Returns an object with BuiltInTags, UserDefinedTags, and DynamicRulesTags arrays.
  Results are cached for 5 minutes.
This function includes caching support to reduce API calls.

```powershell
Get-XdrEndpointDeviceTag [-Force]
Get-XdrEndpointDeviceTag -DeviceId <String> [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The device identifier (also known as MachineId or SenseMachineId). When specified, retrieves the tags for a single device. Results are cached for 5 minutes. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceTag
```

Retrieves all device tags using cached data if available.

Example 2:

```powershell
Get-XdrEndpointDeviceTag -Force
```

Forces a fresh retrieval of device tags, bypassing the cache.

Example 3:

```powershell
Get-XdrEndpointDeviceTag -DeviceId "abc123def456"
```

Returns an object with BuiltInTags, UserDefinedTags, and DynamicRulesTags arrays.

Example 4:

```powershell
(Get-XdrEndpointDeviceTag -DeviceId "abc123def456").UserDefinedTags
```

Returns only the user-defined tags for a single device.

## Get-XdrEndpointDeviceTimeline

Guard: `read`

Retrieves the timeline of events for a specific device from Microsoft Defender XDR.

Gets the timeline of security events for a device from the Microsoft Defender XDR portal with options to filter by date range and other parameters.
Uses parallel chunked requests (1-hour intervals) to improve performance and support longer date ranges up to 180 days.

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId <String> [-FromDate <DateTime>] [-ToDate <DateTime>] [-LastNDays <Int32>] [-PageSize <Int32>] [-MarkedEventsOnly] [-SenseClientVersion <String>] [-SkipIdentityEvents] [-SkipMdiOnlyEvents] [-DoNotUseCache] [-ForceUseCache] [-IncludeSentinelEvents] [-EventType <String>] [-EventsGroups <String[]>] [-DataTypes <String[]>] [-SourceProviders <String[]>] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkHours <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-AllowPartial] [-ExportPath <String>]
Get-XdrEndpointDeviceTimeline -MachineDnsName <String> [-FromDate <DateTime>] [-ToDate <DateTime>] [-LastNDays <Int32>] [-PageSize <Int32>] [-MarkedEventsOnly] [-SenseClientVersion <String>] [-SkipIdentityEvents] [-SkipMdiOnlyEvents] [-DoNotUseCache] [-ForceUseCache] [-IncludeSentinelEvents] [-EventType <String>] [-EventsGroups <String[]>] [-DataTypes <String[]>] [-SourceProviders <String[]>] [-ThrottleLimit <Int32>] [-TimeoutSeconds <Int32>] [-MaxRetries <Int32>] [-RetryDelaySeconds <Int32>] [-ChunkHours <Int32>] [-OutputPath <String>] [-KeepTempFiles] [-AllowPartial] [-ExportPath <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The unique identifier of the device. Accepts pipeline input and can also be specified as MachineId. Use this parameter set when identifying the device by ID. |
| -MachineDnsName | String | yes |  | The DNS name of the machine. Use this parameter set when identifying the device by DNS name. |
| -FromDate | DateTime |  | ((Get-Date).AddHours(-1)) | The start date for the timeline. Defaults to 1 hour before current time. |
| -ToDate | DateTime |  | (Get-Date) | The end date for the timeline. Defaults to current time. |
| -LastNDays | Int32 |  | 0 | Specifies the number of days to look back. Overrides FromDate and ToDate if specified. |
| -PageSize | Int32 |  | 1000 | The number of events to return per page. Defaults to 1000 for optimal performance. |
| -MarkedEventsOnly | SwitchParameter |  | False | Only return events that have been marked in the timeline. |
| -SenseClientVersion | String |  |  | Optional. The version of the Sense client. |
| -SkipIdentityEvents | SwitchParameter |  | False | Skip generating and including identity events. By default, identity events are included. |
| -SkipMdiOnlyEvents | SwitchParameter |  | False | Skip MDI-only events. By default, MDI-only events are supported. |
| -DoNotUseCache | SwitchParameter |  | False | Bypass the API cache when retrieving timeline data. |
| -ForceUseCache | SwitchParameter |  | False | Force using the API cache when retrieving timeline data. |
| -IncludeSentinelEvents | SwitchParameter |  | False | Include Sentinel events in the timeline results. |
| -EventType | String |  |  | Filter events by type. Supports wildcards. Examples: 'Process*', 'Network*', 'File*'. |
| -EventsGroups | String[] |  |  | Filter events by group category. Accepts one or more of the following values: AlertsRelatedEvents, AntiVirus, AppGuard, AppControl, ExploitGuard, Files, Firewall, Network, Processes, Registry, ResponseActions, ScheduledTask, SmartScreen, Other, UserActivity. Multiple values can be specified to include multiple event groups. Values: AlertsRelatedEvents, AntiVirus, AppGuard, AppControl, ExploitGuard, Files, Firewall, Network, Processes, Registry, ResponseActions, ScheduledTask, SmartScreen, Other, UserActivity |
| -DataTypes | String[] |  |  | Filter events by data type. Accepts one or more of the following values: Events, Techniques. Multiple values can be specified to include multiple data types. Values: Events, Techniques |
| -SourceProviders | String[] |  |  | Filter events by source provider. Accepts one or more of the following values: MDE, MDI. Multiple values can be specified to include multiple source providers. Values: MDE, MDI |
| -ThrottleLimit | Int32 |  | 10 | The maximum number of concurrent requests. Defaults to 10. |
| -TimeoutSeconds | Int32 |  | 3600 | Maximum time in seconds to wait for all requests to complete. Defaults to 3600 (1 hour). |
| -MaxRetries | Int32 |  | 10 | Maximum number of retry attempts for failed API requests. Defaults to 10. |
| -RetryDelaySeconds | Int32 |  | 30 | Base delay in seconds between retry attempts (uses exponential backoff). Defaults to 30. |
| -ChunkHours | Int32 |  | 4 | The size of each time chunk in hours for parallel processing. Defaults to 4 hours. For time windows of 40 hours or less, chunk size is automatically calculated as totalHours/10. Larger chunks reduce overhead but may increase individual request times. |
| -OutputPath | String |  |  | Optional. The path to store temporary JSON files. Defaults to a temp folder. |
| -KeepTempFiles | SwitchParameter |  | False | If specified, keeps the temporary JSON files after merging. |
| -AllowPartial | SwitchParameter |  | False | Returns completed chunks when one or more chunks fail or the request times out. By default, the cmdlet fails rather than returning incomplete timeline data. |
| -ExportPath | String |  |  | Optional. Export results directly to a JSON file at the specified path. |

Example 1:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2"
```

Retrieves the last hour of timeline events for the specified device.

Example 2:

```powershell
Get-XdrEndpointDeviceTimeline -MachineDnsName "computer.contoso.com"
```

Retrieves the last hour of timeline events using the machine DNS name.

Example 3:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -FromDate (Get-Date).AddDays(-7) -ToDate (Get-Date)
```

Retrieves timeline events for the last 7 days using parallel requests.

Example 4:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -LastNDays 90 -ThrottleLimit 5
```

Retrieves 90 days of timeline events with 5 concurrent requests.

Example 5:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -EventType "Process*"
```

Retrieves timeline events filtered to process-related events only.

Example 6:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -LastNDays 7 -ExportPath "C:\Reports\timeline.json"
```

Retrieves 7 days of timeline events and exports directly to a JSON file.

Example 7:

```powershell
"2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" | Get-XdrEndpointDeviceTimeline
```

Retrieves timeline events using pipeline input.

## Get-XdrEndpointDeviceTotals

Guard: `read`

Retrieves the device totals from Microsoft Defender XDR.

Gets the total count of devices from the Microsoft Defender XDR portal with options to filter low fidelity devices and specify the lookback period.

```powershell
Get-XdrEndpointDeviceTotals [-HideLowFidelityDevices <Boolean>] [-LookingBackInDays <Int32>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -HideLowFidelityDevices | Boolean |  | True | Whether to hide low fidelity devices from the results. Defaults to $true. |
| -LookingBackInDays | Int32 |  | 30 | The number of days to look back for device data. Defaults to 30 days. |
| -Force | SwitchParameter |  | False | Whether to force bypassing the cache and retrieve fresh data. Defaults to $false. |

Example 1:

```powershell
Get-XdrEndpointDeviceTotals
Retrieves device totals using default settings (hiding low fidelity devices, 30 days lookback).
```

Example 2:

```powershell
Get-XdrEndpointDeviceTotals -HideLowFidelityDevices $false -LookingBackInDays 90
```

Retrieves device totals including low fidelity devices with a 90-day lookback period.

Example 3:

```powershell
Get-XdrEndpointDeviceTotals -LookingBackInDays 7
```

Retrieves device totals for the last 7 days, hiding low fidelity devices.

## Get-XdrEndpointDeviceVendor

Guard: `read`

Retrieves all device vendors from Microsoft Defender for Endpoint.

Gets a list of all device hardware vendors from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointDeviceVendor [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceVendor
```

Retrieves all device vendors using cached data if available.

Example 2:

```powershell
Get-XdrEndpointDeviceVendor -Force
```

Forces a fresh retrieval of device vendors, bypassing the cache.

## Get-XdrEndpointDeviceWindowsReleaseVersion

Guard: `read`

Retrieves all Windows release versions from Microsoft Defender for Endpoint.

Gets a list of all Windows release versions (e.g., 21H2, 22H2) from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointDeviceWindowsReleaseVersion [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointDeviceWindowsReleaseVersion
```

Retrieves all Windows release versions using cached data if available.

Example 2:

```powershell
Get-XdrEndpointDeviceWindowsReleaseVersion -Force
```

Forces a fresh retrieval of Windows release versions, bypassing the cache.

## Invoke-XdrEndpointDeviceAction

Guard: `write`

Invokes response actions on an endpoint device in Microsoft Defender XDR.

Unified cmdlet for executing device response actions including antivirus scans,
device isolation, app execution restriction, investigation package collection,
support log collection, troubleshooting mode, tag management, asset value,
criticality level, exclusion state, policy sync, automated investigation,
and live response sessions.

For responseApiPortal actions (Scan, Isolate, Restrict, etc.), the cmdlet
auto-fetches OsPlatform and SenseClientVersion from the device.

For other actions, the cmdlet wraps dedicated cmdlets like Set-XdrEndpointDeviceTag,
Set-XdrEndpointDeviceAssetValue, etc.

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -Scan <String>
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -Isolate <String>
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -ReleaseFromIsolation
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -RestrictAppExecution
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -RemoveAppExecutionRestriction
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -CollectInvestigationPackage
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -CollectSupportLogs
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -StartTroubleshoot [-TroubleshootDurationHours <Int32>]
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -StopTroubleshoot
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -SetTags <String[]>
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -SetAssetValue <String>
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -SetCriticalityLevel <String>
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -SetExclusionState <String> [-Justification <String>] [-Notes <String>]
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -ForceSync
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -StartInvestigation
Invoke-XdrEndpointDeviceAction -DeviceId <String> [-Comment <String>] -LiveResponse
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The device ID (SenseMachineId) of the target device. Required for all actions. |
| -Comment | String |  |  | A comment describing the reason for the action. Used as RequestorComment for API calls. |
| -Scan | String | yes |  | Runs an antivirus scan on the device. Valid values: Quick, Full. Values: Quick, Full |
| -Isolate | String | yes |  | Isolates the device from the network. Valid values: Full, Selective. Values: Full, Selective |
| -ReleaseFromIsolation | SwitchParameter | yes | False | Releases the device from network isolation. |
| -RestrictAppExecution | SwitchParameter | yes | False | Restricts application execution on the device to Microsoft-signed binaries only. macOS note: this action is currently unsupported and should be attempted only for capability detection/documentation. |
| -RemoveAppExecutionRestriction | SwitchParameter | yes | False | Removes application execution restriction from the device. macOS note: this action is currently unsupported and should be attempted only for capability detection/documentation. |
| -CollectInvestigationPackage | SwitchParameter | yes | False | Collects a forensic investigation package from the device. |
| -CollectSupportLogs | SwitchParameter | yes | False | Collects support diagnostic logs from the device. |
| -StartTroubleshoot | SwitchParameter | yes | False | Enables troubleshooting mode on the device. |
| -TroubleshootDurationHours | Int32 |  | 4 | Duration in hours for troubleshooting mode. Defaults to 4. Maximum 12. |
| -StopTroubleshoot | SwitchParameter | yes | False | Disables troubleshooting mode on the device. |
| -SetTags | String[] | yes |  | Array of tag strings to set on the device. Replaces all existing user-defined tags. Wraps Set-XdrEndpointDeviceTag. For add/remove semantics, use Set-XdrEndpointDeviceTag -Add or -Remove directly. |
| -SetAssetValue | String | yes |  | Sets the asset value of the device. Valid values: Low, Normal, High. Wraps Set-XdrEndpointDeviceAssetValue. Values: Low, Normal, High |
| -SetCriticalityLevel | String | yes |  | Sets the criticality level. Valid values: VeryHigh, High, Medium, Low, Reset. Reset removes the criticality level. Wraps Set-XdrEndpointDeviceCriticalityLevel. Values: VeryHigh, High, Medium, Low, Reset |
| -SetExclusionState | String | yes |  | Sets the exclusion state. Valid values: Excluded, Included. Wraps Set-XdrEndpointDeviceExclusionState. Values: Excluded, Included |
| -Justification | String |  |  | Justification for exclusion state change. |
| -Notes | String |  |  | Additional notes for the exclusion state change. |
| -ForceSync | SwitchParameter | yes | False | Forces a policy sync on the device. Wraps Invoke-XdrEndpointDevicePolicySync. |
| -StartInvestigation | SwitchParameter | yes | False | Starts an automated investigation. Wraps Invoke-XdrEndpointDeviceAutomatedInvestigation. macOS note: this action is currently unsupported and should be attempted only for capability detection/documentation. |
| -LiveResponse | SwitchParameter | yes | False | Starts an interactive Live Response session. Wraps Connect-XdrEndpointDeviceLiveResponse. |

Example 1:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -Scan Quick
```

Runs a quick antivirus scan on the specified device.

Example 2:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -Scan Full -Comment "macOS validation full scan"
```

Runs a full antivirus scan with a comment.

Example 3:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -Isolate Full -Comment "macOS containment test"
```

Fully isolates the device from the network.

Example 4:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -ReleaseFromIsolation -Comment "macOS containment test rollback"
```

Releases the device from isolation.

Example 5:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -CollectInvestigationPackage -Comment "macOS evidence collection"
```

Collects a forensic investigation package from the device.

Example 6:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -LiveResponse
```

Opens an interactive Live Response session to the device.

Example 7:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -SetAssetValue High
```

Sets the asset value to High.

Example 8:

```powershell
Invoke-XdrEndpointDeviceAction -DeviceId "980dddb7036eae7e38d30dee7f11b51e573a6fc2" -ForceSync -Comment "macOS policy sync validation"
```

Forces a policy sync on the device.

## Invoke-XdrEndpointDeviceAutomatedInvestigation

Guard: `write`

Starts an automated investigation on an endpoint device in Microsoft Defender XDR.

Triggers an automated investigation (AutoIR) for the specified endpoint device.
This initiates the Defender XDR automated investigation and remediation workflow.

```powershell
Invoke-XdrEndpointDeviceAutomatedInvestigation -DeviceId <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The device ID (SenseMachineId) of the target device. |

Example 1:

```powershell
Invoke-XdrEndpointDeviceAutomatedInvestigation -DeviceId "abc123"
```

Starts an automated investigation on the specified device.

## Invoke-XdrEndpointDeviceLiveResponseCommand

Guard: `write`

Sends a command to an active Live Response session in Microsoft Defender XDR.

Submits a command to an active Live Response session and polls for the result.
Parses the raw command line to extract the command definition ID and parameters,
then sends the command via the Live Response API and waits for completion.

Supports the full Live Response command syntax including:
- Positional parameters mapped by order from the command definition
- Named parameters using -paramName value syntax (e.g. -output json, -name notepad.exe)
- Boolean flags using -flagName syntax (e.g. -full_path, -upload, -overwrite, -keep)
- Alias resolution (ls -> dir, process -> processes, download -> getfile, etc.)

This cmdlet can be used programmatically or is called automatically by
Connect-XdrEndpointDeviceLiveResponse during interactive sessions.

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId <String> -Command <String> [-CurrentDirectory <String>] [-BackgroundMode] [-TimeoutSeconds <Int32>] [-PollIntervalSeconds <Int32>] [-CommandDefinitions <Array>] [-DeviceName <String>] [-DeviceId <String>] [-ExpandTableOutput] [-IncludeCommandResult] [-RawCommandResult]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -SessionId | String | yes |  | The Live Response session ID (starts with CLR prefix). |
| -Command | String | yes |  | The raw command line to execute (e.g., "dir /Applications", "processes", "getfile /etc/hosts"). Supports all Live Response command aliases (ls, process, download, etc.). Values containing spaces must be quoted: getfile "/Applications/Utilities/Activity Monitor.app/Contents/Info.plist" |
| -CurrentDirectory | String |  | C:\ | The current working directory on the remote device. Defaults to "C:\" for Windows sessions. For macOS and Linux sessions, use '/' or the session's reported current directory. |
| -BackgroundMode | SwitchParameter |  | False | Run the command in background mode if supported. |
| -TimeoutSeconds | Int32 |  | 300 | Maximum time to wait for command completion. Defaults to 300 seconds (5 minutes). Automatically extended to 600s for analyze commands. |
| -PollIntervalSeconds | Int32 |  | 2 | How often to check for command completion. Defaults to 2 seconds. |
| -CommandDefinitions | Array |  |  | Array of command definition objects from the Live Response API's get_command_definitions endpoint. Used to resolve aliases and correctly classify -name tokens as flags or named parameters. When not provided, falls back to heuristic parsing with 'path' as the default param_id. |
| -DeviceName | String |  |  | Optional device name to stamp onto the returned command object. |
| -DeviceId | String |  |  | Optional device ID to stamp onto the returned command object. |
| -ExpandTableOutput | SwitchParameter |  | False | When set, emits PowerShell-native row objects for table outputs and stamps each row with Timestamp, DeviceName, DeviceId, command, and status metadata. |
| -IncludeCommandResult | SwitchParameter |  | False | When used with -ExpandTableOutput, also emits the original command result object before the flattened table rows. |
| -RawCommandResult | SwitchParameter |  | False | Returns the original command result object without default structured table expansion. Useful for callers such as the interactive Live Response shell that need the raw outputs, context, and error collections from the API response. |

Example 1:

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb" -Command "processes"
```

Lists running processes on the remote device.

Example 2:

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb" -Command "dir /Applications" -CurrentDirectory "/"
```

Lists the contents of /Applications on a macOS device.

Example 3:

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb" -Command "dir -full_path"
```

Lists all files with full paths. The -full_path flag is correctly sent in the flags[] array.

Example 4:

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb" -Command "process -name launchd"
```

Filters processes by name using the 'process' alias and a named -name parameter on macOS.

Example 5:

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb" -Command "getfile /etc/hosts" -TimeoutSeconds 120
```

Downloads a file from a macOS device with a 2-minute timeout.

Example 6:

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb" -Command "ls"
```

Lists files using the 'ls' alias for 'dir'. Alias is preserved in raw_command_line.

Example 7:

```powershell
$sessions | Invoke-XdrEndpointDeviceLiveResponseCommand -Command "processes" -ExpandTableOutput
```

Returns one PowerShell object per process row, stamped with device and execution metadata.

Example 8:

```powershell
$sessions | Invoke-XdrEndpointDeviceLiveResponseCommand -Command "processes" -ExpandTableOutput -IncludeCommandResult
```

Returns the original command result object followed by flattened process rows.

Example 9:

```powershell
Invoke-XdrEndpointDeviceLiveResponseCommand -SessionId "CLR0c33ce1c-1665-4e00-9059-8fa39da9e2cb" -Command "drivers" -RawCommandResult
```

Returns the original command result object without expanding structured table rows.

## Invoke-XdrEndpointDevicePolicySync

Guard: `write`

Forces a policy sync on an endpoint device in Microsoft Defender XDR.

Triggers a forced policy synchronization for a managed endpoint device.
This is useful when policy changes need to be applied immediately.

```powershell
Invoke-XdrEndpointDevicePolicySync -DeviceId <String> [-Comment <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String | yes |  | The device ID (SenseMachineId) of the target device. |
| -Comment | String |  | "Force policy sync - Performed by $env:USERNAME via XDRInternals" | A comment describing the reason for the policy sync. |

Example 1:

```powershell
Invoke-XdrEndpointDevicePolicySync -DeviceId "abc123"
```

Forces a policy sync on the specified device.

Example 2:

```powershell
Invoke-XdrEndpointDevicePolicySync -DeviceId "abc123" -Comment "Apply new AV exclusions"
```

Forces a policy sync with a descriptive comment.

## New-XdrEndpointDeviceLiveResponseLibraryFile

Guard: `write`

Uploads a script file to the Live Response library.

Uploads a local script file to the Microsoft Defender XDR Live Response library.
The file can then be used with the 'putfile' and 'run' commands during Live Response sessions.
Multipart form-data is constructed as a byte array to maintain WebSession cookie compatibility.

```powershell
New-XdrEndpointDeviceLiveResponseLibraryFile -FilePath <String> [-Description <String>] [-HasParameters] [-ParametersDescription <String>] [-OverrideIfExists]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -FilePath | String | yes |  | The full path to the local script file to upload. |
| -Description | String |  |  | Optional description for the library file. |
| -HasParameters | SwitchParameter |  | False | Indicates that the script accepts parameters during execution. |
| -ParametersDescription | String |  |  | Description of the parameters accepted by the script. Only relevant when -HasParameters is specified. |
| -OverrideIfExists | SwitchParameter |  | False | If specified, overwrites an existing library file with the same name. Without this switch, uploading a duplicate file name will fail. |

Example 1:

```powershell
New-XdrEndpointDeviceLiveResponseLibraryFile -FilePath 'C:\Scripts\Remediate.ps1'
```

Uploads Remediate.ps1 to the Live Response library.

Example 2:

```powershell
'
```

Uploads with metadata describing the script parameters.

Example 3:

```powershell
New-XdrEndpointDeviceLiveResponseLibraryFile -FilePath 'C:\Scripts\Remediate.ps1' -OverrideIfExists
```

Replaces an existing library file with the same name.

## New-XdrEndpointDeviceRbacGroup

Guard: `write`

Creates a device group in Defender for Endpoint used for RBAC and policies.

Creates a device group in Defender for Endpoint used for RBAC and policies.
After a successful create, this cmdlet refreshes the device-group cache for 30 minutes.

```powershell
New-XdrEndpointDeviceRbacGroup [-GroupObject <Object>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -GroupObject | Object |  |  | Required. The group object to add to the existing RBAC group collection. This cmdlet does not build a default group object when the parameter is omitted. |

Example 1:

```powershell
New-XdrEndpointDeviceRbacGroup -GroupObject $customBody
```

Creates a device group in Defender for Endpoint used for RBAC and policies with a custom request body.

## Remove-XdrEndpointDeviceLiveResponseLibraryFile

Guard: `write`

Deletes a file from the Live Response library.

Removes a script file from the Microsoft Defender XDR Live Response library.
When only -FileName is provided, the cmdlet automatically looks up the file metadata
(last_updated_time) required by the API. Accepts pipeline input from
Get-XdrEndpointDeviceLiveResponseLibrary.

```powershell
Remove-XdrEndpointDeviceLiveResponseLibraryFile -FileName <String>
Remove-XdrEndpointDeviceLiveResponseLibraryFile -InputObject <Object>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -FileName | String | yes |  | The name of the file to delete from the library (e.g. 'PasskeyLogin.ps1'). |
| -InputObject | Object | yes |  | A library file object from Get-XdrEndpointDeviceLiveResponseLibrary. Extracts file_name and last_updated_time automatically. |

Example 1:

```powershell
Remove-XdrEndpointDeviceLiveResponseLibraryFile -FileName 'OldScript.ps1'
```

Deletes OldScript.ps1 from the library after confirmation.

Example 2:

```powershell
Remove-XdrEndpointDeviceLiveResponseLibraryFile -FileName 'OldScript.ps1' -Confirm:$false
```

Deletes without prompting.

Example 3:

```powershell
Get-XdrEndpointDeviceLiveResponseLibrary | Where-Object file_name -eq 'OldScript.ps1' | Remove-XdrEndpointDeviceLiveResponseLibraryFile
```

Deletes using pipeline input from the library listing.

Example 4:

```powershell
Remove-XdrEndpointDeviceLiveResponseLibraryFile -FileName 'OldScript.ps1' -WhatIf
```

Shows what would be deleted without performing the deletion.

## Set-XdrEndpointDeviceAssetValue

Guard: `write`

Sets the asset value on endpoint devices in Microsoft Defender XDR.

Updates the asset value classification for one or more endpoint devices.
Valid asset values are Low, Normal, and High.

```powershell
Set-XdrEndpointDeviceAssetValue -DeviceId <String[]> -AssetValue <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String[] | yes |  | One or more device IDs (SenseMachineIds) identifying the target devices. |
| -AssetValue | String | yes |  | The asset value to assign. Valid values: Low, Normal, High. Values: Low, Normal, High |

Example 1:

```powershell
Set-XdrEndpointDeviceAssetValue -DeviceId "abc123" -AssetValue High
```

Sets the asset value to High on the specified device.

Example 2:

```powershell
Set-XdrEndpointDeviceAssetValue -DeviceId "abc123", "def456" -AssetValue Low
```

Sets the asset value to Low on multiple devices.

## Set-XdrEndpointDeviceCriticalityLevel

Guard: `write`

Sets the criticality level on endpoint devices in Microsoft Defender XDR.

Updates the criticality level for one or more endpoint devices.
Criticality levels help prioritize security operations based on device importance.

```powershell
Set-XdrEndpointDeviceCriticalityLevel -DeviceId <String[]> -CriticalityLevel <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String[] | yes |  | One or more device IDs (SenseMachineIds) identifying the target devices. |
| -CriticalityLevel | String | yes |  | The criticality level to assign. Valid values: VeryHigh, High, Medium, Low, Reset. Reset removes the criticality level from the device. Values: VeryHigh, High, Medium, Low, Reset |

Example 1:

```powershell
Set-XdrEndpointDeviceCriticalityLevel -DeviceId "abc123" -CriticalityLevel High
```

Sets the criticality level to High on the specified device.

Example 2:

```powershell
Set-XdrEndpointDeviceCriticalityLevel -DeviceId "abc123", "def456" -CriticalityLevel Medium
```

Sets the criticality level to Medium on multiple devices.

Example 3:

```powershell
Set-XdrEndpointDeviceCriticalityLevel -DeviceId "abc123" -CriticalityLevel Reset
```

Removes the criticality level from the specified device.

## Set-XdrEndpointDeviceExclusionState

Guard: `write`

Sets the exclusion state on endpoint devices in Microsoft Defender XDR.

Updates the exclusion state for one or more endpoint devices.
Devices can be excluded from or included in Defender for Endpoint monitoring.

```powershell
Set-XdrEndpointDeviceExclusionState -DeviceId <String[]> -ExclusionState <String> [-Justification <String>] [-Notes <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String[] | yes |  | One or more device IDs (SenseMachineIds) identifying the target devices. |
| -ExclusionState | String | yes |  | The exclusion state to set. Valid values: Excluded, Included. Values: Excluded, Included |
| -Justification | String |  |  | Justification for the exclusion state change. Required when excluding devices. |
| -Notes | String |  |  | Additional notes for the exclusion state change. |

Example 1:

```powershell
Set-XdrEndpointDeviceExclusionState -DeviceId "abc123" -ExclusionState Excluded -Justification "MachineOutOfScope" -Notes "Lab device"
```

Excludes the device with a justification and notes.

Example 2:

```powershell
Set-XdrEndpointDeviceExclusionState -DeviceId "abc123" -ExclusionState Included
```

Re-includes a previously excluded device.

## Set-XdrEndpointDeviceRbacGroup

Guard: `write`

Updates Defender for Endpoint device groups.

Updates Defender for Endpoint device groups.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Set-XdrEndpointDeviceRbacGroup [-GroupObject <Object>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -GroupObject | Object |  |  | The GroupObject to send. If not provided, uses a default structure. |

Example 1:

```powershell
Set-XdrEndpointDeviceRbacGroup
```

Updates Defender for Endpoint device groups.

Example 2:

```powershell
Set-XdrEndpointDeviceRbacGroup -Body $customBody
```

Updates Defender for Endpoint device groups with a custom request body.

Example 3:

```powershell
Set-XdrEndpointDeviceRbacGroup -Force
```

Forces a fresh retrieval, bypassing the cache.

## Set-XdrEndpointDeviceTag

Guard: `write`

Sets, adds, or removes user-defined tags on endpoint devices in Microsoft Defender XDR.

Manages user-defined tags on one or more endpoint devices by calling the
editMachineTags API. Only modifies UserDefinedTags; BuiltInTags and DynamicRulesTags
are managed through separate mechanisms. Supports two modes:
- Replace (Tags): Replaces all existing user-defined tags with the provided tags.
- AddRemove (Add/Remove): Retrieves current user-defined tags, adds and/or removes
  the specified tags, and sets the resulting list. Both -Add and -Remove can be used
  together in a single call.

When using -Add or -Remove, the cmdlet fetches each device's current user-defined tags
via Get-XdrEndpointDeviceTag, modifies the list, then calls editMachineTags with the updated set.

```powershell
Set-XdrEndpointDeviceTag -DeviceId <String[]> -Tags <String[]>
Set-XdrEndpointDeviceTag -DeviceId <String[]> [-Add <String[]>] [-Remove <String[]>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DeviceId | String[] | yes |  | One or more device IDs (SenseMachineIds) identifying the target devices. |
| -Tags | String[] | yes |  | Array of tag strings to set on the devices. Replaces all existing user-defined tags. |
| -Add | String[] |  |  | Array of tag strings to add to each device's existing user-defined tags. Duplicates are ignored. Can be combined with -Remove in a single call. |
| -Remove | String[] |  |  | Array of tag strings to remove from each device's existing user-defined tags. Can be combined with -Add in a single call. |

Example 1:

```powershell
Set-XdrEndpointDeviceTag -DeviceId "abc123" -Tags "Production", "VDI"
```

Replaces all user-defined tags on the device with Production and VDI.

Example 2:

```powershell
Set-XdrEndpointDeviceTag -DeviceId "abc123" -Add "VDI"
```

Adds the VDI tag to the device's existing user-defined tags without removing any.

Example 3:

```powershell
Set-XdrEndpointDeviceTag -DeviceId "abc123" -Remove "TestTag"
```

Removes the TestTag from the device, keeping all other user-defined tags.

Example 4:

```powershell
Set-XdrEndpointDeviceTag -DeviceId "abc123" -Add "Production" -Remove "TestTag"
```

Adds the Production tag and removes the TestTag in a single operation.

Example 5:

```powershell
Set-XdrEndpointDeviceTag -DeviceId "abc123", "def456" -Add "Production"
```

Adds the Production tag to multiple devices.

## Stop-XdrEndpointDeviceAction

Guard: `write`

Cancels a pending device action in Microsoft Defender XDR.

Cancels a device response action that is currently in a pending/submitted state.
Uses the request GUID from the original action submission to identify the action to cancel.

```powershell
Stop-XdrEndpointDeviceAction -RequestGuid <String> [-Comment <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -RequestGuid | String | yes |  | The GUID of the request to cancel. This is returned when an action is submitted. |
| -Comment | String |  | "Action cancelled - Performed by $env:USERNAME via XDRInternals" | A comment explaining the reason for the cancellation. |

Example 1:

```powershell
Stop-XdrEndpointDeviceAction -RequestGuid "b28b630c-d1a1-4b1d-9676-680c15366a52" -Comment "Action no longer needed"
```

Cancels the specified device action with a comment.

Example 2:

```powershell
Stop-XdrEndpointDeviceAction -RequestGuid "b28b630c-d1a1-4b1d-9676-680c15366a52"
```

Cancels the specified device action.

