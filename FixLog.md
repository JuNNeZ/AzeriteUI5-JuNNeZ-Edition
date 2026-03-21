
# FixLog — AzeriteUI JuNNeZ Edition

**Archive Note:** Historical entries from project inception through 2026-03-03 have been archived to `FixLog_Archive_20260303.md` (14,673 lines). This fresh log starts with version 5.2.216-JuNNeZ as the baseline.

## 2026-03-21

- **Nameplate tight health-backdrop toggle started:** Adding an in-game option to let the health backdrop hug the actual health bar instead of extending past it as a visible black frame, while keeping the current oversized art as the default.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`
- **Nameplate tight health-backdrop toggle applied:** Added a `/az -> Nameplates -> Size -> Fit health backdrop to health bar` toggle that keeps the current oversized decorative `nameplate_backdrop` art by default, but can snap the health backdrop to the exact health-bar bounds for users who want to remove the black-border look.
  - **Root Cause:** The nameplate health backdrop was intentionally larger than the live health fill (`94.3158x24.8889` backdrop versus `84x14` health bar), so the backdrop art read visually like a black border around the bar instead of a subtle behind-the-bar plate.
  - **Safety:** This is an additive profile toggle only. No texture assets or default sizes were changed; the existing look remains the default, and the alternate mode only swaps the live backdrop anchoring for the health bar.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` and `luac -p 'Options/OptionsPages/Nameplates.lua'` passed. In-game `/reload`, then toggling `/az -> Nameplates -> Size -> Fit health backdrop to health bar`, should confirm the backdrop either hugs the bar exactly or returns to the larger decorative frame.
  - **Files Modified:** `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`, `FixLog.md`
- **Nameplate Blizzard-scale sync toggle started:** Investigating the remaining "too big or too small" feel in AzeriteUI nameplates by letting the custom frame scale optionally follow Blizzard's live nameplate global scale instead of relying only on addon-local scale math.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`
- **Nameplate Blizzard-scale sync toggle applied:** Added a `/az -> Nameplates -> Follow Blizzard global scale` toggle that swaps the custom global baseline scale path over to Blizzard's live `nameplateGlobalScale`, refreshes active plates when that CVar changes, and disables the custom global scale slider while the Blizzard-linked mode is active.
  - **Root Cause:** The current nameplate system already neutralizes Blizzard target scaling and then applies its own frame `SetScale(...)` math. That keeps target-size logic deterministic, but it also means the global baseline can feel slightly disconnected from Blizzard's native world/nameplate scaling, especially when comparing against stock behavior or tuning the live Blizzard slider/CVar.
  - **Safety:** This is a narrow additive option only. Friendly/enemy and target multipliers still run through the same existing AzeriteUI relation-specific scale path, and the new mode only swaps which global baseline multiplier is used before those existing per-relation adjustments.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` and `luac -p 'Options/OptionsPages/Nameplates.lua'` passed. In-game `/reload`, toggling `/az -> Nameplates -> Follow Blizzard global scale`, and then adjusting Blizzard's own nameplate scale should confirm whether the baseline now feels closer to stock while relation/target sliders continue to work.
  - **Files Modified:** `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`, `FixLog.md`
- **Nameplate external-addon logic audit started:** Comparing the local installed `Plater` and `Platynator` nameplate implementations against AzeriteUI's current scale/update path to pull over any safe driver-refresh logic without importing their full architecture or click-region model.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/NamePlates.lua`
- **Nameplate external-addon logic audit applied:** Borrowed the safe driver-refresh pattern from the local `Plater` and `Platynator` installs by adding a shared `RefreshNamePlateScalingState()` helper and hooking Blizzard `NamePlateDriverFrame:UpdateNamePlateSize()` plus `UpdateNamePlateOptions()` so AzeriteUI reapplies its own CVars, native plate size, and active frame scale after Blizzard refreshes nameplate options.
  - **Borrowed logic:** `Plater` explicitly hooks `NamePlateDriverFrame:UpdateNamePlateSize()` to restyle after Blizzard size updates, and `Platynator` centralizes native nameplate size / CVar reapplication in its display manager. AzeriteUI now mirrors that refresh discipline locally instead of depending only on world-entry / UI-scale / manual settings refreshes.
  - **Not borrowed on purpose:** `Plater`'s Midnight click-space path in `Plater.lua` uses `C_NamePlateManager.SetNamePlateHitTestInsets(...)` to decouple visible art from click region, and `Platynator` also owns click-region scaling plus aggressive `NamePlateDriverFrame` event suppression/reparenting. Those patterns are too invasive for AzeriteUI's current WoW 12 path and carry higher taint/click-behavior risk than this addon should take right now.
  - **Safety:** This keeps AzeriteUI's existing scale model intact. It only makes the module reassert that model more reliably after Blizzard's own nameplate driver updates.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` passed. In-game `/reload`, adjusting Blizzard nameplate size/scale-related settings, and then checking whether AzeriteUI plates stay in sync without drifting larger/smaller after the Blizzard update cycle are still required.
  - **Files Modified:** `Components/UnitFrames/Units/NamePlates.lua`, `FixLog.md`
- **Nameplate baseline default-tuning started:** Promoting the user-tested relation scale values into the real defaults so non-targeted plates stop starting too small and targeted plates stop starting too large, instead of requiring manual slider tuning to reach the intended baseline.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`
- **Nameplate baseline default-tuning applied:** Changed the relation-level default baselines so new/current-reset profiles now start from the user-tested values that felt correct in practice: friendly/player scale `1.5`, enemy scale `0.66`, friendly/player target scale `0`, and enemy target scale `0.5`. Also normalized the friendly target slider so the no-bump baseline now reads as `100` instead of `0`.
  - **Root Cause:** AzeriteUI's current all-plate scale stack was technically consistent, but the shipped relation defaults were not centered on the values that actually looked right in play. That made untargeted plates feel too small and target transitions feel too aggressive unless the user manually moved several sliders away from their nominal defaults.
  - **Safety:** This does not add another scale path. It keeps the same existing global -> relation -> target order and only changes the default baseline constants/profile starts plus the friendly-target slider normalization around the new zero-bump default.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` and `luac -p 'Options/OptionsPages/Nameplates.lua'` passed. In-game `/reload`, profile reset or manual comparison against the prior values, and checking that the sliders now start closer to the intended feel are still required.
  - **Files Modified:** `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`, `FixLog.md`
- **Nameplate options UX cleanup started:** Reworking the nameplate options page so it reads like player-facing size/visibility controls instead of a flat list of implementation knobs, while keeping the new `100% = intended default` scale model intact.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/Nameplates.lua`
- **Nameplate options UX cleanup applied:** Reorganized the nameplate options into user-facing sections (`Visibility`, `Size`, `Friendly Players`, `Advanced`), renamed the sliders to read as visible outcomes instead of internal multiplier jargon, and added shared slider helpers so every size control now consistently presents `100%` as the intended default.
  - **Root Cause:** The old flat option list mixed visibility, friendly-player special cases, overall scale, relation scale, and Blizzard integration in one continuous block. Even after the default-tuning pass, the page still read like developer internals because the labels and ordering exposed implementation details instead of the player-facing results.
  - **Safety:** This is an options-page cleanup only. It does not rename saved keys or change the underlying runtime scale order; it only groups the controls more clearly and reuses shared slider helpers for consistent normalization.
  - **Verification:** `luac -p 'Options/OptionsPages/Nameplates.lua'` passed. In-game `/reload` plus opening `/az -> Nameplates` is still required to confirm the new grouping/order reads cleanly and that each slider still updates the live plates as expected.
  - **Files Modified:** `Options/OptionsPages/Nameplates.lua`, `FixLog.md`
- **Friendly target-size fallback follow-up started:** Investigating why friendly player/NPC target sizing still feels inconsistent after the options cleanup, with suspicion on the separate friendly-player name-only target branch.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`
- **Friendly target-size fallback follow-up applied:** Friendly player name-only plates now inherit the main friendly target-size setting by default instead of silently using a separate built-in bump, and the options text now explains that the friendly-player name-only slider is only an override when you want different behavior.
  - **Root Cause:** `Components/UnitFrames/Units/NamePlates.lua` was sending friendly players in name-only mode through `friendlyNameOnlyTargetScale` while friendly NPCs used `friendlyTargetScale`. Because the friendly-player name-only branch still had its own old default bump, the shared `Friendly/player target size` control could feel broken or inconsistent whenever friendly player name-only mode was enabled.
  - **Safety:** Runtime scale order is unchanged. This only changes the fallback source for friendly-player name-only target scaling and adds a one-time profile migration so old default-equal values stop forcing the legacy separate bump.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` and `luac -p 'Options/OptionsPages/Nameplates.lua'` passed. In-game `/reload`, targeting a friendly NPC and then a friendly player with name-only mode enabled, and confirming both now follow the same target-size baseline unless the override slider is intentionally changed, are still required.
  - **Files Modified:** `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`, `FixLog.md`
- **Nameplate/interrupt code-path audit applied:** Rechecked the live nameplate scale hooks, friendly target-size branches, and shared interrupt helper call sites, then fixed the remaining friendly-player name-only target slider mismatch so the UI setter/getter now matches the runtime inheritance model and `100%` on that override correctly restores inherited behavior.
  - **Root Cause:** After the earlier fallback change, the friendly-player name-only override slider still wrote values using the old `0.5` additive baseline while the getter/runtime inheritance path had moved to the new `0`-baseline friendly target model. That meant the override slider could display one value while saving another semantic meaning, and there was no clean way to return to inherited behavior from the slider itself.
  - **Safety:** This is limited to the options mapping. The nameplate runtime scale order and the interrupt helper logic remain unchanged; the override slider now simply writes `false` again at `100%` so inherited friendly target sizing works as designed.
  - **Verification:** `luac -p 'Options/OptionsPages/Nameplates.lua'`, `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`, and earlier `luac -p 'Components/UnitFrames/Functions.lua'` all passed. In-game `/reload`, checking the friendly-player name-only target slider, and retesting enemy castbar interrupt colors are still required.
  - **Files Modified:** `Options/OptionsPages/Nameplates.lua`, `FixLog.md`
- **Nameplate slider-range and centered target-scale fix started:** Expanding the nameplate slider ranges and replacing the current one-sided target-scale math so values below `100%` can actually shrink target plates instead of being clamped away.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/Nameplates.lua`, `Components/UnitFrames/Units/NamePlates.lua`
- **Nameplate slider-range and centered target-scale fix applied:** Expanded all nameplate size sliders to a much wider `1-500%` range and changed the target-size sliders to a true centered model where `100%` is the default, values below `100%` shrink on target, and values above `100%` grow on target.
  - **Reference:** Local `Platynator` already uses broad `1-500%` sliders for its target/cast scale controls in `CustomiseDialog/Main.lua`, so AzeriteUI now follows that broader range philosophy instead of the earlier tight `50-150` / `0-200` limits.
  - **Root Cause:** The previous target slider mapping treated `100%` as the baseline visually, but the setter for the zero-default friendly target path clamped all lower values back to `0`. Separately, the runtime target-scale validation still rejected negative values entirely, so even a corrected slider could not shrink target plates below their untargeted size.
  - **Safety:** Runtime scale order is unchanged. This only widens the option ranges and introduces explicit bounded negative target deltas (`-0.95` minimum) so target scaling can shrink without making plates mathematically negative or blowing up.
  - **Verification:** `luac -p 'Options/OptionsPages/Nameplates.lua'` and `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` passed. In-game `/reload`, dragging each size slider well below and above `100%`, and confirming that friendly/enemy target size now shrinks and grows both ways as expected, are still required.
  - **Files Modified:** `Options/OptionsPages/Nameplates.lua`, `Components/UnitFrames/Units/NamePlates.lua`, `FixLog.md`
- **Nameplate preferred-baseline promotion started:** Promoting the currently user-tested plate values into the actual shipped baseline so the shown positions become the new `100%` defaults instead of a custom post-install tuning set.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`
- **Nameplate preferred-baseline promotion applied:** Updated the shipped baseline constants so AzeriteUI now treats the current preferred values as the new `100%` defaults: overall size unchanged at `100`, friendly/player size `130`, enemy size `100`, friendly/player target size `35`, and enemy target size `70` in the previous scale model now all read as the new default baseline in the current UI.
  - **Runtime mapping:** This means the new underlying defaults are `scale = 2`, `friendlyScale = 1.95`, `enemyScale = 0.66`, `friendlyTargetScale = -0.65`, and `enemyTargetScale = 0.2` / legacy `nameplateTargetScale = 0.2`.
  - **Safety:** This does not add or reorder scale logic. It only rebases the defaults and slider normalization constants, plus a one-time migration for profiles still sitting exactly on the prior shipped baseline so they move to the new intended `100%` positions automatically.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` and `luac -p 'Options/OptionsPages/Nameplates.lua'` passed. In-game `/reload`, opening `/az -> Nameplates -> Size`, and confirming those preferred positions now display as `100%` defaults are still required.
  - **Files Modified:** `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`, `FixLog.md`

- **Nameplate interrupt cooldown secret-number fix started:** Investigating a WoW 12 regression where the shared interrupt-visual helper compares secret cooldown numbers from `GetSpellCooldown()` and throws on nameplate cast updates.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Functions.lua`
- **Nameplate interrupt cooldown secret-number fix applied:** Hardened the `GetSpellCooldown()` fallback in the shared interrupt-visual helper so secret `startTime` and `duration` values are discarded as unknown instead of being compared.
  - **Root Cause:** `Components/UnitFrames/Functions.lua` already filtered secret booleans from `C_Spell.GetSpellCooldownDuration():IsZero()`, but the older `GetSpellCooldown()` fallback still trusted any numeric-looking `startTime` and `duration`. On WoW 12 those values can be secret numbers, and the `<= 0` check at line 153 caused the nameplate castbar update path to error repeatedly.
  - **Safety:** This is a narrow guard in the shared interrupt helper only. When cooldown data is secret, AzeriteUI now falls back to the existing `"base"` interrupt visual instead of forcing a ready/cooldown color from unreadable data.
  - **Verification:** `luac -p 'Components/UnitFrames/Functions.lua'` passed. In-game `/reload` plus retesting enemy nameplate casts should confirm the BugSack spam is gone and that nameplate interrupt colors still show when Blizzard exposes non-secret cooldown data.
  - **Files Modified:** `Components/UnitFrames/Functions.lua`, `FixLog.md`

- **Item upgrade protected-call taint started:** Investigating a fresh retail taint where confirming gear upgrades throws `[ADDON_ACTION_FORBIDDEN]` on Blizzard `UpgradeItem()` while AzeriteUI is enabled.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugs.lua`
- **Item upgrade protected-call taint applied:** Removed the live WoW 12 `SetTooltipMoney` / `MoneyFrame_Update` global rewrites from the passive `FixBlizzardBugs` path so AzeriteUI no longer taints Blizzard shared money widgets that item-upgrade confirmation flows depend on.
  - **Root Cause:** `Core/FixBlizzardBugs.lua` explicitly says the WoW 12 path should stay passive to avoid secure-flow taint, but it still replaced Blizzard's shared money APIs with addon closures. Item upgrade is a Blizzard money-backed confirmation flow, so once those globals were tainted the later protected `UpgradeItem()` call could be blocked and blamed on AzeriteUI.
  - **Safety:** This is a narrow WoW 12 change in the passive fix path only. The addon keeps the Plater absorb cleanup, but stops monkeypatching Blizzard-wide money helpers. Any remaining tooltip-money fault should be fixed locally on the offending widget instead of through shared global rewrites.
  - **Verification:** `luac -p 'Core/FixBlizzardBugs.lua'` passed. In-game `/reload`, reopening the item-upgrade NPC, and confirming an upgrade without the `ADDON_ACTION_FORBIDDEN` popup are still required.
  - **Files Modified:** `Core/FixBlizzardBugs.lua`, `FixLog.md`

- **Mirror timer duplicate breath bar hide started:** Investigating a retail regression where Blizzard's `MirrorTimerContainer` breath bar can still appear alongside AzeriteUI's custom mirror timer bar.
  - **Files Targeted:** `FixLog.md`, `Components/Misc/MirrorTimers.lua`
- **Mirror timer duplicate breath bar hide applied:** Hardened the mirror timer quarantine so AzeriteUI now suppresses both Blizzard mirror timer shapes (`MirrorTimerContainer` and `MirrorTimerFrame`) plus any child timer frames Blizzard may try to show again.
  - **Root Cause:** `Components/Misc/MirrorTimers.lua` only hid `MirrorTimerContainer` on the old client branch and only hid `MirrorTimerFrame` on the WoW 12 branch. On the current retail client, Blizzard can still surface the container-based breath bar path, so the duplicate Blizzard breath bar remained visible next to AzeriteUI's own mirror timer.
  - **Safety:** This stays local to the mirror timer module. It only unregisters/reparents Blizzard mirror timer frames that AzeriteUI already replaces, and adds `OnShow` re-hide guards so the Blizzard breath bar does not pop back in later.
  - **Verification:** `luac -p 'Components/Misc/MirrorTimers.lua'` must pass. In-game `/reload` plus entering water or another mirror-timer state is still required to confirm only the AzeriteUI breath bar remains visible.
  - **Files Modified:** `Components/Misc/MirrorTimers.lua`, `FixLog.md`

- **WoW12 secret cast/aura follow-up started:** Investigating fresh BugSack regressions where the user-facing Plater `Interrupt Ready [v10]` modscript still compared secret `notInterruptible` flags from another saved copy, AzeriteUI compared a secret interrupt-ready flag in shared castbar helpers, and Decursive still reached Blizzard `AuraUtil.UnpackAuraData` with secret aura-point payloads under the active WoW 12 path.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Functions.lua`, `Core/FixBlizzardBugsWow12.lua`, account `WTF/Account/JUNNEZ/SavedVariables/Plater.lua`
- **WoW12 secret cast/aura follow-up applied:** Filtered secret booleans out of the shared interrupt-ready helper before AzeriteUI compares or branches on them, added the live WoW 12 `AuraUtil.UnpackAuraData` guard in `Core/FixBlizzardBugsWow12.lua` so secret aura-point payloads bail out safely instead of crashing Decursive through Blizzard `unpack`, and patched the remaining duplicated `Interrupt Ready [v10]` `Cast Update` bodies in the account Plater SavedVariables file.
  - **Root Cause:** The first Plater fix only hit one duplicated saved script pair, leaving another active pair still using `castbar.notInterruptible == true`. Separately, AzeriteUI's shared castbar helper still trusted `durationObject:IsZero()` to return a plain boolean even though WoW 12 can surface that result as secret, and the earlier `AuraUtil.UnpackAuraData` wrapper lived in the non-live legacy path while the active WoW 12 module never wrapped it.
  - **Safety:** The repo changes are narrow guards only. `Components/UnitFrames/Functions.lua` now treats secret booleans from cooldown and attack checks as unknown instead of branching on them, and `Core/FixBlizzardBugsWow12.lua` only wraps `AuraUtil.UnpackAuraData` to sanitize secret/non-table payloads and return nil on unsafe unpack failures. The external Plater edit only rewrites the saved `Interrupt Ready [v10]` comparison logic to a secret-safe boolean fallback.
  - **Verification:** `luac -p 'Components/UnitFrames/Functions.lua'` and `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed. `rg -n --fixed-strings 'castbar.notInterruptible == true or self.notInterruptible == true'` against `WTF/Account/JUNNEZ/SavedVariables/Plater.lua` returned no remaining matches. In-game `/reload` plus retesting target/nameplate casts and the earlier Decursive aura scan are still required.
  - **Files Modified:** `Components/UnitFrames/Functions.lua`, `Core/FixBlizzardBugsWow12.lua`, `FixLog.md`, external `WTF/Account/JUNNEZ/SavedVariables/Plater.lua`

## 2026-03-20

- **Shared target-style health fake-fill helper started:** Moving the common target health fake-fill path into shared unitframe API and wiring target, boss, and arena through the same helper body instead of keeping three near-duplicate implementations.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Target.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`
- **Shared target-style health fake-fill helper applied:** Added shared unitframe helpers for reversed-horizontal fake-fill texcoords, hidden-native health visual suppression, and `UnitHealthPercent(..., true, CurveConstants.ZeroToOne)`-driven fake-fill updates, then switched target, boss, and arena to call those same shared helpers.
  - **Root Cause:** Boss and arena had accumulated near-copy logic from target, but even small differences in percent sourcing, fallback handling, and fake-fill application were enough to keep their health rendering from matching target exactly. The safest way to remove that drift is to make all three unit styles execute the same shared helper code.
  - **Safety:** This only changes the health fake-fill/render path for target, boss, and arena. It does not touch their power bars, aura layouts, battleground visibility, or the current absorb/prediction rollback.
  - **Verification:** `luac -p 'Components/UnitFrames/Functions.lua'`, `luac -p 'Components/UnitFrames/Units/Target.lua'`, `luac -p 'Components/UnitFrames/Units/Boss.lua'`, and `luac -p 'Components/UnitFrames/Units/Arena.lua'` must pass. In-game `/reload` plus direct visual comparison between target, boss, and arena health behavior is still required.
  - **Files Modified:** `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Target.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`, `FixLog.md`

- **Boss/arena health path audit follow-up started:** Deep-comparing target, boss, arena, and the shared statusbar/update stack to identify why boss/arena still diverge visually even after the earlier fake-fill port.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`
- **Boss/arena health path audit follow-up applied:** Added the remaining target-style health setup parity pieces boss/arena were still missing at creation time: `SetForceNative(false)` on the hidden native health bar, `SetForceNative(true)` on the preview bar, reversed backdrop texcoords, and base-texcoord reset after forcing the target-style horizontal reverse-fill path.
  - **Root Cause:** The deeper comparison showed boss/arena were still not configured the same way as target even after matching the fake-fill callback path. Target also explicitly controls LibSmoothBar native/proxy behavior via `SetForceNative`, resets cached base texcoords when forcing the reverse-fill orientation, and flips the backdrop texcoords to match the reversed health art direction.
  - **Safety:** This remains limited to boss and arena health setup. It does not alter castbar, power, aura, or battleground visibility behavior.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Boss.lua'` and `luac -p 'Components/UnitFrames/Units/Arena.lua'` must pass. In-game `/reload` plus direct comparison of boss/arena against target is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`, `FixLog.md`

- **Test-lab non-maintainer gating hardening started:** Closing the remaining stale-state path so saved `/aztest` globals cannot drive preview refreshes on non-`Junnez` characters even though the slash command itself is gated.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Test-lab non-maintainer gating hardening applied:** Runtime test mode now force-disables itself during enable/refresh when the current character is not `Junnez`, and any existing test previews are explicitly hidden before returning.
  - **Root Cause:** The `/aztest` slash command and menu open path were already gated by `CanUseRuntimeTestMode()`, but `RefreshRuntimeTestPreviews()` still trusted the saved global test-mode flag. That left a stale-state edge case where a non-maintainer character could still execute preview refresh logic if `runtimeUnitTestMenuEnabled` had been left on earlier.
  - **Safety:** This only narrows the maintainer-only test-lab path in `Core/Debugging.lua`. Non-test behavior is unchanged, and the extra guard only disables test state and hides preview frames when the current character is not allowed to use `/aztest`.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload` plus logging onto any non-`Junnez` character and confirming no test previews appear is still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Blizzard battleground flag-carrier duplicate hide started:** Extending the existing Blizzard arena-frame quarantine so the separate Blizzard battleground flag-carrier frames are hidden when AzeriteUI shows its own carrier frames.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`
- **Blizzard battleground flag-carrier duplicate hide applied:** Added the Blizzard battleground match/carrier arena frame names to the WoW12 quarantine list so they get the same safe hide/reparent treatment as the normal Blizzard arena frames AzeriteUI already replaces.
  - **Root Cause:** The existing WoW12 quarantine path in `Core/FixBlizzardBugsWow12.lua` only covered `CompactArenaFrame`, `ArenaEnemyFrames`, `ArenaPrepFrames`, and the standard compact arena members. Battleground flag-carrier displays use separate Blizzard `ArenaEnemyMatch*` frames, so AzeriteUI could hide the normal Blizzard arena frames and still leave the Blizzard carrier frames visible on top of AzeriteUI's own battleground carrier layout.
  - **Safety:** This reuses the existing `QuarantineFrame()` path, which nil-checks the frame, hides it, unregisters events, reparents it to the hidden parent, and keeps it hidden on later `OnShow` calls. If a given Blizzard match frame is absent on the client build, nothing happens.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` must pass. In-game `/reload` plus entering a flag battleground and confirming only the AzeriteUI carrier frame remains visible is still required.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`, `FixLog.md`

- **Test-lab tooltip unit-token fix started:** Fixing preview-frame hover errors where Blizzard tooltip code sees a preview frame with no valid `frame.unit` field even though the secure unit attribute was set.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Test-lab tooltip unit-token fix applied:** The preview interaction helper now assigns a real `frame.unit` value directly before setting the secure unit attribute, so Blizzard hover tooltip code sees a valid unit token on preview frames.
  - **Root Cause:** The interactive preview pass only set the secure `unit` attribute on preview frames. Blizzard's tooltip hover path reads `frame.unit`, not the secure attribute table, so preview frames with a nil `frame.unit` still caused `C_TooltipInfo.GetUnit` to be called with an invalid argument.
  - **Safety:** This remains limited to the maintainer-only `/aztest` interaction path in `Core/Debugging.lua`. The saved live unit token is restored when header-backed previews are hidden, and non-test frames are unchanged.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload` plus another hover test over `/aztest` frames are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Boss/arena target-fill parity follow-up started:** Replacing the earlier simplified boss/arena fake-fill port with the actual target-frame health fill pattern, because the simplified version still did not visually match target.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`
- **Boss/arena target-fill parity follow-up applied:** Boss and arena health now use the same `UnitHealthPercent(..., true, CurveConstants.ZeroToOne)`-driven fake-fill source and the same native/preview setup flags as target, instead of the earlier mirror/fallback approximation.
  - **Root Cause:** The first boss/arena fake-fill pass copied the broad idea of target but not the exact code path. It sampled percent from mirror/value fallbacks instead of target's `UnitHealthPercent` path and did not mirror the same hidden native-bar setup flags, so the visual output could still diverge from target even though both used a fake texture.
  - **Safety:** This only changes boss and arena health rendering. Castbars, power bars, and the absorb/prediction rollback remain as before.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Boss.lua'` and `luac -p 'Components/UnitFrames/Units/Arena.lua'` must pass. In-game `/reload` plus direct visual comparison against target is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`, `FixLog.md`

- **Party options show-player ordering started:** Moving the Party Frames `Show Player` toggle to the top of the `/az` Party section so it sits directly under the enabled state and reads like a primary display choice instead of a buried secondary one.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/UnitFrames.lua`
- **Party options show-player ordering applied:** Moved the Party Frames `Show Player` toggle to the top of the Party options block so it appears immediately under the base enable/toggle area, ahead of the section headers.
  - **Root Cause:** The Party `showPlayer` option in `Options/OptionsPages/UnitFrames.lua` had drifted down to the bottom of the Party block after the health-color and aura additions, which made a primary display choice read like a minor advanced setting.
  - **Safety:** This is only an AceConfig ordering change in `Options/OptionsPages/UnitFrames.lua`. The saved key and runtime Party behavior are unchanged.
  - **Verification:** `luac -p 'Options/OptionsPages/UnitFrames.lua'` passed. In-game `/reload` plus a quick `/az -> Unit Frames -> Party Frames` check are still required.
  - **Files Modified:** `Options/OptionsPages/UnitFrames.lua`, `FixLog.md`

