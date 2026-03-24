
# Changelog

Release note rule: each version entry must include only what changed since the previous release (delta-only).
Do not repeat older items from prior versions in newer entries.

## 5.3.23-JuNNeZ (2026-03-24)

### Highlights
- Fixed a recurring `/az` options crash that could block the raid-frame and party health-color settings pages from opening when a locale lookup returned no value.
- Improved hostile interruptible castbar colors so target and nameplate casts show ready, unavailable, and protected states during combat (work-in-progress, may still fall back under some conditions).

### Access
- Open `/az -> Unit Frames -> Raid Frames (5/25/40)` or `/az -> Unit Frames -> Party` — health-color sections now open reliably again.

### Internal
- Hardened `AddHealthColorOptions()` to fall back to embedded English text when locale keys are missing.
- Reworked the shared interrupt resolver with spec-aware primary/secondary pools and secret-safe cooldown evaluation.

## 5.3.22-JuNNeZ (2026-03-22)

### Highlights
- Fixed a `/az` options crash that could block the raid-frame health-color settings pages from opening after the recent localization update.

### Access
- Open `/az -> Unit Frames -> Raid Frames (5/25/40)` and the health-color section should load normally again.

### Why
- The health-color options helper assigned its localized descriptions into the wrong local-variable names, leaving AceConfig with a `nil` description field when those raid-frame pages were built.

### Internal
- Corrected the `Desc`/`desc` local-variable mismatch in `Options/OptionsPages/UnitFrames.lua` so the existing localized health-color descriptions are passed through correctly.

## 5.3.21-JuNNeZ (2026-03-22)

### Highlights
- Fixed the alternate player frame getting stuck on an incorrect sub-100 health percent after recovering to full health, which could also keep Explorer Mode from fading back out until `/reload`.
- Restored localization coverage for the newer `/az` option pages and addon landing text so recent menu additions no longer stay hardcoded in English on non-English clients.

### Access
- No new menu path. This is a follow-up hotfix release.

### Why
- The alternate-player issue came from the shared health-percent text path trusting a stale health-percent API result over the live frame cache, while Explorer Mode was also checking the low-health and low-mana toggles against the wrong condition.
- The localization issue came from newer option-page labels and descriptions being added directly as raw strings instead of being routed through the locale tables.

### Internal
- Hardened shared `[*:HealthPercent]` resolution against divergent API reads, made Explorer Mode prefer the active player-frame health cache, and corrected the low-health/low-mana toggle wiring.
- Routed recent options and landing-page strings through `AceLocale` and added the missing keys across the shipped locale files.

## 5.3.20-JuNNeZ (2026-03-22)

### Highlights
- Fixed a retail world map setup error that could trigger a Blizzard assertion when AzeriteUI restored map state while the map was not actually maximized.
- Fixed the Enhancement Shaman class-power regression where a large white secondary bar could appear beside the Maelstrom crystal, especially after login or while out of combat.

### Access
- No new menu path. This is a hotfix release.

### Why
- Both issues came from recent retail follow-up work: one in the integrated world map module's maximize-state handling, and one in the shared Shaman class-power path where the Elemental swap bar was still being kept alive outside Elemental.

### Internal
- Guarded world-map maximize-size calls so Blizzard maximized-only sizing logic only runs while the map is actually maximized.
- Limited the retail Shaman secondary `Power` bar to Elemental swap-bar mode and now explicitly hide/clean it for Enhancement and other non-Elemental Shaman states.

## 5.3.19-JuNNeZ (2026-03-22)

### The Rui Reverberation
- Integrated Rui's retail `MapShrinker` world map pass into AzeriteUI, including the integrated border look, player/cursor coordinates, and a player-facing `/az -> World Map` enable toggle that defaults on.
- Brought over Rui's retail nameplate optimization pass with the tighter health/cast presentation, restored target highlight, target-only aura support, and retail cleanup of dead load-list paths.
- Added player-facing controls around the imported nameplate changes instead of hard-locking them: `/az -> Nameplates -> Size -> Maximum distance` now supports `20` to `60`, `/az -> Nameplates -> Size -> Castbar vertical offset` tunes the normal castbar anchor, and target-only auras remain toggleable under `/az -> Nameplates -> Visibility`.
- Fixed the main follow-up regressions from the import so raid markers show again, castbars start closer to the health bar by default, and long creature/cast names behave more like stock instead of clipping/wrapping into the tighter bars.

### Access
- Nameplate visibility and aura options: `/az -> Nameplates -> Visibility`
- Nameplate size, distance, and castbar offset: `/az -> Nameplates -> Size`
- World map toggle: `/az -> World Map`
- Rui credit on the addon landing page: `Blizzard Settings -> AzeriteUI -> Credits & Maintainers`

