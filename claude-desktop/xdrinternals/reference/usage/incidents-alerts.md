# Incidents, alerts, suppression and threat analytics

7 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Get-XdrAlert

Guard: `read`

Retrieves alerts from Microsoft Defender XDR.

Gets alerts from Microsoft Defender XDR with support for filtering by time range and pagination.
Alerts can be retrieved with automatic pagination using the -All parameter or with manual page control.

```powershell
Get-XdrAlert [-DaysAgo <Int32>] [-Order <String>] [-PageNumber <Int32>] [-PageSize <Int32>] [-Severity <String[]>] [-Status <String[]>]
Get-XdrAlert [-DaysAgo <Int32>] [-Order <String>] [-PageSize <Int32>] [-Severity <String[]>] [-Status <String[]>] [-All]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -DaysAgo | Int32 |  | 7 | Number of days to look back for alerts. Default is 7 days. |
| -Order | String |  | desc | Sort order for results. Valid values are "desc" (descending, newest first) or "asc" (ascending, oldest first). Default is "desc". Values: desc, asc |
| -PageNumber | Int32 |  | 1 | Specific page number to retrieve. Cannot be used with -All parameter. Default is 1. |
| -PageSize | Int32 |  | 60 | Number of alerts to retrieve per page. Default is 60. Maximum value depends on API limits. |
| -Severity | String[] |  |  | Filter alerts by severity. Valid values are "Informational", "Low", "Medium", "High". Multiple values can be specified as an array. Values: Informational, Low, Medium, High |
| -Status | String[] |  |  | Filter alerts by status. Valid values are "New", "InProgress", "Resolved". Multiple values can be specified as an array. Values: New, InProgress, Resolved |
| -All | SwitchParameter |  | False | Automatically retrieves all pages of alerts for the specified time range. Cannot be used with -PageNumber parameter. |

Example 1:

```powershell
Get-XdrAlert
```

Retrieves the first page of alerts from the last 7 days, sorted by newest first.

Example 2:

```powershell
Get-XdrAlert -DaysAgo 30
```

Retrieves alerts from the last 30 days.

Example 3:

```powershell
Get-XdrAlert -Order asc
```

Retrieves alerts sorted by oldest first.

Example 4:

```powershell
Get-XdrAlert -PageNumber 2 -PageSize 100
```

Retrieves the second page with 100 alerts per page.

Example 5:

```powershell
Get-XdrAlert -All
```

Automatically retrieves all alerts from the last 7 days across all pages.

Example 6:

```powershell
Get-XdrAlert -DaysAgo 14 -All
```

Retrieves all alerts from the last 14 days with automatic pagination.

Example 7:

```powershell
Get-XdrAlert -Severity High, Medium
```

Retrieves only high and medium severity alerts from the last 7 days.

Example 8:

```powershell
Get-XdrAlert -Status New, InProgress
```

Retrieves only new and in-progress alerts.

Example 9:

```powershell
Get-XdrAlert -Severity High -Status New -DaysAgo 30
```

Retrieves high severity new alerts from the last 30 days.

Example 10:

```powershell
Get-XdrAlert | Where-Object { $_.severity -eq "High" }
```

Retrieves alerts and filters for high severity only.

## Get-XdrIncident

Guard: `read`

Retrieves incidents from Microsoft Defender XDR.

Gets incidents from Microsoft Defender XDR with support for pagination, sorting, and filtering.
This cmdlet translates severity values and detection source IDs to friendly names.
Severity translations: 32=Information, 64=Low, 128=Medium, 256=High
This function includes caching support with a 10-minute TTL to reduce API calls.

```powershell
Get-XdrIncident [-TitleSearchTerms <String[]>] [-LookBackInDays <Int32>] [-SortByField <String>] [-SortOrder <String>] [-PageSize <Int32>] [-PageIndex <Int32>] [-DefenderExpertsLicensed] [-All] [-Force]
Get-XdrIncident -IncidentId <Int32>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -TitleSearchTerms | String[] |  |  | Array of search terms to filter incidents by title. |
| -LookBackInDays | Int32 |  | 30 | Number of days to look back for incidents. Default is 30. |
| -SortByField | String |  | TopRisk | Field to sort by. Valid values are: TopRisk, CreatedDate, LastUpdatedDate, Status, severity, name. Default is TopRisk. Values: TopRisk, CreatedDate, LastUpdatedDate, Status, severity, name |
| -SortOrder | String |  | Descending | Sort order. Valid values are Ascending or Descending. Default is Descending. Values: Ascending, Descending |
| -PageSize | Int32 |  | 40 | Number of incidents to retrieve per page. Default is 40. |
| -PageIndex | Int32 |  | 1 | Page index for pagination. Default is 1. |
| -DefenderExpertsLicensed | SwitchParameter |  | False | Indicates if Microsoft Defender Experts for XDR license is assigned to the tenant. Default is false. |
| -All | SwitchParameter |  | False | Retrieves all incidents by automatically paging through all results. When specified, PageSize and PageIndex parameters are used for the page size, but pagination is automatic. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -IncidentId | Int32 | yes | 0 | Retrieves a specific incident by its ID. When specified, all other filtering and pagination parameters are ignored. Cannot be combined with any other parameters. |

