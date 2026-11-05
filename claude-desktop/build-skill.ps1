<#
    .SYNOPSIS
        Packages the Claude Chat/Cowork skill as dist/xdrinternals-skill.zip for upload.

    .DESCRIPTION
        Copies the shared cmdlet reference from the Claude Code skill so the two never drift,
        then zips claude-desktop/xdrinternals with the skill folder at the archive root. Upload
        the zip in Claude under Settings > Capabilities > Skills.
#>
$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$skillDir = Join-Path $PSScriptRoot 'xdrinternals'
$referenceDir = Join-Path $skillDir 'reference'

$null = New-Item -ItemType Directory -Path $referenceDir -Force
Copy-Item (Join-Path $repoRoot '.claude/skills/xdrinternals/reference/cmdlets.md') $referenceDir -Force
$usageSource = Join-Path $repoRoot '.claude/skills/xdrinternals/reference/usage'
if (Test-Path $usageSource) { Copy-Item $usageSource $referenceDir -Recurse -Force }

$dist = Join-Path $repoRoot 'dist'
$null = New-Item -ItemType Directory -Path $dist -Force
$zip = Join-Path $dist 'xdrinternals-skill.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }

# Compress-Archive on Windows PowerShell writes backslash entry names, which some uploaders
# reject, so build the archive directly with forward-slash paths.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    $baseLength = (Split-Path -Parent $skillDir).Length + 1
    foreach ($file in Get-ChildItem -Path $skillDir -Recurse -File) {
        $entryName = $file.FullName.Substring($baseLength) -replace '\\', '/'
        $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entryName)
    }
} finally {
    $archive.Dispose()
}
Write-Host "Built $zip"