### Why
- Rui's retail patch set cleaned up the world map and nameplate presentation for retail, but this branch already had newer behavior in a few runtime paths and also needed player-facing controls where Rui's copy used fixed retail defaults.
- This follow-up keeps the imported retail look/performance wins while preserving the branch's newer pieces and tightening the imported visuals back toward AzeriteUI stock behavior where the Rui layout exposed clipping or visibility regressions.

### Internal
- Imported from Rui: `MapShrinker` world map integration, tighter retail nameplate health/cast proportions, restored target highlight, target-only aura baseline, retail-only file-load cleanup, and the `LibSmoothBar` throttle reduction.
- Kept from this branch: the newer `1/20` mouseover/soft-target timers instead of Rui's older `1/12`, the existing target-frame path that did not need a direct RUEM Lua port, and the branch-owned nameplate baseline where Rui's actual source did not require forcing global profile scale to `1`.
- Changed locally after import: the hard `40` nameplate distance became a slider, the world map became toggleable, AzeriteUI nameplates were made to follow Blizzard visibility CVars more closely, the standard castbar got a shipped `+8` closer baseline plus a live offset slider, the raid-marker stock `oUF` path was restored, and Rui's credits were added in the relevant options pages and top-level credits list.

### Thanks
- Thanks to Rui for the `MapShrinker` integration and nameplate optimization work that this retail merge was based on.

## 5.3.18-JuNNeZ (2026-03-21)

### Highlights
- Reduced a retail WoW 12 taint path by stopping AzeriteUI from writing replacement highlight handlers onto Blizzard-owned frame tables that could leak into Edit Mode, Encounter Warnings, and other secure systems.

### Access
- No new user-facing menu path. This is a stability hotfix.

### Why
- The failing stacks were inside Blizzard secure/UI systems while marked as tainted by AzeriteUI, which matched the repo’s existing warning about replacing Blizzard-owned methods in current retail.
- This patch removes the remaining live instances of that method-replacement pattern from the affected Blizzard support-frame suppression paths.

### Internal
- Removed the live `HighlightSystem` / `ClearHighlight` replacement from Blizzard mirror timers and cleaned up the same stale pattern in the related retail support-frame modules.

## 5.3.17-JuNNeZ (2026-03-21)

### Highlights
- Added interrupt-readiness coloring to enemy nameplate castbars so interruptible casts read more clearly when your kick is ready, unavailable, or the cast is protected.
- Reworked AzeriteUI nameplate sizing so friendly players, friendly NPCs, enemies, soft targets, and hard targets follow clearer separate scale paths instead of sharing one oversized friendly baseline.
- Added a dedicated Friendly NPC size control and stabilized soft-target handling so interact/soft-target plates behave more predictably without leaning on Blizzard scale mode.
- Expanded player-frame aura-row customization with a cleaner basic/advanced split, while keeping AzeriteUI stock behavior available as the default path.
- Reworked Party Frames aura controls so filtering, layout, and dispellable-debuff emphasis are easier to tune and read in `/az`.
- Fixed Blizzard duplicate support frames that could still appear alongside AzeriteUI, including battleground carrier frames and the Blizzard breath bar mirror timer.
- Improved class-power click blocking so visible Paladin Holy Power coverage matches the actual art footprint more reliably.

### Access
- Nameplate size controls: `/az -> Nameplates -> Size`
- Player aura row settings: `/az -> Unit Frames -> Player`
- Party aura row settings: `/az -> Unit Frames -> Party Frames`
- Aura header targeting options: `/az -> Aura Header`

### Why
- This stable follow-up focuses on visual clarity and duplicate-frame cleanup in active retail WoW 12 gameplay, with extra attention on nameplate scale consistency.
- Castbars, nameplates, aura rows, party-frame aura visibility, and Blizzard frame suppression should now behave more predictably without relying on external addon workarounds.

### Internal
- Normalized retail aura metadata consumers so `spellId`/`spellID` registrations resolve more consistently across filtering, sorting, and styling.
- Moved retail interrupt spell ownership into shared aura data helpers instead of maintaining a duplicate castbar-only map.

## 5.3.16-JuNNeZ (2026-03-20)

### The Signalglass
- Expanded party-frame aura controls and stabilized harmful/dispellable debuff handling, including a frame glow so dispellable states are easier to read.
- Split power value alpha control so player and target power text can be tuned independently.
- Disabled the broken white absorb/heal-prediction overlay on non-player/target frames until a safer retail path is ready.
- Hid duplicate Blizzard battleground carrier/arena support frames that could appear alongside AzeriteUI in current WoW 12 contexts.
- Reworked party and raid health-bar coloring so you can choose AzeriteUI class colors, Blizzard class colors, or flat health green with class color only on mouseover.

### Access
- Party health color controls: `/az -> Unit Frames -> Party Frames`
- Raid health color controls: `/az -> Unit Frames -> Raid Frames (5/25/40)`
- New options:
  - `Use Class Colors`
  - `Use Blizzard Health Bar Colors`
  - `Only Show Class Color on Mouseover`