Example 1:

```powershell
Get-XdrIncident
```

Retrieves the first 40 incidents from the last 30 days, sorted by TopRisk in descending order.

Example 2:

```powershell
Get-XdrIncident -LookBackInDays 7 -PageSize 100
```

Retrieves the first 100 incidents from the last 7 days.

Example 3:

```powershell
Get-XdrIncident -SortByField CreatedDate -SortOrder Ascending
Retrieves incidents sorted by creation date in ascending order (oldest first).
```

Example 4:

```powershell
Get-XdrIncident -TitleSearchTerms "ransomware", "phishing"
```

Retrieves incidents with titles containing "ransomware" or "phishing".

Example 5:

```powershell
Get-XdrIncident -All
```

Retrieves all incidents by automatically paging through all results.

Example 6:

```powershell
Get-XdrIncident -DefenderExpertsLicensed -LookBackInDays 90
```

Retrieves incidents from the last 90 days for a tenant with Defender Experts license.

Example 7:

```powershell
Get-XdrIncident -IncidentId 2823
```

Retrieves a specific incident by its ID.

Example 8:

```powershell
Get-XdrIncident | Where-Object { $_.SeverityName -eq "High" }
```

Retrieves incidents and filters for high severity ones.

## Get-XdrIncidentAssociatedAlert

Guard: `read`

Retrieves alerts associated with a specific incident from Microsoft Defender XDR.

Gets all alerts associated with a specific incident ID from Microsoft Defender XDR.
This cmdlet automatically handles pagination to retrieve all associated alerts.
The results are cached to improve performance.

```powershell
Get-XdrIncidentAssociatedAlert -IncidentId <Int32> [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -IncidentId | Int32 | yes | 0 | The ID of the incident to retrieve associated alerts for. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrIncidentAssociatedAlert -IncidentId 2824
```

Retrieves all alerts associated with incident 2824.

## Get-XdrSuppressionRule

Guard: `read`

Retrieves alert suppression rules from Microsoft Defender XDR.

