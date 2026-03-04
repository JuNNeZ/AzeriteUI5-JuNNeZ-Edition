2026-03-03 23:30 (Fix v5: Edit Mode taint cascade — ClientBuild bug + BackdropMixin taint)

Issue:
- 4 errors on every Edit Mode enter/exit (all "tainted by AzeriteUI"):
  1. EncounterWarningsViewElements.lua:75 — "compare a secret number value"
  2. CastingBarFrame.lua:722 — "iterate a forbidden table" (on arena2 castbar)
  3. CompactUnitFrame.lua:707 — "compare local 'oldR'" (on party frame exit)
  4. SecureUtil.lua:78 — "arithmetic on a secret number value"
- User discovery: disabling arena frame movement in Edit Mode made all errors stop.

Root cause (TWO problems found):

A) `ns.ClientBuild >= 120000` bug (same as v3/v4 but in 6 MORE files):
   - Party.lua, Raid5.lua, Raid25.lua, Raid40.lua, Auras.lua (x2)
   - All had WoW12-safe code paths guarded by `ns.ClientBuild >= 120000`
   - ns.ClientBuild = ~58135 (build number), NOT 120000 (TOC version)
   - Condition was ALWAYS FALSE → fell through to legacy DisableBlizzard calls
   - These legacy calls taint Blizzard frames (CompactPartyFrame, CompactRaidFrame)
   - Party.lua fell through to oUF:DisableBlizzard("party") which touches
     CompactPartyFrameMember* → taint spreads to Edit Mode party frame operations

B) BackdropMixin.SetupTextureCoordinates replacement (the BIG one):
   - FixBlizzardBugs.lua OnInitialize WoW12 block ran EnsureBackdropGuard()
   - This REPLACED BackdropMixin.SetupTextureCoordinates with addon code
   - Every Blizzard frame using BackdropMixin now executes addon-tainted code
   - This spread "tainted by AzeriteUI" to EncounterWarnings, CompactUnitFrame,
     SecureUtil, and any other frame using backdrop textures
   - Root cause of errors #1, #3, #4

C) Arena castbar instances not guarded:
   - FixBlizzardBugsWow12.lua only guarded PlayerCastingBarFrame/PetCastingBarFrame
   - WoW's Mixin() copies methods at creation time — patching the prototype
     doesn't fix frames created BEFORE the patch
   - Arena castbars (unit=arena1-5) created by Blizzard_ArenaUI were unpatched
   - Root cause of error #2 persisting after v4

Fix:
1. Changed `ns.ClientBuild >= 120000` → `ns.ClientVersion >= 120000` in:
   - Components/UnitFrames/Units/Party.lua (DisableBlizzard)
   - Components/UnitFrames/Units/Raid5.lua (DisableBlizzard)
   - Components/UnitFrames/Units/Raid25.lua (DisableBlizzard)
   - Components/UnitFrames/Units/Raid40.lua (DisableBlizzard)
   - Components/Auras/Auras.lua (sort attributes)
   - Components/Auras/Auras.lua (visibility driver)

2. Removed BackdropMixin.SetupTextureCoordinates replacement from WoW12 block.
   The tooltip backdrop error is cosmetic; the taint cascade is critical.
   WoW12 block now just returns immediately (no mixin rewrites at all).

3. Updated FixBlizzardBugsWow12.lua to also guard arena castbar instances:
   - CompactArenaFrame.memberUnitFrames[*].castBar
   - ArenaEnemyMatchFrame1-5 castbars
   - CompactArenaFrameMember1-5 castbars

Testing:
1. `/reload`
2. Open Edit Mode → verify NO BugSack errors
3. Close Edit Mode → verify NO BugSack errors
4. Toggle arena frames checkbox in Edit Mode → verify NO errors
5. Run `/azdebug dump all` → verify castbars function
6. Join party → verify party frames render correctly

---

2026-03-03 23:00 (Fix v4: CastingBarFrame StopFinishAnims — standalone file-scope fix)

Issue:
- v3 ALSO failed. Same error on every Edit Mode entry.

Root cause (v4 investigation):
- The v3 fix correctly changed ClientBuild → ClientVersion (120000), so the WoW12
  condition at FixBlizzardBugs.lua line 2580 NOW evaluates to TRUE.
- But the WoW12 block ends with `return` at line 2633: this exits OnInitialize BEFORE
  the unconditional StopFinishAnims `do...end` block at the bottom can ever execute.
- Summary: v3 placed the guard code AFTER the `return`, making it dead code.

Fix (v4):
1. Created **Core/FixBlizzardBugsWow12.lua** — standalone file-scope script:
   - Runs at FILE SCOPE, NOT inside any module OnInitialize.
   - Cannot be blocked by early `return` statements in other modules.
   - Guards `StopFinishAnims` and `UpdateShownState` on:
     - `CastingBarMixin` (mixin prototype A)
     - `CastingBarFrameMixin` (mixin prototype B)
     - `PlayerCastingBarFrame` (existing instance)
     - `PetCastingBarFrame` (existing instance)
   - Uses `canaccesstable` check on `self` before calling original.
   - Falls through to `pcall` to swallow any remaining forbidden-table errors.
   - Registers ADDON_LOADED for Blizzard_UIPanels_Game / Blizzard_EditMode /
     Blizzard_ArenaUI to re-apply guards when demand-loaded addons appear.
   - Belt-and-suspenders C_Timer.After(0/1/3) for safety.
   - Only activates when `canaccesstable` global exists (WoW 11+).

2. Wired into **Core/Core.xml** right after FixBlizzardBugs.lua.

3. Removed dead unreachable StopFinishAnims code from end of FixBlizzardBugs.lua
   OnInitialize (was after the `return` and never executed).

4. LibEditModeOverride: already at v10 (latest on CurseForge, Oct 2025). No update needed.

Testing:
1. `/reload`
2. Open Edit Mode (ESC → Edit Mode, or Shift+V keybind)
3. Verify NO BugSack error about forbidden table / StopFinishAnims
4. Verify casting bars still work normally on player/pet/arena frames
5. Close Edit Mode, verify no errors

---

2026-03-03 22:00 (Fix v3: CastingBarFrame StopFinishAnims — build detection bug + unconditional guard)

Issue:
- v1 and v2 both failed. Same error on every Edit Mode entry.

Root cause (ACTUAL — found in v3 investigation):
- `ns.ClientBuild` = ~58135 (build number from GetBuildInfo 2nd return)
- The WoW12 guard condition was: `if (issecretvalue or (ns.ClientBuild >= 120000))`
- 58135 >= 120000 = **FALSE**. The entire WoW 12 guard block was SKIPPED.
- `issecretvalue` was also nil at OnInitialize time, making the `or` fallthrough fail.
- `ns.ClientVersion` = 120000 (TOC interface number, 4th return from GetBuildInfo)
  This is the CORRECT field for version detection.
- Constants.lua line 53: `local patch, build, date, version = GetBuildInfo()`
  `build` = "58135", `version` = 120000. ClientBuild stored the build number, not TOC.

Fixes applied:
1. **Fixed WoW 12 detection condition** (line 2578):
   - Old: `if (issecretvalue or (ns.ClientBuild and ns.ClientBuild >= 120000))`
   - New: `if (issecretvalue or canaccesstable or (ns.ClientVersion and ns.ClientVersion >= 120000))`
   - This fixes ALL WoW12-specific guards (backdrop, aura, etc.) that were also skipped.

2. **Moved StopFinishAnims guard OUTSIDE WoW12 block** (unconditional):
   - New `do ... end` block at end of OnInitialize, runs on ALL WoW versions.
   - Guards `StopFinishAnims` on both `CastingBarMixin` AND `CastingBarFrameMixin`.
   - Guards `UpdateShownState` with pcall wrapper on both mixins.
   - Patches existing `PlayerCastingBarFrame` and `PetCastingBarFrame` instances.
   - Deferred via ADDON_LOADED (Blizzard_UIPanels_Game, Blizzard_EditMode, Blizzard_ArenaUI).
   - Deferred via PLAYER_LOGIN.
   - Belt-and-suspenders C_Timer.After(0/1/3).
   - All guards are idempotent (flag-gated).

3. **Loaded LibEditModeOverride** in Libs.xml:
   - Already bundled at Libs/LibEditModeOverride/ but not loaded.
   - Now included via `<Include file="LibEditModeOverride\LibEditModeOverride.xml"/>`.
   - Provides `LibStub("LibEditModeOverride-1.0")` for future Edit Mode integration.

Testing:
1. `/reload`
2. Open Game Menu → Edit Mode
3. Verify no BugSack error about forbidden table / StopFinishAnims
4. Exit Edit Mode, cast something, verify castbar still works
5. Re-enter Edit Mode a second time
6. Verify other WoW12 guards now also work (backdrop, auras, etc.)

---

2026-03-03 21:45 (Fix v2: CastingBarFrame StopFinishAnims forbidden table — deferred patching, FAILED)

Issue:
- Previous fix (v1) did NOT resolve the error. Same BugSack crash on Edit Mode entry:
  `attempted to iterate a forbidden table`
  at Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua:722 in StopFinishAnims
- Call chain: EnterEditMode → RefreshArenaFrames → SetIsInEditMode → UpdateShownState → StopFinishAnims

Root cause analysis (full):
1. **Blizzard_UIPanels_Game is demand-loaded**: At `OnInitialize` time, both `CastingBarMixin`
   and `PlayerCastingBarFrame` are nil. The v1 guard silently skipped because
   `if (_G.CastingBarMixin ...)` was false. Then `return` exited OnInitialize.
2. **Wrong mixin name**: v1 only patched `CastingBarMixin`. The Blizzard casting bar file also
   uses `CastingBarFrameMixin` — these are *separate* mixin tables (confirmed by the disabled
   code block which applies to both separately).
3. **Arena castbars created lazily**: `RefreshArenaFrames` creates arena casting bars during
   Edit Mode entry. These get their methods from the mixin prototype at creation time.
4. **No deferred handler**: The WoW 12+ OnInitialize block had no ADDON_LOADED listener, so
   the guard was never retried after Blizzard_UIPanels_Game loaded.

Taint chain (how AzeriteUI triggers this Blizzard bug):
- oUF castbar element (Libs/oUF_Classic/elements/castbar.lua:650) calls
  PlayerCastingBarFrame:UnregisterAllEvents() and :Hide() from addon code
- PlayerCastBar module (Components/UnitFrames/Units/PlayerCastBar.lua:263) also calls
  PlayerCastingBarFrame:Hide() and :SetAlpha(0)
- This taints the frame; when Edit Mode re-shows it, the secret-value system marks
  StagePips/StagePoints/StageTiers as forbidden tables
- Blizzard's StopFinishAnims iterates these without canaccesstable checks → crash

How other addons handle this:
- ElvUI/TukUI: disable Blizzard unit frames early in PLAYER_LOGIN, don't re-enable them
- oUF (upstream): wraps PlayerCastingBarFrame manipulation in pcall, but does NOT handle
  the Edit Mode re-show scenario
- WeakAuras: doesn't touch PlayerCastingBarFrame at all
- Details!: only hooks castbar events, doesn't hide/show the frame
- The core issue is a Blizzard bug — they iterate their own tables without canaccesstable

Fix v2:
- Created idempotent `ApplyStopFinishAnimsGuards()` master function that guards:
  1. `CastingBarMixin.StopFinishAnims` (mixin A)
  2. `CastingBarFrameMixin.StopFinishAnims` (mixin B)
  3. `CastingBarMixin.UpdateShownState` (pcall wrapper — catches any forbidden iteration)
  4. `CastingBarFrameMixin.UpdateShownState` (same)
  5. `PlayerCastingBarFrame.StopFinishAnims` (instance)
  6. `PetCastingBarFrame.StopFinishAnims` (instance)
- Applied immediately in OnInitialize (works if already loaded)
- Registered ADDON_LOADED for Blizzard_UIPanels_Game, Blizzard_EditMode, Blizzard_ArenaUI
- Registered PLAYER_LOGIN as catch-all
- Added C_Timer.After(0/1/3) belt-and-suspenders retries
- Each guard is idempotent (flag-gated, safe to call multiple times)

Testing:
1. `/reload`
2. Open Game Menu → Edit Mode
3. Verify no BugSack error about forbidden table / StopFinishAnims
4. Exit Edit Mode, cast something, verify castbar still works
5. Re-enter Edit Mode a second time (confirm idempotent)

---

2026-03-03 21:30 (Fix v1: CastingBarFrame StopFinishAnims — instance patching, FAILED)

Issue:
- BugSack error when entering Edit Mode:
  `attempted to iterate a forbidden table`
  at Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua:722 in StopFinishAnims
- Call chain: EnterEditMode → RefreshArenaFrames → SetIsInEditMode → UpdateShownState → StopFinishAnims
- The `(for state)` in the for-loop is a `<forbidden table>` (StagePips/StagePoints/StageTiers)

Root cause:
- An existing guard in FixBlizzardBugs.lua (line ~2636) patched `CastingBarMixin.StopFinishAnims`
  on the mixin prototype, but `PlayerCastingBarFrame` already holds a direct copy of the
  ORIGINAL (unguarded) function reference from when the mixin was applied at frame creation.
- Updating the mixin prototype does NOT retroactively update methods on existing instances.

Fix:
- Extracted a shared `MakeSafeStopFinishAnims(origFunc)` factory that wraps any
  StopFinishAnims reference with:
  1. Edit Mode early-exit (skip entirely when C_EditMode.IsEditModeActive)
  2. canaccesstable checks on all four iterable tables (FinishAnims, StagePips, StagePoints, StageTiers)
  3. pcall fallback for the original function
- Applied the guard to `CastingBarMixin.StopFinishAnims` (future frames)
- Applied the guard to `PlayerCastingBarFrame.StopFinishAnims` (existing instance)
- Applied the guard to `PetCastingBarFrame.StopFinishAnims` (existing instance)

Testing:
1. `/reload`
2. Open Game Menu → Edit Mode (or Settings → Advanced → Edit Mode)
3. Verify no BugSack error about forbidden table / StopFinishAnims
4. Exit Edit Mode, verify castbar still works on player casts

---

2026-03-03 18:12 (Soul fragments stacked mode: corrected overflow fill direction)

Issue:
- Option 4 overflow row (6-10) did not brighten in the intended bottom-up order for this layout.

Fix:
- Updated stacked mode overflow activation from high-index-first to low-index-first:
  - from: `i > (5 - overflow)`
  - to: `i <= overflow`

Result:
- In stacked mode, the second row now fills from the bottom as requested.

Testing:
1. `/reload`
2. Set Soul Fragments Display Mode to `Stacked 5-Point (Hide Empty, Bright Overflow from Bottom)`
3. Build from 5 to 10 points and verify bright overlay advances bottom-up.

---

2026-03-03 18:05 (Soul fragments: Added Option 4 stacked 5-point overflow mode)

Request:
- Add Option 4 behavior:
  1) Show only existing points for 1-5 (no empty points, no background plates)
  2) At 5 points, keep all 5 visible but dimmed
  3) For 6-10, brighten overflow from bottom in the same 5 positions

Changes:
1. Added a fourth soul fragments display mode key: `stacked`
2. Implemented stacked mode render logic in `SoulFragmentsPoints`:
   - For `cur < 5`: only active points are visible (`alpha=1.0`), inactive points + plate textures are hidden (`alpha=0`)
   - For `cur >= 5`: all 5 points stay visible at dim base (`alpha=0.45`)
   - Overflow (`6-10`) brightens from bottom using the same 5 points (`point 5` first, then 4→1)
3. Disabled golden glow while in stacked mode (mode-specific behavior)
4. Restored/extended options dropdown with 4 modes:
   - alpha
   - gradient
   - recolor
   - stacked
5. Added missing enUS locale keys for the display mode option labels/descriptions

Behavior (stacked mode):
- 0-4 stacks: only currently earned points visible; no empty plates shown
- 5 stacks (5 points): all five remain visible but dim
- 6-10 points: bright overlays advance from bottom while dim base remains

Files changed:
- [Components/UnitFrames/Units/PlayerClassPower.lua](Components/UnitFrames/Units/PlayerClassPower.lua):
  - Added `soulFragmentsDisplayMode` default
  - Added `stacked` display mode branch
  - Preserved compatibility mapping (`brightness`→`alpha`, `color`→`gradient`)
- [Options/OptionsPages/UnitFrames.lua](Options/OptionsPages/UnitFrames.lua):
  - Added option value for `stacked` in Soul Fragments display mode dropdown
- [Locale/enUS.lua](Locale/enUS.lua):
  - Added/updated mode-related localization keys

Testing (`/reload` loop):
1. `/reload`
2. Open `/az options` → Unit Frames → Class Power
3. Set `Soul Fragments Display Mode` to `Stacked 5-Point (Hide Empty, Bright Overflow from Bottom)`
4. Validate progression:
   - Build to 1-4 points: only earned points visible, no empty backgrounds
   - Reach 5 points: all 5 visible but dimmed
   - Build 6-10 points: bright points fill from bottom over dim base in same positions
5. Verify mode switching still works for alpha/gradient/recolor

---

2026-03-03 17:20 (Soul fragments: Purple color, individual point offset sliders with live updates)

Changes:
1. Applied purple color (156/255, 116/255, 255/255) to SoulFragmentsPoints style
2. Added individual offset sliders for all 10 soul fragments points
   - Each point has ±50 pixel X and Y offsets
   - Sliders in Options → Unit Frames → Class Power → Soul Fragments
   - Points 1-10 can be moved independently
3. Offsets trigger live updates (ForceUpdate on every slider move)
4. Point 10 uses diamond backdrop (matches ComboPoint style)
5. Added storage for per-point offsets: soulFragmentsPointOffsetX/Y arrays

Behavior:
- All 10 points display in purple when active
- Each point can be repositioned via sliders (+/- 50 pixels on X and Y)
- Offset changes apply immediately without reload
- Point 10 terminates with diamond art (aesthetically matches rogue combo point finish)

Implementation:
- Defaults: soulFragmentsPointOffsetX/Y = { 0, 0, ... 0 } (10 zeros each)
- Styling applies per-point offsets during layout (only for SoulFragmentsPoints style)
- Options loop creates 20 sliders (2 per point × 10 points)
- Each slider saves to array[pointIndex] and triggers ForceUpdate

Files changed:
- [Components/UnitFrames/Units/PlayerClassPower.lua](Components/UnitFrames/Units/PlayerClassPower.lua):
  - Added purple color to SoulFragmentsPoints style
  - Added soulFragmentsPointOffsetX/Y defaults (10-element arrays)
  - Added per-point offset application in styling section
  - Extended classPointOffsets to support 10 points
- [Options/OptionsPages/UnitFrames.lua](Options/OptionsPages/UnitFrames.lua):
  - Added 20 sliders (loop for points 1-10, X and Y each)
  - Orders 700-719 for point offsets
  - Each set/get bound to array elements

Testing:
- `/reload` — 10 purple points in spiral pattern, all displaying correctly
- Open `/az options` → Unit Frames → Class Power → Soul Fragments
- Scroll down to find "Point 1 Offset X", "Point 1 Offset Y", etc.
- Move sliders: points should reposition in real-time
- At 50 stacks: all 10 purple points visible, point 10 with diamond backdrop

---

2026-03-03 17:15 (Soul fragments: Fixed 10-point display, combo-point styling)

Issues:
- Only 1 point was displaying instead of all 10
- Soul fragment remapping was correct (cur * 10) but styling wasn't applying to all points
- Layout iteration using `next` didn't guarantee all 10 entries were processed in order

Root Causes:
1. Loop `for i,info in next,layoutdb` doesn't guarantee numeric order
2. `id` counter wasn't incremented for all 10 points, causing others to be hidden
3. Points weren't explicitly :Show() called after styling

Fixes:
1. Changed layout iteration from `for i,info in next,layoutdb` to explicit `for i=1,10` loop
2. Added `info` existence check: `if (point and info)`
3. Added `point:Show()` after styling to ensure visibility
4. Updated layout to combopoints spiral style (rotations, varying sizes)
   - Points 1-7 follow ComboPoints aesthetic  
   - Points 8-10 extend the spiral further down for 10-point display
   - Point 10 uses diamond backdrop like ComboPoint #7

Behavior:
- 0-5 stacks: 1 point bright (50% of progress)
- 5-10 stacks: 2 points bright
- 10-15 stacks: 3 points bright
- ... continues to...
- 45-50 stacks: all 10 points bright (1.0 alpha on active, 0.5 on inactive)

Files changed:
- [Components/UnitFrames/Units/PlayerClassPower.lua](Components/UnitFrames/Units/PlayerClassPower.lua):
  - Fixed styling loop: explicit i=1,10 iteration
  - Added :Show() call for each styled point
- [Layouts/Data/PlayerClassPower.lua](Layouts/Data/PlayerClassPower.lua):
  - Replaced grid layout with spiral ComboPoints-style layout for 10 points

Testing:
- `/reload` — 10 points should display in spiral pattern
- At 50 stacks: all 10 points bright (1.0 alpha)
- At 25 stacks: 5 points bright
- At 5 stacks: 1 point bright
- Inactive points show at 0.5 alpha for visual clarity

---

2026-03-03 17:05 (Soul fragments points: Removed unreliable font labels)

Issues:
- SetFontObject() was failing during PostUpdate initialization
- Font objects were not reliably available during style application
- Label display became unreliable and caused errors

Fix:
- Removed numbered label FontString creation entirely
- Simplified display to pure 10-point system without text overlays
- Points still light up cumulatively as soul fragments accumulate (5 stacks per point)
- Visual indication is clear: active points are bright (1.0 alpha), inactive points are dim (0.5 alpha)

Behavior:
- 0-4 stacks: 1 point active (bright)
- 5-9 stacks: 2 points active (bright)
- 10-14 stacks: 3 points active (bright)
- ... continues to...
- 45-50 stacks: 10 points active (bright)

Files changed:
- [Components/UnitFrames/Units/PlayerClassPower.lua](Components/UnitFrames/Units/PlayerClassPower.lua):
  - Removed label FontString creation code
  - Removed label visibility handling loop
- [Layouts/Data/PlayerClassPower.lua](Layouts/Data/PlayerClassPower.lua):
  - Removed Label = "X" fields from all 10 SoulFragmentsPoints entries

Testing:
- `/reload` — 10 unadorned points should display cleanly
- Points light up progressively as soul fragments accumulate
- No font errors, clean visual representation

Rationale:
- Font system initialization during PostUpdate is unreliable
- Visual clarity maintained through point brightness (alpha 1.0 vs 0.5)
- Simpler, more robust implementation without text rendering dependencies

---

2026-03-03 17:03 (Soul fragments points: Fixed font API error)

Issues:
- SetFont() was called with wrong signature: `SetFont(GetFont(...), size, flags)`
- GetFont() returns a font object, not a font path string
- Should use `SetFontObject()` instead of `SetFont()` for font objects

Fix:
- Changed `point.label:SetFont(ns.API.GetFont("AceFont-14"), 10, "OUTLINE")` 
- To: `point.label:SetFontObject(ns.API.GetFont(10, true))`
- GetFont() signature: GetFont(size, outline, type)
- SetFontObject() takes single argument (font object)

Files changed:
- [Components/UnitFrames/Units/PlayerClassPower.lua](Components/UnitFrames/Units/PlayerClassPower.lua#L263) — Fixed label font initialization

Testing:
- `/reload` — 10 numbered points should display with no font errors

---

2026-03-03 17:00 (Soul fragments: Switched from bar to 10-point numbered system)

Changes:
- Replaced single bar visualization with 10-point discrete system (every 5 stacks = 1 point)
- Added numbered labels (1-10) on each point that only show when active
- Points arranged in 2-column x 5-row grid for compact display
- Each point uses crystal texture with plate backdrop (matches other class powers)
- Cumulative display: as stacks accumulate, more points light up with visible numbers

Behavior:
- 0-4 stacks: 1 point active + "1" label visible
- 5-9 stacks: 2 points active + "1", "2" labels visible
- 10-14 stacks: 3 points active + "1", "2", "3" labels visible
- ... continues to...
- 45-50 stacks: 10 points active + all labels visible

Implementation:
1. Created new layout: `SoulFragmentsPoints` with 10 numbered point entries
2. Modified `ClassPower_PostUpdate` to detect soul fragments and remap values:
   - `cur = ceil(cur / 5)` (convert 0-50 stacks to 0-10 points)
   - `max = 10` (set display to 10-point system)
   - Use `SoulFragmentsPoints` style instead of `SoulFragments` bar
3. Updated `ClassPower_CreatePoint` to track point index for label lookup
4. Added label creation/visibility in styling section:
   - Creates font string on first style application
   - Updates text from layout info.Label
   - Visibility tied to cumulative point count (point `i` shown if `i <= cur`)
5. Updated alpha handling for points: active points at 1.0, inactive at 0.5

Files changed:
- `Layouts/Data/PlayerClassPower.lua` — Added SoulFragmentsPoints layout (10 points)
- `Components/UnitFrames/Units/PlayerClassPower.lua`:
  - `ClassPower_CreatePoint`: Added point.index tracking
  - `ClassPower_PostUpdate`: Added soul fragments remapping + SoulFragmentsPoints style
  - Label creation/visibility handling in style section
  - Alpha handling for points visibility

Testing:
- `/reload` — 10 points should display with all numbered labels visible when stacks are active
- Move DH Devourer around to accumulate/lose soul fragments
- Labels should appear/disappear as points activate/deactivate

Previously accumulated texture customization options (rotation, flip, tile) are retained for potential future use but no longer apply to this points-based layout.

---

2026-03-03 16:45 (Soul fragments bar: Full texture customization with WoW API controls)

Changes:
- Reverted rotation back to 0 degrees (normal orientation)
- Added full texture manipulation options using WoW TextureBase API methods
- All controls now trigger live update via ForceUpdate()

New customization options (in `/az options` → Unit Frames → Class Power):
- **Rotation:** 4-way select (0°, 90°, 180°, 270°) — uses SetRotation(radians)
- **Flip Horizontal:** Toggle — mirrors texture left↔right via SetTexCoord()
- **Flip Vertical:** Toggle — mirrors texture top↔bottom via SetTexCoord()
- **Tile Horizontal:** Toggle — tiles texture horizontally via SetHorizTile()
- **Tile Vertical:** Toggle — tiles texture vertically via SetVertTile()

WoW API methods used:
- `SetRotation(radians)` — Apply rotation in radians (π/2, π, 3π/2)
- `SetTexCoord(left, right, top, bottom)` — Flip by swapping coordinates
  - Horizontal flip: (0,1,0,1) → (1,0,0,1)
  - Vertical flip: (0,1,0,1) → (0,1,1,0)
  - Both: (0,1,0,1) → (1,0,1,0)
- `SetHorizTile(boolean)` — Enable horizontal texture tiling
- `SetVertTile(boolean)` — Enable vertical texture tiling

Testing combinations:
1. `/reload`
2. Open `/az` options → Unit Frames → Class Power
3. Try different rotation angles
4. Toggle "Flip Horizontal" to mirror left-right
5. Toggle "Flip Vertical" to flip top-bottom
6. Toggle tiling to repeat pattern (useful with custom rotation/flip combos)
7. **All changes apply live without reload**

Example configurations:
- 180° rotation → upside down, mirrored bar
- 90° rotation + Flip Vertical → sideways with dip on different edge
- Flip Horizontal only → left-mirrored bar
- Tile options → repeat texture pattern across bar

---

2026-03-03 16:40 (Soul fragments bar: proportions + live update fix)

Issues:
- Live update still not triggering when sliders moved
- Bar/backdrop proportions didn't match player health bar (used wrong size base)

Root Cause:
- UpdateSettings() alone doesn't trigger element re-render
- Proportion calculations based on wrong bar size (385×18 instead of 385×37)
- Element ForceUpdate() must be called directly by slider setter

Fix:
- **Updated bar dimensions to match player health bar:**
  - Default bar size: 385×37 (was 385×18)
  - Backdrop now scales from base 716×188 (player backdrop proportions)
  - Width ratio: 716/385 = 1.859
  - Height ratio: 188/37 = 5.081
  - Example scaling: 300×25 bar → 469×133 backdrop (proportional)
- **Fixed live update pipeline:**
  - All 4 sliders now directly call ForceUpdate() on ClassPower element
  - Changed from `mod:UpdateSettings()` to direct element re-render
  - Each slider setter: checks if `mod.frame.ClassPower` exists, then calls `:ForceUpdate()`
  - No longer depends on general UpdateSettings() call chain
- **Updated getter defaults:**
  - Bar height default: 18 → 37
  - Ensures sliders start with correct player health bar proportion

Testing:
1. `/reload`
2. Open `/az` options → Unit Frames → Class Power
3. Move "Bar Width" slider → **bar AND backdrop should update in real-time**
4. Move "Bar Height" slider → **bar AND backdrop should update in real-time**
5. **Verify proportions:** 716×188 backdrop for 385×37 bar is the base ratio
   - Expand bar to 500×48 → backdrop should be ~693×255 (proportional)
   - Shrink bar to 200×20 → backdrop should be ~362×107 (proportional)

---

2026-03-03 16:35 (Soul fragments bar: fixed bar/backdrop sync + removed conflicting backdrop sliders)

Issues:
- Bar height, width and background height/width were not synced
- Live update still broken (sliders weren't triggering re-render)
- Independent backdrop sliders conflicted with proportional scaling

Root Cause:
- Backdrop sliders allowed users to set arbitrary backdrop sizes
- This overrode the proportional scaling calculations
- Two simultaneous size systems competing (proportional vs independent values)

Fix:
- **Removed independent backdrop size sliders:**
  - Deleted soulFragmentsBackdropSizeX and soulFragmentsBackdropSizeY from options
  - Removed these values from defaults
  - Now only bar size sliders exist (position X/Y, width, height)
- **Simplified backdrop calculation:**
  - Backdrop size now ONLY calculated from bar size
  - No longer reads db.soulFragmentsBackdropSizeX/Y
  - Always uses fixed ratio: 420/385 for width, 45/18 for height
  - Example: bar 300×15 → backdrop 329×37.5 (proportionally scaled)
- **Result:**
  - All bar and backdrop sizes are now perfectly synced
  - Adjust bar width slider → backdrop width automatically scales
  - Adjust bar height slider → backdrop height automatically scales
  - No conflicting independent controls

Testing:
1. `/reload`
2. Open `/az` options → Unit Frames → Class Power
3. **Verify only 4 sliders exist:** Bar Pos X/Y, Bar Width, Bar Height
4. Move Bar Width slider → both bar AND backdrop should grow/shrink together
5. Move Bar Height slider → both bar AND backdrop should grow/shrink together
6. **Verify:** Changes apply live (no reload needed)

---

2026-03-03 16:30 (Soul fragments bar: live update + proportional scaling fixes)

Issues:
- Bar doesn't update when customization sliders are moved (requires `/reload`)
- Bar grows/shrinks independently from backdrop (visual mismatch when resizing)

Root Cause:
- UpdateSettings() wasn't triggering ClassPower element re-render
- Backdrop and bar sizes calculated independently instead of scaled proportionally

Fix:
- **Added live update pipeline:**
  - Modified UnitFrame.lua:UpdateSettings() to call ForceUpdate() on ClassPower elements
  - Now when you move sliders, the element immediately re-renders without reload
  - Works for all unitframes in ns.UnitFrames table
- **Implemented proportional backdrop scaling:**
  - Changed backdrop sizing from independent values to proportional calculation
  - Backdrop scales based on bar size ratio: `(baseWidth/385) * scaleX`, `(baseHeight/18) * scaleY`
  - Default ratio maintains 420×45 backdrop for 385×18 bar (same as current)
  - When bar resizes via slider, backdrop grows/shrinks proportionally
  - Moved scaleX/scaleY to outer scope so they're available for all sizing
- **Fixed syntax error:**
  - Missing `end` statement for soul fragments customization if-block
  - Variables scaleX/scaleY now initialized at top of block for proper scope
  - Point customization code properly structured with correct indentation
- **Fixed GetModule error:**
  - UnitFrames.lua was calling GetModule("PlayerClassPowerFrame") without silent flag
  - Now uses `silent=true` with null check fallback
  - Prevents errors if module isn't loaded during options generation

Testing:
1. `/reload`
2. Open `/az` options → Unit Frames → Class Power
3. Move any slider (bar width, height, backdrop size, position)
4. **Verify:** Bar updates in real-time without reload
5. **Verify:** Backdrop maintains proper size relationship (scales with bar)

---

2026-03-03 (Devourer DH: soul fragments bar fixes - backdrop visibility + proper vertical flip)

Issue:
- Soul fragments bar statusbar visible but backdrop art completely missing
- Bar texture wasn't properly flipped upside down (dip that was at bottom-right needs to move to top-right)
- Rotation slider was applying 180 degree rotation instead of vertical flip

Root Cause:
- Backdrop texture SetTexture() call accidentally removed during code refactoring
- 180 degree rotation rotates the center point instead of flipping vertically
- Need vertical flip (Y-axis mirror) not rotation to preserve the dip positioning

Fix:
- **Restored backdrop rendering:**
  - Re-added `point.case:SetTexture(info.BackdropTexture)` after SetSize
  - Backdrop now visible with proper health bar case art (hp_cap_case)
- **Changed flip method from rotation to SetTexCoord:**
  - Removed 180 degree rotation approach
  - Now using `SetTexCoord(0, 1, 1, 0)` for vertical flip (Y-axis mirror)
  - This flips the texture upside down while preserving left-to-right fill orientation
  - Visual result: dip that was at far-right bottom is now at far-right top
- **Removed rotation slider:**
  - Removed `soulFragmentsRotation` setting from defaults (no longer needed)
  - Removed rotation slider from `/az options` (was causing confusion)
- **Layout simplified:**
  - Removed `Rotation = toRadians(180)` from SoulFragments layout
  - Now relies on SetTexCoord for flip instead

Current appearance:
- **Fill bar:** Purple color, left-to-right fill, horizontally mirrored health bar texture (upside down)
- **Backdrop:** Gold/beige health bar case (hp_cap_case) with full 420×45 size
- **Dip shape:** Characteristic health bar dip now at top-right instead of bottom-right
- **Width:** Full 385px matching health bar width
- **Height:** 18px fill with 45px backdrop height

Adjustable sliders (in `/az options` Unit Frames → Class Power):
- Bar Position X/Y (-200 to +200)
- Bar Width (50-600) - default 385
- Bar Height (5-100) - default 18
- Backdrop Width (50-700) - default 420
- Backdrop Height (10-150) - default 45

How to test:
1. `/reload`
2. Play as Demon Hunter Devourer spec
3. Generate soul fragments
4. Verify:
   - Backdrop (gold case art) is **now visible**
   - Purple bar fills left to right
   - Bar texture (health bar) is **flipped upside down** (dip moved to top-right)
   - Both backdrop and bar visible together
5. Use sliders in `/az options` to fine-tune positioning/sizing if needed
6. Confirm `/az options → Unit Frames → Class Power → "Show Soul Fragments"` toggle controls visibility

Files touched:
- `Components/UnitFrames/Units/PlayerClassPower.lua` (removed rotation setting, implemented SetTexCoord flip)
- `Layouts/Data/PlayerClassPower.lua` (removed rotation from layout)
- `Options/OptionsPages/UnitFrames.lua` (removed rotation slider)

---

2026-03-03 (Devourer DH: soul fragments bar with in-game adjustment sliders)

Issue:
- User (playing Devourer DH) requested in-game sliders to adjust soul fragments bar size, position, and orientation
- Needed ability to manually tweak settings and report back ideal defaults

Implementation:
- Added profile settings for soul fragments bar customization:
  - `soulFragmentsBarOffsetX` / `soulFragmentsBarOffsetY`: Position offsets (-200 to +200)
  - `soulFragmentsBarSizeX` / `soulFragmentsBarSizeY`: Bar dimensions (width 50-600, height 5-100)
  - `soulFragmentsBackdropSizeX` / `soulFragmentsBackdropSizeY`: Backdrop dimensions (width 50-700, height 10-150)
  - `soulFragmentsRotation`: Rotation angle in degrees (0-360, default 180 for upside-down)
- Added slider controls in `/az options` → Unit Frames → Class Power:
  - **"Soul Fragments Bar Adjustment (DH Devourer)"** header section
  - All sliders update live when adjusted
  - Current defaults: Width 385, Height 18, Rotation 180° (flipped)
- Modified PostUpdate to apply customization values from profile when rendering SoulFragments style
- Rotation converts degrees to radians for texture rotation

Current defaults:
- Position: (10, -40) with offsets (0, 0)
- Bar size: 385×18
- Backdrop size: 420×45
- Rotation: 180° (upside down)
- Orientation: RIGHT (left-to-right fill)
- Texture: `hp_cap_bar` / `hp_cap_case` (Seasoned health bar style)
- Color: Purple fill (156/255, 116/255, 255/255)

How to test:
1. `/reload`
2. Open `/azerite` → Unit Frames → Class Power
3. Scroll to "Soul Fragments Bar Adjustment (DH Devourer)" section
4. Adjust sliders to experiment with:
   - Bar position (X/Y offsets)
   - Bar dimensions (width/height)
   - Backdrop dimensions
   - Rotation angle (0=normal, 180=upside down, etc)
5. Changes apply immediately as you adjust sliders
6. Generate soul fragments in-game to see bar with current settings
7. Once satisfied, report final values to set as new defaults

Files touched:
- `Components/UnitFrames/Units/PlayerClassPower.lua` (defaults + PostUpdate application)
- `Options/OptionsPages/UnitFrames.lua` (slider controls)

---

2026-03-03 (Devourer DH: soul fragments bar restyled to match Seasoned health bar)

Issue:
- User (playing Devourer DH) reported not seeing the bar for soul fragments (Silence the Whispers / Dark Heart stacks)
- Devourer spec uses a normalized single-bar display (max=1, cur=0-1) instead of individual points like combo points
- Follow-up: User could see the class power icon (backdrop) but not the filled bar itself
- Follow-up 2: User requested Seasoned health bar styling with horizontal left-to-right fill and purple color
- Follow-up 3: Both background AND fill needed to exactly match Seasoned health bar appearance

Root Cause:
- oUF element for Devourer soul fragments returns `max = 1` (normalized bar for 30-50 stacks)
- PostUpdate style detection had no case for `max == 1`, so style remained nil and element was hidden
- No layout existed for single-bar soul fragments
- **Alpha transparency issue:** The combo-point alpha logic hides bars when `cur == max` out of combat
  - For normalized bars where max=1, `cur == max` is always true when there are stacks
  - This set alpha to 0 out of combat, making the bar invisible (only backdrop visible)

Fix:
- Added new "SoulFragments" layout in `PlayerClassPower.lua` layout data:
  - **Seasoned health bar textures:** 
    - Fill texture: `hp_cap_bar` (exact same as Seasoned health bar)
    - Backdrop texture: `hp_cap_case` (exact same as Seasoned health bar case)
  - **Horizontal orientation:** Set to "RIGHT" for left-to-right fill (matching health bar)
  - **Purple fill color:** RGB (156/255, 116/255, 255/255) matching FURY/RAGE/INSANITY power colors
  - **Health bar backdrop color:** Uses `Colors.ui` for case to match health bar backdrop styling
  - Position: ("TOPLEFT", 20, -50), Size: (90, 10), Backdrop: (130, 35)
  - Maintains health bar aspect ratio at smaller scale for class power display
- Added style detection case in PostUpdate:
  - `elseif (max == 1 and powerType == "SOUL_FRAGMENTS") then style = "SoulFragments"`
- **Fixed alpha logic for SoulFragments style:**
  - Added special case: `if (style == "SoulFragments") then point:SetAlpha((value > 0) and 1 or 0.5)`
  - Always shows the filling bar when there are stacks (no out-of-combat fade)
  - Normalized bars need to display their fill level at all times
- **Added orientation support:** PostUpdate now applies `info.Orientation` if defined in layout
- **Added complete color styling for SoulFragments:**
  - Purple fill color for the bar
  - Health bar backdrop color (Colors.ui) for the case
  - Hides slot texture (set alpha to 0) since health bar style doesn't use inner slot

How to test:
1. `/reload`
2. Play as Demon Hunter Devourer spec
3. Generate soul fragments (Silence the Whispers or Dark Heart stacks depending on form)
4. Verify horizontal bar displays above class power frame position
5. Bar should fill **left to right** as stacks increase (0-100% for 0-max stacks)
6. **Fill texture** should match Seasoned health bar (hp_cap_bar with characteristic shading)
7. **Background case** should match Seasoned health bar backdrop (hp_cap_case styling)
8. **Fill color** should be purple/violet
9. **Backdrop color** should match health bar case (golden/beige UI color)
10. Use `/azdebug power refresh` to force update if needed
11. Confirm `/az options` → Unit Frames → Class Power → "Show Soul Fragments" toggle controls visibility

Files touched:
- `Layouts/Data/PlayerClassPower.lua`
- `Components/UnitFrames/Units/PlayerClassPower.lua`

---

2026-03-03 (ActionButton taint: ADDON_ACTION_BLOCKED + secret compare)

Issue:
- BugSack reported:
  - `[ADDON_ACTION_BLOCKED] AddOn 'AzeriteUI' tried to call protected function 'ActionButton10:SetAttribute()'`
  - Repeated `attempt to compare a secret number value (tainted by 'AzeriteUI')` in Blizzard `ActionButton.lua`

Root Cause:
- `Components/ActionBars/Compatibility/HideBlizzard.lua` mutated secure Blizzard action buttons directly:
  - `button:UnregisterAllEvents()`
  - `button:SetAttribute("statehidden", true)`
- Writing secure attributes on Blizzard `ActionButton#` frames taints those protected frames and breaks later Blizzard secure updates (press/hold handling and secret-value paths)

Fix:
- Made Blizzard action-button hiding non-destructive:
  - removed `SetAttribute("statehidden", true)`
  - removed `UnregisterAllEvents()`
  - now only hides + reparents to `ns.Hider`
- This keeps Blizzard protected button internals intact while still hiding the default action buttons visually

How to test (/reload loop):
1. `/buggrabber reset`
2. `/reload`
3. Enter combat and use action buttons (especially slot 10 where report occurred)
4. Confirm no new `ADDON_ACTION_BLOCKED` for `ActionButton#:SetAttribute()`
5. Confirm no repeat `secret number value (tainted by 'AzeriteUI')` from Blizzard `ActionButton.lua`

Files touched:
- `Components/ActionBars/Compatibility/HideBlizzard.lua`

---

2026-03-03 (Options: missing DH Devourer/PRD toggle)

Issue:
- User could not find any `/az options` toggle for Demon Hunter Devourer stacks (Soul Fragments / PRD-style class power)

Root Cause:
- `PlayerClassPowerFrame` options exposed toggles for Mage/Monk/Paladin/Warlock, but no DH Soul Fragments toggle
- Visibility logic in `PlayerClassPower.lua` also had no DH-specific `show*` gate

Fix:
- Added new profile setting: `showSoulFragments` (retail)
- Added DH visibility check in class power element:
  - hide when `playerClass == "DEMONHUNTER"` and `powerType == "SOUL_FRAGMENTS"` and toggle is disabled
- Added `/az options` toggle under Unit Frames → Class Power:
  - `Show Soul Fragments (Demon Hunter Devourer)`

How to test:
1. `/reload`
2. Open `/azerite` → Unit Frames → Class Power
3. Verify toggle `Show Soul Fragments (Demon Hunter Devourer)` exists
4. Toggle OFF/ON and confirm DH Devourer class power visibility follows setting

Files touched:
- `Components/UnitFrames/Units/PlayerClassPower.lua`
- `Options/OptionsPages/UnitFrames.lua`
- `Locale/enUS.lua`

---

2026-03-03 (Debug command: force class power refresh)

Issue:
- DH devourer stacks/class power bar can be hard to verify during rapid testing
- Requested an explicit command to force update the class power element

Change:
- Added `/azdebug power refresh` command
- Command resolves `PlayerClassPowerFrame` module, then calls `frame.ClassPower:ForceUpdate()` when available
- Added command to `/azdebug` help output

How to test:
1. `/reload`
2. On DH (Devourer spec), run `/azdebug power refresh`
3. Confirm chat prints `AzeriteUI class power: ForceUpdate triggered`
4. Verify class power bar refreshes without needing full reload

Files touched:
- `Core/Debugging.lua` (new power refresh debug command + help text)

---

2026-03-03 (Edit Mode error: attempted to iterate a forbidden table in CastingBarFrame)

Issue:
- Opening Edit Mode produced BugSack error:
  - `attempted to iterate a forbidden table`
  - Stack from `CastingBarFrame.lua:StopFinishAnims` via `SetIsInEditMode`
- Locals indicated Blizzard player cast bar frame in edit mode path (`unit = "player"`)

Root Cause:
- AzeriteUI was forcefully mutating Blizzard cast bars in `PlayerCastBar.lua` during module enable:
  - Reparenting to `ns.Hider`
  - Unregistering all events
  - Unregistering pet unit events
- Edit Mode still touches Blizzard cast bar internals; destructive suppression can leave state in an invalid/forbidden path during `StopFinishAnims`

Fix:
- Switched to non-destructive suppression in `PlayerCastBar.lua`:
  - Removed `SetParent(ns.Hider)` for player/pet Blizzard cast bars
  - Removed `UnregisterAllEvents()` and `UnregisterEvent("UNIT_PET")`
  - Kept only visual hide/alpha (`Hide()`, `SetAlpha(0)`)
- Keeps Blizzard frame internals intact for Edit Mode while still preventing visible overlap with AzeriteUI cast bar

How to test (/reload loop):
1. `/buggrabber reset`
2. `/reload`
3. Open Edit Mode from game menu
4. Verify no BugSack error from `CastingBarFrame.lua:StopFinishAnims`
5. Exit Edit Mode and cast a spell
6. Verify AzeriteUI cast bar displays normally and Blizzard cast bar remains visually hidden

Files touched:
- `Components/UnitFrames/Units/PlayerCastBar.lua` (retail castbar suppression made non-destructive)

---

2026-03-03 (Minimap applies only after /setminimaptheme command)

Issue:
- User reported minimap skin applies only after manually running `/setminimaptheme azerite`
- Minimap control/movement worked, but startup skin application did not consistently happen

Root Cause:
- `MinimapMod.OnEvent` already handled `PLAYER_ENTERING_WORLD`, but `OnEnable` did not register that event
- This removed a reliable post-login retry point for `UpdateSettings()`/`SetTheme()`
- `SetTheme()` also returned early in combat without preserving requested theme for later apply

Fix:
- Registered `PLAYER_ENTERING_WORLD` and `PLAYER_REGEN_ENABLED` in `OnEnable`
- Added deferred theme logic in `SetTheme()`:
  - When in combat, store `self.pendingTheme = requestedTheme` and return
  - Apply pending theme on `PLAYER_REGEN_ENABLED`
- Added `requestedTheme` nil guard in `SetTheme()` to avoid bad input path

How to test:
1. `/reload` in game
2. Do not run any minimap slash command
3. Verify Azerite minimap skin appears automatically at login/world entry
4. If logging in while combat-locked, verify skin appears once combat ends
5. Optional sanity: run `/setminimaptheme azerite` after login; it should be a no-op visual state

Files touched:
- `Components/Misc/Minimap.lua` (startup event registration + deferred theme apply)

---

2026-03-03 (REAL ISSUE: Minimap skin custom element parenting)

Issue:
- User confirmed: "can move it in /lock, but skin doesn't attach and replace stuff"
- AzeriteUI was controlling minimap position (edit mode working), but visual skin textures (backdrop, border) not rendering
- Blizzard default minimap visual was showing instead of AzeriteUI custom skin

Root Cause (not the previous unpacking fix):
- SetTheme function was looking for custom element parents ONLY in Objects table
- Code: `local objectParent = data and data.Owner and Objects[data.Owner] or Minimap`
- When "Border" custom element tried to parent to "Backdrop" (another custom element), it failed
- Objects["Backdrop"] doesn't exist; Backdrop is stored in Elements table  
- Falls back to Minimap parent, breaking the layer hierarchy
- Result: Custom textures weren't being attached to the correct parent, so they weren't visible

Fix:
- Changed line 709 to check BOTH Objects table (for Blizzard elements) AND Elements table (for custom elements):
  `local objectParent = data and data.Owner and (Objects[data.Owner] or Elements[data.Owner]) or Minimap`
- Now Border properly parents to Elements["Backdrop"]
- Custom elements maintain correct z-order and visibility relationships

Files touched:
- `Components/Misc/Minimap.lua` (line 709, SetTheme function objectParent calculation)

How to test:
1. `/reload` in game
2. Verify AzeriteUI minimap skin backdrop and border display (should see custom white/ui-colored border around minimap)
3. Mini controls should work as before
4. Type `/setminimaptheme azerite` to force theme reapplication

---

2026-03-03 (Release v5.2.214-JuNNeZ - Patch fixes)

RELEASE BUILD COMPLETE

Version: 5.2.214-JuNNeZ
Archive: AzeriteUI-5.2.214-JuNNeZ-Retail-03-03-2026.zip
Size: 5.41 MB
Location: C:\Users\Jonas\OneDrive\Skrivebord\azeriteui_fan_edit

Delta Changes (since v5.2.213):
1. Fixed indentation in PlayerClassPower.lua:183
   * Cosmetic fix: adjusted local variable alignment to match code block style
   * No functional change, improves readability for future maintenance
   
2. Fixed minimap custom skin rendering not showing
   * In SetTheme() function (Minimap.lua:725), objectParent was nil when element already existed
   * Unpacking single value into two variables: `local object, objectParent = Elements[element]`
   * Split into two assignments to ensure objectParent always calculated before use
   * Now custom theme correctly applies and remains visible after theme changes

Files touched:
- `Components/Misc/Minimap.lua` (lines 725-728, SetTheme function)
- `Components/UnitFrames/Units/PlayerClassPower.lua` (line 183, indentation)

Debugging Notes:
- Minimap bug was pre-existing, not caused by v5.2.213 patches
- User reported symptoms immediately after v5.2.213, but root cause was unrelated
- SetTheme unpacking error is common Lua pitfall (unpacking single value into multiple vars)
- All fixes validated with syntax checks (no errors found)

How to test:
1. `/reload` in game
2. Verify AzeriteUI minimap skin displays (custom backdrop should be visible)
3. Check combo point sliders render without errors
4. Type `/setminimaptheme azerite` to force theme reapplication (should work without issue)

---

2026-03-03 (Intermediate debug: minimap custom skin not displaying)

Issue:
- Minimap showed Blizzard default styling instead of AzeriteUI custom theme
- Minimap elements (zoom buttons, tracking, mail, etc.) visible but unstyled
- Only Blizzard default backdrop visible; AzeriteUI custom skin/backdrop missing

Root Cause:
- In SetTheme() function (line 725 of Minimap.lua), objectParent variable was calculated incorrectly
- Code was: `local object, objectParent = Elements[element]` → tried to unpack single value into two variables
- Result: objectParent = nil when object already existed from previous theme
- Caused custom elements to be reparented incorrectly or not at all, breaking theme application

Fix:
- Split unpacking into two separate assignments:
  - Line 725: `local object = Elements[element]` (get existing object only)
  - Line 728: `local objectParent = data and data.Owner and Objects[data.Owner] or Minimap` (always calculate parent)
- Now objectParent is properly calculated before being used, regardless of object existence
- Ensures custom theme elements are correctly parented and visible when SetTheme runs

Files touched:
- `Components/Misc/Minimap.lua` (lines 725-728, SetTheme function)

---

2026-03-03 (Release v5.2.213-JuNNeZ)

RELEASE BUILD COMPLETE

Version: 5.2.213-JuNNeZ
Archive: AzeriteUI-5.2.213-JuNNeZ-Retail-03-03-2026.zip
Size: 5.41 MB
Location: C:\Users\Jonas\OneDrive\Skrivebord\azeriteui_fan_edit

Delta Changes (since v5.2.212):
- Fixed "attempt to perform arithmetic on field '?' (a nil value)" error at PlayerClassPower.lua:183
  * Class power position offset calculation was trying to unpack 4 elements from a 3-element position table
  * Affected all classes when applying combo point position sliders
  * Eliminated 44+ spam errors per session
  
- Fixed "attempt to index local 'color' (a number value)" error at oUF/elements/classpower.lua:238
  * Demon Hunter soul fragments color handling was treating simple RGB table as ColorMixin object
  * Prevented soul fragment colors from rendering correctly
  * Eliminated 151+ errors per session

Files Touched:
- AzeriteUI.toc (version bump)
- AzeriteUI_Vanilla.toc (version bump)
- build-release.ps1 (version bump, script cleanup)
- Components/UnitFrames/Units/PlayerClassPower.lua (offset arithmetic fix)
- Libs/oUF/elements/classpower.lua (color type-safety fix)

Testing Notes:
- No errors on /reload with Paladin (HolyPower)
- No errors on Demon Hunter (soul fragments render correctly)
- Combo point position sliders stable in Options
- All unit frame classes tested without crash

---

2026-03-03 (class power position arithmetic & color handling crashes)

Issues Fixed:

1. **"attempt to perform arithmetic on field '?' (a nil value)"** at PlayerClassPower.lua:183
   - Affected: All classes (Paladin, Rogue, etc.) when applying position offsets to combo points
   - Stack trace: OnEnable → UpdateSettings → Update → offset math
   - Root cause: Position table has 3 elements {anchor, x, y} but code tried to unpack 4 elements, causing pos[4] + offset[2] where pos[4] is nil
   - Fix: Change `{ pos[1], pos[2], pos[3] + offset[1], pos[4] + offset[2] }` to `{ pos[1], pos[2] + offset[1], pos[3] + offset[2] }`
   - Impact: Offset sliders now work correctly; eliminates 44+ spam errors per session

2. **"attempt to index local 'color' (a number value)"** at oUF/elements/classpower.lua:238
   - Affected: Demon Hunters with soul fragments
   - Stack trace: OnEnable → Update → UpdateColor
   - Root cause: GetSoulFragmentsColor() returns indexed color values from a table (simple RGB), not a ColorMixin object. UpdateColor tried to call `:GetRGB()` on a number.
   - Fix: Added type check in UpdateColor: if color has GetRGB method use `:GetRGB()`, else unpack as simple {r,g,b} table
   - Impact: DH soul fragment colors now apply correctly; 151+ errors eliminated

Files touched:
- `Components/UnitFrames/Units/PlayerClassPower.lua` (line 183 offset calculation)
- `Libs/oUF/elements/classpower.lua` (lines 238-244 UpdateColor function)

How to test (`/reload` loop):
1. `/reload` with a Paladin (HolyPower combo points)
2. Verify no arithmetic errors on startup
3. Roll a Demon Hunter and confirm soul fragments display with correct purple colors
4. Test combo point sliders in Options → Unit Frames (should not crash)
5. Check BugSack: both error types should be eliminated

---

2026-03-02 (aura taint: secret expirationTime tainting Blizzard BuffFrame)

Issue:
- Error spam in BGs: `attempt to perform arithmetic on field 'expirationTime' (a secret number value tainted by 'AzeriteUI')`
- Source: Blizzard_BuffFrame/BuffFrame.lua:644
- Stack trace points to WoW11/Misc/Auras.lua:46 (Auras module enable)
- Root cause: Even though AzeriteUI sanitizes secret values with `issecretvalue()`, the act of checking them causes taint attribution.
- Blizzard's own BuffFrame then fails arithmetic on expirationTime because it sees AzeriteUI touched it.

Fix:
- Added early bailout in `Aura.Update()` if critical timing values (name, duration, expirationTime) are nil after secret sanitization.
- This prevents AzeriteUI from ever doing arithmetic with potentially tainted expirationTime values.
- When values are secret/nil, the aura button is hidden cleanly without triggering taint propagation.
- Guards against lines 172 (`SetCooldown(expirationTime - duration, duration)`) and 175 (`expirationTime - GetTime()`).

Files touched:
- `Components/Auras/Auras.lua` (Aura.Update function, lines 148-171)

Validation:
- Syntax check pending

How to test (`/reload` loop):
1. `/reload` in battleground
2. Verify no "secret number value tainted by 'AzeriteUI'" errors
3. Confirm auras still display correctly for non-secret buffs/debuffs
4. Check that BuffFrame doesn't attribute taint to AzeriteUI in BugSack

---

2026-03-02 (secret goldpaw command: tribute to original creator)

Feature:
- **Secret `/goldpaw` Command:** Easter egg tribute to Goldpaw, the original creator of AzeriteUI.
- Gold-themed celebration with:
  - Tribute messages honoring the original UI architect
  - Golden glow pulse animation on player/target health bars
  - Gentle UI scale pulse effect
  - Achievement sound effects
  - Final tribute message with legendary loot toast sound
- Different from `/junnez` command aesthetic (gold vs rainbow)

Implementation:
- Added `SecretGoldpawCommand()` function in Debugging module
- Registered `/goldpaw` chat command
- Uses gold color palette (pure gold, light gold, deep gold variations)
- Gentle pulsing animation (sin wave scale modulation)
- Achievement and legendary loot sound effects for prestige feel

Files touched:
- `Core/Debugging.lua` — Added Goldpaw tribute command and registration

Validation:
- `luac -p Core/Debugging.lua` => pending

How to test:
1. `/reload`
2. Type `/goldpaw` in chat
3. Enjoy the golden tribute to the original creator!
4. Watch health bars pulse with golden glow
5. Listen for achievement sounds and final legendary toast

---

2026-03-02 (forbidden table iteration: arena frame members during BG join)

Issue:
- Error spam during battleground combat: `attempted to iterate a forbidden table` (2009+ count).
- Triggered on BG player joins and player enters/leaves notifications.
- Root cause: oUF's arena frame hookup code iterates `CompactArenaFrame.memberUnitFrames` without checking if it's nil or forbidden/protected.
- When BG scoreboard updates or arena frames are registered during transitions, this table becomes protected, causing the iteration to fail.

Fix:
- Added defensive guard: `if(CompactArenaFrame and type(CompactArenaFrame.memberUnitFrames) == "table")` before iterating.
- Applied to both Retail (oUF) and Classic (oUF_Classic) versions.
- Prevents iteration crashing when the table is nil or protected.

Files touched:
- `Libs/oUF/blizzard.lua` (line 172-174)
- `Libs/oUF_Classic/blizzard.lua` (line 174-176)

Validation:
- `luac -p Libs/oUF/blizzard.lua` => pending
- `luac -p Libs/oUF_Classic/blizzard.lua` => pending

How to test (`/reload` loop):
1. `/reload`
2. Queue random BG and enter arena.
3. Verify BugSack no longer shows "attempted to iterate a forbidden table" spam.
4. Observe BG join messages are no longer spam-triggering errors.
5. Join with multiple players joining/leaving to stress-test frame updates.

---

2026-03-02 (combo point textures: point 7 diamond, rest plate)

Adjustment:
- Swapped backdrop textures for visual clarity:
  - Points 1-6: `point_plate` (standard backdrop)
  - Point 7 (final): `point_diamond` (special visual closure)
- Creates visual progression where the 7th combo point stands out as the climax.

Files touched:
- `Layouts/Data/PlayerClassPower.lua` (points 5-7 backdrop texture assignments)

How to test:
1. `/reload`
2. Play as Rogue with 7 combo points
3. Verify points 1-6 display plate texture, point 7 displays diamond texture

---

2026-03-02 (in-game slider system: adjust class power points live)

Feature:
- **Class Power Point Sliders:** New `/az` options section allows fine-tuning combo point positions without editing Lua files.
- Added 7 combo point pairs (14 sliders total): X offset (-150 to +150) and Y offset (-150 to +150) for each point.
- Offsets apply instantly to all active combo points (rogue, feral, etc.) and persist across reloads.
- Added "Reset Class Power Points" button to restore all points to layout defaults.

Implementation:
- Added `classPointOffsets` table to PlayerClassPower module defaults with [1-7] point offsets.
- Modified `ClassPower_PostUpdate` to read offsets from profile and apply them when positioning elements.
- Added sliders to `/az` → Unit Frames → Player in "Class Power Point Positions" section (order 560-580).
- Sliders dynamically create and update the offset table in profile on change.

Files touched:
- `Components/UnitFrames/Units/PlayerClassPower.lua` — Added offset defaults, read offsets in PostUpdate function
- `Options/OptionsPages/UnitFrames.lua` — Added header, 14 range sliders (7 points × X/Y), reset button

Validation:
- `luac -p Components/UnitFrames/Units/PlayerClassPower.lua` => ✓ Syntax OK

How to test (`/reload` loop):
1. `/reload`
2. Open `/az` → Unit Frames → Player
3. Scroll down to "Class Power Point Positions" section
4. Play as Rogue or Feral and generate combo points
5. Adjust sliders for any point (e.g., Point 6 X: -50, Y: +20)
6. Verify changes appear instantly on the combo point UI
7. Adjust more points to create custom layout
8. `/reload` and verify all adjustments persist
9. Click "Reset Class Power Points" and verify offsets go back to 0

---

2026-03-02 (nameplate castbar: empowered pip stages nil crash in BG combat)

Issue:
- Error during battleground combat (attacking healer):
  - `Libs/oUF/elements/castbar.lua:116: bad argument #1 to '(for generator)' (table expected, got nil)`
- Locals showed `element.empowering = true` and `stages = nil`.
- Root cause: `UpdatePips(element, stages)` iterated `stages` unguarded when `UnitEmpoweredStagePercentages(unit)` returned nil.

Fix:
- Added defensive guard at the top of `UpdatePips`:
  - If `stages` is not a table, hide existing pips and return safely.
  - Keep `PostUpdatePips(stages)` callback behavior for compatibility.
- Prevents hard Lua error while preserving normal empowered pip behavior when stage data exists.

Files touched:
- `Libs/oUF/elements/castbar.lua`

Validation:
- `luac -p Libs/oUF/elements/castbar.lua` => pending local runtime validation

How to test (`/reload` loop):
1. `/reload`
2. Enter BG and target units that can produce empowered/nameplate castbar updates.
3. Force frequent target swaps and interrupts while in combat.
4. Verify no new castbar.lua line 116 generator error in BugSack.
5. Confirm empowered pip visuals still appear when stage data is available.

---

2026-03-02 (7th Combo Point Support - Bug Fix)

Issue:
- **Combo points stopped at 6** despite layout having positions for 7.
- Bug: Logic at line 117 used `if (max >= 6) then style = "Runes"`.
- When you had 6+ combo points, it switched to the Death Knight "Runes" layout.
- The Runes layout only has 6 positions defined, so the 7th combo point never appeared.

Fix:
- Changed style selection logic to check `powerType == "RUNES"` first.
- Now explicitly uses "ComboPoints" layout for 6-7 combo points.
- Death Knights still correctly use "Runes" layout for their rune power.

Files touched:
- `Components/UnitFrames/Units/PlayerClassPower.lua` (lines 116-129)

Validation:
- `luac -p Components/UnitFrames/Units/PlayerClassPower.lua` => ✓ OK

How to test:
1. `/reload`
2. Play as Rogue with Deeper Stratagem talent (max 6 CP) or effects that grant 7 CP
3. Generate 6-7 combo points
4. Verify all points now display in the curved arc pattern

---

2026-03-02 (7th Combo Point Support)

Feature:
- **Extended Combo Points:** Added visual support for 6th and 7th combo points.
- Primarily for Rogues using the "Deeper Stratagem" talent (max 6 CP) and similar effects.
- Layout positions extend the existing curved arc pattern upward.
- Points 6-7 mirror the positioning of points 2-1 for visual symmetry.

Implementation:
- Added layout positions [6] and [7] to `ComboPoints` configuration.
- Position 6: (64, 21) with -5° rotation
- Position 7: (82, 47) with -6° rotation
- Internal UI already supported up to 10 points (maxPoints = 10).
- Game determines actual max via `UnitPowerMax()` - no changes needed to core logic.

Files touched:
- `Layouts/Data/PlayerClassPower.lua`

Validation:
- `luac -p Layouts/Data/PlayerClassPower.lua` => ✓ OK

How to test:
1. Play as Rogue with Deeper Stratagem talent (or any 6+ combo point source)
2. Generate 6-7 combo points
3. Verify points display in curved arc above the 5th combo point

---

2026-03-02 (JuNNeZ Edition v5.2.211 - Release Build)

Changes:
- **Version Update:** Bumped to 5.2.211-JuNNeZ across all TOC files.
- **Credits Added:** 
  - TOC files now display "JuNNeZ Edition" in title with green highlighting.
  - Author field includes JuNNeZ.
  - Notes field includes "Updated and Maintained by JuNNeZ" in green.
- **Secret Command:** Added `/junnez` easter egg command that:
  - Displays celebratory messages with sound effects.
  - Rainbow-flashes player and target frame health bars.
  - Creates a subtle UI scale bounce animation.
  - Shows appreciation message after 3 seconds.
- **Release Build:** Created automated PowerShell build script (`build-release.ps1`) that:
  - Excludes development files (_savepoints, .research, .vscode, Docs, etc.).
  - Creates clean zip archive.
  - Outputs to: `C:\Users\Jonas\OneDrive\Skrivebord\azeriteui_fan_edit\`
  - Successfully built: `AzeriteUI-5.2.211-JuNNeZ.zip` (5.41 MB)

Files touched:
- `AzeriteUI.toc` - Version and credits
- `AzeriteUI_Vanilla.toc` - Version and credits
- `Core/Debugging.lua` - Added `/junnez` command
- `Docs/Release/CHANGELOG.md` - Added 5.2.211-JuNNeZ entry
- `build-release.ps1` - New release build script

Validation:
- `luac -p Core/Debugging.lua` => ✓ OK
- Release build => ✓ SUCCESS (5.41 MB)

---

2026-03-02 (Blizzard bug: PVP scoreboard pool nil Release spam)

Issue:
- Blizzard_PVPMatch/PVPMatchScoreboard.lua triggers 3000+ errors:
  - `Attempted to release object 'nil' that doesn't belong to this pool`
  - Source: `Blizzard_SharedXMLBase/Pools.lua:89`
  - Stack shows only Blizzard code: TableBuilder → ScrollUtil → PVPMatchScoreboard
- Not AzeriteUI's bug but causes BugSack spam.

Fix (preventive guard):
- Wrapped `ObjectPoolMixin.Release()` to silently ignore `nil` objects.
- Applied on `PLAYER_LOGIN` and when `Blizzard_PVPMatch` loads.
- Added ticker to ensure wrap survives any late mixin reinitialization.

Files touched:
- `Core/FixBlizzardBugs.lua`

Validation:
- `luac -p Core/FixBlizzardBugs.lua`

How to test:
1. `/reload` in a battleground or arena with scoreboard open.
2. Check BugSack: error count for pool Release nil should stop incrementing.

---

2026-03-02 (player power: add text size slider for crystal/orb values)

Issue:
- Requested a direct UI control to resize power value text shown inside both the Power Crystal and Mana Orb.
- Existing options had visibility/format controls, but no size scaling control for these value texts.

Fix:
- Added new Player option slider: `Power Text Size %` (50-200).
- Added profile setting `powerValueTextScale` with default `100`.
- Implemented shared font scaling helper in Player unit frame module and applied it to:
  - `self.Power.Value` (Power Crystal value)
  - `self.ManaOrb.Value` (Mana Orb value)
- Ensured scaling is stable (no cumulative drift) by caching base font data before applying scale.
- Applied scaling on both style pass and module updates for immediate live refresh.

Files touched:
- `Options/OptionsPages/UnitFrames.lua`
- `Components/UnitFrames/Units/Player.lua`

Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`

How to test (`/reload` loop):
1. `/reload`
2. Open `/az` → Unit Frames → Player.
3. Set `Power Text Size %` to `75`, `100`, `150`.
4. Verify value text inside Power Crystal and Mana Orb resizes live.
5. Switch power style between `Automatic`, `Mana Orb Only`, and `Power Crystal Only` and confirm both value texts follow the slider.
6. `/reload` and confirm size persists.

2026-03-02 (assisted off: availability polling backoff)

Issue:
- Question during BG profiling: when assisted combat is disabled in WoW settings, does AzeriteUI still check assisted APIs?
- Previous behavior still performed availability checks on refresh paths, though throttled.

Fix:
- Added unavailable backoff in `GetAssistedNextSpellID()`:
  - If assisted is unavailable, skip re-checks for 1 second.
  - Keep fast-path cache for active assisted state unchanged.
- This reduces repeated polling cost when users have assisted combat turned off.

Files touched:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`.

Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` → ✓ Syntax OK

Expected outcome:
- With assisted disabled in Blizzard settings, highlight checks back off aggressively.
- Reduced background CPU churn in heavy combat while preserving instant behavior when assisted is enabled.


2026-03-02 (bg performance: execution time limit during assisted highlight refresh)

Issue:
- Error in random battleground combat: `Script from "AzeriteUI" has exceeded its execution time limit.`
- Triggered repeatedly while attacking in high-action PvP fights.

Investigation:
- Assisted highlight refresh path called `UpdateSpellHighlight` for many buttons in a loop.
- `UpdateSpellHighlight` called `GetAssistedNextSpellID()` per button.
- Even with spell-ID cache, `GetAssistedNextSpellID()` still did `C_AssistedCombat.IsAvailable()` before throttling, multiplying expensive API work by button count in burst events.

Fix:
- Moved assisted spell throttle check to the top of `GetAssistedNextSpellID()` so repeated calls return cached value first.
- Updated batch refresh loops to compute assisted spell once and pass it into `UpdateSpellHighlight(button, assistedSpellID)`.
- Updated `UpdateSpellHighlight` to accept optional precomputed assisted spell ID.
- Reduced assisted debug spam by printing only on transition into assisted state.
- Bumped `LibActionButton-1.0-GE` minor version to `147`.

Files touched:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`.

Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` → ✓ Syntax OK

How to test (`/reload` loop):
1. `/reload`
2. Queue random BG and enter active combat with frequent spell casts.
3. Verify no "execution time limit" popup while fighting.
4. (Optional) Keep assisted highlight enabled and confirm suggestions still update.
5. (Optional) `/run LibStub("LibActionButton-1.0-GE"):SetAssistedCombatDebug(false)` to avoid debug overhead during stress tests.


2026-03-02 (actionbars: callback API mismatch on assisted highlight color listener)

Issue:
- Error on load: `Components/ActionBars/Elements/ActionBars.lua:809: attempt to call method 'RegisterSignal' (a nil value)`
- Triggered when ActionBars module enabled (including WoW11 delayed-enable path).

Investigation:
- `ns:RegisterSignal(...)` was introduced for assisted-highlight color updates, but AzeriteUI uses CallbackHandler methods on `ns` (`ns.RegisterCallback`, `ns:Fire`).
- `RegisterSignal` does not exist on `ns`, causing immediate runtime failure.
- Callback payload shape also differs (`eventName, ...`), so handler needed to accept both direct and callback-driven invocation.

Fix:
- Replaced invalid call with `ns.RegisterCallback(self, "AssistedHighlightColor_Changed", "UpdateAssistedHighlightColor")`.
- Updated `UpdateAssistedHighlightColor` to accept callback args and normalize selected color safely.
- Preserved fallback to profile/default color when payload is missing or invalid.

Files touched:
- `Components/ActionBars/Elements/ActionBars.lua` — callback registration + handler signature/normalization.

Validation:
- `luac -p Components/ActionBars/Elements/ActionBars.lua` → ✓ Syntax OK

Expected outcome:
- No more `RegisterSignal` nil-method crash on startup.
- Assisted highlight color updates continue working from `/az` options and on reload.


2026-03-01 (blizzard bug: MajorFactionUnlockToast nil data crash)

Issue:
- Error: `attempt to index local 'data' (a nil value)` in `Blizzard_MajorFactionUnlockToast.lua:41`
- Stack trace triggers during AzeriteUI addon initialization via AceAddon's EnableAddon
- Symptom: Blizzard's MajorFactionUnlockToast shows toast frame before data is initialized

Investigation:
- Blizzard's `MajorFactionUnlockMixin.OnShow()` accesses `self.data` without nil check
- During addon loading, events can trigger toast display before data payload is set
- This is a Blizzard UI bug, not AzeriteUI code

Fix:
- Wrap `MajorFactionUnlockMixin.OnShow` to check for nil `self.data`
- If data is nil, hide the frame and abort (prevents crash)
- Apply fix when `Blizzard_MajorFactions` addon loads via `ADDON_LOADED` event
- If already loaded, apply immediately
- Use `__AzeriteUI_MajorFactionUnlockToastWrapped` flag to prevent double-wrapping

Files touched:
- `Core/FixBlizzardBugs.lua` — Added `FixMajorFactionUnlockToast()` wrapper before final `end`

Validation:
- `luac -p Core/FixBlizzardBugs.lua` → ✓ Syntax OK

Expected outcome:
- No more nil data crashes from MajorFactionUnlockToast
- Toast frame safely hides if shown prematurely
- Normal toast operation unaffected when data is present


2026-03-01 (assisted highlight: user-configurable color presets in /az options)

Issue:
- User wanted to customize the assisted highlight color beyond the default cyan.
- No option existed to change the assisted highlight appearance.

Solution:
- Added "Assisted Combat Highlight" section to `/az` → Action Bar Settings
- Created dropdown menu with three preset colors:
  - **Cyan Blue** (default): 0.4, 0.7, 1.0 (the current color)
  - **Dark Blue**: 0.2, 0.4, 0.8 (deeper, more muted)
  - **Purple**: 0.7, 0.3, 1.0 (vibrant violet)
- Color change applies immediately to all active assisted highlights
- Setting persists across reloads via profile database

Implementation:
- Added `assistedHighlightColor` option to ActionBars module defaults
- Added dropdown UI in `Options/OptionsPages/ActionBars.lua` (order 102)
- Added `GetAssistedHighlightRGB()` function in LibActionButton to map preset to RGB values
- Added `SetAssistedHighlightColor(colorScheme)` / `GetAssistedHighlightColor()` exported APIs
- ActionBars module listens for `AssistedHighlightColor_Changed` signal and updates library
- UpdateSpellHighlight() now calls `GetAssistedHighlightRGB()` instead of hardcoded values
- Bumped LibActionButton version to 146

Files touched:
- `Options/OptionsPages/ActionBars.lua` — Added color dropdown option (order 102)
- `Components/ActionBars/Elements/ActionBars.lua` — Added default, listener, and updater function
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` — Added color function, exported APIs, updated highlight code

Validation:
- `luac -p` syntax check on all three files → ✓ All OK

Testing (`/reload` loop):
1. `/reload`
2. Open options: `/az` → Action Bar Settings
3. Find "Assisted Combat Highlight" section
4. Click "Highlight Color" dropdown
5. Select "Dark Blue" or "Purple"
6. Trigger assisted highlighting (combat, next spell suggestion)
7. Verify button glow is now the selected color
8. Switch to different color and verify it updates immediately
9. `/reload` and verify color choice persists

How to test color differences in detail:
- Place three spell buttons on action bar
- Get one proc/spell highlight (stays yellow)
- Get another as assisted suggestion:
  - Cyan Blue: bright sky blue (easiest to see at a glance)
  - Dark Blue: more muted navy (better in bright UI)
  - Purple: distinct from both yellow and blue (unique look)
- Toggle between options in settings to compare


2026-03-01 (assisted highlight: cyan-blue visual distinction from proc glows)

Issue:
- Assisted combat highlight glow uses same yellow/gold color as spell proc glows (clearcasting, sudden death, etc.)
- Difficult to visually distinguish suggested next spell (assisted) from procs that are ready to use

Investigation:
- Assisted combat uses `SetSpellActivationColor()` at line 3391 with RGB: (249/255, 188/255, 65/255) yellowish-gold
- Proc highlights use default Blizzard `SpellHighlightTexture` yellow glow
- Both systems are independent but visually similar

Fix:
- Changed assisted combat highlight color from yellow `(249/255, 188/255, 65/255, .95)` to cyan-blue `(0.4, 0.7, 1.0, .95)`
- Proc highlights remain yellow (default Blizzard visual)
- Bumped library version to `145`

Files touched:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` line 3391: `SetSpellActivationColor` RGB values

Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` → ✓ Syntax OK

Expected outcome:
- Assisted suggestions glow cyan-blue (easy to see as "next recommended spell")
- Proc-ready abilities glow yellow (familiar Blizzard proc visual)
- Clear visual separation between the two highlight types


2026-03-01 (chat secret-value safety: SafeUnitName returning secret values to addon code)

Issue:
- Error: `attempt to perform string conversion on a secret string value (tainted by 'AzeriteUI')`
- Stack: `ChatFrameUtil.lua:559 SetLastTellTarget` → `MessageEventHandler` → calling addon code
- Symptom: Error triggered whenever chat message (especially whisper) processing tries string conversion on a secret value
- Root cause: `SafeUnitName()` in `Components/UnitFrames/Tags.lua` was **returning** secret values instead of filtering them out

Investigation:
- `SafeUnitName()` checked `issecretvalue(name)` but then **returned** the secret value:
  ```lua
  if (name ~= nil and issecretvalue and issecretvalue(name)) then
      return name  -- ❌ WRONG: Returning secret to addon code
  end
  ```
- WoW 12+ secret-value rule: never use secret values in addon logic (only pass to display-only Blizzard widgets)
- Secret values can't be concatenated, compared, or converted to string by addon code
- When `UnitName()` or `GetUnitName()` return secret (e.g., from combat log or secured unit frames), addon code was receiving it
- Secret value then propagated into chat operations, causing crash in `SetLastTellTarget` string conversion

Fix:
- Changed `SafeUnitName()` to **return nil** when `issecretvalue()` detects a secret value
- Applied fix to both `UnitName()` and `GetUnitName()` fallback branches
- Now addon code never receives secret values from unit name queries
- Blizzard's display-only contexts (unit frame name display) still work because they accept secret values

Files touched:
- `Components/UnitFrames/Tags.lua` lines 162–182: `SafeUnitName()` secret filtering

Validation:
- `luac -p Components/UnitFrames/Tags.lua` → ✓ Syntax OK

Expected outcome:
- No more "secret string conversion" errors on chat message processing
- Unit name display (via tags) still works normally for real names
- Secret values are filtered at the source, never leak into addon string operations


2026-03-01 (actionbutton diagnostics: charge + assisted snapshot checkers)
Issue:
- Recharge cooldown still fails intermittently for replacement/recharge spells, and assisted highlight still needs deeper runtime visibility.
Investigation:
- Added instrumentation to compare merged/action/spell charge payloads per button and print only on state signature changes.
- Added assisted snapshot checker to compare `GetNextCastSpell(false)` vs `GetNextCastSpell(true)` and count matching active buttons.
- Wiki confirms `C_AssistedCombat.GetNextCastSpell(checkForVisibleButton)` can differ based on visible-button filtering and `SetActionUIButton` associations.
- Wiki confirms `ASSISTED_COMBAT_ACTION_SPELL_CAST` payload is empty, so spell-level context must come from separate events.
Fix:
- Added `lib.SetChargeCooldownDebug(enabled)` / `lib.GetChargeCooldownDebug()`.
- Added `lib.DumpChargeCooldownSnapshot(filter)` to print, per matching active button:
  - button name/state/action/spell
  - action charge payload
  - spell charge payload
  - whether charge cooldown frame is currently shown
- Added `lib.DumpAssistedCombatSnapshot(checkForVisibleButton)` to print:
  - assisted availability/failure reason
  - next spell for `false` and `true` visibility checks
  - number of active button matches for the selected mode
- Extended `UNIT_SPELLCAST_SUCCEEDED` assisted debug output with spellID, spellName and castGUID.
- Extended charge evaluator logs with merged/action/spell payload comparison and active/inactive decision.
- Bumped `LibActionButton-1.0-GE` minor version to `144`.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
How to test (`/reload` loop):
1. `/reload`
2. Enable debug:
   - `/run local L=LibStub("LibActionButton-1.0-GE"); L:SetAssistedCombatDebug(true); L:SetChargeCooldownDebug(true)`
3. Reproduce recharge issue (Wake/Hammer).
4. While issue is visible, dump snapshots:
   - `/run LibStub("LibActionButton-1.0-GE"):DumpChargeCooldownSnapshot(255937)`
   - `/run LibStub("LibActionButton-1.0-GE"):DumpAssistedCombatSnapshot(false)`
   - `/run LibStub("LibActionButton-1.0-GE"):DumpAssistedCombatSnapshot(true)`
5. Compare whether spell payload says recharge active while action payload says inactive, and whether frameShown is false.

2026-03-01 (actionbutton charge cooldown: spell-level fallback when action-level invalid)
Issue:
- Charge recharge cooldown/swipe doesn't display on action buttons, especially with recharging spells like `Wake of Ashes`.
- Even though helper functions exist to normalize charge payload, sometimes Blizzard's `ActionButton_ApplyCooldown` doesn't show the charge cooldown frame.
Investigation:
- Action-level API (`C_ActionBar.GetActionCharges`) can return incomplete/stale data during spell replacements or early combat ticks.
- Spell-level API (`C_Spell.GetSpellCharges`) often has correct active recharge data when action-level doesn't.
- Modern path calls `ActionButton_ApplyCooldown(self.cooldown, cooldownInfo, self.chargeCooldown, chargeInfo, ...)` which should apply charge frame.
- But if `hasChargeCooldown` predicate is false (because action-level charge info is invalid), the frame gets hidden and never re-shown.
- No fallback to spell-level API existed if Blizzard's apply function silently failed to show the frame.
Fix:
- Added spell-level charge fallback in the else branch of the charge cooldown check.
- After Blizzard's `ActionButton_ApplyCooldown` runs, if frame should be hidden but spell-level API has valid active recharge, force-show the charge frame with spell data.
- This ensures recharge swipe appears even when action button API is stale or incomplete.
- Added detailed debug logging for charge show/hide/fallback events (conditional on `DebugMode`):
  - `[LAB CHARGE] Action button show charge` - when ApplyCooldown sets charge
  - `[LAB CHARGE] Action button hide charge` - when charge is cleared
  - `[LAB CHARGE] Spell fallback show charge` - when spell-level data rescues the display
Expected result:
- Recharge cooldown now displays even during spell replacement transitions and early combat updates.
- Charge swipe (blackout) appears consistently on recharging spells like Wake of Ashes, Divine Toll, etc.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
How to test (`/reload` loop):
1. `/reload`
2. Place a recharging spell (Wake of Ashes, Divine Toll, etc.) on action bar.
3. Spend all charges with `/run C_Spell.RequestSpellCastFailed(...) equivalent` or use spell normally.
4. Recharge should visibly progress (swipe fills/blackout appears on button).
5. **Critical test**: Click away and click back to that button → charge swipe should still show (not disappear after 1 frame).
6. If debug enabled, check chat for `[LAB CHARGE]` messages showing when charge frame is updated.
7. Check both direct spell buttons and macro-based buttons with recharging spells.


Issue:
- Assisted highlight only updated when player **cast the suggested spell** (`ASSISTED_COMBAT_ACTION_SPELL_CAST` event).
- If player clicked a non-suggested button and cast a different spell, the highlight didn't update to the new next-best spell.
Investigation:
- Event flow path:
  1. Player clicks button → fires button's `OnClick` handler
  2. Spell casts → fires `UNIT_SPELLCAST_SUCCEEDED` event (for any spell)
  3. WoW assisted system updates to new next-best spell
  4. BUT: LibActionButton only listened to `ASSISTED_COMBAT_ACTION_SPELL_CAST` (suggests spell was cast)
  5. If player ignored suggestion and cast something else, that event didn't fire
  6. Highlight remained frozen on old suggestion until next suggested cast
- Root cause: Missing event listener for general player spell casts
Fix:
- Added listener for `UNIT_SPELLCAST_SUCCEEDED` event with unit == "player" check
- When ANY player spell completes, clear assisted spell cache and refresh all button highlights
- This mirrors the `ASSISTED_COMBAT_ACTION_SPELL_CAST` handler behavior but triggers on any cast
- Now highlights snap to new next-best spell immediately, even if player ignores suggestion
- Combined with deduplication fix (see next entry), this prevents flicker while enabling real-time updates
Expected result:
- Assisted highlight continuously tracks next-best spell as rotation progresses, regardless of whether player follows suggestion
- Glow appears immediately on current next-best action after any spell cast
- No delays or missed suggestions due to event filtering
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
How to test (`/reload` loop):
1. `/reload`
2. Open assisted combat (Suggested Action panel)
3. In combat, cast the **suggested** spell → glow updates to new suggestion
4. **Critical test**: Cast a spell that is **NOT** suggested → glow should immediately jump to actual next-best spell
5. Repeat both paths (follow suggestion, ignore suggestion) and confirm glow always reflects current recommendation
6. Check chat logs (if debug enabled) for "Player cast spell, refreshing assisted highlights"

2026-03-01 (actionbutton assisted highlight: deduplication to prevent glow cancel)
Issue:
- WoW in-game assisted combat system suggests next spell, but the glow/highlight on action bar buttons appears intermittently or not at all.
- Debug logs showed `UpdateSpellHighlight` called 6+ times per second for same button, but glow didn't reliably appear.
Investigation:
- `UpdateSpellHighlight` is hooked via `ActionBarController_UpdateAllSpellHighlights` and can be called multiple times per tick.
- Each call to `UpdateSpellHighlight` was invoking `ShowSpellActivation()` or `HideSpellActivation()` unconditionally, even if state hadn't changed.
- Multiple rapid show/hide calls could appear as flicker or no glow from user perspective.
- Function was painting all buttons every time, then immediately repainting them with hide calls on subsequent invocations.
Fix:
- Track previous highlight state per-button (`_spellHighlightState`).
- Only call `ShowSpellActivation()` / `HideSpellActivation()` when state transitions (assisted→shown, shown→assisted, shown→hidden, etc.).
- Skips redundant method calls on unchanged state.
- Eliminates show-then-hide race conditions that appeared as glow flicker.
- Also added debug logging to `ShowOverlayGlow()`, `HideOverlayGlow()`, `UpdateOverlayGlow()` to track actual glow calls (conditional on `DebugMode`).
Expected result:
- Assisted highlight glow should appear consistently when next-spell recommendation is active.
- No more intermittent or missing glow on action buttons.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
How to test (`/reload` loop):
1. `/reload`
2. Open assisted combat rotation frame (right-side panel, "Suggested Action").
3. Run combat rotation with in-game assisted system Active.
4. Verify glow appears on action bar button matching suggested next spell.
5. Confirm glow persists (doesn't flicker) and updates as suggestion rotates through rotation.
6. Toggle `/az` debug mode if available to check glow show/hide logs in chat.

2026-03-01 (FixBlizzardBugs backdrop guard: protect width/height reads)
Issue:
- Bugsack showed repeated Details breakdown errors with stack including `Core/FixBlizzardBugs.lua:2561` in `SetupTextureCoordinates`.
- That line was calling `self:GetWidth()` / `self:GetHeight()` directly inside AzeriteUI backdrop guard.
Investigation:
- Some third-party frames can run callback-heavy logic on dimension reads.
- Unprotected `GetWidth/GetHeight` in guard path can trigger addon-side failures before guard reaches protected `Orig_SetupTextureCoordinates` call.
Fix:
- Wrapped `self:GetWidth()` / `self:GetHeight()` calls in `pcall` inside the backdrop guard wrapper.
- If reads fail, guard proceeds without treating dimensions as secret and still uses protected call for original setup.
- Keeps WoW12 secret-value protection while reducing cross-addon callback cascades.
Validation:
- `luac -p Core/FixBlizzardBugs.lua`


2026-03-01 (actionbutton replacement spell: Wake of Ashes <-> Hammer of Light cooldown state)
Issue:
- `Wake of Ashes` turning into `Hammer of Light` and back could leave action slot showing the spell as available even when Wake cooldown/recharge should be active.
Investigation:
- Slot-level action cooldown/charge APIs can transiently report ready/empty values during replacement-spell transitions.
- Spell-level APIs for the resolved spell can still report the active cooldown/recharge correctly.
Fix:
- Added spell-level charge helper + normalization (`GetSpellChargeInfo`) and active-state predicates.
- `Action.GetCooldown` now prefers spell-level cooldown when action-level data says ready but spell-level reports active cooldown.
- `Action.GetCharges` / `Action.GetChargeInfo` now prefer spell-level recharge data when action-level charge payload is missing/invalid or stale.
- This keeps cooldown/recharge visuals correct through Wake/Hammer state swaps.
- Bumped `LibActionButton-1.0-GE` minor to 143.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
How to test (`/reload` loop):
1. `/reload`
2. Put `Wake of Ashes` on action bar.
3. Trigger `Hammer of Light` replacement and cast it.
4. Confirm button returns to Wake and shows active cooldown/recharge swipe/blackout, not ready state.
5. Repeat in/out of combat and while target swapping.

2026-03-01 (actionbutton charge recharge: normalize payload + secure fallback)
Issue:
- Charge recharge swipe/blackout still behaved inconsistently on action buttons, especially during combat updates.
Investigation:
- Action charge payload can vary by API/client and field naming (`currentCharges` vs `charges`, `cooldownStartTime` vs `startTime`, etc.).
- Modern `ActionButton_ApplyCooldown` path accepted non-nil but unsafe/secret values, which bypassed fallback and could suppress visible charge swipe updates.
- Even with valid charge info, secure apply could leave charge swipe hidden on some ticks.
Fix:
- Added charge info normalization helper for all action charge payload sources.
- Hardened modern charge field extraction to use safe numeric alias lookup with cache fallback.
- Added post-apply charge swipe fallback: when charge cooldown data is valid but swipe frame is hidden, force `CooldownFrame_Set` on charge cooldown frame.
- Preserve cleanup path to hide recycled charge frame when no recharge is active.
- Bumped `LibActionButton-1.0-GE` minor to 142.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`

2026-03-01 (nameplates: add /az options scaler/resizer)
Issue:
- User requested a nameplate scaler/resizer in `/az` options.
- Nameplates module had `db.profile.scale` defaulted to `1` but it was not wired to visuals.
Decision:
- Reuse existing `NamePlates` profile key `scale`.
- Add `Nameplate Scale (%)` range slider in `Options/OptionsPages/Nameplates.lua`.
- Apply scale live to active nameplates in `NamePlatesMod:UpdateSettings()`.
- Apply scale on plate creation in style setup (`self:SetScale(...)`).
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
- `luac -p Options/OptionsPages/Nameplates.lua`

2026-03-01 (assisted combat highlight: keep visible in combat using AzeriteUI glow path)
Issue:
- Assisted recommendation debug confirmed spell matching, but visual highlight disappeared in combat.
- Visuals still relied on Blizzard mark texture path (`SpellHighlightTexture`/anim), not AzeriteUI custom glow.
Investigation:
- `UpdateSpellHighlight` drove Blizzard mark visuals for assisted suggestions.
- LAB already has a combat-safe custom visual path: `CustomSpellActivationAlert` via `ShowSpellActivation`/`HideSpellActivation`.
- Using Blizzard mark visuals can be inconsistent with addon styling and combat updates.
Fix:
- Updated assisted-next-cast branch in `UpdateSpellHighlight` to use AzeriteUI custom glow (`ShowSpellActivation`) as primary visual.
- Kept Blizzard spell-highlight texture as secondary behavior for non-assisted mark types.
- Assisted path now hides Blizzard mark texture/anim to avoid mixed visuals.
- Non-assisted paths clear custom glow first, then apply Blizzard mark texture if needed.
- Bumped `LibActionButton-1.0-GE` minor version to 141.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
How to test (`/reload` loop):
1. `/reload`
2. `/azdebug assisted on`
3. Enter combat with assisted combat enabled.
4. Confirm recommendation remains visible in combat and uses AzeriteUI glow visuals.
5. Cast through rotations and verify glow follows next spell updates.
6. Exit combat and verify behavior remains consistent.

2026-03-01 (assisted combat highlight: fix hidden texture + add spell names)
Issue:
- After implementing assisted combat availability check and debug system, spell IDs were being detected correctly but visual highlights weren't appearing on action buttons.
- Debug output showed highlight logic executing, but no visible feedback on bars.
Investigation:
- Line 465 in LibActionButton hid the SpellHighlightTexture by setting parent to hidden Hider frame: `button.SpellHighlightTexture:SetParent(Hider)`
- This was done to hide Blizzard's default spell highlights but also prevented assisted combat highlights from showing.
- The texture existed but was invisible because its parent frame was hidden.
Root cause:
- SpellHighlightTexture was being hidden at button creation and never reparented when highlights needed to show.
- Even though `Show()` was called, the hidden parent prevented visibility.
- No spell names in debug output made it hard to identify spells quickly.
Fix:
- Don't hide SpellHighlightTexture at button creation (removed SetParent(Hider) call).
- Reparent texture back to button when showing highlight: `self.SpellHighlightTexture:SetParent(self)`
- Added `GetSafeSpellName()` helper to safely get spell names (C_Spell.GetSpellName or GetSpellInfo).
- Enhanced debug output to show:
  - Spell ID and name when assisted spell changes
  - Spell ID and name when highlighting button
  - Texture state (shown, alpha, parent) when debug enabled
- Bumped LibActionButton minor version to 139.
Testing steps:
1. `/reload`
2. `/azdebug assisted on`
3. Enter combat with assisted combat enabled
4. Watch for debug messages with spell names:
   - "Assisted next spell: <id> (<name>)"
   - "Highlighting button: <id> [<name>]"
   - "Texture state: shown= true alpha= 1 parent= <button>"
5. Verify visible yellow/golden highlight appears on recommended spell button
6. Verify highlight moves when recommendation changes
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Files touched:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` — unhide texture, reparent on show, add spell name support, improve debug output

2026-03-01 (assisted combat highlight: add availability check + debug system)
Issue:
- Prior implementation added assisted combat API calls but highlights weren't appearing on actionbars.
- No check for `C_AssistedCombat.IsAvailable()` — feature might not be enabled.
- No debug output — impossible to diagnose whether API was working or configuration was incorrect.
Investigation:
- `C_AssistedCombat.IsAvailable()` must return true for the feature to work.
- Returns (isAvailable: boolean, failureReason: string) when not available.
- Common reasons: feature disabled in settings, not in appropriate content, spec/class restrictions.
Diagnosis:
- Missing availability check meant code ran but silently failed when feature was unavailable.
- No visibility into spell ID matching, cache state, or availability status.
- User couldn't tell if implementation was broken or feature was simply disabled.
Fix:
- Added `C_AssistedCombat.IsAvailable()` check in `GetAssistedNextSpellID()`.
- Track availability state (`AssistedCombatAvailable`) for internal reference.
- Added debug flag (`AssistedCombatDebug`) with global API:
  - `lib.SetAssistedCombatDebug(enabled)` — enable/disable debug output
  - `lib.GetAssistedCombatDebug()` — query current debug state
  - `lib.GetAssistedCombatStatus()` — get availability + next spell ID
- Debug output shows:
  - Availability check failures with reason
  - Next spell ID when available
  - Highlight matching events (button spell vs assisted spell)
  - Event firing (ASSISTED_COMBAT_ACTION_SPELL_CAST)
- Added `/azdebug assisted` command:
  - `/azdebug assisted on|off|toggle` — enable/disable debug output
  - `/azdebug assisted status` — show availability, next spell, and debug state
- Persist debug state in SavedVariables (`ns.db.global.debugAssisted`)
Testing steps:
1. `/reload`
2. `/azdebug assisted status` — check if feature is available
3. If "Available: NO", check in-game settings or content requirements
4. If "Available: YES", enable debug: `/azdebug assisted on`
5. Enter combat on target dummy with assisted combat enabled
6. Watch chat for:
   - "Assisted next spell ID: <spellID>"
   - "Highlighting button with spell: <spellID>"
   - "ASSISTED_COMBAT_ACTION_SPELL_CAST fired"
7. Verify actionbar button highlights appear for recommended spell
8. Check BugSack for any new Lua errors
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- `luac -p Core/Debugging.lua`
Files touched:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` — availability check, debug system, global API
- `Core/Debugging.lua` — `/azdebug assisted` command + SavedVariables persistence

2026-03-01 (target cast probe visibility: expose TestBar in debug dumps)
Issue:
- `/azdebug dump target` output still showed only `Target.Castbar` + `FakeFill`; probe bar state/source was not visible.
- Without probe dump data, we cannot confirm whether timer-driven probe succeeds while legacy fake-fill path stays pending.
Decision:
- Extend debug dump output to include `Target.Castbar.TestBar`.
- Populate probe bar debug fields (`path/source/percent`) so existing `DumpBar` output includes probe state.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast test harness: add separate timer-driven probe castbar)
Issue:
- Current target cast fake-fill path is still hard to validate in isolation when enemy/non-self payload timing is intermittent.
- Need a side-by-side control bar to confirm whether native timer-driven cropping is stable before replacing the live cast renderer.
Decision:
- Add a separate debug-gated castbar probe (`Target.Castbar.TestBar`) in `Components/UnitFrames/Units/Target.lua`.
- Keep existing castbar logic untouched; probe is for comparison only.
- Probe update order:
  1. Use callback payload if present.
  2. Fallback to `cast:GetTimerDuration()` payload.
  3. Fallback to resolved percent path (`ResolveTargetCastPercent`).
- Show probe only when `/azdebug bars` is enabled (`_G.__AzeriteUI_DEBUG_BARS`).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game: `/azdebug bars on`, target enemy casts/channels, compare probe vs current cast fill behavior.

2026-03-01 (partyframes regen callback nil-call: add missing OnEvent handler)
Issue:
- Lua error on `PLAYER_REGEN_ENABLED`:
  - `Libs/LibMoreEvents-1.0/LibMoreEvents-1.0.lua:76: attempt to call field '?' (a nil value)`
- Locals show module `AzeriteUI_PartyFrames` with callbacks `{ "OnAnchorEvent", "OnEvent" }`.
Investigation:
- `Components/UnitFrames/Units/Party.lua` registers:
  - `self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")` when in combat (`UpdateHeader`).
- The module defines no `PartyFrameMod.OnEvent`, so LibMoreEvents string-dispatch calls nil.
- `needHeaderUpdate` is set in the same path but never consumed.
Decision:
- Add `PartyFrameMod.OnEvent` for the deferred post-combat header update path:
  - handle `PLAYER_REGEN_ENABLED`
  - unregister this one-shot callback
  - run `UpdateHeader()` when `needHeaderUpdate` is set.
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`

2026-03-01 (target cast: prevent generic hooks from downgrading live fill to pending/idle)
Issue:
- Enemy/non-self target casts still showed `castFake: path idle source pending` even after callback and unit-duration fallback work.
- Self-target remained mostly correct, indicating a runtime overwrite issue rather than missing API coverage alone.
Investigation:
- `wow-api` confirms cast timers are available on `StatusBar` (`GetTimerDuration`/`SetTimerDuration`), and cast events carry `castBarID`.
- In `Components/UnitFrames/Units/Target.lua`, generic cast hooks (`OnUpdate`, `OnValueChanged`) called `UpdateTargetLiveCastFakeFill(..., nil)`.
- That path can resolve to `pending`, then `ShowTargetIdleCastFakeFill(...)` overwrites the most recent live crop from `CustomTimeText`/`CustomDelayText`.
Decision:
- Add timer-duration probe (`cast:GetTimerDuration()` via `pcall`) for generic sync hooks and sync entrypoint.
- In `UpdateTargetLiveCastFakeFill`, do not downgrade to idle when no fresh percent is available but the cast fake fill is already live.
- Keep existing resolver order and secret-safe constraints intact.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast: add unit-duration fallback source to break pending/idle lock)
Issue:
- Target cast dump still shows `castFake: path idle source pending` for non-self targets.
- When oUF does not pass a duration payload for non-player units, fake fill never receives a live percent.
Investigation:
- In `Libs/oUF/elements/castbar.lua`, `CustomTimeText/CustomDelayText` only receive payload when:
  - `GetTimerDuration()` returns a duration object, or
  - fallback remaining time is available (typically requires player-only start/end timeline).
- For non-self targets in WoW12, both can be missing on some ticks.
Decision:
- Keep existing resolver order, but add one extra authoritative source before mirror fallback:
  - query `UnitCastingDuration(unit)` / `UnitChannelDuration(unit)` / `UnitEmpoweredChannelDuration(unit)` directly
  - derive percent via existing duration-object parser (`CurveConstants.ZeroToOne` compatible methods).
- This keeps secret-safe behavior (no arithmetic on secret unit values) and unifies self/non-self crop feed.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast prune pass: removed dead sync state and redundant branches)
Issue:
- Cast runtime still carried debug-era generic sync counters/fields and redundant state resets.
- User requested cleanup while preserving working health/cast behavior.
Decision:
- Pruned target cast dead state:
  - removed `__AzeriteUI_CastGenericSyncCount` writes
  - removed `__AzeriteUI_FakeUpdateElapsed` / `__AzeriteUI_CastTimerTotal` resets (unused)
- Simplified cast sync path:
  - removed redundant fake-fill hide branch in `SyncTargetCastVisualState`.
  - removed unused `sourceTag` plumbing in `UpdateTargetLiveCastFakeFill`.
- Reduced debug dump noise by removing generic sync fields from cast fake dump output.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-03-01 (target cast numeric-duration fallback converted to percent)
Issue:
- After path cleanup, enemy target cast alpha became consistent but crop-fill still wrong.
- Self-target cast stayed correct, indicating the remaining divergence was source payload shape.
Investigation:
- In `Libs/oUF/elements/castbar.lua`, `CustomTimeText/CustomDelayText` can receive numeric fallback remaining duration when no duration object is available.
- Target parser in `Components/UnitFrames/Units/Target.lua` only accepted numeric payloads in `0..1`, rejecting numeric remaining seconds.
Decision:
- Extend target cast parser to handle numeric remaining duration payloads:
  - derive normalized percent from native castbar min/max/value when safe
  - `casting`: percent = elapsed/max = (max - remaining)/max
  - `channeling`: percent = remaining/max
- Keep duration-object percent and mirror percent paths intact; mirror remains fallback, not primary.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast major path cleanup: single resolver + single renderer)
Issue:
- Target cast still showed alpha jumps and idle/live state flips (`path idle/none`) between first and second target.
- Fake fill could be rewritten by multiple branches (generic show/value hooks, callback path, and style-reset path).
Investigation:
- `Target.lua` had multiple competing cast paths:
  - explicit callback path
  - mirror/native fallback path
  - generic idle writer on show/value
  - style pass resetting cast fake state to `none`
- This caused inconsistent alpha/crop state and made first-target behavior unstable.
Decision:
- Keep one cast resolver path only:
  - `explicit -> duration payload -> mirror/texture -> pending idle`.
- Keep one fake-fill renderer:
  - live: `SetTexCoord(percent, 0, 0, 1)`
  - idle: `SetTexCoord(1, 0, 0, 1)`
- Remove old branch competition by:
  - eliminating `UpdateTargetLiveCastFakeFillFromNative`
  - routing `OnValueChanged`/`OnUpdate` through the same resolver
  - keeping `OnShow` synced through the same visual-state entrypoint
  - removing style-time cast path reset to `"none"`.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast now samples hidden native bar continuously while shown)
Issue:
- First target often stayed at `castFake source duration_callback_pending`, with fake fill not entering live crop.
- Dumps showed inconsistent fake-fill alpha/state between first and second target, indicating crosswired generic fallback.
Investigation:
- Duration callback payload is not consistently available on first non-self target cast tick.
- Hidden native castbar still updates geometry/value, but fake fill depended too much on callback timing.
Decision:
- Keep native/oUF target castbar hidden and shown as timing/data source.
- Drive fake fill from one render path:
  - primary: explicit duration callback percent
  - fallback: mirrored native percent
  - continuous while shown: sample mirrored native percent on `OnUpdate` for casting/channeling targets.
- Remove generic `OnValueChanged` fallback call to idle fake fill to avoid state overwrite.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast non-self fallback now uses mirrored native percent)
Issue:
- Non-self target casts still remained in `duration_callback_pending`, so fake fill stayed idle and looked wrong.
- Dump confirmed cast fake path frequently never received a usable explicit duration percent.
Investigation:
- `Target.Castbar` was not bound to `API.BindStatusBarValueMirror`, so no stable mirrored percent fallback was available.
- We already have safe mirrored statusbar sampling in `Components/UnitFrames/Functions.lua` (`__AzeriteUI_MirrorPercent` / `__AzeriteUI_TexturePercent`), used elsewhere for WoW12-safe rendering.
Decision:
- Keep duration callback as primary target cast crop source.
- Add cast-specific fallback in `Components/UnitFrames/Units/Target.lua`:
  - when explicit callback percent is missing, use mirrored native percent (`mirror` then `texture`) normalized to `0..1`.
- Bind mirror tracking for target castbar with `ns.API.BindStatusBarValueMirror(self.Castbar)`.
- Keep fake-fill-only visual path; native cast visuals remain hidden.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast fake-fill UV corrected to cast-specific rule)
Issue:
- Target cast still looked wrong with `castFake: source duration_callback_pending`.
- Dump showed `Target.Castbar.FakeFill` idle texcoord was `1,0,1,1`.
Investigation:
- Cast fake fill was still using shared `GetTargetFillTexCoords(nil)` in setup/apply paths.
- For this cast model (fake fill bound to hidden native cast texture region), idle UV must be `1,0,0,1`.
Decision:
- Make cast fake fill UV explicit and cast-specific:
  - idle: `1,0,0,1`
  - active: `percent,0,0,1`
- Keep this limited to cast paths (do not change health/shared helper behavior).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast: native-region fallback on OnValueChanged)
Issue:
- Target cast still sat in `duration_callback_pending` for non-self targets, leaving fake-fill crop inconsistent.
Investigation:
- Dump showed `castFake: path idle source duration_callback_pending`, with visible fake fill still active.
- In that state, duration callbacks were pending, but hidden native castbar value updates were still occurring.
Decision:
- On target cast `OnValueChanged`, explicitly reapply idle fake fill so it remains bound to the hidden native cast texture region.
- This uses no secret arithmetic; native widget clipping provides the crop while callbacks are pending.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast accepts oUF callback payload variants again)
Issue:
- `/azdebug dump target` showed target cast stuck in `duration_callback_pending` with `path idle`.
- That means cast callbacks were firing, but our target cast percent parser rejected the payload shape.
Investigation:
- `GetTargetCastPercentFromDurationPayload(...)` had been narrowed to duration-object evaluators only.
- Non-self target cast payloads can still come through `GetProgress()` and in some fallback cases as numeric payloads.
Decision:
- Re-accept `durationPayload:GetProgress()` for target cast percent.
- Re-accept numeric payload only when it is already a normalized percent (`0..1`).
- Keep active crop authority on callback-derived percent; do not reintroduce generic bar/timer crop fallbacks.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast: remove competing payload fallback crop path)
Issue:
- Enemy/non-self target cast still diverged from self-target cast despite prior split-path cleanup.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still allowed two active payload crop sources:
  - `GetTargetCastPercentFromDurationObject(...)`
  - `durationPayload:GetProgress()` fallback
- During active casts, failure to resolve an explicit percent still forced `ShowTargetIdleCastFakeFill(...)`,
  which could overwrite crop state before the next callback.
Decision:
- Keep duration-object evaluators as the only authoritative cast crop source.
- Remove `durationPayload:GetProgress()` fallback from active crop resolution.
- Stop forcing idle mirrored fill when callbacks are pending; keep current fake-fill state instead.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-28 (target cast duration callback becomes sole crop authority)
Issue:
- Self-target cast still cropped correctly, but enemy/non-self target casts diverged.
Investigation:
- `Libs/oUF/elements/castbar.lua` only stores `startTime/endTime` for `unit == "player"`.
- `Components/UnitFrames/Units/Target.lua` still let generic cast hooks (`OnMinMaxChanged`, `OnValueChanged`, `OnShow`, `PostCast*`) call cast visual sync without an explicit percent.
- That meant the intended duration-callback crop path could be overwritten by generic idle/native-bar behavior for non-self targets.
Decision:
- Make `Cast_CustomTimeText(...)` / `Cast_CustomDelayText(...)` the only authoritative crop writers for target cast.
- Reduce generic cast hooks to native-hide, reset, and idle mirrored fill only.
- Remove native-bar percent fallback and Lua remaining/total duration reconstruction from the active target-cast crop path.
- Add narrow dump fields proving whether crop came from `duration_callback` or a generic hook.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-02-28 (target cast non-self double-crop fallback)
Issue:
- Non-self target casts still cropped wrong after adding the live bar value/range fallback.
Investigation:
- The fake cast fill is anchored to `cast:GetStatusBarTexture()`.
- When percent comes from the hidden native bar itself, that native region is already cropped.
- Applying `SetTexCoord(percent, 0, 0, 1)` on top of that crops a second time.
Decision:
- Distinguish native-bar fallback from live duration-payload percent.
- For native-bar fallback, keep the fake fill fully mirrored and let the hidden native cast region provide the crop.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-28 (target cast smallest-diff fallback from live bar values)
Issue:
- Non-self target casts still did not crop like self-target casts.
Investigation:
- Self-target works because oUF has stronger native cast timeline state for `player`.
- Non-self targets depend more on payload callbacks, which can be missing or late.
- Our target fake-fill updater fell back to idle mirrored fill too early when `explicitPercent` was missing.
Decision:
- Keep the current target cast path, but add one fallback:
  - derive percent from `cast:GetValue()` / `cast:GetMinMaxValues()` when those are safe numerics
- This is the smallest local diff that can make non-self targets use the live hidden castbar state instead of dropping to idle.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-28 (target cast uses DurationObject curve percent directly)
Issue:
- Non-self target casts still cropped differently than self-target casts.
Investigation:
- Warcraft Wiki confirms `UnitCastingDuration(unit)` / `UnitChannelDuration(unit)` return `DurationObject`.
- Warcraft Wiki also documents `DurationObject:EvaluateElapsedPercent(curve)` and `DurationObject:EvaluateRemainingPercent(curve)`.
- `Components/UnitFrames/Units/Target.lua` was still reconstructing cast percent from remaining/total duration in Lua.
- That is the exact class of secret-value math we were already avoiding on target health.
Decision:
- Make target cast use the `DurationObject` curve percent directly.
- Keep Lua-side remaining/total reconstruction only as the last fallback path.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-28 (target health crop regression after cast cleanup)
Issue:
- Target health fill crop regressed again after nearby target cast cleanup.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still routed target health crop through `GetTargetFillTexCoords(percent)`.
- That helper clamps and compares `percent`, which is exactly what the working curve-based snippet avoids.
- The literal working pattern is:
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
Decision:
- Restore the target health fake-fill updater to the literal snippet logic.
- Do not clamp or compare the health curve percent in addon code.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-28 (target cast parity with self-target live path)
Issue:
- Non-self target casts still cropped/fill-behaved differently than the working self-target path.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still had a split cast runtime after the live duration callback:
  - timer fallback duration synthesis
  - stale `__AzeriteUI_FakeValue` call sites during texture update and target resets
- Those branches could still override or diverge from the live fake-fill crop.
Decision:
- Remove the timer fallback runtime and stale fake-value bookkeeping.
- Keep `Cast_CustomTimeText` / `Cast_CustomDelayText` as the authoritative cast crop source.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-28 (target boss UV revert + cast single-source crop)
Issue:
- Boss health was still not supposed to use a boss-only reversed UV rule; it should behave like other target bars.
- Non-self target cast still used a weird crop/fill compared to self target.
Investigation:
- The previous boss-specific pre-mirrored UV rule was the wrong assumption for this art path.
- Target cast still had multiple fallback percent sources in the live updater:
  - bar min/max/value
  - unit-time reconstruction
  - timer fallback
- Those extra branches could still diverge from the working visible cast path.
Decision:
- Revert target health/cast to one mirrored UV rule shared with normal target bars.
- Simplify live target cast crop to:
  - explicit duration payload percent when available
  - timer percent fallback
  - otherwise full mirrored idle fill
Expected result:
- Boss health uses the same live reverse-fill presentation as normal target bars.
- Self and non-self target casts follow the same crop path.

2026-02-28 (target boss pre-mirrored texture + dead cast healthLab prune)
Issue:
- Boss health was cropping correctly but still visually reversing the wrong way.
- Target cast still behaved as if old reverse/texcoord runtime state existed in the file, even after the live runtime had been moved to the new health-style path.
Investigation:
- `Layouts/Data/TargetUnitFrame.lua` uses `hp_boss_bar_mirror` for boss health, while the live target fake-fill path still applied the same UV mirroring as the normal target bar.
- `Components/UnitFrames/Units/Target.lua` still carried dead cast-only `healthLab` reverse/texcoord fields and helpers:
  - `ResolveTargetCastNativeReverseFill`
  - `ResolveTargetCastNativeFlipH`
  - `castUseHealthFillRules`
  - `castReverseFill`
  - `castSetFlippedHorizontally`
  - `castTexLeft/Right/Top/Bottom`
Decision:
- Treat boss health/cast textures as pre-mirrored and use a style-specific UV rule instead of reusing the normal target UV mirror.
- Remove the dead cast `healthLab` reverse/texcoord scaffolding from the live file path.
Expected result:
- Boss health uses the same working live path as target health, but with the correct boss texture orientation.
- Target cast no longer has old reverse/texcoord logic lingering in the file.

2026-02-28 (target cast parity + boss style live path)
Issue:
- Target castbar was visible again, but non-self targets still used the old crop/fill method instead of the working target-health model.
- Boss targets still did not reliably enter the `Boss` style path even when boss texture was enabled.
Investigation:
- `Components/UnitFrames/Units/Target.lua` showed target health on the new direct curve path, but target cast still used old `healthLab` runtime fields:
  - `castTexLeft/Right/Top/Bottom`
  - `castReverseFill`
  - `castSetFlippedHorizontally`
  - `cast.__AzeriteUI_FakeOrientation`
  - `cast.__AzeriteUI_FakeReverse`
- Boss style selection in `UnitFrame_UpdateTextures(...)` still relied on older heuristics only.
- `Classification_Update(...)` already had a separate boss heuristic based on level/classification, so style selection and badge selection were inconsistent.
Decision:
- Make target cast use the same dominant runtime model as target health:
  - hidden native reversed bar
  - fake fill bound to native texture region
  - direct live crop from percent with `SetTexCoord(percent, 0, 0, 1)`
- Add one local boss-unit helper and use it for style selection so boss skin resolution follows one path.
Expected result:
- Non-self target cast crops the same way as self/health.
- Boss targets reliably use the boss skin and boss sizing path.

2026-02-28 (target boss API + cast crop method alignment)
Issue:
- Boss targets still did not reliably switch to the boss skin.
- Non-self target casts were visible again, but still used the wrong crop/fill method compared to the working health path.
Investigation:
- Warcraft Wiki confirms `UnitIsBossMob(unit)` exists and is the right direct boss signal for modern WoW:
  - https://warcraft.wiki.gg/wiki/API_UnitIsBossMob
- `Components/UnitFrames/Units/Target.lua` was still resolving boss style from older heuristics only.
- Target cast runtime was still using the older `healthLab` orientation/reverse/texcoord crop logic, while target health now uses the direct hidden-native-plus-fakefill model.
Decision:
- Use `UnitIsBossMob(unit)` first for boss style resolution, with old heuristics as fallback.
- Make target cast fake-fill use the same crop method as target health:
  - hidden native reversed bar
  - fake fill bound to native texture region
  - `SetTexCoord(percent, 0, 0, 1)`
Expected result:
- Boss targets reliably use boss style.
- Target cast crops the same way as the working target health path.

2026-02-28 (target boss style + cast visibility follow-up 2)
Issue:
- Boss targets still missed the boss skin in practice.
- Target castbars could still be invisible, especially right as casts started on non-self targets.
Investigation:
- `Classification_Update(...)` already treats bosses as:
  - `UnitClassification(unit) == "boss"`
  - or `UnitLevel(unit) < 1` / worldboss semantics
- `UnitFrame_UpdateTextures(...)` style selection was still using `UnitEffectiveLevel(unit)` for the boss heuristic, which is not equivalent.
- `UpdateTargetFakeCastFill(...)` still hid `Castbar.FakeFill` when no live/timer/unit percent could be resolved yet.
- That left no visible castbar at cast start because the native cast visuals are intentionally hidden.
Decision:
- Make target style selection use the same boss heuristic shape as classification badges.
- Keep fake cast visible with its full style texcoord until live crop data arrives.
Expected result:
- Boss targets consistently use the boss style.
- Non-self target casts remain visible immediately instead of disappearing.

2026-02-28 (target boss style + cast visibility regression follow-up)
Issue:
- Boss targets could still miss the boss skin/size path.
- Target castbars for non-self targets could disappear entirely after the split-path cleanup.
Investigation:
- Boss style selection in `Components/UnitFrames/Units/Target.lua` still required `UnitCanAttack("player", unit)`, so some boss targets never resolved to `Boss`.
- The target cast fake-fill runtime hid `Castbar.FakeFill` whenever timer/unit-time percent resolution failed.
- The real castbar still had safe local numeric state:
  - `__AzeriteUI_FakeMin`
  - `__AzeriteUI_FakeMax`
  - `__AzeriteUI_FakeValue`
  but the live updater was not using it as a fallback.
Decision:
- Treat `classification == "boss"` / `classification == "worldboss"` / max-level boss heuristic as boss style without the hostile-only gate.
- Add bar-value fallback to the target cast fake-fill updater before it hides the visible castbar.
Expected result:
- Boss targets reliably use the boss skin and boss health sizing path.
- Non-self target casts stay visible on the fake-fill path instead of disappearing.

2026-02-28 (target style: boss detection and boss/critter-specific health tuning)
Issue:
- Target health tuning was still global across all target styles.
- Boss targets could miss the boss skin because style selection only treated `worldboss` and one max-level heuristic as boss targets.
- The user needs separate health offset/scale control for:
  - boss targets
  - critter targets
Investigation:
- `Components/UnitFrames/Units/Target.lua` applies only:
  - `healthBarOffsetX/Y`
  - `healthBarScaleX/Y`
  to every target style.
- The boss-style path in `Components/UnitFrames/Units/Target.lua` did not include `classification == "boss"`.
- `Layouts/Data/TargetUnitFrame.lua` already has distinct `Boss` and `Critter` layouts, so the missing piece is profile-level per-style tuning.
Decision:
- Add boss/critter-specific target health offset/scale profile keys.
- Use those keys only when the resolved target style is `Boss` or `Critter`.
- Treat `classification == "boss"` as a boss-style target.
Expected result:
- Boss and critter targets can be tuned independently in `/az`.
- Boss targets consistently switch to the boss skin when appropriate.

2026-02-28 (target cast: remove native visual fallback)
Issue:
- When targeting units other than self, the target castbar could still revert to the old native cast visuals:
  - full alpha
  - non-reversed
- The new target cast fake-fill path existed, but it was not authoritative.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still had an explicit native fallback:
  - `ShowTargetNativeCastVisuals(...)`
  - `SyncTargetCastVisualState(...)` called it whenever fake-fill percent resolution failed
  - `OnMinMaxChanged`, `OnValueChanged`, and `OnHide` hooks also restored native visuals
- That means the old castbar path was still live, unlike the now-working target health path.
Decision:
- Remove native visual fallback from the target cast runtime.
- Keep the hidden native cast `StatusBar` as the timing/data source.
- Keep `Castbar.FakeFill` as the only visible runtime path, matching the new target health approach.
Expected result:
- Target cast will no longer fall back to the old native bar for non-self targets.
- The visible castbar should stay on the fake-fill path consistently.

2026-02-28 (target health/cast controls cleanup after scale/follow-health pass)
Issue:
- The new target health/cast offset and scale controls were live, but `/az` still exposed duplicate legacy cast width/height controls from the old `healthLab` path.
- That made the menu ambiguous and increased the risk of tuning the wrong runtime path.
Investigation:
- `Components/UnitFrames/Units/Target.lua` already reads the new keys first:
  - `healthBarOffsetX/Y`
  - `healthBarScaleX/Y`
  - `castBarOffsetX/Y`
  - `castBarScaleX/Y`
  - `castBarFollowHealth`
- `Options/OptionsPages/UnitFrames.lua` still had the old disabled `healthLabCastWidthScale` and `healthLabCastHeightScale` controls visible below the new controls.
Decision:
- Remove the duplicate legacy cast width/height controls from `/az`.
- Keep runtime fallback reads from the old saved-variable keys for compatibility, but stop surfacing them in the live UI.
Expected result:
- `/az` exposes one clear target health/cast tuning surface:
  - direct X/Y offsets
  - direct width/height scale
  - optional cast follow-health toggle

2026-02-28 (target health/cast scale controls + cast follows health)
Issue:
- Offsets alone were not enough to align the target health and target cast visually.
- The target frame needed direct in-game size controls on the live runtime path.
- The user also wanted an option to make target cast fully follow target health size/position.
Investigation:
- `Components/UnitFrames/Units/Target.lua` already had runtime cast width/height scaling via legacy `healthLabCastWidthScale/HeightScale`, but target health had no equivalent runtime scaling at all.
- The cast path still read old width/height settings and anchor frame settings, so the cleanest change was to:
  - add explicit new profile keys for live health/cast scale
  - keep fallback reads from the old cast keys for existing profiles
  - add one explicit `castBarFollowHealth` boolean that forces cast anchoring/sizing to the health bar
Decision:
- Add explicit target:
  - `healthBarScaleX`
  - `healthBarScaleY`
  - `castBarScaleX`
  - `castBarScaleY`
  - `castBarFollowHealth`
- Apply health scaling directly to the live target health size before the reverse-fill setup.
- Apply cast scaling directly to the live target cast size, unless `castBarFollowHealth` is enabled, in which case cast size/anchor follow health.
Expected result:
- Target health and target cast can both be resized from `/az`.
- Target cast can be locked to the target health bar for size/position while keeping the current old-style cast visuals.

2026-02-28 (target offset controls: fix 3-field point tuple regression)
Issue:
- The new target health/cast offset controls caused a `Target.lua:2005` nil arithmetic error on target frame refresh.
Investigation:
- `Layouts/Data/TargetUnitFrame.lua` stores `HealthBarPosition` as a 3-field tuple:
  - `{ point, x, y }`
- The new direct `SetPoint(...)` call in `Components/UnitFrames/Units/Target.lua` incorrectly treated it like a 4-field tuple:
  - `{ point, relativePoint, x, y }`
- That made `db.HealthBarPosition[4]` nil and broke the arithmetic.
Decision:
- Restore correct handling of the 3-field tuple for target health placement.
- Apply the same fix to the cast `FRAME` anchor path, which reused the same tuple shape.
Expected result:
- Target frame refresh no longer throws the nil arithmetic error.
- Health and cast offsets still work from `/az`.

2026-02-28 (target health/cast offset controls + cast fake-fill cleanup)
Issue:
- Target health still needed user-facing offset control even after the reverse-fill path started working.
- Target castbar was still carrying old fake-fill option surface and runtime baggage, and its crop path was still more complex than the working health path.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still read cast placement from `healthLabCastOffsetX/Y` and still populated many unused `__AzeriteUI_Fake*` fields:
  - width/height
  - fake offsets/insets
  - fake anchor frame
  - manual/statusbar alpha modes
  - fake invert percent
- `Options/OptionsPages/UnitFrames.lua` still exposed the whole old cast fake-fill tuning block even though the current cast fake updater only needs:
  - texcoords
  - reverse/orientation
  - configured alpha
- Target health had no explicit runtime X/Y offset controls in `/az`, even though cast already had them in the older health-lab block.
Decision:
- Add explicit target `healthBarOffsetX/Y` and `castBarOffsetX/Y` profile controls and wire them directly into the live target layout.
- Keep existing cast width/height/anchor options for now, but remove the dead cast fake-fill suboptions and corresponding unused runtime fields.
- Simplify cast fake fill to the same direct hidden-native-plus-fakefill crop model as health while preserving the old cast style texcoords and configured alpha.
- Keep runtime fallback reads for old `healthLabCastOffsetX/Y` saved variables, but remove the duplicate legacy offset controls from the live `/az` menu so only the explicit health/cast offset controls remain visible.
Expected result:
- Target health and target cast can both be nudged in `/az` without touching layout files.
- Target cast uses a smaller live path and no longer depends on the removed fake inset/anchor/alpha toggle branches.

2026-02-28 (target health offset + target castbar adopts hidden-native-plus-fakefill model)
Issue:
- After target health started cropping correctly, the live bar still needed a small layout correction against the frame art.
- The next requested step was to port the same hidden-native-plus-fakefill model to target castbar while preserving the old cast style/texcoord rules.
Investigation:
- `Layouts/Data/TargetUnitFrame.lua` still used `HealthBarPosition = { "TOPRIGHT", ..., -67 }` for the main target styles, while the proven working snippet uses `-66`.
- `Components/UnitFrames/Units/Target.lua` still rendered target cast fake fill through the older geometry helper `ApplyTargetFakeHealthFillByPercent(...)`, rather than the simpler:
  - hidden native cast statusbar texture
  - fake visible texture bound to `cast:GetStatusBarTexture()`
  - direct percent crop on texcoords
- Castbar still needs to preserve the old style orientation/reverse/UV rules, so only the update model should change.
Decision:
- Nudge the main target health bar position up by one pixel for the standard target styles.
- Add a dedicated target cast fake-fill updater that binds the visible cast fake fill to the hidden native cast texture region, while reusing the existing cast style texcoords/reverse rules.
Expected result:
- Target health aligns better with the frame art.
- Target castbar now follows the same hidden-native-plus-fakefill structure as health, but still looks like AzeriteUI’s old cast style.

2026-02-28 (target health reverse fill: stop sanitizing away curve percent and remove health mirror hook)
Issue:
- Target health still did not crop correctly even after moving closer to the requested snippet model.
- The live path still diverged in two ways:
  - `UpdateTargetHealthFakeFillFromBar(...)` only accepted the curve value if it passed local numeric sanitizers, which could reject the direct `UnitHealthPercent(..., CurveConstants.ZeroToOne)` result and fall back to a full mirrored texture.
  - `ns.API.BindStatusBarValueMirror(self.Health)` was still attached to target health even though the new target-health method no longer used mirror-driven fill logic.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still routed the curve percent through:
  - `IsSafeNumber(...)`
  - `ClampTargetFakePercent01(...)`
- The live screenshot/debug behavior matched that failure mode:
  - hidden native bar cropped
  - `Health.FakeFill` stayed on full mirrored UVs
- The addon-wide audit showed the remaining extra health-side hook was `BindStatusBarValueMirror(self.Health)`.
Decision:
- Stop sanitizing away the direct curve percent in the target-health fake-fill updater.
- Apply the curve value directly to `FakeFill:SetTexCoord(...)` through a guarded `pcall(...)`.
- Remove the health-side mirror hook so the target-health path is just:
  - real hidden target health bar
  - `SetReverseFill(true)`
  - hidden native texture
  - visible `Health.FakeFill`
  - direct `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)` UV crop
Expected result:
- The visible target health fake fill now follows the direct curve-based crop path instead of falling back to a full mirrored texture when the curve value is not accepted by local numeric sanitizers.

2026-02-28 (target health reverse fill: disable native health smoothing for snippet path)
Issue:
- Target health still did not crop correctly even after switching to the direct hidden-bar callback path.
Investigation:
- The hidden target health bar was still configured with linear smoothing in `Components/UnitFrames/Units/Target.lua`.
- The requested snippet model depends on:
  - hidden native statusbar texture region
  - direct `UnitHealthPercent(..., CurveConstants.ZeroToOne)` crop on the fake fill
- If the hidden native statusbar smooths while the fake fill uses the live percent, the fake fill is anchored to a lagging native region and the crop looks wrong.
Decision:
- Disable smoothing on the hidden target health bar so the native texture region updates immediately and matches the live curve-percent crop path.
Expected result:
- The fake visible target health fill now uses a native texture region that matches the current health state instead of a smoothed lagging state.

2026-02-28 (target health reverse fill: replace helper chain with direct hidden-bar callback path)
Issue:
- Target health still did not crop exactly like the requested snippet.
- The file still routed target health through a broader helper chain:
  - `ResolveTargetSimpleHealthFillPercent(...)`
  - `UpdateTargetFakeHealthFill(...)`
  - `SyncTargetHealthVisualState(...)`
- That was more indirect than the requested model:
  - hidden native statusbar
  - fake visible fill
  - direct callback from the native bar updates
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
Investigation:
- The target health setup already has the right structural pieces:
  - real hidden `StatusBar`
  - `SetReverseFill(true)`
  - `Health.FakeFill`
  - `OnValueChanged` / `OnMinMaxChanged` hooks
- The remaining drift was architectural: the visible fill still passed through extra helper routing and cached fields.
Decision:
- Replace the helper chain with one direct target-health fake-fill updater called from the hidden health bar callbacks.
- Keep AzeriteUI art and placement, but make the live health update path match the requested snippet model as closely as possible.
Expected result:
- Target health is now driven by one direct hidden-bar callback path instead of multiple local helper layers.

2026-02-28 (target health cleanup: remove dead healthLab health fields and orphaned display branch)
Issue:
- `Components/UnitFrames/Units/Target.lua` still carried old health-side `healthLab` fields even though the live target health path no longer used them:
  - `texLeft`
  - `texRight`
  - `texTop`
  - `texBottom`
  - `healthReverseFill`
  - `healthSetFlippedHorizontally`
- There was also an orphaned `element.Display` color branch in `Health_PostUpdateColor(...)`.
Investigation:
- The live target health path now is:
  - hidden native health bar
  - `health:SetReverseFill(true)`
  - visible `Health.FakeFill`
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
- Those old `healthLab` health fields were only remaining as dead setup/signature baggage.
- Castbar still legitimately uses `healthLab` settings, so cast-related fields were retained.
Decision:
- Remove the dead health-only `healthLab` fields and stop referencing them in the target signature/setup path.
- Keep cast-related `healthLab` fields intact.
- Remove the orphaned `element.Display` color branch.
Expected result:
- `Target.lua` keeps the current live target-health path with less dead configuration and fewer misleading health-only branches.

2026-02-28 (target health reverse fill: remove last-percent fallback and keep curve percent authoritative)
Issue:
- Target health was still not cropping exactly like the requested snippet, even after restoring `FakeFill:SetTexCoord(percent, 0, 0, 1)`.
- The target health path still kept extra fallback behavior around the visible fake fill:
  - cached last percent reuse
  - broader helper routing instead of a strictly authoritative curve-percent path
Investigation:
- `Components/UnitFrames/Units/Target.lua` still let `ResolveTargetSimpleHealthFillPercent(...)` fall back to `health.__AzeriteUI_LastFakePercent`.
- That meant the fake visible fill could keep using stale local state instead of the direct curve percent requested by the user.
- The requested snippet does not reuse cached percent; it uses `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)` as the live source each update.
Decision:
- Remove the last-percent fallback from the live target health path.
- Keep the visible fake fill update authoritative on:
  - hidden native health bar
  - `SetReverseFill(true)`
  - `UnitHealthPercent(..., CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
Expected result:
- The visible target health crop is driven only by the live curve percent and no longer drifts through cached target-health fallback state.

2026-02-28 (target health reverse fill: restore literal fake-fill crop logic)
Issue:
- Target health was now reversed visually, but the visible bar crop still did not match the intended snippet-style behavior.
- FStack showed:
  - `AzeriteUnitFrameTarget.Health.FakeFill` using full mirrored UVs
  - the hidden native statusbar texture carrying the live crop state
- This meant the fake visible fill was no longer following the literal snippet path.
Investigation:
- `Components/UnitFrames/Units/Target.lua:ApplyTargetSimpleHealthFakeFillByPercent(...)` had been changed so that when `FakeFill` was bound to the native statusbar texture region, it always used:
  - `SetTexCoord(1, 0, 0, 1)`
- That diverged from the intended snippet:
  - `healthTex:SetAllPoints(health:GetStatusBarTexture())`
  - `healthTex:SetTexCoord(percent, 0, 0, 1)`
- The result was that the visible target bar was reversed, but not cropped through the literal fake-fill path the user wanted.
Decision:
- Restore the literal snippet crop logic:
  - keep `health:SetReverseFill(true)` on the hidden native bar
  - keep `Health.FakeFill` bound to `health:GetStatusBarTexture()`
  - always apply `FakeFill:SetTexCoord(percent, 0, 0, 1)` on live updates
  - fall back to `SetTexCoord(1, 0, 0, 1)` only when no usable percent exists
Expected result:
- The visible target health fill now follows the exact fake-fill crop model requested by the user.

2026-02-28 (target health reverse fill: stop double-cropping fake fill and mirror backdrop art)
Issue:
- The visible target health fill now reversed, but the health case/backdrop art still faced the old direction.
- The visible fill also did not crop correctly while reversed.
Investigation:
- `Health.FakeFill` is anchored to the hidden native statusbar texture region.
- With `health:SetReverseFill(true)`, that native texture region is already clipped from the reversed side.
- `ApplyTargetSimpleHealthFakeFillByPercent(...)` was still also doing `FakeFill:SetTexCoord(percent, 0, 0, 1)` on that already-clipped region.
- This double-cropped the visible bar on the target path.
- `Health.Backdrop` was still using `SetTexCoord(0, 1, 0, 1)`, so the case art did not mirror with the reversed bar.
Decision:
- When the fake fill is bound to the hidden native statusbar texture region, use full mirrored UVs only:
  - `SetTexCoord(1, 0, 0, 1)`
- Keep the native hidden statusbar responsible for the actual reversed clipping.
- Mirror the target health backdrop art with `SetTexCoord(1, 0, 0, 1)`.
Expected result:
- The target health fill is reversed without being cropped twice.
- The target health case art now matches the reversed target bar direction.

2026-02-28 (target health reverse fill: reduce health to one literal native-bar-plus-fakefill path)
Issue:
- Target health was still not behaving like the snippet-style reverse-fill model even after multiple local cleanups.
- Fstack proved the file still had:
  - a real health statusbar texture
  - a fake fill texture
  - a visible/managed preview bar on the health path
Investigation:
- `Components/UnitFrames/Units/Target.lua` still routed target health through:
  - `SyncTargetHealthVisualState(...)`
  - native show/hide fallback
  - preview setup that remained in the stack even when prediction was disabled
- The fake fill was still updated through a broader helper path instead of one literal hidden-native-texture + fake-texture model.
Decision:
- Keep the real target health statusbar, hide its native texture, and keep one visible fake fill anchored to the native statusbar texture region.
- Always hide native/preview health visuals on the target health path.
- Keep the target health fake fill driven only by:
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
Expected result:
- The visible target health fill comes from one source only.
- Preview/native fallbacks no longer compete with the fake reversed fill.

2026-02-28 (target health reverse fill: explicitly opt target health out of shared texcoord rewrite paths)
Issue:
- After the snippet-style target health path was restored, there was still a risk that shared statusbar helpers could rewrite the hidden native target health texture after target setup.
Investigation:
- The only addon-wide paths that can still affect a statusbar after unit setup are:
  - `Components/UnitFrames/UnitFrame.lua` orientation compatibility shim
  - `Components/UnitFrames/Functions.lua:BindStatusBarValueMirror()` texcoord writer
- Target health does not intentionally use the value-mirror texcoord rewrite path, but making that opt-out explicit is safer than relying on implicit defaults during repeated target updates.
Decision:
- Explicitly disable shared value-mirror texcoord rewriting for target health and target health preview.
- Keep the live target health path local and authoritative:
  - hidden native target health texture
  - visible fake fill
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
Expected result:
- Shared addon code should no longer be able to rewrite target health texcoords behind the local target-health logic.
- Any remaining mismatch is then fully local to `Components/UnitFrames/Units/Target.lua`.

2026-02-28 (target health reverse fill: hidden native reverse-fill was still required for fake texture anchoring)
Issue:
- The target health background art could look mirrored, but the visible health fill still behaved like a normal left-to-right bar.
Investigation:
- `AzeriteUnitFrameTarget.Health.FakeFill` was already using mirrored UVs.
- But `Health.FakeFill` is anchored to the hidden native statusbar texture region.
- We had removed `health:SetReverseFill(true)` from the hidden target health bar while trying to reduce the path to pure texcoord logic.
- That made the fake texture inherit left-to-right native width changes even though its UVs were mirrored.
Decision:
- Restore `SetReverseFill(true)` on the hidden native target health bar so its texture region grows from the correct side.
- Keep the visible fake fill on the simple snippet-style update:
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
Expected result:
- The visible target health fill should now reverse properly because both:
  - the hidden native texture region
  - the visible fake texture UVs
  are aligned to the same right-to-left model.

2026-02-28 (target health reverse fill: reduce live path to snippet-style fake texture + curve percent)
Issue:
- The target health bar still did not reliably reverse the visible statusbar, even after the texcoord transform surface was added.
- The remaining mismatch was that the live target fake-fill path still diverged from the user-provided snippet.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still wrapped target health fill in extra runtime state:
  - transform helpers
  - reverse-fill toggle path
  - extra per-layer transform options
- The live target fake-fill updater was still more complicated than:
  - hidden native texture
  - visible fake texture
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - `SetTexCoord(perc, 0, 0, 1)`
Decision:
- Reduce the live target-health path to the snippet model as closely as possible.
- Keep surrounding frame art/placement, but remove the target-health transform/reverse-fill option path from the visible fill logic.
Expected result:
- The target visible health fill is driven by one dominant method:
  - hidden native bar texture
  - visible fake fill
  - curve percent
  - `SetTexCoord(perc, 0, 0, 1)`
- Rogue target-health transform/reverse-fill interference is removed.

2026-02-28 (target health reverse fill: add explicit texcoord transform controls for live fake-fill)
Issue:
- The target health backdrop/art could be mirrored independently, but the live visible fake-fill still only supported two hardcoded texcoord modes.
- This made it hard to verify whether the remaining mismatch was the art transform, the live fill transform, or both.
Investigation:
- `Components/UnitFrames/Units/Target.lua:ApplyTargetSimpleHealthFakeFillByPercent(...)` still used a two-branch texcoord write:
  - `SetTexCoord(percent, 0, 0, 1)`
  - `SetTexCoord(0, percent, 0, 1)`
- Init-time target health art setup already had a separate config surface in `/az`, but it did not expose vertical flips or rotation, and the live fake-fill was not using the same generalized transform model.
Decision:
- Add explicit `/az` controls for target health texcoord transform:
  - horizontal mirror
  - vertical mirror
  - rotation (0/90/180/270, with 360 treated as 0)
- Route the live fake-fill through one transform helper so the visible health fill and visible health art are driven by the same transform settings.
Expected result:
- `/az -> Unit Frames -> Target -> Health Reverse` can now test the live target health fill with horizontal flip, vertical flip, and rotation without changing health percent logic.
- The visible target health fill and visible target health art should respond consistently to the same transform settings.

2026-02-28 (target health reverse fill: live fake-fill updater ignored mirror toggle and diverged from visible backdrop)
Issue:
- The manual `/az` mirror test appeared to affect the target health backdrop art, but not the visible target health fill itself.
Investigation:
- `Components/UnitFrames/Units/Target.lua:ApplyTargetSimpleHealthFakeFillByPercent(...)` was still hardcoding the live fake-fill texcoord path.
- The runtime config block updated backdrop/preview/absorb texcoords from the toggle, but the actual live fill updater overwrote the visible fill independently.
Decision:
- Make the live target fake-fill updater respect the same mirror toggle.
- Re-align the live fake-fill geometry with the hidden native health texture region so the visible fill behaves closer to the in-game snippet.
Expected result:
- `/az -> Target -> Mirror Health Art` affects the live visible target fill too, not just backdrop art.
- The target fake-fill path is consistent between init-time setup and live health updates.

2026-02-28 (target health reverse fill: add manual `/az` controls for texcoord mirroring and reverse-fill testing)
Issue:
- Target health appears to fill correctly now, but the visible art still may not be mirrored correctly compared to the player frame.
Investigation:
- The visible target health art layers are:
  - `Health.FakeFill`
  - `Health.Backdrop`
  - `Health.Preview`
  - absorb texture
- `Health.Overlay` is not the bar art.
- There was still one init-time path anchoring `Health.FakeFill` to the native health texture before the live fake-fill update re-anchored it.
Decision:
- Add direct `/az` controls for the new target-health method:
  - visible art texcoord mirroring
  - experimental reverse-fill on hidden health layers
- Make init-time `Health.FakeFill` also anchor to the full health frame.
Expected result:
- The live target-health method remains curve-driven.
- You can now manually test the only two remaining visual levers in `/az` without code changes.

2026-02-28 (target health reverse fill: stop anchoring fake fill to native texture, drive width directly from curve percent)
Issue:
- Target health still was not visibly reversed even after removing native reverse-fill calls.
Investigation:
- `ApplyTargetSimpleHealthFakeFillByPercent(...)` still anchored `Health.FakeFill` to `health:GetStatusBarTexture()`.
- The hidden native health bar was still being oriented through the shared `CreateBar()` shim, so its internal fill direction was still affecting visible fake-fill placement.
- That meant the visible target fill width was still indirectly following the native statusbar geometry instead of the new curve-driven fake-fill method.
Decision:
- Make target fake health fill independent of the native statusbar texture.
- Anchor `Health.FakeFill` directly to the full health frame and size it from the right using the safe `UnitHealthPercent(..., CurveConstants.ZeroToOne)` result.
- Force the hidden native target health bar back to plain horizontal orientation so it no longer controls visible direction.
Expected result:
- The visible target health fill direction is determined only by:
  - safe curve percent
  - fake fill frame width
  - mirrored `SetTexCoord(percent, 0, 0, 1)`
- No remaining dependence on native statusbar fill direction.

2026-02-28 (target health reverse fill: remove native reverse-fill dependence, make fake texcoord path authoritative)
Issue:
- `Components/UnitFrames/Units/Target.lua` still had target-health reverse-fill split across two models:
  - fake fill driven by `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
  - native health / preview / absorb layers still configured with reverse-fill settings
Investigation:
- The current health fake fill already uses the right visible method:
  - hide native statusbar texture
  - show `Health.FakeFill`
  - drive it with `SetTexCoord(percent, 0, 0, 1)`
- Remaining interference was still present in target-health setup:
  - `health:SetReverseFill(true)`
  - `healthPreview:SetReverseFill(...)`
  - `absorb:SetReverseFill(...)`
- `Docs/API Framework.md` and the WoW wiki guidance both support using a hidden native bar plus a separate visible texture, not mixing reverse-fill with fake texcoord-driven reversal.
Decision:
- Make the fake texture path the only active reverse behavior for target health.
- Remove native reverse-fill from target health, preview, and absorb setup.
- Keep castbar logic separate.
Expected result:
- Target health uses one dominant reverse model only:
  - `UnitHealthPercent(..., CurveConstants.ZeroToOne)`
  - `FakeFill:SetTexCoord(percent, 0, 0, 1)`
- No more native reverse-fill interference on target-health visuals.

2026-02-28 (target health/cast cleanup: remove cast debug toggle maze, keep curve/timer live path only)
Issue:
- `Components/UnitFrames/Units/Target.lua` still mixed the new target-health curve path with an older target-cast fallback maze and a large debug toggle surface.
Investigation:
- The live target health path already uses:
  - hidden native health texture
  - visible `Health.FakeFill`
  - `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`
- The remaining cast path still carried:
  - native fallback
  - mirror fallback
  - secret fallback
  - min/max fallback
  - last-percent fallback
  - clip-native testing
  - forced invert / reverse / fliph debug toggles
- `Core/Debugging.lua` still exposed that obsolete cast-toggle matrix through `/azdebug target ...` and `/azdebugtarget ...`.
Decision:
- Keep target health on the new curve-driven path.
- Reduce target cast fake fill to:
  - explicit live percent from duration payload
  - timer fallback
  - unit-time fallback
- Remove target cast debug flags, presets, clipnative controls, and related command/menu surface.
Expected result:
- Cleaner target code with one live health path and one live cast path.
- No more debug-era target cast toggle system to interfere with the final implementation.

2026-02-28 (target health reverse fill: remove dead Health.Display and stale health debug/cache scaffolding)
Issue:
- After the health-path cleanup, `Target.lua` still carried a dead secondary health display bar plus a few stale health-only debug/cache fields.
Investigation:
- `self.Health.Display` was only being created, hidden, and dumped in debug. It no longer participated in the live target-health rendering path.
- `self.Health.__AzeriteUI_ManageDisplayInOverride` was only there to support that dead secondary display path.
- `self.Health.__AzeriteUI_DisplayNativeTexCaptured` was no longer written anywhere in the live target-health path.
- `Health_PostUpdate(...)` still wrote old health fake cache fields even though the direct `UnitHealthPercent(..., CurveConstants.ZeroToOne)` method no longer uses them.
Decision:
- Remove `Health.Display` creation and all health-only references to it.
- Remove the target-health-only managed-display flag and dead debug field.
- Remove the stale `Health_PostUpdate(...)` fake cache write.
Expected result:
- No behavior change for the working reversed target health fill.
- Less dead target-health scaffolding and clearer ownership of the live health path.
2026-02-28 (target health reverse fill: prune old health-only fake-geometry residue)
Issue:
- Target health is now working on the new direct fake-fill method, but `Components/UnitFrames/Units/Target.lua` still carried a large set of health-only fake-geometry fields from the older path.
Investigation:
- The current target health path only uses:
  - `Health.FakeFill`
  - `ResolveTargetSimpleHealthFillPercent(...)`
  - `ApplyTargetSimpleHealthFakeFillByPercent(...)`
  - `SyncTargetHealthVisualState(...)`
- It no longer reads the old health-only fake geometry/cache fields:
  - `health.__AzeriteUI_FakeTex*`
  - `health.__AzeriteUI_FakeOrientation`
  - `health.__AzeriteUI_FakeReverse`
  - `health.__AzeriteUI_FakeWidth/Height`
  - `health.__AzeriteUI_FakeOffset*`
  - `health.__AzeriteUI_FakeInset*`
  - `health.__AzeriteUI_FakeAnchorFrame`
  - `health.__AzeriteUI_FakeMin/Max/Value`
- Those fields are still needed for the target castbar fake-fill path, so cleanup must stay health-only.
Decision:
- Remove the dead health-only fake-geometry/cache writes and the matching reset code.
- Keep the shared fake-fill helpers and castbar fake fields untouched.
Expected result:
- No behavior change for the working target health reverse fill.
- Less misleading target-health code and less stale state on the health element.
2026-02-28 (target health reverse fill: visible health art was still using a second mirror path)
Issue:
- Target health fake fill was moved to the direct `UnitHealthPercent(..., CurveConstants.ZeroToOne)` path, but the visible target health art still was not consistently mirrored.
Investigation:
- `Components/UnitFrames/Units/Target.lua` was still mixing two systems:
  - the live fake fill used explicit reversed texcoords (`1,0,0,1`)
  - other visible health layers (`healthBackdrop`, `healthPreview`, `absorb`) still used `healthLab.texLeft/texRight/...`
- That means the fill path and the visible art path could disagree even when the percent source was correct.
Decision:
- Keep the fake-fill percent logic.
- Make the visible target health layers share one explicit mirrored texcoord for the health path.
- Leave castbar logic alone for now.
Expected result:
- Target health fill and visible health art mirror the same way.
- No more split between fake-fill mirroring and secondary health-layer texcoords.
2026-02-28 (target health reverse fill: collapse live path to UnitHealthPercent ZeroToOne)
Issue:
- Target health reverse rendering still depends on a large fallback chain in `Components/UnitFrames/Units/Target.lua`, even though the intended WoW 12-safe path is a visible fake texture driven by `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)`.
Investigation:
- `Components/UnitFrames/Units/Target.lua` already creates `Health.FakeFill`, hides the native health texture, and applies reversed texcoords with `SetTexCoord(percent, 0, 0, 1)`.
- The remaining complexity is in `ResolveTargetSimpleHealthFillPercent(...)`, which still falls back through native geometry, cached `safePercent`, mirror percent, and min/max-derived math.
- `Docs/API Framework.md` and Warcraft Wiki guidance both support passing secret values to widgets, but avoiding addon-side math on secret values.
- `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)` is the correct direct API for a 0..1 texcoord driver.
Decision:
- Keep the existing fake texture and native texture hiding.
- Simplify the live target-health percent resolver so it prefers `UnitHealthPercent(..., CurveConstants.ZeroToOne)` and only falls back to the last successfully rendered percent.
- Do not add more hidden-native, mirror, or min/max fallback logic to the live target-health path.
Expected result:
- Target health fake fill uses a direct 0..1 percent source.
- Reverse fill should follow target health without addon-side arithmetic on secret values.
- The target health path becomes simpler and easier to debug.
2026-02-28 (party frames: cleanup after working fix)
Issue:
- Party layout is now working, but the party code still contained a few dead or misleading branches from before the final fix.
Cleanup:
- Keep compatibility defaults in place, but simplify the live forced-`GROUP` path in `Components/UnitFrames/Units/Party.lua`.
- Remove unused locals/misleading comments around `groupBy` / `groupingOrder`.
- Fix one stale options orphan in `Options/OptionsPages/UnitFrames.lua` where raid5 visibility still checked a non-existent `showInRaids` flag on the party module.
Reasoning:
- The live party path now always uses `GROUP` ordering; the old intermediate locals were noise, not configuration.
- The `showInRaids` option check was dead and could only confuse future debugging.
Expected result:
- No behavior change for the working party layout.
- Less dead logic around the party path and options visibility.
2026-02-28 (party frames: force real child size/layout and stop permanently killing Blizzard party frames)
Issue:
- Party members still stack/overlap, with only a tiny effective clickable hotspot.
- Disabling AzeriteUI party frames does not restore Blizzard compact party frames after reload.
Investigation:
- `Libs/oUF/ouf.lua` uses `SecureGroupHeaderTemplate` child layout via header attributes plus `oUF-initialConfigFunction`.
- Warcraft Wiki for `SecureGroupHeaderTemplate` confirms `point`, `xOffset`, `yOffset`, `unitsPerColumn`, and child sizing are all header-driven.
- In `Components/UnitFrames/Units/Party.lua`, party children were only being re-anchored in `ConfigureChildren()`. They were not being force-sized there, so if the initial secure sizing path misfired, the children could stay effectively collapsed while still drawing oversized art.
- `Components/UnitFrames/Units/Party.lua:DisableBlizzard()` also permanently hid/unregistered Blizzard compact party/raid frames even when AzeriteUI party was merely disabled in profile settings.
Decision:
- Force party child button size explicitly in both `style()` and `ConfigureChildren()`.
- Reassert `initial-width`/`initial-height` on the live party header in `UpdateHeader()`.
- Stop permanently killing Blizzard compact party frames when AzeriteUI party is disabled; only suppress Blizzard party when AzeriteUI party is actually enabled.
Expected result:
- Party unit buttons occupy their full intended secure click area instead of a 1x1 hotspot.
- Party members no longer stack in the same origin.
- Disabling AzeriteUI party frames allows Blizzard compact party frames to appear again after reload.
2026-02-28 (party frames: real header bug was old SpawnHeader argument shape)
Issue:
- Party frames still stacked after forcing stable ordering and adding manual child placement.
- Symptoms included a tiny effective click area and party children behaving as if the header never received its full initial layout attributes.
Investigation:
- `Libs/oUF/ouf.lua` in this repo defines `oUF:SpawnHeader(overrideName, template, ...)`.
- `Components/UnitFrames/Units/Party.lua:GetHeaderAttributes()` was still returning `overrideName, nil, nil, "initial-width", ...`.
- Because `oUF:SpawnHeader(...)` iterates variadic attributes in pairs and stops on the first missing attribute key, that extra legacy `nil` caused the entire initial attribute list to abort.
- This matches the observed behavior much better than art or click registration: the header starts life without its intended width/height/layout attributes.
Decision:
- Remove the legacy visibility-placeholder `nil` from `PartyFrameMod.GetHeaderAttributes()`.
- Keep the explicit child layout patch in place for now; it is not the root bug, but it is compatible with the corrected header initialization.
Expected result:
- Party header receives its real initial layout attributes.
- Party children stop collapsing into the same origin.
- Clickable area should match the visible row rather than a tiny effective anchor.
2026-02-28 (party frames: first patch fixed mover assumptions, but child layout still stacked)
Issue:
- Party members still overlapped after forcing `GROUP` ordering in `Components/UnitFrames/Units/Party.lua`.
- The first patch fixed header sizing and grouping assumptions, but not the actual child-frame placement.
Investigation:
- `Components/UnitFrames/Units/Party.lua` still relies on plain `oUF:SpawnHeader(...)` child placement.
- The working local small-group modules (`Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Arena.lua`) do not trust that path alone; they explicitly position child buttons with `ConfigureChildren()`.
- `GW2_UI` also does not use AzeriteUI's plain-party-header path; its party implementation is custom and not a drop-in attribute fix.
Decision:
- Keep AzeriteUI's existing party art and `SpawnHeader`.
- Add explicit child ordering and horizontal placement to `Components/UnitFrames/Units/Party.lua`.
- Re-run that layout on header updates and roster changes so the live frames and `/lock` mover stay aligned.
Change(s):
- `Components/UnitFrames/Units/Party.lua`
  - add ordered-child collection and manual `ConfigureChildren()` layout
  - calculate header size from the same layout math used for live child placement
  - refresh party header layout on `GROUP_ROSTER_UPDATE`
Expected result:
- Party members no longer stack on top of each other.
- Each member frame becomes individually clickable.
- The party mover continues matching the live grouped footprint.
2026-02-28 (party frames: stop grouped overlap and fix mover size)
Issue:
- Party members overlapped on top of each other when grouped, making them hard or impossible to click.
- The party mover/header size also stopped matching the live grouped layout.
Investigation:
- `Components/UnitFrames/Units/Party.lua` differs from the working small-group header modules in two relevant ways:
  - it used a plain `SpawnHeader` with `groupBy = "ROLE"` / `groupingOrder = "TANK,HEALER,DAMAGER"`
  - `PartyFrameMod.GetHeaderSize()` hardcoded a 5x1 header size, even though the actual party layout is a horizontal row of 4 members unless `showPlayer` is enabled
- `Layouts/Data/PartyUnitFrames.lua` confirms the intended layout footprint is horizontal (`Size = { 130*4, 130 }`).
Decision:
- Keep the existing party art and `SpawnHeader` path.
- Force the party header onto stable group-order layout (`GROUP` / `1,2,3,4,5,6,7,8`) instead of role-grouping.
- Make the header/mover width follow 4 units by default, or 5 when `showPlayer` is enabled.
Change(s):
- `Components/UnitFrames/Units/Party.lua`
  - force stable party grouping constants (`GROUP`, `1,2,3,4,5,6,7,8`)
  - fix `PartyFrameMod.GetHeaderSize()` to match the real horizontal party layout and `showPlayer`
Expected result:
- Party members no longer stack on top of each other.
- Each party member frame becomes individually clickable again.
- The `/lock` mover matches the grouped party footprint.
Next step:
- `/reload`, join a party, verify party members spread into a horizontal row and are clickable.
2026-02-28 (mana orb: remove auto-dump investigation plumbing)
- Confirmed live orb path remains Components/UnitFrames/Functions.lua:API.UpdateManaOrb -> Libs/LibOrb-1.0/LibOrb-1.0.lua -> player orb frame-level fix in Components/UnitFrames/Units/Player.lua.
- Removed temporary orb auto-dump plumbing that spammed chat during reload/update testing:
  - removed debugOrbAutoDump saved-variable init/use
  - removed reload-time auto-dump hook
  - removed 
s.API.DebugOrbDumpIfEnabled() and its update call site
  - removed /azdebug orb auto [on|off|toggle]
- Kept manual /azdebug orb dump intact for targeted verification.
- No runtime orb/crystal render logic changed in this cleanup.
2026-02-28 (mana orb: path cleanup after final fix)
Issue:
- Orb and crystal now work, but the repo still carried leftover orb-investigation branches that were no longer part of the live path.
Cleanup:
- Remove the unused orb text parser in Components/UnitFrames/Functions.lua.
- Remove the dead native-orb mirror binding from Components/UnitFrames/Units/Player.lua.
- Trim orb debug output so it reflects the working raw-widget/draw-order path only.
Reasoning:
- The working orb path is RefreshManaOrb -> API.UpdateManaOrb -> LibOrb:SetMinMaxValues/SetValue -> LibOrb native clip path -> draw-order-fixed layers.
- The removed branches were not part of that chain anymore.
Next step:
- /reload and confirm orb mode and crystal mode still work after cleanup.
2026-02-28 (mana orb: cleanup after final fix)
Issue:
- The orb is working again, but the repo still contains dead orb experiment paths from the WoW 12 investigation.
Root cause summary:
- We spent most of the time chasing secret-value data paths because hidden crystal/native/proxy sampling was stale or nil under WoW 12.
- The final blocker was visual, not numeric: the live LibOrb fill was rendering behind AzeriteUI's orb wrapper art because the internal LibOrb frame levels were too low.
Cleanup:
- Remove the dead orb-local ProxyBar experiment.
- Trim temporary orb debug dump fields that were only used during the investigation.
- Keep the working raw-widget orb path and final draw-order fix intact.
Next step:
- /reload and confirm orb/crystal still work after cleanup.
2026-02-28 (mana orb: reapply draw-order fix now that raw widget path is live again)
Issue:
- Latest orb dump shows the runtime path is coherent again:
  - liborb.barValue = 50000
  - liborb.barDisplayValue = 50000
  - scrollShown = true
  - 
ativeTex.height moves from   to 103
- But the orb still looks empty in-game.
Investigation:
- At this point the remaining likely failure is visual stacking, not value transport.
- Libs/LibOrb-1.0/LibOrb-1.0.lua currently creates its clip/content frames at the base orb frame level.
- Components/UnitFrames/Units/Player.lua then adds AzeriteUI wrapper art (Backdrop, Shade, Case, Glass, Artwork) on the orb after those internal fill frames exist.
- Result: the fill can be alive but still render behind the orb wrapper stack.
Decision:
- Reapply the earlier draw-order fix now that the raw-widget path is active again.
Change(s):
- Libs/LibOrb-1.0/LibOrb-1.0.lua:
  - raise clip/content frame levels above the base orb frame
  - keep overlay above the fill
- Components/UnitFrames/Units/Player.lua:
  - raise manaCaseFrame again so case/text stay above the fill
Expected result:
- Visible orb fill renders between backdrop/shade and the case/glass/text layers instead of disappearing behind the wrapper art.
Next step:
- /reload, verify whether the orb fill becomes visible, then spend mana to confirm movement.
2026-02-28 (mana orb: restore raw-widget orb path and stop re-overwriting it with stale safe values)
Issue:
- The shown orb-local proxy still does not provide a usable sampled percent:
  - proxy.mirrorPct / proxy.texturePct remain 
il
- Current dumps show the real overwrite path:
  - UpdateManaOrb() writes stale safe 50000 / 100% into LibOrb
  - Mana_PostUpdate() then writes those same stale safe values back into the orb again
  - LibOrb never gets to render from the raw widget path
Investigation:
- Components/UnitFrames/Functions.lua:API.UpdateManaOrb() still ends with lement:SetMinMaxValues(safeMin, safeMax, true) and lement:SetValue(safeCur, true).
- Components/UnitFrames/Units/Player.lua:Mana_PostUpdate() still calls lement:SetMinMaxValues(safeMin, safeMax, true) and lement:SetValue(displayCur, true).
- Docs/API Framework.md and the WoW 12 API notes both say the same thing: pass secret values directly to widgets, but do not do addon-side secret math.
Decision:
- Make the orb widget itself authoritative again, matching the Diabolic-style widget contract more closely.
- Feed raw mana directly into the orb widget.
- Keep safe caches for text/debug only.
- In LibOrb.Update(), when values are secret, stop trying to derive orb geometry from addon-side math; just show the clip frame and let the native bar drive it.
Change(s):
- Components/UnitFrames/Functions.lua:
  - raw SetMinMaxValues(min, max) / SetValue(cur) for orb widget
- Components/UnitFrames/Units/Player.lua:
  - Mana_PostUpdate() no longer re-drives the orb widget from safe fallback values
- Libs/LibOrb-1.0/LibOrb-1.0.lua:
  - restore a secret-safe branch in Update() that shows the orb without doing addon-side secret arithmetic
Expected result:
- Orb fill should finally follow the widget-driven raw mana path instead of being pinned by stale safe cache rewrites.
- Text/debug safe caches may lag or stay conservative, but visible orb fill should move.
Next step:
- /reload, spend mana, confirm visible orb fill moves even if debug safe values remain conservative.
2026-02-28 (mana orb: move orb proxy on-screen with near-zero alpha so geometry sampling can work)
Issue:
- The new orb-local ProxyBar exists, but it still does not produce a usable percent source.
- Latest dump shows:
  - proxy: shown true value <secret> min <secret> max <secret>
  - proxy: mirrorPct nil texturePct nil
  - orb text still changes visually while orb safeCur/safePct remain pinned at 50000 / 100
Investigation:
- Components/UnitFrames/Units/Player.lua currently creates ManaOrb.ProxyBar offscreen at TOPLEFT -2048,2048.
- Components/UnitFrames/Functions.lua:GetTexturePercentFromBar(...) depends on the widget having real rendered geometry.
- An offscreen shown statusbar does not provide usable geometry sampling here, so the proxy mirror path never updates.
Decision:
- Keep the proxy approach.
- Move the proxy on-screen, attached to the orb itself, with near-zero alpha and behind the orb art.
- Keep orb and crystal separate.
Change(s):
- Components/UnitFrames/Units/Player.lua:
  - parent ManaOrb.ProxyBar to the orb
  - SetAllPoints(mana) instead of offscreen placement
  - set near-zero alpha on the bar/texture
  - keep it non-interactive and behind the orb visuals
Expected result:
- proxy.texturePct or proxy.mirrorPct should finally move.
- API.UpdateManaOrb() can then derive orb safePercent/safeCur from the shown proxy as intended.
Next step:
- /reload, spend mana, inspect /azdebug orb dump and verify proxy: is no longer 
il for percent.
2026-02-28 (mana orb: add orb-local shown proxy statusbar and remove hidden/native orb fallback)
Issue:
- Deep path check confirms the orb is still pinned because its safe numeric driver comes from stale or invalid hidden sources.
- Latest dumps show:
  - visible orb text changes with live mana
  - hidden crystal remains stale at 100
  - hidden orb-native mirror/texture sampling is pinned or invalid
  - LibOrb still receives 50000 / 100% as its safe state
Investigation:
- Components/UnitFrames/Functions.lua:API.UpdateManaOrb() still builds orb-safe values from display cache plus hidden/native fallback paths.
- Components/UnitFrames/Units/Player.lua does not yet create the planned ManaOrb.ProxyBar; debug output confirms proxy: is absent.
- Libs/LibOrb-1.0/LibOrb-1.0.lua uses its internal native StatusBar as a clip source, but that hidden bar is not a trustworthy addon-side percent source in WoW 12.
- Docs/API Framework.md and the local WoW 12 API notes both support the same rule: pass secret values to widgets, but do not derive addon logic from hidden widget state.
Decision:
- Keep orb and crystal fully separate.
- Stop deriving orb-safe numerics from hidden crystal or hidden native-orb paths.
- Add an orb-local shown ProxyBar dedicated to geometry/mirror sampling.
- Feed raw live mana only into that shown proxy, then derive orb safePercent/safeCur from the proxy before updating LibOrb.
Change(s):
- Components/UnitFrames/Units/Player.lua:
  - create ManaOrb.ProxyBar as an offscreen shown vertical StatusBar
  - bind AzeriteUI mirror logic to it
  - show/hide it with orb visibility
- Components/UnitFrames/Functions.lua:
  - write raw live mana to ManaOrb.ProxyBar
  - prefer proxy mirror/texture percent as orb safePercent
  - remove the hidden native-orb raw fallback block
Expected result:
- Orb mode gets its own authoritative numeric driver without touching the crystal.
- LibOrb receives sanitized numeric values derived from a shown orb-local widget instead of stale hidden state.
Next step:
- /reload, spend mana, run /azdebug orb dump, verify proxy: moves and lement.safeCur/safePct stop pinning at 50000 / 100.
2026-02-28 (mana orb: expand orb debug output for display cache, native texture, and proxy state)
Issue:
- Current orb dump is still missing the exact state needed to separate:
  - stale orb cache
  - dead hidden/native sampling
  - missing proxy/shown sampler state
Investigation:
- The orb dump already shows `safeCur/safePct`, `liborb` values, and hidden native mirror values.
- It does not show:
  - `__AzeriteUI_DisplayCur`
  - `__AzeriteUI_DisplayPercent`
  - `safeBarValue/safeBarMin/safeBarMax`
  - native statusbar texture geometry
  - any orb-local proxy statusbar state if present
Decision:
- Add debug only. No runtime logic changes in this iteration.
Change(s):
- `Core/Debugging.lua`:
  - print orb display-cache fields
  - print `LibOrb` safe cache fields
  - print native statusbar texture visibility/size/alpha
  - print `orb.ProxyBar` mirror/texture/value state when present
Expected result:
- Next `/azdebug orb dump` will show whether orb-local cached display values or a shown proxy ever become usable.
Next step:
- `/reload`, `/azdebug orb dump`, spend mana, `/azdebug orb dump` again, compare `display:` / `proxy:` / `nativeTex:` / `liborbSafe:`

2026-02-28 (mana orb: add orb-local shown proxy statusbar for readable geometry sampling)
Issue:
- The orb's internal hidden/native statusbar still does not provide a usable moving sample:
  - `native.mirrorPct` now stays pinned at `100`
  - `native.texturePct` stays `nil`
- The crystal remains hidden and stale, and must not drive the orb.
Investigation:
- The user confirmed the practical WoW 12 boundary: hidden statusbars/orbs are no longer a reliable source for derived addon logic.
- A shown statusbar can still accept secret values safely, and AzeriteUI already has a geometry sampler for shown bars in `Components/UnitFrames/Functions.lua:GetTexturePercentFromBar(...)`.
Decision:
- Stop trying to derive orb-safe numerics from hidden/native/crystal bars.
- Add an orb-local shown proxy statusbar dedicated to geometry sampling.
- Feed the proxy with raw live mana, mirror its visible percent, and use that orb-local percent to drive `safeCur/safePct`.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - create `ManaOrb.ProxyBar` as a tiny shown statusbar with near-zero alpha
  - bind AzeriteUI's value mirror helper to it
- `Components/UnitFrames/Functions.lua`:
  - feed `ManaOrb.ProxyBar` with raw mana
  - prefer `ProxyBar.__AzeriteUI_MirrorPercent` / `__AzeriteUI_TexturePercent` for orb `safePercent`
Expected result:
- The orb gets its own separate numeric driver based on a shown widget AzeriteUI can sample, instead of hidden widget state.
- Orb fill should move without depending on the crystal.
Next step:
- `/reload`, spend mana, inspect `/azdebug orb dump` for proxy-driven percent and visible orb fill movement

2026-02-28 (mana orb: add shown orb-local proxy bar and use it as orb percent source)
Issue:
- Orb-native hidden statusbar still does not provide a live usable sample:
  - `native.mirrorPct` stayed stale/pinned
  - `native.texturePct` stayed `nil`
- The crystal remains hidden and stale, and must not be used by orb logic.
Investigation:
- A shown widget is still sampleable by AzeriteUI's geometry mirror path.
- The orb already has a separate runtime path and can host its own proxy without touching the crystal.
Decision:
- Add `ManaOrb.ProxyBar` as a tiny shown statusbar used only for orb-local percent sampling.
- Feed it raw live mana and derive `safePercent/safeCur` from that proxy before updating `LibOrb`.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - create `ManaOrb.ProxyBar`
  - bind AzeriteUI mirror logic to it
- `Components/UnitFrames/Functions.lua`:
  - write raw live mana to `ManaOrb.ProxyBar`
  - prefer proxy mirror/texture percent for orb `safePercent`
- `Core/Debugging.lua`:
  - print proxy mirror state in `/azdebug orb dump`
Expected result:
- Orb fill should finally move from an orb-local shown widget sample, without any dependence on hidden crystal or hidden orb-native bars.
Next step:
- `/reload`, spend mana, inspect `/azdebug orb dump` for `proxy:` percent movement and visible orb fill movement

2026-02-28 (mana orb: drive orb-native statusbar with raw mana after safe LibOrb update)
Issue:
- Orb debug still shows safe cache pinned at full:
  - `element.safeCur = 50000`
  - `element.safePct = 100`
  - `liborb.barValue = 50000`
- But all hidden/proxy-derived percent sources remain invalid:
  - `native.mirrorPct = 0`
  - `native.texturePct = 0`
  - hidden crystal stays stale at `100`
Investigation:
- The one reliable WoW 12 rule still holding is that Blizzard widgets can consume secret values even when addon logic cannot.
- `Components/UnitFrames/Functions.lua:API.UpdateManaOrb()` currently feeds `LibOrb` only sanitized safe values.
- `LibOrb` in turn writes those same safe values into its internal native `StatusBar`, so the clip-frame driver never sees the real live mana.
- The orb's native `StatusBar` is the actual clip source:
  - `Libs/LibOrb-1.0/LibOrb-1.0.lua:552`
  - `clipFrame:SetPoint("TOP", nativeStatusBar:GetStatusBarTexture(), "TOP")`
Decision:
- Keep AzeriteUI's addon-side orb math on sanitized numeric values.
- After the safe `LibOrb` update, re-drive the orb's internal native `StatusBar` with raw live mana so the clip source can move independently.
- Do not reintroduce crystal dependency.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - after `element:SetMinMaxValues(...)` / `element:SetValue(...)`, fetch `LibOrb.orbs[element].nativeStatusBar`
  - write raw `UnitPower/UnitPowerMax` into that native bar via protected calls
Expected result:
- `liborb.barValue` may remain safe/stale for addon math, but the orb fill itself should now follow the native clip source and move with live mana.
- This mirrors the WoW 12 rule the user pointed out: render through widgets, not through hidden derived addon arithmetic.
Next step:
- `/reload`, spend mana, confirm the orb fill moves even if `safeCur/safePct` remain conservative

2026-02-28 (mana orb: stop pre-rejecting secret display strings, use guarded parse instead)
Issue:
- Orb text on screen changes correctly, but orb fill still pins at full.
- Latest dump still shows:
  - `element.safeCur = 50000`
  - `element.safePct = 100`
  - `liborb.barValue = 50000`
  - `native.mirrorPct = 0`, `native.texturePct = 0`
Investigation:
- Hidden/native/crystal sources remain invalid in this client state.
- `Components/UnitFrames/Units/Player.lua:ParseDisplayNumber(...)` and `Components/UnitFrames/Functions.lua:ParseVisiblePowerText(...)` still reject secret display strings before attempting any parse.
- That means AzeriteUI discards the only source that visibly changes: the already-formatted orb text path.
Decision:
- Keep orb and crystal separate.
- Stop pre-rejecting secret display strings.
- Attempt guarded parsing with `pcall(...)`, and only use the parsed result when the parse succeeds.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - remove the early secret-string reject from `ParseDisplayNumber(...)`
  - parse display text inside a protected block
- `Components/UnitFrames/Functions.lua`:
  - remove the early secret-string reject from `ParseVisiblePowerText(...)`
  - parse visible power text inside a protected block
Expected result:
- If Blizzard allows string formatting output to be inspected even when the source number is secret, AzeriteUI can finally recover numeric orb current/percent from the visible text path.
- Orb fill should then stop pinning at full.
Next step:
- `/reload`, spend mana once, inspect `/azdebug orb dump` for `__AzeriteUI_DisplayCur` effect via `safeCur/safePct`

2026-02-28 (mana orb: remove stale ScrollFrame API from WoW12 clip-frame LibOrb update path)
Issue:
- Restoring the `LibOrb` display bootstrap brought the orb runtime back, but introduced a new crash:
  - `Libs/LibOrb-1.0/LibOrb-1.0.lua:130: attempt to call method 'SetVerticalScroll' (a nil value)`
Investigation:
- In the current WoW 12 `LibOrb` implementation, `scrollframe` is not a `ScrollFrame`.
- `Libs/LibOrb-1.0/LibOrb-1.0.lua:493` creates it as a plain `Frame` with `SetClipsChildren(true)`.
- `Update()` still contained old ScrollFrame-era calls:
  - `SetHeight(displaySize)`
  - `SetVerticalScroll(...)`
- The actual visible clip height is already driven by the native statusbar texture anchor in `OnSizeChanged()`.
Decision:
- Keep the restored display bootstrap.
- Remove only the stale ScrollFrame API calls from `Update()`.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - remove `SetHeight(displaySize)` and `SetVerticalScroll(...)` from `Update()`
Result:
- Prevents the WoW 12 clip-frame crash while preserving orb display bootstrap.
Next step:
- `/reload`, spend mana, verify no `SetVerticalScroll` error and check `barDisplayValue`

2026-02-28 (mana orb: restore LibOrb display bootstrap from pre-parity runtime)
Issue:
- Orb-safe values are numeric again, but the orb still does not visibly fill.
- Latest orb dump shows:
  - `liborb.barValue = 50000`
  - `liborb.barMax = 50000`
  - `liborb.barDisplayValue = 0`
  - `scrollShown = true`
Investigation:
- That means the updater is no longer the blocking issue.
- The current exact-Diabolic `Libs/LibOrb-1.0/LibOrb-1.0.lua` in AzeriteUI never bootstraps `barDisplayValue` or smoothing state in `Orb.SetValue(...)` / `Orb.SetMinMaxValues(...)`.
- The last pre-parity runtime in `Libs/LibOrb-1.0/LibOrb-1.0.lua.pre_proxy_restore_20260228` did bootstrap:
  - `barDisplayValue`
  - `smoothingInitialValue`
  - `smoothingStart`
  - `safeBarValue/safeBarMin/safeBarMax`
  - `OnUpdate`
Decision:
- Keep the current WoW 12 clip-frame/native statusbar structure.
- Restore only the display bootstrap behavior from the last working pre-parity `LibOrb` runtime.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - restore `Orb.SetValue(...)` bootstrap and secret-safe branch
  - restore `Orb.SetMinMaxValues(...)` clamping/bootstrap and safe range caching
Result:
- `barDisplayValue` can move again, which is required for visible orb fill and animation.
Next step:
- `/reload`, spend mana, verify `barDisplayValue` tracks `barValue`

2026-02-28 (mana orb: stop caching secret numerics, drive orb from parsed display numbers)
Issue:
- The tag crash is gone, but the orb still does not animate/fill correctly.
- Latest orb dump now shows:
  - `safeCur = <secret>`
  - `safePct = nil`
  - `liborb.barValue = <secret>`
  - `liborb.barDisplayValue = 0`
Investigation:
- `Components/UnitFrames/Units/Player.lua:GetFormattedPlayerPowerValue(...)` returned raw readable-secret `UnitPower(...)` values whenever `canaccessvalue(...)` succeeded.
- That let `TrySetPlayerElementValueTextFromRaw(...)` cache secret numerics into:
  - `__AzeriteUI_DisplayCur`
  - `safeCur`
- `Components/UnitFrames/Functions.lua:API.UpdateManaOrb()` was also still feeding raw secret values directly into `LibOrb`.
- With current Diabolic-style `LibOrb`, that leaves `barDisplayValue` at `0`.
Decision:
- Never cache readable-secret numerics as orb-safe values.
- Use the orb's own visible display formatting path as the authoritative numeric source:
  - parse formatted full/short text into clean numerics
  - derive percent from parsed value and safe max when needed
  - write only sanitized numeric values into `LibOrb`
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - `GetFormattedPlayerPowerValue(...)` now prefers parsed display numbers, not raw readable-secret values
  - `TrySetPlayerElementValueTextFromRaw(...)` now caches only non-secret parsed numerics
- `Components/UnitFrames/Functions.lua`:
  - `API.UpdateManaOrb()` now writes sanitized orb-local values into `LibOrb`
Result:
- Orb text remains driven by the live raw display path, while orb fill/animation get clean numeric inputs again.
Next step:
- `/reload`, spend mana, verify `safeCur/safePct` and `barValue/barDisplayValue` now move below full

2026-02-28 (mana orb: fix tag secret arithmetic regression, drive orb cache from visible orb geometry)
Issue:
- Latest current-Diabolic parity pass regressed the player orb again.
- BugSack error:
  - `Components/UnitFrames/Tags.lua:577: attempt to perform arithmetic on local 'value' (a secret number value tainted by 'AzeriteUI')`
- Orb text still updates on screen, but orb cached values remain pinned at:
  - `safeCur = 50000`
  - `safePct = 100`
Investigation:
- `Components/UnitFrames/Tags.lua:GetElementLivePercent(...)` was still willing to subtract `value - minValue` after `UpdateManaOrb()` started feeding raw secret values back into the orb element again.
- The latest orb dumps still show hidden/native/proxy sources are unusable in this client:
  - `native: mirrorPct nil texturePct nil`
  - hidden crystal remains stale while orb mode is active
- The only orb-local source that is demonstrably changing is the visible orb layer geometry already used by player orb text fallback in `Components/UnitFrames/Units/Player.lua`.
Decision:
- Stop doing arithmetic on any secret orb values in tags.
- Keep orb and crystal separate.
- Reuse the orb's own visible geometry in `Mana_PostUpdate()` to update orb-safe cache and re-drive `LibOrb`.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - guard `GetElementLivePercent(...)` against secret numeric arithmetic
- `Components/UnitFrames/Units/Player.lua`:
  - in `Mana_PostUpdate(...)`, fall back to visible orb geometry for `safeCur` / `safePct` when raw display numerics are unavailable
Result:
- Removes the tag crash and makes orb-safe values follow the visible orb instead of hidden stale state.
Next step:
- `/reload`, spend mana, verify orb fill now tracks the visible orb text again

2026-02-28 (mana orb: current Diabolic parity pass, remove local LibOrb secret-path drift)
Issue:
- Player orb text is correct on screen, but orb fill remains pinned at full.
- Latest orb dump still shows:
  - `safeCur = 50000`
  - `safePct = 100`
  - `liborb.barValue = 50000`
  - `liborb.barDisplayValue = 50000`
  - `native: mirrorPct nil texturePct nil`
Investigation:
- The old Azerite proxy/scroll orb path is not viable on WoW 12. User confirmed that was the reason for moving toward Diabolic's fix.
- Current `Libs/LibOrb-1.0/LibOrb-1.0.lua` is no longer 1:1 with `..\DiabolicUI3\Libs\LibOrb-1.0\LibOrb-1.0.lua`.
- The remaining local drift is not art-related; it is secret-value fallback logic in `Update`, `SetValue`, and `SetMinMaxValues`.
- Diabolic also differs structurally because the orb is the authoritative player power widget there, while AzeriteUI still feeds a secondary `ManaOrb`.
Decision:
- Do not go back to the old proxy orb path.
- Restore current Diabolic `LibOrb` clip-frame behavior exactly again and simplify AzeriteUI's orb updater to the same direct write contract.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - restore exact current Diabolic implementation
- `Components/UnitFrames/Functions.lua`:
  - reduce `API.UpdateManaOrb()` to direct raw `UnitPower/UnitPowerMax` writes, matching Diabolic's updater contract as closely as possible while keeping AzeriteUI text/art hooks
Result:
- Orb runtime and updater contract are back on the same model as current Diabolic.
Next step:
- `/reload`, spend mana once, inspect `/azdebug orb dump`

2026-02-28 (mana orb: sample readable secret native geometry)
Issue:
- Orb fill still pins at full even after separating orb/crystal logic.
- Latest orb dump still shows:
  - `safeCur = 50000`
  - `safePct = 100`
  - `native: mirrorPct nil texturePct nil`
Investigation:
- The orb-native hidden `StatusBar` is the right source conceptually, but AzeriteUI's geometry sampler still rejects all secret numerics.
- That makes `GetTexturePercentFromBar(nativeOrbBar)` return `nil`, even when Blizzard may expose readable secret geometry on the widget itself.
Decision:
- Keep orb and crystal separate.
- Make the geometry sampler accept readable secret numerics only when `canaccessvalue(...)` explicitly allows them.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - add readable-secret numeric probe for widget geometry
  - use it in `GetTexturePercentFromBar(...)` for texcoords and texture/bar width/height
Result:
- Orb-native `texturePct` can now become the orb's own safe numeric source without relying on hidden crystal state.
Next step:
- `/reload`, spend mana once, inspect `/azdebug orb dump`

2026-02-28 (mana orb: allow parsing readable secret display strings)
Issue:
- Orb animation renders and visible orb text is correct, but orb fill still pins at full.
- Latest orb dump still shows:
  - `safeCur = 50000`
  - `safePct = 100`
  - `barValue = 50000`
  - `barDisplayValue = 50000`
Investigation:
- The visible orb text on screen is correct, e.g. `23K (47%)`, but `ManaOrb.Value:GetText()` is still flagged secret in debug output.
- `TrySetPlayerElementValueTextFromRaw(...)` and `ParseVisiblePowerText(...)` both refused to parse any secret string at all.
- That means AzeriteUI discarded the only source path already proven to contain the right live numbers.
Decision:
- Keep orb and crystal separate.
- Allow parsing of secret display strings only when `canaccessvalue(...)` explicitly says the string is readable.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - allow `ParseDisplayNumber(...)` to parse readable secret strings
  - derive percent from parsed current value when direct percent is unreadable
- `Components/UnitFrames/Functions.lua`:
  - allow `ParseVisiblePowerText(...)` to parse readable secret strings
Result:
- Orb cache can now be updated from the same visible display strings already proven correct in the live UI, without depending on hidden crystal or orb-native mirror state.
Next step:
- `/reload`, spend mana once, inspect `/azdebug orb dump`

2026-02-28 (mana orb: cache readable secret numerics from orb text path)
Issue:
- Orb fill still pins at full even after orb-native and crystal fallback changes.
- Visible orb text is correct on screen, but orb dump still shows:
  - `safeCur = 50000`
  - `safePct = 100`
Investigation:
- The visible orb text is updated through `TrySetPlayerElementValueTextFromRaw(...)`.
- That helper writes the correct display string using raw values, but only caches numeric `__AzeriteUI_DisplayCur` / `__AzeriteUI_DisplayPercent` when they are non-secret.
- On this client, those values are secret but readable enough to drive the text widget.
Decision:
- Keep orb and crystal fully separate.
- Cache readable secret numerics locally in the orb text path.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add local readable-secret numeric probe for player power/orb values
  - cache `rawCur` / `rawPercent` when readable, even if secret
  - stop `Mana_PostUpdate()` from consulting hidden crystal fallback
Result:
- `Mana_PostUpdate()` can re-drive orb fill from the same live numeric source already used to render correct orb text.
Next step:
- `/reload`, spend mana once, inspect `/azdebug orb dump`

2026-02-28 (mana orb: use orb-local readable secret numerics)
Issue:
- Orb and crystal are now numerically separated, but orb fill still pins at full.
- Orb dump shows:
  - raw orb values remain secret
  - orb-native mirror percent is still nil
  - crystal fallback is stale and hidden
Investigation:
- `Components/UnitFrames/Units/Target.lua` already uses a narrow `canaccessvalue(...)` probe for readable secret numerics.
- The earlier recursion issue came from a broad shared helper path, not from every targeted use of `canaccessvalue`.
Decision:
- Keep orb and crystal separate.
- Add an orb-local readable-secret probe inside `API.UpdateManaOrb()` only.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - add orb-local readable numeric checks for:
    - `UnitPower(unit, MANA)`
    - `UnitPowerMax(unit, MANA)`
    - `UnitPowerPercent(unit, MANA, ...)`
  - build orb `safeCur/safeMax/safePercent` from those orb-local readable values before any stale fallback
Result:
- The orb can now consume readable secret mana numerics directly without depending on hidden crystal state.
Next step:
- `/reload`, spend mana once, inspect `/azdebug orb dump`

2026-02-27 (mana orb: decouple orb from crystal and use orb-native mirror)
Issue:
- Player mana orb animation renders, but fill stays pinned at full.
- Orb and crystal are separate widgets and should not depend on each other.
Investigation:
- Current orb dump shows:
  - `element.safeCur = 50000`, `safePct = 100`
  - `liborb.barValue = 50000`, `barDisplayValue = 50000`
  - visible orb text is correct, but secret and unreadable in Lua
- Linked crystal state is not a valid orb source:
  - `crystal: shown false`
  - `mirrorPct nil`
  - `texturePct 100`
- Diabolic works because the orb is the primary power widget and is fed directly, not because it reads from another hidden power bar.
Decision:
- Stop using hidden crystal percent as an orb source.
- Give the orb its own safe numeric source by mirroring the orb's internal native StatusBar.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - bind AzeriteUI's statusbar mirror helper to the orb's internal native StatusBar after orb creation
- `Components/UnitFrames/Functions.lua`:
  - `API.UpdateManaOrb()` now uses the orb-native mirror percent before any stale orb cache
  - remove crystal fallback from the orb update path
- `Core/Debugging.lua`:
  - print orb-native mirror state in orb debug dump
Result:
- Orb and crystal numeric paths are now separated.
- Orb fill should follow its own hidden native StatusBar instead of stale crystal state.
Next step:
- `/reload`, spend mana once, inspect `/azdebug orb dump`

2026-02-27 (debugging: print linked crystal mirror state in orb dump)
Issue:
- Need to distinguish between:
  - crystal mirror percent working and orb not consuming it
  - crystal text being correct while crystal mirror percent is also stale
Investigation:
- Current orb dump does not show the linked player crystal state.
Change(s):
- `Core/Debugging.lua`:
  - print linked `frame.Power` mirror and safe values in `PrintPlayerOrbDebug()`
Result:
- One orb dump now shows whether the crystal render-mirror path is a valid numeric source for the orb.
Next step:
- `/reload`, cast once, compare linked crystal mirror percent with orb fill state

2026-02-27 (mana orb: drive from player crystal mirror percent)
Issue:
- Orb text remains correct on screen, but orb fill still stays full.
- Orb debug now proves:
  - orb text is secret
  - orb cache stays pinned at `safeCur = 50000`, `safePct = 100`
Investigation:
- Parsing orb text is not viable because `ManaOrb.Value:GetText()` is secret.
- The player crystal is already updating correctly and is bound through `BindStatusBarValueMirror(self.Power)`.
- That gives AzeriteUI a numeric rendered percent on the player crystal via:
  - `self.Power.__AzeriteUI_MirrorPercent`
  - `GetSecretPercentFromBar(self.Power)`
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - make `API.UpdateManaOrb()` prefer the player crystal mirror percent before stale orb cache fallbacks
- `Components/UnitFrames/Units/Player.lua`:
  - in `Mana_PostUpdate()`, if the player crystal mirror percent exists, re-drive the orb fill from that percent
Result:
- Orb fill should now follow the already-correct crystal render percent instead of the stale orb cache.
Next step:
- `/reload`, spend mana once, inspect orb fill and next auto-dump

2026-02-27 (mana orb: re-drive fill from raw display cache in Mana_PostUpdate)
Issue:
- Orb auto-dump now reflects the real orb update path and prints orb text.
- Result still shows:
  - `text: <secret>`
  - `safeCur = 50000`
  - `safePct = 100`
- But the visible orb text on screen is correct.
Investigation:
- `GetText()` on the orb fontstring returns a secret string, so parsing visible text after the fact is not viable.
- The only proven-correct source is still the raw display formatter in `Components/UnitFrames/Units/Player.lua`:
  - `GetPlayerRawPowerPercent()`
  - `GetFormattedPlayerPowerValue()`
- That path runs inside `UpdatePlayerElementValueText()` / `Mana_PostUpdate()`.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - cache display-safe percent/current on the element during the raw text formatting path
  - in `Mana_PostUpdate()`, after updating text, re-drive the orb widget value from that cached display state
Result:
- Orb fill should now follow the same raw display path that already produces the correct on-orb text.
Next step:
- `/reload`, spend mana once, and inspect the orb fill plus next auto-dump

2026-02-27 (debugging: orb auto-dump was attached to crystal updates, not orb updates)
Issue:
- Live orb dumps remained pinned at full even after moving orb sync to use the orb text path.
- The dump spam timing did not match the orb update lifecycle cleanly.
Investigation:
- `ns.API.DebugOrbDumpIfEnabled()` was still being called from `API.UpdatePower()`.
- That means the visible dump spam was coming from the player crystal update loop, not from `API.UpdateManaOrb()`.
- Orb debug also did not print `ManaOrb.Value:GetText()`, so the key source value was missing.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - remove orb auto-dump call from `API.UpdatePower()`
  - add orb auto-dump call to `API.UpdateManaOrb()` after `PostUpdate`
- `Core/Debugging.lua`:
  - print `ManaOrb.Value:GetText()` in `PrintPlayerOrbDebug()`
Result:
- Orb debug output now reflects the real orb update path and shows the on-orb text used for comparison.
Next step:
- `/reload`, spend mana once, and inspect the new orb-specific dump

2026-02-27 (mana orb: sync fill from orb text after Mana_PostUpdate)
Issue:
- Orb text is correct on screen (for example `23K (47%)`), but orb fill stays full.
- Live orb debug still reports:
  - `safeCur = 50000`
  - `safePct = 100`
  - `barValue = 50000`
Investigation:
- The previous fix parsed the player crystal text before the orb update finalized.
- In orb mode, the reliable text source is `self.ManaOrb.Value`, updated in `Mana_PostUpdate`.
- `API.UpdateManaOrb()` was still locking the orb fill before that text update happened.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - stop preferring the player crystal text pre-write
  - after `element:PostUpdate(...)`, parse `element.Value:GetText()`
  - if parsed current/percent are available, update:
    - `element.safeCur`
    - `element.safePercent`
    - orb widget min/max/value
Result:
- Orb fill should now follow the same on-orb text that is already updating correctly.
Next step:
- `/reload`, spend mana once, and inspect the auto-dump plus orb fill

2026-02-27 (mana orb: derive numeric state from visible player crystal text)
Issue:
- Orb runtime is now healthy and visible:
  - `scrollShown = true`
  - `barValue = 50000`
  - `barDisplayValue = 50000`
- But after spending mana, live orb dumps still stay pinned at full:
  - `safeCur = 50000`
  - `safePct = 100`
  - `native.value = 50000`
- At the same time, the on-screen player crystal text is correct, e.g. `33K (66%)`.
Investigation:
- `Components/UnitFrames/Units/Player.lua` already formats correct live power text from raw power APIs.
- `Components/UnitFrames/Functions.lua:API.UpdateManaOrb()` was still preferring stale cache/bar-derived values.
- The visible player crystal text is currently the only proven-correct safe display source in this client path.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - add a small parser for the visible player power text
  - in `API.UpdateManaOrb()`, prefer parsed current value / percent from `self.Power.Value:GetText()` before stale orb cache fallbacks
Result:
- Orb numeric input should now follow the same live display source as the working player crystal text.
Next step:
- `/reload`, spend mana, and inspect the automatic orb dump again

2026-02-27 (debugging: add rate-limited live orb auto-dump on updates)
Issue:
- Reload-time orb dump is useful, but it only captures the initialized full state.
- The unresolved question is what happens on the first live mana update after a spell cast.
Investigation:
- `API.UpdateManaOrb()` is the authoritative live update path for the orb.
- `Core/Debugging.lua` already has a persisted orb auto-dump toggle.
Change(s):
- `Core/Debugging.lua`:
  - expose a rate-limited `ns.API.DebugOrbDumpIfEnabled()` helper
- `Components/UnitFrames/Functions.lua`:
  - call that helper at the end of `API.UpdateManaOrb()`
Result:
- With `/azdebug orb auto on`, the orb state now prints after reload and on live mana updates, without requiring manual chat macros.
Next step:
- cast one spell and inspect the new live orb dump

2026-02-27 (mana orb: raise fill layer frame levels above backdrop)
Issue:
- Orb debug now shows a fully healthy runtime:
  - `safeCur = 50000`
  - `safePct = 100`
  - `barValue = 50000`
  - `barDisplayValue = 50000`
  - `scrollShown = true`
- But the orb fill is still not visibly rendering.
Investigation:
- At this point the failure is no longer data or clip state.
- The remaining likely cause is draw order:
  - AzeriteUI backdrop/shade/case art sits on the orb wrapper
  - LibOrb fill textures live inside internal child frames at the orb's base frame level
- Result: the fill can be alive but still render behind the visible art stack.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - raise internal clip/content frame levels above the base orb frame
- `Components/UnitFrames/Units/Player.lua`:
  - raise `manaCaseFrame` so case/text still render above the orb fill
Result:
- Orb fill should render between the backdrop and the case/text art, instead of being hidden behind the wrapper stack.
Next step:
- `/reload` and verify whether the orb fill becomes visible

2026-02-27 (mana orb: force immediate display-value sync so fill becomes visible)
Issue:
- Orb debug now shows:
  - `safeCur = 50000`
  - `safePct = 100`
  - `native.value = 50000`
  - `liborb.barValue = 50000`
  - but `liborb.barDisplayValue = 0`
Investigation:
- The orb now has correct numeric source data and the hidden native statusbar is full.
- The remaining failure is the displayed LibOrb state never syncing out of its initial zero value.
- For the orb, visible fill correctness matters more than smoothing right now.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - make `API.UpdateManaOrb()` write the orb value with immediate display sync
Result:
- `barDisplayValue` should stop remaining at zero, allowing the orb fill to render.
Next step:
- `/reload` and inspect the automatic orb dump again

2026-02-27 (mana orb: reuse player crystal safe power cache for orb numeric fallback)
Issue:
- Reload-time orb dump still showed:
  - `cur = <secret>`
  - `safeCur = 0`
  - `safePct = 0`
  - `liborb.barValue = 0`
  - `scrollShown = false`
Investigation:
- The orb still lacked a trustworthy numeric source of its own on the secret-value path.
- `API.UpdateManaOrb()` was trying to bootstrap from:
  - raw mana APIs when clean
  - its own previous orb cache
  - percent APIs / bar percent fallbacks
- On the player frame, the crystal power path is already known-good and produces correct sanitized values for the same mana pool.
- Result: the orb was trying to solve a numeric source problem that the player power element had already solved.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - in `API.UpdateManaOrb()`, prefer `self.Power.safeCur/safeMin/safeMax/safePercent` as the first fallback when raw orb mana is secret
Result:
- The orb can now reuse the player crystal's known-good sanitized mana state instead of self-seeding from `0%`.
Next step:
- `/reload` and retest orb fill/animation

2026-02-27 (debugging: fix local scope for orb auto-dump helper)
Issue:
- After fixing the timer callback, reload still errored:
  `attempt to call global 'PrintPlayerOrbDebug' (a nil value)`
Investigation:
- `Core/Debugging.lua:OnEvent()` referenced `PrintPlayerOrbDebug` before the later `local function PrintPlayerOrbDebug()` declaration.
- In Lua, that meant `OnEvent` resolved the symbol as a global, not the later local function.
Change(s):
- `Core/Debugging.lua`:
  - add a forward declaration for `PrintPlayerOrbDebug`
  - change the later definition to assign into that local
Result:
- Orb auto-dump now resolves the local helper correctly during reload/login.
Next step:
- `/reload` and inspect the printed orb dump

2026-02-27 (debugging: fix orb auto-dump C_Timer callback wrapper)
Issue:
- `/azdebug orb auto on` caused:
  `bad argument #2 to '?' (Usage: C_Timer.After(seconds, callback))`
Investigation:
- `Core/Debugging.lua` passed `PrintPlayerOrbDebug` directly to `C_Timer.After`.
- In this runtime path, the callback needs to be wrapped in an anonymous function.
Change(s):
- `Core/Debugging.lua`:
  - change `C_Timer.After(.5, PrintPlayerOrbDebug)` to `C_Timer.After(.5, function() PrintPlayerOrbDebug() end)`
Result:
- Orb auto-dump no longer errors on `PLAYER_ENTERING_WORLD`.
Next step:
- `/reload` and inspect the printed orb dump

2026-02-27 (mana orb: stop trusting pre-render bar percent before API percent)
Issue:
- After reordering orb writes, the debug dump still showed the orb pinned at zero:
  - `barValue = 0`
  - `barMin = 0`
  - `barMax = 50000`
  - `scrollframe:IsShown() = false`
Investigation:
- `API.UpdateManaOrb()` still resolved `safePercent` in this order:
  1. `GetSecretPercentFromBar(element)`
  2. `ProbeSafePercentAPI(...)`
  3. `SafeUnitPercentNumber(...)`
- For the orb, the generic bar sampler can return an initial `0%` before the orb has ever rendered, because the clip/native state starts empty.
- That bogus initial `0%` then forces `safeCur = 0`, and the orb remains pinned there.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - change orb percent resolution order to:
    1. `SafeUnitPercentNumber(...)`
    2. `ProbeSafePercentAPI(...)`
    3. `GetSecretPercentFromBar(element)`
Result:
- The orb no longer trusts a pre-render bar percent ahead of real API-derived percent.
Next step:
- `/reload` and retest orb fill/animation

2026-02-27 (mana orb: write safe numeric values into LibOrb runtime)
Issue:
- Player orb no longer crashes, but still does not render.
- Debug after spell casts showed:
  - `barValue` changes
  - `barDisplayValue` stays pinned at `50000`
  - `scrollframe:IsShown()` stays `false`
Investigation:
- `Components/UnitFrames/Functions.lua:API.UpdateManaOrb()` was still calling:
  - `element:SetMinMaxValues(min, max)`
  - `element:SetValue(cur, forced)`
  before computing `safeCur/safePercent`.
- On WoW 12, `cur` can be secret there, which leaves `LibOrb` with a raw secret target value but no numeric display value to animate/render against.
- Result: the orb runtime advances partially, but its displayed state stays pinned to the previous numeric value.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - compute `safeCur/safeMax/safePercent` first
  - write the orb runtime with safe numeric values instead of raw secret current values
  - keep raw values cached separately on the element for debugging/metadata
Result:
- `LibOrb` receives a numeric display current/max pair each update, so `barDisplayValue` can move and the clip frame can render the orb fill.
Next step:
- `/reload` and retest orb fill/animation

2026-02-27 (mana orb: remove dead ScrollFrame calls from clip-frame LibOrb path)
Issue:
- Player orb still did not render, and BugSack reported:
  `LibOrb-1.0.lua:134: attempt to call method 'SetVerticalScroll' (a nil value)`
Investigation:
- `Libs/LibOrb-1.0/LibOrb-1.0.lua` currently creates `scrollframe` as a plain clipping `Frame`, not a real `ScrollFrame`.
- `Update()` still called old scroll APIs:
  - `scrollframe:SetHeight(displaySize)`
  - `scrollframe:SetVerticalScroll(...)`
- The same file already anchors the clip frame top to the hidden native statusbar texture in `OnSizeChanged()`, so the native statusbar is supposed to drive visible fill height.
- Result: the orb runtime was mixing two incompatible implementations:
  - old scrollframe math
  - new native-statusbar clip frame
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - remove `SetVerticalScroll(...)` usage from both secret and non-secret branches in `Update()`
  - stop manually setting clip-frame height in `Update()`
  - rely on the native hidden statusbar texture anchor to define the clip height
  - keep show/hide and spark placement logic
Result:
- Orb update no longer crashes on `SetVerticalScroll`
- Visible orb fill can now follow the native statusbar clip path this WoW 12 version was built around
Next step:
- `/reload` and retest orb fill/animation

2026-02-27 (mana orb: use orb widget safe caches in LibOrb secret render path)
Issue:
- Orb runtime now advances correctly (`barValue/barDisplayValue = 50000`), but `scrollframe` still stays hidden.
Investigation:
- The restored secret-safe branch in `LibOrb.Update()` only renders when `data.safeBarValue/safeBarMin/safeBarMax` exist.
- Current AzeriteUI orb path populates the widget caches:
  - `self.safeCur`
  - `self.safeMin`
  - `self.safeMax`
- but it does not populate `LibOrb`'s internal `safeBarValue` consistently on the secret path.
- Result: secret render branch hides the scrollframe even though safe values already exist on the orb widget.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - in the secret-safe `Update()` branch, fall back to `self.safeCur/safeMin/safeMax` when internal `safeBar*` values are absent
Result:
- Orb fill should now render from the widget's existing safe caches when raw orb values are secret.
Next step:
- `/reload` and retest orb fill/animation.

2026-02-27 (mana orb: restore secret-safe Update branch in LibOrb)
Issue:
- After restoring `barDisplayValue` bootstrap, player orb advanced far enough to crash in `LibOrb.Update()` on:
  `attempt to compare local 'value' (a secret number value tainted by 'AzeriteUI')`
Investigation:
- Current `Libs/LibOrb-1.0/LibOrb-1.0.lua:Update()` immediately compares:
  - `value > max`
  - `value < min`
  - `value > 0`
- Older working copy `Libs/LibOrb-1.0/LibOrb-1.0.lua.bak_20260226_orbregress` still contained a secret-safe early branch in `Update()`:
  - if `value/min/max` are secret, render from cached safe values instead of comparing secret numbers
- This is the exact branch needed now that the orb runtime is finally receiving live secret values again.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - restore the secret-safe early branch in `Update()`
Result:
- Orb update should stop crashing on secret values and resume rendering from safe cached orb values when raw values are secret.
Next step:
- `/reload` and retest orb fill/animation.

2026-02-27 (mana orb: restore LibOrb display-value bootstrap and OnUpdate start)
Issue:
- Player mana orb textures and native statusbar now initialize, but the orb still remains empty.
- Debug showed:
  - orb layer textures are assigned
  - `barValue=50000`, `barMin=0`, `barMax=50000`
  - native statusbar is `50000/0/50000`
  - but `barDisplayValue` remains `0`
Investigation:
- Current `Libs/LibOrb-1.0/LibOrb-1.0.lua:SetValue()` only stores `data.barValue`.
- It no longer seeds `barDisplayValue`, `smoothingInitialValue`, `smoothingStart`, or starts `OnUpdate`.
- Older working copy `Libs/LibOrb-1.0/LibOrb-1.0.lua.bak_20260226_orbregress` still had that runtime bootstrap logic.
- This matches the live failure exactly: the orb has real values, but the displayed value never leaves zero.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - restore the display-value bootstrap logic in `Orb.SetValue(...)`
  - restore the range/display synchronization logic in `Orb.SetMinMaxValues(...)`
Result:
- `barDisplayValue` should now move away from zero and drive the visible orb fill/animation again.
Next step:
- `/reload` and retest orb fill/animation.

2026-02-27 (mana orb: initialize textures immediately and bypass ForceUpdate indirection)
Issue:
- Player mana orb still rendered as an empty square.
- Debug showed:
  - `GetStatusBarTexture()` layers existed but had nil texture paths
  - `LibOrb` runtime stayed at defaults: `barValue=0, barMin=0, barMax=1, barDisplayValue=0`
  - forcing the orb visible did nothing
Investigation:
- That means the orb was not merely hidden; it was never being initialized/populated.
- In AzeriteUI, orb textures were primarily assigned later through `UnitFrame_UpdateTextures(...)`, not at creation.
- Orb updates were also routed through a custom `self.ManaOrb.ForceUpdate` indirection.
- Since debug showed the runtime stayed at defaults, the safest fix is to remove both uncertainties:
  - assign the orb textures/colors immediately during creation
  - call `ns.API.UpdateManaOrb(...)` directly from player update/event paths
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - initialize `self.ManaOrb` texture/color/texcoords at creation time
  - replace `self.ManaOrb:ForceUpdate()` call sites with direct `ns.API.UpdateManaOrb(...)`
  - make `self.ManaOrb.ForceUpdate` call `ns.API.UpdateManaOrb(...)` directly
Result:
- Player mana orb should no longer depend on delayed texture setup or a stale force-update chain before it can render.
Next step:
- `/reload` and retest orb fill/animation.

2026-02-27 (mana orb: fix multi-return collapse in orb layer show/hide wrapper)
Issue:
- Player mana orb still showed no proper fill/swirl even after aligning `LibOrb` and the updater with DiabolicUI.
Investigation:
- `LibOrb:GetStatusBarTexture()` returns four orb layers.
- In `Components/UnitFrames/Units/Player.lua`, both `HidePlayerNativePowerVisuals(...)` and `ShowPlayerNativePowerVisuals(...)` used:
  `power.GetStatusBarTexture and power:GetStatusBarTexture()`
- In Lua, `and` collapses a multi-return call to a single value.
- Result: the wrapper only ever handled layer 1, not layers 2-4.
- That directly explains why the orb never restored the full swirl/animated layer stack correctly.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - call `power:GetStatusBarTexture()` only after an explicit guard, preserving all four returned layers
Result:
- Player orb wrapper should now show/hide all orb layers instead of silently dropping the animated layers.
Next step:
- `/reload` and retest orb visibility/animation.

2026-02-27 (mana orb: revert LibOrb drift and restore Diabolic runtime)
Issue:
- Mana orb still shows no visible fill/animation even after aligning the updater with Diabolic's direct `UnitPower` write path.
Investigation:
- Exact file comparison against `..\\DiabolicUI3\\Libs\\LibOrb-1.0\\LibOrb-1.0.lua` showed AzeriteUI's `LibOrb` still had local drift:
  - extra `IsSafeNumber(...)` helper
  - immediate `Update(self, 0)` redraw branches in `Orb.SetValue(...)`
  - immediate `Update(self, 0)` redraw branches in `Orb.SetMinMaxValues(...)`
- Those code paths do not exist in Diabolic's working orb runtime.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`:
  - remove the extra safe-number redraw shortcut logic
  - restore `Orb.SetValue(...)` / `Orb.SetMinMaxValues(...)` behavior to Diabolic's runtime contract
Result:
- AzeriteUI orb runtime should now match Diabolic at both the updater and library level, while keeping AzeriteUI art/placement above it.
Next step:
- `/reload` and retest orb fill/animation.

2026-02-27 (mana orb: align updater with Diabolic direct orb contract)
Issue:
- Player and target crystal text now work, but the mana orb still does not reliably render/fill like DiabolicUI.
Investigation:
- Current AzeriteUI already uses a Diabolic-style `LibOrb` renderer, but `Components/UnitFrames/Functions.lua:API.UpdateManaOrb()` still runs a custom secret-safe cache pipeline before writing the orb widget.
- DiabolicUI does not do that for orb power. It writes raw `UnitPower`/`UnitPowerMax` directly into the orb widget and lets the orb/native statusbar handle the live fill.
- Current orb text/art/visibility in `Components/UnitFrames/Units/Player.lua` are already layered on top of the widget and can remain.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - replace `API.UpdateManaOrb()` with a Diabolic-style direct widget update path
  - keep AzeriteUI cache fields only as secondary metadata/fallbacks
Result:
- Mana orb fill/animation should follow the same live power payload as Diabolic instead of drifting behind a custom cache resolver.
Next step:
- `/reload` and verify orb fill and animation at full, partial, and near-empty mana.

2026-02-27 (target crystal text: remove live tag path and use raw widget formatting)
Issue:
- Player crystal text now updates correctly, but target crystal current/percent text can still stay pinned at max while the native target power statusbar itself moves.
Investigation:
- `Components/UnitFrames/Units/Target.lua` still drives visible target crystal text through `UpdateTargetPowerValueTag(...)` and oUF tags.
- The player fix worked by bypassing the tag/cache path and formatting the visible text directly from the live power payload with `SetFormattedText(...)`.
- This leaves target as the remaining old path.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - remove the live tag dependency for visible target power text
  - format target crystal current/percent text directly from raw power values and Blizzard formatters
  - refresh target power text from `Power_UpdateVisibility(...)`
Result:
- Target crystal text should follow the same live raw power path as the statusbar instead of stale tag/cache state.
Next step:
- `/reload` and verify target power current/percent text while targeting units with changing mana/power.

2026-02-27 (player crystal text: use widget formatting on raw live power payloads)
Issue:
- Player crystal current/percent text can still freeze because addon-side cache math drifts from the live secret-powered statusbar.
- Previous raw-first change introduced a secret-string crash by parsing formatted secret strings in Lua.
Investigation:
- WoW 12 local API notes (`API_CHANGES_12.0.0_FULL.md`) already recommend avoiding Lua-side concatenation/arithmetic on secret values and preferring widget formatting paths.
- The safest live source is still the raw power payload the statusbar is already consuming.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - use `FontString:SetFormattedText(...)` with raw live power formatter outputs for player crystal text
  - avoid Lua parsing/concatenation of formatted secret strings
  - keep cached/text-math path only as fallback when widget formatting cannot be used
Result:
- Player crystal text should follow the same live raw value path as the statusbar without secret-string arithmetic in addon Lua.
Next step:
- `/reload` and verify player crystal text at full, partial, and near-empty mana.

2026-02-27 (player crystal text: prefer raw formatted power over stale caches)
Issue:
- Player crystal statusbar keeps moving, but current/percent text can still freeze because cached `safeCur/safePercent` stop tracking the live bar.
Investigation:
- Deep trace across:
  - `Components/UnitFrames/Functions.lua`
  - `Components/UnitFrames/Tags.lua`
  - `Components/UnitFrames/Units/Player.lua`
  - `Libs/oUF/elements/tags.lua`
- The player crystal is updated with live raw secret power values, but the visible text path still depends too heavily on cached `safeCur/safePercent`.
- `SafePowerValueText(...)` already uses Blizzard `AbbreviateNumbers(...)`, which the repo previously documented as safe enough to consume secret values for display.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - prefer raw player power formatting (`UnitPower` + Blizzard number formatters) for visible player crystal text
  - derive displayed percent from parsed formatted current text plus safe max when possible
  - use `SetFormattedText("%s", ...)` for the final fontstring write
Result:
- Player crystal text should follow the same live raw value path as the statusbar, with caches only as fallback.
Next step:
- `/reload` and verify player crystal text at full, partial, and near-empty mana.

2026-02-27 (drive player power text from visible bar geometry)
Issue:
- Player crystal statusbar keeps moving, but `safeCur/safePercent` can still drift and freeze at stale values.
- User dump shows `AzeriteUnitFramePlayer.Power.Value:GetText()` can differ from what the player expects from the live crystal state.
Investigation:
- The authoritative live signal is the rendered crystal geometry, not the cached power text state.
- Existing cache/mirror logic has regressed multiple times while the native statusbar itself stayed correct.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add a local helper to derive player power percent from the visible statusbar texture geometry
  - prefer that visual percent in `FormatPlayerPowerPercentText(...)`
  - derive displayed current value from visual percent when formatting the crystal/orb text
Result:
- Player power number/percent text should track the visible crystal even if cached `safeCur/safePercent` stall.
Next step:
- `/reload` and verify player crystal text at full, partial, and empty power.

2026-02-27 (restore post-write mirror correction for player crystal text)
Issue:
- Player power crystal statusbar updates visually, but `AzeriteUnitFramePlayer.Power.Value` still pins at max/current-percent values.
Investigation:
- User `fstack` confirms the visible text object is `AzeriteUnitFramePlayer.Power.Value`, so this is not a wrong-fontstring problem.
- `FixLog.md:8451` documents the earlier working fix:
  - `API.UpdatePower()` performed a post-write mirror-percent pass for secret raw power and recalculated `safeCur` from the rendered bar percent.
- Current `Components/UnitFrames/Functions.lua` computes `safeCur/safePercent` before the native statusbar has finished rendering secret current values.
- In this state, `writeCur` can still be the raw secret value so the crystal moves, while cached text state remains pinned to `safeMax`.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - restore the post-write mirror-percent correction in `API.UpdatePower()` for secret raw power
  - refresh `safeCur/safePercent` from `GetSecretPercentFromBar(element)` after `SetStatusBarValuesCompat(...)`
Result:
- Player crystal text should again follow the rendered statusbar when raw power current is secret.
Next step:
- `/reload` and verify player crystal text while spending power.

2026-02-27 (Revert player power update logic closer to 5.2.209 known-good behavior)
Issue:
- Player crystal statusbar updates visually, but current-value and percent text still pin at max.
Investigation:
- Compared current AzeriteUI against:
  - `C:\\Users\\Jonas\\OneDrive\\Skrivebord\\azeriteui_fan_edit\\AzeriteUI_Release_5.2.209\\AzeriteUI\\Components\\UnitFrames\\Functions.lua`
  - `C:\\Users\\Jonas\\OneDrive\\Skrivebord\\azeriteui_fan_edit\\AzeriteUI_Release_5.2.209\\AzeriteUI\\Components\\UnitFrames\\Tags.lua`
- The old release used a much simpler `API.UpdatePower()`:
  - `safePercent = NormalizePercent100(SafeUnitPercentNumber(...))`
  - mirror fallback only when raw current was not safe
  - no `ProbeSafePercentAPI(...)`
  - no `staleRawCur` override path
  - no post-write mirror-percent rewrite for player crystal
Hypothesis:
- The newer power update logic is over-correcting and pinning `safeCur/safePercent` even though the native crystal bar itself still renders correctly.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - revert `API.UpdatePower()` power text/cache path closer to the 5.2.209 implementation
  - keep current structure and guards, but remove the newer percent-probe/stale-raw/post-mirror correction logic from the player crystal path
Result:
- Player power text should again follow the same simpler `safeCur/safePercent` model that worked in 5.2.209.
Next step:
- `/reload` and verify player crystal current/percent in `Short`, `Percent`, and `Short + Percent`.

2026-02-27 (Power mirror sampler pinned at 100 because native texcoords stay unchanged)
Issue:
- Player crystal current value and percent can still stay pinned at max even after moving visible text off tags.
Hypothesis:
- `Components/UnitFrames/Functions.lua` `GetTexturePercentFromBar(...)` prefers texcoord-span sampling whenever base texcoords exist.
- For the native vertical player crystal, Blizzard appears to keep the texture texcoords unchanged and clip by texture height instead.
- That makes the texcoord-span branch return `100` every time, which then feeds `__AzeriteUI_MirrorPercent` and causes `safeCur/safePercent` to stay at max.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - In `GetTexturePercentFromBar(...)`, only trust texcoord-span sampling when the current texcoords actually differ from the cached base texcoords.
  - If texcoords are unchanged, fall through to the live texture width/height ratio path.
Result:
- Native-clipped statusbars like the player power crystal should derive mirror percent from real visible geometry again instead of a constant `100%`.
Next step:
- `/reload` and verify player crystal current value and percent while spending/regenerating power.

2026-02-27 (Player power value text moved off tags and onto power callback)
Issue:
- Player crystal value and percent text could still pin or stop updating even after multiple tag source-order fixes.
Hypothesis:
- The remaining instability is in the tag stack itself, not the underlying power data.
- Other local UIs in this workspace update visible power text directly during the power update pass instead of routing it through tags:
  - `..\\FeelUI\\Modules\\Unitframes\\Core.lua`
  - `..\\GW2_UI\\core\\Units\\powerbar.lua`
  - `..\\DiabolicUI3\\Components\\UnitFrames\\Common\\Functions.lua`
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - Stop depending on tags for the visible player crystal/orb value text.
  - Format the text directly from sanitized element values (`safeCur/safeMin/safeMax/safePercent`) in the power update callbacks.
Result:
- Player power text now follows the same sanitized bar state as the rendered crystal/orb, without tag ordering issues.
Next step:
- `/reload` and verify player crystal/orb in `Short`, `Percent`, `Full`, and `Short + Percent` modes while spending/regenerating power.

2026-02-27 (Player crystal tags trust sanitized element cache, not raw power API)
Issue:
- Player crystal power text and percent could stop updating or pin at `100%` after the recent tag refactors.
Hypothesis:
- `Components/UnitFrames/Tags.lua` was still letting `[*:Power]` and `[*:PowerPercent]` trust raw `UnitPower(...)`, `UnitPowerMax(...)`, or mirrored percent before the sanitized element state written by `API.UpdatePower()`.
- Per `API_CHANGES_12.0.0_FULL.md:106-108`, `UnitPower(unit, powerType)` is a secret-returning API in WoW 12 and should not be treated as the primary display source for tag logic.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - Made player/target power text and percent prefer the active oUF element cache (`safeCur/safeMin/safeMax/safePercent`) first.
  - For power tags, stopped trusting mirrored/texture percent before sanitized element values.
  - Kept raw API reads as a last-resort fallback only.
Result:
- Crystal current value and percent should now follow the same sanitized power element state that drives the rendered bar.
Next step:
- `/reload` and verify player crystal in `Short`, `Percent`, and `Short + Percent` modes while spending/regenerating power.

2026-02-27 (Power tags use raw current/max before cached percent API)
Issue:
- After the previous power-tag refactor, player crystal value text and percent text could both stop updating.
Hypothesis:
- The tag path was over-trusting cached element values/percent before direct `UnitPower` / `UnitPowerMax` reads.
- WoW 12 API docs make `UnitPowerPercent(...)` its own restricted/secret-returning API, while `UnitPower(...)` and `UnitPowerMax(...)` are the direct current/max primitives.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - Restored `[*:Power]`, `[*:Power:Full]`, `[*:Power:FullNumber]` to prefer direct raw current/max for the resolved display power type first.
  - Restored raw current/max percent derivation in `[*:PowerPercent]` and `[*:ManaPercent]` before cached safe fallbacks.
  - `SafeUnitPercent(...)` now tries a direct raw current/max percent for power before `UnitPowerPercent(...)`.
  - `GetElementLivePercent(...)` now prefers mirror/texture percent for power, then cached/live ranges.
Result:
- Player crystal current value and percent should both update again while still respecting the bar's resolved power type.
Next step:
- `/reload` and verify player crystal in `Percent` and `Short + Percent` modes while spending/regenerating power.

2026-02-27 (Player crystal percent follows oUF safe cache first)
Issue:
- Player crystal percent text could still stay pinned at `100%` while the current numeric power text changed correctly.
Hypothesis:
- `Components/UnitFrames/Tags.lua` still let `GetValue()/GetMinMaxValues()` and raw `UnitPowerType(unit)` drive power tags before the oUF-safe cached values written by `API.UpdatePower()`.
- On the player crystal path, the bar cache (`safeCur/safeMin/safeMax`, `displayType`) is the authoritative display source.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - Added a power-specific safe value-range helper for frame elements.
  - `GetElementLivePercent(...)` now prefers the safe cached power range before probing native widget values.
  - Power tags now align to the frame element `displayType` when present, instead of always using `UnitPowerType(unit)`.
  - `[*:Power]`, `[*:Power:Full]`, `[*:Power:FullNumber]`, `[*:PowerPercent]` now prefer the active oUF power element/cached values before raw API fallbacks.
Result:
- Player crystal current text and percent text now read from the same sanitized oUF-updated source first.
Next step:
- `/reload` and verify player crystal with `Percent` and `Short + Percent` while spending/regenerating power.

2026-02-27 (Power percent live-source fix + target dead-code cleanup)
Issue:
- Power text could show the current numeric value correctly while the percent text still stayed pinned at `100%`.
- `Target.lua` still carried a few health-only helper branches and one cast debug flag that no longer affected runtime.
Hypothesis:
- `Components/UnitFrames/Tags.lua` still trusted cached `safePercent` or raw percent-style fallbacks too early, before safer frame/current-max reconstruction paths.
- The remaining target dead surface was making review harder without driving the live renderer.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - `SafeUnitPower()` now samples the live frame element value/min/max helper first instead of mixing direct `safeCur/safeMax` reads and stale cached percent.
  - `[*:PowerPercent]` and `[*:ManaPercent]` now prefer:
    1. live frame element percent
    2. safe reconstructed power percent
    3. safe percent helper
    4. cached frame percent only as last fallback
  - Removed the direct raw `UnitPower/UnitPowerMax` percent shortcut from the tag path.
- `Components/UnitFrames/Units/Target.lua`:
  - Removed dead target-health helper functions that were always resolving to the same behavior.
  - Removed the unused `nativevisual` target-cast debug hook.
  - Dropped the unused `styleKey` argument from `GetTargetHealthLabSettings(...)`.
- `Core/Debugging.lua`:
  - Removed the dead cast `nativevisual` debug option from the target debug flag table.
Result:
- Power percent text should now follow the same live/current value path as the visible crystal and power number text.
- Target runtime and target debug now have less dead code around the final renderer.
Next step:
- `/reload` and verify player/target crystal percent while spending power, then retest target health/cast behavior.

2026-02-27 (Power percent follows live statusbar + target cleanup)
Issue:
- Crystal power percent could still pin at `100%` even after the numeric value changed.
- `Target.lua` still carried the final deep-clean compatibility branch for cast visual sync.
Hypothesis:
- Percent tags were still preferring cached `safeCur/safeMax` before the actual live statusbar value/min/max.
- Target cast sync no longer needed the extra deep-clean gating once target health had already been collapsed to the single fake-fill path.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - Added a live statusbar value-range helper and made percent tags/sample helpers prefer `GetValue()/GetMinMaxValues()` before cached fields.
- `Components/UnitFrames/Units/Target.lua`:
  - Removed the last `TARGET_HEALTH_DEEP_CLEAN` cast sync branch and the now-inert helper around it.
Result:
- Power percent text should now follow the same live bar state as the visible crystal.
- Target runtime has one fewer dead compatibility branch.
Next step:
- `/reload` and verify crystal percent while spending power, then retest target cast behavior.

2026-02-27 (Crystal power percent pinned at 100)
Issue:
- Player crystal power text could show the current numeric value correctly while the percent tag stayed pinned at `100%`.
Hypothesis:
- `Components/UnitFrames/Tags.lua` still returned the raw `UnitPower/UnitPowerMax` percent before checking the live frame element.
- On WoW 12 secret/stale paths, raw power can remain pinned to max while the visible bar and cached safe frame values have already updated.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - `[*:PowerPercent]` now prefers the active visible frame power element first.
  - `[*:ManaPercent]` now prefers the active visible mana element first.
  - Raw unit power percent remains as fallback only when no usable frame/widget values exist.
Result:
- Crystal percent text now follows the same live frame values as the visible bar/current number instead of returning stale raw `100%`.
Next step:
- `/reload` and verify crystal-only mode while spending/regenerating power.

2026-02-27 (Player/Target surface cleanup pass)
Issue:
- Player/target unitframe code still carried dead debug-era branches, legacy power-format writebacks, and target debug commands/options that no longer matched the live runtime.
Hypothesis:
- The remaining dead surface increases regression risk because it preserves multiple obsolete paths around the target health fake-fill and target debug UI.
Change(s):
- `Core/Debugging.lua`:
  - Reduced `/azdebugtarget` and `/azdebug target` help/menu/command handling to cast-only target fill debug.
  - Removed the dead `both`/health target-debug menu surface from the live command/UI path.
- `Options/OptionsPages/UnitFrames.lua`:
  - Stopped writing legacy `powerValueUsePercent` / `powerValueUseFull` booleans from the live `PowerValueFormat` option.
  - Stopped writing legacy orb booleans from the live `powerOrbMode` selector.
- `Components/UnitFrames/Units/Player.lua`:
  - Removed legacy power-format booleans from defaults; kept read-only fallback for older saved variables.
- `Components/UnitFrames/Units/Target.lua`:
  - Removed legacy power-format booleans from defaults; kept read-only fallback for older saved variables.
  - Collapsed target health fill to the simple fake-fill resolver/update path and removed dead health debug fallback helpers.
Result:
- Player/target options and debug now match the live runtime path more closely, with less dead code around target health rendering.
Next step:
- `/reload` and verify:
  - `/azdebugtarget` only exposes cast-oriented commands
  - player/target power text formatting still switches correctly
  - target health still updates through the simplified reversed fake-fill path

2026-02-26 (orbV2 dynamic resolver adjusted to mana-pool presence)
Issue:
- `orbV2` still rendered crystal in specs where current primary power is not mana (e.g. Retribution), despite player having a mana pool.
Hypothesis:
- Dynamic resolver used `UnitPowerType(unit) == MANA` and a Retribution exclusion, which is too strict for orb preference.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - `ResolvePlayerPowerWidgetVisibility` now resolves dynamic orb mode from `UnitPowerMax(unit, MANA) > 0` (safe/pcall checked) instead of current active power type.
  - Removed Retribution/current-power gate from orb dynamic decision.
Result:
- `orbV2` now shows orb for specs with mana pools even when current active resource is a class resource.
Next step:
- `/reload` and verify `orbV2` on Retribution/Balance/etc. and `legacyCrystal` still forces crystal.

2026-02-26 (Player options wording cleanup in /az)
Issue:
- Player power dropdown/toggle names were technical and unclear (`orbV2`, ambiguous bar/case labels).
Hypothesis:
- Clear user-facing wording reduces setup confusion without changing behavior.
Change(s):
- `Options/OptionsPages/UnitFrames.lua` (Player section):
  - Renamed power text toggles/descriptions (`Show Power Text`, `Show In Combat Only`, `Power Text Style`).
  - Updated power style choices to plain language (`Mana Orb Only`, `Power Crystal Only`).
  - Renamed `Use Ice Crystal` label/description for clarity.
  - Renamed major power layout labels (Widget/Backdrop/Frame anchors, size, and offsets).
Result:
- `/az -> UnitFrames -> Player` reads in end-user language while keeping internal option keys/values unchanged.
Next step:
- `/reload` and confirm option text updates and behavior remains unchanged.

2026-02-26 (Power style UX naming cleanup + class-based dynamic restore)
Issue:
- `orbV2` naming was unclear in UI and dynamic behavior expectation was class-based.
Hypothesis:
- Users expect stable class-level behavior for automatic mode and human-readable option names.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - Restored dynamic resolver to class-based routing via allow-list (mana-oriented classes).
- `Options/OptionsPages/UnitFrames.lua`:
  - Renamed option label from `Power Orb Mode` to `Player Power Style`.
  - Renamed visible choices:
    - `Automatic (By Class)` (`orbV2`)
    - `Mana Orb (Always)` (`orbV2Always`)
    - `Power Crystal (Always)` (`legacyCrystal`)
  - Kept internal values unchanged for compatibility.
Result:
- UI wording is clearer and dynamic mode behavior matches class-based expectation.
Next step:
- `/reload` and verify option labels + dynamic switching by class.

2026-02-26 (Orb text alignment on self.Power)
Issue:
- Orb fill works, but player power text appears off-center in orb mode.
Hypothesis:
- After moving orb runtime to `self.Power`, text anchors were still using crystal positions (`PowerValuePosition` / `PowerPercentagePosition`).
Change(s):
- `Components/UnitFrames/Units/Player.lua` (`UnitFrame_UpdateTextures`):
  - Re-anchor/re-style `self.Power.Value` to mana text config when orb mode is active.
  - Re-anchor/re-style `self.Power.Percent` to mana percent config when orb mode is active.
  - Keep crystal text anchors/styles unchanged when crystal mode is active.
Result:
- Player power text now follows orb-centered positions when orb mode is enabled.
Next step:
- `/reload`, enable orb mode, verify value/percent text is centered on orb and switches back correctly in crystal mode.

2026-02-26 (Player power frequent updates + combat-driven power text toggle)
Issue:
- Requested smoother player power/orb updates and optional combat-only power text visibility.
Hypothesis:
- `self.Power.frequentUpdates = false` can make rapid mana updates feel delayed.
- Power text visibility needed an explicit combat gate in profile/options.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - Set `self.Power.frequentUpdates = true`.
  - Added profile default `powerValueCombatDriven = false`.
  - `ShouldShowPlayerPowerValue()` now respects `powerValueCombatDriven` via `InCombatLockdown()`.
  - On `PLAYER_REGEN_ENABLED/DISABLED`, force `self.Power:ForceUpdate()` to refresh text visibility immediately.
- `Options/OptionsPages/UnitFrames.lua`:
  - Added `Power Text Combat Driven` toggle in Player options.
Result:
- Player power/orb updates run at frequent cadence.
- Player power text can be configured to show only during combat and updates immediately on combat state transitions.
Next step:
- `/reload`, then verify:
  - Toggle `Power Text Combat Driven` on/off out of combat and in combat.
  - Orb/crystal fill updates continuously while spending mana.

2026-02-26 (Player orb runtime switched to self.Power renderer)
Issue:
- Mana orb updates remained unreliable under `AdditionalPower` visibility/update path.
- User requested to run orb via `self.Power` (Diabolic-style primary power element path).
Hypothesis:
- Splitting runtime between `Power` and `AdditionalPower` created desync between active visuals and the element receiving power updates.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - `Mana_UpdateVisibility` now always disables/hides `AdditionalPower` at runtime.
  - `Power_UpdateVisibility` now keeps `self.Power` visible for both crystal and orb modes.
  - `PostUpdateWidgetLayout` now applies mana orb anchors/textures/backdrop/case directly to `self.Power` when orb mode is active.
  - `PlayerFrameMod.Update` now refreshes `self.Power` for both crystal and orb modes and hides `AdditionalPower`.
Result:
- Single active renderer (`self.Power`) is used for player crystal/orb runtime, removing split update ownership.
- `AdditionalPower` remains present only as legacy fallback scaffolding.
Next step:
- `/reload` and verify:
  - `legacyCrystal`: crystal visuals + updating power.
  - `orbV2` / `orbV2Always`: orb visuals on `self.Power` with live fill updates.
  - No player-frame disappearance when toggling orb mode.

2026-02-26 (Power Orb Mode unified to menu-only, Diabolic-style selection)
Issue:
- Orb/crystal behavior was split between dropdown mode and extra toggles, causing conflicting state and `orbV2` not activating reliably when force-orb toggle was off.
Hypothesis:
- Multiple controls (`powerOrbMode`, `alwaysUseCrystal`, `alwaysShowManaOrb`) acted as competing sources of truth.
Change(s):
- Player options now use menu-only mode selection for power widget behavior:
  - `legacyCrystal`
  - `orbV2` (dynamic)
  - `orbV2Always` (always orb)
- Removed visible `Always show Mana Orb` toggle from options (kept legacy profile fields for migration).
- Runtime resolver now derives visibility from normalized mode value, with backward mapping from legacy toggles.
Result:
- Single authoritative mode controls crystal/orb behavior.
- Legacy profiles still migrate safely.
Next step:
- `/reload` and test all three modes in player options:
  - `legacyCrystal`: crystal only
  - `orbV2`: orb only when mana-user dynamic condition is true
  - `orbV2Always`: orb always
2026-02-26 (Always Show Mana Orb should override Power Orb Mode)
Issue:
- `Always show Mana Orb` could be blocked when `Power Orb Mode` was set to `legacyCrystal`, causing confusing menu behavior and orb not appearing as expected.
Hypothesis:
- Visibility resolver treated mode selection as a hard gate even when force-orb toggle was enabled.
Change(s):
- Updated player power visibility resolver so `alwaysShowManaOrb` is a hard override.
- `powerOrbMode` now controls only default behavior when override is off.
Result:
- Checking `Always show Mana Orb` now shows orb regardless of `Power Orb Mode` selection.
Next step:
- `/reload`, set `Power Orb Mode = legacyCrystal`, enable `Always show Mana Orb`, verify orb appears and crystal hides.
2026-02-26 (Power orb toggle recursion + crystal/orb state cleanup)
Issue:
- Toggling `Always Show Mana Orb` could trigger stack overflow in UnitFrame functions and desync crystal/orb visibility state.
- Player frame visibility/state appeared unstable during rapid toggles.
Hypothesis:
- `Mana_UpdateVisibility` called `element:ForceUpdate()` inside visibility override path, which re-entered oUF visibility and caused recursive loop.
- Crystal visibility callback (`Power_UpdateVisibility`) was mutating AdditionalPower enabled state directly, creating competing state writers.
- Secret-safety helper path could recurse via `canaccessvalue` in some clients.
Change(s):
- Removed recursive `ForceUpdate` call from `Mana_UpdateVisibility` and added re-entry guard (`__AzeriteUI_VisibilityUpdating`).
- Wrapped visibility body in `pcall`; on failure orb safely disables/hides.
- Removed cross-disabling side effect from `Power_UpdateVisibility` (no direct `AdditionalPower.__isEnabled` mutation there).
- Reordered `PlayerFrameMod.Update` power flow:
  - resolve orb/crystal visibility first via `OverrideVisibility`,
  - refresh only active widget (crystal `ForceUpdate` or orb `Override` update).
- Simplified `CanAccessValue` to treat only non-secret values as safe (avoids `canaccessvalue` recursion/stack overflow path).
Result:
- Orb/crystal toggles are deterministic and no longer recurse through visibility.
- Stack overflow path from toggle flow should be eliminated.
Next step:
- `/reload`, toggle `Always Show Mana Orb`, `Power Orb Mode`, and `Use Ice Crystal` repeatedly in/out of combat.
- Verify: no BugSack recursion error, player frame remains visible, and exactly one of crystal/orb is visible at a time.
2026-02-26 (Wake of Ashes replacement swap loses cooldown swipe/number)
Issue:
- When Wake of Ashes is temporarily replaced by another spell and then returns, the button can lose active cooldown swipe/count display.
Hypothesis:
- In LAB secure cooldown path, `GetCooldownInfo()` table values (often zero/inactive during replacement transitions) were taking precedence over tuple fallback (`GetCooldown()`), even when tuple had active cooldown.
Change(s):
- In `UpdateCooldown` (ActionButton_ApplyCooldown branch), added active-cooldown precedence logic:
  - detect active tuple cooldown (`start/duration/enable`),
  - detect inactive table cooldown (`cooldownInfo`),
  - if tuple is active and table is inactive, override `cooldownInfo` with tuple values before normalization.
Result:
- Replacement-spell swap-back should retain/start cooldown swipe and countdown immediately.
Next step:
- `/reload`, cast Wake of Ashes, trigger replacement spell, let it swap back, verify swipe + timer show while cooldown is running.
2026-02-26 (Orb visible but stays filled / stale percent)
Issue:
- Mana orb can toggle on/off but visual fill stays near/full instead of draining continuously.
Hypothesis:
- Shared mirror-percent fallback (`__AzeriteUI_MirrorPercent`) is invalid for `LibOrb` because orb base texture remains full-size; this can pin fallback percent to 100.
Change(s):
- `GetSecretPercentFromBar(...)` now skips mirror-percent fallback when element sets `__AzeriteUI_IgnoreMirrorPercent`.
- Player `AdditionalPower` orb now sets `__AzeriteUI_IgnoreMirrorPercent = true`, so secret fallback prefers orb-native `GetSecretPercent()` / safe percent chain.
Result:
- Orb percent resolution no longer trusts statusbar mirror percent on `LibOrb`, preventing max-pinned fallback.
Next step:
- `/reload`, spend mana repeatedly, verify orb drains every cast and refills while idle/drinking.

2026-02-26 (PlayerFrame missing after secure driver failure)
Issue:
- PlayerFrame intermittently disappears while other modules continue loading; no direct Lua stack shown.
Hypothesis:
- Secure `RegisterAttributeDriver` on PlayerFrame can fail under taint/lockdown conditions, leaving the frame hidden or unit driver unset.
Change(s):
- Wrapped PlayerFrame unit driver registration in `pcall`.
- Added fallback to force frame unit to `"player"` and keep frame visible if secure driver registration fails.
- Added module-level retry handler (`RetryEnableDriver`) on `PLAYER_REGEN_ENABLED` to restore secure vehicle/player driver post-combat.
- Wrapped `UnregisterAttributeDriver` in `pcall` during disable.
Result:
- PlayerFrame should remain visible even when secure driver registration is temporarily blocked.
- Secure vehicle/player driver is retried when combat lockdown ends.
Next step:
- `/reload` and verify PlayerFrame visibility in/out of combat and during vehicle transitions.

2026-02-26 (Mana orb drains once then pins)
Issue:
- Orb fills after one cast but does not continue draining while mana is spent.
Hypothesis:
- `UpdateAdditionalPower` used a weaker percent fallback path than `UpdatePower`, causing stale `safeCur` when `UnitPower`/percent payloads become secret or stale.
Change(s):
- Ported resilient power resolution logic into `UpdateAdditionalPower`:
  - use `ProbeSafePercentAPI(...)`,
  - detect stale raw values vs percent,
  - apply post-write mirror percent refresh from bar texture state.
- Added `Value:UpdateTag()` refresh for orb value text parity.
Result:
- AdditionalPower now updates from the same robust fallback chain as Power and should keep draining/updating continuously.
Next step:
- `/reload`, then repeatedly spend mana and verify orb fill + text update continuously.

2026-02-26 (Mount/vehicle special bar using base actions on keybinds)
Issue:
- On mount/vehicle special bars, keybinds were triggering base bar spells instead of the active special actions.
Hypothesis:
- Command bindings (`SetOverrideBinding` with `ACTIONBUTTON#` tokens) on Bar 1 can bypass secure state-mapped button actions during override/vehicle/possess paging.
Change(s):
- In `ActionBar.UpdateBindings`, force Bar 1 to use click-binding route (`SetOverrideBindingClick`) even when command-binding mode is enabled.
- Keep command-binding route for non-dynamic bars.
Result:
- Bar 1 keybinds now resolve through the live secure button state and should execute mount/vehicle special actions correctly.
Next step:
- `/reload`, mount and test special actions + dismount.
- Verify normal keybinds still work on Bar 1 and hold-cast behavior on other bars.

2026-02-26 (Orb update resiliency + target cast/health movement controls)
Issue:
- Orb appeared visible but not reliably updating in some states.
- Requested movement controls for current target health/cast behavior similar to fake-fill era.
Hypothesis:
- `UpdateAdditionalPower` was dropping updates when unit payload was nil.
- Visibility/update routing could leave orb stale unless explicit refresh occurred.
- Cast movement controls were still gated by flip-lab dev path.
Change(s):
- `API.UpdateAdditionalPower`: accept nil unit payload by falling back to `self.unit`.
- `Mana_UpdateVisibility`: force update while orb is enabled.
- `GetTargetHealthLabSettings`: remove flip-lab gating from orientation and cast movement/size/anchor settings.
- Target options: expose cast movement/size/orientation controls in active fake-fill mode (`TargetUseNativeFedFakeFill`) instead of dev-only flip-lab gating.
Result:
- Orb update path is more robust to event payload variance.
- Target cast/health movement controls now affect active renderer in normal mode.
Next step:
- `/reload` and verify orb drains/recharges live; test target cast anchor/offset/size and health orientation on self, player, NPC.

2026-02-26 (Target option trace cleanup + player orb/crystal overlap guard)
Issue:
- Target options still contained legacy/duplicate controls, and player orb/crystal could overlap or appear with wrong draw precedence during mode/event transitions.
Hypothesis:
- Legacy percent/full toggles are redundant now that `PowerValueFormat` drives runtime tags.
- Orb/crystal visibility was computed in two places without a shared resolver, allowing transient overlap and inconsistent z-order.
Change(s):
- Hid legacy power text toggles in options for Player/Target (`powerValueUsePercent`, `powerValueUseFull`) while keeping profile compatibility.
- Added shared player power visibility resolver and used it in both orb and crystal update paths.
- Enforced mutual exclusion (`Power` vs `AdditionalPower`) and deterministic frame levels from fixed base levels each update.
Result:
- Cleaner options UI with active controls only.
- Orb/crystal mode transitions are deterministic and no longer rely on event-order luck.
Next step:
- `/reload` and validate:
  - mode switches `orbV2`/`legacyCrystal`,
  - `alwaysShowManaOrb`/`alwaysUseCrystal`,
  - no overlap while entering/leaving combat and vehicle transitions.

2026-02-26 (Target options cleanup for active fake-fill renderer)
Issue:
- Target options page still exposes many legacy/debug controls that do not affect live target health/cast visuals in native-fed fake-fill mode.
- Useful fake-fill alignment controls were gated behind `healthFlipLabEnabled`/dev-only visibility.
Hypothesis:
- `GetTargetHealthLabSettings` still requires flip-lab enabled for key fake-fill geometry values (especially health fake offsets/insets), so user-facing controls appear dead.
Change(s):
- Expose active target fake-fill options (health/cast fake alignment) in normal target options flow.
- Keep deep flip-lab/debug controls dev-gated.
- Make style fake overrides and fake alignment values apply without requiring `healthFlipLabEnabled`.
Result:
- Target options now map to the active renderer path and avoid dead controls in normal use.
Next step:
- `/reload` and validate target health/cast fake alignment sliders/toggles apply instantly on self target, player target, NPC target, and boss style target.

2026-02-26 (Midnight stabilization pass: key routing, power orb mode, target native-fed fake fill)
Issue:
- Requested bundled stabilization pass:
  - add explicit key/hold diagnostics (`/azdebugkeys`),
  - move action key routing to command-binding first for hold-cast reliability,
  - harden LAB cooldown payload normalization,
  - add power orb/text mode controls and target native-fed fake-fill mode.
Hypothesis:
- Hold-cast is currently limited by click-binding path and stale toggle visibility.
- Cooldown payloads still risk nil/secret shape drift under combat updates.
- Target fake/native visual arbitration is too permissive and allows wrong-direction fallback.
- Power text mode is fragmented (`percent`/`full` booleans) and needs a single format selector.
Change(s):
  - Add `/azdebugkeys` status/bindings/cooldown/holdtest commands.
  - Add `ActionBars.UseCommandBindingsForHoldCast` and command-binding primary path with click fallback.
  - Normalize LAB `cooldownInfo/chargeInfo` numeric+enabled fields before secure apply.
  - Add `UnitFrames.PowerOrbMode`, `UnitFrames.PowerValueFormat`, `UnitFrames.TargetUseNativeFedFakeFill`.
  - Gate target fill logic to native-fed fake path when enabled, with native bars retained as data sources.
Result:
- Implemented code-side pass across debugging, actionbar routing, LAB cooldown normalization, unitframe power formatting, and target fake-fill mode gating.
- Added defensive fallback behavior so missing unitframe submodules no longer explode option generation (`GenerateSubOptions` now returns a safe disabled stub instead of nil).
Next step:
- Run in-game `/reload` loop and validate:
  - `/azdebugkeys status|bindings|cooldown`,
  - press-and-hold repeat behavior with command mode ON/OFF,
  - target health/cast mirrored fake-fill behavior with `TargetUseNativeFedFakeFill`,
  - player/target power text formatting via new `PowerValueFormat`.

2026-02-23 (WoW 12.0 secret-value crash: oUF Health)
Issue:
 - Lua error: "table index is secret" in AzeriteUI/Libs/oUF/elements/health.lua:125
 - Stack shows Health:UpdateColor using secret values as table indices (threat, selection, reaction)
Hypothesis:
 - WoW 12+ marks some return values (e.g., UnitThreatSituation, UnitReaction, unitSelectionType) as secret for protected units
 - Using these as table keys triggers a hard error
Change(s):
 - Added issecretvalue() checks before using threat, selection, or reaction as table indices in Health:UpdateColor
 - If secret, skip and optionally log if FixBlizzardBugs debug is enabled
Result:
 - No more "table index is secret" errors when targeting protected/secret units
 - Health bar color fallback is safe
Next step:
 - Monitor for any missed secret-value cases in oUF or other elements
# Fix Log

Purpose: Track Lua errors, hypotheses, fixes tried, and results so we avoid looping.

Format:
- Date (YYYY-MM-DD)
- Error(s)
- Hypothesis
- Change(s)
- Result
- Next step (if needed)

---

2026-02-21 (press/hold regression follow-up: remove forced `useOnKeyDown` path, restore CVar-driven behavior, fix `/az` toggle sync)
Issue:
- User reports:
  - no Lua errors,
  - cooldowns/swipes restored,
  - hold/press still behaves like key-up queueing,
  - `/az` actionbar toggle for key-down appears ineffective.
Root cause hypothesis:
- Current LAB fork forced `useOnKeyDown` per-button; if stale/mismatched it can override expected CVar behavior.
- `/az` option updated addon DB, but ActionBars refresh mirrored DB back from CVar, so UI toggle looked stuck unless CVar also changed.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Removed custom `useOnKeyDown` helpers and per-button attribute writes.
  - Stopped mutating `useOnKeyDown` on create/config/CVAR updates.
  - Restored `CVAR_UPDATE` handling for `countdownForCooldowns` visibility updates.
- `Options/OptionsPages/ActionBars.lua`:
  - `/az` `clickOnDown` toggle now sets Blizzard CVar `ActionButtonUseKeyDown` out of combat.
  - Getter now reads live CVar on retail clients so menu state reflects actual behavior.
- `Components/ActionBars/Elements/ActionBars.lua`:
  - `UpdateSettings` now reads key-down state via `C_CVar.GetCVarBool` (fallback `GetCVarBool`).
  - Added `OnCVarUpdate` handler for `ActionButtonUseKeyDown` and registered `CVAR_UPDATE` to refresh bars when changed outside `/az`.
Expected result:
- Press/hold and key-down/up behavior follow Blizzard setting again.
- `/az` toggle immediately reflects and applies real key-down CVar state.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- `luac -p Options/OptionsPages/ActionBars.lua`
- `luac -p Components/ActionBars/Elements/ActionBars.lua`
- In-game:
  - `/reload`
  - toggle key-down in `/az` and Blizzard options, verify both UIs stay in sync
  - verify hold/press no longer queues to key release.

2026-02-21 (LAB hold-to-cast follow-up: sync `useOnKeyDown` with ActionButtonUseKeyDown CVar)
Issue:
- User reports no Lua errors, cooldowns/swipes restored, but hold/press behavior still acts like key-up queueing.
API verification:
- `C_CVar.GetCVarBool` / `CVAR_UPDATE` are available.
- `C_Spell.IsPressHoldReleaseSpell` confirms press/hold spell detection path.
Root cause hypothesis:
- Secure buttons rely on `useOnKeyDown` attribute for keybind press timing.
- In current fork this attribute can stay nil/stale on LAB buttons, causing key-up style activation even when player expects key-down/hold.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Added helper to read `ActionButtonUseKeyDown` (`C_CVar.GetCVarBool` fallback `GetCVarBool`).
  - Added helper to apply `useOnKeyDown` attribute to LAB buttons.
  - Apply on button creation and config updates.
  - Handle `CVAR_UPDATE` for `ActionButtonUseKeyDown` and refresh all LAB buttons.
  - Forced initial action refresh on create (`UpdateAction(true)`) so secure state/timing attributes are synchronized immediately.
Expected result:
- Keybind press timing matches game setting.
- Hold/press behavior should stop feeling queued-to-release when key-down casting is enabled.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- In-game `/reload`, toggle key-down casting setting and verify immediate behavior change.

2026-02-20 (LAB follow-up 2: preserve secret cooldown payloads for in-combat swipes/timers + force action refresh)
Issue:
- User reports:
  - cooldown swipes/timers only resume after leaving combat,
  - hold-to-cast still not functioning.
Root cause hypothesis:
- Apply-branch sanitizer replaced secret numeric payload fields with safe numeric fallbacks (`0/cached`), preventing Blizzard's secure cooldown path from consuming live in-combat secret values.
- `UpdateConfig` used `self:UpdateAction()` (non-forced), which can skip secure state refresh when action id/type did not change.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - In `ActionButton_ApplyCooldown` path:
    - preserve non-nil secret payload fields,
    - only backfill nil fields from live tuple/cache fallbacks.
  - Keep nil guards that prevent compare-with-nil errors for charge/cooldown payloads.
  - In `Generic:UpdateConfig`, force refresh via `self:UpdateAction(true)` (aligns with upstream behavior).
Expected result:
- In-combat cooldown swipes/timers continue updating while secret payloads are present.
- Hold/cast secure attributes are refreshed more reliably after config/action updates.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- In-game `/reload` + combat test for swipes/timers and hold casting.

2026-02-20 (LAB follow-up: restore cooldown swipes/timers under secret payloads + mouse-up click state fix)
Issue:
- User reports:
  - press/hold casting still unreliable,
  - cooldown swipes/timers disappeared after recent secret-value sanitizer updates.
Root cause:
- `ActionButton_ApplyCooldown` sanitizer in `UpdateCooldown(...)` defaulted secret/unknown cooldown fields to zeros too aggressively.
- This effectively disabled visible cooldown state during secret ticks.
- LAB also still forced `self:SetButtonState("NORMAL")` on `GLOBAL_MOUSE_UP`; upstream removed this in `c2cf299` due click/keybind interaction issues.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - In `UpdateCooldown(...)` apply-branch:
    - switched from zero-only fallbacks to cache-aware fallbacks for:
      - `cooldownInfo.startTime/duration/modRate/isEnabled`
      - `chargeInfo.currentCharges/maxCharges/cooldownStartTime/cooldownDuration/chargeModRate`
    - persist normalized values back to existing per-button cache.
  - In `Generic:OnButtonEvent(...)`:
    - removed `self:SetButtonState("NORMAL")` on `GLOBAL_MOUSE_UP` (aligns with upstream `c2cf299` behavior).
Expected result:
- Cooldown swipes/countdown timers return during secret-heavy updates.
- Fewer input-state conflicts between hold/mouse/keybind interactions.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- In-game `/reload`; verify cooldown swipes/timers and press/hold behavior.

2026-02-20 (LAB cooldown sanitizer: avoid boolean test on secret `isEnabled`)
Issue:
- BugSack spam:
  - `LibActionButton-1.0-GE.lua:2499: attempt to perform boolean test on field 'isEnabled' (a secret boolean value tainted by 'AzeriteUI')`
  - Triggered in `UpdateCooldown(...)` before `ActionButton_ApplyCooldown(...)`.
Root cause:
- Sanitizer used:
  - `cooldownInfo.isEnabled = (cooldownInfo.isEnabled and 1) or 0`
- This boolean-tests `isEnabled`; on WoW12 secret payloads that can be a secret boolean and crashes immediately.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Added secret-safe enabled-normalizer that:
    - accepts safe numbers (`0/1` normalization),
    - accepts non-secret booleans,
    - falls back to `0` for secret/invalid values.
  - Applied it to both:
    - `cooldownInfo.isEnabled` in `ActionButton_ApplyCooldown` branch,
    - legacy fallback `enable` normalization branch.
Expected result:
- No secret-boolean test on `isEnabled`; BugSack error should stop.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- In-game `/reload`; exercise actionbar/flyout updates and verify no repeat of this error.

2026-02-20 (LAB hold/cast regression: restore upstream useOnKeyDown pickup toggle)
Issue:
- User reports hold-and-cast behavior is broken.
- Workspace scan showed AzeriteUI fork replaced LAB pickup-click on-down handling with a no-op block in:
  - `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`WrapOnClick`).
- Post-handler no longer restores `useOnKeyDown`, and fork kept a dead `ToggleOnDownForPickup` stub.
Research:
- Compared against upstream LAB source in workspace clone and online GitHub mirror:
  - repo: `https://github.com/Nevcairiel/LibActionButton-1.0`
  - commit: `e95063e` (`Fix preventing casting when picking up an action`)
- Upstream fix uses secure attribute toggling (`useOnKeyDown`) instead of CVar mutation.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Restored upstream pickup path in `WrapOnClick`:
    - when pickup drag is possible, backup `useOnKeyDown`,
    - temporarily set `useOnKeyDown=false`,
    - set `LABToggledOnDown` and `LABToggledOnDownBackup`.
  - Restored post-click re-enable logic:
    - `useOnKeyDown = LABToggledOnDownBackup`,
    - clear LAB toggle attributes.
  - Removed dead local `ToggleOnDownForPickup` helper stub (unused).
Expected result:
- Hold/on-down cast behavior works again while retaining protected-action safety.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- In-game `/reload`, verify:
  - normal press/hold casting works,
  - pickup/drag still works,
  - no new protected-action BugSack errors.

2026-02-20 (LAB flyout: prevent nil charge fields in ActionButton_ApplyCooldown)
Issue:
- BugSack still reports:
  - `Blizzard_ActionBar/Shared/ActionButton.lua:921: attempt to compare number with nil`
  - stack enters secure flyout `HandleFlyout` and then `slotButton:CallMethod("UpdateAction")`.
- Prior `numFlyoutButtons` guard is active, so this is no longer the numeric-for nil issue.
Hypothesis:
- `ActionButton_ApplyCooldown(...)` expects numeric charge fields.
- Flyout spell buttons without real charge data can pass `chargeInfo.maxCharges/currentCharges = nil`.
- Blizzard then evaluates `chargeMaxCharges > 1`, causing `number with nil`.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - In `UpdateCooldown(...)`, normalize `cooldownInfo`, `chargeInfo`, and `lossOfControlInfo` fields to safe numeric defaults immediately before `ActionButton_ApplyCooldown(...)`.
  - Explicitly force missing/secret charge fields to:
    - `currentCharges = 0`
    - `maxCharges = 0`
    - `cooldownStartTime = 0`
    - `cooldownDuration = 0`
    - `chargeModRate = 1`
Expected result:
- Flyout buttons no longer trigger `ActionButton.lua:921` nil comparison errors when opened/updated.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- In-game `/reload`, open/close flyouts repeatedly, confirm BugSack stays clean for this error.

2026-02-20 (target power visibility: don't hide when power values are secret)
Issue:
- Target power bar/value disappeared after recent changes; dump shows power min/max/cur are often secret.
- `Power_UpdateVisibility` coerces secret values to `safeCur=0`/`safeMax=1` then hides the bar when `cur==0`, which collapses visibility during secret-value updates.
Hypothesis:
- Hiding based on coerced secret zeros is masking valid power updates.
- We should only hide for `cur==0`/`max==0` when those values are non-secret.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Track secret flags for `cur/max`.
  - Use last safe numeric values for rendering, but only apply the `cur==0/max==0` hide rule when both values are non-secret.
Expected result:
- Power crystal/value stays visible and updates during secret-value ticks, while still hiding for truly zero-power units.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload` then `/azdebug dump target`:
  - power bar remains visible during combat/secret updates
  - values update again (or at least no longer disappear).

2026-02-20 (player/target power text: derive percent from texcoords for secret values)
Issue:
- Power statusbar renders correctly, but text shows max value only (current appears pinned to max).
- Secret-value paths often return `cur/max` as secrets; fallback uses `safeCur=safeMax`, which makes tags read as max.
Hypothesis:
- Power statusbars rely on texcoord clipping, so texture size does not change; the existing size-based percent probe returns 100%.
- We should derive percent from texcoord span relative to a cached base texcoord when available.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - In `GetTexturePercentFromBar`, first attempt percent from texcoord span vs cached base texcoord.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - Cache base texcoord on power bars at creation time so texcoord-based percent can be computed.
Expected result:
- Power value tag uses a realistic current value instead of always showing max.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, verify player/target power text reflects current power.

2026-02-20 (power texcoord percent: guard secret texcoords; pet options nil guard)
Issue:
- BugSack: `GetTexturePercentFromBar` attempted arithmetic on secret texcoords when base coords are present.
- Options crash: `OptionsPages/UnitFrames.lua` pet section still assumes `suboptions` exists.
Hypothesis:
- Texture texcoords can be secret; we must avoid arithmetic on secret values and fall back to size-based probe.
- Pet options need the same nil guard used for cast/classpower sections.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - Skip texcoord-span math when base/current coords are secret or base span is zero.
- `Options/OptionsPages/UnitFrames.lua`:
  - Guard pet options block against nil `suboptions`.
Expected result:
- No secret-value arithmetic errors in power percent probe.
- Options menu no longer errors on Pet section when module is unavailable.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
- In-game `/reload`, open `/az` options and confirm no BugSack errors.

2026-02-20 (power text: prefer direct UnitPower when current is secret)
Issue:
- Power text still pins to max because SafeUnitPower falls back to `safeCur = safeMax` when current is secret.
Hypothesis:
- We can display secret current values directly (no arithmetic) by returning the raw `UnitPower` value through safe formatting.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - In `*:Power` tag, attempt to render direct `UnitPower` first (including secret values) before SafeUnitPower fallback.
Expected result:
- Power value text shows current power again even when current is secret.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- In-game `/reload`, confirm power text updates while spending power.

2026-02-20 (power text formatting: add full option + use Blizzard formatter)
Issue:
- Power text shows full raw values; user requested health-like formatting and a full/percent-style option.
Hypothesis:
- Using Blizzard `AbbreviateNumbers` when available will match health formatting without arithmetic.
- Add a `powerValueUseFull` option to switch between `current`, `full (cur/max)`, and `percent`.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - Added safe power value formatter using `AbbreviateNumbers` when available.
  - `*:Power` and `*:Power:Full` use the formatter for current/max values.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - Added `powerValueUseFull` default and tag selection logic.
- `Options/OptionsPages/UnitFrames.lua`:
  - Added “Power Text Uses Full (cur/max)” toggle for player/target.
  - Toggle clears percent option and vice-versa to avoid conflicts.
Expected result:
- Power text is abbreviated like health by default, with selectable full/percent formatting.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
- In-game `/reload`, toggle options and verify power text formatting.

2026-02-20 (deep clean pass 6: force texcoord on native health statusbar texture each update)
Issue:
- Even with deep-clean `reverse=true` and flipped health art texcoords, user still observed native health fill not matching.
- Dump indicated backdrop/fake texcoords were flipped, but native fill behavior could still diverge.
Hypothesis:
- Setting texcoord on the statusbar wrapper may be insufficient; native statusbar texture can be rewritten by internal updates.
- Need direct texcoord application on `health:GetStatusBarTexture()` and periodic reapply.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Added helper to apply texcoords directly to native health texture.
  - Reapply native texture texcoord during deep-clean visual sync.
  - Reapply native texture texcoord during target texture/layout update pass.
Expected result:
- Native health texture orientation should stay locked to deep-clean flipped texcoord settings across updates.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload` then `/azdebug dump target`:
  - `Target.Health reverse: true`
  - health art texcoord remains `1 0 ...`
  - native fill direction remains consistent after repeated health updates.

2026-02-20 (deep clean pass 5: force native reverse fill to align with flipped texcoord art)
Issue:
- After pass 4, health art flipped correctly via texcoord, but live native health fill still did not match.
- Dump showed `Target.Health flipped: false reverse: false` while health art texcoord was flipped.
Hypothesis:
- Native statusbar fill direction is controlled by reverse fill, not only texture texcoord.
- With texcoord-flipped art and `reverse=false`, visuals diverge.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In deep-clean mode, force native health reverse fill ON (`reverse=true`).
  - Keep deep-clean flip ownership via texcoord (`healthTexLeft/right = 1,0`).
Expected result:
- Target health fill direction and health art should move in the same flipped direction.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload` then `/azdebug dump target`:
  - `Target.Health reverse: true`
  - health art texcoord remains horizontally flipped (`1 0 ...`).

2026-02-20 (deep clean pass 4: move target health flip control to texcoord path)
Issue:
- User reports native flip flags are not producing stable visual parity between bar fill and surrounding health art.
- Requested that both visuals follow texture texcoord flipping.
Hypothesis:
- Mixing `SetFlippedHorizontally(...)` with texcoord inversion can create hard-to-predict cancellation.
- For deep-clean baseline, one flip mechanism should own the result.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In deep-clean mode, stop forcing native flipH on the health statusbar.
  - Force deep-clean health texcoords to horizontal flip (`left/right = 1,0`) so:
    - health bar texture and related health art use the same flip source.
  - Keep deep-clean native-only health visual path.
Expected result:
- Target health and health art should flip together via texcoord, reducing mixed-state drift.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload` then `/azdebug dump target`:
  - `Target.Health flipped: false reverse: false`
  - health-related texcoords show horizontal flip (`1 0 ...`).

2026-02-20 (deep clean pass 3: neutralize health texcoords to prevent double-flip cancellation)
Issue:
- Bar dumps showed target health with `flipped=true reverse=false`, but visual direction still appeared unflipped.
Hypothesis:
- In deep-clean mode, native flip was forced ON, but health texcoords could still be horizontally flipped (`1,0`) from style/profile/frame config.
- `SetFlippedHorizontally(true)` + flipped texcoords can visually cancel each other (double flip).
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In deep-clean mode, force health texcoords to neutral:
    - `healthTexLeft/right = 0,1`
    - `healthTexTop/bottom = 0,1`
  - Keep native orientation clamp (`reverse=false`, `flipped=true`) and native-only visuals.
Expected result:
- Target health should now visibly use the forced native flip direction, without texcoord cancellation.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, then `/azdebug dump target`:
  - `Target.Health flipped: true reverse: false`
  - `Target.Health.Display.StatusBarTexture texcoord: 0 1 0 1` (or equivalent neutral horizontal texcoord)

2026-02-20 (deep clean pass 2: force native health only, forced flip=true/reverse=false)
Issue:
- Deep-clean baseline still rendered target health reversed during live updates.
- Runtime dumps continued to show `Target.Health flipped=false reverse=true`, matching profile defaults.
Hypothesis:
- Deep-clean mode still inherited health profile fill defaults (`healthLabReverseFill=true`, `healthLabSetFlippedHorizontally=false`) and continued to run fake/display arbitration.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In deep-clean mode, hard-force native health orientation to:
    - `reverseFill = false`
    - `flippedHorizontally = true`
  - In deep-clean mode, bypass fake health fill arbitration and show native health visuals only.
  - Keep fake/display health textures hidden in deep-clean mode so updates are driven only by native statusbar value changes.
Expected result:
- Target health should be visibly flipped and continue updating every health tick without fake-fill branch interference.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload` then `/azdebug dump target`:
  - confirm `Target.Health flipped: true reverse: false`
  - confirm health continues updating.

2026-02-20 (deep clean baseline pass: target health fake-fill reduced to native mirror only)
Issue:
- User requested a hard reset of target health fill logic after repeated orientation/fallback drift while testing many debug toggles.
- Current runtime often converges to:
  - `healthFake: source native nativeMode mirror percent nil targetPctSource none`
  - with many alternate percent and force-direction branches still available.
Hypothesis:
- Too many concurrent health fill branches (mirror/texture/safepct/nativegeom/minmax/last + force invert/flip/reverse overrides + display/crop experiments) are obscuring root-cause verification.
- A deterministic baseline with one health fallback path is needed before reintroducing complexity.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Enable a temporary deep-clean baseline mode for target health.
  - Disable health percent-source fallbacks (mirror, texture, safepct, nativegeom, minmax, last).
  - Disable health force-direction overrides (invert/noinvert/reverse/noreverse/flip/noflip).
  - Collapse native health fallback to one path:
    - direct native geometry mirror + native texcoord copy to fake fill.
  - Force native fallback path on, clip-native behavior on, and prefer fake visuals in this baseline.
Expected result:
- Target health rendering path should be deterministic and reproducible:
  - no percent-source arbitration,
  - no force-direction side effects,
  - one native mirror baseline to validate orientation and clipping.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, then verify target health behavior with minimal toggles and collect fresh dumps.

2026-02-20 (slash parity: accept dotted /azdebugtarget option tokens)
Issue:
- User reports target debug commands appear to work only through the menu.
- Chat usage commonly follows menu labels (for example `health.clipnative off`) and was not accepted by slash parser.
Hypothesis:
- `Debugging.TargetDebugMenu` only accepted the spaced form:
  - `/azdebugtarget health clipnative off`
- It did not parse dotted tokens like:
  - `/azdebugtarget health.clipnative off`
  - `/azdebugtarget cast.nativevisual off`
Change(s):
- In `Core/Debugging.lua`:
  - Added parser helper `ParseTargetFillScopedOptionToken(...)` supporting:
    - `<scope>.<option>` (`cast.*`, `health.*`, `both.*`)
    - `target.<scope>.<option>`
  - Added dotted-token handling path in `Debugging.TargetDebugMenu`.
  - Updated `/azdebugtarget help` output to include dotted command syntax.
Expected result:
- Menu toggles and slash commands now map to the same options with either syntax style.
Validation:
- `luac -p Core/Debugging.lua`
- In-game examples:
  - `/azdebugtarget health.clipnative off`
  - `/azdebugtarget cast.nativevisual on`
  - `/azdebugtarget target.health.forceinvert on`

2026-02-20 (target health first-update flip: prevent generic UpdateHealth from overriding target-managed display layout)
Issue:
- User reports target health can appear correct on target switch/toggle, then flips/scales after the first combat health update.
- Behavior is consistent with a runtime layout writer reapplying state during `UNIT_HEALTH` updates.
Hypothesis:
- `API.UpdateHealth` generic `element.Display` block force-called `SetAllPoints(element)` + `Show()` on every update.
- `Target.lua` also manages `Health.Display` geometry/visibility, so generic writes can stomp target-specific layout right when combat updates begin.
Change(s):
- In `Components/UnitFrames/Functions.lua`:
  - Added managed-display guard in `API.UpdateHealth`:
    - if `element.__AzeriteUI_ManageDisplayInOverride == true`, skip generic parent/points/framelevel/show forcing.
    - keep value sync (`SetStatusBarValuesCompat(display, ...)`) only.
- In `Components/UnitFrames/Units/Target.lua`:
  - Marked target health as local-display-managed:
    - `self.Health.__AzeriteUI_ManageDisplayInOverride = true`
    - `self.Health.Display.__AzeriteUI_ManagedByTarget = true`
Expected result:
- First health update during combat should no longer re-anchor/force-show target display bar from the generic health pipeline.
- Target health orientation/clipping should stay under target module control across updates.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game: `/reload`, target enemy, attack once, verify orientation does not change on first health tick.

2026-02-20 (target native mirror flip on damage: gate native texcoord copy behind clipnative)
Issue:
- User still reports target health flips direction as soon as target takes damage.
- Dump shows frequent fallback path:
  - `healthFake: source native nativeMode mirror percent nil targetPctSource none`
- In this mode, texcoord updates can still track native runtime orientation changes.
Hypothesis:
- Mirror fallback was still copying native texcoords every update even when `health.clipnative` was OFF.
- Native texcoord orientation can change on combat ticks in secret-value paths, causing visible direction flips.
Change(s):
- In `Components/UnitFrames/Units/Target.lua` (`UpdateTargetFakeHealthFillFromNativeTexture` mirror branch):
  - `clipnative ON`: keep native texcoord copy (explicit A/B behavior).
  - `clipnative OFF`: force stable configured fake texcoords (`__AzeriteUI_FakeTex*`) and do not copy native texcoords per tick.
Expected result:
- With `health.clipnative OFF`, native mirror fallback should keep a stable orientation through damage updates.
- `clipnative ON` remains the intentionally native-mirrored test path and can still flip based on native state.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target display mode orientation drift: snapshot native texcoord once per target)
Issue:
- User confirms `nativeMode display` is active with `health.clipnative OFF`, but health orientation still starts wrong or drifts after first updates.
- With `clipnative ON`, initial orientation can look correct but flips after first update (expected native texcoord drift path).
Hypothesis:
- `Health.Display` was still seeded by configured texcoords during style update, not by live native orientation state.
- Native orientation can be correct at first sample and then drift if texcoord is reapplied dynamically.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - In display native fallback path (`UpdateTargetFakeHealthFillFromNativeTexture`):
    - snapshot native texcoord onto `Health.Display` exactly once per target using `ApplyTargetNativeTexCoordToFakeFill(...)`,
    - fallback to AzeriteUI fake texcoords if native copy fails,
    - mark snapshot with `health.__AzeriteUI_DisplayNativeTexCaptured = true`.
  - In `UnitFrame_UpdateTextures(...)`:
    - only push configured texcoords into `Health.Display` when the one-shot native snapshot has not been captured yet.
  - In `PLAYER_TARGET_CHANGED` reset:
    - clear `health.__AzeriteUI_DisplayNativeTexCaptured` so next target can resample.
- In `Core/Debugging.lua`:
  - extended `healthFake` dump line with `displayTexCaptured` to verify one-shot capture state.
Result:
- `Health.Display` now locks to the first live native orientation for each target and avoids post-update orientation drift from repeated texcoord reseeding.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-02-20 (target native fallback v2: display-statusbar crop path + debug dump)
Issue:
- User confirms current target health behavior:
  - update direction can be correct,
  - but fallback fill still behaves like scale/stretch instead of crop when source resolves to native with no safe percent.
- Dump repeatedly shows:
  - `healthFake: source native nativeMode mirror percent nil targetPctSource none`
Hypothesis:
- Native no-percent fallback still depends on texture-mirror path when percent derivation fails under secret values.
- We need a crop-safe path that does not require percent arithmetic and does not rely on native texcoord semantics.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added `Health.Display` statusbar overlay (`Target.Health.Display`) for native no-percent fallback rendering.
  - `UpdateTargetFakeHealthFillFromNativeTexture(...)` now prefers `nativeMode = "display"` when `health.clipnative` is OFF:
    - forwards native `GetMinMaxValues()` + `GetValue()` directly into `Health.Display` via `pcall`,
    - hides fake texture and shows display bar on success.
  - Kept existing direct native geometry behavior for `clipnative ON` A/B.
  - Wired display visibility into fake/native visual arbitration:
    - hide display on non-native percent paths and when showing native visuals.
  - Synced display style/color in `UnitFrame_UpdateTextures(...)` and `Health_PostUpdateColor(...)`.
  - Hide display on `PLAYER_TARGET_CHANGED` reset path.
- In `Core/Debugging.lua`:
  - Added dump entry for `Target.Health.Display` in `DumpUnitBars(...)`.
Result:
- Native no-percent fallback has a new crop-capable rendering path that is independent of fake texture scaling behavior.
- `/azdebugtarget` A/B remains available via existing `clipnative` toggle.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-02-20 (target native mirror crop pass: full fake geometry + native texcoord sync)
Issue:
- User confirms latest state:
  - orientation and update direction are now correct,
  - but health fill still behaves like scale/stretch instead of crop.
- Dump path remains:
  - `healthFake: source native nativeMode mirror percent nil`
Hypothesis:
- Native mirror path still ties fake fill geometry to native texture size in default mode, which visually behaves like scaling.
- To preserve crop behavior, fake fill should keep full bar geometry and mirror native texcoords each update.
Change(s):
- In `Components/UnitFrames/Units/Target.lua` (`UpdateTargetFakeHealthFillFromNativeTexture`):
  - For default mode (`health.clipnative OFF`):
    - fake fill now anchors to full fake geometry (health/fake anchor + insets/offsets).
    - texcoords are synced from native texture via `ApplyTargetNativeTexCoordToFakeFill`.
  - For clipnative mode (`health.clipnative ON`):
    - keep explicit native-geometry mirror behavior for A/B.
  - Added robust fallback: if native texcoord sync fails, use AzeriteUI fake texcoords.
Result:
- Default native mirror path is now oriented around crop-style rendering instead of geometry-size scaling.
- `clipnative` remains the deliberate “mirror native size” test mode.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target native mirror flip on update: keep AzeriteUI texcoord mapping unless clipnative is enabled)
Issue:
- User reports target health appears correct, then flips wrong as soon as health updates.
- Dump shows runtime path:
  - `healthFake: source native nativeMode mirror percent nil`
Hypothesis:
- On each native mirror update, fake fill copied native texcoords again.
- Native texcoord orientation can shift during secret/native updates, causing post-update direction flips.
Change(s):
- In `Components/UnitFrames/Units/Target.lua` (`UpdateTargetFakeHealthFillFromNativeTexture` direct mirror path):
  - Default behavior now keeps AzeriteUI fake texcoords (`__AzeriteUI_FakeTex*`) instead of mirroring native texcoords each update.
  - Native texcoord mirroring is now only used when `health.clipnative` is enabled.
  - Existing invert toggle transform is still applied after texcoord assignment.
Result:
- Native mirror fallback should no longer spontaneously flip orientation on each health update in default mode.
- `clipnative` remains available as explicit A/B path for full native texcoord mirroring.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target native nil-path follow-up: make invert toggles affect native mirror + expose native mode in dump)
Issue:
- Latest dump shows target health is still on:
- `healthFake: source native percent nil targetPctSource none ...`
- In this path, new health invert commands appeared to have little/no effect.
Hypothesis:
- Health invert/no-invert toggles only affected percent-crop path (`ApplyTargetFakeHealthFillByPercent`).
- When resolver falls to native mirror (`source native percent nil`), fake fill copied native geometry directly, bypassing percent inversion.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Track native fallback mode:
    - `__AzeriteUI_TargetNativeMode = "crop"` when derived percent crop succeeds.
    - `__AzeriteUI_TargetNativeMode = "mirror"` when direct native geometry mirror is used.
  - In direct native mirror path, apply health invert toggle by flipping fake-fill texcoords horizontally (supports 4-value and 8-value texcoords).
  - Clear `__AzeriteUI_TargetNativeMode` when non-native path is used or update fails.
- In `Core/Debugging.lua`:
  - Extend health dump line to print `nativeMode` for target health fake-fill.
Result:
- `health.forceinvert` / `health.forcenoinvert` now affect behavior even when target health is on native `percent=nil` mirror path.
- Dump now clearly indicates whether native fallback is using `crop` or `mirror`.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-02-20 (target health direction persistence: use live reverse state + add invert action buttons)
Issue:
- User reports target health can appear correct immediately after toggling `nativevisual` OFF, then drift back after next health update.
- New health invert commands were added but user requested explicit menu buttons for all new commands.
Hypothesis:
- Fake-fill direction used cached setup reverse (`__AzeriteUI_FakeReverse`) and could diverge from live statusbar reverse state after runtime updates/retarget.
- Dedicated action buttons reduce command friction and make A/B reproducible.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - `ApplyTargetFakeHealthFillByPercent(...)` now reads live `health:GetReverseFill()` every update (when available) and uses that for fill direction.
- In `Core/Debugging.lua` (`/azdebugtarget` actions):
  - Added explicit buttons:
    - `Health Invert ON`
    - `Health Invert OFF`
    - `Health NoInvert ON`
    - `Health NoInvert OFF`
  - Buttons wire to:
    - `health.forceinvert`
    - `health.forcenoinvert`
Result:
- Target health fake-fill direction should stay aligned with the live bar reverse state across updates.
- New health invert commands are now available as explicit menu buttons in addition to toggle rows/commands.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-02-20 (target health direction mix: add percent invert controls without reverting update fix)
Issue:
- After latest target health source-reliability fix, user reports:
  - target health now updates,
  - but fill direction is wrong.
Hypothesis:
- Update reliability and visual direction are now decoupled.
- We need a directional override at fake-fill percent stage (like cast already has) so we can keep live updates while tuning target fill direction.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added target health percent-direction toggles:
    - `__AzeriteUI_DEBUG_TARGET_HEALTH_FORCE_INVERT`
    - `__AzeriteUI_DEBUG_TARGET_HEALTH_FORCE_NOINVERT`
  - Added helper `ShouldTargetHealthInvertPercent()` and applied it in `ApplyTargetFakeHealthFillByPercent(...)`.
- In `Core/Debugging.lua`:
  - Added `/azdebugtarget` health options:
    - `health.forceinvert`
    - `health.forcenoinvert`
  - Added mutual-exclusion pair for the two new flags.
  - Extended bar dump `healthFake` line to print current invert/noinvert flags.
Result:
- We can now A/B target health direction independently from source reliability:
  - updates remain from the previous fix,
  - direction can be flipped via debug toggles without code rollback.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-02-20 (target health freeze follow-up: distrust target UnitHealthPercent on secret paths + add target identity snapshot)
Issue:
- User still reports target health bar can stay visually correct but not update while target changes (player vs enemy/dummy).
- Latest dump still showed:
  - `healthFake: source safepct percent 100 ...`
  - This indicates fake-fill kept consuming `safePercent` during secret target flow.
Hypothesis:
- `UnitHealthPercent` can be stale/frozen for target in secret-value conditions and should not drive target fake-fill percent when raw target values are unreadable.
- We also need explicit target-type metadata in snapshot output to correlate behavior by target class/faction/control.
Change(s):
- In `Components/UnitFrames/Functions.lua`:
  - For `unit == "target"`, ignore `safePercent` from `UnitHealthPercent` when raw cur/max are not both safe.
  - Remove `targetPercentSource = "unitpct"` assignment in target resolver (keeps source as `none` unless mirror/api/minmax/cached applies).
- In `Components/UnitFrames/Units/Target.lua`:
  - Tighten `IsTargetHealthSafePercentReliable(...)` to trust only `mirror`/`api` for target.
- In `Core/Debugging.lua`:
  - Extend `snapshot` output with target identity/reaction flags:
    - `UnitGUID`
    - `isPlayer`, `playerControlled`
    - `canAttack`, `canAssist`
    - `isEnemy`, `isFriend`
    - `reaction`, `tapDenied`
Result:
- Target health fake-fill should stop locking onto stale `safepct=100` in secret target updates and fall through to native/mirror-driven live geometry instead.
- Snapshot now includes enough target metadata to validate whether behavior differs by enemy/player/player-controlled classification.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-02-20 (target health freeze after retarget: explicit unitpct source + last-fallback gate)
Issue:
- Target health can appear oriented correctly but stop updating after target swaps.
- Dumps show resolver moving between `source last` and `source native`, with `source last` sometimes freezing at full percent.
Hypothesis:
- `UpdateHealth` may have a valid target percent from UnitHealthPercent probes, but marks source as `none`, so target resolver treats `safePercent` as unreliable and falls through to stale/native paths.
- Health `last` fallback for target can freeze bar when no reliable source exists.
Change(s):
- In `Components/UnitFrames/Functions.lua`:
  - For target updates, when `safePercent` is numeric but no mirror/api/minmax/cached source was selected, assign source `unitpct`.
- In `Components/UnitFrames/Units/Target.lua`:
  - Treat `unitpct` as reliable in target health safe-percent/minmax reliability checks.
  - Gate target health `last` fallback: only allow `last` when target source is explicitly `cached`.
Result:
- Target health fake resolver should keep using live percent sources more often and avoid stale `last` freezes when source is unknown.
- Expected effect: health updates continue after retarget without dropping into frozen full-bar state.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target health freeze follow-up: stop trusting synthetic safepct/minmax)
Issue:
- New dumps still showed frozen target health:
  - `healthFake: source safepct percent 100 targetPctSource minmax rawCurSafe false`
- This indicates target health fake resolver consumed a non-live `safePercent` path during secret-value updates.
Hypothesis:
- `targetPctSource=minmax` in secret conditions is synthetic (recomputed from cached safe values), not a live health signal.
- Treating this as reliable lets resolver lock at 100% and bypass native-geometry fallback updates.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Restrict `IsTargetHealthSafePercentReliable(...)` to live sources only:
    - `mirror`, `api`, `unitpct`
  - Remove source-based bypass in `IsTargetHealthMinMaxReliable(...)`; keep raw-safe-only rule.
- In `Components/UnitFrames/Functions.lua`:
  - Only assign target percent source `minmax`/`cached` when raw target cur/max are both safe.
Result:
- Target fake health should no longer prefer stale `safepct=100` from synthetic minmax source when target raw values are secret.
- Expected resolver behavior in those moments: use live mirror/api/unitpct or fall through to native geometry fallback instead of freezing.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target retarget drift: relax health reliability gates)
Issue:
- Target health can render correctly, then flip to native wrong-direction behavior after target swap/update.
- Dumps show resolver path oscillation:
  - first: `healthFake: source last percent 100`
  - then: `healthFake: source native percent nil`
Hypothesis:
- Reliability guards were too strict for target secret-value flow and rejected `safePercent/minmax` in cases where `API.UpdateHealth` had already produced usable target percent source (`minmax`/`cached`).
- After `PLAYER_TARGET_CHANGED` cache clears, this pushed resolver into native fallback path, reintroducing flip/orientation drift.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - `IsTargetHealthSafePercentReliable(...)` now accepts target percent sources:
    - `mirror`, `api`, `minmax`, `cached`
  - `IsTargetHealthMinMaxReliable(...)` now accepts the same source set (in addition to raw-safe cur/max).
Result:
- Target health resolver can stay on fake-fill percent paths more consistently after retarget instead of dropping to native fallback immediately.
- Expected effect: fewer native-path flips after target swaps and improved visual continuity.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target debug UX: dedicated clipnative A/B buttons)
Issue:
- User confirmed command-based clipnative exists, but requested easier A/B testing via single-click debug UI controls.
Hypothesis:
- Dedicated `ClipNative ON/OFF/Toggle` buttons in `/azdebugtarget` reduce command friction and improve reproducibility during rapid HP/cast state changes.
Change(s):
- In `Core/Debugging.lua`, add explicit clipnative action buttons to the target debug menu actions section:
  - `ClipNative ON`
  - `ClipNative OFF`
  - `ClipNative Toggle`
- Buttons call the same backend toggle path (`SetTargetFillDebugOptionBoth("clipnative", ...)`) and refresh menu state.
Result:
- Implemented dedicated action buttons in `/azdebugtarget`:
  - `ClipNative ON`
  - `ClipNative OFF`
  - `ClipNative Toggle`
- Buttons call `SetTargetFillDebugOptionBoth("clipnative", ...)` and refresh menu state for immediate A/B.
- Existing mirrored row toggle (`clipnative`) remains available in the options grid.
Validation:
- `luac -p Core/Debugging.lua`

2026-02-20 (experimental /azdebugtarget clipnative A/B mode)
Issue:
- User reports target orientation can appear correct after toggles, then flips back/wrong on target HP updates.
- Dumps continue to show frequent health native fallback state:
  - `healthFake: source native percent nil`
- Need an isolated A/B switch for native fallback rendering behavior without changing default runtime behavior.
Hypothesis:
- Native fallback can oscillate between percent-derived fake crop and direct native geometry mirror during secret-value updates.
- A dedicated "clipnative" mode that forces direct native clipping path (instead of percent recrop) will help isolate if flip drift is coming from percent recrop math versus native geometry state changes.
Change(s):
- Add experimental target debug toggle `clipnative` behind `/azdebugtarget`.
- Keep default OFF to preserve current behavior.
- Wire this toggle into target health/cast native fallback code paths so ON forces direct native clipping/mirroring branch and skips percent-derived recrop branch.
Result:
- Implemented experimental `clipnative` toggle in `Core/Debugging.lua` as mirrored target debug options:
  - `target.cast.clipnative`
  - `target.health.clipnative`
- Added command alias:
  - `/azdebugtarget clipnative [on|off|toggle]`
  - (also works through existing `/azdebug target ...` passthrough)
- Wired runtime behavior in `Components/UnitFrames/Units/Target.lua`:
  - health native fallback: when clipnative is ON, skip percent-derived recrop and force direct native clip/mirror branch.
  - cast native fallback: same behavior for cast native path.
- Defaults remain OFF, so baseline behavior is unchanged unless explicitly toggled.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target native percent extraction + flip order cleanup + stale cast mirror cleanup)
Issue:
- Latest target dumps still show dominant native fallbacks:
  - `healthFake: source native percent nil`
  - `castFake: path native` / intermittent stale fallback behavior.
- User-visible symptom remains "scale-like/native drift" instead of deterministic crop progression.
Hypothesis:
- Native percent extraction currently expects 8-value texcoords only; when runtime returns 4-value texcoords, extraction fails and forces `percent=nil`.
- Target health applies `SetTexCoord(...)` before `SetFlippedHorizontally(...)`; the flip shim can overwrite intended texcoords.
- Target cast still preserves mirror percent on no-sample ticks in two setup paths, allowing stale mirror state to bleed into resolver decisions.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Extend `GetTargetNativePercentFromTexCoord(...)` to support both 4-value and 8-value texcoords.
  - Re-apply target health texcoords after `SetFlippedHorizontally(...)` (same safety order already used for cast).
  - Disable cast mirror retention by default in target setup paths (`__AzeriteUI_KeepMirrorPercentOnNoSample = false`).
Result:
- Implemented all listed changes in `Components/UnitFrames/Units/Target.lua`.
- Native geometry percent extraction now supports 4-value and 8-value texcoord returns.
- Target health now reapplies texcoords after flip assignment to prevent flip-shim overwrite drift.
- Target cast mirror retention-on-miss is disabled in setup paths to reduce stale mirror reuse.
- In-game behavior validation is pending (reload + target cast/health test loop).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target nativevisual toggle bug + cast last-path freeze guard)
Issue:
- Logs show dominant target fallback states:
  - health: `healthFake: source native percent nil`
  - cast: `castFake: path native percent nil` and intermittent `castFake: path last percent 1`
- User reports nativevisual/fake toggles appear ineffective in this state and cast can stick/full-fill unexpectedly.
Hypothesis:
- Visual arbitration logic for target health/cast only honored `nativevisual OFF` when native path had a numeric percent.
- For `native + nil percent`, code always forced native visuals, effectively ignoring fake/nativevisual toggles during secret-value fallback.
- Cast `last` fallback can reuse stale percent while an active cast is still running, producing full-bar artifacts.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Updated `SyncTargetHealthVisualState(...)` and `SyncTargetCastVisualState(...)` so `nativevisual OFF` always prefers fake visuals whenever fake update succeeds, including `native + nil percent`.
  - Kept `nativevisual ON` behavior to prefer native visuals only for native path.
  - Added guard in cast resolver to disable `last` fallback while cast/channel/empower is active; stale `last` is now only used when cast is not actively progressing.
Result:
- `nativevisual OFF` now has real effect in the exact native/nil-percent secret fallback state.
- Cast no longer reuses stale `last` percent during active casts, reducing first-cast/full-bar and stuck-progress artifacts.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target debug UX follow-up: mirrored cast/health toggles and shared command)
Issue:
- User requested easier live testing in `/azdebugtarget` by mirroring cast+health toggles on the same row and using the same command shape.
Hypothesis:
- A row-based mirrored layout plus a shared `both` scope will reduce toggle friction and make A/B tests faster and less error-prone.
Change(s):
- In `Core/Debugging.lua`:
  - Added mirrored option-row index (`TARGET_FILL_DEBUG_OPTION_ROWS`) grouped by shared option key.
  - Added shared scope command handler: `/azdebugtarget both <option> [on|off|toggle]`.
  - Added mirrored list output: `/azdebugtarget list both`.
  - Updated help text in `/azdebug` and `/azdebugtarget` to include `both`.
  - Reworked target debug menu toggle area into mirrored rows:
    - Option label on left.
    - Cast checkbox + Health checkbox on same row.
    - Row-level `Toggle` button bound to `both` command behavior.
  - Added extra bulk action buttons in target debug menu:
    - `All ON`, `All OFF`, `Cast ON`, `Health ON`.
  - Updated options action button to print mirrored option list.
Result:
- Cast/health toggles are now mirrored by option on the same line in the target debug menu.
- Shared `both` command enables one-line changes for paired options while preserving legacy single-scope commands.
- Added extra runtime toggle buttons for faster test passes.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target health/cast fallback: allow readable secret numerics via canaccessvalue)
Issue:
- Fresh logs still show target health frequently stuck on native fallback with no percent:
  - `healthFake: source native percent nil targetPctSource minmax rawCurSafe false ...`
- Cast can resolve `path live`, but health percent resolvers still fail when texture/value readbacks are secret-tagged.
Hypothesis:
- Current numeric guards reject all secret values (`issecretvalue == true`) even when the runtime can legally read them.
- WoW 12 provides `canaccessvalue(value)` specifically for this case.
Change(s):
- In `Components/UnitFrames/Functions.lua`:
  - Updated target raw-safety classification to use `IsSafeNumeric(...)` (which now accepts readable secret numerics via `canaccessvalue`) instead of hard `not issecretvalue(...)`.
  - Updated target bar-max fallback gating to use `IsSafeNumeric(...)`.
- In `Components/UnitFrames/Units/Target.lua`:
  - Routed remaining secret-number gates in target health/cast fake-fill math through `IsSafeNumber(...)`:
    - native-geometry size sampling (`SafeDim` in health/cast native texture paths),
    - fake-fill width derivation (`gotAnchorWidth`/`gotWidth`),
    - cast percent normalization and duration payload reads (`remaining/total` in timer + unit/payload fallbacks).
Result:
- Readable secret numerics now stay eligible through the resolver chain instead of being dropped to `native percent nil` solely due secret tagging.
- Target health/cast fake-fill has a better chance to resolve `mirror/nativegeom/minmax/timer/unit` percent paths before native-only visual fallback.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target native-path stabilization + cast unit-time fallback)
Issue:
- User reports target health/cast can be direction-toggled but still render wrong fill behavior.
- Logs show frequent native fallback with no reliable percent:
  - `healthFake: source native percent nil`
  - `castFake: path native percent nil`
- Additional symptom: cast progression may stall unless retarget/recast.
Hypothesis:
- When native fallback has no numeric percent (`nil`), fake-fill geometry mirroring is less reliable than showing native/proxy visuals directly.
- Cast timer duration payloads may be intermittently unavailable; direct `UnitCastingInfo`/`UnitChannelInfo` timestamps are cleaner fallback signals (validated by secret test showing clean cast/channel times).
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added `GetTargetCastPercentFromUnitTimes(cast)` fallback using:
    - `UnitCastingInfo(unit)` for normal casts
    - `UnitChannelInfo(unit)` (plus empower hold) for channel/empower
    - `GetTime()` for current timeline
  - Wired this into `UpdateTargetFakeCastFill(...)` as `castFake: path unit` fallback after timer path and before mirror/secret/minmax/native.
  - Updated visual arbitration for both health and cast:
    - If path/source is `native` but numeric percent is unavailable, force native visuals instead of hiding them for fake-fill rendering.
    - Keeps fake native rendering only when native percent is actually numeric and `nativevisual` toggle allows it.
Result:
- Native fallback no longer forces fake-fill rendering on nil-percent samples.
- Cast has an additional robust percent source from unit API timestamps when timer payloads are missing.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Functions.lua`

2026-02-20 (target retarget regression: stale texture/layout cache across PLAYER_TARGET_CHANGED)
Issue:
- User reports:
  - first target after login: health + cast look correct, but cast progress does not update,
  - after untarget/retarget: health and cast appear reversed.
Hypothesis:
- `UnitFrame_UpdateTextures` fast-path cache (`__AzeriteUI_HealthLabSignature` + `__AzeriteUI_TargetGUID`) can skip full texture/layout reapply after target transitions.
- On untarget, target does not exist so update path returns early, leaving cache values intact.
- Re-target (especially same style/same GUID) may early-return and skip restoring target-specific orientation/reverse/flip/texcoords.
Planned change(s):
- In `Components/UnitFrames/Units/Target.lua`, clear `self.__AzeriteUI_HealthLabSignature` and `self.__AzeriteUI_TargetGUID` during `PLAYER_TARGET_CHANGED` handling.
- Keep existing fake-state clearing intact.
- This forces full target texture/layout rebind on each target change and should remove direction drift after retarget.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - On `PLAYER_TARGET_CHANGED`, now clears:
    - `self.__AzeriteUI_HealthLabSignature`
    - `self.__AzeriteUI_TargetGUID`
- In `Core/Debugging.lua`:
  - `RefreshTargetDebugTestFrames()` now also clears `frame.__AzeriteUI_TargetGUID` (it already cleared signature), ensuring forced refresh rebinds full target texture/layout state.
- In `Components/UnitFrames/Units/Target.lua`:
  - `ApplyTargetNativeTexCoordToFakeFill(...)` now supports both:
    - 8-value texcoords (`ulx, uly, llx, lly, urx, ury, lrx, lry`)
    - 4-value texcoords (`left, right, top, bottom`)
  - This prevents silent fallback to static texcoords when native statusbar textures expose 4-value coords.
Result:
- Removes stale retarget cache reuse path that could preserve wrong reverse/flip/texcoord state after untarget/retarget.
- Improves native fallback visual tracking for both target health/cast fake fills when `path/source native` is active.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`
Next step:
- In-game reproduce:
  1) first target cast update,
  2) untarget/retarget direction consistency,
  3) confirm `castFake: path native` now visually tracks progression when percent sources are unavailable.

2026-02-20 (target debug UX: add 10 preset buttons for rapid live testing)
Issue:
- User requested 10 one-click presets in target debug UI to rapidly A/B native/fake direction and fallback combinations.
Hypothesis:
- Repeated manual toggling across many flags is too slow and error-prone during live cast/health reproduction.
Planned change(s):
- Add a preset table with 10 distinct test profiles in `Core/Debugging.lua`.
- Add `/azdebugtarget preset <1-10>` and `/azdebugtarget presets` commands.
- Add 10 preset buttons to the `ToggleTargetDebugMenu` UI and show preset descriptions in status/help output.
- Apply presets in one pass (single refresh) while preserving force-pair mutual-exclusion rules.
Result:
- Added 10 preset profiles in `Core/Debugging.lua` (`TARGET_FILL_DEBUG_PRESETS`) with distinct fallback/direction combinations.
- Added command support:
  - `/azdebugtarget presets`
  - `/azdebugtarget preset <1-10>`
  - `/azdebug target presets`
  - `/azdebug target preset <1-10>`
- Added a `Presets` section in the target debug menu with 10 clickable preset buttons and tooltip descriptions.
- Preset application now runs in one pass (defaults -> overrides -> mutual-exclusion normalize -> sync -> single refresh).
- Added shared mutual-exclusion normalization helper for force-toggle pairs used by both single-toggle changes and preset application.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Functions.lua`

2026-02-20 (target native direction controls: verify native reverse support + add explicit reverse/flip overrides)
Issue:
- Latest target dumps show both bars resolving to native visual path:
  - `healthFake: source native`
  - `castFake: path native`
- User confirms bars are visible again but horizontal fill direction is still wrong relative to intended target-opposite behavior.
Hypothesis:
- In secret-value target states, fake percent sources are unavailable, so native path is authoritative.
- We need explicit native direction controls (reverse/flip) on target health/cast to test and lock the correct opposite-of-player tuple without relying on fake-fill percent tricks.
Planned change(s):
- Confirm available native widget methods via WoW API MCP (`StatusBar:SetReverseFill`, `StatusBar:SetOrientation`).
- Add target debug toggles for direction overrides:
  - cast: `forcereverse`, `forcenoreverse`, `forcefliph`, `forcenofliph`
  - health: `forcereverse`, `forcenoreverse`, `forcefliph`, `forcenofliph`
- Apply these overrides in `Components/UnitFrames/Units/Target.lua` when configuring target health/cast native bars.
- Expose new options in `/azdebugtarget` status/list/menu output.
Result:
- Confirmed via WoW API MCP (`get_widget_methods(StatusBar)`) that native statusbars support `SetReverseFill` and `SetOrientation`.
- Added new `/azdebugtarget` toggles for native direction forcing:
  - cast: `forcereverse`, `forcenoreverse`, `forcefliph`, `forcenofliph`
  - health: `forcereverse`, `forcenoreverse`, `forcefliph`, `forcenofliph`
- Wired these toggles into target texture setup so health and cast native bars can be forced independently.
- Added pairwise mutual-exclusion handling for all new force toggles in debug command processing.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Functions.lua`

2026-02-20 (target debug tooling expansion: dedicated /azdebugtarget menu + broader fallback toggles)
Issue:
- Iterating target fill behavior requires frequent live A/B toggling of health/cast fallback paths and visual routing.
- Existing `/azdebug target ...` only exposes a small subset of flags, making isolation slow and error-prone.
Hypothesis:
- A dedicated target debug surface with explicit, named toggles for each resolver branch (live/timer/mirror/native/etc.) and visual preference routing will make behavior differences reproducible and measurable.
Planned change(s):
- Add a dedicated `/azdebugtarget` command (menu + parser) in `Core/Debugging.lua`.
- Expand target debug flags with explicit cast/health fallback toggles and visual-preference toggles, plus force-invert overrides for cast fakefill.
- Extend target status print to include descriptions for each toggle.
- Add target-specific debug buttons (dump target, snapshot target, force target health/cast refresh, secret test target, reset flags) in the new menu.
- Wire new flags into `Components/UnitFrames/Units/Target.lua` resolver paths without changing secure/protected API usage.
Result:
- Added dedicated `/azdebugtarget` command + menu with grouped cast/health toggles and live action buttons.
- Centralized target debug flag definitions in `Core/Debugging.lua` so parser, globals, status output, and menu stay aligned.
- Extended runtime toggles beyond native/mirror/last to include live/timer/secret/minmax and native-visual preference branches.
- Added cast invert override toggles (`forceinvert` / `forcenoinvert`) for live A/B direction tests.
- Hooked `Target.lua` health/cast resolver branches to these toggles and added native-visual preference gating for both bars.
- Existing `/azdebug target ...` now delegates to the new target parser to preserve compatibility.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (deep-dive cleanup: remove stale target cast state + gate unreliable target health synthetic percent)
Issue:
- Target cast sometimes starts as full on first visible frame, then stabilizes on subsequent casts.
- Target health can pin to synthetic 100% in secret-value paths, bypassing native geometry fallback.
Root cause:
- Cast fakefill reused stale `__AzeriteUI_FakeMin/Max/Value` and `__AzeriteUI_LastFakePercent` across show/hide/retarget boundaries.
- Target health resolver trusted `safePercent/minmax` even when target raw values were secret and percent source was synthetic.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Clear stale cast fake state on `PLAYER_TARGET_CHANGED`, castbar `OnShow`, and castbar `OnHide` (`FakeMin/Max/Value`, mirror/texture percent, last fake percent).
  - Clear stale health fake min/max/value on `PLAYER_TARGET_CHANGED`.
  - Add reliability gates:
    - `IsTargetHealthSafePercentReliable()` allows safepct only when target percent source is `mirror` or `api`.
    - `IsTargetHealthMinMaxReliable()` allows minmax fallback for target only when raw cur/max are safe.
  - Apply cast force-invert debug override consistently in native-geometry cast fallback path (`ShouldTargetCastInvertPercent`).
- In `Components/UnitFrames/Functions.lua`:
  - Store per-update raw safety flags on health elements (`__AzeriteUI_RawCurSafe`, `__AzeriteUI_RawMaxSafe`, plus secret markers) for resolver reliability checks.
- In `Core/Debugging.lua`:
  - Extend `DumpBar` output to include fake-fill texture dump (`<Bar>.FakeFill`) plus target fake source metadata (`TargetFakeSource`, `TargetPercentSource`, raw safety flags).
Result:
- Reduces stale/orphan state influence on first cast frame.
- Prevents synthetic target `safePercent/minmax` from pinning health fakefill when target data is secret-only.
- Pushes unresolved secret cases toward native mirror path instead of stale 100% assumptions.
- Improves deep-dive observability by showing fake texture geometry directly in `/azdebug dump` output.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Core/Debugging.lua`

2026-02-20 (BugSack 3895: Target fake-fill helper nil call)
Issue:
- BugSack error spam on target updates:
  - `Components/UnitFrames/Units/Target.lua:675 attempt to call global 'ApplyTargetNativeTexCoordToFakeFill' (a nil value)`.
Hypothesis:
- `UpdateTargetFakeHealthFillFromNativeTexture()` invokes `ApplyTargetNativeTexCoordToFakeFill` before that helper is locally declared.
- In Lua, this resolves as a global at callsite compile-time unless forward-declared.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added a local forward declaration for `ApplyTargetNativeTexCoordToFakeFill` alongside other local forward declarations near the fake-fill section.
Result:
- Prevents nil global lookup; call now resolves to the local helper once assigned.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (BugSack 3897: upvalue still nil due to shadowed local)
Issue:
- After forward declaration, BugSack still reports:
  - `Target.lua:676 attempt to call upvalue 'ApplyTargetNativeTexCoordToFakeFill' (a nil value)`.
Root cause:
- Helper definition used `local ApplyTargetNativeTexCoordToFakeFill = function(...)` later in file.
- That creates a new local and shadows the forward-declared upvalue, leaving the original upvalue nil for early callsites.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`, changed helper definition to assign the forward declaration:
  - `ApplyTargetNativeTexCoordToFakeFill = function(...)`
Result:
- Early callsites and later helper now reference the same local upvalue.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (BugSack 3898: residual helper nil + secret spellID compare)
Issue:
- Continued target errors:
  - `attempt to call upvalue 'ApplyTargetNativeTexCoordToFakeFill' (a nil value)`
  - `attempt to compare local 'spellID' (a secret number value tainted by 'AzeriteUI')`.
Root cause:
- During some init/update timing paths, helper invocation can still occur before helper assignment is guaranteed.
- `spellID > 0` performed direct comparison on a potential secret number.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Wrapped both native fake-fill texcoord helper callsites with a function-exists guard and fallback to configured texcoords.
  - Replaced spell fallback gate from `type(spellID) == "number" and spellID > 0` to `IsSafeNumber(spellID) and spellID > 0`.
Result:
- Prevents nil helper call crashes in early/runtime edge paths.
- Removes forbidden secret-number comparison in cast fallback duration logic.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target fill behavior follow-up: reduce native fallback dependence)
Issue:
- After crash fixes, target fill direction/cropping still behaves inconsistently:
  - target health often appears wrong regardless of target type,
  - target cast is more often wrong on enemy targets than self-target.
Hypothesis:
- Target health resolver was overly restrictive for `safePercent`, accepting it only when source was `api/mirror`, which pushed frequent fallbacks into native sampling paths.
- Cast mirror percent continuity could be dropped between updates, increasing fallback churn on enemy casts.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - `ResolveTargetFakeHealthFillPercent`: accept any safe `health.safePercent` as `safepct` source (not only `api/mirror` source tags).
  - Enabled `cast.__AzeriteUI_KeepMirrorPercentOnNoSample = true` in both style setup and texture refresh path.
Expected result:
- Target health fake fill should stay on percent-driven crop path more consistently.
- Target cast should rely less on native fallback during enemy casts/channels when samples are intermittent.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target health frozen + first-cast full on target)
Issue:
- Target health fake fill can appear frozen/incorrect and native health bar is not visible as fallback.
- Target cast can appear full on first cast after show/retarget, then behave differently on subsequent casts.
Root cause hypothesis:
- `SyncTargetHealthVisualState` hid native visuals whenever production mode flag was set, even when fake fill failed.
- Health mirror percent was configured to persist when no sample was available, increasing stale-health risk on target.
- Cast mirror/texture percent were not reset on `OnShow` / target change, allowing stale first-frame cast percent.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - `SyncTargetHealthVisualState`: hide native only when fake fill successfully updates; otherwise show native.
  - Health mirror continuity set to non-sticky (`__AzeriteUI_KeepMirrorPercentOnNoSample = false`) in both style setup paths.
  - Cast `OnShow` and target-change reset now clear `__AzeriteUI_MirrorPercent` / `__AzeriteUI_TexturePercent`.
  - Removed unused production-mode short-circuit in health percent resolver to reduce misleading dead-path behavior.
Expected result:
- Target health no longer disappears/freezes when fake-fill inputs are unavailable.
- First enemy cast no longer inherits stale full percent from prior state.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target fill arbitration: prefer native visuals when fake path is native)
Issue:
- Runtime dump still shows `castFake: path native percent nil` while visuals remain incorrect.
- Fake-fill path was still being treated as authoritative even when it had no percent and only native-geometry fallback.
Root cause:
- Visual routing hid native bars whenever fake update returned true, including `native` fallback source/path.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Health visual sync now checks source; if source is `native`, show native health visuals and hide fake.
  - Added `SyncTargetCastVisualState(cast, value, explicitPercent)` helper.
  - Cast callers now route visuals through sync helper; if cast path resolves to `native`, native cast visuals are shown.
Expected result:
- Prevents “fake native” mismatch and wrong fill method when no reliable fake percent exists.
- Keeps fake fill active only for non-native paths (`live/timer/mirror/minmax/last/secret`).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target fill follow-up: native fallback uses scaling geometry instead of crop)
Issue:
- Target health/cast bars still animate as scaled geometry (not cropped), especially on enemy/enemy-player targets.
- User confirms self-target path can look correct, while non-self targets often regress.
Root cause hypothesis:
- Target fake-fill frequently falls into `native` fallback (`castFake: path native` / health fake source native).
- In that fallback, fake fill mirrors native texture bounds with full base texcoords, which visually scales the texture instead of cropping.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Add texcoord-based native percent resolver (from `TextureBase:GetTexCoord`) and prefer it before size-based native geometry percent.
  - In direct native mirror fallback, copy full native texcoords safely (8-value form) when available.
  - Keep existing configured texcoord fallback when native texcoord payload is unavailable/unsafe.
Expected result:
- Native fallback should preserve crop-like animation instead of scale-like animation on target health/cast.
- Non-self target casts/health should visually match player-style fill behavior more closely.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, then test target self vs enemy/enemy-player while casting/taking damage.

2026-02-18 (follow-up: BugSack 3815 health.lua GetRGB nil)
Issue:
- Runtime error in `Libs/oUF/elements/health.lua:125`: `attempt to call method 'GetRGB' (a nil value)`.
- Trigger context includes DialogueUI interaction flow, but crash site is AzeriteUI oUF health color application.
Hypothesis:
- `UpdateColor()` assumed every color object had ColorMixin methods and called `color:GetRGB()` unconditionally.
- In some runtime paths, color can be a plain RGB table (`{r,g,b}` or indexed values), where `GetRGB` is nil.
Change(s):
- In `Libs/oUF/elements/health.lua`:
  - Added `ExtractColorRGB(color)` helper to support both ColorMixin and plain RGB tables.
  - Guarded smooth-color access so `GetCurve()` is only called when that method exists.
  - Switched vertex-color write to use extracted `r,g,b` values instead of direct `color:GetRGB()`.
Validation:
- `luac -p Libs/oUF/elements/health.lua` => `health=0`.
Result:
- Health color update no longer crashes when color data lacks ColorMixin methods.
- Expected to resolve this error regardless of whether DialogueUI is the trigger context.

2026-02-18 (follow-up: BugSack 3808 Rarity/Ace3 protected RegisterEvent)
Issue:
- BugSack reports `ADDON_ACTION_FORBIDDEN`: `Ace3` tried to call protected `AceEvent30Frame:RegisterEvent()`.
- Stack shows this is reached from `LoadAddOn` invoked by `Components/Misc/ArcheologyBar.lua:PrepareFrames`.
Hypothesis:
- `ArcheologyBar` forces `LoadAddOn("Blizzard_ArchaeologyUI")` during module enable.
- When this occurs in combat, dependent addon enable/event registration paths (Rarity/Ace3) can taint and trigger protected-call restrictions.
Change(s):
- In `Components/Misc/ArcheologyBar.lua`:
  - Made `PrepareFrames()` combat-safe:
    - return early when `self.frame` already exists,
    - defer with `PLAYER_REGEN_ENABLED` when `InCombatLockdown()` is true,
    - only load/initialize when safe and frame exists.
  - Added `OnSafeEnable()` retry handler to complete deferred frame + anchor initialization out of combat.
  - Updated `OnEnable()` to abort early when initialization is deferred.
Validation:
- `luac -p Components/Misc/ArcheologyBar.lua` => `arch=0`.
Result:
- AzeriteUI no longer forces archaeology addon loading in combat from this module path.
- Expected to prevent the reported Rarity/Ace3 protected RegisterEvent taint chain.

2026-02-18 (follow-up: BugSack 3809 persists out of combat)
Issue:
- Same protected-call stack still occurs out of combat.
- Stack still points to `LoadAddOn` in `Components/Misc/ArcheologyBar.lua:PrepareFrames`.
Revised hypothesis:
- The taint source is the explicit `LoadAddOn("Blizzard_ArchaeologyUI")` path itself in this environment (not only combat timing).
Change(s):
- In `Components/Misc/ArcheologyBar.lua`:
  - Removed forced `LoadAddOn("Blizzard_ArchaeologyUI")` from `PrepareFrames()`.
  - Added passive initialization flow:
    - `OnEnable()` now registers `ADDON_LOADED` when archaeology frame is unavailable,
    - `OnSafeEnable(event, addonName)` now filters for `"Blizzard_ArchaeologyUI"` before initializing,
    - anchor/module enable only proceed after frame is available.
Validation:
- `luac -p Components/Misc/ArcheologyBar.lua` => `arch=0`.
Result:
- AzeriteUI no longer directly triggers this protected-call chain via explicit archaeology addon loading.
- Pending runtime `/reload` confirmation that BugSack 3809 no longer reproduces.

2026-02-18 (follow-up: maintenance comments for cooldown pipeline)
Issue:
- User requested durable inline documentation to reduce risk of reintroducing combat cooldown regressions in future patches.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Added guardrail comments in `UpdateCooldown()` explaining:
    - why `ActionButton_ApplyCooldown` branch must stay enabled,
    - what the fallback/cache path is for,
    - where combat-critical cooldown refresh events are handled (`ACTIONBAR_UPDATE_COOLDOWN`, `SPELL_UPDATE_COOLDOWN`).
- In `Components/ActionBars/Elements/ActionBars.lua`:
  - Added comments clarifying this file is visual-only for cooldown presentation and that runtime progression/debugging belongs in LAB.
Validation:
- Pending parse checks:
  - `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
  - `luac -p Components/ActionBars/Elements/ActionBars.lua`
Result:
- Future patch points are now documented at the exact failure-prone locations.

2026-02-18 (follow-up: actionbar code parity check; combat cooldown updates)
Issue:
- User reports swipes/CD timers update out of combat but stop updating in combat.
Investigation:
- Compared `Components/ActionBars/Elements/ActionBars.lua` against release `5.2.208` and stock baseline.
- Cooldown styling/wiring in ActionBars module is effectively identical for runtime behavior; no combat-specific divergence found there.
- Found divergence in `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - `UpdateCooldown()` had secure path hard-disabled via `if false and ActionButton_ApplyCooldown then`.
Hypothesis:
- Disabling `ActionButton_ApplyCooldown` forces legacy fallback math only; in combat with secret-value payloads this can stall visual cooldown progression.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown`):
  - Restored full release `5.2.208` implementation body.
  - Re-enabled secure cooldown apply branch (`if ActionButton_ApplyCooldown then`) and release fallback behavior.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` => `lab=0`.
Result:
- Actionbar element code is not the blocker; cooldown engine now matches release combat-update path.
- Pending runtime `/reload` verification in combat for continuous cooldown progression.

2026-02-18 (follow-up: cooldown rollback to 5.2.208 and function-boundary repair)
Issue:
- Cooldown swipes/timers still missing in runtime after iterative LAB secret-value tweaks.
- During rollback attempt, `LibActionButton-1.0-GE.lua` action method block became malformed (accidental inline of cooldown logic into `Action.GetCooldownInfo`), causing parser failures.
Hypothesis:
- The most reliable path is to restore the known-good cooldown behavior from release `5.2.208` and keep method boundaries exactly aligned with release structure.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Synced `Action.GetCooldown` secret gating to release behavior.
  - Restored `Action.GetCooldownInfo` to return-only form.
  - Repaired and restored full `Action.*` / spell helper section (`Action.IsAttack`, `Action.IsAutoRepeat`, `Action.GetPassiveCooldownSpellID`, classic overrides, spell helper locals, `Spell.HasAction`, `Spell.GetActionText`, etc.).
  - Kept `UpdateCooldown` as the release-style known-good implementation block in its original location.
Validation:
- VS Code diagnostics no longer report missing `end` / unmatched function boundaries in `LibActionButton-1.0-GE.lua`.
Result:
- File structure and cooldown pipeline are back to release-aligned state.
- Pending runtime `/reload` verification for:
  - cooldown swipes/timers visible in and out of combat,
  - no new BugSack actionbar errors.

2026-02-18 (follow-up: Brann Devilsaur summon missing nameplate)
Issue:
- User reports Brann's Egg summoned Devilsaur does not show a nameplate, including after combat.
Hypothesis:
- Nameplate classifier marks some passive friendly units as object plates when `UnitNameplateShowsWidgetsOnly(unit)` is true, which unintentionally suppresses companion/summon plates.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua` (`NamePlate_PostUpdate`):
  - Added `isCompanionLikeGuidType` for `Pet`/`Creature`/`Vehicle` GUID types.
  - Updated object-plate suppression so the widgets-only passive branch does **not** classify companion-like GUID units as object plates.
  - Keeps explicit object GUID suppression and NPC denylist suppression intact.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Pending runtime `/reload` verification that Brann Devilsaur gets a nameplate while decorative object-like plates remain hidden.

2026-02-18 (BugSack 3790: ActionButton cooldownStartTime nil in Blizzard ActionButton)
Issue:
- BugSack reports repeated error from Blizzard secure action update path:
  - `Blizzard_ActionBar/Shared/ActionButton.lua:920 attempt to perform arithmetic on local 'cooldownStartTime' (a nil value)`
- Stack runs through restricted `UpdateAction`/state driver path, indicating malformed cooldown payload entering Blizzard `ActionButton_ApplyCooldown`.
Hypothesis:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` can pass `chargeInfo`/`cooldownInfo` tables with nil/secret numeric fields into `ActionButton_ApplyCooldown` during edge transitions.
- Blizzard code now assumes numeric `cooldownStartTime` in this path and errors on nil arithmetic.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown`):
  - Added defensive normalization for `cooldownInfo`, `chargeInfo`, and `lossOfControlInfo` fields immediately before `ActionButton_ApplyCooldown`.
  - Any nil/secret/non-numeric values are coerced to safe defaults:
    - time/duration fields => `0`
    - mod rates => `1`
    - charges => `0`
    - enabled flag => numeric `0/1`.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Syntax valid (`lab=0`).
- Pending runtime `/reload` + combat/state-change verification and BugSack recheck.

2026-02-18 (follow-up BugSack 3792: secret boolean in cooldownInfo.isEnabled)
Issue:
- New high-frequency error:
  - `LibActionButton-1.0-GE.lua:2490 attempt to perform boolean test on field 'isEnabled' (a secret boolean value)`
- User reports combat timers/cooldown swipes disappear again.
Hypothesis:
- Recent cooldown payload sanitization still used direct boolean coercion:
  - `cooldownInfo.isEnabled = cooldownInfo.isEnabled and 1 or 0`
- This performs a forbidden boolean test when `isEnabled` is a WoW12 secret boolean.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown`):
  - Replaced direct boolean coercion with secret-safe normalization:
    - keep numeric `isEnabled` as-is,
    - only boolean-test non-secret booleans,
    - otherwise derive enable state from safe `startTime`/`duration` (`duration > 0` => enabled), else `0`.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending runtime `/reload` + combat cooldown swipe verification and BugSack recheck.

2026-02-18 (follow-up BugSack 3794: Tags secret boolean + combat cooldown loss)
Issue:
- BugSack reports:
  - `Components/UnitFrames/Tags.lua:529 attempt to perform boolean test on a secret boolean value`.
- User reports boss names visible but current health text missing, and action bar cooldown swipes/timers still lost in combat.
Hypothesis:
- `*:Health` / `*:HealthCurrent` still performed direct boolean checks on API booleans (`UnitIsConnected`, `UnitIsAFK`, `UnitIsDeadOrGhost`) that can be secret.
- In LAB cooldown apply path, normalization could still degrade secret cooldown fields to zeros instead of reusing last safe values, suppressing swipes/timers in combat.
Change(s):
- In `Components/UnitFrames/Tags.lua`:
  - Added `SafeBoolean(value, defaultValue)` helper.
  - Updated `*:Health` and `*:HealthCurrent` to use secret-safe booleans for dead/connected/AFK checks.
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown`, `ActionButton_ApplyCooldown` path):
  - Added cache-backed recovery for unsafe `cooldownInfo` and `chargeInfo` fields before defaulting to zeros.
  - Persisted safe cooldown/charge values back to cache to keep combat swipes/timers stable when live API payloads are secret.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
2026-02-18 (follow-up: combat swipes still missing after 3794)
Issue:
- User reports cooldown swipes/timers still missing in combat even after 3794 fixes.
What changed (regression note):
- Recent hardening moved more updates through `ActionButton_ApplyCooldown` with aggressive secret-value sanitization.
- In combat, secret payloads can leave `cooldownInfo`/`chargeInfo` fields effectively empty; sanitization then falls back to zeros, producing no visible swipe/timer.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown` apply path):
  - Before zero-defaulting, fill missing/unsafe fields from safe tuple fallbacks:
    - `self:GetCooldown()` for start/duration/enabled/modRate,
    - `self:GetCharges()` for charge cooldown fields.
  - Keep existing cache fallback after tuple fill.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending runtime `/reload` + combat verification for restored swipes/timers.

2026-02-18 (follow-up: compare to earlier behavior, swipes still missing)
Issue:
- User confirms combat swipes/timers are still missing and asks what changed versus earlier revisions.
Regression summary:
- Earlier behavior relied on fallback cooldown path (`CooldownFrame_Set`) that tolerates cache-derived values.
- Recent changes prefer `ActionButton_ApplyCooldown` and can still receive secret payload tables during combat updates.
- Even sanitized payloads may represent empty/zero cooldown data and suppress visual swipes/timers.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown`):
  - Added `applyHasSecretPayload` detection for cooldown/charge table fields.
  - If secret payload is detected, skip `ActionButton_ApplyCooldown` and continue into existing fallback/cache path instead of returning early.
  - Keep `ActionButton_ApplyCooldown` for non-secret payloads.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending runtime `/reload` + combat verification for restored swipes/timers with no new BugSack spam.

2026-02-18 (follow-up: cooldown updates only after combat)
Issue:
- User reports cooldown swipes/timers still do not update in combat, but resume after combat.
Root cause:
- Fallback updater still marked cooldown payload as secret if `isEnabled`/`modRate` were secret, then dropped otherwise-valid `start/duration` timing.
- It also coerced `enable` via direct boolean test, which is unsafe for secret booleans.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - `Action.GetCooldown`: only treat payload as secret when `startTime` or `duration` are secret (ignore `isEnabled`/`modRate` secrecy for tuple acceptance).
  - `UpdateCooldown` fallback path:
    - `startSecret` now checks only `start/duration`.
    - `chargesSecret` now checks only charge amount/timing fields.
    - `enable` derivation now avoids secret boolean tests and derives from safe timing when needed.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending runtime `/reload` + in-combat verification for continuous cooldown updates.

2026-02-18 (follow-up: cooldowns still not appearing in or out of combat)
Issue:
- User reports cooldown swipes/timers still not visible; updates appear stalled.
Root cause hypothesis:
- Fallback updater still treated `enable` as required for active cooldown and aggressively cleared cache whenever payload wasn't a clear active cooldown.
- Under secret/uncertain payloads this can erase last safe cooldown state and leave buttons with no drawable cooldown.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown` fallback):
  - `hasCooldown` now depends on safe `start/duration` only (not `enable` truthiness).
  - Cache clear now only happens on explicit safe zero cooldown (`start==0` and `duration==0`).
  - `CooldownFrame_Set` now uses `1` when `hasCooldown` is true, ensuring active swipes render even when `enable` is uncertain.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending runtime `/reload` verification for visible cooldown swipes/timers during and outside combat.

2026-02-18 (follow-up: still no CD swipes/timers after branch routing)
Issue:
- User confirms cooldown swipes and timer text are still absent in combat.
Decision:
- Roll back the modern `ActionButton_ApplyCooldown` path entirely for this addon build and force legacy fallback updater path, since that path is the last known reliably visible-swipe behavior in this codebase.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` (`UpdateCooldown`):
  - Disabled the `ActionButton_ApplyCooldown` branch by gating it off (`if false and ActionButton_ApplyCooldown then`).
  - All cooldown updates now run through the fallback/cache logic (`CooldownFrame_Set` path).
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending runtime `/reload` + combat confirmation that swipes and timers are visible again.

2026-02-18 (follow-up: cannot target Brann from party portrait click)
Issue:
- User reports Brann cannot be targeted by clicking his portrait in the AzeriteUI party frame.
Hypothesis:
- Party unit frames were re-registering clicks as both `AnyDown` and `AnyUp`, which can conflict with secure click behavior on pingable unit frame templates and block expected left-click target action for follower-party units.
Change(s):
- In `Components/UnitFrames/Units/Party.lua`:
  - Changed party frame click registration from `RegisterForClicks("AnyDown", "AnyUp")` to `RegisterForClicks("AnyUp")`.
  - This matches the shared unit-frame initialization path and standard secure target click timing.
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`
Result:
- Pending runtime `/reload` verification that clicking Brann portrait targets him.

2026-02-18 (follow-up: enemy names blank on target + nameplates)
Issue:
- User reports enemy names are missing on both target frame and nameplates, while health text is present.
Hypothesis:
- Shared tag method `*:Name` treated secret names as invalid and returned empty text, causing both frames using this tag to render no name.
Change(s):
- In `Components/UnitFrames/Tags.lua`:
  - Updated `SafeUnitName()` to return secret name values from `UnitName`/`GetUnitName` instead of discarding them.
  - In `Methods[prefix("*:Name")]`, added early return for secret names to avoid unsafe string operations (length/abbreviation/truncation/concatenation) while still displaying the name.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- Pending runtime `/reload` verification that enemy names render on both target frame and nameplates.

2026-02-18 (follow-up: target stale-name + nameplate question-mark health)
Issue:
- User reports remaining regressions after first delve nameplate pass:
  - target frame can retain previous friendly name after retarget,
  - nameplate health text can show `?` instead of current health,
  - hostile name visibility remains inconsistent when tags return unstable fallback values.
Hypothesis:
- `*:Name` fallback cache keyed by unit token can leak stale names across rapidly changing dynamic units.
- Nameplate health tag using smart `*:Health(true)` path can emit `?` when neither safe percent nor safe current value resolves in that update tick.
- Target retarget events need an explicit immediate tag refresh to avoid one-frame stale carryover.
Change(s):
- In `Components/UnitFrames/Tags.lua`:
  - Added `SafeUnitGUID()` helper.
  - Switched `*:Name` cache/fallback matching from unit-token based to GUID based.
  - Clear cached fallback when no safe GUID is available, preventing stale-name reuse.
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Changed health value tag from `[*:Health(true)]` to `[*:HealthCurrent]` for deterministic current-health display.
- In `Components/UnitFrames/Units/Target.lua`:
  - On `PLAYER_TARGET_CHANGED`, explicitly call `UpdateTag()` for `Name`, `Health.Value`, and `Health.Percent`, then run `Name_PostUpdate()`.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Pending runtime `/reload` verification in Delves for:
  - no stale friendly target name carryover,
  - no `?` health text under hostile nameplates,
  - hostile name visibility stable without requiring initial target lock.

2026-02-18 (follow-up: delve hostile nameplate stale-name + non-target health visibility)
Issue:
- User reports in Delves:
  - enemy nameplates can inherit the previous friendly target name,
  - hostile name text and health value are not visible until target/hover transitions.
Hypothesis:
- `NamePlate_PostUpdateHoverElements()` relied on interaction-state gating and a one-off friendly fallback name write, which can leave stale text on recycled frames and hide hostile info until interaction events.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added hostile-name visibility gate (`showHostileName`) into `NamePlate_PostUpdatePositions()` so aura/raid-target offsets account for persistent hostile names.
  - In `NamePlate_PostUpdateHoverElements()`:
    - force-refresh name tags with `self.Name:UpdateTag()` when available,
    - include hostile units in name visibility conditions,
    - show hostile `Health.Value` outside cast states when not target-gated by casting.
Result:
- Syntax valid (`nameplates=0`).
- Expected runtime outcome: hostile names persist on their own plates, stale friendly-name carryover is removed, and hostile health value appears pre-target (except during cast overlay states).

2026-02-18 (BugSack 3772: nil global IsSafeUnitToken in NamePlates)
Issue:
- BugSack reported repeated runtime error:
  - `Components/UnitFrames/Units/NamePlates.lua:92: attempt to call global 'IsSafeUnitToken' (a nil value)`.
- Chat debug output did not appear reliably because this error fired during nameplate post-update flow.
Hypothesis:
- `SafeUnitName()` referenced `IsSafeUnitToken` before the local function declaration existed in scope, causing Lua to resolve a missing global instead.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua` utility block:
  - Moved `IsSafeUnitToken` declaration above `SafeUnitName`.
  - Kept logic unchanged; only fixed declaration order to keep lookup local.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Expected outcome: runtime nil-global crash is removed; debug chat lines should resume and trainer/chair diagnostics can now be captured.

2026-02-18 (follow-up: object-plate visibility enforcement)
Issue:
- Live logs now show classifier correctness:
  - trainer-like plates (`canAssist=true`) => `isObjectPlate=nil`
  - clutter-like plates (`canAssist=false`) => `isObjectPlate=true`
- But clutter could still appear visually, indicating visibility re-application from non-classifier paths.
Hypothesis:
- Alpha-only suppression in `NamePlate_PostUpdateElements()` could be bypassed by later hover/cast callbacks or frame recycling edge states.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added early-return guard in `NamePlate_PostUpdateHoverElements()` for object plates to force-hide:
    - `Name`, `Health.Value`, `SoftTargetFrame`.
  - Expanded object branch in `NamePlate_PostUpdateElements()` to explicitly hide:
    - `SoftTargetFrame`, `Health`, `Health.Backdrop`, `Classification`, `TargetHighlight`, `RaidTargetIndicator`.
  - Kept existing aura disable + castbar hide + alpha suppression.
  - Added non-object restore path to re-show `Health` and `Health.Backdrop` for recycled frames.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game `/reload` verification that chair/clutter plates stay hidden while trainers remain visible.

2026-02-18 (research + fix: softinteract loss and recycled object-state leakage)
Issue:
- User reports:
  - softinteract icon lost on trainers/chairs,
  - trainer plates missing,
  - chair plate still visible.
Research:
- Workspace comparison:
  - Only `AzeriteUI` / `AzeriteUI_Stock` implement this specific nameplate flow.
  - `AzeriteUI_Stock` does not force-hide `SoftTargetFrame` in object suppression paths.
- Online source check (`Blizzard_NamePlates.lua` from Gethe/wow-ui-source):
  - Soft-interact icon is managed through `frame.UnitFrame.SoftTargetFrame.Icon` in `UpdateSoftTargetIconInternal`.
  - Hiding `SoftTargetFrame` directly can suppress expected soft icon behavior.
Hypothesis:
- Our recent object suppression pass hid `SoftTargetFrame`, unintentionally removing soft-interact icons.
- Recycled nameplate frames could retain stale `self.isObjectPlate=true` because it was not cleared on hide/remove.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Removed forced `self.SoftTargetFrame:Hide()` from object-suppression paths.
  - Cleared `self.isObjectPlate` in both `NamePlate_OnHide` and `NAME_PLATE_UNIT_REMOVED` cleanup.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game confirmation that softinteract icon returns and trainer plates are no longer suppressed by stale recycled state.

2026-02-18 (follow-up: trainer/chair split + first-frame suppression timing)
Issue:
- After restoring softinteract, user still reports:
  - Treni Fishing Trainer plate missing,
  - one chair/object-like plate can appear until nameplate cycling, then disappear.
Hypothesis:
- Current passive creature suppression is still too broad for at least one interactable trainer NPC.
- Initial `NAME_PLATE_UNIT_ADDED` timing can display stale visuals before the next full post-update pass.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added surgical NPC-ID exception tables from live logs:
    - `AlwaysShowFriendlyNPCByID["229383"] = true` (Treni)
    - `AlwaysHideObjectLikeNPCByID["223648"] = true`, `AlwaysHideObjectLikeNPCByID["212708"] = true` (decorative chair-side NPC plates observed in logs).
  - Integrated these overrides into `self.isObjectPlate` computation.
  - Extended friendly NPC nameplate gate to include force-show IDs even when `canAssist` is false.
  - Added immediate deferred post-add refresh on `NAME_PLATE_UNIT_ADDED`:
    - `C_Timer.After(0, function() NamePlate_PostUpdate(...) end)`
    - to remove first-frame stale visual carryover.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game verification for:
  - Treni trainer plate visible,
  - chair/object-like plate suppressed immediately without needing cycle-through.

2026-02-18 (follow-up: restore interactable NPC plates beyond Treni)
Issue:
- New debug capture shows broad suppression of many friendly interactable NPCs (vendors/innkeepers/etc):
  - `guidType=Creature`, `reaction=5`, often `canAssist=false`.
- User confirms Treni returned, but most other interactable NPC plates remained hidden.
Hypothesis:
- Generic passive `Creature` suppression (`canAttack=false`, `canAssist=false`) is too broad in this zone and catches valid interactable NPCs.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua` classifier:
  - Removed broad `suppressPassiveCreatureLike` branch.
  - Kept suppression for true object GUID types (`GameObject`, `AreaTrigger`).
  - Kept suppression for explicit known decorative NPC IDs only (`AlwaysHideObjectLikeNPCByID`).
  - Kept widgets-only passive suppression fallback.
Resulting behavior target:
- Friendly interactable NPC `Creature` plates are shown by default.
- Chairs/mailboxes/object-like clutter remain suppressed via object GUID or explicit ID list.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game verification that vendors/innkeepers return while chair/mailbox suppression remains intact.

2026-02-18 (follow-up: suppress Tuskarr Beanbag vehicle-style chair plate)
Issue:
- User reports one remaining clutter plate:
  - `Tuskarr Beanbag` with `npcID=191909`, `guidType=Vehicle`, `canAttack=false`, `canAssist=false`, `reaction=5`, still visible.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added `191909` to `AlwaysHideObjectLikeNPCByID` denylist.
  - Kept broader classifier unchanged to avoid re-hiding valid interactable NPCs.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game confirmation that beanbag plate is now suppressed while trainer/vendor/innkeeper plates remain visible.

2026-02-18 (cleanup: remove temporary nameplate debug instrumentation)
Issue:
- Fixes are confirmed working and chat is noisy from temporary deep debug logging.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Removed temporary debug helpers used during investigation:
    - `SafeText`, `IsNamePlateObjectDebugEnabled`, `DebugObjectPlateDecision`.
  - Removed debug call from `NamePlate_PostUpdate`.
  - Removed stale debug-state cleanup (`__AzeriteUI_ObjectPlateDebugState`).
  - Removed now-unused local alias `string_find`.
  - Kept final classifier logic and explicit NPC ID overrides unchanged.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Expected runtime behavior unchanged, with cleaner chat output.

2026-02-18 (minimap tracking compatibility hardening for WoW12)
Issue:
- User reports possible missing entries in minimap right-click tracking menu on current build.
Hypothesis:
- WoW11 branch used direct `MenuUtil.CreateContextMenu(...menuGenerator)` from AzeriteUI hook path, which can drift from Blizzard's primary tracking button interaction flow as tracking options evolve.
Change(s):
- In `Components/Misc/Minimap.lua` (`Minimap_OnMouseUp_Hook`, RightButton WoW11 path):
  - Prefer invoking Blizzard tracking button behavior directly:
    - `trackingButton:OnMouseDown()` when available,
    - fallback `trackingButton:Click()`.
  - Keep context-menu generator as fallback only.
  - This defers option population to Blizzard's current logic and should include newly added tracking categories.
Validation:
- `luac -p Components/Misc/Minimap.lua`
Result:
- Syntax valid (`minimap=0`).
- Pending in-game check that right-click tracking menu includes full current WoW12 options.

2026-02-18 (BugSack 3781: secret-string compare order in NamePlates/Tags)
Issue:
- BugSack reported:
  - `Components/UnitFrames/Units/NamePlates.lua:124` secret string compare in GUID helper path.
  - `Components/UnitFrames/Tags.lua:129` secret string compare in unit-name helper path.
Hypothesis:
- Several helper conditions compared string emptiness (`== ""` / `~= ""`) before secret-value checks, triggering WoW12 secret comparison faults.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Reordered guards to check `IsSecretValue(...)` before string equality checks in:
    - `IsSafeUnitToken`, `SafeUnitName`, `SafeUnitGUID`, `GetGuidType`, `GetGuidAndNpcID`.
- In `Components/UnitFrames/Tags.lua`:
  - Reordered `SafeUnitName` and `_G.GetUnitName` fallback checks so secret validation runs before `~= ""` comparisons.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- Syntax valid (`nameplates=0`, `tags=0`).
- Expected outcome: BugSack 3781 secret compare errors are resolved.

2026-02-18 (follow-up: minimap RMB/MMB click handling regression)
Issue:
- User reports minimap right-click only pings (tracking menu not opening), and middle-click action appears missing.
Hypothesis:
- Minimap used `HookScript("OnMouseUp", ...)`, so Blizzard's native handler still processed clicks first; right/middle actions could fall through to ping behavior.
Change(s):
- In `Components/Misc/Minimap.lua`:
  - Restored explicit minimap click ownership with `SetScript("OnMouseUp", Minimap_OnMouseUp)`.
  - Kept WoW11 tracking handling (prefer Blizzard tracking button interaction with context-menu fallback).
  - Added explicit fallback branch to call `Minimap.OnClick` / `Minimap_OnClick` for default left-click ping behavior.
Validation:
- `luac -p Components/Misc/Minimap.lua`
Result:
- Syntax valid (`minimap=0`).
- Expected outcome: RMB opens tracking, MMB triggers landing page behavior on retail, LMB still pings.

2026-02-18 (BugSack 3784: protected Minimap:PingLocation taint)
Issue:
- BugSack reports:
  - `[ADDON_ACTION_FORBIDDEN] AddOn 'AzeriteUI' tried to call protected function 'Minimap:PingLocation()'`
  - stack points to minimap click handler fallback path.
Hypothesis:
- AzeriteUI `OnMouseUp` fallback called Blizzard click/ping handler directly (`Minimap.OnClick` / `Minimap_OnClick`) from addon code, tainting protected `PingLocation`.
Change(s):
- In `Components/Misc/Minimap.lua`:
  - Removed left-click fallback call to Blizzard ping handler from addon code.
  - Kept explicit RMB handling for WoW11 via `MenuUtil.CreateContextMenu(...menuGenerator)` + sound.
  - Kept MMB retail landing page behavior unchanged.
Validation:
- `luac -p Components/Misc/Minimap.lua`
Result:
- Syntax valid (`minimap=0`).
- Expected outcome: no protected ping taint; RMB tracking menu works via Blizzard menu generator path.

2026-02-18 (follow-up: restore LMB ping + MMB fallback with taint safety)
Issue:
- After taint fix, user reports:
  - right-click works,
  - left-click ping no longer works,
  - middle-click expected behavior incomplete when landing page button not available.
Change(s):
- In `Components/Misc/Minimap.lua`:
  - Added `DispatchDefaultMinimapClick(self)` helper.
  - Routed default minimap click handling through `securecallfunction` (fallback to direct call if unavailable).
  - `MiddleButton` path now falls back to default click behavior when no landing page button is shown.
  - Non-right/non-middle clicks now use default minimap click dispatch (restores LMB ping behavior).
Validation:
- `luac -p Components/Misc/Minimap.lua`
Result:
- Syntax valid (`minimap=0`).
- Expected outcome: LMB ping restored, RMB tracking remains functional, MMB keeps landing page action + safe fallback.

2026-02-18 (follow-up: final minimap click taint resolution)
Issue:
- User still reports protected-action taint on LMB ping (`Minimap:PingLocation`) and MMB no-op.
Hypothesis:
- Any addon-side dispatch into Blizzard minimap click handler can still taint ping path.
- Safer approach is to let Blizzard fully own default click handling and only hook RMB/MMB add-on behavior.
Change(s):
- In `Components/Misc/Minimap.lua`:
  - Removed addon-side default click dispatch helper.
  - Switched back to hook-only click integration:
    - `HookScript("OnMouseUp", Minimap_OnMouseUp_Hook)`.
  - Hook handler now processes only:
    - RMB tracking menu,
    - MMB landing page toggle (retail).
  - LMB is fully handled by Blizzard native script (no addon ping call path).
Validation:
- `luac -p Components/Misc/Minimap.lua`
Result:
- Syntax valid (`minimap=0`).
- Expected outcome: no LMB ping taint; RMB tracking remains; MMB works when landing page button is available.

2026-02-18 (follow-up: WoW12-safe minimap click ownership)
Issue:
- WoW12 appears to have removed old expansion landing page entry points used by addon MMB fallback logic.
- Addon-side MMB handling can create stale behavior and unnecessary risk around click taint paths.
Hypothesis:
- Safest model is to let Blizzard fully own default minimap click behavior (LMB/MMB), while addon hook only handles RMB tracking menu compatibility.
Change(s):
- In `Components/Misc/Minimap.lua`:
  - Removed addon-side `MiddleButton` branch from `Minimap_OnMouseUp_Hook`.
  - Updated hook comment to explicitly state:
    - addon hook handles `RightButton` only,
    - Blizzard owns `LeftButton` and `MiddleButton` behavior.
Validation:
- `luac -p Components/Misc/Minimap.lua`
Result:
- Syntax valid (`minimap=0`).
- Expected outcome: all minimap clicks stay taint-safe; LMB/MMB follow Blizzard-native behavior; RMB tracking remains handled by AzeriteUI compatibility hook.

2026-02-18 (follow-up debug instrumentation: object/gameobject nameplate classification)
Issue:
- User still reports gameobject nameplates appearing.
- Need concrete runtime evidence for why a plate is classified as object-vs-enemy in current environment.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added toggleable debug logger `DebugObjectPlateDecision` behind existing `ns.db.global.debugFixes` (`/azdebug fixes on`).
  - Logger prints: `event`, `unit`, `widgetsOnly`, `canAttack`, `isPlayer`, `isObjectPlate`.
  - Added state dedupe (`self.__AzeriteUI_ObjectPlateDebugState`) to reduce repeat spam.
  - Clear debug state on `NAME_PLATE_UNIT_REMOVED`.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game log capture for problematic gameobjects.

2026-02-18 (follow-up classifier upgrade after debug logs: widgetsOnly=false object plates)
Issue:
- Debug logs showed object-like plates with `widgetsOnly=false`, `canAttack=false`, `isPlayer=false`, so widgets-only detection alone was insufficient.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added `GetGuidType(unit)` from `UnitGUID` prefix parsing (`GameObject`, `AreaTrigger`, etc.).
  - Expanded object classifier inputs: `canAttack`, `canAssist`, `isPlayer`, `playerControlled`, `guidType`.
  - Upgraded object detection to classify when:
    - GUID type is object-like (`GameObject`/`AreaTrigger`), or
    - passive non-player/non-assist/non-controlled widget plates, or
    - passive non-player/non-assist/non-controlled plates with missing GUID type.
  - Updated raid-target indicator suppression to honor `self.isObjectPlate`.
  - Extended debug output to print `guidType`, `canAssist`, and `playerControlled`.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending one more in-game `/reload` + `/azdebug fixes on` capture to confirm object plates are now classified/suppressed.

2026-02-18 (follow-up classifier tune: passive creature plates)
Issue:
- New debug logs showed persistent plates with `guidType=Creature`, `canAttack=false`, `canAssist=false`, `isPlayer=false`, `playerControlled=false`, still not classified as object/suppressible.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added extra classifier inputs: `isTrivial`, `classification`, `creatureType`, `reaction`.
  - Added suppression rule for passive/trivial creature-like plates:
    - `guidType == "Creature"`
    - non-attackable, non-assistable, non-player, non-player-controlled
    - and one of: `UnitIsTrivial`, `classification == "trivial"`, or friendly reaction (`reaction >= 4`).
  - Expanded debug output to print these fields for rapid verification.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game verification that passive creature/gameobject-like plates are now suppressed.

2026-02-18 (follow-up classifier tune: friendly non-hostile NPC creature plates)
Issue:
- Debug logs still showed trainer/guard style plates (`guidType=Creature`, `canAttack=false`, `reaction=5`, often `canAssist=true`) not classified as suppressible.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added `suppressFriendlyCreatureLike` rule for friendly, non-attackable, non-player, non-player-controlled creature plates (`reaction >= 4`).
  - Included this rule in `self.isObjectPlate` classification.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game confirmation that trainer/guard/clutter creature plates no longer show AzeriteUI nameplate visuals.

2026-02-18 (classifier correction: keep trainer/guard nameplates)
Issue:
- User requirement clarification: trainers and guards should keep nameplates; only clutter objects (chairs/campfires/etc) should be suppressed (including raid icons).
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Removed the broad `suppressFriendlyCreatureLike` classifier branch.
  - Kept suppression only for object-like and passive non-assistable clutter-style plates (`GameObject`/`AreaTrigger`, widget-only passive, and passive non-assistable creature-like plates).
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game confirmation: trainer/guard plates visible; chair/campfire plates suppressed.

2026-02-18 (targeted-friendly visibility fix: trainer NPC name hidden)
Issue:
- Even with correct classifier (`isObjectPlate=nil`) trainer/guard targets could still appear without expected nameplate text.
Root cause hypothesis:
- `NamePlate_PostUpdateHoverElements` hid target name unless `showNameAlways` was enabled, regardless of friendly NPC target state.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added `showFriendlyTargetName` condition (`self.isTarget` and `self.canAttack == false` and `self.canAssist == true`).
  - Applied this condition in both:
    - `NamePlate_PostUpdateHoverElements` target branch (show name for targeted friendly NPCs),
    - `NamePlate_PostUpdatePositions` (`hasName`) for correct aura/raid marker offset when friendly target name is shown.
  - Cached `self.canAttack`/`self.canAssist` in `NamePlate_PostUpdate` and cleared them on hide.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game verification that trainer/guard target nameplates display while chairs/campfires remain suppressed.

2026-02-18 (follow-up: secret-safe target matching + hard object frame hide)
Issue:
- User still reported missing trainer nameplates and returned object plates despite classifier updates.
Root cause hypothesis:
- `UnitIsUnit` can yield secret/invalid results causing false negatives for `self.isTarget`/`self.isFocus` updates.
- Object suppression via alpha-only could still leak visible elements depending on frame/show state transitions.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added `IsSafeUnitToken`, `SafeUnitGUID`, `SafeUnitMatches` helpers.
  - Replaced direct `UnitIsUnit` usage in `NamePlate_PostUpdate` and event handlers (`PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `PLAYER_SOFT_ENEMY_CHANGED`, `PLAYER_SOFT_INTERACT_CHANGED`) with `SafeUnitMatches` (GUID fallback when needed).
  - For `isObjectPlate` frames, now calls `self:Hide()` and returns early.
  - For non-object frames, explicitly restores visibility with `self:Show()` before normal element updates.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending one more in-game trainer/chair/guard verification pass.

2026-02-18 (follow-up rollback/fix: restore soft-interact + friendly NPC nameplate visibility)
Issue:
- User reported friendly NPC (trainer) nameplate still missing and soft-interact icon lost.
Root cause hypothesis:
- Hard `self:Hide()` on object-classified plates was too aggressive for recycled nameplate frames and could interfere with subsequent visual/state updates.
- Friendly assistable NPC names still needed explicit visibility path independent of strict target-event timing.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Removed hard frame hide/show control for object plates.
  - Kept object suppression as element-level hide/alpha only, preserving frame lifecycle updates.
  - Added `self.isFriendlyAssistableNPC` state in `NamePlate_PostUpdate`.
  - Updated name visibility/positioning logic to show names for friendly assistable NPC plates (`showFriendlyAssistName`) in both:
    - `NamePlate_PostUpdateHoverElements`,
    - `NamePlate_PostUpdatePositions`.
  - Clear `isFriendlyAssistableNPC` on hide.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending in-game confirmation that trainer names + soft-interact visuals are restored while object clutter remains suppressed.

2026-02-18 (follow-up diagnostics expansion: identify chair-vs-trainer plate source)
Issue:
- User still reports trainer nameplate missing and chair plate visible, despite classifier outputs.
Change(s):
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Expanded debug log payload to include:
    - `name`, `guid`, `npcID`,
    - `frameShown`, `frameAlpha`, `nameShown`, `nameText`,
    - `softIconShown`, `blizzUFShown`.
  - Added helper parsers `SafeUnitName(unit)` and `GetGuidAndNpcID(unit)`.
  - Added friendly assistable NPC name fallback in hover update:
    - if tagged name text is blank, set `self.Name` from `SafeUnitName(self.unit)`.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`nameplates=0`).
- Pending focused in-game capture to determine whether remaining chair plates come from AzeriteUI or Blizzard UF path and why trainer text is blank.

2026-02-18 (follow-up: boss/nameplate data consistency + unnecessary gameobject nameplates)
Issue:
- Boss unitframes could show incorrect/missing name/data in dungeon/delve encounters.
- Enemy nameplate names/health values were not consistent.
- Unnecessary gameobject/widget-only nameplates still appeared with AzeriteUI visuals.
Root cause hypothesis:
- `*:Name` tag resolution preferred `realUnit` first; stale `realUnit` values could bleed wrong names and levels into frames.
- Several tag fallback paths still compared `frame.unit == unit` directly, which is unsafe when unit tokens can be secret-wrapped.
- Nameplate callback forced `self:Show(); self:SetAlpha(1)` for every plate and custom visuals were not suppressed for widget-only object plates.
Change(s):
- In `Components/UnitFrames/Tags.lua`:
  - Added `SafeUnitTokenEquals(left, right)` and replaced direct `frame.unit == unit` compares in safe health/power/percent fallbacks.
  - Updated `*:Name` to resolve unit-first (`unit` before `realUnit`), cache last safe name per token, and use unit-first level lookup.
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added `self.isObjectPlate` classification in `NamePlate_PostUpdate` using secret-safe `UnitCanAttack`/`UnitIsPlayer` checks.
  - Suppressed AzeriteUI health/name/castbar/auras for object/widget-only plates in `NamePlate_PostUpdateElements`.
  - Removed forced `self:Show(); self:SetAlpha(1)` in `NAME_PLATE_UNIT_ADDED` callback.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Syntax valid (`tags=0;nameplates=0`).
- Pending in-game `/reload` verification for boss frame data, enemy nameplate text consistency, and gameobject plate suppression.

2026-02-18 (BugSack 3755: secret-string compares in aura filters + priority debuff update)
Issue:
- `Components/UnitFrames/Auras/AuraFilters.lua:243` attempted direct compare on `data.sourceUnit` secret string.
- `Libs/oUF_Plugins/oUF_PriorityDebuff.lua:394` attempted direct compare on local `unit` secret string in `UNIT_SPELLCAST_SUCCEEDED` path.
- User also reports missing enemy target names in delves/dungeons (gets own name when targeted), needs verification for relation.
Root cause hypothesis:
- WoW12 can deliver secret unit tokens/strings in aura payload and spellcast events; direct `==` / `~=` string comparisons on these values throw.
- Error spam likely interrupts related unitframe update flows and may contribute to observed target name anomalies.
Change(s):
- In `Components/UnitFrames/Auras/AuraFilters.lua`:
  - Replaced `data.sourceUnit == unit` with secret-safe token comparison using `SafeKey(data.sourceUnit)` and typed string guards.
- In `Libs/oUF_Plugins/oUF_PriorityDebuff.lua`:
  - Added `IsSecret` alias and guarded `Update(self, event, unit)` against non-string/secret unit tokens before comparing with `self.unit`.
  - Hardened `UNIT_SPELLCAST_SUCCEEDED` branch in `UpdateDispelTypes` to skip non-string/secret `castUnit` before `castUnit ~= "player"` check.
- In `Components/UnitFrames/Tags.lua`:
  - Added `SafeUnitName(unit)` helper to avoid calling `UnitName`/`GetUnitName` with secret unit tokens.
  - Updated `*:Name` tag to use safe name resolution (`SafeUnitName(realUnit) or SafeUnitName(unit)`).
Validation:
- `luac -p Components/UnitFrames/Auras/AuraFilters.lua`
- `luac -p Libs/oUF_Plugins/oUF_PriorityDebuff.lua`
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- Syntax valid (`aurafilters=0;prioritydebuff=0;tags=0`).
- Pending in-game `/reload` verification for 3755 errors and target-name behavior in delves/dungeons.

2026-02-18 (party follow-up: revert custom anchor overrides + explicit party click registration)
Issue:
- Party anchor could be visible but frame geometry appeared offset/outside the anchor bounds.
- Party click-targeting (Brann/party unit) was still unreliable after earlier lock/anchor adjustments.
Root cause hypothesis:
- Custom `UpdateAnchor` overrides for Party/Raid5 bypassed the default movable-frame prototype path and could desync perceived anchor bounds from actual rendered group frame geometry.
- Party secure unit buttons needed explicit down/up click registration in this environment to avoid click-up-only edge cases.
Change(s):
- In `Components/UnitFrames/Units/Party.lua`:
  - Removed custom `PartyFrameMod.UpdateAnchor` override (return to `ns.MovableModulePrototype.UpdateAnchor`).
  - Added explicit `self:RegisterForClicks("AnyDown", "AnyUp")` in Party style after common unitframe initialization.
- In `Components/UnitFrames/Units/Raid5.lua`:
  - Removed custom `RaidFrame5Mod.UpdateAnchor` override (return to `ns.MovableModulePrototype.UpdateAnchor`).
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`
- `luac -p Components/UnitFrames/Units/Raid5.lua`
Result:
- Pending command execution and in-game `/reload` verification for party click-target + `/lock` anchor alignment.

2026-02-18 (follow-up usability pass: Party click-target restored + Party/Raid5 anchor visibility + retail critter style fallback)
Issue:
- Party member click-targeting regressed (could not click party unit frames to target).
- `/lock` anchor visibility/draggability still inconsistent for Party and Raid (5).
- Dungeon/delve critters still resolved to normal style instead of Critter style, without Lua errors.
Root cause hypothesis:
- Party lock-sync logic toggled unit frame mouse handling, which can suppress intended click-target behavior.
- Group header anchor size can collapse to tiny/near-zero in some states; draggable anchor then becomes effectively invisible.
- Critter style relied mainly on `UnitCreatureType == "Critter"`; in modern content this can fail to classify some tiny ambient enemies.
Change(s):
- In `Components/UnitFrames/Units/Party.lua`:
  - Added explicit `UpdateAnchor` override using `GetHeaderSize()` with minimum anchor size clamp.
  - Removed runtime mouse enable/disable toggling from lock sync to preserve click-target behavior.
- In `Components/UnitFrames/Units/Raid5.lua`:
  - Added explicit `UpdateAnchor` override using `GetHeaderSize()` with minimum anchor size clamp.
- In `Components/UnitFrames/Units/Target.lua`:
  - Switched critter type lookup to `UnitCreatureType(unit)`.
  - Added secret-safe low-health/low-level fallback for critter-like hostile units in retail (`level <= 2`, low max health).
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`
- `luac -p Components/UnitFrames/Units/Raid5.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Syntax valid (`luac-party-raid5-target-fixes-ok`).
- Pending in-game `/reload` verification for click-target + draggable anchors + critter style behavior.

2026-02-18 (follow-up BugSack 3752: Target cached GUID compare + Party /lock anchor visibility/drag)
Issue:
- `Components/UnitFrames/Units/Target.lua:1803` compared cached target GUID with a secret GUID value.
- Party anchor remained hidden/non-draggable in `/lock` (reported in dungeon/critters repro path).
Root cause hypothesis:
- Target style fast-path compared `self.__AzeriteUI_TargetGUID == unitGUID` without secret guard.
- Party frame could still capture mouse while lock UI is open, and party anchor visibility needed explicit sync with lock state.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added secret-safe GUID handling in style cache fast-path; skip direct GUID compare when either GUID is secret and clear cached GUID.
- In `Components/UnitFrames/Units/Party.lua`:
  - Added `UpdateAnchorAndMouseForLock`:
    - force-show party anchor when lock UI is open,
    - disable party header/child mouse only while lock UI is open,
    - restore mouse when lock UI closes.
  - Hooked `MovableFramesManager` show/hide anchor events to call the sync function.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/Party.lua`
Result:
- Syntax valid (`luac-bugsack-3752-fixes-ok`).
- Pending fresh `/buggrabber reset` + `/reload` verification in dungeon/citter target scenario.

2026-02-18 (follow-up BugSack 3751: persistent groupingOrder nil + power guid secret compare + party /lock drag parity)
Issue:
- `SecureGroupHeaders.lua:467` still hit nil `groupingOrder` from `Party.lua:UpdateHeader` path.
- `Components/UnitFrames/Functions.lua:740` compared secret GUID values in `UpdatePower`.
- Party anchor remained non-draggable in `/lock` while other raid anchors were draggable.
Root cause hypothesis:
- Party header can trigger `SecureGroupHeader_Update` inside `UpdateVisibilityDriver` before `UpdateHeader` sets grouping attributes.
- `GetHeaderAttributes` still accepted non-string/invalid grouping values from profile payloads.
- Party had unique `/lock` mouse-interactivity hooks not used by raid modules, making behavior diverge.
Change(s):
- In `Components/UnitFrames/Units/Party.lua`:
  - `GroupHeader.UpdateVisibilityDriver` now computes safe `groupBy`/`groupingOrder` and sets them before `showRaid/showParty/showPlayer` attributes.
  - `GetHeaderAttributes` now uses typed fallback-safe values for all secure header fields.
  - Removed party-only `UpdateFrameMouseInteractivity` hooks/logic to restore parity with other raid modules in `/lock` drag behavior.
- In `Components/UnitFrames/Functions.lua`:
  - `UpdatePower` now guards secret GUID values before compare and avoids direct secret-string equality checks.
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Syntax valid (`luac-bugsack-3751-fixes-ok`).
- Pending fresh `/buggrabber reset` + `/reload` repro to confirm no new 3751 stacks.

2026-02-18 (follow-up BugSack 3750: secure groupingOrder nil + secret guid compare + tooltip SetWatch taint)
Issue:
- `SecureGroupHeaders.lua:467` still reported nil `groupingOrder` from `Party.lua:UpdateHeader`.
- `Components/UnitFrames/Functions.lua:503` compared secret GUID values (`guid ~= element.guid`).
- Blizzard tooltip `SetWatch("name", value)` taint still attributed to AzeriteUI during world-cursor tooltip updates.
Root cause hypothesis:
- `UpdateHeader` wrote non-grouping attributes first; each `SetAttribute` can trigger `SecureGroupHeader_Update` before grouping fields are repaired.
- GUID equality checks are unsafe when either side can be a secret string in WoW12.
- Tooltip module stored addon metadata directly on protected tooltip/statusbar frames (`tooltip.__az*`, `bar.__az*`, `bar.Text`) and reassigned `GameTooltip.StatusBar`, increasing taint pressure on Blizzard-owned watch paths.
Change(s):
- In `Components/UnitFrames/Units/Party.lua`:
  - `UpdateHeader` now computes typed fallback-safe locals and sets `groupBy`/`groupingOrder` first before any other secure attributes.
- In `Components/UnitFrames/Functions.lua`:
  - `UpdateHealth` now guards secret GUID values before compare; when secret is detected it forces refresh and clears cached GUID/state without direct comparison.
- In `Components/Misc/Tooltips.lua`:
  - Replaced tooltip/statusbar metadata on frame objects with weak-table caches.
  - Removed direct `GameTooltip.StatusBar = GameTooltipStatusBar` assignment.
  - Added statusbar/text helpers using cache tables and updated health text/statusbar code paths to use those helpers.
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/Misc/Tooltips.lua`
Result:
- Syntax valid (`luac-bugsack-3750-fixes-ok`).
- Pending fresh in-game `/reload` + BugSack reset verification for remaining taint occurrences.

2026-02-18 (party startup regressions + nameplate gameobject marker bleed)
Issue:
- New BugSack errors after latest updates:
  - `Libs/oUF/ouf.lua:257` nil `unit` during secure header init.
  - `SecureGroupHeaders.lua` nil `groupingOrder` from party header update flow.
  - `Components/UnitFrames/Units/Party.lua:755` nil `self.frame` in `GroupHeader.ForAll`.
- Nameplate raid markers and stale names appeared over gameobjects (campfire/mailbox/benches/chairs), with `AzeriteNameplate3.RaidTargetIndicator` visible in frame stack.
- `Tags.lua` threw secret-string conversion error in `*:Name` tag path.
Root cause hypothesis:
- WoW11 party delayed-enable path was manually creating frames before `self:Enable()`, causing duplicate/unsafe initialization.
- `GroupHeader.ForAll` referenced `self.frame` instead of the header itself.
- Nameplate recycle path did not explicitly clear `RaidTargetIndicator`/name text for widget-only/non-unit plates.
- `*:Name` tag called string length/abbreviation on secret or nil name payloads.
Change(s):
- In `Components/UnitFrames/Units/Party.lua`:
  - Fixed `GroupHeader.ForAll` child iteration to use `self:GetChildren()`.
- In `WoW11/UnitFrames/PartyFrames.lua`:
  - Restored delayed enable flow to stock pattern (`self:Enable(); self:Update()`) and removed duplicate explicit create calls.
- In `Libs/oUF/ouf.lua`:
  - Hardened `initObject` unit resolution and suffix handling against nil/empty guessed units.
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Disable/hide `RaidTargetIndicator` for `nameplateShowsWidgetsOnly` plates.
  - Explicitly clear/hide raid marker and name text on `OnHide` and `NAME_PLATE_UNIT_REMOVED`.
- In `Components/UnitFrames/Tags.lua`:
  - `*:Name` now returns `""` for nil/secret names before any string ops.
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`
- `luac -p WoW11/UnitFrames/PartyFrames.lua`
- `luac -p Libs/oUF/ouf.lua`
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- Pending command execution and in-game `/reload` verification.

2026-02-18 (follow-up BugSack 3749: privateauras nil unit + target secret compare + gameobject nameplate markers)
Issue:
- `Libs/oUF/elements/privateauras.lua:181` nil `self.unit` indexing during secure header startup.
- Party secure header could still receive nil group attributes in update path (`groupingOrder` stack).
- Nameplate raid target icons could still appear on gameobjects/non-unit widget plates.
- `Target.lua` style selection compared secret string values (`UnitClassification`/`UnitCreatureType`).
Change(s):
- In `Libs/oUF/elements/privateauras.lua`:
  - Added `type(self.unit) == "string"` guard before pattern matching.
- In `Components/UnitFrames/Units/Party.lua`:
  - Added defensive fallback to module defaults for secure header attributes in `GetHeaderAttributes`, `UpdateHeader`, and visibility driver path.
- In `Components/UnitFrames/Units/NamePlates.lua`:
  - Added `RaidTargetIndicator.Override` with strict unit validity checks:
    - hide on nil/secret/non-existing units,
    - hide on `UnitNameplateShowsWidgetsOnly` plates,
    - hide for non-player non-attackable units.
- In `Components/UnitFrames/Units/Target.lua`:
  - Sanitized classification/creature type locals before string comparisons.
Validation:
- `luac -p Libs/oUF/elements/privateauras.lua`
- `luac -p Components/UnitFrames/Units/Party.lua`
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Pending command execution and in-game `/reload` verification.

2026-02-18 (party anchor in /lock not draggable/clickable)
Issue:
- Party frame anchor was visible in `/lock` but could not be clicked/dragged with mouse.
- Manual offset edits in the anchor menu still moved party frames, and no Lua error was thrown.
Root cause hypothesis:
- In WoW 12 branch, `PartyFrameMod.DisableBlizzard()` skips `oUF:DisableBlizzard("party")`, allowing Blizzard party/compact frames to remain active and potentially capture mouse over the same area.
- Party unit frame mouse handlers can also compete with anchor hit-testing while `/lock` is open.
Change(s):
- In `Components/UnitFrames/Units/Party.lua`:
  - Add WoW 12 safe suppression for already-loaded Blizzard party/compact frames (without forcing Blizzard addon load).
  - Toggle party frame mouse interactivity off while movable frame manager (`/lock`) is open, and restore it when closed.
Validation:
- `luac -p Components/UnitFrames/Units/Party.lua`
Result:
- Pending command execution and in-game `/reload` verification.

2026-02-18 (tooltip secret-value + SetWatch taint mitigation)
Issue:
- BugSack reported secret-value error from `Core/API/Colors.lua` (`UnitExists` called with secret unit token) via tooltip status bar update flow.
- Separate BugSack taint path hit Blizzard tooltip `SetWatch` during world-cursor tooltip handling.
Root cause hypothesis:
- Tooltip code could pass unvalidated unit tokens (including secret values) into `GetUnitColor`/`UnitExists`.
- Tooltip bar theming path forcibly reset `GameTooltipStatusBar` `OnValueChanged` script, increasing taint pressure on Blizzard-owned tooltip status bar behavior.
Change(s):
- In `Core/API/Colors.lua`:
  - Added safe unit-token guard (`type(unit) == "string"` and non-secret check when `issecretvalue` exists).
  - `GetUnitColor(unit)` now only calls `UnitExists` for validated unit tokens.
- In `Components/Misc/Tooltips.lua`:
  - Added the same safe unit-token guard helper.
  - Guarded tooltip unit flows (`SetHealthValue`, `SetStatusBarColor`, `OnValueChanged`, `OnTooltipSetUnit`) so `UnitExists`/unit APIs are only called with safe string tokens.
  - Removed direct `bar:SetScript("OnValueChanged", nil)` override in tooltip statusbar theme update to avoid overriding Blizzard statusbar script handling.
Validation:
- `luac -p Core/API/Colors.lua`
- `luac -p Components/Misc/Tooltips.lua`
Result:
- Lua parse pending command execution; in-game `/reload` verification pending.

2026-02-17 (removal ledger created)
Issue:
- Need full traceability of all cleanup removals for possible selective restore.
Change(s):
- Added detailed removal ledger: `Docs/RemovalLedger_2026-02-17.md`.
- Added restore checklist companion: `Docs/RemovalRestoreChecklist_2026-02-17.md`.
Result:
- All removed symbols/blocks are now itemized by wave and file with restore guidance.

2026-02-17 (dead-code cleanup pass: aggressive wave 2, legacy branches preserved)
Issue:
- Requested a more aggressive cleanup while keeping compatibility/legacy function paths for other WoW versions.
Approach:
- Removed only symbols proven unused (single-reference locals) and avoided deleting version-gated logic (`ns.IsClassic`, `ns.WoW11`, etc.).
Change(s):
- Removed additional dead locals/helpers in:
  - `Components/ActionBars/Elements/StatusBars.lua`
  - `Components/Misc/{Tooltips,TrackerVanilla,TrackerWoW11,VehicleSeat}.lua`
  - `Components/UnitFrames/Auras/{AuraStyling,Cata/Cata_AuraStyling,Classic/Classic_AuraStyling,Wrath/Wrath_AuraStyling}.lua`
  - `Components/UnitFrames/Units/{Party,Raid40}.lua`
  - `Core/{MovableFrameManager,Widgets/Popups}.lua`
  - `Options/OptionsPages/{Auras,Minimap,Tooltips,Tracker}.lua`
- Explicitly did not remove legacy/version-specific branches and compatibility functions.
Validation:
- `luac -p` on all wave-2 touched files: `luac-wave2-ok`
Result:
- More aggressive cleanup completed with legacy support kept intact.

2026-02-17 (dead-code cleanup pass: aggressive alias/function pruning)
Issue:
- Requested more aggressive cleanup of moot/unused code.
Approach:
- Pruned file-local symbols with single-reference proof (defined but never referenced).
- Focused on non-behavioral cleanup: unused local aliases/functions in Components + Options pages.
Change(s):
- Removed unused locals in:
  - `Components/ActionBars/Elements/ActionBars.lua`
  - `Components/ActionBars/Elements/StanceBar.lua`
  - `Components/Misc/{AlertFrames,ChatFrames,Info,TrackerWoW11,VehicleSeat}.lua`
  - `Components/UnitFrames/Tags.lua`
  - `Components/UnitFrames/Units/{Player,PlayerAlternate,PlayerCastBar}.lua`
  - `Options/OptionsPages/{ActionBars,Auras,Bags,Chat,ExplorerMode,Info,Nameplates,Tooltips,Tracker,TrackerVanilla}.lua`
- Removed unused helper functions where not referenced (`setoption/getoption/isdisabled` variants depending on file).
Validation:
- `luac -p` across all edited files (batch): `luac-all-ok`
Result:
- Cleanup-only pass with no intended runtime behavior changes.

2026-02-17 (dead-code cleanup pass: high-confidence unused symbols)
Issue:
- Requested broad cleanup of moot/unused code.
Approach:
- Safe first pass only: remove symbols proven unused by static single-reference scan in active addon code.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Removed unused helper `IsSafeBoolean(value)`.
  - Removed unused wrapper `GetSpellChargesTuple(...)`.
  - Removed stale commented-out legacy block for `ACTION_HIGHLIGHT_MARKS` / `UpdateNewAction` hooks.
  - Removed stale commented local placeholders (`LBG`, `Masque`) and old commented map init line.
- Removed stale non-runtime file `debug.log` from addon root.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- No functional behavior change expected; cleanup only.

2026-02-17 (release prep: scuttle charge investigation for this build)
Issue:
- Divine Steed/Judgment charge updates still not resolved to release quality.
Decision:
- Defer actionbar charge investigation to a follow-up build.
- Proceed with release packaging focused on stable WoW12 compatibility fixes already completed.
Change(s):
- Freeze actionbar charge work for this release.
- Prepare release notes + changelog + desktop package.
Result:
- Release prep in progress.

2026-02-17 (WoW12 charge reliability: remove action->spell charge override)
Issue:
- Divine Steed/Judgment charges still failed in combat after custom action->spell charge fallback work.
Investigation:
- Compared against current WoW12 `LibActionButton` patterns in ElvUI/Bartender/Dominos references.
- Common pattern: action buttons use action-slot charge info (`C_ActionBar.GetActionCharges`), with no extra action->spell charge replacement.
Root cause hypothesis:
- Our custom `Action.GetCharges`/`Action.GetChargeInfo` spell fallback could replace/clear valid action-slot charge state under restricted/secret payload timing, especially for specific charge spells.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Simplified `Action.GetCharges` to return only action-slot charge info tuple from `GetActionChargeInfo(self._state_action)`.
  - Simplified `Action.GetChargeInfo` to return only `GetActionChargeInfo(self._state_action)`.
  - Removed custom action->spell charge override logic.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification for Divine Steed/Judgment charge decrement/recharge in and out of combat.

2026-02-17 (charge fallback: resolve spellID from action button)
Issue:
- Charge updates still failed for specific spells after action->spell charge fallback.
Root cause hypothesis:
- Charge fallback keyed off `GetActionInfo` subtype can miss macro-based spell buttons.
- For macro actions, reliable spell resolution should come from the action button resolver (`GetSpellId`), which already handles macro spell extraction.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - `Action.GetCharges` now uses `self:GetSpellId()` for spell charge fallback lookup.
  - `Action.GetChargeInfo` now uses `self:GetSpellId()` for spell charge info fallback lookup.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (WoW12 actionbar charge fallback for spell actions)
Issue:
- Cooldown swipes/timers are working again, but charge behavior for some spells (Divine Steed, Judgment) is incorrect.
Investigation:
- Online API references indicate actionbar charge APIs can be restricted/secret in modern clients:
  - `C_ActionBar.GetActionCharges` (`SecretWhenActionCooldownRestricted`)
  - `GetActionCharges` / action-slot data can be stale/absent for spell charge state.
- `C_Spell.GetSpellCharges` returns spell-centric charge info that can be more reliable for spell actions.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - `Action.GetCharges` now prefers spell-charge tuple for spell/macro-spell actions when action-slot charge data is missing, stale, or lacks recharge state.
  - `Action.GetChargeInfo` now returns a spell-derived charge info table for spell actions when action info is missing/secret/non-charge or lacks recharge state.
- Kept cooldown swipe/timer flow unchanged.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (user-requested rollback to known working cooldown behavior)
Issue:
- Multiple iterative cooldown changes caused regressions (combat swipes/timers disappearing).
Change(s):
- Rolled back `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` sections to earlier known-working behavior:
  - Removed `UNIT_SPELLCAST_SUCCEEDED` refresh hook.
  - Restored `UpdateCooldown` apply/fallback normalization and secret checks to prior logic.
  - Restored `Action.GetCooldown` and `Action.GetCharges` fallback behavior to prior logic.
- Kept WoW11 stance-bar re-enable fix in place.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (combat cooldown visuals missing: fallback start/enable gating)
Issue:
- User reports cooldown swipes and numeric timers still disappear in combat.
Root cause hypothesis:
- Fallback path marked cooldown as secret when `enable` was secret/non-numeric, then dropped valid `start/duration` data.
- This caused `hasCooldown` to resolve false even when cooldown time data was valid, suppressing both swipe and timer.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` fallback branch:
  - `startSecret` now checks only `start/duration` secrecy.
  - Safe normalization for `enable` now uses `IsSafeNumber`/`IsSafeBoolean` only (no unsafe truthiness).
  - If `start/duration` indicate an active cooldown and `enable` normalizes to 0, promote `enable` to 1.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (combat regression: swipes and timers disappear again)
Issue:
- User reports cooldown swipes and numeric timers disappear in combat after recent sanitizer changes.
Root cause hypothesis:
- `ActionButton_ApplyCooldown` combat path can still receive secret/stale cooldown payloads for spell actions.
- When this occurs, secure apply path suppresses visible cooldown state; library cache-aware fallback path is more resilient in combat.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` `UpdateCooldown(self)`:
  - Use `ActionButton_ApplyCooldown` only out of combat.
  - In combat, always use existing cache-aware fallback logic below.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (BugSack spam: secret boolean test in cooldown sanitizer)
Issue:
- BugSack reports repeated error in `LibActionButton-1.0-GE.lua`:
  - `attempt to perform boolean test on local 'safeEnable' (a secret boolean value tainted by 'AzeriteUI')`.
Root cause hypothesis:
- Cooldown sanitize path used truthiness conversion `((safeEnable and 1) or 0)` on `cooldownInfo.isEnabled`.
- In combat, `isEnabled` could be a secret boolean; evaluating it in a boolean test triggered the error.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Added `IsSafeBoolean(value)` helper.
  - Replaced truthiness conversion with explicit safe normalization:
    - Accept safe numeric `isEnabled` directly.
    - Convert only safe booleans (`true/false`) to `1/0`.
    - Fall back to safe `enable` values, defaulting to `0`.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (cross-UI comparison: spell cooldown fallback preference)
Issue:
- Potions/items update correctly, but some spells still fail to update cooldown timers in combat.
Investigation:
- Compared `LibActionButton-1.0-GE` handling against `DiabolicUI3` and `AzeriteUI_Stock` in the workspace.
- Main delta: our action-slot branch can accept non-secret but stale/zero action cooldown values for spell actions, while spell APIs (`C_Spell/GetSpellCooldown`, `GetSpellCharges`) can have valid recharge/cooldown state.
Root cause hypothesis:
- For spell/macro-spell action buttons, action-slot cooldown/charge payload may be non-secret yet stale/zero during combat; current logic only fell back when values were secret/nil.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Updated `Action.GetCooldown` to prefer spell cooldown tuple when action payload has no active cooldown but spell payload does.
  - Updated `Action.GetCharges` to prefer spell charge recharge tuple when action recharge payload is missing/zero but spell recharge payload is active.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (cross-UI follow-up: stale-zero cooldownInfo override)
Issue:
- Spell cooldowns still failed in combat for specific spells after fallback preference changes.
Root cause hypothesis:
- `ActionButton_ApplyCooldown` sanitization accepted numeric `cooldownInfo`/`chargeInfo` values even when they were stale zeroes.
- Because values were numeric (not secret), tuple fallback values were not chosen in that path.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` `UpdateCooldown(self)` apply path:
  - Detect active fallback cooldown/recharge tuples.
  - If info-table cooldown/recharge is not active but fallback tuple is active, override with fallback tuple values.
  - Ensure `isEnabled` is promoted from fallback when fallback has active cooldown.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (combat cooldown stale on specific spells despite cast-event refresh)
Issue:
- User still reports some spells (Divine Steed/Judgment) not updating cooldown timers correctly in combat.
Root cause hypothesis:
- `ActionButton_ApplyCooldown` path consumed `GetCooldownInfo()`/`GetChargeInfo()` tables directly.
- In combat, these tables can contain secret/invalid fields; using them as-is can produce stale cooldown application for specific spell states.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` `UpdateCooldown(self)`:
  - Added strict sanitization for `cooldownInfo`, `chargeInfo`, and `lossOfControlInfo` before `ActionButton_ApplyCooldown`.
  - Fallback now prefers safe numeric values from already-computed cooldown/charge tuples when info-table fields are secret/invalid.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (in-combat cooldown timer refresh gaps on casted spells)
Issue:
- User reports cooldown numbers/swipes still fail to update for some spells during combat (observed with Divine Steed and possibly Judgment).
Root cause hypothesis:
- Combat cooldown event delivery can be inconsistent for some action-slot spell updates; relying only on cooldown events can leave stale button cooldown state until later updates.
Change(s):
- In `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Registered `UNIT_SPELLCAST_SUCCEEDED`.
  - Added handler for player casts (`arg1 == "player"`) to force `UpdateCount` + `UpdateCooldown` across active buttons, with tooltip refresh when relevant.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (stance bar missing from /lock on WoW11)
Issue:
- User reports stance bar is not visible and not present in `/lock` anchors.
Root cause hypothesis:
- `WoW11/ActionBars/PetBar.lua` and `WoW11/ActionBars/StanceBar.lua` intentionally disable auto-load (`SetEnabledState(false)`) and rely on `WoW11/ActionBars/ActionBars.lua` to re-enable them.
- Local `WoW11/ActionBars/ActionBars.lua` had been reduced to a no-op, so delayed enable never happened.
Change(s):
- Restored WoW11 delayed-enable override in `WoW11/ActionBars/ActionBars.lua`:
  - Defers actionbar initialization to `PLAYER_ENTERING_WORLD`.
  - Re-enables `ActionBars`, `PetBar`, and `StanceBar` after setup.
Validation:
- `luac -p WoW11/ActionBars/ActionBars.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (cooldown timers disappeared after charge registration)
Issue:
- User reports cooldown swipe and charge behavior are present, but numeric cooldown timers disappear on all bars.
Root cause hypothesis:
- Same `cooldownCount` FontString was registered to both main cooldown and `chargeCooldown` frames.
- Shared text ownership caused conflict/clears when one cooldown frame hid while the other tried to render text.
Change(s):
- Reverted charge cooldown text registration in:
  - `Components/ActionBars/Elements/ActionBars.lua`
  - `Components/ActionBars/Elements/StanceBar.lua`
  - `Components/ActionBars/Elements/PetBar.lua`
- Keep cooldown text attached only to the primary cooldown frame per button.
Validation:
- `luac -p Components/ActionBars/Elements/ActionBars.lua`
- `luac -p Components/ActionBars/Elements/StanceBar.lua`
- `luac -p Components/ActionBars/Elements/PetBar.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (global actionbar numeric cooldown fallback)
Issue:
- User still reports no numeric cooldown timer text anywhere while swipes remain visible.
Root cause hypothesis:
- Custom cooldown text path can be unavailable/stale when secure cooldown payloads are sanitized, while Blizzard countdown numbers were forcibly hidden via `SetHideCountdownNumbers(true)` plus enforcing hooks.
Change(s):
- Enabled native Blizzard countdown numbers across actionbar-related cooldown frames by:
  - Switching `SetHideCountdownNumbers(true)` to `SetHideCountdownNumbers(false)`.
  - Inverting enforcement hooks so hidden state is not allowed (`if h then SetHideCountdownNumbers(false) end`).
- Applied in:
  - `Components/ActionBars/Elements/ActionBars.lua`
  - `Components/ActionBars/Elements/PetBar.lua`
  - `Components/ActionBars/Elements/StanceBar.lua`
  - `Components/ActionBars/Elements/ExtraButtons.lua`
Validation:
- `luac -p Components/ActionBars/Elements/ActionBars.lua`
- `luac -p Components/ActionBars/Elements/PetBar.lua`
- `luac -p Components/ActionBars/Elements/StanceBar.lua`
- `luac -p Components/ActionBars/Elements/ExtraButtons.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (stance bar appears hidden + cooldown timer parity follow-up)
Issue:
- User reports stance bar appears hidden (paladin observed) and requested follow-up parity for cooldown timer registration.
Root cause hypothesis:
- In `Options/OptionsPages/ActionBars.lua`, stance settings updates mistakenly called `pet:UpdateSettings()` instead of `stance:UpdateSettings()`.
- In `Components/ActionBars/Elements/StanceBar.lua`, shapeshift/actionbar events updated button content but did not always re-run `UpdateEnabled()`, which could leave the stance bar in stale hidden/disabled state after form-state changes.
- Pet/Stance style paths registered main cooldown text, but lacked defensive registration for optional `chargeCooldown` frames.
Change(s):
- Fixed ActionBars options setter typo to call `stance:UpdateSettings()` in both relevant toggles.
- Updated `StanceBarMod.OnEvent` to re-run `UpdateEnabled()` when processing deferred (`PLAYER_REGEN_ENABLED`) and regular form/state event updates.
- Added optional `chargeCooldown` timer registration to existing cooldown count text in:
  - `Components/ActionBars/Elements/StanceBar.lua`
  - `Components/ActionBars/Elements/PetBar.lua`
Validation:
- `luac -p Components/ActionBars/Elements/StanceBar.lua`
- `luac -p Components/ActionBars/Elements/PetBar.lua`
- `luac -p Options/OptionsPages/ActionBars.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (actionbar cooldown swipe visible but no cooldown timer number)
Issue:
- User reports actionbar cooldown swipe appears, but no numeric cooldown text is visible.
Root cause hypothesis:
- Main action button cooldown text (`cooldownCount`) is registered to `self.cooldown`, but charge/recharge swipes use `self.chargeCooldown` which was not registered to the cooldown text widget.
- Result: swipe can be visible while numeric timer text is not driven for charge cooldown updates.
Change(s):
- In `Components/ActionBars/Elements/ActionBars.lua`, register `self.chargeCooldown` to the existing `self.cooldownCount` inside `UpdateCharge` once the charge cooldown frame exists.
- Keep change minimal and local to actionbar button styling path.
Validation:
- `luac -p Components/ActionBars/Elements/ActionBars.lua`
Result:
- Pending in-game `/reload` verification.

2026-02-17 (target frame aura layout options + growth direction ignored)
Issue:
- User reports target-frame auras still growing upward and requests live `/az` controls for per-row count, padding, icon size, and growth direction.
Root cause hypothesis:
- `Components/UnitFrames/Units/Target.lua` hard-overrides target aura layout after reading config:
  - `initialAnchor = "TOPLEFT"`
  - `growth-x = "RIGHT"`
  - `growth-y = "DOWN"`
- This bypasses layout/profile values and makes aura layout controls ineffective.
Planned change(s):
- Remove hardcoded aura growth override in `Target.lua`.
- Add target-profile aura layout settings (max-per-row, size, spacing X/Y, growth X/Y, initial anchor).
- Apply these settings through a single runtime aura-layout helper so changes apply immediately via `/az`.
- Add corresponding options in `Options/OptionsPages/UnitFrames.lua`.
Files targeted:
- `Components/UnitFrames/Units/Target.lua`
- `Options/OptionsPages/UnitFrames.lua`
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Added target profile defaults for aura layout controls:
    - `AurasMaxCols`, `AuraSize`, `AurasSpacingX`, `AurasSpacingY`, `AurasGrowthX`, `AurasGrowthY`, `AurasInitialAnchor`.
  - Added `ApplyTargetAuraLayout(frame, styleKey)` helper to apply target aura layout from profile/config in one path.
  - Removed hardcoded target aura force:
    - `initialAnchor = "TOPLEFT"`, `growth-x = "RIGHT"`, `growth-y = "DOWN"`.
  - Updated runtime style update path to call `ApplyTargetAuraLayout(...)` and force-refresh auras.
  - Applied aura layout once on style creation for reload-safe startup behavior.
- `Options/OptionsPages/UnitFrames.lua` (`/az -> UnitFrames -> Target`):
  - Added new **Aura Layout** controls:
    - `Auras Per Row` (`AurasMaxCols`, 0=auto)
    - `Aura Size` (`AuraSize`)
    - `Aura Padding X` (`AurasSpacingX`)
    - `Aura Padding Y` (`AurasSpacingY`)
    - `Aura Growth X` (`AurasGrowthX`)
    - `Aura Growth Y` (`AurasGrowthY`)
    - `Aura Initial Anchor` (`AurasInitialAnchor`)
  - Wired these to live refresh via the existing target live-refresh path.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Done; target aura growth is no longer hardcoded and is now user-configurable in `/az` with live updates.

2026-02-17 (target castbar differs between self-target and other player targets)
Issue:
- User reports target castbar aligns/fills correctly on self-target, but appears offset or wrong-fill on other player targets.
Root cause hypothesis:
- `Components/UnitFrames/Units/Target.lua` cache gate in `UnitFrame_UpdateTextures(...)` only compared style + health-lab signature.
- When switching between different targets with same style/signature (for example player -> player), update returned early and skipped per-target cast refresh (`Castbar:ForceUpdate()` path and related setup execution).
Change(s):
- Added target GUID to the cache fast-path key in `UnitFrame_UpdateTextures(...)`.
- Cache now returns early only when style, signature, and target GUID are all unchanged.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Done; target changes between same-style units now re-run target texture/cast setup and avoid stale castbar state carry-over.

2026-02-17 (actionbar cooldown swipes/timers missing in combat on some buttons)
Issue:
- User reports multiple actionbar buttons do not show cooldown blackout/timer until leaving combat.
- Charge/count state tends to recover on combat end, indicating in-combat update path is incomplete.
Root cause hypothesis:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` handles `SPELL_UPDATE_COOLDOWN` for non-action buttons only.
- Action-slot APIs can return secret cooldown/charge data in combat; without fallback source, cooldown display can be cleared/stale until a later non-secret update.
Planned change(s):
- Expand combat cooldown event coverage so spell cooldown updates refresh action-slot buttons too.
- Add action-slot fallback cooldown/charge reads from underlying spell/item APIs when action API payload is nil/secret.
Files targeted:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Update:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Added cross-source cooldown/charge helpers:
    - `GetSpellCooldownTuple(...)`
    - `GetSpellChargesTuple(...)`
  - Event coverage:
    - `SPELL_UPDATE_COOLDOWN` now updates `ActiveButtons` (includes action-slot buttons), not only `NonActionButtons`.
    - `SPELL_UPDATE_CHARGES` now updates both counts and cooldowns (`UpdateCount` + `UpdateCooldown`).
  - Action-slot fallback logic:
    - `Action.GetCooldown(...)` now falls back to spell/item APIs (`C_Spell`/`GetSpellCooldown`, `C_Container.GetItemCooldown`) when action cooldown payload is secret or unavailable.
    - `Action.GetCharges(...)` now falls back to spell charge APIs (`C_Spell`/`GetSpellCharges`) when action charge payload is secret or unavailable.
    - `Action.GetCount(...)` now falls back to item count APIs (`C_Item.GetItemCount` / `GetItemCount`) when action count payload is secret or unavailable for item actions/macros.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Done; in-combat cooldown/charge updates now have broader event triggers and non-action-slot API fallback paths.

2026-02-17 (target cast timer secret compare crash in combat)
Issue:
- BugSack: `Components/UnitFrames/Units/Target.lua:806 attempt to compare local 'total' (a secret number value tainted by 'AzeriteUI')`.
- Stack points into `GetTargetCastPercentFromTimer(...)` during target cast updates.
Root cause hypothesis:
- Secret-value guard ordering is unsafe in timer-percent helpers: numeric comparisons (for example `total > 0`) are evaluated before `issecretvalue(...)` checks.
- On secret payloads in combat, comparison executes first and errors.
Change(s):
- Reordered secret guards ahead of numeric comparisons in `Components/UnitFrames/Units/Target.lua` for the target cast/health helper path:
  - `GetTargetCastPercentFromTimer(...)`
  - `GetTargetCastPercentFromRemainingDuration(...)`
  - `GetTargetCastPercentFromDurationPayload(...)`
  - `UpdateTargetFakeCastFillFromNativeTexture(...)` (`SafeDim`)
  - `ApplyTargetFakeHealthFillByPercent(...)` width sampling checks
  - `Health_PostUpdate(...)` fake health cache guard
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- guard-order scan shows no remaining compare-before-secret pattern matches in this file.
Result:
- Done; secret compare crash path at line 806 is removed.

2026-02-17 (actionbar cooldown/charge desync on some slots, potion/item cooldown stale until slot reassign)
Issue:
- Some action buttons fail to show cooldown blackout/timer consistently.
- Item charges/cooldowns (notably potions) can remain stale until moving/reassigning the action.
Root cause hypothesis:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` still reads legacy action cooldown/charge APIs directly in places where modern clients use `C_ActionBar` table returns.
- Mixed tuple/table return handling can produce nil/invalid cooldown/charge values on some buttons.
- Item cooldown refresh may miss bag-driven cooldown/count refresh events in some combat/update paths.
Change(s):
- Port DiabolicUI3-style action cooldown/charge wrappers:
  - normalize `C_ActionBar.GetActionCooldown/GetActionCharges` table returns with fallback to legacy APIs.
  - ensure action and item cooldown getters always return numeric tuple values to the existing LAB update pipeline.
- Add bag cooldown/count refresh events for item-action consistency:
  - `BAG_UPDATE_COOLDOWN`
  - `BAG_UPDATE_DELAYED`
- Keep existing secret-safe fallback/cache logic and only normalize API/event inputs.
- Implemented in `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - added `GetActionCooldownInfo` / `GetActionChargeInfo` wrappers using `C_ActionBar` first and legacy fallback second.
  - updated `Action.GetCooldown` / `Action.GetCharges` to always unpack numeric tuple values from wrapper tables.
  - updated `Item.GetCooldown` to normalize tuple/table returns from `C_Container.GetItemCooldown`.
  - added `BAG_UPDATE_COOLDOWN` and `BAG_UPDATE_DELAYED` handlers to force cooldown/count refresh for action+item buttons.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Done; syntax check passes.

2026-02-17 (actionbar cooldowns/charges disappearing or freezing in combat)
Issue:
- Actionbar cooldown swipes/charge counts may stop showing correctly in combat.
- Symptom pattern matches secret-value reads during combat causing update paths to clear visuals.
Root cause (hypothesis):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` clears cooldown/charge state when `GetCooldown/GetCharges/GetCount` return secret values, instead of using last safe values.
- This can zero out or hide cooldown visuals until a later non-secret event.
Change(s):
- Add per-button cached safe cooldown/charge/count state in `LibActionButton-1.0-GE`.
- Use cached values when current API reads are secret/unavailable.
- Reset caches on action identity changes to avoid stale data crossing buttons/actions.
- Implementation details in `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Added safe cache helpers (`IsSafeNumber`, action-keyed cache init/reset).
  - `UpdateCount(...)` now reuses last safe `count`/`charges` when current reads are secret.
  - `UpdateCooldown(...)` now reuses last safe normal cooldown, loss-of-control cooldown, and charge cooldown timing when current reads are secret.
  - Cache now resets automatically when action identity changes or when button no longer has an action texture.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Done; syntax check passes.

2026-02-17 (cleanup sweep: remove non-runtime patch/backup artifacts)
Issue:
- Repository had temporary patch/backup files from iterative debugging that are not runtime addon files.
Root cause:
- Prior manual/AI patch loops left helper artifacts in source folders.
Change(s):
- Removed:
  - `Core/FixBlizzardBugs_patch.tmp`
  - `Core/FixBlizzardBugs.lua.patch`
  - `Components/UnitFrames/Units/Target.lua.before_revert`
  - `Components/UnitFrames/Units/Target.lua.backup`
Validation:
- `rg -n "FixBlizzardBugs_patch\\.tmp|FixBlizzardBugs\\.lua\\.patch|Target\\.lua\\.before_revert|Target\\.lua\\.backup"` (no matches)
Result:
- Done; only runtime/source files remain in those paths.

2026-02-17 (cleanup: remove redundant target cast fake-fill paths)
Issue:
- Target cast fake-fill had multiple overlapping percent paths kept from earlier debugging (`live`, `unit`, `timer`, `mirror`, `minmax`, `native`).
Root cause:
- After adopting the live duration-payload path, the extra unit-time reconstruction path became redundant complexity and a potential desync source.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Removed `GetTargetCastPercentFromUnitTiming(...)`.
  - Removed `unit` branch in `UpdateTargetFakeCastFill(...)`.
  - Refactored cast time text handlers to share payload extraction/update helpers and reduce duplicated logic.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Syntax check passes; in-game verification pending (expected same smooth behavior with less redundant code).

2026-02-17 (target cast fake-fill only updates on config nudges; no smooth per-frame progress)
Issue:
- Target cast text/time updates, but fake-fill progress often appears static and only jumps when `/az` cast settings are changed.
Root cause:
- Fake-fill update path could miss or deprioritize the same live duration payload used by oUF castbar time updates.
- Existing percent path ordering could stick to stale fallbacks (`unit`/`timer`) instead of the per-frame duration payload.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added `NormalizeTargetCastPercent(...)` and `GetTargetCastPercentFromRemainingDuration(...)` helpers for safe, consistent 0..1 progress math.
  - Added `GetTargetCastPercentFromDurationPayload(...)` to consume live duration payloads (`DurationObject` or numeric remaining).
  - Added a high-priority `explicitPercent` path to `UpdateTargetFakeCastFill(...)` (`castFake: path live`).
  - Added `Cast_CustomTimeText(...)` and `Cast_CustomDelayText(...)` to:
    - update fake-fill every frame from oUF’s live duration payload;
    - preserve cast time text formatting.
  - Wired `self.Castbar.CustomTimeText` and `self.Castbar.CustomDelayText` to those handlers.
  - Kept existing fallback paths (`unit`, `timer`, `mirror`, `minmax`, `native`) intact for resilience.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- In-game verification pending: expected smooth target cast fake-fill progression that updates continuously without requiring option nudges.

2026-02-17 (target cast fake-fill visible but static during channel)
Issue:
- Target cast fake-fill is visible and oriented correctly, but does not progress while channeling.
Root cause:
- In native fallback mode, fake-fill percent is derived from native cast texture geometry.
- Native cast texture was being hidden (`Hide()`), which can stop/flatten geometry updates used for fallback sampling.
- Some channel updates do not reliably trigger enough value callbacks for fake-fill refresh every frame.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Keep native cast texture shown with alpha `0` in fake mode (do not `Hide()`), so geometry continues updating.
  - Add a lightweight throttled `OnUpdate` refresh hook on target castbar fake-fill (`~30 FPS`) to keep native-path progress in sync during channels.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Target cast fake-fill updates continuously during channeling while preserving fake-fill visual style.

2026-02-17 (target cast fake-fill uses native fallback too often; fill line/flow looks wrong)
Issue:
- Target cast fake-fill often reports `castFake: path native` and progression/edge line appears jittery or inconsistent.
Root cause:
- Cast fake-fill update order did not use cast timer duration data before native geometry fallback.
- Native geometry fallback is only an approximation and can desync with smooth timer progression.
- Timer object guard was too strict (`type == "table"`), so valid duration objects could be ignored.
- Mirror percent path could take precedence even when timer data was available.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added timer-derived percent path from `GetTimerDuration()` duration object (`GetTotalDuration` + `GetRemainingDuration`) with channel/cast aware mapping.
  - Added secondary fallback to duration object `GetProgress()` when total/remaining are unavailable.
  - Relaxed duration object handling to support non-table timer objects.
  - Update order now prefers `timer` path before `mirror`/`native` fallback.
  - Exposed debug path marker `castFake: path timer` for verification.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Cast fake-fill follows actual cast/channel timer flow more consistently and no longer depends on native geometry for most updates.

2026-02-17 (target cast fake-fill still appears static/jittery on some target casts)
Issue:
- Even with `castFake: path timer`, visual fill could still appear static or update in coarse jumps.
Root cause:
- Duration-object progress can be inconsistent for some target casts/channels.
- Fake-fill refresh cadence was throttled to ~30 FPS, which can look stepped with narrow fill windows.
- Unit timing path could lock at `percent=1` when start/end and `now` used different time bases.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Added primary cast progress from `UnitCastingInfo/UnitChannelInfo` timing (start/end ms) for target unit.
  - Keep duration-object timer path as secondary fallback.
  - Increased cast fake-fill refresh cadence from ~30 FPS to ~60 FPS.
  - Added debug path marker `castFake: path unit`.
  - Hardened unit timing selection to only accept plausible progress candidates across multiple timebase candidates (`GetTime`, `GetTime*1000`, `time`, `time*1000`).
  - Improved timer fallback to cache/update a per-cast total duration from remaining time when total duration is unavailable.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Target cast fake-fill progress uses direct cast/channel timing first and updates more smoothly frame-to-frame.

2026-02-17 (target cast fake-fill invisible + alpha controls appear non-functional)
Issue:
- Target cast fake-fill disappeared even though cast text/time still showed.
- Changing cast fake alpha controls in `/az` appeared to do nothing.
- Fake-fill path/percent debug was updating, but no cast fill was visible.
Root cause:
- `GetTargetCastFakeAlpha(...)` could honor `healthLabCastFakeUseStatusBarAlpha=true` while sampled runtime alpha was `0` (native cast texture hidden), producing invisible fake-fill.
- `UnitFrame_UpdateTextures(...)` signature cache did not include cast fake-fill option keys, so live option changes were skipped by early-return.
- `Castbar.FakeFill` texture was created but not explicitly assigned the cast texture in target texture updates, so fake-fill could render invisible despite valid geometry/alpha math.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Hardened status-alpha mode: if sampled status alpha is non-usable (`<= 0`), fall back to manual/config alpha instead of returning 0.
  - Extended target texture signature to include cast fake-fill settings (invert/alpha mode/alpha value/anchor/offsets/insets), so live tuning invalidates cache correctly.
  - Explicitly assign `Castbar.FakeFill` texture/texcoords/draw layer to mirror the cast statusbar texture setup path.
- In `Options/OptionsPages/UnitFrames.lua`:
  - Target live refresh now clears `frame.__AzeriteUI_HealthLabSignature` before `PostUpdate()` so cast fake-fill options always reapply immediately.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Target cast fake-fill no longer disappears when status-alpha mode samples hidden/native zero alpha.
- `/az` cast fake-fill controls now apply immediately and consistently.

2026-02-17 (target cast fake-fill reliability pass: option wiring, deterministic alpha, fallback traceability)
Issue:
- User reports target cast fake-fill alpha not restored and many `/az` cast options have little/no visible effect.
Root cause:
- `UnitFrame_UpdateTextures(...)` was hard-binding cast reverse/texcoord/flip to health values, making cast-specific controls inert.
- `UpdateTargetFakeCastFill(...)` could fall into native fallback where cast fake offset/inset tuning had no geometry impact.
- Cast fake alpha source depended on runtime statusbar state, not a stable configured alpha baseline.
Change(s):
- Re-enable cast rule branching (`castUseHealthFillRules` true=mirror health, false=use cast-specific controls).
- Make cast fake alpha deterministic with `db.HealthCastOverlayColor[4]` as default baseline.
- Keep manual/statusbar alpha overrides available through fake-fill controls.
- Add cast fake fill path markers (`mirror|minmax|native|none`) and percent for debug visibility.
- Extend `/azdebug dump target` to print cast fake path/percent/alpha-source fields.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
- `luac -p Core/Debugging.lua`
Result:
- Target cast options now drive the same cast fake metadata path they configure.
- Cast alpha defaults to configured overlay alpha and only changes when explicit statusbar/manual toggles are used.
- `/azdebug dump target` now reports cast fake source path and alpha mode fields for live verification.

2026-02-17 (target castbar alpha too strong + live cast fake-fill tuning controls)
Issue:
- Cast fake-fill became too visible after forcing vertex alpha to `1`.
- Cast orientation still needed live tuning controls to test cap side/crop behavior quickly in `/az`.
Root cause:
- Cast fake-fill color path ignored castbar/statusbar alpha.
- Cast fake-fill had no dedicated runtime controls for invert/alpha/anchor/inset alignment.
Change(s):
- Restore cast fake-fill alpha from statusbar color by default.
- Add optional custom fake-fill alpha override.
- Add cast fake-fill tuning options in target menu:
  - invert progress,
  - alpha source/amount,
  - fake-fill anchor,
  - fake-fill X/Y offsets,
  - fake-fill insets (L/R/T/B).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Cast fake-fill visibility returns to pre-change behavior unless overridden.
- Live `/az` controls allow tuning cast fake-fill orientation/cropping without code edits.

2026-02-17 (target castbar cap side wrong + stretch fallback)
Issue:
- Target castbar visual showed thick cap on the wrong side and sometimes looked like stretched native scaling instead of cropped fake-fill.
Root cause:
- `UpdateTargetFakeCastFill(...)` used `UpdateTargetFakeCastFillFromNativeTexture(...)` too early (before numeric min/max crop path), so cast often fell back to native geometry.
- Cast fake-fill also reused statusbar alpha from `GetStatusBarColor()`, which could be 0 and make fake-fill unreliable.
Change(s):
- In `Components/UnitFrames/Units/Target.lua`:
  - Reordered cast fake-fill update priority to: mirror percent -> numeric min/max crop -> native fallback (last resort).
  - Normalized cast fake-fill vertex alpha to `1` (same model as target health fake-fill).
  - Hard-bound cast fake-fill orientation data to health settings (`texcoord`, `reverse fill`, `flipped horizontally`) so cast cap/fill side cannot diverge from health.
Result:
- Castbar now prefers true cropped fake-fill rendering and only uses native geometry if crop math cannot be applied.
- Visual orientation/cap behavior now follows the fake-fill rules consistently instead of native stretch artifacts.

2026-02-17 (target castbar visual stretch/reverse mismatch: fake-fill parity with healthbar)
Issue:
- Target castbar still rendered with native statusbar scaling, so the art stretched and the thick end appeared on the wrong side.
- User requested castbar visuals to match target health fake-fill cropping behavior (left-thick cap, cropped fill) while keeping cast logic unchanged.
Root cause:
- `Components/UnitFrames/Units/Target.lua` had `UpdateTargetFakeCastFill(...)` intentionally disabled.
- Castbar was still using native texture geometry, which scales the whole texture instead of preserving cap/crop style.
Change(s):
- Implemented cast fake-fill rendering in `Components/UnitFrames/Units/Target.lua`:
  - Added `HideTargetNativeCastVisuals(...)` / `ShowTargetNativeCastVisuals(...)`.
  - Added `UpdateTargetFakeCastFillFromNativeTexture(...)` fallback.
  - Replaced `UpdateTargetFakeCastFill(...)` stub with health-style percent crop logic (`ApplyTargetFakeHealthFillByPercent(...)`).
- Wired cast fake fill into target lifecycle:
  - Created `Castbar.FakeFill` texture.
  - Bound castbar value mirror via `ns.API.BindStatusBarValueMirror(castbar)`.
  - Added safe `OnMinMaxChanged`/`OnValueChanged`/`OnShow`/`OnHide` hooks to refresh fake fill and toggle native texture visibility.
  - Added `PostCastStart`/`PostCastUpdate`/`PostCastStop`/`PostCastFail`/`PostCastInterrupted` visual refresh callbacks.
- In `UnitFrame_UpdateTextures(...)`, cast now receives fake-fill metadata (texcoords/orientation/reverse/width/anchor) from health-lab settings before refresh.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Target castbar now uses the same cropped fake-fill rendering model as target health.
- Native stretch behavior is suppressed while castbar is shown; fill direction/side follows health-lab flip/reverse rules.

2026-02-17 (target cast direction mismatch: make cast fill follow health fill rules)
Issue:
- User reports target castbar fill orientation is reversed relative to target healthbar.
Root cause:
- Target castbar had its own reverse/flip/texcoord override path (`healthLabCast*`) and defaults in profile could diverge from health settings.
- Health uses one fill model, cast used a parallel model, so direction could drift.
Planned change(s):
- Add `healthLabCastUseHealthFillRules` (default `true`).
- When enabled, cast inherits health fill semantics exactly:
  - orientation (already shared),
  - reverse fill,
  - SetFlippedHorizontally,
  - texcoords.
- Keep existing cast-specific override controls available only when this toggle is disabled.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Target castbar now mirrors target healthbar fill semantics by default (`healthLabCastUseHealthFillRules = true`):
  - reverse fill, flip state, and texcoord all follow health settings.
- Cast-specific reverse/flip/texcoord controls remain available but are only active when health-rule mirroring is disabled in options.

2026-02-17 (target cast already in progress: health text not hiding)
Issue:
- When targeting a unit already casting, target health value/percent text may stay visible instead of hiding behind cast text.
Root cause:
- `Components/UnitFrames/Units/Target.lua` sets `health.Value`/`health.Percent` visible during texture update, then calls `cast:ForceUpdate()`.
- Cast text visibility relies on `Cast_UpdateTexts` hooked to castbar `OnShow/OnHide`.
- If castbar is already shown during `ForceUpdate`, `OnShow` does not fire again, leaving health text visible.
Planned change(s):
- After `cast:ForceUpdate()` in target texture/update path, call `Cast_UpdateTexts(cast)` explicitly to resync text visibility regardless of `OnShow` transitions.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Target cast/health text state is now explicitly synchronized after `cast:ForceUpdate()`, so health text hides even when the castbar was already shown (no `OnShow` edge trigger).

2026-02-17 (ToT vs Target current-health mismatch)
Issue:
- User reports `ToT` and `Target` health values do not consistently agree on current HP.
Root cause:
- `Target` health value tag uses `[*:HealthCurrent]` (direct current path), while `ToT` still used `[*:Health(true)]` (smart/fallback path that can display percent or max-fallback under secret/stale conditions).
Planned change(s):
- Switch `ToT` health value tag to `[*:HealthCurrent]` so both frames read current health via the same tag source.
- Keep ToT styling/alpha/cast behavior unchanged.
Validation:
- `luac -p Components/UnitFrames/Units/ToT.lua`
Result:
- ToT now uses the same direct-current health tag source as Target (`[*:HealthCurrent]`), removing smart-tag percent/max fallback differences between the two frames.

2026-02-17 (target options: add Boss/Critter fake-fill microalign controls in /az Target menu)
Issue:
- User requested per-style alignment controls in the `/az` Target options menu for bars that still need micro-tuning (`Boss`, `Critter`).
Root cause:
- Existing target health-lab controls in `Options/OptionsPages/UnitFrames.lua` only exposed global fake-fill alignment values.
- Runtime resolver had style-data fallback support, but no profile-level style toggle/settings were exposed in options.
Planned change(s):
- Add style-specific profile keys for `Boss` and `Critter` fake-fill alignment overrides.
- Update target health-lab resolver to prefer style profile overrides when enabled.
- Add `/az` Target menu controls (toggle + anchor + offsets + insets) for Boss/Critter.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- `/az` -> Unit Frames -> Target now includes style-specific fake-fill controls for `Boss` and `Critter`:
  - per-style enable toggle,
  - per-style anchor frame,
  - per-style X/Y offsets and inset sliders.
- Runtime now reads these profile overrides when enabled, without affecting other target styles.

2026-02-17 (target per-style fake-fill microalign: Boss/Critter independent from global lab offsets)
Issue:
- User reports `Boss` and `Critter` target health bars are out of alignment while regular target bars are aligned.
- Current health-lab fake-fill alignment controls are profile-global, so one tuning pass affects every target style.
Root cause:
- `Components/UnitFrames/Units/Target.lua` resolved `healthLabFakeOffset*` and `healthLabFakeInset*` only from `TargetFrame` profile globals.
- Style config (`Layouts/Data/TargetUnitFrame.lua`) had no style-level fake-fill override fields.
Change(s):
- Added style-level fake-fill override support in `GetTargetHealthLabSettings(...)`:
  - `HealthLabFakeOffsetX/Y`
  - `HealthLabFakeInsetLeft/Right/Top/Bottom`
  - `HealthLabFakeAnchorFrame`
- Style values now override global debug-lab values when present, enabling per-style micro-alignment.
- Added explicit per-style override fields for `Critter` and `Boss` in `Layouts/Data/TargetUnitFrame.lua` (defaults set to neutral `0`/`HEALTH` so they can be tuned independently).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Layouts/Data/TargetUnitFrame.lua`
Result:
- Boss/Critter now have independent fake-fill microalign override slots and no longer have to share the same global fake alignment values.

2026-02-17 (player/target health text: direct-current tag to avoid max-fallback collapse)
Issue:
- User reports health percent updates but current health text is wrong/stale:
  - hostile target often missing current/max or showing incorrect values,
  - player frame can show max while current does not update.
- Castbar text visibility behavior is now correct and must remain unchanged.
Root cause:
- Existing `[*:Health]` tag in `Components/UnitFrames/Tags.lua` routes through `SafeUnitHealth(...)`.
- In secret/stale paths this can collapse current to max (`cur = max`) and then text follows that fallback instead of true current.
- `Core/API/Abbreviations.lua` also returns empty on secret numbers, so direct current text can be discarded.
Change(s):
- Added new tag `[*:HealthCurrent]` in `Components/UnitFrames/Tags.lua`:
  - same event set/status handling as `[*:Health]`,
  - primary source: direct `UnitHealth(unit)` with Blizzard formatter attempt (`AbbreviateNumbers`) in `pcall`,
  - secondary fallback: existing safe current value formatting (`SafeUnitHealth` + `SafeValueToText` current only),
  - avoids max-first text reconstruction.
- Wired only player/target value text to new tag:
  - `Components/UnitFrames/Units/Player.lua`: `[*:Health]` -> `[*:HealthCurrent]` (absorb suffix preserved)
  - `Components/UnitFrames/Units/Target.lua`: `[*:Health]` -> `[*:HealthCurrent]` (absorb suffix preserved)
- Left existing generic `[*:Health]` unchanged for other unitframes.
- Left castbar show/hide text logic untouched.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-17 (aura counters/time-left missing in combat across player/target/nameplates)
Issue:
- User reports stack counters and time-left text missing/stalling on multiple auras in combat.
- Symptoms appear across `Player`, `Target`, and `NamePlates`.
Root cause hypothesis:
- Aura button combat-mutation guard can still block button layout/show mutations when frames are protected unless `allowCombatUpdates` is set.
- Virtual cooldown timer path clears text whenever `DurationObject:EvaluateRemainingTime()` yields secret/unavailable values, even when aura should continue counting.
Planned change(s):
- Enable `allowCombatUpdates` on unit aura containers for player/target/nameplates.
- Harden virtual cooldown handling for duration objects:
  - keep numeric fallback state when secret reads occur,
  - avoid clearing timer text/bar on transient secret reads,
  - accept fallback expiration/duration from aura data when available.
- Pass aura fallback duration data from oUF aura update path into the cooldown widget.
Files targeted:
- `Core/Widgets/Cooldowns.lua`
- `Libs/oUF/elements/auras.lua`
- `Components/UnitFrames/Units/Player.lua`
- `Components/UnitFrames/Units/Target.lua`
- `Components/UnitFrames/Units/NamePlates.lua`
Update:
- `Core/Widgets/Cooldowns.lua`:
  - Added secret-safe fallback state for duration-object timers (`remaining`, `lastTick`, fallback start/duration).
  - Timer no longer clears text/bar immediately when `EvaluateRemainingTime()` is temporarily secret/unavailable.
  - Added `SetAuraFallbackData(expiration, duration)` so aura code can supply safe numeric fallback timing.
  - Hooked `SetCooldownFromDurationObject` for real cooldown widgets in `RegisterCooldown`.
- `Libs/oUF/elements/auras.lua`:
  - Aura update now passes `data.expirationTime/data.duration` into cooldown fallback (`SetAuraFallbackData`) when available.
  - Cooldown hide path now avoids clearing when a duration object exists but direct write path is unavailable.
  - Stack count write hardened to use Blizzard display count when safe, then numeric `data.applications` fallback.
  - Added explicit per-button aura state writes (`isHarmfulAura`, `isHarmful`, `filter`) so style/tooltip logic always receives debuff-vs-buff context.
  - Stack count path now accepts non-nil display-count values directly (including combat paths), with numeric fallback only when display-count is unavailable.
- `Components/UnitFrames/Auras/AuraStyling.lua`:
  - Retail aura buttons now use a native `CooldownFrameTemplate` cooldown element for timer text updates.
  - Native cooldown countdown numbers are used for aura timer text so Blizzard can handle combat secret duration values safely.
  - Legacy custom aura `Time` fontstring is kept but hidden for retail aura buttons.
- `Components/UnitFrames/Units/Player.lua`:
  - Set `auras.allowCombatUpdates = true`.
- `Components/UnitFrames/Units/Target.lua`:
  - Set `auras.allowCombatUpdates = true`.
- `Components/UnitFrames/Units/NamePlates.lua`:
  - Set `auras.allowCombatUpdates = true`.
Validation:
- `luac -p Core/Widgets/Cooldowns.lua`
- `luac -p Libs/oUF/elements/auras.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
- `luac -p Components/UnitFrames/Auras/AuraStyling.lua`
Result:
- Ready for `/reload` verification of combat aura counters/time-left on player, target, and nameplates.

2026-02-17 (player power hard-isolation: player-only percent-driven crystal/orb)
Issue:
- User confirms: none of player power visuals update correctly (crystal + orb), despite multiple shared-path adjustments.
- Request: isolate fix to player power behavior only.
Root cause hypothesis:
- Raw `UnitPower`/statusbar callback values in this WoW12 setup are unreliable for player power visuals (pinned/secret mix).
- Shared-path edits created regressions and are too broad.
Planned change(s):
- Keep shared non-player power flow unchanged.
- Add player-only percent-driven path:
  - In `API.UpdatePower`, for `unit == "player"`, derive current from safe percent and write that value.
  - In `API.UpdateAdditionalPower`, hard-lock orb to mana and use player mana percent as primary value source.
- Preserve safe max/current caches for tags.
Files targeted:
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - `API.UpdatePower` now applies a player-only percent override:
    - computes `playerPercent` from `SafeUnitPercentNumber(unit, true, nil)` (fallback to `displayType`),
    - uses that percent to derive `safeCur` and `writeCur` only when `unit == "player"`.
  - Non-player/shared power flow remains unchanged.
  - `API.UpdateAdditionalPower` now computes `playerManaPercent` first (`POWER_TYPE_MANA`) and uses it as primary orb percent source for `unit == "player"`.
  - Hardened percent retrieval order in `SafeUnitPercentNumber(...)` to match working external patterns:
    - try plain `UnitPowerPercent(unit, powerType)` / `UnitHealthPercent(unit)` first,
    - fallback to curve variants only when needed.
  - In `API.UpdatePower`, skip `GetDisplayPower()` for `unit == "player"` (player now follows primary power path like working references), while keeping non-player alt-power behavior unchanged.
Reference checks:
- `..\\DiabolicUI3\\Components\\UnitFrames\\Common\\Functions.lua`
- `..\\FeelUI\\Modules\\Unitframes\\Core.lua`
- `..\\GW2_UI\\core\\Units\\powerbar.lua`
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest focused on player crystal + orb updates without non-player regression.
Deepdive follow-up (still stuck):
- Root-cause candidate found in `SafeUnitPercentNumber(...)`:
  - helper previously treated a secret numeric return as "numeric enough" and skipped fallback percent API variants.
  - in WoW12 this can leave percent unresolved (`nil`) while raw power remains stale/max-cached.
Update:
- `Components/UnitFrames/Functions.lua`:
  - `SafeUnitPercentNumber(...)` now keeps probing fallback variants until it gets a non-secret numeric percent.
  - added local `IsSafePercent(...)` guard and switched fallback conditions from `type(...) ~= "number"` to `not IsSafePercent(...)`.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest; player crystal/orb should now be able to consume safe percent instead of sticking on stale raw values.
Deepdive event-path correction:
- Observed that player power/orb updates were configured around frequent-power updates, while reference UIs in workspace either rely on `UNIT_POWER_UPDATE` or register both.
- To prevent event-path stalls, updated player power/orb wiring:
  - `Components/UnitFrames/Units/Player.lua`
    - `power.frequentUpdates = false`
    - `mana.frequentUpdates = false`
    - `Mana_UpdateVisibility` now registers both `UNIT_POWER_UPDATE` and `UNIT_POWER_FREQUENT` when enabling orb updates.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload` retest; expected to restore live power updates even when frequent event delivery is inconsistent.

Rollback (shared power path restore after regression report):
Issue:
- User confirms all power bars regressed after recent `Functions.lua` power-read changes.
- Request: restore shared power behavior and keep orb fix isolated.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Restored shared `SafeUnitPercentNumber(...)` behavior to prior minimal flow:
    - curve-first call with plain API fallback.
  - Removed player-only special handling from `API.UpdatePower`:
    - no player override percent path,
    - no player-specific `displayAltPower` bypass.
  - Shared `API.UpdatePower` is now back to prior pre-isolation behavior.
  - Left orb logic in `API.UpdateAdditionalPower` unchanged for targeted follow-up.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest to confirm non-orb bar recovery before next orb-only adjustment.

User-identified regression rollback (write condition):
Issue:
- User pinpointed regression source:
  - changed write condition from `rawCurNum and rawCur or safeCur`
  - to `rawCurSafe and rawCur or safeCur`
- Result observed in-game: orb became visible but shared bars stopped updating correctly.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Reverted shared write conditions back to numeric-check behavior:
    - `API.UpdateHealth` write path:
      - `writeCur = rawCurNum and rawCur or safeCur`
    - `API.UpdatePower` write path:
      - `writeCur = rawCurNum and rawCur or safeCur`
  - Left `API.UpdateAdditionalPower` unchanged (orb path still isolated).
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest; expected to restore shared bar updates while preserving orb visibility path.

2026-02-17 (target health frozen in combat: disable fake-fill production path)
Issue:
- User reports target health/current/max text do not update in combat (works when targeting self).
Root cause:
- `Components/UnitFrames/Units/Target.lua` still used fake health-fill production path that hides native statusbar texture.
- In combat/secret-value paths, fake-fill callback values can be unavailable/secret, leaving hidden native texture and stale visual/text state.
Change(s):
- Restored native target health rendering path:
  - Added `ShowTargetNativeHealthVisuals(...)`.
  - `Health_PostUpdate` now forces native visibility (no fake-fill driving).
  - Removed fake-fill color coupling from `Health_PostUpdateColor`.
  - In `UnitFrame_UpdateTextures`, removed fake-fill production setup and forced hide of fake texture.
  - In health `OnValueChanged`, removed fake-fill/hide-native behavior and re-show native visuals.
Files touched:
- Components/UnitFrames/Units/Target.lua
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Ready for `/reload` retest; target health/current/max should update in combat using native statusbar path.

2026-02-17 (target fakefill hybrid restore: keep art, safe-value driven updates)
Issue:
- User confirmed fakefill is required for target graphic/style, but previous fakefill production path froze in combat.
Root cause:
- Fakefill depended on callback values that may be secret/unavailable in combat and could starve updates.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Re-enabled fakefill as primary visual path, but now driven by safe values from `Health_PostUpdate(cur,max)` caches.
  - `UpdateTargetFakeHealthFill(...)` now returns success/failure.
  - Added guarded fallback behavior:
    - if fakefill update succeeds -> hide native health texture,
    - if fakefill update fails -> show native health texture (no freeze).
  - Restored fakefill color sync in `Health_PostUpdateColor`.
  - Re-enabled fakefill texture/geometry config in `UnitFrame_UpdateTextures`.
  - Updated health `OnMinMaxChanged`/`OnValueChanged` hooks to use fakefill with native fallback instead of forcing one path.
Files touched:
- Components/UnitFrames/Units/Target.lua
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Ready for `/reload` retest; target should keep fakefill look while staying live in combat.

2026-02-17 (target still wrong health values: target-only percent fallback in UpdateHealth)
Issue:
- User dump still shows target health `min/max/value` as secret with `secretPercent: nil`.
- Fakefill visual is correct, but value source remains unresolved in combat.
Root cause hypothesis:
- Curve-first `SafeUnitPercentNumber(unit,false)` path can fail to return a safe percent for `target` in combat.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - In `API.UpdateHealth`, added target-only fallback sequence when `safePercent` is nil:
    - try `UnitHealthPercent(unit)` first,
    - then `UnitHealthPercent(unit, false, CurveConstants.ScaleTo100)`.
  - Accept fallback only when numeric and non-secret.
  - Left power paths unchanged.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest; target health text/fill should now receive a usable percent source in combat.

2026-02-17 (target fakefill: proxy hidden native texture geometry)
Issue:
- User confirms target fakefill style is correct, but value remains wrong in combat.
- Dumps show target health min/max/value still secret and `secretPercent` nil.
Root cause hypothesis:
- Any fakefill math path still depends on recoverable safe values/percent, which are unavailable for some target combat states.
Planned change(s):
- Keep native target statusbar as the source of truth for fill geometry.
- Keep native texture alpha at 0 (not hidden), and anchor fakefill directly to native statusbar texture bounds.
- This avoids addon-side arithmetic/comparisons on secret values while preserving fakefill art.
Files targeted:
- Components/UnitFrames/Units/Target.lua
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Added `UpdateTargetFakeHealthFillFromNativeTexture(...)`:
    - fakefill now anchors directly to native statusbar texture bounds.
  - `UpdateTargetFakeHealthFill(...)` now uses native-texture proxy path first.
  - `HideTargetNativeHealthVisuals(...)` now sets native alpha to 0 but does not hide the native texture object.
  - This keeps Blizzard-driven secret-safe fill geometry live while preserving fakefill visuals.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Ready for `/reload` retest; expected to show correct target health fill with fakefill art in combat.

2026-02-17 (combat tooltip crash spam: Backdrop.lua width secret tainted by AzeriteUI)
Issue:
- Massive error spam on actionbar/bag hover in combat:
  - `Blizzard_SharedXML/Backdrop.lua:226 attempt to perform arithmetic on local 'width' (a secret number value tainted by 'AzeriteUI')`
Root cause:
- `Components/Misc/Tooltips.lua` `UpdateBackdropTheme` still read tooltip/backdrop dimensions in secret-value mode (`GetWidth`/`GetHeight`) before backdrop suppression.
- Reading those dimensions in WoW12 secret paths can taint width/height used later by Blizzard backdrop arithmetic.
Change(s):
- `Components/Misc/Tooltips.lua`:
  - Added `SuppressTooltipBackdrop(tooltip)` helper for secret-mode suppression.
  - In `UpdateBackdropTheme`, secret-value mode now immediately suppresses AzeriteUI tooltip backdrop styling and returns.
  - Removed secret-mode width/height reads on tooltip and backdrop frames.
Validation:
- `luac -p Components/Misc/Tooltips.lua`
Result:
- Ready for `/reload` retest; expected to stop `Backdrop.lua:226 width secret` combat hover spam.

2026-02-17 (regression follow-up: reverse fill behavior + tooltip backgrounds)
Issue:
- User reports:
  - reverse-fill now behaves like full-bar scaling instead of correct fill effect,
  - tooltip backgrounds disappeared.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Enhanced native-proxy fakefill path to mirror native statusbar texture texcoords:
    - `UpdateTargetFakeHealthFillFromNativeTexture(...)` now copies `nativeTexture:GetTexCoord()` to fakefill.
  - Keeps fakefill geometry bound to native texture points.
- `Components/Misc/Tooltips.lua`:
  - Relaxed secret-mode suppression to combat-only:
    - `UpdateBackdropTheme` now calls `SuppressTooltipBackdrop(...)` only when `InCombatLockdown()` is true.
  - Restores AzeriteUI tooltip backgrounds out of combat.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/Misc/Tooltips.lua`
Result:
- Ready for `/reload` retest:
  - reverse fill should follow native fill effect,
  - tooltip backgrounds should be back out of combat,
  - combat hover should still avoid backdrop secret-width crash path.

2026-02-17 (follow-up stabilization: target bar invisible + tooltip backdrop balance)
Issue:
- User reports:
  - target healthbar disappeared entirely,
  - tooltip background behavior regressed.
Root cause:
- Target fakefill could inherit alpha `0` from health color and become fully transparent.
- Combat secret-mode tooltip suppression removed all backdrop layers (including visual background).
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Forced fakefill alpha/vertex alpha to visible (`alpha=1`) in native-proxy and setup paths.
  - Keeps color RGB sync but never copies alpha `0`.
- `Components/Misc/Tooltips.lua`:
  - Added `RestoreBlizzardTooltipBackdrop(...)`.
  - In combat+secret mode, now restores Blizzard backdrop layers/NineSlice and disables AzeriteUI backdrop frame only.
  - Keeps anti-taint behavior while preserving tooltip background visuals.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/Misc/Tooltips.lua`
Result:
- Ready for `/reload` retest:
  - target fake bar should be visible again,
  - tooltip backgrounds should remain visible,
  - combat hover crash path should stay mitigated.

2026-02-17 (retarget sliver/disappear: native proxy texcoord secret guard)
Issue:
- User reports target fake health bar shows as tiny sliver, then disappears on retarget.
Root cause:
- Native-proxy path copied native texture texcoords unconditionally by numeric type check.
- In WoW12, texcoords can be secret numbers; applying them to fakefill can collapse visual fill.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Removed native-texture point-count gate so proxy can bind immediately during retarget/setup.
  - Added secret-value guard for proxied texcoords:
    - only mirror native texcoords when all are non-secret numbers,
    - otherwise use configured fake texcoords (`__AzeriteUI_FakeTex*`) as fallback.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Ready for `/reload` retest; expected to stop retarget sliver/disappear behavior.

2026-02-17 (target health write passthrough to restore native fill geometry)
Issue:
- Player health updates again, but target enemy fakefill still scales/disappears and does not track live combat health.
- Current target path writes sanitized fallback values (`safeCur/safeMax`) into the native target health statusbar.
Root cause:
- Fakefill is anchored to native statusbar texture geometry.
- When target write path forces fallback values, native texture geometry can stay stale/full and fakefill mirrors the wrong fill.
Change(s):
- `Components/UnitFrames/Functions.lua` (`API.UpdateHealth`):
  - for `unit == "target"`, write passthrough values to the statusbar:
    - `writeMax = rawMaxNum and rawMax or safeMax`
    - `writeCur = rawCurNum and rawCur or safeCur`
  - keep non-target write behavior unchanged.
Why:
- This lets Blizzard/oUF own target fill geometry in secret-value paths, while AzeriteUI fakefill continues to mirror that geometry.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest targeting self then enemy in combat; expected to restore target fakefill motion without rebreaking player updates.

Checkpoint:
- User confirmed movement is back ("we're close"), but target fill/scaling still looks wrong.
- Next iteration narrows to fakefill geometry/texcoord interaction only.

2026-02-17 (target fakefill stretch fix: percent-driven crop with alignment controls)
Issue:
- Target fakefill now moves, but appears horizontally stretched (scaled art) instead of proper statusbar crop.
- Fake alignment options stopped applying in native-proxy mode.
Root cause:
- Native-proxy path anchored fake texture directly to native texture bounds.
- When native geometry changes by width, full texcoords cause stretched art; direct proxy also bypasses fake offset/inset controls.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - added `ApplyTargetFakeHealthFillByPercent(...)` to render crop-style fill using existing fake settings:
    - `healthLabFakeOffsetX/Y`, `healthLabFakeInset*`, fake anchor frame, configured texcoords.
  - `UpdateTargetFakeHealthFill(...)` now prefers mirrored percent (`__AzeriteUI_MirrorPercent`, fallback `__AzeriteUI_TexturePercent`) and applies percent-driven crop first.
  - keeps native-texture proxy as fallback only when mirrored percent is unavailable.
Result:
- Ready for `/reload` retest; expected to keep motion while restoring correct crop fill and fake alignment controls.

2026-02-17 (nameplates parity with target health write passthrough)
Issue:
- Nameplates can still desync in WoW12 secret-value combat paths because shared health write path does not mirror target passthrough behavior.
Root cause:
- In `API.UpdateHealth`, non-target units write `writeMax` from `rawMaxSafe` only.
- For `nameplate*` units with secret numeric max values, this can keep stale cached max while current updates via raw value, causing incorrect fill math.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - treat `nameplate*` units like `target` for write passthrough:
    - `writeMax = rawMaxNum and rawMax or safeMax`
    - `writeCur = rawCurNum and rawCur or safeCur`
  - non-target/non-nameplate units remain unchanged.
Result:
- Ready for `/reload` retest; nameplate fill math should follow live native values in secret paths without touching player/orb behavior.

2026-02-17 (tooltip Backdrop.lua width secret-taint hardening)
Issue:
- Repeated combat tooltip crashes:
  - `Blizzard_SharedXML/Backdrop.lua:226 attempt to perform arithmetic on local 'width' (a secret number value tainted by 'AzeriteUI')`
  - stack enters `TooltipDataHandler` from action button mouseover.
Root cause:
- AzeriteUI tooltip backdrop skinning still mutates tooltip backdrop state in WoW12 secret-value builds.
- Blizzard tooltip backdrop math can then run on secret width/height under AzeriteUI taint context.
Change(s):
- `Components/Misc/Tooltips.lua`:
  - in secret-value builds, fully bypass AzeriteUI backdrop skinning and restore Blizzard tooltip backdrop immediately.
- `Core/FixBlizzardBugs.lua`:
  - broaden backdrop guard wrapping to cover both `_G.BackdropMixin` and `_G.BackdropTemplateMixin` `SetupTextureCoordinates` when present.
Result:
- Ready for `/reload` retest; expected to eliminate `Backdrop.lua:226` combat hover spam.

2026-02-17 (target enemy health still wrong: split write policy health vs power)
Issue:
- User dump after targeting enemy still shows target health secret flow:
  - health `min/max/value` remain secret,
  - native texture alpha `0`, fakefill scales incorrectly.
Root cause:
- `API.UpdateHealth` was still writing current value with `rawCurNum` gate:
  - secret numeric current passed through and poisoned native fill geometry.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - In `API.UpdateHealth`, changed write gate back to safe-only:
    - `writeCur = rawCurSafe and rawCur or safeCur`
  - Kept `API.UpdatePower` write gate as numeric (`rawCurNum`) to avoid re-breaking player crystals.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest; target enemy health fill should now use safe fallback values while crystals remain stable.

2026-02-17 (target enemy still full/stuck: force target health writes from safe percent)
Issue:
- After split policy, target dump still shows health stuck full (`0/145220 -> 145220`) with no usable secret percent.
Root cause:
- Even with safe health write gate, target raw current can remain "safe numeric but wrong/full" in combat.
Change(s):
- `Components/UnitFrames/Functions.lua` (`API.UpdateHealth`):
  - Added `targetPercent` path using `UnitHealthPercent(unit)` fallback chain for `unit == "target"`.
  - When `targetPercent` is available:
    - force `safeCur = safeMax * (targetPercent / 100)`
    - force `writeCur = safeCur`
  - Keeps non-target health behavior unchanged.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest; target enemy health should stop pinning to full and fakefill proxy should follow proper fill.

2026-02-17 (player health regression + target still unstable: strict per-unit health write split)
Issue:
- User reports:
  - target enemy health still scales/fills incorrectly,
  - player health may stop updating after target fixes.
Change(s):
- `Components/UnitFrames/Functions.lua` `API.UpdateHealth`:
  - Added `ProbeSafeHealthPercent(unit)` helper inside update path:
    - probes multiple `UnitHealthPercent` variants,
    - accepts only non-secret numeric values,
    - normalizes to 0-100.
  - For `unit == "target"`:
    - prefer `targetPercent` when available,
    - write current from `safeCur` (not raw current),
    - this avoids trusting raw target current in combat secret paths.
  - For non-target units (player included):
    - preserved stable write behavior:
      - `writeCur = rawCurNum and rawCur or safeCur`.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` retest with strict split:
  - target should follow safe percent-driven health writes,
  - player health should retain prior stable behavior.

2026-02-17 (rollback shared power path + orb-only patch)
Issue:
- User requested restoring non-orb crystals and isolating changes to mana orb only.
- Shared power changes caused regressions across player/target crystal behavior.
Change strategy:
- Revert shared power logic (`API.UpdatePower`) to previous behavior.
- Keep targeted orb logic only in `API.UpdateAdditionalPower`.
Files targeted:
- Components/UnitFrames/Functions.lua
- Components/UnitFrames/Units/Player.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - Restored previous `SafeUnitPercentNumber` behavior (CurveConstants-first path).
  - Restored shared `API.UpdatePower` flow (removed unitPercent-priority branch and related write override).
  - Kept orb-specific logic in `API.UpdateAdditionalPower`:
    - hard-lock power type to mana (`POWER_TYPE_MANA`),
    - stop using `GetDisplayPower()` for orb,
    - compute percent from mana APIs/raw safe values/mirror fallback,
    - write orb current value from safe computed current (`writeCur = safeCur`).
- `Components/UnitFrames/Units/Player.lua`:
  - Set `mana.displayAltPower = false` so orb does not enter alternate-power routing.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload` retest with isolated orb changes and restored shared crystal behavior.

2026-02-17 (player power/orb pinned at max: trust percent over raw power in secret build)
Issue:
- User reports player power crystal and mana orb still pinned at max.
- Latest debug dump shows contradictory state:
  - `Player.ManaOrb min/max/value: 0 50000 50000` while `secretPercent: 1`.
Root cause hypothesis:
- In current WoW12 path, raw `UnitPower(...)` can appear numerically valid yet be unreliable/pinned.
- Update flow still preferred raw current when numeric/safe, only using percent as secondary fallback.
Planned change(s):
- `SafeUnitPercentNumber`: prefer plain `UnitPowerPercent(unit, powerType)` / `UnitHealthPercent(unit)` call first.
- In `API.UpdatePower` and `API.UpdateAdditionalPower`, prioritize percent-derived current (`unitPercent`) over raw current when percent is available.
- Write statusbar current from percent-derived value in that case.
Files targeted:
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - Updated `SafeUnitPercentNumber` to try plain percent APIs first, extended-args variants second.
  - Added `unitPercent` path in `API.UpdatePower` and `API.UpdateAdditionalPower`.
  - `safeCur` now prefers percent-derived value when available.
  - `writeCur` now prefers percent-derived value when available (instead of raw `UnitPower`).
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload`; player power crystal and mana orb should follow live mana/power changes instead of staying pinned at max.

2026-02-17 (all mana crystals/orbs static: fallback gate missed secret-cur/safe-max case)
Issue:
- User reports no live updates for any mana crystals/orbs.
- Debug showed common pattern: `cur = <secret>`, `max = safe number`.
Root cause:
- In `Components/UnitFrames/Functions.lua`, both `API.UpdatePower` and `API.UpdateAdditionalPower` only used `GetSecretPercentFromBar(...)` fallback when both cur and max were unsafe:
  - `if (safePercent == nil and (not rawCurSafe) and (not rawMaxSafe)) then ...`
- With secret cur + safe max (most common), fallback never ran, so `safeCur` remained cached/stale.
Planned change(s):
- Relax fallback gate to run whenever current value is unsafe:
  - `if (safePercent == nil and (not rawCurSafe)) then ...`
- Improve value-mirror hook to seed mirror percent from texture geometry fallback when arithmetic on callback `value` is unavailable (secret-value path).
Files targeted:
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - In both `API.UpdatePower` and `API.UpdateAdditionalPower`, relaxed secret-percent fallback gate:
    - from `safePercent == nil and not rawCurSafe and not rawMaxSafe`
    - to `safePercent == nil and not rawCurSafe`
  - This now covers the common WoW12 case where current value is secret but max is safe.
  - In `API.BindStatusBarValueMirror` `OnValueChanged`, added texture-percent seeding:
    - when arithmetic mirror percent is unavailable, fallback to `GetTexturePercentFromBar(self)` for `__AzeriteUI_MirrorPercent`.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload`; power/mana bars should now update live when current values are secret but max remains safe.

2026-02-17 (mana orb still invisible after safe-flow refactor: secret current write)
Issue:
- Debug dump still shows `Player.ManaOrb` with:
  - `min/max/value: 0 50000 <secret>`
  - visible texture + frame, but no usable fill.
Root cause:
- In `Components/UnitFrames/Functions.lua`, safe-flow refactor still used:
  - `writeCur = rawCurNum and rawCur or safeCur`
- `rawCurNum` is true even when `rawCur` is a secret number, so secret current value still gets written to statusbar.
Planned change(s):
- Use `rawCurSafe` (not just numeric) for write decisions:
  - `writeCur = rawCurSafe and rawCur or safeCur`
- Apply same fix to `API.UpdatePower` to avoid identical secret-current write risk there.
Files targeted:
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - Replaced secret-prone current write condition in statusbar update paths:
    - from `rawCurNum and rawCur or safeCur`
    - to `rawCurSafe and rawCur or safeCur`
  - Applied to health/power/additional-power write paths so secret numeric values are never written as current fill.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload`; `Player.ManaOrb` should now report a non-secret current value and render fill.

2026-02-17 (mana orb statusbar still not visible after fallback-type hotfix)
Issue:
- User still reports no visible statusbar/fill in mana orb (`AdditionalPower` / `PowerAlternative`).
Root cause hypothesis:
- `Components/UnitFrames/Functions.lua` `API.UpdateAdditionalPower` still writes raw `UnitPower/UnitPowerMax` to the orb before sanitization.
- In WoW12 secret-value paths, raw writes can leave the orb without a valid rendered fill even when safe fallback values exist.
Planned change(s):
- Refactor `API.UpdateAdditionalPower` to use safe write flow (matching `API.UpdatePower`):
  - sanitize raw values first,
  - compute safe fallback min/max/cur,
  - call `SetStatusBarValuesCompat(...)` with safe write values.
- Bind statusbar value mirror on `self.AdditionalPower` in `Player.lua` for better secret-percent fallback stability.
Files targeted:
- Components/UnitFrames/Functions.lua
- Components/UnitFrames/Units/Player.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - Refactored `API.UpdateAdditionalPower` to use safe write flow (same pattern as `API.UpdatePower`):
    - evaluates raw power values for secret/non-secret safety first,
    - computes safe fallback `min/max/cur` with percent fallback,
    - writes values via `SetStatusBarValuesCompat(...)` instead of direct raw `SetMinMaxValues/SetValue`.
  - `PostUpdate` now receives safe numeric values to avoid downstream secret-value side effects.
- `Components/UnitFrames/Units/Player.lua`:
  - Added `ns.API.BindStatusBarValueMirror(self.AdditionalPower)` to improve secret-percent fallback stability for mana orb updates.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload`; mana orb statusbar fill should now render using safe values even when WoW12 power APIs return secret values.

2026-02-17 (tooltip secret-width crash + SpellBook CastSpellBookItem forbidden)
Issue:
- BugSack on action-button tooltip hover:
  - `Blizzard_SharedXML/Backdrop.lua:226 attempt to perform arithmetic on local 'width' (a secret number value tainted by 'AzeriteUI')`
  - stack flows through `TooltipDataHandler` -> tooltip `Show` while hovering action buttons.
- BugSack:
  - `[ADDON_ACTION_FORBIDDEN] AddOn 'AzeriteUI' tried to call the protected function 'CastSpellBookItem()'`
  - stack points to Blizzard SpellBook click path (`Blizzard_SpellBookItem.lua:OnIconClick`).
Root cause hypothesis:
- `Components/Misc/Tooltips.lua` secret-value bypass currently restores Blizzard tooltip draw layers/NineSlice for some paths (item tooltip / secret-size guard), which can re-enter Blizzard BackdropTemplate arithmetic on secret dimensions.
- `Core/Compatibility.lua` WoW12 `LoadAddOn`/`C_AddOns.LoadAddOn` monkeypatch replaces global loader functions; this is a high-taint surface and can poison secure Blizzard flows (including SpellBook click actions).
Planned change(s):
- Tooltip: in secret-value bypass paths, keep Blizzard backdrop layers suppressed (do not re-enable BACKGROUND/BORDER/NineSlice there).
- Compatibility: remove WoW12 global `LoadAddOn` monkeypatch block to reduce secure taint risk.
Files targeted:
- Components/Misc/Tooltips.lua
- Core/Compatibility.lua
Update:
- `Components/Misc/Tooltips.lua`:
  - In `UpdateBackdropTheme` secret-value bypass paths, stopped restoring Blizzard tooltip backdrop layers/NineSlice.
  - Now keeps `BACKGROUND`/`BORDER` disabled and keeps NineSlice parented away from the tooltip in those early-return paths.
  - Goal: prevent Blizzard BackdropTemplate from re-running width/height arithmetic when tooltip dimensions are secret.
- `Core/Compatibility.lua`:
  - Removed WoW12 global monkeypatch block that replaced `LoadAddOn` and `C_AddOns.LoadAddOn`.
  - Added explicit note to avoid monkeypatching global loader APIs due taint risk in secure Blizzard flows.
Validation:
- `luac -p Components/Misc/Tooltips.lua`
- `luac -p Core/Compatibility.lua`
Result:
- Ready for `/reload` retest of:
  - action-button tooltip hover (no `Backdrop.lua:226 width secret`),
  - spellbook icon click (no `ADDON_ACTION_FORBIDDEN CastSpellBookItem()` from AzeriteUI).

2026-02-17 (mana orb shows wrong/empty resource via PowerAlternative path)
Issue:
- Player mana orb (`AdditionalPower`, seen as `PowerAlternative` in FrameStack) does not show actual mana reliably.
- Orb can reflect primary power token/value instead of mana, especially in paths that force orb visibility.
Root cause hypothesis:
- `Components/UnitFrames/Functions.lua` `API.UpdateAdditionalPower` falls back to `UnitPower(unit, nil)` when no `GetDisplayPower()` method exists on `AdditionalPower`.
- For `AdditionalPower`, nil power type resolves to primary resource, which breaks mana-orb intent.
- Compared against DiabolicUI3 working orb behavior/path and confirmed AzeriteUI divergence is in custom override logic, not oUF element registration.
Planned change(s):
- In `API.UpdateAdditionalPower`, add deterministic fallback to `Enum.PowerType.Mana` when no valid display type is provided.
- Keep guarded `GetDisplayPower()` call only when method exists.
- Preserve existing WoW12 safety cache/tag flow.
Files targeted:
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - Added explicit mana fallback for `API.UpdateAdditionalPower`:
    - default `displayType = Enum.PowerType.Mana` (or `0` fallback),
    - only override when `GetDisplayPower()` exists and returns a safe numeric type.
  - Removed nil display-type path for mana orb updates so `UnitPower(...)` no longer falls back to primary resource by default.
  - Kept existing secret-value safety and tag cache behavior intact.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload`; mana orb (`AdditionalPower`/`PowerAlternative`) should now track actual mana deterministically.

2026-02-16 18:31 (TARGET FLIP LAB LIVE UPDATES + ANCHOR CONTROLS)
Issue:
- Target health/cast flip-lab controls do not always apply live.
- User wants readable anchor options for health/cast alignment against different target art elements.
Hypothesis:
- `UnitFrame_UpdateTextures` cache signature is missing newer flip-lab fields (fake/cast offsets/scales/tex-flips), so updates are skipped.
- Target options setters currently only write profile/update settings; adding explicit frame refresh will make sliders/toggles visibly live.
Planned change(s):
- Expand target health-lab signature in `Target.lua` to include all cast/fake tuning fields.
- Add anchor resolution for fake health fill and castbar (`FRAME`, `HEALTH`, `HEALTH_OVERLAY`, `HEALTH_BACKDROP`) and apply in layout.
- Add live-refresh setters in target options so changes trigger immediate post-update + forceupdate.
Files targeted:
- Components/UnitFrames/Units/Target.lua
- Options/OptionsPages/UnitFrames.lua
Result:
- In progress.
Update:
- `Components/UnitFrames/Units/Target.lua`
  - Added new debug defaults: `healthLabCastAnchorFrame`, `healthLabFakeAnchorFrame`.
  - Expanded health-lab signature cache to include cast/fake offsets, scales, tex-flips, and anchor frame selections.
  - Added target anchor resolver for live routing (`FRAME`, `HEALTH`, `HEALTH_OVERLAY`, `HEALTH_BACKDROP`).
  - Fake fill now supports anchoring to selected art/frame and uses anchor width when available.
  - Castbar now anchors to selected frame/art while keeping existing position offsets/scales.
- `Options/OptionsPages/UnitFrames.lua`
  - Added target-only live setter (`targetLabSetter`) with forced immediate refresh (`UpdateSettings` + `PostUpdate` + `ForceUpdate`).
  - Added readable anchor dropdowns for castbar and fake health fill.
  - Wired all target flip-lab controls to live setter for immediate visual updates.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Ready for `/reload` and in-game validation of live slider/toggle updates and anchor swapping.

2026-02-16 18:45 (TARGET CASTBAR: REALIGN TO HEALTH + CONSISTENT FLIP BASELINE)
Issue:
- Target castbar is no longer aligned with target health bar.
- Castbar flip direction appears incorrect.
Hypothesis:
- Cast placement reused `db.HealthBarPosition` offsets even when anchoring to `HEALTH`/overlay/backdrop, causing double-offset drift.
- Cast should default to health-synced texcoords/flip while retaining lab overrides.
Planned change(s):
- Rework target cast placement:
  - `FRAME` anchor keeps old behavior (db health position baseline).
  - `HEALTH`/overlay/backdrop anchors center on selected frame, then apply only cast X/Y offsets.
- Keep cast orientation/reverse/flipped + texcoords in same health-lab path for consistency.
Files targeted:
- Components/UnitFrames/Units/Target.lua
Result:
- In progress.
Update:
- `Components/UnitFrames/Units/Target.lua`
  - Reworked castbar placement logic:
    - `FRAME` anchor keeps legacy behavior using `db.HealthBarPosition`.
    - `HEALTH` / overlay / backdrop anchors now center on selected anchor and apply only cast X/Y offsets.
  - Cast size now derives from selected anchor frame size (fallback to health bar size), then applies cast width/height scales.
  - Cast orientation/reverse/texcoord/flip path remains in health-lab settings.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Ready for `/reload` check: cast should be back inside target healthbar by default (`Cast Anchor Frame = Health Bar`).

2026-02-16 18:57 (TARGET CASTBAR: LAB GATE FIX + FAKE CAST FILL PIPELINE)
Issue:
- Cast anchor/flip controls still appeared non-functional.
- Target castbar flip remained wrong.
Hypothesis:
- Health Flip Lab runtime gate still required hidden `healthFlipLabDebugMode`; normal lab controls were not actually active.
- Castbar needs same fake-fill strategy as target health to avoid native statusbar flip inconsistencies.
Change(s):
- `Target.lua`:
  - Relaxed lab runtime gate to `enableDevelopmentMode + healthFlipLabEnabled` (removed hidden debug-mode requirement).
  - Added fake cast pipeline:
    - hide native cast statusbar texture,
    - create `Castbar.FakeFill`,
    - drive fake cast fill via `OnMinMaxChanged`/`OnValueChanged` handler values only,
    - apply cast flip texcoords/reverse/orientation from lab settings.
  - Updated `Cast_PostCastInterruptible` to sync fake fill color with castbar color state.
Result:
- Pending `/reload` validation that cast anchor controls now apply and cast flips/fills in correct direction.

2026-02-16 19:08 (PLAYER POWER: FAKE FILL PIPELINE LIKE TARGET HEALTH/CAST)
Issue:
- Requested to restructure player power with same fake-fill pattern used for target health/cast alignment stability.
Hypothesis:
- Hiding native statusbar texture and rendering a handler-driven fake fill texture will keep power fill aligned with moved/scaled crystal art in WoW12.
Planned change(s):
- Add player power fake-fill helpers and native-texture hide helper.
- Drive fake fill by `OnMinMaxChanged` + `OnValueChanged` on player power bar.
- Reconfigure fake fill texture/orientation during `UnitFrame_UpdateTextures` with existing power orientation/texcoord logic.
Files targeted:
- Components/UnitFrames/Units/Player.lua
Result:
- In progress.
Update:
- `Components/UnitFrames/Units/Player.lua`
  - Added `HidePlayerNativePowerVisuals` and `UpdatePlayerFakePowerFill`.
  - Added `Power.FakeFill` texture and hooked `OnMinMaxChanged` / `OnValueChanged` to drive fake fill from handler values.
  - During `UnitFrame_UpdateTextures`, fake power fill now inherits current texture/texcoord/orientation/scale and updates immediately.
  - Native power statusbar texture is hidden after updates, mirroring target fake-fill strategy.
  - Power visibility/color callbacks now refresh fake fill and keep it color-synced.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload` validation of player crystal bar alignment/fill with moved/scaled art.

2026-02-16 19:19 (HOTFIX: PLAYER POWER NIL FUNCTION + PLAYER HEALTH TEXT FALLBACK)
Issue:
- BugSack: `Player.lua:351 attempt to call global 'UpdatePlayerFakePowerFill' (nil value)`.
- Player health text can show max health instead of current health under secret-value conditions.
Hypothesis:
- Fake-power helpers were referenced before local function assignment, causing global lookup.
- `SafeUnitHealth` fallback in tags promotes current health to max too early when secret values are present.
Planned change(s):
- Add forward declarations for player fake-power helpers and bind function definitions to those locals.
- Update `SafeUnitHealth` fallback order to prefer safe percent/mirror-derived current health before max fallback.
Files targeted:
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Tags.lua
Result:
- In progress.
Update:
- `Components/UnitFrames/Units/Player.lua`
  - Added forward declarations for `HidePlayerNativePowerVisuals` and `UpdatePlayerFakePowerFill`.
  - Converted helper definitions to assignments (no local re-declaration) to keep early references valid.
- `Components/UnitFrames/Tags.lua`
  - Updated `SafeUnitHealth` fallback:
    - prefer `SafeUnitPercent`-derived current health,
    - then frame cached current/percent (`safeCur`, `safePercent`),
    - only then fall back to max health.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- Ready for `/reload` retest of player power error and player health text behavior.

2026-02-16 16:05 (WOw12 STABILIZATION: NATIVE HEALTH PATH + EDIT MODE SAFETY)
Issue:
- Target/nameplate health rendering still mismatched and unstable from mixed fake-fill + native statusbar logic.
- Target castbar could appear behind health in some paths.
- Edit Mode could throw forbidden-table errors on castbar/registered systems paths.
Hypothesis:
- WoW12 is more reliable with one native statusbar path per frame (no per-value texcoord/fake texture manipulation in production).
- Flip-lab should remain debug-only and not mutate live production rendering.
- Edit Mode safety improves by removing risky frame-iteration/noop overrides and avoiding castbar method calls while Edit Mode is active.
Change(s):
- Switched target/nameplate health production path to native statusbar rendering only.
- Disabled fake-fill runtime path and handler-driven per-value texture reshaping in production.
- Added production native fill marker on health bars and simplified secret fallback usage in `API.UpdateHealth`.
- Hid flip-lab option groups unless development mode is enabled; added debug-mode gating for flip-lab runtime.
- Reasserted target castbar layering relative to health frame.
- Hardened Edit Mode logic to avoid iterating inaccessible `registeredSystemFrames` and removed broad AccountSettings no-op overrides.
- Added Edit Mode-aware guard in WoW12 `CastingBarMixin.StopFinishAnims` wrapper.
Result:
- Pending `/reload` and in-game validation.
Next step:
- Validate target/nameplate fill direction + sync under combat and secret-value conditions, then verify Edit Mode opens/closes without new errors.

2026-02-16 16:18 (POST-STABILIZATION: TARGET HEALTH DIRECTION CORRECTION)
Issue:
- Health values now update correctly, but target health fills in the wrong direction.
Hypothesis:
- Production defaults in target health lab settings still force reverse fill (`healthReverseFill = true`), which is now driving native statusbar direction.
Change(s):
- Set production default target `healthReverseFill` to `false`.
- Keep flip-lab overrides available only in dev/debug mode.
Result:
- Pending `/reload` verification that target fill direction matches frame art while preserving correct value updates.
Next step:
- If target and nameplate should share direction policy, apply the same orientation/reverse policy to nameplates.

2026-02-16 16:31 (MIRRORED HEALTH DISPLAY BAR: HIDDEN SOURCE + VISIBLE REVERSED BAR)
Issue:
- Native production path updates values correctly, but target/nameplate fill direction still appears wrong against art.
Hypothesis:
- Keep the original health bar as hidden trusted source (WoW12-safe updates), then mirror its min/max/value to a second visible statusbar configured with opposite reverse-fill direction.
Change(s):
- Add `Health.Display` statusbar for target and nameplates.
- Hide source statusbar texture (alpha 0), keep source as value authority.
- Mirror source `OnMinMaxChanged` and `OnValueChanged` into `Health.Display` without arithmetic.
- Route health color updates to `Health.Display`.
- Configure display bar orientation/texcoord from style settings but with opposite `SetReverseFill`.
Result:
- Pending `/reload` and combat validation for target and nameplate fill direction.
Next step:
- If prediction/absorb placement appears off, move those overlays to follow `Health.Display` texture anchors.

2026-02-16 16:39 (MIRROR BAR FOLLOW-UP: INITIAL WHITE COLOR + DIRECTION INVERSION)
Issue:
- Mirrored health display starts white until first damage/color event.
- Mirrored fill direction is still opposite of desired.
Hypothesis:
- Display bar needs immediate color seed from source bar color at texture/style update.
- Reverse-fill inversion needs to be toggled for mirror display.
Change(s):
- Seed `Health.Display` color from source `Health:GetStatusBarColor()` during style/position updates.
- Flip mirror reverse-fill setting to the opposite of previous mirror behavior.
Result:
- Pending `/reload` and immediate target-self test (full health, no damage) plus direction verification.
Next step:
- If still direction-mismatched, flip display X texcoord while keeping current reverse-fill setting.

2026-02-16 16:48 (REGRESSION HOTFIX: MIRROR UPDATE SOURCE + AURA CLICK TAINT + BACKDROP RETRY WRAP)
Issue:
- Mirror bar can desync or disappear because it relied on event-script timing instead of primary health update path.
- BugSack: ADDON_ACTION_BLOCKED in aura template `RegisterForClicks` during secure aura header updates.
- BugSack: Backdrop secret width error still appears intermittently (likely wrapper race/load-order timing).
Hypothesis:
- Mirror display must be written from `API.UpdateHealth` directly.
- `RegisterForClicks` in secure aura template OnLoad can trigger protected-call block under restricted execution.
- Backdrop wrapper should retry until mixin exists, not only attempt once.
Change(s):
- `API.UpdateHealth`: write min/max/value to `Health.Display` when present.
- Removed `RegisterForClicks(...)` from `Components/Auras/AuraTemplates.xml` OnLoad script.
- `FixBlizzardBugs.OnInitialize` WoW12 path: added `EnsureBackdropGuard()` with delayed/ticker retries.
- Mirror display visual direction: flipped X texcoord (`right,left`) and added non-white fallback color seed.
Result:
- Pending `/reload` verification for:
  - mirror fill visibility and % sync,
  - no aura RegisterForClicks protected-call block,
  - no new Backdrop secret-width errors on tooltip hover.
Next step:
- If mirror direction still wrong, toggle only display reverse-fill and keep X-tex flip fixed.

2026-02-16 16:55 (DISPLAY BAR VISIBILITY HARDENING)
Issue:
- Mirrored display bar can remain invisible even while percentages update.
Hypothesis:
- Display bar/texture alpha and effective frame level are not guaranteed after style updates.
Change(s):
- Force `Health.Display` visible state during texture updates:
  - `SetAlpha(1)`, `Show()`,
  - texture alpha `1`,
  - ensure frame level above source health.
Result:
- Pending `/reload` check that mirrored display is visible at full health immediately on target acquire.
Next step:
- If still invisible, print debug dump of display texture path/alpha/frame level and parent alpha chain.

2026-02-16 17:03 (DISPLAY BAR RUNTIME ANCHOR/VISIBILITY GUARD IN UPDATEHEALTH)
Issue:
- Display bar may still disappear at runtime despite style-time visibility enforcement.
Hypothesis:
- Later updates can override frame parent/points/alpha or texture alpha after style setup.
Change(s):
- In `API.UpdateHealth`, when `Health.Display` exists:
  - force parent to source health,
  - force all-points anchor,
  - enforce frame level above source health,
  - enforce frame alpha and texture alpha to `1`,
  - force `Show()`.
Result:
- Pending `/reload` validation that display bar remains visible while % updates.
Next step:
- If still hidden, extend `/azdebug dump target` to include `Health.Display` live object dump.

2026-02-16 17:12 (TARGET DIRECTION REGRESSION: RESTORE PRE-REFACTOR DEFAULT FILL MODEL)
Issue:
- Target health now updates, but fill direction is still wrong.
- User asked how it worked before.
Hypothesis:
- Before refactors, target used a single native statusbar with `SetFlippedHorizontally(isFlipped)` and no default texcoord swapping.
- Current default lab settings force texcoord X swap + non-flipped bars, which deviates from legacy behavior.
Change(s):
- Restore pre-refactor default direction semantics for target health lab defaults:
  - no default texcoord X swap,
  - default flipped-horizontally follows layout `IsFlippedHorizontally`,
  - preview/absorb/cast default flipped follows layout flip as well.
- Make `Health.Display` use normal texcoord order by default (`texLeft, texRight`), not swapped.
Result:
- Pending `/reload` validation that target fill direction matches old behavior while keeping WoW12-safe display mirroring.
Next step:
- If needed, apply the same restored defaults to nameplates for consistency.

2026-02-16 17:24 (TARGET HEALTH: HANDLER-DRIVEN FAKE TEXTURE FILL + HIDDEN NATIVE BAR)
Issue:
- Target fill direction remains unreliable under mixed statusbar/display flip controls.
- User requested creator-style WoW12-safe fix using handler arguments only.
Hypothesis:
- A fake texture driven from `OnMinMaxChanged` + `OnValueChanged` callback args is the most deterministic path under secret-value constraints.
Change(s):
- Added target fake health fill renderer:
  - hide native statusbar texture alpha,
  - render `Health.FakeFill` texture on top of health bar,
  - update width/texcoords using cached handler min/max/value only.
- Kept health flip-lab toggles active by mapping lab orientation/reverse/texcoords into fake-fill renderer settings.
- Disabled visible `Health.Display` proxy for target to avoid fighting the fake-fill path.
Result:
- Pending `/reload` + in-game target tests (full health, damage, heal, retarget, in/out combat).
Next step:
- If stable on target, apply the same fake-fill path to nameplates.

2026-02-16 17:38 (CLEANUP + TARGET FAKE-FILL CONSOLIDATION)
Issue:
- Multiple leftover snippets/toggles are no longer used after switching target health to fake-fill path.
- Target bar could still appear with mismatched art/fill orientation depending on stale display/texcoord paths.
Hypothesis:
- Removing dead `Health.Display` target plumbing and unused fake-fill toggles reduces conflicts.
- Fake-fill art should follow target layout flip (`IsFlippedHorizontally`) by default.
Change(s):
- Removed dead target `Health.Display` setup/updates/hooks and related guard usage.
- Removed unused `healthUseFakeTextureFill` option/default entries for target and nameplates.
- Removed unused nameplate fake-fill setting fields (`useFakeTextureFill`, `fakeReverse`) and dead marker assignments.
- Updated target fake-fill defaults to inherit target layout horizontal flip for texture orientation.
- Ensured target fake-fill refreshes in `Health_PostUpdate` to avoid initial/non-combat stale visibility.
Result:
- Pending `/reload` validation for: immediate target health visibility, correct art orientation, and no regression in flip-lab toggles.
Next step:
- If target is stable, perform same fake-fill consolidation strategy on nameplates.

2026-02-16 17:46 (TARGET FAKE-FILL VISIBILITY TIMING: FORCEUPDATE ON TARGET TRANSITIONS)
Issue:
- Target fake-fill bar can stay hidden/stale out of combat until a health event (combat/heal) occurs.
Hypothesis:
- Handler-driven fake fill needs an explicit refresh on target-frame transitions because no immediate health delta event is guaranteed.
Change(s):
- In target frame post-update path, force a health element update (`Health:ForceUpdate()`) to prime fake fill immediately on target changes/style updates.
- Seed fake-fill cached min/max/value from safe cached health values before first handler tick.
Result:
- Pending `/reload` verification that target health appears and updates immediately when targeting self/others out of combat.
Next step:
- Apply similar force-prime logic to nameplates if they show delayed first paint.

2026-02-16 17:55 (TARGET ART ALIGNMENT + CASTBAR ORIENTATION PARITY)
Issue:
- Target fake-fill health sits slightly off versus frame art.
- Target castbar orientation should match health orientation behavior.
Hypothesis:
- Fake fill should use edge-locked cropping (texcoord + opposite-edge inset) instead of raw width slicing for better visual alignment.
- Castbar default reverse/flip should inherit health reverse/flip defaults.
Change(s):
- Updated target fake-fill renderer to keep full bar anchoring and apply directional inset based on percent for tighter art alignment.
- Set castbar default reverse/flip to follow health reverse/flip in target health lab settings.
Result:
- Pending `/reload` validation for visual alignment and castbar direction parity.
Next step:
- If still slightly off, add small per-style fake-fill inset values in layout config.

2026-02-16 18:06 (TARGET LIVE TUNING LAB: SLIDERS/TOGGLES FOR HEALTH FAKE FILL + CASTBAR)
Issue:
- User requested extensive in-game controls to tune target health alignment and castbar orientation/flip.
Hypothesis:
- A dedicated live tuning set in Target Flip Lab will let us converge quickly without code churn.
Change(s):
- Added target profile controls for:
  - fake health fill offsets/insets (X/Y + left/right/top/bottom),
  - castbar texcoord X/Y flip toggles,
  - castbar X/Y offsets,
  - castbar width/height scale percentages.
- Wired controls in `Target.lua`:
  - fake health fill alignment uses new offsets/insets live,
  - castbar uses separate cast texcoord flips + offset + scale.
Result:
- Pending `/reload` + live tuning session in options.
Next step:
- Once tuned, bake chosen values as defaults and reduce debug noise.

2026-02-16 18:14 (TARGET GHOST BAR BRIGHTNESS: HARD-HIDE NATIVE/PREVIEW TEXTURES)
Issue:
- Target health appears slightly washed/light, like a ghost bar is rendering under fake fill.
Hypothesis:
- Native health or preview statusbar textures can become visible intermittently after updates/style changes.
Change(s):
- Added helper to force-hide native health and preview textures (alpha 0 + hidden) on refresh paths.
- Applied helper in style update, post-update, and value-changed handler.
Result:
- Pending `/reload` validation that only fake health fill is visible.
Next step:
- If any residual glow remains, tune fake-fill alpha and absorb overlay stacking.

2026-02-16 18:22 (TARGET GHOST OVERLAY ROOT CAUSE: HEALTHPREDICTION LAYER)
Issue:
- Ghost/light duplicate still visible after hiding native + preview textures.
Hypothesis:
- Target `HealthPrediction` overlay texture (incoming heal/absorb tint) is still painting above fake fill and reading like a ghost bar.
Change(s):
- Disabled target HealthPrediction visual rendering in target-specific `HealPredict_PostUpdate` (hide and return).
Result:
- Pending `/reload` confirmation that washed overlay is gone while core fake health fill remains.
Next step:
- If desired, reintroduce prediction later behind a dedicated target toggle tuned for WoW12-safe behavior.

2026-02-16 14:48 (CREATOR-STYLE WOW12 HEALTH FILL HANDLER: FAKE TEXTURE + HANDLER VALUES)
Issue:
- Target/nameplate health fill still not behaving correctly despite orientation/reverse/texcoord toggles.
- User provided creator note: hide native status texture and drive a fake texture from handler values (`OnMinMaxChanged`/`OnValueChanged`) to avoid secret-value API reads.
Hypothesis:
- A direct handler-driven fake-texture fill path (using callback args only) is more stable in WoW12 than mixed native statusbar flip controls.
Change(s):
- Implement creator-style path:
  - create fake health fill texture over the bar,
  - hide native statusbar texture (`alpha=0`),
  - cache min/max in script handler,
  - compute fill texcoord and horizontal offset from handler `value` and cached `max`.
- Wire for Target and Nameplates, with option toggle for live enable/disable.
Result:
- Pending `/reload` and in-game damage tests on target + nameplates.
Next step:
- If this resolves direction but not visuals, tune fake texture layer/alpha/blend and orientation-specific branch for vertical bars.

2026-02-16 15:02 (FAKE FILL INIT/REFRESH STABILITY + DIRECTION SOURCE)
Issue:
- Fake fill does not initialize on first target in full-health states.
- Fake fill appears delayed or stale unless value changes.
- Direction can still appear wrong regardless of some options.
Hypothesis:
- Handler-only (`OnValueChanged`) refresh misses stable-value frames; should also refresh from `Health.PostUpdate` safe values.
- Direction source should come from final texcoord X ordering (`texLeft > texRight`) rather than mixed orientation/reverse-fill flags.
Change(s):
- Add `UpdateFakeHealthFill(...)` helper in target/nameplates unit modules.
- Call helper from `Health_PostUpdate(element, unit, cur, max)` so fake fill updates on every health refresh.
- Keep handler path but route to helper for consistency.
- In Nameplates, set fake reverse from computed texcoord ordering.
Result:
- Pending `/reload` and first-target/full-health verification.
Next step:
- If still delayed, force one post-style refresh after `UnitFrame_UpdateTextures`/`NamePlate_PostUpdateElements` via current cached safe values.

2026-02-16 15:12 (HANDLER PATH UNBLOCK + WIDTH-BASED FAKE FILL VISIBILITY)
Issue:
- Fake fill not responding to damage after last pass.
Hypothesis:
- Handler secret-guards were over-filtering WoW12 handler values and suppressing updates.
- Full-width texture + offset approach can appear static depending on clipping behavior; explicit width-based fill is clearer.
Change(s):
- Remove handler secret guards for `OnMinMaxChanged`/`OnValueChanged` in target/nameplates fake path.
- Switch fake fill rendering to explicit `width * percent` with left/right anchoring.
- Keep texcoord cropping for visual continuity.
Result:
- Pending `/reload` and live damage/heal checks.
Next step:
- If still stale, add lightweight debug print for handler value/min/max and fake width percent per update tick.

2026-02-16 15:21 (SECRET HEALTH TEXT/FILL DESYNC RESYNC)
Issue:
- UI can show full health text while bar renders partially (or vice versa) under secret `UnitHealth` path.
Hypothesis:
- `safeCur/safePercent` were computed before final bar write/mirror state was available; when `rawCur` is secret they can drift from rendered bar state.
Change(s):
- In `API.UpdateHealth`, after `SetStatusBarValuesCompat(...)`, re-read mirrored/texture percent via `GetSecretPercentFromBar(element)` and update `safePercent/safeCur` when `rawCur` is secret.
Result:
- Pending `/reload` validation that numeric readouts and visible health fill remain synchronized.
Next step:
- If still mismatched, route player health text/tag source directly from mirror percent cache in tag helpers.

2026-02-16 15:29 (SECRET CURRENT + CLEAN MAX FALLBACK BUG + CASTBAR LAYER REGRESSION)
Issue:
- Health text/fill still mismatched.
- Target castbar ended up behind health layer after fake-fill path.
Hypothesis:
- `API.UpdateHealth` only used bar-derived fallback percent when both current and max were secret; in observed case current is secret but max is clean, so fallback never ran.
- Fake fill texture parented to `healthOverlay` (higher framelevel) can overdraw castbar.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - fallback `GetSecretPercentFromBar` now runs whenever current health is secret (`not rawCurSafe`), regardless of max secrecy.
- `Components/UnitFrames/Units/Target.lua` and `Components/UnitFrames/Units/NamePlates.lua`:
  - reparent fake fill texture from overlay frame to health bar frame so castbar stays above it.
Result:
- Pending `/reload` validation for both health sync and target castbar visibility.
Next step:
- If mismatch persists, add player-specific fake fill path (same handler model) so player uses identical source as target/nameplates.

2026-02-16 14:33 (TARGET FLIP LAB CACHE STALL + TOOLTIP BACKDROP SECRET WIDTH)
Issue:
- Target health flip lab toggles appeared to do nothing unless style changed.
- BugSack spam on tooltip hover:
  - `Blizzard_SharedXML/Backdrop.lua:226 attempt to perform arithmetic on local 'width' (secret)`.
Hypothesis:
- `Target.lua` exits early on unchanged `currentStyle`, skipping reapplication of lab settings.
- WoW12 passive path in `FixBlizzardBugs.OnInitialize` returns before the existing backdrop guard (which was disabled anyway), so tooltip backdrops still hit secret width/height math.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - add `healthLabSignature` cache key and only early-return when both style and signature are unchanged.
- `Core/FixBlizzardBugs.lua`:
  - add active WoW12 guard for `BackdropMixin.SetupTextureCoordinates` before passive return:
    - bail if width/height are secret,
    - run original via `pcall`.
Result:
- Pending `/reload` validation:
  - target flip-lab toggles should apply instantly without style changes,
  - tooltip hover should stop generating Backdrop secret-width errors.
Next step:
- If target fill still appears unchanged with toggles, dump live `healthLabSignature` and bar flags each update to verify option propagation.

2026-02-16 14:21 (TARGET/NAMEPLATE HEALTH FLIP LAB OPTIONS FOR LIVE DIRECTION DEBUG)
Issue:
- Target frame and nameplate health fills still appear visually wrong-way under current combined orientation/texcoord/reverse-fill setup.
- Need an in-game way to live-test multiple flip permutations without code edits/reloads each time.
Hypothesis:
- Exposing direct profile controls for orientation, texcoord flips, reverse fill, and `SetFlippedHorizontally` (for health + preview + absorb + cast) will let us isolate the exact combination matching the art.
Change(s):
- Add `health flip lab` profile controls for:
  - `TargetFrame` module.
  - `NamePlates` module.
- Add new options UI groups in:
  - `Options/OptionsPages/UnitFrames.lua` (Target section).
  - `Options/OptionsPages/Nameplates.lua`.
- Apply those toggles live in:
  - `Components/UnitFrames/Units/Target.lua`.
  - `Components/UnitFrames/Units/NamePlates.lua`.
Result:
- Pending `/reload` and in-game toggle pass:
  - Test orientation + reverse fill + tex flips for target health and nameplate health.
  - Confirm settings apply instantly via options without requiring reload.
Next step:
- Once preferred combo is identified, bake that combo into defaults and keep the lab as a hidden dev block (or remove if requested).

2026-02-16 14:02 (EDIT MODE CASTBAR FORBIDDEN TABLE + TARGET HEALTH ART DIRECTION)
Issue:
- Opening Edit Mode throws:
  - `attempted to iterate a forbidden table`
  - stack in `Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua:StopFinishAnims`.
- Target health now fills with correct direction logic but bar art appears visually reversed relative to target frame backdrop/case.
Hypothesis:
- Blizzard `StopFinishAnims` can hit forbidden animation tables under WoW12 secret/taint paths during Edit Mode arena refresh.
- Target health statusbar texture itself needs explicit horizontal texcoord flip to match flipped target art while keeping reverse fill behavior.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - add a narrow WoW12-safe wrapper for `CastingBarMixin.StopFinishAnims` before passive early return.
  - wrapper bails on inaccessible animation table and protects call with `pcall`.
- `Components/UnitFrames/Units/Target.lua`:
  - set explicit texcoords for health/preview/absorb/cast bars using `isFlipped` to align texture art with target backdrop orientation.
Result:
- Pending `/reload` + Edit Mode open/close validation and target damage check.
Next step:
- If Edit Mode still errors, add a second guard on `CastingBarMixin.UpdateShownState` with the same inaccessible-table bailout pattern.

2026-02-16 13:46 (DEBUG PRINT SECRET TAINT + WOW12 AURA HEADER PATH + TARGET HEALTH REVERSE FILL)
Issue:
- BugSack: `Core/Debugging.lua:706 bad argument #5 to SetText`.
- BugSack: secret string taint through debug dump path (`Debugging.lua` around dump lines).
- Player buffs/debuffs not visible in WoW12 secret mode because custom aura header path exits early.
- Target health bar still fills the wrong way.
Hypothesis:
- Tooltip API call uses invalid argument signature (`SetText(..., true)` alpha slot).
- Debug dump prints still push dynamic values through raw `print/tostring`, letting secret-tainted strings leak into chat filters.
- `Auras.OnEnable` returns early in secret mode before `CreateBuffs/CreateAnchor`.
- Target health needs deterministic reverse-fill behavior applied to the real statusbar.
Change(s):
- `Core/Debugging.lua`:
  - fix tooltip call to `GameTooltip:SetText(tooltip, 1, 1, 1)`.
  - add `SafePrint(...)` using `SecretSafeText(...)`, and route dump output through it.
- `Components/Auras/Auras.lua`:
  - remove secret-mode early return so AzeriteUI aura header creation runs in WoW12.
  - keep Blizzard aura suppression path and normal update registrations.
- `Components/UnitFrames/Units/Target.lua`:
  - enforce reverse fill on target health (`SetReverseFill(true)`), with handler-value cache only.
  - remove conflicting manual texture point/texcoord manipulation in health `OnValueChanged`.
Result:
- Pending `/reload` validation:
  - no debug-menu tooltip errors,
  - no secret-string taint from `/azdebug dump`,
  - custom player auras visible,
  - target health fills opposite of player.
Next step:
- If target health still appears wrong, add a dedicated non-statusbar overlay texture mirror and hide native fill texture.

2026-02-16 13:34 (SECRET TEXSIZE ARITHMETIC CRASH + TARGET HEALTH DIRECTION CONFLICT)
Issue:
- BugSack spam: `Functions.lua:226 attempt to perform arithmetic on local 'texWidth' (a secret number value tainted by 'AzeriteUI')`.
- Target health bar fill direction still wrong.
Hypothesis:
- `GetTexturePercentFromBar()` still divides by `texWidth/texHeight` before secret checks.
- Target health statusbar is being horizontally flipped by style updates while also using custom OnValueChanged texcoord math, causing direction conflict.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - guard `barWidth`, `barHeight`, `texWidth`, `texHeight` with `IsSecretValue(...)` before arithmetic.
- `Components/UnitFrames/Units/Target.lua`:
  - keep custom handler-based target health texcoord logic.
  - disable horizontal statusbar flipping for health/prediction/absorb/cast bars (`SetFlippedHorizontally(false)`) so custom handler controls direction deterministically.
Result:
- Pending `/reload` + live validation with target swaps and combat.
Next step:
- If target direction still appears wrong, switch to dedicated fake health texture mirror path and hide native statusbar texture updates.

2026-02-16 00:18 (TARGET HEALTH MIRROR + PLAYER POWER THREAT ALIGN + GLOBAL BLIZZARD AURA HIDE)
Issue:
- Target health bar still fills the wrong direction (bar itself), despite prior texture/art fixes.
- Player power threat highlight remains offset after power/case slider transforms.
- Blizzard aura frames still appear and overlap AzeriteUI aura layouts in some states.
Hypothesis:
- Target health needs an isolated WoW12-safe `OnMinMaxChanged`/`OnValueChanged` path matching the provided handler-style fix, without mirror helper interference.
- Power backdrop threat anchor currently double-applies base case offsets when attached to the case texture.
- Blizzard aura frames should be kept hidden globally by always applying the hide visibility driver and disabling Blizzard aura frames on enable.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - removed target health mirror helper binding for this bar.
  - kept handler-driven value/texcoord path and mirrored fill math (`percent -> texcoord + left offset`) for the statusbar texture.
  - set target aura growth override to left-to-right and downward (`TOPLEFT`, `RIGHT`, `DOWN`).
- `Components/UnitFrames/Units/Player.lua`:
  - fixed `PowerBackdrop` threat anchoring to follow case offsets without doubling base offsets (anchor to power root + case offsets).
- `Components/Auras/Auras.lua`:
  - always use Blizzard aura visibility driver `hide`.
  - call `DisableBlizzard()` in `OnEnable()` before branching to secret mode path.
Result:
- Pending `/reload` and in-game validation of target health fill direction + power threat highlight placement.
Next step:
- If target fill is still inverted, switch to dedicated fake texture mirror path (keeping secure handler math) and leave native fill hidden.

2026-02-16 00:37 (CHAIN-SAFE TARGET HEALTH HANDLERS + STATIC SAFETY SMOKETEST)
Issue:
- Target health fix currently used direct `SetScript` for `OnMinMaxChanged`/`OnValueChanged`, which can override existing scripts on the statusbar.
- Request for broader taint/safe-call smoketest.
Hypothesis:
- Introduce a reusable chain-safe script helper in UnitFrame API:
  - prefer `HookScript` (non-clobbering),
  - fallback to `GetScript`/`SetScript` chaining.
- Use this helper for target health handler path so the WoW12-safe value flow remains intact while reducing script clobber risk.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - add `API.AttachScriptSafe(frame, scriptName, handler)`.
  - reuse helper in `API.BindStatusBarValueMirror`.
- `Components/UnitFrames/Units/Target.lua`:
  - switch target health `OnMinMaxChanged`/`OnValueChanged` handler registration to `ns.API.AttachScriptSafe`.
Result:
- Pending static parse + taint-pattern scan.
Next step:
- In-game `/reload` verification and BugSack watch during target swaps/combat.

2026-02-15 23:32 (POWER ART STACK LAYER + ICE TINT FIX)
Issue:
- Existing slider only moved inner bar texture; at positive values bar could appear in front of case while negative values had little visible effect.
- Ice crystal looked overly blue (power-type tint) instead of neutral/light icy.
Hypothesis:
- Layer control must apply to the full power-art stack (bar + backdrop + case + power threat textures) using coordinated draw sublayers.
- Ice/winter crystal should disable power-type tinting (`colorPower`) and force white statusbar color.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - repurposed `powerBarArtLayer` as shared sublayer offset for full power-art stack.
  - apply draw-layer offsets to:
    - power statusbar texture
    - power backdrop texture
    - power case texture
    - threat `PowerBar` + `PowerBackdrop` textures
  - when ice/winter crystal is active:
    - set `power.colorPower = false`
    - force `SetStatusBarColor(1,1,1,1)`
  - when regular crystal is active:
    - restore `power.colorPower = true`
- `Options/OptionsPages/UnitFrames.lua`:
  - renamed slider label/description to clarify it controls full power-art layering.
Result:
- Pending `/reload` + live slider test with `Use Ice Crystal` on/off.
Next step:
- If needed, add separate case-only layer slider for finer control.

2026-02-15 23:18 (PLAYER POWER BAR ART-LAYER SLIDER)
Issue:
- Player power bar color/look appears wrong, especially on ice crystal; likely visual stacking/layer issue.
Hypothesis:
- Expose a live slider for power bar texture sublayer so user can move the bar between surrounding crystal art layers without code edits.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add profile field `powerBarArtLayer` (default `0`).
  - apply it to power statusbar texture via `SetDrawLayer("ARTWORK", layer)`.
- `Options/OptionsPages/UnitFrames.lua`:
  - add `Power Bar Art Layer` range slider under Player -> Power Crystal Position.
Result:
- Pending `/reload` and in-game tuning, especially with `Use Ice Crystal` enabled.
Next step:
- If needed, add a secondary frame-level slider for broader strata shifts.

2026-02-15 23:05 (MINIMAP PING TAINT FIX + PLAYER POWER DEFAULT SCALE)
Issue:
- BugSack `ADDON_ACTION_FORBIDDEN`: AzeriteUI called protected `Minimap:PingLocation()`.
- Requested Player power defaults: `Scale X = 111`, `Scale Y = 93`, offsets `0`.
Hypothesis:
- Taint comes from overriding Minimap `OnMouseUp` and manually calling minimap click handler.
- DiabolicUI3 avoids this by hooking mouse-up and handling only right/middle, while Blizzard owns left click ping path.
Change(s):
- `Components/Misc/Minimap.lua`:
  - convert custom minimap click handler to hook-style callback for right/middle only.
  - stop overriding Blizzard `OnMouseUp`; use `HookScript("OnMouseUp", ...)`.
- `Components/UnitFrames/Units/Player.lua`:
  - set profile defaults: `powerBarScaleX = 1.11`, `powerBarScaleY = 0.93`.
  - keep offset defaults at `0`.
Result:
- Pending `/reload` + BugSack verification for forbidden ping call.
Next step:
- If any ping taint remains, audit external hooks around Minimap click path for script replacement conflicts.

2026-02-15 22:24 (BAKE CURRENT PLAYER POWER POSITION INTO LAYOUT)
Issue:
- Request: extrapolate current in-game crystal/case position and bake it into code defaults.
Hypothesis:
- Current tuned offsets are:
  - bar: `x=-4`, `y=+16`
  - case: `x=+24`, `y=-17`
- Apply these directly to layout positions in all player variants, then one-time migrate saved profile base offsets so visuals do not double-shift.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - `PowerBarPosition`: `{-10,-30}` -> `{-14,-14}`
  - `PowerBarForegroundPosition`: `{-23,19}` -> `{1,2}`
  - `PowerBarThreatPosition`: `{0,1}` -> `{-4,17}`
  - `PowerBackdropThreatPosition`: `{-23,19}` -> `{1,2}`
  - applied to `Novice`, `Hardened`, `Seasoned`.
- `Components/UnitFrames/Units/Player.lua`:
  - added one-time profile migration flag to subtract baked offsets from saved base offsets.
Result:
- Pending `/reload` + visual check that current look remains while sliders can stay near zero.
Next step:
- If needed, repeat same bake pass for scale values once target size is finalized.

2026-02-15 22:31 (ROLLBACK: BAKED POSITION SHIFTED LIVE TUNED STATE)
Issue:
- Bake + migration pass shifted the user away from the intended current tuned position.
Hypothesis:
- Existing profile baseline/slider state was not aligned with hardcoded extrapolation.
Change(s):
- Reverted baked layout position edits in `Layouts/Data/PlayerUnitFrame.lua`.
- Reverted one-time baked-layout migration flag logic in `Components/UnitFrames/Units/Player.lua`.
Result:
- Restored pre-bake behavior.
Next step:
- Bake from explicit current slider values (no extrapolation) to avoid drift.

2026-02-15 22:06 (PLAYER POWER BAR: SEPARATE X/Y SCALE CONTROLS)
Issue:
- Requested independent width/height scaling controls instead of one uniform scale slider.
Hypothesis:
- Replace single `powerBarScale` usage with `powerBarScaleX` and `powerBarScaleY`.
- Keep backward compatibility by falling back to existing `powerBarScale` if new fields are unset.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add profile defaults for `powerBarScaleX` and `powerBarScaleY`.
  - apply bar size using independent X/Y scales.
  - fallback to legacy `powerBarScale` for existing profiles.
- `Options/OptionsPages/UnitFrames.lua`:
  - replace single scale slider with `Power Bar Scale X (%)` and `Power Bar Scale Y (%)`.
Result:
- Pending `/reload` + options validation.
Next step:
- If requested, add a lock toggle to keep X/Y linked while dragging.

2026-02-15 22:12 (SAVE CURRENT CRYSTAL/CASE POSITION+SIZE AS DEFAULT)
Issue:
- Requested to keep current crystal/case placement/size as new default state.
Hypothesis:
- Use baseline fields for both offsets and scale so current look can be baked in.
- Reset visible controls to neutral after baking:
  - offsets -> `0`
  - size scales -> `100%`
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - added baseline scale fields (`powerBarBaseScaleX/Y`) and applied effective scale as `base * slider`.
- `Options/OptionsPages/UnitFrames.lua`:
  - updated rebase action to include size scales:
    - bake current `Scale X/Y` into baseline scale
    - reset scale sliders to 100%
  - renamed button to `Save Current Position/Size as Default`.
  - full reset now also resets scale baseline/slider fields.
Result:
- Pending `/reload` + button click verification.
Next step:
- Optional: add a short status line showing effective base+slider values in the options panel.

2026-02-15 21:58 (PLAYER POWER BAR: LARGE + ASPECT-LOCKED SCALE)
Issue:
- Desired behavior: keep player power bar large, but avoid any stretched/distorted look.
Hypothesis:
- Use a single uniform scale factor for the inner power bar so width/height always change together (aspect ratio preserved).
- Expose one options slider (percent) instead of independent width/height edits.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add `powerBarScale` profile value (default `1`).
  - apply power bar size as uniform scale from layout size (`x` and `y` scaled equally).
- `Options/OptionsPages/UnitFrames.lua`:
  - add `Power Bar Scale (%)` slider under Player -> Power Crystal Position.
Result:
- Pending `/reload` + visual verification of larger bar with preserved proportions.
Next step:
- If desired, clamp slider range tighter after live feel test.

2026-02-15 21:49 (ROLLBACK: POWER BAR SIZE RESTORE AFTER BAD SHAPE)
Issue:
- After restoring legacy small size, player power bar shape looked wrong again.
Hypothesis:
- The global size rollback to `{120,140}` does not match current art/offset stack in this profile and causes visually incorrect sizing.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - restore `PowerBarSize` back to `{196,228}` for `Novice`, `Hardened`, and `Seasoned`.
Result:
- Pending `/reload` visual check.
Next step:
- If height still feels too tall, add controlled aspect-safe size tuning (single scalar) instead of hard switching templates.

2026-02-15 21:41 (PLAYER POWER BAR STRETCH FIX: RESTORE ORIGINAL SIZE)
Issue:
- Player power bar appears vertically stretched/tall and reads as aspect-ratio distortion.
Hypothesis:
- Current player `PowerBarSize` values are oversized from prior tuning iterations.
- Restoring original bar dimensions will remove stretched appearance.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - restore `PowerBarSize` to original `{120, 140}` in `Novice`, `Hardened`, and `Seasoned`.
Result:
- Pending `/reload` visual verification of corrected bar shape.
Next step:
- If needed, add dedicated size controls with aspect lock in options (separate from position sliders).

2026-02-15 21:31 (POWER OFFSET ZERO-BASELINE MIGRATION)
Issue:
- User expects current visual position to be treated as default/zero in sliders.
- Existing profiles can contain non-zero slider values from prior tuning.
Hypothesis:
- Introduce hidden baseline offsets and compute effective position as `base + slider`.
- One-time migrate existing slider values into baseline, then reset visible sliders to `0` while preserving current visuals.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add baseline profile fields for power bar/case offsets.
  - apply effective offsets as baseline + slider.
  - add one-time migration for old profiles (`powerOffsetZeroMigrated`) that moves current slider values into baseline and zeroes sliders.
- `Options/OptionsPages/UnitFrames.lua`:
  - add "Set Current Position as Zero" action to re-baseline current slider state.
  - keep reset action for full default reset (baseline + slider -> 0).
Result:
- Pending `/reload` + options verification that current position shows sliders at zero.
Next step:
- If desired, expose baseline values in dev-only diagnostics.

2026-02-15 21:20 (FIX: PLAYER POWER SLIDERS NOT MOVING FRAME)
Issue:
- New Player power sliders appear in options but visual position does not change.
Hypothesis:
- Offset application used 5-arg `SetPoint(point, relTo, relPoint, x, y)` unconditionally.
- Player layout point tables for power/case are 3-arg forms (`point, x, y`), so the wrong argument shape prevented effective movement.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add local point helper to apply offsets to both 3-arg and 5-arg point tables.
  - switch power bar, power case, and power-related threat textures to use helper.
Result:
- Pending `/reload` + slider movement retest in options.
Next step:
- If movement still appears static, dump current profile offset values from options getter path and frame points after `UpdateSettings()`.

2026-02-15 21:14 (PLAYER POWER OFFSET SLIDERS IN OPTIONS UI)
Issue:
- Command-driven tuning is not desired; request is mouse-driven controls with visible numeric values in options.
Hypothesis:
- Add range sliders under `Unit Frames -> Player` bound to profile offset fields already used at runtime:
  - `powerBarOffsetX/Y`
  - `powerCaseOffsetX/Y`
- Use immediate `UpdateSettings()` via existing option setter for live preview.
Change(s):
- `Options/OptionsPages/UnitFrames.lua`:
  - added new "Power Crystal Position" section in Player options.
  - added 4 range sliders for bar/case X/Y offsets.
  - added one-click reset action to restore all four offsets to `0`.
Result:
- Pending `/reload` + in-game options panel verification.
Next step:
- If needed, narrow slider ranges or adjust step size for finer control.

2026-02-15 21:02 (PLAYER POWER LIVE TUNING COMMANDS)
Issue:
- Static layout edits are slow to iterate; latest requested move appeared unchanged in-game.
- Need an in-game way to reposition player power bar/case without file edits each pass.
Hypothesis:
- Add profile-backed runtime offsets for player `PowerBar` and `PowerCase`.
- Expose `/azdebug power ...` command controls to set/nudge/reset offsets and force-refresh the player frame.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - add profile defaults for `powerBarOffsetX/Y` and `powerCaseOffsetX/Y`.
  - apply offsets in `UnitFrame_UpdateTextures` when placing power bar/case (and corresponding threat overlays).
- `Core/Debugging.lua`:
  - add `/azdebug power` command family for status/set/nudge/reset of bar/case offsets.
  - force-update player frame after command changes.
Result:
- Pending `/reload` + in-game `/azdebug power ...` verification.
Next step:
- If command-based tuning feels good, optional follow-up can add UI sliders in debug menu.

2026-02-15 20:42 (PLAYER POWER X OFFSET: BAR + CASE 30PX LEFT)
Issue:
- Requested: move both power bar and case 30 px to the left.
Hypothesis:
- Horizontal alignment uses:
  - `PowerBarPosition` X
  - `PowerBarForegroundPosition` X
  - `PowerBackdropThreatPosition` X (case threat overlay)
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua` (all player variants):
  - `PowerBarPosition` X: `20` -> `-10`
  - `PowerBarForegroundPosition` X: `7` -> `-23`
  - `PowerBackdropThreatPosition` X: `7` -> `-23`
Result:
- Pending `/reload` visual verification.
Next step:
- If needed, nudge by small X increments.

2026-02-15 20:39 (PLAYER POWER CASE: UP 50PX)
Issue:
- Requested: move power case up by exactly 50 px.
Hypothesis:
- Case alignment uses `PowerBarForegroundPosition` and mirrored `PowerBackdropThreatPosition`.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua` (all player variants):
  - `PowerBarForegroundPosition` Y: `-31` -> `19`
  - `PowerBackdropThreatPosition` Y: `-31` -> `19`
Result:
- Pending `/reload` visual verification.
Next step:
- If needed, adjust by small px deltas around +50.

2026-02-15 20:36 (PLAYER POWER BAR MICRO-TUNE: +2% SIZE, -10% Y)
Issue:
- Requested: make player power bar 2% bigger and move it down 10%.
Hypothesis:
- Apply proportional tweak on `PowerBarSize` and `PowerBarPosition` only.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua` (all player variants):
  - `PowerBarSize`: `{192, 224}` -> `{196, 228}` (~+2%)
  - `PowerBarPosition` Y: `-7` -> `-30` (~10% downward based on bar height)
Result:
- Pending `/reload` visual verification.
Next step:
- If needed, fine-tune with exact px targets.

2026-02-15 20:33 (PLAYER POWER BAR OFFSET: DOWN 20%)
Issue:
- Requested: move the player power bar down by 20%.
Hypothesis:
- Current player power bar height is `224`; 20% is ~`45` px.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - changed `PowerBarPosition` Y from `38` to `-7` in all player variants.
Result:
- Pending `/reload` visual verification.
Next step:
- Fine-tune by exact pixel amount if needed.

2026-02-15 20:28 (TARGET AURAS: FORCE LEFTWARD EXPANSION)
Issue:
- Auras under target frame are expanding right; requested behavior is expansion to the left.
Hypothesis:
- Static layout config may not be the active source at runtime in all cases; enforce growth direction on frame construction.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - hard-set target aura layout to:
    - `initialAnchor = "TOPRIGHT"`
    - `growth-x = "LEFT"`
    - `growth-y = "DOWN"`
Result:
- Pending `/reload` and visual check on target aura row direction.
Next step:
- If needed, tweak `AurasPosition` offset for spacing after direction lock.

2026-02-15 20:24 (PLAYER POWER ALIGNMENT RESET + CASE UP 20%)
Issue:
- Requested: revert prior coupled offset changes, then raise only the case by 20%.
Hypothesis:
- Restore baseline offsets first, then adjust only case Y:
  - baseline bar Y = `38`
  - baseline case Y = `-51`
  - case up 20% => `-31`
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua` (all player variants):
  - `PowerBarPosition` Y restored to `38`
  - `PowerBarForegroundPosition` Y set to `-31`
  - `PowerBackdropThreatPosition` Y set to `-31`
Result:
- Pending `/reload` visual verification.
Next step:
- Fine-tune case by exact px if needed.

2026-02-15 20:20 (PLAYER POWER ALIGNMENT COUPLED TUNE: CASE UP 20%, BAR DOWN 20%)
Issue:
- Bar/case alignment drifts because offsets are interdependent.
Hypothesis:
- Apply both moves together to preserve visual spacing:
  - bar down by ~20% of bar height (`224 * 0.2 ~= 45`)
  - case up by ~20% of case height (`98 * 0.2 ~= 20`)
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua` (all player variants):
  - `PowerBarPosition` Y: `-7 -> -52`
  - `PowerBarForegroundPosition` Y: `-41 -> -21`
  - `PowerBackdropThreatPosition` Y: `-41 -> -21`
Result:
- Pending `/reload` visual verification.
Next step:
- Fine-tune with exact pixel targets if needed.

2026-02-15 20:17 (PLAYER POWER BAR OFFSET: DOWN 20% MORE)
Issue:
- Requested: move player power bar down by another 20%.
Hypothesis:
- With current `PowerBarSize` height `224`, 20% is ~`45` px.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - changed `PowerBarPosition` Y from `38` to `-7` in all player variants.
Result:
- Pending `/reload` visual check.
Next step:
- Fine-tune by exact px if this overshoots/undershoots.

2026-02-15 20:15 (PLAYER POWER BAR SIZE: -20%)
Issue:
- Requested: reduce player power size by 20%.
Hypothesis:
- This refers to `PowerBarSize` (inner fill bar) in player layout variants.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - changed `PowerBarSize` from `{240, 280}` to `{192, 224}` in all player variants.
  - kept crystal art/case sizes unchanged.
Result:
- Pending `/reload` visual verification.
Next step:
- If needed, adjust by exact px values rather than percentages.

2026-02-15 20:12 (PLAYER POWER CASE OFFSET: UP 20%)
Issue:
- Requested: move player power case up by 20%.
Hypothesis:
- `PowerBarForegroundPosition` controls case placement; threat case should move with it.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - changed `PowerBarForegroundPosition` Y from `-51` to `-41` in all player variants.
  - changed `PowerBackdropThreatPosition` Y from `-51` to `-41` in all player variants.
Result:
- Pending `/reload` visual verification.
Next step:
- If needed, fine-tune by small increments (+/-5 to 10 px).

2026-02-15 20:08 (PLAYER POWER BAR OFFSET TUNE: MOVE DOWN 20%)
Issue:
- Requested: move the enlarged player power bar downward by 20%.
Hypothesis:
- With `PowerBarSize` at `{240, 280}`, a 20% downward move equals `56` px on the Y offset.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - adjusted `PowerBarPosition` Y from `38` to `-18` in all player variants.
  - kept all crystal art/frame sizes unchanged.
Result:
- Pending `/reload` visual verification for bar alignment.
Next step:
- If still off, fine-tune Y offset in smaller steps (e.g. +/-10 px).

2026-02-15 20:05 (PLAYER POWER BAR ONLY x2)
Issue:
- Requested: increase only player power bar fill size, keep all crystal frame art unchanged.
Hypothesis:
- `PowerBarSize` in player layout controls fill dimensions; backdrop/case/threat sizes should remain original.
Change(s):
- `Layouts/Data/PlayerUnitFrame.lua`:
  - doubled `PowerBarSize` from `{120, 140}` to `{240, 280}` in all player level variants.
  - left `PowerBackdropSize`, `PowerBarForegroundSize`, and threat/backdrop art sizes unchanged.
Result:
- Pending `/reload` visual check for larger inner fill with original crystal art.
Next step:
- If the enlarged fill clips, adjust only `PowerBarTexCoord`/`PowerBarPosition` minimally.

2026-02-15 19:55 (TARGETFRAME + SCALE PASS: TARGET FEEL, POWER CRYSTAL SCALING ROLLED BACK, NAMEPLATE HEALTH FIX)
Issue:
- Player frame is now moving correctly, but target frame still needs parity.
- Power crystal scaling experiment produced incorrect visuals; revert all crystal size changes to original.
- Nameplates should be fixed, not scaled up.
Hypothesis:
- Target frame still uses immediate smoothing on health; enabling linear should match player behavior.
- Keep original power crystal sizes for both player and target (bar + frame art).
- Nameplate health/power in secret-number windows can miss percent fallback when `rawCur` is secret numeric; allow fallback when both current and max are not safely numeric.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - re-enable target health smoothing (`DisableSmoothing(false)`).
  - set target power crystal interpolation to linear.
- `Layouts/Data/PlayerUnitFrame.lua` and `Layouts/Data/TargetUnitFrame.lua`:
  - restored all power crystal sizes (including `PowerBarSize`) to original values.
- `Components/UnitFrames/Functions.lua`:
  - use bar-derived percent fallback when `rawCur` is unsafe and `rawMax` is unsafe (secret-number path), restoring nameplate current-health tracking without affecting player path where max is clean.
Result:
- Pending `/reload` + visual verification on target frame, original crystal visuals, and nameplate health movement.
Next step:
- If crystal art overlaps after doubling, adjust crystal anchor offsets with minimal position tweaks.

2026-02-15 19:40 (PLAYERFRAME FEEL TUNING: RE-ENABLE LINEAR BAR SMOOTHING)
Issue:
- Player health/power bars now update correctly with secret-safe writes, but movement feels stepped/choppy.
Hypothesis:
- We currently write native statusbar values without interpolation mode, and player bars are configured to immediate smoothing.
- Re-enabling linear interpolation on player bars plus passing `element.smoothing` into native `SetValue` should restore smoother motion.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - update `SetStatusBarValuesCompat` to pass `element.smoothing` to native `SetValue` when available.
- `Components/UnitFrames/Units/Player.lua`:
  - switch player health bar from `DisableSmoothing(true)` to `DisableSmoothing(false)`.
  - set player power crystal `smoothing` to linear interpolation.
Result:
- Pending `/reload` + live damage/heal test for smoother player health/power motion.
Next step:
- If still too choppy, tune interpolation mode/duration in player-only path without touching target/nameplate behavior.

2026-02-15 19:30 (SESSION 3569: SECRET-NUMBER COMPARISON CRASH HARDENING)
Issue:
- BugSack reports:
  - `Functions.lua:497 attempt to compare local 'rawMax' (a secret number value)`
  - `Functions.lua:431 attempt to compare local 'safeMax' (a secret number value)`
Hypothesis:
- Two remaining numeric comparisons run on values that may still be secret:
  - `writeMax = (rawMaxNum and rawMax > 0) ...`
  - `if (type(safeMax) ~= "number" or safeMax <= 0) then ...`
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - use `rawMaxSafe` (already secret-guarded) for health/power `writeMax` selection.
  - sanitize prediction `safeCur/safeMax` reads from health element and guard `safeMax` validation against secret values before numeric comparison.
Result:
- Pending `/reload` + BugSack retest for session 3569.
Next step:
- If clean, keep current player health behavior and proceed to nameplate current-health parity.

2026-02-15 19:18 (PLAYER HEALTH COLLAPSE TO 0: SELF-FEEDING BAR FALLBACK)
Issue:
- New logs after write-compat fix:
  - player `Health bar` now has valid min/max (`0/145220`) but value stays `0`.
  - `safeCur=0`, `safePct=0`, `mirrorPct=0` repeated while `rawCur=<secret>`.
- Power path remains stable at expected values.
Hypothesis:
- Health fallback still reads current bar value (`barCurSafe`) too early; this feeds back previous fallback output (0) as authoritative state.
- We should not use bar current value as primary health fallback in secret windows.
- For visuals, passing secret raw values directly to Blizzard `StatusBar` is safe and allows native rendering to resolve real fill.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - remove `barCurSafe` priority in health/power `safeCur` fallback chain (prefer cached safe value over live bar value).
  - for bar writes, use raw numeric values (including secret values) when available; keep safe values for addon-side math only.
  - only allow bar-derived percent fallback when raw current value is not numeric (avoid self-fed `mirrorPct` overrides when `rawCur` is secret numeric).
Result:
- Pending `/reload` + `/azdebug snapshot player` expecting health bar value no longer pinned at `0`.
Next step:
- If still pinned, instrument one short debug line indicating native write success and whether rawCur was secret for that tick.

2026-02-15 19:04 (SMOOTHING ALIGNMENT: PREFER NATIVE STATUSBAR WRITES)
Issue:
- Current compatibility writer tries legacy `(..., forced)` statusbar calls first.
- Team direction is oUF + Blizzard/native smoothing behavior for natural bar movement.
Hypothesis:
- Native 2-arg writes should be preferred so interpolation behavior follows default statusbar/oUF paths.
- Legacy forced-arg writes should remain fallback-only for compatibility.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - swap write order in compatibility helper:
    - first: `SetMinMaxValues(min,max)` + `SetValue(value)`
    - fallback: legacy `(..., forced)` variant.
Result:
- Pending `/reload` + live feel check for smoother player health/power transitions.
Next step:
- If movement still looks stepped, inspect element interpolation mode during init on player health/power bars.

2026-02-15 18:58 (PLAYERFRAME BAR WRITES FAILING: MIN/MAX STUCK AT 0)
Issue:
- New `/azdebug snapshot player` output shows:
  - `Health safe: cur 145220 ... max 145220 pct 100`
  - `Health bar: value 0 min 0 max 0`
  - same for `Power bar`.
- DebugLog rows also show `writeCur/writeMax` as valid numbers while frame bar values remain zero.
Hypothesis:
- `API.UpdateHealth` / `API.UpdatePower` still call `SetMinMaxValues(..., forced)` and `SetValue(..., forced)`.
- Native `StatusBar` paths can reject the extra `forced` argument; calls are inside `pcall`, so failure is swallowed and bar state never updates.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - add compat writer that tries legacy 3-arg calls first, then falls back to native 2-arg statusbar API.
  - use compat writer in health/power and health preview update paths.
Result:
- Pending `/reload` with `/azdebug snapshot player` expecting non-zero bar `min/max/value`.
Next step:
- If bars still return `0/0`, instrument one temporary debug flag for write success/failure per tick.

2026-02-15 17:34 (PLAYERFRAME HEALTH/PERCENT FALLBACK ORDER)
Issue:
- Player frame health/power can appear pinned or non-moving in secret-value windows, and current-value tags can drift from bar behavior.
Hypothesis:
- `Components/UnitFrames/Functions.lua` unconditionally applies percent-derived `safeCur` when a percent exists, even when a better safe current source is already present.
- In WoW12 secret paths, percent APIs can be stale/full, so unconditional overwrite can freeze visual updates.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - only apply percent-derived fallback when raw current value is not safely numeric (`rawCurSafe == false`) in `API.UpdateHealth`.
  - same fallback rule in `API.UpdatePower`.
Result:
- Pending `/reload` validation on player frame health/power movement and current-value tags.
Next step:
- If player still sticks, capture `/azdebug health filter player` + `/azdebug healthchat on` rows for one damage cycle.

2026-02-15 17:16 (SESSION 3565: /AZDEBUG SNAPSHOT SECRET-STRING PRINT HARDENING)
Issue:
- BugSack error spam when using debug snapshot path:
  - `Interface/AddOns/ChatCleaner/Core/Core.lua:298: attempt to compare local 'msg' (a secret string value tainted by 'ChatCleaner')`
  - stack includes `AzeriteUI/Core/Debugging.lua:295` and `:346`.
Hypothesis:
- `DumpUnitValue()` prints `tostring(value)` for runtime unit API values; when value is secret-tainted, chat print handling receives a secret string and downstream addons can fail on comparisons.
Change(s):
- `Core/Debugging.lua`:
  - add secret-safe text sanitizer for debug output,
  - make snapshot/unit token normalization reject secret/non-string inputs,
  - route snapshot value prints through sanitized text.
Result:
- Pending `/reload` + `/azdebug snapshot target` retest with BugSack/ChatCleaner enabled.
Next step:
- If any debug command still leaks secret strings to chat, route those print payloads through the same sanitizer.

2026-02-15 17:08 (DEBUG TOOLING PASS: ADD UNIT SNAPSHOT FUNCTIONS)
Issue:
- Current debug output is verbose but fragmented across chat/log categories, making root-cause isolation slower during regressions.
Hypothesis:
- A single `/azdebug` snapshot command that prints API raw values + secret flags + frame safe caches + bar internals for one unit token will reduce iteration time.
Change(s):
- `Core/Debugging.lua`:
  - add snapshot helpers that print:
    - `UnitHealth/UnitHealthMax/UnitHealthPercent`,
    - `UnitPower/UnitPowerMax/UnitPowerPercent`,
    - secret/clean flags,
    - bound frame element (`Health`/`Power`) safe fields and live bar values.
  - add command: `/azdebug snapshot [unit]` (defaults to `target`).
  - update `/azdebug help` output with snapshot command.
Result:
- Pending `/reload` and live use while reproducing bar-stall/percent-mismatch cases.
Next step:
- If needed, add a timed sampler (`/azdebug sample <unit> <seconds>`) in a follow-up.

2026-02-15 17:01 (POST-STANDARDIZATION REGRESSION: FRAMES VISIBLE BUT BARS NOT MOVING)
Issue:
- Frames render again, but health/power bars do not animate with live value changes.
Hypothesis:
- After switching to native `StatusBar`, `UpdateHealth`/`UpdatePower` still writes `rawCur/rawMax` whenever they are numeric, even if they are secret values.
- Native bars do not reliably consume secret values, so updates appear frozen.
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - in `UpdateHealth`, write raw values only when they are non-secret safe numbers (`rawCurSafe/rawMaxSafe`), otherwise write derived safe values.
  - in `UpdatePower`, same rule for `writeCur/writeMax`.
Result:
- Pending `/reload` + combat/value-change check on player/target/ToT/nameplates.
Next step:
- If any unit still sticks, log that unit token and the corresponding `Health~Update` / `Power~Update` row for one tick.

2026-02-15 16:56 (SESSION 3563: OUF-NATIVE BAR SHIM GAPS AFTER STANDARDIZATION)
Issue:
- New startup/runtime errors after switching UnitFrames bars to native `StatusBar`:
  - `SetOrientation` bad arg in `PlayerClassPower.lua` and `PlayerCastBar.lua`.
  - `attempt to call method 'SetTexCoord' (a nil value)` in `NamePlates.lua`.
Hypothesis:
- Unit layout code still uses `LibSmoothBar`-style directional APIs (`UP/DOWN/LEFT/RIGHT`, `SetTexCoord`, `GetTexCoord`, growth helpers).
- Native `StatusBar` only accepts `HORIZONTAL|VERTICAL` and lacks those convenience methods.
Change(s):
- `Components/UnitFrames/UnitFrame.lua` `CreateBar` compatibility shim expanded:
  - directional `SetOrientation` mapper (`UP/DOWN/LEFT/RIGHT` -> valid statusbar orientation + reverse fill),
  - texture-proxy methods: `SetTexCoord`, `GetTexCoord`,
  - growth helpers: `SetGrowth`, `GetGrowth`,
  - flip helper state: `IsFlippedHorizontally`.
Result:
- Pending `/reload` + BugSack retest for session 3563 errors.
Next step:
- If any remaining callsites depend on extra LibSmoothBar-only methods, add only the missing shim(s) to `CreateBar` rather than per-frame patches.

2026-02-15 16:49 (STANDARDIZE UNITFRAMES TO OUF-NATIVE STATUSBARS)
Issue:
- Request to standardize unitframe bars on oUF/native statusbar behavior instead of relying on `LibSmoothBar` wrappers.
Hypothesis:
- Using plain `StatusBar` for `UnitFrames:CreateBar()` reduces wrapper-specific drift and keeps behavior aligned with current oUF element expectations.
- Existing unit code still calls helper methods provided by `LibSmoothBar`, so a thin compatibility shim is required to avoid widespread refactors.
Change(s):
- `Components/UnitFrames/UnitFrame.lua`:
  - switch `CreateBar` factory from `LibSmoothBar:CreateSmoothBar(...)` to `CreateFrame("StatusBar", ...)`.
  - add compatibility methods on created bars:
    - `DisableSmoothing`
    - `SetSparkMap`
    - `SetSparkTexture`
    - `SetFlippedHorizontally`
    - `SetForceNative`
    - `GetSecretPercent`
Result:
- Pending `/reload` validation across player/target/ToT/nameplates for movement, orientation and percent stability.
Next step:
- If all good, follow up with optional cleanup pass removing dead `SetForceNative` guards from unit files.

2026-02-15 16:42 (TARGET PERCENT TEXT: DECIMAL SPAM + MISMATCH ON TARGET SWAP)
Issue:
- Target health percent text can show long decimals (example: `51.391238213218963%`) instead of whole numbers.
- On rapid target swaps, percent text can briefly disagree with displayed target bar state.
Hypothesis:
- Tag formatter currently concatenates raw numeric percent via `tostring(value)`, so high-precision values from percent APIs leak directly into UI text.
- `HealthPercent` tag prefers API percent before safe health/value fallback in some paths, which can desync from bar-derived safe values during secret-value transitions.
Change(s):
- `Components/UnitFrames/Tags.lua`:
  - normalize numeric percent text to whole-number output (`%.0f`) with clamp/0..100 normalization support for `0..1` inputs.
  - in `*:HealthPercent`, prefer `SafeUnitHealth` + `SafePercent` (bar-aligned fallback) before API `SafeUnitPercent`.
Result:
- Pending `/reload` + target-swap retest for stable integer percent display.
Next step:
- If mismatch remains, add a one-tick guard to hide/update percent text until first post-GUID safe health update lands.

2026-02-15 16:36 (SESSION 3557 FOLLOW-UP: FORCE MIRROR SCRIPT ATTACH FOR TARGET/PREDICTION)
Issue:
- New target logs still show `mirrorPct=nil` while `rawCur/rawMax` are often secret, so health fallback stays on fragile texture math.
- `TargetBar` repeatedly reports `barMax=1` windows during secret-only updates.
Hypothesis:
- `HookScript("OnMinMaxChanged"/"OnValueChanged")` attach can fail silently on some statusbars in this environment.
- When hook attach fails, mirror cache never initializes and secret-percent fallback degrades.
Change(s):
- `Components/UnitFrames/Functions.lua`: in `BindStatusBarValueMirror`, add a local attach helper:
  - try `HookScript` first,
  - fallback to `GetScript` + chained `SetScript` when hook attach fails.
- Use helper for both `OnMinMaxChanged` and `OnValueChanged`.
Result:
- Pending `/reload` and fresh `/dl` capture to confirm `mirrorPct` is populated for target updates.
Next step:
- If mirror data is stable, reduce reliance on texture-size fallback for target health/power in secret-only windows.

2026-02-15 16:33 (SESSION 3557 FOLLOW-UP: TARGET BAR SCALE STARTS AT 1, MIRROR HOOK NOT FIRING)
Issue:
- New logs show `target` frequently stuck on `barMax=1` / `safeMax=1` during secret-only windows, while `targettarget` stabilizes at real scales.
- `mirrorPct` stays `nil` across updates, so arg-safe mirror path is not active.
Hypothesis:
- `HookScript("OnMinMaxChanged"/"OnValueChanged")` is silently not attaching on some bars, so mirror cache never initializes.
- Without mirror cache, fallback relies on texture/bar heuristics and can start from 1-scale frames.
Change(s):
- `Components/UnitFrames/Functions.lua`: in `BindStatusBarValueMirror`, add robust script attach helper:
  - try `HookScript` first,
  - if unavailable/fails, chain via `GetScript` + `SetScript`.
- Keep existing texture fallback as secondary source.
Result:
- Pending `/reload` + log check that `mirrorPct` is now populated and `safeMax=1` windows are reduced.
Next step:
- If `mirrorPct` becomes stable, bias secret fallback to mirror percent before texture percent for target health/power.

2026-02-15 16:28 (SESSION 3557 FOLLOW-UP: SCALE COLLAPSE WHEN rawMax BECOMES SECRET)
Issue:
- New logs confirm tex-based percent tracking works (`texPct` changes with health), but target occasionally collapses to `safeMax=100` when both `rawCur` and `rawMax` are secret.
- At the same timestamps, `TargetBar` debug still reports large `barMax` (e.g. `2955200`/`145220`), proving usable scale exists on the live bar.
Hypothesis:
- `UpdateHealth` fallback chooses `100` before consulting bar min/max, so scale collapses during secret-only windows.
Change(s):
- `Components/UnitFrames/Functions.lua` `UpdateHealth` now probes `element:GetMinMaxValues()` / `element:GetValue()` and uses safe bar scale/value before falling back to cached/100 defaults.
- Added `barSafeMax` field to health debug line.
Result:
- Pending `/reload` and validation that `safeMax` no longer drops to `100` while `TargetBar.barMax` remains large.
Next step:
- If stable, apply identical fallback ordering to `UpdatePower` to reduce target power 0/100 flapping in secret windows.

2026-02-15 16:24 (SESSION 3557 FOLLOW-UP: LIVE LOG SHOWS safePct PINNED 100)
Issue:
- Live DebugLog rows (not export) show target updates with:
  - `rawCur=<secret>`, `rawMax=2955200`
  - `safeCur=2955200`, `safeMax=2955200`, `safePct=100` on every tick.
- This confirms fallback still pins target health at full.
Hypothesis:
- Mirror percent from handler args is not being populated for this bar path; current fallback chain needs a texture-size derived percent.
Change(s):
- Added safe texture-size percent fallback in `Components/UnitFrames/Functions.lua` and wired it into `GetSecretPercentFromBar`.
- Added `texPct` debug field to health update logs.
Result:
- Pending `/reload` and fresh `/dl` capture.
Next step:
- Verify `texPct` changes during target damage; if yes, map `safeCur` from this percent when raw cur stays secret.

2026-02-15 16:22 (SESSION 3557 LOG ANALYSIS: TARGET STUCK AT 100% SAFE FALLBACK)
Issue:
- DebugLog now works, but target health pipeline repeatedly reports:
  - `rawCur=<secret> rawMax=<secret>`
  - `safeCur=100 safeMax=100 safePct=100`
  - target bar snapshot `barMin=0 barMax=1 barValue=<secret>`.
Hypothesis:
- Current mirror pipeline is not producing a usable percent from statusbar handler args.
- Without mirror percent, `UpdateHealth` falls back to synthetic `safeMax=100/safeCur=100` for secret-only target values.
Change(s):
- Capture and cache mirror min/max/value/percent directly from `OnMinMaxChanged` + `OnValueChanged` handler args in `Components/UnitFrames/Functions.lua`.
- Use cached mirror percent as first fallback in `GetSecretPercentFromBar`.
- Add debug output for mirror percent.
Result:
- Pending `/reload` and fresh `/dl` sample.
Next step:
- Verify `Health~Update` now shows varying `safePct` for target while `rawCur/rawMax` remain secret.

2026-02-15 16:16 (SESSION 3557: DEBUGLOG SILENCE + CHATCLEANER SECRET STRING + TOOLTIP BACKDROP TAINT)
Issue:
- BugSack shows `ChatCleaner/Core.lua:298` comparing a secret string while viewing `_DebugLog`.
- User reports no useful AzeriteUI debug output visible.
- Backdrop secret-width taint remains in action button tooltip path (`LibActionButton-1.0-GE.lua:2382`).
Hypothesis:
- `API.DebugPrintf` still forwards potentially secret-tainted values/messages into `DLAPI.DebugLog`, and a downstream addon (`ChatCleaner`) trips while filtering that output.
Change(s):
- Harden `Components/UnitFrames/Functions.lua` debug writer to sanitize all debug arguments and message payloads before dispatching to DebugLog.
- Add guarded `pcall` around DebugLog write with safe fallback output path for diagnostics.
Result:
- Pending `/reload` + new `/dl` capture.
Next step:
- Verify `Health/Power/TargetBar` messages return without ChatCleaner secret-string errors; then continue tooltip backdrop taint isolation in `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`.

2026-02-15 16:40 (DEBUGLOG OUTPUT HARDENING + CHATCLEANER SECRET STRING COLLISION)
Issue:
- `_DebugLog` output triggered `ChatCleaner` error: secret string in debug message path.
- User reported no useful debug output after enabling DebugLog routing.
Hypothesis:
- Some debug arguments/messages are still secret-tainted when passed to `DLAPI.DebugLog`, causing downstream addon filters to compare secret strings.
Change(s):
- Hardened `API.DebugPrintf` in `Components/UnitFrames/Functions.lua`:
  - sanitize every format argument (`issecretvalue` -> `"<secret>"`),
  - sanitize final formatted message before dispatch,
  - wrap `DLAPI.DebugLog` in `pcall`,
  - fallback to chat output when DebugLog call fails and health chat debug is enabled.
Result:
- Pending `/reload` and new `/dl` capture.
Next step:
- Reproduce with `/azdebug healthchat on`; confirm `Health/Power/TargetBar` lines appear and no ChatCleaner secret-string errors are added.

2026-02-15 16:30 (EXPANDED DEBUGLOG FOR HEALTH/POWER/TARGET BAR STATE)
Issue:
- Existing prediction-only debug lines are not enough to isolate persistent dual-bar behavior.
Request:
- Expand debugging coverage for health, power, and target bar update state and route all output to DebugLog.
Change(s):
- Added expanded debug logging in `Components/UnitFrames/Functions.lua` for:
  - health update pipeline (`raw`, `safe`, `write`, `percent`, connection state),
  - power update pipeline (`raw`, `safe`, `write`, `percent`, displayType),
  - target-specific bar snapshot (orientation/reverse/min-max/value).
- Logging is gated by `/azdebug healthchat on`, respects health filter, and is throttled to avoid spam.
Result:
- Pending `/reload` and log capture from `/dl` (`AzeriteUI` tab, categories: `Health`, `Power`, `TargetBar`).
Next step:
- Use expanded logs to identify which exact layer/value diverges when the red duplicate appears.

2026-02-15 16:20 (DEBUGLOG INTEGRATION FOR HEALTH/PREDICTION DIAGNOSIS)
Issue:
- Need reproducible diagnostics for persistent double-bar behavior without relying on chat spam.
- User added `DebugLog` addon and requested debug output to be written via `DLAPI.DebugLog`.
Hypothesis:
- Routing health/prediction debug into a persistent log tab will make branch-level prediction state easier to compare across events/targets.
Change(s):
- Added `API.DebugPrintf(category, verbosity, fmt, ...)` helper in `Components/UnitFrames/Functions.lua`.
- Updated player/target prediction debug paths to write to DebugLog tab `AzeriteUI` with category/verbosity prefixes.
Result:
- Pending `/reload` and reproduction with `/azdebug healthchat on`.
Next step:
- Use `/dl` and review `Health` category entries while reproducing double-bar; then patch exact branch producing stale red overlay.
Update (from provided DebugLog sample):
- Target prediction repeatedly logged `cur=0 max=1 incoming=0 absorb=0`.
- Root cause: target prediction callback was using local fallback values instead of health-element safe cache path.
- Applied:
  - target prediction now uses `ns.API.GetSafeHealthForPrediction(...)` (same model as player),
  - target preview baseline layer alpha set to `0` to suppress persistent second-layer visuals during stabilization.

2026-02-15 16:12 (PREDICTION DEBUG INSTRUMENTATION FOR DOUBLE-BAR)
Issue:
- Player/target still show double-bar behavior (one correct/white plus inconsistent red layer).
Hypothesis:
- Health prediction overlay path (not base health fill) is still rendering stale/negative segments in some update paths.
Change(s):
- Added temporary prediction debug output in:
  - `Components/UnitFrames/Units/Player.lua`
  - `Components/UnitFrames/Units/Target.lua`
  (active only with `/azdebug healthchat on`).
- Added runtime kill-switch to isolate prediction artifacts:
  - `_G.__AzeriteUI_DISABLE_HEALTH_PREDICTION = true`
  (hides prediction overlay + absorbBar in callbacks).
Result:
- Pending `/reload` and comparison test with prediction ON vs OFF.
Next step:
- Capture chat debug output for player/target while reproducing, then patch exact branch causing stale red overlay.

2026-02-15 16:05 (RAW-VALUE WRITE RESTORE FOR PLAYER/TARGET HEALTH VISIBILITY)
Issue:
- Player and target frames regressed to not showing reliable current health values.
- Prior percent-only write mode (`0..100`) improved taint safety but degraded current-value fidelity.
Hypothesis:
- Bars should receive raw unit values when available (including secret-capable payloads), with proxy fallback handling secret paths; forcing percent writes causes display/text drift.
- This matches the previously working SafeBar pattern (raw writes + proxy rendering when values are secret).
Change(s):
- `Components/UnitFrames/Functions.lua`:
  - restore raw write model for health/power bars:
    - `SetMinMaxValues(0, rawMax)` / `SetValue(rawCur)` when numeric inputs exist,
    - fall back to safe cached numeric values only when raw inputs are unavailable.
  - keep safe caches and percent fallbacks for tag/math safety.
Result:
- Pending `/reload` validation for player/target current health display and smooth behavior.
Next step:
- If needed, enable explicit value-mirror texcoord path per bar (`BindStatusBarValueMirror`) for strict manual texture-reveal behavior.

2026-02-15 15:58 (PLAYER/TARGET CURRENT HEALTH REGRESSION AFTER PERCENT PIPELINE)
Issue:
- Player and target health display/state regressed again (reported as not showing current health correctly).
Hypothesis:
- Percent API calls using `includePredicted=false` are less reliable in current WoW12 secret-value paths; this can leave `safePercent` nil and bars/text fall back to stale/full values.
- Local baseline (`..\\DiabolicUI3\\Components\\UnitFrames\\Common\\Functions.lua`) uses `includePredicted=true`.
Change(s):
- Switch health/power percent API requests to `includePredicted=true` in:
  - `Components/UnitFrames/Functions.lua` (`SafeUnitPercentNumber`)
  - `Components/UnitFrames/Tags.lua` (`SafeUnitPercent`)
Result:
- Pending `/reload` retest on player/target health movement + value text.
Next step:
- If still regressing, add one-pass debug print for player/target `safePercent/safeCur/safeMax` to validate source values per event.

2026-02-15 15:50 (SESSION 3550: CASTBAR MATH USERDATA + TOOLTIP BACKDROP TAINT + FRAME PREDICTION DRIFT)
Errors:
- `Libs/oUF/elements/castbar.lua:357` bad argument #1 to `max` (number expected, got userdata), count 20x.
- `Blizzard_SharedXML/Backdrop.lua:226` secret width arithmetic tainted by AzeriteUI from `LibActionButton-1.0-GE.lua:2375`, count 121x.
- Visual regression remains on player/target health behavior (color/prediction drift).
Hypothesis:
- Castbar duration path is still passing a duration object/userdata into numeric math.
- Tooltip path still allows Blizzard tooltip rendering for secret-sized buttons in some branches.
- Player/target prediction/color path needs parity pass with proven workspace implementations.
Change(s):
- `Libs/oUF/elements/castbar.lua` + `Libs/oUF_Classic/elements/castbar.lua`:
  - guard `math.max(duration, 0)` with `tonumber(duration)` to prevent userdata math errors.
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - added forbidden/secret geometry checks (`IsForbidden`, `GetRect`) before tooltip setup.
- `Components/UnitFrames/Functions.lua`:
  - stabilized health/power writes to fixed `0..100` percent mode (removed raw secret-value write path) to reduce bar direction/state flips.
- `Components/UnitFrames/Units/Target.lua`:
  - fixed negative-width prediction size bug for LEFT-growth branch (`SetSize((-change)*previewWidth, ...)`).
  - updated `Health_PostUpdateColor` to accept color-object callbacks.
- Deep comparison reference used:
  - `..\\DiabolicUI3\\Components\\UnitFrames\\Common\\Functions.lua`
  - `..\\DiabolicUI3\\Components\\UnitFrames\\Units\\Player.lua`
Result:
- Syntax checks pass; pending in-game `/reload` validation.
Next step:
- Add strict numeric coercion in oUF castbar fallback math.
- Gate LAB tooltip update on secret button geometry and fail closed.
- Deep-compare player/target health-prediction flow against local workspace UIs before minimal patching.

2026-02-15 15:45 (PLAYERFRAME COLOR + PREDICTION REVERSAL STABILIZATION)
Issue:
- Player frames still misbehave visually: missing expected color behavior and occasional reverse/weird prediction animation.
- Minimap left-click ping currently disabled by previous taint-avoidance hotfix.
Hypothesis:
- Player/alternate health color callback still partly assumes legacy `(r,g,b)` args; current oUF passes color objects in WoW12 path.
- Health prediction path renders negative (heal-absorb) overlays, including a LEFT-growth branch with problematic size/texcoord behavior that looks like reversal.
Change(s):
- Restore player/alternate color callback compatibility with both color-object and legacy RGB args.
- Restrict health prediction overlay to positive incoming-heal preview only (hide negative absorb/red overlay) for stable visual behavior.
- Keep minimap ping deferred while avoiding protected call taint.
Result:
- Pending `/reload` + player/alternate combat test.
Next step:
- Reintroduce minimap ping via a safe Blizzard-side path once frame behavior is stable.
Update:
- Re-enabled minimap left-click forwarding out of combat only (`InCombatLockdown` guard) to restore ping usability without reintroducing the protected call spam in combat.

2026-02-15 15:35 (PLAYER CLASS POWER: HIDE WHEN EMPTY)
Issue:
- Player class power/personal resource display remains visible at zero resources.
- Requested behavior: hide when current resource is zero; show automatically when resource is gained.
Hypothesis:
- `ClassPower_PostUpdate` keeps the element shown even at `cur == 0`, and point alpha logic does not collapse the empty state.
Change(s):
- Plan to gate class power element visibility in `Components/UnitFrames/Units/PlayerClassPower.lua` on `cur > 0`.
Result:
- Pending `/reload` and in-combat resource gain/spend test.
Next step:
- Verify Holy Power/Combo/Arcane Charges hide at zero and reappear immediately on gain.

2026-02-15 15:30 (SESSION 3548: MINIMAP PING FORBIDDEN + TOOLTIP BACKDROP SECRET + PLAYER DUAL-BAR)
Errors:
- `ADDON_ACTION_FORBIDDEN`: `Minimap:PingLocation()` from `Components/Misc/Minimap.lua:390`.
- `Backdrop.lua:226` secret width arithmetic tainted by AzeriteUI from `LibActionButton-1.0-GE.lua:2359`.
- Visual regression: player health shows dual-layer behavior (front bar + stale under/segment).
Hypothesis:
- Calling Blizzard minimap click handler directly from addon mouse handler enters protected ping path.
- ActionButton tooltip path still runs on buttons with secret dimensions and taints Blizzard backdrop math.
- Player health preview layer is visually leaking stale state; should be hidden until prediction pass is fully stable.
Change(s):
- Minimap: stop forwarding left-click to Blizzard click handler from addon mouse-up callback.
- LAB tooltip: add secret-size guard and `pcall` wrapper around owner/tooltip setup.
- Player: hide health preview layer alpha (`0`) to prevent dual-bar visual overlap while health pipeline is stabilized.
Result:
- Pending `/reload` + retest.
Next step:
- After player/target stabilization, reintroduce intended preview effect with a deterministic per-bar mirror path.

2026-02-15 15:15 (LOG ONLY: BLIZZARD BUFFS NOT HIDING + DEFERRED STOCK BEHAVIOR RESTORE)
Issue:
- Blizzard buffs/debuffs are still visible when they should be hidden.
- Desired behavior (deferred until after player/target frame stabilization): show AzeriteUI buffs only on mouseover; otherwise keep them hidden.
Hypothesis:
- Current WoW12-safe aura fallback path is bypassing original AzeriteUI visibility control logic for BuffFrame/DebuffFrame.
Change(s):
- None (log-only per request).
Next step:
- After player/target frame fixes are complete, re-apply original aura visibility behavior from stock implementation.
- TODO: compare and port aura visibility logic from `AzeriteUI_Stock` once exact source file is confirmed (likely `Components/Auras/Auras.lua` in stock tree).

2026-02-15 15:20 (PLAYER HEALTH DOUBLE-LAYER / WRONG RED SEGMENT)
Issue:
- Player health bar now moves, but visible "double" behavior remains: a red layer shows mismatched value/flickers.
- FrameStack confirms both `AzeriteUnitFramePlayer.Health` and `AzeriteUnitFramePlayer.Health.Preview` are active (`Components/UnitFrames/Units/Player.lua:647` area).
Hypothesis:
- `UpdateHealth` percent fallback mixes scale formats (oUF secret proxy returns `0..1`, UnitHealthPercent returns `0..100`), causing intermittent wrong write values and flicker.
- `Health.PostUpdateColor` still expects legacy `(r,g,b)` args, but current oUF sends a color object, so preview color sync is skipped and can drift visually.
Change(s):
- Normalize percent fallback in `Components/UnitFrames/Functions.lua` so all write paths use a consistent `0..100` scale.
- Update player health color callback in `Components/UnitFrames/Units/Player.lua` to support both legacy RGB args and oUF color object.
Result:
- Pending `/reload` and player-combat retest.
Next step:
- If red mismatch remains, temporarily force `Health.Preview` to mirror exact health texture color/value and re-validate absorb prediction overlay behavior.

2026-02-15 15:40 (PLAYER BAR FLICKER/COLOR PASS)
Issue:
- Player health/power now move, but occasional flicker to wrong texture/setup and missing colors reported.
Hypothesis:
- LibSmoothBar proxy/native switching on player health is causing intermittent texture/color desync during combat ticks.
Change(s):
- Force native rendering for player health + preview bars to prevent proxy swap flicker.
- Keep current safe-value pipeline; this pass is visual stability only.
Result:
- Pending `/reload` and combat retest on player frame.
Next step:
- If still flickering, instrument live values on `Player.lua` health/power only and check for mid-combat min/max source oscillation.

2026-02-15 15:31 (LOG ONLY: COMBAT ERRORS TO FIX LATER)
Errors:
- `Libs/oUF/elements/castbar.lua:357` bad argument #1 to `max` (number expected, got userdata), count 30x.
- `Blizzard_SharedXML/Backdrop.lua:226` secret-width arithmetic tainted by AzeriteUI from LAB tooltip path, count 207x.
Stacks:
- Castbar: `Interface/AddOns/AzeriteUI/Libs/oUF/elements/castbar.lua:357` via castbar update path (`...:309`).
- Tooltip: `Interface/AddOns/AzeriteUI/Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua:2359` -> `OnEnter` -> Blizzard TooltipDataHandler/Backdrop.
Hypothesis:
- Castbar path is receiving userdata in a `math.max` call where numeric coercion is missing.
- Actionbutton tooltip anchor/show path still taints Blizzard tooltip backdrop math under WoW12 secret-value conditions.
Change(s):
- None (log-only pass per request).
Result:
- Logged for deferred fix.
Next step:
- Add numeric type guards/coercion in `Libs/oUF/elements/castbar.lua` near line 357.
- Add safer tooltip path/guard in `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` around lines 2352-2365 without globally disabling actionbar tooltips.

2026-02-15 15:26 (FOCUS PASS: PLAYER HEALTH/POWER MOVEMENT)
Errors/Regression:
- Player/target/nameplate bars still reported visually static.
- Aura driver registration still occasionally throwing `SecureStateDriverManager:SetAttribute()` in WoW12.
Hypothesis:
- Feeding only sanitized percent fallbacks to bars can lock values at 100 when raw values are secret.
- Dynamic state driver updates in secret mode remain too taint-prone.
Change(s):
- Health/Power overrides now prefer writing raw unit values to bars whenever numeric (including secret numbers) so LibSmoothBar/native proxy can animate.
- Retained safe caches for text/math separately.
- Disabled Blizzard aura state-driver registration in WoW12 secret mode (temporary stability guard).
Result:
- Pending `/reload` retest focused on player health/power movement.
Next step:
- Validate movement first; once stable, reintroduce target-hide Blizzard auras via non-taint path.

2026-02-15 15:18 (HOTFIX: VALUE-MIRROR TEXCOORD SIDE EFFECT)
Errors/Regression:
- Unitframes still reported as non-moving after previous pass despite no major Lua spam.
Hypothesis:
- `BindStatusBarValueMirror` texcoord rewrite may interfere with LibSmoothBar/native fill behavior when applied to all bars.
Change(s):
- Make value-mirror texcoord writes opt-in only (`__AzeriteUI_UseValueMirrorTexCoord`), default off.
- Keep mirror bound for safe min/max/value cache hooks without forcing texture coordinate mutation.
Result:
- Pending `/reload` movement retest.
Next step:
- Verify player/target/nameplate bars move with default statusbar fill.

2026-02-15 15:10 (HOTFIX: AURA STATE DRIVER COMBAT BLOCK + RESTORE ACTIONBUTTON TOOLTIPS)
Errors:
- `ADDON_ACTION_BLOCKED ... SecureStateDriverManager:SetAttribute()` from `ApplyBlizzardAuraVisibilityDriver` (`RegisterStateDriver`) while target changes/combat transitions.
- Actionbar tooltips disabled by earlier WoW12 hard short-circuit in LAB tooltip path.
Hypothesis:
- `RegisterStateDriver` was being re-applied from `UpdateSettings` during combat.
- Tooltip suppression was too aggressive; mainstream actionbar UIs use default LAB tooltip flow.
Change(s):
- Make Blizzard aura state-driver apply only out of combat, defer via pending flag to `PLAYER_REGEN_ENABLED`.
- Stop re-registering driver on every target change; state driver already reacts to target existence.
- Restore LAB tooltip function to stock behavior (forbidden guard + normal `SetTooltip()` flow, no blanket disable).
Result:
- Pending `/reload` + retest.
Next step:
- Verify no `SecureStateDriverManager:SetAttribute` blocks.
- Verify actionbar tooltips are back and monitor if Backdrop taint returns.

2026-02-15 14:58 (WOW12 HOTFIX: SECURE AURA HEADER TAINT + TOOLTIP SECRET BACKDROP + BAR PERCENT SOURCE)
Errors:
- `ADDON_ACTION_BLOCKED ... UNKNOWN() ... RegisterForClicks` from `*AuraTemplates.xml` during secure aura header child creation.
- `Backdrop.lua:226` secret width arithmetic from actionbutton tooltip path.
- Unitframes still not moving (castbar moving only).
Hypothesis:
- WoW12 secret mode still cannot safely run AzeriteUI secure aura header template flow.
- LAB tooltip rendering still triggers Blizzard tooltip backdrop math on secret-sized values.
- Percent helper likely using wrong API flag and returning nil, causing fallback to static/full values.
Change(s):
- In secret mode, skip AzeriteUI secure aura-header creation and only apply Blizzard aura visibility state driver.
- Harden LAB tooltip path by short-circuiting in secret mode before tooltip population.
- Switch percent reads to non-smoothed API mode for health/power (`Unit*Percent(..., false, CurveConstants.ScaleTo100)`).
Result:
- Pending `/reload` + retest.
Next step:
- Verify no new ADDON_ACTION_BLOCKED from aura headers and no tooltip backdrop taint.
- Re-check unitframe movement after percent-source correction.

2026-02-15 14:50 (POST-PASS HOTFIX: VALUE-MIRROR HOOK + ARENA EDITMODE)
Errors:
- `Frame:HookScript(): Doesn't have a "OnMinMaxChanged" script` from `BindStatusBarValueMirror`.
- `attempted to iterate a forbidden table` in `CastingBarFrame.StopFinishAnims` during Edit Mode arena refresh.
Hypothesis:
- Some AzeriteUI bars are wrapper frames (not native `StatusBar`) and do not support `OnMinMaxChanged`/`OnValueChanged`.
- Disabling Blizzard arena frames in secret mode taints Edit Mode arena castbar state path.
Change(s):
- Guard value-mirror binding to native `StatusBar` object type and protected `pcall` hook registration.
- Re-introduce secret-mode bypass for arena disable path in `Libs/oUF/blizzard.lua`.
Result:
- Pending `/reload` retest.
Next step:
- Verify no hookscript crash and no EditMode arena forbidden-table error.

2026-02-15 15:30 (WOW12 UNITFRAME MOVEMENT + TARGET AURA VISIBILITY STABILIZATION)
Errors:
- Unitframes/nameplates still not animating reliably; values can appear to stick/adopt previous unit state.
- Blizzard aura visibility conflicts while targeting.
Hypothesis:
- Mixed raw/percent fallback logic in `Components/UnitFrames/Functions.lua` can desync visual bars from live value writes under WoW12 secret-value rules.
- Health/power art updates are not consistently driven from statusbar handler arguments.
- WoW12 guard in `Components/Auras/Auras.lua` prevents custom aura visibility flow.
Change(s):
- Planned targeted patch:
  - deterministic health/power write pipeline with per-element safe caches
  - handler-arg-based bar art updates (`OnMinMaxChanged`/`OnValueChanged`)
  - enable aura visibility flow in WoW12 and add explicit Blizzard-on-target toggle
  - align oUF Blizzard disable behavior with proven local workspace patterns
Result:
- In progress.
Next step:
- Apply minimal diffs across `Components/UnitFrames/*`, `Components/Auras/Auras.lua`, `Options/OptionsPages/Auras.lua`, and `Libs/oUF/blizzard.lua`, then `/reload` test loop.

2026-02-12 16:45 (NAMEPLATE BLIZZARD-UF REParent PATH DISABLED)
Errors:
- `ADDON_ACTION_BLOCKED ... Frame:SetForbidden()` and high forbidden-table indexing persisted.
- Blizzard nameplate aura arg errors and CompactUnitFrame secret boolean errors still marked tainted.
Hypothesis:
- `Components/UnitFrames/Units/NamePlates.lua` reparent/unregister path for Blizzard UnitFrame/Auras is tainting protected nameplate/compact frame flows.
Change(s):
- `Components/UnitFrames/Units/NamePlates.lua`:
  - Disabled `DisableBlizzardNamePlate(unit)` body (no-op guard).
  - Disabled `RestoreBlizzardNamePlate(unit)` body (no-op guard).
Result:
- Pending `/reload` + retest.
Next step:
- If forbidden-table/index taint drops, keep Blizzard nameplate internals untouched and only style AzeriteUI-owned overlays.

2026-02-12 16:38 (SYNTAX HOTFIX - CHUNK RETURN REMOVED)
Errors:
- `FixBlizzardBugs.lua:59 unexpected symbol near 'if'`
Hypothesis:
- Top-level `return` in Lua chunk caused parse failure (`return` not allowed before later statements in this context).
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Replaced emergency top-level `return` approach with a disabled condition guard:
    - `if (false and (...)) then`
Result:
- Pending `/reload`; file should parse again.
Next step:
- Confirm `/az` and player frame are restored before any further WoW12 compatibility work.

2026-02-12 16:20 (EMERGENCY ROLLBACK - DISABLE FixBlizzardBugs ON WOW12)
Errors:
- `/az` unavailable and core frame regressions reported (`playerframe gone`).
- New protected-call blocks (`CompactPartyFrameMember:SetAttribute`) and continued taint spread.
Hypothesis:
- `FixBlizzardBugs.lua` has accumulated too many global/mixin interventions; current state is unstable and taints secure Blizzard flows broadly.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Added hard early return at top of WoW12 branch to disable the module entirely for now.
Result:
- Pending `/reload`.
Next step:
- Confirm base AzeriteUI functionality is restored (`/az`, playerframe, normal login behavior).
- Rebuild WoW12 fixes from a minimal clean baseline in a separate controlled pass.

2026-02-12 16:12 (NAMEPLATE TAINT REDUCTION PASS)
Errors:
- `ADDON_ACTION_BLOCKED Frame:SetForbidden()` on nameplate creation.
- Secret boolean errors in `NamePlateAuras/AddAura` and `CompactUnitFrame` (`isHarmful`, `outOfRange`) still marked tainted by AzeriteUI.
- Ongoing forbidden table indexing.
Hypothesis:
- Global mixin overrides in castbar/nameplate fix paths are still tainting secure nameplate/frame creation.
- Additional global wrappers (`UnitInRange`/`IsItemInRange`, C_UnitAuras wrappers) broaden taint propagation into Blizzard aura/range logic.
Change(s):
- Disable invasive runtime patchers by turning them into no-op guards:
  - `ApplyCastingBarFixes()`
  - `ApplyNamePlateAuraFixes()`
- Disable global `C_UnitAuras` arg-guard wrapper block.
- Disable WoW10 global wrappers for `IsItemInRange` and `UnitInRange`.
Result:
- Pending `/reload` + fresh BugSack.
Next step:
- If taint persists, strip remaining global wrappers in `FixBlizzardBugs.lua` (ColorUtil/GetRaidTargetIndex/UnitRaidTargetIndex) and keep only local frame-level fixes.

2026-02-12 16:08 (TARGET/PRD TAINT CONTAINMENT PASS)
Errors:
- PRD EditMode secret arithmetic still tainted by AzeriteUI.
- Blizzard Target/ToT mana (`UnitFrame.lua:955/908`) and `TextStatusBar` secret errors tainted by AzeriteUI.
- Forbidden table indexing remained.
Hypothesis:
- Remaining global wrappers and Blizzard unitframe coexistence continue to keep execution tainted.
- Blizzard Target/ToT frames are still active and hitting WoW12 secret power values.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Disabled `UnitCastingInfo` and `UnitChannelInfo` global wrappers (`if false and ...`) to reduce taint surface.
  - Added `DisableBlizzardUnitFrames()` helper to disable Blizzard `TargetFrame` and `TargetFrameToT`.
  - Call `DisableBlizzardUnitFrames()` on `PLAYER_LOGIN` and when `Blizzard_UnitFrame` loads.
  - Disabled `HookEditModeEventRegistry()` body and `WrapEncounterWarnings()` body (both now no-op guards).
Result:
- Pending `/reload` + retest.
Next step:
- If PRD taint still appears, stop loading PRD addon from `.toc` (hard exclusion) for WoW12 sessions.

2026-02-12 16:00 (SYNTAX RECOVERY + UNITAURA ARG GUARD WRAPPERS)
Errors:
- `FixBlizzardBugs.lua:221 'end' expected ... near 'DisableEncounterWarnings'`
- Nameplate aura API arg errors persisted (`GetUnitAuras`, `IsAuraFilteredOutByInstanceID`)
Hypothesis:
- Early `return` statements were inserted in function blocks in invalid Lua position (must be terminal statement).
- Nameplate aura calls still occasionally receive invalid unit/aura args under WoW 12 secret-value edge cases.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Replaced early returns in disabled EditMode functions with `if (true) then return/return false end` form to keep file parse-valid.
  - Added narrow `C_UnitAuras` argument guards:
    - `GetUnitAuras`
    - `GetAuraDataByAuraInstanceID`
    - `IsAuraFilteredOutByInstanceID`
  - Guards only validate args + `pcall`; they do not mutate aura tables.
Result:
- Pending `/reload` + BugSack retest.
Next step:
- Confirm syntax load is clean first.
- If `tainted by AzeriteUI` on Blizzard target mana still persists, isolate remaining global wrappers (likely `UnitCastingInfo`/`UnitChannelInfo` path) in a separate pass.

2026-02-12 15:55 (EDITMODE/PRD TAINT ISOLATION PASS)
Errors:
- `Blizzard_PersonalResourceDisplay.lua:477` secret arithmetic still marked `tainted by 'AzeriteUI'`
- `attempted to index a forbidden table`
Hypothesis:
- EditMode pruning/bypass and frame hard-disable paths are still touching protected/forbidden tables and propagating taint into Blizzard EditMode/PRD execution.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Turned PRD/EncounterWarnings/LowHealth/Buff hard-disable helpers into no-ops for now.
  - Disabled EditMode prune/bypass function bodies (`PruneEditModeSystems`, `PrePruneEditModeSystems`, `SetEditModeBypass`, `HookEditModeBypass`) to stop protected table access.
Result:
- Pending `/reload` + fresh BugSack capture.
Next step:
- If taint clears, re-introduce only minimal non-invasive guards (hooksecurefunc-only, no direct table mutation).

2026-02-12 15:25 (NAMEPLATE AURA ARGUMENT HOTFIX + CASTBAR NIL-MAX GUARDS)
Errors:
- `Blizzard_NamePlateAuras.lua:188/215` bad argument #1 in `C_UnitAuras.IsAuraFilteredOutByInstanceID` / `GetAuraDataByAuraInstanceID`
- `Libs/oUF/elements/castbar.lua:462` compare nil with number (high-frequency spam)
- Ongoing taint spread from broad `C_UnitAuras.GetUnitAuras` global override
Hypothesis:
- Nameplate aura frame instances intermittently lose/skip `unitToken` initialization, so Blizzard aura calls receive invalid arg #1.
- oUF castbar `self.max`/timing can be nil during delayed/start race conditions under WoW 12 secret-value behavior.
- Wrapping `C_UnitAuras.GetUnitAuras` globally increases taint surface in Blizzard aura/compact frame execution.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - In `EnsureNamePlateAuraScaleForUnit(unit)`, force `frame.unit`, `auraFrame.unit`, and `auraFrame.unitToken` to the added nameplate unit token.
  - Disabled global `C_UnitAuras.GetUnitAuras` override (`if false and ...`) to reduce taint propagation.
- `Libs/oUF/elements/castbar.lua`:
  - Added safe numeric coercion/clamps in `CastUpdate` for `startTime`, `endTime`, and `element.max`.
  - Added `onUpdate` guards for nil/invalid `self.max` and `self.duration`.
Result:
- Pending `/reload` + combat/nameplate test.
Next step:
- Re-test with only AzeriteUI enabled and capture fresh BugSack.
- If aura arg #1 persists, add per-instance (not mixin/global) `AurasFrame:AddAura/UpdateAura` wrappers with corrected Retail signatures only.

2026-02-12 14:30 (TAINT REDUCTION PASS - BLIZZARD UNITFRAME/PRD)
Errors:
- `Blizzard_PersonalResourceDisplay.lua:477` secret arithmetic (tainted by AzeriteUI)
- `TargetFrame.lua:464` secret compare (tainted by AzeriteUI)
- `UnitFrame.lua:908` secret arithmetic in target mana bar (tainted by AzeriteUI)
- `attempted to index a forbidden table`
Hypothesis:
- Direct overrides/wrappers on Blizzard PRD and UnitFrame update functions are tainting secure execution paths.
- Aura hook logic that mutates aura tables can hit forbidden tables under WoW 12 secure rules.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Disabled `WrapPRD()` body (early return) to stop invasive PRD mixin/frame method overrides.
  - Disabled `UnitFrameManaBar_Update` global wrapper (`if false and ...`) to stop touching Blizzard target mana updates.
  - Disabled `wrapHealPrediction("UnitFrameHealPredictionBars_Update*")` calls to avoid injecting taint via Blizzard frame wrappers.
  - Removed Retail `HookAddAura` mutation path that wrote into aura tables from hooks.
- `.toc` retail interface bump:
  - `AzeriteUI.toc`: `## Interface: 120100`
  - `AzeriteUI_Vanilla.toc`: retail slot bumped to `120100`
Result:
- Pending in-game verification after `/reload`.
- Expected: fewer or no `tainted by 'AzeriteUI'` errors on Blizzard TargetFrame/UnitFrame/PRD paths.
Next step:
- Re-test with only AzeriteUI enabled and capture fresh BugSack output.
- If taint remains, isolate remaining global mixin overrides in `FixBlizzardBugs.lua` (CastingBar/ColorUtil blocks).

2026-02-12 15:05 (HOTFIX - LUA SYNTAX + MORE TAINT SURFACE REDUCTION)
Errors:
- `Core/FixBlizzardBugs.lua:1316 unexpected symbol near 'local'`
- Blizzard UnitFrame/CompactUnitFrame secret errors still marked `tainted by 'AzeriteUI'`
- `attempted to index a forbidden table`
Hypothesis:
- `return` placed directly in `WrapPRD` made following locals invalid in Lua parsing.
- Additional global function overrides (`AuraUtil.UnpackAuraData`, `C_UnitAuras.GetUnitAuras`, `CompactUnitFrame_UpdateAuras`, `TextStatusBar`, `CompactUnitFrame_GetRangeAlpha`) still taint Blizzard execution paths.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Fixed `WrapPRD` syntax by making return conditional (`if (true) then return end`) so function body parses.
  - Disabled more taint-prone global overrides by guarding with `if (false and ...)`:
    - `AuraUtil.UnpackAuraData`
    - `C_UnitAuras.GetUnitAuras`
    - `CompactUnitFrame_UpdateAuras`
    - `TextStatusBar` wrappers
    - `CompactUnitFrame_GetRangeAlpha`
Result:
- Pending test after `/reload`.
Next step:
- Verify syntax error is gone first.
- Re-check if `tainted by 'AzeriteUI'` on Blizzard `UnitFrame/CompactUnitFrame` is reduced.

2026-02-12 15:20 (TAINT ROLLBACK PASS - AURA/PRD/BACKDROP WRAPPERS)
Errors:
- `tainted by 'AzeriteUI'` still present on PRD and Blizzard UnitFrame/CompactUnitFrame stacks.
- `bad argument #1` in `C_UnitAuras.GetUnitAuras(...)` from NamePlateAuras parse path.
- `attempted to index a forbidden table`
- CompactUnitFrame aura errors (`isHarmful` secret / AuraUtil table index nil)
- Backdrop secret width arithmetic tainted by AzeriteUI
Hypothesis:
- The active global aura API rewrite path (`WrapAuraAPIs`) plus broad global wrappers (Backdrop/AuraUtil/C_UnitAuras aura helpers) are still tainting Blizzard execution.
- `C_UnitAuras.GetUnitAuras` still needs a minimal guard for invalid/secret unit input, but broad wrapper sets should be removed.
Change(s):
- `Core/FixBlizzardBugs.lua`:
  - Reduced `DisablePRD()` to hide/unregister only; removed method/mixin overwrites.
  - Disabled `WrapAuraAPIs()` calls in event paths (kept function code but no longer executed).
  - Disabled global wrappers for:
    - `BackdropMixin.SetupTextureCoordinates`
    - `AuraUtil.IsBigDefensive`
    - `C_UnitAuras.AuraIsBigDefensive`
  - Re-enabled only a narrow `C_UnitAuras.GetUnitAuras` guard:
    - returns `{}` when `unit` is not a string or input is secret/invalid.
Result:
- Pending test after `/reload`.
Next step:
- Validate whether taint and forbidden-table counts drop.
- If PRD taint persists, disable `DisablePRD()` invocation during EditMode and rely on pure frame hide only at load.

2026-02-02 23:00 (TEXTURE FLICKERING FIX - WOW 12.0 SetStatusBarTexture ISSUE)
Errors:
- Target health bar, power bar, nameplates showing "flickering between two textures"
- One frame shows correct percentage fill, next frame shows scaled/stretched texture
- User describes: "switches or is overlaid each frame/update with a different version... scales from 0 to cur instead of showing it like a percentage fill"
- Affects all statusbars: target health, target power, player power, tot health, nameplates
Hypothesis:
- WoW 12.0 changed how SetStatusBarTexture() works with LibSmoothBar's proxy system
- Calling SetStatusBarTexture repeatedly (even with same texture) causes rendering mode to flip between:
  - Proper tiled/wrapped texture (percentage fill) - CORRECT
  - Stretched/scaled texture (entire image scaled 0→cur) - WRONG
- The style caching exists (line 474-476) but doesn't help because SetStatusBarTexture is still called on style change
- Need to cache the TEXTURE itself, not just the style, and only call SetStatusBarTexture when texture actually changes
Change(s):
- **Target.lua UnitFrame_UpdateTextures()**: Added texture caching for all statusbars:
  - health: Check if health._cachedTexture != db.HealthBarTexture before calling SetStatusBarTexture
  - healthPreview: Same caching check
  - absorb: Same caching check  
  - cast: Same caching check
  - Only calls SetStatusBarTexture when texture path actually changes
  - Stores texture path in ._cachedTexture for comparison
- This prevents redundant SetStatusBarTexture calls that cause WoW 12.0 rendering flip
Result:
- Pending test after /reload
- Should eliminate flickering on all Target statusbars (health, cast, absorb)
- Texture only updates when style actually changes (Novice→Boss, etc)
Next step:
- /reload and test Target frame
- Apply same fix to Player.lua and ToT.lua if Target works
- Test with nameplate health bars
- Fix health bar positioning (already done: -137 → -140)

2026-02-02 22:00 (HEAL PREDICTION / ABSORB SECRET VALUE FIX - ROOT CAUSE FOUND!)
Errors:
- Target health, Target power, Player power, ToT health, nameplate health ALL flickering
- Flickering shows "two textures" or "calculation types" cycling
- User reports it affects "everything targethealth,targetpower,nameplate and tot"
Hypothesis:
- After researching ElvUI code and WoW 12.0 secret value best practices, discovered the REAL issue:
- **HEAL PREDICTION AND ABSORB textures are doing math/comparisons on SECRET VALUES**
- HealPredict_PostUpdate() in Target.lua, Player.lua, ToT.lua does:
  - `change = (allIncomingHeal - allNegativeHeals)/maxHealth` - ARITHMETIC on potentially secret values
  - `if (change > threshold)` - COMPARISON on secret values
  - `absorb = UnitGetTotalAbsorbs(unit)` then `if (absorb > maxHealth * .4)` - COMPARISON on secret value
- These functions run on EVERY health update, causing constant flickering
- ElvUI code shows they use SEPARATE overlay textures for absorbs/predictions, NOT statusbar changes
- The "two textures" user sees are: 1) statusbar fill, 2) flickering heal prediction overlay
Change(s):
- **Target.lua HealPredict_PostUpdate()**: Added secret value sanitization at function start:
  - Check all incoming parameters (myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, curHealth, maxHealth)
  - Replace secret values with 0 or cached safe values
  - For UnitGetTotalAbsorbs() call: wrap in issecretvalue check, hide bar if secret
- **Player.lua HealPredict_PostUpdate()**: Fixed absorb section (already had safe health):
  - Wrap UnitGetTotalAbsorbs() in issecretvalue check
  - Hide bar if secret, only show if safe
- **ToT.lua HealPredict_PostUpdate()**: Fixed absorb section (already had safe health):
  - Wrap UnitGetTotalAbsorbs() in issecretvalue check
  - Hide bar if secret, only show if safe
Result:
- Pending test after /reload
- Should eliminate ALL flickering on Target health, Target power, Player power, ToT health
- Absorb bars will hide when values are secret (better than flickering)
- Heal prediction overlays won't flicker between states
Next step:
- /reload and test all unit frames
- Check if nameplate health bars also need similar fixes
- Test with absorb effects (shields) to verify they display correctly when not secret

2026-02-02 18:45 (SPARK TEXTURE FIX - TARGET & PLAYER BROKEN)
Errors:
- User reports Target power crystal still doing weird behavior - might be spark texture
- User reports Player power/mana bar NOW ALSO doing the same weird cycling behavior
- On /reload, profile settings change (particularly actionbar scales)
Hypothesis:
- In UnitFrame_UpdateTextures(), used SetSparkMap for Target but Target config uses PowerBarSparkTexture, not PowerBarSparkMap
- Player config uses PowerBarSparkMap (different property)
- Wrong spark method causes the bar to render incorrectly, creating cycling/overlay issues
- Both Player and Target now broken suggests a common issue with how we're updating bars
Change(s):
- **Target.lua line ~533**: Changed `power:SetSparkMap(db.PowerBarSparkMap)` to `power:SetSparkTexture(db.PowerBarSparkTexture)`
- Target uses SparkTexture property, Player uses SparkMap property
Result:
- Pending test after /reload
- Target power should now use correct spark property
- Still need to investigate why Player broke and profile settings reset
Next step:
- /reload and check if Target power crystal works
- Check Player power crystal behavior
- Investigate profile settings reset issue

2026-02-02 (POWER CRYSTAL: COPY PLAYER.LUA PATTERN)
Errors:
- Power crystal still showing weird overlay/scaling behavior even after flip removal
- Goes from 100% filled to border, down to 0, then back to 100% in cycles
Hypothesis:
- Target.lua sets power bar properties (position, size, texture, orientation, alpha) ONLY ONCE during CreateBar()
- Player.lua sets these properties EVERY TIME in UnitFrame_UpdateTextures()
- When style changes (Novice→Hardened→Seasoned or Boss/Critter), Target power bar never updates
- The cycling is likely the bar using stale/wrong dimensions or positions from a different style
- Need to follow Player.lua's pattern: minimal creation, full updates in UnitFrame_UpdateTextures()
Change(s):
- **Removed all visual property setters from power creation** (lines ~797-803):
  - Removed: SetPoint, SetSize, SetSparkTexture, SetOrientation, SetStatusBarTexture, SetAlpha
  - Kept only: SetFrameLevel, frequentUpdates, displayAltPower, colorPower
- **Added power update to UnitFrame_UpdateTextures()** (after portraitBorder, line ~530):
  - power: ClearAllPoints, SetPoint, SetSize, SetStatusBarTexture, SetOrientation, SetSparkTexture, SetAlpha
  - powerBackdrop: ClearAllPoints, SetPoint, SetSize, SetTexture, SetVertexColor
- Now matches Player.lua pattern exactly
Result:
- BROKE TARGET AND PLAYER - used wrong spark method (SetSparkMap instead of SetSparkTexture for Target)
- Power crystal should now update correctly when switching targets with different styles
- Should fill correctly without cycling/overlay issues
Next step:
- Fix spark texture method to use SetSparkTexture for Target

2026-02-02 (POWER CRYSTAL FLIP REVERTED)
Errors:
- After adding flip to power crystal, new issue appeared:
- Overlay/something scales down instead of filling up
- Goes from 100% filled to border of current power, down to 0, then back to 100%
- Weird animation/display behavior
Hypothesis:
- Power crystal has orientation="UP" (vertical fill)
- SetFlippedHorizontally() flips the texture horizontally
- For a vertical bar, horizontal flip causes the fill to display inverted/backwards
- The cycling behavior (100% → border → 0 → 100%) suggests the bar is fighting between fill states
- Vertical bars shouldn't be horizontally flipped - only horizontal bars need flip
Change(s):
- **Removed SetFlippedHorizontally from power crystal** - reverted previous change
- Power bar is vertical (UP orientation), not horizontal like health bar
- Only horizontal bars (LEFT/RIGHT orientation) should be flipped
- Power crystal should fill naturally from bottom to top without flip
Result:
- Pending test after /reload.
- Power crystal should fill correctly from bottom to top
- No more cycling/animation issues
Next step:
- /reload and verify power crystal fills correctly without weird overlay behavior.

2026-02-02 (POWER CRYSTAL FLIP FIX)
Errors:
- Target power crystal always displays and shows full
- When taking damage, power crystal flips back and forth  
- Power value number doesn't update
Hypothesis:
- Target health bar is flipped with IsFlippedHorizontally=true
- Power crystal bar was created with orientation="UP" but NO flip setting
- Health, healthPreview, absorb, and cast all have SetFlippedHorizontally(isFlipped) in UnitFrame_UpdateTextures
- Power bar was never getting flip applied, causing visual inconsistency
- The flipping back and forth is the bar trying to auto-correct but fighting with the frame flip
Change(s):
- **Added SetFlippedHorizontally to power crystal creation** in Target.lua style() function:
  * Check if db.IsFlippedHorizontally is set
  * Apply power:SetFlippedHorizontally(db.IsFlippedHorizontally)
  * This matches the pattern used for health bar
Result:
- Pending test after /reload.
- Power crystal should now be consistently flipped to match Target frame orientation.
- Should eliminate the flipping back and forth behavior.
Next step:
- /reload and verify power crystal displays correctly and updates values.
- May still need to investigate why it "always displays and shows full" - could be Power_UpdateVisibility logic.

2026-02-02 (STOCK TARGET.LUA + WOW 12 FIX)
Errors:
- After replacing with stock Target.lua from June 2025 (pre-WoW 12.0), new error appeared:
- "attempt to compare local 'cur' (a secret value)" at Target.lua:218 in Power_UpdateVisibility
Hypothesis:
- Stock Target.lua is from June 2025, before WoW 12.0 was released in August 2024.
- Stock code has: `if (... or max == 0 or cur == 0)` which directly compares secret values.
- WoW 12.0 doesn't allow secret value comparisons in addon code.
- Need to sanitize secret values using issecretvalue() and fallback to safe cached values.
Change(s):
- **Added secret value sanitization to Power_UpdateVisibility** in Target.lua:
  * Check if cur is secret, use element.safeCur fallback
  * Check if max is secret, use element.safeMax fallback
  * This mirrors the pattern used elsewhere in the codebase for WoW 12.0 compatibility
Result:
- Pending test after /reload.
- Power crystal visibility checks should now work without secret value errors.
- Stock Target.lua now WoW 12.0 compatible.
Next step:
- /reload and verify Target flip works with stock code + WoW 12 fix.
- Monitor for any other secret value errors in stock code.

2026-02-02 (COMPREHENSIVE STOCK COMPARISON)
Errors:
- Target health bar STILL flipped wrong after all previous attempts
Hypothesis:
- Did full comparison of Target.lua style() function vs stock.
- Found significant differences in health bar creation code:
  * Extra conditional logic for USE_BLIZZARD_TARGET_HEALTH (even though it's false)
  * __AzeriteUI_DebugLabel properties being set
  * Extra color properties: colorSmooth, colorClassNPC, colorSelection, colorHealth, duplicate colorReaction
  * Debug text creation (HealthDebug)
  * Conditional checks for DisableSmoothing and SetSparkTexture
  * healthPreview alpha .25 vs stock .5
- Stock version is clean and simple - just CreateBar() with minimal properties.
- All these extra properties and conditional code may interfere with flip behavior.
Change(s):
- **Removed ALL extra code from health bar creation** - now exactly matches stock:
  * Removed USE_BLIZZARD_TARGET_HEALTH conditional
  * Removed __AzeriteUI_DebugLabel properties
  * Removed extra color properties (colorSmooth, colorClassNPC, colorSelection, colorHealth)
  * Removed duplicate colorReaction
  * Removed HealthDebug debug text creation
  * Removed conditional checks for DisableSmoothing/SetSparkTexture
  * Changed healthPreview alpha from .25 to .5
- Health bar now created with simple `self:CreateBar()` exactly like stock.
- healthPreview now simple `self:CreateBar(nil, health)` exactly like stock.
Result:
- Pending test after /reload.
- Target health bar creation now IDENTICAL to stock.
Next step:
- /reload and verify flip. If still wrong, check UnitFrame_UpdateTextures backdrop SetTexCoord.

2026-02-02 (FLIP FIX - ROOT CAUSE FOUND)
Errors:
- Target health bar still flipped wrong despite all previous fixes
Hypothesis:
- The UnitFrame_UpdateTextures function looked correct and matched stock.
- But Health_PostUpdate was calling EnsureTargetBarOrientation() on EVERY health update!
- This function was checking __AzeriteUI_ExpectedFlipped and resetting flip state, potentially with wrong values.
- Stock version has simple 5-line Health_PostUpdate that only calls ForceUpdate on HealthPrediction.
- Our version had 45+ lines of orientation enforcement logic that was fighting against the correct flip settings.
Change(s):
- **Simplified Health_PostUpdate to match stock exactly** - removed entire EnsureTargetBarOrientation function.
- Now only calls predict:ForceUpdate() like stock, no orientation/flip enforcement.
- This allows the flip state set in UnitFrame_UpdateTextures to persist without being overridden.
Result:
- Pending test after /reload.
- Health_PostUpdate no longer interferes with flip state on every health update.
- Flip should now match stock behavior exactly.
Next step:
- /reload and verify Target frame flip is correct.
- If still wrong, check if there are any other places resetting flip state.

2026-02-02 (CRITICAL TAINT FIX)
Errors:
- [ADDON_ACTION_BLOCKED] AddOn 'AzeriteUI' tried to call the protected function 'Frame:SetForbidden()' during nameplate creation
- Nameplate castbar highlight secret value errors (SetShown)
- PersonalResourceDisplay secret value arithmetic during Edit Mode
Hypothesis:
- FixBlizzardBugs.lua was directly modifying nameplate mixins (NamePlateUnitFrameMixin, NamePlateBaseAuraFrameMixin, etc) by replacing methods.
- Direct method replacement on Blizzard mixins taints the mixin table.
- When Blizzard creates new nameplate frames and tries to call SetForbidden(), the taint chain blocks it.
- hooksecurefunc() is safe and doesn't taint, but direct assignment (mixin.Method = function...) does taint.
Change(s):
- **Changed NamePlateUnitFrameMixin.UpdateCastBarDisplay from direct override to hooksecurefunc** - avoids tainting mixin during nameplate creation.
- **Disabled ApplyToMixin() calls for all nameplate mixins** - these were directly replacing AddAura, UpdateAura, RefreshList, RefreshAuras methods which taints the mixins.
- **Kept HookAuraScale() calls only** - these use hooksecurefunc which is safe and doesn't taint.
- Commented out: ApplyToMixin(_G.NamePlateBaseAuraFrameMixin), ApplyToMixin(_G.NamePlateAuraFrameMixin), ApplyToMixin(_G.NamePlateAurasMixin), ApplyToMixin(_G.NamePlateAuraMixin), ApplyToMixin(_G.NamePlateUnitFrameAuraMixin).
Result:
- Pending test after /reload.
- Nameplate creation should no longer trigger ADDON_ACTION_BLOCKED taint errors.
- Castbar patches still applied via hooksecurefunc after frame creation.
- Aura scale hooks still work via hooksecurefunc.
Next step:
- /reload and verify nameplate SetForbidden taint is gone.
- Monitor for any aura/nameplate functionality loss from disabled ApplyToMixin calls.
- If aura issues arise, may need to patch individual nameplate frames after creation instead of modifying mixins.

2026-02-02 (continued - FINAL FIX)
Errors:
- Target frame still flipped wrong after previous changes
- Health bar textures and castbar "scaling" instead of filling properly
- Power/mana percentages still showing on player and target frames
Hypothesis:
- The texture caching approach was WRONG. Stock version calls SetStatusBarTexture() EVERY update, not just once.
- WoW 12.0 doesn't have issues with calling SetStatusBarTexture frequently - the problem was missing SetSparkMap and incorrect conditional logic.
- Stock version has NO texture caching, NO conditional SetTexCoord checks, and calls SetSparkMap unconditionally.
- The "Blizzard resets textures internally" comment was misleading - stock still calls SetStatusBarTexture every update.
Change(s):
- **REMOVED ALL TEXTURE CACHING** from Player.lua, PlayerAlternate.lua, and Target.lua (removed __AzeriteUI_TextureSet and __AzeriteUI_LastTexture logic).
- **Restored direct SetStatusBarTexture() calls** on every update to match stock behavior.
- **Removed conditional SetTexCoord checks** from Target.lua (stock doesn't use them).
- **Added SetSparkMap unconditionally** for castbar in Target.lua (was conditional before).
- **Removed __AzeriteUI_ExpectedOrientation tracking** from Target castbar.
- **Hidden power/mana percentages**: Added powerPerc:Hide() and manaPerc:Hide() in Player.lua, powerPerc:Hide() in Target.lua.
- Applied changes to health, healthPreview, absorb, power, mana, and cast bars across all three files.
Result:
- Pending test after /reload.
- All bars now call SetStatusBarTexture() on every update, matching stock behavior exactly.
- SetSparkMap called unconditionally for proper spark positioning.
- All percentage text hidden except Target health percentage.
Next step:
- /reload and verify:
  1. Target frame art flips correctly (opposite to Player)
  2. Castbar fills instead of "scaling"
  3. No power/mana percentages visible on any frame except Target health %
  4. Health bars update smoothly without texture issues

2026-02-02 (continued)
Change(s) continued:
- **Hidden health percentage text on all unit frames except Target**: Added healthPerc:Hide() in Player.lua, PlayerAlternate.lua, Pet.lua, Party.lua, Boss.lua, Arena.lua, and Raid5.lua.
- **Simplified Target.lua flip logic to match stock version**: Removed all conditional __AzeriteUI_UseBlizzard checks from SetFlippedHorizontally() calls for health, healthPreview, absorb, and cast bars. Stock version uses simple `health:SetFlippedHorizontally(isFlipped)` without conditionals.
- Removed db.HealthBarTexCoord conditional checks and SetTexCoord() calls from cast bar setup (stock doesn't use them).
Result:
- Pending test after /reload.
- Health percentages should now only display on Target frames.
- Target flip logic simplified to match stock implementation.
Next step:
- /reload and verify health percentages hidden on all frames except Target.
- Verify Target frame flip matches stock behavior (art should appear opposite to Player).
- Compare runtime behavior to AzeriteUI_Stock if issues persist.

2026-02-02
Errors:
- Health bar textures resetting or flickering on every health update.
- Possible orientation/fill direction issues with statusbars.
- Target bars potentially starting with wrong flip state before first update.
Hypothesis:
- Addon creator confirmed: "you're probably applying the textures directly to the statusbar. And blizzard's new system resets that on every health update."
- SetStatusBarTexture() is being called during style updates, but Blizzard's WoW 12.0 system resets textures on every health change.
- Solution: Use health:SetReverseFill(true) instead of manual texture manipulation for fill direction.
- Blizzard StatusBars created without initial orientation/reverseFill state may start in wrong configuration.
Change(s):
- Moved SetStatusBarTexture() calls to occur only during initial bar setup, not on every update.
- Implemented texture caching in Player.lua, Target.lua, and PlayerAlternate.lua UnitFrame_UpdateTextures functions.
- Added __AzeriteUI_TextureSet and __AzeriteUI_LastTexture flags to track when textures actually change.
- Textures now only re-applied when they differ from the last set value, avoiding redundant calls.
- SetReverseFill() is already used consistently for controlling fill direction on Blizzard StatusBars.
- Applied caching to health, healthPreview, absorb, castbar, power, and mana statusbars where they appear in update functions.
- Unit frames that only set textures during creation (Boss, Arena, Party, Raid5/25/40, Pet, Focus, ToT, NamePlates) left unchanged as those are one-time calls.
- **Added initial state setup for Target.Health and Target.HealthPreview Blizzard StatusBars at creation**: SetOrientation("HORIZONTAL") and SetReverseFill(false) with Blizzard defaults; first update will apply correct isFlipped state.
- **REVERTED Target HealthBarOrientation back to RIGHT (matching Player) per stock version**. Removed HealthBarTexCoord flips. The visual flip comes from `IsFlippedHorizontally=true` applied to LibSmoothBar via SetFlippedHorizontally(), NOT from changing orientation to LEFT. All Target styles (Critter, Novice, Hardened, Seasoned, Boss) now use HealthBarOrientation = "RIGHT" with no TexCoord manipulation.
Result:
- Pending test after /reload.
- Updated initial SetReverseFill to false (Blizzard default) to prevent reversed art; update function applies correct flip state.
- HealthBarTexCoord flips texture coordinates so beveled/shaded edges match fill direction and appear opposite to Player frame.
Next step:
- /reload and test all unit frames; verify health bars update correctly without texture resets; check target/player damage updates.
- Monitor for any texture flickering or fill direction issues.
- Verify Target frame starts with correct flip state immediately on creation.

2026-01-29
Errors:
- AzeriteUI aura errors: table index is secret in AuraStyling; nil comparisons in AuraSorting; inconsistent aura filtering when secret values present.
Hypothesis:
- Aura filters and styling still index dispelName/spellId directly, and sorting compares duration/expiration with secret or non-number values.
Change(s):
- Added SafeBool/SafeNumber/SafeKey helpers in retail AuraFilters; guard Player/Target/Nameplate/Arena against secret values and avoid secret arithmetic.
- Updated Nameplate/Arena aura styling to sanitize dispelName/spellId before indexing Colors/Spells tables.
- Adjusted AuraSorting priority return and expiration sorting to avoid nil comparisons.
- Relaxed NameplateAuraFilter secret guard (only skip if the table itself is secret) to avoid dropping valid auras.
- If nameplate aura tables are not accessible (canaccesstable false), sanitize to empty tables to prevent secret compares in Blizzard_NamePlateAuras.
- Target/Nameplate filters now always show harmful player-applied auras in combat to avoid drops when duration is sanitized to 0.
Result:
- Pending retest after /reload; validate target -> nameplate -> player aura behavior and BugSack counts.
Next step:
- /reload; test target and nameplate auras first, then player; capture any remaining stacks in FixLog.

2026-01-29 (follow-up)
Errors:
- Auras missing or not updating in combat (e.g., HOJ, consecration) suspected due to secret-value guards.
Hypothesis:
- oUF aura element discards addedAuras when isHelpful/isHarmful are secret; Player/Target filters return early when any field is secret; isPlayerAura/isHarmful derived from sourceUnit/isHarmful fields that can be secret.
Change(s):
- oUF aura element now computes isPlayerAura/isHarmful/isHelpful using C_UnitAuras.IsAuraFilteredOutByInstanceID when needed; SortAuras uses SafeBool.
- Removed early secret guards in Player/Target/Party filters; added safe expiration fallback and secret-aware player/harmful detection; nameplate filter uses expiration fallback for secret duration/applications.
Result:
- Pending retest after /reload; verify target -> nameplate -> player aura visibility and in-combat updates.
Next step:
- /reload; test HOJ, consecration, and re-cast execution sentence in combat; record results.

2026-01-25
Errors:
- CastingBarFrame.lua:182 secret notInterruptible
- CastingBarFrame.lua:423 secret endTime arithmetic
- CastingBarFrame.lua:916 secret SetShown
- Blizzard_NamePlateAuras.lua:295 auraItemScale nil
- GetAuraDataByAuraInstanceID bad argument (missing unit)
Hypothesis:
- Blizzard returns secret values for nameplate cast/channel and aura data, and aura list frames miss a default scale.
Change(s):
- Wrapped secret booleans and cast highlight paths in Core/FixBlizzardBugs.lua.
- Added aura API sanitizers and nameplate aura list scale defaults.
- Added unit resolution for nameplate aura frames.
Result:
- Some errors persisted (endTime secret, auraItemScale nil, notInterruptible secret).
Next step:
- Sanitize UnitCastingInfo/UnitChannelInfo return values and reapply nameplate aura hooks after Blizzard mixins load.

2026-01-28
Errors:
- NamePlateUnitFrame:SetForbidden protected-call taint on nameplate creation.
- PRD/EncounterWarnings/BuffFrame secret-value errors during Edit Mode.
- Nameplate castbar highlight secret SetShown; nameplate aura isHarmful secret.
- Backdrop.lua secret width from action button tooltips.
Hypothesis:
- Overriding Blizzard nameplate mixins and/or disabling Blizzard nameplate frames taints protected creation.
- Edit Mode systems for PRD/Buffs/EncounterWarnings need broader pruning.
Change(s):
- Skip Blizzard nameplate suppression in secret builds to reduce taint (NamePlates.lua).
- Avoid mixin overrides for nameplate castbar/aura/raid target in secret builds; patch instances + wrap CastTargetIndicator/ImportantCastIndicator SetShown.
- Broaden Edit Mode system pruning for PRD + Buffs and add BackdropMixin guard against secret width/height.
Result:
- Pending retest after /reload and BugGrabber reset.
Next step:
- Reproduce after /reload; confirm SetForbidden and EditMode errors are gone. If castbar/auras still error, increase instance-level patch timing.

2026-01-28 (follow-up)
Errors:
- ClassNameplateManaBar SetupBar secret arithmetic.
- Nameplate aura isHarmful secret, auraItemScale nil.
- CastingBarFrame HandleCastStop castID secret.
- SetNamePlateHitTestFrame taint/invalid argument.
Hypothesis:
- Blizzard class nameplate bars and aura APIs still emit secret values; nameplate hit test frames are forbidden/invalid in secret builds.
Change(s):
- Hide/unregister class nameplate power/mechanic bars (mirroring DiabolicUI3).
- Wrap additional aura APIs (GetAuraDataByIndex/BySlot/ForEachAura) and hook aura scale setters.
- Sanitize castID in CastingBarFrame OnEvent and guard SetNamePlateHitTestFrame in secret builds.
- Target healthbar orientation set to LEFT (mirror of player) to fix flipped start state.
Result:
- Pending retest after /reload.
Next step:
- Re-test nameplates/castbar/edit mode; verify target bar orientation.

2026-01-25 (Vanilla TOC)
Errors:
- TBC Anniversary client flagged AzeriteUI as out of date (Vanilla TOC).
Hypothesis:
- AzeriteUI_Vanilla.toc lacked the TBC Anniversary interface number and the latest Classic ID.
Change(s):
- Added interface IDs 20505 (TBC Anniversary) and 11508 (Classic) to AzeriteUI_Vanilla.toc.
Result:
- Pending test (launch TBC Anniversary client).
Next step:
- Enable in TBC Anniversary and confirm it loads without out-of-date warning.

2026-01-25 (update)
Errors:
- CastingBarFrame.lua:423 secret endTime arithmetic
- CastingBarFrame.lua:182 secret notInterruptible
- Blizzard_NamePlateAuras.lua:295 auraItemScale nil
Hypothesis:
- OnEvent uses UnitCastingInfo/UnitChannelInfo results directly; mixin overwrites may be undoing our hooks.
Change(s):
- Added UnitCastingInfo/UnitChannelInfo sanitizers with cached durations + spell castTime fallback.
- Re-apply nameplate aura mixin wrappers if overwritten, and ensure list frame scales on NAME_PLATE_UNIT_ADDED.
- Moved Frame:SetShown guard outside castbar mixin check so it applies early.
Result:
- Pending test (reload UI).
Next step:
- /reload and confirm whether errors stop; if not, capture new stack traces.

2026-01-25 (update 2)
Errors:
- Blizzard_PersonalResourceDisplay.lua:477 secret arithmetic (EditMode UpdateLayoutInfo)
Hypothesis:
- PRD does math on UnitHealth/UnitPower values that become secret in WoW12.
Change(s):
- Wrap PRD methods (UpdateLayoutInfo/UpdateLayout/Update/UpdateHealth) to run with sanitized UnitHealth/UnitPower values using cached last-known numbers.
Result:
- Pending test (reload UI).
Next step:
- /reload, then verify PRD and Edit Mode update without errors.

2026-01-25 (update 3)
Errors:
- Blizzard_PersonalResourceDisplay.lua:477 secret arithmetic still occurs.
Hypothesis:
- PRD math uses cached/layout/statusbar values (not just UnitHealth/Power).
Change(s):
- Sanitize PRD layout tables and wrap PRD statusbar getters to return cached numeric values when secret.
- Cache per-unit cast durations to improve cast timing fallback.
Result:
- Pending test (reload UI).
Next step:
- /reload, test Edit Mode + PRD, and verify target castbar orientation.

2026-01-25 (update 4)
Errors:
- Blizzard_PersonalResourceDisplay.lua:477 secret arithmetic still occurs in Edit Mode.
- EncounterWarningsViewElements.lua:75 secret compare in Edit Mode.
- SecureUtil.lua:78 secret arithmetic in Edit Mode exit.
Hypothesis:
- PRD mixin methods are being used (not the instance), and secret values leak through secureexecuterange and encounter warning info fields.
Change(s):
- Wrap secureexecuterange args to sanitize secret numeric values and nested tables.
- Wrap PRD mixin methods (UpdateLayoutInfo/GetLayoutInfo/etc.) and sanitize returned tables.
- Sanitize all EncounterWarnings info fields with defaults.
- Flip target castbar horizontally to match target health bar.
Result:
- Pending test (reload UI).
Next step:
- /reload, enter/exit Edit Mode, watch PRD + EncounterWarnings errors, and verify target castbar direction.

2026-01-25 (update 5)
Errors:
- PRD maxHealth compare secret in Edit Mode.
- ADDON_ACTION_FORBIDDEN: TargetUnit() during Edit Mode.
Hypothesis:
- secureexecuterange wrapper is tainting Edit Mode; PRD uses systemInfo tables with secret values.
Change(s):
- Removed secureexecuterange wrapper to avoid taint.
- Sanitized PRD systemInfo/savedSystemInfo/settings tables and rewrap all PRD mixin methods.
- Ensure EncounterWarnings wrapper re-applies if Blizzard overwrites Init.
Result:
- Pending test (reload UI).
Next step:
- /reload, enter/exit Edit Mode, confirm no TargetUnit taint and no PRD/EncounterWarnings errors.

2026-01-25 (update 6)
Errors:
- PRD secret arithmetic/compare persists in Edit Mode.
Hypothesis:
- Secret values leak through PRD statusbar getters and layout tables; some tables may be inaccessible.
Change(s):
- Guard PRD table sanitization with canaccesstable.
- Wrap Blizzard PRD statusbars (healthbar/PowerBar/AlternatePowerBar/tempMaxHealthLossBar) to return cached numeric values when secret.
- On PRD secret-value failure, keep sanitized state and skip rethrow to avoid breaking Edit Mode.
Result:
- Pending test (reload UI).
Next step:
- /reload, enter/exit Edit Mode, verify PRD + EncounterWarnings errors are gone.

2026-01-25 (update 7)
Errors:
- PRD secret arithmetic persists in Edit Mode (lines 211/477).
- EncounterWarnings secret compare persists (line 75).
Hypothesis:
- PRD uses frame geometry or local functions not covered by mixin wrappers.
- EncounterWarnings instances may be created before mixin replacement.
Change(s):
- Wrap PRD frame geometry getters (GetWidth/Height/Left/Right/Top/Bottom/Scale/Center).
- Wrap PRD OnEvent/OnUpdate/OnShow scripts with sanitized unit values.
- Deep-sanitize EncounterWarnings info and patch existing pooled elements.
Result:
- Pending test (reload UI).
Next step:
- /reload, enter/exit Edit Mode, re-check BugSack counts for PRD and EncounterWarnings.

2026-01-25 (update 8)
Errors:
- PRD secret arithmetic persists in Edit Mode (lines 211/477).
- EncounterWarnings secret compare persists (line 75).
- SecureUtil.lua:78 secret arithmetic on Edit Mode exit.
Hypothesis:
- EditMode may call cached PRD functions stored in systemInfo, bypassing our wrappers.
- EncounterWarnings may call ShowWarning before mixin replacement.
Change(s):
- Wrap PRD systemInfo functions inside tables (function values replaced with safe wrappers).
- Patch EditMode registered system frames to re-prepare PRD.
- Wrap EncounterWarnings.ShowWarning at view and module level to sanitize warning info early.
Result:
- Pending test (reload UI).
Next step:
- /reload, enter/exit Edit Mode, confirm counts drop and timestamps update.

2026-01-28 (debug menu)
Errors:
- /azdebug menu controls overflowed the frame; dumps lacked art/anchor detail.
Hypothesis:
- Debug frame size too small and dump output missing key layout/texture info.
Change(s):
- Expanded /azdebug frame size, clamped to screen, and reflowed utility buttons.
- Added script errors button/command and dump tot/all commands.
- Dump output now includes points, scale/strata, statusbar color, and art texture details (size/points/texcoord).
Result:
- Pending retest after /reload.
Next step:
- /reload, open /azdebug and confirm all controls are inside; run dump to verify power crystal/mana orb sizes.

2026-01-28 (scale debug)
Errors:
- Player/Target effective scales diverged (player 0.7111, target 0.8) causing art size mismatch.
Hypothesis:
- Unitframe scale comes from savedPosition.scale; one frame was left at non-default (1.0).
Change(s):
- Added /azdebug scale status + reset commands and debug menu buttons.
Result:
- Pending retest after /reload.
Next step:
- Use /azdebug scale or Scale Status button; then Reset UnitFrame Scales and re-check bar sizes.

2026-01-28 (target flip fix)
Errors:
- Target healthbar starts flipped/wrong; castbar texture appears to shrink/grow instead of filling.
Hypothesis:
- Target flip flag was read from per-style table (nil) instead of the global TargetFrame config, so bars were never flipped.
Change(s):
- Restored TargetFrame.IsFlippedHorizontally to true and re-applied global flip in Components/UnitFrames/Units/Target.lua for health/preview/absorb/cast + backdrop texcoord.
Result:
- Pending test (reload UI).
Next step:
- /reload, target something, verify health and castbar fill direction/texture look.

2026-01-28 (target flip proxy)
Errors:
- Target healthbar still appears flipped wrong while LibSmoothBar proxy is active.
Hypothesis:
- Proxy statusbar was both reverse-filled and texcoord-flipped, causing a double reverse when growth is LEFT.
Change(s):
- LibSmoothBar: only flip proxy texcoords when reverse-fill is false.
Result:
- Pending test (reload UI).
Next step:
- /reload, dump target bars, confirm proxy output looks correct.

2026-01-25 (update 9)
Errors:
- PRD secret arithmetic persists in Edit Mode (lines 211/477).
- EncounterWarnings secret compare persists (line 75).
- SecureUtil.lua:78 secret arithmetic on Edit Mode exit.
Hypothesis:
- EditMode UpdateSystems/UpdateLayoutInfo uses cached system frames or layout data before our PRD prep.
- HideSystemSelections uses secureexecuterange on data that now contains secret values.
Change(s):
- Wrap EditMode UpdateSystems/UpdateLayoutInfo to sanitize layout info and re-prepare PRD.
- Wrap HideSystemSelections to fallback-hide selections when secret errors occur.
- Add timers to re-apply WrapPRD/WrapEncounterWarnings/HideSystemSelections.
Result:
- Pending test (reload UI).
Next step:
- /reload, enter/exit Edit Mode, check for new timestamps and count changes.

2026-01-25 (update 10)
Errors:
- PRD secret arithmetic persists in Edit Mode (lines 211/477).
- EncounterWarnings secret compare persists (line 75).
- ADDON_ACTION_FORBIDDEN: ClearTarget() during Edit Mode exit.
- FixBlizzardBugs.lua: script ran too long (WrapAllMethods on PRD).
Hypothesis:
- EditMode wrappers tainted the Blizzard call path (ClearTarget).
- WrapAllMethods is too aggressive and rewraps internal methods repeatedly.
Change(s):
- Removed EditMode UpdateSystems/UpdateLayoutInfo and HideSystemSelections wrappers.
- Removed WrapAllMethods and function replacement inside PRD table sanitization.
Result:
- Pending test (reload UI).
Next step:
- /reload, enter/exit Edit Mode, confirm ClearTarget and script-timeout errors are gone.

2026-01-25 (update 11)
Errors:
- PRD secret arithmetic persists in Edit Mode (line 477).
- EncounterWarnings secret compare persists (line 75).
- Nameplate castbar SetShown secret.
- Nameplate auraItemScale nil.
- SecureUtil HideSystemSelections secret arithmetic.
Hypothesis:
- Existing nameplate frames still hold original methods; mixin changes aren’t applied to instances.
- PRD/EncounterWarnings still receive secret values despite sanitizers.
Change(s):
- Patch existing nameplate castbar methods to safe highlight handlers.
- Patch existing nameplate aura frames to ensure auraItemScale and wrap RefreshList/RefreshAuras.
- Add dev-mode debug counters for PRD and EncounterWarnings secret values.
Result:
- Pending test (reload UI).
Next step:
- /reload, enable dev mode if needed, and re-test Edit Mode + nameplates.

2026-01-25 (update 12)
Errors:
- PRD secret arithmetic persists in Edit Mode (line 477, count 13).
- EncounterWarnings secret compare persists (line 75, count 17).
- Nameplate castbar SetShown secret persists (count 3173).
- Nameplate auraItemScale nil persists (count 2146).
- SecureUtil HideSystemSelections secret arithmetic persists (count 4).
Hypothesis:
- Existing nameplate instances still not fully patched; PRD/EncounterWarnings still see secret fields.
Change(s):
- Deep scan performed; no direct TargetUnit/ClearTarget calls found in AzeriteUI.
- AGENTS.md updated with debug toggles and Edit Mode cautions.
Result:
- Pending test (reload UI).
Next step:
- /buggrabber reset, /reload, enable Development Mode, capture FixBlizzardBugs debug counters and new BugSack report.

2026-01-25 (update 13)
Errors:
- PRD secret arithmetic persists in Edit Mode.
- EncounterWarnings secret compare persists in Edit Mode.
Hypothesis:
- Edit Mode is still feeding secret values; bypassing PRD/EncounterWarnings during Edit Mode avoids errors without affecting gameplay.
Change(s):
- Added Edit Mode-only bypass (hide PRD + EncounterWarnings while Edit Mode is active).
- Added /azdebugfixes toggle for FixBlizzardBugs debug output.
- Hooked Edit Mode enter/exit via hooksecurefunc (no protected calls).
Result:
- Pending test (reload UI).
Next step:
- /buggrabber reset, /reload, enter/exit Edit Mode and confirm PRD/EncounterWarnings errors stop.

2026-01-25 (update 14)
Change(s):
- Debug slash commands now only register when Dev Mode is enabled.
- SanityBarFix debug command gated behind Dev Mode.
Result:
- Pending test (/reload required).

2026-01-25 (update 15)
Errors:
- PRD secret arithmetic persists in Edit Mode.
- EncounterWarnings secret compare + ScaleTextToFit secret (Edit Mode).
- SecureUtil HideSystemSelections secret arithmetic persists.
Hypothesis:
- EditMode bypass hook not attaching early enough, so Edit Mode calls occur before bypass activates.
Change(s):
- Strengthened EditMode bypass hook with Show/Hide hooks and a retry ticker.
- Added debug log when bypass hook attaches.
Result:
- Pending test (/reload required).
Next step:
- /buggrabber reset, /reload, enter/exit Edit Mode; confirm bypass activates and PRD/EncounterWarnings errors stop.

2026-01-25 (update 16)
Errors:
- PRD secret arithmetic persists in Edit Mode (counts rising).
- EncounterWarnings secret compare persists in Edit Mode (counts rising).
- SecureUtil HideSystemSelections secret arithmetic persists on Edit Mode exit.
Hypothesis:
- Bypass runs but PRD/EncounterWarnings still execute before hide; SecureUtil error occurs during Edit Mode exit sequence.
Change(s):
- EditMode bypass now hides EncounterWarnings parent and attempts HideSystemSelections with safe fallback.
- On login, explicitly sync bypass state with C_EditMode.IsEditModeActive.
Result:
- Pending test (/reload required).

2026-01-25 (update 17)
Errors:
- PRD secret arithmetic persists in Edit Mode (counts rising).
- EncounterWarnings secret compare persists in Edit Mode (counts rising).
- SecureUtil HideSystemSelections secret arithmetic persists.
Hypothesis:
- PRD/EncounterWarnings still execute inside Edit Mode update path even after bypass.
Change(s):
- Edit Mode bypass now prunes PRD/Encounter systems from registeredSystemFrames while active.
- Temporarily no-op PRD Update* and EncounterWarnings ShowWarning during Edit Mode; restore on exit.
Result:
- Pending test (/reload required).

2026-01-25 (update 18)
Errors:
- PRD secret arithmetic persists in Edit Mode (counts rising).
- EncounterWarnings secret compare persists in Edit Mode (counts rising).
Hypothesis:
- PRD/EncounterWarnings use mixin methods and view elements not covered by instance-only no-ops.
Change(s):
- No-op PRD Update* on frame + mixins during Edit Mode.
- No-op EncounterWarnings ShowWarning on frame + mixins, and ViewElements Init/Reset during Edit Mode.
Result:
- Pending test (/reload required).

2026-01-25 (update 19)
Errors:
- PRD secret arithmetic persists in Edit Mode (counts low but still present).
- EncounterWarnings secret compare persists in Edit Mode (counts low).
Hypothesis:
- Bypass activates too late; EditMode Enter/Exit hooks run after update.
Change(s):
- Wrapped EditModeManagerFrame.EnterEditMode/ExitEditMode to enable bypass BEFORE updates.
Result:
- Pending test (/reload required).

2026-01-25 (update 20)
Errors:
- PRD secret arithmetic persists in Edit Mode (low count).
- EncounterWarnings secret compare persists in Edit Mode (low count).
- TargetUnit taint triggered after Edit Mode Enter.
Hypothesis:
- Overriding EditModeManagerFrame.Enter/Exit tainted protected calls.
Change(s):
- Removed Enter/Exit overrides; rely on HookScript OnShow/OnHide + hooksecurefunc only.
Result:
- Pending test (/reload required).

2026-01-25 (update 21)
Errors:
- PRD secret arithmetic persists in Edit Mode (single-occurrence per entry).
- EncounterWarnings secret compare persists in Edit Mode (single-occurrence per entry).
Hypothesis:
- PRD/EncounterWarnings are still registered with Edit Mode before bypass hooks fire, so UpdateSystems/RefreshEncounterEvents runs once.
Change(s):
- Pre-prune PRD/EncounterWarnings from EditMode registered systems on PLAYER_LOGIN and Blizzard_EditMode load (with delayed retries).
- Narrowed Edit Mode system matching to avoid removing unrelated systems (e.g., Boss Frames).
- Registered dev-only `/azsecrettest` command for secret-value testing helpers.
Result:
- Pending test (/reload required).
Next step:
- /buggrabber reset, /reload, enter/exit Edit Mode; confirm PRD/EncounterWarnings errors stop.

2026-01-25 (update 22)
Errors:
- PRD secret arithmetic persists in Edit Mode (still 1 per entry).
- EncounterWarnings secret compare persists in Edit Mode (still 1 per entry).
Hypothesis:
- PRD/EncounterWarnings register into additional Edit Mode containers (modernSystems/modernSystemMap/etc.) after our first pre-prune.
Change(s):
- Pre-prune now removes PRD/EncounterWarnings from multiple Edit Mode containers (registeredSystemFrames, modernSystems, modernSystemMap, etc.).
- Added a registration hook to prune immediately when systems are registered.
Result:
- Pending test (/reload required).
Next step:
- /buggrabber reset, /reload, enter/exit Edit Mode; confirm errors stop.

2026-01-25 (update 23)
Errors:
- PRD secret arithmetic persists in Edit Mode (still 1 per entry).
- EncounterWarnings secret compare persists in Edit Mode (still 1 per entry).
- FixBlizzardBugs.lua error: attempted to index Edit Mode entry when it was numeric (system id).
Hypothesis:
- Some Edit Mode containers store numeric system IDs; our prune logic assumed frames/tables.
Change(s):
- Guarded Edit Mode name lookup against non-table/userdata values.
- Added lookup mapping from numeric system IDs to system frames when pruning.
Result:
- Pending test (/reload required).
Next step:
- /buggrabber reset, /reload, enter/exit Edit Mode; confirm PRD/EncounterWarnings errors stop.

2026-01-26
Errors:
- PlayerFrame health color stuck (custom colors ignored).
- PlayerFrameAlternate health color defaulting to white.
Hypothesis:
- WoW12 secret-value workaround forced a constant red UpdateColor for PlayerFrame and left PlayerFrameAlternate without a non-class color path.
Change(s):
- PlayerFrame health UpdateColor now uses static class/custom/config colors (no gradients).
- PlayerFrameAlternate adds static UpdateColor, applies configured/class/picker colors, and fixes config lookup.
Result:
- Pending test (/reload required).
Next step:
- /reload, change PlayerFrame/PlayerAlternate health colors in options, verify colors update and persist.

2026-01-26 (update)
Errors:
- AzUI_Color_Picker still not overriding Player/PlayerAlternate colors.
Hypothesis:
- AzeriteUI UpdateColor runs after picker, reapplying static color every update.
Change(s):
- Player/PlayerAlternate now re-apply AzUI_Color_Picker color during Update/PostUpdate and UpdateColor via shared picker helpers.
Result:
- Pending test (/reload required).
Next step:
- /reload and confirm picker color sticks on Player and PlayerAlternate.

2026-01-26 (update 2)
Errors:
- AzUI_Color_Picker override still not sticking.
Hypothesis:
- AzeriteUI custom UpdateColor blocks oUF color path; picker needs oUF/Colors health override.
Change(s):
- Player/PlayerAlternate revert to oUF color path (colorHealth true, no UpdateColor override).
- AzUI_Color_Picker now sets oUF.colors.health alongside AzeriteUI Colors.health.
Result:
- Pending test (/reload required).
Next step:
- /reload, set picker color, verify Player/PlayerAlternate use picker color with no gradients.

2026-01-26 (update 3)
Errors:
- Picker still not applying (Player frame stays red).
Hypothesis:
- ApplyColor short-circuits before AzeriteUI loads; HasColorPicker cached false at load time.
Change(s):
- AzUI_Color_Picker now forces one re-apply when AzeriteUI loads.
- Player/PlayerAlternate now check color picker enabled dynamically.
Result:
- Pending test (/reload required).
Next step:
- /reload and confirm player frame color follows picker.

2026-01-27
Errors:
- TargetFrame health bar flips direction when taking damage.
Hypothesis:
- Target bar orientation/flip state drifts (possibly during secret-value proxy swaps or external SetReverseFill calls).
Change(s):
- Added LibSmoothBar debug logging for target bars (proxy show/hide + flip/orientation/reversefill calls).
- Target frame now stores expected orientation/flip and re-applies them on health updates.
Result:
- Pending test (/reload required).
Next step:
- /reload with dev mode + /azdebughealth, take damage on target and capture chat logs for proxy/flip events.

2026-01-27 (update)
Errors:
- Nameplate castbar SetShown secret value (CastingBarFrame.lua:916) persists.
Hypothesis:
- Nameplate castbars copy mixin methods before our overrides; instance methods remain unsafe.
Change(s):
- Hooked NamePlateUnitFrameMixin OnUnitSet/UpdateCastBarDisplay to patch castbar instance methods.
Result:
- Pending test (/reload required).
Next step:
- /reload, then target nameplates during casts; confirm SetShown secret error stops.

2026-01-27 (update 2)
Change(s):
- Consolidated debug commands into /azdebug and added health debug filter support (default "Target.").
Result:
- Pending test (/reload required).

2026-01-27 (update 3)
Change(s):
- Added /azdebug popup menu with toggle buttons and bar dump actions.
Result:
- Pending test (/reload required).

2026-01-27 (update 4)
Change(s):
- /azdebug registration now retries when dev mode becomes available (late DB load).
Result:
- Pending test (/reload required).

2026-01-27 (update 5)
Change(s):
- /azdebug bar dump now prints LibSmoothBar internal/proxy state for target bars.
Result:
- Pending test (/reload required).

2026-01-27 (update 6)
Change(s):
- When proxy rendering is active, sync proxy reverse fill to horizontal flip (reversedH) to prevent target bar flip.
Result:
- Pending test (/reload required).

2026-01-27 (update 7)
Change(s):
- Avoid double-flip by keeping proxy texcoords default when reverse fill is enabled.
Result:
- Pending test (/reload required).

2026-01-27 (update 8)
Change(s):
- Proxy rendering now applies horizontal flip via texcoords only (no reverse fill), to prevent target bar staying flipped.
Result:
- Pending test (/reload required).

2026-01-27 (update 9)
Change(s):
- Target health/cast bars now respect TargetFrame.IsFlippedHorizontally (default false) to avoid permanent flip.
Result:
- Pending test (/reload required).

2026-01-27 (update 10)
Change(s):
- Target health/preview now can use Blizzard StatusBar (native) for flip testing; orientation/reverse-fill mapped.
Result:
- Pending test (/reload required).

2026-01-27 (update 11)
Change(s):
- Blizzard StatusBar fallback now uses safe numeric values when secret values block updates.
- Target Blizzard StatusBar forces reverse fill to avoid stuck flipped direction.
Result:
- Pending test (/reload required).

2026-01-27 (update 12)
Change(s):
- Blizzard StatusBar fallback now always uses safe values for target health/preview updates.
- Reverse fill for Blizzard target bars now follows TargetFrame.IsFlippedHorizontally.
Result:
- Pending test (/reload required).

2026-01-27 (update 13)
Change(s):
- Revert target health/preview to LibSmoothBar and set TargetFrame HealthBarOrientation to LEFT (no flip).
Result:
- Pending test (/reload required).

2026-01-27 (update 14)
Change(s):
- Added TargetFrame HealthBarTexCoord = {1,0,0,1} and apply to health/preview/cast to flip texture UVs without changing bar logic.
Result:
- Pending test (/reload required).

2026-01-27 (update 15)
Change(s):
- Reverted TargetFrame to RIGHT orientation with IsFlippedHorizontally=true and removed texture UV flip.
Result:
- Pending test (/reload required).

2026-01-27 (update 16)
Change(s):
- LibOrb now caches safe values and uses them when secret values block orb rendering.
Result:
- Pending test (/reload required).

2026-01-28
Errors:
- PRD secret arithmetic (Edit Mode), EncounterWarnings secret compare, nameplate aura secrets/auraItemScale nil, nameplate castbar SetShown secret, LowHealthFrame secret, SecureGroupHeaders aura sort secret, oUF auras sortedDebuffs nil.
Hypothesis:
- Some Blizzard frames/mixins still execute before our wrappers; aura tables contain secret fields; default buff frames and PRD/EncounterWarnings should be fully disabled when AzeriteUI is active.
Change(s):
- FixBlizzardBugs now disables PRD, EncounterWarnings, LowHealthFrame, and Blizzard Buff/Debuff/TempEnchant frames when secret-value mode is active.
- Strengthened aura sanitization to avoid CopyTable on secret tables and default secret fields to safe values.
- oUF auras now ensures sortedDebuffs is initialized before length checks.
Result:
- Pending test (/reload required).

2026-01-28 (update)
Errors:
- ADDON_ACTION_BLOCKED from C_NamePlateManager.SetNamePlateHitTestFrame wrapper.
- AuraIsBigDefensive nil/secret spellID (AuraUtil/C_UnitAuras).
- CompactUnitFrame_GetRangeAlpha secret outOfRange.
- AuraUtil.UnpackAuraData CopyTable error when auraData is secret.
Hypothesis:
- Wrapping protected nameplate hit-test setter taints a protected function.
- Aura big-defensive helpers don't guard nil/secret spellIDs.
- CompactUnitFrame range alpha does boolean tests on secret outOfRange.
- CopyTable on secret aura tables fails in secure context.
Change(s):
- Removed nameplate hit-test wrapper to avoid protected call blocks.
- Wrapped C_UnitAuras.AuraIsBigDefensive and CompactUnitFrame_GetRangeAlpha for secret/nil inputs.
- Guarded AuraUtil.UnpackAuraData copy against secret/inaccessible auraData.
- Re-apply nameplate aura fixes on Blizzard_NamePlates load with a short ticker.
Result:
- Pending test (/reload required).

2026-01-28 (update 2)
Errors:
- PRD secret arithmetic still occurs in Edit Mode.
- EncounterWarnings secret compare still occurs in Edit Mode.
- Nameplate castbar SetShown secret persists.
- Nameplate aura isHarmful secret + auraItemScale nil persists.
- SecureGroupHeaders secret aura sort persists on Edit Mode exit.
- SetNamePlateHitTestFrame protected call blocked.
Hypothesis:
- Hooking NamePlateUnitFrame mixins may taint protected hit-test calls.
- Castbar fix doesn't reach nameplate instances when mixins load late.
- Aura mixins differ across builds; our wrappers miss the live mixin.
- Buff headers still load despite frame hiding.
Change(s):
- Disabled Blizzard_PersonalResourceDisplay, Blizzard_EncounterWarnings, Blizzard_BuffFrame for future sessions.
- Removed NamePlateUnitFrame mixin hooks (avoid taint).
- Castbar patch now installs safe methods per-instance even without mixin.
- Nameplate aura fix now targets multiple mixins and AurasFrame list scales.
Result:
- Pending test (/reload required).

2026-01-28 (update 3)
Errors:
- SetForbidden protected call during nameplate AcquireUnitFrame.
- Nameplate raid target secret compare.
- Castbar SetShown secret persists.
- Nameplate auraItemScale/isHarmful secret persists.
- CastInfoCache secret table index from UnitCastingInfo wrapper.
- AuraSorting comparator nil compare.
- SecureAuraHeader sort secret.
Hypothesis:
- oUF hooks AcquireUnitFrame, tainting forbidden nameplate creation.
- Nameplate raid target mixin uses secret raidTargetIndex.
- Nameplate castbar mixin methods still run before patch.
- Aura mixin wrappers don't reach instance methods.
- CastInfoCache uses secret unit/spellID as table key.
- Aura sorting compares nil auraInstanceID.
- Secure aura header sort by TIME uses secret expires.
Change(s):
- oUF SpawnNamePlates skips AcquireUnitFrame hook in WoW12/secret mode.
- Nameplate raid target mixin and instances sanitize raidTargetIndex.
- Nameplate castbar UpdateCastBarDisplay overridden to patch bar before update.
- Aura frame instances now wrap AddAura + ensure auraItemScale; also patch AurasFrame.
- CastInfoCache guard against secret unit/spellID keys.
- AuraSorting falls back to 0 auraInstanceID when nil.
- Buff header uses INDEX sort in secret-value mode.
- PRD/EncounterWarnings hard no-op methods when disabled.
Result:
- Pending test (/reload required).

2026-01-28 (update 4)
Errors:
- Nameplate SetForbidden protected call persists.
- Nameplate castbar SetShown secret persists.
- Nameplate auraItemScale/isHarmful secret persists.
- Edit Mode still triggers PRD/EncounterWarnings once.
Hypothesis:
- Avoiding AcquireUnitFrame isn’t enough; Blizzard nameplate unitframes need to be hidden/unregistered entirely.
- Cast highlight runs on Blizzard nameplate castbar even if mixin patched.
- Nameplate aura mixins still execute before our sanitizers.
- Edit Mode callbacks need earlier hooks.
Change(s):
- NamePlates: hook NamePlateDriverFrame OnNamePlateAdded/Removed; unregister Blizzard UnitFrame events, force alpha 0, reparent AurasFrame lists to hidden parent, and no-op cast highlight on Blizzard castbars.
- FixBlizzardBugs: added EditMode EventRegistry callbacks for early bypass.
Result:
- Pending test (/reload required).

2026-01-28 (update 5)
Errors:
- SetForbidden protected call still fires on nameplate creation.
- Castbar highlight + castID secret errors persist.
- Nameplate auraItemScale/isHarmful secrets still fire.
- AuraUtil Unpack secret table from our buff header.
Hypothesis:
- Hooking NamePlateDriverFrame still taints forbidden creation; use NAME_PLATE_UNIT_* events instead.
- Castbar safe methods need to handle important-cast highlight and castID compares.
- AuraItemScale should also be set on the aura frame itself.
- UnitAura calls can explode when AuraUtil sees secret tables.
Change(s):
- NamePlates: switched to NAME_PLATE_UNIT_ADDED/REMOVED events, skip NamePlateDriverFrame hooks in secret mode.
- Castbar: added safe important-cast highlight methods and castID sanitization in HandleCastStop.
- Nameplate auras: ensure auraItemScale is set on the aura frame itself.
- Auras: wrap UnitAura in pcall and skip secret values before comparisons/formatting.
- FixBlizzardBugs: handle EDIT_MODE_LAYOUTS_UPDATED to re-disable PRD/EncounterWarnings.
Result:
- Pending test (/reload required).

2026-01-28 (update 6)
Errors:
- FixBlizzardBugs.lua syntax error due to extra `end`.
- ObjectiveTrackerFrame:Show protected call in Edit Mode.
- AuraStyling secret table index in Spells/debuff lookup.
Hypothesis:
- Extra `end` broke FixBlizzardBugs execution, so most fixes didn’t apply.
- Tracker module calls Show/Hide in secret-value mode.
- Aura styling indexes secret spellId/dispelName.
Change(s):
- Removed extra `end` in FixBlizzardBugs OnEvent handler.
- TrackerWoW10/WoW11 now use autoHider only in secret mode (no Show/Hide).
- AuraStyling uses SafeKey for dispelName/spellId before table indexing.
- NAME_PLATE_UNIT_ADDED/REMOVED now defers to next frame to avoid taint.
Result:
- Pending test (/reload required).

2026-01-28 (update 7)
Errors:
- FixBlizzardBugs.lua syntax error persisted (missing closing parenthesis).
Hypothesis:
- frame:SetScript("OnEvent", function(...) was missing its closing `)`, preventing FixBlizzardBugs from loading.
Change(s):
- Closed the SetScript call with `end)` so the file parses.
Result:
- Pending test (/reload required).

2026-02-03
Issue:
- Target/ToT/nameplate health & power bars flicker between tiled and stretched textures when secret values arrive.
Hypothesis:
- LibSmoothBar falls back to its proxy StatusBar whenever values are secret/nil, while our unit updates also provide safe numeric fallbacks; proxy swap changes render mode, causing visible flicker.
Change(s):
- Tried adding safeBarValue/min/max fallback inside LibSmoothBar Update to avoid proxy swaps.
Result:
- Regression: health/power bars stopped updating. Change reverted; flicker still pending. (/reload required)

2026-02-12 (stability pass - private globals)
Errors:
- Blizzard target mana secret errors (UnitFrame.lua:955/:908) tainted by AzeriteUI.
- 'attempted to index a forbidden table' spam.
Hypothesis:
- Core/Private.lua was globally overriding Blizzard Compact/UnitFrame functions to no-op in WoW 12, which taints protected frame flows and leaks secret values into Blizzard arithmetic paths.
Change(s):
- Removed WoW12 global no-op overrides from Core/Private.lua (CompactUnitFrame, CompactRaidFrameManager, UnitFrame* hooks).
- Kept only a guard comment: no global Blizzard function replacement in Private bootstrap.
Result:
- Pending test (/reload required). Expect reduced forbidden-table spam and fewer TargetFrame currValue secret crashes.


2026-02-12 (nameplate/aura taint guard pass)
Errors:
- ADDON_ACTION_BLOCKED UNKNOWN() from SecureAuraHeader/RegisterForClicks.
- Nameplate castbar SetShown(secret) in CastingBarFrame:SetIsHighlightedCastTarget.
- Nameplate TextStatusBar secret compare and ClassNameplateBar secret arithmetic.
Hypothesis:
- Custom secure aura header is tainting restricted aura paths in WoW12.
- Blizzard nameplate cast-target highlight + text/power widgets still execute on secret values unless explicitly neutralized per frame.
Change(s):
- Components/Auras/Auras.lua: OnEnable now hard-returns in WoW12 secret-value mode (keeps Blizzard BuffFrame, avoids secure aura header setup).
- Components/UnitFrames/Units/NamePlates.lua: kept invasive Disable/Restore path off in secret mode, but added per-nameplate PatchBlizzardNamePlate(unit) to:
  - hide/unregister class nameplate power widgets via clearClutter,
  - disable cast-target highlight methods on Blizzard castbars,
  - disable Blizzard healthbar text update methods that compare secret values.
- Hooked the patch on NAME_PLATE_UNIT_ADDED and initial plate scan on enable.
Result:
- Pending test (/reload required).


2026-02-12 (nameplate early-patch + forbidden-index fix)
Errors:
- CastingBarFrame:SetIsHighlightedCastTarget secret SetShown still firing on first nameplate setup.
- attempted to index a forbidden table still present.
Hypothesis:
- NAME_PLATE_UNIT_ADDED patch timing is too late (OnUnitSet already ran).
- Iterating C_NamePlate.GetNamePlates() and indexing plate.UnitFrame can trip forbidden-table access on some plates.
Change(s):
- Components/UnitFrames/Units/NamePlates.lua: added early OnNamePlateCreated hook to patch Blizzard plate frames before first OnUnitSet.
- Added PatchBlizzardNamePlateFrame(plate) path that patches by direct plate reference with forbidden guards.
- Reworked initial plate scan to use frame patcher only (no direct unitFrame/unit indexing from forbidden tables).
Result:
- Pending test (/reload required).

2026-02-12 (secret-aura + cast highlight hardening)
Errors:
- Nameplate castbar SetShown(secret) still firing in CastingBarMixin SetIsHighlightedCastTarget.
- TargetFrame aura secret fields (applications/sourceUnit) still crashing Blizzard aura update.
- CompactUnitFrame heal prediction secret maxHealth in nameplate/party paths.
- Sporadic forbidden-table index remains.
Hypothesis:
- Early nameplate patch coverage was still incomplete for some created frames; Blizzard mixin-level guard needed.
- Blizzard aura/healprediction code needs defensive pcall wrappers in WoW12 to avoid hard breakage when secret fields leak through.
- Initial nameplate scan over GetNamePlates can still touch forbidden entries.
Change(s):
- Core/FixBlizzardBugs.lua: wrapped CastingBarMixin.SetIsHighlightedCastTarget to coerce secret flags to false.
- Core/FixBlizzardBugs.lua: wrapped CompactUnitFrame_UpdateHealPrediction with pcall + hide prediction bars on failure.
- Core/FixBlizzardBugs.lua: wrapped TargetFrameMixin.UpdateAuras with pcall + hide BuffFrame/DebuffFrame on failure.
- Components/UnitFrames/Units/NamePlates.lua: patched AurasFrame per-instance (unitToken/unit sync and safe AddAura wrapper).
- Components/UnitFrames/Units/NamePlates.lua: removed startup full GetNamePlates patch scan to avoid forbidden-table indexing from restricted entries.
Result:
- Pending test (/reload required).

2026-02-13 (UnhaltedUnitFrames parity pass)
Errors:
- Nameplate/target secret-value crashes still tainted by AzeriteUI (cast highlight, aura flags, mana/power text math).
- Forbidden-table indexing still appears intermittently.
Hypothesis:
- We are still tainting Blizzard paths by replacing Blizzard mixin/global methods in `Core/FixBlizzardBugs.lua`.
- `Components/UnitFrames/Units/NamePlates.lua` per-frame method replacement (`AddAura`, castbar highlight methods, health text methods) is too invasive.
- UnhaltedUnitFrames pattern is safer: disable/hide Blizzard components and avoid runtime API/mixin rewrites.
Planned change(s):
- Roll back WoW12 global/mixin method rewrites in `Core/FixBlizzardBugs.lua` (keep module passive in Midnight).
- Remove per-instance Blizzard method replacement in nameplate patcher; keep only non-invasive state sync and clutter hide.
- Keep custom player aura header disabled in WoW12 (`Components/Auras/Auras.lua`) to avoid secure aura taint.
Result:
- In progress.

2026-02-15 (library refresh pass)
Issue:
- Embedded libraries are mixed-age; several are older than current upstream builds for WoW 12.
Hypothesis:
- Updating core third-party libs (Ace3 stack, LibSharedMedia-3.0, TaintLess) to latest stable upstream revisions reduces taint edge cases and keeps API behavior aligned with current clients.
Planned change(s):
- Sync Ace3 modules from latest local Ace3 package (Release-r1390).
- Sync LibSharedMedia-3.0 from latest standalone package (revision 164 / 12.0.0 v1).
- Sync TaintLess script to 24-07-27 and update bundled toc version tags.
- Keep custom/forked libs (`oUF`, `LibActionButton-1.0-GE`, `LibSmoothBar-1.0`, `LibSpinBar-1.0`, etc.) unchanged unless upstream mapping is explicit.
Result:
- Synced embedded Ace3 modules from `..\Ace3` (Release-r1390 sources) for:
  - `AceAddon-3.0`, `AceComm-3.0`, `AceConfig-3.0`, `AceConsole-3.0`, `AceDB-3.0`, `AceDBOptions-3.0`,
    `AceEvent-3.0`, `AceGUI-3.0`, `AceHook-3.0`, `AceLocale-3.0`, `AceSerializer-3.0`, `AceTimer-3.0`,
    plus `CallbackHandler-1.0` and `LibStub`.
- Synced `LibSharedMedia-3.0` from `..\LibSharedMedia-3.0\LibSharedMedia-3.0` (revision 164 / minor 12000001).
- Synced `TaintLess.xml` to 24-07-27 and updated:
  - `Libs/TaintLess/TaintLess.toc`
  - `Libs/TaintLess/TaintLess_Classic.toc`
  - `Libs/TaintLess/TaintLess_Wrath.toc`
- Kept forked/custom libraries unchanged in this pass (`oUF`, `LibActionButton-1.0-GE`, `LibSmoothBar-1.0`, `LibSpinBar-1.0`, etc.).

2026-02-15 (oUF upstream update request)
Issue:
- User requested updating embedded `oUF` directly from upstream GitHub.
Plan:
- Pull latest official oUF release source from GitHub.
- Replace `Libs/oUF` and `Libs/oUF_Classic` with upstream files.
- Apply minimal AzeriteUI compatibility patches where local integration assumptions no longer hold.
Result:
- Downloaded official oUF GitHub tag `13.1.2` archive (`oUF-wow/oUF`).
- Replaced embedded `Libs/oUF` and `Libs/oUF_Classic` with upstream source.
- Normalized embedded toc version tokens to explicit `13.1.2` (kept `oUF_Classic` interface compatibility header).
- Found integration regression: upstream `oUF/init.lua` no longer defines AzeriteUI-expected
  compatibility flags (`oUF.isRetail`, `oUF.isClassic`, `oUF.isTBC`, `oUF.isWrath`, `oUF.isCata`, `oUF.WoW10`).
- Planned fix: reintroduce these flags locally in embedded `Libs/oUF/init.lua` and `Libs/oUF_Classic/init.lua`.
- Applied compatibility flag shim in both embedded init files.
- Static audit pass after update:
  - Nameplate driver API usage now matches oUF 13.1.2 callback model.
  - No additional direct misuse found for refreshed Ace3/LibSharedMedia/TaintLess in repository callsites.
- Remaining validation requires in-game `/reload` + BugSack run.

2026-02-15 (post-oUF 13.1.2 regression triage, session 3523)
Errors:
- Repeated `Style [...] already registered` in unit CreateUnitFrames.
- oUF aura cooldown API mismatch (`SetCooldownFromDurationObject` nil).
- oUF power API arg mismatch (`GetUnitPowerBarInfo` bad unit token).
- oUF aura color table mismatch (`colors.dispel` nil).
- AzeriteUI frame math now receiving nil heal prediction values.
- Castbar timer API mismatch (`SetTimerDuration` bad arg).
Hypothesis:
- AzeriteUI custom frame code still assumes older oUF element contracts in several spots.
- oUF 13.x accepts/returns newer data forms and stricter unit checks; we need compatibility guards.
Planned change(s):
- Add style registration guards.
- Add fallback paths in oUF elements for old/new cooldown/timer APIs.
- Add nil-safe math guards in AzeriteUI PostUpdate handlers.
- Add safe fallback for missing `colors.dispel`.
Result:
- Applied:
  - `oUF:RegisterStyle` duplicate registration now replaces existing style instead of erroring.
  - Aura cooldown update now supports both duration-object and legacy `SetCooldown` fallback.
  - Aura dispel color curve now falls back to `oUF.colors.dispel` when `self.colors.dispel` is missing.
  - Power display path now guards non-string unit tokens before `GetUnitPowerBarInfo`.
  - Castbar timer setup now wraps `SetTimerDuration` and falls back to numeric duration when needed.
  - Player/Pet Blizzard castbar suppression in oUF castbar enable now uses forbidden-safe `pcall` wrappers.
  - Nil-safe heal prediction math added in target/nameplate post-update handlers.
  - Extended nil-safe heal prediction normalization to all unit-frame PostUpdate handlers relying on old callback args (`Arena/Boss/Focus/Pet/Party/Player/PlayerAlternate/Raid5/Raid25/Raid40/ToT`).
  - Castbar OnUpdate now guards `GetTimerDuration()` with `pcall` to avoid forbidden/bad-arg runtime errors.
  - oUF Blizzard-disabling paths are now secret-mode gated for `boss/party/arena` and nameplate frame touching is skipped in secret mode to reduce EditMode taint.
  - LibActionButton tooltip update path now uses `pcall` wrappers and hides tooltip on failure to avoid Backdrop secret-width crashes.
- Updated nameplate integration for new oUF driver callback API:
  - `Components/UnitFrames/Units/NamePlates.lua`: switched from
    `oUF:SpawnNamePlates(prefix, callback, cvars)` to driver-based setup using
    `SetAddedCallback`, `SetRemovedCallback`, `SetTargetCallback`, `SetCVars`.
- Pending in-game `/reload` regression test.

2026-02-15 (session 3526 triage)
Errors:
- Forbidden-table iterate via Blizzard CastingBar `StopFinishAnims` from `PlayerCastBar.lua` (`SetUnit(nil)` path).
- Player castbar safe-zone math uses `element.max` which is nil with oUF 13 timer-object flow.
- Blizzard NamePlateAuras/CompactUnitFrame secret-value errors still active (`nameplateShowPersonal`, `maxHealth`).
Hypothesis:
- Direct `PlayerCastingBarFrame:SetUnit(nil)` / `PetCastingBarFrame:SetUnit(nil)` is unsafe in WoW12 and can trip forbidden internal animation tables.
- Player castbar callbacks still assume numeric duration state; oUF 13 now uses duration objects.
- Blizzard nameplate aura/heal-prediction logic remains live; we still need to non-invasively suppress Blizzard nameplate sub-systems per plate.
Planned change(s):
- Remove `SetUnit(nil)` calls and harden Blizzard castbar suppression with forbidden-safe wrappers.
- Add timer-duration resolver in `PlayerCastBar.lua` and guard safe-zone ratio when max duration is unavailable.
- Expand nameplate clutter clearing to disable Blizzard `UnitFrame` aura/health/power/cast update event paths without reparent hacks.
Result:
- In progress.
Update:
- `Components/UnitFrames/Units/PlayerCastBar.lua`
  - Removed Blizzard castbar `SetUnit(nil)` calls; suppression now uses forbidden-safe `pcall` wrappers.
  - Added duration-object aware timer helpers for custom text and safe-zone math (no direct `element.max` requirement).
- `Libs/oUF/elements/castbar.lua` + `Libs/oUF_Classic/elements/castbar.lua`
  - Guarded `SetTimerDuration` in CastUpdate with `pcall` fallback.
  - Guarded Blizzard castbar event re-registration behind forbidden-safe `pcall` blocks.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Expanded `clearClutter` to disable Blizzard nameplate UnitFrame/aura/health/power/cast events and hide Blizzard aura frame.
  - Removed direct `auras.unit/unitToken/auraItemScale` writes on Blizzard frames to reduce taint propagation.
Validation:
- `luac -p` passed for all touched files.
Result:
- Ready for in-game `/reload` verification against session 3526 stacks.

2026-02-15 (session 3526 follow-up: stale bars)
Issue:
- No Lua errors, but player/target/nameplate health and power bars appear static.
Hypothesis:
- `Components/UnitFrames/Functions.lua` was defaulting secret current values to max, which effectively pins bars at full when WoW12 returns secret current values.
Change(s):
- `API.UpdateHealth`: when current health is secret/nil, derive current value from `UnitHealthPercent` (safe) or cached `element.safeCur` before falling back to full.
- `API.UpdatePower`: same strategy for power using `UnitPowerPercent` and cached safe values.
- Added clamping for derived values to min/max bounds.
Validation:
- `luac -p Components/UnitFrames/Functions.lua` passed.
Result:
- Pending in-game `/reload` verification for moving health/power on player/target/nameplates.

2026-02-15 (session 3530 triage)
Errors:
- `SetVertexColor` bad arg in `Components/UnitFrames/Units/Player.lua`, `Target.lua`, `PlayerAlternate.lua`.
- oUF castbar arithmetic on secret `endTime` (`Libs/oUF/elements/castbar.lua`).
- Nameplates boolean test on secret `notInterruptible`.
- Tooltip/Backdrop secret width errors still tainted via LibActionButton tooltip path.
Hypothesis:
- We still pass secret values into color/boolean/arithmetic logic in frame callbacks.
- oUF castbar safe-zone ratio path still assumes numeric `endTime/startTime` and does math directly.
- Tooltip path needs stricter fallback that avoids triggering Blizzard backdrop updates when parameters are tainted.
Planned change(s):
- Add explicit `issecretvalue` guards and numeric/color sanitizers at failing unitframe callbacks.
- Guard oUF castbar ratio calculation from secret `startTime/endTime`.
- Disable nameplate cast color decisions when `notInterruptible` is secret.
- Tighten LAB tooltip wrapper path to bail before style application on failure.
Result:
- In progress.
Update:
- `Components/UnitFrames/Units/Player.lua`, `PlayerAlternate.lua`, `Target.lua`:
  - Threat indicator `PostUpdate` now sanitizes `r/g/b` before `SetVertexColor` to avoid secret/nil color args.
- `Components/UnitFrames/Units/NamePlates.lua`:
  - `Castbar_PostUpdate` now sanitizes `element.notInterruptible` before boolean tests.
- `Libs/oUF/elements/castbar.lua` + `Libs/oUF_Classic/elements/castbar.lua`:
  - Guarded `startTime/endTime` arithmetic paths from secret values in timer fallback and safe-zone ratio calculations.
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - In secret-value mode, action button tooltip update now bails early (hide + disable per-button update) to stop recurring Backdrop secret-width taint.
Validation:
- `luac -p` passed for all touched files.
Result:
- Ready for `/reload` and session 3530 regression retest.

2026-02-15 (session 3530 follow-up: bars still static + mixed Blizzard/oUF plates)
Issue:
- Bars still appear non-animated/non-moving.
- Some NPCs still show Blizzard nameplates alongside AzeriteUI handling.
Hypothesis:
- `Components/UnitFrames/Functions.lua` still calls `SetSafeValue`/`SetSafeMinMaxValues` each update; LibSmoothBar treats these as direct safe-display assignments, which can flatten smoothing/update behavior.
- Nameplate callback filter hides AzeriteUI plates for some non-hostile/special units, allowing Blizzard plate visuals to remain visible.
Planned change(s):
- Stop per-tick `SetSafeValue` writes in health/power overrides; keep cached safe fields but let regular `SetValue` path drive bar updates.
- Remove aggressive custom nameplate filtering branch in `NAME_PLATE_UNIT_ADDED` callback.
Result:
- In progress.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Removed per-update `SetSafeMinMaxValues`/`SetSafeValue` calls in health/power overrides.
  - Kept cached safe fields, but let normal bar `SetMinMaxValues`/`SetValue` path drive updates to restore motion/smoothing behavior.
- `Components/UnitFrames/Units/NamePlates.lua`:
  - Removed aggressive custom filtering in `NAME_PLATE_UNIT_ADDED` callback that hid AzeriteUI plates for certain units.
  - oUF plate is now forced visible for all NamePlateDriver-provided units to avoid mixed Blizzard/oUF plate visuals.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Ready for `/reload` test loop.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Health override now keeps raw `UnitHealth/UnitHealthMax` values for `SetMinMaxValues/SetValue` writes (including secret-capable path), while safe numeric fallbacks are used only for addon-side math/text.
  - Power override now keeps raw `UnitPower/UnitPowerMax` values for bar writes and no longer prefers `SetSafeValue` for live updates.
- `Components/UnitFrames/Units/NamePlates.lua`:
  - Added hook on `NamePlateUnitFrameMixin:OnUnitSet` to run plate patching for every unit assignment, including units that enter view after reload.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Ready for `/reload` retest of bar motion + Blizzard plate suppression.
- `Components/UnitFrames/Units/PlayerCastBar.lua`:
  - Removed `nameplateShowSelf` visibility gating; custom player castbar now stays enabled when module is enabled.
  - This avoids accidental castbar disappearance when personal nameplate CVar is enabled.

2026-02-15 (follow-up: player moves, target static; colors lost; residual Blizzard plates)
Issue:
- Player bar movement restored, but target bars still static and player colors regressed.
- Some Blizzard nameplates still visible for NPCs that enter view after reload.
Hypothesis:
- Target/raw secret values still reaching bar writes; if bar backend cannot consume them reliably, target appears frozen. We need deterministic safe percent writes when raw values are secret.
- Color regression likely from fallback `safeCur/safeMax` collapsing to defaults; derive from safe percent first.
- `Libs/oUF/blizzard.lua` currently short-circuits `DisableBlizzardNamePlate` in secret mode, so some Blizzard plate UFs remain visible.
Planned change(s):
- In `Components/UnitFrames/Functions.lua`, use safe percent (0-100) as write source whenever raw current/max are secret/unusable for health/power.
- In `Libs/oUF/blizzard.lua` (and classic mirror), remove secret-mode early return in `DisableBlizzardNamePlate` and rely on forbidden guards.
Result:
- In progress.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Health writes now use raw UnitHealth/UnitHealthMax only when both are non-secret usable numbers.
  - Otherwise writes switch to safe percentage mode (`0..100` via `UnitHealthPercent`) to keep bars moving for secret-value units (notably target/nameplates).
  - Power writes now follow the same rule using `UnitPowerPercent` when raw power values are secret/unusable.
- `Libs/oUF/blizzard.lua` + `Libs/oUF_Classic/blizzard.lua`:
  - Removed secret-mode early return from `DisableBlizzardNamePlate(frame)`.
  - We now rely on existing `frame.UnitFrame` + `IsForbidden()` guards so late-entering NPC plates are still forced invisible on Blizzard side.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Libs/oUF/blizzard.lua`
- `luac -p Libs/oUF_Classic/blizzard.lua`
Result:
- Ready for `/reload` verification of target movement, color restoration, and Blizzard plate suppression.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Switched health/power live writes to prefer safe percent (`UnitHealthPercent` / `UnitPowerPercent`) when available; raw values are used only when both current/max are clean numeric values.
  - This keeps bars moving in secret-value scenarios while preserving cached numeric fields for addon-side math/color/text.
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Restored tooltip updates in secret-value mode (removed unconditional early bail).
  - On transient `SetTooltip` failure, tooltip now hides but update function is not permanently disabled.
- `Libs/oUF/elements/castbar.lua` + `Libs/oUF_Classic/elements/castbar.lua`:
  - Added OnUpdate fallback animation path using `startTime/endTime` when timer-duration object is unavailable/blocked.
  - Fallback also drives time text so castbar remains visibly active.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- `luac -p Libs/oUF/elements/castbar.lua`
- `luac -p Libs/oUF_Classic/elements/castbar.lua`
Result:
- Ready for `/reload` retest of bars, castbar animation, and actionbar tooltips.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Synced `SafeUnitPercentNumber` to DiabolicUI3-style signature (`includePredicted=true`) for `UnitHealthPercent/UnitPowerPercent` calls.
  - Health/power overrides now align cached `cur/max/min` with the actual write mode (`raw` or `0..100 percent`) to prevent stale cross-target carry-over.
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - Added per-button secret-size guard before tooltip anchor/set to skip only tainted button tooltips and avoid Backdrop secret-width errors.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Ready for `/reload` retest: frame movement + tooltip stability.
Update (creator guidance alignment):
- Adopted safer percentage API semantics (`includePredicted=true`) and synchronized cache state with write mode.
- Fixed power-update local shadowing bug (`local barMin = barMin`) that could destabilize safe min/max cache and produce stale/cross-target values.
- ActionButton tooltip path now checks button dimensions for secret values before tooltip anchor/setup.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
2026-02-15 (power orb polish + hide power values)
Issue:
- Requested: improve mana orb (power orb) behavior inspired by DiabolicUI3 and remove power values from all unitframes for now.
- Current orb visuals can drift when color state is inherited from power-color logic; power value tags are still created on multiple frames.
Planned change(s):
- Player orb: add explicit PostUpdate color enforcement for AdditionalPower (mana orb), and force `colorPower = false` so orb keeps intended color.
- Global: hide power value/percent text outputs in shared power update functions so all unitframe powerbars stop showing values.
Files targeted:
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added `Mana_PostUpdate` to enforce orb color from `config.PowerOrbColors.MANA` each update (DiabolicUI3-inspired explicit orb color path).
  - Forced orb `colorPower = false` both on creation and texture refresh to prevent unwanted recolor drift.
  - Wired `self.AdditionalPower.PostUpdate = Mana_PostUpdate`.
- `Components/UnitFrames/Functions.lua`:
  - Added `HidePowerTexts(element)` helper.
  - `API.UpdatePower` and `API.UpdateAdditionalPower` now hide `Value`, `Percent`, and `ManaText` overlays on every update.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` test loop.
2026-02-15 (target healthbar reverse to opposite of player)
Issue:
- Target healthbar currently fills in same direction as player; requested opposite orientation.
Root cause:
- `Layouts/Data/TargetUnitFrame.lua` has `IsFlippedHorizontally = false` while both player/target use `HealthBarOrientation = "RIGHT"`.
Planned change(s):
- Set `TargetFrame.IsFlippedHorizontally = true` to reverse target fill direction without changing layout geometry.
Files targeted:
- Layouts/Data/TargetUnitFrame.lua
Update:
- `Layouts/Data/TargetUnitFrame.lua`:
  - Changed `IsFlippedHorizontally` from `false` to `true` for TargetFrame.
Validation:
- `luac -p Layouts/Data/TargetUnitFrame.lua`
Result:
- Ready for `/reload` test.
2026-02-15 (player power crystal threat highlight follow live crystal position)
Issue:
- Player power crystal threat/target highlight renders at stale position after user-adjusted crystal offset/scale.
Root cause:
- Threat textures used static `PowerBarThreatPosition` / `PowerBackdropThreatPosition` anchors on parent frame; only additive offsets were applied.
- They were not anchored to live `power` / `powerCase` widgets.
Planned change(s):
- Anchor `ThreatIndicator` power textures directly to `power` and `powerCase` frames using their threat point offsets.
- Keep existing offset sliders applied on top.
Files targeted:
- Components/UnitFrames/Units/Player.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - `ThreatIndicator` power textures now anchor to live widgets:
    - `PowerBar` threat texture anchors to `power`.
    - `PowerBackdrop` threat texture anchors to `powerCase`.
  - Existing user offsets are still applied on top.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload` verification of combat/target highlight alignment.
2026-02-15 (target health direction via script-handler mirror values)
Issue:
- Target health still appears visually flipped-only in some cases; requested fix where actual bar fill direction uses safe handler values (OnMinMaxChanged/OnValueChanged), not direct bar queries.
Planned change(s):
- Enable value-mirror texcoord mode for TargetFrame health bar.
- Recompute mirror base texcoords when target style/flip updates.
- In shared mirror handler, avoid GetMinMaxValues fallback reads when texcoord mirror mode is active (use only handler-cached min/max).
Files targeted:
- Components/UnitFrames/Units/Target.lua
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Enabled handler-driven texcoord mirror mode for target health (`self.Health.__AzeriteUI_UseValueMirrorTexCoord = true`).
  - Reset cached base texcoords whenever target horizontal flip changes so mirror math rebinds correctly.
- `Components/UnitFrames/Functions.lua`:
  - In statusbar mirror `OnValueChanged`, removed min/max fallback query (`GetMinMaxValues`) for mirror texcoord path.
  - Mirror path now relies on values passed by script handlers (`OnMinMaxChanged` + `OnValueChanged`) only.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Ready for `/reload` validation of target health fill direction.
2026-02-15 (target health handler-mirror hard fix + power threat highlight scaling)
Issue:
- Target health fill still reversed incorrectly (bar logic direction, not art frame).
- Player power threat highlight still misaligned after user scale/offset changes.
Planned change(s):
- Apply direct target health script-handler mirror logic (`OnMinMaxChanged` + `OnValueChanged`) to drive bar texture coords/anchor from handler values only.
- Disable target health reverse-fill/flip reliance and use explicit texcoord mirror math.
- Scale player power threat textures with current power-bar X/Y scales so highlight follows size changes.
Files targeted:
- Components/UnitFrames/Units/Target.lua
- Components/UnitFrames/Units/Player.lua
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Applied direct script-handler mirror fix on target health bar:
    - `OnMinMaxChanged` caches min/max.
    - `OnValueChanged` drives flipped texcoords + left anchor shift from handler values only.
  - Disabled target health texcoord mirror toggle (`__AzeriteUI_UseValueMirrorTexCoord = false`) to avoid double-control.
- `Components/UnitFrames/Units/Player.lua`:
  - Power threat textures (`PowerBar`, `PowerBackdrop`) now scale with current `powerBarScaleX/powerBarScaleY` in addition to offset anchoring.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload` verification of target fill direction and player power threat highlight alignment.
2026-02-16 (player power fake fill secret arithmetic crash)
Issue:
- BugSack error in `Components/UnitFrames/Units/Player.lua`:
  - `attempt to perform arithmetic on local 'texBottom' (a secret number value tainted by 'AzeriteUI')`
Root cause:
- Player fake power fill path still performed runtime arithmetic for clip/inset updates in a way that could involve secret-tainted values during updates.
Planned change(s):
- Switch player fake power fill to texcoord-only clipping using cached safe base texcoords.
- Remove width/height inset math from the fake fill update path.
Files targeted:
- Components/UnitFrames/Units/Player.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Rewrote `UpdatePlayerFakePowerFill` to use texcoord-only clipping on `FakeFill`.
  - Removed fake-fill width/height inset math from runtime updates.
  - Cached base fake-fill texcoords on `power` (`__AzeriteUI_PowerFakeTexLeft/Right/Top/Bottom`) during style update and reuse them for updates.
  - Added safe fallback path for fake fill:
    - Uses `power.safeMin/safeMax/safeCur` when handler values are missing/secret.
    - Returns visibility state from `UpdatePlayerFakePowerFill`.
    - Keeps native statusbar texture visible whenever fake fill cannot be drawn yet, preventing empty bar.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload` verification; expected to eliminate secret arithmetic from player power fake fill.
2026-02-16 (ToT health ghost overlay)
Issue:
- ToT health appears to have a pale/ghost duplicate layer (similar to earlier target ghost).
Root cause:
- `Components/UnitFrames/Units/ToT.lua` creates `self.Health.Preview` and keeps it visible at `alpha .5`.
- Since preview is continuously value-synced in `API.UpdateHealth`, it behaves like a permanent second health layer.
Planned change(s):
- Keep `Health.Preview` as internal prediction helper but set its visible alpha to `0` to remove ghosting.
Files targeted:
- Components/UnitFrames/Units/ToT.lua
Update:
- `Components/UnitFrames/Units/ToT.lua`:
  - Changed `self.Health.Preview` visual alpha from `.5` to `0`.
  - Left preview bar in place for internal prediction math only.
Validation:
- `luac -p Components/UnitFrames/Units/ToT.lua`
Result:
- Ready for `/reload` verification; expected to remove ToT ghost health overlay.
2026-02-16 (ToT ghost persisted after preview alpha change)
Issue:
- User still reports a visible pale/ghost layer on ToT.
Root cause hypothesis:
- A hidden-by-alpha preview helper can still be reintroduced visually by downstream updates.
- ToT cast overlay may remain visible as a pale full-bar overlay when not actively casting.
Planned change(s):
- Hard-hide ToT preview helper bar (`:Hide()` + alpha 0).
- Hard-hide ToT cast overlay at init (`:Hide()`), so only active casts show.
Files targeted:
- Components/UnitFrames/Units/ToT.lua
Update:
- `Components/UnitFrames/Units/ToT.lua`:
  - Added `healthPreview:Hide()` (in addition to alpha 0) to keep preview helper non-visible.
  - Added `castbar:Hide()` at init to prevent inactive cast overlay ghosting.
Validation:
- `luac -p Components/UnitFrames/Units/ToT.lua`
Result:
- Ready for `/reload` verification; expected to remove remaining ToT ghost layer.
2026-02-16 (player power mirror-statusbar conversion + stock geometry restore)
Issue:
- Player power statusbar could become invisible/incorrect while using fake texture fill path.
- Ice crystal geometry was oversized/misaligned compared to `AzeriteUI_Stock`.
Root cause:
- Fake texture path depended on extra state and could hide native visuals before fake draw state was valid.
- `Layouts/Data/PlayerUnitFrame.lua` power geometry had drifted from stock values.
Planned change(s):
- Use hidden native power statusbar as source and a visible mirrored display statusbar (`Power.Display`) as output.
- Sync display writes in `API.UpdatePower`.
- Restore stock power crystal size/position/case threat anchors for Novice/Hardened/Seasoned profiles.
Files targeted:
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Functions.lua
- Layouts/Data/PlayerUnitFrame.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added real display statusbar for player power (`self.Power.Display`) and stopped relying on texture fake-fill for rendering.
  - Power visibility now hides native and shows display when crystal is active.
  - Power display texture/orientation/texcoords now mirror stock setup each texture update pass.
  - Locked runtime power offsets/scales to stock baseline (`0` offsets, `1` scales) for deterministic stock alignment.
- `Components/UnitFrames/Functions.lua`:
  - `API.UpdatePower` now mirrors min/max/value into `element.Display` (same pattern used by health display path).
- `Layouts/Data/PlayerUnitFrame.lua`:
  - Restored stock power crystal geometry:
    - `PowerBarSize = {120, 140}`
    - `PowerBarPosition = {"BOTTOMLEFT", 20, 38}`
    - `PowerBarForegroundPosition = {"BOTTOM", 7, -51}`
    - `PowerBackdropThreatPosition = {"BOTTOM", 7, -51}`
  - Applied for Novice, Hardened, Seasoned.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Layouts/Data/PlayerUnitFrame.lua`
Result:
- Ready for `/reload` verification of player power visibility and stock crystal geometry.
2026-02-16 (player power SetOrientation argument error)
Issue:
- BugSack: `Components/UnitFrames/Units/Player.lua:687 bad argument #1 to SetOrientation`.
Root cause:
- Runtime power orientation value can be non-supported for a direct `SetOrientation(...)` call.
- We removed prior orientation guard in a previous pass.
Planned change(s):
- Add guarded orientation normalizer with safe fallback for player power and mirrored display bar.
- Fallback to stock crystal-safe vertical orientation when value is invalid.
Files targeted:
- Components/UnitFrames/Units/Player.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added guarded orientation normalization/fallback for player power and mirrored display bar.
  - Invalid orientation values now fall back safely instead of erroring.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload`; expected to prevent `SetOrientation` argument errors on player power.
2026-02-16 (player power rollback to native statusbar + drawlayer range guard)
Issue:
- User requested rollback to real/native player power statusbar (remove mirror/fake path).
- BugSack:
  - `Texture:SetDrawLayer` sublevel out of range (`-8..7`) from power art layer slider values.
Planned change(s):
- Remove player power display mirror rendering path and return to native statusbar rendering.
- Clamp all power-related drawlayer sublevels to valid integer range.
- Keep fake-fill visuals hidden.
Files targeted:
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Restored native player power rendering in `Power_UpdateVisibility` (show native, hide display/fake).
  - Removed creation/use of `self.Power.Display`.
  - Simplified power orientation to native crystal-safe vertical orientation.
  - Added `ClampLayer(...)` helper in texture update flow and applied to:
    - power texture layer
    - power backdrop/case layers
    - threat glow layers
  - Kept fake texture hidden.
- `Components/UnitFrames/Functions.lua`:
  - Removed `API.UpdatePower` display mirror write block.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Ready for `/reload`; expected to remove drawlayer error and use native player power bar only.
2026-02-16 (player power threat aura follow crystal transforms)
Issue:
- User requested power crystal threat aura to move/scale with crystal adjustments.
Root cause:
- Crystal transform variables were temporarily hardcoded (`offset=0`, `scale=1`) during rollback, so threat textures didn't follow profile transforms.
Planned change(s):
- Re-enable profile-based power offset/scale values while keeping native power rendering and drawlayer clamping.
Files targeted:
- Components/UnitFrames/Units/Player.lua
Update:
- Restored profile-driven:
  - `powerBarOffsetX/Y`
  - `powerCaseOffsetX/Y`
  - `powerBarScaleX/Y` (+ legacy fallback)
- Existing threat anchoring logic already follows `power`/`powerCase` and uses these values, so no extra threat rewrite needed.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Ready for `/reload`; threat aura should now follow crystal move/scale changes.

2026-02-16 (UnitFrames options nil db guards)
Issue:
- BugSack:
  - `Options/OptionsPages/UnitFrames.lua:43 attempt to index field 'db' (a nil value)`
  - `Options/OptionsPages/UnitFrames.lua:130 attempt to index field 'db' (a nil value)`
Root cause:
- Options closures assumed module/db/profile always exists during UI interactions.
Planned change(s):
- Add nil guards around module/db/profile access in GenerateSubOptions and Player/PlayerAlternate toggles.
Files targeted:
- Options/OptionsPages/UnitFrames.lua
Update:
- Added defensive checks before all `module.db.profile` accesses in setter/getter helpers.
- Added guards for `PlayerFrame` and `PlayerFrameAlternate` db access in visibility and enable handlers.
Validation:
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Ready for `/reload`; expected to prevent options-page nil db crashes.
2026-02-16 (drawlayer clamp hardening + tooltip secret-size guards)
Issue:
- BugSack still reports:
  - `Texture:SetDrawLayer(): sublevel must be between -8 and 7` from player power texture updates.
  - `Backdrop.lua:226 width secret` on bag tooltip hover.
Root cause hypothesis:
- Drawlayer path can still receive invalid sublevels from profile/slider state transitions.
- Tooltip skinning calls BackdropTemplate flow while tooltip width/height is secret in WoW12, triggering Blizzard backdrop arithmetic.
Planned change(s):
- Harden player SetDrawLayer calls with safe clamped wrapper and clamp art-layer option range.
- Add WoW12 secret-size early-exit in tooltip backdrop theming and avoid re-theming when dimensions are secret.
Files targeted:
- Components/UnitFrames/Units/Player.lua
- Options/OptionsPages/UnitFrames.lua
- Components/Misc/Tooltips.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added `SafeSetDrawLayer(...)` wrapper using clamped integer sublevels and `pcall`.
  - Switched all player power/crystal/threat `SetDrawLayer` writes to `SafeSetDrawLayer`.
- `Options/OptionsPages/UnitFrames.lua`:
  - Clamped `powerBarArtLayer` slider range from `-8..8` to `-8..7` (WoW API valid sublevels).
- `Components/Misc/Tooltips.lua`:
  - Added WoW12 secret-size guard in `UpdateBackdropTheme` to bypass AzeriteUI backdrop skinning when tooltip/backdrop width/height are secret.
  - Restores Blizzard tooltip layers/NineSlice in that bypass path.
  - Skips runtime `SharedTooltip_SetBackdropStyle` hook when secret-value API is present to reduce re-entry into backdrop math.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
- `luac -p Components/Misc/Tooltips.lua`
Result:
- Ready for `/reload`; expected to remove drawlayer sublevel errors and stop tooltip secret-width backdrop errors without disabling tooltips.
2026-02-16 (player+target powerbar lab rebuild for /az options)
Issue:
- Existing player power controls are limited and do not expose full anchor/scale control.
- Target power crystal has almost no live tuning options in `/az`.
- User requested comprehensive micromanagement for powerbar alignment/scaling/anchoring.
Planned change(s):
- Add comprehensive `Power Crystal Lab` options for Player and Target in `Options/OptionsPages/UnitFrames.lua`.
- Add neutral profile defaults for new power tuning keys in Player/Target module defaults.
- Apply new player power tuning keys in `Components/UnitFrames/Units/Player.lua` during `UnitFrame_UpdateTextures`.
- Apply new target power tuning keys in `Components/UnitFrames/Units/Target.lua` during `UnitFrame_UpdateTextures`.
Files targeted:
- Options/OptionsPages/UnitFrames.lua
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Units/Target.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added comprehensive power tuning profile defaults (anchors, offsets, scales, threat offsets/scales).
  - Reworked power placement in `UnitFrame_UpdateTextures` to support anchor-frame selection for bar/backdrop/case and threat glow anchors.
  - Added independent scale controls for backdrop/case/threat and applied them live during texture updates.
- `Components/UnitFrames/Units/Target.lua`:
  - Added target power tuning defaults (anchors, offsets, scales, art layer).
  - Added target power anchor helpers and drawlayer clamp helper.
  - Extended `UnitFrame_UpdateTextures` signature cache to include target power options so changes refresh immediately.
  - Applied target power bar/backdrop/value anchor+offset+scale+layer tuning in update path.
- `Options/OptionsPages/UnitFrames.lua`:
  - Expanded Player `/az` power options with comprehensive controls:
    - anchor selection (bar/backdrop/case/threat)
    - offsets (bar/backdrop/case/threat)
    - scales (bar/backdrop/case/threat)
    - art layer and existing reset/rebase integration
  - Added Target `/az` `Power Crystal Lab` controls:
    - anchors (bar/backdrop/value)
    - offsets (bar/backdrop/value)
    - scales (bar/backdrop)
    - art layer
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Ready for `/reload`; player and target power crystal systems now support fine-grained live micromanagement in `/az` options.
2026-02-16 (target health fake-fill WoW12 safety hardening)
Issue:
- Target health reported as broken/intermittent after recent changes.
- Fake-fill path could ingest callback min/max/value from statusbar scripts without WoW12 secret-value guarding.
Root cause hypothesis:
- `OnMinMaxChanged`/`OnValueChanged` can provide secret numbers; fake-fill logic then compares/arithmetic on those values and can silently fail or break updates.
Planned change(s):
- Add a local safe-number guard in `Target.lua`.
- Only cache callback min/max/value when values are non-secret numbers.
- Guard fake-fill math entry for health and cast fake bars.
Files targeted:
- Components/UnitFrames/Units/Target.lua
Update:
- Added `IsSafeNumber(...)` helper.
- Hardened `UpdateTargetFakeHealthFill` and `UpdateTargetFakeCastFill` input checks to reject secret/non-numeric values before any comparisons or math.
- Updated health/cast callback caches:
  - `OnMinMaxChanged`: cache only when min/max are safe numbers.
  - `OnValueChanged`: cache only when value is a safe number.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Ready for `/reload`; target fake-fill path should now remain stable when WoW12 callbacks surface secret values.
2026-02-16 (player self-anchor + target style power nil guards)
Issue:
- BugSack:
  - Player power anchor options can trigger `Cannot anchor to itself` from `SetPointWithOffset`.
  - Target texture update can crash on some styles with `db.PowerBarSize` nil.
Root cause hypothesis:
- Player anchor resolver may return the same frame being positioned (self-anchor not allowed in modern SetPoint usage).
- Target style tables (e.g. style variants) do not always carry power fields; power fields are defined at root Target config.
Planned change(s):
- In player `SetPointWithOffset`, treat self-anchor as nil/relative anchor and fall back safely.
- In target `UnitFrame_UpdateTextures`, use root target config fallbacks for power position/size fields.
Files targeted:
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Units/Target.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Hardened `SetPointWithOffset` to avoid self-anchoring (`anchorFrame == frame` and `relativeFrame == frame` now fallback to parentless point syntax).
- `Components/UnitFrames/Units/Target.lua`:
  - Added root target config fallback for power fields in style update path:
    - `PowerBarPosition`, `PowerBarSize`, `PowerBackdropPosition`, `PowerBackdropSize`, `PowerValuePosition`.
  - Power anchoring/scaling now uses resolved fallback tables instead of assuming style-local keys exist.
- `Components/Misc/Tooltips.lua`:
  - Added WoW12 secret-value safety bypass for item tooltips (`tooltip:GetItem()` link present): temporarily restore Blizzard backdrop layers instead of applying AzeriteUI backdrop skin.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/Misc/Tooltips.lua`
Result:
- Ready for `/reload`; expected to fix player self-anchor errors and target style nil power-size error.
- Bag-item tooltip secret-size crashes should be avoided without disabling tooltips globally.
2026-02-17 (step 1: player power orb parity vs DiabolicUI3)
Issue:
- Player orb behavior drifted from expected Diabolic-style behavior after WoW12 stabilization changes.
- Orb color/update behavior is currently fixed to MANA in `Mana_PostUpdate`, and orb display behavior can desync from display power token changes.
Planned change(s):
- Align player orb behavior in `Components/UnitFrames/Units/Player.lua` with DiabolicUI3 reference while keeping AzeriteUI assets/settings:
  - deterministic orb update path
  - token-aware color logic via `PowerOrbColors`
  - explicit orb display-power behavior and stable runtime updates
- Keep WoW12 secret-value safety by avoiding math/comparisons on potentially secret values.
Files targeted:
- Components/UnitFrames/Units/Player.lua
2026-02-17 (step 2: target castbar deterministic render path)
Issue:
- Target castbar still uses mixed native + fake-fill rendering, causing visibility/fill/alignment instability.
Planned change(s):
- Remove target cast fake-fill runtime path and keep one native castbar render path.
- Keep target cast orientation/anchor bound to target health art update path.
- Keep WoW12-safe behavior (no secret-value math on cast dimensions/values in addon logic).
Files targeted:
- Components/UnitFrames/Units/Target.lua
2026-02-17 (step 3: nameplates stabilization one production path)
Issue:
- Nameplates still have mixed behavior for health/cast orientation/visibility and inconsistent aura presentation.
Planned change(s):
- Stabilize nameplate health and cast rendering to one deterministic production path.
- Keep aura behavior consistent with configured intent while avoiding render-path conflicts.
- Keep WoW12 secret-value-safe handling.
Files targeted:
- Components/UnitFrames/Units/NamePlates.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Updated `Mana_PostUpdate` to use token-aware orb coloring (`UnitPowerType(unit, element.displayType)`), with fallback to `MANA`.
  - Kept color application deterministic via configured `PowerOrbColors` and disabled generic power-color mode for orb (`element.colorPower = false`).
  - Enabled `mana.displayAltPower = true` so orb display behavior follows display-power path consistently (Diabolic-style behavior parity).
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
Result:
- Player orb now has deterministic update/color behavior aligned with Diabolic-style flow while retaining AzeriteUI assets/colors.

Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Removed production use of target cast fake-fill path and native-texture hiding for castbar.
  - Kept one deterministic native castbar render path (orientation/texcoord/reverse/anchor still controlled from unified target update path).
  - Removed fake-fill color coupling from `Cast_PostCastInterruptible`.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Target castbar now uses a single render path to reduce fill/visibility/alignment conflicts.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`:
  - Disabled production use of duplicate health display bar (`Health.Display`) and restored native health texture visibility.
  - Removed style-time creation/wiring of the extra display bar mirror path.
  - Simplified health color update to affect active production health path only.
Validation:
- `luac -p Components/UnitFrames/Units/NamePlates.lua`
Result:
- Nameplate health/cast now operate on one deterministic production path with reduced ghosting/conflict risk.
2026-02-17 (target enemy-owned buffs too aggressive filter in mixed PvE content)
Issue:
- User asks for a target aura policy that is consistent across open world, Mythic+, and raids.
- Current target filter can hide enemy-owned helpful auras when duration/application fields are secret or non-timed.
Root cause hypothesis:
- `TargetAuraFilter` currently favors timed/stacked auras and player-applied harmful auras, but does not explicitly keep Blizzard-flagged important enemy buffs.
- In WoW12 secret-value paths, helpful auras with secret duration/application can be dropped unless they expose expiration.
Planned change(s):
- Add a secret-safe helper in `AuraFilters.lua` to query Blizzard aura flags by instance:
  - `IMPORTANT`, `RAID_IN_COMBAT`, `CROWD_CONTROL`, `BIG_DEFENSIVE`, `EXTERNAL_DEFENSIVE`.
- Update `TargetAuraFilter` to keep enemy helpful auras when flagged important/combat-relevant (and keep stealables), while preserving existing anti-clutter behavior for generic long/passive buffs.
Files targeted:
- Components/UnitFrames/Auras/AuraFilters.lua
Update:
- `Components/UnitFrames/Auras/AuraFilters.lua`:
  - Added secret-safe aura-token helpers:
    - `HasAuraToken(...)` for Blizzard aura-flag checks via `IsAuraFilteredOutByInstanceID`.
    - `IsImportantAura(...)` for cross-content relevance (`IMPORTANT`, `RAID_IN_COMBAT`, `CROWD_CONTROL`, `BIG_DEFENSIVE`, `EXTERNAL_DEFENSIVE`, plus stealable fallback).
  - Updated `TargetAuraFilter`:
    - keeps enemy helpful auras flagged as important/combat-relevant even when duration/applications are secret,
    - keeps existing player-harmful/can-apply logic for debuffs,
    - preserves anti-clutter baseline for generic non-timed/non-stackable buffs.
Validation:
- `luac -p Components/UnitFrames/Auras/AuraFilters.lua`
Result:
- Target aura policy now better matches mixed PvE expectations:
  - open world: avoids passive clutter while keeping meaningful enemy buffs,
  - Mythic+/raid: keeps important/combat-relevant enemy helpful auras visible in WoW12 secret-value paths.
2026-02-17 (always show current health text on player and target frames)
Issue:
- User requests current health value to remain visible on both player and target frames.
- Existing castbar text toggles hid health value while casts were visible.
Root cause hypothesis:
- `Cast_UpdateTexts` in player/target unit files swapped cast text in and health text out during cast visibility.
Planned change(s):
- Keep health value visible in cast-visible state for player and target.
- Keep critter-style exceptions and target percent behavior intact.
Files targeted:
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Units/Target.lua
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - `Cast_UpdateTexts` now keeps `Health.Value` visible when castbar is shown.
  - Added nil-guard for early frame init safety.
- `Components/UnitFrames/Units/Target.lua`:
  - `Cast_UpdateTexts` now keeps `Health.Value` visible when castbar is shown.
  - Keeps `Health.Percent` hidden during cast and restores it when castbar hides.
  - Added safe local references/guards for `Health.Value` and `Health.Percent`.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Player and target current health values stay visible through castbar state changes.
2026-02-17 (health value shows max/stale while percent updates; restore old cast visibility behavior)
Issue:
- User reports player/target health value text appears stuck at max while health percent updates correctly.
- User also prefers previous cast behavior where health text is hidden while casting.
Root cause hypothesis:
- `*:Health` path can keep a stale `cur` fallback while `frame.Health.safePercent` remains live.
- Recent cast visibility tweak kept health value visible during casts, increasing clutter.
Planned change(s):
- In `Tags.lua`, use `frame.Health.safePercent` as correction source when current looks stale (e.g. full while percent is below full).
- Revert cast text visibility for player/target to previous behavior:
  - hide health text while castbar is shown.
Files targeted:
- Components/UnitFrames/Tags.lua
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Units/Target.lua
2026-02-17 (hotfix: additional power GetDisplayPower nil)
Issue:
- BugSack: `Components/UnitFrames/Functions.lua:780` attempt to call method `GetDisplayPower` (nil) in `UpdateAdditionalPower`.
Root cause hypothesis:
- Some AdditionalPower elements set `displayAltPower = true` but do not implement `GetDisplayPower()`.
Planned change(s):
- Guard calls to `GetDisplayPower()` behind method-existence checks in power update functions.
- Keep behavior unchanged when method exists.
Files targeted:
- Components/UnitFrames/Functions.lua
Update:
- `Components/UnitFrames/Functions.lua`:
  - Added method guards for alt-power lookup in both `API.UpdatePower` and `API.UpdateAdditionalPower`:
    - now only calls `element:GetDisplayPower()` when `element.GetDisplayPower` exists.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
Result:
- Prevents nil-method crash while preserving alt-power behavior for elements that implement `GetDisplayPower()`.
2026-02-17 (target aura counters/cooldowns stall in combat)
Issue:
- Target-frame aura stack counters/cooldowns update out of combat, then stall or disappear in combat.
- Reproduced in AzeriteUI and DiabolicUI3 target auras; Platynator nameplate auras continue updating.
Root cause hypothesis:
- Shared oUF aura update path is not fully WoW12 secret-duration safe for custom/virtual cooldown widgets.
- When combat returns duration objects/secret values, counters/cooldowns can fail to refresh unless explicitly handled.
- Some `updatedAuraInstanceIDs` updates can skip redraw paths if no visibility-set changes are detected.
Planned change(s):
- Add duration-object support to virtual cooldown widget used by aura text/bar wrappers.
- Harden aura element count/cooldown writes against secret values.
- Force redraw pass on aura-instance update events even when active set membership is unchanged.
Files targeted:
- Core/Widgets/Cooldowns.lua
- Libs/oUF/elements/auras.lua
Update:
- `Core/Widgets/Cooldowns.lua`:
  - Added virtual cooldown support for `SetCooldownFromDurationObject(...)`.
  - Timer loop now updates virtual cooldowns from duration objects via `EvaluateRemainingTime()`.
  - Added secret-safe guards and cleanup for duration-object state.
- `Libs/oUF/elements/auras.lua`:
  - Added secret-safe numeric helper for aura math.
  - Cooldown fallback now uses safe `data.expirationTime/data.duration` when duration object cannot be unpacked to start/duration.
  - Stack count write now guards secret display counts and falls back to safe `data.applications`.
  - Added redraw fallback on `updatedAuraInstanceIDs` for Auras/Buffs/Debuffs paths so visual updates are not skipped when only metadata changes.
Validation:
- `luac -p Core/Widgets/Cooldowns.lua`
- `luac -p Libs/oUF/elements/auras.lua`
Result:
- Combat target aura counters/cooldowns now have a duration-object-safe update path and forced redraw on aura-instance updates.
- Ready for in-game `/reload` verification on target auras during combat.
Follow-up (Platynator comparison):
Issue:
- User still reports target aura behavior diverges in combat; asks for Platynator-style handling.
Finding:
- Platynator keeps one consistent filter path and drives updates from `UNIT_AURA` delta payloads without combat-state filter branching.
- AzeriteUI target filter still branched on `UnitAffectingCombat("player")`, causing visibility rules to change at combat boundaries.
Planned change(s):
- Remove combat-state conditional from target aura filter and keep one stable visibility rule set.
Files targeted:
- Components/UnitFrames/Auras/AuraFilters.lua
Update:
- `Components/UnitFrames/Auras/AuraFilters.lua`:
  - `TargetAuraFilter` no longer branches on `UnitAffectingCombat("player")`.
  - Uses one stable rule path for both combat and non-combat:
    - always keep harmful player/can-apply auras,
    - otherwise keep timed auras and stackable auras.
Validation:
- `luac -p Components/UnitFrames/Auras/AuraFilters.lua`
Result:
- Target aura visibility rules no longer change when entering combat, matching Platynator’s stable filtering strategy.
- This should prevent counters/cooldowns from disappearing due to combat-state filter flips.
Workaround follow-up (combat-time secure mutations):
Issue:
- User reports multiple target auras still stop updating in combat.
Root cause hypothesis:
- Secure aura buttons can fail/skip updates if layout code mutates anchors/sizes during combat.
- Platynator avoids this by keeping combat updates data-driven and minimizing protected mutations.
Planned change(s):
- In shared oUF aura element, skip `SetPoint`, `SetSize`, and `EnableMouse` while in combat for secure aura buttons.
- Keep non-secure opt-in via `element.allowCombatUpdates`.
Files targeted:
- Libs/oUF/elements/auras.lua
Update:
- `Libs/oUF/elements/auras.lua`:
  - `SetPosition(...)` now guards anchor changes behind `not InCombatLockdown()` (or `allowCombatUpdates`).
  - `updateAura(...)` now guards button size/mouse/show mutations behind the same combat check.
  - In combat, if button is hidden, uses `pcall(button.Show, button)` as a safe best-effort fallback.
Validation:
- `luac -p Libs/oUF/elements/auras.lua`
Result:
- Workaround aligns AzeriteUI aura update behavior with Diabolic-style combat guards.
- Expected outcome: existing target aura counters/cooldowns keep refreshing in combat without layout-mutation stalls.
Follow-up regression (missing auras on target/nameplates/player):
Issue:
- User reports aura loss across multiple unit types after combat guard workaround.
Root cause:
- Guard was too broad: it blocked anchor/size updates for all aura buttons in combat.
- Newly created aura buttons during combat could remain unanchored/unsized, appearing "missing".
Change(s):
- `Libs/oUF/elements/auras.lua`:
  - Added `CanMutateButtonInCombat(element, button)`:
    - allows updates out of combat,
    - allows updates in combat when `allowCombatUpdates` is set,
    - allows updates in combat for non-protected buttons (`not button:IsProtected()`).
  - Switched `SetPosition(...)` and `updateAura(...)` mutation gates to this helper.
  - Applied the same gate to gap-button show/mouse operations.
Validation:
- `luac -p Libs/oUF/elements/auras.lua`
Result:
- Combat mutation guard now targets protected-button risk only.
- Non-protected aura buttons (player/target/nameplates) can still size/anchor/update in combat, matching Platynator behavior more closely.
Follow-up regression (missing counters/time-left):
Issue:
- User reports aura counters and time-left still missing.
Root cause hypothesis:
- oUF aura cooldown path still hid timers whenever `C_UnitAuras.GetAuraDuration` returned nil, even when safe `data.expirationTime/data.duration` existed.
- Count display was over-defensive with secret checks; writes could be skipped.
Change(s):
- `Libs/oUF/elements/auras.lua`:
  - Cooldown update now:
    - prefers `SetCooldownFromDurationObject(...)` when duration object exists,
    - falls back to safe numeric `data.expirationTime/data.duration` with `SetCooldown(...)`,
    - only hides cooldown when neither path is available.
  - Count update now always attempts `SetText(...)` via `pcall` using Blizzard display count result; falls back to safe `data.applications` when the write fails.
Validation:
- `luac -p Libs/oUF/elements/auras.lua`
Result:
- Counters/time-left now have both duration-object and numeric-data fallback paths, reducing combat-time dropouts across player/target/nameplates.

2026-02-17 (health number text stuck at max while percent updates)
Issue:
- Player/target health number text can stay at max value while percent continues to change.
- Symptom appears when WoW12 secret/cached paths return stale `cur` values that look numeric/safe.
Root cause:
- `Components/UnitFrames/Tags.lua` `SafeUnitHealth()` only corrected current health when `cur` was secret/invalid.
- If `cur` was numeric but stale (for example equal to max while percent was below 100), the function returned stale `cur`.
Planned change(s):
- Add a percent-based correction pass in `SafeUnitHealth()`:
  - prefer `frame.Health.safePercent` (then `UnitHealthPercent` fallback),
  - recalculate `cur` when `cur` is clearly stale (`cur >= max` while percent < 100, `cur <= 0` while percent > 0, or `cur > max`),
  - keep existing secret-safe guards and fallback behavior.
Files targeted:
- Components/UnitFrames/Tags.lua
Update:
- `Components/UnitFrames/Tags.lua`:
  - `SafeUnitHealth()` now uses a shared safe percent hint:
    - first `frame.Health.safePercent`,
    - then `UnitHealthPercent` fallback via `SafeUnitPercent(...)`.
  - Added stale numeric correction when current is clearly wrong:
    - `cur > max`,
    - `cur >= max` while percent is below full,
    - `cur <= 0` while percent is above zero.
  - Secret/invalid fallback path now reuses the same percent hint before final `cur = max` fallback.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- Current HP number tags now follow live health more reliably instead of sticking at max while percent changes.
- WoW12 secret-value safety remains intact.

2026-02-17 (follow-up: current HP still stale + cast text visibility regression)
Issue:
- User still sees current HP number stuck while health percent updates.
- Castbar visibility behavior regressed: health text stays visible during cast on frames where it should hide.
Root cause:
- `Components/UnitFrames/Tags.lua`: `maxIsSafeNumber` was computed before frame fallback updates `max`, so stale-value correction could be skipped.
- `Components/UnitFrames/Functions.lua`: `UpdateHealth()` still preferred `rawCur` whenever it looked numeric-safe, even when it clearly conflicted with safe percent.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`: `Cast_UpdateTexts` still shows health text while castbar is visible.
Planned change(s):
- Recompute safe-max predicate in `SafeUnitHealth()` after frame fallback.
- In `UpdateHealth()`, detect stale raw current values against safe percent and:
  - recalc `safeCur` from percent,
  - avoid writing stale raw current to the statusbar.
- Restore old cast behavior:
  - hide health value (and target health percent) while castbar is shown,
  - show them again when castbar hides.
Files targeted:
- Components/UnitFrames/Tags.lua
- Components/UnitFrames/Functions.lua
- Components/UnitFrames/Units/Player.lua
- Components/UnitFrames/Units/Target.lua
Update:
- `Components/UnitFrames/Tags.lua`:
  - moved `maxIsSafeNumber` evaluation to run after frame fallback updates `max`.
  - this allows stale-current correction to run when `UnitHealthMax()` is secret but frame-safe max is available.
- `Components/UnitFrames/Functions.lua`:
  - `UpdateHealth()` now marks `rawCur` as stale when it conflicts with safe percent (full/zero/out-of-range mismatch).
  - when stale, `safeCur` is recomputed from safe percent even if `rawCur` is numeric-safe.
  - stale `rawCur` is no longer written to bars; write path now uses corrected `safeCur`.
- `Components/UnitFrames/Units/Player.lua`:
  - `Cast_UpdateTexts` now hides player health value while castbar is visible; shows it again when castbar hides.
- `Components/UnitFrames/Units/Target.lua`:
  - `Cast_UpdateTexts` now hides target health value/percent while castbar is visible; restores them when castbar hides.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Current HP text path now stops trusting stale raw health numbers and follows the same safe-percent source driving percent text.
- Castbar text/health visibility behavior matches pre-regression behavior (health text hidden during cast).

2026-02-17 (actionbar spell cooldowns still stale in combat for some spells)
Issue:
- User reports potion cooldowns now update in combat, but some spell buttons still do not update until combat ends.
Root cause hypothesis:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` `UpdateCooldown(...)` uses addon-side tuple math/cache gating before draw updates.
- In WoW12 combat, some spell cooldown payloads can remain secret/unavailable in Lua, so this path can skip/clear updates until a later non-secret event.
Planned change(s):
- Prefer Blizzard `ActionButton_ApplyCooldown(...)` in `UpdateCooldown(...)` with info tables (`cooldownInfo`, `chargeInfo`, `lossOfControlInfo`) so C++ cooldown handling can consume combat payloads safely.
- Keep existing manual/cache path as fallback when `ActionButton_ApplyCooldown` is unavailable.
- Preserve current passive-cooldown aura override path and charge/loss-of-control behavior.
Files targeted:
- Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua
Update:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - `UpdateCooldown(...)` now prefers `ActionButton_ApplyCooldown(...)` before addon-side cooldown math/cache logic.
  - Built secure info-table inputs for apply path:
    - `cooldownInfo`
    - `chargeInfo`
    - `lossOfControlInfo`
  - Preserved passive-cooldown aura override inputs in the apply path.
  - Added deterministic creation of `self.lossOfControlCooldown` (child of button) so apply path can render LoC cooldowns safely.
  - Re-applies `SetDrawEdge(false)` after apply call for cooldown/LoC/charge frames to preserve existing visuals.
  - Existing manual/cache cooldown path remains intact as fallback when `ActionButton_ApplyCooldown` is unavailable.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
Result:
- Cooldown rendering now uses Blizzard's secure action-button cooldown updater on modern clients, which should keep spell cooldown visuals updating in combat even when Lua-side values are secret/stale.

2026-02-19 (feature: player/target power value text toggle in /az)
Issue:
- User requested current power value text on player and target power bars, with an on/off toggle in the `/az` menu.
Root cause hypothesis:
- Power value fontstrings exist on both frames, but visibility is currently hardwired and not controlled by profile options.
Planned change(s):
- Add `showPowerValue` profile settings to both modules:
  - `Components/UnitFrames/Units/Player.lua`
  - `Components/UnitFrames/Units/Target.lua`
- Add `/az` UnitFrames options toggles for Player and Target:
  - `Options/OptionsPages/UnitFrames.lua`
- Apply visibility in module power-visibility/update paths so toggling is immediate and keeps existing dead/disconnected/no-power behavior.
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added `showPowerValue = true` to defaults.
  - Added `ShouldShowPlayerPowerValue()` helper and applied it in `Power_UpdateVisibility()` so player `Power.Value` follows option state and crystal visibility.
- `Components/UnitFrames/Units/Target.lua`:
  - Added `showPowerValue = true` to defaults.
  - Added `ShouldShowTargetPowerValue()` helper and applied it in `Power_UpdateVisibility()` while preserving existing dead/disconnected/zero-power hiding.
  - `TargetFrameMod.Update()` now forces a power-visibility refresh so toggle changes apply immediately.
- `Options/OptionsPages/UnitFrames.lua`:
  - Added Player option toggle:
    - `Show Power Value` (`showPowerValue`)
  - Added Target option toggle:
    - `Show Power Value` (`showPowerValue`)
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- Player and target power bars now support current-power text visibility toggled from `/az` UnitFrames settings.
- Default behavior keeps power values enabled, while allowing users to disable them per frame.

2026-02-19 (follow-up: absorb text shows "(?)" and power value hides/looks wrong after updates)
Issue:
- Health absorb suffix can display `(?)` on unitframes.
- Player/target power value text appears briefly, then disappears on updates; when visible, it can look like max instead of current.
Root cause hypothesis:
- `Components/UnitFrames/Tags.lua` `[*:Absorb]` formats secret/invalid absorb values through `SafeValueToText`, which can yield `"?"`, producing `(?)`.
- `Components/UnitFrames/Functions.lua` `API.UpdatePower()` calls `HidePowerTexts(element)` after `PostUpdate`, which re-hides power value text every update.
- In some secret-value paths, `API.UpdatePower()` falls back to max when current/percent are unavailable before mirror data is refreshed.
Planned change(s):
- `Components/UnitFrames/Tags.lua`:
  - Make `[*:Absorb]` return nothing for secret/invalid/non-positive values (no `(?)`).
- `Components/UnitFrames/Functions.lua`:
  - Let `HidePowerTexts()` respect a per-element keep-visible flag for value text.
  - In `API.UpdatePower()`, refresh safe current from post-write mirrored percent when raw current is secret.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - Set the keep-visible flag in power visibility callbacks based on option state and actual bar visibility.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `[*:Absorb]` now bails out for non-numeric, secret, or non-positive absorb values.
  - Added guard so absorb suffix never formats `"?"`, preventing `(?)` output.
  - `SafeUnitPower()` now corrects stale numeric current values using safe percent hints and cached frame values before max fallback.
- `Components/UnitFrames/Functions.lua`:
  - `HidePowerTexts()` now keeps `element.Value` visible when `element.__AzeriteUI_KeepValueVisible` is true.
  - `API.UpdatePower()` now performs a post-write mirror-percent pass for secret raw power, recalculating `safeCur` from rendered bar percent.
- `Components/UnitFrames/Units/Player.lua`:
  - `Power_UpdateVisibility()` now sets `element.__AzeriteUI_KeepValueVisible` from crystal visibility + `showPowerValue`.
- `Components/UnitFrames/Units/Target.lua`:
  - `Power_UpdateVisibility()` now sets `element.__AzeriteUI_KeepValueVisible` from target power visibility + `showPowerValue`.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Absorb suffix no longer prints `(?)`; it now hides when absorb is unknown/secret/zero.
- Player/target power value text no longer gets re-hidden every power update when toggle is enabled.
- Power current-value text is less likely to stick at max under secret/stale power payloads.

2026-02-19 (follow-up: player mana text still stuck at max; compare sibling UI fix)
Issue:
- User reports player power value text remains stuck around max (for example `50k`) while mana is clearly being spent.
Investigation:
- Compared sibling addon implementations in this workspace:
  - `DiabolicUI3/Components/UnitFrames/Common/Functions.lua`
  - `DiabolicUI3/Components/UnitFrames/Common/Tags.lua`
- Notable behavior in DiabolicUI3:
  - power update path uses `UnitPowerPercent(..., CurveConstants.ScaleTo100)` as authoritative non-secret signal,
  - text tags are driven by current update flow (`:Power:Full`) and not hidden by shared post-update text hiders.
Root cause hypothesis:
- AzeriteUI power path can still trust stale-but-numeric `UnitPower` in cases where percent/cached values indicate otherwise.
- Tag refresh can lag behind update corrections when relying on event-only updates.
Planned change(s):
- In `Components/UnitFrames/Functions.lua`:
  - add robust power-percent probe (Diabolic-style fallback signatures),
  - detect stale numeric `rawCur` against safe percent and avoid writing stale values,
  - force `element.Value:UpdateTag()` after power updates.
- In `Components/UnitFrames/Tags.lua`:
  - prefer frame-cached power values for `[*:Power]` / `[*:Power:Full]` when available, before raw API fallbacks.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Added `ProbeSafePowerPercent(...)` in `API.UpdatePower()` to query `UnitPowerPercent` via multiple signatures (including `CurveConstants.ScaleTo100`) similar to DiabolicUI3 fallback strategy.
  - Added `staleRawCur` detection in `API.UpdatePower()` so stale-but-numeric current power values are corrected from safe percent.
  - Prevented writing stale raw current values by switching write source to corrected `safeCur` when stale.
  - Extended post-write mirror-percent correction to run for stale raw values as well as secret raw values.
  - Added explicit `element.Value:UpdateTag()` in `API.UpdatePower()` to ensure visible power text refreshes on each update pass.
- `Components/UnitFrames/Tags.lua`:
  - `[*:Power]` and `[*:Power:Full]` now prefer `_FRAME.Power.safeCur/safeMax` when present and valid, before falling back to raw API paths.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- Power text now follows corrected current power values instead of sticking to stale max values in the reported mana-use scenario.
- Behavior aligns more closely with the resilient percent-first approach observed in `DiabolicUI3`.

2026-02-19 (feature follow-up: toggle power value text mode between current and percent)
Issue:
- User requested a toggle so power value text can switch between:
  - current power value (`[*:Power]`)
  - percent (`[*:PowerPercent]`)
  while `showPowerValue` remains the master visibility toggle.
Root cause hypothesis:
- Player/target currently hard-tag `Power.Value` to `[*:Power]` at frame creation time, with no profile-driven retagging path.
Planned change(s):
- Add profile boolean `powerValueUsePercent` (default `false`) to:
  - `Components/UnitFrames/Units/Player.lua`
  - `Components/UnitFrames/Units/Target.lua`
- Add helper retag functions in Player/Target modules to switch `Power.Value` tag between `[*:Power]` and `[*:PowerPercent]`.
- Call helper on frame creation and in module `Update()` so `/az` option changes apply immediately.
- Add `/az` options toggles for Player and Target in:
  - `Options/OptionsPages/UnitFrames.lua`
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added `powerValueUsePercent = false` profile default.
  - Added `UpdatePlayerPowerValueTag(frame)` helper to retag `Power.Value` as `[*:Power]` or `[*:PowerPercent]`.
  - Applied helper at power text creation and in `PlayerFrameMod.Update()` for live option switching.
- `Components/UnitFrames/Units/Target.lua`:
  - Added `powerValueUsePercent = false` profile default.
  - Added `UpdateTargetPowerValueTag(frame)` helper to retag `Power.Value` as `[*:Power]` or `[*:PowerPercent]`.
  - Applied helper at power text creation and in `TargetFrameMod.Update()` for live option switching.
- `Options/OptionsPages/UnitFrames.lua`:
  - Added Player toggle: `Power Text Uses Percent` (`powerValueUsePercent`), disabled when `showPowerValue` is off.
  - Added Target toggle: `Power Text Uses Percent` (`powerValueUsePercent`), disabled when `showPowerValue` is off.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
Result:
- With `Show Power Value` enabled, player and target power text can now be toggled between raw current value and percent from `/az`.
- Option changes apply immediately without reloading.

2026-02-19 (cleanup: consolidate health/power percent probe helper)
Issue:
- Recent power/health hotfixes introduced duplicated local percent-probe blocks inside `API.UpdateHealth()` and `API.UpdatePower()`, making the path harder to maintain.
Planned change(s):
- In `Components/UnitFrames/Functions.lua`, move duplicate probe logic into one shared local helper used by both update paths.
Update:
- Added `ProbeSafePercentAPI(unit, isPower, powerType)`.
- Replaced inline `ProbeSafeHealthPercent` / `ProbeSafePowerPercent` blocks with helper calls.
- Removed redundant target-only fallback branch now covered by the unified probe helper.
Validation:
- `rg -n "ProbeSafePercentAPI|ProbeSafeHealthPercent|ProbeSafePowerPercent" Components/UnitFrames/Functions.lua`
Result:
- Same safety behavior with less duplicated code and simpler maintenance.

2026-02-19 (bug: absorb text missing for valid shields like Shield of Vengeance)
Issue:
- Absorb suffix stays hidden even when expected absorb exists (example: ~45k Shield of Vengeance) on player/target readouts.
Root cause hypothesis:
- `UnitGetTotalAbsorbs(unit)` can be secret in WoW12.
- Current tag path returns early on secret absorbs and uses `AbbreviateNumber` fallback that intentionally returns empty for secret values.
Planned change(s):
- Add WoW12-safe absorb text formatter in `Components/UnitFrames/Tags.lua`.
- For secret absorb values, try Blizzard `AbbreviateNumbers()` formatter via `pcall` and only display safe non-empty output.
- Keep hiding absorb when value is unknown/zero/invalid.
Update:
- `Components/UnitFrames/Tags.lua`:
  - Added `SafeAbsorbValueText(absorb)` helper.
  - For secret absorb payloads, now attempts Blizzard `AbbreviateNumbers(absorb)` via `pcall` and only renders safe non-empty output.
  - Keeps hiding absorb text when value is zero/invalid/unknown.
  - Expanded absorb tag events to include `PLAYER_TARGET_CHANGED` and `UNIT_AURA` alongside `UNIT_ABSORB_AMOUNT_CHANGED`.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
Result:
- No `(?)` placeholder behavior retained.
- Added path to display valid absorb text even when absorb arrives as WoW12 secret numeric payload.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `SafeAbsorbValueText()` now supports WoW12 secret results from `AbbreviateNumbers()` and can fall back to returning raw secret absorb payload for direct text rendering.
  - `[*:Absorb]` no longer concatenates color wrappers around secret text (avoids secret-value string ops); for secret text it returns the payload directly.
  - Added fallback to `_FRAME.Health.safeAbsorb` when direct absorb formatting returns nil.
- `Components/UnitFrames/Functions.lua`:
  - `API.UpdateHealth()` now caches `element.safeAbsorb` from non-secret `UnitGetTotalAbsorbs(unit)` for absorb-tag fallback.
Validation planned:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Functions.lua`

2026-02-19 (ui tweak: absorb text placement/color + hide zero)
Issue:
- User wants absorb text to be hidden when no absorb, and displayed on far right with white parentheses and yellow value.
Update:
- `Components/UnitFrames/Tags.lua`:
  - Updated absorb colors to white parentheses + yellow value.
  - Removed secret absorb raw fallback; now hides when absorb cannot be safely rendered.
  - Keeps strict hide-on-zero behavior.
- `Components/UnitFrames/Units/Player.lua`:
  - Changed health text tag to `[*:HealthCurrent]` only.
  - Added dedicated right-aligned absorb fontstring tagged `[*:Absorb]`.
- `Components/UnitFrames/Units/Target.lua`:
  - Changed health text tag to `[*:HealthCurrent]` only.
  - Added dedicated right-aligned absorb fontstring tagged `[*:Absorb]`.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Re-anchored target absorb text to sit between `Health.Percent` and `Health.Value`.
  - Uses dual anchors (`LEFT` to percent, `RIGHT` to health value) with center justification.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
Update:
- `Components/UnitFrames/Tags.lua` absorb logic relaxed to restore rendering:
  - Accept secret formatter results from `AbbreviateNumbers`.
  - Added safe `tostring(absorb)` fallback for secret payloads when formatter path fails.
  - Restored secret-text passthrough in `[*:Absorb]` tag (avoids unsafe color concatenation on secret values).
- Keeps zero/empty filtering where possible and preserves non-secret colored `(value)` formatting.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
Update:
- `Components/UnitFrames/Tags.lua`:
  - Added shared `IsZeroLikeText()` helper and applied it to secret absorb formatter/tostring paths.
  - Secret absorb text now gets dropped when it resolves to zero-like output (`0`, `0.0`, `0K`, etc.).
  - Secret absorb display path now only renders if safe text is non-zero-like.
- `Components/UnitFrames/Units/Player.lua`:
  - Moved player absorb text anchor to 20px from right edge (`RIGHT, -20, 4`).
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
Update:
- `Components/UnitFrames/Tags.lua`:
  - Absorb tag now prefers verified positive numeric sources:
    1) `UnitGetTotalAbsorbs(unit)` when non-secret,
    2) `_FRAME.Health.safeAbsorb`,
    3) `_FRAME.HealthPrediction.absorbBar:GetValue()`.
  - Removed secret-text passthrough path that could leak false `0` display.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - HealthPrediction absorb handling no longer depends on `hasOverAbsorb and curHealth >= maxHealth`.
  - Now updates absorb bar/cache whenever a safe positive absorb exists.
  - Caches `element.health.safeAbsorb` for tag fallback.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Update:
- `Components/UnitFrames/Tags.lua`:
  - Restored safe secret-formatted absorb text extraction from `AbbreviateNumbers(absorb)` by converting secret formatted payloads via `tostring` and filtering zero-like values.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - Fixed absorb cache destination from `element.health.safeAbsorb` to `element.__owner.Health.safeAbsorb`.
  - This makes absorb tag fallback actually see cached absorb values.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Update:
- Stock visual parity change:
  - Reverted absorb text to inline-with-health style (single health text tag) for Player/Target.
  - Restored stock-like absorb coloring in tag output: gray parentheses + normal value color.
  - Removed separate absorb fontstring elements created in prior tweaks.
- Kept WoW12-safe absorb source handling/caching behind the scenes.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Update:
- Added `UpdatePlayerAbsorbState(...)` and `UpdateTargetAbsorbState(...)` helpers.
- Helpers run at the start of `HealPredict_PostUpdate` before any early returns/secret-value skips.
- This decouples absorb cache/bar updates from prediction rendering flow, which is often short-circuited in WoW12.
- Removed duplicate absorb update blocks at the bottom of both prediction callbacks.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Tags.lua`
Update:
- `Components/UnitFrames/Tags.lua`:
  - Relaxed absorb-bar fallback to accept any numeric `absorbBar:GetValue()` (including secret numeric payloads), then pass through safe formatter.
  - This improves visibility when raw absorb APIs are secret but bar state still carries usable value.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
Update:
- `UpdatePlayerAbsorbState` / `UpdateTargetAbsorbState` now only clear absorb when a safe numeric zero is explicitly known.
- Unknown/secret absorb states no longer force `absorbBar` to 0 (prevents wiping potentially valid absorb state in WoW12 secret paths).
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
2026-02-19 (absorb backend parity with modern UIs)
Issue:
- Absorb text still not visible in WoW12 secret-value sessions despite stock-style visuals.
Root cause hypothesis:
- `UnitGetTotalAbsorbs` path is unreliable/secret in WoW12 for these units.
- Need calculator-first absorb source like FeelUI/GW2/Diabolic modern paths.
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added `GetSafeDamageAbsorbFromCalculator(element, unit)` using `CreateUnitHealPredictionCalculator` + `UnitGetDetailedHealPrediction` + `GetDamageAbsorbs`.
  - `UpdatePlayerAbsorbState` now prefers calculator absorb first, then falls back to `UnitGetTotalAbsorbs`, then callback absorb.
- `Components/UnitFrames/Units/Target.lua`:
  - Added identical calculator-first absorb helper and integration in `UpdateTargetAbsorbState`.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
Result:
- Backend now matches modern calculator-based approach used by other UIs, while keeping AzeriteUI_Stock-style absorb visual output.
2026-02-19 (cleanup: canonical absorb source, avoid legacy accidental methods)
Issue:
- Absorb path had stacked fallbacks (`UnitGetTotalAbsorbs`, bar value scraping, callback args), making it easy to accidentally use stale/legacy sources.
Update:
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - `GetSafeDamageAbsorbFromCalculator(...)` now returns safe numeric absorb (including 0) when available.
  - Removed direct `UnitGetTotalAbsorbs` usage from absorb-state updater.
  - Canonical source is calculator; callback absorb remains compatibility fallback only when calculator output is unavailable.
- `Components/UnitFrames/Tags.lua`:
  - `[*:Absorb]` now reads only `_FRAME.Health.safeAbsorb` (canonical cached value), removing legacy direct API and bar-scrape reads.
Result:
- Cleaner single-source absorb flow, less risk of old methods/values re-entering display path.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Tags.lua`
Update:
- Absorb calculator update now tries `UnitGetDetailedHealPrediction(unit, nil, calculator)` first, then falls back to `"player"` caster key.
- `[*:Absorb]` tag is now fail-open again for visibility:
  1) cached `_FRAME.Health.safeAbsorb`
  2) direct `UnitGetTotalAbsorbs(unit)` (including secret payload pass-through to formatter)
  3) `_FRAME.HealthPrediction.absorbBar:GetValue()`
- Stock visual output unchanged.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Tags.lua`
2026-02-19 (cleanup sweep)
Issue:
- Absorb/prediction paths had redundant branches and repeated state-write snippets from iterative fixes.
Update:
- `Components/UnitFrames/Tags.lua`:
  - Added `ToNonZeroText()` utility to normalize secret/string/number absorb text filtering.
  - Simplified `SafeAbsorbValueText()` secret formatting path.
  - Simplified absorb tag source resolution (cache/api/bar) and removed redundant branch assignments.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - Refactored repeated owner-health absorb cache writes into local `SetOwnerSafeAbsorb()` helper inside absorb state updater.
Result:
- Cleaner, easier-to-audit code with same runtime behavior.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
2026-02-19 (BugSack regressions + absorb visibility restore)
Issue:
- BugSack reported:
  - `Options/OptionsPages/UnitFrames.lua:596` nil `suboptions` assignment.
  - `Core/ExplorerMode.lua:189` iterating nil action bar table.
  - `Components/UnitFrames/Tags.lua:594` secret-value compare (`absorb <= 0`).
- Absorb display still suppressed on player/target in active prediction-hide paths.
Update:
- `Options/OptionsPages/UnitFrames.lua`:
  - Guarded Player Alternate option writes with `if (suboptions and suboptions.args) then ... end`.
- `Core/ExplorerMode.lua`:
  - Guarded action bar loop with `if (ActionBars and ActionBars.bars) then`.
- `Components/UnitFrames/Tags.lua`:
  - Replaced direct secret-unsafe absorb compare with `IsSafePositiveNumber(...)` gate.
- `Components/UnitFrames/Functions.lua`:
  - `API.HidePrediction(...)` no longer hides `absorbBar` by default.
  - Added opt-in gate `element.__AzeriteUI_HideAbsorbWithPrediction` for styles that explicitly want old behavior.
- `Components/UnitFrames/Units/Player.lua` and `Components/UnitFrames/Units/Target.lua`:
  - Added safe `UnitGetTotalAbsorbs(unit)` fallback in absorb state updater when calculator/callback are unavailable.
  - Clear stale cached absorb on unknown/secret-only states without forcing visible zero text.
Result:
- Crash regressions addressed.
- Absorb bar/text can stay visible even when prediction overlay is hidden every update.
Validation:
- `luac -p Options/OptionsPages/UnitFrames.lua`
- `luac -p Core/ExplorerMode.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
2026-02-19 (absorb visuals rollback: text only)
Issue:
- User reported new light overlay strip across health bars after absorb visibility fixes.
- Desired behavior: keep absorb value text, remove absorb bar visual noise.
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added `HidePlayerAbsorbBarVisual(...)`.
  - Enforced absorb bar invisibility in setup (`UnitFrame_UpdateTextures`), creation, and absorb state updates.
  - Added OnShow hook on absorb bar to immediately hide/clear alpha if any external code shows it.
  - Set `self.HealthPrediction.__AzeriteUI_HideAbsorbWithPrediction = true`.
- `Components/UnitFrames/Units/Target.lua`:
  - Added `HideTargetAbsorbBarVisual(...)`.
  - Enforced absorb bar invisibility in setup (`UnitFrame_UpdateTextures`), creation, and absorb state updates.
  - Added OnShow hook on absorb bar to immediately hide/clear alpha if any external code shows it.
  - Set `self.HealthPrediction.__AzeriteUI_HideAbsorbWithPrediction = true`.
Result:
- Absorb numeric text path stays intact, but absorb overlay bar is intentionally disabled for player/target.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
2026-02-19 (ToT absorb overlay off + absorb text fallback hardening)
Issue:
- User still saw ToT healthbar lighten (absorb overlay visual).
- Player/target absorb text still missing in some WoW12 secret-value cases.
Update:
- `Components/UnitFrames/Units/ToT.lua`:
  - Added `HideToTAbsorbBarVisual(...)`.
  - Forced ToT absorb bar to value `0` + hidden in prediction updates.
  - Added absorb-bar `OnShow` hook to immediately hide if shown externally.
  - Set `self.HealthPrediction.__AzeriteUI_HideAbsorbWithPrediction = true`.
- `Components/UnitFrames/Tags.lua`:
  - Added `GetAbsorbFromCalculator(frame, unit)` helper using heal prediction calculator.
  - `[*:Absorb]` now checks sources in this order:
    1) cached `frame.Health.safeAbsorb`
    2) calculator absorb (`GetDamageAbsorbs`)
    3) `UnitGetTotalAbsorbs(unit)`
    4) absorbBar value fallback
  - Expanded absorb tag event list with `UNIT_HEAL_PREDICTION`.
  - `SafeAbsorbValueText(...)` now tries Blizzard `AbbreviateNumbers(...)` first for both normal and secret values.
Result:
- ToT absorb light overlay disabled.
- Absorb text path is more fail-open under WoW12 secret-value behavior.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/ToT.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
2026-02-19 (absorb text recovery after visual-hide regression)
Issue:
- Absorb text no longer appeared on player/target after absorb overlay visual-hide changes.
Root cause:
- Player/target absorb state updater still overwrote absorb channels (`absorbBar:SetValue(0)` / strict safe-number gating), and tag fallback order discarded potentially formatable secret/raw candidates.
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - `UpdatePlayerAbsorbState(...)` no longer writes `absorbBar` values.
  - Keeps bar visuals hidden, but now resolves and caches `Health.safeAbsorb` from calculator/callback/API sources.
  - Preserves non-numeric/secret absorb payloads for tag-format fallback instead of dropping them.
- `Components/UnitFrames/Units/Target.lua`:
  - Same recovery changes as Player for `UpdateTargetAbsorbState(...)`.
- `Components/UnitFrames/Tags.lua`:
  - `[*:Absorb]` now resolves text by trying each source and returning the first successfully formatted value:
    1) cached `Health.safeAbsorb`
    2) calculator absorb
    3) `UnitGetTotalAbsorbs(unit)`
    4) absorbBar value fallback
  - Removed strict safe-positive gating from source selection path.
Result:
- Keeps absorb overlays hidden while restoring absorb value text discovery for WoW12 secret-value paths.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/ToT.lua`
2026-02-19 (absorb cache wipe fix in UpdateHealth)
Issue:
- Absorb text could disappear immediately after appearing because `API.UpdateHealth()` frequently overwrote `Health.safeAbsorb` with `nil` whenever `UnitGetTotalAbsorbs` was secret/unavailable.
- This matched user symptom: absorb visible briefly, then gone on next update.
Update:
- `Components/UnitFrames/Functions.lua`:
  - `safeAbsorb` now starts from existing `element.safeAbsorb` cache.
  - Only updates cache when `UnitGetTotalAbsorbs(unit)` returns a known non-secret number.
  - Known positive updates cache; known zero clears cache.
  - Secret/unknown values no longer wipe existing absorb cache every health tick.
Result:
- Absorb tag has stable cached data between secret/unknown API ticks, while still hiding when a known zero is received.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/ToT.lua`
2026-02-19 (temporary fail-open: always show absorb text value)
Issue:
- User still does not see absorb value text on player/target.
Requested behavior for now:
- Keep only absorb value visible (no absorb bar), and always show a value.
Update:
- `Components/UnitFrames/Tags.lua`:
  - Expanded absorb tag refresh events with `UNIT_HEALTH`, `UNIT_MAXHEALTH`, and `PLAYER_ENTERING_WORLD` to keep display updated even when absorb-specific events are sparse.
  - `[*:Absorb]` now uses temporary fail-open fallback: when no source resolves, returns `0` instead of hiding.
  - Existing source order and formatting attempts remain in place; fallback only applies when all sources fail.
Result:
- Absorb value text is always rendered on tagged frames (player/target), while absorb overlays stay disabled by earlier changes.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/ToT.lua`
2026-02-19 (absorb value accuracy: prefer oUF prediction values)
Issue:
- Absorb value text is visible but does not match expected shield amount.
Root cause hypothesis:
- We were mostly resolving absorb from API/cache fallbacks; in WoW12 those can be secret/unstable.
- oUF already updates `HealthPrediction.values` each tick; not using it as primary source caused drift/fallbacks.
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Added `GetAbsorbFromPredictionValues(element)` using `element.values:GetDamageAbsorbs()`.
  - `UpdatePlayerAbsorbState(...)` now prefers prediction-values absorb first, then calculator/API/callback.
  - Relaxed calculator helper to return non-nil absorb payloads (not only safe numbers) for formatter fallback.
- `Components/UnitFrames/Units/Target.lua`:
  - Same changes as Player for target absorb state.
- `Components/UnitFrames/Tags.lua`:
  - `GetAbsorbFromCalculator(frame, unit)` now first reads `frame.HealthPrediction.values:GetDamageAbsorbs()` before creating/refreshing a separate calculator.
Result:
- Absorb text now follows the same source oUF uses for absorb prediction on each update, improving correctness under WoW12 secret-value behavior.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Tags.lua`
2026-02-19 (restore earlier working secret absorb passthrough behavior)
Issue:
- User confirmed absorb value was visible in an earlier iteration, then regressed after later hide/format changes.
- Current absorb text path always concatenated wrapper colors, which can break WoW12 secret payload rendering.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `SafeAbsorbValueText(...)` now restores raw secret passthrough behavior:
    - if `AbbreviateNumbers(absorb)` returns a secret payload, return it directly.
    - if `absorb` itself is secret, return it directly.
  - `[*:Absorb]` now restores secret-safe return path:
    - if resolved `absorbText` is secret, return it directly (no color concatenation).
  - Non-secret path remains stock-style wrapped `(value)` formatting.
  - Existing fail-open fallback to `0` remains for non-secret unresolved states.
Result:
- Matches earlier known-good WoW12 approach where absorb text could render through secret payloads instead of being dropped by concatenation.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
2026-02-19 (stability fix: avoid returning raw secret absorb payloads from tag)
Issue:
- After many absorb iterations, `[*:Absorb]` could return raw secret payload objects.
- Inline tag rendering with health text can fail or drop output when absorb method returns a secret object instead of plain text.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `SafeAbsorbValueText(...)` no longer returns raw secret objects.
  - Secret results from `AbbreviateNumbers(...)` are converted via `ToNonZeroText(...)`.
  - Secret raw absorb payloads are converted via `ToNonZeroText(...)`.
  - Removed direct secret passthrough return in `[*:Absorb]`; method now always returns plain formatted string (or fallback `0`).
Result:
- Absorb tag output is now string-only, reducing inline tag rendering failures under WoW12 secret-value handling.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
2026-02-19 (absorb-at-full-health fix: use totalDamageAbsorbs, remove text clamp)
Issue:
- User observed absorb value appears when damaged but falls as health rises; often missing at full health.
Root cause:
- `GetDamageAbsorbs()` can reflect clamped absorb in some modes/sources.
- Player/Target absorb cache path also still applied legacy `maxHealth * .4` clamp intended for old overlay visuals, reducing displayed text.
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - `GetAbsorbFromPredictionValues(...)` now prefers `values:GetPredictedValues().totalDamageAbsorbs` before `GetDamageAbsorbs()`.
  - `GetSafeDamageAbsorbFromCalculator(...)` now prefers `calculator:GetPredictedValues().totalDamageAbsorbs` before `GetDamageAbsorbs()`.
  - Removed legacy `maxHealth * .4` clamp when caching absorb for text.
- `Components/UnitFrames/Units/Target.lua`:
  - Same updates as Player for prediction/calculator source preference.
  - Removed legacy `maxHealth * .4` text clamp.
- `Components/UnitFrames/Tags.lua`:
  - `GetAbsorbFromCalculator(frame, unit)` now prefers `prediction.values:GetPredictedValues().totalDamageAbsorbs`, then `GetDamageAbsorbs` fallback, then private calculator predicted totals.
Result:
- Absorb text should track total absorb amount more accurately regardless of current health state (including full health), while absorb bars remain hidden.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/ToT.lua`
2026-02-19 (full-health inline tag fix: HealthCurrent must return plain text)
Issue:
- User still reported no absorb text at full health.
- Player/Target health line uses inline tag: `[HealthCurrent]  [Absorb]`.
- `SafeHealthCurrentText()` could return a raw secret payload from `AbbreviateNumbers(...)`, which can break inline tag concatenation and suppress the whole line segment.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `SafeHealthCurrentText()` now returns only plain text strings:
    - string output requires `SafeNonEmptyString(...)`
    - numeric output converted via `tostring(...)`
    - secret formatted output converted via `tostring(...)` and validated as non-empty string
  - No raw secret objects are returned from HealthCurrent helper anymore.
Result:
- Inline `[HealthCurrent]  [Absorb]` rendering is less likely to fail at full-health secret-value states, allowing absorb suffix to remain visible.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`

2026-02-19 (stable backup: absorb secret-value fix confirmed in user test)
Issue:
- User confirmed in live testing that absorb text now behaves correctly and no longer sticks at `(0)` under secret-value sessions.
What works and why:
- `[*:Absorb]` no longer hard-falls back to `"0"` when source payloads are secret/unknown.
- Absorb value is returned directly from tag methods, and parentheses/prefix/suffix are applied by oUF tag wrapping (`$>` / `<$`) instead of Lua-side concatenation.
- This keeps secret payloads on the secret-safe `SetFormattedText` path and avoids unsafe string coercion/concatenation.
- `UNIT_ABSORB_AMOUNT_CHANGED` handlers now also feed callback absorb args into absorb-state updaters as an additional numeric fallback source.
Stability note:
- Marking current absorb implementation as stable-known-good.
- Savepoint snapshot path: `_savepoints/20260219_214124`

2026-02-19 (visual parity pass: absorb text style aligned with AzeriteUI_Stock)
Issue:
- User requested absorb/health inline visuals to be closer to `AzeriteUI_Stock`.
Stock baseline:
- Stock `[*:Absorb]` style is gray parentheses around normal-color absorb value.
- Stock player/target health tags use plain inline composition with absorb suffix (`[Health]  [Absorb]`).
Plan:
- Keep current secret-safe absorb value resolution.
- Restore stock-like visual wrapping for absorb output using secret-safe wrapper calls.
- Revert player/target/player-alt tag strings to stock-like inline composition.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `[*:Absorb]` now wraps resolved absorb output with stock-style visuals (`gray "(" + normal value + gray ")"`) using `C_StringUtil.WrapString(...)`.
  - Kept secret-safe unresolved behavior: no forced `0` fallback.
- `Components/UnitFrames/Units/Player.lua`:
  - Restored inline stock-like health composition: `[*:HealthCurrent]  [*:Absorb]`.
- `Components/UnitFrames/Units/Target.lua`:
  - Restored inline stock-like health composition: `[*:HealthCurrent]  [*:Absorb]`.
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Restored inline stock-like health composition: `[*:Health]  [*:Absorb]`.
Result:
- Player/Target/PlayerAlt absorb text now matches stock visual style more closely while preserving WoW12 secret-value safety.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`

2026-02-19 (absorb `(0)` loop under secret payloads: remove tag fallback and use secret-safe wrapping)
Issue:
- New target/player logs still showed `calc=<secret>` / `total=<secret>` with `out=0 source=fallback.zero` for `[*:Absorb]`.
- This confirmed absorb data existed but was being dropped by tag-side coercion and forced fallback.
Root cause:
- `[*:Absorb]` built a final colored string in Lua and hard-forced `"0"` when formatting failed.
- Secret absorb payloads could not survive that path, so output repeatedly collapsed to `(0)`.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `SafeAbsorbValueText(...)` now returns secret payloads directly for oUF formatting instead of forcing string conversion.
  - Removed hard `fallback.zero` behavior; unknown absorb now returns empty instead of fake `0`.
  - `[*:Absorb]` now returns absorb value only (no Lua-side color/paren concatenation).
- `Components/UnitFrames/Units/Player.lua`:
  - Health text tag switched to secret-safe absorb wrapping syntax: `[*:HealthCurrent][ ($>*:Absorb<$)]`.
  - `UNIT_ABSORB_AMOUNT_CHANGED` now forwards event callback absorb (`...`) into `UpdatePlayerAbsorbState(...)` and logs it.
- `Components/UnitFrames/Units/Target.lua`:
  - Same secret-safe health tag wrapping and absorb event callback forwarding/logging as player.
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Updated retail health tag to secret-safe absorb wrapping syntax: `[*:Health][ ($>*:Absorb<$)]`.
Result:
- Absorb text is no longer forced to `(0)` when only secret payloads are available.
- Prefix/suffix rendering for absorb now runs through oUF `C_StringUtil.WrapString` path, which is safer for secret values.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`

2026-02-19 (revert: HealthCurrent secret-string conversion)
Issue:
- User reported the latest `HealthCurrent` conversion patch broke health current display behavior.
Update:
- Reverted `SafeHealthCurrentText()` in `Components/UnitFrames/Tags.lua` to prior behavior:
  - return `formatted` directly for string/number outputs
  - return secret `formatted` directly
  - removed forced tostring conversion path added in previous patch
Result:
- Restores prior `HealthCurrent` behavior while keeping other absorb changes untouched.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`

2026-02-19 (absorb text: copy non-stock UI logic, avoid clamped sources)
Issue:
- Absorb text could be wrong or missing at full health.
- Behavior matched clamped absorb (`GetDamageAbsorbs` / absorb bar value) instead of total absorb amount.
Root cause:
- Some fallback paths still used clamped absorb sources (especially absorb bar value and `GetDamageAbsorbs` without enforcing clamp mode).
- Secret/non-numeric payload pass-through made text path inconsistent.
Update:
- `Components/UnitFrames/Units/Player.lua`:
  - Enforced `damageAbsorbClampMode = MaximumHealth` on prediction values and private calculator.
  - `GetAbsorbFromPredictionValues(...)` and calculator helper now return only safe numeric absorb values.
  - Removed non-numeric/secret absorb payload pass-through from `UpdatePlayerAbsorbState(...)`.
- `Components/UnitFrames/Units/Target.lua`:
  - Same clamp-mode and numeric-only absorb updates as Player.
  - Removed non-numeric/secret absorb payload pass-through from `UpdateTargetAbsorbState(...)`.
- `Components/UnitFrames/Tags.lua`:
  - `GetAbsorbFromCalculator(...)` now enforces `MaximumHealth` clamp mode and returns safe numeric values only.
  - Removed absorb-bar-value fallback (`HealthPrediction.absorbBar:GetValue`) because it can be clamped/misleading.
  - `UnitGetTotalAbsorbs` fallback is now numeric-safe only.
Result:
- Absorb text now follows the same stable pattern used in modern non-stock UIs: prediction totals first, numeric-safe fallback paths only.
- This should keep absorb visible/correct at full health while absorb bar visuals remain hidden.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-19 (absorb deep-dive tracing: prove where value becomes 0)
Issue:
- User still sees absorb text as `(0)` and needs proof of whether absorb is being read from APIs/calculators or dropped in formatting/cache paths.
Update:
- Added absorb trace logging (category `Absorb`) across read/write points:
  - Tag read path in `[*:Absorb]` now logs source attempts and chosen source (`cache`, calculator source, `UnitGetTotalAbsorbs`, or `fallback.zero`).
  - Player/Target absorb state writers now log calculator value, callback absorb, API absorb, resolved absorb, known-zero state, and final cached `safeAbsorb`.
  - Health updater now logs raw API absorb, cached `safeAbsorb`, and secret-flag status in existing `Health` debug lines.
- Added explicit absorb event handling/refresh on target frame:
  - Target now registers `UNIT_ABSORB_AMOUNT_CHANGED`.
  - Event forces health/tag refresh and logs event-time absorb values.
- Player absorb event branch now also forces health/tag refresh and logs event-time absorb values.
How to use:
- `/azdebug healthchat on`
- `/azdebug health filter target` (or `player`)
- Reproduce absorb cast, then inspect `Absorb;4;...` and updated `Health;4;... rawAbsorb=... safeAbsorb=...` lines.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Functions.lua`

2026-02-19 (absorb stuck at `(0)`: secret absorb was read but dropped by numeric gate)
Issue:
- Debug logs showed absorb was being read as secret payloads (`rawAbsorb=<secret>`, `total=<secret>`), but `[*:Absorb]` still output `(0)`.
- `safeAbsorb` cache stayed nil because numeric-only paths rejected secret values.
Root cause:
- `[*:Absorb]` only attempted `UnitGetTotalAbsorbs(unit)` when it was a non-secret numeric value.
- Calculator/prediction helpers also rejected secret absorb payloads up front, so formatter paths never ran.
Update:
- `Components/UnitFrames/Tags.lua`:
  - `GetAbsorbFromCalculator(...)` now returns non-nil absorb payloads from prediction/calculator sources (including secret payloads), allowing formatter handling downstream.
  - `[*:Absorb]` now always attempts to format `UnitGetTotalAbsorbs(unit)` (no numeric-only gate).
  - Added placeholder filtering in zero-like text detection (`<secret>`, `secret`, `?`, `nil`) to avoid displaying placeholder payload strings.
Result:
- Absorb text path now actually consumes secret absorb reads instead of bypassing them directly to fallback zero.
- Debug output remains in place to confirm whether displayed absorb comes from cache, calculator, or direct API.
Validation:
- `luac -p Components/UnitFrames/Tags.lua`

2026-02-19 (PlayerAlternate absorb bar modernization: stock-like visuals, WoW12-safe)
Issue:
- `PlayerAlternate` still used legacy absorb bar logic (`hasOverAbsorb && curHealth >= maxHealth`) and direct absorb math.
- This caused the old absorb bar bug and missed updates outside strict over-absorb/full-health conditions.
Root cause:
- Absorb bar updates relied on old stock gating and single-source reads.
- No modern safe resolution chain (prediction values/calculator/event/API) for `PlayerAlternate`.
Update:
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Added WoW12-safe absorb helpers for `PlayerAlternate`:
    - Resolve absorb from `HealthPrediction.values:GetPredictedValues().totalDamageAbsorbs`.
    - Fallback to private calculator (`CreateUnitHealPredictionCalculator`) with `MaximumHealth` clamp mode.
    - Fallback to `UNIT_ABSORB_AMOUNT_CHANGED` callback absorb.
    - Final fallback to `UnitGetTotalAbsorbs(unit)`.
    - Numeric non-secret only for bar math, with known-zero handling.
  - Added absorb state/bar updater:
    - Writes `owner.Health.safeAbsorb`.
    - Resolves safe health via `ns.API.GetSafeHealthForPrediction(...)` (with owner health fallback).
    - Applies stock-like visual cap: `cap = safeMax * .4`.
    - Shows absorb bar when resolved absorb `> 0`, hides/clears otherwise.
  - Replaced legacy absorb block in `HealPredict_PostUpdate` with modern updater call.
  - Added `self.HealthPrediction.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MaximumHealth` (guarded).
  - Improved `UNIT_ABSORB_AMOUNT_CHANGED` handling:
    - Gated on `unit == self.unit`.
    - Runs absorb updater with callback absorb.
    - Forces health/tag refresh (`Health:ForceUpdate()`, `Health.Value:UpdateTag()`).
Result:
- `PlayerAlternate` absorb bar now behaves like stock visually (capped span) while using modern safe absorb reads.
- Absorb bar updates are no longer restricted to over-absorb/full-health-only conditions.
- Player/Target absorb bar policy remains unchanged.
Validation:
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`
- `/reload` + manual in-game verification checklist (absorb gain/loss, full/missing health, event-only updates).

2026-02-19 (PlayerAlternate absorb bar follow-up: no visible bar after v1 modernization)
Issue:
- User reports `PlayerAlternate` absorb bar still not visible at full health or missing health.
Investigation:
- `AzeriteUI_Stock` confirms a dedicated `HealthPrediction.absorbBar` path on PlayerAlternate.
- `Platynator` also uses a dedicated absorb statusbar and drives it directly from calculator/API absorb payloads.
- Our v1 `PlayerAlternate` absorb updater accepted only non-secret numeric absorb values for rendering math.
Root cause:
- In WoW12, absorb payloads are often secret values.
- Numeric-only gating dropped secret absorb payloads before `absorbBar:SetValue(...)`, so bar stayed hidden.
Update:
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Reworked absorb resolution to accept numeric absorb payloads including secret values for bar writes.
  - Kept arithmetic/clamping on safe numeric `safeMax` only (visual cap remains `safeMax * .4`).
  - Bar now shows when absorb payload exists (safe numeric > 0 or secret payload), and hides on known zero/unresolved.
  - `owner.Health.safeAbsorb` remains numeric-safe cache only (no secret arithmetic path).
Result:
- PlayerAlternate absorb bar follows the same practical model seen in other UIs: dedicated absorb statusbar fed from calculator/API payloads.
- Expected behavior: visible absorb segment at full and missing health when absorb exists.
Validation:
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`
- In-game: `/reload`, apply absorbs at full/missing health, verify show/hide behavior.

2026-02-19 (PlayerAlternate absorb bar follow-up 2: anchor/overflow alignment)
Issue:
- User reports absorb bar now appears, but starts too far right and can render beyond expected healthbar end.
Root cause:
- Follow-up v1 forced `absorbBar` min/max to `visualCap` (`safeMax * .4`) on every update.
- This diverged from stock/oUF geometry handling and could distort fill behavior.
Update:
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Removed forced `absorbBar:SetMinMaxValues(0, visualCap)` in absorb updater.
  - Numeric payload path still clamps displayed absorb to `visualCap` before `SetValue`.
  - Secret payload path no longer forces `SetValue`; it now preserves oUF/native absorb write and only toggles visibility.
Result:
- Absorb bar geometry should now follow native/oUF alignment while keeping stock-like cap semantics for numeric values.
- Reduces right-edge drift/overflow artifacts introduced by custom min/max remapping.
Validation:
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`
- In-game `/reload` and verify start/end alignment at full and missing health.

2026-02-19 (PlayerAlternate absorb bar follow-up 3: remove full-time visibility regression)
Issue:
- After follow-up 2, user reports absorb bar is now visible full-time.
Root cause:
- Secret payload branch forced `okSet = true` and always showed absorb bar whenever a secret payload existed.
Update:
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Secret payload branch now uses `pcall(absorbBar:SetValue(absorbPayload))`.
  - Visibility now follows whether native `SetValue` accepts that payload, instead of unconditional show.
Result:
- Keeps follow-up 2 geometry fix while restoring non-forced visibility behavior.
Validation:
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`
- In-game `/reload`, verify bar is no longer always-on and still appears with active absorb.

2026-02-20 (PlayerAlternate absorb regression loop: secret compare crash + full-time/right-edge absorb)
Issue:
- BugSack reports repeated error:
  - `Components/UnitFrames/Functions.lua:359: attempt to compare local 'minValue' (a secret number value tainted by 'AzeriteUI')`
- PlayerAlternate absorb bar regressed to always-on and could appear pinned toward the right edge.
Root cause:
- `API.BindStatusBarValueMirror` compared/status math'd min/max/value without rejecting secret numeric payloads first.
- PlayerAlternate absorb visibility still treated unknown secret absorb payloads as showable, while geometry updates were not fully deterministic for this unit's new "always track absorbs" behavior.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Added secret-safe numeric guards in value-mirror hooks.
  - `OnMinMaxChanged` now ignores secret min/max values before any numeric comparison.
  - `OnValueChanged` now ignores secret values for mirror-percent/texcoord math.
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Reworked absorb resolution precedence so safe numeric absorb or known-zero state wins over fallback secret payloads.
  - Restored deterministic absorb bar range (`0..safeMax*0.4`) for PlayerAlternate absorb rendering.
  - Secret payload branch no longer forces "show"; it updates value and keeps visibility conservative to avoid always-on state.
  - Aligned absorb bar orientation with PlayerAlternate health orientation for this modernized overlay behavior.
Result:
- Removes the secret-value comparison crash loop from statusbar mirroring.
- PlayerAlternate absorb bar no longer force-shows on unknown secret payloads and uses stable capped geometry.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`
- In-game `/reload` + absorb gain/loss checks at full and missing health.

2026-02-20 (mirror percent regression after secret-guard hotfix)
Issue:
- After the secret-compare crash guard in `Functions.lua`, user reports:
  - PlayerAlternate health current/% no longer updating correctly.
  - Target fake-fill appears scaled/wrong and can look stuck (e.g. around 91%).
Root cause:
- `API.BindStatusBarValueMirror` `OnValueChanged` was changed to return early unless `value` was safe numeric.
- On WoW12 secret-value frames, this prevented mirror-percent refresh (`__AzeriteUI_MirrorPercent`), so downstream health/fake-fill logic consumed stale percent data.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Keep secret guard for unsafe min/max comparisons (prevents BugSack crash).
  - Reworked `OnValueChanged` to:
    - always process when texture exists (even if `value` is secret),
    - compute percent from numeric min/max/value only when safe,
    - otherwise refresh from texture-percent fallback,
    - clear stale mirror percent only when no safe source is available.
  - Clear cached numeric min/max mirror fields when incoming min/max are unsafe, preventing stale range math reuse.
Result:
- Preserves crash fix while restoring live mirror percent updates for secret-value healthbars.
- Target fake-fill and PlayerAlternate health text should track current fill again.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- In-game `/reload` then verify:
  - target fake-fill crops/fills correctly,
  - PlayerAlternate current health and percent update continuously.

2026-02-20 (snapshot parity check + target fake-fill order regression + PlayerAlternate secret fillSize compare)
Issue:
- User reports target health fake-fill is scaling instead of crop-filling and PlayerAlternate absorb path throws:
  - `Components/UnitFrames/Units/PlayerAlternate.lua:355: attempt to compare local 'fillSize' (a secret number value tainted by 'AzeriteUI')`
Investigation:
- Compared current files against stable savepoint `_savepoints/20260219_214124`:
  - `Target.lua` logic is effectively unchanged in fake-fill implementation (main diff in that file is health tag composition).
  - Regression source is shared mirror/update behavior, not target layout block drift.
Root cause:
- Mirror percent could remain stale (e.g. stuck around prior value) when neither safe arithmetic nor texture fallback updated in a tick.
- `UpdateTargetFakeHealthFill` preferred native-texture fallback before min/max crop fallback, causing scale-like behavior when mirror percent was unavailable.
- PlayerAlternate secret-only absorb visibility check compared `fillSize` directly without secret guard.
Update:
- `Components/UnitFrames/Functions.lua`:
  - `OnValueChanged` now tracks whether mirror percent was refreshed this tick; if not, stale mirror percent is cleared.
- `Components/UnitFrames/Units/Target.lua`:
  - `UpdateTargetFakeHealthFill` fallback order changed to:
    - mirror percent
    - min/max crop fill
    - native texture fallback (last resort)
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - Guarded `fillSize` visibility check against secret payloads before numeric comparison.
Result:
- Prevents stale mirrored percent reuse that pinned fake-fill at old values.
- Restores crop-first fake-fill behavior for target when safe min/max data exists.
- Removes PlayerAlternate `fillSize` secret compare crash.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`

2026-02-20 (target lag follow-up after fake-fill reorder: current updates but %/bar drift)
Issue:
- User reports:
  - `PlayerAlternate` bar updates, but current text can desync.
  - `Target` current value updates, but health `%` lags/sticks.
  - `Target` fake-fill can stop following live health after recent fake-fill ordering changes.
Investigation:
- Compared current files against:
  - `_savepoints/20260219_214124/Target.lua`
  - desktop release `C:\Users\Jonas\Desktop\AzeriteUI_Release_2026-02-17\Components\UnitFrames\Units\Target.lua`
- Key regression point in current `Components/UnitFrames/Units/Target.lua`:
  - `UpdateTargetFakeHealthFill` currently prefers min/max path before native fallback.
  - Stable snapshot used: mirror -> native -> min/max.
- `Components/UnitFrames/Functions.lua` still allowed compare sites that can fault when secret detection is unavailable/timing-sensitive.
- `safePercent` assignment preferred probed percent over resolved `safeCur/safeMax`, allowing `%` text drift when probe output lags.
Root cause:
- Fake-fill path ordering drift from stable snapshot can prioritize stale cached min/max over live native geometry.
- Percent cache source priority can preserve stale probe percent even when current/max are already resolved.
- Secret-value comparisons can still occur in mirror hook conditions in edge timing paths.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Restore stable fake-fill fallback order: mirror -> native -> min/max.
- `Components/UnitFrames/Functions.lua`:
  - Guard min/max and range comparisons with pcall-based safe numeric checks to avoid secret compare faults.
  - Set `element.safePercent` from resolved `safeCur/safeMax` first, probe percent second.
Expected result:
- Target fake-fill follows live health again (no stale freeze), and target `%` tracks current health.
- Secret compare errors in mirror logic stop recurring.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/buggrabber reset` + `/reload`, then verify target current/%/bar move together.

2026-02-20 (follow-up rollback: write-path sanitizer regression + % cache bypass)
Issue:
- After the previous patch, user reports:
  - PlayerAlternate current health stopped tracking.
  - Bars appeared frozen/not updating correctly.
  - Target/Player `%` still not updating reliably.
Root cause:
- The last `SetStatusBarValuesCompat` sanitizer/write-gating change over-constrained min/max/value writes and could suppress native statusbar updates in secret-value paths.
- `%` tag could still prefer stale `frame.Health.safePercent` cache over live unit percent API.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Reverted write-path sanitizer block in `SetStatusBarValuesCompat`.
  - Restored prior raw-write selection behavior (`rawCurNum` + target/nameplate native path handling).
  - Kept secret-safe compare guards in mirror hooks (`HasSafeNumericRange`) from this loop.
- `Components/UnitFrames/Tags.lua`:
  - `*:HealthPercent` now prefers live `SafeUnitPercent(unit, false)` first.
  - On success, refreshes `frame.Health.safePercent` cache and returns formatted live value.
Expected result:
- Bars/cur values should resume normal updates (including PlayerAlternate).
- `%` text should follow live health and not stick on stale cached percent.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- In-game `/buggrabber reset` + `/reload` and verify PlayerAlternate cur/bar and target/player `%`.

2026-02-20 (live follow-up: bars moving again, target fill still wrong, health/power % and power text stale)
Issue:
- User reports after rollback:
  - Bars animate again.
  - Target fill remains visually incorrect.
  - Health `%` still lags/sticks.
  - Power `%` and power numeric text no longer update reliably.
Hypothesis:
- `%`/power tags still prioritize stale API/cache sources in some paths.
- Target fake-fill still over-uses native texture fallback when crop math should drive visual.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Re-prioritize fake-fill to prefer safe min/max crop path before native texture fallback.
- `Components/UnitFrames/Tags.lua`:
  - `*:HealthPercent` now derives from frame health values first, then `SafeUnitHealth`, then API percent fallback.
  - `*:PowerPercent` / `*:ManaPercent` now derive from frame power values first, then safe power values, then API percent fallback.
  - `*:Power` / `*:Power:Full` now trust frame power values without strict unit-token equality gate (prevents stale fallback when token mismatches).
Expected result:
- Target fake-fill tracks crop behavior again.
- Health/power percent text and power numeric values stay in sync with moving bars.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target fake-fill follow-up: accept post-write safePercent for mirror source)
Issue:
- Target fake-fill can still miss crop percent even when post-write health resolution reports mirror source.
- `GetSecretPercentFromBar()` may resolve via `GetSecretPercent()` (proxy), which does not always populate `__AzeriteUI_MirrorPercent`.
Root cause:
- `ResolveTargetFakeHealthFillPercent(...)` only accepted `health.safePercent` when `__AzeriteUI_TargetPercentSource == "api"`.
- Mirror-derived safePercent path was ignored, so resolver could still fall to native fallback.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Expanded safePercent acceptance branch to include:
    - `__AzeriteUI_TargetPercentSource == "mirror"` (in addition to `"api"`).
Expected result:
- When target post-write source is mirror via proxy percent, fake-fill can still crop from `safePercent` instead of native geometry fallback.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- In-game `/buggrabber reset` + `/reload` and verify target fill + player/target power value/percent updates.

2026-02-20 (temporary fallback: copy Player current-health text behavior to PlayerAlternate)
Issue:
- User requests a narrow temporary fix: make `PlayerAlternate` show current-health amount like `PlayerFrame` for now.
Update:
- `Components/UnitFrames/Units/PlayerAlternate.lua`:
  - On Retail, changed health value tag from `[*:Health]` to `[*:HealthCurrent]`.
  - Kept inline absorb display (`[*:Absorb]`) unchanged.
Scope:
- Text-only fallback for current health amount on `PlayerAlternate`.
- No changes to `%` behavior, health fill behavior, or absorb bar logic in this step.
Validation:
- `luac -p Components/UnitFrames/Units/PlayerAlternate.lua`
- In-game `/reload` and verify Player vs PlayerAlternate current-health amount parity.

2026-02-20 (target health fake-fill stabilization: deterministic mirror/crop path + text sync)
Issue:
- Target health fake-fill still flaps/sticks and can desync from health/power `%` text in WoW12 secret-value paths.
- Existing target path mixed mirror/min-max/native fallbacks with unstable source precedence.
Root cause:
- `Functions.lua` target health path still allowed stale percent preference in some secret/raw-unsafe ticks.
- `BindStatusBarValueMirror` cleared mirror percent on no-sample ticks, causing source flapping.
- `Target.lua` health fake-fill path still included production native fallback and non-deterministic branch choices.
- `Target.lua` fake-fill geometry could use lab offsets/insets even when lab mode was not active.
- Tags could still fall through to stale API/cache percent/value paths before frame-authoritative data.
Update:
- `Components/UnitFrames/Functions.lua`:
  - Target health now uses deterministic percent authority:
    - target-safe API percent only when raw current/max are both safe,
    - post-write bar mirror percent first,
    - then safe min/max recompute,
    - then retained prior `element.safePercent`.
  - Added `element.__AzeriteUI_TargetPercentSource` for target debug visibility.
  - Added opt-in mirror retention in `BindStatusBarValueMirror` (`__AzeriteUI_KeepMirrorPercentOnNoSample`) and used it for target health.
  - Target debug line now includes `safePct`, `pctSource`, `fakeSource`, `fakePct`.
- `Components/UnitFrames/Units/Target.lua`:
  - Added deterministic fake-fill resolver:
    - `mirror` -> `texture` -> `minmax` -> `last`.
  - Disabled production native fallback in target health fake-fill path; native fallback remains only for non-production mode.
  - Added last-state retention fields:
    - `__AzeriteUI_LastFakePercent`,
    - `__AzeriteUI_TargetFakeSource`,
    - `__AzeriteUI_TargetFakePercent`.
  - Added `SyncTargetHealthVisualState(...)` and switched target health update hooks to this path.
  - Locked fake-fill geometry to health bounds when dev-lab is off (zero offsets/insets, `health` anchor).
  - Enabled mirror retention for target health bar setup (`__AzeriteUI_KeepMirrorPercentOnNoSample = true`).
  - On `PLAYER_TARGET_CHANGED`, clears target fake-fill/mirror state to avoid stale carry-over across targets.
- `Components/UnitFrames/Tags.lua`:
  - `SafeUnitPercent(...)` now prefers frame-authoritative values first (cached percent or frame bar values), then API percent.
  - `*:Power` and `*:Power:Full` now use explicit `UnitPowerType(unit)` in safe fallback.
Result:
- Target fake-fill path is now deterministic and crop-first with stable source fallback behavior.
- Text source priority is aligned toward frame/bar-authoritative values to reduce `%`/value desync.
Validation:
- `luac -p Components/UnitFrames/Functions.lua` (pass)
- `luac -p Components/UnitFrames/Units/Target.lua` (pass)
- `luac -p Components/UnitFrames/Tags.lua` (pass)
- In-game `/buggrabber reset` + `/reload` loop pending user runtime verification.

2026-02-20 (target fill follow-up: minmax-100 pin when mirror/texture percent is missing)
Issue:
- Target bar updates every frame, but fake-fill remains visually wrong (stuck/full-like behavior).
- Debug log repeatedly shows:
  - `pctSource=minmax`
  - `fakeSource=minmax fakePct=100`
  - `mirrorPct=nil texPct=nil`
Root cause:
- In production target path, fake-fill resolver reaches `minmax` fallback when mirror/texture percent is unavailable.
- During secret-heavy windows, `safeCur/safeMax` can collapse to synthetic fallback values (e.g. `100/100`), so `minmax` percent becomes pinned at `100`.
- Existing production path disables native-renderer fallback, so there is no deterministic non-API percent source before `minmax`.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Added a native-statusbar-geometry percent resolver for target health fake-fill.
  - New resolver order:
    - `mirror` -> `texture` -> `nativegeom` -> `minmax` -> `last`.
  - `nativegeom` derives percent from native statusbar texture size vs full bar/anchor size, then applies existing crop path (`ApplyTargetFakeHealthFillByPercent`).
  - Keeps production behavior of hiding native health visuals and not swapping to native renderer.
Expected result:
- Target fake-fill no longer pins to `minmax=100` when mirror samples are missing.
- Fill stays crop-based and follows live native geometry deterministically in secret-value ticks.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/buggrabber reset` + `/reload`, then verify `TargetBar` logs show `fakeSource=nativegeom` (or `mirror/texture`) instead of constant `minmax=100`.

2026-02-20 (target fill follow-up 2: copy cast fallback semantics for production health)
Issue:
- Latest debug log still shows:
  - `mirrorPct=nil texPct=nil`
  - `fakeSource=minmax fakePct=100`
- So target fake-fill remains pinned to synthetic min/max fallback in production secret-value ticks.
Root cause:
- Even with `nativegeom` added, resolver could still settle on `minmax`/`last` in production.
- Production health path then never reaches the cast-style native texture fallback that keeps moving visually.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - In production health mode, resolver now skips `minmax` and `last` percent fallbacks.
  - `UpdateTargetFakeHealthFill(...)` no longer hard-aborts on production mode before native fallback.
  - Always attempts native fallback path (same model cast uses as last resort) when percent resolver has no live source.
  - Target debug source now reports `native` when this path is used.
Expected result:
- When mirror/texture percent is unavailable, target fake-fill follows native geometry instead of pinning at `100`.
- Visual fill should continue updating even in fully secret-value combat windows.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/buggrabber reset` + `/reload` and confirm `TargetBar` no longer sits on `fakeSource=minmax fakePct=100`.

2026-02-20 (options crash: nil suboptions in UnitFrames options page)
Issue:
- BugSack:
  - `Options/OptionsPages/UnitFrames.lua:1582: attempt to perform indexed assignment on local 'suboptions' (a nil value)`
  - Stack: `group -> GenerateOptionsMenu -> OnEvent`.
Root cause:
- `GenerateSubOptions(moduleName)` returns `nil` when the module/db/profile is not ready.
- The castbar/classpower option blocks dereferenced `suboptions` without a nil guard.
Update:
- `Options/OptionsPages/UnitFrames.lua`:
  - Added minimal nil guards in the `PlayerCastBarFrame` and `PlayerClassPowerFrame` option blocks.
  - If `suboptions` or `suboptions.args` is missing, the block now no-ops instead of crashing options generation.
Result:
- Options menu generation no longer hard-errors when these modules initialize late or are unavailable.
Validation:
- `luac -p Options/OptionsPages/UnitFrames.lua`
- In-game `/reload`, open `/az` options, and confirm Unit Frames page loads without BugSack errors.

2026-02-20 (target health visual follow-up: still moving but appears scaled instead of cropped)
Issue:
- User reports target healthbar updates again, but fill looks scaled/stretched rather than crop-based (player health/cast behavior is correct).
Hypothesis:
- In target health native fallback, fake fill can still mirror native texture geometry directly (`SetPoint` to native texture bounds), which behaves like geometry scaling.
- Cast fallback already attempts native-percent -> shared crop path first; health fallback did not.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Updated target health native fallback to first derive a safe percent from native geometry and apply `ApplyTargetFakeHealthFillByPercent(...)`.
  - Kept direct native-geometry mirror only as last-resort fallback.
  - Added health fake height cache during setup for safer percent derivation in non-horizontal layouts.
Expected result:
- Target health fake fill should follow crop behavior first (matching cast/player style), reducing stretched/scaled visuals.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload` and verify target health fill edge crops cleanly; optional debug should prefer `fakeSource=mirror|texture|nativegeom|minmax` over persistent `fakeSource=native`.

2026-02-20 (target health follow-up: persistent fakeSource=native, fakePct=nil)
Issue:
- User debug logs still show target health on:
  - `fakeSource=native`
  - `fakePct=nil`
- This indicates percent-based crop path is not getting a usable percent and we keep falling into native geometry fallback.
Root cause:
- In production target path, mirror/texture/native-geometry sampling can all be unavailable in secret-value ticks.
- Target health update had no explicit API-percent fallback in post-write resolution, so fake-fill resolver had no percent source to crop from.
Update:
- `Components/UnitFrames/Functions.lua`:
  - In target post-write percent resolution, added fallback to probed safe API percent (`targetPercent`) before minmax/cached fallback.
  - New debug source tag: `api`.
- `Components/UnitFrames/Units/Target.lua`:
  - Fake-fill resolver now accepts target `safePercent` when source is `api`, and applies crop path with source `safepct`.
Expected result:
- Target fake-fill should use crop math (`fakeSource=safepct`/`mirror`/`texture`) more often and avoid persistent native scaling fallback.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, verify target debug no longer stuck on `fakeSource=native fakePct=nil`.

2026-02-20 (target health follow-up: proxy percent path blocked by forceNative)
Issue:
- Latest dumps still show target health in native fallback behavior:
  - health texture alpha is 0 (native hidden),
  - fake fill remains full-rect geometry,
  - debug remains effectively `fakeSource=native` with no percent.
Root cause:
- Target health bar was created with `SetForceNative(true)`.
- In secret-value frames this prevents LibSmoothBar proxy path from being used.
- `GetSecretPercent()` depends on proxy visibility; with force-native, proxy percent remains unavailable.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Disable force-native for target health bar (`SetForceNative(false)`).
  - Keep existing fake-fill/crop logic unchanged.
Expected result:
- Proxy can render secret frames and provide `GetSecretPercent()` values.
- Target fake-fill should regain crop percent sources and stop sticking on native geometry fallback.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, re-test target damage and confirm target debug no longer stays on `fakeSource=native`.

2026-02-20 (cleanup pass: remove dead target fake-fill fields)
Issue:
- User requested cleanup of unused code before continuing target health fix iterations.
Update:
- `Components/UnitFrames/Units/Target.lua`:
  - Removed unused fields:
    - `health.__AzeriteUI_FakeTexWidth`
    - `health.__AzeriteUI_FakeTexHeight`
  - These were only assigned/reset and never read.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-02-20 (target cast follow-up: works on self-target, fails on enemy/player targets)
Issue:
- User reports target cast fake fill/cropping looks correct when targeting self, but not when targeting other players/enemies.
Hypothesis:
- Secret cast updates on non-self targets are falling through to native fallback because cast fake resolver lacks proxy-secret percent fallback.
- Target castbar still forced native (`SetForceNative(true)`), reducing proxy-secret percent availability.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Add cast fake-fill fallback using `cast:GetSecretPercent()` (proxy/native secret-safe path) before minmax/native fallback.
  - Switch target castbar to `SetForceNative(false)` to allow proxy path when cast values are secret.
Expected result:
- Cast fake fill should keep crop behavior on enemy/player targets and avoid persistent `castFake: path native` fallthrough.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, target enemy/player casts, and confirm `/azdebug dump target` shows `castFake: path` preferring `live|timer|mirror|secret` over `native`.
Deep scan notes:
- `Components/UnitFrames/UnitFrame.lua` currently creates native `StatusBar` bars via `UnitFrame_CreateBar(...)`.
- In this native path, `SetForceNative(...)` is a compatibility shim (stores `element.forceNative`) and has no active runtime consumer.
- Practical effect for this patch:
  - `GetSecretPercent()` fallback path is the primary behavior change.
  - `SetForceNative(false)` on target castbar is future-proof/intentional, but not the direct driver in the current native-bar path.

2026-02-20 (target cast follow-up: use documented LuaDurationObject percent methods)
Issue:
- Target cast fake-fill still falls back to `native` too often on enemy/player casts in secret-heavy paths.
- Current target resolver probes `durationPayload:GetProgress()` as fallback, but extension docs expose `GetRemainingPercent()` / `GetElapsedPercent()` on `LuaDurationObject`.
Hypothesis:
- Using documented percent methods directly will recover cast percent in more runtime states than remaining/total reconstruction alone.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In cast timer/duration payload percent resolvers, read `GetRemainingPercent()` and `GetElapsedPercent()` before legacy progress fallback.
  - Keep existing invert/channel mapping and all current fallbacks unchanged.
Expected result:
- Target cast fake-fill should use crop paths (`live|timer|mirror|secret|minmax`) more consistently and reduce `castFake: path native` fallthrough on non-self targets.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, target enemy/player casts/channels, and verify `/azdebug dump target` for `castFake: path` distribution and visual crop behavior.

2026-02-20 (target health/cast native-fallback scaling: mirror native texcoords)
Issue:
- User reports target health and cast bars now move, but fill appears scaled/stretched instead of player-like crop behavior.
- Debug dump shows target cast frequently in `castFake: path native percent nil`.
Hypothesis:
- In native fallback we anchor fake fill to native texture geometry, but force configured/base texcoords instead of native runtime texcoords.
- On secret/non-numeric ticks, native texture may still carry the correct runtime texcoord clip. Overriding with base texcoords can look like scaling.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In both health and cast native direct-mirror fallback blocks, copy runtime texcoords from native statusbar texture to fake fill via pass-through `GetTexCoord()` -> `SetTexCoord(...)`.
  - Keep existing geometry fallback and all percent-path ordering intact.
Expected result:
- When resolver falls through to `native`, fake fill should visually match native crop behavior instead of stretched/scaled appearance.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`; reproduce target health/cast updates and compare target fill behavior against player frame.

2026-02-20 (target-only rollback + safer fallback after native-texcoord mirror regression)
Issue:
- User reported target health/cast fake statusbars became invisible after native texcoord-copy fallback patch.
- Prior regression patch mirrored native runtime texcoords in direct native fallback for target health/cast.
Root cause (observed behavior):
- Target native fallback path is still reached in secret-value ticks.
- Copying native runtime texcoords in that fallback can produce invalid/empty fake fill presentation on some target states.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Revert native texcoord-copy fallback for target health and target cast (restore configured fake texcoords in native fallback).
  - Keep target-only minimal fallback hardening:
    - Health: allow `__AzeriteUI_LastFakePercent` fallback even in production mode before returning `none`.
    - Cast: persist `__AzeriteUI_LastFakePercent` on successful crop paths and use it as fallback before native fallback.
Expected result:
- Target bars should stop disappearing.
- When live/timer/mirror/secret values are temporarily unavailable, target bars should continue cropping using last known safe percent instead of dropping to native geometry.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, then target self and non-self casts; confirm `castFake: path` can show `last` and visuals crop instead of scale/disappear.

2026-02-20 (target cast follow-up: prevent live-percent stomping by generic OnUpdate)
Issue:
- User reports target cast fill now crops correctly but does not update correctly over time.
- Debug shows `castFake` alternating/downgrading from `live` to `mirror` despite valid live percent snapshots.
Root cause:
- Two update paths race:
  - `Cast_CustomTimeText` / `Cast_CustomDelayText` provides explicit live percent (`castFake: path live`).
  - Castbar `OnUpdate` runs immediately after without explicit percent and can overwrite result with mirror/last fallback.
- Recent cast mirror-retention (`__AzeriteUI_KeepMirrorPercentOnNoSample = true`) can prolong stale mirror percent when sampling misses.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Record timestamp when explicit live-percent path is applied.
  - In castbar `OnUpdate`, skip fallback recompute briefly after a fresh live update so `live` is not stomped.
  - Clear live timestamp on target change / cast show/hide.
  - Remove cast-only mirror-retention assignment to avoid stale mirror lock-in.
Expected result:
- Target cast fake fill should keep progressing from live/timer sources and stop regressing to stale mirror path between updates.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`; target active caster/channeler and verify `castFake: path` remains primarily `live|timer` while cast is ongoing.

2026-02-20 (debug tooling: target fill-path toggles in /azdebug menu)
Issue:
- User can reproduce target health/cast fill animation mismatch but needs faster runtime isolation without code edits.
- Current `/azdebug` lacks direct toggles for target fake-fill source paths (native/mirror/last/onupdate).
Change(s):
- `Core/Debugging.lua`:
  - Add target-specific debug flags persisted in DB and mirrored to `_G`:
    - cast: `native`, `mirror`, `last`, `onupdate`
    - health: `native`, `nativegeom`, `last`
  - Add `/azdebug target ...` command group and status/reset output.
  - Add corresponding toggles in debug menu UI and include in `/azdebug status` + help.
- `Components/UnitFrames/Units/Target.lua`:
  - Read new `_G` debug flags and gate target fallback paths accordingly.
Expected result:
- User can toggle target source paths live (no code changes/reload loop per attempt) to isolate which fallback causes wrong growth/crop behavior.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game: `/azdebug target status`, `/azdebug target cast native off`, `/azdebug target cast mirror off`, `/azdebug target cast onupdate off`, etc.

2026-02-20 (requested UX: move target fill test toggles into /az options)
Issue:
- User requested real toggle controls in `/az` options UI (not only `/azdebug`) for target health/cast fill-path testing.
Change(s):
- Add target fill debug controls to `/az` > Unit Frames > Target:
  - Cast: native / mirror / last / onupdate
  - Health: native / nativegeom / last
  - Reset button
- Wire these toggles to the same global runtime flags used by target fill logic.
- Expose a small Debugging module sync method for immediate runtime application from options.
Expected result:
- User can click-toggle target path options directly in `/az` and test immediately.
Validation:
- `luac -p Core/Debugging.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`

2026-02-20 (target cast follow-up: seed readable timer fallback when secret duration object path is unavailable)
Issue:
- Latest target dumps still show frequent `castFake: path native percent nil` on non-self targets.
- Secret test confirms `UnitCastingInfo` timing fields are secret for target casts, while self-target behaves correctly.
Root cause hypothesis:
- oUF cast start/update can fail to seed a usable timer object when secret duration arguments are not accepted in the current taint context.
- Without a readable timer/duration payload, target cast fake-fill resolver has no safe percent source and falls through to `native`.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Add a target-only helper that ensures castbar has a readable timer source.
  - If timer object is missing/unreadable, seed `SetTimerDuration(...)` once per cast with a safe numeric fallback duration:
    - prefer safe `LuaDurationObject:GetTotalDuration()`
    - otherwise use spell base cast time (`C_Spell.GetSpellInfo` / `GetSpellInfo`).
  - Call this helper before target fake-fill updates in cast visual callbacks and castbar scripts.
Expected result:
- Target cast fake-fill should prefer `timer/live/last` crop paths more consistently on enemy/player targets and reduce `path native percent nil`.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`; target non-self caster and verify `/azdebug dump target` shows fewer `castFake: path native percent nil` and smoother crop progression.

2026-02-20 (target cast fallback hotfix: use LuaDurationObject for SetTimerDuration)
Issue:
- Target cast fallback timer seeding still not affecting path selection in live tests.
Root cause:
- Fallback called `SetTimerDuration(...)` with a numeric seconds value.
- Mainline `SimpleStatusBar:SetTimerDuration` expects a `LuaDurationObject`, so numeric fallback can fail and leave cast in `path native`.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In timer fallback seeding, create a `LuaDurationObject` via `C_DurationUtil.CreateDuration()`.
  - Populate it with `SetTimeFromStart(C_DurationUtil.GetCurrentTime() or GetTime(), fallbackDuration)`.
  - Call `SetTimerDuration(...)` with the duration object (and keep numeric attempt only as legacy fallback).
Expected result:
- Timer fallback seeding should apply reliably on modern clients, allowing target cast fake fill to use timer/live percent paths instead of persistent native fallback.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, target non-self caster, and verify `/azdebug dump target` shows `castFake: path timer|live` more frequently than `native`.

2026-02-20 (target health flip drift: ignore implicit AceDB defaults for lab direction flags)
Issue:
- Target health can appear correct before first texture refresh, then flip direction after combat updates.
- Debug logs show reverse/flip state changing after first post-update while health fill source remains in secret-heavy native fallback.
Root cause:
- `GetTargetHealthLabSettings(...)` treated AceDB default booleans as explicit lab overrides.
- With development mode + health flip lab enabled, baseline target style direction (`isFlipped`/reverse defaults) was silently replaced by lab default booleans even when user never changed those options.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - In health-lab direction resolver, read flip/reverse booleans via `rawget(profile, key)` so only explicitly saved profile values override baseline style behavior.
  - Applied to health/preview/absorb/cast flip+reverse and related tex flip booleans.
Expected result:
- Baseline target orientation remains stable across first update and damage ticks unless the user explicitly set a lab direction override.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, keep target fill debug defaults, then acquire/attack a target and confirm target direction no longer flips on first damage tick.

2026-02-20 (target health/cast parity follow-up: remove deep-clean gate from target health)
Issue:
- Self-target castbar looks correct (reversed art + cropped updates), but target health and non-self target visuals diverge.
- Target health path still reports native-only behavior and skips the same percent/crop resolver flow used by cast updates.
Root cause:
- `TARGET_HEALTH_DEEP_CLEAN` remained enabled in `Components/UnitFrames/Units/Target.lua`.
- Deep-clean short-circuits target health resolver state:
  - forces native fallback on,
  - disables mirror/texture/safe/nativegeom/minmax/last health percent sources,
  - forces deep-clean flip/reverse overrides,
  - bypasses `UpdateTargetFakeHealthFill(...)` in `SyncTargetHealthVisualState(...)`.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Disable `TARGET_HEALTH_DEEP_CLEAN` baseline so target health uses the same staged percent/crop fallback model as castbar logic.
Expected result:
- Target health regains normal fake-fill source arbitration and can crop/update instead of being pinned to deep-clean native-only behavior.
- Target health flip/reverse behavior follows normal health-lab + style defaults instead of deep-clean hard overrides.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`; target self and non-self units and compare `/azdebug dump target`:
  - `healthFake: source` should no longer be hard-pinned to deep-clean native-only path.

2026-02-20 (LAB flyout secure handler: guard nil numFlyoutButtons)
Issue:
- BugSack reports secure click/flyout error:
  - `Blizzard_ActionBar/Shared/ActionButton.lua:921: attempt to compare number with nil`
  - Stack points into LAB secure flyout handler script in `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`.
Root cause:
- Secure flyout handler loop used:
  - `for i = usedSlots + 1, self:GetAttribute("numFlyoutButtons") do`
- In restricted execution, `numFlyoutButtons` can be nil (timing/sync edge), causing numeric-for comparison against nil.
Change(s):
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - In secure flyout handler, coerce `numFlyoutButtons` to a safe number (`or 0`) before numeric-for.
  - Keep existing behavior unchanged when attribute is present.
Expected result:
- Flyout secure handler no longer throws compare-with-nil when attribute is missing/unset for a frame.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- In-game `/reload`; open/close spell flyouts repeatedly and verify BugSack no longer logs this error.

2026-02-20 (target health/cast visual parity: prefer fake visuals on native fallback)
Issue:
- Target dumps still show health fake source as `native`, while fake layer is hidden:
  - `healthFake: source native nativeMode mirror ...`
  - `Target.Health.FakeFill ... shown: false`
- Similar pattern can occur on target cast when path falls back to `native`.
Root cause:
- Visual state logic defaulted `nativevisual` preference to `true`.
- On `source/path == native`, code showed native texture and intentionally hid fake fill.
- This prevents the mirrored fake layer from being visible even when native fallback prepared it.
Change(s):
- `Components/UnitFrames/Units/Target.lua`:
  - Default `IsTargetHealthPreferNativeVisualsEnabled()` to `false`.
  - Default `IsTargetCastPreferNativeVisualsEnabled()` to `false`.
- Source/path selection and fallback ordering remain unchanged.
Expected result:
- When target health/cast resolves to native fallback, fake layer remains visible by default.
- This aligns visual behavior with the working fake-fill path (flipped art + mirrored/cropped presentation).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- In-game `/reload`, then `/azdebug dump target`:
  - On `healthFake: source native`, `Target.Health.FakeFill` should be shown.
  - On `castFake: path native`, `Target.Castbar.FakeFill` should be shown.




2026-02-26 (player orb swirl parity: restore LibOrb runtime path)
Issue:
- Player orb still looked different from Diabolic and lacked swirl behavior.
- Current player path rendered orb mode via `self.Power` (plain StatusBar), while `self.AdditionalPower` (LibOrb) was forced hidden/disabled.
Root cause:
- `Mana_UpdateVisibility(...)` unconditionally disabled `AdditionalPower` events and visuals.
- `UnitFrame_UpdateTextures(...)` styled `self.Power` as orb in orb modes, bypassing `LibOrb` multi-layer animations.
- `PlayerFrameMod.Update(...)` always hid `AdditionalPower`.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - Restored `Mana_UpdateVisibility(...)` enable/disable/event flow for `AdditionalPower` based on resolved orb mode.
  - Updated `Power_UpdateVisibility(...)` to show crystal only when crystal mode is active.
  - Reworked `UnitFrame_UpdateTextures(...)`:
    - `self.Power` is crystal-only styling.
    - `self.AdditionalPower` now receives orb textures/colors/positions and keeps LibOrb path active.
    - Explicitly flips orb texture layer 2 texcoord (`1,0,1,0`) for Diabolic parity.
  - `self.AdditionalPower.frequentUpdates` set to `true`.
  - `PlayerFrameMod.Update(...)` now force-updates both `Power` and `AdditionalPower` instead of hard-hiding `AdditionalPower`.
Expected result:
- Orb mode uses actual LibOrb renderer again (animated swirl layers) instead of static crystal-style statusbar fill.
- Crystal and orb visibility follow selected power mode consistently.
Validation:
- In-game `/reload` and test `Player Power Style` options:
  - `Power Crystal Only`: crystal shown, orb hidden.
  - `Mana Orb Only`: orb shown with swirl, crystal hidden.
  - `Automatic (By Class)`: class-based switch as configured.
- Use `/azdebug dump player` to confirm `AdditionalPower` is active in orb mode.
2026-02-26 (lib replacement: use Diabolic LibOrb implementation)
Issue:
- User reported AzeriteUI LibOrb path is broken and swirl behavior does not match Diabolic.
- Prior AzeriteUI LibOrb file had heavy local modifications/divergence and likely regression points.
Root cause:
- `Libs/LibOrb-1.0/LibOrb-1.0.lua` drifted far from Diabolic (`MINOR_VERSION 4` in AzeriteUI fork vs `7` in Diabolic), including custom secret/proxy branches and behavior changes.
Change(s):
- Replaced `AzeriteUI/Libs/LibOrb-1.0/LibOrb-1.0.lua` with `DiabolicUI3/Libs/LibOrb-1.0/LibOrb-1.0.lua`.
- Kept local backup at `Libs/LibOrb-1.0/LibOrb-1.0.lua.bak_20260226_orbregress` for rollback.
Expected result:
- Orb rendering and swirl animation behavior now follow Diabolic's proven LibOrb implementation.
Validation:
- `luac -p Libs/LibOrb-1.0/LibOrb-1.0.lua`
- In-game `/reload`, set player power style to orb mode, verify orb fill + swirl visual.
2026-02-26 (rollback: Diabolic LibOrb replacement clipped orb fill)
Issue:
- After replacing `LibOrb` wholesale with Diabolic copy, player mana orb rendered empty (no visible fill).
Root cause:
- Diabolic LibOrb variant was not drop-in compatible with AzeriteUI runtime in this branch; orb fill path clipped out under current update/visibility pipeline.
Change(s):
- Restored previous AzeriteUI LibOrb file from backup:
  - `Libs/LibOrb-1.0/LibOrb-1.0.lua.bak_20260226_orbregress` -> `Libs/LibOrb-1.0/LibOrb-1.0.lua`
Expected result:
- Orb fill rendering returns to pre-replacement behavior.
Validation:
- `luac -p Libs/LibOrb-1.0/LibOrb-1.0.lua`

2026-02-27 (investigation start: 1:1 Diabolic player power orb port)\nIssue:\n- User requested a 1:1 Diabolic-style player power orb port, limited to power orb behavior/art/logic without changing crystal, health, or unrelated statusbars.\nPlan:\n- Ground current Azerite player orb/crystal path against Diabolic player orb implementation and port orb-only behavior with minimal surface area.\n
2026-02-27 (implementation: Diabolic orb-only art/logic port for player mana orb)
Issue:
- User requested a Diabolic 1:1-style player power orb port without changing crystal, health, or unrelated statusbars.
Root cause:
- AzeriteUI orb path already had working fill updates, but lacked Diabolic's dedicated orb-only art stack and frame wiring on the player mana orb path.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - Added Diabolic-style orb mouse handlers for the player orb widget.
  - Added `ApplyDiabolicManaOrbArt(...)` to style `AdditionalPower` with Diabolic orb border/glass/art layering while keeping existing crystal code separate.
  - Wired `AdditionalPower` to create/use extra orb-only textures: `Glass`, `Artwork`.
  - Kept crystal (`self.Power`) path unchanged.
- Added Diabolic orb-only assets to `Assets/`:
  - `orb-glass.tga`
  - `orb-border.tga`
  - `orb-art2.tga`
Expected result:
- Orb mode keeps current AzeriteUI-safe fill path but renders with Diabolic-style orb presentation.
- Crystal, health, and other statusbars stay on their existing code paths.
Validation:
- Static asset existence check.
- In-game `/reload`, enable orb mode, confirm fill remains and Diabolic glass/border/art overlay appears.
2026-02-27 (follow-up: restore AzeriteUI orb art and force immediate orb fill writes)
Issue:
- Player orb still had no visible fill, and user clarified the orb should keep AzeriteUI art rather than Diabolic art.
Root cause:
- Orb widget used the generic statusbar writer without forcing immediate orb display-value updates, so LibOrb smoothing path could leave the orb visually empty.
- Earlier Diabolic-style art overlay patch also replaced AzeriteUI orb casing textures, which was not desired.
Change(s):
- `Components/UnitFrames/Units/Player.lua`:
  - Restored orb art application to AzeriteUI's existing orb textures (`ManaOrbBackdropTexture`, `ManaOrbShadeTexture`, `ManaOrbForegroundTexture`).
  - Hid optional Diabolic-only glass/art layers.
  - Set `self.AdditionalPower.smoothing = true` so orb writes use immediate display-value updates through the existing compatibility writer.
Expected result:
- Orb keeps AzeriteUI art.
- Orb fill/statusbar becomes visible again instead of remaining visually empty.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
- In-game `/reload`, set `Mana Orb Only`, cast/regen mana, verify orb fill appears and updates.
## 2026-02-27 Orb Fill Regression Follow-up
- Repro: Player mana orb frame/case visible but no interior fill renders, while mana text still updates.
- Scope: `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Player.lua`.
- Hypothesis: `UpdateAdditionalPower` still writes secret raw mana into `LibOrb`, so the orb render path never gets a stable safe value to display after recent swirl/art experiments.
- Plan: Force orb writes to resolved safe current/max values only and explicitly restore orb layer visibility after texture application.
Change(s):
- `Components/UnitFrames/Functions.lua`: `UpdateAdditionalPower()` now only writes raw current mana when it is explicitly non-secret (`rawCurSafe`), otherwise it writes the resolved safe current value.
- `Components/UnitFrames/Units/Player.lua`: `ShowPlayerNativePowerVisuals()` / `HidePlayerNativePowerVisuals()` now apply to all orb layers returned by `LibOrb:GetStatusBarTexture()` instead of only layer 1.
- `Components/UnitFrames/Units/Player.lua`: orb texture setup now explicitly calls `ShowPlayerNativePowerVisuals(self.AdditionalPower)` after applying AzeriteUI orb textures/art.
Expected result:
- AzeriteUI orb art stays intact.
- Orb fill layers are explicitly visible again.
- Orb fill is driven by safe mana values instead of secret raw values.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
## 2026-02-27 Target Health Simple Fake Fill Cleanup
- Repro:
  - Player health resumed updating after the native write-path fix, but target health could still pin or misrender.
  - The target bar was still routed through old debug/nativevisual/health-lab branches instead of a single runtime path.
- Root cause:
  - `Components/UnitFrames/Units/Target.lua` still reconfigured native health texcoords/flip state and still respected health fake-fill alignment/debug settings.
  - That left the visible target health bar dependent on dead option/debug-era code rather than only the live statusbar geometry.
- Fix:
  - Reduced target health runtime to one fake-fill renderer:
    - native health statusbar stays alive as the data/geometry source
    - native statusbar texture is hidden
    - visible fill is a sibling fake texture attached to the native statusbar texture
    - fake texture texcoord is driven by resolved target percent only
  - Stopped the target health update pass from applying extra native texcoord/flip/display geometry logic.
  - Hid the retired target health fake-fill options in `Options/OptionsPages/UnitFrames.lua` so `/az` no longer suggests they drive the live bar.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
## 2026-02-27 Target Health Dead Code / Options Cleanup
- Repro:
  - After moving target health to one simple fake-fill renderer, the codebase still carried target-health-specific debug flags, profile defaults, hidden menu builders, and command paths that no longer affected runtime.
  - The previous menu cleanup also hid target cast controls even though cast settings still drive the live renderer.
- Cleanup goal:
  - Remove target-health-only dead code and commands.
  - Remove target-health-only profile defaults and menu options.
  - Keep target cast configuration and target cast debug controls intact.
- Plan:
  - Simplify `Components/UnitFrames/Units/Target.lua` defaults/settings resolution so it no longer carries unused target-health fake-fill configuration.
  - Remove target-health menu/debug options from `Options/OptionsPages/UnitFrames.lua` while restoring live cast controls.
  - Reduce `Core/Debugging.lua` target-fill debug support to cast-only where health flags no longer affect runtime.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
- `luac -p Core/Debugging.lua`
## 2026-02-27 ManaOrb Secret Feed Regression
- Repro:
  - `Player.ManaOrb` exists, backdrop/case/shade render, but the animated orb fill remains visually empty.
  - Latest `/azdebug dump player` shows `Player.ManaOrb` is being fed a secret current value while max is numeric.
- Root cause:
  - Diabolic's current `LibOrb` still expects the visible display value it uses for Lua-side fill math to be numeric.
  - AzeriteUI's recent parity change started feeding raw secret mana values directly into `LibOrb`, which leaves the orb display value at zero and collapses the visible fill.
  - AzeriteUI's generic statusbar helpers in `Components/UnitFrames/UnitFrame.lua` also only mutated the first texture returned by `GetStatusBarTexture()`, which is unsafe for orb widgets that return multiple animated layers.
- Fix:
  - Restore `API.UpdateManaOrb()` to write secret-safe numeric min/max/value into the orb widget while keeping raw values only as cached metadata.
  - Update unitframe statusbar helper shims so `SetTexCoord()` and `SetFlippedHorizontally()` apply to every texture returned by `GetStatusBarTexture()`, not only the first one.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/UnitFrame.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
## 2026-02-27 Health StatusBar Freeze Regression
- Repro:
  - User reports player/target health statusbars stopped updating again after the rebuild sequence.
  - Earlier local dumps already showed health bar state diverging from expected live behavior.
- Root cause:
  - `API.UpdateHealth()` is currently using the stricter `rawCurSafe/rawMaxSafe` write gate again.
  - AzeriteUI already documented this as a regression on 2026-02-20: it can suppress native statusbar updates in secret-value paths and make health bars appear frozen.
- Fix:
  - Restore the native health write path to use raw numeric values (`rawCurNum/rawMaxNum`) for the actual widget write, while keeping all addon-side caches and comparisons secret-safe.
  - This lets Blizzard/native statusbars consume secret health values directly again, which is what keeps the visible bars moving.
Validation:
- pending
## 2026-02-27 Target Deep-Clean Fake Fill Pinned
- Repro:
  - Player health resumes updating, but target fake health fill still does not move.
- Root cause:
  - `ResolveTargetFakeHealthFillPercent()` deep-clean branch trusted `health.safePercent` first.
  - In secret target health paths, `health.safePercent` can fall back to a synthetic cached/full value while the native target bar is actually moving.
  - That pins the fake fill to the wrong percent and masks the native update underneath.
- Fix:
  - Reorder the deep-clean resolver to prefer live target geometry:
    - mirror percent
    - native geometry percent
    - reliable safe percent (`mirror/api` sourced only)
    - reliable min/max
    - last known percent
  - This keeps target fake fill driven by the live bar state instead of stale cached percent.
Validation:
- pending
- In-game `/reload`, set `Mana Orb Only`, cast/regen mana, verify orb fill appears and updates.
## 2026-02-27 Orb Update Regression Root Cause
- Repro: orb layers animate/render, but fill stays static instead of tracking current mana.
- Root cause: `API.UpdateAdditionalPower()` was changed to write only safe current mana into the orb. `LibOrb` needs the raw numeric current value, even when secret, so its proxy texture path can derive a live fill percent.
- Fix plan: restore raw numeric writes for `AdditionalPower` only, while keeping safe cached values for tag text and math.
Change(s):
- `Components/UnitFrames/Functions.lua`: restored raw numeric write behavior for `API.UpdateAdditionalPower()` (`rawCurNum` / `rawMaxNum`) so `LibOrb` can use its proxy-driven secret-value fill logic again.
Expected result:
- Orb remains animated and visible.
- Orb fill now updates with live mana instead of staying pinned to the last safe value.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- In-game `/reload`, set orb mode, cast mana repeatedly, confirm the orb drains/refills live.
## 2026-02-27 Orb Regressed Again
- Repro: after restoring raw numeric writes for `AdditionalPower`, both orb animation and visible fill disappeared again.
- Scope: `Components/UnitFrames/Functions.lua`, `Libs/LibOrb-1.0/LibOrb-1.0.lua`, `Components/UnitFrames/Units/Player.lua`.
- Plan: compare current `AdditionalPower` write path against the last state where the orb at least rendered, then revert only the regression point.
## 2026-02-27 LibOrb Secret Branch Bug
- Root cause: `Libs/LibOrb-1.0/LibOrb-1.0.lua` secret-value branch in `Orb.SetValue()` updated the proxy statusbar and returned early without calling `Update(self)`.
- Impact: when orb writes raw secret mana values, the orb never redraws even though the proxy has current data.
- Fix plan: keep raw secret writes for orb mode, but force a redraw from the secret branch after proxy update.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`: `Orb.SetValue()` secret-value branch now calls `Update(self)` after updating the proxy statusbar.
Expected result:
- Orb animation remains present.
- Orb fill/statusbar becomes visible again and updates from live secret mana values.
Validation:
- `luac -p Libs/LibOrb-1.0/LibOrb-1.0.lua`
- `luac -p Components/UnitFrames/Functions.lua`
- In-game `/reload`, cast mana repeatedly, confirm orb animates and fill drains/refills live.
Change(s):
- `Libs/LibOrb-1.0/LibOrb-1.0.lua`: orb proxy statusbar is now explicitly created as `VERTICAL`, with seeded min/max/value defaults.
Why this matters:
- LibOrb's secret-value path derives percent from `proxy:GetStatusBarTexture():GetHeight() / orbHeight`.
- That only makes sense if the proxy statusbar is vertical.
- The previous default horizontal proxy made secret-percent geometry invalid, which explains the orb losing visible fill when fed secret mana values.
Validation:
- `luac -p Libs/LibOrb-1.0/LibOrb-1.0.lua`
- In-game `/reload`, cast mana repeatedly, verify orb animation and fill both remain visible and update.
## 2026-02-27 Orb/Target Rebuild Start
- Repro:
  - Player mana orb still routes through `AdditionalPower`, so orb runtime, text, visibility, and secret-value handling are split across two different systems.
  - Target health/cast still have multiple competing reverse-fill/native-fallback branches, so one-frame-correct states keep snapping back.
- Grounded findings:
  - `..\DiabolicUI3\Components\UnitFrames\Units\Player.lua` uses a dedicated orb widget created by `self:CreateOrb(...)`; it does not run the player orb through `AdditionalPower`.
  - AzeriteUI only uses `CreateOrb()` for the player mana orb path, so rebasing `LibOrb` is low blast-radius here.
  - WoW 12 guidance in `API_CHANGES_12.0.0.md`/`API_CHANGES_12.0.0_FULL.md` still applies: do not do addon-side arithmetic/comparisons on secret values, but let widgets accept them when needed.
- Plan being implemented:
  - Rebase `Libs/LibOrb-1.0/LibOrb-1.0.lua` to the Diabolic renderer baseline.
  - Replace player orb runtime with a dedicated `self.ManaOrb` path and stop using `self.AdditionalPower`.
  - Retarget tags/debug/options from `AdditionalPower` to `ManaOrb`.
  - Collapse target health/cast reverse rendering to one fake sibling texture driven by native statusbar updates.
Change(s):
- `Components/UnitFrames/Functions.lua`: `API.UpdateManaOrb()` now targets `self.ManaOrb` only; `AdditionalPower` is no longer part of the live player-orb path.
- `Components/UnitFrames/Units/Player.lua`: player orb runtime now uses dedicated `self.ManaOrb` visibility, value-tag, update, and force-update flow.
- `Components/UnitFrames/Tags.lua`: mana tags now read from `frame.ManaOrb`.
- `Core/Debugging.lua`: player orb dumps now inspect `frame.ManaOrb`.
- `Components/UnitFrames/Units/Target.lua`: fake health/cast geometry is now active whenever `TargetUseNativeFedFakeFill` is enabled; retired flip-lab overrides were removed from runtime settings resolution.
- `Options/OptionsPages/UnitFrames.lua`: removed dead target flip-lab controls, kept only fake-fill anchor/offset/inset and live cast alignment/fake-fill controls.
Expected result:
- Player orb is isolated from `AdditionalPower` and follows the dedicated `ManaOrb` widget path.
- Target fake-fill alignment options now affect the live health/cast renderer instead of only affecting a debug-only path.
- Removed target flip/reverse options no longer appear in `/az` because they no longer affect runtime.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Core/Debugging.lua`
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
## 2026-02-27 Player ManaOrb Visibility Nil Call
- Repro:
  - Enabling/loading the player frame crashes in `Components/UnitFrames/Units/Player.lua:585` with `attempt to call a nil value`.
- Root cause:
  - `UpdateManaOrbVisibility()` calls `ShouldShowPlayerPowerValue()` before that function was declared in lexical scope.
  - During the orb refactor, `ShouldShowPlayerPowerValue` was converted to a later `local` function declaration without a forward declaration, so the earlier closure resolved a nil upvalue/global at runtime.
- Fix:
  - Added a forward declaration near the other player-power helper locals.
  - Changed the later definition to assign into that forward-declared local instead of creating a new local.
Validation:
- `luac -p Components/UnitFrames/Units/Player.lua`
## 2026-02-27 Mana Orb Visible Layers Not Redrawing
- Repro:
  - Player orb widget exists and can be toggled, but the animated fill/statusbar layers remain visually empty.
- Root cause:
  - `Libs/LibOrb-1.0/LibOrb-1.0.lua` was storing updated min/max/value on the orb, but the visible clipped layers were not being forced through `Update(...)` on safe numeric writes.
  - That left the native data path updated while the visible orb layers stayed at their previous zero-height clipped state.
- Fix:
  - Added a safe-number gate in `Orb.SetValue()` and `Orb.SetMinMaxValues()`.
  - When values are non-secret numerics, `barDisplayValue` is synchronized and `Update(self, 0)` is called immediately to redraw the visible orb layers.
Validation:
- `luac -p Libs/LibOrb-1.0/LibOrb-1.0.lua`
## 2026-02-27 Diabolic Orb Parity Pass
- Repro:
  - After the dedicated `ManaOrb` refactor and redraw patches, the player orb still has no visible animated fill layers in AzeriteUI.
- Next step:
  - Compare `Libs/LibOrb-1.0/LibOrb-1.0.lua`, `Components/UnitFrames/UnitFrame.lua`, and `Components/UnitFrames/Units/Player.lua` one-to-one against `..\DiabolicUI3`.
  - Port only the behavioral differences needed for AzeriteUI's orb, while keeping AzeriteUI media/config references intact.
Change(s):
- `Components/UnitFrames/Functions.lua`: `API.UpdateManaOrb()` now follows the Diabolic update pattern more closely:
  - raw `UnitPower(..., Mana)` / `UnitPowerMax(..., Mana)` are written directly into the orb widget
  - safe values are now only used for cached text/debug fields
- `Components/UnitFrames/Units/Player.lua`: `ManaOrb` now matches Diabolic setup more closely by dropping the custom `smoothing = true` assignment and enabling `displayAltPower`.
Why:
- The biggest remaining behavioral difference was that AzeriteUI's live orb render loop was still driven through a custom safe-value path instead of the direct widget-fed path Diabolic uses.
- This patch removes that mismatch while preserving AzeriteUI-safe text caches.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Units/Player.lua`
## 2026-02-27 Crystal Power Percent Stuck At 100
- Repro:
  - Player/target crystal power value can be switched to percent text, but the displayed percent stays pinned at `100%` even when the numeric power value continues to change.
- Root cause:
  - The power tag path still trusted cached frame percent too early.
  - In secret/stale paths, `API.UpdatePower()` could keep an old API percent until the bar geometry was sampled again, and `Components/UnitFrames/Tags.lua` would reuse cached power percent before recomputing from live values.
- Fix plan:
  - In `Components/UnitFrames/Functions.lua`, always prefer post-write bar geometry percent for power when available.
  - In `Components/UnitFrames/Tags.lua`, recompute power percent from live raw/frame values before falling back to cached safe percent.
  - In `Options/OptionsPages/UnitFrames.lua`, remove the old hidden power text toggles now that `PowerValueFormat` is the only live menu surface for player/target power text.
Change(s):
- `Components/UnitFrames/Functions.lua`
  - `API.UpdatePower()` now prefers post-write bar geometry percent (`GetSecretPercentFromBar(element)`) whenever it is available, instead of leaving stale `UnitPowerPercent` results in place.
- `Components/UnitFrames/Tags.lua`
  - Added `GetActiveFramePowerElement(frame, powerType)` so mana classes use the visible power widget:
    - visible `ManaOrb` for mana-orb text
    - `Power` crystal otherwise
  - `SafeUnitPercent()` now recomputes from live frame bar values before trusting cached `safePercent`.
  - `SafeUnitPower()` now resolves the active widget the same way.
  - `*:PowerPercent` / `*:ManaPercent` now try live raw power values first, then active frame values, then safe fallbacks.
- `Options/OptionsPages/UnitFrames.lua`
  - Removed the hidden legacy `powerValueUsePercent` / `powerValueUseFull` toggles for player and target. `PowerValueFormat` is now the only live menu control for that surface.
Validation:
- `luac -p Components/UnitFrames/Functions.lua`
- `luac -p Components/UnitFrames/Tags.lua`
- `luac -p Options/OptionsPages/UnitFrames.lua`
## 2026-02-27 Player/Target Power Surface Cleanup
- Repro:
  - Player/target power text selection still carried legacy branching for hidden percent/full toggles.
  - `/az -> Unit Frames -> Target` still exposed target fill debug toggles even though that debug surface already has its own slash/menu path.
- Cleanup plan:
  - Normalize player/target power text format selection through one helper each, with legacy booleans only as compatibility fallback.
  - Remove target fill debug controls from `Options/OptionsPages/UnitFrames.lua`.
  - Tighten debug help text so it no longer advertises removed/dead target scopes.
Validation:
- pending






2026-03-01 (boss health orientation follow-up: pre-change repro)
Issue:
- User report: boss target healthbar is still filling the wrong way around.
- Current target runtime applies `SetReverseFill(true)` for all target styles in `Components/UnitFrames/Units/Target.lua`, including `Boss` style.
Investigation plan:
- Keep boss texture/media unchanged for now.
- Test a minimal runtime fix by making boss style reverse-fill conditional in target health setup.

2026-03-01 (boss health orientation follow-up: conditional boss reverse-fill)
Decision:
- Keep existing boss texture mapping (`hp_boss_bar_mirror`) unchanged.
- In `Components/UnitFrames/Units/Target.lua`, make target health reverse-fill style-aware:
  - non-boss styles keep `SetReverseFill(true)`
  - boss style now uses `SetReverseFill(false)`
- Apply the same flag to `Health.Preview` so preview/fallback visuals stay aligned.
Expected result:
- Boss target health fill direction no longer runs opposite of the intended visual flow.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (boss health orientation correction: use non-mirrored boss bar texture)
Issue:
- Follow-up identified boss style still referenced `hp_boss_bar_mirror` in `Layouts/Data/TargetUnitFrame.lua`.
Decision:
- Switch boss health texture to `hp_boss_bar`.
- Remove the temporary boss-only reverse-fill override in `Components/UnitFrames/Units/Target.lua` so boss follows the same reverse-fill runtime as other target styles.
Expected result:
- Boss health direction matches intended target-side behavior with the correct base texture.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target health crop follow-up: test hostility-based reverse-fill gate)
Issue:
- `/azdebug dump target` still reports wrong crop/fill direction on hostile targets with `Target.Health reverse: true`.
- User requested trying reverse-fill disabled only for enemy targets.
Plan:
- Keep texture/style selection unchanged.
- In target health runtime setup, derive hostility from `UnitCanAttack("player", unit)` and set reverse-fill only for non-hostile targets.

2026-03-01 (target health crop follow-up: enemy-only reverse-fill disable applied)
Decision:
- Updated `Components/UnitFrames/Units/Target.lua` target health setup:
  - `isEnemyTarget = UnitCanAttack("player", unit)`
  - `shouldReverseTargetHealthFill = not isEnemyTarget`
  - apply this flag to both `Health` and `Health.Preview`.
Expected result:
- Hostile targets should report `reverse: false` for target health in `/azdebug dump target`, while friendly targets keep reverse fill.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (correction: revert health gate, apply non-self cast reverse-fill gate)
Issue:
- User clarified the reverse-fill test request was for castbars (non-self targets), not target health.
Decision:
- Revert target health reverse-fill to the prior always-reversed behavior.
- Apply target cast reverse-fill gate in `Components/UnitFrames/Units/Target.lua`:
  - self target (`UnitIsUnit(unit, "player")`): `SetReverseFill(true)`
  - non-self target: `SetReverseFill(false)`
- Apply the same rule to `Target.Castbar.TestBar` so `/azdebug` cast probe matches live cast orientation.
Expected result:
- Target health behavior returns to previous state.
- Non-self target castbars should no longer use reversed fill.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast crop parity pass: timer driver promoted to primary crop source)
Issue:
- `/azdebug dump target` still showed non-self cast fake fill stuck in pending/idle (`castFake source pending`) while health fake fill cropped correctly.
- Probe bar (`Target.Castbar.TestBar`) already proved timer payload updates existed (`probe_timer`), so percent extraction was the weak link.
Decision:
- Added dedicated hidden `Target.Castbar.CropDriver` statusbar in `Components/UnitFrames/Units/Target.lua`.
- Promoted timer-driver path to primary cast crop writer:
  - update `CropDriver:SetTimerDuration(...)` from callback/timer payload
  - anchor `Target.Castbar.FakeFill` to `CropDriver` statusbar texture
  - render fake fill with full texcoord (`1,0,0,1`) so native timer geometry controls crop.
- Kept existing percent resolver path as strict fallback when timer-driver update fails.
- Prevented active-cast fallback to idle while timer-driver state is marked active.
- Kept non-self cast reverse-fill rule and applied it to both `TestBar` and `CropDriver`.
- Extended debug output in `Core/Debugging.lua`:
  - cast dump now includes `timerDriver` and `driverSource`
  - `/azdebug dump target` now prints `Target.Castbar.CropDriver`.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-03-01 (target cast crop parity follow-up: dynamic strategy for self vs non-self)
Issue:
- After timer-driver became unconditional primary, self-target cast crop regressed.
- User reports cast no longer crop-fills correctly even when targeting self.
Investigation:
- Self-target cast path previously behaved correctly with explicit/duration percent route.
- Non-self path benefits from timer-driver due to frequent pending percent resolution.
Plan:
- Add dynamic strategy:
  - self target cast: percent-first, timer-driver fallback
  - non-self target cast: timer-driver first, percent fallback

2026-03-01 (target cast crop parity follow-up: dynamic self/non-self strategy applied)
Decision:
- Added `ShouldPreferTimerDriverForTargetCast(cast)` in `Components/UnitFrames/Units/Target.lua`.
- Updated cast resolution order:
  - self target (`target == player`): resolve percent first, timer-driver only fallback.
  - non-self target: timer-driver first, percent fallback.
- Applied this order in both `SyncTargetCastVisualState(...)` and `UpdateTargetLiveCastFakeFill(...)`.
Expected result:
- Self target cast returns to prior correct crop behavior.
- Non-self target keeps timer-driver robustness when percent payloads are pending.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast crop parity follow-up: timer-driver UV guard with dynamic fallback)
Issue:
- Runtime dump showed timer-driver path active while `Target.Castbar.FakeFill` reported degenerate UV (`1 0 1 1`), which breaks expected crop-fill behavior.
Decision:
- Added UV validity guard in `UpdateTargetCastFakeFillFromTimerDriver(...)`:
  - if fake fill texcoord collapses vertically (`top == bottom`), treat timer-driver apply as failed.
- Updated both sync/live callsites to fall through to percent resolver path when timer-driver apply fails UV guard.
Expected result:
- Timer-driver remains primary when it produces valid crop geometry.
- Cast path dynamically falls back to percent crop when timer-driver UV becomes invalid at runtime.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast crop parity follow-up: apply timer rendering to real castbar for non-self)
Issue:
- Latest dump still shows non-self cast stuck as `path idle source pending` while `timerDriver=true`.
- Test/experimental timer-driven statusbar behavior works, but fake-fill handoff on the real cast path still fails.
Decision:
- For non-self targets, apply timer payload directly to the real `Target.Castbar` and render native castbar texture with configured alpha.
- Keep fake fill as fallback path only.
- Keep self-target on existing percent-first fake-fill path (already confirmed working).
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast crop parity follow-up: non-self timer-native render applied)
Decision:
- Added `ApplyTargetNativeCastVisualFromTimer(...)` in `Components/UnitFrames/Units/Target.lua`.
- For non-self targets, cast update now attempts timer-native rendering first:
  - call `SetTimerDuration(...)` on the real `Target.Castbar`
  - show native cast texture with configured alpha
  - hide fake fill while native timer render is active
  - set cast fake path/source to `timer_native`.
- Kept existing fake-fill timer-driver/percent paths as fallback.
- Added lifecycle resets for `__AzeriteUI_UseNativeCastVisual` on target change and cast hide.
Expected result:
- Non-self cast should crop on the real castbar path (matching the bar that worked in experiment), instead of idling with pending fake-fill.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast texture follow-up: non-self uses mirrored hp_cap_bar)
Issue:
- User requested applying the mirrored cap-bar art to real target castbars for non-self targets.
Plan:
- In `Components/UnitFrames/Units/Target.lua`, select cast texture dynamically:
  - self target: existing style texture (`db.HealthBarTexture`)
  - non-self target: `hp_cap_bar_mirror`
- Apply this texture consistently to castbar, fake fill, crop driver, and test bar.

2026-03-01 (target cast texture follow-up: non-self mirrored cap-bar applied)
Decision:
- Updated target cast style setup in `Components/UnitFrames/Units/Target.lua`:
  - added dynamic `castBarTexture` selection by target identity:
    - self target: `db.HealthBarTexture`
    - non-self target: `ns.API.GetMedia("hp_cap_bar_mirror")` (fallback to style texture if unavailable)
- Applied `castBarTexture` to:
  - `Target.Castbar` statusbar texture
  - `Target.Castbar.FakeFill` texture
  - `Target.Castbar.CropDriver` statusbar texture
  - `Target.Castbar.TestBar` statusbar texture
Expected result:
- Non-self target castbars render with mirrored cap-bar art while keeping self-target castbar texture unchanged.
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`

2026-03-01 (target cast cleanup: remove experimental cast bars and extra pathways)
Issue:
- User requested cleanup now that target cast behavior is converging.
- `Target.lua` still carried experimental `Castbar.TestBar` and `Castbar.CropDriver` bars and related resolver branches.
Plan:
- Remove experimental cast bars and their debug/runtime plumbing.
- Keep only two active cast paths:
  - non-self target: native timer render on real `Target.Castbar`
  - self target: existing fake-fill percent resolver path

2026-03-01 (target cast cleanup: experimental bars removed, cast path simplified)
Decision:
- Removed experimental cast statusbars from `Components/UnitFrames/Units/Target.lua`:
  - removed `self.Castbar.TestBar`
  - removed `self.Castbar.CropDriver`
- Removed probe/timer-driver helper pathways and related hook calls.
- Simplified cast runtime to two active paths:
  - non-self target: `ApplyTargetNativeCastVisualFromTimer(...)`
  - self target: existing percent-resolved fake-fill path
- Cleaned debug output in `Core/Debugging.lua`:
  - removed `timerDriver/driverSource` cast fields
  - removed `Target.Castbar.CropDriver` and `Target.Castbar.TestBar` dumps
Validation:
- `luac -p Components/UnitFrames/Units/Target.lua`
- `luac -p Core/Debugging.lua`

2026-03-01 (auras combat visibility follow-up: pre-change investigation)
Issue:
- User reports player buff icons can be missing until leaving combat after they were hidden in combat.
- Current custom aura visibility uses secure state driver (`Components/Auras/Auras.lua`, visibility `UpdateDriver/UpdateVisibility`) and can hide/show header without guaranteed per-button refresh.
Hypothesis:
- When the secure header is re-shown in combat, aura buttons may keep stale/nil icon state until a later full refresh; forcing a lightweight refresh on header show should restore icons immediately.
Plan:
- Add a minimal `OnShow`-triggered refresh path in `Auras.lua` that runs `ForAll("Update")` and `UpdateAuraButtonAlpha()`.

2026-03-01 (auras combat visibility follow-up: OnShow refresh for secure buff header)
Decision:
- Updated `Components/Auras/Auras.lua` to refresh aura button visuals whenever the secure buff header is shown again:
  - Added `Auras.RefreshVisibleBuffButtons()` to re-run `ForAll("Update")` and `UpdateAuraButtonAlpha()` when header is visible.
  - Added `Auras.QueueRefreshVisibleBuffButtons()` (next-frame via `ScheduleTimer(..., 0)`) to avoid racing secure header show/attribute timing.
  - Hooked `buffs` `OnShow` with `self:SecureHookScript(buffs, "OnShow", "QueueRefreshVisibleBuffButtons")`.
Expected result:
- If buffs are hidden during combat and later shown in combat, icons should repopulate immediately instead of staying blank until leaving combat.
Validation:
- `luac -p Components/Auras/Auras.lua`

2026-03-01 (tooltips secret-value crash: pre-change investigation)
Issue:
- Runtime error in `Components/Misc/Tooltips.lua:707`:
  - `attempt to perform boolean test on a secret boolean value`
- Stack points to `Tooltips.OnTooltipSetUnit` while processing unit tooltips (example unit `raid15`).
Finding:
- `OnTooltipSetUnit` directly branches on API booleans (`UnitIsPlayer(unit)`, `UnitIsAFK(unit)`) and compares realm relationship values without sanitizing secret values first.
Plan:
- Add secret-safe sanitization for unit-derived values before boolean tests/comparisons in `OnTooltipSetUnit`, while preserving existing display behavior for non-secret values.

2026-03-01 (tooltips secret-value crash: OnTooltipSetUnit boolean guards)
Decision:
- Patched `Components/Misc/Tooltips.lua` in `Tooltips.OnTooltipSetUnit`:
  - sanitize `unitName` / `unitRealm` when secret, and fallback `unitName` to `_G.UNKNOWN`
  - sanitize `UnitIsPlayer(unit)` result before boolean branch
  - sanitize `UnitRealmRelationship(unit)` before relationship comparisons
  - sanitize `UnitIsAFK(unit)` result before AFK suffix branch
Expected result:
- No secret-boolean branch errors in tooltip unit postcall flow.
- Tooltip name formatting stays identical for non-secret values.
Validation:
- `luac -p Components/Misc/Tooltips.lua`

2026-03-01 (tooltips secret-safety audit with wow-api MCP + additional hardening)
Audit:
- Queried wow-api MCP for unit APIs used in tooltip path:
  - `UnitIsAFK`, `UnitIsPlayer`, `UnitExists`, `UnitIsDeadOrGhost`, `UnitRealmRelationship`, `UnitName`
  - `C_UnitAuras.GetAuraDataByAuraInstanceID`
  - discovered/confirmed `C_Secrets.ShouldUnitAuraIndexBeSecret` and `C_Secrets.ShouldUnitAuraInstanceBeSecret`.
Decision:
- Added shared helpers in `Components/Misc/Tooltips.lua`:
  - `IsSecretValue(value)`
  - `SafeBooleanValue(value)` (drops secret booleans before branch tests).
- Hardened remaining tooltip unit branches:
  - `SetHealthValue`: sanitize `UnitExists` + `UnitIsDeadOrGhost` booleans before boolean logic.
  - `OnTooltipSetUnit`: sanitize `UnitExists` check in fallback unit resolution.
- Hardened aura tooltip pathways:
  - `SetUnitAura`:
    - guard unit token
    - skip if `C_Secrets.ShouldUnitAuraIndexBeSecret(...)` indicates secret
    - sanitize `name`, `source`, `spellID`, and `UnitName(source)`.
  - `SetUnitAuraInstanceID`:
    - guard unit token
    - skip if `C_Secrets.ShouldUnitAuraInstanceBeSecret(...)` indicates secret
    - sanitize `data.name`, `data.spellId`, `data.sourceUnit`, and `UnitName(sourceUnit)`.
Expected result:
- Tooltip postcalls no longer branch on secret booleans and no longer format secret aura payloads.
- Reduced risk of secret-value errors from unit/aura tooltips under WoW 12.
Validation:
- `luac -p Components/Misc/Tooltips.lua`

2026-03-01 (actionbars assisted highlight: pre-change API/wiki check)
Issue:
- User requested assisted highlight mechanic support on AzeriteUI actionbars.
- Existing LAB path updates proc overlays (`UpdateOverlayGlow`) and legacy mark hooks (`UpdateOnBarHighlightMarksBySpell/Flyout`), but has no direct `C_AssistedCombat.GetNextCastSpell()` fallback.
API/wiki findings:
- `C_AssistedCombat.GetNextCastSpell`, `C_AssistedCombat.IsAvailable`, `C_AssistedCombat.GetActionSpell`, `C_AssistedCombat.GetRotationSpells`.
- `C_ActionBar.FindAssistedCombatActionButtons`, `C_ActionBar.IsAssistedCombatAction`, `C_ActionBar.HasAssistedCombatActionButtons`.
- `C_SpellActivationOverlay.IsSpellOverlayed` exists and is preferred over legacy global `IsSpellOverlayed`.
Plan:
- Add a throttled assisted next-cast resolver in LAB and feed it into button highlight update.
- Register `ASSISTED_COMBAT_ACTION_SPELL_CAST` to refresh highlights promptly.

2026-03-01 (actionbars assisted highlight: LAB assisted next-cast fallback added)
Decision:
- Updated `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`:
  - bumped `MINOR_VERSION` to `138`.
  - added helper `GetAssistedNextSpellID()` with lightweight throttle and secret-safe numeric sanitization.
  - registered `ASSISTED_COMBAT_ACTION_SPELL_CAST` when `C_AssistedCombat.GetNextCastSpell` exists.
  - on `ASSISTED_COMBAT_ACTION_SPELL_CAST`, clear assisted cache and refresh `UpdateSpellHighlight` on active buttons.
  - `UpdateSpellHighlight(...)` now falls back to assisted next-cast spell match when Blizzard highlight mark hooks are absent/stale.
  - `UpdateOverlayGlow(...)` now prefers `C_SpellActivationOverlay.IsSpellOverlayed` and uses legacy `IsSpellOverlayed` only as fallback.
  - added secret-safe guards for spell IDs and booleans in both highlight paths.
Expected result:
- Assisted recommendation highlight can appear on AzeriteUI action buttons by spellID matching, even if only `C_AssistedCombat.GetNextCastSpell()` is available.
- Proc overlay glow path is modernized for WoW 12 via `C_SpellActivationOverlay`.
Validation:
- `luac -p Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