### Why
- Party and raid health colors now read more clearly and behave more predictably.
- Players can keep a simple green health baseline, switch to Blizzard palette parity, or only surface class/reaction colors when hovering a frame.
- The release also reduces duplicate or broken overlays and improves readability across common unit-frame states.

### Internal
- Expanded the maintainer-only `/aztest` runtime preview flow for supported unit-frame layouts.
- Continued boss/arena reverse-fill and fake-fill groundwork against the target-frame path while narrowing remaining mismatches to the preview/test presenter instead of live target rendering.

## 5.3.15-JuNNeZ (2026-03-18)

### The Aura Homeostasis
- Reworked the retail aura handling around WoW 12 secret-value restrictions so player-frame and top-right aura behavior stays closer to AzeriteUI stock intent without combat-state disappearance.
- Converted the top-right aura header to a safer mixed modern data path, reducing blank-icon and border-only failures when fresh auras are gained in combat.
- Restored stock-style player-frame combat relevance as the default behavior, while keeping new player-aura filtering controls available for local tuning.
- Fixed party/player aura settings wiring so growth and spacing options actually apply to the live aura layout.

### Fixes & Changes
- Removed forbidden aura-table iteration in the WoW 12 Blizzard-fix paths.
- Reduced chat-related taint risk by skipping temporary chat frame styling/hooks that could bleed into Blizzard whisper handling.
- Added clearer `/az` option grouping and labeling for aura header, unit-frame aura settings, and related UI pages.
- Reframed the Aura Header targeting options so WoW 12 only shows the setting that is actually active.

## 5.3.14-JuNNeZ (2026-03-16)

### Fixes & Changes
- Disabled the golden glow effect for soul fragments (Demon Hunter/Enhancement Shaman) due to visual bugs; groundwork for future improvements remains in code (commented out).
- Soul Fragments Display Mode dropdown is now always visible for all Demon Hunters, regardless of specialization.

### Internal
- Code cleanup and groundwork for future class power visual improvements.

## 5.3.13-JuNNeZ (2026-03-14)

### Fixes
- Fixed battleground/local-party frame handling so the party-style header follows the player's actual raid subgroup in PvP raid contexts instead of briefly showing and then vanishing after the roster settles.
- Corrected the party-header child reflow so PvP/battleground party members no longer collapse onto overlapping visual slots.
- Removed the bad `/az -> Unit Frames` options-tree rule that hid `Raid Frames (5)` whenever Party Frames enabled any raid visibility toggle.

### Thanks
- Thanks to AceShotz for finding the battleground party-frame bug and testing the fix in-game.

# 5.3.12-JuNNeZ (2026-03-14)

### Fixes
- Restored the stock player-frame PvP badge to AzeriteUI's own Alliance/Horde media instead of leaving the override path without assigned faction textures.
- Moved the default player-frame PvP badge anchor back onto a centered base point and added `/az -> Unit Frames -> Player -> PvP Badge` X/Y offset controls plus a reset action for local repositioning.

## 5.3.11-JuNNeZ (2026-03-14)

### Fixes
- Added `/az` options to hide or shrink the large priority debuff icon on retail 11-25 and 26-40 raid frames.
- Kept the change on the visual `PriorityDebuff` element only, so the big-debuff option does not touch secure raid header attributes, visibility drivers, or protected click/layout paths.

### Thanks
- Thanks to Yarko for testing the retail large-raid changes and confirming the updated behavior in-game.

## 5.3.10-JuNNeZ (2026-03-14)

### Fixes
- Reworked retail 11-25 and 26-40 raid headers to explicitly re-anchor their spawned child buttons after secure roster updates, fixing the compact square/grid bunching in larger raids.
- Fixed the original secure raid-button click taint: the header-spawned party/raid unit buttons were hitting `ADDON_ACTION_BLOCKED` because addon code was calling `RegisterForClicks("AnyUp")` from insecure Lua while oUF was styling secure group-header children.
- Corrected the first workaround for that click bug: moving `RegisterForClicks("AnyUp")` into the restricted `oUF-initialConfigFunction` did not work because `RegisterForClicks` is not exposed inside secure header snippets. The final fix leaves secure header children on oUF's built-in `*type1 = target` and `*type2 = togglemenu` setup, while only non-header frames register clicks through the shared initializer.

## 5.3.9-JuNNeZ (2026-03-14)

### Fixes
- Moved the retired retail `/az remove addontext|clocktext` behavior into Minimap options, migrated any saved legacy text-hide flags, and switched remaining hardcoded AzeriteUI media references in that path over to addon-safe media lookups.
- Hardened raid header refresh in raid frames so stale or incomplete saved layout values can no longer feed invalid secure header attributes and break raid frames in raid groups.

## 5.3.8-JuNNeZ (2026-03-13)

