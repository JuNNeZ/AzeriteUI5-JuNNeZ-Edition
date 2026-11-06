<#
.SYNOPSIS
    Expose only the game files of the dev repos in C:\dev to every WoW client.

.DESCRIPTION
    Each client's Interface\AddOns\<Addon> becomes a real folder that holds
    links into the repo: a junction per runtime folder and a link per runtime
    root file. .git, Docs, Tools, Assets_Draft, wiki etc. never reach the game.
    Edits in the repo reach the game on /reload.

    Root files are symbolic links when Windows allows them (Developer Mode on
    or an elevated shell) and hard links otherwise. A hard link silently goes
    stale when an editor or git replaces the file instead of rewriting it, so
    in hard-link mode run this script again (or with -Check) before testing.

    The lists below mirror what each addon ships (build-release.ps1 for
    AzeriteUI, .pkgmeta for AHOS and ABCS). Keep them in step when a runtime
    root folder or file is added.

    Safe to re-run. It only ever deletes links. A real folder or file it did
    not create is moved to Interface\AddOns-backup-<date>, never deleted.

.EXAMPLE
    ./Tools/Link-WoWAddons.ps1          # (re)build the links on every client
    ./Tools/Link-WoWAddons.ps1 -Check   # report stale or missing links only
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [string]$DevRoot = 'C:\dev',
    [string]$WoWRoot = 'C:\Program Files (x86)\World of Warcraft',
    [string[]]$Clients = @('_retail_', '_forever_', '_classic_beta_')
)

$ErrorActionPreference = 'Stop'

# Dirs: junctioned whole. Files: wildcard patterns in the repo root.
# Exclude: root files matched by Files that must not ship.
# Whole: the repo folder itself is all game files; one junction for it.
$Addons = @(
    @{ Name = 'AzeriteUI5_JuNNeZ_Edition'; Repo = 'AzeriteUI5_JuNNeZ_Edition'
       Dirs = 'Assets', 'Components', 'Core', 'Layouts', 'Libs', 'Locale', 'Options', 'WoW11'
       Files = 'AzeriteUI5_JuNNeZ_Edition.toc', 'AzeriteUI5_JuNNeZ_Edition_Camelot.toc', 'FontStyles.xml' }
    @{ Name = 'AzeriteUI5_JuNNeZ_Edition_Debug'; Repo = 'AzeriteUI5_JuNNeZ_Edition\AzeriteUI5_JuNNeZ_Edition_Debug'
       Whole = $true }
    @{ Name = 'AdvancedHotkeyOverlaySystem'; Repo = 'AdvancedHotkeyOverlaySystem'
       Dirs = 'Libs', 'locales', 'media', 'modules', 'options'
       Files = '*.toc', '*.lua'
       Exclude = 'AdvancedHotkeyOverlaySystem.toc' }   # .pkgmeta ignores the base TOC
    @{ Name = 'AzUI_Color_Picker'; Repo = 'AzUI_Color_Picker'
       Dirs = 'Libs', 'Locales', 'Media', 'Options', 'Pages'
       Files = '*.toc', '*.lua', 'Bindings.xml', 'icon.tga' }
)

function Test-CanSymlink {
    $probe = Join-Path ([IO.Path]::GetTempPath()) "wowlink-probe-$PID"
    $target = "$probe.target"
    try {
        Set-Content -LiteralPath $target -Value '' -NoNewline
        New-Item -ItemType SymbolicLink -Path $probe -Target $target -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    } finally {
        Remove-Item -LiteralPath $probe, $target -Force -ErrorAction SilentlyContinue
    }
}

function Get-HardLinkCount([string]$Path) {
    @(fsutil hardlink list $Path 2>$null).Count
}

# True when $Item is something this script created: a junction or symlink,
# or a file hard-linked to a second name.
function Test-IsLink($Item) {
    if ($Item.LinkType -in 'Junction', 'SymbolicLink') { return $true }
    if (-not $Item.PSIsContainer -and $Item.LinkType -eq 'HardLink') {
        return (Get-HardLinkCount $Item.FullName) -ge 2
    }
    return $false
}

function Remove-Link($Item) {
    if ($Item.PSIsContainer) { [IO.Directory]::Delete($Item.FullName, $false) }
    else { [IO.File]::Delete($Item.FullName) }
}

function Get-Wanted($Addon, [string]$RepoPath) {
    $wanted = [ordered]@{}
    foreach ($d in $Addon.Dirs) {
        $p = Join-Path $RepoPath $d
        if (Test-Path -LiteralPath $p -PathType Container) { $wanted[$d] = @{ Path = $p; Dir = $true } }
        else { Write-Warning "$($Addon.Name): runtime folder '$d' is missing in the repo" }
    }
    foreach ($pattern in $Addon.Files) {
        foreach ($f in Get-ChildItem -LiteralPath $RepoPath -File -Filter $pattern) {
            if ($Addon.Exclude -contains $f.Name) { continue }
            $wanted[$f.Name] = @{ Path = $f.FullName; Dir = $false }
        }
    }
    $wanted
}

