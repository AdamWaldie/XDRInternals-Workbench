# Export, Sentinel and Azure Data Explorer

7 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Export-XdrAzureDataExplorer

Guard: `write`

Exports pipeline data to Azure Data Explorer using queued ingestion.

Accepts pipeline input, stages records as newline-delimited JSON, compresses the staged
files with gzip, uploads them to the Azure Data Explorer-managed staging container, and
submits queued-ingestion requests.

When used with -TableName alone, the cmdlet uses a raw-table pattern with a single
Event:dynamic column. When used with -Source, the cmdlet automatically routes events
to typed tables based on their ActionType or SourceTable, creating typed schemas with
the appropriate column definitions and JSON ingestion mappings.

Queued ingestion is asynchronous. After this cmdlet uploads blobs and submits ingestion
requests, Azure Data Explorer may still take several minutes before the data is queryable.
Use -TrackIngestion together with Get-XdrAzureDataExplorerIngestionStatus, or use
-WaitForIngestion when you want the cmdlet to wait for queued ingestion to finish.

If a later batch or pipeline stage fails, queued batches that were already submitted cannot
be rolled back. Pipeline cancellation closes local writers and removes staging files without
uploading or submitting the buffered, unclosed batch.

Requires Set-XdrAzureDataExplorerConnection to be called first.

```powershell
Export-XdrAzureDataExplorer -Data <Object> -TableName <String> [-MappingName <String>] [-MaxBlobSizeMB <Int32>] [-TempPath <String>] [-KeepTempFiles] [-SkipBootstrap] [-DisableCompression] [-TrackIngestion] [-WaitForIngestion] [-WaitTimeoutMinutes <Int32>] [-StatusPollingIntervalSeconds <Int32>] [-PassThru]
Export-XdrAzureDataExplorer -Data <Object> [-TableName <String>] -Source <String> [-MaxBlobSizeMB <Int32>] [-TempPath <String>] [-KeepTempFiles] [-SkipBootstrap] [-DisableCompression] [-TrackIngestion] [-WaitForIngestion] [-WaitTimeoutMinutes <Int32>] [-StatusPollingIntervalSeconds <Int32>] [-PassThru]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Data | Object | yes |  | The objects to export. Accepts pipeline input. |
| -TableName | String | yes |  | The target Azure Data Explorer table name. Mandatory when -Source is not specified. When -Source is specified, -TableName is optional and serves as a fallback table for events that don't match any typed table profile. |
| -Source | String | yes |  | Enables typed table routing. Events are automatically routed to the appropriate typed ADX table based on their ActionType or SourceTable. Each unique table gets its own staging file, blob upload, and ingestion submission. Values: DeviceTimeline, IdentityTimeline, CloudAppsActivityTimeline, CloudAppsTimeline, Alert, Incident, Device, AdvancedHunting |
| -MappingName | String |  |  | Optional mapping name. Defaults to <TableName>_EventMapping. Only valid when -Source is not specified. |
| -MaxBlobSizeMB | Int32 |  | 1024 | Maximum uncompressed staging size, in MB, before the cmdlet rolls over to a new blob. The value is capped by the service's reported queued-ingestion maxDataSize. |
| -TempPath | String |  |  | Optional root path for temporary staging files. |
| -KeepTempFiles | SwitchParameter |  | False | Keeps temporary staging files instead of deleting them after upload. |
| -SkipBootstrap | SwitchParameter |  | False | Skips the create-if-missing table and mapping bootstrap logic. |
| -DisableCompression | SwitchParameter |  | False | Disables gzip compression for uploaded staging files. |
| -TrackIngestion | SwitchParameter |  | False | Requests ADX ingestion operation IDs for each queued ingestion request. Leave this disabled for high-volume exports unless you specifically need per-request tracking. |
| -WaitForIngestion | SwitchParameter |  | False | Waits for all queued ingestion requests submitted by this invocation to finish. This automatically enables tracking for the current export. |
| -WaitTimeoutMinutes | Int32 |  | 30 | Maximum number of minutes to wait when -WaitForIngestion is specified. |
| -StatusPollingIntervalSeconds | Int32 |  | 15 | Number of seconds between ingestion-status polls when -WaitForIngestion is specified. |
| -PassThru | SwitchParameter |  | False | Outputs the original input objects after staging them for ingestion. |

Example 1:

```powershell
Set-XdrAzureDataExplorerConnection -ClusterUri "https://mycluster.westeurope.kusto.windows.net" -Database "Investigations"
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" | Export-XdrAzureDataExplorer -TableName "DeviceTimeline"
```

Exports a device timeline to Azure Data Explorer using queued ingestion with a single dynamic table.

Example 2:

```powershell
Get-XdrIdentityUser -Upn "user@contoso.com" | Get-XdrIdentityUserTimeline -LastNDays 30 | Export-XdrAzureDataExplorer -TableName "IdentityTimeline" -PassThru
```

Queues identity timeline data for ingestion and also passes the records through the pipeline.

Example 3:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -LastNDays 7 | Export-XdrAzureDataExplorer -TableName "DeviceTimeline" -TrackIngestion -Verbose
```