### Fixes
- Corrected the release version metadata from `5.3.7-JuNNeZ` to `5.3.8-JuNNeZ` in the TOC, build script, and changelog after finalizing the assisted-highlight release state.

### Known Issues
- The `/az` action-bar option `Cast action keybinds on key down` can still throw Blizzard Settings BugSack noise for `ActionButtonUseKeyDown` on WoW 12. The bars themselves continue to function, but the settings-side error remains unresolved in this release.
- Assisted highlight color customization is not ready for release yet. The circular assisted highlight currently ships in Blizzard blue while work continues on a stable multi-color version.

## 5.3.7-JuNNeZ (2026-03-13)

### Fixes
- Restored action-bar spell proc highlights by reconnecting `LibActionButton` overlay-glow handling to AzeriteUI's custom `CustomSpellActivationAlert` texture on the main bars.
- Added Blizzard assisted-combat highlight support to AzeriteUI action bars and kept the assisted suggestion circular on AzeriteUI buttons instead of falling back to the native square frame.

### Known Issues
- The `/az` action-bar option `Cast action keybinds on key down` can still throw Blizzard Settings BugSack noise for `ActionButtonUseKeyDown` on WoW 12. The bars themselves continue to function, but the settings-side error remains unresolved in this release.

## 5.3.6-JuNNeZ (2026-03-13)

### Axiom Extravaganza
- Reworked the WoW 12 compact-frame fix strategy back toward root-cause ownership handling instead of broad shared Blizzard wrappers.
- Kept the original compact aura `isHarmful` secret-value fix while stripping back the taint-prone symptom guards that cascaded into party, Edit Mode, and nameplate regressions.
- Tightened Blizzard compact party/raid shutdown so hidden Blizzard frames stop participating in roster refresh paths more reliably.
- Restored a secret-mode visual-only hide for Blizzard nameplate health bars so duplicate Blizzard bars no longer show behind AzeriteUI nameplates.

### Fixes
- Restored and improved the BugSack copy workflow so the current session can be exported into a selectable multiline copy window again.
- Added the hidden `SaiyaRatt Exposition` command and improved SaiyaRatt alternate-player live refresh and threat-texture stability.
- Clarified the passive WoW 12 path in `FixBlizzardBugs.lua` so the legacy lower-half Blizzard rewrites are no longer misleading during maintenance.

## 5.3.5-JuNNeZ (2026-03-12)

### Fixes
- Restored the embedded `oUF`, `oUF_Plugins`, and `oUF_Classic` libraries to the pre-sync snapshot after the newer mixed library state introduced startup, travel, combat, and secret-value regressions.
- Added local `Backups/` snapshots to `.gitignore` so operational rollback folders no longer clutter the worktree.

## 5.3.4-JuNNeZ (2026-03-11)

### Saiyaratt Exposition
- Added a built-in selectable SaiyaRatt profile preset alongside the default Azerite profile.
- Recreated the verified SaiyaRatt player, alternate-player, and target unitframe presentation using only the referenced AzRattUI assets and layout deltas.
- Added the required SaiyaRatt media for the alternate-player power bar and compact target presentation.
- Gated SaiyaRatt-specific target and alternate-player behavior so the stock Azerite profile remains unchanged.
- Fixed SaiyaRatt target health-percent placement and percent sourcing so the compact target crystal follows the live health percentage path more reliably.
- Prevented Blizzard's alternate power bar restore path from reintroducing the old playeralternate crystal while SaiyaRatt is active.

## 5.3.3-JuNNeZ (2026-03-11)

### Fixes
- Party frame priority debuff stability:
  - Normalized oUF priority-debuff dispel entries to numeric priorities so party leader and roster updates no longer hit the boolean-vs-number compare error.

## 5.3.2-JuNNeZ (2026-03-10)

### Fixes
- Class Power stability and layout follow-up:
  - Restored safe default anchoring for class power on fresh/reset/copied profiles so `/lock` placement stays aligned after reinstall or profile changes.
  - Synced the Elemental Shaman one-time anchor migration with the movable `/lock` anchor state.
  - Fixed Enhancement Shaman class power visibility gating so the configured spell-known requirement is actually honored in both retail and classic/shared oUF copies.
  - Removed dead Elemental class power toggle/offset leftovers from runtime defaults and options.
  - Split Rogue 6-7 combo point rendering onto a dedicated extended arc so Rogue gets the larger end-cap layout without changing Feral's original 5-point finisher presentation.
  - Prevented pre-specialization fallback from forcing the Elemental swap-bar path before spec is known.

## 5.3.1-JuNNeZ (2026-03-09)

### Fixes
- Tooltip secret-value hardening:
  - Guarded unit-tooltip nameplate detection against secret unit tokens in arena and other restricted contexts.
  - Added safe tooltip unit fallback and protected `C_NamePlate.GetNamePlateForUnit` lookups to stop tooltip backdrop styling errors.
