
# Changelog

## A note on WoW 12.1 addon development

Retail 12.1 protects more combat, aura, cooldown, and unit data as secret values. Addons can often display those values only by handing them directly to Blizzard-owned widgets instead of reading or formatting them, which is why one visual layer may keep working while related text or logic disappears; safe fixes increasingly require narrow ownership boundaries between Blizzard and other addons.

Release note rule: each version entry must include only what changed since the previous release (delta-only).
Do not repeat older items from prior versions in newer entries.


## Unreleased


## 5.4.0-JuNNeZ (2026-09-03) - Reclaimed Art, Working Smoothing, and a Cleared Audit Backlog

The version family moves from 5.3 to 5.4 because this release is not a patch. A full codebase
audit on 2026-08-26 produced a backlog of eight items; all of them are closed here. Along the way
three things turned out to have never worked at all rather than to have broken recently - bar
smoothing, the development mode toggle, and roughly a fifth of the artwork the addon has been
shipping since the fork.

### Highlights

- **The mana orb has its glass dome.** The player frame has been creating a glass texture for the
  orb on every single login and hiding it again, because the layout never carried a texture for it
  to draw. It draws now. This is a specular highlight over the orb rather than a change to its
  shape, and it is one toggle away if you prefer the old look.
- **The mana orb ships four fill artworks and you can pick one.** Clouds is what you have always
  had. Galaxy, Moon and Sphere have been sitting in the addon's art folder, unreachable, since the
  fork. Two further decorative layers came with them - a heavy **Rim** at the orb's edge and a
  sculpted **Pedestal** beneath it - and both default to off.
- **Health and power bars can finally animate.** The function that turns bar smoothing on has been
  discarding its argument since it was written: it asked the game for an interpolation mode that
  does not exist, got nothing back, and quietly fell through to "no smoothing" on both branches.
  Two bars asked for smoothing and never got it, and both now interpolate: the **player health
  bar** and the **target power bar**. Every other bar in the addon explicitly asks for immediate
  updates and is unchanged.
- **Boss castbars use boss castbar art.** With mirrored castbar art switched on, a boss target drew
  the *Seasoned* tier's bar - a different texture at a different height from the health bar
  underneath it - because the mirror was hardcoded to one tier's name. Each tier now names its own.
- **Raid target icons sit in the right place on 40-player raid frames.** The Raid (25) frames move
  the raid target marker to the left of the leader and master-looter icons. The Raid (40) frames
  never did, because the function that does it only ever existed in one of the two nearly identical
  files. Mark a target in a 40 and it now matches a 25.
- **The cog wheel lights up when you hover it.** It was the only button in the addon with no
  mouseover feedback at all, and the lit version of its artwork has been shipping unused the whole
  time.
- **Optional badges for ordinary, level-?? and dead targets.** The classification badge set that
  ships includes a silver badge, a lit skull and a spent skull that nothing has ever drawn. Off by
  default, because it puts a badge on units that normally have none.
- **`/devmode` actually turns on development mode.** The experimental module gated itself on an
  unpackaged git checkout *and* the dev mode setting, and the first half is never true in a build
  anyone can download. `/serial` and `/toggleblips` now work from an installed copy once dev mode
  is on, which is what the setting always claimed to do.
- **Two option descriptions came back.** The nameplate interrupt-colour legend and the Class Power
  Click-Through description were removed from all ten locale files by an unreleased cleanup pass,
  which would have rendered them as raw English key text in every language. Both are restored,
  byte-identical to their previous translations.
- **The public documentation has been rewritten.** The README and all twelve wiki pages predated
  roughly forty-five releases. They now describe the current addon, including everything shipped
  since April: group frame sorting, per-context player toggles, party and raid specialization
  icons, the micro menu toggle, assisted combat highlight, ability pings and the target castbar
  rework. Several documented facts were simply wrong - `/azdebug` does not require development
  mode, the Player Alternate frame does not require development mode, the interface version was a
  release behind, and six slash commands were missing entirely.

### Access

- `/azerite` -> Unit Frames -> Player -> **Mana Orb Texture** (Clouds, Galaxy, Moon, Sphere)
- `/azerite` -> Unit Frames -> Player -> **Mana Orb Glass** (new, on by default)
- `/azerite` -> Unit Frames -> Player -> **Mana Orb Rim** / **Mana Orb Pedestal** (new, off by default)
- `/azerite` -> Unit Frames -> Target -> **Extended Classification Badges** (new, off by default)
- `/devmode` now reaches `/serial` and `/toggleblips` from an installed copy

### Internal

- `DisableSmoothing` resolves the enabled branch to `Enum.StatusBarInterpolation.ExponentialEaseOut`,
  with a literal `1` fallback mirroring the existing literal `0`. There is no `Linear` member on
  12.1 - the enum has only `Immediate = 0` and `ExponentialEaseOut = 1` - so reading it returned nil,
  fell back to `immediate`, and made the assignment `disabled and 0 or 0`. `Target.lua` read the
  same missing member for `power.smoothing`.
- `Raid40.lua` gains `LeaderIndicator_PostUpdate`, copied verbatim from `Raid25.lua` and assigned at
  the matching point in `style()`. The diff between the two files drops from 41 hunks to 39, with no
  `Leader` difference remaining.
- `Target.lua` reads `db.HealthBarMirrorTexture` instead of a hardcoded `hp_cap_bar_mirror`. The
  Seasoned and Boss tiers declare their own; the SaiyaRatt variant declares `false` explicitly,
  because `ns:Merge` only fills keys a variant leaves nil and would otherwise have paired a cap
  mirror with a critter bar.
- Unreferenced art went from 28 files of 135 to zero, with nothing deleted. 26 were wired into
  rendering code or published through `Core/SharedMedia.lua`; the last two, which have no home,
  moved to a new gitignored `Assets_Moot/` that reaches neither build. Research, measurements and
  per-asset reasoning are in `Docs/RESEARCH_Optional_Deletions_2026-09-02.md`. The short version is
  that 24 of the 28 ship unreferenced in upstream AzeriteUI 5 as well and were never referenced in
  its 1596-commit history, so there was no upstream implementation to restore and placement had to
  come from the art, the naming, and what the code was already shaped to accept.
- `ApplyDiabolicManaOrbArt` ended with unconditional `Hide()` calls on the orb's `Glass` and
  `Artwork` textures. Both now route through one `ApplyManaOrbDecoration` helper alongside a new
  `Rim` layer, driven by `ManaOrbGlass*` / `ManaOrbRim*` / `ManaOrbArtwork*` layout keys on all
  three player style tiers. Sizes come from each file's measured content fraction, not its canvas:
  `orb-glass` frames its circle at 0.594 of canvas and `orb-border` at 0.656, so matching the orb's
  103px fill needs 173 and 157. The pedestal also moved from `OVERLAY, 1` on the case frame to
  `BACKGROUND, -3` on the orb frame, since drawn above the wooden surround it covered the orb.
- `SetManaOrbFillTexture` resolves the orb fill from a profile setting and falls back to the layout
  as written. LibOrb takes one path per animated layer and the layout has always passed the same
  texture twice; the existing texcoord flip on layer two still follows both call sites, so the
  paired layers keep animating against each other.
- `Classification_Update` gained generic, unknown-level and dead branches behind one profile toggle.
  The badge refreshes on the frame's normal update cycle rather than on health ticks, so a target
  dying while already selected can hold its old badge until the next update; registering
  `UNIT_HEALTH` on that frame was not judged worth it for an opt-in decoration.
- `Layouts/Data/ActionButton.lua` gained `ButtonAssistedHighlightTexture`. The assisted-combat
  highlight and the proc glow were tinted from the same coloured ring, and `SetVertexColor`
  multiplies, so only a white base lands on the intended hue.
- `GetSpecialization` migrated to `C_SpecializationInfo.GetSpecialization` across six files as a
  file-local shadow, so the existing call sites and their `type()` guards keep working whichever the
  client exposes. Twelve sites, not the nine the audit listed - `GroupSpecCache.lua` arrived after
  that list was drawn, and its guard pairs `GetSpecialization` with `GetSpecializationInfo`, so both
  moved together.
- `GetCVar` / `GetCVarBool` migrated to `C_CVar.*` the same way in nine files. `SetCVar` needed more
  than a shadow because `C_CVar.SetCVar` expects a string and several call sites passed numbers:
  `WorldMap.lua` and `Tutorials.lua` got a local `SetCVarValue` helper, and `NamePlates.lua`'s six
  bare calls now route through `SetCVarIfSupported`, the guarded string-converting helper that
  already existed in that file.
- Removed the `tocversion >= 110007` block in `Compatibility.lua` that recaptured `InCombatLockdown`,
  `issecurevariable`, `issecure`, `hooksecurefunc`, `RegisterStateDriver` and `UnregisterStateDriver`
  into `_G`. The 11.0.7 restriction never shipped, all six exist on 12.1, and the block's `rawget`
  guards were all true, so it wrote nothing. Re-publishing captured secure functions is the shape of
  thing that causes taint problems if it ever does fire.
- Removed the Cataclysm Classic branches (`or (tocversion >= 40400 and tocversion < 50000)`) at three
  sites and the four "Classics" shims for `UnitEffectiveLevel`, `IsXPUserDisabled`,
  `UnitHasVehicleUI` and `GetTimeToWellRested`. All four exist on retail, so none of the
  `if (not _G.X)` guards ever fired; the addon's calls to all four now reach Blizzard's own
  functions. `Compatibility.lua` is 54 lines shorter.
- `Core/Experimental.lua` gates on a local `IsDevModeEnabled()` testing
  `ns.IsDevelopment or ns.db.global.enableDevelopmentMode`, matching the idiom `Core/Debugging.lua`
  already used. `ToggleUI` stays unregistered and now says why in a comment: it switches between
  AzeriteUI and DiabolicUI, and this build has no relationship with DiabolicUI.
- `Durability.lua` no longer writes an unused `anyItemBroken` global. The bytecode `SETGLOBAL` scan
  is down to the three deliberate global writes in the whole addon.
- `Finalize.lua`'s metatable lock spelled the metafield `____metatable`, with four underscores, so
  it has never locked anything in this lineage. Corrected to `__metatable`. Verified that the only
  `setmetatable` on the addon namespace is AceAddon's, from `Core.lua`, which runs well before
  `Finalize.lua`.
- `Core/SharedMedia.lua` registered "Azerite Vehicle Exit Button" as `icon-exit-flight`; the file is
  `icon_exit_flight.tga`. `GetMedia` only formats a path and never checks the file exists, so that
  entry pointed at nothing. The addon's own use had the correct name.
