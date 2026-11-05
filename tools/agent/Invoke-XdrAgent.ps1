<#
    .SYNOPSIS
        Runs XDRInternals commands for Claude against the session saved by Save-XdrAgentSession.ps1.

    .DESCRIPTION
        Each call starts a fresh PowerShell process. The script imports the module, restores
        the saved portal session, runs the PowerShell you pass, and prints the results as JSON
        on stdout. Write-Host output, warnings and errors go to stderr, so stdout stays
        parseable.

        Before it runs anything, the script checks the command against a write guard. It
        refuses any XDR cmdlet that changes tenant state (New-, Set-, Remove-, Merge-, Move-,
        Stop-, Update-, Export-, Disconnect-, device response actions, Live Response, and
        non-GET Invoke-XdrRestMethod), plus dynamic invocation, unless you pass -AllowWrite.
        Connect-Xdr* and connection-setting cmdlets are always refused, because the user
        manages the session. The guard catches mistakes; it isn't a sandbox.

        Exit codes: 0 ok, 1 the command threw, 2 non-terminating errors (partial results),
        3 refused by the write guard, 4 no or stale session, 5 tenant mismatch, 7 tenant guard,
        6 not PowerShell 7 (4 also when the portal answers 440 to a non-hunting call), 8 hunt session timeout (HTTP 440 from a hunting endpoint while the
        portal session still works; see .claude/skills/xdrinternals/reference/hunting-outage.md).

    .PARAMETER Command
        PowerShell to run, e.g. "Get-XdrIncident -IncidentId 123".

    .PARAMETER CommandFile
        Path to a .ps1 file to run instead of -Command. Easier for multi-line scripts and
        KQL, because nothing has to survive shell quoting.

    .PARAMETER ExpectTenantId
        Refuse to run unless the saved session belongs to this tenant ID.

    .PARAMETER AllowWrite
        Lets state-changing cmdlets through the guard. Only pass this after the user has
        approved that specific action.

    .PARAMETER OutFile
        Writes the full JSON result to this file and prints only a summary to stdout. Use it
        for timelines and other large results.

    .PARAMETER MaxItems
        Maximum number of result items printed to stdout. Defaults to 100. Ignored with
        -OutFile.

    .PARAMETER Depth
        JSON serialization depth. Defaults to 8.

    .PARAMETER Format
        Json (default), Table or List.

    .PARAMETER SessionPath
        Session file written by Save-XdrAgentSession.ps1. Defaults to $env:XDR_SESSION_PATH,
        then <repo>/.xdr-agent/session.json if it exists (for Cowork, which only sees the
        shared folder), then ~/.xdr-agent/session.json.

    .PARAMETER MaxSessionAgeHours
        Refuse a saved session older than this. Defaults to 12.

    .PARAMETER CaseTenantId
        Locks hunting to one customer: every Invoke-XdrMtoAdvancedHunting call must name exactly
        this tenant in -TenantIds. Defaults to $env:XDR_CASE_TENANT_ID, then to the case tenant
        Start-XdrWorkbench.ps1 recorded in <repo>/.xdr-agent/case.json (skipped when
        -AllowMultiTenant is passed). The session tenant (-ExpectTenantId) can differ when the case tenant is reached
        through MTO.

    .PARAMETER AllowMultiTenant
        Allows a hunt that names more than one tenant (an estate sweep the user asked for). Not
        combinable with -CaseTenantId. Split the output per tenant with Split-XdrMtoResult.ps1.

    .NOTES
        Tenant guard: every hunt must name its tenants; without -AllowMultiTenant it may name only
        one; with -CaseTenantId it must name exactly that one. Any hunt row whose TenantId wasn't
        named discards the whole result with exit code 7.

    .EXAMPLE
        pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -Command "Get-XdrTenantContext -Force"

    .EXAMPLE
        pwsh -NoProfile -File tools/agent/Invoke-XdrAgent.ps1 -CommandFile ./q.ps1 -OutFile ./investigations/x/timeline.json