- **Boss/arena target-style fake health fill follow-up started:** Replacing the earlier boss/arena reverse-fill workaround with the same hidden-native-health plus visible fake-fill approach used on the target frame, because the native leftward fill path is still rendering incorrectly on those unit bars.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`
- **Boss/arena target-style fake health fill follow-up applied:** Boss and arena health bars now keep the native statusbar hidden as the live data/geometry source and draw a separate visible fake fill texture on top, mirroring the target-frame health approach instead of relying on the broken old leftward fill path.
  - **Root Cause:** The earlier boss/arena pass only converted `LEFT` growth to `HORIZONTAL` plus `SetReverseFill(true)`, but those unit bars still rendered the visible fill incorrectly. The target frame already avoids that rendering path by hiding the native health texture, reading its live statusbar geometry/value updates, and showing a separate fake texture with matching texcoord logic.
  - **Safety:** This is scoped to boss and arena health bars only. Their absorb/prediction rollback remains intact, power bars are unchanged, and the hidden native health bar is still left in place so existing oUF updates continue driving the live values.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Boss.lua'` and `luac -p 'Components/UnitFrames/Units/Arena.lua'` must pass. In-game `/reload` plus a visual check that boss and arena health bars now drain/fill from the same side and with the same texture behavior as target is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`, `FixLog.md`

- **Test-lab interactive preview pass started:** Enabling real hover/click interaction on `/aztest` preview frames so mouseover-driven color behavior and basic targeting can be tested without relying only on the menu's synthetic mouseover state.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Test-lab interactive preview pass applied:** Enabled mouse interaction on preview frames, let real hover override the synthetic menu mouseover state, and assigned secure click-target behavior where the preview frame supports secure attributes so `/aztest` frames can be hovered and clicked meaningfully.
  - **Root Cause:** The test-lab preview code in `Core/Debugging.lua` explicitly disabled mouse interaction on both the spawned preview frames and the fallback preview buttons, so only the menu-driven `Mouseover State` toggle could exercise hover-only color behavior. That also prevented straightforward click targeting on preview frames even when they already carried a usable unit context.
  - **Safety:** This stays inside the maintainer-only `/aztest` path in `Core/Debugging.lua`. The secure-header preview path restores the original unit/click attributes when the preview is hidden, and live non-test unit-frame behavior remains unchanged.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload`, `/aztest`, and a hover/click pass across Party/Raid previews are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Test-lab secure-header raid preview rework started:** Reworking the large-raid test-lab path to use the live secure header children in forced config mode, matching the local ElvUI/GW2 patterns, instead of trying to preview `Raid25` and `Raid40` as standalone unitframes.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Test-lab secure-header raid preview rework applied:** Switched the `Raid25` and `Raid40` preview defs over to a secure-header preview path that force-shows the live header children, sets their displayed unit context for previewing, and restores the real header state when the test set is hidden again.
  - **Root Cause:** `Raid5` in this addon is a manually spawned button set, but `Raid25` and `Raid40` are real secure headers created through `oUF:SpawnHeader(...)` in `Components/UnitFrames/Units/Raid25.lua` and `Components/UnitFrames/Units/Raid40.lua`. Treating those larger raid styles as ordinary standalone unitframes in `/aztest` does not match how they are actually built. The local ElvUI and GW2_UI config-mode code both solve this by force-showing the existing secure-header children instead of trying to clone those group styles as regular frames.
  - **Safety:** This remains inside the `Junnez`-only `/aztest` path in `Core/Debugging.lua` and restores the live header visibility/unit state when the preview is hidden. Live raid header behavior outside test mode is unchanged.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload`, `/aztest`, and checks for `Raid 10`, `Raid 20`, `Raid 25`, and `Raid 40` are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Test-lab nameplate preview fallback started:** Stopping the maintainer test-lab from probing the live `AzeriteNamePlates` style registration when the custom NamePlates module is disabled or conflict-disabled, and using the generic preview path instead.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Test-lab nameplate preview fallback applied:** Switched the maintainer nameplate preview set to use the generic preview-frame path directly instead of trying to spawn the live `AzeriteNamePlates` oUF style.
  - **Root Cause:** The live nameplate style is only registered in `Components/UnitFrames/Units/NamePlates.lua` during `NamePlatesMod.OnEnable()`. When custom nameplates are disabled or conflict-disabled, `/aztest` was still calling `oUF:SetActiveStyle(ns.Prefix .. "NamePlates")`, which produced the `Style [AzeriteNamePlates] does not exist` error even though the test-lab only needs a visual preview.
  - **Safety:** This only changes the maintainer-only `/aztest` nameplate preview path in `Core/Debugging.lua`. Live nameplate registration, driver behavior, and conflict handling are unchanged.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload` plus toggling the nameplate preview in `/aztest` are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Test-lab runtime helper scope fix started:** Fixing a Lua scoping regression in `Core/Debugging.lua` where early runtime-test helper closures call `GetRuntimeTestModule()` before the local function exists, causing them to resolve a nil global at runtime.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Test-lab runtime helper scope fix applied:** Forward-declared `GetRuntimeTestModule` before the earlier runtime-test helper closures and assigned the function later, so those helpers bind the intended local instead of falling through to a nil global at runtime.
  - **Root Cause:** The earlier runtime-test helpers in `Core/Debugging.lua` reference `GetRuntimeTestModule()` before the later `local function GetRuntimeTestModule(def)` statement. In Lua, that means the earlier closures were compiled against a global name, not the later local, which is why `/aztest` blew up with `attempt to call global 'GetRuntimeTestModule'`.
  - **Safety:** This is a pure scoping fix inside the maintainer-only test-lab code path. It does not alter preview logic, saved variables, or any live unit-frame behavior outside `/aztest`.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload` plus another `/aztest` pass are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Party/raid flat-health green follow-up started:** Fixing the live Party/Raid health-color fallback so disabling class colors actually uses a green health bar instead of inheriting AzeriteUI's red generic `Colors.health` value unless the Blizzard palette toggle happens to be enabled.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Party/raid flat-health green follow-up applied:** Changed the Party/Raid health-color table builders so their non-class fallback uses `ns.Colors.green` explicitly, while the class/reaction palette still swaps between AzeriteUI and Blizzard colors as configured.
  - **Root Cause:** `CreateHealthColors()` in `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, and `Components/UnitFrames/Units/Raid40.lua` copied `source.health` into the frame color table. With `useBlizzardHealthColors = false`, that meant `ns.Colors.health`, which is intentionally red in `Core/Common/Colors.lua`, not the flat green the Party/Raid option flow expects when class colors are disabled.
  - **Safety:** This only changes the flat non-class health fallback in the Party/Raid modules. Class colors, reaction colors, mouseover-only behavior, and the Blizzard-vs-AzeriteUI class palette selection are otherwise unchanged.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Party.lua'`, `luac -p 'Components/UnitFrames/Units/Raid5.lua'`, `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, and `luac -p 'Components/UnitFrames/Units/Raid40.lua'` passed. In-game `/reload` plus Party/Raid color toggle validation are still required.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `FixLog.md`
- **Test-lab preview reliability follow-up started:** Fixing maintainer preview regressions where group health bars use the wrong base color, fake class colors only appear after forced mouseover, auras/cast/class-power previews stay hidden behind the debug overlay, and unsupported style spawns still fail closed instead of falling back to a usable preview frame.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Test-lab preview reliability follow-up applied:** Switched the maintainer preview base health tint to the actual green palette, made party/raid fake class coloring respect each module's class-color profile flags instead of only the mouseover simulator, kept functional aura/cast/class-power widgets visible even when the debug label overlay is hidden, and added a generic fallback preview frame path when a style spawn fails so larger raid or specialized preview sets do not disappear entirely.
  - **Root Cause:** The runtime test presenter in `Core/Debugging.lua` used `ns.Colors.health` as its non-class fallback, but that addon palette is intentionally red, not green. It also bypassed the live Party/Raid profile flags that decide whether class colors are always on, Blizzard-colored, or mouseover-only, so fake colors only looked correct once the test-lab mouseover state forced them. On top of that, the shared overlay container hid functional aura/cast/class-power widgets together with the optional debug labels, and failed style spawns still left some preview sets with nothing visible.
  - **Safety:** This pass stays inside the `Junnez`-only `/aztest` runtime preview code in `Core/Debugging.lua`. It does not change live oUF style registrations, live Party/Raid health coloring, or any non-test-lab frame behavior.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload`, `/aztest`, and checks for green base health, immediate fake class colors, visible aura/cast/class-power widgets, and raid10/20/25/40 preview visibility are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Unit-frame options UX cleanup started:** Refactoring the `/az` Unit Frames Party/Raid option blocks into shared builders so visibility, health-color, and aura sections read more cleanly, use simpler ordering, and stop duplicating the same health-color controls in four places.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/UnitFrames.lua`
- **Unit-frame options UX cleanup applied:** Added a shared group-visibility guide, extracted a shared Party/Raid health-color option builder, reordered the Party section so health colors read before aura tuning, and replaced the fragile fractional order values with cleaner integer spacing.
  - **Root Cause:** The `/az` Unit Frames page had become functionally correct but structurally uneven: Party/Raid duplicated the same health-color controls, used decimal order values, exposed group visibility as raw toggles without a guiding explanation, and placed Party aura tuning too close to the more fundamental health-color choices.
  - **Safety:** This only changes the AceConfig page structure in `Options/OptionsPages/UnitFrames.lua`. It does not alter runtime frame behavior, saved variable keys, or module update paths.
  - **Verification:** `luac -p 'Options/OptionsPages/UnitFrames.lua'` passed. In-game `/reload` and a visual pass through `/az -> Unit Frames` are still required.
  - **Files Modified:** `Options/OptionsPages/UnitFrames.lua`, `FixLog.md`
- **Test-lab large-raid visibility and options cleanup started:** Investigating why the maintainer preview still fails to surface the larger raid presets and tightening the Party/Raid options so the visibility copy and health-color controls are grouped more clearly.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`, `Options/OptionsPages/UnitFrames.lua`, `Components/UnitFrames/Units/Party.lua`

## 2026-03-21

- **Enemy castbar interrupt-readiness coloring started:** Auditing AzeriteUI's current castbar interruptibility handling against the WoW 12 spellbook/cooldown APIs and the local comparison addons so enemy casts can reflect whether the player's interrupt is ready instead of only flipping between interruptible and protected states.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Target.lua`, `Components/UnitFrames/Units/NamePlates.lua`
- **Enemy castbar interrupt-readiness coloring applied:** Added shared interrupt spell discovery/cooldown helpers based on `C_SpellBook.IsSpellKnownOrInSpellBook(...)` and `C_Spell.GetSpellCooldownDuration(...)`, then wired target and nameplate enemy castbars to color as yellow when interruptible and ready, gray when uninterruptible, and red when interruptible but the player's primary interrupt is still on cooldown.
  - **Root Cause:** AzeriteUI already sanitized `notInterruptible` for WoW 12 secret-value safety, but its enemy castbar visuals still only had a binary protected/default color model. That left no built-in readiness cue for whether the player could actually kick the cast right now, which is why the Plater-style workaround was attractive in the first place.
  - **Safety:** The new readiness check is read-only and stays on the addon side: it only looks up the player's known interrupt spells and their cooldown duration objects, sanitizes castbar interruptibility before branching, and falls back to the existing cast colors when no known interrupt can be resolved. Player/self castbars are not recolored by this pass.
  - **Verification:** `luac -p 'Components/UnitFrames/Functions.lua'`, `luac -p 'Components/UnitFrames/Units/Target.lua'`, and `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` must pass. In-game `/reload` plus checks against interruptible, uninterruptible, and on-cooldown enemy casts are still required.
  - **Files Modified:** `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Target.lua`, `Components/UnitFrames/Units/NamePlates.lua`, `FixLog.md`
- **AuraData interrupt source-of-truth follow-up started:** Removing the duplicated retail interrupt map from the castbar helper and checking the older AuraData registration path itself for stale or broken registrations.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Auras/AuraData.lua`, `Components/UnitFrames/Functions.lua`
- **AuraData interrupt source-of-truth follow-up applied:** Fixed `AuraData.Add(...)` so hidden spell registrations write to `Hidden[spellID]` instead of `Hidden[isHidden]`, added a retail interrupt-priority table and cached known-interrupt helpers directly to `AuraData`, removed the stale `Call Felhunter` retail interrupt entry, and added Priest `Silence` to the retail interrupt list used by the castbar readiness helper.
  - **Root Cause:** The first interrupt-readiness pass worked, but it duplicated a class interrupt map that already conceptually belonged with `AuraData`, and the existing `AuraData.Add(...)` helper had an old hidden-flag indexing bug that prevented hidden-spell registrations from ever matching the spell IDs the filters check. Keeping interrupt ownership in `AuraData` avoids drift, and fixing the hidden registration bug corrects the data layer itself instead of only the castbar consumer.
  - **Safety:** This stays data-side and helper-side only. It does not change aura filter logic structure, and the castbar helper still falls back safely when no known interrupt is available. The retail interrupt priority now resolves from `AuraData` after spellbook load instead of a duplicate local table.
  - **Verification:** `luac -p 'Components/UnitFrames/Auras/AuraData.lua'` and `luac -p 'Components/UnitFrames/Functions.lua'` must pass. In-game `/reload` plus another interrupt-ready/enemy-cast pass are still required.
  - **Files Modified:** `Components/UnitFrames/Auras/AuraData.lua`, `Components/UnitFrames/Functions.lua`, `FixLog.md`
- **Retail aura consumer normalization follow-up started:** Auditing the retail aura filter/sort/style stack for field-name drift and stale registration behavior after the data-layer fixes, to make sure `AuraData` registrations actually flow through to visible aura handling.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Auras/AuraData.lua`, `Components/UnitFrames/Auras/AuraFilters.lua`, `Components/UnitFrames/Auras/AuraSorting.lua`, `Components/UnitFrames/Auras/AuraStyling.lua`
- **Retail aura consumer normalization follow-up applied:** Populated `SpellParents` inside `AuraData.Add(...)`, added a shared retail `GetAuraSpellID(...)` helper, and updated the retail aura filter/sort/style consumers to normalize `spellId` versus `spellID` before checking `Spells`, `Priority`, or other registered metadata.
  - **Root Cause:** The retail consumers had accumulated a mixed-field assumption where some code read `data.spellId`, older/shared paths still used `spellID`, and `SpellParents` was declared in `AuraData` but never written. That meant valid retail registrations could still be skipped in sorting/styling if the incoming aura table used the alternate field name, and parent relationships were never recorded even when the data file provided them.
  - **Safety:** This is a compatibility hardening pass only. It does not change the overall filter rules; it just makes the existing registered aura metadata resolve consistently across the retail data consumers.
  - **Verification:** `luac -p 'Components/UnitFrames/Auras/AuraData.lua'`, `luac -p 'Components/UnitFrames/Auras/AuraFilters.lua'`, `luac -p 'Components/UnitFrames/Auras/AuraSorting.lua'`, and `luac -p 'Components/UnitFrames/Auras/AuraStyling.lua'` must pass. In-game `/reload` plus player/target/party/nameplate aura checks are still required.
  - **Files Modified:** `Components/UnitFrames/Auras/AuraData.lua`, `Components/UnitFrames/Auras/AuraFilters.lua`, `Components/UnitFrames/Auras/AuraSorting.lua`, `Components/UnitFrames/Auras/AuraStyling.lua`, `FixLog.md`
- **Test-lab large-raid visibility and options cleanup applied:** Relaxed the maintainer preview bootstrap so it can prepare unit-frame styles even when the live module is not currently active, anchored inactive previews against `UIParent` instead of hidden live frames, corrected the group visibility copy, and added dedicated `Health Colors` sections to the Party/Raid option blocks.
  - **Root Cause:** The `/aztest` preview path in `Core/Debugging.lua` only trusted already-live modules as preview anchors and style sources, which made optional frame families like the larger raid groups prone to disappearing from the test lab. At the same time, the Party/Raid options still mixed visibility and health-color controls together and repeated incorrect raid-size descriptions.
  - **Safety:** This preview change stays inside the maintainer-only test lab. It does not alter live group visibility drivers or live unit-frame positioning. The Party default now explicitly stores `useBlizzardHealthColors = false`, which matches the existing intended behavior.
  - **Verification:** `luac -p 'Core/Debugging.lua'`, `luac -p 'Options/OptionsPages/UnitFrames.lua'`, and `luac -p 'Components/UnitFrames/Units/Party.lua'` passed. In-game `/reload`, `/aztest`, and large-raid preset checks are still required.
  - **Files Modified:** `Core/Debugging.lua`, `Options/OptionsPages/UnitFrames.lua`, `Components/UnitFrames/Units/Party.lua`, `FixLog.md`
- **Party/raid health color option hierarchy started:** Reworking the party and raid health-bar color settings so `Use Class Colors` becomes the parent toggle, with Blizzard palette and mouseover-only behavior as dependent sub-options and flat health green as the explicit fallback path.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Party/raid health color option hierarchy applied:** Added `Use Class Colors` as the master party/raid health-color toggle, moved Blizzard palette selection and mouseover-only class coloring under that path, and made flat health green the explicit fallback when class colors are disabled.
  - **Root Cause:** The earlier party/raid color toggles were independent booleans, so the UI exposed contradictory states like "mouseover-only class color" without an obvious parent "use class colors" choice. That made the green-health path feel incidental instead of intentional.
  - **Safety:** Existing profiles keep the old behavior because the new `useClassColors` default is `true`. Only users who turn it off will get persistent health green bars, and the Blizzard palette toggle is now ignored when class colors are disabled.
  - **Verification:** `luac -p 'Options/OptionsPages/UnitFrames.lua'`, `luac -p 'Components/UnitFrames/Units/Party.lua'`, `luac -p 'Components/UnitFrames/Units/Raid5.lua'`, `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, and `luac -p 'Components/UnitFrames/Units/Raid40.lua'` passed. In-game `/reload` plus option-combination checks are still required.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`, `FixLog.md`
- **Party/raid mouseover-only class color started:** Adding a shared toggle for party and raid health bars so they stay flat health green until the player mouses over the unit frame, then temporarily switch to the configured class/reaction palette.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Party/raid mouseover-only class color applied:** Added `Only Show Class Color on Mouseover` to Party Frames and Raid Frames (5/25/40), and wired those modules so their health bars stay on the base health color until hovered, then switch to the configured class/reaction palette.
  - **Root Cause:** Party and raid health bars were always running with `Health.colorClass`, `Health.colorClassPet`, and `Health.colorReaction` enabled in their style setup, so there was no profile-level way to keep them flat green except by removing class/reaction coloring entirely.
  - **Safety:** This only changes party/raid health-bar color selection. The bars still use the existing base health color when not hovered, and the raid Blizzard-color toggle continues to decide which class/reaction palette is used once hovered.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Party.lua'`, `luac -p 'Components/UnitFrames/Units/Raid5.lua'`, `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, `luac -p 'Components/UnitFrames/Units/Raid40.lua'`, and `luac -p 'Options/OptionsPages/UnitFrames.lua'` passed. In-game `/reload` plus party/raid mouseover validation is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`, `FixLog.md`
- **Maintainer unit-frame test menu started:** Replacing the narrow `/aztest` preview path with a proper `Junnez`-only test menu that can live-toggle preview coverage for all AzeriteUI-owned unit frame groups instead of only raid5/arena.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Maintainer unit-frame test menu applied:** Reworked `/aztest` into a `Junnez`-only menu and preview system that can toggle cloned test coverage for player, target, focus, pet, boss, party, raid, arena, and nameplate-style AzeriteUI frames from one place.
  - **Root Cause:** [Core/Debugging.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/Debugging.lua) only exposed a single boolean `/aztest` path wired to the earlier raid5/arena preview experiment, so there was no practical way to preview the rest of the unit-frame styles or selectively test individual frame groups without real group members.
  - **Safety:** The new path is gated to `ns.PlayerName == "Junnez"` and uses separate `runtimeUnitTestMenuEnabled` / `runtimeUnitTestSets` state, leaving the older `runtimeUnitTestMode` flag forced off so the legacy raid5/arena-only hook stays dormant.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. In-game `/reload`, `/aztest`, and live preview validation are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Maintainer unit-frame test lab expansion started:** Extending the new `Junnez`-only `/aztest` menu into a full test lab with presets, fake roster/state scenarios, layout stress toggles, nameplate variants, quick actions, and clearer chaptered UI so previewing AzeriteUI unit frames is practical instead of ad hoc.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Maintainer unit-frame test lab expansion applied:** Added the full 10-item test-lab pass to `/aztest`, including roster presets, class/role mixes, health-state scenarios, aura scenarios, cast scenarios, mouseover simulation, nameplate pack and side variants, layout stress toggles, quick actions, and a richer debug overlay in a reorganized chaptered menu.
  - **Root Cause:** The first menu pass exposed the frame families, but it still lacked the scenario depth and menu structure needed to test realistic party/raid/nameplate states quickly. That made it cumbersome to validate layout, hover-only color behavior, aura visibility, cast states, and stress cases without manually rebuilding the same conditions over and over.
  - **Safety:** All new preview state is still scoped to maintainer-only `ns.db.global.runtimeUnitTest*` keys in [Core/Debugging.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/Debugging.lua). It drives addon-side cloned preview frames only and does not attempt to fabricate real Blizzard `party1`/`raid1` units.
  - **Verification:** `luac -p 'Core/Debugging.lua'` passed. A static logic check also passed for the new state tables, menu sections, nameplate variant path, and layout/debug toggles. In-game `/reload`, `/aztest`, and live interaction checks are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Maintainer unit-frame test lab follow-up started:** Investigating reports that the expanded `/aztest` lab still misrenders dedicated castbars, lays out `raid20`/`raid40` incorrectly, can show stale live class colors until another scenario toggle is changed, and throws an oUF style error when nameplate previews are requested in sessions where the custom nameplate style is unavailable.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Maintainer unit-frame test lab follow-up applied:** Fixed the preview pass so raid layouts use the same point math as the real raid modules, fake class colors are reapplied after show instead of being left to live oUF class-color logic, native castbars are driven directly when a preview frame already owns one, and unsupported style previews fail closed instead of throwing noisy nameplate-style errors.
  - **Root Cause:** [Core/Debugging.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/Debugging.lua) used a generalized point helper with horizontal signs opposite the raid modules, relied on a one-pass post-update texture tint for fake class colors that could be overwritten by later frame updates, treated all cast previews as a generic overlay instead of using existing frame castbars, and always assumed the requested oUF style had been registered even in addon-conflict cases like custom nameplates being disabled.
  - **Safety:** The fix stays inside the maintainer-only runtime preview code. It does not change live raid headers, live castbar modules, or nameplate behavior outside `/aztest`.
  - **Verification:** `luac -p 'Core/Debugging.lua'` is required again after the follow-up. In-game `/reload`, `raid20` / `raid40` preview checks, native castbar checks, and a no-error nameplate toggle check are still required.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`

## 2026-03-16

## 2026-03-20

- **Unit-frame absorb overlay rollback started:** Investigating report that the current absorb/shield overlay is covering most non-player health bars, including party, raid, pet, focus, target-of-target, arena, boss, and nameplate health bars. Scope is limited to the non-player/target unit-frame absorb wiring so the broken overlay can be disabled without touching health text, heal prediction, or the custom player/target secret-value paths.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Components/UnitFrames/Units/Pet.lua`, `Components/UnitFrames/Units/Focus.lua`, `Components/UnitFrames/Units/ToT.lua`, `Components/UnitFrames/Units/Arena.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/NamePlates.lua`
- **Unit-frame absorb overlay rollback applied:** Commented out the absorb-bar attachment on the affected non-player/target unit styles so oUF no longer drives those shield overlays while the visuals are broken.
  - **Root Cause:** The affected unit styles all still create an absorb `StatusBar` and then attach it through `self.HealthPrediction.absorbBar`, for example in [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua), [Components/UnitFrames/Units/Raid5.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid5.lua), and the matching pet/focus/ToT/arena/boss/nameplate modules. That link is what lets the HealthPrediction element drive the absorb overlay across those frames.
  - **Safety:** This rollback only disables the absorb overlay hookup for the affected unit styles. Health bars, heal prediction textures, player/target absorb handling, and secure header behavior are otherwise unchanged.
  - **Verification:** `luac -p` on the touched Lua files is required; in-game `/reload` plus a quick pass over party, raid, pet, focus, ToT, arena/boss, and nameplate health bars is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Components/UnitFrames/Units/Pet.lua`, `Components/UnitFrames/Units/Focus.lua`, `Components/UnitFrames/Units/ToT.lua`, `Components/UnitFrames/Units/Arena.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/NamePlates.lua`, `FixLog.md`
- **Unit-frame white prediction overlay follow-up started:** The first rollback removed absorb-bar attachment, but the reported white 10-20% alpha overlay still matches the custom heal-prediction texture path on the same unit styles. Scope remains limited to the non-player/target frames where the current prediction overlay is visually broken.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Components/UnitFrames/Units/Pet.lua`, `Components/UnitFrames/Units/Focus.lua`, `Components/UnitFrames/Units/ToT.lua`, `Components/UnitFrames/Units/Arena.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/NamePlates.lua`
- **Unit-frame white prediction overlay follow-up applied:** Disabled the custom `HealPredict_PostUpdate` hookup and hid the preview helper bar on the affected non-player/target unit styles, so the semi-transparent white prediction layer no longer renders over those health bars.
  - **Root Cause:** The white overlay was not only the absorb bar. The affected modules also wire `self.HealthPrediction.PostUpdate = HealPredict_PostUpdate`, and that callback explicitly shows a textured overlay with partial alpha on incoming-heal/heal-absorb updates. Several modules also leave `self.Health.Preview` at `0.5` alpha, which can read as a pale duplicate bar underneath the main health fill.
  - **Safety:** This follow-up only disables the visible heal-prediction/preview overlay for the affected non-player/target unit styles. Base health updates, tags, player/target special handling, and secure header logic remain unchanged.
  - **Verification:** `luac -p` on the touched Lua files is required; in-game `/reload` plus another pass over party, raid, pet, focus, ToT, arena/boss, and nameplates is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Components/UnitFrames/Units/Pet.lua`, `Components/UnitFrames/Units/Focus.lua`, `Components/UnitFrames/Units/ToT.lua`, `Components/UnitFrames/Units/Arena.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/NamePlates.lua`, `FixLog.md`
- **Unit-frame absorb bar hard-hide follow-up started:** The pale duplicate bar can still exist if the unhooked absorb `StatusBar` itself remains visible by default after creation. Scope remains limited to the same non-player/target unit-style absorb bar creation blocks.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Components/UnitFrames/Units/Pet.lua`, `Components/UnitFrames/Units/Focus.lua`, `Components/UnitFrames/Units/Arena.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/NamePlates.lua`
- **Unit-frame absorb bar hard-hide follow-up applied:** Force-hid the created absorb bars with `SetAlpha(0)` and `Hide()` in the affected non-player/target unit styles so the detached status bars cannot remain visible as a pale overlay.
  - **Root Cause:** Commenting out the `self.HealthPrediction.absorbBar = absorb` attachment stops the prediction system from driving those bars, but the absorb `StatusBar` objects still exist at a higher frame level over health. If one of them remains visible with its texture active, it can still read as a white/washed duplicate health bar.
  - **Safety:** This change only affects the local absorb-bar widgets in the already-targeted non-player/target unit styles. It does not change health values, tags, secure headers, or player/target special handling.
  - **Verification:** `luac -p` on the touched Lua files is required; in-game `/reload` plus a fresh visual check of party, raid, pet, focus, arena, boss, and nameplates is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Components/UnitFrames/Units/Pet.lua`, `Components/UnitFrames/Units/Focus.lua`, `Components/UnitFrames/Units/Arena.lua`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/NamePlates.lua`, `FixLog.md`
