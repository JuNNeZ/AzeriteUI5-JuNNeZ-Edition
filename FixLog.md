# FixLog — AzeriteUI JuNNeZ Edition

**Archive Note:** Historical entries from project inception through 2026-03-03 have been archived to `FixLog_Archive_20260303.md` (14,673 lines). This fresh log starts with version 5.2.216-JuNNeZ as the baseline.

## 5.3.3-JuNNeZ (2026-03-11)

**Status:** Release candidate.

### Bug Fixes In Progress
- **Party leader-change priority debuff crash:** Normalized `oUF_PriorityDebuff` dispel entries to numeric priorities so party roster and leader updates no longer hit the boolean-vs-number compare path.
  - **Files Modified:** `Libs/oUF_Plugins/oUF_PriorityDebuff.lua`

## 2026-03-10

- **Rogue combo-point layout review started:** Investigating report that 6th/7th Rogue combo points still render on the wrong arc with incorrect final backdrop behavior.
  - **Files Targeted:** `Layouts/Data/PlayerClassPower.lua`, `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Rogue combo-point arc restored:** Fixed the `ComboPoints` layout so point 6 returns to the archived mirrored arc position (`64, 21`) instead of overlapping point 5, keeping the 6th/7th Rogue path on the intended curve. Also removed the leftover `classPointOffsets` runtime path/default so stale saved slider offsets can no longer distort combo-point placement after that experimental UI was removed.
  - **Files Modified:** `Layouts/Data/PlayerClassPower.lua`, `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Rogue combo-point arc follow-up (math-based curve + final finisher move):** Replaced the hand-authored 7-point Rogue/Feral layout with a mirrored parabolic arc so all seven combo points follow one curve. Also moved the oversized round finisher from point 5 to point 7, leaving points 1-6 on standard plate sizing and making the final point the large round capstone.
  - **Files Modified:** `Layouts/Data/PlayerClassPower.lua`
- **Rogue combo-point finisher spacing follow-up:** Increased the final oversized combo-point padding/spacing so point 7 sits farther out on the arc and no longer clips point 6.
  - **Files Modified:** `Layouts/Data/PlayerClassPower.lua`
- **Rogue combo-point finisher spacing follow-up 2:** Added a bit more outward padding to the oversized final combo point so the 7th point clears the 6th more comfortably.
  - **Files Modified:** `Layouts/Data/PlayerClassPower.lua`
- **Combo-point layout gating fix:** Split the shared 5-point combo layout from the Rogue-only extended 7-point layout so Feral and other standard combo-point users keep the original 5-point finisher while Rogues alone use the extended arc at 6-7 combo points.
  - **Files Modified:** `Layouts/Data/PlayerClassPower.lua`, `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Shaman classpower gate review started:** Re-checking local classpower visibility logic across retail/classic copies after follow-up suspicion that the per-spec gate bypasses the intended talent-known requirement.
  - **Files Targeted:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Shaman classpower talent gate restored in both oUF copies:** Updated the Shaman-specific visibility branch to honor the existing `requireSpell`/`C_SpellBook.IsSpellKnown` gate instead of enabling classpower on Enhancement spec alone. This matches the explicit spell-known gating pattern used in local peer addons such as `GW2_UI` and `ElvUI`.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Classpower cleanup pass started:** Reviewing the current player classpower module after report that the latest update may have broken classpower. Scope limited to dead Elemental swap-bar config/UI and pre-spec fallback behavior.
  - **Files Targeted:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Classpower cleanup pass completed:** Removed the unused hidden `enableElementalMaelstromDisplay` option/default and changed Elemental swap-bar pre-spec fallback to stay off until specialization is known, avoiding premature classpower mode switching during early load.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Options/OptionsPages/UnitFrames.lua`

## 2026-03-11

- **Party leader-change priority debuff crash investigation started:** Reviewing `oUF_PriorityDebuff` after user report of `attempt to compare number with boolean` during party leader swaps; also checking Blizzard quest portrait error and local `ElvUI`/`GW2_UI` handling for reusable guards.
  - **Files Targeted:** `Libs/oUF_Plugins/oUF_PriorityDebuff.lua`, `Components/Misc/TrackerWoW11.lua`, `Core/FixBlizzardBugsWow12.lua`
- **Priority debuff compare crash fixed:** Normalized resolved dispel eligibility in `oUF_PriorityDebuff` to numeric `DispellPriority` values before aura-loop comparisons, so party/raid refreshes no longer try to compare the scan priority number against raw booleans or spell-name strings.
  - **Root Cause:** `UpdateDispelTypes()` copied spec/class entries like `Magic = true` and function results like `GetSpellInfo(...)` directly into `self.dispelTypes`, but the aura scan later expects numeric priorities at `Libs/oUF_Plugins/oUF_PriorityDebuff.lua:341`.
  - **Peer Check:** Local `ElvUI` and `GW2_UI` installs do not contain a reusable guard for the separate Blizzard `QuestFrame_ShowQuestPortrait` measurement error; both only hook that function later to reposition `QuestModelScene`.
  - **Files Modified:** `Libs/oUF_Plugins/oUF_PriorityDebuff.lua`
- **Blizzard quest portrait measurement guard added:** Wrapped `QuestFrame_ShowQuestPortrait` in the WoW12 Blizzard-fix layer so the specific `Cannot perform measurement in QuestFrameModelScene` failure from objective-tracker quest opens is swallowed and falls back to hiding the portrait scene instead of throwing a Lua error.
  - **Scope:** Narrow string-matched guard only for the known model-scene measurement failure; unrelated quest frame errors still propagate normally.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **Blizzard quest portrait guard parked:** Commented the temporary `QuestFrame_ShowQuestPortrait` measurement wrapper back out pending confirmation that the fault is ours rather than a broader Blizzard / third-party tracker-skin interaction. The candidate code remains in place but inactive for quick restoration.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`

## 2026-03-09

- **Arena tooltip secret-unit fix (`Tooltips.lua:171`):** Reworked tooltip nameplate detection to follow the local `ElvUI`/`GW2_UI` pattern: reject secret tooltip unit tokens, fall back to safe `"mouseover"`/mouse-focus unit tokens when available, and wrap `C_NamePlate.GetNamePlateForUnit` in `pcall` so tooltip styling no longer faults in arena on secret unit arguments.
  - **Files Modified:** `Components/Misc/Tooltips.lua`
- **Non-library nameplate lookup hardening:** Added the same secret-unit/`pcall` guard around remaining direct `C_NamePlate.GetNamePlateForUnit(unit)` calls in our Blizzard-fix module so future castbar/aura patches do not reintroduce the same crash path from addon-side code.
  - **Files Modified:** `Core/FixBlizzardBugs.lua`
- **Mouseover-cast support restored for secure unitframes:** Ported the local `AzeriteUI_Stock`/older `LibActionButton-1.0-GE` `checkmouseovercast` behavior into our action-button wrapper and refresh path, following the same secure-button attribute pattern used by ElvUI. Also aligned raid unit buttons with party-frame click registration (`RegisterForClicks("AnyUp")`) so secure raid frames present a proper click-cast surface.
  - **Files Modified:** `Components/ActionBars/Prototypes/ActionButton.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Nameplate mouseover-cast limitation documented:** Current oUF nameplates in this addon are instantiated as `PingableUnitFrameTemplate` buttons rather than `SecureUnitButtonTemplate`, unlike party/raid frames and GW2UI's secure XML unit frames. That means keyboard mouseover-cast on custom nameplates may still depend on Blizzard's underlying nameplate click surface, and would require a larger secure-frame architecture change rather than a small patch.
  - **Files Investigated:** `Libs/oUF/ouf.lua`, `Components/UnitFrames/Units/NamePlates.lua`
- **Future feature research logged (heal-predict/absorb overlays):** Reviewed local `ElvUI`, `GW2_UI`, and `Platynator` for health-bar-integrated incoming-heal / damage-absorb / heal-absorb visuals and documented the borrowable patterns in the feature docs instead of changing runtime behavior.
  - **Files Modified:** `Docs/PeerAddons-AurasHealth.md`, `Docs/Nameplate Feature Plan.md`
- **Future feature feasibility discussion added:** Compared peer overlay models against AzeriteUI's mirror/fake-fill/preview architecture and documented where implementation is realistic, where it conflicts with current bar rendering, and which frame types are lower-risk candidates.
  - **Files Modified:** `Docs/PeerAddons-AurasHealth.md`, `Docs/Nameplate Feature Plan.md`
- **Addon-wide feature comparison documented:** Mapped AzeriteUI's current feature surface from `TOC`/`Core`/`Components`/`Options`, compared it against the local `ElvUI` and `GW2_UI` module and settings surfaces, and documented practical borrowable features plus secure/hardening paths for future work.
  - **Files Modified:** `FEATURE_PLAN.md`, `Docs/Nameplate Feature Plan.md`

## 5.3.0-JuNNeZ (2026-03-08)

**Status:** Ready for release.

### Release Summary
- Release name: **The big nameplate rework**
- Version bump: `5.2.235-JuNNeZ-hotfix-20260308` -> `5.3.0-JuNNeZ`
- Changelog scope includes the nameplate rework plus the current `Options/OptionsPages/UnitFrames.lua` class-power option cleanup.

### Release Files Updated
- `AzeriteUI5_JuNNeZ_Edition.toc`
- `build-release.ps1`
- `CHANGELOG.md`

## 5.2.235-JuNNeZ (2026-03-08)

**Status:** Release candidate.

### Bug Fixes In Progress
- **Minimap right-click tracking reliability follow-up:** Retail path now uses a dedicated click handler overlay and tighter tracking-button discovery (`Tracking`, `TrackingFrame`, `MiniMapTrackingButton`, `MiniMapTracking`) with menu-visibility validation before fallback.
  - **Files Modified:** `Components/Misc/Minimap.lua`
- **Shaman classpower max-stack resolver hardening:** Added numeric fallbacks for Maelstrom Weapon aura stack/max retrieval and guarded classpower update max handling to prevent nil/invalid max values from breaking point updates.
  - **Root Cause:** Shaman classpower uses aura-driven stack data (`C_UnitAuras`) + spell max lookup (`C_Spell.GetSpellMaxCumulativeAuraApplications`) unlike other class powers using `UnitPowerMax`; invalid/non-numeric max could propagate into update loops.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Shaman classpower split by spec (Enhancement aura + Elemental power):** ClassPower now selects source by specialization: Enhancement keeps Maelstrom Weapon aura tracking (`UNIT_AURA`), while Elemental uses standard Maelstrom power (`UnitPower`/`UnitPowerMax`, `UNIT_POWER_UPDATE`). Also normalized high-max Maelstrom pools into the existing 10-point renderer for consistent visuals.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`, `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Classpower secret-number crash fix (`cur + 0.9`):** Hardened oUF classpower update path against WoW12 secret power payloads by normalizing unsafe `cur/max` to previous safe cached numeric values before arithmetic/comparisons.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Elemental Maelstrom builder-point model (DH-style behavior):** Elemental now maps Maelstrom power (0..max, e.g. 0..100) into explicit 0..10 classpower points before entering renderer logic, so point icons build/spend like the Devourer-style system while keeping Enhancement on aura-stack sourcing.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Elemental Maelstrom display mode toggle (Power Crystal vs Class Power Plates):** Added ClassPower options to enable Elemental Maelstrom display mode selection and choose between current power crystal behavior or classpower plate behavior. When classpower plate mode is selected, player power crystal display source is forced to mana for Elemental so mana remains in the crystal while Maelstrom uses class plates.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Elemental classpower visibility gate fix:** Decoupled Elemental classpower plate mode from the Enhancement-only `showMaelstrom` toggle so Elemental plates remain visible when classpower mode is selected.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Elemental classpower deep-path cleanup (old pathway removal):** Removed brittle Elemental point source assumptions in oUF classpower by adding secret-safe UnitPower fallback (`UnitPowerPercent` path) and relaxing strict event power-token gating for Elemental Shaman updates. This prevents stale/zero-only class plates when client reports non-standard/secret payloads.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Elemental classpower blink/despawn follow-up:** Normalized Elemental non-maelstrom `UNIT_POWER_UPDATE` payloads back to `MAELSTROM` before renderer dispatch and stopped forced point reset to zero when both raw/percent values are unreadable (preserve previous safe points instead).
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Enhancement classpower in-combat regression fix:** Restored real-time Enhancement Maelstrom updates by adding hybrid source fallback (aura -> power pool) and registering Shaman aura+power update events in aura mode. Also normalizes Shaman power update events to classpower type in update dispatch.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`
- **Retail-only Shaman classpower event/source cleanup:** Added safe Maelstrom value/max readers (`UnitPower`/`UnitPowerMax` + unmodified fallback), enabled `UNIT_POWER_FREQUENT` handling for Shaman classpower, and removed remaining brittle update assumptions that could stall Elemental point updates when crystal mode switched to mana.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`
- **Retail-only Elemental classpower secret-value fallback rework:** Replaced Elemental point resolver with aura-stack sourcing (auto-detected player aura stack source with cached spell/max), retained safe power fallback only when numeric values are available, and registered `UNIT_AURA` updates for Elemental path to reduce blink/despawn behavior while crystal is forced to mana.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`
- **Elemental aura-scan secret `spellId` crash fix:** Guarded aura scan spellID/max/applications filters with `issecretvalue` checks before any compare/range logic, preventing `attempt to compare local 'spellID' (a secret number value)` spam in classpower updates.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`
- **ElvUI-style classpower secret-visibility borrow (Elemental):** Updated classpower post-update to keep Maelstrom plates visible and reuse last safe values when current/max payload is unreadable, instead of auto-hiding on nil/secret paths.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Elemental classplate mirror-percent bridge (option 1):** Added classpower fallback to read the player power crystal mirrored/display percent (`__AzeriteUI_DisplayPercent`/`safePercent`/mirror texture percent) and quantize it into 10 class points when direct Elemental resource values are unreadable.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`
- **Elemental smooth-fill follow-up for 10-point plates:** Removed forced integer stepping in Elemental 0..10 conversion paths and updated Maelstrom plate rendering modes to consume fractional phase fill per point, so plates fill progressively instead of snapping full on first gain.
  - **Files Modified:** `Libs/oUF/elements/classpower.lua`, `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Elemental classplate path scrubbed; replaced with movable secondary resource bar:** Retired Elemental Shaman class plates and switched to a petbar-art secondary statusbar in `PlayerClassPowerFrame` (movable via `/lock`). Added clear crystal/bar split modes (`Crystal: Maelstrom | Bar: Mana` and `Crystal: Mana | Bar: Maelstrom`) and updated player crystal routing accordingly. Also constrained oUF Shaman classpower visibility back to Enhancement-only for plate rendering.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`, `Libs/oUF/elements/classpower.lua`
- **Elemental swap-bar pathway fix (visibility/activation):** Ensured Shaman `Power` element stays enabled, added specialization/talent/world refresh event hooks for `PlayerClassPowerFrame` update routing, and hardened early-spec detection so the secondary bar can appear reliably after reload/spec sync.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Elemental swap-bar anchor/value polish:** Set shaman swap-bar default/migrated anchor to `BOTTOMLEFT` with offsets matching in-game lock reference (X=375, Y=130), and added centered live resource value text inside the secondary bar for both mana and maelstrom modes.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Bossbar health text placeholder fix:** Updated `*:Health(true)` smart/full paths to prefer secret-safe formatted current/max health text and return empty string when no safe value exists, preventing visible `?` output.
  - **Files Modified:** `Components/UnitFrames/Tags.lua`
- **WoW12 CompactRaidFrameManager taint follow-up:** Removed `CompactRaidFrameManager_SetSetting("IsShown","0")` call from compact quarantine path to avoid protected `HideBase()` taint/`ADDON_ACTION_BLOCKED` during roster/EditMode refresh.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **Blizzard ActionButton secret-compare regression (`ActionButton.lua:609`) investigation started:** New report shows hidden stock `MultiBarBottomLeftButton*` still entering Blizzard `ActionButton_Update` with secret-number compare failure (`pressAndHoldAction` path). Preparing minimal hide-path taint rollback in Blizzard button compatibility layer.
  - **Files Targeted:** `Components/ActionBars/Compatibility/HideBlizzard.lua`
- **Blizzard ActionButton secret-compare follow-up (`ActionButton.lua:609`) minimal taint rollback applied:** Removed secure `SetAttribute("statehidden", true)` writes from hidden stock Blizzard action buttons. Buttons are still hidden, reparented, and event-unregistered, but we no longer mutate secure attributes on Blizzard button frames from addon code.
  - **Root Cause Hypothesis:** Writing secure attributes on Blizzard stock action buttons taints their later `ActionButton_Update` press/hold comparison path when WoW12 secret action payloads are present.
  - **Files Modified:** `Components/ActionBars/Compatibility/HideBlizzard.lua`

### Added Content
- **Game Menu skin module:** Added `GameMenuSkin` module and loader entry to apply AzeriteUI tooltip-style backdrop/button treatment to the ESC game menu.
  - **Files Modified:** `Components/Misc/GameMenu.lua`, `Components/Misc/Misc.xml`
- **Resting indicator visual cue:** Added resting-state icon prefix to info text for clearer at-a-glance status.
  - **Files Modified:** `Components/Misc/Info.lua`

## 5.2.234-JuNNeZ (2026-03-07)

**Status:** Release candidate.

### Bug Fixes In Progress
- **Player Alternate runtime gating fix:** Removed hard runtime dependency on `enableDevelopmentMode` in `UpdateEnabled()`. Devmode now gates enabling/discoverability only; already-enabled Player Alternate remains active when devmode is turned off.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerAlternate.lua`