#>
[CmdletBinding(DefaultParameterSetName = 'Command')]
param (
    [Parameter(Mandatory, ParameterSetName = 'Command', Position = 0)]
    [string]$Command,

    [Parameter(Mandatory, ParameterSetName = 'File')]
    [string]$CommandFile,

    [string]$ExpectTenantId,

    [switch]$AllowWrite,

    [string]$OutFile,

    [int]$MaxItems = 100,

    [int]$Depth = 8,

    [ValidateSet('Json', 'Table', 'List')]
    [string]$Format = 'Json',

    [string]$SessionPath,

    [double]$MaxSessionAgeHours = 12,

    [string]$CaseTenantId = $env:XDR_CASE_TENANT_ID,

    [switch]$AllowMultiTenant
)

$ErrorActionPreference = 'Stop'

function Write-Stderr {
    param ([string]$Message)
    [Console]::Error.WriteLine($Message)
}

function Test-XdrAgentCommand {
    # Returns the reasons a command is refused; empty means it may run.
    param ([string]$Code, [bool]$WriteAllowed)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        return @("Command doesn't parse: $($parseErrors[0].Message)")
    }

    $reasons = @()
    $commandAsts = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($commandAst in $commandAsts) {
        $name = $commandAst.GetCommandName()

        if (-not $name) {
            if (-not $WriteAllowed) { $reasons += "Dynamic invocation ('$($commandAst.Extent.Text)') can't be checked by the write guard." }
            continue
        }
        if ($name -match '^(Connect-Xdr(By|Auth)|Set-XdrConnectionSettings$|Update-XdrConnectionSettings$)') {
            $reasons += "$name changes the session. The user manages sign-in; ask them to reconnect and rerun Save-XdrAgentSession.ps1."
            continue
        }
        if ($name -eq 'Invoke-XdrMtoAdvancedHunting') {
            # The cmdlet picks its target tenant(s) from the module cache when -TenantIds is absent.
            # Make every hunt name its tenant. A splatted hashtable can't be inspected, so it passes.
            $named = @($commandAst.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName.Length -ge 2 -and 'TenantIds'.StartsWith($_.ParameterName, 'OrdinalIgnoreCase') })
            $splat = @($commandAst.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.VariableExpressionAst] -and $_.Splatted })
            if (-not $named -and -not $splat) {
                $reasons += "Invoke-XdrMtoAdvancedHunting needs -TenantIds naming the case tenant. Without it the target comes from the module cache."
            }
        }
        if ($WriteAllowed) { continue }

        if ($name -match '^(Invoke-Expression|iex)$') {
            $reasons += "$name can't be checked by the write guard."
        } elseif ($name -match '^(New|Set|Remove|Merge|Move|Stop|Update|Export|Disconnect|Connect)-Xdr' -or $name -match '^Invoke-XdrEndpointDevice') {
            $reasons += "$name changes tenant state or runs a response action. It needs the user's approval and -AllowWrite."
        } elseif ($name -eq 'Invoke-XdrRestMethod') {
            $elements = $commandAst.CommandElements
            for ($i = 1; $i -lt $elements.Count; $i++) {
                $element = $elements[$i]
                if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and 'Method'.StartsWith($element.ParameterName, 'OrdinalIgnoreCase')) {
                    $value = if ($element.Argument) { $element.Argument } elseif ($i + 1 -lt $elements.Count) { $elements[$i + 1] } else { $null }
                    $methodText = if ($value -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $value.Value } elseif ($value) { $value.Extent.Text } else { '' }
                    if ($methodText -notmatch "^['`"]?get['`"]?$") {
                        $reasons += "Invoke-XdrRestMethod -Method $methodText may change tenant state. It needs the user's approval and -AllowWrite."
                    }
                }
            }
        }
    }
    return $reasons
}

# Load the command
if ($PSCmdlet.ParameterSetName -eq 'File') {
    $Command = Get-Content -LiteralPath $CommandFile -Raw
}

$refusals = @(Test-XdrAgentCommand -Code $Command -WriteAllowed $AllowWrite.IsPresent)
if ($refusals.Count -gt 0) {
    Write-Stderr "REFUSED by the XDR agent write guard:"
    foreach ($reason in $refusals) { Write-Stderr "  - $reason" }
    exit 3
}