Queues device timeline data for ingestion and asks ADX to return queued-ingestion operation IDs.

Example 4:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -LastNDays 7 | Export-XdrAzureDataExplorer -TableName "DeviceTimeline" -WaitForIngestion -Verbose
```

Queues a device timeline export and waits until the queued-ingestion operations finish.

Example 5:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -LastNDays 7 | Export-XdrAzureDataExplorer -Source DeviceTimeline -Verbose
```

Exports a device timeline using typed table routing. Events are automatically split across tables like XDRDeviceTimelineProcessEvents, XDRDeviceTimelineNetworkEvents, etc. based on their ActionType.

Example 6:

```powershell
Get-XdrEndpointDeviceTimeline -DeviceId "2bec169acc9def3ebd0bf8cdcbd9d16eb37e50e2" -LastNDays 7 | Export-XdrAzureDataExplorer -Source DeviceTimeline -TableName "DeviceTimelineFallback" -WaitForIngestion -Verbose
```

Exports a device timeline using typed table routing with a fallback table for unrecognized event types, and waits for all queued ingestion operations to complete.

## Export-XdrToSentinel

Guard: `write`

Exports XDR data to a Microsoft Sentinel (Log Analytics) custom table.

Sends data to a Log Analytics workspace using the HTTP Data Collector API.
Data appears in the workspace as a custom log table with the "_CL" suffix.

Requires Set-XdrSentinelConnection to be called first with workspace credentials.

Accepts pipeline input from any XDRInternals Get-* cmdlet or any PowerShell object array.
Objects are serialized to JSON and posted in batches (max 30 MB per batch).

