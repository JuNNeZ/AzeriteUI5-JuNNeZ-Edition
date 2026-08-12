# WoW 12.1 Update Tracking

Last updated: 2026-08-12

This page collects the newest verified WoW retail update details, addon-facing API changes, current CurseForge status, and the first investigation targets for AzeriteUI.

## External snapshot

- **Newest live retail update:** _Midnight: Curse of Ula'tek_ (`12.1.0`).
- **Latest live build found:** `69273`.
- **Latest documented TOC/interface bump:** `120100`.
- **Current repo/public addon support:** [AzeriteUI5_JuNNeZ_Edition.toc](../AzeriteUI5_JuNNeZ_Edition.toc) still tops out at `120007`, and [CHANGELOG.md](../CHANGELOG.md) currently ends at `5.3.76-JuNNeZ` with WoW `12.0.7` support.

### Source links

- Blizzard update overview: https://worldofwarcraft.blizzard.com/en-us/news/24293281/
- Blizzard UI update article: https://worldofwarcraft.blizzard.com/en-us/news/24294064/
- Townlong-Yak build browser (`69273`): https://www.townlong-yak.com/framexml/69273
- Warcraft Wiki addon/API notes: https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes

## New addon/API risk areas in 12.1

### 1. Aura APIs are the biggest risk

The 12.1 addon notes describe a major aura security change:

- when auras are secret, `UnitAura`-style APIs and `C_UnitAuras` results can now return **secrets or nil**
- addon code can no longer safely assume it can enumerate or inspect aura payloads during combat, encounters, Mythic+, or PvP
- Blizzard added **AuraContainer** and **AuraButton** as the intended safer presentation path for custom aura displays
- Blizzard also added **Private Script Objects**, a **Forbidden Partition**, and **Forbidden Aspects**, which further restrict addon hooks and script bindings around aura objects

This is the highest-priority compatibility audit for AzeriteUI because the addon has a large custom aura pipeline:

- [Components/Auras/Auras.lua](../Components/Auras/Auras.lua)
- [Components/UnitFrames/Auras/AuraData.lua](../Components/UnitFrames/Auras/AuraData.lua)
- [Components/UnitFrames/Auras/AuraFilters.lua](../Components/UnitFrames/Auras/AuraFilters.lua)
- [Components/UnitFrames/Auras/AuraStyling.lua](../Components/UnitFrames/Auras/AuraStyling.lua)
- [Libs/oUF/elements/auras.lua](../Libs/oUF/elements/auras.lua)

### 2. Blizzard unit-frame and raid-frame changes need regression testing

Blizzard's 12.1 UI update adds or changes:

- action-bar / cooldown-manager ping support
- own-frame health and healer mana pings
- healer configuration/hiding of raid-frame buffs

This increases the odds of interaction changes in:

- [Components/UnitFrames/Units/Party.lua](../Components/UnitFrames/Units/Party.lua)
- [Components/UnitFrames/Units/Raid5.lua](../Components/UnitFrames/Units/Raid5.lua)
- [Components/UnitFrames/Units/Raid25.lua](../Components/UnitFrames/Units/Raid25.lua)
- [Components/UnitFrames/Units/Raid40.lua](../Components/UnitFrames/Units/Raid40.lua)
- [Core/Compatibility.lua](../Core/Compatibility.lua)

### 3. Action-bar and cooldown behavior should be smoke-tested

Blizzard also expanded the Cooldown Manager to track:

- trinkets
- potions
- racial cooldowns and durations

That does not automatically break AzeriteUI, but it is worth retesting these areas because Blizzard's default action/cooldown flows often change around major UI updates:

- [Components/ActionBars/Elements/ActionBars.lua](../Components/ActionBars/Elements/ActionBars.lua)
- [Components/ActionBars/Prototypes/ActionBar.lua](../Components/ActionBars/Prototypes/ActionBar.lua)
- [Core/Widgets/Cooldowns.lua](../Core/Widgets/Cooldowns.lua)

### 4. New content-update widgets may affect custom frame placement

Curse of Ula'tek introduces new zone/season systems and updated UI surfaces. AzeriteUI should smoke-test any custom widget anchoring or suppression logic in:

