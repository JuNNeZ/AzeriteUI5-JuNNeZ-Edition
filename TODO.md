# TODO — Known Bugs & Outstanding Issues

---

## 1. Nameplate Castbar Interrupt: Non-Interruptible Shows as Yellow Instead of Grey

**Expected behavior:**
- Yellow — interrupt is ready (`primary-ready`)
- Red — interrupt is on cooldown (`unavailable`)
- Grey — cast is non-interruptible / protected (`locked`)

**Current behavior:** Non-interruptible casts show yellow instead of grey on nameplates.

**Root cause:**

The nameplate castbar color logic lives in `Castbar_RefreshInterruptVisuals` at [NamePlates.lua:1444-1484](Components/UnitFrames/Units/NamePlates.lua#L1444-L1484). It calls `API.GetInterruptCastColor()` which routes through `API.GetInterruptCastVisualState()` at [Functions.lua:304-333](Components/UnitFrames/Functions.lua#L304-L333).

The three colors are defined at [Functions.lua:255-259](Components/UnitFrames/Functions.lua#L255-L259):

```lua
local InterruptVisualColors = {
    primaryReady = { 1, .82, 0 },   -- yellow
    unavailable  = Colors.red,       -- red
    locked       = Colors.gray       -- grey
}
```

`GetInterruptCastVisualState` checks `ShouldUseEnemyInterruptVisuals()` at [Functions.lua:289-302](Components/UnitFrames/Functions.lua#L289-L302) before doing anything else. If this returns `false`, the function returns `"base"` immediately — which falls back to the default castbar color (yellow), bypassing the `locked` → grey path entirely.

`ShouldUseEnemyInterruptVisuals` calls `IsEnemyUnitForInterruptVisuals` at [Functions.lua:261-287](Components/UnitFrames/Functions.lua#L261-L287), which checks `owner.canAttack`. If `canAttack` is not yet set or resolves as `false`/`nil` on the nameplate owner at the time `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` fires, the whole state machine short-circuits to `"base"` and the bar stays yellow.

The `PostCastInterruptible` callback is wired at [NamePlates.lua:2042](Components/UnitFrames/Units/NamePlates.lua#L2042) as `Castbar_PostUpdate`, which immediately calls `UpdateInterruptCastBarRefresh` → `Castbar_RefreshInterruptVisuals`. The callback fires correctly — it's the `canAttack` gate that prevents reaching `IsCastMarkedNotInterruptible`.

**Fix suggestion:**

Add a debug print inside `Castbar_RefreshInterruptVisuals` to log `interruptState` and `element.__owner.canAttack` when `element.notInterruptible` is true. If `canAttack` is `nil` or `false` at that point, the fix is to ensure the nameplate owner's `canAttack` flag is set before the cast starts, or to add a fallback in `IsEnemyUnitForInterruptVisuals` — e.g. also check `element.notInterruptible` directly as a hint that this is an enemy cast (since friendlies can't be interrupted anyway).

Alternatively, `IsCastMarkedNotInterruptible` at [Functions.lua:241-254](Components/UnitFrames/Functions.lua#L241-L254) could be checked *before* the `ShouldUseEnemyInterruptVisuals` gate, so that `locked` is always returned for genuinely non-interruptible casts regardless of the enemy check.

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
