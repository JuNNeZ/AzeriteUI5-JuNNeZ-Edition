# AzeriteUI Release Builder
# JuNNeZ Edition
# Builds a clean release package excluding development files

$ErrorActionPreference = "Stop"

# Configuration
$AddonName = "AzeriteUI5_JuNNeZ_Edition"
$SourcePath = $PSScriptRoot
$DestinationBase = "C:\Users\Jonas\OneDrive\Skrivebord\azeriteui_fan_edit"

# IMPORTANT: UPDATE VERSION BEFORE EACH RELEASE!
# Also update version in: AzeriteUI5_JuNNeZ_Edition.toc
# Versioning: patch (5.2.214->5.2.215), minor (5.2.x->5.3.0), major (5.x.x->6.0.0)
$Version = "5.3.3-JuNNeZ"

$DateStamp = Get-Date -Format "dd-MM-yyyy"
$ArchiveName = "AzeriteUI-$Version-Retail-$DateStamp.zip"

# Files and folders to exclude from release
$ExcludePatterns = @(
    "*.git*",
    "_savepoints",
    ".research",
    ".vscode",
    "*.md",
    "build-release.ps1",
    "*.code-workspace",
    "AGENTS.md",
    "FixLog.md",
    "Docs\*"
)

Write-Host "========================================"
Write-Host "  AzeriteUI Release Builder"
Write-Host "  JuNNeZ Edition v$Version"
Write-Host "========================================"
Write-Host ""

# Verify source path
if (-not (Test-Path $SourcePath)) {
    Write-Host "ERROR: Source path not found: $SourcePath"
    exit 1
}

# Create destination directory if it doesn't exist
if (-not (Test-Path $DestinationBase)) {
    Write-Host "Creating destination directory..."
    New-Item -ItemType Directory -Path $DestinationBase -Force | Out-Null
}

# Temporary build directory
$TempBuildPath = Join-Path $env:TEMP "AzeriteUI_Build"
$TempAddonPath = Join-Path $TempBuildPath $AddonName

# Clean temp directory if it exists
if (Test-Path $TempBuildPath) {
    Write-Host "Cleaning temporary build directory..."
    Remove-Item $TempBuildPath -Recurse -Force
}

# Create temp directory structure
Write-Host "Creating temporary build directory..."
New-Item -ItemType Directory -Path $TempAddonPath -Force | Out-Null

# Copy files excluding development/internal files
Write-Host "Copying addon files..."
$CopyParams = @{
    Path = "$SourcePath\*"
    Destination = $TempAddonPath
    Recurse = $true
    Force = $true
    Exclude = $ExcludePatterns
}

try {
    Copy-Item @CopyParams
    
    # Remove excluded directories that made it through
    $ExcludeDirs = @("_savepoints", ".research", ".vscode", "Docs")
    foreach ($dir in $ExcludeDirs) {
        $dirPath = Join-Path $TempAddonPath $dir
        if (Test-Path $dirPath) {
            Remove-Item $dirPath -Recurse -Force
        }
    }
    
    Write-Host "[DONE] Files copied successfully"
} catch {
    Write-Host "ERROR: Failed to copy files - $_"
    exit 1
}

# Create archive
$ArchivePath = Join-Path $DestinationBase $ArchiveName
Write-Host "Creating release archive..."
Write-Host "  Output: $ArchivePath"

try {
    # Remove existing archive if present
    if (Test-Path $ArchivePath) {
        Remove-Item $ArchivePath -Force
    }
    
    # Create zip archive
    Compress-Archive -Path $TempAddonPath -DestinationPath $ArchivePath -CompressionLevel Optimal
    
    Write-Host "[DONE] Archive created successfully"
} catch {
    Write-Host "ERROR: Failed to create archive - $_"
    exit 1
}

# Clean up temp directory
Write-Host "Cleaning up..."
Remove-Item $TempBuildPath -Recurse -Force

# Get archive size
$ArchiveSize = (Get-Item $ArchivePath).Length / 1MB
$ArchiveSizeFormatted = "{0:N2} MB" -f $ArchiveSize

Write-Host ""
Write-Host "========================================"
Write-Host "  Release Build Complete!"
Write-Host "========================================"
Write-Host ""
Write-Host "Archive: $ArchiveName"
Write-Host "Size: $ArchiveSizeFormatted"
Write-Host "Location: $DestinationBase"
Write-Host ""
Write-Host "Ready to distribute!"
Write-Host ""