# Load the saved session
if (-not $SessionPath) {
    $repoSessionPath = Join-Path $PSScriptRoot '../../.xdr-agent/session.json'
    $SessionPath = if ($env:XDR_SESSION_PATH) { $env:XDR_SESSION_PATH }
    elseif (Test-Path -LiteralPath $repoSessionPath) { $repoSessionPath }
    else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.xdr-agent/session.json' }
}
if (-not (Test-Path -LiteralPath $SessionPath)) {
    Write-Stderr "NO SESSION: $SessionPath doesn't exist. Ask the user to connect (e.g. Connect-XdrByBrowserExtension) and then run tools/agent/Save-XdrAgentSession.ps1 in the same PowerShell session."
    exit 4
}
$saved = Get-Content -LiteralPath $SessionPath -Raw | ConvertFrom-Json
if (-not $saved -or -not $saved.SccAuth -or -not $saved.SavedAt) {
    Write-Stderr "NO SESSION: $SessionPath holds no session (cleared). Run the standup again."
    exit 4
}
$savedAt = [datetime]::Parse($saved.SavedAt, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
$ageHours = ((Get-Date).ToUniversalTime() - $savedAt.ToUniversalTime()).TotalHours
if ($ageHours -gt $MaxSessionAgeHours) {
    Write-Stderr ("STALE SESSION: saved {0:N1} hours ago (limit {1}). Ask the user to reconnect and rerun Save-XdrAgentSession.ps1." -f $ageHours, $MaxSessionAgeHours)
    exit 4
}
if ($ExpectTenantId -and $saved.TenantId -ne $ExpectTenantId) {
    Write-Stderr "TENANT MISMATCH: the saved session is for '$($saved.TenantName)' ($($saved.TenantId)), not $ExpectTenantId. Stop and confirm the tenant with the user."
    exit 5
}
Write-Stderr "[xdr-agent] Tenant: $($saved.TenantName) | $($saved.TenantId) | as $($saved.Account)"

# The module uses PowerShell 7 syntax (a 7.3 clean {} block, ForEach-Object -Parallel) and
# doesn't parse under Windows PowerShell 5.1.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Stderr "WRONG POWERSHELL: XDRInternals needs PowerShell 7 (pwsh). This is $($PSVersionTable.PSVersion). Run the wrapper with pwsh, e.g. in the Docker container."
    exit 6
}

# Import the module, preferring this checkout's copy
$repoManifest = Join-Path $PSScriptRoot '../../XDRInternals/XDRInternals.psd1'
if (Test-Path -LiteralPath $repoManifest) {
    Import-Module $repoManifest -Force -WarningAction SilentlyContinue
} else {
    Import-Module XDRInternals -WarningAction SilentlyContinue
}
Set-XdrConnectionSettings -SccAuth $saved.SccAuth -Xsrf $saved.Xsrf -TenantId $saved.TenantId 6>$null
# The multi-tenant portal keeps its own sign-in; restore it when the relay carried one.
$module = Get-Module XDRInternals
$savedMtoSccAuth = if ($saved.PSObject.Properties['MtoSccAuth']) { $saved.MtoSccAuth } else { $null }
$savedMtoXsrf = if ($saved.PSObject.Properties['MtoXsrf']) { $saved.MtoXsrf } else { $null }
& $module { param($s, $x) Initialize-XdrMtoSession -SccAuth $s -Xsrf $x } $savedMtoSccAuth $savedMtoXsrf