## 5.2.233-JuNNeZ (2026-03-07)

**Status:** Release candidate.

### Bug Fixes In Progress
- **Actionbar shift-mod + dragonriding compatibility fix:** Updated override click bindings to use `Keybind` button token (`SetOverrideBindingClick(..., "Keybind")`) so shift-mod macro keybinds no longer hit mouse-only chat-link interception, while bar 1 dynamic paging/dragonriding continues using safe click routing.
  - **Files Modified:** `Components/ActionBars/Prototypes/ActionBar.lua`, `Components/ActionBars/Elements/PetBar.lua`, `Components/ActionBars/Elements/StanceBar.lua`
- **Minimap right-click tracking reliability follow-up:** Added retail tracking open-chain hardening + visibility validation, minimap click/mouse safeguards, and tooltip crafting-order count lookup fix.
  - **Files Modified:** `Components/Misc/Minimap.lua`
- **Player Alternate toggle sync follow-up:** Added explicit enabled-state synchronization so toggling player alternate cleanly re-enables/disables the main player module.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerAlternate.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Shaman classpower integration follow-up:** Added Maelstrom visibility toggle + 10-point renderer support and removed talent-spell gate in oUF classpower detection.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Options/OptionsPages/UnitFrames.lua`, `Libs/oUF/elements/classpower.lua`, `Libs/oUF_Classic/elements/classpower.lua`

## 5.2.231-JuNNeZ (2026-03-07)

**Status:** In progress (release with known WoW12 edge cases).

### Bug Fixes In Progress
- **Guarded Blizzard CompactUnitFrame aura path against WoW 12 secret/forbidden aura payloads:** Added safe wrappers for `AuraUtil.IsBigDefensive`, `C_UnitAuras.AuraIsBigDefensive`, and a fail-safe wrapper around `CompactUnitFrame_UpdateAuras` that suppresses repeated error loops and hides Blizzard aura containers on failure.
  - **Files Modified:** `Core/FixBlizzardBugs.lua`
- **Hardened deprecated portrait compatibility shim against nil/broken upstream implementations:** Added nil-safe `SetPortraitToTexture` fallback wrapper (`pcall` + `SetTexture`) when the deprecated API is missing.
  - **Files Modified:** `Core/Compatibility.lua`
- **Tooltip/MoneyFrame WoW 12 secret-value follow-up:** Added active `OnInitialize` guards for `SetTooltipMoney` + `MoneyFrame_Update` (safe fail/Hide fallback) and moved compact aura guards to active code path (previous copies were in a disabled block). Tooltip module is no longer hard-disabled; it now runs with secret-safe behavior and skips secure backdrop mutations under secret-value clients.
  - **Files Modified:** `Core/FixBlizzardBugs.lua`, `Components/Misc/Tooltips.lua`
- **Tooltip skin restoration in secret-value clients (ElvUI/GW2UI/DiabolicUI pattern):** Re-enabled `SharedTooltip_SetBackdropStyle` hook in secret-value mode, but only applies AzeriteUI backdrop when tooltip width/height resolve as non-secret (with cached fallback), and added protected backdrop application (`pcall`) with Blizzard backdrop restore on failure.
  - **Files Modified:** `Components/Misc/Tooltips.lua`
- **Tooltip deep-scan hardening follow-up (DiabolicUI-aligned):** Reworked tooltip backdrop cache to avoid `SetAllPoints()` secret-size inheritance, wrapped backdrop mixin callbacks (`OnBackdropSizeChanged`, `ApplyBackdrop`, `SetupTextureCoordinates`) and frame-level sync in `pcall`, hardened default anchor path (forbidden/map-parent guards + protected placement), and guarded `TooltipDataProcessor` callbacks + statusbar theme updates to prevent tooltip-skin taint/error cascades while keeping AzeriteUI tooltip skin enabled.
  - **Files Modified:** `Components/Misc/Tooltips.lua`
- **Top-right buff cancel regression fix:** `AzeriteAuraTemplate` did not register right-clicks, so secure `cancelaura` action never fired for player buffs. Added explicit secure click registration (`RightButtonUp,RightButtonDown`) matching ElvUI/GW2UI pattern for mainline.
  - **Files Modified:** `Components/Auras/AuraTemplates.xml`
- **Nameplate/CUF secret-mode taint reduction follow-up (ElvUI/GW2UI-aligned):** Stopped patching Blizzard nameplate unitframes in secret mode (no `clearClutter` mutations), and removed live WoW12 `CompactUnitFrame` rewrite call from `FixBlizzardBugs.OnInitialize` to avoid tainting Blizzard secure CUF/NamePlate flows.
  - **Files Modified:** `Components/UnitFrames/Units/NamePlates.lua`, `Core/FixBlizzardBugs.lua`
- **Communities protected-call taint follow-up (`SetAvatarTexture`):** Stopped force-overriding global `SetPortraitToTexture`; compatibility shim now only defines deprecated APIs when missing. This avoids AzeriteUI-owned wrapper execution inside secure Blizzard Communities avatar paths.
  - **Files Modified:** `Core/Compatibility.lua`
- **Blizzard ActionButton secret-taint follow-up (`pressAndHoldAction`):** LAB secure snippet now always sets/reset `pressAndHoldAction` explicitly and clears `typerelease` when not applicable, preventing stale press-hold state from leaking into update comparisons.
  - **Files Modified:** `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Hidden stock action button isolation:** When hiding Blizzard buttons, we now unregister their events and set `statehidden=true` out of combat to stop stale Blizzard update paths from running behind AzeriteUI bars.
  - **Files Modified:** `Components/ActionBars/Compatibility/HideBlizzard.lua`
- **Healthbar spark removal + AzUI Color Picker compatibility follow-up:** Removed custom player/target health spark attachments (spark no longer rendered), and added an AceAddon compatibility alias so external tools requesting `AceAddon:GetAddon("AzeriteUI")` resolve correctly when running `AzeriteUI5_JuNNeZ_Edition` (restores AzUI health color picker integration path).
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`, `Components/UnitFrames/Units/Target.lua`, `Core/Core.lua`
- **Talent/spec-change castbar forbidden-table fix (`CastingBarFrame.lua:GetTypeInfo`):** Added WoW12 guards for `GetTypeInfo` on casting bar mixins/instances (including `OverlayPlayerCastingBarFrame`) with safe fallback type-info table when Blizzard returns forbidden data. Also removed taint-prone `UnregisterAllEvents()+Hide()` suppression of Blizzard player/pet castbars in oUF path; replaced with non-invasive alpha suppression to keep Blizzard castbar state machine intact during specialization/talent transitions.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`, `Libs/oUF/elements/castbar.lua`, `Components/UnitFrames/Units/PlayerCastBar.lua`
- **Target power value toggle follow-up:** Fixed target power visibility logic that incorrectly treated `cur == 0` as “no power pool,” which hid the target power bar/value even when a valid pool existed. Also added WoW12-safe fallback formatting for power text/percent using cached `safeCur/safeMax` when direct `UnitPower`/`UnitPowerPercent` values are secret/unreadable.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`
- **WoW12 hybrid stabilization pass (castbar + EditMode/CUF):** Protected `GetTypeInfo` retrieval in castbar OnEvent guards, added centralized WoW12 Blizzard-frame quarantine for Compact frames + target/focus/boss spellbars, removed duplicate oUF castbar suppression path, and routed party/raid WoW12 disable branches through the quarantine helper.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`, `Libs/oUF/elements/castbar.lua`, `Components/UnitFrames/Units/PlayerCastBar.lua`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **WoW12 follow-up (EditMode target+CUF warning cleanup):** Kept Blizzard target/focus/boss spellbars on original parent while suppressing them (avoid parent-assumption nil warnings in `TargetFrame.lua`), added safe wrapper for `CompactUnitFrame_GetRangeAlpha`, and hooked Compact frame lifecycle setup (`CompactUnitFrame_SetUpFrame/SetUnit`, `CompactRaidGroup_InitializeForGroup`) so late-created Compact frames are quarantined immediately.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **WoW12 follow-up (nameplate/party spillover guard):** Narrowed Compact lifecycle quarantine hooks to party/raid/arena frame patterns only (exclude nameplates), added safe wrappers for `AuraUtil.IsBigDefensive` / `C_UnitAuras.AuraIsBigDefensive`, and guarded party health/text update functions (`PartyMemberHealthCheck`, `UpdateTextStringWithValues`) against secret-value compare failures.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **WoW12 follow-up (nameplate aura API hardening):** Added guarded wrappers for `C_UnitAuras.GetUnitAuras` and `C_UnitAuras.IsAuraFilteredOutByInstanceID` with safe defaults on invalid/secret payloads, plus a protected wrapper around `CompactUnitFrame_UpdateAuras` to suppress crash loops when Blizzard aura data is unreadable.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **WoW12 follow-up (4532 taint rollback + secure-hide fix):** Rolled back taint-prone global wrappers (`CompactUnitFrame_*`, `UpdateTextStringWithValues`, `PartyMemberHealthCheck`, `C_UnitAuras.*`) from `FixBlizzardBugsWow12`, and restricted quarantine `Show->Hide` hook usage to non-protected frames only (prevents secure `Frame:Hide()` blocks from `SecureGroupHeaders`). Also added in-combat protected-child skip in quarantine subelement event teardown.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **WoW12 follow-up (4533 external-pattern alignment: ElvUI/GW2UI/DiabolicUI/FeelUI):** Removed remaining shared Blizzard rewrite paths in `FixBlizzardBugsWow12` (no global `CastingBarMixin` guards, no `AuraUtil.IsBigDefensive` override), removed reusable frame `Show->Hide` quarantine hooks, and stopped quarantining anonymous party/arena pool members. Quarantine now targets explicit Blizzard party/raid/arena frame names plus deterministic hide/reparent, matching external UI behavior that avoids poisoning nameplate hit-test/aura flows.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **Class power clickthrough toggle:** Added `clickThrough` setting for `PlayerClassPowerFrame` with a dedicated click-blocker overlay; disabling clickthrough now blocks right-click from falling through to player unit menu.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Minimap right-click tracking deep-sweep (moot path removal):** Removed the experimental full-map click-handler/proxy path and restored deterministic minimap `OnMouseUp` handling. Retail tracking now tries `Tracking.Button:OpenMenu()` first, then `MenuUtil` menu-generator fallback, then legacy dropdown fallback.
  - **Files Modified:** `Components/Misc/Minimap.lua`
- **Class power click-through reliability follow-up:** Simplified click blocking to blocker-only behavior (removed direct ClassPower mouse API mutations) and updated toggle wording for explicit ON/OFF behavior.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Class power click-through deep-hardening:** Corrected clickthrough option default rendering (`nil` now shows ON/true), added scale-aware blocker sizing against `UIParent`, and synchronized blocker geometry on `SetPoint`/`SetSize`/`SetScale`.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Minimap right-click tracking deep-hardening:** Added `Minimap:EnableMouse(true)` safeguard, kept deterministic `OnMouseUp` path, added retail hidden-proxy `MiniMapTrackingButtonMixin` fallback when stock tracking button paths fail, and added classic fallback to `MiniMapTrackingDropDown` when custom classic menu is unavailable.
  - **Files Modified:** `Components/Misc/Minimap.lua`
- **Minimap mail tooltip cleanup (latent bug):** Fixed undefined `mail.countInfos` reference in `Mail_OnEnter` by resolving count info from module mail state/frame context.
  - **Files Modified:** `Components/Misc/Minimap.lua`
- **Minimap tracking opener reliability follow-up (deep path audit):** Removed false-positive "success" path when `OpenMenu()`/mouse handlers return without showing a menu, added explicit menu-visibility checks before short-circuiting, and added `OnClick` fallback in the retail tracking open chain so hidden stock tracking buttons no longer swallow the right-click path.
  - **Files Modified:** `Components/Misc/Minimap.lua`
- **Class power click-through geometry reliability follow-up (parent-chain sync):** Added owner-frame sync hooks (`SetPoint/SetSize/SetScale/SetFrameLevel/SetFrameStrata/OnSizeChanged/OnShow`) plus `ClassPower:SetParent` sync to keep the click-blocker aligned when parent movement/scale changes occur outside direct classpower mutations.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`
- **Actionbar chat-link regression fix:** Restored modified-click spell linking on LibActionButton buttons (`Shift+Click`/`CHATLINK`) by adding a guarded chat-link click path in wrapped `OnClick` and resolving spell links from action/spell/macro states before inserting into active chat edit box.
  - **Files Modified:** `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`

### Known Bugs (Under Investigation)
- **Compact/Arena aura defensive edge case:** Rare forbidden-table error in Blizzard `AuraUtil.IsBigDefensive` during Compact/Arena aura updates.
- **Compact party color edge case:** Rare secret-value compare in Blizzard `CompactUnitFrame_UpdateHealthColor` during EditMode/party refresh.


## 5.2.220-JuNNeZ (2026-03-05)

**Status:** Fixing post-5.2.219 regression.

### Bug Fixes In Progress
  - **Files Modified:** `Options/Options.lua`


## 5.2.221-JuNNeZ (2026-03-06)

**Status:** Secret-value bug fix.

### Bug Fixes In Progress
- **Fixed BugSack error in Player.lua (PostUpdateColor):** Defensive check for secret value 'max' before comparison/arithmetic. Fallback: percent=1 if secret. Prevents taint crash on WoW 12+ secret values.
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`
- **Removed deprecated power/threat debug surfaces from `/azdebug` menu path:** Unregistered `/azdebugtarget`, removed power/orb/target fill menu commands from help and parser, and removed related buttons from the debug frame UI.
  - **Files Modified:** `Core/Debugging.lua`
- **Player power crystal color/overlay cleanup:** Re-added `crystalOrbAccent` toggle, kept only `default`/`class` color source behavior, switched default crystal color back to stock blue base, and changed accent handling to a gold overlay pass instead of recoloring the full crystal.
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Removed target Power Crystal Lab options from UnitFrame settings:** Hid the target power crystal lab controls from options to avoid duplicate/conflicting power configuration surfaces.
  - **Files Modified:** `Options/OptionsPages/UnitFrames.lua`
- **Power crystal stability/spark follow-up:** Added mirror-percent texture sampling opt-out flag support and enabled it for player crystal, pixel-aligned crystal sizing in texture updates, and restored a visible crystal spark texture update path.
  - **Files Modified:** `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Player.lua`
- **Player crystal fakefill/overlay correction:** Added a dedicated player power `FakeFill` texture and now drive crystal spark/overlay from fakefill percent instead of the hidden native statusbar. Accent overlay now anchors to fakefill/native texture bounds and uses matching texcoords to prevent oversized gold overlays.
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`
- **Crystal color mode cleanup (token-aware):** `default` now uses stock `PowerBarColors` by active power token (AzeriteUI_stock behavior), and `new` uses an alternate token-based palette. Legacy `class` values auto-map to `new` for compatibility.
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Player crystal accent rollback + absorb text source hardening:** Removed the player crystal gold accent overlay path entirely (options + runtime code) and switched player absorb text sourcing to prefer statusbar/fallback cached values while hiding output when the resolved numeric value is `<= 0`.
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`, `Components/UnitFrames/Tags.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Absorb `(0)` text suppression:** Hardened absorb tag output filtering so zero-like absorb payloads are always hidden, including unresolved secret-value fallback paths that could previously surface as `(0)`.
  - **Files Modified:** `Components/UnitFrames/Tags.lua`
- **Player crystal/threat stock realignment:** Restored player power crystal + case + threat geometry to `AzeriteUI_Stock` dimensions/positions, removed legacy tuned offset defaults, and removed the hardcoded `+28` threat-case shift. Also reapply player aura size/anchor from layout in `UnitFrame_UpdateTextures` to keep aura placement aligned after settings refresh.
  - **Files Modified:** `Layouts/Data/PlayerUnitFrame.lua`, `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Fixed secret-string crash in absorb zero filter:** `IsZeroLikeText()` now guards `issecretvalue(value)` and uses protected string operations (`pcall(string.gsub/lower, ...)`) so secret strings no longer trigger `attempt to index local 'value'` in `Tags.lua`.
  - **Files Modified:** `Components/UnitFrames/Tags.lua`