- **Locale.** 124 dead `enUS` keys, the `Chat` orphan and a `zhCN`/`zhTW` aura-sorting orphan were
  removed from all ten files - 1,251 lines, pure deletions, so every surviving translation is
  byte-identical to what it was. That pass also removed two keys that are still referenced, both
  containing embedded `\n` sequences, which is the exact blind spot the audit had identified in its
  own key-extraction regex; the recount was redone with an index-based extractor but the deletion
  was not. Both restored. Ten new keys were added for the five new options and translated across all
  nine non-English locales. All ten files now hold 605 keys with zero missing, extra or duplicate,
  and every key is used.
- **Packaging.** `.pkgmeta`'s ignore list is now the blacklist mirror of `build-release.ps1`'s
  whitelist, so the CI-published zip and the locally built zip contain the same files. Seven tracked
  root entries were reaching the published zip that the local zip excluded. `build-release.ps1`
  parses `## Version:` out of the TOC and exits non-zero if it is missing, empty or an
  unsubstituted token, so the version has one home. `FixLog.md` is no longer tracked: the
  11,150-line internal debug log stays on the maintainer's disk and stops being published.

### Verification

All 167 addon Lua files parse. The bytecode global-write scan returns only the three deliberate
writes. Ten locale files hold 605 keys each with zero missing, extra or duplicate, and every
`L["..."]` lookup in the addon resolves. `Assets/` holds 133 files with an unreferenced count of
zero. Nothing here can be confirmed statically - see the in-client checklist in `Docs/TODO.md`.


## 5.3.90-JuNNeZ (2026-08-24) - Per-Context Player Toggles and Group Frame Sorting

### Highlights

- **Showing your own frame is now two separate settings** on both the Party frames and the 1-5 Raid frames: one for parties, one for raid groups. Hiding yourself in arena while keeping your frame in a five man dungeon was not possible before, because a single toggle covered both. Your existing choice carries over to both halves, so nothing changes until you split them yourself.
- **The 1-5 raid frames can now show your own frame in a party.** They only ever drew your group members there, never you, no matter what the setting said - the raid half of the same frames always drew you. Both halves answer to their own toggle now, and both default to showing you.
- **All four group frame families gained Sort By and Sort Direction**: by group, by role, by class, or by name. Nothing was configurable before.
- **Role sorting on the Raid (25) and Raid (40) frames now actually works.** Those frames have shipped with role sorting turned on for years and have been quietly ignoring it, because the setting named the main tank flag rather than the tank/healer/damage role, so nothing ever matched and the roster stayed in join order. **These frames will visibly reorder** the next time you are in a raid: tanks, then healers, then damage. Set Sort By to Group if you want the old order back.

### Access

- `/azerite` -> Unit Frames -> Party Frames -> **Show player in party** / **Show player in raid**
- `/azerite` -> Unit Frames -> Raid Frames (5) -> **Show player in party** / **Show player in raid**
- `/azerite` -> Unit Frames -> Party Frames, Raid Frames (5), (25) and (40) -> **Sort By** / **Sort Direction**

### Internal

- New `Components/UnitFrames/GroupSorting.lua` owns the four modes for both mechanisms. Real headers get `groupBy` / `groupingOrder` / `sortMethod` / `sortDir` attributes; the driver fed Raid (5) frames get an ordered token list instead, since none of those attributes reach them.
- `ROLE` is the main tank / main assist flag in `SecureGroupHeaders.lua`; `ASSIGNEDROLE` is TANK / HEALER / DAMAGER. Raid (25) and (40) paired the former with a `TANK,HEALER,DAMAGER` order, so every unit fell through to the nil-order branch and sorted by raid index. ElvUI spells the same mode `ASSIGNEDROLE`.
- The party header's name list branch ignores `groupBy` entirely, so hiding yourself in a raid would have silently dropped the sort with it. The list is now built in sorted order and read back with `sortMethod = "NAMELIST"`.
- `showPlayer` splits into `showPlayerInParty` / `showPlayerInRaid` in place on first read, rather than through `SETTINGS_VERSION`, which resets every profile wholesale.
- Both header families now refresh on `PLAYER_ROLES_ASSIGNED`. Blizzard re-sorts a group header on roster and name events only, so a plain role change left a role sorted header stale.


## 5.3.89-JuNNeZ (2026-08-24) - Hiding Your Own Frame in Raid Sized Groups

### Highlights

- The party frames' **Show player** toggle now works in raid groups as well. It only ever applied while you were in an actual party, so in the raid sizes you can set the party frames to appear in - arenas and battlegrounds included, since those put you in a raid group - your own frame came back no matter what the setting said. Blizzard's group header only consults that setting on party units, so the frames now pick their members by name in a raid instead.
- The **1-5 raid frames** gained the same toggle, which they never had. Turn it off and those frames carry the rest of your group without you, which is what you want in arena when your own frame is already the big health orb: two teammates to heal, and nothing else in the way.
- Both toggles follow the group as it changes. Joining, leaving, or being moved between raid subgroups rebuilds the frames, and anything that lands mid-fight is applied the moment you drop out of combat.

### Access

- `/azerite` -> Unit Frames -> Party Frames -> **Show player**
- `/azerite` -> Unit Frames -> Raid Frames (5) -> **Show player** (new, on by default, so nothing changes unless you turn it off)

### Internal

- `showPlayer` is a party-only attribute in `SecureGroupHeaders.lua`: `GetGroupHeaderType` reads it only on the PARTY branch, while the RAID branch walks `raid1` to `raid<N>` with no way to drop a single unit. `Party.lua` now routes both `groupFilter` and `nameList` through one helper and, in a raid with the option off, clears the filter and hands the header its own subgroup minus the player. The name list branch is unreachable while any group or role filter is set, so the two attributes have to move together.
- The 5 player frames are not a secure group header at all - five oUF frames on a `SecureHandlerStateTemplate`, each driven by its own unit attribute driver on a fixed `raid1`-`raid5` token. `GetRaidUnitIndexes` now builds those tokens and skips the player's own index, leaving the empty slots last so the visible frames stay flush against the anchor. Party tokens are left alone; they never included the player to begin with.
- `RaidFrame5Mod.OnEvent` called `UpdateHeader` on `PLAYER_REGEN_ENABLED`, which never touches the unit drivers, so a driver rebuild deferred out of combat was dropped. It calls `Update` now.

## 5.3.88-JuNNeZ (2026-08-22) - Ability Pings, Resource Callouts, and the Pet Bar Ping Error

### Highlights

- Pinging an ability on your action bars now works. It announces the spell or item along with its cooldown and whether you can afford it, the same callout Blizzard's own bars give. This had never worked on any AzeriteUI bar: the buttons claimed to be ping receivers but reported no action underneath, so the ping system quietly decided there was nothing to announce.
- Pinging your own unit frame now calls out your health and mana instead of only flagging where you are standing. This is the resource callout Blizzard puts on the player frame; every AzeriteUI frame was being treated as an ordinary unit frame, which has no notion of your own resources.
- Fixed an error from the pet bar that broke Blizzard's ability ping system. Pinging anywhere over the pet bar raised a Lua error and left pinging broken everywhere else on screen until reload. This is the same defect fixed on the stance bar in 5.3.87, which the pet bar shared and which the stance bar fix did not reach.
- Pings aimed past an empty slot on an action bar now reach the world instead of dying on the button. Empty buttons had been holding on to their ping receiver status rather than stepping aside as Blizzard's do.
- Holding the ping key over your own unit frame no longer opens the ping wheel, and gives you the health and mana callout instead. Blizzard offers the wheel only over the player portrait and the callout everywhere else on that frame; our player frame is all orb and crystal with no portrait, so the callout is the whole frame. The wheel is unchanged everywhere else, including over the world, your target, and other players' frames.

### Internal

- `LibActionButton-1.0-GE` gains `GetActionButtonInfo` on the generic, action, spell, item and toy prototypes, and clears the inherited `BaseActionButtonInfoMixin` stub off each button at creation the way it already cleared `HasAction`. The stub returns nil, and `PingableType_ActionButtonMixin:GetIsPingable` reads a nil result as "not pingable", so every button on every bar was unpingable while looking correctly configured. Bumped to minor 76.
- The library's secure `UpdateState` snippet now maintains the `ping-receiver` attribute, replicating `PingableType_ActionButtonMixin:UpdatePingAttributes`. `PingableActionButtonTemplate` hardcodes the attribute on and Blizzard clears it again for empty slots; we inherited the attribute but not the upkeep. It is done inside the restricted environment because it has to stay correct through combat.
- `PetButton.Create` sets `button.index`, which `PetActionButtonMixin:GetActionButtonInfo` reads. See the matching note on `StanceButton.lua`.
- The player frame overrides `GetTargetInfo` to pass `isPlayerResource`, and `GetAllowRadialWheel` to suppress the wheel, matching `PingableType_PlayerUnitFrameMixin`. Blizzard gates both on the cursor being off the portrait; our player frame has no portrait, so the health orb and power crystal are the whole frame.
- Removed the target frame's `GetContextualPingType`/`GetTargetPingGUID` pair. Both were dropped from `PingableTypeMixin` when the ping system moved to `GetTargetInfo`, so nothing called them, and the bare mixin they sat on returns a target with no guid. All the frame did was park a second, guid-less ping receiver over a target frame that oUF already spawns from `PingableUnitFrameTemplate`.


## 5.3.87-JuNNeZ (2026-08-21) - Target Castbar Fill, Raid Specialization Icons, and Fewer Stray Clicks

### Highlights

- The target castbar now fills instead of stretching. The art was being scaled into the fill region rather than revealed by it, so a cast looked like a zooming picture rather than a filling bar. This had been wrong since 12.0 for every target except yourself.
- The target castbar now also fills in the same direction as the target health bar it sits on. It previously swept left-to-right while the health bar underneath emptied right-to-left.
- Added specialization icons to the raid frames. On Raid Frames (5) they replace the portrait, as in party; on Raid Frames (25) and (40) they sit on the role badge next to the health bar, which also gives damage dealers a badge where they previously had none.
- Fixed Explorer Mode getting stuck visible and never fading again until a reload. Mounting and dismounting - including the automatic dismount from casting while mounted - could leave the interface believing you were still on a skyriding mount.
- Added an option to hide an action bar while you are mounted. A hidden bar cannot be clicked at all, so this stops stray clicks landing on abilities while you ride. Your skyriding bar is unaffected.
- Added an option to ignore clicks on faded out buttons. Faded buttons are invisible but still live, so clicking where one sits will cast it; with this on the click is ignored until you hover the bar and the buttons come back into view.
- Fixed an error from AzeriteUI's stance bar buttons that broke Blizzard's ability ping system. Pinging anywhere over the stance bar raised a Lua error and left pinging broken everywhere else on screen until reload.