# Case lock default: the tenant the standup recorded, unless this call is an explicit estate sweep.
$caseFile = Join-Path $PSScriptRoot '../../.xdr-agent/case.json'
if (-not $CaseTenantId -and -not $AllowMultiTenant -and (Test-Path -LiteralPath $caseFile)) {
    try {
        $case = Get-Content -LiteralPath $caseFile -Raw | ConvertFrom-Json
        if ($case.CaseTenantId) { $CaseTenantId = $case.CaseTenantId }
    } catch { Write-Stderr "[warning] Couldn't read $caseFile; no default case lock." }
}
if ($CaseTenantId) { Write-Stderr "[xdr-agent] Case lock: hunts limited to $CaseTenantId" }
# When the case tenant is reached through MTO, every non-hunting cmdlet would answer for the
# session's own tenant, which is a different customer. Allow only hunting and tenant metadata.
if ($CaseTenantId -and $CaseTenantId -ne $saved.TenantId) {
    $mtoSafe = '^(Invoke-XdrMtoAdvancedHunting|Get-XdrTenantContext|Get-XdrMtoTenantList|ConvertTo-XdrEncodedAdvancedHuntingQuery|Invoke-XdrHuntingQueryValidation)$'
    $names = [System.Management.Automation.Language.Parser]::ParseInput($Command, [ref]$null, [ref]$null).FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -match '-Xdr' -and $_ -notmatch $mtoSafe } | Select-Object -Unique
    if ($names) {
        Write-Stderr "TENANT GUARD: the session belongs to $($saved.TenantName) ($($saved.TenantId)) but the case is $CaseTenantId. $($names -join ', ') would return $($saved.TenantName) data. Hunt the case tenant only, or switch tenant in the portal and rerun the standup for it."
        exit 7
    }
}
elseif ($AllowMultiTenant) { Write-Stderr "[xdr-agent] Multi-tenant sweep allowed for this call" }

