# Removal Ledger — 2026-02-17

Purpose: exhaustive log of cleanup removals to enable targeted restore if required.

Scope constraints used during cleanup:
- Removed only symbols/blocks identified as unused/dead in current code paths.
- Preserved version-gated legacy branches/functions (`ns.IsClassic`, `ns.WoW11`, etc.).

## Wave 0 (initial safe cleanup)

### LibActionButton and root artifacts
- Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua
  - Removed local helper: `IsSafeBoolean`
  - Removed local helper: `GetSpellChargesTuple`
  - Removed commented placeholders: `LBG`, `Masque`
  - Removed commented map init: `lib.ACTION_HIGHLIGHT_MARKS = ...`
  - Removed commented legacy block:
    - `ClearNewActionHighlight(...)`
    - hooksecurefunc blocks for `MarkNewActionHighlight` / `ClearNewActionHighlight`
    - `UpdateNewAction(...)`
- debug.log
  - Removed stale non-runtime log file.

## Wave 1 (aggressive alias/function pruning)

### Components
- Components/ActionBars/Elements/ActionBars.lua
  - Removed unused local: `LAB` (replaced by direct `LibStub(LAB_Name)` side-effect init)
  - Removed unused local: `UIHider`
  - Removed unused local: `noop`
- Components/ActionBars/Elements/StanceBar.lua
  - Removed unused local: `math_max`
- Components/Misc/AlertFrames.lua
  - Removed unused local: `table_remove`
- Components/Misc/ChatFrames.lua
  - Removed unused local: `string_format`
- Components/Misc/Info.lua
  - Removed unused locals: `math_max`, `math_min`, `table_insert`
- Components/Misc/TrackerWoW11.lua
  - Removed unused local: `UIHider`
  - Removed unused locals: `CURRENT_THEME`, `Cache`, `Custom`, `Skins`
- Components/Misc/VehicleSeat.lua
  - Removed unused local helper function: `clearSetPoint`
- Components/UnitFrames/Tags.lua
  - Removed unused locals: `math_max`, `string_find`, `c_paleblue`
- Components/UnitFrames/Units/Player.lua
  - Removed unused local helper function: `HasColorPickerEnabled`
- Components/UnitFrames/Units/PlayerAlternate.lua
  - Removed unused local helper function: `HasColorPickerEnabled`
- Components/UnitFrames/Units/PlayerCastBar.lua
  - Removed unused local: `string_gsub`

### Options
- Options/OptionsPages/ActionBars.lua
  - Removed unused locals: `math_floor`, `math_max`
- Options/OptionsPages/Auras.lua
  - Removed unused local: `math_floor`
  - Removed unused local helper function: `setoption`
- Options/OptionsPages/Bags.lua
  - Removed unused local helper functions: `setoption`, `getoption`
- Options/OptionsPages/Chat.lua
  - Removed unused local helper function: `setoption`
- Options/OptionsPages/ExplorerMode.lua
  - Removed unused local helper function: `setoption`
- Options/OptionsPages/Info.lua
  - Removed unused local helper functions: `setoption`, `getoption`
- Options/OptionsPages/Nameplates.lua
  - Removed unused local helper function: `setoption`
- Options/OptionsPages/Tooltips.lua
  - Removed unused local helper function: `setoption`
- Options/OptionsPages/Tracker.lua
  - Removed unused local helper function: `setoption`
- Options/OptionsPages/TrackerVanilla.lua
  - Removed unused local helper functions: `isdisabled`, `setoption`, `getoption`

## Wave 2 (aggressive wave with legacy preservation)

### Components
- Components/ActionBars/Elements/StatusBars.lua
  - Removed unused local helper function: `RingFrame_UpdateTooltip`
- Components/Misc/Tooltips.lua
  - Removed unused local helper function: `SuppressTooltipBackdrop`
- Components/Misc/TrackerVanilla.lua
  - Removed unused local: `math_min`
- Components/Misc/TrackerWoW11.lua
  - Removed unused local: `DEFAULT_THEME`
- Components/Misc/VehicleSeat.lua
  - Removed unused locals: `clearAllPoints`, `setPoint`
- Components/UnitFrames/Auras/AuraStyling.lua
  - Removed unused local helper function: `OnClick`
- Components/UnitFrames/Auras/Cata/Cata_AuraStyling.lua
  - Removed unused local helper function: `OnClick`
- Components/UnitFrames/Auras/Classic/Classic_AuraStyling.lua
  - Removed unused local helper function: `OnClick`
- Components/UnitFrames/Auras/Wrath/Wrath_AuraStyling.lua
  - Removed unused local helper function: `OnClick`
- Components/UnitFrames/Units/Party.lua
  - Removed unused local: `string_split`
- Components/UnitFrames/Units/Raid40.lua
  - Removed unused local helper function: `LeaderIndicator_PostUpdate`

### Core
- Core/MovableFrameManager.lua
  - Removed unused local helper function: `createBackdropFrame`
- Core/Widgets/Popups.lua
  - Removed unused local helper function: `push`

### Options
- Options/OptionsPages/Auras.lua
  - Removed unused local: `string_match`
- Options/OptionsPages/Minimap.lua
  - Removed unused local helper functions: `setter`, `getter`, `setoption`, `getoption`
- Options/OptionsPages/Tooltips.lua
  - Removed unused local helper function: `isdisabled`
- Options/OptionsPages/Tracker.lua
  - Removed unused local helper function: `isdisabled`

## Restore Guidance

If restoration is needed:
1. Restore specific symbol/block from this ledger only (avoid broad rollback).
2. Re-run syntax check for touched file(s):
   - `luac -p <file>`
3. In-game verify with `/reload` loop and BugSack/BugGrabber.
4. Record the restore in `FixLog.md` with exact symbol(s) restored.

Potential source material for restore snippets:
- Recent local history/savepoints under `_savepoints/`
- Parallel addon baseline in `AzeriteUI_Stock/` for equivalent files
- This ledger + `FixLog.md` entries for context