- **Boss/arena reverse-fill health follow-up started:** Investigating report that boss and arena health-style overlays still grow the wrong way because those modules are relying on the older orientation path instead of the newer target-style reverse-fill setup.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`
- **Boss/arena reverse-fill health follow-up applied:** Switched boss and arena health-related bars to an explicit reverse-fill configuration when their layout requests leftward growth, matching the current target-frame fill rule instead of relying on the older orientation shorthand.
  - **Root Cause:** [Components/UnitFrames/Units/Boss.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Boss.lua) and [Components/UnitFrames/Units/Arena.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Arena.lua) still fed `db.HealthBarOrientation` directly into health, preview, cast, and absorb bars. Their layouts use `HealthBarOrientation = "LEFT"`, but the modern target path now pins bars to a concrete axis and applies `SetReverseFill(true)` explicitly, which is more stable with the current statusbar compatibility layer.
  - **Safety:** This change is limited to boss and arena visual fill configuration. It does not alter unit drivers, tag text, or secure header behavior.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Boss.lua'` and `luac -p 'Components/UnitFrames/Units/Arena.lua'` are required; in-game `/reload` plus boss and arena health/cast overlay checks are still required.
  - **Files Modified:** `Components/UnitFrames/Units/Boss.lua`, `Components/UnitFrames/Units/Arena.lua`, `FixLog.md`
- **Split player/target power value alpha started:** Reworking the shared power-value alpha setting so player-side power text and target-side power text can be tuned independently instead of both inheriting one Unit Frames root slider.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/UnitFrame.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Split player/target power value alpha applied:** Added separate player and target power value alpha settings, kept backward fallback to the old shared key for existing profiles, and moved the sliders into the Player and Target option groups.
  - **Root Cause:** [Components/UnitFrames/UnitFrame.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/UnitFrame.lua) only stored one `powerValueAlpha` profile key and [Options/OptionsPages/UnitFrames.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/OptionsPages/UnitFrames.lua) only exposed one global slider, even though the target module already had its own local alpha lookup path.
  - **Safety:** This change only affects power value text alpha lookup and options UI. Existing profiles still fall back to the old shared key until the new player/target values are set.
  - **Verification:** `luac -p 'Components/UnitFrames/UnitFrame.lua'` and `luac -p 'Options/OptionsPages/UnitFrames.lua'` are required; in-game `/reload` plus player/target alpha slider checks are still required.
  - **Files Modified:** `Components/UnitFrames/UnitFrame.lua`, `Options/OptionsPages/UnitFrames.lua`, `FixLog.md`

- **Runtime unit-test forced visibility started:** Extending `/aztest` so the supported preview frames are shown while solo instead of only swapping unit tokens behind the normal party/arena visibility gates.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Arena.lua`
- **Runtime unit-test forced visibility applied:** `/aztest` now forces the supported preview headers visible while test mode is active, so you can preview them solo without joining a party, raid, or arena.
  - **Root Cause:** The first `/aztest` pass only swapped the unit drivers to `player`, but [Components/UnitFrames/Units/Raid5.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid5.lua) still honored party/raid visibility conditions and [Components/UnitFrames/Units/Arena.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Arena.lua) still honored arena-instance visibility. That meant the preview units existed but stayed hidden when you were solo in the open world.
  - **Safety:** The forced-show path is only active while `runtimeUnitTestMode` is enabled. Normal group and arena visibility returns immediately when `/aztest off` is used.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Raid5.lua'` and `luac -p 'Components/UnitFrames/Units/Arena.lua'` are required; in-game `/aztest on` while solo should now show the preview headers.
  - **Files Modified:** `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Arena.lua`, `FixLog.md`
- **Runtime unit-test player-name gate started:** Restricting the new `/aztest` runtime preview command to the maintainer character name so it stays available for your local testing flow without exposing another broad debug path.
  - **Files Targeted:** `FixLog.md`, `Core/Debugging.lua`
- **Runtime unit-test player-name gate applied:** Gated `/aztest` behind the existing `ns.PlayerName` constant so only the `Junnez` character can use the runtime unit preview command.
  - **Root Cause:** The modifier-key test path was removed to avoid collisions, but the replacement `/aztest` command was still globally callable. Since this is a maintainer-only preview tool, the simplest stable gate is the player identity already cached in [Core/Common/Constants.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/Common/Constants.lua).
  - **Safety:** This change only blocks command entry in [Core/Debugging.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/Debugging.lua). It does not alter raid/arena frame behavior for normal users, saved variables, or other debug commands.
  - **Verification:** `luac -p 'Core/Debugging.lua'` is required; in-game `/aztest status` on `Junnez` should still work, while other character names should receive the restriction message.
  - **Files Modified:** `Core/Debugging.lua`, `FixLog.md`
- **Runtime unit-test toggle started:** Replacing the modifier-key-at-reload unit-frame test mode with a dedicated runtime slash command so fake group/arena previews do not collide with other addons using Alt/Ctrl/Shift debug maintenance and can be toggled without `/reload`.
  - **Files Targeted:** `FixLog.md`, `Core/Common/Constants.lua`, `Core/Debugging.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Arena.lua`
- **Runtime unit-test toggle applied:** Replaced the reload-time modifier-key latch with a persistent `/aztest` command that toggles AzeriteUI's unit test mode live and refreshes the supported preview modules immediately.
  - **Root Cause:** [Core/Common/Constants.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/Common/Constants.lua) only set `ns.Private.IsInTestMode` from `Alt+Ctrl+Shift` during load, so the preview path conflicted with other addons using the same maintenance chord and could not be changed without a reload.
  - **Safety:** The runtime toggle is scoped to the existing preview consumers in [Components/UnitFrames/Units/Raid5.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid5.lua) and [Components/UnitFrames/Units/Arena.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Arena.lua). It only swaps their secure unit drivers out of combat and persists one debug flag in `ns.db.global.runtimeUnitTestMode`.
  - **Usage:** `/aztest on`, `/aztest off`, `/aztest toggle`, `/aztest status`
  - **Verification:** `luac -p 'Core/Common/Constants.lua'`, `luac -p 'Core/Debugging.lua'`, `luac -p 'Components/UnitFrames/Units/Raid5.lua'`, and `luac -p 'Components/UnitFrames/Units/Arena.lua'` are required; in-game `/aztest on` / `/aztest off` validation is still required.
  - **Files Modified:** `Core/Common/Constants.lua`, `Core/Debugging.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Arena.lua`, `FixLog.md`
- **Raid frame health color source toggle started:** Adding a `/az -> Unit Frames -> Raid Frames` option so raid health bars can use either AzeriteUI's custom class/reaction colors or Blizzard's default class/reaction colors, without changing raid layout or non-health elements.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Raid frame health color source toggle applied:** Added `Use Blizzard Health Bar Colors` to the 5/25/40 raid-frame option groups and wired each raid module to swap only its health-bar class/reaction/base health color tables between AzeriteUI colors and Blizzard/oUF colors.
  - **Root Cause:** [Components/UnitFrames/UnitFrame.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/UnitFrame.lua) initializes unit frames with `self.colors = ns.Colors`, so raid health bars always inherited AzeriteUI's custom class/reaction palette and there was no profile-level override in [Options/OptionsPages/UnitFrames.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/OptionsPages/UnitFrames.lua).
  - **Safety:** The change is limited to raid-frame health color selection. Power bars, debuff styling, secure header behavior, and non-raid unit frames are unchanged because each raid frame now gets a small per-frame color table with only the health-related color groups swapped.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Raid5.lua'`, `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, `luac -p 'Components/UnitFrames/Units/Raid40.lua'`, and `luac -p 'Options/OptionsPages/UnitFrames.lua'` are required; in-game `/reload` and `/az -> Unit Frames -> Raid Frames (5/25/40)` validation are still required.
  - **Files Modified:** `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`, `FixLog.md`

- **Raid secure-header consumable/click regression started:** Investigating current-session retail reports where entering raid states throws `SecureGroupHeaders.lua` nil `groupingOrder` / nil `point` errors from [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua), and the user then cannot click food or other consumables. Scope is limited to the raid secure-header visibility/update path in [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua), [Components/UnitFrames/Units/Raid5.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid5.lua), and [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua), because [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua) already contains the missing secure-attribute preflight pattern.
- **Raid secure-header consumable/click regression applied:** Added a sanitized secure-header preflight to the raid 5/25/40 visibility drivers so `groupBy`, `groupingOrder`, `point`, and the rest of the layout attributes are restored before any `showRaid` / `showParty` / `showPlayer` writes can trigger Blizzard's secure header refresh.
  - **Root Cause:** [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua), [Components/UnitFrames/Units/Raid5.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid5.lua), and [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua) still let `UpdateVisibilityDriver()` change secure visibility attributes while relying on a later `UpdateHeader()` pass to restore grouping/layout state. Blizzard's `SecureGroupHeader_Update` can run on every `SetAttribute(...)`, so the header sometimes refreshed with nil `groupingOrder` or nil `point`, faulted inside the restricted environment, and left the session tainted enough to interfere with protected item/consumable clicks.
  - **Safety:** The fix only reorders and sanitizes existing secure header attributes on AzeriteUI-owned raid headers. It does not change click registration, item logic, or Blizzard inventory frames.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, `luac -p 'Components/UnitFrames/Units/Raid5.lua'`, and `luac -p 'Components/UnitFrames/Units/Raid40.lua'` are required; in-game `/reload`, `/buggrabber reset`, then a raid-group retest plus food/consumable click validation are still required.
  - **Files Modified:** `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid40.lua`, `FixLog.md`

- **Soul Fragments golden glow effect disabled:** Commented out all golden glow code for Demon Hunter/Enhancement Shaman class power due to visual bugs (glow sticking, incorrect growth). Lays groundwork for future improvements.
- **Soul Fragments Display Mode dropdown fix:** Dropdown is now always visible for all Demon Hunters, regardless of specialization.
- **Internal:** Code cleanup and prep for future class power visual improvements.
- **Verification:** `/reload` and options menu tested. No errors in Lua diagnostics. Golden glow no longer appears; dropdown is visible for all DH specs.
- **Files Modified:** `Components/UnitFrames/Units/PlayerClassPower.lua`, `Options/OptionsPages/UnitFrames.lua`, `AzeriteUI5_JuNNeZ_Edition.toc`, `build-release.ps1`, `CHANGELOG.md`, `FixLog.md`

## 2026-03-15

- **Retail item-upgrade protected-call taint started:** Investigating BugSack report `[ADDON_ACTION_FORBIDDEN] AddOn 'AzeriteUI5_JuNNeZ_Edition' tried to call the protected function 'UpgradeItem()'` from Blizzard's item-upgrade confirm flow. Scope is limited to current-retail code that still writes addon functions onto Blizzard-owned frame tables, because the repo already documents that this class of override can spread taint into unrelated protected UI flows.
  - **Files Targeted:** `FixLog.md`, `Components/ActionBars/Elements/MicroMenu.lua`, `Components/ActionBars/Elements/EncounterBar.lua`, `Components/Misc/Minimap.lua`, `Components/Misc/MirrorTimers.lua`, `Components/Misc/Tooltips.lua`, `Components/Misc/VehicleSeat.lua`
- **Retail item-upgrade protected-call taint applied:** Stopped the WoW12/current-retail path from replacing Blizzard `HighlightSystem` / `ClearHighlight` methods with `ns.Noop` on MicroMenu, EncounterBar, Minimap, MirrorTimers, Tooltips, and VehicleSeat containers.
  - **Root Cause:** Multiple live retail modules were still doing direct writes like `MicroMenuContainer.HighlightSystem = ns.Noop` and `GameTooltipDefaultContainer.ClearHighlight = ns.Noop`. That pattern matches the taint source already called out in [Core/FixBlizzardBugs.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/FixBlizzardBugs.lua): replacing Blizzard-owned methods in WoW12 can propagate addon taint into unrelated protected Blizzard flows. The `UpgradeItem()` forbidden call is consistent with that class of taint leak.
  - **Safety:** The change is WoW12-gated and only stops addon-side method replacement on Blizzard frame tables. It does not alter AzeriteUI-owned frames, secure click handlers, item APIs, or item-upgrade UI logic.
  - **Verification:** `luac -p` on the touched Lua files is required; in-game `/reload`, `/buggrabber reset`, and a fresh item-upgrade confirm test are still required.
  - **Files Modified:** `Components/ActionBars/Elements/MicroMenu.lua`, `Components/ActionBars/Elements/EncounterBar.lua`, `Components/Misc/Minimap.lua`, `Components/Misc/MirrorTimers.lua`, `Components/Misc/Tooltips.lua`, `Components/Misc/VehicleSeat.lua`

## 2026-03-14

- **Target enemy cast/channel visual inversion toggle started:** Adding a profile-backed `/az` toggle to visually reverse hostile target castbar behavior so enemy channels can fill like casts and enemy casts can drain like channels, without swapping the underlying cast/channel state used by oUF/WoW12 duration APIs.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Target enemy cast/channel visual inversion toggle applied:** Added `/az -> Unit Frames -> Target -> Reverse Enemy Cast/Channel Visuals`, and wired the target castbar renderer to flip hostile-target visual progress in the final percent/native-timer stage while leaving the actual cast/channel classification untouched.
  - **Root Cause:** [Components/UnitFrames/Units/Target.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Target.lua) already distinguishes casts from channels correctly for WoW 12 duration objects and callbacks, but it had no profile-level way to intentionally invert the hostile-target visual behavior. Existing compare addons in the local tree keep normal detection and only swap timer direction or displayed progress, which is the safer pattern here too.
  - **Safety:** The new toggle only affects hostile target castbar visuals by flipping the returned visual percent and swapping the timer-direction choice in the timer-driven path. It does not rewrite `casting`/`channeling` flags, does not change unit event handling, and does not alter player/self target behavior.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Target.lua'` and `luac -p 'Options/OptionsPages/UnitFrames.lua'` passed. In-game `/reload` plus hostile-target testing of both a normal cast and a channel is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Target castbar growth-direction follow-up applied:** Reworked the new target toggle so it swaps only the hostile castbar growth side, not the cast/channel progress logic, and preserves the same one-directional art by cropping from the selected side instead of inverting the sampled timeline.
  - **Root Cause:** The first pass changed hostile target progress semantics, which also changed how the fake fill sampled the texture. Because AzeriteUI’s target cast art is one-directional, the visible result was the right timing direction but the wrong art behavior. The actual requirement was to keep the same art orientation and only move the fill origin between left and right.
  - **Safety:** The follow-up leaves `casting` / `channeling`, duration payload lookup, and native timer direction untouched. It only changes hostile target fake-fill anchoring/cropping and the matching `SetReverseFill` state used for spark/growth positioning.
  - **Verification:** Re-run `luac -p 'Components/UnitFrames/Units/Target.lua'` and `luac -p 'Options/OptionsPages/UnitFrames.lua'`; in-game `/reload` plus hostile cast/channel growth-side testing still required.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Target castbar secret-width growth follow-up started:** Fixing the WoW12 secret-value fault in the new hostile growth-side crop path where fake-fill sizing still read `GetWidth()` through an `or` chain and compared the result before confirming the number was safe to access.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`
- **Target castbar secret-width growth follow-up applied:** Replaced the hostile growth-side width probe with a stepwise safe-width lookup that only uses `anchorFrame:GetWidth()` / `cast:GetWidth()` after `IsSafeNumber(...)` succeeds, so secret widths now fall back cleanly instead of faulting during the crop path.
  - **Root Cause:** The previous crop code still did two unsafe things for WoW12 secret values: it fed `GetWidth()` results through an `or` chain, which boolean-tested the candidate width, and it compared `width > 0` before proving the number was readable. When Blizzard returned a secret width, the growth-side target castbar path tripped exactly on that comparison.
  - **Safety:** This follow-up does not change cast/channel semantics or the hostile growth-side toggle behavior. It only changes how the fake-fill crop path obtains width, and it now uses the existing safe-number guard before any numeric comparison or arithmetic.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Target.lua'` passed. In-game `/reload` plus hostile target castbar retest is still required.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`
- **Plater absorb-bar compatibility started:** Investigating report that Plater nameplates can show a detached/floating absorb or shield segment above the health bar while AzeriteUI is otherwise active. Scope is limited to [Core/FixBlizzardBugs.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/FixBlizzardBugs.lua), because [Components/UnitFrames/Units/NamePlates.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/NamePlates.lua) already hard-disables itself when `Plater` is enabled, so the visible broken absorb widget is coming from Plater's own frame tree rather than AzeriteUI's nameplate module.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugs.lua`
- **Plater absorb-bar compatibility applied:** Added a narrow Plater-only nameplate cleanup guard in the passive Blizzard-fix module that hides absorb/heal-absorb/shield child frames on Plater nameplates when they appear, including a delayed re-pass and `OnShow` lock so the detached absorb widget does not pop back above the health bar.
  - **Root Cause:** The debug screenshot shows the visible stray region is `NamePlate5PlaterUnitFrameAbsorbBar.barTexture`, which is inside Plater's frame tree, not AzeriteUI's own [Components/UnitFrames/Units/NamePlates.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/NamePlates.lua) nameplate renderer. That module already disables itself when `Plater` is enabled, so the practical failure mode is coexistence: AzeriteUI stays loaded, Plater owns the nameplate, and Plater's absorb widget can remain visible in a broken detached state.
  - **Safety:** The fix is Plater-gated and runs from [Core/FixBlizzardBugs.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/FixBlizzardBugs.lua) without taking over nameplate ownership. It only hides absorb/shield child objects whose frame names or direct keys match the affected Plater widgets on `NAME_PLATE_UNIT_ADDED` / world entry.
  - **Verification:** `luac -p 'Core/FixBlizzardBugs.lua'` passed. In-game `/reload` with Plater enabled and an enemy carrying an absorb/shield effect still needs verification.
  - **Files Modified:** `Core/FixBlizzardBugs.lua`
- **Battleground party subgroup visibility logic started:** Investigating the follow-up report that battleground party-style frames now appear briefly and then vanish, while enabling `Show in Raid (6-10)` on the 25-man raid module or toggling party-in-raid options changes which frame tree survives. Scope is limited to [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua) and [Options/OptionsPages/UnitFrames.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/OptionsPages/UnitFrames.lua), because the symptom points to conflicting party/raid visibility drivers plus a bad options-page hide predicate rather than another bar-rendering issue.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Battleground party subgroup visibility logic applied:** Changed the party header to filter raid visibility down to the player's actual raid subgroup instead of all raid groups, and removed the `/az` options rule that hid `Raid Frames (5)` whenever Party Frames had any raid visibility toggle enabled.
  - **Root Cause:** [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua) was still feeding `groupFilter = "1,2,3,4,5,6,7,8"` into the secure party header in raid contexts. Because that header also uses `maxColumns = 1`, the live battleground result was effectively “show raid group 1”, not “show my local party subgroup”. Once the PvP roster finished settling, players outside raid group 1 saw the header empty out, which matched the “works for a few seconds then vanishes” report. Separately, [Options/OptionsPages/UnitFrames.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/OptionsPages/UnitFrames.lua) hid the entire `Raid Frames (5)` tree whenever Party Frames enabled any raid-size toggle, including unrelated `6-10`, `11-25`, and `26-40` states.
  - **Safety:** The runtime change only updates the addon-owned secure header filter on roster refresh using the player's current raid subgroup. It does not alter click actions, aura paths, Blizzard compact frames, or the raid module unit-token drivers. The options change only removes an incorrect UI hide predicate.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Party.lua'` and `luac -p 'Options/OptionsPages/UnitFrames.lua'` passed. In-game `/reload` plus battleground retest of party-in-raid visibility and the `/az` unit-frame tree are still needed.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Battleground party-frame overlap started:** Investigating the reported PvP/BG-only local-party layout break where the small party-style unit frames stack names/bars on top of each other while normal world/party groups still render correctly. Scope is limited to [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua) because that secure header is the only group module still reflowing raw `GetChildren()` results instead of explicit secure `child#` unit buttons.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`
- **Battleground party-frame overlap applied:** Switched the party secure-header reflow to anchor explicit secure `child#` unit buttons first, filtered the fallback child scan down to real unit buttons only, and sanitized saved header-point values before pushing them back into secure attributes.
  - **Root Cause:** [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua) was the last local group-header module still rebuilding layout from raw `header:GetChildren()`. In battleground/PvP raid-party states that can include non-unit or stale children in an order that does not match the secure `child1..N` member list, so the addon re-anchored the wrong frames and several party members collapsed onto the same visual slot. The same file also still trusted saved header anchor strings directly, unlike the already-hardened raid modules.
  - **Safety:** The fix stays inside the addon-owned party-header layout pass. It does not add new secure snippets, does not touch Blizzard compact PvP frames, and does not change click registration or unit-token drivers.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Party.lua'` passed. In-game `/reload` plus battleground/arena-skirmish party verification is still needed.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`
- **Player PvP badge asset/anchor follow-up started:** Investigating the stock player-frame PvP badge showing the wrong texture and landing on an awkward anchor after the retail frame updates. Scope is limited to the visual player badge path in [Components/UnitFrames/Units/Player.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Player.lua), the stock player layout in [Layouts/Data/PlayerUnitFrame.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Layouts/Data/PlayerUnitFrame.lua), and the `/az` player options in [Options/OptionsPages/UnitFrames.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/OptionsPages/UnitFrames.lua).
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Player.lua`, `Layouts/Data/PlayerUnitFrame.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Player PvP badge asset/anchor follow-up applied:** Restored the stock player-frame PvP badge to AzeriteUI’s Alliance/Horde media, moved its default layout onto a centered base anchor inside the player frame, and added `/az` X/Y offset controls plus a reset action so the badge can be repositioned without editing layout data.
  - **Root Cause:** [Components/UnitFrames/Units/Player.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Player.lua) created the player `PvPIndicator` texture but never assigned `Alliance` / `Horde` media to it, unlike the alternate player and target frame implementations. That left the override path with no addon media to swap in. The stock player layout in [Layouts/Data/PlayerUnitFrame.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Layouts/Data/PlayerUnitFrame.lua) also still used an old corner-based badge point, which made local player-frame repositioning awkward.
  - **Safety:** The change only affects the non-secure visual player PvP badge texture and its local point math. It does not touch secure headers, unit drivers, click registration, or aura logic.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Player.lua'` and `luac -p 'Options/OptionsPages/UnitFrames.lua'` passed. In-game `/reload` validation of the new `/az -> Unit Frames -> Player -> PvP Badge` controls pending.
  - **Files Modified:** `Components/UnitFrames/Units/Player.lua`, `Layouts/Data/PlayerUnitFrame.lua`, `Options/OptionsPages/UnitFrames.lua`

- **Big-raid priority debuff visibility/size option started:** Investigating request to shrink or hide the large raid priority debuff icon on retail 11-25 / 26-40 raid frames through `/az`. Scope is limited to the visual `PriorityDebuff` element in [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua) and [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua), plus [Options/OptionsPages/UnitFrames.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/OptionsPages/UnitFrames.lua), so the change stays away from secure header attributes and layout drivers.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Big-raid priority debuff visibility/size option applied:** Added `/az -> Unit Frames -> Raid Frames (25)` and `(40)` settings to hide the large priority debuff entirely or shrink it down, and wired the raid modules to reapply that visual sizing on live unit updates without touching secure header attributes.
  - **Root Cause:** [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua) and [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua) hardcoded the `PriorityDebuff` widget at `40x40` in the center of each raid button, with no profile control. That made the icon dominate the compact retail big-raid layout for users who prefer minimal debuff emphasis.
  - **Safety:** The fix only changes the visual `PriorityDebuff` element after the unit buttons already exist, and exposes profile-backed toggles in [Options/OptionsPages/UnitFrames.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/OptionsPages/UnitFrames.lua). It does not modify secure header attributes, visibility drivers, or any protected click/layout snippet paths.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, `luac -p 'Components/UnitFrames/Units/Raid40.lua'`, and `luac -p 'Options/OptionsPages/UnitFrames.lua'` passed. In-game `/reload` + retest of the new `/az` options pending.
  - **Files Modified:** `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Options/OptionsPages/UnitFrames.lua`
