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
        3 refused by the write guard, 4 no or stale session, 5 tenant mismatch,
        6 not PowerShell 7.

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
        Session file written by Save-XdrAgentSession.ps1. Defaults to ~/.xdr-agent/session.json.

    .PARAMETER MaxSessionAgeHours
        Refuse a saved session older than this. Defaults to 12.

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

    [string]$SessionPath = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.xdr-agent/session.json'),

    [double]$MaxSessionAgeHours = 12
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
if (-not (Test-Path -LiteralPath $SessionPath)) {
    Write-Stderr "NO SESSION: $SessionPath doesn't exist. Ask the user to connect (e.g. Connect-XdrByBrowserExtension) and then run tools/agent/Save-XdrAgentSession.ps1 in the same PowerShell session."
    exit 4
}
$saved = Get-Content -LiteralPath $SessionPath -Raw | ConvertFrom-Json
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

# The module uses PowerShell 7 syntax and doesn't parse under Windows PowerShell 5.1.
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

# Run the command, keeping only real output on stdout
$results = New-Object System.Collections.Generic.List[object]
$exitCode = 0
# Let non-terminating errors report and continue, so one bad item doesn't discard the rest.
$ErrorActionPreference = 'Continue'
try {
    $scriptBlock = [scriptblock]::Create($Command)
    foreach ($item in (& $scriptBlock 2>&1 3>&1 6>&1)) {
        if ($item -is [System.Management.Automation.InformationRecord]) {
            Write-Stderr "[info] $($item.MessageData)"
        } elseif ($item -is [System.Management.Automation.WarningRecord]) {
            Write-Stderr "[warning] $($item.Message)"
        } elseif ($item -is [System.Management.Automation.ErrorRecord]) {
            Write-Stderr "[error] $item"
            $exitCode = 2
        } else {
            $results.Add($item)
        }
    }
} catch {
    $message = $_.Exception.Message
    Write-Stderr "[error] $message"
    if ($message -match '401|403|Unauthorized|Forbidden|login\.microsoftonline|sign in') {
        Write-Stderr "The portal session looks expired or lacks permission. Ask the user to reconnect and rerun Save-XdrAgentSession.ps1."
    }
    $exitCode = 1
}

# The portal rotates XSRF tokens; keep the saved copy current for the next call.
$module = Get-Module XDRInternals
$currentXsrf = (& $module { $script:session }).Cookies.GetCookies('https://security.microsoft.com')['xsrf-token'].Value
if ($currentXsrf -and $currentXsrf -ne $saved.Xsrf) {
    $saved.Xsrf = $currentXsrf
    $saved | ConvertTo-Json | Set-Content -LiteralPath $SessionPath -Encoding utf8
}

# Emit results
if ($OutFile) {
    $directory = Split-Path -Parent $OutFile
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }
    ConvertTo-Json -InputObject @($results) -Depth $Depth -WarningAction SilentlyContinue | Set-Content -LiteralPath $OutFile -Encoding utf8
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
        'Json' { ConvertTo-Json -InputObject @($shown) -Depth $Depth -WarningAction SilentlyContinue }
        'Table' { $shown | Format-Table -AutoSize | Out-String -Width 400 }
        'List' { $shown | Format-List | Out-String -Width 400 }
    }
}

exit $exitCode