### Access

- `/az -> Unit Frame Settings -> Raid Frames (5) -> Show Specialization Icons`
- `/az -> Unit Frame Settings -> Raid Frames (25) -> Show Specialization Icons`
- `/az -> Unit Frame Settings -> Raid Frames (40) -> Show Specialization Icons`
- `/az -> Action Bars -> Action Bar <n> -> Show while mounted`
- `/az -> Action Bars -> Action Bar <n> -> Ignore clicks while faded`

### Internal

- The target castbar's visible art is now an addon-owned texture anchored to the statusbar texture, rather than the statusbar texture itself. A timer-driven `StatusBar` on 12.x resizes its texture's region but does not narrow its texcoords, and texcoords written onto it by an addon do not survive, so neither letting it crop itself nor cropping it in place could ever work. The target health bar had always used the addon-owned structure, which is why health rendered correctly and cast did not.
- `/azdebugtarget` gains `cast`, `crop` and `mirror` subcommands for comparing castbar render paths live, and `status` now reads the fill direction back off both bars and states whether they agree.
- Specialization icon drawing for party and all three raid layouts is shared in `Components/UnitFrames/SpecIcons.lua`. `GroupSpecCache.lua` stays a pure data module.

## 5.3.86-JuNNeZ (2026-08-21) - Micro Menu Toggle, Party Specialization Icons, and an Options Overhaul

### Highlights

- Added a toggle that brings Blizzard's own micro menu back along the bottom of the screen, at `/az -> Action Bars -> Micro Menu`. The AzeriteUI cog wheel in the bottom right corner now has its own toggle in the same place, and the two are independent, so you can run either or both.
- Added an option to show each party member's specialization icon in place of their portrait, at `/az -> Unit Frame Settings -> Party -> Show Specialization Icons`.
- Fixed AzeriteUI calling protected mouse methods on Blizzard's hidden action buttons during combat, which could raise `ADDON_ACTION_BLOCKED` whenever Blizzard touched their mouse state mid-fight.
- Added `/azdebug taint`, which names the addon responsible for tainting Blizzard's action, pet and stance buttons.
- Party specialization icons now resolve within a couple of seconds instead of up to six, and keep resolving during combat. Rejoining a group you were in earlier draws its icons immediately.
- Every Explorer Mode option now has a tooltip. The four delay sliders previously gave no indication that their numbers were seconds, and the exit conditions and element toggles had no explanation at all.
- Auras with no timer, such as Devotion Aura and the bonus event buffs, now show a full duration bar in the movable top-right aura header instead of an empty trough.
- Fixed an `AzeriteUI tried to call the protected function 'Frame:SetScale()'` error when opening `/lock` during combat. Moving the player aura row or the secondary mana crystal while in combat now waits for the fight to end and then applies the position, instead of being blocked outright.

### Internal

- Replaced roughly 440 bare `pcall` guards across 27 files with `API.SafeCall` / `API.TryCall` from the new `Core/API/ProtectedCall.lua`. `SafeCall` routes a failed guarded call to the standard error handler so BugSack, BugGrabber, or Blizzard's error frame reports it with a call-site label, bursting three times per site and then throttling to one report per 60 seconds. `TryCall` remains silent and is reserved for guards whose failure is expected. Nothing in the addon should swallow an error without either fixing it or naming it.
- Consolidated the secret-value accessibility check into `API.CanAccess`, with `API.IsSafeNumber`, `API.IsSafeString` and `API.IsSafeBool` wrappers in `Core/API/SecretValues.lua`. It replaces three private copies - `CanAccessValue` in `Components/UnitFrames/Functions.lua`, `CanAccessTargetValue` in `Units/Target.lua` and `IsArenaValueAccessible` in `Units/Arena.lua` - which had drifted apart: the arena copy returned true when both probe globals were absent while the target copy returned true when only `issecretvalue` was absent, so arena and target frames could disagree about the same value. The shared check never consults `canaccessvalue`.
- Repaired the locale files. Ten strings that appear in the live interface had never been added to `enUS`, so they could not be translated in any language: the `/lock` help text, the movable-frame position and validation strings, the `Vehicle Seat` and `Widgets` anchor names, the tooltip `ID` label, and the player power color description, which had been reworded for the class-color option in `5.3.74` without the locale key following. Two entries had been destroyed by a bad global replace, collapsing pairs of real keys into `Enable Aura SoClass Powerr Key` in `ptBR` and a spliced action-bar/clock string in `zhTW`. Twenty-eight further translations were missing and falling back to English, mostly the Mana Orb and Demon Hunter Soul Fragment options, with `zhTW` also missing its Edit Mode and aura keys. All ten locales now carry every `enUS` key exactly once.
- `disableMouseInput` in `HideBlizzard.lua` now defers to the combat drop when the target frame is protected and combat is active, with a weak-keyed pending set flushed on `PLAYER_REGEN_ENABLED`. It runs as a `hooksecurefunc` handler, so Blizzard changing mouse state on a protected action button in combat previously took us straight into a blocked protected call.
- `GroupSpecCache` now advances the moment a reply arrives rather than on a fixed 1.5 second tick, with 0.5 seconds kept only as a floor between consecutive requests. It also drops the combat gate, since `NotifyInspect` is unprotected and gating on combat meant a group that zoned in and pulled could go a long time before anything resolved. `INSPECT_READY` is no longer filtered on our own pending request, so inspects triggered by other addons are harvested for free.
- Fixed a stall in `GroupSpecCache`: `INSPECT_READY` is not guaranteed to arrive, and a dropped reply left the pending slot occupied permanently, halting every later lookup for the rest of the session. Pending requests now expire after three seconds.
- Members who leave a group keep their cached specialization, marked stale, so a rejoin draws instantly and re-inspects in the background instead of starting from portraits again.
- Localized the group frame reload prompt in `Core/FixBlizzardBugs.lua`, which had shipped as hardcoded English including its button label while every other user-facing string went through `AceLocale`.
- Moved the new `Micro Menu` group to order 50 so it sits with the page-level Action Bars settings instead of after the stance bar.
- Fixed a duplicated `order` in the numbered action bar options, where `fadeAlone` and `fadeInCombat` both sat at 10 so their on-screen positions were settled by an alphabetical tiebreak instead of by intent. They now read 10 and 11, matching the pet and stance bar generator they had drifted from.
- `MicroMenu` gained a settings namespace, and the Blizzard micro menu frames moved out of `HIDDEN_FRAME_NAMES` into their own list so the quarantine can be skipped. The AzeriteUI popup is unaffected either way: its entries are proxies running `/click <MicroButtonName>`, not reparented Blizzard buttons.
- Added `Components/UnitFrames/GroupSpecCache.lua`, a throttled inspect-backed specialization cache. There is no API that reports a group member's specialization, so it drives `NotifyInspect` and `INSPECT_READY` one unit at a time, skips units that are disconnected, out of range or not inspectable, retries failures no more than once every fifteen seconds, and drops members who leave. It stays dormant until an option asks for it.
- `Core/Compatibility.lua` now adopts `ns.API` at file scope, because the TOC loads it ahead of `Core.xml`.
- The top-right aura header's duration bar is now drawn inverted: a full-width aura-colored layer with an opaque dark spent layer growing over it from the right, bound with `Enum.StatusBarTimerDirection.ElapsedTime` and `SetReverseFill(true)`. Blizzard's `ApplyDurationBar` passes permanent auras a zero duration with no zero check, unlike the `ApplyDurationText` path beside it, and addons have no per-aura way to tell a permanent aura apart. Inverting the layers makes elapsed zero render as a full bar, leaving timed auras looking the same as before.

Not yet released or verified in client. Expect this change to surface previously silent failures rather than hide them.


## 5.3.85-JuNNeZ (2026-08-20) - Group Frames in Arena, Reload Prompt, and the Blizzard Party Title

### Highlights

- Group frames now actually appear in Arena, Solo Shuffle and Skirmish. The 5 player frames were taking their group filter from Blizzard's raid manager, which does not exist in instanced PvP and reports "no groups shown" there, so the frames were both hidden and faded out no matter what your settings said.
- The reload prompt no longer greets you at every login. It was firing whenever a group frame module was switched off in your profile, including the settings pass that runs at login, so a permanently disabled module asked every session. It now appears only when you turn the frames off during the session, which is the case where Blizzard's own frames really are left stranded.
- Blizzard's leftover "Party" title no longer floats over the screen when you use the Raid (1-5) frames with the Party frames turned off. Blizzard's party frames were only being hidden when the Party module itself was enabled.
- Fixed the remaining `Cannot set tex coords when texture has mask` error from arena enemy frames. The previous guard asked the texture whether it was masked, and Retail 12.1 does not answer that reliably.

### Access

- Group frame visibility: `/az -> Unit Frame Settings -> Raid` or `Party`, then the `Visibility` toggles.
- Blizzard group frame fallback: `/az -> Unit Frame Settings -> Party` or `Raid`, turn the Azerite frames off, then accept the reload prompt.
- Group frame diagnostics: `/azdebug group`.

### Internal

- `Raid5` no longer consults `WoW12BlizzardQuarantine.GetRaidGroupFilter`. That filter describes which subgroups of a 10-40 player raid the compact frames draw, and it returns `"0"` whenever the raid manager is unavailable, which both wrote `groupFilter = "0"` onto the header and turned the driver's `[@raid1,exists]` clause into `hide`. The 5 player header now always uses `"1,2,3,4,5,6,7,8"`, and `IsRaidGroupShown` is gone.
- `ApplyAzeriteRaidGroupVisibility` no longer mirrors the raid manager's hidden mode onto `RaidFrame5`, which was setting its alpha to zero in the same contexts. `RaidFrame25` and `RaidFrame40` still follow it.
- `ShouldHandlePartyFrames` now returns true when either `PartyFrames` or `RaidFrame5` is enabled, so the party quarantine covers `PartyFrame`, `CompactPartyFrame` and their titles in a Raid5-only setup.
- The reload prompt in each group module's `UpdateSettings` now compares `profile.enabled` against a per-module `__blizzardFrameHandoverState` and only fires on an enabled to disabled transition.
- `SetSpecIconTexture` trusts an `azeriteHasMask` flag written where `SetMask` is called instead of `GetNumMaskTextures()`, with `pcall` around the fallback `SetTexCoord`.


## 5.3.84-JuNNeZ (2026-08-19) - Group Frames in Instanced PvP