- **Secure header click-snippet regression started:** Investigating the follow-up retail BugSack spam where the secure party header now faults with `attempt to call method 'RegisterForClicks' (a nil value)` from the restricted `oUF-initialConfigFunction` snippet after the earlier click-taint workaround. Review scope is limited to the header child click-registration path because [Libs/oUF/ouf.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Libs/oUF/ouf.lua) already assigns secure `*type1` / `*type2` actions for header-spawned buttons before the layout snippet runs.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`, `Libs/oUF/ouf.lua`
- **Secure header click-snippet regression applied:** Removed the bad `RegisterForClicks("AnyUp")` calls from the restricted party / raid `oUF-initialConfigFunction` snippets and kept the shared non-header guard in [Components/UnitFrames/UnitFrame.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/UnitFrame.lua), so manually spawned unit frames still register clicks normally while secure header children rely on oUF’s existing secure `*type1` / `*type2` setup.
  - **Root Cause:** The earlier workaround moved click registration into the restricted snippet stored in `oUF-initialConfigFunction`, but `RegisterForClicks` is not exposed there. That made every secure header refresh fail inside the restricted environment. The underlying left-click target and right-click menu behavior was already being provided by oUF’s built-in secure header init in [Libs/oUF/ouf.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Libs/oUF/ouf.lua), which sets `frame:SetAttribute('*type1', 'target')` and `frame:SetAttribute('*type2', 'togglemenu')` for header children before each layout-specific snippet runs.
  - **Verification:** `luac -p 'Components/UnitFrames/UnitFrame.lua'`, `luac -p 'Components/UnitFrames/Units/Party.lua'`, `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, and `luac -p 'Components/UnitFrames/Units/Raid40.lua'` passed. In-game `/reload` + retest of party/raid clicks and Clique pending.
  - **Files Modified:** `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Secure raid-button click taint started:** Investigating the older retail `ADDON_ACTION_BLOCKED` report where [Components/UnitFrames/UnitFrame.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/UnitFrame.lua) calls `RegisterForClicks("AnyUp")` while oUF is styling secure party/raid header children. The BugSack stack points at the insecure style/init path during the restricted header build, not the later raid layout follow-up.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/UnitFrame.lua`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Secure raid-button click taint applied:** Stopped insecure `RegisterForClicks("AnyUp")` calls on secure header children during style/init by guarding the shared unitframe initializer and removing the redundant party / raid style-level calls for secure header children.
  - **Root Cause:** [Components/UnitFrames/UnitFrame.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/UnitFrame.lua) and the extra style-level calls in [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua), [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua), and [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua) were calling the protected `RegisterForClicks` API from insecure Lua while oUF was styling secure group-header children via the restricted header build path. That trips `ADDON_ACTION_BLOCKED` even before the frames are fully laid out. The later restricted-snippet attempt was reverted by the follow-up entry above after confirming oUF already provides secure `*type1` / `*type2` actions for header children.
  - **Verification:** `luac -p 'Components/UnitFrames/UnitFrame.lua'`, `luac -p 'Components/UnitFrames/Units/Party.lua'`, `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, and `luac -p 'Components/UnitFrames/Units/Raid40.lua'` passed. In-game `/reload` + retest of party/raid click targeting and Clique or mouseover-cast behavior pending.
  - **Files Modified:** `Components/UnitFrames/UnitFrame.lua`, `Components/UnitFrames/Units/Party.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Big-raid visual layout regression started:** Investigating retail 11-25 / 26-40 raid frames still bunching into a compact square after the nil-point crash fix. Initial comparison shows [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua) and [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua) still rely on the stock secure-header child placement path, unlike [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua) and [Components/UnitFrames/Units/Raid5.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid5.lua), which explicitly re-anchor children.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Big-raid visual layout regression applied:** Ported the explicit child re-layout pass used by the party / raid5 headers into the 25-man and 40-man raid headers, and added world/roster refresh hooks so retail raids reapply AzeriteUI’s intended row/column layout after the secure header populates.
  - **Root Cause:** [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua) and [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua) were updating secure attributes but never re-anchoring the spawned child buttons afterward. On retail, once the roster filled after login/join, Blizzard’s default secure placement kept the buttons packed into the compact square/grid instead of the addon’s intended growth pattern.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Raid25.lua'` and `luac -p 'Components/UnitFrames/Units/Raid40.lua'` passed. In-game `/reload` + retest in 11-25 and 26-40 raid rosters pending.
  - **Files Modified:** `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Raid frame secure-header nil-point bug started:** Investigating raid-frame breakage in raid groups where `SecureGroupHeaders.lua` faults with `attempt to index local 'point' (a nil value)` during [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua) `UpdateHeader()`. Scope includes the shared raid-header modules because [Components/UnitFrames/Units/Party.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Party.lua) already contains profile sanitization that the raid headers do not.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Raid frame secure-header nil-point bug applied:** Added shared saved-profile sanitization to the raid header modules before any secure `SetAttribute(...)` calls, so stale or incomplete raid-frame profile values can no longer clear `point`, `columnAnchorPoint`, or the numeric layout attributes during header refresh. The header anchor update path now also derives from the same sanitized values.
  - **Root Cause:** [Components/UnitFrames/Units/Raid25.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid25.lua) and the matching [Components/UnitFrames/Units/Raid5.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid5.lua) / [Components/UnitFrames/Units/Raid40.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/UnitFrames/Units/Raid40.lua) refresh paths still pushed raw saved profile fields directly into secure group-header attributes. If an older profile left `point` missing or invalid, Blizzard's `SecureGroupHeaders.lua` reconfigured on a later attribute write and crashed on a nil point table lookup.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/Raid5.lua'`, `luac -p 'Components/UnitFrames/Units/Raid25.lua'`, and `luac -p 'Components/UnitFrames/Units/Raid40.lua'` passed. In-game `/reload` + raid-group verification pending.
  - **Files Modified:** `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`
- **Release metadata bumped for current fixes:** Updated the in-repo release metadata and changelog from `5.3.8-JuNNeZ` to `5.3.9-JuNNeZ` for the minimap text-visibility cleanup and raid-frame secure-header fix set.
  - **Files Modified:** `AzeriteUI5_JuNNeZ_Edition.toc`, `build-release.ps1`, `CHANGELOG.md`, `VERSION_CHECKLIST.md`
- **Release metadata bumped for raid header follow-up:** Updated the in-repo release metadata and changelog from `5.3.9-JuNNeZ` to `5.3.10-JuNNeZ` for the big-raid layout repair and the secure raid-button click-taint / bad secure-snippet follow-up.
  - **Files Modified:** `AzeriteUI5_JuNNeZ_Edition.toc`, `build-release.ps1`, `CHANGELOG.md`, `VERSION_CHECKLIST.md`
- **Release metadata bumped for priority debuff test build:** Updated the in-repo release metadata and changelog from `5.3.10-JuNNeZ` to `5.3.11-JuNNeZ` for the uncommitted big-raid priority debuff visibility/size option test build.
  - **Files Modified:** `AzeriteUI5_JuNNeZ_Edition.toc`, `build-release.ps1`, `CHANGELOG.md`, `VERSION_CHECKLIST.md`

## 2026-03-13

- **Minimap text toggle/options-path cleanup started:** Replacing the retail-only `/az remove addontext|clocktext` slash path with proper `/az` minimap options, and fixing the remaining hardcoded legacy `Interface\\AddOns\\AzeriteUI\\...` texture paths so renamed-addon builds stop missing those assets.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/Minimap.lua`, `Components/Misc/Minimap.lua`, `Components/Misc/Info.lua`, `Components/Misc/TrackerWoW11.lua`, `Options/Options.lua`, `Core/Debugging.lua`
- **Minimap text toggle/options-path cleanup applied:** Moved the retired retail `/az remove addontext|clocktext` behavior into the `/az` Minimap options page, removed the conflicting tracker-side `/az` slash registration, migrated any legacy tracker text-hide flags into the Minimap profile once, and switched the remaining hardcoded legacy AzeriteUI texture paths over to addon-safe media lookups.
  - **Root Cause:** [Components/Misc/TrackerWoW11.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/Misc/TrackerWoW11.lua) still claimed `/az` for a small text-hide helper even though [Options/Options.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Options/Options.lua) and [WoW11/Misc/Options.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/WoW11/Misc/Options.lua) also register `/az` for the options UI. AceConsole only keeps one active slash handler per command, so the tracker helper path was effectively shadowed. Separately, the settings-panel icon and debug splash textures bypassed [Core/API/Assets.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Core/API/Assets.lua) and still hardcoded `Interface\\AddOns\\AzeriteUI\\...`, which misses in the renamed JuNNeZ edition folder.
  - **Verification:** `luac -p 'Components/Misc/Minimap.lua'`, `luac -p 'Components/Misc/Info.lua'`, `luac -p 'Options/OptionsPages/Minimap.lua'`, `luac -p 'Components/Misc/TrackerWoW11.lua'`, `luac -p 'Options/Options.lua'`, and `luac -p 'Core/Debugging.lua'` passed. Repository searches for legacy `Interface\\AddOns\\AzeriteUI\\` / `Interface\\Addons\\AzeriteUI\\` paths in addon code returned no matches. In-game `/reload` verification pending.
  - **Files Modified:** `Components/Misc/Minimap.lua`, `Components/Misc/Info.lua`, `Options/OptionsPages/Minimap.lua`, `Components/Misc/TrackerWoW11.lua`, `Options/Options.lua`, `Core/Debugging.lua`
- **Action bar proc overlay audit started:** Investigating report that action bar buttons are not showing spell proc/activation highlights. Scope limited to the main action-bar skin and embedded `LibActionButton` proc-glow path so we can restore the existing overlay behavior without adding a second event system.
  - **Files Targeted:** `FixLog.md`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar proc overlay audit applied:** Restored the embedded `LibActionButton` bridge that maps spell-activation overlay events onto AzeriteUI’s custom `CustomSpellActivationAlert` texture, while keeping LibCustomGlow as the fallback for buttons that do not define the custom alert.
  - **Root Cause:** [Components/ActionBars/Elements/ActionBars.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/ActionBars/Elements/ActionBars.lua) still creates `self.CustomSpellActivationAlert`, but the active [Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua) had regressed to `LCG.ShowOverlayGlow(self)` / `LCG.HideOverlayGlow(self)` only. That bypassed the texture the action bars actually skin, so proc highlights stopped rendering on the main bars even though the library was still receiving `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` and `SPELL_ACTIVATION_OVERLAY_GLOW_HIDE`.
  - **Verification:** `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed, plus in-game `/reload` proc verification pending.
  - **Files Modified:** `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar key-down options bug started:** Investigating `/az` action-bar settings BugSack errors when toggling the key-down option. Scope limited to the `ActionButtonUseKeyDown` setter in `Options/OptionsPages/ActionBars.lua`, since the runtime bars continue working and the stack points at the settings bridge rather than button behavior.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/ActionBars.lua`
- **Action bar key-down options bug remains known:** The attempted setter-path change was not sufficient; the `/az` toggle can still trip Blizzard Settings errors for `ActionButtonUseKeyDown` even though the actual action-bar runtime behavior remains fine. Reverted the speculative setter tweak so this release does not ship a claimed fix without verified in-game resolution.
  - **Known Issue:** Toggling `Cast action keybinds on key down` in `/az` may still throw BugSack errors from Blizzard Settings (`attempt to call a nil value` / `SetValue 'ActionButtonUseKeyDown' requires 'boolean' type, not 'nil' type`) on the WoW 12 client. Treat as settings-UI noise for now, not an action-bar runtime regression.
  - **Verification:** Attempted local code-path change was not accepted as fixed after user repro; no verified in-game fix in this iteration.
- **Action bar native assisted-highlight support started:** Auditing how local addons preserve Blizzard's assisted combat visuals on custom action bars without folding them into proc glow logic. Scope limited to AzeriteUI's embedded `LibActionButton` and the main action-bar button config path.
  - **Files Targeted:** `FixLog.md`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`, `Components/ActionBars/Prototypes/ActionBar.lua`
- **Action bar native assisted-highlight support applied:** Implemented Bartender-style native Blizzard assisted combat support on AzeriteUI's custom action bars by registering pure action buttons with `SetActionUIButton(...)`, restoring the native assisted rotation/highlight frames in the embedded LAB, and keeping spell proc overlay glows on their own path instead of merging them into assisted highlight state like ElvUI does.
  - **Root Cause:** AzeriteUI already had partial assisted plumbing in [Components/ActionBars/Elements/ActionBars.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Components/ActionBars/Elements/ActionBars.lua) and a color option that still called `SetAssistedHighlightColor`, but the active [Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua](c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/AzeriteUI5_JuNNeZ_Edition/Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua) no longer exposed that API, did not register custom action buttons with Blizzard via `SetActionUIButton`, and had no native `ActionBarButtonAssistedCombatRotationTemplate` / `ActionBarButtonAssistedCombatHighlightTemplate` update path. Bartender's embedded LAB keeps those native frames alive on custom action buttons; ElvUI replaces them with `LibCustomGlow`. The Bartender path is the safer fit here because AzeriteUI already has a distinct proc overlay texture and should not collapse proc and assisted highlights into one effect.
  - **Verification:** `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` and `luac -p 'Components/ActionBars/Prototypes/ActionBar.lua'` passed. In-game `/reload` and assisted-combat visual verification pending.
  - **Files Modified:** `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`, `Components/ActionBars/Prototypes/ActionBar.lua`
- **Action bar assisted-highlight circle follow-up started:** Keeping native assisted rotation support but replacing the square native assisted highlight layer on AzeriteUI's circular action buttons with a custom circular highlight texture. Scope limited to the action-button skin and the assisted highlight renderer in embedded LAB.
  - **Files Targeted:** `FixLog.md`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight circle follow-up applied:** Added a dedicated `CustomAssistedHighlight` texture to AzeriteUI's circular action-button skin and taught embedded LAB to prefer that circular texture for assisted next-cast highlights while keeping the native Blizzard assisted rotation frame and native square highlight frame as fallback for non-AzeriteUI buttons.
  - **Root Cause:** The Bartender-style native support restored Blizzard's assisted highlight functionality, but the native `ActionBarButtonAssistedCombatHighlightTemplate` itself is square. Local references do not reshape it cleanly; ConsolePort instead avoids that square native frame on custom buttons and uses an alternate highlight path. AzeriteUI already had a circular spell-highlight texture on the button skin, so the least risky hybrid is to keep native assisted rotation support and swap only the highlight renderer on AzeriteUI buttons.
  - **Verification:** `luac -p 'Components/ActionBars/Elements/ActionBars.lua'` and `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed. In-game `/reload` and assisted-combat visual verification pending.
  - **Files Modified:** `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight color follow-up started:** Investigating report that the circular assisted highlight still reads blue regardless of the `/az` dropdown selection. Scope limited to the assisted highlight palette values and the custom assisted texture tinting path.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight color follow-up applied:** Expanded the assisted highlight palette to `cyan`, `blue`, `purple`, `green`, `red`, `white`, and `pink`, and made the custom circular assisted texture use additive neutral tinting so the selected color reads more clearly instead of inheriting the source art's blue bias.
  - **Root Cause:** The new circular assisted highlight reused AzeriteUI's spell-highlight texture directly. That texture art carries a strong cool-toned base, so merely swapping vertex colors could still look blue in practice. On top of that, both the action-bar module and embedded LAB validated only the original three color keys. The fix was to keep the custom assisted path separate from proc glow, broaden the accepted palette, and force the custom assisted texture into a tint-friendly mode with `SetBlendMode("ADD")` plus `SetDesaturated(true)` where supported.
  - **Verification:** `luac -p 'Options/OptionsPages/ActionBars.lua'`, `luac -p 'Components/ActionBars/Elements/ActionBars.lua'`, and `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed. In-game `/reload` and visual color verification pending.
  - **Files Modified:** `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight release cleanup started:** Pruning the non-working assisted highlight color customization before release so the shipped code matches the verified native-assisted behavior. Scope limited to the `/az` action-bar options page, the action-button skin, and embedded LAB's speculative assisted tint helpers.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight release cleanup applied:** Removed the non-working assisted highlight color dropdown and the speculative custom assisted tint path, while keeping the verified native Blizzard assisted combat support on AzeriteUI action bars. Release code now ships only the working native-assisted implementation: `SetActionUIButton(...)`, native assisted rotation, native assisted highlight updates, and the earlier proc overlay restoration.
  - **Root Cause:** The visible assisted suggestion effect on AzeriteUI bars is still controlled by Blizzard's native assisted-highlight ownership once buttons are registered via `SetActionUIButton(...)`. The added color dropdown and custom tint scaffolding did not control the effect users actually saw, so keeping that UI and code in the release would advertise behavior the addon does not reliably provide yet.
  - **Verification:** `luac -p 'Options/OptionsPages/ActionBars.lua'`, `luac -p 'Components/ActionBars/Elements/ActionBars.lua'`, and `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed. In-game `/reload` verification of the native assisted highlight path still pending.
  - **Files Modified:** `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight cleanup correction started:** Restoring the circular assisted highlight renderer after the release cleanup removed too much and regressed AzeriteUI buttons back to Blizzard's square native highlight. Scope limited to the action-button skin and embedded LAB's assisted highlight display branch.
  - **Files Targeted:** `FixLog.md`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight cleanup correction applied:** Restored the circular assisted highlight renderer on AzeriteUI buttons while keeping the release cleanup's removal of the non-working color dropdown and tint scaffolding. The assisted suggestion should now be circular again, but color customization remains intentionally out of scope for this release.
  - **Root Cause:** The release cleanup correctly removed the broken color UI, but it also removed the separate `CustomAssistedHighlight` render path that was masking Blizzard's square assisted highlight on AzeriteUI's circular buttons. Re-adding only that renderer preserves the working shape fix without reintroducing unverified color behavior.
  - **Verification:** `luac -p 'Components/ActionBars/Elements/ActionBars.lua'` and `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed. In-game `/reload` verification pending.
  - **Files Modified:** `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight color reintroduction started:** Re-adding assisted highlight color choices, but only on the custom circular assisted renderer now that it is the visible layer on AzeriteUI buttons. Scope limited to the action-bar options page, the action-button skin, and the LAB branch that shows `CustomAssistedHighlight`.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight color reintroduction applied:** Restored the assisted highlight color dropdown and wired it only to AzeriteUI's custom circular assisted highlight texture. The color setting now tints `CustomAssistedHighlight` directly and does not attempt to recolor Blizzard's native assisted frame.
  - **Root Cause:** Once the circular assisted renderer was restored, its texture was showing untinted source art, which read as bright white. That made the path workable again for a narrow color feature, because AzeriteUI now controls the visible assisted layer on its own buttons. The earlier failure came from trying to influence a native Blizzard-controlled effect; this version only tints the custom circular texture that AzeriteUI itself shows.
  - **Verification:** `luac -p 'Options/OptionsPages/ActionBars.lua'`, `luac -p 'Components/ActionBars/Elements/ActionBars.lua'`, and `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed. In-game `/reload` and color verification pending.
  - **Files Modified:** `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight neutral overlay experiment started:** Adding a separate neutral color layer above the existing circular assisted highlight so the dropdown tints AzeriteUI's own overlay instead of the blue-biased base art. Scope limited to the action-button skin and the custom assisted highlight color setter path.
  - **Files Targeted:** `FixLog.md`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight neutral overlay experiment applied:** Added a second assisted-highlight texture above the existing circular assisted art and tinted only that top layer from the dropdown. The base circular assisted art remains untinted for shape, while `CustomAssistedHighlightColor` now provides the visible configurable color overlay.
  - **Root Cause:** The existing circular assisted texture keeps its shape correctly, but its source art collapses most tint choices back toward blue. A separate neutral overlay is a better color target because its visible color comes from AzeriteUI's own additive circle layer rather than from the baked-in color bias of the base art.
  - **Verification:** `luac -p 'Components/ActionBars/Elements/ActionBars.lua'` and `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed. In-game `/reload` and color verification pending.
  - **Files Modified:** `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight color experiment parked started:** Commenting out the assisted color UI and neutral overlay experiment so the release path goes back to the original circular assisted highlight in a fixed blue tint. Scope limited to the action-bar options page, the action-button skin, and LAB's assisted color helper path.
  - **Files Targeted:** `FixLog.md`, `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Action bar assisted-highlight color experiment parked applied:** Commented out the assisted highlight color dropdown, neutral overlay layer, and dynamic tint helper path. AzeriteUI now goes back to the original circular assisted highlight with a fixed blue tint for release, while the experimental color code remains parked in comments for later revisit.
  - **Root Cause:** The neutral overlay made the assisted highlight footprint too large, and the earlier attempts at tinting the base art were not reliable. For release, the stable path is the simple circular assisted highlight with one fixed color and no exposed color controls.
  - **Verification:** `luac -p 'Options/OptionsPages/ActionBars.lua'`, `luac -p 'Components/ActionBars/Elements/ActionBars.lua'`, and `luac -p 'Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua'` passed. In-game `/reload` verification pending.
  - **Files Modified:** `Options/OptionsPages/ActionBars.lua`, `Components/ActionBars/Elements/ActionBars.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`
- **Release version correction applied:** Bumped the in-repo release metadata from `5.3.7-JuNNeZ` to `5.3.8-JuNNeZ` after finalizing the assisted-highlight release state.
  - **Files Modified:** `AzeriteUI5_JuNNeZ_Edition.toc`, `build-release.ps1`, `CHANGELOG.md`

## 2026-03-12

- **SaiyaRatt secret command started:** Adding a small always-available hidden command that does a silly profile-themed effect without mutating settings or requiring dev mode. Scope limited to `Core/Core.lua`.
  - **Files Targeted:** `FixLog.md`, `Core/Core.lua`
- **SaiyaRatt secret command applied:** Added a new hidden AceConsole command that fires a small in-game “SaiyaRatt Exposition” burst, prints profile/variant status, and forces the SaiyaRatt-affected target and alternate-player frames to update.
  - **Root Cause:** There was no lightweight always-on fun command in the core addon path even though the SaiyaRatt work now has enough profile-specific behavior to make a harmless themed refresh gag useful.
  - **Verification:** `luac -p 'Core/Core.lua'` passed.
  - **Files Modified:** `Core/Core.lua`
- **SaiyaRatt alternate-player live-apply/threat audit started:** Reviewing follow-up report that the SaiyaRatt `PlayerAlternate` bar art still sometimes needs `/reload` after a profile switch and that the power threat glow now remains visible/white even when no active threat exists. Scope limited to the `PlayerAlternate` runtime refresh path and threat texture visibility logic.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/PlayerAlternate.lua`
- **SaiyaRatt alternate-player live-apply/threat audit applied:** Reapplied the alternate-player power bar geometry and textures during `UnitFrame_UpdateTextures()` so profile switches now restyle the already-spawned power widget instead of waiting for a frame recreate, and stopped the threat refresh path from force-showing every configured threat texture when no threat state is active.
  - **Root Cause:** The SaiyaRatt bar art lived in the root `PlayerFrameAlternate` config and was only consumed during frame creation, while later live refreshes only restyled health/cast/threat style textures. At the same time, the local threat rebuild loop had drifted from AzRattUI and unconditionally called `texture:Show()` whenever a threat texture path existed, which left the power glow visible even without active threat.
  - **Verification:** `luac -p 'Components/UnitFrames/Units/PlayerAlternate.lua'` passed.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerAlternate.lua`
- **CompactUnitFrame secret debuff boolean crash started:** Investigating Brawl PvP BugSack report from `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1666` (`attempt to perform boolean test on field 'isHarmful'`) while Blizzard compact aura code processes a secret-tainted aura table. Scope limited to the WoW 12 file-scope guards so we can sanitize compact aura payloads without re-enabling the older broad aura rewrites.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`
- **CompactUnitFrame secret debuff boolean crash applied:** Added a WoW 12 file-scope compact-aura sanitizer that strips secret aura fields to safe defaults before Blizzard compact-frame buff/debuff/dispel helpers consume them, plus a narrow `CompactUnitFrame_UpdateAuras` fallback that hides compact aura widgets only when Blizzard still throws a secret-value error.
  - **Root Cause:** `Core/FixBlizzardBugsWow12.lua` intentionally left compact-unit-frame globals untouched to avoid broad taint, but Brawl PvP still let Blizzard compact aura helpers evaluate a secret `aura.isHarmful` boolean directly. That crashed before Blizzard could finish `CompactUnitFrame_UpdateAuras`.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **CompactUnitFrame aura visual regression follow-up started:** Re-checking the new WoW 12 compact-aura guard after follow-up report that auras can look vanilla after the secret-value failure path. Scope limited to reducing the wrapper surface so we guard the crashing boolean gate without overriding Blizzard’s normal aura-set/render helpers.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`
- **CompactUnitFrame aura visual regression follow-up applied:** Removed the temporary wrappers around Blizzard compact aura `UtilSet*` render helpers and kept only the secret-safe display-gate sanitizers plus the `CompactUnitFrame_UpdateAuras` fallback. This keeps the crash guard focused on the `isHarmful` boolean check instead of altering Blizzard’s normal aura render path.
  - **Root Cause:** The first WoW 12 compact-aura fix also wrapped Blizzard’s aura-set helpers, which was broader than the reported `isHarmful` boolean fault and risked influencing the visual/render path that decides how compact auras look after recovery.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **CompactUnitFrame range/heal/nameplate follow-up started:** Investigating new current-session reports from March 12, 2026 for `CompactUnitFrame_GetRangeAlpha` secret `outOfRange`, `CompactUnitFrame_UpdateHealPrediction` secret `maxHealth`, and `Blizzard_NamePlateUnitFrame.lua:143` invalid `SetNamePlateHitTestFrame` argument during nameplate unit setup. Scope limited to adding the missing WoW 12 file-scope compact/nameplate guards without reviving the older broad secret wrappers.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`
- **CompactUnitFrame range/heal/nameplate follow-up applied:** Added WoW 12 file-scope guards for `CompactUnitFrame_GetRangeAlpha` and `CompactUnitFrame_UpdateHealPrediction`, plus a defensive `NamePlateUnitFrameMixin:OnUnitSet()` preflight that guarantees a fallback `HitTestFrame` before Blizzard calls `SetNamePlateHitTestFrame`.
  - **Root Cause:** The WoW 12 companion file still lacked active compact-frame guards for secret `frame.outOfRange` and secret heal-prediction math, and Blizzard nameplate unit setup could still receive a missing/invalid `HitTestFrame` during addon-tainted nameplate initialization.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **BugSack clipboard restore started:** Re-adding the missing BugSack copy-to-clipboard workflow through a local compatibility hook so retail can once again open the current formatted BugSack entry in a selectable multiline copy window.
  - **Files Targeted:** `FixLog.md`, `Components/Misc/Misc.xml`, `Components/Misc/BugSack.lua`
- **BugSack clipboard restore applied:** Added a new always-on misc hook that waits for `BugSack`, injects a `Copy` button into the BugSack footer, and opens a reusable multiline copy window seeded from `BugSackScrollText` so the current formatted report can be selected and copied again.
  - **Root Cause:** The installed retail `BugSack` UI no longer exposes any built-in copy-to-clipboard control, and this addon's old post-load BugSack hook was no longer present in the current retail module list.
  - **Verification:** `luac -p 'Components/Misc/BugSack.lua'` passed.
  - **Files Modified:** `Components/Misc/BugSack.lua`, `Components/Misc/Misc.xml`
- **BugSack clipboard follow-up started:** Adjusting the restored copy flow after runtime report that the popup was not surfacing above the BugSack window and that the copied payload must include the full current session rather than only the currently displayed error.
  - **Files Targeted:** `FixLog.md`, `Components/Misc/BugSack.lua`
- **BugSack clipboard follow-up applied:** Switched the popup payload to a full current-session export built from `BugSack:GetErrors(BugGrabber:GetSessionId())`, stripped the inline color markup for cleaner external pastes, raised the copy frame above BugSack explicitly, and added `Ctrl+C` auto-close with a chat confirmation once the copy keystroke is detected.
  - **Root Cause:** The first restore reused the currently visible `BugSackScrollText` entry and a normal dialog strata window, so it only copied one error at a time and could still appear behind the main BugSack frame.
  - **Verification:** `luac -p 'Components/Misc/BugSack.lua'` passed.
  - **Files Modified:** `Components/Misc/BugSack.lua`
- **WoW 12 compact/nameplate taint follow-up started:** Reworking the March 12 compact/nameplate companion guards after new runtime reports showed our local wrappers still leaked on secret-number heal prediction, tainted `NamePlateUnitFrameMixin` enough to trigger `Frame:SetForbidden()`, and exposed an EditBox-only BugSack copy-window sizing bug. Scope limited to replacing the tainting nameplate method override with per-frame hooks, broadening the secret-error matcher, and hardening the local BugSack popup sizing path.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`, `Components/Misc/BugSack.lua`
- **WoW 12 compact/nameplate taint follow-up applied:** Removed the direct `NamePlateUnitFrameMixin` override, moved compact/nameplate sanitizing onto the existing secure lifecycle hooks, broadened the secret-value error matcher so secret-number and secret-boolean compact heal/aura faults collapse quietly, prepared already-created compact frames during quarantine, and replaced the BugSack copy popup’s unsupported `EditBox:GetStringHeight()` call with font-height and line-count sizing.
  - **Root Cause:** The prior follow-up still replaced Blizzard methods on protected/shared frame paths. That was enough to taint nameplate creation in a way that surfaced `Frame:SetForbidden()` and also left the compact heal wrapper only matching the narrower `"secret value"` text, so secret-number comparisons still escaped and rethrew. Separately, the local BugSack popup assumed a FontString sizing API that retail EditBoxes do not always expose.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` and `luac -p 'Components/Misc/BugSack.lua'` passed.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`, `Components/Misc/BugSack.lua`