function Move-ToBackup([string]$Path, [string]$AddOnsPath) {
    $backup = Join-Path (Split-Path $AddOnsPath) ("AddOns-backup-" + (Get-Date -Format 'yyyy-MM-dd'))
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    $dest = Join-Path $backup ((Split-Path $Path -Leaf) + '-' + (Get-Date -Format 'HHmmss'))
    Move-Item -LiteralPath $Path -Destination $dest
    Write-Warning "Moved real content to $dest"
}

# Report whether one client's addon folder matches the wanted links.
function Get-Problems($Addon, [string]$Dest, $Wanted) {
    $problems = @()
    $item = Get-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
    if (-not $item) { return , "missing" }
    if ($Addon.Whole) {
        if ($item.LinkType -ne 'Junction' -or $item.Target -ne $Addon.RepoPath) { $problems += "not a junction to the repo" }
        return , $problems
    }
    if ($item.LinkType) { return , "is a $($item.LinkType) to the whole repo" }
    foreach ($name in $Wanted.Keys) {
        $w = $Wanted[$name]
        $have = Get-Item -LiteralPath (Join-Path $Dest $name) -Force -ErrorAction SilentlyContinue
        if (-not $have) { $problems += "missing $name"; continue }
        if ($w.Dir) {
            if ($have.LinkType -ne 'Junction' -or $have.Target -ne $w.Path) { $problems += "$name is not a junction to the repo" }
        } elseif ($have.LinkType -eq 'SymbolicLink') {
            if ($have.Target -ne $w.Path) { $problems += "$name points elsewhere" }
        } elseif ((Get-HardLinkCount $w.Path) -lt 2 -or (Get-FileHash $have.FullName).Hash -ne (Get-FileHash $w.Path).Hash) {
            $problems += "$name is stale (hard link broken)"
        }
    }
    foreach ($child in Get-ChildItem -LiteralPath $Dest -Force) {
        if (-not $Wanted.Contains($child.Name)) { $problems += "extra $($child.Name)" }
    }
    , $problems
}

$useSymlinks = Test-CanSymlink
$fileLinkType = if ($useSymlinks) { 'SymbolicLink' } else { 'HardLink' }
if (-not $Check) { Write-Host "Root files are linked as: $fileLinkType" }

$bad = 0
foreach ($client in $Clients) {
    $addOnsPath = Join-Path $WoWRoot "$client\Interface\AddOns"
    if (-not (Test-Path -LiteralPath $addOnsPath)) { continue }

    foreach ($addon in $Addons) {
        $addon.RepoPath = Join-Path $DevRoot $addon.Repo
        if (-not (Test-Path -LiteralPath $addon.RepoPath)) { Write-Warning "No repo at $($addon.RepoPath)"; continue }
        $dest = Join-Path $addOnsPath $addon.Name
        $wanted = if ($addon.Whole) { $null } else { Get-Wanted $addon $addon.RepoPath }

        $problems = Get-Problems $addon $dest $wanted
        if ($Check) {
            if ($problems.Count) { $bad++; Write-Host "[$client] $($addon.Name): $($problems -join '; ')" -ForegroundColor Yellow }
            else { Write-Host "[$client] $($addon.Name): ok" -ForegroundColor Green }
            continue
        }
        if (-not $problems.Count) { Write-Host "[$client] $($addon.Name): ok"; continue }

        # Clear what is there: links are deleted, real content is backed up.
        $item = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType) {
            Remove-Link $item
        } elseif ($item) {
            # Drop the links first so a backup never holds junctions into the repo.
            Get-ChildItem -LiteralPath $dest -Force | Where-Object { Test-IsLink $_ } | ForEach-Object { Remove-Link $_ }
            # Anything left is real (an old packaged copy, or a stale hard link that may be the
            # newer side): keep it.
            if (Get-ChildItem -LiteralPath $dest -Force) { Move-ToBackup $dest $addOnsPath }
        }

        if ($addon.Whole) {
            New-Item -ItemType Junction -Path $dest -Target $addon.RepoPath | Out-Null
        } else {
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            foreach ($name in $wanted.Keys) {
                $w = $wanted[$name]
                $type = if ($w.Dir) { 'Junction' } else { $fileLinkType }
                New-Item -ItemType $type -Path (Join-Path $dest $name) -Target $w.Path | Out-Null
            }
        }
        Write-Host "[$client] $($addon.Name): linked" -ForegroundColor Green
    }
}

if ($Check -and $bad) { exit 1 }
