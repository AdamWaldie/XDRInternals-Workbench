<#
    .SYNOPSIS
        Builds the xdrinternals-workbench skill (Claude account skill and Codex) from the repo copy.

    .DESCRIPTION
        The source of truth is .claude/skills/xdrinternals-workbench (SKILL.md and reference/). This script
        copies it under the name xdrinternals-workbench, so the account skill and the Codex skill
        never drift from the repo:

          - dist/xdrinternals-workbench-skill.zip, with the skill folder at the archive root, for
            Claude > Settings > Capabilities > Skills (replace the existing xdrinternals-workbench).
          - With -InstallCodex, the same folder in ~/.codex/skills/xdrinternals-workbench (or
            $env:CODEX_HOME/skills), replacing what was there.

        The archive is checked before it is written: SKILL.md frontmatter is named xdrinternals-workbench and has a description, and every
        reference/*.md file that SKILL.md mentions exists.

    .PARAMETER InstallCodex
        Also install the skill for Codex on this machine.

    .EXAMPLE
        pwsh -NoProfile -File claude-desktop/build-workbench-skill.ps1 -InstallCodex
#>
[CmdletBinding()]
param([switch]$InstallCodex)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$source = Join-Path $repoRoot '.claude/skills/xdrinternals-workbench'
$skillName = 'xdrinternals-workbench'

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("xdr-skill-" + [guid]::NewGuid().ToString('N'))
$skillDir = Join-Path $stage $skillName
try {
    $null = New-Item -ItemType Directory -Path $skillDir -Force
    Copy-Item -Path (Join-Path $source '*') -Destination $skillDir -Recurse -Force

    # The repo copy, the account skill and the Codex skill share one name, so the copy is used as is.
    # Claude's uploader rejects a SKILL.md whose name differs from the skill it replaces ("Skill name
    # mismatch"), so check the name here instead of letting the upload find it.
    $skillFile = Join-Path $skillDir 'SKILL.md'
    $text = Get-Content -LiteralPath $skillFile -Raw
    $nameMatch = [regex]::Match($text, '(?ms)\A\uFEFF?---\s*\r?\n.*?^name:[ \t]*(.+?)[ \t]*\r?$.*?^---')
    if (-not $nameMatch.Success) { throw "$skillFile has no YAML frontmatter with a name." }
    if ($nameMatch.Groups[1].Value -ne $skillName) { throw "$skillFile is named '$($nameMatch.Groups[1].Value)'; it must be '$skillName' to replace the uploaded skill." }
    if ($text -notmatch '(?m)^description:\s*\S') { throw "$skillFile has no description in its frontmatter." }

    # Every reference/... file SKILL.md points at must ship with it.
    $missing = @([regex]::Matches($text, 'reference/[A-Za-z0-9_./-]+\.md') | ForEach-Object Value | Select-Object -Unique | Where-Object { -not (Test-Path (Join-Path $skillDir $_)) })
    if ($missing) { throw "SKILL.md references files that aren't in the skill: $($missing -join ', ')" }

    $dist = Join-Path $repoRoot 'dist'
    $null = New-Item -ItemType Directory -Path $dist -Force
    $zip = Join-Path $dist "$skillName-skill.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    # Forward-slash entry names: some uploaders reject the backslashes Compress-Archive writes on Windows.
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
    try {
        $baseLength = $stage.TrimEnd([IO.Path]::DirectorySeparatorChar).Length + 1
        foreach ($file in Get-ChildItem -Path $skillDir -Recurse -File) {
            $entryName = $file.FullName.Substring($baseLength) -replace '\\', '/'
            $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entryName)
        }
    } finally { $archive.Dispose() }
    $count = @(Get-ChildItem -Path $skillDir -Recurse -File).Count
    Write-Host "Built $zip ($count files). Upload it in Claude > Settings > Capabilities > Skills, replacing $skillName."

    if ($InstallCodex) {
        $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' }
        $target = Join-Path $codexHome "skills/$skillName"
        if (Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force
        Copy-Item -LiteralPath $skillDir -Destination $target -Recurse -Force
        Write-Host "Installed for Codex: $target (restart Codex to pick it up)."
    }
} finally {
    if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
