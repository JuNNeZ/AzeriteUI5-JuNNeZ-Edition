# Peer Addon Review: Auras, Health/Power Bars, Secret-Value Risk

Scope: compare AzeriteUI with two popular, co-located addons that implement unit frames/nameplates—Plater (nameplates) and ShadowedUnitFrames (party/raid). Focus on how they set status-bar textures, read health/power values, and process auras, and whether any patterns could help our WoW 12.0 secret-value fixes.

## Plater
Sources: `Plater_Auras.lua`, `Plater.lua`, `libs/DF/unitframe.lua`.

- **Status-bar texture usage**
  - Bars are built with DetailsFramework statusbar wrapper; a child texture `barTexture` is created once and then assigned to the bar (`unitframe.lua` ~478–499). No per-update `SetStatusBarTexture` calls and no caching booleans.
  - Uses custom draw layers and masks; no LibSmoothBar proxy. Flicker is unlikely because texture mode never flips between proxy/native.
- **Health/power math**
  - Uses raw `UnitHealth/UnitHealthMax` arithmetic for coloring/thresholds; no guards for secret values. Calculations (e.g., gradients, threat coloring) assume numeric inputs.
- **Aura handling**
  - Slot-based scanning (`C_UnitAuras.GetAuraSlots` / `GetAuraDataBySlot` / `AuraUtil.UnpackAuraData`, lines ~41–130). Maintains multiple caches (special/extra/ghost auras) keyed by GUID and auraInstanceID.
  - Provides “extra aura” overlay system with explicit start/duration fields; pandemic curve for time-based coloring.
  - No checks for secret values; assumes all aura fields are plain numbers/strings.
- **Takeaways for AzeriteUI**
  - Texture stability comes from never swapping the StatusBar’s texture or render target after creation; we could mirror this for nameplate/target bars by avoiding LibSmoothBar proxy swaps (partly addressed via safe-value fallback) or providing a “no proxy” mode.
  - Slot-based aura iteration with per-GUID caching could reduce our aura re-reads, but still needs secret-value sanitation before indexing/sorting.

## ShadowedUnitFrames (SUF)
Source: `modules/health.lua`.

- **Status-bar texture usage**
  - Uses native Blizzard StatusBar via oUF-like wrapper; texture set once at creation (not repeatedly in updates).
  - No smoothing proxies; updates call `SetMinMaxValues` and `SetValue` directly.
- **Health/power math**
  - Gradients and offline/dead logic use direct arithmetic on `UnitHealth` / `UnitHealthMax` (`health.lua` lines ~6–80, 150–180). No handling for secret/opaque values.
- **Aura handling**
  - Debuff-based color checks iterate debuffs with `AuraUtil.UnpackAuraData(C_UnitAuras.GetDebuffDataByIndex(...))` (lines ~40–60). No guarding for secret fields or nils.
- **Takeaways for AzeriteUI**
  - Simplicity (no smoothing/proxy) avoids texture-mode flicker by never swapping bars; aligns with our move to disable smoothing on target/ToT/nameplates.
  - Does not help with secret-value crashes; confirms AzeriteUI’s extra guards are necessary for WoW 12.

## Key Differences vs AzeriteUI

- AzeriteUI uses LibSmoothBar proxies plus orientation flips; peers rely on static native statusbars without proxy swapping. This is the likely reason peers don’t see WoW 12 texture flicker.
- AzeriteUI performs secret-value sanitation (issecretvalue checks, SafeNumber/Key helpers); peers perform raw arithmetic and indexing, meaning they would crash under WoW 12 rules if fed secrets.
- Aura processing in peers is slot-based and heavily cached (Plater) vs our safer but more defensive wrappers. Peers skip secret safety, so we cannot copy verbatim.

## Actionable Ideas