- **Player crystal statusbar + anchor regression cleanup:** Reworked player crystal runtime placement to stock-style geometry flow (no center-shift compensation), restored stock orientation handling in both creation and update paths, and normalized crystal/threat anchor defaults/resets to `FRAME` to match `AzeriteUI_Stock` anchoring. This removes the non-stock anchoring drift introduced during spark/accent iterations.
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`
## 5.2.225-JuNNeZ (2026-03-06)

**Status:** Patch release for secret-value bug fix and power crystal improvements.

### Bug Fixes
- Defensive check for secret value 'max' in Player.lua (PostUpdateColor).
- Removed deprecated power/threat debug surfaces from `/azdebug` menu.
- Player power crystal color/overlay cleanup and accent handling improvements.
- Removed target Power Crystal Lab options from UnitFrame settings.
- Power crystal stability/spark follow-up and fakefill/overlay correction.

### Files Modified
- Components/UnitFrames/Units/Player.lua
- Core/Debugging.lua
- Options/OptionsPages/UnitFrames.lua
- Components/UnitFrames/Functions.lua
## 5.2.219-JuNNeZ (2026-03-05)

**Status:** Fixing post-release regression.

### Bug Fixes In Progress
- **Fixed GetModule nil crash on retail:** Removed `WoW11\WoW11.xml` from TOC file. Classic/Vanilla support was fully dropped in 5.2.217, but the WoW11 folder was still being loaded on retail, causing "attempt to call method 'GetModule' (a nil value)" error in WoW11/Misc/Options.lua line 30. The entire WoW11/ folder was being inappropriately executed on retail WoW 12 where `ns.WoW11` is never set.
  - **Root Cause:** Incomplete cleanup of 5.2.217 breaking change. WoW11.xml was no longer needed but still referenced in the main TOC.
  - **Files Modified:** `AzeriteUI5_JuNNeZ_Edition.toc`

---

## 5.2.218-JuNNeZ (2026-03-05)

**Status:** Shipped and released.

### Bug Fixes Shipped
- **Fixed enemy names not showing in dungeons (nameplates + target frame):** In WoW 12+ dungeon combat, `UnitName()` returns secret values for NPC enemies (`SecretWhenUnitIdentityRestricted`). Also `UnitCanAttack()`/`UnitCanAssist()` can return secrets, causing hostile mobs to be misclassified and their names hidden.
  - **Root Cause:** `SafeUnitName()` in Tags.lua rejected secret name strings → tag returned `""` → no name text. Secret `canAttack`/`canAssist` → fell to `nil` → `self.canAttack = false` → visibility logic hid the name.
  - **Fix (Tags.lua `*:Name` tag):** When `SafeUnitName()` returns nil, now calls raw `UnitName()` and returns the secret string directly. oUF's `SetFormattedText` accepts secret string values per WoW 12 API. Caches non-secret names for GUID-matched fallback.
  - **Fix (NamePlates.lua `canAttack`/`canAssist`):** When both are secret, falls back to `UnitReaction("player", unit)` to determine hostility. Reaction <= 4 = hostile (canAttack=true), >= 5 = friendly (canAssist=true).
  - **Fix (NamePlates.lua `SetText` fallback):** After tag update, checks `GetText()` with `issecretvalue()` to avoid `==` comparison on secrets. If text is empty, calls `self.Name:SetText(UnitName(unit))` directly — `SetText` accepts secret strings.
  - **Fix (Target.lua `SetText` fallback):** Same pattern as nameplates. Also wrapped `UpdateTag()` in `pcall()` to handle potential secret propagation errors gracefully.
  - **Fix (Target.lua `TargetIndicator_Update`):** All `UnitCanAttack`/`UnitIsUnit`/`UnitExists` calls now guarded with `issecretvalue()`. Falls back to `UnitReaction` for hostility when `canAttack` is secret.
  - **Fix (NamePlates.lua secret guard ordering):** Moved ALL `issecretvalue` guards together before the `UnitReaction` fallback and `passiveWorldObjectLike` calculations, preventing comparisons on unsanitized secret values.
  - **Files Modified:** `Components/UnitFrames/Tags.lua`, `Components/UnitFrames/Units/NamePlates.lua`, `Components/UnitFrames/Units/Target.lua`
  - **WoW 12 Secret Value Rule Applied:** `type()` is safe. `issecretvalue()` is safe. `SetText()`/`SetFormattedText()` accept secrets. `==`/`~=` on secrets is NOT safe. `string_len()`/`AbbreviateName()` on secrets is NOT safe.
  - **Testing Required:** Enter a dungeon, engage enemies, verify nameplate names show. Target hostile mobs, verify target frame name shows. Check BugSack for errors. Test with `/azdebug dump target`.
- **Fixed ExplorerMode secret value crash:** "attempt to perform arithmetic on local 'min' (a secret number value)" error in ExplorerMode.CheckPower() when checking player mana power. Added secret value guards using `issecretvalue()` check before arithmetic operations on power values. When secret values are detected, power check is skipped (defaults to non-low-power state).
  - **Files Modified:** `Core/ExplorerMode.lua` (CheckPower function)
  - **Root Cause:** WoW 12+ returns secret values for player unit power data. Direct arithmetic/comparison on secret values causes taint error.
  - **Testing Required:** Reload in-game as maximum level character (Druid/Evoker to hit both mana code paths), verify no errors in console.
- **Fixed BtWQuests compatibility error:** "attempt to call upvalue 'original_SetPortraitToTexture' (a nil value)" in compatibility shim for deprecated `SetPortraitToTexture`.
  - **Files Modified:** `Core/Compatibility.lua` (deprecated API shim block)
  - **Root Cause:** On current builds, `original_SetPortraitToTexture` can be nil, but fallback shim always called it.
  - **Fix Applied:** Added nil-safe fallback to `texture:SetTexture(asset)` when original API is unavailable.
  - **Testing Required:** Reload with BtWQuests enabled and open BtWQuestsFrame, verify no `Compatibility.lua:90` errors.
- **Restored target frame to stock configuration (commit `c3d7e97`):** Reverted experimental size changes on target frame power crystal.
  - **Restored Values:**
    - Power crystal sizes: 90x90 → **80x80** (both PowerBarSize and PowerBackdropSize)
  - **Files Modified:** `Layouts/Data/TargetUnitFrame.lua`
  - **Rationale:** Aligns target frame with stock AzeriteUI configuration.
  - **Testing Required:** `/reload`, verify target frame power crystal displays at stock 80x80 size.
- **Shipped player frame power crystal alignment baseline:** Baked tested defaults for crystal art alignment and sizing so the crystal, frame, and threat glow fit correctly without manual slider tuning.
  - **Files Modified:** `Layouts/Data/PlayerUnitFrame.lua`, `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`
  - **Default Offsets Set:**
    - Widget: X `-76`, Y `-49`
    - Frame: Y `50`
    - Threat bar: X `76`, Y `52`
    - Threat case: Y `-34`
  - **Sizing Baseline Set (Novice/Hardened/Seasoned):**
    - Power bar: `231x223`
    - Backdrop/threat bar: `208x210`
    - Foreground case/threat case: `218x104`
  - **Reset Behavior Updated:** Reset actions now restore these tuned values as the default baseline.
- **Shipped SafeCall return passthrough fix:** Extended `SafeCall()` in debug utilities to return a fifth value to avoid dropping fields in debug dump pipelines.
  - **Files Modified:** `Core/Debugging.lua`

---

## 5.2.217-JuNNeZ (2026-03-04)

**Status:** Release ready.

### Breaking Changes
- **Dropped Classic/Vanilla support:** Removed `AzeriteUI5_JuNNeZ_Edition_Vanilla.toc`. Addon now targets Retail (Midnight/WoW 12+) only. Classic WoW code removal planned for future versions.

### CurseForge Configuration Fixed
- **Added JuNNeZ Edition project ID:** Now uses CurseForge project ID `1477618` to prevent conflicts with original AzeriteUI (ID: 298648).
- **Removed original identifiers:** Stripped `X-Curse-Project-ID: 298648` and `X-Wago-ID: R4N2PZKL` from TOC.
- **Updated folder references:** All IconTexture paths now correctly use `AzeriteUI5_JuNNeZ_Edition` folder name.
- **Added edition attribution:** TOC includes `X-Edition: JuNNeZ Fan Edition - Not affiliated with original AzeriteUI`.
- **Fixed packaging:** Updated `.pkgmeta` and GitHub Actions workflow for proper multi-version detection.
- **Renamed TOC files:** Main TOC renamed from `AzeriteUI.toc` to `AzeriteUI5_JuNNeZ_Edition.toc` to match addon folder name (required for WoW recognition).

### Bug Fixes Shipped
- **Fixed nameplate unit names in dungeons:** Hostile enemy names now display on nameplates in dungeon/instance content. Previously overly restrictive visibility logic only showed names when mousing over or in combat.

### Files Modified
- **TOC:** `AzeriteUI5_JuNNeZ_Edition.toc` (renamed, version bumped to 5.2.217)
- **Packaging:** `.pkgmeta`, `.github/workflows/release.yml`, `build-release.ps1`
- **Nameplate fix:** `Components/UnitFrames/Units/NamePlates.lua`
- **Documentation:** `VERSION_CHECKLIST.md`, `RELEASE_WORKFLOW.md`, `CHANGELOG.md`

---

## 5.2.216-JuNNeZ (2026-03-03)

**Status:** Shipped and released.

### Features Shipped
- Demon Hunter Devourer soul fragments 10-point display system
- 4 soul fragments display modes (Alpha, Gradient, Recolor, Stacked 5-Point)
- Show Soul Fragments visibility toggle in Options → Unit Frames → Class Power

### Bug Fixes Shipped
- Fixed ActionButton taint (`ADDON_ACTION_BLOCKED` errors from secure attribute writing)

### Libraries Updated
- Loaded LibEditModeOverride-1.0 (was bundled but not included in load order)
- Updated LibEditModeOverride-1.0 with upstream CooldownViewer slider fix (commit 39f30e5)

### Known Issues (Documented)
- **Edit Mode taint errors:** Opening/closing Edit Mode causes multiple taint errors. Deep investigation planned for next version.
- **Mana orb:** Mana orb display still under investigation for WoW 12.
- **Target castbar crop:** Some non-self target casts may show incorrect fill behavior.

### Development Notes
- **Experimental code removed before release:** All combo point position sliders, soul fragments bar adjustment sliders, texture flip/rotation/tiling controls, and debug commands (`/azdebug power refresh`) were implemented during development but removed from the final release build as they were not production-ready.
- **Release output:** `AzeriteUI-5.2.216-JuNNeZ-Retail-03-03-2026.zip` (9.87 MB)
- **Build date:** 2026-03-03 22:45

### Unreleased Fixes (In Progress)

2026-03-04 00:00 (Player power crystal size sync, rolled back)

Issue:
- Player frame power statusbar could be a different size than the power background asset.

Root Cause:
- Player power bar size and power backdrop size were driven by separate size/scale paths.

Fix:
- Initial attempt synced player statusbar to backdrop dimensions.
- Change was rolled back after testing because it altered crystal attachment/alignment behavior in player frame.
- Restored original player power sizing path to preserve legacy attachment points.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — reverted player power-size sync to restore original attachment

Testing:
1. `/reload`
2. Enter world with AzeriteUI enabled
3. Observe player frame power crystal and its background at idle/combat
4. Adjust power-related scale sliders and verify bar/backdrop remain matched

Status: Rolled Back (needs safer follow-up)

2026-03-04 00:15 (Player power crystal size match with anchor compensation)

Issue:
- Player power fill remained smaller than the backdrop art.

Root Cause:
- Raw size sync changed attachment behavior because dependent anchor offsets were tuned for the legacy bar size.

Fix:
- Player power bar now uses backdrop dimensions for width/height.
- Added anchor compensation to preserve crystal attachment behavior when size delta is applied.
- Added matching compensation for power case and power threat overlays to prevent drift.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — size/anchor compensation for player power crystal and related overlays

Testing:
1. `/reload`
2. Verify player power fill matches backdrop art dimensions
3. Verify crystal casing/threat overlays remain attached to the same visual location
4. Enter/leave combat and recheck alignment

Status: Ready for Test

[2026-03-10] Iteration: Add one-time classpower anchor migration for previously affected installs

Request:
- Make the update move classpower back to the correct place for users who already saved the bad default from the previous release.

Plan:
- Detect only the exact old non-Shaman bad generated default anchor (`BOTTOMLEFT`, `-223`, `-84` at saved scale).
- Rewrite that one case back to `CENTER`.
- Leave user-moved `/lock` positions untouched.

Applied fix:
- `Components/UnitFrames/Units/PlayerClassPower.lua`
  - Added `defaultAnchorHotfixMigrated` profile flag.
  - Added a one-time migration helper that only matches the old bad generated non-Shaman classpower default from the previous release.
  - Rewrites that single case from `BOTTOMLEFT` back to `CENTER` and immediately refreshes both the frame and `/lock` anchor.

Testing:
1. Update from the affected previous release with an untouched bad non-Shaman classpower position.
2. `/reload`
3. Confirm classpower snaps back to the intended centered location.
4. Confirm manually moved `/lock` positions do not get overwritten.

Status: Ready for Test

[2026-03-10] Iteration: Investigate classpower anchor drift on profile reset/copy and /lock

Request:
- Check whether class power can move out of frame for some users after reinstall, profile reset/copy, or while viewing `/lock`.

Investigation:
- Traced `Components/UnitFrames/Units/PlayerClassPower.lua` through `Core/MovableFrameModulePrototype.lua`.
- Confirmed fresh profile defaults are replayed directly from `db.profile.savedPosition` during profile copy/reset.
- Confirmed baseline versions `5.2.212` and pre-shaman update `5.2.233` used `CENTER` for classpower defaults.
- Current code had switched all fresh classpower defaults to `BOTTOMLEFT`, which can replay from the wrong origin for non-Shaman profiles.

Applied fix:
- Restored `CENTER` as the generated default anchor point for non-Shaman classpower profiles.
- Kept the Shaman Elemental swap-bar path on `BOTTOMLEFT`.
- Synced the one-time Shaman anchor migration with `/lock` by calling both `UpdatePositionAndScale()` and `UpdateAnchor()` after rewriting `savedPosition`.

Testing:
1. `/reload`
2. Reset/copy profile with `/lock` open on a non-Shaman class and confirm classpower stays in the expected player-center position.
3. Test Elemental Shaman once to confirm the migrated swap-bar anchor still lands near the player frame and the `/lock` anchor follows it.

Status: Ready for Test

---

Date: 2026-03-08
Area: Nameplates - slider/runtime scale consistency audit

Problem:
- After the hostile target-scale fix, other slider paths still had inconsistent fallback/default logic.
- Some values shown as `100%` in options could resolve to different runtime baselines when profile data was missing or stale.

Findings:
- `profile.scale` in `Components/UnitFrames/Units/NamePlates.lua` could fall back to `1` at runtime even though the normalized UI default for `Nameplate Scale (%)` is `2.0`.
- Friendly name-only font scale could fall back to `1` in runtime visuals even when the UI baseline/default is `2.5`.
- Additive target-scale sliders allowed `0` at runtime after the previous fix, but the options UI still forced a minimum of `50`, making "no target bump" impossible from the slider.

Fix:
- Added a shared `GetValidatedProfileScale(value, default, allowZero)` helper in `Components/UnitFrames/Units/NamePlates.lua`.
- Converted all nameplate scale accessors to use explicit shared defaults instead of mixed literals/fallbacks.
- Fixed runtime baseline fallback for:
  - global nameplate scale
  - friendly scale
  - enemy scale
  - friendly target bump
  - hostile target bump
  - friendly name-only target bump
  - friendly name-only font scale
- Updated additive target-scale sliders in `Options/OptionsPages/Nameplates.lua` to use `0..200` so:
  - `100` still means the intended default bump
  - `0` now means no extra target bump
  - the UI matches runtime semantics
- Kept multiplicative/base scale sliders at `50..150`.

Validation:
- `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
- `luac -p 'Options/OptionsPages/Nameplates.lua'`

Testing:
1. `/reload`
2. Verify untargeted plates keep the same baseline size before and after profile reset.
3. Set each target-scale slider to `0` and confirm no extra target-size jump.
4. Set each target-scale slider back to `100` and confirm the intended default bump returns.
5. Toggle friendly name-only mode and confirm the name font keeps its expected larger default scale.

Status: Ready for Test

---

Date: 2026-03-08
Area: Nameplates - hostile target scaling regression

Problem:
- Enemy nameplates could become smaller when targeted instead of larger.
- This was intermittent from the user perspective because the result depended on the untargeted relation scale multiplied by a target scale value below `1`.

Cause:
- In `Components/UnitFrames/Units/NamePlates.lua`, hostile/friendly target scale settings were being treated as raw final multipliers.
- After the recent slider normalization work, defaults like `0.5` now represent a `50%` target bump in the UI model, but runtime still interpreted them as "scale to 50%".
- That made targeted enemy plates smaller whenever `enemyTargetScale` was less than `1`.

Fix:
- Changed target-scale application to additive bump semantics:
  - target scale now applies as `baseScale * (1 + targetScaleSetting)`