### Highlights

- Party frames now appear in Skirmish Arena and other instanced PvP. The group frames decided whether you were grouped using a group-state condition rather than checking whether your party members actually exist, and that distinction matters in an instance group where you have no home party at all. All four group frame families now test for the party and raid units directly, the way the frames already tested for raid sizes.
- Group frames recover after zoning straight into combat. Blizzard's secure group header can only lay its unit buttons out while you are out of combat, and nothing on Blizzard's side retries once combat drops. Party and raid headers now rebuild themselves when you zone in and again whenever you leave combat.
- Fixed the `Cannot set tex coords when texture has mask` error thrown repeatedly by arena enemy frames. The specialization icon is drawn through a circular mask, and Retail 12.1 rejects tex coordinate changes on a masked texture.
- Raid (11-25) and Raid (26-40) unit frames now receive their intended frame layering again. Both headers were being created without any of their startup configuration, which left every unit button ten frame levels lower than designed.
- Holding the modifier key now reveals the top-right aura header even when you have a target selected. The target check previously ran first, so the key could not reveal anything for as long as something was targeted.
- Turning the Azerite party or raid frames off now offers to reload. Blizzard's own group frames cannot be revived mid-session once they have been replaced, and a reload is what brings them back.

### Access

- Group sizes: `/az -> Unit Frame Settings -> Party` or `Raid`, then the `Visibility` toggles.
- Blizzard group frame fallback: `/az -> Unit Frame Settings -> Party` or `Raid`, turn the Azerite frames off, then accept the reload prompt.
- Aura header modifier: `/az -> Aura Header Settings -> Only Show With Modifier Key`. `Keep Visible While Targeting` is greyed out while that mode is on, because the modifier now overrides it.

### Internal

- Group visibility drivers moved from `[group:party,nogroup:raid]` and `[group:raid]` to `[@party1,exists]` and `[@raid1,exists]`, with the raid sizes tested ahead of the party check because a raid subgroup also answers to the `party1-4` tokens. This matches how ElvUI and GW2_UI drive their own group headers.
- Added `GroupHeader.ForceSecureUpdate`, which bumps a private attribute to fire `OnAttributeChanged` and rerun `SecureGroupHeader_Update`. It is applied at the end of every `UpdateHeader` and on every combat drop, and is a no-op on headers that are not real secure group headers.
- `PartyFrames` now registers `PLAYER_ENTERING_WORLD` and keeps `PLAYER_REGEN_ENABLED` registered; the raid modules no longer unregister theirs after the first recovery.
- Fixed a stale `oUF:SpawnHeader` call shape in `Raid25` and `Raid40`. The bundled oUF no longer takes the old third `visibility` parameter, and its attribute loop exits on the first nil name, so the leftover argument was discarding every spawn attribute.
- Added `/azdebug group`, which reports instance type, combat state, group category, roster counts, each header's live driver result via `SecureCmdOptionParse`, and every child button with its assigned unit.


## 5.3.83-JuNNeZ (2026-08-18) - Target Auras in Combat, Class Power Layering, and Group Frame Fixes

### Highlights

- Target frame buffs and debuffs now display during combat on Retail 12.1. The target aura row was still reading aura data through the old scanning path, which Retail 12.1 no longer supplies to addons while in combat; it now uses the same Blizzard-owned aura display the player rows already use.
- The Class Power bar no longer disappears behind the player frame when dragged over the Mana Orb. It now stays above every player frame layer, matching how it already behaved over the Power Crystal.
- Removed the invisible clickable area left by the Class Power frame. Clicking an empty Class Power region no longer targets you.
- Top-right aura headers set to mouse-over now reliably come back. They could previously stay invisible for the rest of the session while still showing tooltips, after a reload or zone change with the cursor over them.
- Azerite raid frames now appear in Skirmish Arena. Zoning straight into combat previously left the group frames hidden for the entire match.
- Turning Azerite raid frames off now leaves Blizzard's raid frames working, instead of leaving you with no group frame at all.
- Fixed two Lua errors on nameplate auras in combat that could stop aura updates for the rest of the session.
- Party, raid, and arena auras gained during combat can now appear, instead of only ones carried in from before the pull.

### Access

- Class Power position: run `/lock`, then drag `Class Power`.
- Blizzard raid frame fallback: `/az -> Unit Frame Settings -> Raid`, turn the Azerite raid frames off, then `/reload`.

### Internal

- Target auras migrated to `AuraContainer` via a new single-unit `ns.PlayerAuraContainers.CreateForUnit`; the oUF scanning element stays as the fallback when the native template is unavailable.
- Secret-value handling reworked in the embedded oUF aura element: surrogate keys for secret `auraInstanceID`, non-secret sort ranks, up-front cache initialization, and `issecrettable` adopted for wholly-secret payload guards.
- Aura filters now fail open when a payload cannot be judged, rather than silently hiding it.
- Added `/azdebug aurasnapshot target`.


## 5.3.82-JuNNeZ (2026-08-16) - Secondary Mana Crystal and Options Fixes

### Highlights

- Fixed the small secondary Mana crystal on Retail 12.1 so it can display protected Mana values for Balance Druids, Shadow Priests, and Elemental Shamans while a non-Mana primary resource is active.
- Added an independent mover for the secondary Mana crystal. Its position now persists separately instead of following the main player crystal.
- Fixed `/az` pages appearing empty when another addon loaded an outdated shared AceGUI checkbox widget.

### Access

- Run `/lock`, then drag `Player Secondary Mana Crystal` to place the small crystal independently.


## 5.3.81-JuNNeZ (2026-08-15) - Power Displays, Bartender Compatibility, and Cooldown Numbers

### Highlights

- Player Power Style `Automatic (By Resource)` now selects the Mana Orb for Mana and the Power Crystal for Insanity and other primary resources, with corrected resource colors for Shadow Priests and other classes.
- Added a small secondary Mana crystal at the player crystal's bottom-left. It appears while a non-Mana primary resource is active and Mana is below full, then hides again at full Mana.
- Fixed target Power Crystal colors and Short Number, Full Number, Percent, and Short + Percent text so they follow the target's actual resource on Retail 12.1.
- Restored numeric cooldown timers on AzeriteUI action buttons while preserving the existing cooldown sweep and charge behavior.
- Restored complete Bartender4 coexistence: Bartender keeps ownership of its action, pet, stance, bag, micro-menu, vehicle, extra-action, status, queue, configuration, and binding systems without AzeriteUI hiding or reparenting them.

### Access

- Player resource routing: `/az -> Unit Frame Settings -> Player -> Player Power Style -> Automatic (By Resource)`.
- Target resource text: `/az -> Unit Frame Settings -> Target -> Power Text Style`.
- Bartender4 requires no AzeriteUI profile reset; enable both addons and configure its bars through `/bt` as usual.


## 5.3.80-JuNNeZ (2026-08-14) - Player Aura Controls and Arena Visibility

### Highlights

- Restored the player-frame aura customization that remains possible on Retail 12.1: maintained important buffs, boss/role buffs, stealable buffs, personal and player/pet buffs, nameplate-highlighted buffs, other temporary buffs, and optional long or permanent utility buffs.
- Added working controls for full-brightness aura icons and the maximum original duration of temporary buffs, while retaining debuff-only, mixed-debuff, aura-count, and separate-debuff-row controls.
- Custom player-aura filters now use Blizzard's native combat-safe aura groups, so the selected categories continue to work during combat and in vehicle state without inspecting protected aura data.
- Fixed arena-opponent portraits with a reliable 2D fallback, restored class-colored health when ordinary unit data is unavailable, and replaced misleading question-mark badges with specialization or class icons when Retail exposes either value.
- Added an option to keep full class-power displays visible out of combat, including fully recharged Death Knight runes.
- Fixed Retail 12.1 status-ring hover errors that could leave the experience or reputation ring covering the minimap.
- Added native translations for the restored player-aura controls and full class-power option in every supported locale.

### Access

- Open `/az -> Unit Frame Settings -> Player -> Player Aura Row`.
- Disable `Use AzeriteUI Stock Behavior` to configure individual buff categories. Stock behavior, debuff controls, brightness, and display-count controls remain available directly in the same section.
- Open `/az -> Unit Frame Settings -> Class Power` and enable `Show Full Class Power Out of Combat` to keep a capped resource visible between fights.

### Known Limitation

- AzeriteUI now makes a best-effort attempt to recover Training Grounds specialization icons from readable unit-tooltip text when Blizzard's normal arena specialization API returns nothing. Retail 12.1 can also protect that tooltip text; in that case AzeriteUI displays the opponent's class icon when available and otherwise hides the badge instead of showing a misleading question mark.


## 5.3.79-JuNNeZ (2026-08-13) - Target PvP Secret-Value Hotfix

### Highlights

- Fixed a Retail 12.1 error that could occur while selecting or clearing targets whose PvP state was protected by Blizzard's secret-value system.
- Target faction badges now hide safely when their source data is inaccessible, while preserving the existing badge behavior for normal, PvP, free-for-all, mercenary, elite, rare, and boss targets.


## 5.3.78-JuNNeZ (2026-08-13) - Retail 12.1 Native Aura and Input Hardening

### Highlights

- Rebuilt player-frame auras on Blizzard's Retail 12.1 native aura containers so combat buffs, harmful effects, vehicle auras, tooltips, and right-click cancellation remain available without secret-value or taint failures.
- Restored the intended AzeriteUI player-aura behavior: important and short temporary effects are prioritized, generic effects remain subdued, buff/debuff capacity is shared, and aura buttons no longer lose mouse input to the player or target frame.
- Modernized the movable top-right aura header with native secure containers, a dark remaining-time bar, and the original centered red warning during the final 10 seconds.
- Fixed AzeriteUI action-button input and state refreshes while safely suppressing invisible Blizzard action buttons; cooldowns, charges, item counts, pet/stance bindings, and Bartender handoff now use current Retail paths.
- Kept stock action-bar furniture hidden after Blizzard load transitions, including the backpack and bag controls, while restoring the Looking for Group queue eye to its AzeriteUI minimap position.
- Hardened unit-frame health, power, nameplate, private-aura, raid-warning, and boss-emote updates for Retail 12.1 secret values and load-on-demand frames.

### Access

- Player-frame aura controls: `/az -> Unit Frame Settings -> Player -> Auras`.
- Movable top-right aura controls: `/az -> Auras`.
- Existing `/az -> Action Bars` and `/az -> Minimap` settings continue to apply; no profile reset is required.

### Internal

