# Vulnerability and exposure management

14 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Get-XdrExposureManagementRecommendations

Guard: `read`

Retrieves recommendations from Exposure Management.

Gets security recommendations from Microsoft Defender XDR Exposure Management.
Supports multiple data sources including TVM recommendations, vulnerability assessments, and device misconfigurations.
This function includes caching support with a 30-minute TTL to reduce API calls.
By default, returns the recommendations array.

```powershell
Get-XdrExposureManagementRecommendations [-Force] [-Top <Int32>]
Get-XdrExposureManagementRecommendations [-Force] [-CountOnly] [-Top <Int32>]
Get-XdrExposureManagementRecommendations [-Force] [-Top <Int32>] [-Tags]
Get-XdrExposureManagementRecommendations [-Force] [-Top <Int32>] [-ActiveVulnerabilities]
Get-XdrExposureManagementRecommendations [-Force] [-Top <Int32>] [-AllVulnerabilities]
Get-XdrExposureManagementRecommendations [-Force] [-Top <Int32>] [-Misconfigurations]
Get-XdrExposureManagementRecommendations [-Force] [-Top <Int32>] [-ByAssets] -RecommendationId <String>
Get-XdrExposureManagementRecommendations [-Force] [-Top <Int32>] [-ByOperatingSystems] -RecommendationId <String>
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -CountOnly | SwitchParameter |  | False | Returns only the total count of recommendations (numOfResults). |
| -Top | Int32 |  | 0 | Limits the number of results returned. Useful for previewing data without fetching all pages. |
| -Tags | SwitchParameter |  | False | Retrieves vulnerability assessment recommendation tags. |
| -ActiveVulnerabilities | SwitchParameter |  | False | Retrieves vulnerability assessment recommendations with filters (Active or PartialException status). |
| -AllVulnerabilities | SwitchParameter |  | False | Retrieves all vulnerability assessment recommendations without status filters. |
| -Misconfigurations | SwitchParameter |  | False | Retrieves device misconfiguration recommendations from the posture/oversight API. |
| -ByAssets | SwitchParameter |  | False | Retrieves assets for a specific recommendation. Requires -RecommendationId. |
| -ByOperatingSystems | SwitchParameter |  | False | Retrieves operating systems for a specific recommendation. Requires -RecommendationId. |
| -RecommendationId | String | yes |  | The recommendation ID required for -ByAssets and -ByOperatingSystems parameters. |

Example 1:

```powershell
Get-XdrExposureManagementRecommendations
```

Retrieves all recommendations using cached data if available.

Example 2:

```powershell
Get-XdrExposureManagementRecommendations -Force
```

Forces a fresh retrieval of recommendations, bypassing the cache.

Example 3:

```powershell
Get-XdrExposureManagementRecommendations -CountOnly
```

Returns only the total number of recommendations.

Example 4:

```powershell
Get-XdrExposureManagementRecommendations -Top 10
```

Returns only the first 10 recommendations.

Example 5:

```powershell
Get-XdrExposureManagementRecommendations -Tags
```

Retrieves vulnerability assessment recommendation tags.

Example 6:

```powershell
Get-XdrExposureManagementRecommendations -ActiveVulnerabilities
```

Retrieves vulnerability assessment recommendations with Active or PartialException status.

Example 7:

```powershell
Get-XdrExposureManagementRecommendations -AllVulnerabilities
```

Retrieves all vulnerability assessment recommendations regardless of status.

Example 8:

```powershell
Get-XdrExposureManagementRecommendations -Misconfigurations
```

Retrieves device misconfiguration recommendations.

Example 9:

```powershell
Get-XdrExposureManagementRecommendations -ByAssets -RecommendationId "sca-_-scid-69"
```

Retrieves assets for a specific recommendation.

Example 10:

```powershell
Get-XdrExposureManagementRecommendations -ByOperatingSystems -RecommendationId "va-_-microsoft-_-windows_11"
```

Retrieves operating system breakdown for a specific recommendation.

## Get-XdrVulnerabilityManagementAdvisories

Guard: `read`

Retrieves security advisories from Vulnerability Management.

Gets security advisories from Threat and Vulnerability Management (TVM) in Microsoft Defender XDR.
This function includes caching support with a 30-minute TTL to reduce API calls.
By default, returns all pages of results with pagination handled automatically.

```powershell
Get-XdrVulnerabilityManagementAdvisories [-Force] [-Top <Int32>]
Get-XdrVulnerabilityManagementAdvisories [-Force] [-CountOnly] [-Top <Int32>]
Get-XdrVulnerabilityManagementAdvisories [-Force] [-Top <Int32>] [-ByVendor]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -CountOnly | SwitchParameter |  | False | Returns only the total count of advisories (numOfResults). |
| -Top | Int32 |  | 0 | Limits the number of results returned. Useful for previewing data without fetching all pages. |
| -ByVendor | SwitchParameter |  | False | Returns only the vendor-specific advisory counts (meta object). |