- Updated all target-scale accessors to allow `0` as a valid value, so `0` now means "no extra target bump" instead of being discarded.
- Updated slider descriptions in `Options/OptionsPages/Nameplates.lua` to describe these as additional target scale values, matching runtime behavior.

Validation:
- `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
- `luac -p 'Options/OptionsPages/Nameplates.lua'`

Testing:
1. `/reload`
2. Target hostile units at several distances and confirm targeting never shrinks the plate.
3. Set hostile target scale to `0` and confirm no target-size jump.
4. Increase hostile target scale and confirm only a positive bump is applied.

Status: Ready for Test

[2026-03-08] Iteration: Friendly player nameplates name-only option (pre-change)

Issue:
- Request to hide friendly player world nameplate healthbars while still showing names in class colors.

Plan:
- Add a Nameplates profile toggle for friendly-player "name only".
- Keep behavior scoped to friendly player nameplates only (not PRD, not NPCs, not object-like plates).
- Hide healthbar visuals/value and force visible class-colored names when toggle is enabled.

Status: In Progress

[2026-03-08] Iteration: Friendly player nameplates name-only option (post-change)

Update:
- Components/UnitFrames/Units/NamePlates.lua
  - Added profile default `hideFriendlyPlayerHealthBar = false`.
  - Added helpers:
    - `IsFriendlyPlayerNameOnlyEnabled()`
    - `ShouldUseFriendlyPlayerNameOnly(self)`
    - `SetNameColorForUnit(self, db)`
  - Name-only mode now applies to friendly player world nameplates:
    - hides health bar/backdrop/value
    - keeps name visible
    - colors name by class
  - Name color now safely falls back to configured `db.NameColor` when class color is unavailable.
- Options/OptionsPages/Nameplates.lua
  - Added toggle:
    - `Hide friendly player healthbars (name only)`

Testing:
1. `/reload`
2. Options -> Nameplates -> enable `Hide friendly player healthbars (name only)`.
3. In world content with friendly players nearby:
   - verify friendly player nameplates show name only (no health bar)
   - verify names are class-colored
4. Verify hostile/enemy plates and friendly NPC plates are unchanged.
5. Disable option and verify friendly player healthbars return with normal name color behavior.

Status: Ready for Test

[2026-03-08] Iteration: Tracking open false-positive fix (double-click sound, no menu)

Issue:
- User reports two quick click sounds on minimap right-click, but no tracking menu.

Likely Cause:
- Tracking open path treated successful function calls as success even when no menu became visible.
- This can produce click sounds without a usable menu.

Update:
- `Components/Misc/Minimap.lua`
  - Added strict menu-visibility verification (`IsTrackingMenuVisible`) after each open attempt.
  - Open attempts now only succeed when menu is actually shown.
  - Retail order changed to proxy-first, then live tracking button fallback.
  - Added Blizzard `Minimap_OnClick(..., "RightButton")` fallback with visibility check.
  - Removed forced tracking open click sounds from our path (prevents false audio feedback).

Validation:
- `luac -p Components/Misc/Minimap.lua` passed.

Testing:
1. `/reload`
2. Right-click minimap once.
3. Verify tracking menu appears (not just click sound).
4. Toggle at least one tracking entry and reopen menu to confirm interactivity.

Status: Ready for Test

[2026-03-08] Iteration: WoW12 CompactRaidFrame HideBase protected-call block (pre-change)

Issue:
- BugSack captured:
  - `[ADDON_ACTION_BLOCKED] AddOn 'AzeriteUI5_JuNNeZ_Edition' tried to call the protected function 'CompactRaidFrameContainer:HideBase()'`
  - Stack roots in `Core/FixBlizzardBugsWow12.lua` `QuarantineCompactFrames()` at:
    - `CompactRaidFrameManager_SetSetting("IsShown", "0")`
    - then Blizzard `CompactRaidFrameManager_UpdateContainerVisibility` -> `CompactRaidFrameContainer:HideBase()`.

Scope:
- Error #1 is AzeriteUI-owned and addressed in this pass.
- Error #2 (`KeyMaster`) and Error #3 (`TroveTally`) are third-party addon secret-value compares and not modified here.

[2026-03-08] Iteration: WoW12 CompactRaidFrame HideBase protected-call block (post-change)

Update:
- `Core/FixBlizzardBugsWow12.lua`
  - In `QuarantineCompactFrames()`, removed the direct call to:
    - `CompactRaidFrameManager_SetSetting("IsShown", "0")`
  - Kept quarantine behavior via direct frame suppression/reparenting only (`QuarantineFrame(...)` paths).

Why:
- The manager setting path can invoke Blizzard visibility updates that hit protected
  `CompactRaidFrameContainer:HideBase()` during restricted state transitions, which causes
  `ADDON_ACTION_BLOCKED` even when wrapped in `pcall`.

Testing:
1. `/reload`
2. Join/leave party and raid; open/close Edit Mode.
3. Enter combat while roster state changes (or while frames are updating).
4. Confirm BugSack no longer logs:
   - `AddOn 'AzeriteUI5_JuNNeZ_Edition' tried to call the protected function 'CompactRaidFrameContainer:HideBase()'`.

Status: Ready for Test

[2026-03-08] Iteration: Esc menu skinning feasibility + isolated module path (pre-change)

Request:
- Add AzeriteUI skin pass for Blizzard Escape menu (`GameMenuFrame`) similar to tooltip styling approach,
  with isolated code to reduce taint risk.

Reference checked:
- `..\GW2_UI\Classic\Immersive\Skins\gamemenu.lua`
  - Uses `GameMenuFrame` show/update hooks and visual-only restyling of frame/buttons.

[2026-03-08] Iteration: Esc menu skinning (isolated module implementation)

Update:
- Added new isolated module:
  - `Components/Misc/GameMenu.lua`
- Registered module in:
  - `Components/Misc/Misc.xml`

Implementation details:
- Uses safe hook pattern (no protected function replacement):
  - `GameMenuFrame:OnShow` (SecureHookScript)
  - `GameMenuFrame_UpdateVisibleButtons` (SecureHook)
- Applies visual skin only:
  - Hides Blizzard menu NineSlice/header art for `GameMenuFrame`.
  - Adds AzeriteUI tooltip-style frame backdrop using `border-tooltip`.
  - Styles visible GameMenu buttons with local backdrop + hover border color.
- Leaves button behavior/click logic unchanged.

Testing:
1. `/reload`
2. Press `Esc` to open the Game Menu.
3. Verify frame uses Azerite-style backdrop/border and no Blizzard default frame art.
4. Hover each visible menu button; verify border highlight changes on hover.
5. Open/close menu repeatedly and toggle options that change visible buttons
   (for example when addon/settings buttons appear) to confirm dynamic buttons get styled.
6. Check BugSack for new taint/protected-call errors while opening/closing Esc menu in and out of combat.

Status: Ready for Test

[2026-03-08] Iteration: Esc menu border residue cleanup (pre-change)

Issue:
- After initial Esc menu skin pass, Blizzard default frame border was still visible behind AzeriteUI backdrop.

[2026-03-08] Iteration: Esc menu border residue cleanup (post-change)

Update:
- `Components/Misc/GameMenu.lua`
  - Added one-time strip of legacy `GameMenuFrame` texture regions in `SkinFrame()`.
  - Added explicit hide/alpha suppression for `GameMenuFrame.Border` and `GameMenuFrame.Background` when present.
  - Kept existing safe hook model and behavior-neutral scope.

Testing:
1. `/reload`
2. Press `Esc` and inspect frame edges.
3. Confirm Blizzard default border is no longer visible.
4. Open/close menu repeatedly and verify border does not return.
5. Check BugSack for taint/protected-call regressions.

Status: Ready for Test

[2026-03-08] Iteration: Minimap tracking full rewrite (fast-mode deep scan, local refs)

Issue:
- User reports minimap right-click tracking menu still not opening/usable after prior fallback patches.
- Request: deep scan + restart function using local FeelUI / ElvUI / GW2_UI patterns.

Local reference scan (used):
- `..\ElvUI\Game\Shared\Modules\Maps\Minimap.lua`
  - Right-click opens tracking from mouse-down via:
    `local button = MinimapCluster.Tracking.Button` then `button:OpenMenu()`.
  - Uses dedicated minimap click-handler frame (not direct minimap right-click hook).
- `..\GW2_UI\Mainline\Immersive\minimap.lua`
  - Dedicated click-handler frame + `OnMouseDown` right-click -> `gwTrackingButton:OpenMenu()`.
  - Mixes a hidden `DropdownButton` proxy with `MiniMapTrackingButtonMixin`.
- `..\FeelUI\Modules\Maps\MinimapButtonsBar.lua`
  - Tracking widget handling is primarily minimap-button skin/ignore behavior, no direct right-click tracking open path.

Rewrite applied:
- `Components/Misc/Minimap.lua` tracking logic replaced from scratch:
  1. Added dedicated retail minimap click-handler frame:
     - captures `OnMouseDown` right-click for tracking menu open.
     - keeps left/middle button passthrough.
  2. Rebuilt tracking open function:
     - resolves live tracking button (`MinimapCluster.Tracking.Button` / legacy fallbacks).
     - falls back to a `DropdownButton` proxy mixed with `MiniMapTrackingButtonMixin`/`MinimapTrackingDropdownMixin`.
     - uses direct open attempts (`OpenMenu`, `OnMouseDown`, `OnClick`, `Click`) and dropdown fallback.
  3. Removed prior dual-hook + dedupe path that had accumulated layered fallback behavior.

Validation:
- `luac -p Components/Misc/Minimap.lua` passed.

Testing:
1. `/reload`
2. Right-click minimap once in Azerite theme.
3. Verify tracking menu appears and entries are clickable.
4. Reopen repeatedly and after zoning/combat transition.

Status: Ready for Test

[2026-03-08] Iteration: Minimap tracking menu still not opening/usable (right-click)

Issue:
- User reports minimap right-click tracking menu still not appearing/usable after prior deep-sweep.

Investigation Notes:
- Current `Components/Misc/Minimap.lua` has only `Minimap:HookScript("OnMouseUp", Minimap_OnMouseButton_Hook)`.
- Prior notes referenced dual-phase handling; missing mouse-down path can break retail tracking menus.
- Current open flow also requires immediate menu visibility checks after `OpenMenu`/`OnMouseDown`, which can fail on deferred menu construction.

Planned Fix:
- Restore dual-phase minimap click hook (`OnMouseDown` + `OnMouseUp`) with dedupe.
- Prefer retail tracking open on mouse-down path.
- Treat successful open calls as success without requiring same-frame visibility.

Applied:
- `Components/Misc/Minimap.lua`
  - Added dual-phase minimap hooks:
    - `Minimap:HookScript("OnMouseDown", ...)` routes right-click tracking open attempts.
    - `Minimap:HookScript("OnMouseUp", ...)` remains hooked for compatibility.
  - Added 150ms tracking-menu dedupe window to avoid duplicate open/toggle behavior.
  - Updated retail right-click handler to execute tracking open on mouse-down path only.
  - Relaxed `OpenTrackingContextMenu` success criteria:
    - `OpenMenu` / `CreateContextMenu` / `OnMouseDown` / `OnClick` / `Click` now count as success on successful call,
      without requiring immediate same-frame visibility checks.

Validation:
- `luac -p Components/Misc/Minimap.lua` passed.

Testing:
1. `/reload`
2. Right-click minimap once in Azerite theme.
3. Verify tracking menu appears and can be clicked.
4. Toggle several tracking entries, close menu, reopen, and verify state sticks.
5. Repeat after zoning and after entering/leaving combat.

Status: Ready for Test

[2026-03-07] Iteration: WoW12 nameplate/party spillover follow-up (BugSack 4531)

Issue:
- After opening EditMode, flying, and entering combat:
  - `PartyMemberFrame.lua:598` secret compare in `PartyMemberHealthCheck`
  - `TextStatusBar.lua:106` secret compare in `UpdateTextStringWithValues`
  - `AuraUtil.lua:332/336` forbidden-table in `IsBigDefensive`
  - Nameplate aura API argument errors (`GetUnitAuras`, `IsAuraFilteredOutByInstanceID`)
  - Nameplate hit-test errors (`SetNamePlateHitTestFrame` bad arg #2)

Root Cause:
- Compact lifecycle hooks were too broad and also quarantined NamePlate unitframes (which must stay intact for hit-test/aura internals).
- Party frame updates can still execute transient secret-value compares during EditMode refresh windows.
- Aura big-defensive path still needed WoW12-safe fallback in this file-scope guard path.

Update:
- `Core/FixBlizzardBugsWow12.lua`:
  - Added `ShouldQuarantineCompactFrame(frame)` name/pattern filter and excluded nameplate frames.
  - Restricted `CompactUnitFrame_SetUpFrame`, `CompactUnitFrame_SetUnit`, and `CompactRaidGroup_InitializeForGroup` hooks to party/raid/arena Compact frames only.
  - Added `PartyFrame_UpdatePartyFrames` hook to immediately re-apply Compact quarantine after Blizzard refresh.
  - Added safe wrappers:
    - `AuraUtil.IsBigDefensive`
    - `C_UnitAuras.AuraIsBigDefensive`
    - `C_UnitAuras.GetUnitAuras`
    - `C_UnitAuras.IsAuraFilteredOutByInstanceID`
    - `PartyMemberHealthCheck`
    - `UpdateTextStringWithValues`
  - Added protected wrapper for `CompactUnitFrame_UpdateAuras` to stop forbidden/secret aura payload crash loops.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Open/close EditMode, fly, then enter combat.
4. Confirm no new errors for:
   - PartyMemberFrame.lua:598
   - TextStatusBar.lua:106
   - AuraUtil.lua:332/336
   - Blizzard_NamePlateAuras.lua API argument failures
   - Blizzard_NamePlateUnitFrame.lua:143 hit-test arg failure

Status: Ready for Test

[2026-03-07] Iteration: WoW12 EditMode warning follow-up (TargetFrame parent assumption + CUF range alpha)

Issue:
- New EditMode warnings after quarantine rollout:
  - `TargetFrame.lua:1097` attempt to compare number with nil
  - `TargetFrame.lua:1115` attempt to index field `powerBarAlt` (nil)
- `CompactUnitFrame.lua:1073` (`outOfRange` secret boolean taint) still reported in Compact frame update paths.

Root Cause:
- Target/Focus/Boss spellbars were being reparented to hidden parent; Blizzard `TargetFrame.lua` spellbar code expects original target-frame parent fields (`powerBarAlt`, offsets).
- Compact frames can be created/reinitialized late by Blizzard edit/raid setup flows, after initial quarantine pass.
- `CompactUnitFrame_GetRangeAlpha` still had a direct secret-bool path.

Update:
- `Core/FixBlizzardBugsWow12.lua`:
  - Spellbar quarantine now uses `skipParent=true` for target/focus/boss spellbars (hide/unregister/show-hook only; no parent swap).
  - Added guarded wrapper for `CompactUnitFrame_GetRangeAlpha` with safe fallback alpha `1`.
  - Added lifecycle hooks to quarantine late-created Compact frames:
    - `CompactUnitFrame_SetUpFrame`
    - `CompactUnitFrame_SetUnit`
    - `CompactRaidGroup_InitializeForGroup`

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Open/close Edit Mode repeatedly.
4. Confirm no `TargetFrame.lua:1097` or `TargetFrame.lua:1115` warnings.
5. Confirm no `CompactUnitFrame.lua:1073` warnings during EditMode/group frame refresh.

Status: Ready for Test

[2026-03-07] Iteration: WoW12 hybrid castbar/EditMode quarantine implementation

Issue:
- `CastingBarFrame.lua:340` (`SetStatusBarTexture(asset)`) and `CastingBarFrame.lua:212` forbidden-table errors were still reproducible, including `TargetFrameSpellBar`.
- CompactUnitFrame secret-value errors persisted in Edit Mode (`1057/1182/1210/707`) because Blizzard Compact frames/spellbars were not consistently quarantined on all load paths.
- Castbar suppression ownership was split between oUF element logic and PlayerCastBar module.

Root Cause:
- `MakeSafeOnEvent` still directly called `self:GetTypeInfo()` in a path that can return forbidden data.
- Not all Blizzard castbar instances were explicitly guarded (target/focus/boss).
- WoW12 party/raid disable branches had early-return paths that skipped deterministic Compact-frame suppression.

Update:
- `Core/FixBlizzardBugsWow12.lua`:
  - `MakeSafeOnEvent` now uses protected `GetTypeInfo` retrieval (`pcall`) plus normalized cached fallback before applying texture.
  - Expanded castbar frame guarding to include `TargetFrameSpellBar`, `FocusFrameSpellBar`, and `BossNTargetFrameSpellBar`.
  - Added centralized WoW12 quarantine controller:
    - deterministic hide/unregister/reparent of Compact party/raid/arena frames and Blizzard target/focus/boss spellbars
    - parent lock + show-hook suppression for reactivation attempts
    - combat-safe pending queue flushed on `PLAYER_REGEN_ENABLED`
    - re-apply via `ADDON_LOADED` (`Blizzard_UnitFrame`, `Blizzard_CompactRaidFrames`, `Blizzard_CUFProfiles`, `Blizzard_ArenaUI`, `Blizzard_EditMode`, `Blizzard_UIPanels_Game`, `Blizzard_NamePlates`) and world/roster events.
- `Libs/oUF/elements/castbar.lua`:
  - Removed duplicate Blizzard player/pet suppression logic to avoid competing ownership.
- `Components/UnitFrames/Units/PlayerCastBar.lua`:
  - Kept suppression/restore ownership here only.
  - Restore now prefers Blizzard `OnLoad` routines with safe event-registration fallback.
- `Components/UnitFrames/Units/Party.lua`, `Raid5.lua`, `Raid25.lua`, `Raid40.lua`:
  - WoW12 branches now call shared quarantine helper instead of no-op early returns.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Cast normal spells (e.g. Flash of Light) and verify no `CastingBarFrame.lua:340`.
4. Change spec/talents and verify no `CastingBarFrame.lua:212` forbidden-table errors.
5. Open/close Edit Mode repeatedly and verify no CUF `1057/1182/1210/707`.
6. Retest with BetterBags/CVar activity and confirm suppressed Blizzard spellbars do not re-activate.

Status: Ready for Test

2026-03-04 00:25 (Player power threat overlay alignment follow-up)

Issue:
- Power threat highlight/case-glow alignment drifted after power-size anchor compensation changes.

Root Cause:
- Threat overlay path received extra compensation offsets, effectively double-adjusting relative placement.

Fix:
- Restored original threat overlay offset path for `PowerBar` and `PowerBackdrop` threat textures.
- Kept power fill/backdrop sizing adjustments intact.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — removed extra compensation in threat overlay positioning

Testing:
1. `/reload`
2. Enter combat to trigger threat art
3. Verify power glow/case highlight align with crystal and frame art
4. Re-check out-of-combat alignment

Status: Ready for Test

2026-03-04 00:42 (Player power threat glow size correction)

Issue:
- PowerBar threat glow still misaligned with power fill after previous fixes.

Root Cause:
- PowerBar threat overlay sizing used legacy `powerBarScaleX/Y` while the power bar itself now uses `powerBackdropScaleX/Y`, causing size mismatch.

Fix:
- Changed PowerBar threat glow size calculation to use `powerBackdropScaleX/Y * powerThreatBarScaleX/Y` instead of `powerBarScaleX/Y * powerThreatBarScaleX/Y`.
- PowerBackdrop threat sizing remains unchanged (already uses case scales).

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — threat sizing logic (lines ~1723-1728)

Testing:
1. `/reload`
2. Enter combat to trigger threat glow
3. Verify PowerBar threat glow matches power fill dimensions exactly
4. Re-check alignment at different scale settings if applicable

Status: Ready for Test

2026-03-04 00:50 (Player power threat case Y-offset adjustment)

Issue:
- PowerBackdrop threat case (glow) was misaligned vertically by 28 pixels.

Fix:
- Added +28 pixel Y-offset to PowerBackdrop threat positioning.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — threat case positioning (line ~1717)

Testing:
1. `/reload`
2. Enter combat to trigger threat glow
3. Verify PowerBackdrop threat case aligns properly with power crystal

Status: Ready for Test

2026-03-04 00:50 (Actionbar enable toggle now updates live)

Issue:
- Toggling actionbar "enable" option in settings didn't show/hide bars immediately; required `/reload`.

Root Cause:
- `Bar.Enable()` and `Bar.Disable()` set internal flag but didn't call `:Show()` or `:Hide()` on the bar frame.

Fix:
- Added `:Show()` call to `Bar.Enable()` and `:Hide()` call to `Bar.Disable()`.

Files Touched:
- `Components/ActionBars/Prototypes/Bar.lua` — Enable/Disable methods (lines 49-60)

Testing:
1. Open options (`/azerite`)
2. Navigate to ActionBars → Action Bar 2 (or any bar)
3. Toggle "Enable" checkbox
4. Verify bar appears/disappears immediately without `/reload`
5. Test during combat (should defer update until leaving combat)

Status: Ready for Test

2026-03-04 01:15 (ToT frame secret boolean crash fix)

Issue:
- Error when selecting targets in instances: "attempt to compare local 'shouldHide' (a secret boolean value tainted by 'AzeriteUI')"
- Occurred at ToT.lua:278 during target selection in raids/dungeons

Root Cause:
- `UnitIsUnit()` can return secret boolean values in WoW 12
- Code attempted to compare the secret `shouldHide` value directly: `if (shouldHide == self.shouldHide)`

Fix:
- Added `issecretvalue(shouldHide)` check before comparison
- Falls back to `false` (don't hide) when value is secret, preventing unnecessary frame hiding
- Comparison now safe as non-secret value

Files Touched:
- `Components/UnitFrames/Units/ToT.lua` — secret-value sanitization (lines ~278-282)

Testing:
1. `/reload`
2. Enter instance (raid/dungeon)
3. Select various targets (NPCs, players, critters)
4. Verify ToT frame shows/hides correctly
5. Check BugSack for no more secret comparison errors

Status: Ready for Test

2026-03-04 17:40 (NamePlate secret unit string crash fix)

Issue:
- Error when viewing nameplates: "attempt to compare local 'unit' (a secret string value tainted by 'AzeriteUI')"
- Occurred at NamePlates.lua:1046 during PLAYER_SOFT_INTERACT_CHANGED and other events
- Generated 22 errors in one session

Root Cause:
- Event handler unit parameter can be a secret string value in WoW 12
- Code attempted to compare secret unit directly: `if (unit and unit ~= self.unit)`

Fix:
- Added `issecretvalue(unit)` check at function entry
- Falls back to `nil` when unit is secret, then uses `self.unit` as fallback
- Comparison now safe as non-secret value

Files Touched:
- `Components/UnitFrames/Units/NamePlates.lua` — secret-value sanitization (lines ~1046-1049)

Testing:
1. `/reload`
2. Enter world and move around with nameplates enabled
3. Target various units, enter/leave soft interact range
4. Check BugSack for no more secret comparison errors

Status: Ready for Test

---

## Future Work Tracking

### Planned for Next Version
- [ ] Edit Mode taint deep audit (EncounterWarnings, arena frames, party/raid frames)
- [ ] Mana orb WoW 12 investigation
- [ ] Target castbar crop fixes for non-self casts
- [ ] Dead code cleanup (2500+ lines in FixBlizzardBugs.lua disabled block)

### Under Consideration
- [ ] Combo point position sliders (refinement needed)
- [ ] Soul fragments bar styling controls (needs testing with live DH users)
- [ ] Enhanced debug menu improvements

---

## Log Format Guidelines

When adding entries:
1. **Date format:** `YYYY-MM-DD HH:MM (Brief title)`
2. **Include:** Issue description, root cause, fix applied, files touched, testing steps
3. **Version entries:** Mark with status (In Progress, Ready for Release, Shipped)
4. **Keep focused:** One issue per entry, link related entries if needed
5. **Test validation:** Always include `/reload` loop test steps

---

## Next Entry Template

```