# Tenant guard. A proxy shadows Invoke-XdrMtoAdvancedHunting for everything this process runs
# (including scripts it calls, such as a case's xdr_hunt.ps1) and checks -TenantIds at run time,
# which also covers splatted calls the static check can't read.
if ($CaseTenantId -and $AllowMultiTenant) {
    Write-Stderr "TENANT GUARD: -CaseTenantId and -AllowMultiTenant can't be combined. A case hunts one tenant; an estate sweep names its tenants with -AllowMultiTenant and no case lock."
    exit 7
}
$global:XdrHuntTenants = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
function Assert-XdrHuntTenants {
    param ($Bound)
    $ids = @($Bound['TenantIds'] | Where-Object { $_ } | ForEach-Object { "$_".Trim() } | Select-Object -Unique)
    if (-not $ids) { throw "TENANT GUARD: Invoke-XdrMtoAdvancedHunting needs -TenantIds. Without it the module may fan out to every tenant in its cached MTO list." }
    if ($CaseTenantId) {
        $other = @($ids | Where-Object { $_ -ne $CaseTenantId })
        if ($other) { throw "TENANT GUARD: this call is locked to case tenant $CaseTenantId, but the hunt names $($other -join ', '). Use that customer's own case, or an estate sweep without -CaseTenantId." }
    } elseif ($ids.Count -gt 1 -and -not $AllowMultiTenant) {
        throw "TENANT GUARD: the hunt names $($ids.Count) tenants. Multi-tenant hunts need -AllowMultiTenant, used only for an estate sweep the user asked for."
    }
    foreach ($id in $ids) { $null = $global:XdrHuntTenants.Add($id) }
}
$global:XdrHuntCmd = Get-Command -Module XDRInternals -Name Invoke-XdrMtoAdvancedHunting -CommandType Function
# Hunt routing. When the case tenant is the session tenant (direct mode), the single-tenant endpoint
# on security.microsoft.com answers for exactly that tenant and doesn't depend on the multi-tenant
# portal session, which a relay may not carry (HTTP 440). So a hunt written for the MTO cmdlet is
# sent to Invoke-XdrAdvancedHunting when the module has it and its parameters can express the call.
# XDR_HUNT_ROUTE=mto forces the MTO endpoint.
$global:XdrDirectHuntCmd = Get-Command -Module XDRInternals -Name Invoke-XdrAdvancedHunting -ErrorAction SilentlyContinue
$global:XdrSessionTenant = [pscustomobject]@{ Id = "$($saved.TenantId)"; Name = "$($saved.TenantName)" }
$global:XdrHuntRouteNoted = $false
function global:Invoke-XdrDirectHuntShim {
    param ([hashtable]$HuntParameters)
    # Direct rows don't carry the tenant columns MTO rows do; add them so tenant checks, sidecars and
    # per-tenant splitting treat both routes alike.
    & $global:XdrDirectHuntCmd @HuntParameters | ForEach-Object {
        if ($_ -is [psobject] -and $_ -isnot [string] -and -not $_.PSObject.Properties['TenantId']) {
            $_ | Add-Member -NotePropertyName TenantId -NotePropertyValue $global:XdrSessionTenant.Id -PassThru | Add-Member -NotePropertyName TenantName -NotePropertyValue $global:XdrSessionTenant.Name -PassThru
        } else { $_ }
    }
}
function Resolve-XdrHuntRoute {
    param ($Bound)
    $mto = $global:XdrHuntCmd
    if ($env:XDR_HUNT_ROUTE -eq 'mto' -or -not $global:XdrDirectHuntCmd) { return $mto }
    $ids = @($Bound['TenantIds'] | Where-Object { $_ } | ForEach-Object { "$_".Trim() } | Select-Object -Unique)
    if ($ids.Count -ne 1 -or $ids[0] -ne $global:XdrSessionTenant.Id) { return $mto }
    $direct = $global:XdrDirectHuntCmd.Parameters
    $common = [System.Management.Automation.Cmdlet]::CommonParameters + [System.Management.Automation.Cmdlet]::OptionalCommonParameters
    $mapped = @{}
    foreach ($key in @($Bound.Keys)) {
        if ($key -eq 'TenantIds') {
            $tp = @('TenantId', 'TenantIds') | Where-Object { $direct.ContainsKey($_) } | Select-Object -First 1
            if ($tp) { $mapped[$tp] = $ids[0] }
        } elseif ($key -eq 'MinutesAgo' -and $direct.ContainsKey('StartTime') -and -not $direct.ContainsKey('MinutesAgo')) {
            # Same window, expressed as a start time.
            $end = if ($Bound.ContainsKey('EndTime')) { [datetime]$Bound['EndTime'] } else { Get-Date }
            $mapped['StartTime'] = $end.AddMinutes(-[int]$Bound['MinutesAgo'])
        } elseif ($direct.ContainsKey($key) -or $common -contains $key) { $mapped[$key] = $Bound[$key] }
        else { Write-Stderr "[xdr-agent] Hunt stays on the MTO endpoint: Invoke-XdrAdvancedHunting has no -$key."; return $mto }
    }
    # The MTO cmdlet defaults to the last 7 days; keep that window on the direct route.
    if (-not ($Bound.Keys | Where-Object { $_ -in 'DaysAgo', 'MinutesAgo', 'StartTime' })) {
        if ($direct.ContainsKey('DaysAgo')) { $mapped['DaysAgo'] = 7 }
        else { Write-Stderr '[xdr-agent] Hunt stays on the MTO endpoint: Invoke-XdrAdvancedHunting has no -DaysAgo for the default 7-day window.'; return $mto }
    }
    if (-not $global:XdrHuntRouteNoted) {
        Write-Stderr "[xdr-agent] Direct mode: hunt sent to Invoke-XdrAdvancedHunting (single-tenant endpoint on security.microsoft.com). XDR_HUNT_ROUTE=mto forces the MTO endpoint."
        $global:XdrHuntRouteNoted = $true
    }
    $Bound.Clear()
    $Bound['HuntParameters'] = $mapped
    return (Get-Command -Name Invoke-XdrDirectHuntShim -CommandType Function)
}
$huntMeta = [System.Management.Automation.CommandMetadata]::new($global:XdrHuntCmd)
$huntProxy = [System.Management.Automation.ProxyCommand]::Create($huntMeta)
$huntProxy = $huntProxy -replace '\$ExecutionContext\.InvokeCommand\.GetCommand\(''Invoke-XdrMtoAdvancedHunting'',[^)]*\)', '(Resolve-XdrHuntRoute -Bound $PSBoundParameters)'
$huntProxy = $huntProxy -replace '(?m)^begin\s*\r?\n\{', "begin`n{`n    Assert-XdrHuntTenants -Bound `$PSBoundParameters"
if ($huntProxy -notmatch 'Assert-XdrHuntTenants' -or $huntProxy -notmatch 'Resolve-XdrHuntRoute') {
    Write-Stderr 'TENANT GUARD: could not build the hunting proxy. Refusing to run.'
    exit 7
}
# Guard state is global because scripts the command calls (xdr_hunt.ps1) resolve $script: to their
# own scope; each wrapper call is its own process, so nothing carries over.
# Defined per run in a child scope (below). Import-Module put the real function in this script's
# scope, so redefining it here would overwrite it and the proxy would call itself.
$global:XdrHuntProxy = [scriptblock]::Create($huntProxy)
$tenantLeak = @()
$notSearched = @()
# HTTP 440 ("Session timeout") from a hunting endpoint: the portal session can still be valid
# for every other cmdlet. Name it, so the caller switches route instead of re-relaying in a loop.
$huntTimeout = $false
$directMode = -not $CaseTenantId -or $CaseTenantId -eq $saved.TenantId
$hasDirectHunt = [bool](Get-Command -Module XDRInternals -Name Invoke-XdrAdvancedHunting -ErrorAction SilentlyContinue)
$portalTimeout = $false
function Write-HuntTimeout([string]$Message) {
    if ($Message -notmatch '\b440\b|Session ?timeout') { return $false }
    if ($Message -notmatch '(?i)hunt') {
        # 440 from a non-hunting call: the portal session itself was rejected.
        Write-Stderr "PORTAL SESSION TIMEOUT (440): the portal rejected the saved session. Rerun the standup (sign in again and relay)."
        $script:portalTimeout = $true
        return $false
    }
    if ($Message -match 'MTO') {
        $next = if ($directMode -and $hasDirectHunt) { 'This case is in direct mode: hunt with Invoke-XdrAdvancedHunting, which uses the single-tenant endpoint on security.microsoft.com.' }
        elseif ($directMode) { 'This checkout has no Invoke-XdrAdvancedHunting (direct route); update it, or use the portal fallback.' }
        else { 'This is an MTO case, so the direct route would answer for the session tenant. Use the portal fallback, or a direct-mode standup in the customer tenant.' }
        Write-Stderr "HUNT SESSION TIMEOUT (440): the multi-tenant endpoint (mto.security.microsoft.com) rejected the relayed session. $next Don't re-relay in a loop. See reference/hunting-outage.md."
    } else {
        Write-Stderr "HUNT SESSION TIMEOUT (440): the hunting endpoint rejected the session. Check Get-XdrTenantContext -Force; if that fails too, the portal session has expired: rerun the standup. See reference/hunting-outage.md."
    }
    return $true
}