- Mouseover cast follow-up:
  - Restored `checkmouseovercast` propagation on AzeriteUI action buttons so Blizzard mouseover-cast keyboard targeting can work again when the CVar is enabled.
  - Added `enableMouseoverCast` CVar refresh handling for action-bar button settings.
  - Registered AzeriteUI raid unit buttons for clicks to match secure party-frame behavior for click-cast style interaction.

## 5.3.0-JuNNeZ (2026-03-08)

### The big nameplate rework
- Reworked AzeriteUI nameplate scaling so friendly, hostile, target, and friendly name-only plates all use one explicit scale model instead of mixed Blizzard/addon scaling.
- Added separate sliders for global nameplate scale, friendly/player scale, enemy scale, friendly/player target scale, enemy target scale, friendly name-only font scale, and friendly name-only target scale.
- Normalized slider math so `100%` maps to the intended default for each control, and additive target-scale sliders now allow `0` for no extra target bump.
- Fixed hostile target plates shrinking when targeted by changing target scaling to additive bump logic instead of raw multiplier logic.
- Hardened runtime fallback/default handling so missing or stale profile values no longer drift to smaller-than-intended plate or font scales.
- Added stronger nameplate driver refresh/update handling inspired by Platynator so scale and native size/CVar settings reapply more reliably after world entry, UI scale changes, and combat deferral.
- Friendly player name-only mode now fully hides remaining healthbar visuals and overlays and keeps only the class-colored name at the configured size.

### Unit Frames
- Cleaned up `Unit Frames -> Class Power` option visibility so class/spec-specific controls only appear when relevant.
- Reordered Class Power options so shared controls stay grouped and niche toggles no longer crowd the section.
- Restricted the Elemental crystal/bar resource split option to Elemental Shaman, Enhancement Maelstrom settings to Enhancement, Vengeance-only 10-point display mode to Vengeance Demon Hunter, and similar class power toggles to their owning class/spec.

## 5.2.235-JuNNeZ-hotfix-20260308 (2026-03-08)

### Fixes
- Elemental Shaman resource presentation rework:
  - Replaced Elemental class-plate style points with a dedicated secondary resource bar using pet-bar art.
  - Added crystal/bar split modes so the Power Crystal can show either Maelstrom or Mana while the secondary bar shows the other resource.
  - Added live numeric value rendering on the secondary bar using the same display-read strategy as the power crystal (`short`, `full`, `percent`, `shortpercent`).
  - Added one-time default anchor migration for the new bar placement and preserved `/lock`-moved positions across reloads.
- Shaman power update stability:
  - Hardened Retail and Classic oUF classpower Maelstrom handling against secret/unreadable payloads using safe fallbacks.
  - Added/expanded Shaman power event coverage so Enhancement/Elemental updates remain responsive during combat.
- Combat lockdown safety:
  - Deferred Elemental display-mode geometry/element toggles until `PLAYER_REGEN_ENABLED` to prevent `ADDON_ACTION_BLOCKED` when switching mode in combat.
- Blizzard action button taint follow-up:
  - Removed `statehidden` attribute write from Blizzard action button hide path to reduce protected-action taint risk.
- Unitframe options:
  - Added Elemental crystal/bar split selector in UnitFrames options and moved the 10-point Soul Fragments display selector lower in the Class Power section.

## 5.2.235-JuNNeZ (2026-03-08)

### Fixes
- Minimap tracking right-click reliability follow-up:
  - Added dedicated retail minimap click handler overlay and improved tracking button discovery/fallback validation.
  - Prevents false-positive "opened" paths when tracking menu is not actually shown.
- Bossbar health text fallback cleanup:
  - `*:Health(true)` smart/full output now prefers secret-safe formatted health values and no longer surfaces literal `?` placeholders.
- WoW12 compact frame taint hardening:
  - Removed compact manager `IsShown` setting write from quarantine path to avoid protected `HideBase()` taint (`ADDON_ACTION_BLOCKED`) during roster/EditMode refresh.

### Added
- New `GameMenuSkin` module:
  - Added AzeriteUI skinning for ESC game menu frame/buttons via `Components/Misc/GameMenu.lua`.
  - Wired module load in `Components/Misc/Misc.xml`.
- Added resting icon prefix in info panel resting text for clearer status readability.

## 5.2.234-JuNNeZ (2026-03-07)

### Fixes
- Player Alternate devmode gating follow-up:
  - Devmode is now required to enable Player Alternate from options, but no longer required to keep it active at runtime.
  - Turning devmode off no longer force-disables/hides an already-enabled Player Alternate frame.

## 5.2.233-JuNNeZ (2026-03-07)

### Fixes
- Action bar keybind routing follow-up:
  - Override click bindings now use a dedicated `Keybind` button token instead of `LeftButton`.
  - Restores shift-mod macro behavior on bar 1 while preserving dynamic paging/dragonriding action functionality.
