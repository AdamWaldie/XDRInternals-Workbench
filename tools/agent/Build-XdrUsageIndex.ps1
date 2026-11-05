<#
    .SYNOPSIS
        Builds the per-cmdlet usage index for the xdrinternals skill from the module's own help.

    .DESCRIPTION
        Imports XDRInternals, reads Get-Help -Full for every exported cmdlet, and writes
        .claude/skills/xdrinternals/reference/usage/<group>.md plus INDEX.md. The guard column
        uses the same rules as Invoke-XdrAgent.ps1, so the index can't drift from what the
        wrapper allows. Run it after any module change, then run claude-desktop/build-skill.ps1
        to repackage the desktop skill.

    .EXAMPLE
        pwsh -NoProfile -File tools/agent/Build-XdrUsageIndex.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir = (Join-Path $PSScriptRoot '../../.claude/skills/xdrinternals/reference/usage')
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Import-Module (Join-Path $repoRoot 'XDRInternals/XDRInternals.psd1') -Force

function Get-Guard([string]$Name) {
    if ($Name -match '^(Connect-Xdr(By|Auth)|Set-XdrConnectionSettings$|Update-XdrConnectionSettings$)') { return 'blocked' }
    if ($Name -match '^(New|Set|Remove|Merge|Move|Stop|Update|Export|Disconnect|Connect)-Xdr' -or $Name -match '^Invoke-XdrEndpointDevice') { return 'write' }
    if ($Name -eq 'Invoke-XdrRestMethod') { return 'read (GET only)' }
    'read'
}

$groups = [ordered]@{
    'session-tenant'     = @('Session, tenant and MTO', { param($n) $n -like 'Connect-XdrBy*' -or $n -in 'Get-XdrTenantContext', 'Get-XdrTenantWorkloadStatus', 'Get-XdrMtoTenantList', 'Set-XdrConnectionSettings', 'Update-XdrConnectionSettings' })
    'hunting'            = @('Advanced Hunting, Data Lake and XSPM hunting', { param($n) $n -match 'AdvancedHunting|HuntingQuery|Datalake' })
    'incidents-alerts'   = @('Incidents, alerts, suppression and threat analytics', { param($n) $n -match 'Incident|Alert(?!Service|Tuning|Threshold)|SuppressionRule|ThreatAnalytics' })
    'endpoint-response'  = @('Endpoint devices, timelines, response actions and Live Response', { param($n) $n -match 'EndpointDevice|ActionsCenter' })
    'endpoint-config'    = @('Endpoint configuration and licensing', { param($n) $n -match 'XdrEndpoint' })
    'identity'           = @('Defender for Identity', { param($n) $n -match 'XdrIdentity' })
    'cloud-apps'         = @('Defender for Cloud Apps', { param($n) $n -match 'CloudApps' })
    'exposure-vuln'      = @('Vulnerability and exposure management', { param($n) $n -match 'Vulnerability|Xspm|ExposureManagement' })
    'portal-config'      = @('Portal configuration and streaming', { param($n) $n -match 'XdrConfiguration|StreamingApi' })
    'export-integration' = @('Export, Sentinel and Azure Data Explorer', { param($n) $n -match 'AzureDataExplorer|Sentinel' })
    'raw-api'            = @('Raw portal API', { param($n) $true })
}

function Clean([string]$s) { if (-not $s) { return '' }; ($s -replace [char]0x2014, ' - ' -replace [char]0x2013, '-').Trim() }
function Cell([string]$s) { (Clean ($s -replace '\s+', ' ')) -replace '\|', '/' }

$common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
$buckets = [ordered]@{}; foreach ($k in $groups.Keys) { $buckets[$k] = [System.Collections.Generic.List[object]]::new() }
foreach ($c in Get-Command -Module XDRInternals | Sort-Object Name) {
    foreach ($k in $groups.Keys) { if (& $groups[$k][1] $c.Name) { $buckets[$k].Add($c); break } }
}

$null = New-Item -ItemType Directory -Path $OutDir -Force
$index = [System.Collections.Generic.List[string]]::new()
$index.AddRange([string[]]@(
    '# XDRInternals usage index', '',
    'Generated from the module''s comment-based help by `tools/agent/Build-XdrUsageIndex.ps1`. Regenerate after any module change. Guard matches `tools/agent/Invoke-XdrAgent.ps1`: `read` runs freely, `write` needs the user''s approval for that specific action and `-AllowWrite`, `blocked` is user-only (sign-in and connection settings).', '',
    '| Cmdlet | Guard | File | Synopsis |', '| --- | --- | --- | --- |'))
