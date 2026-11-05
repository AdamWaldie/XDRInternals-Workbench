# XDRInternals cmdlet reference

Generated from README.md. **Guard** shows how `tools/agent/Invoke-XdrAgent.ps1` treats each cmdlet: `read` runs freely, `write` needs the user's approval and `-AllowWrite`, `blocked` is never run by the agent (the user manages sign-in). Check full parameters with `Get-Help <cmdlet> -Full` through the wrapper.

| Cmdlet | Guard | Description |
| --- | --- | --- |
| Connect-XdrByBrowser | blocked | Authenticates to Microsoft Defender XDR using an interactive browser sign-in. |
| Connect-XdrByBrowserExtension | blocked | Authenticates to Microsoft Defender XDR by relaying a session from the XDR Docker Relay browser extension. |
| Connect-XdrByCredential | blocked | Authenticates to Microsoft Defender XDR using username, password, and optional TOTP MFA. |
| Connect-XdrByEstsCookie | blocked | Establishes an authenticated session to the Microsoft Defender XDR portal. |
| Connect-XdrByPhoneSignIn | blocked | Authenticates to Microsoft Defender XDR using Microsoft Authenticator phone sign-in. |
| Connect-XdrBySoftwarePasskey | blocked | Authenticates to Microsoft Defender XDR using a software passkey. |
| Connect-XdrBySSO | blocked | Authenticates to Microsoft Defender XDR using browser-based single sign-on. |
| Connect-XdrByTemporaryAccessPass | blocked | Authenticates to Microsoft Defender XDR using a Temporary Access Pass (TAP). |
| Connect-XdrEndpointDeviceLiveResponse | write | Opens a Live Response session to an endpoint device in Microsoft Defender XDR. |
| Disconnect-XdrEndpointDeviceLiveResponse | write | Closes an active Live Response session in Microsoft Defender XDR. |
| Export-XdrAzureDataExplorer | write | Exports pipeline data to Azure Data Explorer using queued ingestion. |
| Export-XdrToSentinel | write | Exports XDR data to a Microsoft Sentinel (Log Analytics) custom table. |
| Get-XdrActionsCenterHistory | read | Retrieves historical actions from the Microsoft Defender XDR Action Center. |
| Get-XdrActionsCenterPending | read | Retrieves pending actions from the Microsoft Defender XDR Action Center. |
| Get-XdrAdvancedHuntingFunction | read | Retrieves Advanced Hunting functions from Microsoft Defender XDR. |
| Get-XdrAdvancedHuntingTableSchema | read | Retrieves the Advanced Hunting table schema from Microsoft Defender XDR. |
| Get-XdrAdvancedHuntingUnifiedDetectionRules | read | Retrieves the Unified Detection Rules from Advanced Hunting. |
| Get-XdrAdvancedHuntingUserHistory | read | Retrieves Advanced Hunting user history from Microsoft Defender XDR. |
| Get-XdrAlert | read | Retrieves alerts from Microsoft Defender XDR. |
| Get-XdrAzureDataExplorerCluster | read | Discovers accessible Azure Data Explorer clusters and databases. |
| Get-XdrAzureDataExplorerIngestionStatus | read | Gets the status of queued Azure Data Explorer ingestion operations. |
| Get-XdrCloudAppsActivityTimeline | read | Retrieves Microsoft Defender for Cloud Apps activity timeline data. |
| Get-XdrCloudAppsApp | read | Retrieves app-focused Microsoft Defender for Cloud Apps data. |
| Get-XdrCloudAppsConfiguration | read | Retrieves grouped Microsoft Defender for Cloud Apps configuration data. |
| Get-XdrCloudAppsDiscovery | read | Retrieves Cloud Discovery data from Microsoft Defender for Cloud Apps. |
| Get-XdrCloudAppsGeneralSetting | read | Retrieves general settings from Microsoft Defender for Cloud Apps (Cloud Apps). |
| Get-XdrCloudAppsGovernance | read | Retrieves governance data from Microsoft Defender for Cloud Apps and App Governance. |
| Get-XdrCloudAppsPolicy | read | Retrieves policies from Microsoft Defender for Cloud Apps. |
| Get-XdrConfigurationAlertServiceSetting | read | Retrieves alert service settings from Microsoft Defender XDR. |
| Get-XdrConfigurationAlertTuning | read | Retrieves alert tuning configuration from Microsoft Defender XDR. |
| Get-XdrConfigurationAssetRuleManagement | read | Retrieves asset rule management configuration from Microsoft Defender XDR. |
| Get-XdrConfigurationCriticalAssetManagementClassification | read | Retrieves critical asset management classification rules from Microsoft Defender XDR. |
| Get-XdrConfigurationCriticalAssetManagementClassificationSchema | read | Retrieves the schema for Critical Asset Management rules from Microsoft Defender XDR. |
| Get-XdrConfigurationPreviewFeatures | read | Retrieves the configuration for Defender XDR Preview features. |
| Get-XdrConfigurationServiceAccountClassification | read | Retrieves service account classification rules from Microsoft Defender XDR. |
| Get-XdrConfigurationUnifiedRBACWorkload | read | Retrieves Unified RBAC workload configuration from Microsoft Defender XDR. |
| Get-XdrDatalakeDatabase | read | Retrieves databases from Microsoft Defender XDR datalake. |
| Get-XdrDatalakeTableSchema | read | Retrieves database entities schema from Microsoft Defender XDR datalake. |
| Get-XdrEndpointAdvancedFeatures | read | Retrieves comprehensive advanced features configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationAdvancedFeatures | read | Retrieves the advanced features configuration settings for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationAuthenticatedTelemetry | read | Retrieves the Authenticated Telemetry status for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationCustomCollectionRule | read | Retrieves custom collection rules for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationIntuneConnection | read | Retrieves the Intune connection status for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationLiveResponse | read | Retrieves the Live Response configuration settings for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationPotentiallyUnwantedApplications | read | Retrieves the potentially unwanted applications (PUA) configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationPreviewFeature | read | Retrieves the preview features configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationPurviewSharing | read | Retrieves the Purview alert sharing configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointDevice | read | Retrieves endpoint devices from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceActionResult | read | Gets device action results and download URIs from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceLiveResponseLibrary | read | Retrieves the Live Response library files from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceLiveResponseLibraryFile | read | Downloads a script file from the Live Response library. |
| Get-XdrEndpointDeviceModel | read | Retrieves all device models from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceOsVersionFriendlyName | read | Retrieves all OS version friendly names from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceRbacGroup | read | Retrieves device groups for Defender for Endpoint. |
| Get-XdrEndpointDeviceRbacGroupScope | read | Retrieves all RBAC groups from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceTag | read | Retrieves all device tags from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceTimeline | read | Retrieves the timeline of events for a specific device from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceTotals | read | Retrieves the device totals from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceVendor | read | Retrieves all device vendors from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceWindowsReleaseVersion | read | Retrieves all Windows release versions from Microsoft Defender for Endpoint. |
| Get-XdrEndpointLicenseReport | read | Retrieves license usage report for Microsoft Defender for Endpoint. |
| Get-XdrExposureManagementRecommendations | read | Retrieves recommendations from Exposure Management. |
| Get-XdrIdentityAlertThreshold | read | Retrieves alert threshold configuration for Microsoft Defender for Identity. |
| Get-XdrIdentityConfigurationDirectoryServiceAccount | read | Retrieves directory service accounts for Microsoft Defender for Identity. |
| Get-XdrIdentityConfigurationRemediationActionAccount | read | Retrieves the remediation action account configuration for Microsoft Defender for Identity. |
| Get-XdrIdentityDomainControllerCoverage | read | Retrieves domain controller coverage from Microsoft Defender for Identity. |
| Get-XdrIdentityIdentity | read | Retrieves identities from Microsoft Defender for Identity. |
| Get-XdrIdentityOnboardingStatus | read | Retrieves the onboarding status of Microsoft Defender for Identity. |
| Get-XdrIdentityServiceAccount | read | Retrieves service accounts from Microsoft Defender for Identity. |
| Get-XdrIdentityStatistic | read | Retrieves aggregated identity statistics from Microsoft Defender for Identity. |
| Get-XdrIdentityUser | read | Retrieves detailed user identity information from Microsoft Defender for Identity. |
| Get-XdrIdentityUserTimeline | read | Retrieves the timeline of events for a specific user from Microsoft Defender for Identity. |
| Get-XdrIncident | read | Retrieves incidents from Microsoft Defender XDR. |
| Get-XdrIncidentAssociatedAlert | read | Retrieves alerts associated with a specific incident from Microsoft Defender XDR. |
| Get-XdrMtoTenantList | read | Retrieves the list of accessible tenants from Microsoft Defender XDR. |
| Get-XdrStreamingApiConfiguration | read | Retrieves Streaming API configuration from Microsoft Defender XDR. |
| Get-XdrSuppressionRule | read | Retrieves alert suppression rules from Microsoft Defender XDR. |
| Get-XdrTenantContext | read | Retrieves the tenant context information from Microsoft Defender XDR. |
| Get-XdrTenantWorkloadStatus | read | Retrieves and evaluates the workload status from Microsoft Defender XDR tenant context. |
| Get-XdrThreatAnalyticsOutbreaks | read | Retrieves threat analytics outbreaks from Microsoft Defender XDR. |
| Get-XdrVulnerabilityManagementAdvisories | read | Retrieves security advisories from Vulnerability Management. |
| Get-XdrVulnerabilityManagementBaseline | read | Retrieves security baseline assessment data from Microsoft Defender XDR. |
| Get-XdrVulnerabilityManagementCertificates | read | Retrieves certificates from Vulnerability Management. |
| Get-XdrVulnerabilityManagementChangeEvents | read | Retrieves change events from Vulnerability Management. |
| Get-XdrVulnerabilityManagementDashboard | read | Retrieves Microsoft Defender Vulnerability Management dashboard analytics data. |
| Get-XdrVulnerabilityManagementExtensions | read | Retrieves browser extensions from Vulnerability Management. |
| Get-XdrVulnerabilityManagementProducts | read | Retrieves products from Vulnerability Management. |
| Get-XdrVulnerabilityManagementRemediationTasks | read | Retrieves remediation tasks from Vulnerability Management. |
| Get-XdrVulnerabilityManagementVulnerabilities | read | Retrieves vulnerabilities from Vulnerability Management. |
| Get-XdrXspmAttackPath | read | Retrieves attack path data from Microsoft Defender XDR XSPM. |
| Get-XdrXspmChokePoint | read | Retrieves choke point data from Microsoft Defender XDR XSPM. |
| Get-XdrXspmTopEntryPoint | read | Retrieves top entry points from Microsoft Defender XDR XSPM attack paths. |
| Get-XdrXspmTopTarget | read | Retrieves top targets from Microsoft Defender XDR XSPM attack paths. |
| Invoke-XdrAzureDataExplorerQuery | read | Executes a KQL query or management command against an Azure Data Explorer cluster. |
| Invoke-XdrEndpointDeviceAction | write | Invokes response actions on an endpoint device in Microsoft Defender XDR. |
| Invoke-XdrEndpointDeviceAutomatedInvestigation | write | Starts an automated investigation on an endpoint device in Microsoft Defender XDR. |
| Invoke-XdrEndpointDeviceLiveResponseCommand | write | Sends a command to an active Live Response session in Microsoft Defender XDR. |
| Invoke-XdrEndpointDevicePolicySync | write | Forces a policy sync on an endpoint device in Microsoft Defender XDR. |
| Invoke-XdrHuntingQueryValidation | read | Validates an Advanced Hunting query for custom detection rules in Microsoft Defender XDR. |
| Invoke-XdrAdvancedHunting | read | Runs a read-only Advanced Hunting query against the session's own tenant (direct mode). The wrapper routes direct-mode hunts here automatically. |
| Invoke-XdrMtoAdvancedHunting | read | Executes an Advanced Hunting query across multiple tenants in MTO (Multi-Tenant Organization). |
| Invoke-XdrRestMethod | read (GET only) | Invokes a REST API call to Microsoft Defender XDR with authenticated session. |
| Invoke-XdrXspmHuntingQuery | read | Executes a hunting query against the Microsoft Defender XDR XSPM attack surface API. |
| Merge-XdrIncident | write | Merges multiple incidents into a single incident in Microsoft Defender XDR. |
| Move-XdrAlertToIncident | write | Moves alerts to a specific incident or creates a new one. |
| New-XdrAdvancedHuntingFunction | write | Creates a new Advanced Hunting function in Microsoft Defender XDR. |
| New-XdrConfigurationCriticalAssetManagementClassification | write | Creates a new Critical Asset Management classification rule in Microsoft Defender XDR. |
| New-XdrEndpointConfigurationCustomCollectionRule | write | Creates a new custom collection rule for Microsoft Defender for Endpoint from a YAML file. |
| New-XdrEndpointDeviceLiveResponseLibraryFile | write | Uploads a script file to the Live Response library. |
| New-XdrEndpointDeviceRbacGroup | write | Creates a device group in Defender for Endpoint used for RBAC and policies. |
| New-XdrIdentityConfigurationRemediationActionAccount | write | Registers a new remediation action account for Microsoft Defender for Identity. |
| Remove-XdrAdvancedHuntingFunction | write | Removes an Advanced Hunting function from Microsoft Defender XDR. |
| Remove-XdrConfigurationCriticalAssetManagementClassification | write | Removes a Critical Asset Management classification rule from Microsoft Defender XDR. |
| Remove-XdrEndpointDeviceLiveResponseLibraryFile | write | Deletes a file from the Live Response library. |
| Remove-XdrIdentityConfigurationRemediationActionAccount | write | Removes a remediation action account from Microsoft Defender for Identity. |
| Set-XdrAdvancedHuntingFunction | write | Updates an existing Advanced Hunting function in Microsoft Defender XDR. |
| Set-XdrAzureDataExplorerConnection | write | Configures Azure Data Explorer connection settings for export cmdlets. |
| Set-XdrCloudAppsDiscoveredApp | write | Updates a discovered app note in Microsoft Defender for Cloud Apps. |
| Set-XdrConfigurationCriticalAssetManagementClassification | write | Updates critical asset management classification rule metadata in Microsoft Defender XDR. |
| Set-XdrConfigurationPreviewFeatures | write | Sets the configuration for Defender XDR Preview features. |
| Set-XdrConnectionSettings | blocked | Creates XDR connection settings using authentication cookies. |
| Set-XdrEndpointAdvancedFeatures | write | Configures advanced features settings for Microsoft Defender for Endpoint. |
| Set-XdrEndpointConfigurationCustomCollectionRule | write | Updates an existing custom collection rule for Microsoft Defender for Endpoint. |
| Set-XdrEndpointDeviceAssetValue | write | Sets the asset value on endpoint devices in Microsoft Defender XDR. |
| Set-XdrEndpointDeviceCriticalityLevel | write | Sets the criticality level on endpoint devices in Microsoft Defender XDR. |
| Set-XdrEndpointDeviceExclusionState | write | Sets the exclusion state on endpoint devices in Microsoft Defender XDR. |
| Set-XdrEndpointDeviceRbacGroup | write | Updates Defender for Endpoint device groups. |
| Set-XdrEndpointDeviceTag | write | Sets, adds, or removes user-defined tags on endpoint devices in Microsoft Defender XDR. |
| Set-XdrIdentityConfigurationRemediationActionAccount | write | Configures the remediation action account type for Microsoft Defender for Identity. |
| Set-XdrSentinelConnection | write | Configures the Sentinel (Log Analytics) workspace connection for data export. |
| Stop-XdrEndpointDeviceAction | write | Cancels a pending device action in Microsoft Defender XDR. |
| Update-XdrConnectionSettings | blocked | Updates XDR connection session cookies and authentication tokens. |