- Minimap tracking right-click reliability follow-up:
  - Added robust retail tracking open chain (proxy/menu visibility checks + fallback order) while keeping tracking hidden safely.
  - Added minimap click registration/mouse safeguards and fixed crafting-order tooltip count lookup path.
- Player Alternate toggle behavior:
  - Enabling/disabling Player Alternate now cleanly syncs with the main Player frame without requiring `/devmode` re-toggle workarounds.
- Shaman class power support and visibility:
  - Added Maelstrom toggle/visibility integration in unitframe options.
  - Removed talent-spell gate from oUF classpower for Enhancement Maelstrom detection.
  - Added Maelstrom to the 10-point classpower renderer path with Shaman-specific color treatment.
- Class power click-through and visuals:
  - Hardened click-blocker alignment/sync behavior.
  - Fixed stacked-mode threshold and overflow dimming so 5 vs 6 points are clearly distinct.

## 5.2.232-JuNNeZ (2026-03-07)

### Fixes
- Tooltip deep-scan stability hardening (DiabolicUI-aligned):
  - Reworked tooltip backdrop cache to avoid `SetAllPoints()` secret-size inheritance.
  - Wrapped tooltip backdrop mixin callbacks (`OnBackdropSizeChanged`, `ApplyBackdrop`, `SetupTextureCoordinates`) and frame-level sync in protected calls.
  - Hardened tooltip default-anchor handling with forbidden/map-parent guards and protected placement.
  - Guarded tooltip post-call/statusbar update paths to reduce WoW12 taint/error cascades while keeping AzeriteUI tooltip skin enabled.
- Restored actionbar spell chat links on modified click:
  - `Shift+Click`/`CHATLINK` on action buttons now inserts spell links into the active chat edit box again.

## 5.2.231-JuNNeZ (2026-03-07)

### Fixes
- Aligned WoW12 Blizzard frame disable behavior with ElvUI/GW2UI/DiabolicUI/FeelUI patterns:
  - Removed taint-prone shared Blizzard rewrites in `FixBlizzardBugsWow12` (no global castbar mixin hooks, no global aura API rewrites).
  - Removed reusable `Show -> Hide` quarantine hooks and anonymous pool-frame quarantine.
  - Kept deterministic disable/reparent only for explicit Blizzard party/raid/arena frame names, reducing nameplate/EditMode taint spillover.
- Focus frame washout fix:
  - Focus target highlight now initializes hidden and uses focus tint when shown.

### Known Bugs (Under Investigation)
- Rare Blizzard arena/compact aura defensive check can still throw a forbidden-table error in `AuraUtil.IsBigDefensive`.
- Rare Blizzard compact party health-color update can still throw a secret-value compare error in `CompactUnitFrame_UpdateHealthColor`.

## 5.2.230-JuNNeZ (2026-03-07)

### Fixes
- Fixed talent/spec change castbar crash (`CastingBarFrame.lua:GetTypeInfo` forbidden-table indexing):
  - Added WoW 12 guards for `GetTypeInfo` on castbar mixins and live castbar instances (including `OverlayPlayerCastingBarFrame`) with safe fallback type info.
  - Replaced taint-prone Blizzard player/pet castbar suppression (`UnregisterAllEvents()+Hide()`) with non-invasive alpha suppression so Blizzard castbar internals stay intact during specialization/talent transitions.

## 5.2.229-JuNNeZ (2026-03-07)

### Fixes
- Reworked WoW 12 tooltip handling so AzeriteUI tooltip skin can stay enabled with secret-value safety:
  - Kept `SharedTooltip_SetBackdropStyle` hook active.
  - Added non-secret width/height gating + cached dimension fallback.
  - Added protected backdrop apply fallback to Blizzard visuals on failure.
- Added WoW 12 tooltip money guards (`SetTooltipMoney`/`MoneyFrame_Update`) and reduced tooltip-related taint paths.
- Fixed top-right buff cancel regression by registering right-clicks on `AzeriteAuraTemplate` secure buttons.
- Reduced secret-mode taint in nameplate/CUF paths by stopping risky Blizzard nameplate mutations.
- Hardened compatibility portrait shim and removed forced global `SetPortraitToTexture` override to avoid secure-call taint (`SetAvatarTexture` chain).
- Hardened action button press/hold state updates and hidden stock Blizzard button isolation to reduce `ActionButton.lua` secret-value errors.
- Removed player/target health bar spark visuals (spark no longer rendered).
- Added AceAddon compatibility alias so external tools expecting `AceAddon:GetAddon("AzeriteUI")` work with `AzeriteUI5_JuNNeZ_Edition` (restores AzUI health color picker integration path).

## 5.2.228-JuNNeZ (2026-03-06)

