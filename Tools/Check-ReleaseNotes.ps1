param(
    [string]$ChangelogPath = (Join-Path $PSScriptRoot '..\CHANGELOG.md')
)

$ErrorActionPreference = 'Stop'

# GitHub previously rejected the release body at 125000 characters. Leave
# room for the packager's heading and links, and check before any upload.
$MaximumCharacters = 120000
$Notes = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ChangelogPath).Path)
if ($Notes.Length -gt $MaximumCharacters) {
    throw "Release notes contain $($Notes.Length) characters (budget: $MaximumCharacters). Move older complete releases to CHANGELOG_ARCHIVE.md and regenerate Options/Changelog.lua before packaging."
}

Write-Host "Release notes: $($Notes.Length)/$MaximumCharacters characters."
