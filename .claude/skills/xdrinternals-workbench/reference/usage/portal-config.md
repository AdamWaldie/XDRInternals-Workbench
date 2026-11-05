# Portal configuration and streaming

13 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Get-XdrConfigurationAlertServiceSetting

Guard: `read`

Retrieves alert service settings from Microsoft Defender XDR.

Gets the alert service settings for various workloads from the Microsoft Defender XDR portal,
showing which services have alerts disabled and the reasons for disablement.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrConfigurationAlertServiceSetting [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationAlertServiceSetting
```

Retrieves the alert service settings using cached data if available.

Example 2:

```powershell
Get-XdrConfigurationAlertServiceSetting -Force
```

Forces a fresh retrieval of the alert service settings, bypassing the cache.

## Get-XdrConfigurationAlertTuning

Guard: `read`

Retrieves alert tuning configuration from Microsoft Defender XDR.

Gets the alert suppression rules configuration from the Microsoft Defender XDR portal,
including alert tuning rules and their conditions.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrConfigurationAlertTuning [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationAlertTuning
```

Retrieves the alert tuning configuration using cached data if available.

Example 2:

```powershell
Get-XdrConfigurationAlertTuning -Force
```

Forces a fresh retrieval of the alert tuning configuration, bypassing the cache.

## Get-XdrConfigurationAssetRuleManagement

Guard: `read`

Retrieves asset rule management configuration from Microsoft Defender XDR.

Gets the asset rule management configuration from the Microsoft Defender XDR portal,
including device tagging rules, conditions, and actions.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrConfigurationAssetRuleManagement [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationAssetRuleManagement
```

Retrieves the asset rule management configuration using cached data if available.

Example 2:

```powershell
Get-XdrConfigurationAssetRuleManagement -Force
```

Forces a fresh retrieval of the asset rule management configuration, bypassing the cache.

## Get-XdrConfigurationCriticalAssetManagementClassification

Guard: `read`

Retrieves critical asset management classification rules from Microsoft Defender XDR.

Gets the critical asset management rules from the Microsoft Defender XDR portal,
including asset classification rules and conditions.
This function includes caching support with a 30-minute TTL to reduce API calls.

Critical asset management allows you to define classification rules that identify
high-value assets in your organization, such as privileged accounts, critical servers,
or sensitive data repositories.

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification [-RuleId <String>] [-RuleType <String>] [-Enabled <Boolean>] [-IncludeAffectedAssets] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -RuleId | String |  |  | The unique identifier of a specific rule to retrieve. If specified, returns only the rule with the matching ID. |
| -RuleType | String |  |  | Filters rules by type. Valid values are "Predefined" and "CreatedByUser". If not specified, all rules are returned. Values: Predefined, CreatedByUser |
| -Enabled | Boolean |  | False | Filters rules by enabled status. When specified, returns only rules where isEnabled matches the specified value. |
| -IncludeAffectedAssets | SwitchParameter |  | False | When specified, retrieves the list of affected assets for each rule by making additional API calls to the querybuilder/assets endpoint. This adds an 'affectedAssets' property to each rule containing the detailed asset information. |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification
```

Retrieves all critical asset management rules using cached data if available.

Example 2:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleId "55a3f458c38a4b53b7d6a5564e0d1ac7"
```

Retrieves a specific critical asset management rule by its ID.

Example 3:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType Predefined
```

Retrieves only predefined critical asset management rules.

Example 4:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType CreatedByUser
```

Retrieves only user-created critical asset management rules.

Example 5:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -Enabled $true
```

Retrieves only enabled critical asset management rules.

Example 6:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType Predefined -Enabled $false
```

Retrieves predefined rules that are currently disabled.

Example 7:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -Force
```

Forces a fresh retrieval of the critical asset management configuration, bypassing the cache.

Example 8:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleId "b65d8e2e4e2f496d975a3987e43811f8" -IncludeAffectedAssets
```

Retrieves a specific rule and includes the list of affected assets.

Example 9:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType Predefined -IncludeAffectedAssets | Where-Object { $_.affectedAssetsCount -gt 0 }
```

Retrieves predefined rules that have affected assets and includes the asset details.

Example 10:

```powershell
# Pipeline to Set: Enable all disabled predefined rules
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType Predefined -Enabled $false |
    Set-XdrConfigurationCriticalAssetManagementClassification -Enabled $true
```

Enables all disabled predefined critical asset management rules.

Example 11:

```powershell
# Pipeline to Remove: Clean up test rules
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType CreatedByUser |
    Where-Object { $_.ruleName -like "*Test*" } |
    Remove-XdrConfigurationCriticalAssetManagementClassification -Force
```

Removes all user-created rules with "Test" in the name.

## Get-XdrConfigurationCriticalAssetManagementClassificationSchema

Guard: `read`

Retrieves the schema for Critical Asset Management rules from Microsoft Defender XDR.

Gets the schema definition for the Critical Asset Management query builder. This includes
the available asset types (Devices, Identities, CloudResources) and their filterable
properties that can be used when creating custom critical asset rules.

Each property includes its name and type (e.g., ClosedList, Boolean, String, Array).
This information is useful for understanding what criteria can be used to identify
critical assets in your organization.

```powershell
Get-XdrConfigurationCriticalAssetManagementClassificationSchema [-AssetType <String>] [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -AssetType | String |  |  | Filter the schema to a specific asset type. Valid values are: - Devices: Properties for device-based rules - Identities: Properties for identity/user-based rules - CloudResources: Properties for cloud resource-based rules Values: Devices, Identities, CloudResources |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassificationSchema
```

Retrieves the full schema for all asset types.

Example 2:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassificationSchema -AssetType Identities
```

Retrieves only the schema for identity-based rules.

Example 3:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassificationSchema -AssetType Devices |
    Select-Object -ExpandProperty properties
```

Lists all available properties for device-based critical asset rules.

Example 4:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassificationSchema -Force
```

Forces a fresh retrieval of the schema, bypassing the cache.

Example 5:

```powershell
# Discover schema and create a rule based on available properties
$deviceProps = Get-XdrConfigurationCriticalAssetManagementClassificationSchema -AssetType Devices |
    Select-Object -ExpandProperty properties
```

# Display available properties $deviceProps | Format-Table name, propertyType # Create a rule using one of the discovered properties New-XdrConfigurationCriticalAssetManagementClassification ` -RuleName "Critical Servers" ` -RuleDescription "Servers with critical tag" ` -AssetType Devices ` -CriticalityLevel VeryHigh ` -Property "Tags" ` -Operator Contains ` -Value "Critical" Discovers available properties and creates a rule using one of them.

## Get-XdrConfigurationPreviewFeatures

Guard: `read`

Retrieves the configuration for Defender XDR Preview features.

Retrieves the configuration for Defender XDR Preview features.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrConfigurationPreviewFeatures [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationPreviewFeatures
```

Retrieves the configuration for Defender XDR Preview features.

Example 2:

```powershell
Get-XdrConfigurationPreviewFeatures -Force
```

Forces a fresh retrieval, bypassing the cache.

## Get-XdrConfigurationServiceAccountClassification

Guard: `read`

Retrieves service account classification rules from Microsoft Defender XDR.

Gets the service account classification rules from the Microsoft Defender XDR portal,
including rules for identifying and classifying service accounts.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrConfigurationServiceAccountClassification [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationServiceAccountClassification
```

Retrieves the service account classification rules using cached data if available.

Example 2:

```powershell
Get-XdrConfigurationServiceAccountClassification -Force
```

Forces a fresh retrieval of the service account classification rules, bypassing the cache.

## Get-XdrConfigurationUnifiedRBACWorkload

Guard: `read`

Retrieves Unified RBAC workload configuration from Microsoft Defender XDR.

Gets the Unified RBAC workload configuration for all workloads from the Microsoft Defender XDR portal,
including workload eligibility, provisioning status, URBAC enablement, and cloud scoping activation status.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrConfigurationUnifiedRBACWorkload [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrConfigurationUnifiedRBACWorkload
```

Retrieves the Unified RBAC workload configuration using cached data if available.

Example 2:

```powershell
Get-XdrConfigurationUnifiedRBACWorkload -Force
```

Forces a fresh retrieval of the Unified RBAC workload configuration, bypassing the cache.

## Get-XdrStreamingApiConfiguration

Guard: `read`

Retrieves Streaming API configuration from Microsoft Defender XDR.

Gets the Streaming API data export settings from the Microsoft Defender XDR portal,
including workspace properties and log streaming configuration.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Get-XdrStreamingApiConfiguration [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Force | SwitchParameter |  | False | Bypasses the cache and forces a fresh retrieval from the API. |

Example 1:

```powershell
Get-XdrStreamingApiConfiguration
```

Retrieves the Streaming API configuration using cached data if available.

Example 2:

```powershell
Get-XdrStreamingApiConfiguration -Force
```

Forces a fresh retrieval of the Streaming API configuration, bypassing the cache.

## New-XdrConfigurationCriticalAssetManagementClassification

Guard: `write`

Creates a new Critical Asset Management classification rule in Microsoft Defender XDR.

Creates a custom Critical Asset Management classification rule to identify and classify
critical assets in your organization. Rules can target Devices, Identities, or CloudResources
and use property-based conditions to match assets.

Use Get-XdrConfigurationCriticalAssetManagementClassificationSchema to discover available properties
and their types for building rule conditions.

```powershell
New-XdrConfigurationCriticalAssetManagementClassification -RuleName <String> -RuleDescription <String> -AssetType <String> -CriticalityLevel <Object> -Property <String> -Operator <String> -Value <String[]> [-Disabled] [-PassThru]
New-XdrConfigurationCriticalAssetManagementClassification -RuleName <String> -RuleDescription <String> -AssetType <String> -CriticalityLevel <Object> -RuleDefinition <Hashtable> [-Disabled] [-PassThru]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -RuleName | String | yes |  | The display name for the new classification rule. Must be unique. |
| -RuleDescription | String | yes |  | A description explaining what the rule identifies and its purpose. |
| -AssetType | String | yes |  | The type of assets this rule applies to. Valid values are: - Devices: Target device/endpoint assets - Identities: Target user/identity assets - CloudResources: Target cloud resource assets Values: Devices, Identities, CloudResources |
| -CriticalityLevel | Object | yes |  | The criticality level to assign to matching assets. Accepts either numeric values or friendly names: - 0 or 'VeryHigh': Very High criticality - 1 or 'High': High criticality - 2 or 'Medium': Medium criticality - 3 or 'Low': Low criticality |
| -Property | String | yes |  | The property name to filter on. Use Get-XdrConfigurationCriticalAssetManagementClassificationSchema to see available properties for each asset type. |
| -Operator | String | yes |  | The comparison operator. Valid values are: - Equals: Exact match - NotEquals: Does not match - Contains: Contains the value (for string properties) - NotContains: Does not contain the value Values: Equals, NotEquals, Contains, NotContains |
| -Value | String[] | yes |  | The value(s) to match against. Can be a single value or an array of values. |
| -RuleDefinition | Hashtable | yes |  | Advanced: A complete rule definition hashtable for complex rules with multiple conditions. When specified, Property, Operator, and Value parameters are ignored. Example structure: @{ conditionType = "Operational" logicalOperator = "AND" # or "OR" conditions = @( @{ conditionType = "Simple" predicate = @{ property = "Property Name" operator = "Equals" value = @("value1", "value2") } } ) } |
| -Disabled | SwitchParameter |  | False | If specified, creates the rule in a disabled state. |
| -PassThru | SwitchParameter |  | False | When specified, returns the full rule object after creation. By default, only the ruleId is returned. |

Example 1:

```powershell
New-XdrConfigurationCriticalAssetManagementClassification -RuleName "Executive Accounts" `
    -RuleDescription "Identifies executive user accounts" `
    -AssetType Identities `
    -CriticalityLevel VeryHigh `
    -Property "Job Title" `
    -Operator Equals `
    -Value "CEO", "CFO", "CTO"
```

Creates a Very High criticality rule for executive accounts using the friendly name.

Example 2:

```powershell
New-XdrConfigurationCriticalAssetManagementClassification -RuleName "Domain Controllers" `
    -RuleDescription "Identifies domain controller servers" `
    -AssetType Devices `
    -CriticalityLevel 1 `
    -Property "Device Role" `
    -Operator Equals `
    -Value "DomainController"
```

Creates a High criticality rule for domain controllers using numeric level.

Example 3:

```powershell
# Discover available properties for Devices, then create a rule
Get-XdrConfigurationCriticalAssetManagementClassificationSchema -AssetType Devices |
    Select-Object -ExpandProperty properties
```

New-XdrConfigurationCriticalAssetManagementClassification -RuleName "Windows Servers" ` -RuleDescription "Windows Server devices" ` -AssetType Devices ` -CriticalityLevel High ` -Property "OS Platform" ` -Operator Equals ` -Value "Windows" ` -PassThru Discovers schema properties, then creates a rule and returns the full rule object.

Example 4:

```powershell
$rule = @{
    conditionType = "Operational"
    logicalOperator = "AND"
    conditions = @(
        @{
            conditionType = "Simple"
            predicate = @{
                property = "Device Type"
                operator = "Equals"
                value = @("Server")
            }
        },
        @{
            conditionType = "Simple"
            predicate = @{
                property = "Tags"
                operator = "Contains"
                value = @("Production")
            }
        }
    )
}
New-XdrConfigurationCriticalAssetManagementClassification -RuleName "Production Servers" `
    -RuleDescription "Production server devices" `
    -AssetType Devices `
    -CriticalityLevel High `
    -RuleDefinition $rule
```

Creates a rule with multiple conditions using AND logic.

Example 5:

```powershell
# Full workflow: Create, verify, check affected assets, then clean up
$newRule = New-XdrConfigurationCriticalAssetManagementClassification `
    -RuleName "Test Rule" `
    -RuleDescription "Temporary test rule" `
    -AssetType Devices `
    -CriticalityLevel Low `
    -Property "Tags" `
    -Operator Contains `
    -Value "Test" `
    -PassThru
```

# View the created rule with affected assets Get-XdrConfigurationCriticalAssetManagementClassification -RuleId $newRule.ruleId -IncludeAffectedAssets # Clean up test rule $newRule | Remove-XdrConfigurationCriticalAssetManagementClassification -Force Demonstrates a complete workflow of creating, verifying, and removing a rule.

## Remove-XdrConfigurationCriticalAssetManagementClassification

Guard: `write`

Removes a Critical Asset Management classification rule from Microsoft Defender XDR.

Deletes a user-created Critical Asset Management classification rule. This operation
marks the rule as deleted and it will no longer be evaluated against assets.

Note: Only user-created rules (ruleType = "CreatedByUser") can be deleted.
Predefined rules cannot be deleted, only disabled.

```powershell
Remove-XdrConfigurationCriticalAssetManagementClassification -RuleId <String> [-Force]
Remove-XdrConfigurationCriticalAssetManagementClassification -InputObject <PSObject> [-Force]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -RuleId | String | yes |  | The unique identifier of the rule to delete. |
| -InputObject | PSObject | yes |  | A rule object from Get-XdrConfigurationCriticalAssetManagementClassification to delete. Can be piped to this cmdlet. |
| -Force | SwitchParameter |  | False | Suppresses the confirmation prompt before deleting the rule. |

Example 1:

```powershell
Remove-XdrConfigurationCriticalAssetManagementClassification -RuleId "b2ccb988-5761-4947-93da-12e7c0ae6171"
```

Deletes the specified rule after confirmation.

Example 2:

```powershell
Remove-XdrConfigurationCriticalAssetManagementClassification -RuleId "b2ccb988-5761-4947-93da-12e7c0ae6171" -Force
```

Deletes the specified rule without confirmation.

Example 3:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleId "b2ccb988-5761-4947-93da-12e7c0ae6171" |
    Remove-XdrConfigurationCriticalAssetManagementClassification
```

Pipes a rule object to delete it.

Example 4:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType CreatedByUser |
    Where-Object { $_.ruleName -like "*Test*" } |
    Remove-XdrConfigurationCriticalAssetManagementClassification -Force
```

Deletes all user-created rules with "Test" in the name.

Example 5:

```powershell
# Full create and cleanup workflow
$rule = New-XdrConfigurationCriticalAssetManagementClassification `
    -RuleName "Temporary Test Rule" `
    -RuleDescription "Rule for testing" `
    -AssetType Devices -CriticalityLevel Low `
    -Property "Tags" -Operator Contains -Value "TestTag" `
    -PassThru
```

# Verify creation Get-XdrConfigurationCriticalAssetManagementClassification -RuleId $rule.ruleId # Remove when done testing $rule | Remove-XdrConfigurationCriticalAssetManagementClassification -Force Creates a rule, verifies it exists, then removes it.

## Set-XdrConfigurationCriticalAssetManagementClassification

Guard: `write`

Updates critical asset management classification rule metadata in Microsoft Defender XDR.

Modifies critical asset management rules in the Microsoft Defender XDR portal.
This function allows enabling or disabling rules by updating their metadata.

Critical asset management allows you to define classification rules that identify
high-value assets in your organization, such as privileged accounts, critical servers,
or sensitive data repositories.

```powershell
Set-XdrConfigurationCriticalAssetManagementClassification -RuleId <String> -Enabled <Boolean> [-PassThru]
Set-XdrConfigurationCriticalAssetManagementClassification -InputObject <PSObject> -Enabled <Boolean> [-PassThru]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -RuleId | String | yes |  | The unique identifier of the rule to update. This parameter is mandatory when not using -InputObject. |
| -InputObject | PSObject | yes |  | A rule object from Get-XdrConfigurationCriticalAssetManagementClassification. When provided, avoids an extra API call to fetch rule details. Can be piped directly to this cmdlet. |
| -Enabled | Boolean | yes | False | Sets whether the rule should be enabled or disabled. Use $true to enable the rule or $false to disable it. |
| -PassThru | SwitchParameter |  | False | When specified, returns the updated rule object after the operation completes. By default, this cmdlet does not generate any output. |

Example 1:

```powershell
Set-XdrConfigurationCriticalAssetManagementClassification -RuleId "55a3f458c38a4b53b7d6a5564e0d1ac7" -Enabled $true
```

Enables the critical asset management rule with the specified ID.

Example 2:

```powershell
Set-XdrConfigurationCriticalAssetManagementClassification -RuleId "55a3f458c38a4b53b7d6a5564e0d1ac7" -Enabled $false
```

Disables the critical asset management rule with the specified ID.

Example 3:

```powershell
Get-XdrConfigurationCriticalAssetManagementClassification -RuleType Predefined -Enabled $false |
    Set-XdrConfigurationCriticalAssetManagementClassification -Enabled $true
```

Enables all disabled predefined critical asset management rules using pipeline.

Example 4:

```powershell
Set-XdrConfigurationCriticalAssetManagementClassification -RuleId "55a3f458c38a4b53b7d6a5564e0d1ac7" -Enabled $true -PassThru
```

Enables the rule and returns the updated rule object.

Example 5:

```powershell
Set-XdrConfigurationCriticalAssetManagementClassification -RuleId "55a3f458c38a4b53b7d6a5564e0d1ac7" -Enabled $true -WhatIf
```

Shows what would happen if the rule were enabled, without making any changes.

Example 6:

```powershell
# Create a rule, then disable it
$rule = New-XdrConfigurationCriticalAssetManagementClassification `
    -RuleName "Temp Rule" -RuleDescription "Test" `
    -AssetType Devices -CriticalityLevel Low `
    -Property "Tags" -Operator Contains -Value "Test" -PassThru
```

$rule | Set-XdrConfigurationCriticalAssetManagementClassification -Enabled $false Creates a new rule and immediately disables it using the pipeline.

## Set-XdrConfigurationPreviewFeatures

Guard: `write`

Sets the configuration for Defender XDR Preview features.

Sets the configuration for Defender XDR Preview features.
This function includes caching support with a 30-minute TTL to reduce API calls.

```powershell
Set-XdrConfigurationPreviewFeatures [-EnableXdrAndMdi <Boolean>] [-EnableMde <Boolean>] [-EnableMda <Boolean>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -EnableXdrAndMdi | Boolean |  | False | Boolean to enable or disable preview features for Microsoft Defender XDR + Microsoft Defender for Identity. |
| -EnableMde | Boolean |  | False | Boolean to enable or disable preview features for Microsoft Defender for Endpoint. |
| -EnableMda | Boolean |  | False | Boolean to enable or disable preview features for Microsoft Defender for Cloud Apps. |

Example 1:

```powershell
Set-XdrConfigurationPreviewFeatures
```

Sets the configuration for Defender XDR Preview features.

Example 2:

```powershell
Set-XdrConfigurationPreviewFeatures -EnableXdrAndMdi $true
```

Enables preview features for Microsoft Defender XDR + Microsoft Defender for Identity.

Example 3:

```powershell
Set-XdrConfigurationPreviewFeatures -EnableMde $false
```

Disables preview features for Microsoft Defender for Endpoint.

Example 4:

```powershell
Set-XdrConfigurationPreviewFeatures -EnableMda $true
```

Enables preview features for Microsoft Defender for Cloud Apps.

Example 5:

```powershell
Set-XdrConfigurationPreviewFeatures -EnableXdrAndMdi $true -WhatIf
```

Shows what would happen if preview features were enabled for XDR and MDI.