Example 1:

```powershell
Get-XdrVulnerabilityManagementAdvisories
```

Retrieves all security advisories with full pagination.

Example 2:

```powershell
Get-XdrVulnerabilityManagementAdvisories -Force
```

Forces a fresh retrieval of security advisories, bypassing the cache.

Example 3:

```powershell
Get-XdrVulnerabilityManagementAdvisories -CountOnly
```

Returns only the total number of advisories.

Example 4:

```powershell
Get-XdrVulnerabilityManagementAdvisories -Top 10
```

Returns only the first 10 advisories.

Example 5:

```powershell
Get-XdrVulnerabilityManagementAdvisories -ByVendor
Returns only the vendor-specific advisory counts (Dell, HP, Lenovo).
```

## Get-XdrVulnerabilityManagementBaseline

Guard: `read`

Retrieves security baseline assessment data from Microsoft Defender XDR.

Retrieves various security baseline profile information including compliance status, statistics,
settings, and device data. Supports multiple endpoint variants for comprehensive baseline assessment.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrVulnerabilityManagementBaseline [-ProfilesStatistics] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline [-ProfilesCompliance] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline [-TopFailingDevices] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline [-AllSettingsResults] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline [-AllSettingsFilters] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline [-AllSettingsStatistics] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline [-Profiles] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline [-ProfileFilters] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline -ProfileId <String> [-OrgSettingsProfile] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline -ProfileId <String> [-ProfileComplianceStatus] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline -ProfileId <String> [-ProfileDevices] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline -ProfileId <String> [-ProfileSettings] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline -ProfileId <String> [-ProfileDetails] [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementBaseline -ProfileId <String> [-ProfileStatistics] [-Top <Int32>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -ProfilesStatistics | SwitchParameter |  | False | Retrieves statistics for all baseline profiles. |
| -ProfilesCompliance | SwitchParameter |  | False | Retrieves compliance data for all baseline profiles with pagination support. |
| -TopFailingDevices | SwitchParameter |  | False | Retrieves the top devices failing baseline assessments. |
| -AllSettingsResults | SwitchParameter |  | False | Retrieves results for all settings across all profiles with filtering and ordering. |
| -AllSettingsFilters | SwitchParameter |  | False | Retrieves available filters for all settings queries. |
| -AllSettingsStatistics | SwitchParameter |  | False | Retrieves statistical data for all settings. |
| -Profiles | SwitchParameter |  | False | Retrieves a list of all baseline profiles. |
| -ProfileFilters | SwitchParameter |  | False | Retrieves available filters for profile queries (from orgsettings). |
| -ProfileId | String | yes |  | The GUID of a specific baseline profile to query. Required when using profile-specific switches. |
| -ProfileStatistics | SwitchParameter |  | False | Retrieves statistics for a specific profile. Requires -ProfileId. |
| -ProfileDetails | SwitchParameter |  | False | Retrieves detailed information for a specific profile. Requires -ProfileId. |
| -ProfileSettings | SwitchParameter |  | False | Retrieves settings for a specific profile. Requires -ProfileId. |
| -ProfileDevices | SwitchParameter |  | False | Retrieves devices associated with a specific profile. Requires -ProfileId. |
| -ProfileComplianceStatus | SwitchParameter |  | False | Retrieves compliance status for a specific profile. Requires -ProfileId. |
| -OrgSettingsProfile | SwitchParameter |  | False | Retrieves organization settings for a specific profile. Requires -ProfileId. |
| -Top | Int32 |  | 0 | Limits the number of results returned for paginated endpoints. Useful for previewing data. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrVulnerabilityManagementBaseline -ProfilesStatistics
```

Retrieves statistics for all baseline profiles.

Example 2:

```powershell
Get-XdrVulnerabilityManagementBaseline -Profiles
```

Retrieves a list of all baseline profiles.

Example 3:

```powershell
Get-XdrVulnerabilityManagementBaseline -Profiles -Top 10
```

Retrieves the first 10 baseline profiles.

Example 4:

```powershell
Get-XdrVulnerabilityManagementBaseline -ProfileId "e0ee318e-5f4a-4a41-a49f-d899b25759ba" -ProfileDetails
```

Retrieves detailed information for a specific profile.

Example 5:

```powershell
Get-XdrVulnerabilityManagementBaseline -ProfileId "e0ee318e-5f4a-4a41-a49f-d899b25759ba" -ProfileStatistics
```

Retrieves statistics for a specific profile.

Example 6:

```powershell
Get-XdrVulnerabilityManagementBaseline -ProfileId "e0ee318e-5f4a-4a41-a49f-d899b25759ba" -ProfileDevices
```

Retrieves all devices for a specific profile with automatic pagination.

Example 7:

```powershell
Get-XdrVulnerabilityManagementBaseline -AllSettingsResults
```

Retrieves results for all settings with default filtering.

Example 8:

```powershell
Get-XdrVulnerabilityManagementBaseline -TopFailingDevices
```

Retrieves the top devices failing baseline assessments.

## Get-XdrVulnerabilityManagementCertificates

Guard: `read`

Retrieves certificates from Vulnerability Management.

Gets certificate inventory data from TVM in Microsoft Defender XDR.
This includes information about server certificates, machine certificates, certificate issues, and issuers.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-ServerCertificateIssues]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-MachineCertificateIssues]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-PrivateCaCertificateIssues]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-ServerIssuers]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-MachineIssuers]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-CountOnly]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-CountByExpirationDate]
Get-XdrVulnerabilityManagementCertificates [-Force] [-Top <Int32>] [-AggregatedMachineCertificates]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -Top | Int32 |  | 0 | Limits the number of results returned for paginated endpoints. Useful for previewing data. |
| -ServerCertificateIssues | SwitchParameter |  | False | Retrieves server certificate issues. |
| -MachineCertificateIssues | SwitchParameter |  | False | Retrieves machine certificate issues. |
| -PrivateCaCertificateIssues | SwitchParameter |  | False | Retrieves private CA certificate issues. |
| -ServerIssuers | SwitchParameter |  | False | Retrieves server certificate issuers. |
| -MachineIssuers | SwitchParameter |  | False | Retrieves machine certificate issuers. |
| -CountOnly | SwitchParameter |  | False | Retrieves only the total count of certificates. |
| -CountByExpirationDate | SwitchParameter |  | False | Retrieves certificate count grouped by expiration date. |
| -AggregatedMachineCertificates | SwitchParameter |  | False | Retrieves aggregated machine certificate data from the aggregatedCertificate endpoint. |

Example 1:

```powershell
Get-XdrVulnerabilityManagementCertificates
```

Retrieves all certificates using cached data if available.

Example 2:

```powershell
Get-XdrVulnerabilityManagementCertificates -Force
```

Forces a fresh retrieval of certificate inventory, bypassing the cache.

Example 3:

```powershell
Get-XdrVulnerabilityManagementCertificates -Top 10
```

Retrieves only the first 10 certificates.

Example 4:

```powershell
Get-XdrVulnerabilityManagementCertificates -ServerCertificateIssues
```

Retrieves server certificate issues.

Example 5:

```powershell
Get-XdrVulnerabilityManagementCertificates -CountOnly
```

Returns only the total count of certificates.

Example 6:

```powershell
Get-XdrVulnerabilityManagementCertificates -AggregatedMachineCertificates
```

Retrieves aggregated machine certificate data.

## Get-XdrVulnerabilityManagementChangeEvents

Guard: `read`

Retrieves change events from Vulnerability Management.

Gets change event information from Threat and Vulnerability Management (TVM) in Microsoft Defender XDR.
This function includes caching support with a 30-minute TTL to reduce API calls.
By default, returns all change event results with pagination handled automatically.

```powershell
Get-XdrVulnerabilityManagementChangeEvents [-Force] [-Top <Int32>]
Get-XdrVulnerabilityManagementChangeEvents [-Force] [-Top <Int32>] [-CountOnly]
Get-XdrVulnerabilityManagementChangeEvents [-Force] [-Top <Int32>] [-SummaryOnly]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -Top | Int32 |  | 0 | Limits the number of results returned. Useful for previewing data without fetching all pages. |
| -CountOnly | SwitchParameter |  | False | Returns only the total count of change events (numOfResults). |
| -SummaryOnly | SwitchParameter |  | False | Returns only the change event summary metadata (meta object). |

Example 1:

```powershell
Get-XdrVulnerabilityManagementChangeEvents
```

Retrieves all change events with full pagination.

Example 2:

```powershell
Get-XdrVulnerabilityManagementChangeEvents -Force
```

Forces a fresh retrieval of change events, bypassing the cache.

Example 3:

```powershell
Get-XdrVulnerabilityManagementChangeEvents -Top 10
```

Returns only the first 10 change events.

Example 4:

```powershell
Get-XdrVulnerabilityManagementChangeEvents -CountOnly
```

Returns only the total number of change events.

Example 5:

```powershell
Get-XdrVulnerabilityManagementChangeEvents -SummaryOnly
```

Returns only the change event summary metadata.

## Get-XdrVulnerabilityManagementDashboard

Guard: `read`

Retrieves Microsoft Defender Vulnerability Management dashboard analytics data.

Retrieves various analytics data displayed on the TVM dashboard including risk scores,
secure scores, asset exposure levels, change events, and notification rules.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrVulnerabilityManagementDashboard [-RiskScore] [-Force]
Get-XdrVulnerabilityManagementDashboard [-VulnerabilityNotificationRules] [-Force]
Get-XdrVulnerabilityManagementDashboard [-SecureScoreCategories] [-Force]
Get-XdrVulnerabilityManagementDashboard [-SecureScoreTotal] [-Force]
Get-XdrVulnerabilityManagementDashboard [-AssetsCountByExposureLevel] [-Force]
Get-XdrVulnerabilityManagementDashboard [-AssetsTopVulnerable] [-Force]
Get-XdrVulnerabilityManagementDashboard [-ChangeEventsVaTopPerDay] [-Force]
Get-XdrVulnerabilityManagementDashboard [-ChangeEventsScaTopPerDay] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -VulnerabilityNotificationRules | SwitchParameter |  | False | Retrieves metadata for vulnerability notification rules configuration. |
| -SecureScoreCategories | SwitchParameter |  | False | Retrieves secure score breakdown by categories. |
| -SecureScoreTotal | SwitchParameter |  | False | Retrieves the total secure score for the organization. |
| -RiskScore | SwitchParameter |  | False | Retrieves the organization's risk score from TVM analytics. |
| -AssetsCountByExposureLevel | SwitchParameter |  | False | Retrieves count of assets grouped by their exposure level. |
| -AssetsTopVulnerable | SwitchParameter |  | False | Retrieves the top most vulnerable assets in the environment. |
| -ChangeEventsVaTopPerDay | SwitchParameter |  | False | Retrieves top vulnerability assessment (VA) change events per day. |
| -ChangeEventsScaTopPerDay | SwitchParameter |  | False | Retrieves top software composition analysis (SCA) change events per day. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrVulnerabilityManagementDashboard -RiskScore
```

Retrieves the organization's current risk score.

Example 2:

```powershell
Get-XdrVulnerabilityManagementDashboard -SecureScoreTotal
```

Retrieves the organization's total secure score.

Example 3:

```powershell
Get-XdrVulnerabilityManagementDashboard -SecureScoreCategories
```

Retrieves secure score broken down by security categories.

Example 4:

```powershell
Get-XdrVulnerabilityManagementDashboard -AssetsCountByExposureLevel
Retrieves count of assets at each exposure level (None, Low, Medium, High, Critical).
```

Example 5:

```powershell
Get-XdrVulnerabilityManagementDashboard -AssetsTopVulnerable
```

Retrieves the most vulnerable assets in your environment.

Example 6:

```powershell
Get-XdrVulnerabilityManagementDashboard -ChangeEventsVaTopPerDay
Retrieves top vulnerability changes per day (new vulnerabilities discovered).
```

Example 7:

```powershell
Get-XdrVulnerabilityManagementDashboard -VulnerabilityNotificationRules
```

Retrieves vulnerability notification rules metadata.

## Get-XdrVulnerabilityManagementExtensions

Guard: `read`

Retrieves browser extensions from Vulnerability Management.

Gets browser extension inventory data from TVM in Microsoft Defender XDR.
This function includes caching support with a 30-minute TTL to reduce API calls.
Supports various sub-endpoints for detailed extension information.

```powershell
Get-XdrVulnerabilityManagementExtensions [-Force] [-Top <Int32>]
Get-XdrVulnerabilityManagementExtensions [-Force] [-Top <Int32>] [-Summary]
Get-XdrVulnerabilityManagementExtensions [-Force] [-Top <Int32>] [-Installations] -ExtensionId <String> -TargetSoftware <String>
Get-XdrVulnerabilityManagementExtensions [-Force] [-Top <Int32>] [-InstallationsAggregate] -ExtensionId <String> -TargetSoftware <String>
Get-XdrVulnerabilityManagementExtensions [-Force] [-Top <Int32>] [-Users] -ExtensionId <String> -TargetSoftware <String>
Get-XdrVulnerabilityManagementExtensions [-Force] [-Top <Int32>] [-CountOnly]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -Top | Int32 |  | 0 | Limits the number of results returned for paginated endpoints. Useful for previewing data. |
| -Summary | SwitchParameter |  | False | Retrieves the extensions summary endpoint. |
| -Installations | SwitchParameter |  | False | Retrieves extension installation details. Requires -ExtensionId and -TargetSoftware. |
| -InstallationsAggregate | SwitchParameter |  | False | Retrieves aggregated extension installation data. Requires -ExtensionId and -TargetSoftware. |
| -Users | SwitchParameter |  | False | Retrieves users with the extension installed. Requires -ExtensionId and -TargetSoftware. |
| -CountOnly | SwitchParameter |  | False | Retrieves only the total count of extensions. |
| -ExtensionId | String | yes |  | The extension ID required for -Installations, -InstallationsAggregate, and -Users parameters. |
| -TargetSoftware | String | yes |  | The target software (e.g., 'edge', 'chrome') required for -Installations, -InstallationsAggregate, and -Users parameters. |

Example 1:

```powershell
Get-XdrVulnerabilityManagementExtensions
```

Retrieves all browser extensions using cached data if available.

Example 2:

```powershell
Get-XdrVulnerabilityManagementExtensions -Force
```

Forces a fresh retrieval of browser extensions, bypassing the cache.

Example 3:

```powershell
Get-XdrVulnerabilityManagementExtensions -Top 10
```

Retrieves only the first 10 browser extensions.

Example 4:

```powershell
Get-XdrVulnerabilityManagementExtensions -Summary
```

Retrieves the extensions summary data.

Example 5:

```powershell
Get-XdrVulnerabilityManagementExtensions -Installations -ExtensionId "ggjhpefgjjfobnfoldnjipclpcfbgbhl" -TargetSoftware "edge"
```

Retrieves installation details for a specific extension.

Example 6:

```powershell
Get-XdrVulnerabilityManagementExtensions -CountOnly
```

Returns only the total count of extensions.

## Get-XdrVulnerabilityManagementProducts

Guard: `read`

Retrieves products from Vulnerability Management.

Gets product information from Threat and Vulnerability Management (TVM) in Microsoft Defender XDR.
This function includes caching support with a 30-minute TTL to reduce API calls.
By default, returns the products array.

```powershell
Get-XdrVulnerabilityManagementProducts [-Top <Int32>] [-Force]
Get-XdrVulnerabilityManagementProducts [-Force] [-CountOnly]
Get-XdrVulnerabilityManagementProducts [-Force] [-HardwareVendorsInventoryCount]
Get-XdrVulnerabilityManagementProducts [-Force] [-BiosVendorsInventoryCount]
Get-XdrVulnerabilityManagementProducts [-Force] [-ProcessorVendorsInventoryCount]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Top | Int32 |  | 0 | Limits the number of results returned. Valid range is 1-10000. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -CountOnly | SwitchParameter |  | False | Returns only the total count of products (numOfResults). |
| -HardwareVendorsInventoryCount | SwitchParameter |  | False | Retrieves hardware vendors inventory count. |
| -BiosVendorsInventoryCount | SwitchParameter |  | False | Retrieves BIOS vendors inventory count. |
| -ProcessorVendorsInventoryCount | SwitchParameter |  | False | Retrieves processor vendors inventory count. |

Example 1:

```powershell
Get-XdrVulnerabilityManagementProducts
```

Retrieves all products using cached data if available.

Example 2:

```powershell
Get-XdrVulnerabilityManagementProducts -Top 100
```

Retrieves the first 100 products.

Example 3:

```powershell
Get-XdrVulnerabilityManagementProducts -Force
```

Forces a fresh retrieval of products, bypassing the cache.

Example 4:

```powershell
Get-XdrVulnerabilityManagementProducts -CountOnly
```

Returns only the total number of products.

Example 5:

```powershell
Get-XdrVulnerabilityManagementProducts -HardwareVendorsInventoryCount
```

Retrieves hardware vendors inventory count.

## Get-XdrVulnerabilityManagementRemediationTasks

Guard: `read`

Retrieves remediation tasks from Vulnerability Management.

Gets remediation task information from the Threat and Vulnerability Management (TVM) in Microsoft Defender XDR.
This includes remediation tasks, exceptions, and blocked applications.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrVulnerabilityManagementRemediationTasks [-Force]
Get-XdrVulnerabilityManagementRemediationTasks [-Force] [-PreRemediation] -Body <Object>
Get-XdrVulnerabilityManagementRemediationTasks [-Force] [-RecommendationExceptions]
Get-XdrVulnerabilityManagementRemediationTasks [-Force] [-AllExceptions]
Get-XdrVulnerabilityManagementRemediationTasks [-Force] [-AllExceptionsAggregated]
Get-XdrVulnerabilityManagementRemediationTasks [-Force] [-BlockedApplications]
Get-XdrVulnerabilityManagementRemediationTasks [-Force] [-BlockedApplicationsCount]
Get-XdrVulnerabilityManagementRemediationTasks [-Force] [-BaselineExceptions]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -PreRemediation | SwitchParameter |  | False | Retrieves pre-remediation information. This is a POST endpoint. |
| -RecommendationExceptions | SwitchParameter |  | False | Retrieves recommendation exceptions. |
| -AllExceptions | SwitchParameter |  | False | Retrieves all exceptions (non-aggregated). |
| -AllExceptionsAggregated | SwitchParameter |  | False | Retrieves aggregated exceptions data. |
| -BlockedApplications | SwitchParameter |  | False | Retrieves blocked applications list. |
| -BlockedApplicationsCount | SwitchParameter |  | False | Retrieves count of blocked applications. |
| -BaselineExceptions | SwitchParameter |  | False | Retrieves baseline exceptions from organization settings. |
| -Body | Object | yes |  | Request body for PreRemediation endpoint (POST request). |

Example 1:

```powershell
Get-XdrVulnerabilityManagementRemediationTasks
```

Retrieves all remediation tasks using cached data if available.

Example 2:

```powershell
Get-XdrVulnerabilityManagementRemediationTasks -Force
```

Forces a fresh retrieval of remediation tasks, bypassing the cache.

Example 3:

```powershell
Get-XdrVulnerabilityManagementRemediationTasks -AllExceptionsAggregated
```

Retrieves aggregated exceptions data.

Example 4:

```powershell
Get-XdrVulnerabilityManagementRemediationTasks -BlockedApplications
```

Retrieves list of blocked applications.

Example 5:

```powershell
$body = @{
    groups = @()
    modelName = "PreRemediationRequestBodyModel"
    preRemediationArgs = @{
        category = "SecurityConfiguration"
        modelName = "PreRemediationArgsModel"
        preRemediationSecurityConfigurationArgs = @{
            modelName = "PreRemediationSecurityConfigurationArgsModel"
            scid = "scid-79"
            taskType = "ConfigurationChange"
        }
    }
    relatedComponent = "deviceMisconfiguration"
}
Get-XdrVulnerabilityManagementRemediationTasks -PreRemediation -Body $body
```

Submits a pre-remediation request with the specified body.

## Get-XdrVulnerabilityManagementVulnerabilities

Guard: `read`

Retrieves vulnerabilities from Vulnerability Management.

Gets vulnerability information from Threat and Vulnerability Management (TVM) in Microsoft Defender XDR.
This function includes caching support with a 30-minute TTL to reduce API calls.
By default, only returns vulnerabilities that impact at least one asset, ordered by number of impacted assets (descending).

```powershell
Get-XdrVulnerabilityManagementVulnerabilities [-Top <Int32>] [-Force] [-AllVulnerabilities]
Get-XdrVulnerabilityManagementVulnerabilities [-Force] [-CountOnly]
Get-XdrVulnerabilityManagementVulnerabilities [-Force] [-Summary]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Top | Int32 |  | 0 | Limits the number of results returned. Valid range is 1-10000. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |
| -AllVulnerabilities | SwitchParameter |  | False | Returns all vulnerabilities without filtering. By default, only vulnerabilities impacting at least one asset are returned. |
| -CountOnly | SwitchParameter |  | False | Returns only the total count of vulnerabilities (numOfResults). |
| -Summary | SwitchParameter |  | False | Returns the vulnerability summary from the dedicated summary endpoint. This provides detailed counts including total vulnerabilities, exploitable, critical, zero-day, and unpatchable vulnerabilities without retrieving full vulnerability data. |

Example 1:

```powershell
Get-XdrVulnerabilityManagementVulnerabilities
Retrieves vulnerabilities impacting at least one asset, ordered by impact (most impacted first).
```

Example 2:

```powershell
Get-XdrVulnerabilityManagementVulnerabilities -Top 100
```

Retrieves the first 100 vulnerabilities impacting at least one asset.

Example 3:

```powershell
Get-XdrVulnerabilityManagementVulnerabilities -Force
```

Forces a fresh retrieval of vulnerabilities impacting at least one asset, bypassing the cache.

Example 4:

```powershell
Get-XdrVulnerabilityManagementVulnerabilities -AllVulnerabilities
```

Retrieves all vulnerabilities without filtering, including those with zero impacted assets.

Example 5:

```powershell
Get-XdrVulnerabilityManagementVulnerabilities -CountOnly
```

Returns only the total number of vulnerabilities.

Example 6:

```powershell
Get-XdrVulnerabilityManagementVulnerabilities -Summary
```

Returns detailed vulnerability summary statistics including total, exploitable, critical, zero-day, and unpatchable counts.

## Get-XdrXspmAttackPath

Guard: `read`

Retrieves attack path data from Microsoft Defender XDR XSPM.

Gets attack path information from the XSPM (Extended Security Posture Management) attack surface API.
Attack paths represent potential routes attackers could take to compromise critical assets.
Supports pagination and can retrieve all available attack paths when using the -All parameter.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrXspmAttackPath [-Top <Int32>] [-Skip <Int32>] [-All] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Top | Int32 |  | 0 | The maximum number of attack paths to return per page. Default is 100. Ignored when -All is specified. |
| -Skip | Int32 |  | 0 | The number of attack paths to skip for pagination. Default is 0. Ignored when -All is specified. |
| -All | SwitchParameter |  | False | When specified, retrieves all available attack paths by handling pagination automatically. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrXspmAttackPath
```

Retrieves the first 100 attack paths.

Example 2:

```powershell
Get-XdrXspmAttackPath -Top 50
```

Retrieves the first 50 attack paths.

Example 3:

```powershell
Get-XdrXspmAttackPath -Top 100 -Skip 100
Retrieves attack paths 101-200 (pagination).
```

Example 4:

```powershell
Get-XdrXspmAttackPath -All
```

Retrieves all available attack paths by automatically handling pagination.

Example 5:

```powershell
Get-XdrXspmAttackPath -All -Force
```

Retrieves all attack paths, bypassing the cache.

## Get-XdrXspmChokePoint

Guard: `read`

Retrieves choke point data from Microsoft Defender XDR XSPM.

Gets choke point information from the XSPM (Extended Security Posture Management) attack surface API.
Choke points are critical nodes in the network that appear in multiple attack paths, making them
high-value targets for security hardening and monitoring.
The results are ordered by risk level (Critical, High, Medium, Low) and attack path count.
Supports pagination and can retrieve all available choke points when using the -All parameter.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrXspmChokePoint [-Top <Int32>] [-Skip <Int32>] [-All] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Top | Int32 |  | 100 | The maximum number of choke points to return per page. Default is 100. Ignored when -All is specified. |
| -Skip | Int32 |  | 0 | The number of choke points to skip for pagination. Default is 0. Ignored when -All is specified. |
| -All | SwitchParameter |  | False | When specified, retrieves all available choke points by handling pagination automatically. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrXspmChokePoint
```

Retrieves the first 100 choke points, ordered by risk level and attack path count.

Example 2:

```powershell
Get-XdrXspmChokePoint -Top 50
```

Retrieves the first 50 choke points.

Example 3:

```powershell
Get-XdrXspmChokePoint -Top 100 -Skip 100
Retrieves choke points 101-200 (pagination).
```

Example 4:

```powershell
Get-XdrXspmChokePoint -All
```

Retrieves all available choke points by automatically handling pagination.

Example 5:

```powershell
Get-XdrXspmChokePoint -All -Force
```

Retrieves all choke points, bypassing the cache.

## Get-XdrXspmTopEntryPoint

Guard: `read`

Retrieves top entry points from Microsoft Defender XDR XSPM attack paths.

Gets the top entry points from active and new attack paths in the XSPM (Extended Security Posture Management) API.
Entry points are the initial access points that attackers could use to begin an attack path.
Results are summarized by entry point ID and ordered by the number of attack paths using each entry point.
Returns the top 10 entry points by default.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrXspmTopEntryPoint [-Top <Int32>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Top | Int32 |  | 10 | The maximum number of top entry points to return. Default is 10. Note: The query includes "top 10" logic, so values other than 10 may not affect results unless the query is modified. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrXspmTopEntryPoint
```

Retrieves the top 10 entry points from active and new attack paths.

Example 2:

```powershell
Get-XdrXspmTopEntryPoint -Force
```

Retrieves the top entry points, bypassing the cache.

## Get-XdrXspmTopTarget

Guard: `read`

Retrieves top targets from Microsoft Defender XDR XSPM attack paths.

Gets the top targets from active and new attack paths in the XSPM (Extended Security Posture Management) API.
Targets are the critical assets that attackers are attempting to compromise through attack paths.
Results are summarized by target ID and ordered by the number of attack paths targeting each asset.
Returns the top 3 targets by default.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrXspmTopTarget [-Top <Int32>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Top | Int32 |  | 10 | The maximum number of top targets to return. Default is 3. Note: The query includes "top N" logic embedded. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrXspmTopTarget
```

Retrieves the top 3 targets from active and new attack paths.

Example 2:

```powershell
Get-XdrXspmTopTarget -Top 10
```

Retrieves the top 10 targets from active and new attack paths.

Example 3:

```powershell
Get-XdrXspmTopTarget -Force
```

Retrieves the top targets, bypassing the cache.