### Fixes
- Fixed startup banner crash from Major Faction unlock toast when re-anchoring top banners:
  - Added nil-frame guard in `Banners.TopBannerManager_Show`.
  - Prevented `frame:PlayBanner(data)` replay when `data` is nil.

## 5.2.227-JuNNeZ (2026-03-06)

### Fixes
- Fixed player power crystal current-value text update regression:
  - Restored live player power value formatter behavior to match the known-good `e53811f` path.
  - Added explicit `self.Power:ForceUpdate()` on player power-related unit events so value text refresh stays in sync with the crystal bar.
- Hardened zero-value display handling for power tags/target power text so empty values clear cleanly instead of leaving stale text.

## 5.2.226-JuNNeZ (2026-03-06)

### Fixes
- Action button count display split restored to preserve spell charge updates while keeping item stack customization:
  - Consumable/item counts still use custom display (`>1` shown, `1` hidden, `*` over max display count).
  - Non-consumable/spell charge display now uses the original action display-count path again so spell charges update correctly.
- LAB charge payload handling hardened:
  - Added charge-info normalization wrapper for action/spell charge payload variants.
  - Reintroduced action-slot spell resolution (`C_ActionBar.GetSpell` + override chain) for charge lookups.
  - Added secret-safe guards to avoid secret-value comparison errors in count/charge paths.

## 5.2.224-JuNNeZ (2026-03-06)

### Fixes

### Known Not Working

## 5.2.225-JuNNeZ (2026-03-06)

### Fixes
- Secret-value bug fix: Defensive check for secret value 'max' before comparison/arithmetic in Player.lua. Prevents taint crash on WoW 12+ secret values.
- Removed deprecated power/threat debug surfaces from `/azdebug` menu path.
- Player power crystal color/overlay cleanup: re-added `crystalOrbAccent` toggle, kept only `default`/`class` color source behavior, switched default crystal color back to stock blue base, changed accent handling to gold overlay pass.
- Removed target Power Crystal Lab options from UnitFrame settings.
- Power crystal stability/spark follow-up: added mirror-percent texture sampling opt-out flag, enabled for player crystal, pixel-aligned crystal sizing, restored visible crystal spark texture update path.
- Player crystal fakefill/overlay correction: added dedicated player power `FakeFill` texture, now drives crystal spark/overlay from fakefill percent, accent overlay anchors to fakefill/native texture bounds.

### Files Modified
- Components/UnitFrames/Units/Player.lua
- Core/Debugging.lua
- Options/OptionsPages/UnitFrames.lua
- Components/UnitFrames/Functions.lua

## 5.2.218-JuNNeZ (2026-03-05)

### Game Version Support
- **Added WoW 12.0.1 support** — Now targets and is compatible with Midnight patch 12.0.1 (120001) and 12.0.0 (120000).

### Bug Fixes
- **Fixed ExplorerMode crash** — "attempt to perform arithmetic on local 'min' (a secret number value)" error when checking player mana power. Added secret value guards to prevent arithmetic on WoW 12+ secure values.
- **Fixed BtWQuests compatibility crash** — `SetPortraitToTexture` fallback in compatibility layer no longer calls a nil original API; now safely falls back to `texture:SetTexture(asset)` when needed.
- **Fixed AuraTemplates global lookup crash** — Restored legacy global alias `AzeriteUI` for XML/legacy script compatibility after addon folder renaming.
- **Fixed enemy name visibility regressions** — Nameplate hostile units are no longer misclassified as object plates when `UnitCanAttack/UnitCanAssist` return secret values; improved target/name fallback resolution in unit tag name logic.
- **Fixed player power crystal art alignment defaults** — Updated default widget/frame/threat offsets and crystal sizing so the player power crystal, case, and threat overlays line up correctly out of the box.
- **Fixed debug SafeCall return passthrough** — `SafeCall()` now preserves a fifth return value to avoid truncated data in debug dump helpers.

## 5.2.217-JuNNeZ (2026-03-04)

### Breaking Changes
- **Removed Classic/Vanilla support** — Dropped `AzeriteUI5_JuNNeZ_Edition_Vanilla.toc` and Classic Era compatibility. This edition now targets Retail (Midnight/WoW 12+) only. Classic WoW code removal will follow in future versions.

### CurseForge & Packaging Configuration
- **Added JuNNeZ Edition CurseForge project ID** — Now uses project ID `1477618` to prevent conflicts with original AzeriteUI (ID: 298648).
- **Removed original AzeriteUI identifiers** — Removed original project IDs (`X-Curse-Project-ID: 298648` and `X-Wago-ID: R4N2PZKL`) from both TOC files.
- **Updated addon folder references** — All IconTexture paths now correctly reference `AzeriteUI5_JuNNeZ_Edition` folder name instead of generic `AzeriteUI`.
- **Added edition attribution** — TOC files now include `X-Edition: JuNNeZ Fan Edition - Not affiliated with original AzeriteUI` to clearly identify this as a fan project.
- **Fixed package configuration** — Updated build script and `.pkgmeta` to use correct addon name and removed invalid folder move directives.
- **Improved multi-version support** — GitHub Actions workflow now auto-detects all game versions (Retail, Cata Classic, Classic Era) instead of forcing retail-only.

