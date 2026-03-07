# Changelog

Release note rule: each version entry must include only what changed since the previous release (delta-only).
Do not repeat older items from prior versions in newer entries.

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