- Player and standalone auras now use `Blizzard_AuraContainer` templates and native duration bindings; the retired Retail secure-header/manual scanner paths were removed.
- Blizzard action bars are quarantined with alpha and mouse-input suppression instead of event removal, reparenting, or secure method replacement.
- LibActionButton and oUF Retail paths now avoid branching, indexing, or arithmetic on secret values and prefer current duration/charge APIs.
- Raid warning, raid boss emote, queue status, and aura-container setup now follow their Retail load-on-demand owners.


## 5.3.77-JuNNeZ (2026-08-12) - WoW 12.1 Aura and Action Bar Fixes

### Highlights

- Fixed action bars missing cooldown swipes, timer text, charges, and item counts after WoW 12.1.
- Restored the standalone player aura frame on Retail 12.1 by replacing the retired secure aura-header path with a manual fallback.
- Fixed Retail 12.1 aura startup so the frame populates after `/reload`.

### Access

- Existing `/az -> Auras` and `/az -> Action Bars` settings continue to apply.

### Internal

- Updated LibActionButton cooldown/count handling for Retail duration objects and charge data.
- Added the initial Retail fallback in `Components/Auras`; it is superseded by the native-container implementation in 5.3.78.


## 5.3.76-JuNNeZ (2026-07-17) - Action Bar Skyriding and Layout Reliability

### Highlights

- Fixed Druid flight mode and travel form with skyriding enabled not switching bar 1 to the skyriding action bar.
- Fixed temporary bar-1 states so keyboard binds stay aligned with the displayed actions during possess, vehicle, override, and skyriding transitions.
- Fixed zigzag and grid action-bar layouts using unstable button iteration, which could leave button positions or refreshes inconsistent after reloads and settings updates.
- Added retail WoW 12.0.7 interface support (`120007`).

### Access

- No new setting is required. Existing `/az -> Action Bars` settings continue to apply.

### Internal

- `Components/ActionBars/Prototypes/ActionBar.lua`: bar 1 now treats skyriding as `bonusbar:5` without requiring `mounted`, and uses the secure click-route consistently for dynamic primary-bar paging states.
- `Components/ActionBars/Elements/ActionBars.lua`: dragon/skyriding visual-state checks now follow `bonusbar:5`, and button-count refreshes iterate deterministically.
- `Components/ActionBars/Prototypes/ButtonBar.lua`: zigzag and grid layouts now iterate buttons in numeric order so order-dependent offsets stay stable.


## 5.3.75-JuNNeZ (2026-05-03) - Dragonflying Relog Keybind Recovery

### Highlights

- Fixed a dragonflying relog edge case where logging out mounted with the dragon bar visible could leave action-bar keybinds non-responsive after login while mouse clicks still worked.
- Action-bar keybind routing now performs a short follow-up refresh after state transitions so late login/mount state cleanup does not leave stale binding routes.

### Access

- No new setting is required. Existing `/az -> Action Bars` settings continue to apply.

### Internal

- `Components/ActionBars/Elements/ActionBars.lua`: added a guarded deferred binding-refresh pass after standard binding rebuilds to recover from late post-login action-bar state settlement.


## 5.3.74-JuNNeZ (2026-05-03) - Player Crystal Class Color + Windwalker 6-Chi

### Highlights

- Added a new `Class Color` source for the player Power Crystal / Mana Orb under `/az -> Unit Frame Settings -> Player -> Crystal/Orb Color Source`.
- Preserved saved-variable compatibility for legacy `class` color-mode values.
- Fixed Windwalker Monk Chi display to support 6 Chi points while still showing 5 points when max Chi is 5.
- Updated the 6-Chi visual layout to use a curved progression with the larger unique point at index 6 for clearer read order.

### Access

- Crystal/Orb color source: `/az -> Unit Frame Settings -> Player -> Crystal/Orb Color Source`.
- No new setting is required for Monk Chi; the 6-point behavior applies automatically when your live max Chi is 6.

### Internal

- `Components/UnitFrames/Units/Player.lua`: added a dedicated `classColor` mode for player power colors and mapped legacy `class` values to it.
- `Options/OptionsPages/UnitFrames.lua`: added `Class Color` to the player Crystal/Orb color-source dropdown.
- `Components/UnitFrames/Units/PlayerClassPower.lua`: keeps Monk `CHI` on the `Chi` style for max 5 or 6 before generic `max >= 6` style routing.
- `Layouts/Data/PlayerClassPower.lua`: extends `Chi` to 6 points and applies the curved point ordering/style tuning.


## 5.3.73-JuNNeZ (2026-05-01) - Party/Raid Right-Click Menu Fix

### Highlights

- Fixed right-clicking party and group unit frames not opening the unit interaction menu (invite, inspect, set focus, trade, etc.) in parties and follower dungeons.
- Fixed the same issue in 10-man and 40-man raids. 5-man raids were already working correctly.
- No settings change required. Works after `/reload`.

### Known Limitation

- Right-clicking a **story-mode companion** (AI-controlled party member in story-mode raids/dungeons) still only opens a menu if that companion is already your current target. This is a Blizzard engine constraint, not an AzeriteUI bug — see Internal notes.

### Internal

#### Root Cause

AzeriteUI's shared `UnitFrame.InitializeUnitFrame` deliberately skips `RegisterForClicks` for secure-group-header children (enforced by an `IsSecureHeaderChild()` guard). This is intentional — calling `RegisterForClicks` from insecure code on a protected header child is unsafe. Instead, each group-frame style function is responsible for calling `self:RegisterForClicks("AnyUp")` explicitly after `InitializeUnitFrame`.

`Raid5.lua` had this call. `Party.lua`, `Raid25.lua`, and `Raid40.lua` did not. Without click registration the button never dispatched any click events, so Blizzard's secure `togglemenu` action bound to `*type2` never fired on right-click.

#### Previous Failed Attempts (from FixLog and research)

1. **`RegisterForClicks` inside restricted `initialConfigFunction`** (oUF snippet) — Failed with `RestrictedExecution.lua:428: Call failed`. `RegisterForClicks` is not available in Blizzard's restricted execution environment.
2. **XML virtual template with `registerForClicks="AnyUp"`** — Produced `bad argument #1 ... self:RegisterForClicks(buttons)` at runtime. Live debug dumps already showed `leftClick true rightClick true`, confirming this was solving the wrong layer.
3. **Force `*type2 = "menu"` with a custom `menu-function`** — Attributes applied but the menu never opened. Clique explicitly converts `menu` back to `togglemenu` because `menu` is hard-coded to mouse-up only and breaks with down-click registration. Referencing `menu-function` in restricted snippets also failed because `function` is a forbidden token in the restricted parser.
4. **`PostClick`/`OnMouseUp` fallback calling `UnitPopup_OpenMenu` directly** — Worked for opening the menu for story-mode companions by mapping non-player `raidN` tokens to `TARGET`. However, selecting any protected item (raid markers, set focus) triggered `ADDON_ACTION_FORBIDDEN` because the open was attributed to AzeriteUI. Patching this by wrapping `UnitPopupRaidTargetButtonMixin.CanShow` broke Blizzard's normal target-frame raid-marker menu globally. Approach abandoned.

#### The Fix

Added `self:RegisterForClicks("AnyUp")` immediately after `ns.UnitFrame.InitializeUnitFrame(self)` in the style functions for `Party.lua`, `Raid25.lua`, and `Raid40.lua`. This is the same pattern already present in `Raid5.lua` and matches how DiabolicUI3 registers clicks globally in its shared style wrapper.

#### Story-Mode Companion Limitation

Blizzard's secure `togglemenu` action classifies the unit token to choose which popup to open. For `raidN` tokens it requires `UnitIsPlayer(unit) == true`. Story-mode companions are NPCs so `UnitIsPlayer` returns false. The only fallback Blizzard provides is `UnitIsUnit(unit, "target")` which maps to a `TARGET` menu — which is why targeting the companion first makes right-click work. Every oUF-based addon (live upstream oUF, DiabolicUI3, ElvUI, DiabolicUI2) hits this same wall. None have a story-mode NPC fallback. Resolution requires Blizzard to expose a secure API for opening unit menus on non-player group tokens.

#### Files Changed
- `Components/UnitFrames/Units/Party.lua` — added `self:RegisterForClicks("AnyUp")`
- `Components/UnitFrames/Units/Raid25.lua` — added `self:RegisterForClicks("AnyUp")`
- `Components/UnitFrames/Units/Raid40.lua` — added `self:RegisterForClicks("AnyUp")`

---

## 5.3.72-JuNNeZ (2026-05-01) - Target Portrait and Stealth Bar Fixes

### Overall

- This release fixes two visible gameplay regressions: bar-1 keyboard binds now follow stealth/form bonus pages correctly, and hostile target portraits have safer fallback handling when WoW 12 refuses or delays the 3D model path inside instances.

### Highlights

- Fixed rogue stealth and Shadow Dance keybinds so pressing bar-1 keys casts the same paged action shown on the button.
- Extended the same dynamic binding route to druid and monk bonus pages, keeping keyboard input aligned with secure action-bar paging.
- Improved target portraits for hostile instance targets by trying the normal 3D model path, then a creature-model fallback when safe, then the 2D portrait fallback.
- Fixed a WoW 12 secret-GUID portrait error by skipping NPC-ID parsing whenever Blizzard marks the target GUID as secret.
- Kept normal base-bar command bindings in place for hold-cast support outside dynamic paging states.

### Access

- No new setting is required. Existing `/az -> Action Bars` and target-frame settings continue to apply.

### Internal

- `Components/ActionBars/Prototypes/ActionBar.lua`: treats bar-1 bonus pages `7-10` as dynamic paging states so override keybinds use secure click routing while those pages are active.
- `Components/UnitFrames/Units/Target.lua`: adds protected target portrait model checks, a sibling 2D fallback frame, optional creature-ID fallback, and secret-value guards around GUID handling.


## 5.3.71-JuNNeZ (2026-04-27) - Party Frame and Action Bar Fixes

### Overall

- This release cleans up two visible annoyances from the recent builds: party frames should keep working normally when groups refresh, and action bars you have turned off should stay off even during combat, mounts, vehicles, and fading updates.

### Highlights

- Fixed party frames so right-clicking a party member opens the normal unit menu again.
- Fixed a party-frame setup error that could stop group frames from building correctly in WoW 12.0.5.
- Fixed disabled AzeriteUI action bars sometimes appearing during combat and staying visible until `/reload`.
- Disabled action bars now stay hidden through secure visibility refreshes.
- Explorer Mode and action-bar fading now ignore disabled action, pet, and stance bars instead of bringing them back into a fade cycle.

### Access

- No new setting is required. Existing disabled action bars keep using your current `/az -> Action Bars` choices.