2026-03-06 13:21 (UnitFrames options nil index + Player power secret compare) [In Progress]

Issue:
- BugSack reports `Options/OptionsPages/UnitFrames.lua:1739` nil index while opening UnitFrames options.
- BugSack reports `Components/UnitFrames/Units/Player.lua:1092` secret-value comparison on `max` in `Power_PostUpdateColor`.

Root Cause:
- Soul Fragment point offset profile tables can be nil, but options getters/setters index them directly.
- `Power_PostUpdateColor` compares `max > 0` before secret-safety short-circuiting, which can taint-crash on WoW 12 secret numbers.

Planned Fix:
- Add defensive table guards in Soul Fragment point offset options accessors.
- Reorder/sanitize power percentage math to avoid any comparisons/arithmetic on secret values.

Files Targeted:
- `Options/OptionsPages/UnitFrames.lua`
- `Components/UnitFrames/Units/Player.lua`

Status: In Progress

2026-03-06 14:05 (ActionBar mount/combat cooldown refresh + MaxDps integration sync + DH combo debug cleanup) [Ready for Test]

Issue:
- Cooldown/swipe visuals could stay inactive when entering combat directly from mounted state.
- MaxDps highlight integration could be out of sync with newly initialized LAB buttons.
- DH Devourer class power options still exposed leftover debug controls no longer needed.
- Paladin could still momentarily show extra points on initial style application.

Root Cause:
- LAB only refreshed usability on `PLAYER_MOUNT_DISPLAY_CHANGED`/combat toggles, not full cooldown/button state.
- MaxDps integration registered LAB but did not force an immediate refetch pass after integration.
- UnitFrames options retained Soul Fragments debug controls (`Show Count`, point offsets) and runtime value text.
- Style-change code re-showed points without reapplying resolved active cap.

Fix:
- In `LibActionButton-1.0-GE`, changed mount transition to run full button refresh (`ForAllButtons(Update)`).
- On `PLAYER_REGEN_DISABLED`, now force full button refresh to ensure combat-start cooldown swipes engage immediately.
- On `PLAYER_REGEN_ENABLED`, now refresh cooldown visuals on active buttons.
- Added guarded MaxDps resync call after integration init (`ButtonFetch`/`Fetch` when available).
- Added nil-safe guard around MaxDps glow-event toggle state reads during integration init.
- Prevented assisted/blizzard highlight updater from clearing MaxDps-owned glow state while MaxDps is actively highlighting a button.
- Removed DH Soul Fragments debug options from Unit Frames Class Power page, keeping only the mode dropdown.
- Removed Soul Fragments value-text runtime path from `PlayerClassPower`.
- Kept point-cap enforcement active during style-change layout application (fixes Paladin initial over-show).

Files Touched:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua` — mount/combat cooldown refresh + MaxDps post-init refetch hook.
- `Options/OptionsPages/UnitFrames.lua` — removed DH Soul Fragments debug controls, kept display mode dropdown.
- `Components/UnitFrames/Units/PlayerClassPower.lua` — removed Soul Fragments value-text debug path; enforced cap visibility on style changes.

Testing:
1. `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'`
2. `luac -p 'Options/OptionsPages/UnitFrames.lua'`
3. `luac -p 'Components/UnitFrames/Units/PlayerClassPower.lua'`
4. In-game manual loop still required: `/reload`, mount -> enter combat immediately -> verify cooldown swipes start in combat.
5. Verify MaxDps glow appears on AzeriteUI buttons after login/reload without requiring additional bar changes.
6. Verify Unit Frames -> Class Power no longer shows DH point offset/count debug controls.

Status: Ready for Test

---

Date: 2026-03-06
Issue: Player power crystal backdrop/cap misalignment and fill envelope mismatch.

Root Cause:
- Runtime crystal layout in `Player.lua` had drifted from stock assumptions:
  - backdrop/case/threat anchor defaults were migrated to `FRAME`.
  - crystal statusbar was positioned/sized from `PowerBar*`, while requested visual envelope is backdrop-sized.

Fix:
- Added explicit stock-vs-current power layout tables in `Components/UnitFrames/Units/Player.lua`:
  - `STOCK_POWER_CRYSTAL_LAYOUT`
  - `CURRENT_POWER_CRYSTAL_LAYOUT`
- Switched runtime crystal statusbar placement/size to current-table mapping:
  - anchor key: `PowerBackdropPosition`
  - size key: `PowerBackdropSize`
- Locked backdrop to the crystal statusbar (`CENTER`, `0,0`) and same dimensions, so fill/backdrop always match.
- Restored stock-style anchor defaults for backdrop/case/threat to `POWER` and added one-time profile migration from prior `FRAME` values.
- Updated player unitframe power offset reset to restore stock anchor defaults (`POWER`) for backdrop/case/threat.

Files Touched:
- Components/UnitFrames/Units/Player.lua — crystal layout tables + runtime/layout migration fixes.
- Options/OptionsPages/UnitFrames.lua — reset defaults for power anchors back to stock-style.

Testing:
1. `luac -p Components/UnitFrames/Units/Player.lua` passed.
2. `luac -p Options/OptionsPages/UnitFrames.lua` passed.
3. In-game validation pending: `/reload`, verify crystal fill stays locked to backdrop while gaining/spending power.

Iteration:
- Adjusted crystal placement back to stock point source (`PowerBarPosition`) while keeping backdrop-sized fill envelope.
- Removed mixed backdrop+bar offset summing for crystal position.
- Crystal anchor-frame resolution now uses `powerBarAnchorFrame` (not backdrop anchor selection).

Follow-up:
- Cap alignment pass: restored case anchoring to resolved stock-style anchor (`powerCaseAnchorFrame`/`POWER`) instead of hardcoded `self`.

Follow-up 2:
- Added explicit delta compensation for cap and power-threat textures when crystal fill uses backdrop dimensions.
- Threat `PowerBar`/`PowerBackdrop` now use resolved anchor frames plus offset helpers, instead of raw `SetPoint(unpack(...))`.

Follow-up 3:
- Adopted verified manual crystal baseline offsets as defaults:
  - `powerBarBaseOffsetX = -37`
  - `powerBarBaseOffsetY = -28`
- Updated "Reset Power Offsets" to restore this baseline instead of zero.
- Added one-time profile migration (`powerCrystalBaselineApplied`) so zero-baseline profiles inherit the new aligned baseline.

Cleanup:
- Removed player power-widget layout/debug controls from `/az` player options (anchor/scale/offset/lab/reset/rebase block).
- Trimmed unused player power fields and dead variables related to backdrop anchor/offset tuning in `Player.lua`.

2026-03-06 15:49 (Party frame aura filtering/styling modernization) [Ready for Test]

Issue:
- Party frame aura rendering was inconsistent and too sparse for modern WoW 12 aura metadata.
- Party frames reused target aura styling logic, causing less predictable visual treatment.

Root Cause:
- `Party.lua` used `TargetPostUpdateButton`, which includes target-specific assumptions.
- `PartyAuraFilter` relied on narrow legacy checks and missed common modern raid tokens (`HARMFUL|RAID`, `HELPFUL|PLAYER|RAID`, `HELPFUL|EXTERNAL_DEFENSIVE`).

Fix:
- Added `ns.AuraStyles.PartyPostUpdateButton` with party-specific icon/border behavior.
- Reworked `ns.AuraFilters.PartyAuraFilter` to prioritize raid-relevant harmful auras and meaningful helpful auras while remaining secret-value safe.
- Switched party aura post-update callback from target style to party style.
- Corrected malformed `maxHealth`/`if` statement in `Party.lua` heal prediction callback.

Files Touched:
- `Components/UnitFrames/Auras/AuraFilters.lua` — modernized party aura filtering.
- `Components/UnitFrames/Auras/AuraStyling.lua` — added party aura post-update styling callback.
- `Components/UnitFrames/Units/Party.lua` — party aura callback wiring + heal prediction syntax fix.

Testing:
1. `luac -p Components/UnitFrames/Auras/AuraFilters.lua`
2. `luac -p Components/UnitFrames/Auras/AuraStyling.lua`
3. `luac -p Components/UnitFrames/Units/Party.lua`
4. In-game: `/reload`, join party, verify raid-relevant debuffs and player/external helpfuls appear on party frames.

Status: Ready for Test


2026-03-06 14:00 (ActionBar MaxDps compatibility + mount-to-combat cooldown refresh + DH combo debug cleanup) [In Progress]

Issue:
- MaxDps-assisted highlights on AzeriteUI buttons are reported as partially non-functional.
- Cooldown/swipe visuals can fail to engage when combat starts directly from a mounted state, then recover only after leaving combat.
- Remaining DH Devourer debug-oriented Soul Fragments controls are still exposed despite combo-point style usage.

Root Cause:
- LibActionButton event flow only refreshed usability on `PLAYER_MOUNT_DISPLAY_CHANGED` and combat toggles, not full cooldown state.
- Mount transition can leave button cooldown visuals stale until a later refresh event.
- Unit Frames options still expose legacy Soul Fragments debug controls (`count` toggle and per-point offset sliders).

Planned Fix:
- Add combat/mount transition cooldown refresh in `LibActionButton-1.0-GE` and force a one-shot state resync on those transitions.
- Trigger a MaxDps button refetch hook after LAB integration initializes (when API is available).
- Remove remaining DH debug controls from Class Power options while keeping the display mode dropdown.
- Remove obsolete Soul Fragments value-text toggle logic from class power runtime.
- Keep paladin class power strictly capped to 5 visible points on style-change updates too.

Files Targeted:
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- `Options/OptionsPages/UnitFrames.lua`
- `Components/UnitFrames/Units/PlayerClassPower.lua`

Status: In Progress

2026-03-06 13:44 (Class power cleanup, orb color simplification, nameplate target visibility) [Ready for Test]

Issue:
- Soul Fragments bar adjuster paths/options were still present despite point-based DH Devourer display.
- Orb/crystal color controls were duplicated by generic option injection and included unused modes.
- Paladin class power could render >5 points in runtime scenarios.
- Targeted nameplates could hide name and health value text.