$total = 0
foreach ($k in $buckets.Keys) {
    $cmds = $buckets[$k]; if ($cmds.Count -eq 0) { continue }
    $L = [System.Collections.Generic.List[string]]::new()
    $L.AddRange([string[]]@("# $($groups[$k][0])", '', "$($cmds.Count) cmdlets. Run them through ``tools/agent/Invoke-XdrAgent.ps1``. Guard and tenant rules are in ``../../SKILL.md``.", ''))
    foreach ($c in $cmds) {
        $total++
        $h = Get-Help $c.Name -Full
        $guard = Get-Guard $c.Name
        $syn = Clean ($h.Synopsis | Out-String)
        $index.Add("| $($c.Name) | $guard | usage/$k.md | $(Cell $syn) |")
        $L.AddRange([string[]]@("## $($c.Name)", '', "Guard: ``$guard``", '', $syn, ''))
        $desc = Clean ((@($h.description) | ForEach-Object Text) -join "`n")
        if ($desc -and $desc -ne $syn) { $L.AddRange([string[]]@($desc, '')) }
        $L.Add('```powershell')
        foreach ($ps in $c.ParameterSets) {
            $parts = foreach ($p in $ps.Parameters | Where-Object { $_.Name -notin $common }) {
                $t = if ($p.ParameterType -eq [switch]) { "-$($p.Name)" } else { "-$($p.Name) <$($p.ParameterType.Name)>" }
                if ($p.IsMandatory) { $t } else { "[$t]" }
            }
            $L.Add(("$($c.Name) " + ($parts -join ' ')).TrimEnd())
        }
        $L.AddRange([string[]]@('```', ''))
        $params = @($h.parameters.parameter) | Where-Object { $_ -and $_.name -and $_.name -notin $common }
        if ($params) {
            $L.AddRange([string[]]@('| Parameter | Type | Required | Default | Description |', '| --- | --- | --- | --- | --- |'))
            foreach ($p in $params) {
                $req = if ("$($p.required)" -eq 'true') { 'yes' } else { '' }
                $pd = Cell ((@($p.description) | ForEach-Object Text) -join ' ')
                $vs = $c.Parameters[$p.name].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
                if ($vs) { $pd = ("$pd Values: " + ($vs.ValidValues -join ', ')).Trim() }
                $L.Add("| -$($p.name) | $($p.type.name) | $req | $(Cell "$($p.defaultValue)") | $pd |")
            }
            $L.Add('')
        }
        $i = 0
        foreach ($e in @($h.examples.example) | Where-Object { $_ }) {
            $i++
            $lines = @((Clean ($e.code | Out-String)) -replace '(?m)^PS [A-Z]:\\>\s?', '' -split "`r?`n")
            # Comment-based help often folds the first remark line into the code block. Move trailing prose out.
            $prose = [System.Collections.Generic.List[string]]::new()
            while ($lines.Count -gt 1 -and $lines[-1] -match '^[A-Z][a-z]+\b[^=|${}()]*[.:]?$' -and $lines[-1] -notmatch '^(Get|Set|New|Invoke|Remove|Connect|Import|Write|Select|Where|ForEach|Export|ConvertTo|Out|Start|Sort)-') {
                $prose.Insert(0, $lines[-1]); $lines = $lines[0..($lines.Count - 2)]
            }
            $remarks = Clean (((@($prose) + @(@($e.remarks) | ForEach-Object Text)) -join ' ') -replace '\s+', ' ')
            $L.AddRange([string[]](@("Example ${i}:", '', '```powershell') + @($lines | ForEach-Object { $_.TrimEnd() }) + @('```', '')))
            if ($remarks) { $L.AddRange([string[]]@($remarks, '')) }
        }
    }
    [System.IO.File]::WriteAllText((Join-Path $OutDir "$k.md"), ($L -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}
[System.IO.File]::WriteAllText((Join-Path $OutDir 'INDEX.md'), ($index -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Host "Indexed $total cmdlets into $OutDir"