# Run the command, keeping only real output on stdout
$results = New-Object System.Collections.Generic.List[object]
$exitCode = 0
# Let non-terminating errors report and continue, so one bad item doesn't discard the rest.
$ErrorActionPreference = 'Continue'
try {
    $scriptBlock = [scriptblock]::Create($Command)
    $runner = { Set-Item -Path Function:local:Invoke-XdrMtoAdvancedHunting -Value $global:XdrHuntProxy; & $scriptBlock }
    foreach ($item in (& $runner 2>&1 3>&1 6>&1)) {
        if ($item -is [System.Management.Automation.InformationRecord]) {
            Write-Stderr "[info] $($item.MessageData)"
        } elseif ($item -is [System.Management.Automation.WarningRecord]) {
            Write-Stderr "[warning] $($item.Message)"
            # A tenant that errored in a hunt returned nothing: that is not the same as clean.
            if ($item.Message -match '^Tenant (?<t>[0-9a-fA-F-]{36}) returned error: (?<e>.+)$') {
                Write-Stderr "TENANT NOT SEARCHED: $($Matches.t) ($($Matches.e)). Report it as not searched, not as no results."
                $notSearched += [pscustomobject]@{ TenantId = $Matches.t; Error = $Matches.e }
                if ($exitCode -eq 0) { $exitCode = 2 }
            }
        } elseif ($item -is [System.Management.Automation.ErrorRecord]) {
            Write-Stderr "[error] $item"
            if (Write-HuntTimeout "$item") { $huntTimeout = $true }
            $exitCode = 2
        } else {
            # A hunt row carries TenantId and TenantName. Refuse any row from a tenant no hunt named.
            if ($global:XdrHuntTenants.Count -and $item -isnot [string] -and $item.PSObject.Properties['TenantId'] -and $item.PSObject.Properties['TenantName'] -and -not $global:XdrHuntTenants.Contains("$($item.TenantId)")) {
                $tenantLeak += "$($item.TenantName) ($($item.TenantId))"
            }
            $results.Add($item)
        }
    }
} catch {
    $message = $_.Exception.Message
    Write-Stderr "[error] $message"
    if ($message -match '401|403|Unauthorized|Forbidden|login\.microsoftonline|sign in') {
        Write-Stderr "The portal session looks expired or lacks permission. Ask the user to reconnect and rerun Save-XdrAgentSession.ps1."
    }
    $exitCode = if ($message -match 'TENANT GUARD') { 7 } else { 1 }
    if ($exitCode -ne 7 -and (Write-HuntTimeout $message)) { $huntTimeout = $true }
}
if ($huntTimeout -and $exitCode -ne 7) { $exitCode = 8 }
elseif ($portalTimeout -and $exitCode -ne 7) { $exitCode = 4 }

