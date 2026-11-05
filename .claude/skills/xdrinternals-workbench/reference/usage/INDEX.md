# XDRInternals usage index

Generated from the module's comment-based help by `tools/agent/Build-XdrUsageIndex.ps1`. Regenerate after any module change. Guard matches `tools/agent/Invoke-XdrAgent.ps1`: `read` runs freely, `write` needs the user's approval for that specific action and `-AllowWrite`, `blocked` is user-only (sign-in and connection settings).

| Cmdlet | Guard | File | Synopsis |
| --- | --- | --- | --- |
| Connect-XdrByBrowser | blocked | usage/session-tenant.md | Authenticates to Microsoft Defender XDR using an interactive browser sign-in. |
| Connect-XdrByBrowserExtension | blocked | usage/session-tenant.md | Authenticates to Microsoft Defender XDR by relaying a session from the XDR Docker Relay browser extension. |
| Connect-XdrByCredential | blocked | usage/session-tenant.md | Authenticates to Microsoft Defender XDR using username, password, and optional TOTP MFA. |
| Connect-XdrByEstsCookie | blocked | usage/session-tenant.md | Establishes an authenticated session to the Microsoft Defender XDR portal. |
| Connect-XdrByPhoneSignIn | blocked | usage/session-tenant.md | Authenticates to Microsoft Defender XDR using Microsoft Authenticator phone sign-in. |
| Connect-XdrBySoftwarePasskey | blocked | usage/session-tenant.md | Authenticates to Microsoft Defender XDR using a software passkey. |
| Connect-XdrBySSO | blocked | usage/session-tenant.md | Authenticates to Microsoft Defender XDR using browser-based single sign-on. |
| Connect-XdrByTemporaryAccessPass | blocked | usage/session-tenant.md | Authenticates to Microsoft Defender XDR using a Temporary Access Pass (TAP). |
| Get-XdrMtoTenantList | read | usage/session-tenant.md | Retrieves the list of accessible tenants from Microsoft Defender XDR. |
| Get-XdrTenantContext | read | usage/session-tenant.md | Retrieves the tenant context information from Microsoft Defender XDR. |
| Get-XdrTenantWorkloadStatus | read | usage/session-tenant.md | Retrieves and evaluates the workload status from Microsoft Defender XDR tenant context. |
| Set-XdrConnectionSettings | blocked | usage/session-tenant.md | Creates XDR connection settings using authentication cookies. |
| Update-XdrConnectionSettings | blocked | usage/session-tenant.md | Updates XDR connection session cookies and authentication tokens. |
| ConvertTo-XdrEncodedAdvancedHuntingQuery | read | usage/hunting.md | Encodes an Advanced Hunting query for use in Microsoft Defender XDR. |
| Get-XdrAdvancedHuntingFunction | read | usage/hunting.md | Retrieves Advanced Hunting functions from Microsoft Defender XDR. |
| Get-XdrAdvancedHuntingTableSchema | read | usage/hunting.md | Retrieves the Advanced Hunting table schema from Microsoft Defender XDR. |
| Get-XdrAdvancedHuntingUnifiedDetectionRules | read | usage/hunting.md | Retrieves the Unified Detection Rules from Advanced Hunting. |
| Get-XdrAdvancedHuntingUserHistory | read | usage/hunting.md | Retrieves Advanced Hunting user history from Microsoft Defender XDR. |
| Get-XdrDatalakeDatabase | read | usage/hunting.md | Retrieves databases from Microsoft Defender XDR datalake. |
| Get-XdrDatalakeTableSchema | read | usage/hunting.md | Retrieves database entities schema from Microsoft Defender XDR datalake. |
| Invoke-XdrAdvancedHunting | read | usage/hunting.md | Runs a read-only Advanced Hunting query against the session's own tenant (direct mode). |
| Invoke-XdrHuntingQueryValidation | read | usage/hunting.md | Validates an Advanced Hunting query for custom detection rules in Microsoft Defender XDR. |
| Invoke-XdrMtoAdvancedHunting | read | usage/hunting.md | Executes an Advanced Hunting query across multiple tenants in MTO (Multi-Tenant Organization). |
| Invoke-XdrXspmHuntingQuery | read | usage/hunting.md | Executes a hunting query against the Microsoft Defender XDR XSPM attack surface API. |
| New-XdrAdvancedHuntingFunction | write | usage/hunting.md | Creates a new Advanced Hunting function in Microsoft Defender XDR. |
| Remove-XdrAdvancedHuntingFunction | write | usage/hunting.md | Removes an Advanced Hunting function from Microsoft Defender XDR. |
| Set-XdrAdvancedHuntingFunction | write | usage/hunting.md | Updates an existing Advanced Hunting function in Microsoft Defender XDR. |
| Get-XdrAlert | read | usage/incidents-alerts.md | Retrieves alerts from Microsoft Defender XDR. |
| Get-XdrIncident | read | usage/incidents-alerts.md | Retrieves incidents from Microsoft Defender XDR. |
| Get-XdrIncidentAssociatedAlert | read | usage/incidents-alerts.md | Retrieves alerts associated with a specific incident from Microsoft Defender XDR. |
| Get-XdrSuppressionRule | read | usage/incidents-alerts.md | Retrieves alert suppression rules from Microsoft Defender XDR. |
| Get-XdrThreatAnalyticsOutbreaks | read | usage/incidents-alerts.md | Retrieves threat analytics outbreaks from Microsoft Defender XDR. |
| Merge-XdrIncident | write | usage/incidents-alerts.md | Merges multiple incidents into a single incident in Microsoft Defender XDR. |
| Move-XdrAlertToIncident | write | usage/incidents-alerts.md | Moves alerts to a specific incident or creates a new one. |
| Connect-XdrEndpointDeviceLiveResponse | write | usage/endpoint-response.md | Opens a Live Response session to an endpoint device in Microsoft Defender XDR. |
| Disconnect-XdrEndpointDeviceLiveResponse | write | usage/endpoint-response.md | Closes an active Live Response session in Microsoft Defender XDR. |
| Get-XdrActionsCenterHistory | read | usage/endpoint-response.md | Retrieves historical actions from the Microsoft Defender XDR Action Center. |
| Get-XdrActionsCenterPending | read | usage/endpoint-response.md | Retrieves pending actions from the Microsoft Defender XDR Action Center. |
| Get-XdrEndpointDevice | read | usage/endpoint-response.md | Retrieves endpoint devices from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceActionResult | read | usage/endpoint-response.md | Gets device action results and download URIs from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceLiveResponseLibrary | read | usage/endpoint-response.md | Retrieves the Live Response library files from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceLiveResponseLibraryFile | read | usage/endpoint-response.md | Downloads a script file from the Live Response library. |
| Get-XdrEndpointDeviceModel | read | usage/endpoint-response.md | Retrieves all device models from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceOsVersionFriendlyName | read | usage/endpoint-response.md | Retrieves all OS version friendly names from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceRbacGroup | read | usage/endpoint-response.md | Retrieves device groups for Defender for Endpoint. |
| Get-XdrEndpointDeviceRbacGroupScope | read | usage/endpoint-response.md | Retrieves all RBAC groups from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceTag | read | usage/endpoint-response.md | Retrieves all device tags from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceTimeline | read | usage/endpoint-response.md | Retrieves the timeline of events for a specific device from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceTotals | read | usage/endpoint-response.md | Retrieves the device totals from Microsoft Defender XDR. |
| Get-XdrEndpointDeviceVendor | read | usage/endpoint-response.md | Retrieves all device vendors from Microsoft Defender for Endpoint. |
| Get-XdrEndpointDeviceWindowsReleaseVersion | read | usage/endpoint-response.md | Retrieves all Windows release versions from Microsoft Defender for Endpoint. |
| Invoke-XdrEndpointDeviceAction | write | usage/endpoint-response.md | Invokes response actions on an endpoint device in Microsoft Defender XDR. |
| Invoke-XdrEndpointDeviceAutomatedInvestigation | write | usage/endpoint-response.md | Starts an automated investigation on an endpoint device in Microsoft Defender XDR. |
| Invoke-XdrEndpointDeviceLiveResponseCommand | write | usage/endpoint-response.md | Sends a command to an active Live Response session in Microsoft Defender XDR. |
| Invoke-XdrEndpointDevicePolicySync | write | usage/endpoint-response.md | Forces a policy sync on an endpoint device in Microsoft Defender XDR. |
| New-XdrEndpointDeviceLiveResponseLibraryFile | write | usage/endpoint-response.md | Uploads a script file to the Live Response library. |
| New-XdrEndpointDeviceRbacGroup | write | usage/endpoint-response.md | Creates a device group in Defender for Endpoint used for RBAC and policies. |
| Remove-XdrEndpointDeviceLiveResponseLibraryFile | write | usage/endpoint-response.md | Deletes a file from the Live Response library. |
| Set-XdrEndpointDeviceAssetValue | write | usage/endpoint-response.md | Sets the asset value on endpoint devices in Microsoft Defender XDR. |
| Set-XdrEndpointDeviceCriticalityLevel | write | usage/endpoint-response.md | Sets the criticality level on endpoint devices in Microsoft Defender XDR. |
| Set-XdrEndpointDeviceExclusionState | write | usage/endpoint-response.md | Sets the exclusion state on endpoint devices in Microsoft Defender XDR. |
| Set-XdrEndpointDeviceRbacGroup | write | usage/endpoint-response.md | Updates Defender for Endpoint device groups. |
| Set-XdrEndpointDeviceTag | write | usage/endpoint-response.md | Sets, adds, or removes user-defined tags on endpoint devices in Microsoft Defender XDR. |
| Stop-XdrEndpointDeviceAction | write | usage/endpoint-response.md | Cancels a pending device action in Microsoft Defender XDR. |
| Get-XdrEndpointAdvancedFeatures | read | usage/endpoint-config.md | Retrieves comprehensive advanced features configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationAdvancedFeatures | read | usage/endpoint-config.md | Retrieves the advanced features configuration settings for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationAuthenticatedTelemetry | read | usage/endpoint-config.md | Retrieves the Authenticated Telemetry status for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationCustomCollectionRule | read | usage/endpoint-config.md | Retrieves custom collection rules for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationIntuneConnection | read | usage/endpoint-config.md | Retrieves the Intune connection status for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationLiveResponse | read | usage/endpoint-config.md | Retrieves the Live Response configuration settings for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationOptionalFeatures | read | usage/endpoint-config.md | Retrieves the advanced features configuration settings for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationPotentiallyUnwantedApplications | read | usage/endpoint-config.md | Retrieves the potentially unwanted applications (PUA) configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationPreviewFeature | read | usage/endpoint-config.md | Retrieves the preview features configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointConfigurationPurviewSharing | read | usage/endpoint-config.md | Retrieves the Purview alert sharing configuration for Microsoft Defender for Endpoint. |
| Get-XdrEndpointLicenseReport | read | usage/endpoint-config.md | Retrieves license usage report for Microsoft Defender for Endpoint. |
| New-XdrEndpointConfigurationCustomCollectionRule | write | usage/endpoint-config.md | Creates a new custom collection rule for Microsoft Defender for Endpoint from a YAML file. |
| Set-XdrEndpointAdvancedFeatures | write | usage/endpoint-config.md | Configures advanced features settings for Microsoft Defender for Endpoint. |
| Set-XdrEndpointConfigurationCustomCollectionRule | write | usage/endpoint-config.md | Updates an existing custom collection rule for Microsoft Defender for Endpoint. |
| Get-XdrIdentityAlertThreshold | read | usage/identity.md | Retrieves alert threshold configuration for Microsoft Defender for Identity. |
| Get-XdrIdentityConfigurationDirectoryServiceAccount | read | usage/identity.md | Retrieves directory service accounts for Microsoft Defender for Identity. |
| Get-XdrIdentityConfigurationRemediationActionAccount | read | usage/identity.md | Retrieves the remediation action account configuration for Microsoft Defender for Identity. |
| Get-XdrIdentityDomainControllerCoverage | read | usage/identity.md | Retrieves domain controller coverage from Microsoft Defender for Identity. |
| Get-XdrIdentityIdentity | read | usage/identity.md | Retrieves identities from Microsoft Defender for Identity. |
| Get-XdrIdentityOnboardingStatus | read | usage/identity.md | Retrieves the onboarding status of Microsoft Defender for Identity. |
| Get-XdrIdentityServiceAccount | read | usage/identity.md | Retrieves service accounts from Microsoft Defender for Identity. |
| Get-XdrIdentityStatistic | read | usage/identity.md | Retrieves aggregated identity statistics from Microsoft Defender for Identity. |
| Get-XdrIdentityUser | read | usage/identity.md | Retrieves detailed user identity information from Microsoft Defender for Identity. |
| Get-XdrIdentityUserTimeline | read | usage/identity.md | Retrieves the timeline of events for a specific user from Microsoft Defender for Identity. |
| New-XdrIdentityConfigurationRemediationActionAccount | write | usage/identity.md | Registers a new remediation action account for Microsoft Defender for Identity. |
| Remove-XdrIdentityConfigurationRemediationActionAccount | write | usage/identity.md | Removes a remediation action account from Microsoft Defender for Identity. |
| Set-XdrIdentityConfigurationRemediationActionAccount | write | usage/identity.md | Configures the remediation action account type for Microsoft Defender for Identity. |
| Get-XdrCloudAppsActivityTimeline | read | usage/cloud-apps.md | Retrieves Microsoft Defender for Cloud Apps activity timeline data. |
| Get-XdrCloudAppsApp | read | usage/cloud-apps.md | Retrieves app-focused Microsoft Defender for Cloud Apps data. |
| Get-XdrCloudAppsConfiguration | read | usage/cloud-apps.md | Retrieves grouped Microsoft Defender for Cloud Apps configuration data. |
| Get-XdrCloudAppsDiscovery | read | usage/cloud-apps.md | Retrieves Cloud Discovery data from Microsoft Defender for Cloud Apps. |
| Get-XdrCloudAppsGeneralSetting | read | usage/cloud-apps.md | Retrieves general settings from Microsoft Defender for Cloud Apps (Cloud Apps). |
| Get-XdrCloudAppsGovernance | read | usage/cloud-apps.md | Retrieves governance data from Microsoft Defender for Cloud Apps and App Governance. |
| Get-XdrCloudAppsPolicy | read | usage/cloud-apps.md | Retrieves policies from Microsoft Defender for Cloud Apps. |
| Set-XdrCloudAppsDiscoveredApp | write | usage/cloud-apps.md | Updates a discovered app note in Microsoft Defender for Cloud Apps. |
| Get-XdrExposureManagementRecommendations | read | usage/exposure-vuln.md | Retrieves recommendations from Exposure Management. |
| Get-XdrVulnerabilityManagementAdvisories | read | usage/exposure-vuln.md | Retrieves security advisories from Vulnerability Management. |
| Get-XdrVulnerabilityManagementBaseline | read | usage/exposure-vuln.md | Retrieves security baseline assessment data from Microsoft Defender XDR. |
| Get-XdrVulnerabilityManagementCertificates | read | usage/exposure-vuln.md | Retrieves certificates from Vulnerability Management. |
| Get-XdrVulnerabilityManagementChangeEvents | read | usage/exposure-vuln.md | Retrieves change events from Vulnerability Management. |
| Get-XdrVulnerabilityManagementDashboard | read | usage/exposure-vuln.md | Retrieves Microsoft Defender Vulnerability Management dashboard analytics data. |
| Get-XdrVulnerabilityManagementExtensions | read | usage/exposure-vuln.md | Retrieves browser extensions from Vulnerability Management. |
| Get-XdrVulnerabilityManagementProducts | read | usage/exposure-vuln.md | Retrieves products from Vulnerability Management. |
| Get-XdrVulnerabilityManagementRemediationTasks | read | usage/exposure-vuln.md | Retrieves remediation tasks from Vulnerability Management. |
| Get-XdrVulnerabilityManagementVulnerabilities | read | usage/exposure-vuln.md | Retrieves vulnerabilities from Vulnerability Management. |
| Get-XdrXspmAttackPath | read | usage/exposure-vuln.md | Retrieves attack path data from Microsoft Defender XDR XSPM. |
| Get-XdrXspmChokePoint | read | usage/exposure-vuln.md | Retrieves choke point data from Microsoft Defender XDR XSPM. |
| Get-XdrXspmTopEntryPoint | read | usage/exposure-vuln.md | Retrieves top entry points from Microsoft Defender XDR XSPM attack paths. |
| Get-XdrXspmTopTarget | read | usage/exposure-vuln.md | Retrieves top targets from Microsoft Defender XDR XSPM attack paths. |
| Get-XdrConfigurationAlertServiceSetting | read | usage/portal-config.md | Retrieves alert service settings from Microsoft Defender XDR. |
| Get-XdrConfigurationAlertTuning | read | usage/portal-config.md | Retrieves alert tuning configuration from Microsoft Defender XDR. |
| Get-XdrConfigurationAssetRuleManagement | read | usage/portal-config.md | Retrieves asset rule management configuration from Microsoft Defender XDR. |
| Get-XdrConfigurationCriticalAssetManagementClassification | read | usage/portal-config.md | Retrieves critical asset management classification rules from Microsoft Defender XDR. |
| Get-XdrConfigurationCriticalAssetManagementClassificationSchema | read | usage/portal-config.md | Retrieves the schema for Critical Asset Management rules from Microsoft Defender XDR. |
| Get-XdrConfigurationPreviewFeatures | read | usage/portal-config.md | Retrieves the configuration for Defender XDR Preview features. |
| Get-XdrConfigurationServiceAccountClassification | read | usage/portal-config.md | Retrieves service account classification rules from Microsoft Defender XDR. |
| Get-XdrConfigurationUnifiedRBACWorkload | read | usage/portal-config.md | Retrieves Unified RBAC workload configuration from Microsoft Defender XDR. |
| Get-XdrStreamingApiConfiguration | read | usage/portal-config.md | Retrieves Streaming API configuration from Microsoft Defender XDR. |
| New-XdrConfigurationCriticalAssetManagementClassification | write | usage/portal-config.md | Creates a new Critical Asset Management classification rule in Microsoft Defender XDR. |
| Remove-XdrConfigurationCriticalAssetManagementClassification | write | usage/portal-config.md | Removes a Critical Asset Management classification rule from Microsoft Defender XDR. |
| Set-XdrConfigurationCriticalAssetManagementClassification | write | usage/portal-config.md | Updates critical asset management classification rule metadata in Microsoft Defender XDR. |
| Set-XdrConfigurationPreviewFeatures | write | usage/portal-config.md | Sets the configuration for Defender XDR Preview features. |
| Export-XdrAzureDataExplorer | write | usage/export-integration.md | Exports pipeline data to Azure Data Explorer using queued ingestion. |
| Export-XdrToSentinel | write | usage/export-integration.md | Exports XDR data to a Microsoft Sentinel (Log Analytics) custom table. |
| Get-XdrAzureDataExplorerCluster | read | usage/export-integration.md | Discovers accessible Azure Data Explorer clusters and databases. |
| Get-XdrAzureDataExplorerIngestionStatus | read | usage/export-integration.md | Gets the status of queued Azure Data Explorer ingestion operations. |
| Invoke-XdrAzureDataExplorerQuery | read | usage/export-integration.md | Executes a KQL query or management command against an Azure Data Explorer cluster. |
| Set-XdrAzureDataExplorerConnection | write | usage/export-integration.md | Configures Azure Data Explorer connection settings for export cmdlets. |
| Set-XdrSentinelConnection | write | usage/export-integration.md | Configures the Sentinel (Log Analytics) workspace connection for data export. |
| Invoke-XdrRestMethod | read (GET only) | usage/raw-api.md | Invokes a REST API call to Microsoft Defender XDR with authenticated session. |