### Internal

- `Libs/oUF/ouf.lua`: preserved the safe party unit-menu assignment path while removing the restricted-environment call that caused the `5.3.70-JuNNeZ` hotfix.
- `Components/ActionBars/Prototypes/Bar.lua`: disabled bars now store their hidden intent in the secure `userhidden` attribute that the action-bar visibility snippet already checks.
- `Components/ActionBars/Prototypes/ActionBar.lua`: disabled action bars and their buttons are removed from `LibFadingFrames` before fading updates return.
- `Core/ExplorerMode.lua`: Explorer Mode skips disabled action, pet, and stance bars when registering fading.


## 5.3.70-JuNNeZ (2026-04-26) - Party Frame Hotfix

### Overall

- This hotfix removes a bad safety call from party/raid frame setup that could break group frame creation in WoW 12.0.5.

### Highlights

- Fixed a `RestrictedExecution.lua` error when AzeriteUI party frames were shown or refreshed.
- Restored the safe group-frame setup path used before `5.3.69-JuNNeZ`.

### Access

- No new setting is required. Reload UI after updating.

### Internal

- `Libs/oUF/ouf.lua`: removed `RegisterForClicks()` from the restricted secure group-header snippet because that method is not available in Blizzard's restricted execution environment.


## 5.3.69-JuNNeZ (2026-04-25) - Party Right-Click Menu Safety

### Overall

- This update tightens party-frame click handling so right-clicking party members keeps opening the normal unit menu consistently.

### Highlights

- Added an explicit click registration safety path for party and raid-style group unit buttons.
- This preserves the existing left-click targeting and right-click unit-menu behavior.

### Access

- No new setting is required. Reload UI after updating.

### Internal

- `Libs/oUF/ouf.lua`: explicitly registers secure group-header unit buttons for mouse-up clicks where the right-click unit menu action is assigned.


## 5.3.68-JuNNeZ (2026-04-25) - Action Bar Safety + Nameplate Color Options

### Overall

- This update focuses on two everyday pain points: hidden dragonriding bars should no longer catch stray clicks, and enemy nameplate threat colors are easier to tell apart from castbar interrupt colors. It also tightens action-button drag-lock handling so button locking behaves more consistently across normal action, pet, and stance buttons without changing the existing hold-to-cast route.

### Highlights

- Added enemy nameplate threat color presets, including color-blind friendly choices and a darker AzeriteUI yellow option.
- Fixed invisible bars 2+ during dragonriding so they no longer catch accidental mouse clicks while hidden.
- Improved dragonriding bar visual refresh after action-page changes so hidden secondary bars recover more reliably.
- Made action, pet, and stance button drag-lock handling more consistent with the embedded action-button library.
- Kept the existing bar 1 hold-to-cast behavior unchanged.

### Access

- Nameplate threat colors: `/az -> Nameplates -> Colors -> Enemy Threat Colors`.
- No new action bar setting is required. Reload UI after updating.

### Internal

- `Components/UnitFrames/Units/NamePlates.lua`, `Options/OptionsPages/Nameplates.lua`, `Locale/enUS.lua`: added the threat color preset profile option, selector, player-facing text, and preset color resolution.
- `Components/ActionBars/Elements/ActionBars.lua`: added dragonriding click blockers for visually hidden secondary bars and centralized dragon visual refresh.
- `Components/ActionBars/Elements/PetBar.lua`, `Components/ActionBars/Elements/StanceBar.lua`, `Components/ActionBars/Prototypes/PetButton.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`: normalized secure drag-lock attribute handling while preserving legacy compatibility.


## 5.3.67-JuNNeZ (2026-04-22) — WoW 12.0.5 Stability + Arena Frames

### Overall

- This update focuses on things that could break silently or make troubleshooting harder in WoW 12.0.5. Arena enemy frames should show again when opponents appear, tooltips should stop tripping over protected unit information, BugSack exports should copy cleanly even when the current target is protected by Blizzard, and aura buttons should behave better in busy fights without losing their normal border look.

### Highlights

- Fixed AzeriteUI arena enemy frames not appearing reliably after the last update.
- Fixed BugSack Copy Session exports failing when Blizzard marks the current target or captured error data as protected.
- Fixed tooltip unit handling so world-cursor and unit tooltips avoid protected unit-name reads in WoW 12.0.5.
- Reduced player aura update load in high-aura PvP situations, helping prevent `script ran too long` errors during heavy buff/debuff churn.
- Restored normal-looking player, target, party, arena, and nameplate aura borders while avoiding the slower Blizzard backdrop path that could stall during aura creation.

### Access

- No new settings required. Reload UI after updating.
- Arena frames use the existing AzeriteUI arena frame settings.
- BugSack users can keep using the Copy Session / Copy All buttons as before.

### Internal

- `Components/UnitFrames/Units/Arena.lua`: registers live arena opponent updates and uses secure arena-unit visibility checks while inside arena instances.
- `Components/Misc/BugSack.lua`: sanitizes secret values before export text is concatenated and avoids protected target identity reads.
- `Components/Misc/Tooltips.lua`: adds safer tooltip-unit discovery and skips custom unit-name rewriting when Blizzard marks identity as secret.
- `Libs/oUF/elements/auras.lua`: caches stable aura button state and avoids repeated unchanged cooldown, icon, count, mouse, and visibility writes.
- `Components/UnitFrames/Auras/AuraStyling.lua`: replaces per-aura `SetBackdrop()` border creation with texture-backed border pieces and keeps cached border/icon styling paths.


## 5.3.66-JuNNeZ (2026-04-18) — Raid Panel Sync + Player Debuff View

### Overall

- This update makes AzeriteUI follow the raid panel more closely and gives players a simpler way to keep the player aura row focused on problems that need attention. If you hide raid groups with Blizzard's raid panel, AzeriteUI raid frames should now follow those choices instead of continuing to show filtered groups. If you prefer a cleaner player aura row, you can now show only harmful effects on yourself without building a custom aura filter.

### Highlights

- Fixed AzeriteUI raid frames so Blizzard's raid panel group buttons can hide and show matching raid subgroups.
- Fixed the raid-panel eye / Hide Groups state so AzeriteUI raid frames can disappear with the Blizzard raid panel instead of staying visible.
- Improved filtered raid layouts so hidden raid groups are not re-added by AzeriteUI's manual raid-frame positioning pass.
- Added a player aura option to show debuffs only, keeping buffs out of the player aura row while preserving boss debuffs and blacklist behavior.
- Added localized option text for the new debuffs-only player aura setting.

### Access

- Raid group hiding uses Blizzard's existing raid panel group buttons and Hide Groups eye button.
- The new aura option is under `/az -> Unit Frame Settings -> Player -> Show Auras -> Player Aura Row -> Show Debuffs Only`.

### Internal

- `Core/FixBlizzardBugs.lua`: mirrors Blizzard raid-panel hidden/group-filter state into AzeriteUI raid headers, queues secure filter updates during combat, and refreshes after delayed Blizzard button-state changes.
- `Components/UnitFrames/Units/Raid5.lua`, `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`: consume the mirrored raid group filter and reject stale filtered child units during raid layout reflow.
- `Components/UnitFrames/Auras/AuraFilters.lua`, `Components/UnitFrames/Units/Player.lua`, `Options/OptionsPages/UnitFrames.lua`, `Locale/*.lua`: added the player `playerAuraDebuffsOnly` profile option, filter behavior, options UI, and locale strings.


## 5.3.65-JuNNeZ (2026-04-18) — Raid, Pet Bar, and Mounted Bar Recovery

### Overall

- This update focuses on things that could disappear, squeeze together, or fail to recover at the wrong moment. Large raid groups should lay out more naturally, hunter pet abilities should appear when the pet UI becomes ready, dragonriding transitions should leave the extra bars in a more dependable visible state, and startup conflicts with AbilityTimeline should be quieter.

### Highlights

- Fixed large raid frames so groups above 20 players are no longer capped or squeezed together by older saved layout values.
- Fixed sparse raid groups so later subgroups keep their own row or column instead of sliding into earlier groups when the raid roster has gaps.
- Fixed hunter pet ability bars not appearing reliably when pet action data arrives after the pet unit itself.
- Improved dragonriding and bonus-bar recovery so bars 2+ are refreshed again after late mount, combat, and bonus-bar state changes.
- Hardened startup/profile refresh handling when AbilityTimeline is enabled, reducing nil-anchor, class-power, and spell-glow crashes caused by shared library timing.

### Access

- No new settings required. Reload UI after updating.
- Existing raid frame options remain under `/az -> Unit Frames -> Raid Frames (25)` and `/az -> Unit Frames -> Raid Frames (40)`.

### Internal

- `Components/UnitFrames/Units/Raid25.lua`, `Components/UnitFrames/Units/Raid40.lua`: large-raid capacity guards, secure child collection hardening, and subgroup-aware sparse roster layout.
- `Components/ActionBars/Elements/PetBar.lua`: registered `PET_UI_UPDATE` and refreshed pet visibility/buttons when pet UI data changes.
- `Components/ActionBars/Elements/ActionBars.lua`: modern bonus-bar source preference plus delayed visual refresh for dragonriding/bonus-bar transitions.
- `Core/MovableFrameModulePrototype.lua`, `Components/UnitFrames/Units/PlayerClassPower.lua`, `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`: defensive startup/profile guards for AbilityTimeline/shared-library timing.


## 5.3.64-JuNNeZ (2026-04-17) — Aura Reliability + Dragonriding Bar Recovery

### Overall

- This update makes buffs, debuffs, and action bars recover more reliably during combat, reloads, and dragonriding transitions. Timers and stack counts should stay accurate, debuffs are easier to spot, and secondary action bars should no longer feel stuck after mounted combat changes.

### Highlights

- Fixed player aura stack counts freezing at their pre-combat value when WoW 12 returned protected combat stack data.
- Fixed the separate player debuff row so active debuffs rebuild more reliably after `/reload`, combat transitions, and short-lived aura update gaps.
- Fixed top-right debuffs being displaced by wrapped buff rows, and added a red debuff border so harmful effects are easier to distinguish from buffs.
- Fixed top-right aura timer bars so they begin draining immediately, while timeless buffs no longer blink like expiring auras.
- Fixed dragonriding and arena/mounted transition handling so secondary action bars hide only visually during dragonriding and restore more reliably after dismounting, including combat transitions.
- Made overlapping action-bar keybinds deterministic: bar 1 now wins conflicts, which keeps dragonriding and primary action routing consistent.

### Access

