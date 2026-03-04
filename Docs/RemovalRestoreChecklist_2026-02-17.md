# Removal Restore Checklist — 2026-02-17

Purpose: quick, practical checklist to restore any removed symbol/block from cleanup waves without full-file rollback.

Primary inventory source:
- `Docs/RemovalLedger_2026-02-17.md`

---

## Fast Restore Workflow (Selective)

1. Identify symbol/block in `Docs/RemovalLedger_2026-02-17.md`.
2. Open target file and restore only that symbol/block.
3. Parse-check touched file:
   - `luac -p <relative/path/to/file.lua>`
4. In-game verify:
   - `/buggrabber reset`
   - `/reload`
   - test affected feature
   - `/reload` again
5. Add restore note in `FixLog.md` (what was restored and why).

---

## Suggested Restore Source Priority

1. `_savepoints/` snapshots in this repo (closest to current branch behavior).
2. `AzeriteUI_Stock/` equivalent file (for baseline-safe helpers).
3. Previous cleanup entries in `FixLog.md` and this checklist.

---

## Wave 0 Restore Targets

### `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- Restore candidates:
  - `IsSafeBoolean`
  - `GetSpellChargesTuple`
  - commented placeholders `LBG`, `Masque`
  - commented `ACTION_HIGHLIGHT_MARKS` map init
  - commented legacy `UpdateNewAction` block/hook block
- Validation:
  - `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`

### `debug.log`
- Restore only if explicitly needed for local debugging workflow.

---

## Wave 1 Restore Targets

### `Components/ActionBars/Elements/ActionBars.lua`
- `LAB`, `UIHider`, `noop`

### `Components/ActionBars/Elements/StanceBar.lua`
- `math_max`

### `Components/Misc/AlertFrames.lua`
- `table_remove`

### `Components/Misc/ChatFrames.lua`
- `string_format`

### `Components/Misc/Info.lua`
- `math_max`, `math_min`, `table_insert`

### `Components/Misc/TrackerWoW11.lua`
- `UIHider`, `CURRENT_THEME`, `Cache`, `Custom`, `Skins`

### `Components/Misc/VehicleSeat.lua`
- `clearSetPoint`

### `Components/UnitFrames/Tags.lua`
- `math_max`, `string_find`, `c_paleblue`

### `Components/UnitFrames/Units/Player.lua`
- `HasColorPickerEnabled`

### `Components/UnitFrames/Units/PlayerAlternate.lua`
- `HasColorPickerEnabled`

### `Components/UnitFrames/Units/PlayerCastBar.lua`
- `string_gsub`

### Options pages
- `Options/OptionsPages/ActionBars.lua`: `math_floor`, `math_max`
- `Options/OptionsPages/Auras.lua`: `math_floor`, `setoption`
- `Options/OptionsPages/Bags.lua`: `setoption`, `getoption`
- `Options/OptionsPages/Chat.lua`: `setoption`
- `Options/OptionsPages/ExplorerMode.lua`: `setoption`
- `Options/OptionsPages/Info.lua`: `setoption`, `getoption`
- `Options/OptionsPages/Nameplates.lua`: `setoption`
- `Options/OptionsPages/Tooltips.lua`: `setoption`
- `Options/OptionsPages/Tracker.lua`: `setoption`
- `Options/OptionsPages/TrackerVanilla.lua`: `isdisabled`, `setoption`, `getoption`

---

## Wave 2 Restore Targets

### `Components/ActionBars/Elements/StatusBars.lua`
- `RingFrame_UpdateTooltip`

### `Components/Misc/Tooltips.lua`
- `SuppressTooltipBackdrop`

### `Components/Misc/TrackerVanilla.lua`
- `math_min`

### `Components/Misc/TrackerWoW11.lua`
- `DEFAULT_THEME`

### `Components/Misc/VehicleSeat.lua`
- `clearAllPoints`, `setPoint`

### Aura style files
- `Components/UnitFrames/Auras/AuraStyling.lua`: `OnClick`
- `Components/UnitFrames/Auras/Cata/Cata_AuraStyling.lua`: `OnClick`
- `Components/UnitFrames/Auras/Classic/Classic_AuraStyling.lua`: `OnClick`
- `Components/UnitFrames/Auras/Wrath/Wrath_AuraStyling.lua`: `OnClick`

### Unit/Core files
- `Components/UnitFrames/Units/Party.lua`: `string_split`
- `Components/UnitFrames/Units/Raid40.lua`: `LeaderIndicator_PostUpdate`
- `Core/MovableFrameManager.lua`: `createBackdropFrame`
- `Core/Widgets/Popups.lua`: `push`

### Options pages
- `Options/OptionsPages/Auras.lua`: `string_match`
- `Options/OptionsPages/Minimap.lua`: `setter`, `getter`, `setoption`, `getoption`
- `Options/OptionsPages/Tooltips.lua`: `isdisabled`
- `Options/OptionsPages/Tracker.lua`: `isdisabled`

---

## Batch Parse-Check Commands

Use this after restoring multiple symbols:

```powershell
Set-Location "c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI"
$files = @(
  "Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua",
  "Components/ActionBars/Elements/ActionBars.lua",
  "Components/ActionBars/Elements/StanceBar.lua",
  "Components/ActionBars/Elements/StatusBars.lua",
  "Components/Misc/AlertFrames.lua",
  "Components/Misc/ChatFrames.lua",
  "Components/Misc/Info.lua",
  "Components/Misc/Tooltips.lua",
  "Components/Misc/TrackerVanilla.lua",
  "Components/Misc/TrackerWoW11.lua",
  "Components/Misc/VehicleSeat.lua",
  "Components/UnitFrames/Tags.lua",
  "Components/UnitFrames/Auras/AuraStyling.lua",
  "Components/UnitFrames/Auras/Cata/Cata_AuraStyling.lua",
  "Components/UnitFrames/Auras/Classic/Classic_AuraStyling.lua",
  "Components/UnitFrames/Auras/Wrath/Wrath_AuraStyling.lua",
  "Components/UnitFrames/Units/Player.lua",
  "Components/UnitFrames/Units/PlayerAlternate.lua",
  "Components/UnitFrames/Units/PlayerCastBar.lua",
  "Components/UnitFrames/Units/Party.lua",
  "Components/UnitFrames/Units/Raid40.lua",
  "Core/MovableFrameManager.lua",
  "Core/Widgets/Popups.lua",
  "Options/OptionsPages/ActionBars.lua",
  "Options/OptionsPages/Auras.lua",
  "Options/OptionsPages/Bags.lua",
  "Options/OptionsPages/Chat.lua",
  "Options/OptionsPages/ExplorerMode.lua",
  "Options/OptionsPages/Info.lua",
  "Options/OptionsPages/Minimap.lua",
  "Options/OptionsPages/Nameplates.lua",
  "Options/OptionsPages/Tooltips.lua",
  "Options/OptionsPages/Tracker.lua",
  "Options/OptionsPages/TrackerVanilla.lua"
)
$failed = @()
foreach ($f in $files) {
  if (Test-Path $f) {
    luac -p $f
    if ($LASTEXITCODE -ne 0) { $failed += $f }
  }
}
if ($failed.Count -eq 0) { "restore-parse-ok" } else { "restore-parse-failed"; $failed }
```

---

## Notes

- This checklist intentionally excludes deleting legacy/version-specific branches.
- If a restore is needed for one WoW branch only, guard it with existing branch checks instead of broad reintroduction.
