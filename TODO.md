# TODO — Known Bugs & Outstanding Issues

---

## 1. Nameplate Castbar Interrupt Colors

Partially resolved.

The old watcher/resolver stack is still gone, but nameplates no longer use the plain base-only castbar model.

Current state in [Components/UnitFrames/Units/NamePlates.lua](Components/UnitFrames/Units/NamePlates.lua):
- yellow when the primary interrupt is ready
- red when the primary interrupt is unavailable
- gray for protected/non-interruptible casts
- base color when the interrupt state is unknown
- red on failed/interrupted

This now works through the current nameplate-local interrupt path plus the spell fallback helper in [Components/UnitFrames/NameplateInterruptDB.lua](Components/UnitFrames/NameplateInterruptDB.lua), not through the old deleted watcher stack.

Related current limitation:
- the target frame full-bar interrupt tint is temporarily disabled, because protected target casts can still show the wrong yellow state
- the target castbar currently stays on its normal base color until that path is rebuilt cleanly

Any future interrupt-color work should start from the current nameplate-local path and the owned spell fallback system, not by reviving the deleted monolithic resolver experiments.

---

## 2. Unitframe Health Percentages Stuck at 100% or 91%

**Expected behavior:** Health % text updates live as unit health changes.

**Current behavior:** Stays at 100%, or gets stuck at an arbitrary value like 91%.

**Root cause:**