- No new settings required. Existing player aura options remain under `/az -> Unit Frames -> Player -> Display & Feedback`.
- Existing action bar behavior applies automatically after `/reload`.

### Internal

- `Components/Auras/Auras.lua`: split top-right buff/debuff rows, debuff border coloring, timer visibility cleanup, and zero-duration aura handling.
- `Components/UnitFrames/Units/Player.lua`: detached player debuff visibility intent, reload bootstrap refresh, and safer combat-entry refresh behavior.
- `Components/UnitFrames/Auras/AuraFilters.lua`, `Components/UnitFrames/Auras/AuraStyling.lua`, `Libs/oUF/elements/auras.lua`: player aura/debuff filtering and stack display hardening for WoW 12 protected aura data.
- `Core/Widgets/Cooldowns.lua`: duration-object cooldown bars now use real duration ranges when safe fallback data is available.
- `Components/ActionBars/Elements/ActionBars.lua`, `Components/ActionBars/Prototypes/ActionBar.lua`: dragonriding secondary-bar visual recovery and deterministic primary-bar binding priority.


## 5.3.63-JuNNeZ (2026-04-16) — Action Bar Stability Follow-Up

### Highlights

- Reverted the experimental per-bar post-combat hold-to-cast rebinding path that could cause intermittent action bar instability.
- Kept the core hold-to-cast and dragonriding slot-routing fixes from 5.3.62 intact.

### Access

- No new settings required. Reload UI to apply this stability follow-up.

### Known Limitation

- If you enter combat while mounted (dragonriding/vehicle-style state) and unmount during that same combat, hold-to-cast still cannot be restored mid-combat due to Blizzard secure restrictions. Hold-to-cast returns once combat ends.

### Internal

- `Components/ActionBars/Prototypes/ActionBar.lua`: rolled back deferred per-bar `PLAYER_REGEN_ENABLED` binding refresh experiment and restored the prior combat guard path.


## 5.3.62-JuNNeZ (2026-04-16) — Hold-To-Cast + Dragonriding Routing

### Highlights

- Restored press-and-hold casting support for Single-Button Assistant flows on AzeriteUI action bars by preferring Blizzard command-binding routing in normal bar states.
- Fixed dragonriding/vehicle transition routing so action keys use temporary mounted action slots instead of stale base-bar actions.
- Fixed a WoW 12 `ADDON_ACTION_FORBIDDEN` regression tied to Blizzard `ForceUpdateAction()` by disabling the taint-prone assisted-rotation template path on AzeriteUI custom action buttons while keeping assisted highlight support.

### Access

- Action bar hold-cast route toggle: `/az -> Action Bar Settings -> Use Command Bindings for Hold Cast`

### Known Limitation

- If you enter combat while mounted (dragonriding/vehicle-style state) and unmount during that same combat, hold-to-cast cannot be restored mid-combat due to Blizzard secure restrictions. AzeriteUI now restores hold-to-cast automatically as soon as combat ends.

### Internal

- `Components/ActionBars/Prototypes/ActionBar.lua`: state-aware command/click routing, dynamic bar-state handling for dragon/vehicle/override paths, and deferred per-bar post-combat binding refresh.
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`: removed assisted-rotation template usage on AzeriteUI custom action buttons to avoid protected `ForceUpdateAction()` taint.


## 5.3.61-JuNNeZ (2026-04-15) — Prediction Stability + Party Frame Hardening

### Highlights

- Fixed a target-frame timeout path where absorb prediction could trigger `script ran too long` during rapid health-prediction updates.
- Fixed a WoW 12.0.1 crash path on party and raid pet aura full refresh by adding a safe fallback when slot enumeration rejects compound unit tokens.
- Hardened party-frame quarantine timing so rare group-join races no longer show Blizzard party frames alongside AzeriteUI party frames.

### Access

- No new settings required. Reload UI to apply all fixes.

### Internal

- `Components/UnitFrames/Units/Target.lua`: target absorb prediction now avoids `GetPredictedValues()` in the hot path and relies on safer absorb sources.
- `Libs/oUF/elements/auras.lua`: full aura rebuild now uses guarded slot reads with bounded index fallback for unsupported compound tokens.
- `Core/FixBlizzardBugs.lua`: restored party-name quarantine during active party context and locked quarantine parent attachment for Blizzard party member frames.


## 5.3.60-JuNNeZ (2026-04-11) — Player Debuff Layer + Aura Controls

### Highlights

- Added a new `Auras Shown` slider for the main player aura row, with the default set to 16.
- Added a new `Separate Player Debuff Row` option that filters harmful auras out of the main player row and shows them in a separate movable debuff layer with its own cap.
- The `Player Debuffs` `/lock` mover now uses a stable holder surface, so the live debuffs can be repositioned visually and stay aligned inside the mover box.
- Target aura layout refresh now reapplies correctly when unit-frame aura settings change.
- Fixed a WoW 12 secret-value safety edge case in the oUF health color path to avoid bad `GetRGB()` payloads reaching health-bar updates.

### Access

- Main player aura count: `/az -> Unit Frames -> Player -> Display & Feedback -> Auras Shown`
- Split player debuff layer: `/az -> Unit Frames -> Player -> Display & Feedback -> Separate Player Debuff Row`
- Separate debuff cap: `/az -> Unit Frames -> Player -> Display & Feedback -> Separate Debuffs Shown`
- Debuff mover: `/lock -> Player Debuffs`

### Internal

- `Components/UnitFrames/Units/Player.lua`: added split player debuff holder/mover flow, independent player aura caps, and cleanup of abandoned split-buff leftovers.
- `Components/UnitFrames/Auras/AuraFilters.lua`: added a dedicated player debuff-row filter wrapper.
- `Components/UnitFrames/UnitFrame.lua`: sort-mode refresh now updates `Auras`, `Buffs`, and `Debuffs`.
- `Components/UnitFrames/Units/Target.lua`: consolidated target aura container layout refresh path.
- `Core/Common/Constants.lua`: addon version now prefers live TOC metadata instead of a stale hardcoded constant.
- `Libs/oUF/elements/health.lua`: added secret-value guards around color extraction.


## 5.3.59-JuNNeZ (2026-04-07) — Lock & Load: Combat-Proof Action Bar Bindings

### Highlights

- Action bar bindings no longer attempt to update during combat lockdown. Updates that arrive mid-combat are now queued and applied cleanly when you leave combat.
- Bindings now refresh correctly when entering or leaving vehicles, override bars, and bonus action bars — no more stale keybinds after a mount or vehicle transition.
- Added WoW interface build 120005 to the supported compatibility list.

### Access

- No new settings. The fixes apply automatically on load and after every combat/vehicle transition.

### Internal

- `Components/ActionBars/Elements/ActionBars.lua`: `UpdateBindings` now guards with `InCombatLockdown()`, defers via `PLAYER_REGEN_ENABLED`, and registers `UPDATE_BONUS_ACTIONBAR`, `UPDATE_OVERRIDE_ACTIONBAR`, and `UPDATE_VEHICLE_ACTIONBAR` events.
- `AzeriteUI5_JuNNeZ_Edition.toc`: added interface version `120005`.


## 5.3.58-JuNNeZ (2026-04-06) — Player Alternate Aura Toggle + Access

### Highlights

- Fixed Player Alternate aura placement so turning off `Auras below frame` now places the aura row above the frame instead of staying underneath.
- Player Alternate settings are now available in normal mode; they are no longer locked behind development mode.

### Access

- `/az -> Unit Frames -> Player Alternate` is now visible without `/devmode` when the main Player frame is disabled.

### Internal

- `Layouts/Data/PlayerUnitFrameAlternate.lua`: corrected `AurasPositionAlternate` to a true above-frame anchor.
- `Options/OptionsPages/UnitFrames.lua`: removed devmode-only hide gate for Player Alternate options and kept mutually-exclusive visibility with the main Player frame.


## 5.3.57-JuNNeZ (2026-04-05) — Tooltip Authority & UI Compatibility

### Highlights

- Compare-item tooltips no longer jump between positions while Shift-hovering items. AzeriteUI now delegates compare-tooltip placement fully to Blizzard's built-in comparison manager.
- Fixed chat compatibility with BigInputBox by automatically disabling AzeriteUI chat-frame modifications when BigInputBox is enabled, reducing protected chat-send conflicts.
- Blizzard player castbar is now hidden immediately on reload if already visible, removing the brief post-reload exposure.
- Party frame health percentage text is now centered inside the health bar and styled consistently with the health value text.

### Access

- No new settings required. Reload UI to apply all changes.

### Internal

- `Components/Misc/Tooltips.lua`: removed addon-side compare-tooltip re-anchoring/layout pipeline and retained only modifier gating, suppression, and frame-level handling.
- `Components/Misc/ChatFrames.lua`: added `BigInputBox` to chat-conflict disable guards.
- `Components/UnitFrames/Units/PlayerCastBar.lua`: added immediate `Hide()` during Blizzard castbar suppression when frame is currently shown.
- `Layouts/Data/PartyUnitFrames.lua`: added explicit health-percentage position/typography/color config for centered in-bar display.


## 5.3.56-JuNNeZ (2026-04-05) — Tooltip Stability & Party Frame Fixes

### Highlights

- Compare tooltips for rings, trinkets, and dual-wield weapons no longer oscillate, jitter between wrap widths, or grow/shrink infinitely while hovered.
- Toy box buttons can be clicked directly again while their tooltip is shown.
- Fixed a WoW 12 secret-value taint crash that fired when Blizzard passed secret numeric dimensions into the compare tooltip size-change callback.
- Party frame health text now correctly shows current health value or percent for follower-dungeon AI party members, switching dynamically based on injury state.
- Party unit frames no longer generate `ADDON_ACTION_BLOCKED` errors for `SetSize` during party roster and header updates.
- Target aura refresh in battlegrounds no longer causes excessive per-frame work during rapid target swaps.

### Access

- No new settings required. Reload UI to pick up all changes.

### Internal

- `Components/Misc/Tooltips.lua`: compare relayout cadence guard, size-snapshot guard, suppression window extension, sticky wrap-width hysteresis to stop near-threshold width oscillation, secret-number-safe `OnSizeChanged` size tracking, dedup for repeated tooltip post-hook lines, mouse disabled on managed-tooltip backdrop.
- `Components/Auras/Auras.lua`: aura hover-tooltip dedup via deterministic cache key to reduce repeat `SetUnitAura*` churn.
- `Components/UnitFrames/Auras/AuraStyling.lua`: cached visual-state guards for target aura styling to skip redundant backdrop/icon updates on rapid target swaps.
- `Components/UnitFrames/Units/Party.lua`: removed insecure `SetSize` from secure-header style path; health display now uses dedicated `HealthCurrent`/`HealthPercent` texts with injury-state visibility toggle.


## 5.3.55-JuNNeZ (2026-04-03) — Compare Tooltip Deferred Hook

### Highlights

- Fixed a race condition where compare tooltips that appeared after the initial item-hover pass would not have AzeriteUI relayout hooks attached, causing them to overlap the main tooltip.
- All four compare tooltip frames (`ShoppingTooltip1/2`, `ItemRefShoppingTooltip1/2`) now receive relayout hooks at module startup and on every subsequent compare-show event, regardless of whether they are visible at that moment.
- Added Wago Addons tracking ID to the addon metadata so the addon can be followed directly on Wago.

### Access

- No new settings required. Hover equippable items in bags and item-links repeatedly to verify compare tooltips no longer collapse onto the same anchor.

### Internal

- `Components/Misc/Tooltips.lua`: split `OnCompareItemShow` into a hook-registration pass (all frames) followed by the frame-level adjustment pass (visible frames); added upfront `HookCompareTooltipLayoutUpdates` calls in `SetHooks`.
- `.github/workflows/release.yml`: added optional WowInterface upload step (enabled by `WOW_INTERFACE_TOKEN` + `WOW_INTERFACE_ADDON_ID` secrets).
- `AzeriteUI5_JuNNeZ_Edition.toc`: added `X-Wago-ID` metadata field.


## 5.3.54-JuNNeZ (2026-04-03) — Combined Fix

### Highlights

- Fixed compare-item tooltip relayout edge cases by hardening compare stack anchoring and adding deferred relayout handling after size/show updates.
- Added stronger managed-tooltip filtering so dropdown/menu backdrops are excluded from AzeriteUI managed tooltip treatment.
- Hardened `LibActionButton` cooldown payload handling by sanitizing secret/unsafe cooldown, charge, and loss-of-control fields before `ActionButton_ApplyCooldown`.

### Access

- No new settings required. Tooltip compare behavior and action-button cooldown overlays update automatically.

### Internal

- `Components/Misc/Tooltips.lua`: compare-tooltip wrap-width + relayout queue improvements and safer managed-tooltip detection.
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`: cooldown/charge/loss-of-control sanitization before Blizzard cooldown application path.