Root Cause:
- Legacy bar customization blocks remained in options/runtime/layout config.
- Color option was added at shared suboption generation level, affecting unrelated tabs.
- Point visibility relied on style history and did not hard-cap active points each update.
- Nameplate hover/position logic explicitly suppressed display when `isTarget` was true.

Fix:
- Removed Soul Fragments bar option controls and kept point adjustment controls only.
- Removed legacy Soul Fragments bar runtime/layout code paths.
- Simplified player orb/crystal color mode to `default` or `class` only, and kept it in Player options only.
- Updated player power coloring to apply a gold overlay blend over the selected base color.
- Forced paladin cap to 5 in class power update and hid points above active cap every update.
- Updated nameplate logic to treat target like other active states for name/health display.

Files Touched:
- `Options/OptionsPages/UnitFrames.lua` — removed global color injection + bar adjuster controls; kept point controls.
- `Components/UnitFrames/Units/Player.lua` — simplified color source logic + added gold overlay blend model.
- `Components/UnitFrames/Units/PlayerClassPower.lua` — removed bar path, enforced paladin cap, explicit point cap visibility.
- `Layouts/Data/PlayerClassPower.lua` — removed obsolete `SoulFragments` bar layout entry.
- `Components/UnitFrames/Units/NamePlates.lua` — removed target-specific hide behavior for name/health value.

Testing:
1. `/reload`
2. Open `Unit Frames -> Class Power` and verify Soul Fragments bar adjuster options are gone; point controls remain.
3. Open `Unit Frames -> Player` and verify orb/crystal color has only `Default` and `Class Color`.
4. On player frame crystal/orb, verify gold overlay effect increases as fill rises.
5. On paladin, build/consume holy power and verify max visible points stays at 5.
6. Target hostile mobs and verify nameplate name/health value no longer disappears on target state.

Status: Ready for Test

2026-03-06 13:24 (UnitFrames options nil index + Player power secret compare) [Ready for Test]

Issue:
- `Options/OptionsPages/UnitFrames.lua:1739` could index a nil profile table while rendering Soul Fragments point offset options.
- `Components/UnitFrames/Units/Player.lua:1092` compared a secret-tainted power max value (`max > 0`) inside `Power_PostUpdateColor`.

Root Cause:
- Soul Fragment offset options assumed `soulFragmentsPointOffsetX/Y` tables always existed.
- Secret-value safety check happened too late in the condition chain, after numeric comparison.

Fix:
- Added defensive initialization/guarding for `soulFragmentsPointOffsetX/Y` in option setters/getters.
- Captured `point` as a stable `pointIndex` inside the loop for closure safety.
- Reordered power percent guard logic to reject secret values before any arithmetic/comparison.

Files Touched:
- `Options/OptionsPages/UnitFrames.lua` — nil-safe Soul Fragments offset option accessors.
- `Components/UnitFrames/Units/Player.lua` — secret-safe power percent calculation in `Power_PostUpdateColor`.

Testing:
1. `/reload`
2. Open Unit Frames options and click Class Power/Soul Fragments controls repeatedly.
3. Verify no new BugSack errors from `UnitFrames.lua:1739`.
4. Trigger power updates (spec swap/combat/resource changes) and verify no secret compare errors from `Player.lua:1092`.

Status: Ready for Test
YYYY-MM-DD HH:MM (Title)

Issue:
- What broke
- How it manifested
- Error messages if any

Root Cause:
- Why it happened
- What assumptions were wrong

Fix:
- What changed
- Why this approach
- Any tradeoffs

Files Touched:
- path/to/file.lua — what changed
- path/to/other.lua — what changed

Testing:
1. /reload
2. Reproduce scenario
3. Verify fix
4. Check for regressions

Status: [In Progress / Ready for Test / Verified / Shipped in vX.X.X]
[2026-03-06] Iteration: hide zero/negative power values in unit frame power text

Issue:
- Power value text could display 0 (or negative) for units when value text is visible.

Fix:
- Suppress power value text when numeric value is <= 0 at the tag formatting layer.
- For target power value, suppress 0% fallback from raw percent calculation.

Files Touched:
- Components/UnitFrames/Tags.lua — hide <=0 in SafePowerValueText/SafePowerValueFullText.
- Components/UnitFrames/Units/Target.lua — hide 0% in target power percent fallback.

Testing:
1. /reload
2. Show power values (target + any unit with value text enabled)
3. Verify 0/negative power values are hidden
4. Verify non-zero power values still display

Status: Ready for Test
[2026-03-06] Iteration: clean up power value zero suppression

Issue:
- Power value text still showed 0 because player/target formatting paths bypassed tag helpers.

Plan:
- Suppress <=0 and secret power values at player/target formatting sources.
- Ensure value text clears when nothing valid is available.

Files Touched:
- Components/UnitFrames/Units/Player.lua — power value formatting suppression.
- Components/UnitFrames/Units/Target.lua — power value formatting suppression + clear.

Status: In Progress
Update:
- Added zero/secret suppression to player power value formatting and percent fallbacks.
- Added zero/secret suppression to target power value formatting, and clear value text when empty.

Testing:
1. /reload
2. Show power values (player + target)
3. Verify 0/negative power values are hidden
4. Verify non-zero power values still display

Status: Ready for Test
[2026-03-06] Iteration: LAB item count/charges display parity

Issue:
- After LAB swap, item stack/charge text (e.g. potions) is inconsistent on action buttons.

Plan:
- Port old GE count/charge display gating to current LAB UpdateCount.
- Port old GE Action.GetCount item fallback for Midnight-safe count retrieval.

Status: In Progress
Update:
- Replaced generic count text path with old GE-style gating in LAB UpdateCount:
  - Consumables/stackables: show * above max, otherwise show only when count > 1.
  - Charges: show only when maxCharges > 1 and current charges > 0.
- Added old GE-style Action.GetCount fallback for item/macro-item actions via C_Item.GetItemCount(..., true) so stack counts remain available on Midnight.

Testing:
1. /reload
2. Put stackable items (potions/healthstones/etc.) on action bars
3. Verify stack count appears when >1 and hides at 1
4. Verify charge-based actions/items show charge text when applicable
5. Enter/leave combat and swap states (mounted/stance) to confirm count text remains stable

Status: Ready for Test
[2026-03-06] Iteration: LAB secret-safe charge/count gating

Issue:
- UpdateCount compared secret-tainted charge values (maxCharges > 1), causing BugSack errors and charge display breakage.

Update:
- Added issecretvalue guards in LAB UpdateCount before numeric comparisons for count and charge values.
- Secret-tainted count/charge values now clear text instead of being compared.

Testing:
1. /reload
2. Trigger charge updates on spell buttons (combat + non-combat)
3. Verify no secret-number compare errors in BugSack
4. Verify item stack counts (potions) still display correctly

Status: Ready for Test
[2026-03-06] Iteration: LAB blended item+spell charge display

Issue:
- Secret-safe gating removed runtime errors but hid spell charge text.

Update:
- Kept old GE consumable/item count branch in UpdateCount (count > 1, * over cap).
- Switched non-consumable branch to prefer self:GetDisplayCount() with secret guards, then fallback to legacy GetCharges() only when non-secret.
- Hardened Generic.GetDisplayCount with secret/type guards to prevent secret comparisons.

Testing:
1. /reload
2. Verify potion/item stack counts still work (>1 shown, 1 hidden)
3. Verify spell charge text is visible again for charge-based abilities
4. Verify no new secret compare errors in BugSack

Status: Ready for Test
[2026-03-06] Iteration: restore old GE spell-charge resolver behavior

Issue:
- Previous blend still failed to show spell charges.
- Old GE library had a stronger charge-source merge (action charge info + spell charge info) than swapped LAB.

Update:
- Added IsSafeNumber helper for secret-safe numeric checks.
- Reworked UpdateCount to use per-button cache (__LABCountCache) for count/charge display continuity during secret-tainted frames.
- Restored old-style Action.GetChargeInfo merge behavior:
  - Prefer spell charge info when it has active recharge and action info does not.
  - Fallback to spell info when action info is missing/unsafe.
- Reworked Action.GetCharges to use merged charge info first, then safe raw fallback.

Testing:
1. /reload
2. Verify charge-based spells display charges again
3. Verify potion/item stacks still display/hide correctly (>1 shown, 1 hidden)
4. Enter/leave combat and mounted transitions
5. Confirm no secret-number compare errors in BugSack

Status: Ready for Test
[2026-03-06] Iteration: normalize action charge payload + resolve action spell IDs

Issue:
- Spell charges still not updating while item counts worked.

Root Cause:
- Item fix touched count display and item count fallback only.
- Spell charge path depended on charge payload shape/resolution from action APIs.
- Swapped LAB was using direct C_ActionBar.GetActionCharges binding without normalization wrapper, and lacked old action-slot spell resolution (C_ActionBar.GetSpell + override chain), so spell charge source could be stale/mismatched.

Update:
- Added NormalizeChargeInfo and wrapped action charge retrieval to normalize all payload variants.
- Restored ResolveActionSpellID + override resolver path for spell charge lookups.
- Updated GetSpellChargeInfo to normalize table/tuple variants.

Testing:
1. /reload
2. Spend/regain charges on known charge spell
3. Verify count updates each change (not static)
4. Verify potion/item stacks still correct
5. Verify no BugSack secret compare errors

Status: Ready for Test
[2026-03-06] Iteration: root-cause comparison (pre-item-fix vs post-item-fix)

Root Cause:
- Pre-item-fix UpdateCount used self:GetDisplayCount() for non-consumable buttons.
- On action buttons, this resolves to Action.GetDisplayCount (C_ActionBar.GetActionDisplayCount) and kept spell charges updating.
- Post-item-fix changed non-consumable path to self:GetCharges() + numeric/secret gating.
- On Midnight, spell charge values may be secret-tainted, so gating suppresses/locks updates while item counts still work (item counts come from safe item APIs).

Update:
- Restored original non-consumable UpdateCount path to self:GetDisplayCount().
- Kept custom item/consumable count branch (count > 1, * over cap).

Testing:
1. /reload
2. Verify spell charges update live (in/out of combat)
3. Verify item counts still follow custom behavior
4. Check BugSack for no new count-related errors

Status: Ready for Test
[2026-03-06] Iteration: player power crystal value text not refreshing (investigation start)

Issue:
- Current power value text on the player power crystal can appear stale while power changes.

Investigation:
- Tracing player unitframe power update flow in Components/UnitFrames/Units/Player.lua.
- Power-related frame event branch refreshes mana orb explicitly; validating crystal value refresh path.

Status: In Progress
[2026-03-06] Iteration: player power crystal value text not refreshing (event-path fix)

Root Cause:
- In UnitFrame_OnEvent power-event handling, the mana orb was explicitly refreshed but the crystal power element was not force-refreshed in that same path.
- Crystal value text is driven by crystal element update/post-update; missing explicit refresh could leave value text stale depending on event routing/filtering.

Update:
- Added self.Power:ForceUpdate() guard in the player frame UNIT_POWER_*/display-power/vehicle event branch before RefreshManaOrb(...).
- File: Components/UnitFrames/Units/Player.lua.

Testing:
1. /reload
2. Spend and regenerate your primary resource (rage/energy/focus/etc.).
3. Verify power crystal value text updates every change (no stale number).
4. Enter/exit vehicle or stance/spec states that swap displayed power and confirm text still updates.
5. Run /azdebug dump player if needed to verify live power values.

Status: Ready for Test
[2026-03-06] Iteration: rollback post-5.2.218 power-value suppression guards

Issue:
- Player power crystal statusbar updated, but current power text stayed stale.
- Regression suspected from recent zero/hide cleanup.

Root Cause (git compare vs e53811f):
- New suppression gates were added in player power text resolver path (GetFormattedPlayerPowerValue, GetPlayerRawPowerPercent, TrySetPlayerElementValueTextFromRaw, and percent/short/full format helpers).
- Those guards blocked/short-circuited raw formatter paths that previously handled live values, causing text fallback/cache behavior to drift from the moving bar.

Update:
- Restored the above helper behavior to match e53811f for live player power text formatting.
- Kept explicit power-event self.Power:ForceUpdate() in UnitFrame_OnEvent.

Testing:
1. /reload
2. Spend/regenerate primary resource continuously.
3. Verify crystal value text changes every tick with the bar.
4. Verify 0-value transitions still behave correctly (no stuck old number).
5. Verify no script errors in BugSack.

Status: Ready for Test

[2026-03-06] Iteration: MajorFactionUnlockToast nil data crash in Banners module

Issue:
- BugSack error on startup/banner path:
  - Blizzard_MajorFactionUnlockToast.lua:41 attempt to index local data (nil)
  - Triggered from Components/Misc/Banners.lua via rame:PlayBanner(data).

Root Cause:
- PrepareFrames() calls TopBannerManager_Show(_G[name]) without payload data while re-anchoring existing banners.
- If that frame is the current top banner, TopBannerManager_Show called rame:PlayBanner(data) with data == nil.

Update:
- Added defensive guard in Banners.TopBannerManager_Show:
  - return early on nil frame
  - only call rame:PlayBanner(data) when data ~= nil
- File: Components/Misc/Banners.lua.

Testing:
1. /reload
2. Ensure Blizzard_MajorFactions toast/banner can appear without throwing script errors.
3. Confirm BugSack no longer logs MajorFactionUnlockToast.lua:41 from AzeriteUI banner hook path.

Status: Ready for Test

[2026-03-07] Iteration: WoW12 Blizzard castbar nil texture crash (CastingBarFrame.lua:340)

Issue:
- BugSack repeatedly reported:
  - bad argument #2 to SetStatusBarTexture(asset)
  - Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua:340
- Reproduced during normal player casts (e.g. Flash of Light) and talent/spec-change castbar flow.

Root Cause:
- WoW12 guard fallback for CastingBar GetTypeInfo could return partial typeInfo under taint/forbidden-table paths.
- Blizzard OnEvent cast-start path then consumed incomplete typeInfo and reached SetStatusBarTexture(nil).
- Existing guard covered StopFinishAnims/UpdateShownState/GetTypeInfo/FinishSpell, but this stack came from the OnEvent path.

Update:
- Hardened Core/FixBlizzardBugsWow12.lua:
  - Added typeInfo normalization with guaranteed texture keys:
    barTexture/statusBarTexture/castBarTexture/texture.
  - Safe GetTypeInfo now returns normalized data (including cached fallback normalization).
  - Added guarded OnEvent wrapper (pcall) on mixins and live frame instances.
- This keeps Blizzard castbar fallback data valid and prevents OnEvent crash propagation.

Testing:
1. /reload
2. Cast normal spells with cast time (e.g. Flash of Light).
3. Trigger talent/spec swap castbar flow.
4. Confirm BugSack no longer logs CastingBarFrame.lua:340 SetStatusBarTexture(asset) usage errors.

Status: Ready for Test

[2026-03-07] Iteration: Conditional Blizzard castbar suppression (remove hard alpha/show hook)

Issue:
- PlayerCastingBarFrame/PetCastingBarFrame errors persisted in cast-start paths.
- Current suppression used SetAlpha(0) + Show-hook interception, which keeps Blizzard castbar logic running and can still taint/show under Edit Mode flows.

Reference checks:
- AzeriteUI_Stock: hard disable via SetParent(UIHider) + UnregisterAllEvents + SetUnit(nil).
- ElvUI: disables Blizzard castbars only when replacement castbar is enabled, with explicit disable/restore handling.
- GW2_UI: dedicated Blizzard disable path + Edit Mode suppression helpers.

Update:
- Reworked Components/UnitFrames/Units/PlayerCastBar.lua:
  - Removed alpha/show-hook suppression model.
  - Added explicit SuppressBlizzardCastbar(frame):
    SetParent(UIHider), UnregisterAllEvents, SetUnit(nil), Hide, SetAlpha(0).
  - Added RestoreBlizzardCastbar(frame, unit):
    restore parent, alpha, re-register cast events, register PLAYER_ENTERING_WORLD (+ UNIT_PET for pet), SetUnit(unit), Hide.
  - Added conditional state gate: only suppress Blizzard castbars when our castbar is active (profile.enabled).
  - Added OnDisable restore path so Blizzard castbars are returned when module is off.

Testing:
1. /reload
2. With AzUI castbar enabled: verify Blizzard player/pet castbars stay suppressed and AzUI castbar works.
3. Disable AzUI castbar option/module: verify Blizzard castbars come back and function.
4. Test normal cast + talent/spec swap castbar flow; confirm no new castbar errors.

Status: Ready for Test

[2026-03-07] Iteration: WoW12 castbar+EditMode guard hardening (no major refactor)

Issue:
- Castbar error persisted on OverlayPlayerCastingBarFrame:
  CastingBarFrame.lua:340 bad argument #2 to SetStatusBarTexture(asset).
- Edit Mode continued to trigger CompactArena/CompactUnitFrame secret-value comparison errors:
  UpdateInRange / UpdateHealPrediction / UpdateHealthColor.

