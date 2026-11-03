# Advanced Hunting, Data Lake and XSPM hunting

13 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## ConvertTo-XdrEncodedAdvancedHuntingQuery

Guard: `read`

Encodes an Advanced Hunting query for use in Microsoft Defender XDR.

Converts a KQL (Kusto Query Language) query into an encoded format that can be used
in Microsoft Defender XDR Advanced Hunting. This is useful for generating shareable
query links or for API operations that require encoded queries.

```powershell
ConvertTo-XdrEncodedAdvancedHuntingQuery -QueryText <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -QueryText | String | yes |  | The KQL query text to be encoded. This should be a valid Advanced Hunting query. |

Example 1:

```powershell
ConvertTo-XdrEncodedAdvancedHuntingQuery -QueryText "DeviceInfo | take 10"
```

Encodes a simple query to retrieve 10 device records.

Example 2:

```powershell
$query = @"
ExposureGraphNodes
| where NodeLabel !in ("iam.user" ,"gcp-user", "user")
| where EntityIds has_any ("AzureResourceId","AwsResourceName","GcpFullResourceName")
| where isnotnull(NodeProperties.rawData.criticalityLevel)
"@
ConvertTo-XdrEncodedAdvancedHuntingQuery -QueryText $query
```

Encodes a multi-line query for exposure graph analysis.

Example 3:

```powershell
Get-Content query.kql -Raw | ConvertTo-XdrEncodedAdvancedHuntingQuery
```

Encodes a query from a file using pipeline input.

## Get-XdrAdvancedHuntingFunction

Guard: `read`

Retrieves Advanced Hunting functions from Microsoft Defender XDR.

Gets saved functions for Advanced Hunting queries in Microsoft Defender XDR.
Functions can be filtered by ID or retrieved all at once.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrAdvancedHuntingFunction [-Id <Int32>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Id | Int32 |  | 0 | Optional ID of a specific function to retrieve. If not specified, all functions will be returned. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrAdvancedHuntingFunction
```

Retrieves all Advanced Hunting functions using cached data if available.

Example 2:

```powershell
Get-XdrAdvancedHuntingFunction -Force
```

Forces a fresh retrieval of all functions, bypassing the cache.

Example 3:

```powershell
Get-XdrAdvancedHuntingFunction -Id 6
```

Retrieves a specific function by ID.

Example 4:

```powershell
Get-XdrAdvancedHuntingFunction | Where-Object { $_.IsShared -eq $true }
```

Retrieves only shared functions.

Example 5:

```powershell
Get-XdrAdvancedHuntingFunction | Where-Object { $_.Path -like "MyFolder*" }
```

Retrieves functions in a specific folder path.

## Get-XdrAdvancedHuntingTableSchema

Guard: `read`

Retrieves the Advanced Hunting table schema from Microsoft Defender XDR.