## 5.3.53-JuNNeZ (2026-04-03) — The Decursive Compability Anomaly

### Highlights

- Fixed the WoW 12 compatibility path for Decursive so in-combat dispellable detection no longer degrades into false-positive non-dispellable classifications.
- Reworked legacy `UnitDebuff` combat sourcing to prefer Blizzard filtered aura query paths first, with guarded fallback behavior only when those APIs are unavailable.
- Removed addon-side dispel-type coercion experiments from the final runtime path and kept a strict pass-through tuple contract with WoW 12 safety guards.

### Access

- No new settings required. Reload UI and test Decursive dispel detection in combat (`/reload`).

### Internal

- `Core/Compatibility.lua`: finalized WoW 12 Decursive compatibility flow around `UnitDebuff` sourcing, slot-11 `auraInstanceID` tuple compatibility, and guarded fallback behavior.
- `FixLog.md` + `Docs/Decursive Aura Compatibility Research.md`: recorded full anomaly timeline, failed branches, and final resolved path.


## 5.3.52-JuNNeZ (2026-04-02) — Obsidian Tooltip Spacing

### Highlights

- Fixed compare-item tooltip overlap in item hovers where multiple comparison tooltips could collide with the main tooltip.
- Improved tooltip comparison placement so compare tooltips now keep stable spacing even when tooltip content expands after initial show.
- Reduced tooltip skin side effects by limiting AzeriteUI skinning to known managed tooltip frames only.

### Access

- No new settings required. Hover equippable items (especially rings/trinkets) to see the compare-tooltip spacing fix.

### Internal

- `Components/Misc/Tooltips.lua`: added deterministic compare-tooltip stacking with theme-aware gap and post-show/resize relayout hooks.
- `Components/Misc/Tooltips.lua`: added managed-tooltip guard for `SharedTooltip_SetBackdropStyle` path to avoid skinning unrelated tooltip-like frames.


## 5.3.51-JuNNeZ (2026-04-02) — Midnight Stocklight

### Highlights

- Stabilized WoW 12 player-row aura behavior around combat secret-value windows while keeping AzeriteUI stock intent: helpful auras fail open during combat secrecy to avoid flicker/dropouts, then return to mixed bright/dim classification out of combat.
- Improved aura diagnostics for live verification by expanding `/azdebug aurasnapshot` output with best-effort spell ID/name resolution from `auraInstanceID`, making post-combat classification checks far easier to audit.
- Added a new player-row aura option, Always Show Full Brightness, for users who prefer no dimmed icons.
- Completed localization coverage for the new/updated player-row aura menu text across all shipped locales.

### Access

- Player-row stock behavior: `/az` -> Unit Frame Settings -> Player Frame -> Auras -> Use AzeriteUI Stock Behavior.
- Force full-bright icons (optional): `/az` -> Unit Frame Settings -> Player Frame -> Auras -> Always Show Full Brightness.
- Snapshot debug command: `/azdebug aurasnapshot player`.

### Internal

- `Components/UnitFrames/Auras/AuraFilters.lua`: added stable per-aura helper state and secret-window fallback signals for stock-mode player aura filtering.
- `Components/UnitFrames/Auras/AuraStyling.lua`: hardened bright/dim decision path to use stable filter-provided signals and keep stock-intended mixed post-combat behavior.
- `Core/Debugging.lua`: expanded aura snapshot payload with by-instance spell/name resolution and richer visual/timing diagnostics.
- `Components/Auras/Auras.lua` and `Libs/oUF/elements/auras.lua`: additional WoW 12 aura payload guards and refresh hardening on high-churn paths.
- `Locale/*.lua` and `Options/OptionsPages/UnitFrames.lua`: localized and exposed the new player-row brightness controls.


## 5.3.50-JuNNeZ (2026-04-02) — Obsidian Aura Shield

### Highlights

- Hardened WoW 12 aura processing to prevent edge-case script breaks under heavy aura churn. Multiple `C_UnitAuras` calls in the oUF aura element are now fail-closed with guarded fallbacks, so a single bad payload no longer interrupts the entire update pass.
- Improved aura button data reliability by removing deprecated `UnitAura` tuple dependency in the aura component and using a single modern `C_UnitAuras` data source path per slot.
- Restored Decursive in-combat dispel detection behavior while keeping the WoW 12 crash guard: only secret `auraInstanceID` is sanitized in the `UnitDebuff` compatibility wrapper, preserving required tuple semantics for third-party scanners.
- Fixed tooltip anchor hijack on nil-named world map pins by adding a MapCanvas ownership guard (`owningMap`) before custom anchor handling.

### Access

- Aura stability verification: `/buggrabber reset` -> `/reload` -> apply/remove buffs and debuffs rapidly (solo + combat) and confirm no new aura-element stack errors.
- World map tooltip verification: enable tooltip anchoring in `/az` settings, hover world quest/AreaPOI map pins, and verify anchor behavior remains Blizzard-normal.

### Internal

- `Libs/oUF/elements/auras.lua`: wrapped high-risk `C_UnitAuras` calls with guarded fallbacks and added nil-safe dispel color handling.
- `Components/Auras/Auras.lua`: simplified `GetAuraButtonData` to modern `GetAuraDataByIndexSafe`-first flow; removed deprecated tuple path and redundant lookup.
- `Core/Compatibility.lua`: narrowed `UnitDebuff` sanitizer to secret `auraInstanceID` slot only.
- `Components/Misc/Tooltips.lua`: added `parent.owningMap` early-return guard in `SetDefaultAnchor`.


## 5.3.49-JuNNeZ (2026-04-02)

### Highlights

- Fixed a WoW 12 error from Decursive's aura scan (`GetUnitDebuffAll`) where secret boolean values returned by `UnitDebuff` caused hard Lua errors. A narrow sanitizer in the compatibility layer now converts secret tuple slots to `nil` before they reach third-party code.
- Fixed a WoW 12 error in LibActionButton's target-aura cooldown overlay where secret aura timing values were forwarded directly to Blizzard's `Cooldown:SetCooldown`. The overlay now prefers the duration-object API when available and skips the update entirely when timing data is unreadable.

### Internal

- `Core/Compatibility.lua`: added `UnitDebuff` secret-tuple sanitizer wrapper for WoW 12 (wraps once, fails closed, leaves `C_UnitAuras` APIs untouched).
- `Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua`: hardened target-aura cooldown helper to prefer `C_UnitAuras.GetAuraDuration` + `SetCooldownFromDurationObject` when available; plain numeric fallback only when values are confirmed non-secret; skips overlay update when timing is secret.


## 5.3.48-JuNNeZ (2026-04-01)

### Highlights

- Fixed recurring WoW 12 Edit Mode taint on repeated open/close loops while solo. Compact party/arena preview frames are no longer touched by AzeriteUI quarantine paths unless the relevant live group context is active.
- Fixed Blizzard castbar forbidden-table errors during Edit Mode arena refresh by removing AzeriteUI castbar method/mixin mutation guards and keeping castbar handling non-invasive.
- Fixed Edit Mode exit protected-call attribution (`ClearTarget()`) by rolling back EditMode manager registration-table mutation in the guard layer.
- Fixed follower/story raid 25-man frame compaction where layout could collapse into one column when profile fallback state was incomplete; Raid25 now uses a safe multi-column fallback.

### Access

- Reproduce Edit Mode fix: open `/az` settings as usual, then open/close Blizzard Edit Mode repeatedly while solo.
- Raid frame behavior: verify in follower/story raid encounters that 25-man layout keeps expected multi-column spacing.

### Internal

- `Core/FixBlizzardBugs.lua`: context-aware quarantine gating for party/raid/arena preview safety in solo Edit Mode.
- `Core/FixBlizzardBugs.lua`: castbar guard layer converted to no-op to avoid taint-prone Blizzard castbar mutation.
- `Core/FixBlizzardBugs.lua`: EditMode manager registration-table bypass logic disabled after protected-call attribution regression.
- `Components/UnitFrames/Units/Raid25.lua`: hardened `maxColumns` fallback in both header size and child layout calculations.

## Older releases

Entries before `5.3.47-JuNNeZ` live in [CHANGELOG_ARCHIVE.md](CHANGELOG_ARCHIVE.md).
This file is published verbatim as the release description on GitHub, CurseForge, Wago and WowInterface, and GitHub rejects a body over 125000 characters, so older entries are rotated out rather than kept here forever.