if ($tenantLeak) {
    Write-Stderr "TENANT GUARD: rows came back from tenants no hunt named: $(($tenantLeak | Select-Object -Unique) -join ', '). All results discarded."
    $results.Clear()
    $exitCode = 7
}

# The portal rotates XSRF tokens; keep the saved copies current for the next call.
$changed = $false
$currentXsrf = (& $module { $script:session }).Cookies.GetCookies('https://security.microsoft.com')['xsrf-token'].Value
if ($currentXsrf -and $currentXsrf -ne $saved.Xsrf) { $saved.Xsrf = $currentXsrf; $changed = $true }
$mtoSessionNow = & $module { $script:mtoSession }
if ($mtoSessionNow) {
    $currentMtoXsrf = $mtoSessionNow.Cookies.GetCookies('https://mto.security.microsoft.com')['xsrf-token'].Value
    if ($currentMtoXsrf -and $currentMtoXsrf -ne $savedMtoXsrf) {
        $saved | Add-Member -NotePropertyName MtoXsrf -NotePropertyValue $currentMtoXsrf -Force
        $changed = $true
    }
}
if ($changed) { $saved | ConvertTo-Json | Set-Content -LiteralPath $SessionPath -Encoding utf8 }

# Emit results. Use ToArray(): in PowerShell 7.4, @() around a generic List breaks ConvertTo-Json
# ("Argument types do not match").
try {
if ($OutFile) {
    $directory = Split-Path -Parent $OutFile
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }
    ConvertTo-Json -InputObject $results.ToArray() -Depth $Depth -WarningAction SilentlyContinue | Set-Content -LiteralPath $OutFile -Encoding utf8
    if ($global:XdrHuntTenants.Count) {
        # Sidecar: which tenants the hunt named, which returned rows, and which weren't searched.
        $returned = @($results | Where-Object { $_ -isnot [string] -and $_.PSObject.Properties['TenantId'] } | ForEach-Object { "$($_.TenantId)" } | Select-Object -Unique)
        [ordered]@{
            Named       = @($global:XdrHuntTenants)
            Returned    = $returned
            NotSearched = @($notSearched)
            CaseTenant  = $CaseTenantId
            RunUtc      = (Get-Date).ToUniversalTime().ToString('o')
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$OutFile.tenants.json" -Encoding utf8
    }
    $properties = if ($results.Count -gt 0 -and $results[0] -isnot [string] -and -not $results[0].GetType().IsPrimitive) { @($results[0].PSObject.Properties.Name) } else { @() }
    [ordered]@{
        Count      = $results.Count
        OutFile    = (Resolve-Path -LiteralPath $OutFile).Path
        Properties = $properties
    } | ConvertTo-Json -Depth 3
} else {
    $shown = $results
    if ($results.Count -gt $MaxItems) {
        Write-Stderr "[xdr-agent] Showing $MaxItems of $($results.Count) items. Narrow the query or use -OutFile for the full set."
        $shown = $results.GetRange(0, $MaxItems)
    }
    switch ($Format) {
        'Json' { ConvertTo-Json -InputObject $shown.ToArray() -Depth $Depth -WarningAction SilentlyContinue }
        'Table' { $shown | Format-Table -AutoSize | Out-String -Width 400 }
        'List' { $shown | Format-List | Out-String -Width 400 }
    }
}
} catch {
    Write-Stderr "[error] Could not write the results: $($_.Exception.Message)"
    exit 1
}

exit $exitCode