1) **Proxy bypass option**: Add a LibSmoothBar “no-proxy” mode for nameplates/target bars where we set the real StatusBar texture once and drive only `SetValue`—mirroring Plater/SUF to eliminate render-mode flipping when secrets appear.
2) **Early safe-value substitution**: Keep the recent safe-value fallback (proxy swap avoidance). Consider also caching `safeMin/safeMax` per element before updates, so even transient secret responses don’t trigger proxy render.
3) **Aura slot iteration with sanitation**: Borrow Plater’s `GetAuraSlots` pattern for performance, but run every unpacked field through `SafeKey/SafeNumber` before comparisons/sorts to stay WoW 12-safe.
4) **Extra aura overlay API**: Plater’s extra-aura overlay system could be replicated for AzeriteUI nameplates, letting us detach cosmetic overlays from Blizzard aura data (avoids secret fields altogether for custom highlights).

## Applicability to current errors

- **StatusBar flicker (target/ToT/nameplates)**: Highest leverage is minimizing texture/proxy swaps (ideas 1–2). Peers show stable rendering with static textures.
- **Aura secret-value crashes**: Peers offer no secret-safe logic; only the slot/caching pattern (idea 3) is reusable once wrapped in our secret-safe helpers.
- **Heal prediction/absorb math**: Peers do raw math; not safe to reuse. Stick with AzeriteUI’s sanitized pipeline.

## FeelUI
Sources: `Modules/Unitframes/Core.lua`, `Modules/Nameplates/Core.lua`, `Modules/Unitframes/Elements/Health.lua`, `Modules/Auras/Core.lua`.

- **Status-bar usage**: Plain StatusBars with shared texture set at creation; updates are `SetMinMaxValues`/`SetValue` only. Optional smoothing flag but no proxy layer.
- **Health/power math**: Direct `UnitHealth/UnitHealthMax/UnitPower`; no secret-value guards or fallbacks.
- **Auras**: Slot-based iteration via `C_UnitAuras.GetAuraDataByIndex`; sorts/filters without secret sanitation.
- **Takeaway**: Stable textures (no flicker path), but zero WoW‑12 secret handling.

## GW2_UI
Sources: `core/Mixin/healthBarMixin.lua`, `Mainline/Units/healthglobe.lua`, `core/Castingbar/castingbar.lua`.

- **Status-bar usage**: Native StatusBars with Blizzard interpolation; textures chosen per skin and set once. No proxy/smoothing lib.
- **Health/power math**: Uses `UnitHealth`, `UnitHealthMax`, `UnitHealthPercent`; no secret checks. Heal prediction via `CreateUnitHealPredictionCalculator` without sanitation.
- **Auras**: Blizzard aura APIs with default sorting; no secret handling noted.
- **Takeaway**: Rendering is stable because textures don’t swap; still unsafe with secret values.

## Platynator
Sources: `Display/HealthBar.lua`, `Display/PowerBar.lua`, `Display/Auras.lua`.

- **Status-bar usage**: Native StatusBars with interpolation and cutaway/absorb overlays; textures set once, no proxy.
- **Health/power math**: Uses `UnitHealth/UnitHealthMax` (or calculator) directly; no secret guards.
- **Auras**: Uses `Enum.UnitAuraSortRule` where available or custom comparators on aura fields (unit, canApplyAura, expirationTime) with no secret safety.
- **Takeaway**: Stable textures, but no secret-value resilience.

## New options informed by added peers

1) **Per-frame “native only” mode**: For target/ToT/nameplates, bypass LibSmoothBar proxy entirely—use a plain StatusBar (like FeelUI/GW2_UI/Platynator) with smoothing off while keeping AzeriteUI’s secret-safe UpdateHealth/UpdatePower. Eliminates render-mode flips.
2) **Proxy stickiness**: If proxy is kept, add a flag to stay on the proxy once a secret is detected until GUID changes/rebuild; prevents repeated proxy↔custom toggles that cause flicker.
3) **Texture immutability guard**: Enforce “set texture once” for these bars (skip repeated `SetStatusBarTexture` calls) and rely solely on `SetValue`/`SetMinMaxValues` plus orientation/texcoord caching, matching peer behavior.

## Next Steps (suggested)

- Prototype a “no-proxy” path in LibSmoothBar for select frames (guarded by config) and test if flicker disappears without regressing smoothing.
- Add an optional aura-slot reader that feeds our existing Safe* helpers, then A/B compare against current aura pipeline for performance/taint.