### Bug Fixes
- **Fixed nameplate unit names in dungeons** — Hostile enemy names now display on nameplates in dungeon/instance content. Previously, names were only visible when mousing over or in active combat due to overly restrictive visibility logic.

## 5.2.216-JuNNeZ (2026-03-03)

### Demon Hunter Devourer — Soul Fragments Display
- **New soul fragments display** — Devourer DH soul fragments (0–50 stacks) now display as a 10-point combo-point-style system. Each point represents 5 stacks; points light up progressively in a spiral layout matching the rogue combo point aesthetic.
- **4 display modes** — Choose between Alpha, Gradient, Recolor, and Stacked 5-Point (hide empty, bright overflow from bottom) via Options → Unit Frames → Class Power.
- **Show Soul Fragments toggle** — New visibility toggle in Options → Unit Frames → Class Power for Demon Hunter Devourer.

### Bug Fixes
- **Fixed ActionButton taint** — `ADDON_ACTION_BLOCKED` and secret number compare errors caused by Blizzard action button hiding writing secure attributes. Now uses non-destructive hide+reparent only.

### Libraries & Internals
- **Loaded LibEditModeOverride-1.0** — Library was bundled but not loaded. Now available for future Edit Mode integration.
- **Updated LibEditModeOverride-1.0** — Applied upstream CooldownViewer slider fix from commit 39f30e5.

### Known Issues
- **Edit Mode taint errors** — Opening or closing Edit Mode causes multiple taint errors. Investigation ongoing for next version.
- **Mana orb** — Mana orb display is still under investigation for WoW 12.
- **Target castbar crop** — Some non-self target casts may still show incorrect fill behavior; probe bar validation is ongoing.

## 5.2.211-JuNNeZ (2026-03-02)
- **JuNNeZ Edition:** Updated and maintained by JuNNeZ.
- Added power text size slider for player power crystal and mana orb (50-200% scale).
- Fixed Blizzard PVP Match scoreboard pool nil Release spam (preventive guard for 3000+ errors).
- Added secret `/junnez` easter egg command for fun.
- Updated version numbering and credits across all TOC files.

## 5.2.210-Release (2026-03-01)
- Added a target castbar debug probe (`Target.Castbar.TestBar`) to compare timer-driven cast fill behavior against the current fake-fill path.
- Improved target cast runtime fallback handling by probing timer payloads (`GetTimerDuration`) in generic cast sync hooks and preserving live fill on transient pending ticks.
- Fixed `PartyFrames` post-combat callback crash (`LibMoreEvents-1.0.lua:76`) by adding the missing `PartyFrameMod.OnEvent` handler for deferred header updates.
- Improved target cast debug visibility by dumping probe castbar state/source in `/azdebug dump target`.
- Updated development guidance for WoW API tooling and MCP usage (`AGENTS.md`) to reflect current working workflow.

### Known issue (deferred)
- Target castbar crop behavior for some enemy/non-self casts is still under investigation; probe bar output is now the primary validation path.
- Mana orb status remains under active investigation in WoW12 paths.

## 5.2.209-Release (2026-02-18)
- Restored actionbar cooldown swipe/timer progression in combat by returning the cooldown pipeline to the known-good WoW12 path.
- Added release-guard comments in actionbar and cooldown code to reduce risk of future regression during patching.
- Fixed party portrait click targeting reliability (including Brann follower targeting).
- Improved unit frame/tag stability for hostile target/nameplate names and health text updates.
- Removed forced archaeology UI loading path from AzeriteUI to avoid external protected-call taint chains (`Rarity`/`Ace3`) in this environment.
- Fixed oUF health color crash when runtime color data is not a ColorMixin object (`GetRGB` nil safeguard).

### Known issue (deferred)
- Charge tracking for some spells (for example Divine Steed and Judgment) still needs additional WoW12 investigation and is deferred to the next build.
- Manaorb doesn't work still.

## 5.2.208-Release (2026-02-17)
- Improved WoW 12 secret-value stability in core UI update flows.
- Fixed player power visual update reliability (mana orb + crystal behavior).
- Fixed target health and fakefill update flow, including crop/stretch behavior.
- Stabilized target and nameplate health writes under restricted/secret value conditions.
- Improved tooltip/backdrop guard behavior for modern tooltip mixins.
- Restored WoW11 delayed module enable flow for action bars, pet bar, and stance bar.

### Known issue (deferred)
- Charge tracking for some spells (for example Divine Steed and Judgment) still needs additional WoW12 investigation and is deferred to the next build.
