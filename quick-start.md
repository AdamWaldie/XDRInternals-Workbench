docker compose run --rm --service-ports xdrinternals


Connect-XdrByBrowserExtension

Get-XdrTenantContext 

Invoke-XdrMtoAdvancedHunting -QueryText "WindowsEvent | summarize Rows = count()" -DaysAgo 30
