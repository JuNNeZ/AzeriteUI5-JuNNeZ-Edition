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
$Version = "5.3.90-JuNNeZ"

$DateStamp = Get-Date -Format "dd-MM-yyyy"
$ArchiveName = "AzeriteUI-$Version-Retail-$DateStamp.zip"

# Runtime roots copied into the release. WoW11 contains the current Retail
# delayed-start bootstrap despite its historical folder name and remains loaded
# by the Retail TOC.
$ReleaseEntries = @(
    "Assets",
    "Components",
    "Core",
    "Layouts",
    "Libs",
    "Locale",
    "Options",
    "WoW11",
    "$AddonName.toc",
    "FontStyles.xml",
    "LICENSE",
    "LICENSE.txt"
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

# Copy only runtime addon files.
Write-Host "Copying addon files..."
try {
    foreach ($entry in $ReleaseEntries) {
        $entryPath = Join-Path $SourcePath $entry
        if (-not (Test-Path -LiteralPath $entryPath)) {
            throw "Required release entry is missing: $entry"
        }
        Copy-Item -LiteralPath $entryPath -Destination $TempAddonPath -Recurse -Force
    }

    # Embedded libraries may carry their upstream repository metadata. Remove
    # it only from the verified temporary build tree.
    $TempAddonRoot = [System.IO.Path]::GetFullPath($TempAddonPath).TrimEnd('\') + '\'
    $DevelopmentDirectoryNames = @(".agents", ".claude", ".codex", ".devcontainer", ".git", ".github", ".research", ".vscode", "_savepoints")
    $DevelopmentDirectories = Get-ChildItem -LiteralPath $TempAddonPath -Directory -Recurse -Force |
        Where-Object { $DevelopmentDirectoryNames -contains $_.Name } |
        Sort-Object { $_.FullName.Length } -Descending
    foreach ($directory in $DevelopmentDirectories) {
        $resolvedPath = [System.IO.Path]::GetFullPath($directory.FullName)
        if (-not $resolvedPath.StartsWith($TempAddonRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a directory outside the temporary release tree: $resolvedPath"
        }
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }

    $EmbeddedDevelopmentPaths = @("Libs\oUF\utils")
    foreach ($relativePath in $EmbeddedDevelopmentPaths) {
        $candidatePath = Join-Path $TempAddonPath $relativePath
        if (-not (Test-Path -LiteralPath $candidatePath)) {
            continue
        }
        $resolvedPath = [System.IO.Path]::GetFullPath($candidatePath)
        if (-not $resolvedPath.StartsWith($TempAddonRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a directory outside the temporary release tree: $resolvedPath"
        }
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }

    $DevelopmentFileNames = @(".editorconfig", ".gitattributes", ".luacheckrc", ".mcp.json", ".pkgmeta")
    Get-ChildItem -LiteralPath $TempAddonPath -File -Recurse -Force |
        Where-Object { $DevelopmentFileNames -contains $_.Name -or $_.Extension -in @(".code-workspace", ".md") } |
        Remove-Item -Force

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