Gets the list of alert suppression rules configured in the Microsoft Defender XDR portal,
including rule details such as title, conditions, scope, status, and matching alert counts.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrSuppressionRule [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrSuppressionRule
```

Retrieves all suppression rules using cached data if available.

Example 2:

```powershell
Get-XdrSuppressionRule -Force
```

Forces a fresh retrieval of suppression rules, bypassing the cache.

Example 3:

```powershell
Get-XdrSuppressionRule | Where-Object { $_.IsEnabled }
```

Retrieves only enabled suppression rules.

Example 4:

```powershell
Get-XdrSuppressionRule | Where-Object { $_.CreatedBy -eq 'Microsoft' }
```

Retrieves only Microsoft-created suppression rules.

Example 5:

```powershell
Get-XdrSuppressionRule | Where-Object { $_.MatchingAlertsCount -gt 0 }
```

Retrieves suppression rules that have matched alerts.

## Get-XdrThreatAnalyticsOutbreaks

Guard: `read`

Retrieves threat analytics outbreaks from Microsoft Defender XDR.

Gets threat analytics outbreaks data from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

By default, retrieves the full outbreaks list. Use -ChangeCount or -TopThreats
switches to retrieve specific outbreak metrics from dedicated endpoints.

```powershell
Get-XdrThreatAnalyticsOutbreaks [-Force]
Get-XdrThreatAnalyticsOutbreaks [-Force] [-ChangeCount]
Get-XdrThreatAnalyticsOutbreaks [-Force] [-TopThreats]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -ChangeCount | SwitchParameter |  | False | Returns the outbreak change count information using the dedicated /changeCount endpoint. This provides metrics about changes in outbreak data over time. |
| -TopThreats | SwitchParameter |  | False | Returns the top threats from outbreaks using the dedicated /topThreats endpoint. This provides a prioritized list of the most significant threats. |

Example 1:

```powershell
Get-XdrThreatAnalyticsOutbreaks
```

Retrieves threat analytics outbreaks using cached data if available.

Example 2:

```powershell
Get-XdrThreatAnalyticsOutbreaks -Force
```

Forces a fresh retrieval of threat analytics outbreaks, bypassing the cache.

Example 3:

```powershell
Get-XdrThreatAnalyticsOutbreaks -ChangeCount
```

Retrieves the outbreak change count metrics from the dedicated endpoint.

Example 4:

```powershell
Get-XdrThreatAnalyticsOutbreaks -TopThreats
```

Retrieves the top threats from outbreaks, prioritized by significance.

Example 5:

```powershell
Get-XdrThreatAnalyticsOutbreaks -TopThreats -Force
```

Forces a fresh retrieval of top threats, bypassing the cache.

## Merge-XdrIncident

Guard: `write`

Merges multiple incidents into a single incident in Microsoft Defender XDR.

Combines multiple incidents into one incident in Microsoft Defender XDR.
All incidents must exist before merging. The cmdlet validates each incident ID before proceeding.
This operation requires confirmation due to its high impact.

```powershell
Merge-XdrIncident -IncidentIds <Int32[]> -Comment <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -IncidentIds | Int32[] | yes |  | Array of incident IDs to merge. Must contain at least 2 incident IDs. All incidents will be validated before the merge operation. |
| -Comment | String | yes |  | Comment explaining the reason for merging the incidents. This will be recorded in the incident history. |

Example 1:

```powershell
Merge-XdrIncident -IncidentIds 2821, 2823 -Comment "Related phishing attacks"
```

Merges incidents 2821 and 2823 with a comment.

Example 2:

```powershell
Merge-XdrIncident -IncidentIds 100, 101, 102 -Comment "Same threat actor campaign"
```

Merges three incidents into one.

Example 3:

```powershell
$incidents = 2821, 2823, 2825
Merge-XdrIncident -IncidentIds $incidents -Comment "Coordinated attack"
```

Merges multiple incidents using a variable.

## Move-XdrAlertToIncident

Guard: `write`

Moves alerts to a specific incident or creates a new one.

Moves one or more alerts to a target incident. If TargetIncidentId is not specified,
a new incident is created containing the alerts.
Validates that the TargetIncidentId and AlertIds exist before attempting the move.

```powershell
Move-XdrAlertToIncident -AlertIds <String[]> [-TargetIncidentId <Int64>] [-Comment <String>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -AlertIds | String[] | yes |  | A list of alert IDs to move. |
| -TargetIncidentId | Int64 |  | 0 | The ID of the incident to move the alerts to. If null or omitted, a new incident is created. |
| -Comment | String |  | Moved via XDRInternals | Optional comment for the operation. Default is "Moved via XDRInternals". |

Example 1:

```powershell
Move-XdrAlertToIncident -AlertIds "ed638962183442188554_-691007355" -TargetIncidentId 2822
```

Moves the specified alert to incident 2822.

Example 2:

```powershell
Move-XdrAlertToIncident -AlertIds "ed638962183442188554_-691007355"
```

Moves the specified alert to a new incident.