- **WoW 12 compact/nameplate range-text follow-up started:** Investigating the next current-session failures after the taint cleanup: `CompactUnitFrame_UpdateInRange` secret `unitOutOfRange`, `Blizzard_NamePlateUnitFrame.lua:143` bad `SetNamePlateHitTestFrame` argument still occurring on nameplate unit setup, and `TextStatusBar.UpdateTextStringWithValues` secret number compares from Blizzard nameplate health text. Scope limited to earlier nameplate creation hooks plus narrow compact range/health fallbacks instead of reviving shared mixin overrides.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`
- **WoW 12 compact/nameplate range-text follow-up applied:** Added fail-closed guards for `CompactUnitFrame_UpdateInRange` and `CompactUnitFrame_UpdateHealth`, now disabling Blizzard compact range fading on secret range results and suppressing Blizzard compact health text on secret health-text updates. Also normalized nameplate unit frames from both `NamePlateDriverFrame:AcquireUnitFrame()` and `:OnNamePlateCreated()` so the plate uses its root unit frame as `HitTestFrame` before later unit assignment paths.
  - **Root Cause:** The previous pass only sanitized the post-update `frame.outOfRange` field, but Blizzard was still throwing earlier inside `CompactUnitFrame_UpdateInRange` on a secret `unitOutOfRange` local. Nameplate hit-testing also needed to be normalized earlier than our later compact hooks, and Blizzard nameplate health bars were still allowed to run their numeric text formatter against secret values.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **WoW 12 Plater/nameplate conflict follow-up started:** Rechecking the same session after stationary inn repro showed the remaining failures are now concentrated in Blizzard nameplate setup and Plater’s Midnight suppression path (`SetPoint` dependency loops, `SetNamePlateHitTestFrame`, and Plater’s `reparentedUnitFrames[self.unit]` nil-index). Scope limited to backing our companion file off nameplate-specific mutation so Plater’s own Blizzard-frame handling remains the only active nameplate suppressor.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`
- **WoW 12 Plater/nameplate conflict follow-up applied:** Removed the companion file’s nameplate-specific frame normalization and creation hooks so it no longer rewrites Blizzard nameplate `HitTestFrame` or participates in nameplate setup/anchoring. The remaining WoW 12 companion guards now stay focused on compact party/raid/arena secret-value failures, leaving Blizzard-nameplate suppression entirely to Plater or the dedicated nameplate module.
  - **Root Cause:** The latest BugSack dump showed the new failures were centered on Blizzard nameplate setup and Plater’s own Midnight `OnRetailNamePlateShow()` reparent path, not on compact party logic. Our added nameplate normalization was colliding with that flow and likely contributed to the `SetPoint` dependency loop, lingering hit-test failure, and Plater nil-index on `self.unit`.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`
- **WoW 12 compact global-surface reduction started:** Reframing the remaining inn/reload repro around global taint rather than encounter context. Scope limited to removing the broad `CompactUnitFrame_UpdateHealth` / `UpdateInRange` / `UpdateHealPrediction` replacements and relying on option-table/frame-state suppression for nameplates and quarantined compact frames instead.
  - **Files Targeted:** `FixLog.md`, `Core/FixBlizzardBugsWow12.lua`
- **WoW 12 compact global-surface reduction applied:** Removed the broad WoW 12 replacements of Blizzard `CompactUnitFrame_UpdateHealth`, `CompactUnitFrame_UpdateInRange`, `CompactUnitFrame_GetRangeAlpha`, and `CompactUnitFrame_UpdateHealPrediction`. The companion file now pre-disables range fading, heal prediction, and numeric health text through frame state and option-table prep on nameplates and quarantined compact frames, while keeping the narrower compact aura guard intact.
  - **Root Cause:** The inn/reload repro made it clear the remaining failures were not encounter-specific. The broader global `CompactUnitFrame_*` replacements were the most likely source of nameplate taint leaking into Blizzard `OnUnitSet` / `SetNamePlateHitTestFrame` and health-text paths. Reducing the override surface is safer than layering more wrappers.
  - **Verification:** `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
  - **Files Modified:** `Core/FixBlizzardBugsWow12.lua`

## 5.3.3-JuNNeZ (2026-03-11)

**Status:** Release candidate.

### Bug Fixes In Progress
- **Full embedded oUF rollback started:** Abandoning the mixed post-sync library state after repeated runtime regressions during travel/combat. Scope limited to restoring the entire pre-sync embedded library trees from `Backups/oUF_sync_20260312_191700/` for `oUF`, `oUF_Plugins`, and `oUF_Classic`, with a safety backup of the current broken state first.
  - **Files Targeted:** `FixLog.md`, `Libs/oUF/**`, `Libs/oUF_Plugins/**`, `Libs/oUF_Classic/**`
- **Selective oUF rollback started:** Re-checking the broad stock library sync after new regressions in `Libs/oUF/colors.lua` and `Libs/oUF/elements/healthprediction.lua`. Scope limited to restoring only the mismatched embedded oUF files from the pre-sync backup instead of reverting the entire library replacement.
  - **Files Targeted:** `FixLog.md`, `Libs/oUF/colors.lua`, `Libs/oUF/elements/health.lua`, `Libs/oUF/elements/healthprediction.lua`, `Libs/oUF_Classic/elements/healthprediction.lua`