Update:
- Core/FixBlizzardBugsWow12.lua:
  - Added frame-level guard for castbar SetStatusBarTexture to coerce invalid/non-string assets to
    Interface\\TargetingFrame\\UI-StatusBar.
  - Strengthened guarded OnEvent wrapper to normalize type info and pre-apply a safe bar texture.
  - Rebound existing castbar frame OnEvent scripts to guarded OnEvent where available.
  - Added lightweight pcall wrappers for Blizzard CUF hot paths:
    CompactUnitFrame_UpdateInRange,
    CompactUnitFrame_UpdateHealPrediction,
    CompactUnitFrame_UpdateHealthColor.
  - Fallback behavior is cosmetic-only (hide prediction overlays / force safe inDistance / safe color) to avoid spam.

Rationale:
- Mirrors ElvUI/GW2 pattern of minimal targeted guards around Blizzard frame updates,
  without a broad frame-system refactor.

Testing:
1. /reload
2. Cast normal spells + spec/talent swap castbar.
3. Open Edit Mode repeatedly and verify no CUF spam.
4. Confirm BugSack session no longer logs CastingBarFrame.lua:340 and CUF 707/1057/1182/1210.

Status: Ready for Test

[2026-03-07] Iteration: Class power clickthrough blocker hardening + clearer option copy

Issue:
- Class power clickthrough toggle did not reliably block right-click passthrough to the player unit menu.
- Option label/tooltip was ambiguous about enabled vs disabled behavior.

API check:
- Verified WoW12 ScriptRegion APIs for this path:
  SetMouseClickEnabled, SetPropagateMouseClicks, SetPropagateMouseMotion.

Update:
- Components/UnitFrames/Units/PlayerClassPower.lua:
  - Added SyncClassPowerClickBlocker helper.
  - Raised blocker to stable capture layer (DIALOG strata, high frame level).
  - Synced blocker positioning/layering on classpower SetFrameLevel/SetFrameStrata.
  - Applied explicit mouse handling toggles:
    SetMouseClickEnabled, SetPropagateMouseClicks, SetPropagateMouseMotion, EnableMouse, SetShown.
- Options/OptionsPages/UnitFrames.lua:
  - Renamed toggle text to "Allow Click-Through".
  - Expanded tooltip text to explicitly describe enabled and disabled behavior.

Testing:
1. /reload
2. Unit Frames -> Class Power -> disable "Allow Click-Through".
3. Right-click directly on class power; verify player unit menu does not open.
4. Re-enable "Allow Click-Through"; verify clicks pass through again.

Status: Ready for Test

[2026-03-07] Iteration: Minimap right-click tracking menu restore (WoW12-safe fallback chain)

Issue:
- Right-clicking Minimap no longer opened tracking list.
- Minimap right-click hook relied on a single path (MinimapCluster.Tracking.Button.menuGenerator), which is not stable across newer retail structures.

Update:
- Components/Misc/Minimap.lua:
  - Added OpenTrackingContextMenu(anchor) helper.
  - Added robust fallback chain:
    1) MenuUtil.CreateContextMenu with TrackingFrame/Tracking menuGenerator
    2) tracking button :Click() fallback
    3) dropdown fallback (custom or Blizzard MiniMapTrackingDropDown)
  - Updated Minimap_OnMouseUp_Hook to use this helper for non-Classic clients.

Testing:
1. /reload
2. Right-click minimap with Azerite theme active.
3. Verify tracking menu opens.
4. Switch theme and verify right-click still opens tracking menu.

Status: Ready for Test

[2026-03-07] Iteration: Player Alternate enable reliability in dev mode

Issue:
- Some users could not enable Player Alternate after using /devmode unless they toggled devmode off/on again.
- Options were hard-disabling entire unitframe modules (Player/PlayerAlternate) instead of only toggling profile enabled state.

Root cause:
- UnitFrames options used module:Disable() in cross-toggle handlers.
- This could leave module runtime state out-of-sync with profile toggles and require extra reload cycles.

Update:
- Options/OptionsPages/UnitFrames.lua:
  - Replaced hard module disables with profile toggles + module:UpdateSettings().
  - Added recovery path: when enabling, call module:Enable() if module is currently disabled.
  - Player Alternate subpage now only hides when devmode is off (not while Player is enabled), so users can enable it directly.
- Components/UnitFrames/Units/PlayerAlternate.lua:
  - Removed hard PreInitialize module-disable path.
  - Added PlayerFrameAltMod.UpdateEnabled override that gates frame activation by both:
    profile.enabled and global devmode flag.

Testing:
1. /reload
2. /devmode (on)
3. Options -> Unit Frames: enable Player Alternate.
4. Verify it enables immediately (no extra devmode flip needed).
5. /devmode (off), /reload: verify alternate stays suppressed while devmode is off.

Status: Ready for Test

[2026-03-07] Iteration: Minimap tracking menu deep fallback (ElvUI/GW2/Diabolic parity)

Issue:
- Right-click on Minimap still failed to open tracking in some retail setups.

Reference comparison:
- ElvUI (Retail): prefers MinimapCluster.Tracking.Button:OpenMenu().
- GW2_UI (Mainline): uses gwTrackingButton:OpenMenu().
- DiabolicUI3 (Retail): uses Tracking.Button:OnMouseDown()/Click fallback.

Update:
- Components/Misc/Minimap.lua OpenTrackingContextMenu now uses fallback order:
  1) trackingButton:OpenMenu()
  2) trackingButton:OnMouseDown()
  3) MenuUtil.CreateContextMenu(menuGenerator)
  4) trackingButton:Click()
  5) Minimap_OnClick(minimap, "RightButton")
  6) dropdown fallback (custom/Blizzard MiniMapTrackingDropDown)
- Button/frame discovery now checks both modern and legacy paths:
  MinimapCluster.Tracking, MinimapCluster.TrackingFrame, MiniMapTrackingButton, MiniMapTracking.

Testing:
1. /reload
2. Right-click minimap in Azerite theme.
3. Verify tracking menu opens.
4. Repeat with other minimap themes and after zone changes.

Status: Ready for Test
- Added dual-phase minimap mouse hook (OnMouseDown + OnMouseUp) with 150ms de-duplication,
  matching modern UI patterns where tracking menus are opened on mouse-down.

[2026-03-07] Iteration: Deep sweep follow-up for minimap tracking + classpower clickthrough

Issue:
- User reports both fixes still failing in live use:
  - Minimap right-click tracking menu not opening.
  - Class power clickthrough/blocking not taking effect.

Minimap deep-sweep update:
- Added retail tracking proxy based on MiniMapTrackingButtonMixin (GW2-style fallback).
- Fixed debounce logic so mouse-down failure no longer suppresses mouse-up retry.
- OpenTrackingContextMenu now validates visible menu state for OpenMenu/OnMouseDown paths.
- Fallback order now resilient across hidden/reparented Blizzard tracking widgets.

Class power deep-sweep update:
- Moved click blocker parent to UIParent to avoid parent-level layering/input edge cases.
- Added classpower OnShow/OnHide visibility sync for blocker.
- Added direct click-block safety net on ClassPower frame itself:
  SetMouseClickEnabled / SetPropagateMouseClicks / EnableMouse + noop mouse scripts.

Reference patterns checked:
- ElvUI minimap: Tracking.Button:OpenMenu()
- GW2_UI minimap: gwTrackingButton:OpenMenu() using mixin proxy
- DiabolicUI3 minimap: Tracking.Button:OnMouseDown()/Click fallback

Testing:
1. /reload
2. Minimap right-click with Azerite theme active.
3. Class power: disable click-through and right-click directly over class power area.
4. Re-enable click-through and verify clicks pass through again.

Status: Ready for Test

[2026-03-08] Iteration: Bossbar health text shows "?" (pre-change)

Issue:
- Boss health text shown in bossbars (when Objective Tracker is hidden for boss encounters) renders as "?" instead of numeric health values.

Investigation:
- Components/UnitFrames/Units/Boss.lua uses tag [*:Health(true)] for health value text.
- Components/UnitFrames/Tags.lua Methods[*:Health] returns "?" in smart/full fallback branches.
- Secret-safe formatting path exists (SafeHealthCurrentText) but is not preferred in *:Health smart/full branches.

Update:
- Components/UnitFrames/Tags.lua
  - Added HasDisplayValue() helper for secret-safe output checks.
  - Added SafeHealthMaxText() formatter mirroring SafeHealthCurrentText().
  - Updated Methods[*:Health] smart/full branches to prefer direct formatted health text sources and stop returning literal "?" fallback.
  - Smart/full fallback now returns empty string when no safe text source exists, avoiding visible placeholder pollution.

Testing:
1. /reload
2. Engage any boss encounter that shows bossbars while Objective Tracker is hidden.
3. Verify boss health value text no longer renders as "?" and follows live health updates.
4. Optional: /azdebug dump target during encounter to inspect health-safe cache/value state.

Status: Ready for Test

[2026-03-08] Iteration: Elemental swap bar value text + anchor persistence polish

Issue:
- Elemental secondary swap bar rendered without visible value text.
- Need to confirm moved /lock position persists after reload and avoid reset loops.

Update:
- Components/UnitFrames/Units/PlayerClassPower.lua
  - Elemental swap bar now sets `__AzeriteUI_KeepValueVisible` so shared power update path no longer hides its `.Value` fontstring.
  - Added explicit value visibility gate mirroring player `showPowerValue` setting.
  - Value text now follows player crystal `PowerValueFormat` modes (`short`, `full`, `percent`, `shortpercent`) using safe cached values.
  - Kept one-time shaman swap-bar anchor migration flag (`elementalSwapBarAnchorMigrated`) so default reposition runs once only and does not reset each reload.

Testing:
1. /reload
2. On Elemental, set mode to crystal mana/spec and generate/consume resource.
3. Verify swap bar shows numeric value text and updates live.
4. Move class power in /lock, /reload, confirm position remains unchanged.

Status: Ready for Test

[2026-03-08] Iteration: Elemental swap bar showing max-only value

Issue:
- Secondary swap bar text could stick to max value instead of current value under secret-value reads.

Update:
- Components/UnitFrames/Units/PlayerClassPower.lua
  - Switched Elemental swap bar value text source to the same raw-display strategy used by player crystal:
    - format UnitPower via AbbreviateNumbers/BreakUpLargeNumbers with pcall
    - parse display text to safe numeric cache when possible
    - read UnitPowerPercent (CurveConstants.ScaleTo100 when available) for percent modes
  - Keep safeCur/safePercent fallback only if raw-display formatting is unavailable.

Testing:
1. /reload
2. Elemental mode with swap bar active.
3. Cast maelstrom generators/spenders and verify displayed value changes current value, not stuck at max.

Status: Ready for Test

[2026-03-08] Iteration: combat dropdown switch caused ADDON_ACTION_BLOCKED

Issue:
- Switching Elemental display mode (crystal/spec) during combat caused protected action block on `SetSize` from PlayerClassPower.Update.

Update:
- Components/UnitFrames/Units/PlayerClassPower.lua
  - Added combat-lockdown deferral for class power settings updates:
    - `ClassPowerMod.Update` now exits early in combat, stores pending update flag, and registers `PLAYER_REGEN_ENABLED` deferred handler.
    - New `ClassPowerMod.OnDeferredUpdateEvent` applies `UpdateSettings()` once combat ends and unregisters itself.
  - Prevents protected geometry/element toggles from running mid-combat while preserving post-combat application.

Testing:
1. Enter combat.
2. Change Elemental display mode in options.
3. Verify no ADDON_ACTION_BLOCKED error.
4. Leave combat and verify mode/size/visibility switch applies automatically.

Status: Ready for Test

[2026-03-08] Iteration: Friendly player nameplates name-only option (append)

Issue:
- Added requested toggle to hide friendly player world nameplate healthbars while keeping class-colored names.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added `hideFriendlyPlayerHealthBar` profile default.
  - Added friendly-player name-only detection helper and class-color name application.
  - Friendly player nameplates now hide health bar/backdrop/value while showing class-colored names when enabled.
- `Options/OptionsPages/Nameplates.lua`
  - Added toggle: `Hide friendly player healthbars (name only)`.

Testing:
1. `/reload`
2. Enable toggle in Nameplates options.
3. Verify friendly player nameplates are name-only and class-colored.
4. Verify hostile and friendly NPC nameplates are unchanged.

Status: Ready for Test

[2026-03-08] Iteration: Nameplates cleanup (health flip lab removal + friendly name-only polish)

Issue:
- Health Flip Lab debug controls still visible in Nameplates options.
- Friendly player name-only mode still showed leftover overlay visuals.
- Requested larger readable name-only plates while option is enabled.

Update:
- `Options/OptionsPages/Nameplates.lua`
  - Removed the full Health Flip Lab options block from Nameplates settings.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added per-plate scale helper and applied a 1.5x multiplier for friendly player name-only mode.
  - Friendly name-only mode now force-hides `TargetHighlight` and `ThreatIndicator` overlays.
  - Kept class-colored names and healthbar/backdrop/value hiding behavior.

Testing:
1. `/reload`
2. Open Nameplates options and verify Health Flip Lab section is gone.
3. Enable `Hide friendly player healthbars (name only)`.
4. Verify friendly player nameplates: no healthbar and no leftover overlay, names class-colored, visually larger.
5. Disable option and verify normal scale/overlays return.

Status: Ready for Test

[2026-03-08] Iteration: Friendly name-only pre-target scale normalization

Issue:
- Friendly player name-only plates appeared too small until the unit was targeted.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added safe selected-scale reader using `GetCVar("nameplateSelectedScale")` (fallback `1.1`).
  - In friendly name-only mode, non-target plates now get the same selected-scale multiplier so pre-target size matches target-size behavior.

Testing:
1. `/reload`
2. Enable `Hide friendly player healthbars (name only)`.
3. Compare same friendly player before/after targeting and verify size no longer jumps smaller->larger on target.

Status: Ready for Test

[2026-03-08] Iteration: Friendly name-only strict visuals (health layers fully suppressed)

Issue:
- Friendly name-only mode could still show residual health-related overlay layers.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Strengthened `ShouldUseFriendlyPlayerNameOnly(self)` to resolve friendliness directly from unit APIs with secret-safe fallbacks (no stale flag dependency).
  - Added `ApplyFriendlyNameOnlyVisualState(self, enabled)`:
    - hides `Health`, `Health.Backdrop`, native health texture, `Health.Value`, `Health.Display`, `Health.Preview`
    - hides `HealthPrediction` + `HealthPrediction.absorbBar`
    - hides `Castbar`, `Power`, `TargetHighlight`, `ThreatIndicator`, `Classification`, `RaidTargetIndicator`
    - keeps only `Name` visible in name-only mode
  - `NamePlate_PostUpdateElements` now early-returns in name-only mode after applying strict visuals and name color, preventing later health/absorb setup from re-showing layers.

Testing:
1. `/reload`
2. Enable `Hide friendly player healthbars (name only)`.
3. Verify friendly player plates show only class-colored names.
4. Confirm no healthbar texture/overlay, no absorb, no heal prediction, no health value layer.

Status: Ready for Test

[2026-03-08] Iteration: Friendly name-only anchor + scale tuning

Issue:
- Name-only friendly plates were floating too high above heads.
- Requested larger default friendly name-only size and only a slight target bump.

Deep check summary:
- `Components/UnitFrames/UnitFrame.lua` is generic bar plumbing (`CreateBar`, base unitframe scale handling).
- Nameplate-specific positioning and scaling live in `Components/UnitFrames/Units/NamePlates.lua` (style, NamePosition, PostUpdateElements, ApplyNamePlateScale).

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added name-only anchor override helper and lowered name Y offset in name-only mode.
  - Friendly name-only scale is now 2.0x baseline.
  - Targeted friendly name-only plates now get only a small extra bump (1.1x on top of baseline).
  - Removed pre-target selected-scale compensation path.

Testing:
1. `/reload`
2. Enable `Hide friendly player healthbars (name only)`.
3. Verify names sit closer to heads (less floating height).
4. Verify non-target friendly name-only plates are ~100% bigger baseline.
5. Verify target only grows slightly from that baseline.

Status: Ready for Test

[2026-03-08] Iteration: API alignment validation pass (wow-api)

API check:
- Confirmed signatures used for friendly detection:
  - `UnitCanAssist(unit, target)` -> boolean
  - `UnitCanAttack(unit, target)` -> boolean
  - `UnitReaction(unit, target)` -> number?
  - `UnitIsPlayer(unit)` -> boolean
  - `UnitNameplateShowsWidgetsOnly(unit)` -> boolean
- `C_NamePlate` namespace in current API exposes `SetNamePlateSize(width,height)` and not friendly/enemy/self split setters.
- CVar API surface uses `C_CVar.GetCVar(name)` (legacy global `GetCVar` still guarded as fallback).

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added `GetNamePlateSelectedScale()` preferring `C_CVar.GetCVar` with legacy fallback.
  - Updated target bump path to use API-backed selected-scale value conservatively.
  - Updated nameplate-size update hook to prefer `C_NamePlate.SetNamePlateSize(...)` and fallback to legacy split setters when present.

Status: Ready for Test