```powershell
Export-XdrToSentinel -Data <Object> -LogType <String> [-TimestampField <String>] [-BatchSize <Int32>] [-PassThru]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Data | Object | yes |  | The data to export. Accepts pipeline input or an explicit array of objects. |
| -LogType | String | yes |  | The custom log type name. This becomes the table name in Log Analytics with "_CL" appended. Example: "XdrSuppressionRules" becomes "XdrSuppressionRules_CL". Must contain only letters, numbers, and underscores, max 100 characters. |
| -TimestampField | String |  |  | Optional field name in the data that contains a timestamp. If specified, Log Analytics uses this as the TimeGenerated field instead of ingestion time. |
| -BatchSize | Int32 |  | 500 | Maximum number of records per API call. Defaults to 500. |
| -PassThru | SwitchParameter |  | False | When specified, outputs the original data to the pipeline after exporting. |

Example 1:

```powershell
Get-XdrSuppressionRule | Export-XdrToSentinel -LogType "XdrSuppressionRules"
```

Exports all suppression rules to the XdrSuppressionRules_CL table.

Example 2:

```powershell
Get-XdrEndpointAdvancedFeatures | Export-XdrToSentinel -LogType "XdrAdvancedFeatures"
```

Example 3:

```powershell
Get-XdrAlert -Top 100 | Export-XdrToSentinel -LogType "XdrAlerts" -TimestampField "CreationTime" -PassThru | Format-Table
```

Exports alerts and also passes them through for display.

Example 4:

```powershell
$devices = Get-XdrEndpointDevice
Export-XdrToSentinel -Data $devices -LogType "XdrDevices"
```

## Get-XdrAzureDataExplorerCluster

Guard: `read`

Discovers accessible Azure Data Explorer clusters and databases.

Enumerates Azure Data Explorer (Microsoft.Kusto) clusters visible to the current Azure
auth context through Azure Resource Manager, and also includes Azure Data Explorer free
clusters exposed through the web control plane. When requested, it also lists databases for
each cluster so you can quickly bootstrap Set-XdrAzureDataExplorerConnection without
hunting for portal details manually.

Authentication uses the module's standard Azure token flow: explicit token, Az.Accounts,
Azure CLI, browser-derived ESTS bridge, or managed identity.

Each returned cluster includes DiscoveryStatus metadata. IsComplete is false when a provider
or requested database enumeration failed, and Failures identifies the provider, scope, and
error. Partial results are returned with a warning. Supplying -SubscriptionId intentionally
scopes discovery to Azure Resource Manager and does not count skipped free-cluster discovery
as a failure.

```powershell
Get-XdrAzureDataExplorerCluster [-SubscriptionId <String[]>] [-ClusterName <String>] [-DatabaseName <String>] [-IncludeDatabases] [-TenantId <String>] [-ManagedIdentityClientId <String>] [-AccessToken <String>] [-RequestTimeout <Int32>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -SubscriptionId | String[] |  |  | Optional subscription IDs to query. When omitted, all accessible subscriptions are enumerated. |
| -ClusterName | String |  |  | Optional cluster name filter. Wildcards are supported. |
| -DatabaseName | String |  |  | Optional database name filter. Wildcards are supported and imply -IncludeDatabases. |
| -IncludeDatabases | SwitchParameter |  | False | Includes Azure Data Explorer databases for each returned cluster. |
| -TenantId | String |  |  | Optional tenant ID used during Azure token acquisition. |
| -ManagedIdentityClientId | String |  |  | Optional user-assigned managed identity client ID for token acquisition via IMDS. |
| -AccessToken | String |  |  | Optional explicit Azure Resource Manager bearer token. |
| -RequestTimeout | Int32 |  | 60 | Optional HTTP timeout for discovery requests. Default is 60 seconds. |

Example 1:

```powershell
Get-XdrAzureDataExplorerCluster
```

Lists Azure Data Explorer clusters visible to the current Azure auth context, including accessible free clusters.

Example 2:

```powershell
Get-XdrAzureDataExplorerCluster -IncludeDatabases
```

Lists clusters together with their databases.

Example 3:

```powershell
Get-XdrAzureDataExplorerCluster -ClusterName 'my*' -DatabaseName 'Investigations'
```

Finds clusters whose names match "my*" and includes only databases matching "Investigations".

## Get-XdrAzureDataExplorerIngestionStatus

Guard: `read`

Gets the status of queued Azure Data Explorer ingestion operations.

Queries the Azure Data Explorer queued-ingestion status REST endpoint for one or more
ingestion operation IDs. Use this cmdlet after Export-XdrAzureDataExplorer -TrackIngestion,
or use -WaitForCompletion to block until the queued-ingestion operations finish.

Requires Set-XdrAzureDataExplorerConnection to be called first.

```powershell
Get-XdrAzureDataExplorerIngestionStatus -TableName <String> -OperationId <String[]> [-Details] [-WaitForCompletion] [-TimeoutMinutes <Int32>] [-PollingIntervalSeconds <Int32>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -TableName | String | yes |  | The target Azure Data Explorer table name that the queued-ingestion operation targeted. |
| -OperationId | String[] | yes |  | One or more queued-ingestion operation IDs returned by Azure Data Explorer. |
| -Details | SwitchParameter |  | False | Includes per-blob details when the service returns them. |
| -WaitForCompletion | SwitchParameter |  | False | Polls the queued-ingestion status endpoint until all specified operations reach a terminal state or the timeout is reached. |
| -TimeoutMinutes | Int32 |  | 30 | Maximum number of minutes to wait when -WaitForCompletion is specified. |
| -PollingIntervalSeconds | Int32 |  | 15 | Number of seconds between queued-ingestion status polls when -WaitForCompletion is specified. |

Example 1:

```powershell
Get-XdrAzureDataExplorerIngestionStatus -TableName "DeviceTimeline" -OperationId "ingest_op_12345"
```

Gets the current status of a queued-ingestion operation.

Example 2:

```powershell
Get-XdrAzureDataExplorerIngestionStatus -TableName "DeviceTimeline" -OperationId "ingest_op_12345" -WaitForCompletion -Details
```

Waits for the queued-ingestion operation to finish and returns detailed blob status.

## Invoke-XdrAzureDataExplorerQuery

Guard: `read`

Executes a KQL query or management command against an Azure Data Explorer cluster.

Runs a Kusto Query Language (KQL) query or management command against the configured
Azure Data Explorer cluster and returns the results as PowerShell objects.

Regular KQL queries are sent to the v2/rest/query endpoint. Management commands
(queries starting with '.') are sent to the v1/rest/mgmt endpoint.

Connection settings must be configured first using Set-XdrAzureDataExplorerConnection.

```powershell
Invoke-XdrAzureDataExplorerQuery -Query <String> [-Database <String>] [-ServerTimeout <TimeSpan>] [-RequestTimeout <Int32>] [-Raw]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Query | String | yes |  | The KQL query or management command to execute. |
| -Database | String |  |  | Optional database name to override the database from connection settings. |
| -ServerTimeout | TimeSpan |  | [timespan]::FromMinutes(4) | Server-side query timeout as a TimeSpan. Default is 4 minutes. |
| -RequestTimeout | Int32 |  | 300 | Client-side HTTP timeout in seconds. Default is 300 seconds. Currently only server-side timeout is enforced via the request body. |
| -Raw | SwitchParameter |  | False | Return the raw API response instead of converting to PSCustomObject output. |

Example 1:

```powershell
Invoke-XdrAzureDataExplorerQuery -Query 'XDRAlerts | take 10'
```

Runs a KQL query and returns the first 10 alerts as objects.

Example 2:

```powershell
Invoke-XdrAzureDataExplorerQuery -Query '.show tables'
```

Runs a management command to list all tables.

Example 3:

```powershell
Invoke-XdrAzureDataExplorerQuery -Query 'StormEvents | count' -Database 'Samples' -ServerTimeout ([timespan]::FromMinutes(10))
```

Runs a query against a specific database with a custom server timeout.

## Set-XdrAzureDataExplorerConnection

Guard: `write`

Configures Azure Data Explorer connection settings for export cmdlets.

Stores the Azure Data Explorer cluster, ingestion endpoint, database, and auth settings
used by Export-XdrAzureDataExplorer and Get-XdrAzureDataExplorerIngestionStatus.

When ClusterUri and Database are omitted, the cmdlet auto-discovers accessible clusters,
prompts you to choose a cluster when multiple matches exist, and then prompts you to
choose a database when the selected cluster has more than one available database.

If IngestionUri is omitted, the cmdlet derives it from the cluster URI by using the
standard `ingest-<cluster>` hostname convention.

```powershell
Set-XdrAzureDataExplorerConnection [-SubscriptionId <String[]>] [-ClusterName <String>] [-DatabaseName <String>] [-TenantId <String>] [-ManagedIdentityClientId <String>] [-RequestTimeout <Int32>] [-NonInteractive] [-AllowPartialDiscovery]
Set-XdrAzureDataExplorerConnection -ClusterUri <Uri> -Database <String> [-IngestionUri <Uri>] [-TenantId <String>] [-ManagedIdentityClientId <String>] [-AccessToken <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -ClusterUri | Uri | yes |  | The Azure Data Explorer cluster URI. You can supply either the engine endpoint or the ingestion endpoint. If omitted, the cmdlet discovers accessible clusters and prompts for a selection when needed. |
| -Database | String | yes |  | The database name to target for table bootstrap and queued ingestion. |
| -SubscriptionId | String[] |  |  | Optional subscription IDs used to narrow cluster discovery when ClusterUri is omitted. |
| -ClusterName | String |  |  | Optional cluster name filter used during discovery when ClusterUri is omitted. Wildcards are supported. |
| -DatabaseName | String |  |  | Optional database name filter used during discovery when ClusterUri is omitted. Wildcards are supported. |
| -IngestionUri | Uri |  |  | Optional explicit data ingestion URI. If omitted, it is derived from ClusterUri. |
| -TenantId | String |  |  | Optional tenant ID used when obtaining a token through Az.Accounts or Azure CLI. |
| -ManagedIdentityClientId | String |  |  | Optional user-assigned managed identity client ID for IMDS token acquisition. |
| -AccessToken | String |  |  | Optional Azure Data Explorer access token to use directly instead of acquiring a token dynamically. This applies only when ClusterUri and Database are supplied explicitly. |
| -RequestTimeout | Int32 |  | 60 | Optional HTTP timeout for discovery requests when ClusterUri is omitted. Default is 60 seconds. |
| -NonInteractive | SwitchParameter |  | False | Prevents interactive cluster or database prompts during discovery. If discovery is ambiguous, the cmdlet throws and asks you to narrow the match or specify the connection explicitly. |
| -AllowPartialDiscovery | SwitchParameter |  | False | Allows automatic connection selection when one or more discovery providers or database enumeration requests failed. By default, discovery fails closed rather than selecting from an incomplete result set. |

Example 1:

```powershell
Set-XdrAzureDataExplorerConnection -ClusterUri "https://mycluster.westeurope.kusto.windows.net" -Database "Investigations"
```

Configures the connection and derives the ingestion endpoint automatically.

Example 2:

```powershell
Set-XdrAzureDataExplorerConnection
```

Discovers accessible clusters, prompts for a cluster if more than one is available, and prompts for a database if the chosen cluster has more than one database.

Example 3:

```powershell
Set-XdrAzureDataExplorerConnection -ClusterName 'nm-test-cluster' -DatabaseName 'Investigations' -NonInteractive
```

Discovers a single matching cluster and database without prompting. If multiple matches remain, the cmdlet throws instead of waiting for user input.

Example 4:

```powershell
$token = az account get-access-token --resource https://api.kusto.windows.net --query accessToken -o tsv
Set-XdrAzureDataExplorerConnection -ClusterUri "https://mycluster.westeurope.kusto.windows.net" -Database "Investigations" -AccessToken $token
```

Configures the connection with an explicit bearer token.

## Set-XdrSentinelConnection

Guard: `write`

Configures the Sentinel (Log Analytics) workspace connection for data export.

Stores the Log Analytics workspace ID and shared key in script-scoped variables
used by Export-XdrToSentinel and Invoke-XdrDefenderHarvest.

The shared key can be found in the Azure portal under:
Log Analytics workspace > Agents > Log Analytics agent instructions > Primary/Secondary key

```powershell
Set-XdrSentinelConnection -WorkspaceId <String> -SharedKey <String> [-DceEndpoint <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -WorkspaceId | String | yes |  | The Log Analytics workspace ID (GUID). |
| -SharedKey | String | yes |  | The primary or secondary shared key for the workspace. |
| -DceEndpoint | String |  |  | Optional Data Collection Endpoint URI. When set, uses the DCR/DCE ingestion API instead of the legacy HTTP Data Collector API. Not required for most use cases. |

Example 1:

```powershell
Set-XdrSentinelConnection -WorkspaceId "12345678-abcd-1234-abcd-123456789012" -SharedKey "base64key=="
```

Example 2:

```powershell
$key = Read-Host -AsSecureString "Shared Key"
Set-XdrSentinelConnection -WorkspaceId "12345678-abcd-1234-abcd-123456789012" -SharedKey ([System.Net.NetworkCredential]::new('', $key).Password)
```

