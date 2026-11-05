function Invoke-XdrAdvancedHunting {
    <#
    .SYNOPSIS
        Runs a read-only Advanced Hunting query against the session's own tenant (direct mode).

    .DESCRIPTION
        Posts the query to the same single-tenant endpoint the Defender portal uses
        (security.microsoft.com/apiproxy/hunting/huntingQueryExecutorService/queryExecutor/v1/external).
        It does not go through mto.security.microsoft.com, so it keeps working when the MTO session
        times out (HTTP 440) while the portal session is still valid. It only ever queries the tenant
        the session is signed in to, and stops if -TenantId is not that tenant.

    .PARAMETER QueryText
        The KQL query.

    .PARAMETER TenantId
        The tenant the caller expects. The call stops if the session tenant differs.

    .PARAMETER DaysAgo
        Look-back in days (default 30). Ignored when -StartTime is given.

    .PARAMETER StartTime
        Window start (UTC).

    .PARAMETER EndTime
        Window end (UTC, default now).

    .PARAMETER MaxRecordCount
        Row cap (default 100000).

    .EXAMPLE
        Invoke-XdrAdvancedHunting -TenantId 'ce37246c-a47b-4e72-ac75-1f10b15a9379' -QueryText 'DeviceInfo | take 5'
    #>
    [CmdletBinding(DefaultParameterSetName = 'DaysAgo')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$QueryText,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'DaysAgo')]
        [int]$DaysAgo = 30,

        [Parameter(ParameterSetName = 'CustomTime', Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter()]
        [datetime]$EndTime = (Get-Date),

        [Parameter()]
        [int]$MaxRecordCount = 100000
    )

    process {
        $sessionTenant = (Get-XdrCache -CacheKey "XdrTenantId" -ErrorAction SilentlyContinue).Value
        if (-not $sessionTenant) {
            $sessionTenant = (Get-XdrTenantContext -Force).AuthInfo.TenantId
        }
        if ($sessionTenant -ne $TenantId) {
            throw "Invoke-XdrAdvancedHunting: the session is signed in to $sessionTenant, not $TenantId. Direct hunting only queries the session's own tenant."
        }

        $start = if ($PSCmdlet.ParameterSetName -eq 'CustomTime') { $StartTime } else { $EndTime.AddDays(-$DaysAgo) }
        $body = [ordered]@{
            QueryText          = $QueryText
            EncodedQueryText   = $QueryText
            StartTime          = $start.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            EndTime            = $EndTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            MaxRecordCount     = $MaxRecordCount
            TenantIds          = $null
            selectedWorkspaces = @{}
            QueryOrigin        = "User"
        }
        $bodyJson = $body | ConvertTo-Json -Depth 10 -Compress

        $customHeaders = $script:headers.Clone()
        $customHeaders["m-package"] = "hunting"
        $customHeaders["m-componentname"] = "createHuntingUsxMsecHost"
        $Uri = "https://security.microsoft.com/apiproxy/hunting/huntingQueryExecutorService/queryExecutor/v1/external?useFanOut=false"

        try {
            $response = Invoke-RestMethod -ContentType "application/json" -Uri $Uri -Method Post -Body $bodyJson -Headers $customHeaders -WebSession $script:session
            Set-XdrConnectionSettings -ResetWebSession
        } catch {
            Write-Error "Failed to execute Advanced Hunting query: $_"
            return
        }

        $result = if ($response.result) { $response.result } else { $response }
        if (-not $result.Results -or $result.Results.Count -eq 0) {
            Write-Verbose "No results in response"
            return $null
        }
        foreach ($row in $result.Results) {
            $props = [ordered]@{}
            foreach ($col in $result.Schema) { $props[$col.Name] = $row.($col.Name) }
            [PSCustomObject]$props
        }
    }
}