- **Selective oUF compatibility restore started:** Restoring the pre-sync `oUF` files whose contracts no longer match AzeriteUI’s current runtime (`colors.lua`, `health.lua`, and health prediction in retail/classic`) after direct diff review showed the stock replacements removed secret-safe prediction handling assumptions and older color table behavior this addon still depends on.
  - **Files Targeted:** `FixLog.md`, `Libs/oUF/colors.lua`, `Libs/oUF/elements/health.lua`, `Libs/oUF/elements/healthprediction.lua`, `Libs/oUF_Classic/elements/healthprediction.lua`
- **Local oUF library sync started:** Backing up the current embedded `oUF`, `oUF_Plugins`, and paired `oUF_Classic` folders, then updating them from the local `AzeriteUI_Stock` addon copy so the runtime libraries match stock before any follow-up fixes.
  - **Files Targeted:** `FixLog.md`, `Libs/oUF`, `Libs/oUF_Plugins`, `Libs/oUF_Classic`
- **Target percent stock-tag recheck started:** Verifying the local stock target file and embedded oUF health element after user suggestion that stock may already be sourcing percent through oUF. Scope limited to confirming the source and, if valid, moving our target percent back onto a tag-driven path without reviving stale fallback math.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Tags.lua`, `Components/UnitFrames/Units/Target.lua`, `Libs/oUF/elements/health.lua`, `AzeriteUI_Stock/Components/UnitFrames/Units/Target.lua`
- **Target percent cleanup/prune started:** Removing the failed proxy/interpolation experiment after local API and peer-addon review confirmed no readable secret-safe target percent source. Scope limited to simplifying `Target.lua` and trimming the matching debug noise so target percent only shows when we truly have a safe numeric source.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`, `Core/Debugging.lua`
- **Target percent API/peer-addon audit started:** Checking local WoW API docs/MCP data and neighboring addons (`GW2_UI`, `ElvUI`, `Platynator`, `AzeriteUI_Stock`) after repeated secret-target dumps still showed `api_secret` with `healthPercentText: 100%`. Scope limited to whether any local implementation exposes a readable post-widget health percent before we change the target path again.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`, `Core/Debugging.lua`
- **Target stale-percent cache purge started:** Removing the addon-side fallback that re-caches `100%` for target health whenever raw current health is secret and no numeric percent source is available. Scope limited to target-safe percent caching and display fallback rules.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Target.lua`
- **Target percent deep path audit started:** Verifying whether the stuck target percentage comes from duplicate local percent logic or addon-created overlay duplication. Audit confirmed the bar and text are following separate percent-resolution paths inside our own target code, not a second tagged fontstring or a taint-driven Blizzard fallback.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`, `Core/Debugging.lua`
- **Target percent live-update follow-up started:** Reviewing continued report that target percent text can still lag behind the visible fake-fill bar even after source-order fixes, with current scope limited to whether the percent fontstring is refreshed on the same live statusbar sync path as the fake-fill texture.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`
- **Target percent pinned-at-100 investigation started:** Reviewing `/azdebug dump target` output after follow-up report that the target percent text stays at `100%` even while the visible fake-fill health bar is lower. Scope limited to the target health percent update order/source priority in `Target.lua`.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`
- **Target health percent nil-call investigation started:** Tracing BugSack report `attempt to call global 'UpdateTargetHealthPercentText'` from `Target.lua:1047` during target frame `Health:PostUpdate`/`ForceUpdate`. Scope limited to local function resolution in the target unitframe module.
  - **Files Targeted:** `FixLog.md`, `Components/UnitFrames/Units/Target.lua`
- **Party leader-change priority debuff crash:** Normalized `oUF_PriorityDebuff` dispel entries to numeric priorities so party roster and leader updates no longer hit the boolean-vs-number compare path.
  - **Files Modified:** `Libs/oUF_Plugins/oUF_PriorityDebuff.lua`
- **Target health percent nil-call fixed:** Forward-declared the local `UpdateTargetHealthPercentText` helper before `Health_PostUpdate` and kept the later function body assignment on that same local, so early health callbacks no longer fall through to a missing global during target frame setup/config refresh.
  - **Root Cause:** `Health_PostUpdate` was defined before `local UpdateTargetHealthPercentText = function(...)` existed in scope, so Lua captured the global name instead of the intended local helper.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`
- **Target percent pinned-at-100 fixed:** Reordered target health post-update so fake-fill/safe-percent sync runs before the percent fontstring refresh, and made the text updater prefer the already-synced visible-bar cache whenever the target fake-fill path is active.
  - **Root Cause:** `Health_PostUpdate` updated the percent text before `SyncTargetHealthVisualState()` refreshed `health.safePercent`, while `UpdateTargetHealthPercentText()` still preferred a fresh `UnitHealthPercent(...ScaleTo100)` read that can stay stale at `100` on secret target updates.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`
- **Target percent live-update follow-up fixed:** Folded the percent fontstring refresh into `SyncTargetHealthVisualState()` so the text now updates on the same `OnValueChanged`/`OnMinMaxChanged` path that already keeps the fake-fill target health bar current.
  - **Root Cause:** The visible target fake-fill could live-update from statusbar script hooks without `Health_PostUpdate()` firing again, leaving the percent text stuck on an older cached value even after the bar itself had moved.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`
- **Target percent deep path audit fixed:** Added a dedicated hidden target-health proxy statusbar to derive an addon-readable display percent from the same secret payload that drives the visible fake-fill bar, and switched the percent text to that proxy-backed cache instead of stale readable API fallbacks when raw target health is secret.
  - **Root Cause:** The target health bar could render from a secret `UnitHealthPercent(...ZeroToOne)` payload, but our text path still relied on readable `ScaleTo100`/cached values. That split let the bar move while the text stayed pinned at an older `100%`.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`, `Core/Debugging.lua`
- **Target stale-percent cache purge fixed:** Target health now clears its numeric percent cache when the live percent is unresolved/secret instead of recomputing a fake `100%` from fallback `safeCur/safeMax`, and the target percent text no longer falls back to stale cached values in that unresolved secret path.
  - **Root Cause:** `API.UpdateHealth()` and `UpdateTargetHealthPercentText()` were still willing to reuse `safePercent` derived from fallback max-health values after the deep audit proved no readable percent existed (`displayPct nil`, `api_secret` path). That preserved a wrong `100%` even though the real live percent was not available to Lua.
  - **Files Modified:** `Components/UnitFrames/Functions.lua`, `Components/UnitFrames/Units/Target.lua`
- **Target percent API/peer-addon audit applied:** Local WoW API references and neighboring addons (`GW2_UI`, `ElvUI`, `Platynator`, `AzeriteUI_Stock`) confirmed there is no reusable secret-safe target-percent text path; peers still format `UnitHealthPercent(...ScaleTo100)` or raw `UnitHealth/UnitHealthMax` directly. Added a new target proxy probe that samples `StatusBar:GetInterpolatedValue()` before geometry fallback and expanded `/azdebug dump target` so the next dump shows whether Blizzard leaves the rendered proxy value readable after widget evaluation.
  - **Root Cause:** The earlier proxy experiment only read back secret-prone `GetValue`/texture geometry paths, so we still had no evidence about the one remaining local widget API that might expose a readable rendered percent.
  - **Peer Check:** `GW2_UI/core/Mixin/healthBarMixin.lua`, `GW2_UI/Libs/Core/oUF/elements/tags.lua`, `ElvUI/Game/Shared/Modules/Tooltip/Tooltip.lua`, `ElvUI/Game/Shared/Tags/Tags.lua`, `Platynator/Display/HealthText.lua`, and `AzeriteUI_Stock/Components/UnitFrames/Tags.lua` all rely on direct percent/raw-health APIs rather than a secret-safe post-widget extractor.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`, `Core/Debugging.lua`
- **Target percent cleanup/prune applied:** Removed the hidden target secret-percent proxy and all proxy-specific dump fields after the next dump proved even `GetInterpolatedValue()` remained secret. The target percent text path is now intentionally minimal: use readable `UnitHealthPercent(...ScaleTo100)` when available, otherwise fall back to safe raw `cur/max` only when both raw values are readable, else clear the text and cache.
  - **Root Cause:** The proxy/interpolation experiment added complexity without producing a readable percent; leaving it in place only made the target path harder to reason about while the UI still lied with stale cached text.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`, `Core/Debugging.lua`
- **Target percent stock-tag recheck applied:** Confirmed stock target percent is tag-driven, not oUF-computed. Moved our target percent back onto a tag as well, but used a dedicated `[*:TargetHealthPercent]` method that only accepts readable `UnitHealthPercent(...ScaleTo100)` or safe raw `cur/max` from the target frame. This keeps the stock-style text update flow without reintroducing the generic stale fallback chain that previously pinned `100%`.
  - **Root Cause:** The shared oUF health element only passes raw `cur/max` from `UnitHealth/UnitHealthMax`; stock gets percent through its tag layer. Our prior bespoke target text formatter had grown into a second logic path, while the generic `[*:HealthPercent]` tag still contained broader fallback behavior than we want for secret target health.
  - **Files Modified:** `Components/UnitFrames/Tags.lua`, `Components/UnitFrames/Units/Target.lua`
- **Local oUF library sync applied:** Backed up the pre-sync libraries to `Backups/oUF_sync_20260312_191700/`, then mirrored `Libs/oUF`, `Libs/oUF_Plugins`, and `Libs/oUF_Classic` from the local `AzeriteUI_Stock` addon copy. This removed local-only upstream metadata files that are not present in stock and aligned the embedded runtime library trees with the stock addon snapshot.
  - **Verification:** `luac -p 'Libs/oUF/elements/health.lua'` passed and `luac -p 'Libs/oUF_Classic/elements/health.lua'` passed. `luac -p 'Libs/oUF_Plugins/oUF_PriorityDebuff.lua'` did not complete within the command timeout, so plugin syntax was not fully re-verified here.
  - **Files Modified:** `Libs/oUF/**`, `Libs/oUF_Plugins/**`, `Libs/oUF_Classic/**`
- **Selective oUF compatibility restore applied:** Restored `Libs/oUF/colors.lua`, `Libs/oUF/elements/health.lua`, `Libs/oUF/elements/healthprediction.lua`, and `Libs/oUF_Classic/elements/healthprediction.lua` from the pre-sync backup after the stock replacements introduced immediate runtime regressions. `colors.lua` had shifted to a newer color-table contract that no longer matched this addon’s runtime, while the synced `healthprediction.lua` compared incoming-heal/heal-absorb values directly and tainted on WoW 12 secret numbers.
  - **Root Cause:** The full stock sync mixed newer `oUF` library assumptions into an addon codebase still built around the older embedded contract and secret-safe prediction behavior. That produced the `DebuffTypeColor` nil iteration crash in `colors.lua` and secret-number comparison crashes in `healthprediction.lua`.
  - **Safety Backup:** Saved the just-synced file set being replaced to `Backups/oUF_partial_rollback_20260312_1945/` before restoring the pre-sync copies.
  - **Verification:** Restored files match `Backups/oUF_sync_20260312_191700/` exactly for the four-file rollback set. `luac -p 'Libs/oUF/colors.lua'`, `luac -p 'Libs/oUF/elements/health.lua'`, `luac -p 'Libs/oUF/elements/healthprediction.lua'`, and `luac -p 'Libs/oUF_Classic/elements/healthprediction.lua'` all passed.
  - **Files Modified:** `Libs/oUF/colors.lua`, `Libs/oUF/elements/health.lua`, `Libs/oUF/elements/healthprediction.lua`, `Libs/oUF_Classic/elements/healthprediction.lua`
- **oUF colors enum guard started:** Following a new load-time crash at `Libs/oUF/colors.lua:91`, auditing the restored file against the local `oUF` bootstrap confirmed this embedded `oUF` tree does not define `oUF.Enum`. Scope limited to making `colors.lua` tolerate the older bootstrap by using stable fallback selection/dispel keys instead of assuming enum tables exist.
  - **Files Targeted:** `FixLog.md`, `Libs/oUF/colors.lua`, `Libs/oUF/init.lua`
- **oUF colors enum guard applied:** Added local fallback `SelectionType` and `DispelType` tables in `Libs/oUF/colors.lua` so the file no longer hard-depends on `oUF.Enum` during load. This keeps the newer color file compatible with the older local `oUF` bootstrap that only initializes `ns.oUF`/`ns.oUF.Private`.
  - **Root Cause:** The restored/synced `colors.lua` expected `oUF.Enum.SelectionType` and `oUF.Enum.DispelType`, but the local `Libs/oUF/init.lua` does not define `oUF.Enum` at all, so load failed before any frame code ran.
  - **Verification:** `luac -p 'Libs/oUF/colors.lua'` passed.
  - **Files Modified:** `Libs/oUF/colors.lua`
- **Full embedded oUF rollback applied:** Restored the entire `Libs/oUF`, `Libs/oUF_Plugins`, and `Libs/oUF_Classic` trees from `Backups/oUF_sync_20260312_191700/` after continued travel/combat regressions made the mixed post-sync state not worth salvaging. This discards the piecemeal compatibility attempts and returns the addon to the last known-good embedded library snapshot.
  - **Root Cause:** The stock sync plus follow-up selective fixes left the embedded library layer in a mixed-contract state. Even when individual crashes were addressed, the net result was still less stable than the original bundled libraries under real gameplay conditions.
  - **Safety Backup:** Saved the fully mixed/broken library state being discarded to `Backups/oUF_full_rollback_20260312_2005/`.
  - **Verification:** `git diff --no-index --quiet` reports `MATCH oUF`, `MATCH oUF_Plugins`, and `MATCH oUF_Classic` against `Backups/oUF_sync_20260312_191700/`. `luac -p 'Libs/oUF/colors.lua'`, `luac -p 'Libs/oUF/elements/health.lua'`, `luac -p 'Libs/oUF/elements/healthprediction.lua'`, `luac -p 'Libs/oUF_Classic/elements/healthprediction.lua'`, and `luac -p 'Libs/oUF_Plugins/oUF_PriorityDebuff.lua'` all passed.
  - **Files Modified:** `Libs/oUF/**`, `Libs/oUF_Plugins/**`, `Libs/oUF_Classic/**`

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

- **SaiyaRatt target/alt-player visibility follow-up started:** Reviewing the built-in SaiyaRatt preset after report that target still shows full health/absorb text and alternate player still shows the legacy mana crystal alongside the new mana bar. Scope limited to preset-gated visibility/layout behavior so stock Azerite remains unchanged.
  - **Files Targeted:** `FixLog.md`, `Layouts/Data/TargetUnitFrame.lua`, `Layouts/Data/PlayerUnitFrameAlternate.lua`, `Components/UnitFrames/Units/Target.lua`, `Components/UnitFrames/Units/PlayerAlternate.lua`
- **SaiyaRatt target/alt-player visibility follow-up applied:** Added explicit SaiyaRatt config flags so target now hides current-health text and absorb while keeping percent visibility under the compact crystal presentation, and alternate player now suppresses the Blizzard alt-power frame plus crops the imported bar art to remove the leftover crystal presentation.
  - **Files Modified:** `Layouts/Data/TargetUnitFrame.lua`, `Layouts/Data/PlayerUnitFrameAlternate.lua`, `Components/UnitFrames/Units/Target.lua`, `Components/UnitFrames/Units/PlayerAlternate.lua`
- **SaiyaRatt alt-power duplicate source identified:** Confirmed the retail `SanityBarFix` helper was restoring Blizzard's `PlayerPowerBarAlt` after login/zone/power-bar events, which can reintroduce the extra playeralternate power widget even when the SaiyaRatt preset hides it in the unitframe module.
  - **Files Targeted:** `Components/Misc/SanityBarFix.lua`, `Components/UnitFrames/Units/PlayerAlternate.lua`
- **SaiyaRatt alt-power duplicate source gated off:** Updated the retail `SanityBarFix` restore path to bail out and hard-hide Blizzard's `PlayerPowerBarAlt` while SaiyaRatt is active, and expanded the alternate-player hide helper to unregister the extra Retail power update events as well.
  - **Files Modified:** `Components/Misc/SanityBarFix.lua`, `Components/UnitFrames/Units/PlayerAlternate.lua`
- **SaiyaRatt target percent anchor issue identified:** Confirmed the compact target percent text was still anchoring to the generic target health overlay instead of the compact health backdrop/crystal, so SaiyaRatt offset tweaks alone could not center the percentage inside the crystal.
  - **Files Targeted:** `Layouts/Data/TargetUnitFrame.lua`, `Components/UnitFrames/Units/Target.lua`
- **Target percent display cache synced to fake-fill source:** Target health now caches a normalized `safePercent` from the same health-percent/fake-fill path that drives the compact target bar, with numeric fallback from `cur/max` during health post-updates. This keeps the SaiyaRatt target percentage text aligned with the visible bar instead of stale cached health values.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`
- **SaiyaRatt target percent + alt-power parity review started:** Re-checking SaiyaRatt against the desktop AzRattUI copy after report that target percent placement regressed and alternate player fell back to the old crystal-style power fill. Focus is limited to using the same percent-display priority as playerframe and removing local SaiyaRatt-only power-bar overrides that AzRattUI itself does not use.
  - **Files Targeted:** `Components/UnitFrames/Tags.lua`, `Components/UnitFrames/Units/Target.lua`, `Layouts/Data/PlayerUnitFrameAlternate.lua`
- **SaiyaRatt target percent priority + alt-power override cleanup applied:** Changed the shared `[*:HealthPercent]` tag to prefer a frame's cached display percent before recomputing from raw health values, moved SaiyaRatt target percent rendering onto a dedicated overlay anchored to the compact health backdrop, and removed local SaiyaRatt alternate-player texcoord/draw-level overrides that were not present in the desktop AzRattUI layout.
  - **Files Modified:** `Components/UnitFrames/Tags.lua`, `Components/UnitFrames/Units/Target.lua`, `Layouts/Data/PlayerUnitFrameAlternate.lua`
- **Peer target-percent review started:** Comparing local `GW2_UI`, `ElvUI`, and `Platynator` health-percent text paths after report that SaiyaRatt target still shows the wrong percentage. Goal is to match the stable peer pattern for percent display without disturbing unrelated target rendering.
  - **Files Targeted:** `Components/UnitFrames/Tags.lua`
- **Peer target-percent pattern applied:** Aligned `[*:HealthPercent]` with the local peer add-ons by preferring the direct Midnight health-percent API (`UnitHealthPercent(..., CurveConstants.ScaleTo100)`) before falling back to cached frame values or raw `cur/max`. This keeps target percent text sourced from the same authority used by `GW2_UI` and `Platynator`, instead of trusting unitframe cache math first.
  - **Peer References:** `GW2_UI/Libs/Core/oUF/elements/tags.lua`, `ElvUI/Game/Shared/Tags/Tags.lua`, `Platynator/Display/HealthText.lua`
  - **Files Modified:** `Components/UnitFrames/Tags.lua`
- **Target percent direct-update pass started:** Reworking target health percent to stop using the shared tag fallback chain and instead follow the same direct-update model already used by target power text. Scope limited to `Target.lua` so other unitframe percent tags stay untouched.
  - **Files Targeted:** `Components/UnitFrames/Units/Target.lua`
- **Target percent direct-update path applied:** Replaced the target-frame health percent tag path with a dedicated `Target.lua` updater that reads `UnitHealthPercent(..., CurveConstants.ScaleTo100)` first, then falls back to cached target health values only when needed. This makes target percent follow the same single-source update model as target power text instead of bouncing through the shared tag engine.
  - **Peer Check:** Local `GW2_UI` and `Platynator` both source displayed target health percent directly from `UnitHealthPercent`, while our target power text already uses a dedicated updater in `Target.lua`.
  - **Files Modified:** `Components/UnitFrames/Units/Target.lua`
- **Playeralternate live-refresh follow-up started:** Investigating report that SaiyaRatt alternate-player sometimes needs `/reload` after profile switches and that option toggles can leave the alternate-player threat textures visible but white. Scope limited to `PlayerAlternate.lua` runtime refresh behavior.
  - **Files Targeted:** `Components/UnitFrames/Units/PlayerAlternate.lua`
- **Playeralternate live-refresh follow-up applied:** Forced alternate-player power to refresh during module updates so SaiyaRatt bar art appears immediately after profile/option changes, and cached/reapplied the last threat color after texture refreshes so the power threat glow no longer comes back white when toggling alternate-player options.
  - **Files Modified:** `Components/UnitFrames/Units/PlayerAlternate.lua`
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
- **Retail tracker option cleanup started:** Confirmed the retail `TrackerWoW11` path no longer applies the old Azerite/Blizzard tracker theme logic, so the retail options page should stop exposing the stale experimental theme selector.
  - **Files Targeted:** `Options/OptionsPages/Tracker.lua`, `Components/Misc/TrackerWoW11.lua`
- **Retail tracker theme option removed:** Dropped the stale retail tracker theme dropdown from the options UI because `TrackerWoW11` no longer consumes that setting; retail now effectively relies on Blizzard's tracker presentation plus our hide/fade helpers only.
  - **Files Modified:** `Options/OptionsPages/Tracker.lua`
- **SaiyaRatt built-in profile preset work started:** Reviewing current `5.3.3` profile plumbing and lifting only the verified AzRattUI visual/layout deltas needed for a selectable built-in `SaiyaRatt` preset, while keeping newer JuNNeZ shared-unitframe/minimap safety fixes intact.
  - **Files Targeted:** `Core/Core.lua`, `Layouts/Layouts.lua`, `Options/Options.lua`, `Layouts/Data/PlayerUnitFrame.lua`, `Layouts/Data/PlayerUnitFrameAlternate.lua`, `Layouts/Data/TargetUnitFrame.lua`, `Components/UnitFrames/Units/PlayerAlternate.lua`, `Components/UnitFrames/Units/Target.lua`, `Assets/`
- **SaiyaRatt built-in profile preset added:** Seeded a protected built-in `SaiyaRatt` profile in the existing profile menu, backed it with a profile-scoped layout variant flag, and recreated the verified AzRattUI visual deltas for standard player PvP badge placement, alternate player mana-bar art/threat/positioning, and the compact critter-style target health presentation without copying the older shared-file regressions.
  - **Assets Imported:** `Assets/power-bar-front.tga`, `Assets/power-bar-back.tga`, `Assets/power_bar_glow.tga`, `Assets/hp_critter_case_hi.tga`
  - **Files Modified:** `Core/Core.lua`, `Options/Options.lua`, `Layouts/Layouts.lua`, `Layouts/Data/PlayerUnitFrame.lua`, `Layouts/Data/PlayerUnitFrameAlternate.lua`, `Layouts/Data/TargetUnitFrame.lua`, `Components/UnitFrames/Units/PlayerAlternate.lua`, `Components/UnitFrames/Units/Target.lua`

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

[2026-03-13] Iteration: WoW 12 ownership reset started

Request:
- Stop the ongoing compact/EditMode/nameplate/castbar secret-value whack-a-mole.
- Rebuild the WoW 12 path around explicit Blizzard frame quarantine/takeover instead of shared Blizzard function rewrites.

Plan for this pass:
- Keep `Core/FixBlizzardBugs.lua` passive on WoW 12.
- Strip `Core/FixBlizzardBugsWow12.lua` back to:
  - explicit compact party/raid/arena quarantine based on AzeriteUI module ownership
  - compact aura sanitization only where still needed
  - no nameplate mutation from the WoW 12 guard file
  - no shared castbar/EditMode rewrites from the WoW 12 guard file

Applied:
- Replaced `Core/FixBlizzardBugsWow12.lua` with a smaller WoW 12 ownership-reset implementation.
- Removed the file-scope castbar method guards and all nameplate-specific preparation/mutation from the WoW 12 companion file.
- Kept only:
  - compact aura predicate sanitization
  - compact aura fail-closed handling on frames AzeriteUI explicitly quarantines
  - compact party/raid/arena quarantine based on the actual AzeriteUI module ownership flags
  - Blizzard target/focus/boss spellbar quarantine instead of castbar method rewriting
- Left `Core/FixBlizzardBugs.lua` passive on WoW 12, so the reset path now lives almost entirely in the narrower companion file.

Root cause:
- The repeated inn `/reload` repro and the local addon comparisons showed this was not a missing single guard. The real failure mode was broad ownership overlap: AzeriteUI was still participating in Blizzard compact/nameplate/castbar lifecycle paths deeply enough to taint secret-value and protected-frame flows. Other full UIs avoid this by taking over party/raid/arena explicitly and not trying to patch shared Blizzard compact/nameplate internals into submission.

Verification:
- `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.

Files Modified:
- `Core/FixBlizzardBugsWow12.lua`

[2026-03-13] Iteration: FixBlizzardBugs WoW 12 passive-path cleanup

Request:
- Clean up `Core/FixBlizzardBugs.lua` so it is obvious the legacy lower-half fixes do not execute on WoW 12.

Applied:
- Added `IsPassiveWoW12FixEnvironment()` in `Core/FixBlizzardBugs.lua`.
- Switched the WoW 12 early-exit in `FixBlizzardBugs.OnInitialize` to use that helper.
- Added explicit comments documenting that the code below the early return is the legacy pre-WoW12 path and is unreachable once the secret-value / forbidden-table environment exists.

Root cause:
- The file still read as if the lower compact/EditMode/nameplate/castbar fix blocks might be live on WoW 12. They are not, but that was only obvious after tracing the early return manually, which made the file easy to misread during debugging.

Verification:
- No behavior change intended; comment/helper cleanup only.

Files Modified:
- `Core/FixBlizzardBugs.lua`

[2026-03-13] Iteration: WoW 12 nameplate secret-mode GW2-style suppression started

Request:
- Follow the GW2-style frame-ownership approach more closely for AzeriteUI-owned nameplates after the remaining WoW 12 errors stayed concentrated in Blizzard nameplate unitframes (`SetNamePlateHitTestFrame`, nameplate health text, and compact heal prediction on nameplate-backed CUF frames).

Plan for this pass:
- Keep the generic WoW 12 companion file out of nameplate ownership.
- Reuse `Components/UnitFrames/Units/NamePlates.lua` `clearClutter()` path in secret mode instead of returning early and leaving Blizzard plate internals alive.
- Limit the secret-mode change to light Blizzard plate suppression hooks for AzeriteUI-owned nameplates only.

Applied:
- Kept `PatchBlizzardNamePlate` / `PatchBlizzardNamePlateFrame` active in secret mode so the nameplate module still suppresses Blizzard plate internals for AzeriteUI-owned nameplates.
- Left the old `DisableBlizzardNamePlate` / `RestoreBlizzardNamePlate` reparent path disabled in secret mode.
- Added a one-shot pass over current `C_NamePlate.GetNamePlates()` in secret mode so already-existing Blizzard plates also receive the `clearClutter()` suppression path, not just newly created ones.

Root cause:
- In WoW 12 secret mode, the nameplate module was returning early before installing its Blizzard plate suppression hooks. That left Blizzard nameplate health text, heal prediction, and hit-test setup alive underneath AzeriteUI-owned nameplates, which matches the remaining error stacks.

Verification:
- `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` passed.

Files Modified:
- `Components/UnitFrames/Units/NamePlates.lua`

[2026-03-13] Iteration: WoW 12 GW2-style compact/nameplate follow-up applied

Request:
- Strengthen the GW2-style ownership approach after the first secret-mode suppression pass still left compact-party heal-prediction warnings and Blizzard nameplate `SetNamePlateHitTestFrame` failures.

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Added `OnShow` hide hooks to quarantined Blizzard frames so compact party/raid/arena surfaces do not reappear during later Blizzard refreshes.
  - Added active-pool/member enumeration for Blizzard party and arena frames, matching the GW2-style “enumerate active frames and disable them too” pattern instead of only relying on named globals.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added a narrow `EnsureBlizzardNamePlateHitTestFrame()` helper.
  - Applied that helper during Blizzard `OnNamePlateCreated`, `NamePlateUnitFrameMixin:OnUnitSet`, and the one-shot current-plate secret-mode pass so Blizzard gets a valid fallback hit-test frame before calling `SetNamePlateHitTestFrame`.

Root cause:
- Blizzard compact party members can still be reached through active frame pools during later profile/EditMode refreshes even after global frame quarantine, and Blizzard nameplate `OnUnitSet` was still reaching `SetNamePlateHitTestFrame` before our earlier suppression path finished hiding the plate internals.

Verification:
- `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
- `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` passed.

Files Modified:
- `Core/FixBlizzardBugsWow12.lua`
- `Components/UnitFrames/Units/NamePlates.lua`

[2026-03-13] Iteration: WoW 12 GW2-style quarantine bugfix started

Request:
- Fix the new helper regression in `Core/FixBlizzardBugsWow12.lua` and re-tighten the Blizzard nameplate hit-test fallback after follow-up errors still showed compact party `outOfRange`/`maxHealth` failures plus `SetNamePlateHitTestFrame`.

Plan for this pass:
- Fix the local function ordering bug that left `PrepareCompactFrame` nil inside the new pool enumeration helper.
- Make the secret-mode nameplate hit-test fallback unconditional so stale Blizzard child hit-test frames are replaced, not only nil/forbidden ones.

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Forward-declared `PrepareCompactFrame` so pooled compact-frame quarantine no longer faults on a nil global during active pool enumeration.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Changed the secret-mode hit-test fallback to always replace `UF.HitTestFrame` with `UF` itself before Blizzard uses it.

Root cause:
- The last compact follow-up accidentally introduced a local-function ordering bug, which could abort the active pool quarantine pass and leave Blizzard compact party members alive. On the nameplate side, only replacing nil/forbidden hit-test frames was too weak because Blizzard could still keep a stale child frame that failed the native `SetNamePlateHitTestFrame` call.

Verification:
- `luac -p 'Core/FixBlizzardBugsWow12.lua'` passed.
- `luac -p 'Components/UnitFrames/Units/NamePlates.lua'` passed.

Files Modified:
- `Core/FixBlizzardBugsWow12.lua`
- `Components/UnitFrames/Units/NamePlates.lua`

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
[2026-03-13] Iteration: WoW 12 compact range/heal fail-closed guard

Request:
- Fresh BugSack dump still showed Blizzard compact party updates reaching secret-value paths after the GW2-style ownership reset:
  - `CompactUnitFrame.lua:1073` boolean test on secret `frame.outOfRange`
  - previous / related `CompactUnitFrame.lua:1182` compare on secret `maxHealth`
- Same dump also included a transient `PrepareCompactFrame` nil regression during pooled-party quarantine.

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Kept the `local PrepareCompactFrame` forward declaration so pooled-frame quarantine does not resolve the helper as a global.
  - Added a narrow fail-closed wrapper for `CompactUnitFrame_GetRangeAlpha()`:
    - only swallows secret-value errors for compact frames AzeriteUI already intends to quarantine
    - disables range fading on that frame and returns full alpha (`1`)
  - Added a narrow fail-closed wrapper for `CompactUnitFrame_UpdateHealPrediction()`:
    - only swallows secret-value errors for compact frames AzeriteUI already owns/quarantines
    - disables Blizzard heal prediction visuals on that frame
- Left Blizzard nameplate ownership out of this file to avoid reopening the broader taint/nameplate overlap.

Why:
- This keeps the WoW 12 reset strategy intact:
  - ownership/quarantine first
  - only minimal fail-closed wrappers for still-leaking Blizzard compact party paths
- It avoids reintroducing broad nameplate/EditMode/castbar mutation while addressing the two remaining compact-party crash sites directly.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce the idle/inn and group-frame case
4. Confirm these no longer appear:
   - `CompactUnitFrame.lua:1073` secret `outOfRange`
   - `CompactUnitFrame.lua:1182` secret `maxHealth`

[2026-03-13] Iteration: WoW 12 compact health-color + nameplate acquire follow-up

Request:
- With Plater disabled, fresh BugSack dumps still showed:
  - `CompactUnitFrame.lua:707` secret `oldR` compare in `CompactUnitFrame_UpdateHealthColor()` on Blizzard compact party frames
  - `CompactUnitFrame.lua:1182` secret `maxHealth` still rethrowing from AzeriteUI's narrow heal wrapper on Blizzard nameplate-backed compact frames
  - `Blizzard_NamePlateUnitFrame.lua:143` invalid `SetNamePlateHitTestFrame` argument still occurring during Blizzard nameplate setup

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Added `IsBlizzardNamePlateCompactFrame()` / `ShouldFailClosedCompactSecretFrame()` so the narrow compact fail-closed wrappers can distinguish Blizzard nameplate CUF frames from party/raid/arena quarantine targets.
  - Added a narrow fail-closed wrapper for `CompactUnitFrame_UpdateHealthColor()`:
    - only swallows secret-value errors on AzeriteUI-owned compact frames or Blizzard nameplate compact frames
    - applies a stable fallback health-bar color instead of letting Blizzard compare secret old RGB values
  - Expanded the existing `CompactUnitFrame_GetRangeAlpha()` and `CompactUnitFrame_UpdateHealPrediction()` fail-closed wrappers to also cover Blizzard nameplate compact frames, with heal/text visuals disabled on secret failures.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added an earlier secret-mode hook on `NamePlateBaseMixin:AcquireUnitFrame()` so `HitTestFrame` is normalized before the later Blizzard `OnUnitSet()` path reaches `SetNamePlateHitTestFrame`.

Why:
- The previous fail-closed wrappers were still too narrow:
  - party frames could still hit Blizzard health-color comparisons before quarantine fully won
  - Blizzard nameplate compact frames were reaching the wrappers, but because they were not classified as quarantine targets the errors were rethrown
  - the nameplate hit-test fallback needed a pre-`OnUnitSet()` seam, not only post-create and post-`OnUnitSet()` hooks

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce both:
   - idle/party-frame setup
   - normal nameplate creation with Plater disabled
4. Confirm these no longer appear:
   - `CompactUnitFrame.lua:707` secret `oldR`
   - `CompactUnitFrame.lua:1182` secret `maxHealth`
   - `Blizzard_NamePlateUnitFrame.lua:143` bad `SetNamePlateHitTestFrame`

[2026-03-13] Iteration: WoW 12 nameplate anchor-cycle follow-up

Request:
- Fresh post-fix dump with Plater disabled removed the old secret-value crashes, but Blizzard nameplates now spammed `PixelUtil.SetPoint()` dependency-loop errors from `NamePlateUnitFrame:UpdateAnchors()` while anchoring the castbar and health container.

Applied:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Stopped calling `PatchBlizzardNamePlateFrame()` during the early secret-mode hooks:
    - `NamePlateDriverFrame:OnNamePlateCreated()`
    - `NamePlateBaseMixin:AcquireUnitFrame()`
    - `NamePlateUnitFrameMixin:OnUnitSet()`
  - In secret mode those hooks now only normalize `HitTestFrame` early enough for Blizzard’s native `SetNamePlateHitTestFrame()` path.
  - Blizzard clutter suppression still runs later through the existing `NAME_PLATE_UNIT_ADDED` / current-plate paths, after Blizzard has finished the sensitive `ApplyFrameOptions()` / `UpdateAnchors()` setup.

Why:
- `clearClutter()` was running too early in the Blizzard nameplate lifecycle. That left Blizzard still trying to lay out castbar and health-container anchors after we had already partially neutered the same frame tree, producing the self-dependent anchor loop in `PixelUtil.SetPoint()`.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce ordinary nameplate creation with Plater still disabled
4. Confirm `Blizzard_SharedXML/PixelUtil.lua:52` anchor-cycle errors no longer appear

[2026-03-13] Iteration: WoW 12 nameplate secret-mode clutter suppression rollback

Request:
- The anchor-cycle spam persisted, which showed that even the later secret-mode `NAME_PLATE_UNIT_ADDED` / current-plate `clearClutter()` path was still perturbing Blizzard nameplate layout.

Applied:
- `Components/UnitFrames/Units/NamePlates.lua`
  - In WoW 12 secret mode, stopped assigning `self.PatchBlizzardNamePlate` and `self.PatchBlizzardNamePlateFrame` entirely.
  - Secret mode now keeps only the early `HitTestFrame` normalization hooks and no longer runs `clearClutter()` on Blizzard nameplates at any stage.
  - Non-secret / legacy path keeps the previous Blizzard clutter suppression behavior unchanged.

Why:
- The remaining errors were no longer secret-value or hit-test faults. They were pure anchor-graph errors from mutating Blizzard castbar/health subframes while Blizzard still expected to lay them out. With the compact/nameplate secret guards already moved into safer fail-closed wrappers, the nameplate module no longer needs to suppress Blizzard subframes directly in secret mode.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce ordinary nameplate creation with Plater disabled
4. Confirm `Blizzard_SharedXML/PixelUtil.lua:52` no longer appears

[2026-03-13] Iteration: WoW 12 stock-oUF nameplate disable path

Request:
- Check other installed UI addons, the API, and outside references for the remaining Blizzard nameplate anchor-cycle failure and switch to the safer pattern if one exists.

Research:
- Local addon code:
  - `AzeriteUI_Stock/Libs/oUF/ouf.lua` hooks `NamePlateDriverFrame:AcquireUnitFrame()` to the shared oUF Blizzard-nameplate disable path.
  - The bundled `Libs/oUF/blizzard.lua` / GW2 / Diabolic / Unhalted all rely on the shared oUF disable path, not addon-local secret-mode `HitTestFrame` hooks.
- API:
  - `C_NamePlateManager.SetNamePlateHitTestFrame(unitToken, hitTestFrame)` expects a `SimpleFrame`.
  - `C_NamePlateManager.SetNamePlateHitTestInsets(type, left, right, top, bottom)` is already the hit-test API used by the oUF nameplate driver.
- Internet:
  - no better primary-source fix surfaced than the same stock/oUF `AcquireUnitFrame` disable pattern.

Applied:
- `Libs/oUF/ouf.lua`
  - Added a one-time `hooksecurefunc(NamePlateDriverFrame, 'AcquireUnitFrame', self.DisableBlizzardNamePlate)` inside `oUF:SpawnNamePlates()`.
- `Components/UnitFrames/Units/NamePlates.lua`
  - In WoW 12 secret mode, stopped installing the addon-local Blizzard-nameplate hook stack entirely by returning early after nulling the old patch/disable helpers.
  - Secret mode now relies on the shared oUF layer for Blizzard nameplate disabling instead of the custom `HitTestFrame` hook stack.

Why:
- The working local UI addons converge on the shared oUF disable path.
- `AcquireUnitFrame` is earlier and safer than the later addon-local mixin hooks, and it avoids our custom overlap with Blizzard nameplate setup/anchor code.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce ordinary nameplate creation with Plater disabled
4. Confirm `Blizzard_SharedXML/PixelUtil.lua:52` anchor-cycle errors stop

[2026-03-13] Iteration: WoW 12 minimal hit-test normalization restore

Request:
- After switching to the stock/oUF `AcquireUnitFrame` disable path, the anchor-cycle spam was gone but the original `SetNamePlateHitTestFrame` bad-argument error returned.

Applied:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Kept the shared oUF `AcquireUnitFrame` Blizzard-nameplate disable path as the only suppression path.
  - Restored only the minimal secret-mode `HitTestFrame` normalization hooks:
    - `NamePlateDriverFrame:OnNamePlateCreated()`
    - `NamePlateBaseMixin:AcquireUnitFrame()`
    - `NamePlateUnitFrameMixin:OnUnitSet()`
    - one-shot normalization for currently existing plates
  - Did not restore any secret-mode clutter suppression or Blizzard subframe mutation.

Why:
- The scan result narrowed it down cleanly:
  - stock/oUF `AcquireUnitFrame` disable path fixes the anchor-loop problem
  - the remaining `SetNamePlateHitTestFrame` error still needs the tiny `HitTestFrame` normalization layer
  - those two pieces can coexist safely as long as we do not bring back `clearClutter()` in secret mode

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce ordinary nameplate creation with Plater disabled
4. Confirm `Blizzard_NamePlateUnitFrame.lua:143` no longer appears

[2026-03-13] Iteration: WoW 12 dedicated nameplate hit-test frame

Request:
- The minimal `HitTestFrame = UnitFrame` restore removed the bad-argument fault but reintroduced the Blizzard nameplate anchor-cycle errors. We need a `SetNamePlateHitTestFrame()`-safe frame that does not participate in the UnitFrame anchor graph.

Applied:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Changed `EnsureBlizzardNamePlateHitTestFrame()` to create and reuse a dedicated inert frame on the nameplate root (`plate.__AzeriteUI_HitTestFrame`) instead of pointing `UF.HitTestFrame` at the full `UnitFrame`.
  - The dedicated frame is parented to the plate and `SetAllPoints(plate)`, keeping the click region alive without feeding Blizzard the same frame tree it is actively laying out.

Why:
- The scan narrowed the regression down to the frame choice, not the hook timing:
  - `UF.HitTestFrame = UF` satisfies `SetNamePlateHitTestFrame()`
  - but it also makes Blizzard treat the full UnitFrame tree as the hit-test target, which appears to be enough to reintroduce the castbar/healthbar anchor dependency loop
- A separate simple frame should satisfy the API without creating that self-reference.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce ordinary nameplate creation with Plater disabled
4. Confirm both stay gone:
   - `Blizzard_NamePlateUnitFrame.lua:143` bad `SetNamePlateHitTestFrame`
   - `Blizzard_SharedXML/PixelUtil.lua:52` anchor-cycle errors

[2026-03-13] Iteration: WoW 12 dungeon follow-up for nameplate castbars and party frame fallbacks

Request:
- Dungeon/party repro after the nameplate hit-test fix still produced:
  - Blizzard nameplate castbar `StopFinishAnims()` forbidden-table failures
  - nameplate CUF `bad self` / `bad argument` errors during health/heal/aura updates
  - Blizzard mainline party frame secret-number errors in `PartyMemberHealthCheck()` and `TextStatusBar`

Applied:
- `Libs/oUF/blizzard.lua`
  - Added an instance-level safe wrapper for Blizzard nameplate castbar `StopFinishAnims()` / `StopAnims()` that swallows only forbidden-table failures.
  - Applied that patch from the shared `oUF` Blizzard nameplate disable path before unregistering nameplate castbar events.
- `Core/FixBlizzardBugsWow12.lua`
  - Added `IsFrameAccessError()` and broadened the active CUF fail-closed wrappers so Blizzard nameplate frames suppress `bad self` / bad-argument errors, not only secret-value errors.
  - Added a live WoW12 guard for `C_UnitAuras.GetUnitAuras()` that returns safe empty data on invalid/secret inputs or API failure.
  - Added live WoW12 wrappers for `PartyMemberHealthCheck()` and `TextStatusBar` party health text updates so hidden Blizzard party frames fail closed instead of comparing secret values.
  - Extended compact status-text handling to the mainline lowercase `healthbar` path and expanded heal-prediction widget hiding to cover the party-frame variants.

Why:
- The remaining nameplate errors were no longer anchor or hit-test issues. They were follow-on failures from Blizzard still touching castbar/health/aura subpaths on frames we had already disabled through the early `AcquireUnitFrame` seam.
- The party errors were a separate gap: our active WoW12 reset handled compact-style `healthBar`, but Blizzard mainline party frames still use lowercase `healthbar` and their own `PartyMemberHealthCheck()` path.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce inside a dungeon with a party and ordinary nameplates active
4. Confirm these stay gone:
   - `CastingBarFrame.lua:722` attempted to iterate a forbidden table
   - `FixBlizzardBugsWow12.lua:552` rethrow from `CompactUnitFrame_UpdateAuras`
   - `PartyMemberFrame.lua:598` secret `unitHPMax`
   - `TextStatusBar.lua:106` secret number compare
   - `Blizzard_NamePlateAuras.lua:266` bad `C_UnitAuras.GetUnitAuras`

[2026-03-13] Iteration: WoW 12 nameplate target/highlight follow-up and party pet quarantine

Request:
- After the dungeon follow-up, the remaining errors were:
  - `CompactPartyFramePet#` secret `oldR` compares still falling through the compact guard
  - Blizzard nameplate selection-highlight and health-text paths still executing on disabled plates
  - a taint warning in `CompactUnitFrame_CheckNeedsUpdate()` after direct hit-test frame replacement on Blizzard nameplates

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Extended compact party quarantine matching to include `CompactPartyFramePet#`.
  - Quarantine pass now explicitly prepares/quarantines `CompactPartyFramePet#` globals alongside the existing party member frames.
- `Libs/oUF/blizzard.lua`
  - Added per-instance nameplate suppression for Blizzard health text and highlight regions from the shared `oUF` disable seam.
  - Nameplate health bars now fail closed by forcing status text off and overriding `UpdateTextDisplay()` locally instead of letting Blizzard re-enter `TextStatusBar` target-display logic on hidden plates.
  - Nameplate selection/aggro highlight regions are now neutralized locally so Blizzard `CompactUnitFrame_UpdateSelectionHighlight()` stops calling native `Show()` / `Hide()` on problem regions.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Changed `EnsureBlizzardNamePlateHitTestFrame()` to reuse Blizzard’s existing `UF.HitTestFrame` whenever it is valid, only falling back to the dedicated plate child frame when Blizzard does not provide a usable one.

Why:
- `CompactPartyFramePet#` was simply outside the current compact-party name matcher, so pet frames never became quarantine targets and still hit the secret `oldR` path.
- The remaining nameplate errors were no longer castbar or aura related. They were target/highlight/text paths still running against Blizzard nameplate subregions after the shared disable seam.
- Reusing Blizzard’s own hit-test frame where possible should reduce direct taint on the UnitFrame table while preserving the `SetNamePlateHitTestFrame()` fix.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce inside a dungeon with a party and ordinary nameplates active
4. Confirm these stay gone:
   - `CompactUnitFrame.lua:707` secret `oldR` on `CompactPartyFramePet#`
   - `CompactUnitFrame.lua:910` bad self on `selectionHighlight:Hide()`
   - `TextStatusBar.lua:166` secret `valueMax` from Blizzard nameplate health text
   - `CompactUnitFrame.lua:233` forbidden-object taint in `CompactUnitFrame_CheckNeedsUpdate()`

[2026-03-13] Iteration: WoW 12 party status-text mixin guard and compact selection follow-up

Request:
- After the nameplate target/highlight follow-up, the remaining errors were:
  - Blizzard mainline party frames still hitting `TextStatusBar.lua:106` and `PartyMemberFrame.lua:598` on Edit Mode refresh paths
  - `CompactRaidFrame#` pet/raid frames still rethrowing the compact heal-prediction `maxHealth` secret compare
  - Blizzard nameplates still hitting `CompactUnitFrame_UpdateSelectionHighlight()` bad-self errors and a forbidden-object taint warning in `CompactUnitFrame_CheckNeedsUpdate()`

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Added `MAX_RAID_MEMBERS`, `IsForbiddenObjectError()`, and nameplate status-bar detection.
  - Extended compact raid matching/quarantine to include `CompactRaidFrame#` and unit-token fallbacks like `partypet#` / `raid#`.
  - Moved the status-text fail-closed guard onto the live `TextStatusBarMixin` methods, with legacy `_G.TextStatusBar` fallback only if needed.
  - Added fail-closed wrappers for `CompactUnitFrame_UpdateSelectionHighlight()` and `CompactUnitFrame_CheckNeedsUpdate()` on Blizzard nameplate compact frames.
  - Broadened `ADDON_LOADED` reapply coverage to include Blizzard text-status, raid, edit-mode, and nameplate modules.

Why:
- The surviving party status errors were still coming through Blizzard’s mixin-backed text update path, not the legacy `_G.TextStatusBar` table we had wrapped.
- `CompactRaidFrame1` fell outside the current raid matcher, so raid/pet compact frames could still miss the quarantine/fail-closed surface.
- The remaining nameplate issues were narrow shared CUF update paths, so adding targeted fail-closed wrappers was safer than reintroducing per-instance Blizzard nameplate mutations.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce with a party, Edit Mode refresh, and ordinary nameplates active
4. Confirm these stay gone:
   - `TextStatusBar.lua:106` secret compare on `STATUS_TEXT_PARTY`
   - `PartyMemberFrame.lua:598` secret `unitHPMax`
   - `CompactUnitFrame.lua:1182` secret `maxHealth` on `CompactRaidFrame#`
   - `CompactUnitFrame.lua:910` bad self on selection highlight
   - `CompactUnitFrame.lua:233` forbidden-object taint warning on Blizzard nameplates

[2026-03-13] Iteration: WoW 12 rollback of early nameplate disable seam and party healthbar script suppression

Request:
- After the mixin/status-text follow-up, the remaining errors shifted to:
  - Blizzard nameplate creation taint (`ADDON_ACTION_BLOCKED` on `Frame:SetForbidden()`)
  - Blizzard nameplate castbar/anchor failures during `ApplyFrameOptions()` / `UpdateAnchors()`
  - Blizzard mainline party status-text and `PartyMemberHealthCheck()` secret compares still firing during Edit Mode refresh

Applied:
- `Libs/oUF/ouf.lua`
  - Removed the early `NamePlateDriverFrame:AcquireUnitFrame()` disable hook. Shared Blizzard nameplate suppression now falls back to the later `NAME_PLATE_UNIT_ADDED` seam only.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Removed the secret-mode local Blizzard nameplate hook stack and the now-unused hit-test normalization helper.
  - Secret mode now avoids addon-local mutation during protected Blizzard nameplate creation.
- `Core/FixBlizzardBugsWow12.lua`
  - `DisableStatusBarText()` now also sets `disableMaxValue` and `statusTextDisplay = "NONE"`.
  - Added `DisableStatusBarScripts()` / `DisableFrameStatusBarScripts()` and apply them from `PrepareCompactFrame()` so hidden Blizzard party/raid frames stop running `OnValueChanged`/`OnMinMaxChanged` health-bar scripts at all.

Why:
- The new `SetForbidden()` block points to the early Blizzard nameplate creation seam itself being tainted. Continuing to touch frames from `AcquireUnitFrame()` was no longer safe.
- The remaining party errors were still arriving through live health-bar scripts on Blizzard frames we already intend to quarantine, so cutting those scripts off directly is safer than chasing inaccessible Blizzard text helpers.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce with a dungeon party, Edit Mode refresh, and ordinary nameplates active
4. Confirm these stay gone:
   - `ADDON_ACTION_BLOCKED` on `Frame:SetForbidden()`
   - `CastingBarFrame.lua:722` forbidden-table iteration
   - `Blizzard_NamePlateUnitFrame.lua:659` / `:746` bad `ClearAllPoints`
   - `TextStatusBar.lua:106` / `:166` secret compares on party health text
   - `PartyMemberFrame.lua:598` secret `unitHPMax`

[2026-03-13] Iteration: WoW 12 late nameplate rollback and live party health wrapper follow-up

Request:
- After rolling back the early nameplate seam, the remaining errors were:
  - Blizzard party health updates still hitting `TextStatusBar.lua:106` / `:166` and `HealthBar.lua:8`
  - Blizzard nameplate creation still showing `ADDON_ACTION_BLOCKED` on `Frame:SetForbidden()`
  - Blizzard nameplate compact updates still failing in `UpdateAnchors()` and `CompactUnitFrame_UpdateName()`

Applied:
- `Libs/oUF/ouf.lua`
  - In WoW 12 secret mode, stopped calling `oUF:DisableBlizzardNamePlate()` from `NAME_PLATE_UNIT_ADDED`.
- `Core/FixBlizzardBugsWow12.lua`
  - Added `IsPartyHealthBar()` so live Blizzard party/pet health bars can be identified directly.
  - Wrapped global helper functions `TextStatusBar_UpdateTextStringWithValues`, `TextStatusBar_UpdateTextString`, `UnitFrameHealthBar_Update`, `UnitFrameHealthBar_OnValueChanged`, and `HealthBar_OnValueChanged`.
  - Party/pet health bars now fail closed by clearing status-bar scripts/text when Blizzard hits secret-value compares.
  - Added a fail-closed wrapper for `CompactUnitFrame_UpdateName()` on Blizzard nameplate compact frames.

Why:
- The latest stacks showed Blizzard was still bypassing the mixin wrapper through global helper functions and direct unit-frame healthbar update paths.
- Any remaining Blizzard nameplate disabling in secret mode was still enough to taint protected nameplate creation, so the safest path is to stop calling the shared disable seam there entirely and rely on the narrower global fail-closed guards.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce with a party, party pets, Edit Mode refresh, and ordinary nameplates active
4. Confirm these stay gone:
   - `TextStatusBar.lua:106` / `:166`
   - `Blizzard_GameTooltip/HealthBar.lua:8`
   - `ADDON_ACTION_BLOCKED` on `Frame:SetForbidden()`
   - `Blizzard_NamePlateUnitFrame.lua:659` / `:746`
   - `CompactUnitFrame.lua:816` bad `UnitShouldDisplayName(unit)`

[2026-03-13] Iteration: WoW 12 mana-bar follow-up and final secret-mode nameplate driver rollback

Request:
- After the late nameplate rollback, the remaining errors were:
  - party mana-bar text still hitting `TextStatusBar.lua:106`
  - party pet health-bar scripts still hitting `Blizzard_GameTooltip/HealthBar.lua:8`
  - Blizzard nameplate creation/update still tainted enough to trip `Frame:SetForbidden()` and `UpdateAnchors():ClearAllPoints()` bad-self errors

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - `DisableFrameStatusBarScripts()` now recursively covers nested party pet frames.
  - Added fail-closed wrappers for `UnitFrameManaBar_UpdateType()` and `UnitFrameManaBar_Update()`.
  - Party quarantine now also explicitly prepares/quarantines nested `PartyMemberFrame#PetFrame` objects.
- `Components/UnitFrames/Units/NamePlates.lua`
  - Removed the last secret-mode call to `clearClutter(NamePlateDriverFrame)`.

Why:
- The latest party error moved from health to the Blizzard mana-bar text path, so the health-only wrappers were no longer enough.
- The remaining pet health-bar error showed that nested party pet frames were still outside the direct status-bar script suppression pass.
- `clearClutter(NamePlateDriverFrame)` was the last unconditional Blizzard nameplate mutation still running in secret mode, making it the most likely remaining source of the protected nameplate taint/anchor fallout.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce with a party, party pets, Edit Mode refresh, and ordinary nameplates active
4. Confirm these stay gone:
   - `TextStatusBar.lua:106` on `UnitFrameManaBar_UpdateType`
   - `Blizzard_GameTooltip/HealthBar.lua:8` on party pets
   - `ADDON_ACTION_BLOCKED` on `Frame:SetForbidden()`
   - `Blizzard_NamePlateUnitFrame.lua:659` / `:746`

[2026-03-13] Iteration: WoW 12 root-cause reset back to ownership-only compact handling

Request:
- Stop the whack-a-mole and remove the disease instead of adding more symptom wrappers.
- The original reproducible bug was the Brawl PvP compact aura `isHarmful` secret boolean crash; the later nameplate/party/EditMode fallout started only after broad shared Blizzard rewrites were added on top.

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Removed the WoW 12 wrappers for:
    - `C_UnitAuras.GetUnitAuras`
    - `PartyMemberHealthCheck`
    - `TextStatusBar*`
    - `UnitFrame*HealthBar*`
    - `UnitFrameManaBar*`
    - `HealthBar_OnValueChanged`
    - `CompactUnitFrame_Update*` shared globals
  - Kept only the narrow compact aura predicate sanitizers:
    - `CompactUnitFrame_UtilShouldDisplayBuff`
    - `CompactUnitFrame_UtilShouldDisplayDebuff`
  - Kept the ownership/quarantine path for Blizzard compact party/raid/arena frames and Blizzard spellbars we replace.
  - Reduced WoW 12 `ADDON_LOADED` reapply back to compact-frame modules only.

Why:
- Replacing shared Blizzard globals was the disease. Once those shared CUF/statusbar/nameplate functions are rewritten by addon code, taint spreads into Blizzard nameplate creation, party Edit Mode refresh, and every later compact-frame update.
- The original Brawl PvP bug was an aura-predicate issue inside Blizzard compact auras. The least invasive fix is to sanitize only that predicate surface while keeping the “ownership” model for compact party/raid/arena frames we already replace.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce the original compact Brawl/party scenario and also ordinary world nameplates
4. Confirm both classes of regression stay gone:
   - original `CompactUnitFrame.lua:1666` secret `isHarmful`
   - the later nameplate/party/EditMode taint cascade (`SetForbidden`, `ClearAllPoints`, `TextStatusBar`, mana/health helpers)

---

[2026-03-13] Iteration: Remove residual Blizzard frame-table taint from WoW 12 compact quarantine

Request:
- Stop the remaining compact party/Edit Mode errors without reintroducing shared Blizzard wrappers.
- The last surviving errors still pointed at Blizzard compact party heal prediction and party status text, both tainted by `AzeriteUI5_JuNNeZ_Edition`.

Applied:
- `Core/FixBlizzardBugsWow12.lua`
  - Removed the remaining direct field writes on Blizzard compact/status bars from the WoW 12 quarantine path.
  - `PrepareCompactFrame()` is now intentionally a no-op, with the narrow aura predicate sanitizers left intact.
- `Components/UnitFrames/Units/Party.lua`
  - Added WoW 12 `UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")` before applying compact quarantine.
- `Components/UnitFrames/Units/Raid5.lua`
  - Added the same WoW 12 `GROUP_ROSTER_UPDATE` shutdown before compact quarantine.
- `Components/UnitFrames/Units/Raid25.lua`
  - Added the same WoW 12 `GROUP_ROSTER_UPDATE` shutdown before compact quarantine.
- `Components/UnitFrames/Units/Raid40.lua`
  - Added the same WoW 12 `GROUP_ROSTER_UPDATE` shutdown before compact quarantine.

Why:
- The remaining `maxHealth` and `valueMax` stacks were still Blizzard code touching secret values on frames whose tables we had previously modified.
- In WoW 12, even "harmless" addon-owned writes like `statusTextDisplay`, `disableMaxValue`, `outOfRange`, `inDistance`, or compact option flags can taint the Blizzard frame object enough to poison later internal secret-value compares.
- The safer ownership model is: sanitize only the original compact aura predicate surface, and otherwise disable/quarantine Blizzard frames through methods and event shutdown, not addon-side state writes.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Reproduce with party frames, raid-style party setting/Edit Mode refresh, and compact party members active
4. Confirm these stay gone:
   - `CompactUnitFrame.lua:1182` secret `maxHealth`
   - `TextStatusBar.lua:106` / `:166` secret `valueMax`

[2026-03-13] Iteration: Restore secret-mode Blizzard nameplate visual hide only

Request:
- After stripping the secret-mode nameplate suppression back to zero mutation, Blizzard health bars were again visible behind the custom AzeriteUI nameplates.

Applied:
- `Components/UnitFrames/Units/NamePlates.lua`
  - Added a new secret-mode-only `HideBlizzardNamePlateVisual(unit)` helper.
  - It applies a delayed visual hide to the Blizzard `NamePlate.UnitFrame` by forcing `SetAlpha(0)` on the root UnitFrame and its health bar only.
  - Added one-time `OnShow` and `SetAlpha` hooks per Blizzard UnitFrame so later Blizzard alpha updates do not make the duplicate health bar visible again.
  - Kept the secret-mode path free of reparenting, event unregistering, clutter stripping, or other protected creation-time mutation.

Why:
- The previous rollback fixed the taint cascade by backing away from Blizzard nameplate mutation entirely, but that also removed the only remaining visual suppression layer.
- The duplicate bar symptom only needs a visual hide. Restoring reparent/event/clutter changes would reopen the same protected nameplate creation and anchor risks we just removed.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Let ordinary nameplates appear
4. Confirm Blizzard health bars are no longer visible behind AzeriteUI nameplates
5. Also confirm the earlier secret-mode regressions do not return:
   - `ADDON_ACTION_BLOCKED` on `Frame:SetForbidden()`
   - `Blizzard_NamePlateUnitFrame.lua:659` / `:746`

---

[2026-03-18] Iteration: Combat aura visibility, chat temp-frame taint, and forbidden aura-table sanitization

Request:
- Investigate separate WoW 12 issues reported across combat aura visibility, `BN_WHISPER` chat taint, battleground/execution-time spam, and `attempted to iterate a forbidden table`.
- Keep the fixes local: do not blanket-disable aura handling or Blizzard wrappers unless the exact path is proven unsafe.

Applied:
- `Components/UnitFrames/Auras/AuraFilters.lua`
  - Removed the player aura combat-state branch so the same filter path is used in and out of combat.
  - Relaxed player/party secret-timing handling so valid auras stay visible when `expirationTime`, `duration`, or `applications` become secret.
- `Components/UnitFrames/Units/Party.lua`
  - Added camelCase aura layout fields (`spacingX`, `spacingY`, `growthX`, `growthY`) alongside the legacy hyphenated keys so party aura direction/padding settings are actually consumed by the active oUF aura layout.
- `Components/UnitFrames/Units/Player.lua`
  - Added the same camelCase aura layout fields for player frame aura settings.
- `Components/Auras/Auras.lua`
  - Stopped hiding the entire top-right player aura button when timing values are unavailable/secret; the icon now remains visible while cooldown/timer text are disabled.
  - Added a lightweight `0.1s` throttle to the visible-buff alpha refresh path.
  - Added temporary combat-only aura debug prints gated by the existing aura debug flags.
- `Components/Misc/ChatFrames.lua`
  - Stopped styling temporary chat windows.
  - Removed the custom `AddMessage` wrapper that ran an extra alpha-fix path for every incoming chat line.
  - Limited the chat clutter updater to non-temporary chat frames only.
- `Core/FixBlizzardBugsWow12.lua`
  - Replaced `pairs(aura)` sanitization with keyed fallback sanitization using the compact aura defaults table.
- `Core/FixBlizzardBugs.lua`
  - Replaced remaining `pairs(aura)` secret sanitizers with keyed fallback sanitization over known aura fields only.

Why:
- The combat aura disappearance was not a single taint issue: player and party aura filters were still allowed to hide auras when timer-related fields became secret at combat boundaries.
- The party aura direction/settings problem was a separate config wiring bug: the runtime layout consumed camelCase keys that party/player setup code never populated.
- The `BN_WHISPER` stack and battleground chat spam were likely amplified by chat-frame mutation on temporary windows and the per-message `AddMessage` override, which touched Blizzard chat internals on every line.
- The forbidden-table error matched the remaining aura sanitizers that still iterated Blizzard aura tables directly under WoW 12.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Verify player-frame and top-right auras stay visible when entering combat, even if cooldown text disappears for some entries.
4. Verify party auras keep the configured growth direction and no longer drop debuffs on combat entry.
5. Reproduce battleground chat spam and confirm these do not return:
   - `Script from "AzeriteUI5_JuNNeZ_Edition" has exceeded its execution time limit`
   - `attempted to iterate a forbidden table`
6. Reproduce Battle.net whispers and confirm this does not return:
   - `attempt to perform string conversion on a secret string value` in `SetLastTellTarget`
7. Recheck aura-related secret stacks and confirm this does not return:
   - `WoW11/Misc/Auras.lua:46` secret `expirationTime`

Update:
- Restored a player-frame-only combat relevance filter in `Components/UnitFrames/Auras/AuraFilters.lua`.
- The combat branch now again trims long/irrelevant player auras, but only when timer data is safely readable.
- Secret or missing timer fields still stay visible, so the combat disappearance regression should remain fixed.

Adjustment:
- Tightened the player-frame secret-data fallback again so only harmful or otherwise important auras survive when timing fields are secret.
- This specifically avoids leaking utility/helpful buffs like mounts into the player-frame combat aura list.

Adjustment:
- Updated the retail player-frame filter to combine token-based relevance (`IMPORTANT`, `RAID_IN_COMBAT`, `CROWD_CONTROL`, `BIG_DEFENSIVE`, `EXTERNAL_DEFENSIVE`) with stack detection from `C_UnitAuras.GetAuraApplicationDisplayCount`.
- Secret-data fallback now keeps harmful, important, stacked, and temporary helpful auras visible in combat, while still filtering non-temporary utility buffs like mounts.

Request:
- Tighten the retail player-frame aura filter again: generic timed utility buffs like Mana Diving Stone, Sign of Battle, and guild tabard reputation bonuses should stay in the top-right aura frame only, not in the player-frame combat aura row.
- Investigate a second regression where top-right aura buttons keep their border and tooltip in combat, but lose icon/count/timer text.

Applied:
- `Components/UnitFrames/Auras/AuraFilters.lua`
  - Added a retail helper for Blizzard `HELPFUL|RAID` / `HELPFUL|PLAYER|RAID` aura categories.
  - Tightened the player-frame filter so secret helpful auras only survive if they are categorized as important/raid-relevant or have visible stacks.
  - Reduced generic timed helpful fallback to shorter player/combat buffs instead of admitting all timed helpful auras.
- `Components/Auras/Auras.lua`
  - Added a retail-safe aura data resolver that reads `C_UnitAuras.GetAuraDataByIndex` alongside `UnitAura`.
  - Rehydrates icon, count, spell texture, and display-count data from auraData/auraInstanceID when direct `UnitAura` returns secret or nil fields in combat.

Why:
- The previous player-frame fallback still admitted helpful auras merely because they had timing data, which is why non-combat utility buffs could remain in the compact combat aura row once timing fields went secret.
- The blank top-right buttons were a separate render regression: the aura still existed, but the button renderer was clearing icon/count/timer inputs instead of rebuilding safe display fields from the modern retail aura API.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Confirm Mana Diving Stone, Sign of Battle, guild tabard rep bonuses, mounts, and similar utility buffs remain in the top-right aura frame only.
4. Enter combat and gain fresh stacked/self-buff combat auras; confirm the player-frame row still shows combat-relevant buffs and stacks.
5. While in combat, confirm top-right aura buttons keep their icon art and stack text instead of showing only borders/tooltips.

Request:
- Convert the retail aura logic properly instead of stacking more patch logic: keep AzeriteUI's intended behavior and look, but move the actual implementation onto modern safe aura APIs.
- Cross-check against `AzeriteUI_Stock` for the original behavior, and use the safer retail methods already used by the other installed UIs where they fit.

Applied:
- `Components/Auras/Auras.lua`
  - Replaced the legacy top-right aura-header display reads from `UnitAura(...)` with a single retail-native path built on `C_UnitAuras.GetAuraDataByIndex`, `C_UnitAuras.GetAuraDuration`, and `C_UnitAuras.GetAuraApplicationDisplayCount`.
  - Moved tooltip tracking onto `auraInstanceID`, matching the modern oUF/unitframe aura path.
  - Converted the consolidation counter update to use `auraData.shouldConsolidate` from `C_UnitAuras` instead of unpacking `UnitAura` tuples.
  - Kept AzeriteUI's existing secure header, layout, border/icon look, bar, and short-duration fade behavior.
- `Components/UnitFrames/Auras/AuraFilters.lua`
  - Cleaned up the retail player-frame helper logic into named short-duration / temporary-duration helpers.
  - Kept the current retail-safe combat relevance behavior, but removed one redundant fallback branch so the filter reads closer to stock intent.

Why:
- `AzeriteUI_Stock` used the intended display rules and look, but its retail aura code still relied on direct `UnitAura` tuple fields and addon-side timer arithmetic that became unreliable under WoW 12 secret values.
- The other modern UIs in the AddOns folder do not try to keep those old tuple paths alive; they render from `auraInstanceID` and let Blizzard duration/count APIs drive the UI.
- Converting AzeriteUI's actual aura header onto the same retail-native data model removes most of the patch-on-patch complexity while preserving the original behavior.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Verify top-right auras still sort, render, and fade like AzeriteUI stock, but no longer lose icon/count/timer display when entering combat.
4. Verify player-frame auras still filter down to combat-relevant buffs/debuffs and do not pick up generic utility buffs.
5. Verify stacked combat buffs gained during combat still appear on the player frame and in the top-right aura header.

Request:
- Follow-up regression from live testing: top-right aura buttons can still lose their icon/count display in combat, and player-frame auras can disappear entirely.
- Tighten the implementation around those two live paths without reverting to the older broad utility-buff leakage.

Applied:
- `Components/Auras/Auras.lua`
  - Changed the top-right aura-header resolver back to a hybrid display read: `UnitAura(...)` tuple fields are used first for immediate button rendering, with `C_UnitAuras`/`auraInstanceID` still supplying duration objects, display counts, and tooltip identity.
  - Stopped clearing the icon texture when the current aura still resolves a name/spell but one display field drops out during combat; spell texture fallback is retained.
- `Components/UnitFrames/Auras/AuraFilters.lua`
  - Added a retail `HELPFUL|CANCELABLE` check and broadened the player-frame secret fallback just enough to keep non-cancelable self/combat buffs visible when timer fields are secret.

Why:
- The pure `C_UnitAuras.GetAuraDataByIndex` header conversion is cleaner on paper, but the live secure-header path still appears to lose some immediate display fields in combat on this client/build.
- The player-frame regression showed the previous secret fallback was too strict for real combat buffs that are not consistently tagged by Blizzard as important/raid-relevant.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Enter combat and verify top-right aura icons no longer blank while borders/tooltips remain.
4. Verify player-frame combat buffs appear again.
5. Recheck that utility/cancelable buffs like mounts/tabard-rep style effects still stay out of the player-frame row.

Adjustment:
- `Components/Auras/Auras.lua`
  - Matched the safer secure-header behavior seen in `FeelUI`: if the combat update path temporarily fails to resolve current aura display data, the button now keeps its last known visual state instead of being cleared to a border-only shell.
- `Components/UnitFrames/Auras/AuraFilters.lua`
  - Removed the display-identity requirement from the player-frame secret fallback so combat auras are not hidden just because `name`/`spellId` becomes unreadable while other aura relevance flags remain valid.

Request:
- The player-frame aura row is still too restrictive for some classes/specs, but long utility buffs like Sign of Battle, guild tabard reputation bonuses, and mounts should still stay in the main aura header by default.
- Add a dedicated "Player Aura settings" section so the player-frame filter categories can be tuned directly from options with clear examples of what each category includes.

Applied:
- `Components/UnitFrames/Units/Player.lua`
  - Added profile defaults for player-frame aura category toggles so the filter behavior is configurable without changing stock defaults.
- `Components/UnitFrames/Auras/AuraFilters.lua`
  - Replaced the remaining hardcoded player-frame aura decisions with profile-backed category gates for debuffs, important buffs, raid-relevant buffs, stacking buffs, short combat buffs, short out-of-combat buffs, and optional long utility buffs.
  - Kept long utility buffs disabled by default so the player-frame row still prefers combat-relevant information.
- `Options/OptionsPages/UnitFrames.lua`
  - Added a new `Player Aura settings` section under the player frame options with toggle descriptions and concrete examples for each category.

Why:
- The live retail-safe filter had reached the point where the only way to loosen or tighten player-frame aura visibility was another code change.
- Exposing the existing filter categories makes the row easier to tune per class/spec while preserving AzeriteUI's default intent: combat-relevant auras on the player frame, long utility buffs in the main aura header.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Open `Unit Frames -> Player` and review the new `Player Aura settings` block.
4. Toggle categories on/off and verify the player-frame aura row updates immediately.
5. Confirm long utility buffs still stay out of the player-frame row by default, and only appear there if `Show Long Utility Buffs` is enabled.

Request:
- Newly gained buffs can still appear as border-only buttons in the top-right aura header during combat, while tooltips still resolve on mouseover.
- Re-check the secure-header display path against the other installed UIs and remove any remaining gating that prevents new combat auras from getting icon/count/timer payloads.

Applied:
- `Components/Auras/Auras.lua`
  - Added a safe `C_UnitAuras.GetAuraDataByAuraInstanceID` fallback inside the top-right button resolver.
  - Removed the hard requirement that a combat aura must expose a readable `name` before the button update is allowed to proceed.
  - Expanded field fallback so icon, spellID, count, duration, and expiration can be recovered from either index data or instanceID data before the button is treated as unresolved.

Why:
- The previous secure-header resolver still had one retail-hostile assumption left: a newly added aura with a valid `auraInstanceID` and tooltip target could still be discarded if `name` was sanitized on that update.
- That leaves the secure button alive but without a visual payload, which matches the live "border only, tooltip still works" symptom.

Testing:
1. `/buggrabber reset`
2. `/reload`
3. Gain a brand new buff in combat and verify the top-right header shows icon/count/timer instead of a border-only button.
4. Mouse over the aura to confirm the tooltip still resolves by `auraInstanceID`.
5. Recheck older pre-combat buffs to make sure they still update normally.

Request:
- Simplify the WoW 12 audit path in `Core/FixBlizzardBugs.lua` by commenting out code that is not enabled on WoW 12 anyway.
- Keep the live WoW 12 path intact, but make the inactive pre-WoW12 body obvious.

Applied:
- `Core/FixBlizzardBugs.lua`
  - Replaced the dead early WoW 12 emergency safe-mode block with a short comment explaining that it is no longer part of the live path.
  - Replaced the unreachable legacy pre-WoW12 body after the WoW 12 early return with a short comment that points to the actual live WoW 12 path.

Why:
- The file contained large inactive sections that made it look like many old wrappers were still live on WoW 12, even though `OnInitialize` returns before that body executes.
- Removing that dead body from the active source makes future debugging of WoW 12 issues much less ambiguous.

Testing:
1. `/reload`
2. Confirm AzeriteUI still loads without Lua errors.
3. Re-check the existing WoW 12 aura and combat fixes, since the live WoW 12 path itself was not changed.

Request:
- Clean up the `/az` titles, page names, and menu headers so it is clear which settings page controls which part of the UI.
- Keep the structure intact, but make the wording cleaner and more user-friendly.

Applied:
- `Options/Options.lua`
  - Updated the main Settings landing page subtitle, instructions, button label, and credits header.
- `Options/OptionsPages/Auras.lua`
  - Renamed the page/menu entry to `Aura Header` / `Aura Header Settings` and clarified that it controls the top-right aura header only.
- `Options/OptionsPages/Chat.lua`
  - Renamed the page/menu entry to `Chat Windows`.
- `Options/OptionsPages/Info.lua`
  - Renamed the page/menu entry to `Top Bar & Clock`.
- `Options/OptionsPages/Tracker.lua`
  - Renamed the page/menu entry to `Objectives Tracker`.
- `Options/OptionsPages/TrackerVanilla.lua`
  - Matched the same `Objectives Tracker` naming in Classic.
- `Options/OptionsPages/Widgets.lua`
  - Renamed the page/menu entry to `Top Center Widgets`.
- `Options/OptionsPages/UnitFrames.lua`
  - Normalized `Unit Frame Settings` spelling and `Player Aura Settings` capitalization.

Why:
- The `/az` menu mixed internal module names, generic labels, and player-facing labels.
- These naming changes make the menu easier to scan and make it clearer which page controls the top-right aura header versus unit-frame aura rows and other UI sections.

Testing:
1. `/reload`
2. Open `/az`
3. Check the landing page subtitle, instructions, and button text.
4. Check the left-side menu labels and confirm the page titles match the visible category names.

Request:
- Improve visual grouping in `/az` so related settings stay together with clearer lines between sections.
- Rename `Top Bar & Clock` to `Info/Clock` to match the in-game wording used elsewhere.

Applied:
- `Options/OptionsPages/Info.lua`
  - Renamed the menu/page label to `Info/Clock`.
  - Added a short top description so the page scope is obvious before the clock settings section.
- `Options/OptionsPages/Chat.lua`
  - Split the page into `Fade Behavior` and `Reload Protection` sections with descriptions.
  - Renamed the reload toggle/range labels to read more cleanly.
- `Options/OptionsPages/Tracker.lua`
  - Added a `Tracker Visibility` header and short description.
- `Options/OptionsPages/TrackerVanilla.lua`
  - Added the same tracker header/description on Classic.
- `Options/OptionsPages/Widgets.lua`
  - Added a `Widget Visibility` header and short description.

Why:
- Some pages still read like flat lists of toggles, even after the menu-title cleanup.
- Adding a few small headers and descriptions makes related options feel grouped without restructuring the menu tree.

Testing:
1. `/reload`
2. Open `/az`
3. Check that `Info/Clock` appears in the menu instead of `Top Bar & Clock`.
4. Open Chat Windows, Objectives Tracker, and Top Center Widgets and verify the new section headers make the pages easier to scan.

Request:
- The player-frame aura defaults should follow the standard AzeriteUI stock behavior by default, even though extra custom settings now exist.
- Apply the stock behavior as the default behavior, not by forcing stock layout/settings elsewhere.

Applied:
- `Components/UnitFrames/Units/Player.lua`
  - Added a new default profile flag, `playerAuraUseStockBehavior = true`.
- `Components/UnitFrames/Auras/AuraFilters.lua`
  - Added a stock-behavior branch for the retail player-frame aura filter:
    - in combat: show harmful auras, buffs under 301 seconds, short-remaining buffs, and stacks
    - out of combat: show timed buffs, short-remaining buffs, and stacks
  - Kept WoW 12 secret-value fallback handling under that stock behavior so combat entry does not hide valid auras just because timing fields go secret.
- `Options/OptionsPages/UnitFrames.lua`
  - Added `Use AzeriteUI Stock Behavior` above the custom player aura toggles.
  - Custom category toggles are disabled while stock behavior is enabled.

Why:
- The new player aura settings were useful for tuning, but the default behavior had drifted away from classic AzeriteUI expectations.
- This restores the stock filtering intent as the default while still allowing custom behavior when needed.

Testing:
1. `/reload`
2. Open `/az -> Unit Frames -> Player`
3. Confirm `Use AzeriteUI Stock Behavior` is enabled by default.
4. Verify player-frame auras behave like stock AzeriteUI again by default.
5. Disable `Use AzeriteUI Stock Behavior` and confirm the custom category toggles become active.

Request:
- Reframe `Ignore current target` and `Hide Blizzard auras while targeting`.
- Verify what each option actually does and stop them from reading like duplicates.

Applied:
- `Components/Auras/Auras.lua`
  - Confirmed `ignoreTarget` only controls the AzeriteUI top-right aura header visibility driver.
  - Documented that Blizzard aura visibility driver updates are legacy-only and intentionally skipped on WoW 12.
- `Options/OptionsPages/Auras.lua`
  - Renamed `Ignore current target` to `Keep Aura Header Visible With Target`.
  - Rewrote the description so it clearly refers only to the AzeriteUI top-right aura header.
  - Reframed `Hide Blizzard auras while targeting` as a legacy compatibility option.
  - Hid the Blizzard option on WoW 12, where Blizzard aura frames are already disabled for secure compatibility and the option cannot do anything distinct.

Why:
- The two toggles looked like they controlled the same thing, because on WoW 12 the Blizzard-aura toggle is not an active code path.
- Making the AzeriteUI header option explicit and hiding the inactive legacy option keeps the page honest and easier to understand.

Testing:
1. `/reload`
2. Open `/az -> Aura Header`
3. Confirm the AzeriteUI header option now reads `Keep Aura Header Visible With Target`.
4. On WoW 12, confirm the Blizzard-targeting option is no longer shown.

Request:
- Prepare the current aura/combat/options fix set for release.
- Update release metadata, changelog, tracking docs, and tag the release build.

Applied:
- `AzeriteUI5_JuNNeZ_Edition.toc`
  - Bumped addon version from `5.3.14-JuNNeZ` to `5.3.15-JuNNeZ`.
- `build-release.ps1`
  - Bumped release package version to `5.3.15-JuNNeZ`.
- `CHANGELOG.md`
  - Added the new `5.3.15-JuNNeZ` delta-only release entry titled `The Aura Homeostasis`.
- `VERSION_CHECKLIST.md`
  - Updated latest/next version tracking for the new release.
- `AGENTS.md`
  - Updated current version tracking to reflect the new latest release.

Why:
- The aura, combat, Blizzard-compatibility, and options cleanup work is now large enough to ship as a patch release.
- Release metadata, changelog, and internal tracking need to stay aligned before packaging, tagging, and distribution.

Testing:
1. Run `luac -p` on touched Lua files if needed.
2. Run the release build script and verify the archive name uses `5.3.15-JuNNeZ`.
3. `/reload` in-game and verify the aura fixes and `/az` labeling changes on the release candidate.

Request:
- Add party-frame aura controls for layout, debuff sizing, and visibility rules.
- Fix party debuffs that flicker out after briefly appearing, especially dispellable/removable debuffs.
- Add a frame glow for dispellable debuffs so both the aura and the unit frame communicate the state.

Applied:
- Started audit of party aura logic in:
  - `Components/UnitFrames/Units/Party.lua`
  - `Components/UnitFrames/Auras/AuraFilters.lua`
  - `Components/UnitFrames/Auras/AuraStyling.lua`
  - `Options/OptionsPages/UnitFrames.lua`
- Compared against:
  - `GW2_UI` retail aura handling (`aurasSecret.lua`, `Units/Grid/elements/auras.lua`)
  - `DiabolicUI3` retail aura filters
  - `FeelUI` retail aura rendering
- Confirmed current gaps:
  - party aura profile layout values are not fully wired like player/target
  - harmful dispellable debuffs can fall through when `RAID_PLAYER_DISPELLABLE` timing/classification data is unstable
  - party frame has no dedicated dispellable-debuff glow, only aura border coloring and target highlight

Why:
- The current party aura path is still partly layout-static and under-modeled compared to the newer retail-safe player/target work.
- Dispellable harmful auras need a more stable fallback path than timing-only checks.

Testing:
1. `/reload`
2. Apply a dispellable debuff to a party member and confirm the debuff stays visible.
3. Verify the party frame glow color matches the debuff type.
4. Check new `/az -> Unit Frames -> Party Frames` aura settings update the live layout.

Request:
- Revert the target-frame helper migration after confirming the latest mismatch likely comes from the test menu preview path rather than live target rendering.

Applied:
- Reverted the recent target-only helper migration in:
  - `Components/UnitFrames/Units/Target.lua`
- Restored the target frame's local health fake-fill helpers for:
  - reversed fill texcoords
  - hidden native health visuals
  - `UnitHealthPercent(..., true, CurveConstants.ZeroToOne)` sampling and fake-fill application

Why:
- Live testing indicates the real target frame is behaving correctly and the wrong fill is likely isolated to the `/aztest` preview presenter.
- Reverting the target-side helper migration removes an unnecessary variable while the preview/test path is investigated.

Testing:
1. `luac -p 'Components/UnitFrames/Units/Target.lua'`
2. `/reload`
3. Compare live target behavior against `/aztest` preview behavior to confirm only the preview path still diverges.

Request:
- Touch up `/az` so the options read more clearly and keep related settings grouped together.

Applied:
- Cleaned wording and section labels in:
  - `Options/OptionsPages/Auras.lua`
  - `Options/OptionsPages/UnitFrames.lua`
- Reframed several labels to be more outcome-based instead of implementation-based.
- Added clearer section headers separating:
  - show / hide behavior
  - layout / direction
  - what to show
  - display / highlighting

Why:
- The options were functional but some of the denser pages still read like maintainer settings.
- This pass improves scanability and makes it clearer what belongs to the top-right aura header versus unit-frame aura rows.

Testing:
1. `luac -p 'Options/OptionsPages/Auras.lua'`
2. `luac -p 'Options/OptionsPages/UnitFrames.lua'`
3. `/reload`
4. Open `/az` and verify the Player, Party Frames, and Aura Header pages read more cleanly.

Request:
- Keep player-frame aura settings highly customizable, but hide the deeper category toggles behind a single advanced switch so the default view stays user-friendly.

Applied:
- Added `playerAuraShowAdvancedCategories` default in:
  - `Components/UnitFrames/Units/Player.lua`
- Added `Show Advanced Aura Categories` in:
  - `Options/OptionsPages/UnitFrames.lua`
- Hid player-frame aura sub-category toggles unless:
  - custom player aura mode is active
  - advanced categories is enabled
  - the relevant parent category is enabled

Why:
- The detailed player aura categories were useful, but too noisy in the default custom view.
- This keeps the simple layer readable while still allowing deeper tuning for power users.

Testing:
1. `luac -p 'Components/UnitFrames/Units/Player.lua'`
2. `luac -p 'Options/OptionsPages/UnitFrames.lua'`
3. `/reload`
4. Open `/az -> Unit Frames -> Player`
5. Turn off stock behavior and verify only the broad custom toggles are shown at first.
6. Enable `Show Advanced Aura Categories` and confirm the deeper sub-category toggles appear under the enabled parent groups.

Request:
- Clean up the Party Frames options in `/az`; the current section feels messy.

Applied:
- Reorganized the Party Frames aura block in:
  - `Options/OptionsPages/UnitFrames.lua`
- Separated the party aura settings into:
  - stock/custom mode
  - what to show
  - layout & highlighting
- Moved size/growth/glow controls out of the middle of the filtering toggles.

Why:
- The previous order mixed layout controls into the middle of the filter controls, which made the page harder to scan.
- This pass keeps the same settings and behavior, but groups them by user intent.

Testing:
1. `luac -p 'Options/OptionsPages/UnitFrames.lua'`
2. `/reload`
3. Open `/az -> Unit Frames -> Party Frames`
4. Confirm the aura section now reads in a cleaner order:
   - stock/custom mode
   - what to show
   - layout & highlighting

Request:
- Class power click-through blocks correctly on Demon Hunter, but not reliably on Paladin.

Applied:
- Reworked the shared class-power click blocker in:
  - `Components/UnitFrames/Units/PlayerClassPower.lua`
- The blocker no longer sizes itself from the raw `ClassPower` frame rectangle alone.
- It now derives its bounds from the live shown class-power points, including their larger backdrop/slot art.
- Added a blocker resync after class-power layout updates and on class-power `OnSizeChanged`.

Why:
- Paladin Holy Power uses the shared `ComboPoints` layout, while Demon Hunter uses `SoulFragmentsPoints`.
- The old blocker only tracked the container frame box, not the actual visible point footprint.
- That made click blocking inconsistent across class layouts even though the click-through setting itself was shared.

Testing:
1. `luac -p 'Components/UnitFrames/Units/PlayerClassPower.lua'`
2. `/reload`
3. On a Paladin, disable `Class Power Click-Through` in `/az -> Unit Frames`.
4. Verify the full visible Holy Power area blocks clicks.
5. Re-enable click-through and verify clicks pass through again.
6. Recheck Demon Hunter Soul Fragments to confirm the shared blocker still behaves correctly.

Follow-up:
- The first blocker pass still relied on relative layout bounds and did not fully fix Paladin Holy Power coverage.

Applied:
- Reworked the blocker bounds again in:
  - `Components/UnitFrames/Units/PlayerClassPower.lua`
- The blocker now derives its size from live screen-space bounds (`GetLeft/GetRight/GetBottom/GetTop`) of the shown class-power points and their art, then anchors directly to `UIParent`.

Why:
- The original fix still depended on relative layout coordinates.
- Anchoring the top-level blocker from actual rendered bounds is more reliable for the Paladin Holy Power layout, which can drift from the raw container rectangle.

Testing:
1. `luac -p 'Components/UnitFrames/Units/PlayerClassPower.lua'`
2. `/reload`
3. On a Paladin, disable `Class Power Click-Through`.
4. Verify the entire visible Holy Power cluster now blocks clicks consistently.
5. Toggle click-through back on and recheck that clicks pass through.

2026-03-21

Request:
- New interrupt-readiness castbar coloring triggered a WoW 12 secret-boolean compare in `Components/UnitFrames/Functions.lua`.
- The user wants the new yellow/gray/red interrupt-state visuals on nameplate castbars only, not the target castbar.

Applied:
- Hardened `GetInterruptCastVisualState(...)` in `Components/UnitFrames/Functions.lua` so secret or non-boolean readiness values are discarded before addon-side comparisons.
- Removed the injected interrupt-readiness recoloring path from `Components/UnitFrames/Units/Target.lua`.
- Restored the target castbar's local visual handling for the native timer path while keeping the nameplate castbar interrupt-state visuals intact.

Why:
- WoW 12 secret booleans cannot be compared by addon code, even against literal `true` or `false`.
- Target-castbar recoloring was outside the requested scope and increased the chance of secret-value regressions on a more complex frame.

Testing:
1. `luac -p 'Components/UnitFrames/Functions.lua'`
2. `luac -p 'Components/UnitFrames/Units/Target.lua'`
3. `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
4. `/reload`
5. Verify nameplate castbars still show yellow for interrupt-ready, red for interruptible but on cooldown, and gray for non-interruptible casts.
6. Verify the target castbar no longer uses the interrupt-state palette and no longer throws the secret compare error from `Functions.lua`.

2026-03-21

Request:
- Enemy nameplate castbars still read as yellow regardless of interrupt availability.
- Nameplate castbars need a clearer interrupt-availability color model as the first step toward the broader Kickit-style feature set.

Applied:
- Extended the shared interrupt helper in `Components/UnitFrames/Functions.lua` to read both the primary and secondary interrupt spell IDs from the existing known-interrupt cache.
- Replaced the old `ready` / `cooldown` cast state model with explicit nameplate-safe states:
  - `primary-ready`
  - `secondary-ready`
  - `unavailable`
  - `locked`
- Assigned distinct castbar colors for those states:
  - primary ready = green
  - secondary ready = purple
  - neither available = red
  - not interruptible = gray
- Updated `Components/UnitFrames/Units/NamePlates.lua` text coloring to follow the same states as the castbar fill color.

Why:
- The previous implementation only checked the first known interrupt spell, so it could not represent the "primary unavailable, secondary available" case at all.
- The previous nameplate fallback color and the old `ready` color were both yellow-toned, which made enemy castbars read as "always yellow" even when the state logic was otherwise falling back.
- Using the existing `KnownInterruptSpells[1]` / `[2]` cache keeps the first pass small and local while moving the visuals closer to the planned Kickit-style model.

Testing:
1. `luac -p 'Components/UnitFrames/Functions.lua'`
2. `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
3. `/reload`
4. On a class with a secondary interrupt in the cache, verify enemy nameplate castbars show:
   - green when the primary interrupt is ready
   - purple when the primary interrupt is unavailable but the secondary is ready
   - red when neither tracked interrupt is available
   - gray when the cast is not interruptible
5. Recheck a class without a secondary interrupt and verify it still falls back cleanly between green, red, and gray.

2026-03-21

Request:
- Nameplate scale appears different inside delves versus open world.
- Add a separate default baseline for delves and for open world.

2026-03-21

Request:
- Soft-target and target scale still feel way out of whack.
- Recheck the target scale defaults and the active runtime branches before adding more environment-specific presets.

Applied:
- Reset the shipped target-scale defaults in `Components/UnitFrames/Units/NamePlates.lua` back to neutral for both friendly and enemy plates.
- Rebased the target slider normalization in `Options/OptionsPages/Nameplates.lua` so `100%` now means no extra target-size change again.
- Added a one-time migration that only rewrites the recently promoted target defaults (`-0.65` friendly, `0.2` enemy) back to neutral, while leaving unrelated custom values alone.

Why:
- The current runtime path only scales actual targets, not soft targets. That made the promoted target defaults feel exaggerated immediately, because soft-targeted plates stayed at baseline while targeted plates jumped to a very different branch.
- Using the recent promoted values as the internal `100%` baseline worked poorly for target sizing specifically. A target modifier reads more clearly when `100%` means "no extra target scaling" and the user moves away from there intentionally.

Testing:
1. `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
2. `luac -p 'Options/OptionsPages/Nameplates.lua'`
3. `/reload`
4. Compare the same unit untargeted, soft-targeted, and targeted.
5. Verify targeting no longer causes the large shrink/grow jump that was present before.
6. Recheck the target sliders in `/az -> Nameplates -> Size` and confirm `100%` now behaves as true neutral target scaling.

2026-03-21

Request:
- Soft-target still does not behave correctly unless Blizzard scale is enabled.
- Changing Blizzard nameplate size while using the Blizzard-scale mode makes AzeriteUI plates drift upward instead of just feeling correctly sized.

Applied:
- In `Components/UnitFrames/Units/NamePlates.lua`, `isSoftTarget` is now derived directly from the live `softenemy` / `softinteract` matches during full updates and soft-target events.
- Removed the redundant `ApplyNamePlateScale(self)` call from the soft-target event branches, because soft target is not part of the actual scale math.
- Fixed the `checkSoftTarget()` timer bug where the retained soft-enemy path initialized `EnemyDead` to `true`, which made the "keep current soft target" branch fail unless the plate was a soft-interact target.

Why:
- Soft-target visibility and highlight behavior was split across two paths: event-driven `isSoftEnemy` / `isSoftInteract`, and timer-driven `isSoftTarget`.
- The timer retention bug made the synthetic `isSoftTarget` state unreliable, so name visibility and hover-like elements could drop out even when the soft target was still valid.
- Because the soft-target events were also calling the target-scale refresh path even though scale does not use soft-target state, the problem was easy to misread as a pure scaling issue.

Testing:
1. `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
2. `/reload`
3. With Blizzard scale disabled, soft-target enemies and interactables in the open world.
4. Verify names/highlights now respond consistently without needing the Blizzard-scale mode.
5. Recheck whether Blizzard size changes are still required to make soft-target feedback visible. If that part still reproduces, the remaining issue is likely the Blizzard `SoftTargetFrame` anchor/art path rather than our synthetic soft-target state.

2026-03-21

Request:
- Soft-target is still scaled too high with AzeriteUI scaling.
- Soft-target should be the same size as a normal target.

2026-03-21

Request:
- Soft-target is still way too big after the latest scaling passes.
- Add a proper nameplate scale debug path so the live soft-target plate can be inspected instead of continuing to guess at the source.

Applied:
- Added `NamePlatesMod.GetDebugPlateScaleBreakdown(frame)` in `Components/UnitFrames/Units/NamePlates.lua`.
- Added `/azdebug scale nameplates [unit]` in `Core/Debugging.lua`.
- The debug dump prints:
  - live target / soft-target flags
  - hostile / friendly-name-only state
  - base, overall, relation, and target-delta multipliers
  - computed frame scale versus actual frame/parent effective scales
  - Blizzard plate and `SoftTargetFrame` scale/size info

Why:
- The remaining soft-target issue may be in the computed plate scale, the Blizzard parent plate scale, or the Blizzard `SoftTargetFrame` child widget.
- Adding a focused dump is the fastest way to distinguish those cases without piling on more speculative scale changes.

Testing:
1. `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
2. `luac -p 'Core/Debugging.lua'`
3. `/reload`
4. Soft-target the problematic unit.
5. Run `/azdebug scale nameplates auto`
6. Capture the printed output so the remaining oversize source can be narrowed to the custom frame path or the Blizzard soft-target widget path.

2026-03-21

Request:
- Live debug output shows the soft-interact plate itself is oversized under AzeriteUI scaling.
- Friendly NPCs should not inherit the same large baseline as friendly players.

Applied:
- Added a separate `friendlyNPCScale` profile/default path in `Components/UnitFrames/Units/NamePlates.lua`.
- Friendly assistable NPCs now use `friendlyNPCScale` instead of the larger `friendlyScale` player-friendly baseline.
- Added a matching `Friendly NPC size (%)` slider to `/az -> Nameplates -> Size` in `Options/OptionsPages/Nameplates.lua`.
- Extended the nameplate debug dump to print whether the inspected plate is being treated as a friendly NPC.

Why:
- The live dump showed the oversized soft-interact plate was not a Blizzard widget issue:
  - `targetDelta = 0`
  - `softFrame scale = 1`
  - but `relation = 1.95`
  - which produced `computed = 2.77`
- That means the plate was simply inheriting the friendly/player baseline intended for much larger friendly-player plates.
- Splitting friendly NPCs off from friendly players is the narrowest fix that addresses the actual source without disturbing enemy scaling or the player-name-only path.

Testing:
1. `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
2. `luac -p 'Options/OptionsPages/Nameplates.lua'`
3. `/reload`
4. Soft-target the same friendly/interact NPC again.
5. Run `/azdebug scale nameplates auto` and confirm the dump now reports `friendlyNPC = true` with a much lower `relation` multiplier.
6. Adjust `/az -> Nameplates -> Size -> Friendly NPC size (%)` if you want that NPC baseline a bit higher or lower after the split.

2026-03-21

Request:
- Add a player-facing explanation for the enemy nameplate interrupt colors in the addon or CurseForge description so users know how to interpret them.

Applied:
- Added a short interrupt-color legend to `/az -> Nameplates -> Advanced` in `Options/OptionsPages/Nameplates.lua`.
- Added the same legend to the `README.md` FAQ so it can also be reused in the CurseForge project description.
- Updated the README addon version badge from the old beta label to `v5.3.17-JuNNeZ`.

Why:
- The color behavior is useful, but it is not self-explanatory unless players already know the internal primary/secondary interrupt logic.
- Putting the legend in both the addon options and the public README covers in-game discovery and external project-page description without inventing a separate documentation path.

Testing:
1. `luac -p 'Options/OptionsPages/Nameplates.lua'`
2. `/reload`
3. Open `/az -> Nameplates -> Advanced` and confirm the interrupt legend reads clearly.
4. Reuse the README FAQ text for the CurseForge description if you want the same explanation on the project page.

Applied:
- Updated `GetEffectivePlateScale()` in `Components/UnitFrames/Units/NamePlates.lua` so soft-target uses the same target-size branch as a real target.
- Reapplied scale immediately from the soft-target enter/leave helpers and the soft-target event handlers so the new target-like rule updates live.

Reference:
- Local `Platynator` uses the same model in `Display/Nameplate.lua`, where `isTarget` includes `UnitIsUnit("softenemy", self.unit)` and `UnitIsUnit("softfriend", self.unit)`.

Why:
- The previous pass fixed soft-target state reliability, but the actual scale math still only treated `self.isTarget` as target-sized.
- That left soft-target in an in-between visual state: highlighted like a special target, but not scaled by the same rule as the real target branch.
- Matching the target-size branch directly is also consistent with the user's request and with the local Platynator implementation.

Testing:
1. `luac -p 'Components/UnitFrames/Units/NamePlates.lua'`
2. `/reload`
3. Soft-target and then hard-target the same enemy/friendly unit.
4. Verify both use the same size now.
5. Recheck Blizzard-scale mode only after that baseline is confirmed; if there is still drift there, the remaining issue is separate from soft-target sizing itself.

2026-03-21

Request:
- BugSack shows current-retail secret-value warnings in `Blizzard_EditMode`, `Blizzard_EncounterWarnings`, `SecureUtil`, and `Blizzard_DamageMeter`.
- The common symptom is secure Blizzard code reporting `tainted by 'AzeriteUI5_JuNNeZ_Edition'` while comparing or doing arithmetic on secret numbers.

Applied:
- Removed the remaining direct `HighlightSystem` / `ClearHighlight` method replacement from the live Blizzard mirror-timer suppression path in `Components/Misc/MirrorTimers.lua`.
- Removed the stale Blizzard-frame highlight-method replacement blocks from `Components/ActionBars/Elements/EncounterBar.lua`, `Components/ActionBars/Elements/MicroMenu.lua`, `Components/Misc/Minimap.lua`, and `Components/Misc/VehicleSeat.lua`.
- Changed `Components/Misc/Tooltips.lua` so the tooltip highlight path no longer swaps `GameTooltipDefaultContainer` methods to `ns.Noop`.

Why:
- The repo already documents this exact taint class: writing addon functions onto Blizzard-owned frame tables can make later secure/secret-value code paths execute as addon-tainted, even when the eventual stack is in an unrelated system.
- The reported failures all happen inside Blizzard-owned secure/UI systems (`EditMode`, `EncounterWarnings`, `SecureUtil`, `DamageMeter`), which is consistent with a broad taint leak rather than a bug in just one target frame path.
- `MirrorTimers.lua` was still doing that write unconditionally, and the other retail UI modules had the same pattern preserved in stale guard branches. Removing those writes is the narrowest fix that matches the known taint mechanism.

Testing:
1. `luac -p 'Components/Misc/MirrorTimers.lua'`
2. `luac -p 'Components/Misc/Tooltips.lua'`
3. `luac -p 'Components/ActionBars/Elements/EncounterBar.lua'`
4. `luac -p 'Components/ActionBars/Elements/MicroMenu.lua'`
5. `luac -p 'Components/Misc/Minimap.lua'`
6. `luac -p 'Components/Misc/VehicleSeat.lua'`
7. `/reload`
8. `/buggrabber reset`
9. Open and close Edit Mode, then save/revert a layout once.
10. Recheck the previous `EncounterWarnings`, `SecureUtil`, and `DamageMeter` stacks in a fresh session.