- [Components/Misc/UIWidgetTopCenter.lua](../Components/Misc/UIWidgetTopCenter.lua)
- [Components/Misc/UIWidgetBelowMinimap.lua](../Components/Misc/UIWidgetBelowMinimap.lua)
- [Components/Misc/TrackerWoW11.lua](../Components/Misc/TrackerWoW11.lua)

## CurseForge status and page issues

Using the public project data for project `1477618`:

- the latest public CurseForge file is still **`v5.3.76-JuNNeZ`** from **2026-07-17**
- the in-worktree release has now been bumped to **`v5.3.77-JuNNeZ`** to cover the 12.1 aura/action-bar fixes
- that file advertises support through **WoW `12.0.7`**
- there is no verified public `12.1` release visible yet

The public CurseForge page also appears to have stale metadata in the description payload:

- the badge text still references **Interface `120000`**
- the badge text still references addon version **`v5.3.46-JuNNeZ`**

So the current public CurseForge presentation is behind both the repo and the newest live game build.

### Comments/issues visibility

- the public comments route exists, but public scraping does **not** reliably expose the comment bodies
- a comments count is visible from page metadata/chrome, but unauthenticated fetches do not provide dependable report text for triage
- no usable public CurseForge issues tracker was verified for this project

**Actionable takeaway:** we still need a **manual signed-in CurseForge review** to capture user-reported 12.1 regressions that are not in this repository yet.

## Existing internal watch items to re-test on 12.1

These are already documented in [CHANGELOG.md](../CHANGELOG.md) and should be re-verified on 12.1 before new fixes start:

- **Story-mode companion right-click menu limitation** - Blizzard secure menu limitation, not known to be addon-fixable
- **Hold-to-cast restoration during combat after mounted temporary-bar transitions** - documented secure limitation
- **`ActionButtonUseKeyDown` settings noise** - settings-side BugSack noise was previously unresolved

Older watch items that should be treated as **retest targets**, not automatically assumed to be current regressions:

- Edit Mode taint behavior
- mana orb display edge cases
- target castbar crop/fill edge cases

## First-pass fix plan

1. **Bump support metadata after smoke test**
   - update [AzeriteUI5_JuNNeZ_Edition.toc](../AzeriteUI5_JuNNeZ_Edition.toc) to include `120100`
   - update README/wiki badges and release metadata to stop advertising `120000`

2. **Audit all aura reads before touching feature code**
   - search for direct `UnitAura`, `C_UnitAuras`, instance-ID iteration, and assumptions that aura lists are enumerable
   - prioritize the files listed in the aura section above

3. **Run an in-game 12.1 regression matrix**
   - player auras
   - target auras
   - party/raid auras
   - nameplate auras
   - raid-frame buff visibility
   - action-bar pings
   - cooldown manager interactions
   - top-center/minimap widgets in new content

4. **Review signed-in CurseForge comments manually**
   - copy unresolved user reports into [FixLog.md](../FixLog.md)
   - separate confirmed Blizzard limitations from addon-owned bugs

5. **Only then decide whether AzeriteUI needs**
   - a surgical 12.1 compatibility release
   - a broader aura-system refactor
   - or a mixed approach with temporary guards plus a later AuraContainer migration

## Recommended immediate audit order

1. [Components/UnitFrames/Auras/](../Components/UnitFrames/Auras)
2. [Components/Auras/](../Components/Auras)
3. [Libs/oUF/elements/auras.lua](../Libs/oUF/elements/auras.lua)
4. [Core/Compatibility.lua](../Core/Compatibility.lua)
5. [Components/UnitFrames/Units/Party.lua](../Components/UnitFrames/Units/Party.lua), [Components/UnitFrames/Units/Raid5.lua](../Components/UnitFrames/Units/Raid5.lua), [Components/UnitFrames/Units/Raid25.lua](../Components/UnitFrames/Units/Raid25.lua), [Components/UnitFrames/Units/Raid40.lua](../Components/UnitFrames/Units/Raid40.lua)
6. [Components/ActionBars/](../Components/ActionBars)
7. [Core/Widgets/Cooldowns.lua](../Core/Widgets/Cooldowns.lua)
8. [Components/Misc/UIWidgetTopCenter.lua](../Components/Misc/UIWidgetTopCenter.lua) and [Components/Misc/UIWidgetBelowMinimap.lua](../Components/Misc/UIWidgetBelowMinimap.lua)