Health percentage tags resolve via `ResolveDisplayHealthPercent()` at [Tags.lua:868-900](Components/UnitFrames/Tags.lua#L868-L900), which reads from two sources:
1. `GetFrameHealthPercentSnapshot()` at [Tags.lua:854-866](Components/UnitFrames/Tags.lua#L854-L866) — reads `frame.Health.safePercent`
2. `UnitHealthPercent()` API call — fallback

The `safePercent` field is written by the fake fill update pipeline (e.g. `NormalizeTargetDisplayPercent` in [Target.lua:1119](Components/UnitFrames/Units/Target.lua#L1119), `NormalizeBossDisplayPercent` in [Boss.lua:137](Components/UnitFrames/Units/Boss.lua#L137)). If the fake fill system isn't firing on each health event, `safePercent` stales out.

The tag event list for `*:HealthPercent` at [Tags.lua](Components/UnitFrames/Tags.lua) is `UNIT_HEALTH UNIT_MAXHEALTH PLAYER_FLAGS_CHANGED UNIT_CONNECTION` — this should be sufficient to trigger updates, but the tag may be reading a cached `safePercent` that hasn't been updated by the time the tag fires.

**Fix suggestion:**

- Add debug output to check what `frame.Health.safePercent` contains at tag evaluation time for the affected unitframe, and whether the fake fill pipeline (`SyncBossHealthVisualState`, `SyncTargetHealthVisualState`, etc.) is being called before the tag fires.
- Consider whether the `_FRAME` context variable in [Tags.lua](Components/UnitFrames/Tags.lua) is being set correctly when the tag evaluates — if it's `nil` or wrong, `GetFrameHealthPercentSnapshot()` returns nothing and the fallback `UnitHealthPercent()` call may be blocked by `SecureHook` / Blizzard restrictions at certain health values.
- The `UnitHealthPercent(unit, true, CurveConstants.ZeroToOne)` call at [Functions.lua:999](Components/UnitFrames/Functions.lua#L999) uses `ZeroToOne` scaling — make sure this is consistent with how the tag interprets the returned value (0–1 vs 0–100 range).

---

## 3. Target Castbar Fill Direction — Can't Reverse Without Breaking the Crop System

**Expected behavior:** Target castbar fills from the right side (opposite to player), depleting toward the left — mirroring the health bar's visual language.

**Current behavior:** The castbar behaves the same as the player castbar (fills left to right), because `SetReverseFill` on a standard StatusBar changes the actual fill direction but breaks the TexCoord crop-fill system.

**Root cause:**

The target health bar does NOT use `SetReverseFill`. Instead it uses a fake fill overlay texture with TexCoord manipulation in `ApplyTargetSimpleHealthFakeFillByPercent` at [Target.lua:556-592](Components/UnitFrames/Units/Target.lua#L556-L592):

```lua
-- Full health: SetTexCoord(1, 0, 0, 1) — flipped horizontally, full width visible
-- At 50%:      SetTexCoord(0.5, 0, 0, 1) — left half cropped away, right half visible
```

This crops from the left at `percent`, making the bar appear to shrink from the right — which is the correct RTL fill illusion.

The castbar, however, is a real `StatusBar` widget. At [Target.lua:2436-2441](Components/UnitFrames/Units/Target.lua#L2436-L2441), `SetReverseFill` is used based on `shouldReverseTargetCastFill`, but `SetReverseFill` on a native bar actually moves the texture origin, which conflicts with TexCoord-based cropping if the castbar also uses a fake fill overlay.

**Fix suggestion:**

If the castbar has a `FakeFill` overlay (like the health bar does), apply the same TexCoord crop logic — using `GetTargetFillTexCoords()` at [Target.lua:209-213](Components/UnitFrames/Units/Target.lua#L209-L213) — instead of `SetReverseFill`. The castbar would need its own `PostCastUpdate` callback that updates the fake fill's TexCoord on each progress tick, mirroring how `ApplyTargetSimpleHealthFakeFillByPercent` works.

If the castbar does not have a FakeFill, one would need to be created and anchored over it the same way the health FakeFill is, then driven by `PostCastUpdate`.

---

## 4. Boss/Arena Frames — Health Bar Fills from Wrong End ("Being Eaten" Effect)

**Expected behavior:** Boss/arena health bars should fill from the right and deplete toward the left, matching the target frame visual direction.

**Current behavior:** The bar appears to fill from the wrong end — looks like it's being consumed from the left rather than depleting from the right.

**Root cause:**

Both [Boss.lua](Components/UnitFrames/Units/Boss.lua) and [Arena.lua](Components/UnitFrames/Units/Arena.lua) use:
- `health:SetReverseFill(true)` at [Boss.lua:388](Components/UnitFrames/Units/Boss.lua#L388) / [Arena.lua:492](Components/UnitFrames/Units/Arena.lua#L492)
- `GetBossFillTexCoords()` / `GetArenaFillTexCoords()` which both call `ns.API.GetReversedHorizontalFillTexCoords(percent)` at [Boss.lua:81-83](Components/UnitFrames/Units/Boss.lua#L81-L83) / [Arena.lua:139-141](Components/UnitFrames/Units/Arena.lua#L139-L141)

`GetReversedHorizontalFillTexCoords(percent)` at [Functions.lua:914-924](Components/UnitFrames/Functions.lua#L914-L924) returns `percent, 0, 0, 1` — this crops the left portion of the texture, showing only the right side. At 100% it shows the full bar; at 50% it shows the right half. This should produce a left-depletion effect.

The conflict: the native `StatusBar` with `SetReverseFill(true)` also moves the texture anchor. Combined with the TexCoord crop from `GetReversedHorizontalFillTexCoords`, the two are likely double-reversing, or the native bar is visually competing with the FakeFill.

The target frame works because it does NOT set `SetReverseFill` on the native bar — it hides the native bar via `HideTargetNativeHealthVisuals()` and drives everything through `ApplyTargetSimpleHealthFakeFillByPercent`. Boss and Arena use a similar pattern via `HideBossNativeHealthVisuals()` / `HideArenaNativeHealthVisuals()` → `UpdateBossHealthFakeFillFromBar()` / `UpdateArenaHealthFakeFillFromBar()` at [Boss.lua:148-158](Components/UnitFrames/Units/Boss.lua#L148-L158) / [Arena.lua:207-216](Components/UnitFrames/Units/Arena.lua#L207-L216).

**Fix suggestion:**

Check whether `HideBossNativeHealthVisuals()` / `HideArenaNativeHealthVisuals()` are actually suppressing the native bar texture completely. If the native bar is still rendering with `SetReverseFill(true)`, it may be visible on top of or under the FakeFill and causing the visual conflict.

The most likely fix is to align boss/arena with how target works:
- Remove or ignore `SetReverseFill` from the native health bar (since the FakeFill drives the visual)
- Ensure the FakeFill texture is rendering on top and is correctly driven by `GetReversedHorizontalFillTexCoords()` (which should give correct RTL behavior matching target)
- The `ApplyBossBarFillRule` / `ApplyArenaBarFillRule` functions at [Boss.lua:100-125](Components/UnitFrames/Units/Boss.lua#L100-L125) / [Arena.lua:158-183](Components/UnitFrames/Units/Arena.lua#L158-L183) handle orientation for the native bar — these should not conflict with the FakeFill, but verify the draw layers are stacked correctly so FakeFill occludes the native bar.

---

## 5. Dead Code & Unused Libraries (Retail-Only Cleanup) ✓ DONE

The addon targets **WoW 12.0 retail only** (TOC `120001`/`120000`). The following is dead weight inherited from the original multi-version AzeriteUI5 source. None of it runs or loads on retail.

---

### 5a. Unused Library Directories

These folders exist in [Libs/](Libs/) but are **not loaded** by [Libs/Libs.xml](Libs/Libs.xml). They are only referenced by the unused `Libs_Vanilla.xml`, `Libs_Wrath.xml`, and `Libs_Cata.xml` variant files.

| Directory | Purpose | Status |
| --- | --- | --- |
| [Libs/LibAuraTypes/](Libs/LibAuraTypes/) | Aura type classification for Classic | Unused |
| [Libs/LibClassicCasterino/](Libs/LibClassicCasterino/) | Cast bar data for Classic Era | Unused |
| [Libs/LibClassicDurations/](Libs/LibClassicDurations/) | Aura duration data for Classic | Unused (only referenced in `oUF_PriorityDebuff.lua:24-26` behind `oUF.isClassic` guard) |
| [Libs/LibClassicSpellActionCount-1.0/](Libs/LibClassicSpellActionCount-1.0/) | Spell action counts for Classic | Unused |
| [Libs/LibPlayerSpells-1.0/](Libs/LibPlayerSpells-1.0/) | Player spell data | Unused (no references anywhere in addon code) |
| [Libs/LibSpellLocks/](Libs/LibSpellLocks/) | Spell school lock tracking for Classic | Unused |
| [Libs/oUF_Classic/](Libs/oUF_Classic/) | oUF fork for Classic/Wrath | Unused (retail uses [Libs/oUF/](Libs/oUF/)) |

**Safe to delete** all 7 directories if Classic support is not planned.

Also safe to delete the variant XML files themselves:

- [Libs/Libs_Vanilla.xml](Libs/Libs_Vanilla.xml)
- [Libs/Libs_Wrath.xml](Libs/Libs_Wrath.xml)
- [Libs/Libs_Cata.xml](Libs/Libs_Cata.xml)

---

### 5b. Unused Aura Data Directories

[UnitFrames.xml](Components/UnitFrames/UnitFrames.xml) only loads the retail aura files (`Auras/AuraData.lua`, etc.). The following subdirectories are **never loaded** by any XML:

- [Components/UnitFrames/Auras/Classic/](Components/UnitFrames/Auras/Classic/) — 4 files (AuraData, AuraFilters, AuraSorting, AuraStyling)
- [Components/UnitFrames/Auras/Wrath/](Components/UnitFrames/Auras/Wrath/) — 4 files
- [Components/UnitFrames/Auras/Cata/](Components/UnitFrames/Auras/Cata/) — 4 files

**Safe to delete** all three subdirectories.

---

### 5c. Unused Tracker Variants

[Misc.xml](Components/Misc/Misc.xml) only loads `TrackerWoW11.lua`. These files are loaded by nothing:

- [Components/Misc/TrackerVanilla.lua](Components/Misc/TrackerVanilla.lua)
- [Components/Misc/TrackerWrath.lua](Components/Misc/TrackerWrath.lua)
- [Components/Misc/TrackerWoW10.lua](Components/Misc/TrackerWoW10.lua)

**Safe to delete** all three.

---

### 5d. Dead Code Blocks in Active Files (IsClassic / IsCata Guards)

These are in loaded files but the conditions can **never be true** on WoW 12 retail (`ns.IsClassic`, `ns.IsCata`, `ns.IsTBC`, `ns.IsWrath` are all `false`).

| File | Lines | Dead condition |
| --- | --- | --- |
| [ActionBars.lua](Components/ActionBars/Elements/ActionBars.lua#L506) | 506 | `if (not ns.IsClassic)` — else branch is dead |
| [MicroMenu.lua](Components/ActionBars/Elements/MicroMenu.lua#L54) | 54, 70, 102, 118, 195, 201 | `ns.IsCata` / `ns.IsClassic` branches |
| [PetBar.lua](Components/ActionBars/Elements/PetBar.lua#L129) | 129, 458, 461 | `ns.IsCata` / `ns.IsClassic` branches |
| [StanceBar.lua](Components/ActionBars/Elements/StanceBar.lua#L741) | 741 | `if (not ns.IsClassic)` — else branch is dead |
| [VehicleExit.lua](Components/ActionBars/Elements/VehicleExit.lua#L133) | 133, 136 | `ns.IsClassic` / `ns.IsCata` branches |
| [ActionBar.lua](Components/ActionBars/Prototypes/ActionBar.lua#L424) | 424, 430, 434, 436 | `ns.IsCata` / `ns.IsClassic` branches |
| [HideBlizzard.lua](Components/ActionBars/Compatibility/HideBlizzard.lua#L27) | 27 | `if (ns.IsClassic) then return end` — dead early-return (retail never returns here) |
| [Minimap.lua](Components/Misc/Minimap.lua#L93) | 93, 94, 142–157, 189–224, 498, 1128, 1308, 1325, 1365, 1383, 1418 | `ns.IsClassic` / `ns.IsCata` branches throughout |
| [Pet.lua](Components/UnitFrames/Units/Pet.lua#L35) | 35 | `PetHasHappiness = (ns.IsClassic and ...)` — always `false` |
| [NamePlates.lua](Components/UnitFrames/Units/NamePlates.lua#L2296) | ~2296 | Classic/Wrath nameplate distance fallbacks |

**Note on `ns.WoW10`:** This is `true` on WoW 12 (`version >= 100000`), so `WoW10` guards are **not dead** — they are permanently-on branches. The `if (not ns.WoW10)` early-returns (e.g. [EncounterBar.lua:28](Components/ActionBars/Elements/EncounterBar.lua#L28), [ActionBars.lua:772](Components/ActionBars/Elements/ActionBars.lua#L772)) are effectively unreachable, but harmless.

---

### 5e. Unloaded Compatibility Files

[ActionBars.xml](Components/ActionBars/ActionBars.xml#L5) loads these, but they exist solely to handle third-party addons (Bartender4, ConsolePort) or a Classic-only Blizzard bar variant. They are low-risk but worth reviewing:

- [Components/ActionBars/Compatibility/HideBlizzardClassic.lua](Components/ActionBars/Compatibility/HideBlizzardClassic.lua) — referenced in [ActionBars.xml](Components/ActionBars/ActionBars.xml)? Verify. If not loaded, delete.
- [Components/ActionBars/Compatibility/HandleBartender.lua](Components/ActionBars/Compatibility/HandleBartender.lua) — loaded, but only useful if Bartender4 is installed. Harmless if Bartender4 is absent, but adds load overhead.
- [Components/ActionBars/Compatibility/HandleConsolePort.lua](Components/ActionBars/Compatibility/HandleConsolePort.lua) — same as above for ConsolePort.

---

## 6. Moot `IsRetail` / `WoW12` Version Checks in Active Files

The addon is retail-only (TOC `120100`). Both `ns.IsRetail` (version >= 100000) and `WoW12` (build >= 120000) are **always true**. Every `if (IsRetail)` wrapper is redundant, every `else` branch is dead, and every `if (not IsRetail) then return end` guard is a no-op.

**Cleanup approach:** Remove the version variables and `GetBuildInfo()` calls, unwrap the true branches (keep the body), delete the dead else branches entirely.

---

### 6a. Root Version Definitions

| File | Lines | What to remove |
| --- | --- | --- |
| [Constants.lua](Core/Common/Constants.lua#L66) | 66–72 | `IsRetail`, `IsClassic`, `IsTBC`, `IsWrath`, `IsCata`, `WoW10`, `WoW11` flag definitions |
| [Private.lua](static/Private/Private.lua#L9) | 9–12 | `clientVersion`, `ns.IsRetail`, `clientBuild`, `ns.WoW12` definitions and `GetBuildInfo()` calls |

---

### 6b. `IsRetail` / `IsClassic` / `IsCata` Dead Branches (Full Inventory)

**Early-return guards (no-op on retail — remove the guard line):**

| File | Line | Guard |
| --- | --- | --- |
| [WorldMap.lua](Components/Misc/WorldMap.lua#L11) | 11 | `if (not ns.IsRetail) then return end` |
| [Banners.lua](Components/Misc/Banners.lua#L28) | 28 | `if (not ns.IsRetail) then return end` |
| [ExtraButtons.lua](Components/ActionBars/Elements/ExtraButtons.lua#L27) | 27 | `if (not ns.IsRetail) then return end` |
| [Tracker.lua](Options/OptionsPages/Tracker.lua#L28) | 28 | `if (not ns.IsRetail) then return end` |
| [AuraStyling.lua](Components/UnitFrames/Auras/AuraStyling.lua#L28) | 28 | `if (not ns.IsRetail) then return end` |
| [AuraFilters.lua](Components/UnitFrames/Auras/AuraFilters.lua#L28) | 28 | `if (not ns.IsRetail) then return end` |
| [AuraSorting.lua](Components/UnitFrames/Auras/AuraSorting.lua#L28) | 28 | `if (not ns.IsRetail) then return end` |
| [AuraData.lua](Components/UnitFrames/Auras/AuraData.lua#L252) | 252 | `if (not ns.IsRetail) then return end` |
| [ObjectiveTracker.lua](Components/Blizzard/ObjectiveTracker.lua#L18) | 27–38 | `if (not IsRetail) then return end` |
| [FloaterBars.lua](Components/Blizzard/FloaterBars.lua#L19) | 30 | `if (IsRetail) then return end` — **entire module body is dead** |

**Early-return guards (always-false conditions — entire module body is dead on retail):**

| File | Line | Guard |
| --- | --- | --- |
| [TrackerVanilla.lua](Options/OptionsPages/TrackerVanilla.lua#L28) | 28 | `if (not ns.IsClassic) then return end` — entire module dead |
| [HideBlizzardClassic.lua](Components/ActionBars/Compatibility/HideBlizzardClassic.lua#L27) | 27 | `if (not ns.IsClassic) then return end` — entire module dead |
| [Focus.lua](Components/UnitFrames/Units/Focus.lua#L27) | 27 | `if (ns.IsClassic) then return end` — guard is no-op |
| [Arena.lua](Components/UnitFrames/Units/Arena.lua#L28) | 28 | `if (ns.IsClassic) then return end` — guard is no-op |
| [ArcheologyBar.lua](Components/Misc/ArcheologyBar.lua#L28) | 28 | `if (ns.IsClassic or ns.IsCata) then return end` — guard is no-op |

**Inline `ns.IsRetail` checks (always true — unwrap / simplify):**

| File | Lines | Pattern |
| --- | --- | --- |
| [ActionBars.lua](Components/ActionBars/ActionBars.lua#L41) | 41, 47–58, 367–398, 575–580, 714–716 | `local IsRetail` + ternaries + `if (IsRetail)` blocks |
| [Blizzard.lua](Components/Blizzard/Blizzard.lua#L21) | 21, 33–113 | `local IsRetail` + multiple blocks |
| [Minimap.lua](Components/Blizzard/Minimap.lua#L19) | 19, 87–105 | `local IsRetail` + multiple blocks |
| [Tooltips.lua](Components/Blizzard/Tooltips.lua#L16) | 16, 33–36 | `local IsRetail` + conditional |
| [UnitFrames.lua](Components/UnitFrames/UnitFrames.lua#L29) | 29, 74–131 | `local IsRetail` + aura filter conditionals |
| [NamePlates.lua](Components/UnitFrames/Units/NamePlates.lua#L26) | 26, 1401, 1811, 2248, 2395 | `local IsRetail` + multiple inline checks |
| [Player.lua](Components/UnitFrames/Units/Player.lua) | 56–57, 107, 736, 1727, 2287, 2293, 2497, 2526, 2567, 2889 | `ns.IsRetail` in ternaries, `ns.IsCata` in config |
| [PlayerAlternate.lua](Components/UnitFrames/Units/PlayerAlternate.lua) | 608, 957, 981, 1222 | `ns.IsRetail` inline checks |
| [PlayerClassPower.lua](Components/UnitFrames/Units/PlayerClassPower.lua) | 52–60, 79, 506, 660–661, 668 | `ns.IsRetail` / `ns.IsCata` in class power config |
| [PlayerCastBar.lua](Components/UnitFrames/Units/PlayerCastBar.lua#L122) | 122 | `if (not ns.IsRetail) then` — dead branch |
| [Boss.lua](Components/UnitFrames/Units/Boss.lua#L539) | 539 | `if (ns.IsRetail) then` — unwrap |
| [Arena.lua](Components/UnitFrames/Units/Arena.lua#L682) | 682 | `if (ns.IsRetail) then` — unwrap |
| [Focus.lua](Components/UnitFrames/Units/Focus.lua#L389) | 389 | `if (ns.IsRetail) then` — unwrap |
| [Pet.lua](Components/UnitFrames/Units/Pet.lua) | 35, 398 | `ns.IsClassic` (always false), `ns.IsRetail` (always true) |
| [ToT.lua](Components/UnitFrames/Units/ToT.lua#L435) | 435 | `if (ns.IsRetail) then` — unwrap |
| [Party.lua](Components/UnitFrames/Units/Party.lua#L943) | 943 | `if (ns.IsRetail) then` — unwrap |
| [Raid25.lua](Components/UnitFrames/Units/Raid25.lua#L764) | 764 | `if (ns.IsRetail) then` — unwrap |
| [Tags.lua](Components/UnitFrames/Tags.lua#L1032) | 1032 | `if (ns.IsRetail) then` — unwrap |
| [Auras.lua](Components/Auras/Auras.lua#L503) | 503 | `self.isRetail = ns.IsRetail` — always true |
| [AlertFrames.lua](Components/Misc/AlertFrames.lua#L207) | 207 | `if (not ns.IsRetail) then` — dead branch |
| [Durability.lua](Components/Misc/Durability.lua#L275) | 275 | `not ns.IsRetail` in expression — always false |
| [ChatFrames.lua](Components/Misc/ChatFrames.lua) | 475, 507 | `ns.IsRetail` checks |
| [PetButton.lua](Components/ActionBars/Prototypes/PetButton.lua#L98) | 98 | `if (ns.IsRetail) then` — unwrap |
| [Minimap.lua](Components/Misc/Minimap.lua) | 1184, 1202 | `ns.IsCata` / `ns.IsClassic` — dead branches |
| [Options.lua](Options/Options.lua#L367) | 367 | `if (ns.IsRetail)` — always true |
| [ExplorerMode.lua](Options/OptionsPages/ExplorerMode.lua) | 266, 273, 333 | `ns.IsRetail or ns.IsCata` — always true |
| [ActionBars.lua](Options/OptionsPages/ActionBars.lua#L698) | 698 | `ns.IsRetail and 8 or 5` — always 8 |
| [Nameplates.lua](Options/OptionsPages/Nameplates.lua) | 374, 387 | `ns.IsRetail` checks |
| [UnitFrames.lua](Options/OptionsPages/UnitFrames.lua) | 892, 1262, 1306, 1354, 1364 | `ns.IsClassic` / `ns.IsRetail` / `ns.IsCata` |
| [ExplorerMode.lua](Core/ExplorerMode.lua) | 634, 728, 762 | `ns.IsRetail or ns.IsCata` — always true |
| [Colors.lua](Core/API/Colors.lua#L110) | 110 | `ns.IsClassic or ns.IsCata` — always false |
| [FixFlavorDifferences.lua](Core/FixFlavorDifferences.lua#L132) | 132 | `ns.IsClassic` — always false |
| [MovableFrameManager.lua](Core/MovableFrameManager.lua#L431) | 431 | `ns.IsCata or ns.IsRetail` — always true |

**`ns.ClientVersion >= 120000` checks (always true on WoW 12 — unwrap):**

| File | Lines | Pattern |
| --- | --- | --- |
| [Auras.lua](Components/Auras/Auras.lua) | 547, 718, 766 | `issecretvalue or (ns.ClientVersion >= 120000)` — always true |
| [Auras.lua](Options/OptionsPages/Auras.lua#L61) | 61 | Same pattern, return value always known |
| [Party.lua](Components/UnitFrames/Units/Party.lua#L1406) | 1406 | `ns.ClientVersion >= 120000` — always true |
| [Raid5.lua](Components/UnitFrames/Units/Raid5.lua#L1074) | 1074 | `ns.ClientVersion >= 120000` — always true |
| [Raid25.lua](Components/UnitFrames/Units/Raid25.lua#L995) | 995 | `ns.ClientVersion >= 120000` — always true |
| [Raid40.lua](Components/UnitFrames/Units/Raid40.lua#L981) | 981 | `ns.ClientVersion >= 120000` — always true |
| [FixBlizzardBugs.lua](Core/FixBlizzardBugs.lua) | 56, 2470 | `ns.ClientBuild >= 120000` / `ns.ClientVersion >= 120000` |

---

### 6c. `WoW12` Dead Branches

| File | Lines | Dead pattern |
| --- | --- | --- |
| [Colors.lua](static/Private/Colors.lua#L11) | 11–21 | `GetBuildInfo()` + `WoW12` + ternary fallback colors (non-WoW12 values dead) |
| [Defaults.lua](static/Private/Defaults.lua#L11) | 11–25 | `GetBuildInfo()` + `WoW12` + `Defaults[1] = WoW12 and 7 or 6` (the `6` is dead) |
| [ActionBars.lua](Components/ActionBars/ActionBars.lua#L38) | 38–40, 112–116, 355–363, 1054–1124 | `GetBuildInfo()` + `WoW12` + multiple `if/else` blocks (else branches dead) |
| [Blizzard.lua](Components/Blizzard/Blizzard.lua#L18) | 18–20, 47–51 | `GetBuildInfo()` + `WoW12` + StatusTrackingBarManager block |
| [FloaterBars.lua](Components/Blizzard/FloaterBars.lua#L16) | 16–18, 90–96 | `GetBuildInfo()` + `WoW12` + hooks (doubly dead — after IsRetail early return) |
| [Minimap.lua](Components/Blizzard/Minimap.lua#L16) | 16–18, 207–214 | `GetBuildInfo()` + `WoW12` + compass/backdrop alpha |
| [ObjectiveTracker.lua](Components/Blizzard/ObjectiveTracker.lua#L15) | 15–17, 41–59 | `GetBuildInfo()` + `WoW12` + tracker code |
| [Tooltips.lua](Components/Blizzard/Tooltips.lua#L13) | 13–15, 53–84 | `GetBuildInfo()` + `WoW12` + tooltip data blocks |
| [UnitFrames.lua](Components/UnitFrames/UnitFrames.lua#L26) | 26–28, 74–131 | `GetBuildInfo()` + `WoW12` + aura filter blocks with dead else |
| [NamePlates.lua](Components/UnitFrames/Units/NamePlates.lua#L24) | 24–25, 151–159, 339–346 | `GetBuildInfo()` + `WoW12` + nameplate styling/config blocks |

---

### 6d. Special Case: FloaterBars.lua Is Entirely Dead on Retail

[FloaterBars.lua](Components/Blizzard/FloaterBars.lua#L30) has `if (IsRetail) then return end` at line 30. On retail, the module's `OnInitialize` returns immediately — **everything after line 30 is unreachable**. The entire file body (UpdateBars, SecureHooks, etc.) is dead code. Consider gutting the file or removing it from [Blizzard.xml](Components/Blizzard/) if nothing loads after the early return.

---

### 6e. `ns.WoW11` Redundant Guards & Dead Modules

`ns.WoW11` (version >= 110000) is always true on WoW 12 retail. All `if (not ns.WoW11) then return end` guards are no-ops (harmless but redundant). However, two modules use `ns.WoW11` in a way that makes them **entirely dead**:

**Dead modules** (condition `not ns.WoW10 or ns.WoW11` always returns on WoW12):

| File | Line | Effect |
| --- | --- | --- |
| [EditMode.lua](Core/EditMode.lua#L29) | 29 | `if (not ns.WoW10 or ns.WoW11) then return end` — entire module dead |
| [EditModePresets.lua](Core/EditModePresets.lua#L29) | 29 | `if (not ns.WoW10 or ns.WoW11) then return end` — entire module dead |

**Redundant `ns.WoW11` guards** (no-op on WoW12, could be removed):

| File | Line | Pattern |
| --- | --- | --- |
| [Core.lua](Core/Core.lua#L53) | 53 | `ns.SETTINGS_VERSION = ns.WoW11 and 25 or 22` — the `22` is dead |
| [Auras.lua](Components/Auras/Auras.lua#L747) | 747, 959 | `if (ns.WoW11 and ...)` — always true, unwrap |
| [AlertFrames.lua](Components/Misc/AlertFrames.lua#L123) | 123 | `ns.WoW11` in condition — always true |
| [SanityBarFix.lua](Components/Misc/SanityBarFix.lua#L15) | 15 | `if (not ns or not ns.WoW11) then return end` — no-op guard |
| [TrackerWoW11.lua](Components/Misc/TrackerWoW11.lua#L28) | 28 | `if (not ns.WoW11) then return end` — no-op guard |
| All 15 files in [WoW11/](WoW11/) | 28 | `if (not ns.WoW11) then return end` — no-op guard in every file |

---

### 6f. `ns.WoW10` Permanently-True Guards (Low Priority)

`ns.WoW10` (version >= 100000) is always true on WoW 12, making `if (not ns.WoW10)` early-returns dead. These are harmless but could be cleaned up:

| File | Lines | Dead pattern |
| --- | --- | --- |
| [EncounterBar.lua](Components/ActionBars/Elements/EncounterBar.lua#L28) | 28 | `if (not ns.WoW10)` early return |
| [ActionBars.lua](Components/ActionBars/Elements/ActionBars.lua#L772) | 772 | `if (not ns.WoW10)` early return |

---

### 6g. Version Constants & Compatibility Polyfills (Root Definitions)

[Constants.lua](Core/Common/Constants.lua#L66) defines all version flags. On WoW 12 retail:

| Flag | Value | Status |
| --- | --- | --- |
| `ns.Private.IsRetail` | `true` | Always true — moot |
| `ns.Private.IsClassic` | `false` | Always false — moot |
| `ns.Private.IsTBC` | `false` | Always false — moot |
| `ns.Private.IsWrath` | `false` | Always false — moot |
| `ns.Private.IsCata` | `false` | Always false — moot |
| `ns.Private.WoW10` | `true` | Always true — moot |
| `ns.Private.WoW11` | `true` | Always true — moot |

[Compatibility.lua](Core/Compatibility.lua#L54) has API polyfills gated by `tocversion >= 40400 and tocversion < 50000` (Cata range). On WoW 12, `tocversion` is 120100 — the Cata conditions are always false. The `tocversion >= 100100` / `100200` / `100205` conditions are always true. All polyfills could be simplified to unconditional or removed if the APIs they shim are already present.

**Note:** Section 6h was merged into 6b above (all `IsRetail`/`IsClassic`/`IsCata` items now in one place).

---

### 6i. Misc Dead Weight (Files & Directories)

**Backup/merge-conflict files (never loaded):**

| Path | Description |
| --- | --- |
| [LibActionButton-1.0-GE.backup-ours-20260306.lua](Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.backup-ours-20260306.lua) | Git merge conflict backup — safe to delete |
| [Backups/](Backups/) | Development backup directories (oUF rollback/sync snapshots) — not loaded by anything |
| [.research/](.research/) | External addon copies for comparison — not loaded by anything |

**Disabled-in-XML modules (commented out in [Core.xml](Core/Core.xml#L38)):**

| File | Status |
| --- | --- |
| [EditMode.lua](Core/EditMode.lua) | Commented out in XML **and** has dead early-return (see 6e) — doubly dead |
| [EditModePresets.lua](Core/EditModePresets.lua) | Commented out in XML **and** has dead early-return (see 6e) — doubly dead |

**Dead branch in library:**

| File | Line | Pattern |
| --- | --- | --- |
| [LibSmoothBar-1.0.lua](Libs/LibSmoothBar-1.0/LibSmoothBar-1.0.lua#L299) | 299–301 | `if false then` — hardcoded dead branch |