[2026-03-08] Iteration: Platynator-inspired enforcement pass (fast mode)

Issue:
- Nameplate scaling behavior felt inconsistent/small at close range.
- Need stronger, more reliable option enforcement without rewriting the full system.

Local comparison findings:
- `Platynator` enforces display behavior via CVar guards (`C_CVar.GetCVarInfo` + `SetCVar`) and avoids fragile assumptions.
- `ElvUI/DiabolicUI3` avoid high-frequency per-element scale thrash and keep scale changes tied to settings/driver updates.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added CVar-safe setter (`SetCVarIfSupported`) and `ApplyFriendlyNameOnlyCVars()`.
  - Friendly name-only toggle now also enforces Blizzard CVars when available:
    - `nameplateShowOnlyNameForFriendlyPlayerUnits`
    - `nameplateUseClassColorForFriendlyPlayerUnitNames`
  - Removed per-update scaling from `NamePlate_PostUpdateElements` (frequent path).
  - Scale updates now run on state transitions/full updates (`PostUpdate`, target/soft-target/focus/combat events, settings update) for more stable behavior.

Testing:
1. `/reload`
2. Toggle friendly name-only option on/off.
3. Move toward/away from friendly players and verify scale behavior feels stable/readable.
4. Target swap rapidly and verify only slight target bump (no jitter).

Status: Ready for Test

[2026-03-08] Iteration: Friendly name-only readability fixes (2 requested + logic bug)

Issue:
- Friendly name-only still looked too small until target.

Fixes applied:
1) CVar scale lock while name-only is enabled:
- Force `nameplateMinScale=1`, `nameplateMaxScale=1`, `nameplateLargerScale=1` in `ApplyFriendlyNameOnlyCVars()`.
- Restore addon baseline (`min=.6`, `max=1`, `larger=1`) when disabled.

2) Dedicated friendly name-only font scale setting:
- Added profile key `friendlyNameOnlyFontScale` (default `1.4`).
- Added Nameplates option slider: `Friendly name-only font scale` (80%..300%).
- Applied through runtime helper so name-only mode scales only the name text.

Logic error fixed:
- `ShouldUseFriendlyPlayerNameOnly(self)` could fail pre-target when assist checks were nil.
- Added `UnitIsFriend("player", unit)` path with secret-safe fallback and reaction fallback,
  so friendly player detection no longer depends on target state.

Testing:
1. `/reload`
2. Enable friendly name-only.
3. Stand near friendly players before targeting: verify mode is already active and readable.
4. Adjust `Friendly name-only font scale` slider and confirm immediate readability change.
5. Disable option and verify CVars/visuals return to baseline.

Status: Ready for Test

[2026-03-08] Iteration: Friendly target scaler from Platynator pattern

Issue:
- Friendly name-only plates became too large when targeted.

Platynator-inspired adjustment:
- Keep target scaling explicit/modifiable through a dedicated setting, similar to Platynator's dedicated target-scale handling.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added profile key `friendlyNameOnlyTargetScale` (default `0.9`).
  - Added `GetFriendlyNameOnlyTargetScale()` helper.
  - Updated target scale math in `GetEffectivePlateScale(self)`:
    - neutralize Blizzard selected-scale via division by current selected-scale value
    - apply friendly-target scale option value as the final target factor
- `Options/OptionsPages/Nameplates.lua`
  - Added slider: `Friendly target scale (%)` (50-140, default 90).

Result:
- Friendly plates can stay readable before target while not oversizing when targeted.

Status: Ready for Test

[2026-03-08] Iteration: Centered nameplate sliders at 100% defaults

Issue:
- Slider center/readability was inconsistent because 100% was not centered for all nameplate sliders.

Update:
- `Options/OptionsPages/Nameplates.lua`
  - `Friendly name-only font scale` slider range changed to `50-150` and fallback default is now `100` (`1.0`).
  - `Friendly target scale (%)` slider range changed to `50-150` and fallback default is now `100` (`1.0`).
  - `Nameplate Scale (%)` slider range changed to `50-150` so `100` is centered.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Profile defaults aligned to `friendlyNameOnlyFontScale = 1` and `friendlyNameOnlyTargetScale = 1`.

Testing:
1. `/reload`
2. Open Nameplates options and verify all three sliders visually center at `100`.
3. Toggle friendly name-only and verify baseline size remains readable before target.
4. Target a friendly player and verify only the configured target delta is applied.

Status: Ready for Test

[2026-03-08] Iteration: Normalize friendly sliders so UI 100 = requested defaults

Issue:
- User requested slider display default of 100 while preserving intended effective defaults:
  - Friendly name-only font default should be 250%
  - Friendly target default should be 50%

Update:
- `Options/OptionsPages/Nameplates.lua`
  - Added normalized mapping constants:
    - `FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT = 2.5`
    - `FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT = 0.5`
  - Slider UI now maps `100` to those effective defaults:
    - Font effective scale = `2.5 * (slider/100)`
    - Target effective scale = `0.5 * (slider/100)`
  - Inverse mapping in getters keeps saved values displayed relative to this 100 baseline.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Profile defaults set to `friendlyNameOnlyFontScale = 2.5` and `friendlyNameOnlyTargetScale = 0.5`.
  - Runtime fallback for friendly target scale aligned to `0.5`.

Testing:
1. `/reload`
2. Open Nameplates options and verify both friendly sliders show `100` at defaults.
3. Verify effective behavior matches old intent (readable font at default, smaller target bump at default).

Status: Ready for Test

[2026-03-08] Iteration: Apply stable scale logic to all nameplates

Issue:
- Non-target nameplates could still look too small due distance-based CVar scale reduction.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added global scale constants:
    - `GLOBAL_NAMEPLATE_MIN_SCALE = 1`
    - `GLOBAL_NAMEPLATE_MAX_SCALE = 1`
    - `GLOBAL_NAMEPLATE_LARGER_SCALE = 1`
  - Updated `ApplyFriendlyNameOnlyCVars()` to always enforce those global scale CVars for all nameplates.
  - Updated default CVar table to use global constants for `nameplateMinScale`, `nameplateMaxScale`, and `nameplateLargerScale`.

Result:
- Nameplates no longer shrink below readable size when not targeted.
- Friendly-name-only specific toggles remain in place, but scale stability now applies globally.

Testing:
1. `/reload`
2. In open world, observe non-target nameplates at multiple distances.
3. Confirm they remain readable and do not drop to tiny size compared to target plates.
4. Toggle friendly name-only on/off and confirm class-color/name-only behavior still works.

Status: Ready for Test

[2026-03-08] Iteration: Fast-mode non-target tiny plate logic correction

Issue:
- Nameplates still appeared too small when not targeted.

Root-cause adjustments:
1) Global baseline scale math was still effectively too low for non-target readability.
2) CVar writes could silently fail on some client states due strict `GetCVarInfo` gate.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added global effective baseline multiplier for all plates in `GetEffectivePlateScale()`:
    - `GLOBAL_NAMEPLATE_BASE_SCALE_MULTIPLIER = 1.5`
    - Effective scale now: `ns.API.GetScale() * profileScale * 1.5`
  - Reduced default target bump for all plates:
    - `nameplateSelectedScale` from `1.1` -> `1.05`
    - fallback selected scale from `1.1` -> `1.05`
  - Hardened CVar setter:
    - `SetCVarIfSupported()` now attempts `C_CVar.SetCVar` via `pcall` first, then falls back to `SetCVar`.
    - avoids dropouts when `GetCVarInfo` probing is inconsistent.

Testing:
1. `/reload`
2. Verify non-target nameplates at typical world distance are now readable.
3. Target and untarget rapidly to confirm target bump is present but slight.
4. Move in/out and verify perceived size no longer feels tiny while untargeted.

Status: Ready for Test

[2026-03-08] Iteration: Normalize global nameplate scale math + add sliders (Platynator-style target control)

Issue:
- Need same normalized slider behavior for global nameplates as friendly target controls.
- Need explicit user control for all-nameplate target scale.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added profile defaults:
    - `scale = 1.5` (readable baseline)
    - `nameplateTargetScale = 1.05`
  - Replaced hardcoded base multiplier usage with profile-driven scale in `GetEffectivePlateScale()`.
  - Added `GetNamePlateTargetScaleSetting()` and applied it as fallback for selected scale reads.
  - `ApplyFriendlyNameOnlyCVars()` now also enforces `nameplateSelectedScale` from profile.
- `Options/OptionsPages/Nameplates.lua`
  - Main `Nameplate Scale (%)` is now normalized around default 1.5x:
    - UI `100` = effective `1.5` baseline.
  - Added `Nameplate target scale (%)` slider:
    - UI `100` = effective `1.05` target scale.
  - Both use same normalized math model already used for friendly target slider.

Platynator alignment:
- Mirrors Platynator pattern of explicit target-scale CVar control (`nameplateSelectedScale`) on settings refresh.

Testing:
1. `/reload`
2. Verify `Nameplate Scale (%)` at 100 yields readable untargeted plates.
3. Verify `Nameplate target scale (%)` at 100 gives slight target bump.
4. Adjust both sliders and confirm immediate effect.

Status: Ready for Test

[2026-03-08] Iteration: Rebase global nameplate defaults + widget option ordering + WoW12 API check

Request:
- Make `Nameplate Scale` default map so UI 100 = effective 200%.
- Make `Nameplate target scale` default map so UI 100 = effective 50%.
- Move `Show Blizzard widgets` to bottom.
- Verify if widget option still does anything in WoW12 secret mode.

Update:
- `Options/OptionsPages/Nameplates.lua`
  - `NAMEPLATE_SCALE_DEFAULT` changed `1.5 -> 2`.
  - `NAMEPLATE_TARGET_SCALE_DEFAULT` changed `1.05 -> 0.5`.
  - `showBlizzardWidgets` option order moved to bottom (`order = 99`).
- `Components/UnitFrames/Units/NamePlates.lua`
  - Profile defaults changed:
    - `scale = 2`
    - `nameplateTargetScale = 0.5`
  - Runtime defaults changed:
    - `GLOBAL_NAMEPLATE_BASE_SCALE_DEFAULT = 2`
    - `GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = 0.5`
  - CVar table `nameplateSelectedScale` now follows the 0.5 default constant.

WoW12/secret-mode behavior check:
- In this addon, `showBlizzardWidgets` still has effect because oUF reparents Blizzard `WidgetContainer` onto custom unitframes (`Libs/oUF/ouf.lua`), and our toggle controls that container parent/position/alpha.
- Secret mode only disables invasive Blizzard UF patching (`PatchBlizzardNamePlate*`/Disable/Restore), but does not disable the local widget container toggle path.

API verification (wow-api MCP):
- `C_NamePlate.GetNamePlateForUnit` exists (Mainline) with `includeForbidden` param.
- `C_NamePlate.SetNamePlateSize` exists (Mainline).
- `UnitNameplateShowsWidgetsOnly` exists (Mainline).
- Frame methods used by widget toggle are valid (`SetParent`, `SetIgnoreParentAlpha`, `ClearAllPoints`, `SetPoint`).

Testing:
1. `/reload`
2. Nameplates options:
   - Verify `Nameplate Scale` at UI 100 is your new baseline.
   - Verify `Nameplate target scale` at UI 100 is 0.5 behavior.
3. Verify `Show Blizzard widgets` appears at bottom and toggles widgets visibility/placement on plates that expose widgets.

Status: Ready for Test

[2026-03-08] Iteration: Separate friendly/enemy scale sliders + scale-math cleanup

Issue:
- Request for separate player/friendly vs enemy sliders.
- Scaling logic felt inconsistent due mixed custom frame scaling and Blizzard target-scale CVar path.

Update:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added profile keys:
    - `friendlyScale`
    - `enemyScale`
    - `friendlyTargetScale`
    - `enemyTargetScale`
    - kept `nameplateTargetScale` for backward compatibility fallback.
  - Added hostile detection helper for per-unit relation scaling.
  - `GetEffectivePlateScale()` now applies scale in one deterministic order:
    1. base (`ns.API.GetScale() * profile.scale`)
    2. relation scale (`friendlyScale` or `enemyScale`)
    3. target scale (`friendlyTargetScale` or `enemyTargetScale`)
    4. friendly name-only override path still uses dedicated `friendlyNameOnlyTargetScale`.
  - Neutralized Blizzard target scaling CVar to avoid double-scaling conflicts:
    - `nameplateSelectedScale = 1`
    - target scaling now handled in addon math only.
- `Options/OptionsPages/Nameplates.lua`
  - Added sliders:
    - `Friendly/player scale (%)`
    - `Enemy scale (%)`
    - `Friendly/player target scale (%)`
    - `Enemy target scale (%)`
  - Enemy target slider writes both `enemyTargetScale` and legacy `nameplateTargetScale` for compatibility.

Why this should fix the "something is off" feeling:
- Previous behavior combined custom scale and Blizzard selected-scale, making target/non-target transitions hard to reason about.
- New path uses one source of truth (addon-side scale math), with per-relation controls.

Testing:
1. `/reload`
2. Set all new sliders to `100`.
3. Compare untargeted friendly/player vs enemy plates by adjusting `Friendly/player scale` and `Enemy scale` independently.
4. Target a friendly then an enemy and verify target size follows respective target sliders.
5. Toggle friendly name-only and confirm dedicated friendly name-only target slider still controls that mode.

Status: Ready for Test

[2026-03-08] Iteration: Player vs enemy scale sliders + target-scale math deconflict

Issue:
- Request to split scale sliders by relation (friendly/player vs enemy).
- Scale behavior felt off due mixed addon frame scaling + Blizzard selected-target CVar scaling.

Update:
- `Options/OptionsPages/Nameplates.lua`
  - Added new sliders:
    - `Friendly/player scale (%)`
    - `Enemy scale (%)`
    - `Friendly/player target scale (%)`
    - `Enemy target scale (%)`
  - Enemy target slider writes both new key (`enemyTargetScale`) and legacy key (`nameplateTargetScale`) for compatibility.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added profile defaults:
    - `friendlyScale`, `enemyScale`, `friendlyTargetScale`, `enemyTargetScale`
  - Added hostile-relation detector and per-relation getters.
  - Reworked `GetEffectivePlateScale()` to apply scale in a single deterministic path:
    1. global base scale
    2. relation scale (friendly/enemy)
    3. relation target scale (friendly/enemy)
    4. dedicated friendly name-only overrides when active
  - Neutralized Blizzard selected-target scale (`nameplateSelectedScale = 1`) to avoid double-application/conflicting math.

Why this should feel correct:
- Only one scaling system now drives runtime size (addon frame scale math).
- Friendly/enemy and target/non-target differences are explicit and independent.

Testing:
1. `/reload`
2. Set all new relation sliders to 100.
3. Compare untargeted friendly/player and hostile units while tuning their individual scale sliders.
4. Target friendly and hostile units and verify each uses its own target slider.
5. Toggle friendly name-only and verify its dedicated slider still controls that path.

Status: Ready for Test

[2026-03-08] Iteration: Platynator-safe driver refresh paths + feature planning pass

Request:
- Recheck against Platynator and implement safe paths from that.
- Create a feature-planning file using Platynator, DiabolicUI3, ElvUI, FeelUI and GW2UI as local references.

Safe-path implementation:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added explicit driver refresh helper inspired by Platynator/Diabolic driver orchestration:
    - reapplies native nameplate size via driver `SetSize(...)`
    - reapplies driver CVars via driver `SetCVars(...)`
  - Added active-plate refresh helper for frame-side scale/visual updates.
  - Added combat-safe deferral:
    - if native driver refresh would happen in combat, defer until `PLAYER_REGEN_ENABLED`.
  - Added refresh triggers on:
    - `PLAYER_ENTERING_WORLD`
    - `UI_SCALE_CHANGED`
    - module-level `PLAYER_REGEN_ENABLED`
  - This aligns AzeriteUI more closely with Platynator's explicit update cycle while keeping the current architecture.

Research/planning output:
- Added `Docs/Nameplate Feature Plan.md`
  - prioritizes realistic follow-up features
  - separates safe/high-value borrowable ideas from risky/avoid items under WoW12 secret-mode constraints
  - uses local addon files as sources

Key comparison outcomes:
- `Platynator`: best source for safe update orchestration, clickability/hit-test controls, simplified plates, friendly-in-instance modes, cast/mouseover/not-target alpha-scale behaviors.
- `DiabolicUI3`: confirms safe oUF driver pattern for explicit `SetSize` and hit-test handling.
- `ElvUI`: strongest source for fine-grained visibility toggles and plugin-style extras (quest, PvP, indicators).
- `FeelUI`: good reference for separate friendly/enemy layout density, but Blizzard hard-disable approach is risky for WoW12.
- `GW2_UI`: weaker direct source for nameplate features locally; strongest nearby idea is nameplate-anchored combat text.

Testing:
1. `/reload`
2. Verify scales remain correct after UI scale changes.
3. Change nameplate sliders, enter combat, leave combat, and confirm native driver settings recover cleanly.
4. Review `Docs/Nameplate Feature Plan.md` for follow-up prioritization.

Status: Ready for Test