Gets the schema for Advanced Hunting tables from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrAdvancedHuntingTableSchema [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrAdvancedHuntingTableSchema
```

Retrieves the Advanced Hunting table schema using cached data if available.

Example 2:

```powershell
Get-XdrAdvancedHuntingTableSchema -Force
```

Forces a fresh retrieval of the Advanced Hunting table schema, bypassing the cache.

## Get-XdrAdvancedHuntingUnifiedDetectionRules

Guard: `read`

Retrieves the Unified Detection Rules from Advanced Hunting.

Retrieves the Unified Detection Rules from Advanced Hunting.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrAdvancedHuntingUnifiedDetectionRules [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrAdvancedHuntingUnifiedDetectionRules
```

Retrieves the Unified Detection Rules from Advanced Hunting.

Example 2:

```powershell
Get-XdrAdvancedHuntingUnifiedDetectionRules -Force
```

Forces a fresh retrieval, bypassing the cache.

## Get-XdrAdvancedHuntingUserHistory

Guard: `read`

Retrieves Advanced Hunting user history from Microsoft Defender XDR.

Gets the user's Advanced Hunting query history from the Microsoft Defender XDR portal.
By default, retrieves the last 28 days of history with a maximum of 30 results.

```powershell
Get-XdrAdvancedHuntingUserHistory [-Days <Int32>] [-MaxResults <Int32>]
Get-XdrAdvancedHuntingUserHistory [-StartTime <DateTime>] [-MaxResults <Int32>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -StartTime | DateTime |  |  | The start time for retrieving user history. Cannot be used together with Days parameter. |
| -Days | Int32 |  | 28 | The number of days to look back from the current date. Cannot be used together with StartTime parameter. Defaults to 28 days if neither StartTime nor Days is specified. |
| -MaxResults | Int32 |  | 30 | The maximum number of results to return. Defaults to 30. |

Example 1:

```powershell
Get-XdrAdvancedHuntingUserHistory
```

Retrieves the last 28 days of Advanced Hunting user history with up to 30 results.

Example 2:

```powershell
Get-XdrAdvancedHuntingUserHistory -Days 7 -MaxResults 50
```

Retrieves the last 7 days of user history with up to 50 results.

Example 3:

```powershell
Get-XdrAdvancedHuntingUserHistory -StartTime "2025-10-18T18:36:11.482Z"
```

Retrieves user history from the specified start time with up to 30 results.

## Get-XdrDatalakeDatabase

Guard: `read`

Retrieves databases from Microsoft Defender XDR datalake.

Gets a list of databases from the Microsoft Defender XDR datalake.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrDatalakeDatabase [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrDatalakeDatabase
```

Retrieves the datalake databases using cached data if available.

Example 2:

```powershell
Get-XdrDatalakeDatabase -Force
```

Forces a fresh retrieval of the datalake databases, bypassing the cache.

## Get-XdrDatalakeTableSchema

Guard: `read`

Retrieves database entities schema from Microsoft Defender XDR datalake.

Gets the database entities schema from the Microsoft Defender XDR datalake using a Kusto query.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrDatalakeTableSchema [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrDatalakeTableSchema
```

Retrieves the database entities schema using cached data if available.

Example 2:

```powershell
Get-XdrDatalakeTableSchema -Force
```

Forces a fresh retrieval of the database entities schema, bypassing the cache.

## Invoke-XdrHuntingQueryValidation

Guard: `read`

Validates an Advanced Hunting query for custom detection rules in Microsoft Defender XDR.

Validates whether an Advanced Hunting query is allowed and checks the permissions required
for creating custom detection rules. This is useful before attempting to create a custom
detection rule to ensure the query syntax is valid and the user has appropriate permissions.

```powershell
Invoke-XdrHuntingQueryValidation -QueryText <String> [-HuntingRule <Object>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -QueryText | String | yes |  | The KQL (Kusto Query Language) query text to validate. This should be a valid Advanced Hunting query. |
| -HuntingRule | Object |  |  | Optional hunting rule object to validate. If not specified, defaults to null. |

Example 1:

```powershell
ago(1h)"
```

Validates the specified Advanced Hunting query.

Example 2:

```powershell
$query = @"
DeviceEvents
| where ActionType == "ProcessCreated"
| where FileName == "powershell.exe"
| project Timestamp, DeviceName, AccountName, ProcessCommandLine
"@
Invoke-XdrHuntingQueryValidation -QueryText $query
```

Validates a multi-line Advanced Hunting query.

Example 3:

```powershell
Invoke-XdrHuntingQueryValidation -QueryText "DeviceProcessEvents | where false"
```

Validates a simple test query that returns no results.

## Invoke-XdrMtoAdvancedHunting

Guard: `read`

Executes an Advanced Hunting query across multiple tenants in MTO (Multi-Tenant Organization).

Runs a KQL (Kusto Query Language) Advanced Hunting query across one or more tenants
in the Microsoft Defender XDR multi-tenant view. Supports querying across tenants
with configurable time ranges and optional workspace selection.

```powershell
Invoke-XdrMtoAdvancedHunting -QueryText <String> [-TenantIds <String[]>] [-DaysAgo <Int32>] [-EndTime <DateTime>] [-MaxRecordCount <Int32>] [-SelectedWorkspaces <Hashtable>]
Invoke-XdrMtoAdvancedHunting -QueryText <String> [-TenantIds <String[]>] [-MinutesAgo <Int32>] [-EndTime <DateTime>] [-MaxRecordCount <Int32>] [-SelectedWorkspaces <Hashtable>]
Invoke-XdrMtoAdvancedHunting -QueryText <String> [-TenantIds <String[]>] [-StartTime <DateTime>] [-EndTime <DateTime>] [-MaxRecordCount <Int32>] [-SelectedWorkspaces <Hashtable>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -QueryText | String | yes |  | The KQL query to execute. This is a required parameter. |
| -TenantIds | String[] |  |  | Array of tenant IDs (GUIDs) to query. If not provided, uses the tenant ID from the cache (the currently selected tenant in MTO view). |
| -DaysAgo | Int32 |  | 7 | Number of days to look back from now for the query time range. Default is 7 days. Cannot be used with -StartTime or -MinutesAgo parameters. |
| -MinutesAgo | Int32 |  | 0 | Number of minutes to look back from now for the query time range. Cannot be used with -StartTime or -DaysAgo parameters. |
| -StartTime | DateTime |  |  | Custom start time for the query (DateTime object or string in ISO 8601 format). Cannot be used with -DaysAgo or -MinutesAgo parameters. |
| -EndTime | DateTime |  | (Get-Date) | End time for the query (DateTime object or string in ISO 8601 format). Default is the current time. |
| -MaxRecordCount | Int32 |  | 0 | Maximum number of records to return. If not specified, the API default is used. |
| -SelectedWorkspaces | Hashtable |  |  | Hashtable mapping tenant IDs to arrays of workspace IDs for querying specific workspaces. Example: @{ "tenantId1" = @("workspaceId1", "workspaceId2"); "tenantId2" = @("workspaceId3") } |

Example 1:

```powershell
Invoke-XdrMtoAdvancedHunting -QueryText "DeviceEvents | limit 10"
```

Executes a simple query across the current tenant for the last 7 days.

Example 2:

```powershell
Invoke-XdrMtoAdvancedHunting -QueryText "DeviceEvents | limit 10" -DaysAgo 30
```

Executes a query across the current tenant for the last 30 days.

Example 3:

```powershell
Invoke-XdrMtoAdvancedHunting -QueryText "DeviceEvents | limit 10" -MinutesAgo 60
```

Executes a query for the last 60 minutes.

Example 4:

```powershell
$tenants = @("e3686c4f-af27-4f22-b9de-062f05b93aac", "48315f62-774c-49c9-884b-34a8931b2b1f")
Invoke-XdrMtoAdvancedHunting -QueryText "DeviceInfo | take 5" -TenantIds $tenants
```

Executes a query across multiple specified tenants.

Example 5:

```powershell
$query = @"
DeviceProcessEvents
| where Timestamp > ago(1h)
| where FileName =~ "powershell.exe"
| take 100
"@
Invoke-XdrMtoAdvancedHunting -QueryText $query -DaysAgo 1 -Verbose
```

Executes a multi-line query with verbose output showing per-tenant latency.

Example 6:

```powershell
$workspaces = @{
    "e3686c4f-af27-4f22-b9de-062f05b93aac" = @("008e3d12-e648-46e1-83ec-f631d94bf434")
}
Invoke-XdrMtoAdvancedHunting -QueryText "DeviceEvents | limit 10" -SelectedWorkspaces $workspaces
```

Executes a query with specific workspace selection.

## Invoke-XdrXspmHuntingQuery

Guard: `read`

Executes a hunting query against the Microsoft Defender XDR XSPM attack surface API.

Executes a custom hunting query against the XSPM (Extended Security Posture Management) attack surface API.
Supports pagination through top and skip parameters.
This function is designed to be used as a base for more specific attack surface queries.

```powershell
Invoke-XdrXspmHuntingQuery -Query <String> [-Top <Int32>] [-Skip <Int32>] -ScenarioName <String> [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Query | String | yes |  | The hunting query string to execute. Should follow XSPM query syntax. |
| -Top | Int32 |  | 0 | The maximum number of records to return. Default is 100. |
| -Skip | Int32 |  | 0 | The number of records to skip for pagination. Default is 0. |
| -ScenarioName | String | yes |  | The scenario name to include in the request header (x-ms-scenario-name). This might be used for telemetry or logging purposes on the server side. Be careful out there. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Invoke-XdrXspmHuntingQuery -Query "AttackPathsV2 | take 10"
```

Executes a query to retrieve 10 attack paths.

Example 2:

```powershell
Invoke-XdrXspmHuntingQuery -Query "AttackPathsV2" -Top 50 -Skip 100
```

Executes a query with pagination, skipping the first 100 records and returning up to 50.

Example 3:

```powershell
Invoke-XdrXspmHuntingQuery -Query "AttackPathsV2 | where RiskLevel == 'High'" -Force
```

Executes a filtered query, bypassing the cache.

Example 4:

```powershell
Invoke-XdrXspmHuntingQuery -Query "AttackPathsV2" -ScenarioName "CustomAnalysis"
```

Executes a query with a custom scenario name in the request header.

## New-XdrAdvancedHuntingFunction

Guard: `write`

Creates a new Advanced Hunting function in Microsoft Defender XDR.

Creates a new saved function for Advanced Hunting queries in Microsoft Defender XDR.
These functions can be reused across multiple hunting queries and detection rules.
Functions can be shared with the organization or kept private in folder structures.

```powershell
New-XdrAdvancedHuntingFunction -Name <String> -KQLQuery <String> [-Description <String>] [-IsShared] [-FolderPath <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Name | String | yes |  | The name of the function. This will be used to call the function in queries. |
| -KQLQuery | String | yes |  | The KQL (Kusto Query Language) body of the function. This is the query logic that will be executed when the function is called. |
| -Description | String |  |  | Optional description of what the function does. |
| -IsShared | SwitchParameter |  | False | Switch to make the function shared with the organization. If not specified, the function will be private to the creator. |
| -FolderPath | String |  |  | Optional folder path for organizing private functions. Use forward slashes (/) or backslashes (\) - they will be automatically converted to double backslashes. Example: "MyFolder/SubFolder" or "MyFolder\SubFolder" |

Example 1:

```powershell
New-XdrAdvancedHuntingFunction -Name "GetSuspiciousLogons" -KQLQuery "DeviceLogonEvents | where LogonType == 'Network'" -IsShared
```

Creates a shared function that can be used across the organization.

Example 2:

```powershell
New-XdrAdvancedHuntingFunction -Name "ExtendedEntraIdSignInEvents" -KQLQuery $query -Description "Combines XDR and Sentinel data" -IsShared
```

Creates a shared function with a description.

Example 3:

```powershell
New-XdrAdvancedHuntingFunction -Name "MyFunction" -KQLQuery "DeviceEvents" -FolderPath "TestFolder/SubFolder"
```

Creates a private function in a folder structure.

Example 4:

```powershell
$query = @"
EntraIdSignInEvents
| where RiskLevelAggregated > 50
| project Timestamp, AccountUpn, IPAddress
"@
New-XdrAdvancedHuntingFunction -Name "HighRiskSignIns" -KQLQuery $query -Description "Returns high-risk sign-ins" -IsShared
```

Creates a shared function with a multi-line query.

## Remove-XdrAdvancedHuntingFunction

Guard: `write`

Removes an Advanced Hunting function from Microsoft Defender XDR.

Deletes a saved function for Advanced Hunting queries in Microsoft Defender XDR.
The function must exist before it can be removed. The cmdlet will verify the function exists before attempting deletion.

```powershell
Remove-XdrAdvancedHuntingFunction -Id <Int32>
Remove-XdrAdvancedHuntingFunction -InputObject <Object>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Id | Int32 | yes | 0 | The ID of the function to remove. This is mandatory to ensure the correct function is deleted. |
| -InputObject | Object | yes |  | PSObject containing the function to remove. The object must include an Id property. Typically obtained from Get-XdrAdvancedHuntingFunction. |

Example 1:

```powershell
Remove-XdrAdvancedHuntingFunction -Id 6
```

Removes the function with ID 6.

Example 2:

```powershell
Get-XdrAdvancedHuntingFunction -Id 6 | Remove-XdrAdvancedHuntingFunction
```

Gets a function and removes it through the pipeline.

Example 3:

```powershell
Get-XdrAdvancedHuntingFunction | Where-Object { $_.Name -eq "OldFunction" } | Remove-XdrAdvancedHuntingFunction
```

Finds a function by name and removes it.

## Set-XdrAdvancedHuntingFunction

Guard: `write`

Updates an existing Advanced Hunting function in Microsoft Defender XDR.

Updates a saved function for Advanced Hunting queries in Microsoft Defender XDR.
The function must exist before it can be updated. The cmdlet will verify the function exists before attempting the update.

```powershell
Set-XdrAdvancedHuntingFunction -Id <Int32> [-Name <String>] [-KQLQuery <String>] [-Description <String>] [-IsShared] [-FolderPath <String>]
Set-XdrAdvancedHuntingFunction -InputObject <Object>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Id | Int32 | yes | 0 | The ID of the function to update. This is mandatory to ensure the correct function is updated. |
| -Name | String |  |  | The new name of the function. If not specified, the existing name is preserved. |
| -KQLQuery | String |  |  | The new KQL (Kusto Query Language) body of the function. If not specified, the existing query is preserved. |
| -Description | String |  |  | The new description of the function. If not specified, the existing description is preserved. |
| -IsShared | SwitchParameter |  | False | Switch to make the function shared with the organization. If not specified, the existing sharing status is preserved. |
| -FolderPath | String |  |  | The new folder path for organizing the function. Use forward slashes (/) or backslashes (\) - they will be automatically converted to double backslashes. If not specified, the existing path is preserved. |
| -InputObject | Object | yes |  | PSObject containing the function to update. The object must include an Id property. Typically obtained from Get-XdrAdvancedHuntingFunction. |

Example 1:

```powershell
Set-XdrAdvancedHuntingFunction -Id 6 -Name "UpdatedFunctionName"
```

Updates the name of function with ID 6.

Example 2:

```powershell
Set-XdrAdvancedHuntingFunction -Id 6 -KQLQuery $newQuery -Description "Updated description"
```

Updates the query and description of a function.

Example 3:

```powershell
$function = Get-XdrAdvancedHuntingFunction -Id 6
$function.IsShared = $false
Set-XdrAdvancedHuntingFunction -InputObject $function
```

Gets a function, modifies it, and updates it.

Example 4:

```powershell
Set-XdrAdvancedHuntingFunction -Id 6 -IsShared -FolderPath "NewFolder/SubFolder"
```

Makes a function shared and moves it to a new folder path.

