# Endpoint configuration and licensing

14 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Get-XdrEndpointAdvancedFeatures

Guard: `read`

Retrieves comprehensive advanced features configuration for Microsoft Defender for Endpoint.

Gets a consolidated view of all advanced features settings from Microsoft Defender for Endpoint,
including EDR in block mode, device discovery, integrations, and various security features.
This is a wrapper function that combines multiple configuration endpoints into a single, formatted output.

```powershell
Get-XdrEndpointAdvancedFeatures
```

Example 1:

```powershell
Get-XdrEndpointAdvancedFeatures
```

Retrieves all advanced features configuration settings with detailed descriptions.

Example 2:

```powershell
Get-XdrEndpointAdvancedFeatures | Where-Object { $_.Value -eq $true }
```

Retrieves only the advanced features that are currently enabled.

## Get-XdrEndpointConfigurationAdvancedFeatures

Guard: `read`

Retrieves the advanced features configuration settings for Microsoft Defender for Endpoint.

Gets the raw advanced features settings from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointConfigurationAdvancedFeatures [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationAdvancedFeatures
```

Retrieves the advanced features configuration using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationAdvancedFeatures -Force
```

Forces a fresh retrieval of the advanced features configuration, bypassing the cache.

## Get-XdrEndpointConfigurationAuthenticatedTelemetry

Guard: `read`

Retrieves the Authenticated Telemetry status for Microsoft Defender for Endpoint.

Gets the Authenticated Telemetry status for Microsoft Defender for Endpoint.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointConfigurationAuthenticatedTelemetry [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationAuthenticatedTelemetry
```

Retrieves the Authenticated Telemetry status for Microsoft Defender for Endpoint.

Example 2:

```powershell
Get-XdrEndpointConfigurationAuthenticatedTelemetry -Force
```

Forces a fresh retrieval, bypassing the cache.

## Get-XdrEndpointConfigurationCustomCollectionRule

Guard: `read`

Retrieves custom collection rules for Microsoft Defender for Endpoint.

Gets the custom collection rules configured for Microsoft Defender for Endpoint.
Custom collection rules allow you to collect specific file, registry, process, and network events
based on defined criteria to support advanced hunting and detection scenarios.
This function includes caching support with a 30-minute TTL to reduce API calls.

It incorporates the same YAML schema as used by Telemetry Collection Manager
https://github.com/FalconForceTeam/TelemetryCollectionManager
for easy export and version control of custom collection rules.

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule [-Output <String>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Output | String |  | PSObject | Specifies the output format. Valid values are 'PSObject' (default) and 'YAML'. - PSObject: Returns PowerShell objects - YAML: Returns rules formatted as YAML text for easy export and version control Values: PSObject, YAML |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule
```

Retrieves all custom collection rules using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule -Force
```

Forces a fresh retrieval of custom collection rules, bypassing the cache.

Example 3:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule | Where-Object { $_.isEnabled -eq $true }
```

Retrieves only enabled custom collection rules.

Example 4:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule |
    Where-Object { $_.table -eq "DeviceFileEvents" } |
    Format-Table ruleName, actionType, platform, isEnabled -AutoSize
```

Retrieves custom collection rules for file events and displays them in a table.

Example 5:

```powershell
$rules = Get-XdrEndpointConfigurationCustomCollectionRule
$rules | Where-Object { $_.createdBy -eq "admin@contoso.com" }
```

Retrieves all rules created by a specific user.

Example 6:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule |
    Select-Object ruleName, table, actionType, scope, isEnabled
```

Retrieves custom collection rules and displays key properties.

Example 7:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule -Output YAML
```

Retrieves custom collection rules in YAML format for export. YAML format is intended to use with https://github.com/FalconForceTeam/TelemetryCollectionManager

Example 8:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule -Output YAML | Out-File "rules.yaml"
```

Exports all custom collection rules to a YAML file.

## Get-XdrEndpointConfigurationIntuneConnection

Guard: `read`

Retrieves the Intune connection status for Microsoft Defender for Endpoint.

Gets the Intune onboarding connection status from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointConfigurationIntuneConnection [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationIntuneConnection
```

Retrieves the Intune connection status using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationIntuneConnection -Force
```

Forces a fresh retrieval of the Intune connection status, bypassing the cache.

## Get-XdrEndpointConfigurationLiveResponse

Guard: `read`

Retrieves the Live Response configuration settings for Microsoft Defender for Endpoint.

Gets the Live Response configuration settings from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointConfigurationLiveResponse [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationLiveResponse
```

Retrieves the Live Response configuration using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationLiveResponse -Force
```

Forces a fresh retrieval of the Live Response configuration, bypassing the cache.

## Get-XdrEndpointConfigurationOptionalFeatures

Guard: `read`

Retrieves the advanced features configuration settings for Microsoft Defender for Endpoint.

Gets the raw advanced features settings from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationAdvancedFeatures
```

Retrieves the advanced features configuration using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationAdvancedFeatures -Force
```

Forces a fresh retrieval of the advanced features configuration, bypassing the cache.

## Get-XdrEndpointConfigurationPotentiallyUnwantedApplications

Guard: `read`

Retrieves the potentially unwanted applications (PUA) configuration for Microsoft Defender for Endpoint.

Gets the configuration settings for potentially unwanted applications from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointConfigurationPotentiallyUnwantedApplications [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationPotentiallyUnwantedApplications
```

Retrieves the PUA configuration using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationPotentiallyUnwantedApplications -Force
```

Forces a fresh retrieval of the PUA configuration, bypassing the cache.

## Get-XdrEndpointConfigurationPreviewFeature

Guard: `read`

Retrieves the preview features configuration for Microsoft Defender for Endpoint.

Gets the preview experience settings from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointConfigurationPreviewFeature [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationPreviewFeature
```

Retrieves the preview features configuration using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationPreviewFeature -Force
```

Forces a fresh retrieval of the preview features configuration, bypassing the cache.

## Get-XdrEndpointConfigurationPurviewSharing

Guard: `read`

Retrieves the Purview alert sharing configuration for Microsoft Defender for Endpoint.

Gets the Purview alert sharing status and configuration from the Microsoft Defender XDR portal.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointConfigurationPurviewSharing [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointConfigurationPurviewSharing
```

Retrieves the Purview sharing configuration using cached data if available.

Example 2:

```powershell
Get-XdrEndpointConfigurationPurviewSharing -Force
```

Forces a fresh retrieval of the Purview sharing configuration, bypassing the cache.

## Get-XdrEndpointLicenseReport

Guard: `read`

Retrieves license usage report for Microsoft Defender for Endpoint.

Retrieves license usage report for Microsoft Defender for Endpoint.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrEndpointLicenseReport [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrEndpointLicenseReport
```

Retrieves license usage report for Microsoft Defender for Endpoint.

Example 2:

```powershell
Get-XdrEndpointLicenseReport -Force
```

Forces a fresh retrieval, bypassing the cache.

## New-XdrEndpointConfigurationCustomCollectionRule

Guard: `write`

Creates a new custom collection rule for Microsoft Defender for Endpoint from a YAML file.

Creates custom collection rules for Microsoft Defender for Endpoint by importing YAML files.
The YAML files should follow the schema format used by Get-XdrEndpointConfigurationCustomCollectionRule.
Each file is validated before submission to ensure proper schema structure.

More information about the schema can be found here: https://github.com/FalconForceTeam/TelemetryCollectionManager

```powershell
New-XdrEndpointConfigurationCustomCollectionRule -FilePath <String[]> [-Enabled <Boolean>] [-BypassCache]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -FilePath | String[] | yes |  | Path to one or more YAML files containing custom collection rule definitions. Supports wildcards for batch processing. |
| -Enabled | Boolean |  | False | Specifies whether the created rule(s) should be enabled. Default is $false. |
| -BypassCache | SwitchParameter |  | False | Bypasses any existing cache entries when creating the rule. Will slow down processing if multiple rules are created in succession. |

Example 1:

```powershell
New-XdrEndpointConfigurationCustomCollectionRule -FilePath "C:\Rules\FileMonitoring.yaml"
```

Creates a single custom collection rule from the specified YAML file.

Example 2:

```powershell
New-XdrEndpointConfigurationCustomCollectionRule -FilePath "C:\Rules\*.yaml"
```

Creates custom collection rules from all YAML files in the specified directory.

Example 3:

```powershell
Get-ChildItem "C:\Rules" -Filter "*.yaml" |
    New-XdrEndpointConfigurationCustomCollectionRule
```

Creates custom collection rules from all YAML files using pipeline input.

## Set-XdrEndpointAdvancedFeatures

Guard: `write`

Configures advanced features settings for Microsoft Defender for Endpoint.

Sets advanced features configuration for Microsoft Defender for Endpoint.
This function updates various advanced features across different configuration endpoints.

Note: AlwaysRemediatePUA and EnableAutomaticAttackDisruption cannot be changed through this function
as they are part of PotentiallyUnwantedApplications which is read-only.

```powershell
Set-XdrEndpointAdvancedFeatures [-EnableEDRInBlockMode <Boolean>] [-EnableMicrosoftDefenderAntivirusInAuditMode <Boolean>] [-DeviceDiscovery <Boolean>] [-HidePotentialDuplicateDeviceRecords <Boolean>] [-AllowOrBlockFile <Boolean>] [-SkypeForBusinessIntegration <Boolean>] [-ShowUserDetails <Boolean>] [-MicrosoftDefenderForIdentityIntegration <Boolean>] [-AutomaticallyResolveAlerts <Boolean>] [-MicrosoftDefenderForCloudApps <Boolean>] [-AzureInformationProtection <Boolean>] [-TamperProtection <Boolean>] [-CustomNetworkIndicators <Boolean>] [-WebContentFiltering <Boolean>] [-MicrosoftEndpointDLP <Boolean>] [-DownloadQuarantinedFiles <Boolean>] [-RestrictCorrelationToWithinScopedDeviceGroups <Boolean>] [-ExcludeDevices <Boolean>] [-ActiveIncidentResponse <Boolean>] [-AggregatedReporting <Boolean>] [-LowFidelityEnrichmentEnabled <Boolean>] [-IsolationExclusionRules <Boolean>] [-DefaultToStreamlinedConnectivityWhenOnboardingDevicesInDefenderPortal <Boolean>] [-ApplyStreamlinedConnectivitySettingsToDevicesManagedByIntuneAndDefenderForCloud <Boolean>] [-PreviewFeatures <Boolean>] [-PurviewSharing <Boolean>] [-MicrosoftIntuneConnection <Boolean>] [-AuthenticatedTelemetry <Boolean>] [-LiveResponse <Boolean>] [-LiveResponseForServers <Boolean>] [-LiveResponseUnsignedScriptExecution <Boolean>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -EnableEDRInBlockMode | Boolean |  | False | Enable EDR in block mode. |
| -EnableMicrosoftDefenderAntivirusInAuditMode | Boolean |  | False | Enable Microsoft Defender Antivirus in audit mode. |
| -DeviceDiscovery | Boolean |  | False | Enable device discovery. |
| -HidePotentialDuplicateDeviceRecords | Boolean |  | False | Hide potential duplicate device records. |
| -AllowOrBlockFile | Boolean |  | False | Enable allow or block file feature. |
| -SkypeForBusinessIntegration | Boolean |  | False | Enable Skype for Business integration. |
| -ShowUserDetails | Boolean |  | False | Show user details. |
| -MicrosoftDefenderForIdentityIntegration | Boolean |  | False | Enable Microsoft Defender for Identity integration. |
| -AutomaticallyResolveAlerts | Boolean |  | False | Automatically resolve alerts. |
| -MicrosoftDefenderForCloudApps | Boolean |  | False | Enable Microsoft Defender for Cloud Apps integration. |
| -AzureInformationProtection | Boolean |  | False | Enable Azure Information Protection integration. |
| -TamperProtection | Boolean |  | False | Enable tamper protection. |
| -CustomNetworkIndicators | Boolean |  | False | Enable custom network indicators. |
| -WebContentFiltering | Boolean |  | False | Enable web content filtering. |
| -MicrosoftEndpointDLP | Boolean |  | False | Enable Microsoft Endpoint DLP. |
| -DownloadQuarantinedFiles | Boolean |  | False | Enable download of quarantined files. |
| -RestrictCorrelationToWithinScopedDeviceGroups | Boolean |  | False | Restrict correlation to within scoped device groups. |
| -ExcludeDevices | Boolean |  | False | Enable exclude devices feature. |
| -ActiveIncidentResponse | Boolean |  | False | Enable Active Incident Response (DART). |
| -AggregatedReporting | Boolean |  | False | Enable aggregated reporting. |
| -LowFidelityEnrichmentEnabled | Boolean |  | False | Low fidelity enrichment enabled. |
| -IsolationExclusionRules | Boolean |  | False | Enable isolation exclusion rules. |
| -DefaultToStreamlinedConnectivityWhenOnboardingDevicesInDefenderPortal | Boolean |  | False | Default to streamlined connectivity when onboarding devices. |
| -ApplyStreamlinedConnectivitySettingsToDevicesManagedByIntuneAndDefenderForCloud | Boolean |  | False | Apply streamlined connectivity settings to devices managed by Intune and Defender for Cloud. |
| -PreviewFeatures | Boolean |  | False | Enable preview features. |
| -PurviewSharing | Boolean |  | False | Enable Purview alert sharing. |
| -MicrosoftIntuneConnection | Boolean |  | False | Enable Microsoft Intune connection to share onboarding information and threat levels. |
| -AuthenticatedTelemetry | Boolean |  | False | Enable authenticated telemetry to prevent spoofing telemetry into your dashboard. |
| -LiveResponse | Boolean |  | False | Enable Live Response. |
| -LiveResponseForServers | Boolean |  | False | Enable Live Response for servers. |
| -LiveResponseUnsignedScriptExecution | Boolean |  | False | Enable unsigned script execution in Live Response. |

Example 1:

```powershell
Set-XdrEndpointAdvancedFeatures -EnableEDRInBlockMode $true
```

Enables EDR in block mode.

Example 2:

```powershell
Set-XdrEndpointAdvancedFeatures -PreviewFeatures $true -WhatIf
```

Shows what would happen when enabling preview features without actually making the change.

Example 3:

```powershell
Set-XdrEndpointAdvancedFeatures -LiveResponse $true -LiveResponseForServers $true
```

Enables Live Response for both workstations and servers.

Example 4:

```powershell
Set-XdrEndpointAdvancedFeatures -MicrosoftIntuneConnection $true
```

Enables the Microsoft Intune connection.

Example 5:

```powershell
Set-XdrEndpointAdvancedFeatures -AuthenticatedTelemetry $true
```

Enables authenticated telemetry.

## Set-XdrEndpointConfigurationCustomCollectionRule

Guard: `write`

Updates an existing custom collection rule for Microsoft Defender for Endpoint.

Updates custom collection rules for Microsoft Defender for Endpoint by importing YAML files or PSObjects.
The YAML files should follow the schema format used by Get-XdrEndpointConfigurationCustomCollectionRule.
Each rule is validated before submission to ensure proper schema structure and that the rule exists.

More information about the schema can be found here: https://github.com/FalconForceTeam/TelemetryCollectionManager

```powershell
Set-XdrEndpointConfigurationCustomCollectionRule -InputObject <Object> [-BypassCache]
Set-XdrEndpointConfigurationCustomCollectionRule -FilePath <String[]> -RuleId <String> [-BypassCache]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -FilePath | String[] | yes |  | Path to one or more YAML files containing custom collection rule definitions. Supports wildcards for batch processing. When using YAML files, the RuleId parameter must be provided. |
| -RuleId | String | yes |  | The GUID of the rule to update. Required when using FilePath parameter. This ensures you're updating the correct rule when using YAML files. |
| -InputObject | Object | yes |  | PSObject containing the rule to update. The object must include a ruleId property. Typically obtained from Get-XdrEndpointConfigurationCustomCollectionRule. |
| -BypassCache | SwitchParameter |  | False | Bypasses any existing cache entries when updating the rule. Will slow down processing if multiple rules are updated in succession. |

Example 1:

```powershell
Set-XdrEndpointConfigurationCustomCollectionRule -FilePath "C:\Rules\FileMonitoring.yaml" -RuleId "12345678-1234-1234-1234-123456789012"
```

Updates a single custom collection rule from the specified YAML file.

Example 2:

```powershell
Set-XdrEndpointConfigurationCustomCollectionRule -FilePath "C:\Rules\*.yaml" -RuleId "12345678-1234-1234-1234-123456789012"
```

Updates custom collection rules from all YAML files in the specified directory.

Example 3:

```powershell
Get-XdrEndpointConfigurationCustomCollectionRule |
    Where-Object { $_.ruleName -eq "My Rule" } |
    Set-XdrEndpointConfigurationCustomCollectionRule
```

Updates a rule by passing a PSObject from Get cmdlet through the pipeline.

Example 4:

```powershell
$rule = Get-XdrEndpointConfigurationCustomCollectionRule | Where-Object { $_.ruleName -eq "My Rule" }
$rule.isEnabled = $false
Set-XdrEndpointConfigurationCustomCollectionRule -InputObject $rule
```

Gets a rule, modifies it, and updates it.

