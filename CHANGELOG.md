
# Changelog

## A note on WoW 12.1 addon development

Retail 12.1 protects more combat, aura, cooldown, and unit data as secret values. Addons can often display those values only by handing them directly to Blizzard-owned widgets instead of reading or formatting them, which is why one visual layer may keep working while related text or logic disappears; safe fixes increasingly require narrow ownership boundaries between Blizzard and other addons.

Release note rule: each version entry must include only what changed since the previous release (delta-only).
Do not repeat older items from prior versions in newer entries.
Writing workflow: [Tools/CHANGELOG_GUIDE.md](Tools/CHANGELOG_GUIDE.md). Lead with player benefits, then explain substantial development work and remaining limits.


## 5.44.1-JuNNeZ (2026-11-20) - Player Aura and Party Layout Fixes

### Highlights

- **Long utility buffs can appear in the player aura row again.** At `/az -> Unit Frames -> Player`, turn off **Use AzeriteUI Stock Behavior** and enable **Show Long Utility Buffs** to allow long and permanent buffs through the duration filter. The other aura filters still apply. Thanks to Boghir for the report.
- **Debuffs no longer register right-click cancellation** in the top-right aura display or the native unit-frame aura rows. Buffs retain their existing right-click behavior. The fallback target aura layout applies debuff-type styling only where appropriate.
- **Party-only Raid 25 and Raid 40 layouts respect their five-player footprint.** With party visibility enabled and all raid sizes disabled, these layouts can use a single column.

### Access and known limits

- Verified offline. Live aura visibility, right-click behavior, and party layouts still need confirmation on Retail and Forever.

## 5.44.0-JuNNeZ (2026-11-19) - Group Loot Rolls and Solo Preview

### Highlights

- **See who rolled on group loot.** Enable **Show group loot roll choices** at `/az -> Bags` for counts on the roll buttons. Hover a button to see who chose it. When Transmog takes the Greed slot, its tooltip also lists Greed voters.
- **Give the loot window an AzeriteUI skin.** Enable **Use AzeriteUI loot roll skin** at `/az -> Bags` and reload. The compact rows use your Options panel's appearance, with an optional **Use active class theme for loot rolls** switch for class-theme frame art.
- **Try and place it solo.** **Preview loot rolls** under Bags opens two sample drops with timers and test votes. Use the **Alerts** mover in `/lock` or Edit Mode to see the stack at its saved position and move it.
- **Forever controller chat settings.** Preserve Blizzard's chat font-size list to address the reported input lock when opening a chat tab's settings with Y.

### Development

- The roll display reads Blizzard's loot history and matches it to visible drops. Counts stay hidden when simultaneous identical drops cannot be distinguished reliably.
- Added offline checks for loot-row reuse, layout preview placement, hover names, the native Forever chat settings path, and Chattynator's guild-tab filtering with nicknames enabled or disabled.

### Access and known limits

- The loot skin and roll counts apply to the mouse-and-keyboard loot window. The separate Forever controller loot window uses Blizzard's layout.
- The maintainer exercised the solo preview on Forever during development. Offline checks cover both supported clients. Real group loot events and the Forever Y-menu fix still need live confirmation.

## 5.43.0-JuNNeZ (2026-11-19) - Clearer Party Bars and Guild Manager Improvements

### Highlights

- **Party cast overlays clear in more cases.** The light casting layer clears when a cast or channel ends, including after zoning and when a party slot changes occupants. A new cast starts with fresh progress. The party overlay also has a fallback for missed empower-stop events when the full hold time is readable.
- **Forever controller XP bar.** Blizzard's extra XP bar stays hidden in native controller mode. XP is still shown on the AzeriteUI minimap ring, and Blizzard's native controller buttons keep their functions.
- **Guild Manager is easier to navigate.** Open it from the cog menu, use `/azguild`, or go to `/az -> Guild & Nicknames`. Sort members by name, rank, level, or last online. The overview counters open filtered lists, and unsaved edits can be saved or discarded before changing members.
- **Apply the Details skin from AzeriteUI.** Go to `/az -> Themes -> Details` to apply AzeriteUI Forged (Preview) to your Details windows. Turning the switch off restores the skin each window used before.

### Development

- Party overlays now clear stale cast state at start, stop, expiry and unit reassignment. Regression tests cover missed stop events, rejected timers and the full empower hold with late cast updates.
- The Guild Manager keeps characters grouped under their main while sorting, preserves drafts when changing pages, and adds shared class and rank dropdowns with clear and reset controls.
- The Details switch uses the meter's own skin selector. Details resets custom appearance settings when changing skins, so the switch asks for confirmation.

### Access and known limits

- Offline checks cover Retail and Forever. In-game checks are still pending for the party overlays, controller XP bar, Guild Manager changes and Details switch.

## 5.42.0-JuNNeZ (2026-11-17) - Guild Manager and Native Controller Support

### Highlights

- **Guild Manager (new).** Open it with `/azguild` or `/az -> Guild & Nicknames -> Open guild overview`. **Guild home** shows the message of the day, guild info, emblem and rank counts. **Members** groups characters into people through main/alt links, with favourites, filters (online, class, rank, missing nickname, unlinked), level-range search, private notes, last-online times and Whisper/Invite for the selected online character; offline members are listed in gray.
- **Guild crafting, history and follow-up.** The Guild Manager also has a searchable directory of your own characters' scanned recipes with a manual lookup of guild members who know a recipe, a history of changes AzeriteUI has seen in ranks, public notes, levels and the guild message, and officer follow-up for trial periods, planned absences and tasks with deadlines.
- **Guild note review, backup, sharing and actions.** Note review suggests main/alt links from public notes and saves nothing until you choose. Back up or import your nickname list, or send it to another online guild member, who reviews it before importing. Edit a public note or rank with permission checks and a confirmation that shows the exact change. Officer notes are never read or stored, and nothing is written to the guild without your confirmation.
- **Nicknames in chat with Chattynator.** Turn on **Chat nicknames** at `/az -> Guild & Nicknames` to show your chosen nickname instead of a character's name. Alts use their main's nickname, and each channel type (guild/officer, group, whisper, other) can show the nickname, nickname (character) or the original name. **Show levels with nicknames** adds the speaker's level. Player links still lead to the real character.
- **Native controller support on Forever.** AzeriteUI now follows Blizzard's selected controller interface automatically. Blizzard's controller bars keep every function (pages, modifiers, stance/possess, pet, radial flyouts, target bars, interact/inspect) and now wear AzeriteUI's backdrop and metal button rings. Toggle the look at `/az -> Action Bars -> Native controller -> AzeriteUI button art`. The target menu on the controller's menu button, the Quest Item Button's own keybinding and AzeriteUI's confirmation dialogs (D-pad, accept, cancel, ConsolePort's cursor) work with the controller too.
- **Keep your party frames with the controller.** With **party targeting** on in Blizzard's controller settings, the D-pad targets party members directly and your AzeriteUI party frames stay. Raids use Blizzard's frames for raid navigation.
- **Use Blizzard's bag controls.** `/az -> Bags -> Use Blizzard's bag controls` leaves Blizzard's bag bar, backpack and expand buttons alone after a reload, for controller navigation or another bag addon. Bag sorting, merchant and loot settings keep working.
- **Quest Item Button tooltip and fading.** Hovering the button shows the item tooltip and quest again, and **Only show on mouseover** at `/az -> Action Bars -> Quest Item Button` fades it until you point at it.
- **Legacy theme: levels and cast name.** Under Legacy, `/az -> Themes -> Show levels` puts levels before player, target and party names (on by default, saved per character). The player frame's cast name now starts at the left of the health bar, as in AzeriteUI 3.
- **Alternate player mana text stays visible.** The crystal's current value now shows while spending, at zero and while regenerating, with the correct range. Thanks to saekyz for the pull request.

### Development

- Built the Guild Manager as its own module with one window: navigation rail, options-style casing, and painted controls reused from AzeriteUI's existing button art. Guild text that the game restricts in combat is read after combat; this fixes a reported blocked-action error. Sharing uses addon whispers in small packets, with strict checks on what is received and a review step before import; private notes, favourites, history and follow-up never leave your computer. Chat nicknames use Chattynator's public interface only.
- Researched Blizzard's Forever controller source and ConsolePort before choosing an approach. The controller's buttons are wired to Blizzard's own bars, so AzeriteUI's bars cannot take over their functions safely. The AzeriteUI look is therefore drawn as extra textures on Blizzard's buttons, which follow every size the game gives them, and nothing in the button press path is touched. Party targeting by D-pad needs no frames, which is why your party frames can stay.
- Replaced Blizzard's popup for AzeriteUI's own questions with an owned confirmation service on Forever, so controller buttons pick an answer without triggering a game action at the same time. A held button cannot approve a newer question, and combat never accepts one.
- Selectively adopted proven parts of saekyz's pull request #7 after checking them against Forever and ConsolePort, and added regression tests for guild data, privacy and combat rules, sharing, crafting, controller ownership, party/raid gating, confirmations and the new button art. New text is translated into all ten languages.

### Access and known limits

- Verified offline; only the first Guild Manager version (overview and chat nicknames) has been confirmed in game. Live testing on Retail and Forever is still owed for the newer guild pages, controller behaviour in and out of combat, confirmations, bag controls, Legacy levels and the mana text.
- The Guild Manager depends on what the server sends: last-online times are rounded, crafting lookups can return nothing, and sharing needs both players online. Chat nicknames require Chattynator.
- In controller mode, Blizzard and Edit Mode decide the bars' layout, scale and button count. Your AzeriteUI bar layouts, fading and button shapes stay saved and come back in keyboard/mouse mode. Raid frames always stay Blizzard's in controller mode. With party targeting off, party frames do too. Changing either mode asks for a reload.
- With ConsolePort's bar module or Bartender4 enabled, that addon keeps the bars and the AzeriteUI button art is not applied.

## 5.41.1-JuNNeZ (2026-11-15) - Target Health Colour Fix in PvP

### Highlights

- **Target health colour fix for battlegrounds.** Secret class colours now go directly to the target preview texture, avoiding the status-bar colour setter implicated in the reported **Object did not allow secret** error. Ordinary target colours retain their existing shading.

### Access and known limits

- Verified offline with the real target colour callback, including mixed secret colour components and switching back to readable colours. Battleground combat and native rendering still need maintainer confirmation.

## 5.41.0-JuNNeZ (2026-11-15) - Separate Party Auras and Per-Bar Controls

### Highlights

- **Separate party buffs and debuffs, with independent sizes.** At `/az -> Group Frames -> Party Frames -> Layout & Highlighting`, use **Buff Size** and **Debuff Size** to resize each type independently. Buffs and debuffs now occupy separate areas below the portrait, with their own wrapping. Existing size choices are preserved when upgrading. Thanks to Neil for the request.
- **Hide the portrait debuff icon while keeping its highlight.** **Show Portrait Debuff Icon**, on the same party-frame page, controls the central priority-debuff icon independently of **Glow Frame For Dispellable Debuffs**. You can keep the coloured health-frame highlight without covering the portrait with an icon.
- **Choose range colouring and count text per action bar.** Each bar at `/az -> Action Bars` now has **Show Range Indicator** and **Show Item and Charge Counts**, both on by default. Turn them off for just the selected bar. Cooldown timers remain visible; unusable-action and low-resource colours still apply when range colouring is off. The count switch controls both item quantities and spell charges.
- **Hover nameplate auras for their description.** Buff and debuff icons on nameplates now accept mouseover and use the configured tooltip anchor. The existing tooltip restrictions still apply when the client hides aura information.
- **Death Knight health-frame fitting update (WIP).** The theme at `/az -> Themes -> Death Knight` receives revised health casings and dedicated target variants, fitted around the different player, target and boss fill shapes. Frame placement and functional fill textures are preserved. This is a preview revision, not approval of the complete theme.

### Development

- Split the party's native aura display into disjoint helpful and harmful containers with separate clipping and sizing. Both follow group-member changes and visibility settings without inspecting secret combat aura data. The scanning fallback also separates the two types; old relative debuff sizes initialize the new independent setting.
- Rebuilt Death Knight health rails from the retained original paintings through bounded resampling, with separate target geometry and matching threat halos. Added checks for gaps around the complete fill contour and at actual 1x/2x draw sizes, alongside source-replay checks that reject erased or substituted artwork. Endcap and complete-theme approval remain separate gates.
- Translated the new controls into all ten supported languages. Offline regressions cover independent sizes, separate aura categories, roster reuse, portrait-icon/highlight independence, per-bar isolation and combat-deferred button updates, alongside the existing options and client checks.

### Access and known limits

- Verified offline only. Party layout, tall or vertically arranged groups, combat rendering, tooltips, bar paging, Legacy/Masque appearance and client taint still need maintainer testing on Retail and Forever. No AI-controlled WoW testing was performed.
- Native party debuffs reserve their own area after the buff area, so they do not jump as buffs appear or disappear. Larger icons or extra rows can require more space between custom-positioned frames.
- Death Knight remains a WIP preview. The revised health rails do not approve the endcaps, cast sockets or full theme, and do not establish live visual acceptance.

## 5.40.0-JuNNeZ (2026-11-14) - Forever Nameplate Combo Points and Binding Repairs

### Highlights

- **Combo points on Forever nameplates.** Rogues and Druids in Cat Form can enable **Show Combo Points** at `/az -> Nameplates -> Visibility`. Small Azerite metal sockets and faceted crystals show each enemy's own points, including enemies you are no longer targeting when Forever supplies their count. Blue crystals mark ordinary points; the fifth lights gold. The option is off by default and specific to Forever.
- **Choose a readable combo-point size.** **Combo point size (%)**, directly below the switch, adjusts the row from 50-300% without a reload. Crystals, sockets and their visibility mask resize together, while names and auras move to leave room. Try 150-200% if the original compact size is too small. The size is saved per profile.
- **Pet and stance hover keybinding support.** `/kb` and Blizzard's Quick Keybind Mode now reach pet and stance buttons. Assigning, replacing and clearing bindings updates their labels, using the game's native pet and stance commands.
- **Target castbar fill and interrupt colours repaired.** The readable-progress fallback follows a native bar instead of resizing already scaled geometry. **Color Entire Target Castbar By State** is available again at `/az -> Unit Frames -> Target`; it uses a fresh readable cast/channel interrupt flag and keeps the normal colour when the game hides that information.

### Development

- Built per-enemy combo-point displays around Forever's target-bound API. Secret counts pass directly to native bars; a fill-driven mask hides empty non-target rows without addon comparisons. Transfers, target changes, form changes, death and recycled nameplates refresh the owning unit's data rather than preserving a stale snapshot.
- Extended offline checks for the actual combo-point module, options and name/aura anchors, including resizing and masked counts. Pet/stance bindings and target casts have focused regression coverage; the repaired full mutation suite now runs through the existing client checks instead of stopping at an outdated nameplate test pattern.
- Moved older complete release entries to `CHANGELOG_ARCHIVE.md`, retaining recent notes in game and updating the archive hint in all ten languages. Both packaging paths now check the release-note length before copying or uploading, preventing the earlier oversized-description failure from recurring.

### Access and known limits

- This release was verified offline. Forever's responses for non-target nameplate tokens, mask rendering, combat behaviour, actual key input and client taint still need maintainer testing; no AI-controlled WoW testing was performed.
- Combo points follow the count the game currently assigns to each mob. If Forever returns zero or withholds a non-target count, AzeriteUI clears it rather than inventing retained points. A secret-zero row can hide its artwork but keeps its small layout reservation, which scales with the selected size.

## 5.39.0-JuNNeZ (2026-11-13) - Clearer Settings, Totems and Combo Points

### Highlights

- **Greyed-out settings explain why.** At `/az -> Tooltips`, `/az -> Explorer Mode` and the affected Unit Frames controls, the help line names the setting or addon that makes a control unavailable. The explanation updates as you change settings and is translated in all ten supported languages.
- **Party dispel filters follow what you can remove.** At `/az -> Group Frames -> Party Frames`, **Only Show Dispellable Debuffs** no longer includes effects that only another group member can dispel on the scanning fallback. Boss and role-marked auras follow the party switches, and role-marked target auras match the native target row.
- **Totem visibility follows Blizzard's combat display.** Secret totem slots use Blizzard's own button visibility to distinguish real timers from empty squares. If another addon stops Blizzard's totem updates, AzeriteUI falls back to the slot's own presence instead of hiding new totems from old data.
- **Forever combo points follow the current target.** Rogue and cat Druid point visibility now uses the same target count as the fills, even when the player's power value disagrees. Clearing the target hides the display, and **Show Full Class Power Out of Combat** still controls full-set visibility at `/az -> Unit Frames -> Class Power`.
- **Details Forged fills and text repaired.** The **AzeriteUI Forged (Preview)** skin in Details' skin selector uses a material and mask that work with native bar progress, removes inherited spec icons, centres its title and gives values more clearance from the right edge. Damage Done shows the primary total; DPS views retain their primary rate.

### Development

- Replaced Forever's player-power visibility curves with target-count-fed masks. Regression checks cover the first layout after reload, target switches, empty slot backings, full-set fading and returning to readable counts without inspecting secret values.
- Compared the totem pool with Blizzard's secure pool implementation and tested the read-only post-hook in Elune. Added fallback checks for addons that unregister Blizzard's updates. This tests a reduced Lua security model rather than the game engine.
- Reworked the Details fill into a source-verified material tile and a separate full-coordinate functional mask. Integration checks run installed Details formatting and row layout code, including skin switching, title dragging and forwarding already formatted secret values unchanged.
- Kept disabled explanations outside the settings tables so the custom panel and both older options dialogs remain compatible. Offline checks cover reason precedence, refresh, translations and the real Retail/Forever option pages.

### Access and known limits

- New totem, combo-point, aura and settings behaviour is verified offline; in-game combat, taint, visuals and click-through still need maintainer confirmation on Retail and Forever.
- Details' repaired fill was confirmed in game during development. The final title placement, primary-value selection, resizing and skin-switching changes still need live review; Forged remains a preview.
- On Forever, lit secret combo points retain a half-opacity dark slot rim; their lit casing and fill remain bright. The complete mutation suite still stops at an unrelated outdated nameplate test pattern; the targeted regressions pass.

## 5.38.0-JuNNeZ (2026-11-13) - Class Themes, Quest Items and Threat Roles

### Highlights

- **Death Knight, Priest and Warlock themes to try.** Choose them at `/az -> Themes` for new health and cast casings, portraits, resource art and matching interface details. Each has its own health and cast ornaments and resource effects. All three ship as WIP previews.
- **A quest item button in AzeriteUI's own style.** At `/az -> Action Bars -> Quest Item Button`, choose tracked quests, zone and distance limits, and whether it borrows the Extra Action Button key. Move it with `/lock` or bind it with `/kb`. It also handles quests without a map position, including Monty's Rat Catcher's Flute. With ExtraQuestButton enabled, choose which addon should own the feature.
- **Healer and DPS threat modes join Tank mode.** `/az -> Nameplates -> Threat roles` offers automatic or manual roles, threat percentages, a warning threshold, group/dungeon/always scope, selectable sounds and optional screen flash, plate pulse and warning text. Tank percentages show the closest group member's threat while you hold a mob, or your own share when recovering it.
- **Let Masque skin the bars, and give Details matching artwork.** With Masque loaded, enable **Let Masque skin the buttons** at `/az -> Action Bars`, then reload to register action, pet and stance bars. In Details' own skin selector, choose **AzeriteUI Forged (Preview)** for the new painted header, angled row casings and faceted class-coloured fills, with quiet toolbar buttons.
- **Quest progress and optional everyday helpers.** Nameplates show objective counts beside the quest marker and can hide the marker when all objectives are done. `/az -> Bags` adds auto sell junk, auto repair with optional guild funds, and fast loot, all off by default. Repair can wait for the junk sale's gold. WoW Forever also gains a layer number on the Info Bar.
- **Fixes for bags, party frames and menus.** Bag slots keep their visibility and placement after swapping bags or dragging items; friendly name-only plates retain raid markers; stale party cast overlays clear. Empty totem squares are removed, Game Menu conflict choices persist, and party aura switches correctly separate your short buffs, raid buffs and dispellable/boss debuffs. Legacy hides player-art options it cannot use, Explorer Mode clarifies overlapping settings, and the XP ring respects the game's XP-bar disable rule.

### Development

- **Built complete class-theme packs and their fitting tools.** The new paintings are registered to native frame geometry, with theme-specific ornaments, tooltip/aura atlas assembly and offline layout checks. Priest and Warlock retain the maintainer's narrowly scoped 10-pixel fit exception; this does not establish live visual approval. Themes now also have navigation icons for their new sections.
- **Kept optional integrations within their owners' systems.** Masque receives registered button groups while AzeriteUI retains bindings and labels. Details keeps its combat data and window positions; the skin supplies painted media, an owned decorative header and masks that keep native fills inside the angled row casings. The quest button updates protected item attributes outside combat and yields its borrowed key to Blizzard's extra action.
- **Expanded regressions around the reported failures.** Offline checks exercise native bag relayout and combat deferral, cast expiry, aura-filter combinations, role detection and secret threat values, merchant sequencing, optional-addon load order and theme layout preservation. The options test stubs now include the addon-title helper used by the quest-button page.

### Access and known limits

- Quest objective counts and the friendly name-only raid-marker repair were confirmed on WoW Forever during development. The remaining changes still need maintainer testing in game on Retail and Forever; offline widgets cannot certify rendering, secure clicks, performance or client taint.
- Details Forged is a selectable artwork preview; assembled fit, skin-switch cleanup and combat rendering still need live confirmation.
- Death Knight remains a preview with failed production fitting/source gates. Priest and Warlock use the exact scoped fitting tolerance recorded during development. All three need complete assembled visual review in game.
- Threat text and alerts stand down when the game hides the required information. Forever's automatic healer detection, tank percentages and alert effects still need live confirmation.
- The layer display is inferred from readable NPC GUIDs outside combat and instances; two different NPCs must agree before it changes. Quest items without a map position are a fallback and are excluded by the zone-only filter. Masque proc highlights retain AzeriteUI's selected button shape.


## 5.37.3-JuNNeZ (2026-11-07) - Druid Mana Crystal on Forever

### Highlights

- **Druids on WoW Forever see their mana in Bear and Cat Form again.** The small secondary mana crystal beside the player power crystal never appeared on Forever. It now shows while you are shapeshifted and your mana is below full, and fades out at full mana, as on Retail. It can still be moved with `/lock` ("Player Secondary Mana Crystal").

### Development

- **Forever's own resource pairs.** The crystal followed Blizzard's list of which resources come with a second mana bar. Forever ships Retail's list (Astral Power, Insanity, Maelstrom), and none of those exist in Forever's classic content, so the crystal was always hidden. On Forever, AzeriteUI now pairs a Druid's Rage and Energy with mana itself. Retail still uses Blizzard's list.

### Access and known limits

- Confirmed in game on Forever in Bear Form, including moving it with `/lock`. Cat Form uses the same path but has not been checked in game yet.


## 5.37.2-JuNNeZ (2026-11-07) - Bag Addon Fixes and Readable Mana Text

### Highlights

- **W2UI's bag button shows again.** With W2UI's **Bag Buttons** module on, its backpack button and bag slots were invisible while AzeriteUI was enabled. AzeriteUI now leaves them to W2UI. AzeriteUI's own bag button (`/az -> Action Bars -> Micro Menu -> Show Bag Button`) still works beside it and opens W2UI's bags. Thanks to Luciful for the report.
- **No more invisible bag tooltips in the lower right.** With BetterBags, Baganator, AdiBags, ArkInventory, Bagnon, Combuctor or W2UI Bags, Blizzard's hidden bag slots still caught the mouse and showed bag tooltips over empty screen. They are now hidden properly.
- **Mana and power values above Lite+ effects.** With a Lite+ orb or crystal effect on (`/az -> Themes`), the effect was drawn over the mana or power value. The numbers now sit on top.

### Development

- **Read from the other addons' newest source.** W2UI 3.0.10 builds its bag bar from Blizzard's own bag bar, backpack button and bag slots, which AzeriteUI had been hiding. AzeriteUI now asks W2UI whether that module is on and stands aside while it is. The other six bag addons were checked the same way: none of them uses Blizzard's bag slots, so hiding the slots costs them nothing.

### Access and known limits

- Checked offline only so far, not yet confirmed in game.


## 5.37.1-JuNNeZ (2026-11-07) - Quick Keybind Mode on AzeriteUI Bars

### Highlights

- **Blizzard's Quick Keybind Mode works on AzeriteUI's action bars.** Open it from the Game Menu at `Options -> Keybindings -> Quick Keybind Mode`, hover one of our action buttons and press a key, mouse button or mouse wheel to bind it. Escape clears the button's binding. Blizzard's **Okay** keeps the new bindings and **Cancel** undoes them, as for Blizzard's own bars. Before, hovering our buttons in this mode did nothing.

### Development

- **Built on the binding tool the bars already use.** Blizzard's mode only reacts to Blizzard-built buttons, and wiring our buttons into it directly would let addon code interfere with Blizzard's keybinding and settings windows. Instead, while Blizzard's window is open, AzeriteUI runs the same binding mode as `/kb`, without its own window, and gives it the key pressed over our buttons first. Blizzard's windows are left untouched.

### Access and known limits

- Covers action bars 1-8. The pet and stance bars are not covered yet. They also cannot be bound with `/kb`, so use the game's Keybindings list for those.
- Checked offline only so far, not yet confirmed in game.


## 5.37.0-JuNNeZ (2026-11-07) - Tank Tools and Friendly NPC Names

### Highlights

- **Names only for friendly NPCs, with their title.** Turn on **Use names only for friendly NPCs** at `/az -> Nameplates -> Friendly NPCs` and friendly NPC nameplates show just their name in green, without a health bar. **Show NPC titles** (on by default) adds the line under the name, such as `<Innkeeper>` or `<Flight Master>`. The name size follows the friendly name size sliders under Friendly Players.
- **Tank mode for nameplates.** While you tank, threat colours mean something for a tank: mobs you hold stay calm, a mob about to be pulled from you warns, a mob someone else has stands out, and a mob held by another tank has its own blue. A mob you do not hold shows the name of the player it is attacking under its health bar, and an optional sound warns you when you lose a mob to someone who is not a tank. By default it turns on in a group when you have the Tank role or a tank specialization, or are in Bear Form, Dire Bear Form or Defensive Stance. Settings are at `/az -> Nameplates -> Tank mode`.
- **Threat percent on the target frame.** In a group, your threat on the target shows beside its name: 100% while you are tanking it, otherwise your share of the tank's threat. Switch it at `/az -> Unit Frames -> Target -> Show Threat Percent`.
- **Class colours for player nameplates, now with switches.** **Class colors for enemy players** (on, as before) and **Class colors for friendly players** (new, off) are at `/az -> Nameplates -> Colors`. Players whose class the game hides in PvP are now class coloured too, on nameplates and on the target, focus, target of target, party and raid frames.
- **Stance bar: one click, one form.** Clicking a form on the stance bar could enter it and leave it again straight away, because the click cast on both press and release. It now casts once, for clicks and for stance keybinds. Thanks to mariuschiarel for the report.
- **Import: Accept works after pasting.** At `/az -> Export & Import`, the Accept button stayed disabled after you pasted a settings string. It now enables a moment after you paste.

### Development

- **Threat read the way the game allows.** Tank mode and the threat percent read the game's threat and role answers, which can be secret values in restricted content. Each answer is checked before it is used, and the features simply stand down when the game hides them, falling back to the plain threat colours. The offline tests feed them hidden threat, hidden roles and hidden names to prove nothing breaks.
- **Hidden PvP classes, done as other nameplate addons do.** When the game hides a player's class, AzeriteUI now hands it to the game's own class colour lookup instead of giving up, the same approach Plater and Platynator use. The bundled unit frame library got the same fix that upstream oUF made. Hidden classes therefore get Blizzard's class colours, a slightly different shade from AzeriteUI's.
- **NPC titles come from the tooltip.** No game function returns an NPC's title, so it is read from the second line of the NPC's tooltip, skipping the level line, and remembered per NPC for the session.

### Access and known limits

- **Confirmed in game on WoW Forever:** names only for friendly NPCs and their titles. Not yet checked on Retail.
- **Checked offline only:** tank mode, threat percent, the class colour switches and hidden PvP classes, the stance bar fix and the Import fix.
- Tank mode, mob target names and threat percent stay off where the game keeps threat information secret.
- In dungeons and raids the game draws friendly nameplates itself, so names only for friendly NPCs does not apply there.
- Name-only NPCs do not show the quest marker, as with name-only players.


## 5.36.0-JuNNeZ (2026-11-06) - Hex Buttons and Lite+ for Every Class

### Highlights

- **Hex action buttons.** A new **Hex** choice joins Circle, Rounded and Square under `/az -> Action Bars -> Action Bar N -> Button Shape`, on the pet and stance bars, and for extra buttons under Extra Button Shape. Each class theme has its own painted hex rim (Hunter wood, Mage obsidian, Paladin silver and gold, Druid bark, Warrior leather, Rogue steel, Shaman copper), and the plain theme has dark gunmetal. Reload after choosing it. Circle stays the default, and Legacy ignores the shape.
- **Lite+ crystal and orb effects for every class (WIP).** New animated materials at `/az -> Themes -> Lite+`, three per class: Warrior (Forge, Valarjar, Battleheart), Rogue (Venom, Shadow, Nightblood), Shaman (Tides, Magma, Storm), Death Knight, Demon Hunter, Priest, Warlock, Monk and Evoker. Hunter now has a crystal effect, Mage has an orb effect, and Druid's Wildheart, Moonvein and Dreamsap also work on the orb. Each one has its own strength slider for the crystal and the orb, and they react to moving, mounting and combat.
- **Legacy: the mana bar no longer disappears in combat.** Under the Legacy HUD, the player's mana bar vanished as soon as combat started and often stayed gone afterwards. It now stays visible. This affected every mana user, on Retail and Forever. Thanks to Kgaa316 for the report.
- **Empty action slots show while you drag an action off a bar.** With Show empty buttons off, the empty slots appeared when you dragged a spell out of the spellbook, but not when you picked an action up off a bar. Now they appear for both.
- **WoW Forever fixes.** Right-clicking the minimap no longer raises an error, and its tracking menu opens again. Class power click-through should now let clicks pass through even when a click-casting addon such as Clique turns the mouse back on.
- **TacoTip tooltips: no second border.** With TacoTip enabled, a grey inner border sat inside our tooltip border and squeezed the health bar. It is hidden while AzeriteUI styles the tooltip and comes back when you turn our styling off. Our health bar texture is kept as well.

### Development

- **Original hex artwork, painted to one shared size.** The rims were painted for this release around a mathematical hex guide, with each class theme's existing materials as references. They are not taken from another skin. Every rim was then measured to the same height and a border thickness within about one pixel, and the build fails before replacing any art that misses those limits. Icon size was reduced after feedback that the first version looked too zoomed in.
- **A shared engine for the new Lite+ materials.** One provider drives all the new class materials. It draws inside the game's own resource fill and mask, so it never reads your power values, and it follows secret combat values without breaking. Effects that are hidden or set to zero stop updating entirely. Previews of each effect were rendered from the real Lua code at full, half and empty resource before shipping.
- **Root causes, not workarounds.** The Legacy fix stops a layering change meant for the Azerite orb from running under Legacy. The empty-slot fix asks the action button library whether a drag is in progress before hiding a slot. The Forever minimap fix gives our hidden tracking button the parts Forever's updated Blizzard code now expects.

### Access and known limits

- **All of this is checked offline only.** Hex buttons, the new Lite+ effects and the fixes still need to be confirmed in game on Retail and Forever.
- **The new Lite+ effects are previews (WIP)** and may still be repainted. Hex rims are painted separately per theme, so light and reflections differ slightly between them.
- The class power click-through cause on Forever is not yet proven in game. If clicks are still caught, please send a `/fstack` screenshot.


## 5.35.1-JuNNeZ (2026-10-31) - Blizzard Raid Bar Stays Hidden

### Highlights

- **Blizzard's raid bar stays hidden when you turn it off.** With **Show Blizzard Raid Bar** off at `/az -> Group Frames`, the bar could come back on every map change while your group was listed in the Premade Group Finder, until you switched the option on and off again. It now stays hidden, and the option is the only thing that decides. Thanks to Luciful for the report.

### Access and known limits

- If the game shows the bar during combat, it stays visible until combat ends, because it cannot be hidden safely before then.
- Checked offline only so far, not yet confirmed in game.


## 5.35.0-JuNNeZ (2026-10-31) - Raid Panel, Rogue and Shaman

### Highlights

- **A raid and party panel of AzeriteUI's own.** It shows member and role counts, raid group filters for AzeriteUI's large raid frames, target and ground markers, ready check, role check, a 10-second countdown, all assist, party/raid conversion, difficulty and ping permission menus, and leave buttons. It is on by default for grouped players, sits folded out at the left edge and moves with `/lock`. Settings are at `/az -> Group Frames -> Raid / Party panel`; `/azraidtools` previews it. Actions you have no rights for are disabled. Thanks to Luciful for the request.
- **Target markers lite: a small separate marker bar.** Off by default, and it works with the full panel switched off. Choose which markers it shows and in what order, as a row, a column or two rows. Left-click sets a marker, Shift-click sets a ground marker and the clear button removes all target markers, or all ground markers with Shift. Settings are at `/az -> Group Frames -> Target markers lite`; `/azmarkerlite` previews it once enabled.
- **Rogue theme (WIP): Venom & Steel.** Choose it at `/az -> Themes` or with `/azrogue on`. Health endcaps are Twin Guard, Serrated, Venom Vial or None, with a separate Venom Vial or None choice for the cast bar.
- **Shaman theme (WIP).** Choose it at `/az -> Themes` or with `/azshaman on`. Health endcaps are Maelstrom, Tides, Lava Totem or None, with a separate Ancestral Totem or None choice for the cast bar.
- **Something extra.**

### Development

- **The raid panel keeps Blizzard's panel out of it.** Markers use the game's own secure button actions, with no custom secure code and no changes to Blizzard's raid panel. Changes made in combat wait until it ends, and group administration is never replayed automatically. New steel and gold panel artwork was painted to match the toolbar, and all ten languages are translated.
- **Theme work focused on fit.** Both themes went through repeated in-game review and repainting of their casings, buttons and crystal holders, and the shared art checks now also verify source images and how crystal casings seat. Both also work with Lite+ crystal and orb mixes.
- **Crystal and orb casings stay in front.** Live testing showed the game lowering these casings during resource updates, so they now return to the correct layer afterwards, waiting for combat to end if needed.

### Access and known limits

- **Rogue and Shaman are unfinished previews.** Rogue's art still fails our own fit checks and its latest repair has not yet been seen in game. Some Shaman endcaps are earlier paintings that were never approved as final. Expect visible seams and further repainting.
- **The raid panel's look has had in-game review, but real marker clicks, administration actions and taint checks are not yet confirmed in game.** Target markers lite and everything on WoW Forever have been checked offline only.
- If you prefer Blizzard's own tools, switch the panel off on its options page.


## 5.34.1-JuNNeZ (2026-10-25) - More Consistent Tooltip Borders

### Highlights

- **More addon tooltips use the AzeriteUI border**, including world-map icon tooltips that use Blizzard's shared tooltip styling. Previously, only a fixed list of known tooltips received the skin. Thanks to Luciful for the report.

### Development

- **Broader coverage with exceptions for sensitive frames.** Compared other UIs' approaches before extending the existing styling hook. Embedded tooltips, forbidden frames and dropdown menus remain excluded. Offline tests cover addon tooltips appearing later, theme changes and restoring their original border when AzeriteUI tooltip styling is switched off.

### Access and known limits

- **Checked offline only; in-game rendering and taint checks on Retail and Forever are still needed.** Addons that draw their own tooltips without Blizzard's shared styling may still need separate support. MapNotes coverage has not yet been confirmed in game.


## 5.34.0-JuNNeZ (2026-10-24) - Hide the Activity Button

### Highlights

- **WoW Forever, China realms: hide the Activity button on the minimap.** The clock button on the left of the minimap (活动) opens Blizzard's event web page. Tick `/az -> Minimap -> Hide Activity Button` to remove it; untick it to bring it back where it was. It is off by default and only listed on the China client. Thanks to Dcryfm for the request and the /fstack.

### Development

- **Built from Blizzard's own code and other UIs.** Forever's minimap code shows the button only while there is an event link, which in practice means the China realms. ElvUI, QUI, EKMinimap, RealUI and EllesmereUI were checked first; AzeriteUI hides it the way ElvUI does, by moving it into a hidden frame, so Blizzard showing it again for a new event does not bring it back. A new offline test covers hiding, restoring, other regions and combat.

### Access and known limits

- **China realms on WoW Forever only.** The same hiding was confirmed in game on a China client with a one-line test command; the switch itself has not yet been tried there.


## 5.33.0-JuNNeZ (2026-10-24) - Hide the Day and Night Indicator

### Highlights

- **WoW Forever: hide the day and night icon on the minimap.** Until now, turning off `/az -> Minimap -> Day and Night Indicator` only swapped AzeriteUI's icon for Blizzard's. The new `/az -> Minimap -> Hide Day and Night Indicator` removes both, so the minimap ring stays clear. It is off by default, and the Day and Night Indicator switch is greyed out while the icon is hidden.

### Development

- **Hidden without breaking Blizzard's icon.** Blizzard's own indicator is made invisible rather than removed, so Edit Mode and the day/night change keep working underneath, and switching the option off brings back whichever icon you had chosen. The offline test for the indicator now covers hiding, including when the game cannot say whether it is day or night.

### Access and known limits

- **Forever only**, as Retail has no day and night cycle. Checked offline only; not yet confirmed in game.
- The switch is on the Minimap options page only, not in the frame settings that open when you click the minimap in `/lock`.


## 5.32.2-JuNNeZ (2026-10-24) - World Map Without Blocked Actions

### Highlights

- **No more "AzeriteUI tried to call a protected function" when you open the world map in combat.** AzeriteUI centres the large world map. With some addon combinations the game protects the map during combat and blocks that move. AzeriteUI now leaves the map where the game puts it, near the top of the screen, and centres it when combat ends. Without such an addon nothing changes, and the map still centres in combat. Thanks to the player who sent the BugGrabber report.
- **Turning the World Map option on or off no longer shrinks the open map twice.**

### Development

- **Every map move and resize checked, not only the one in the report.** Opening, maximizing, minimizing with the quest log, changing the UI scale and switching the option on or off all wait out combat when the map is protected, then apply what they skipped. A resize of an open map waits until the map closes, so the map is never drawn at the wrong size.
- **A new offline test** loads the real module against a world map that follows Blizzard's own code for opening, maximizing and closing, and fails whenever a call would be blocked in combat.

### Access and known limits

- **Checked offline only.** The fix has not yet been confirmed in game. Which addon protects the map in combat is still unknown.


## 5.32.1-JuNNeZ (2026-10-24) - Queue Eye Without Blocked Actions

### Highlights

- **No more "AzeriteUI tried to call a protected function" from the queue eye.** While you were in a queue, a change of action bar in combat (a vehicle, a quest or encounter bar, a form change) made Blizzard move the queue eye, and AzeriteUI's attempt to put it straight back on the minimap was blocked. It now waits until combat ends, so for the rest of that fight the eye can sit where Blizzard put it, near the bottom right of the screen. Thanks to the player who sent the BugGrabber report.

### Development

- **Compared with other UIs first.** ElvUI, FeelUI, GW2 UI, DiabolicUI, Bartender4 and Dominos all move the queue eye too, and none of them waits out combat. From ElvUI we took the check that skips the move when the eye is already in place.

### Access and known limits

- **Checked offline only.** The fix has not yet been confirmed in game.


## 5.32.0-JuNNeZ (2026-10-23) - Object Names Your Way, NPC Plates on the V Keys, and a Forever Sweep

### Highlights

- **Show object names, if you want them.** Since 5.31.4, gathering nodes, chests and other objects only show a name when the game's own settings ask for one, which usually means never. If you liked having them, `/az -> Nameplates -> Visibility -> Show object names` brings them back on mouseover, as your interact target or as your target. It is off by default.
- **Friendly NPC plates can follow the V keys.** On Retail and WoW Forever, Shift+V and Ctrl+V only switch friendly *player* plates, so vendors and quest givers stayed up. Tick `/az -> Nameplates -> Game settings -> Friendly NPCs follow Friendly players` and the NPC plates switch with them, as they do on Mists of Pandaria Classic. V (enemies) is unchanged.
- **WoW Forever: object names really are hidden now.** On Forever, 5.31.4 still named every object, because the "always show names" setting was applied to objects there, which the default plates never do. Thanks to Dcryfm and Luciful for the reports and readouts.
- **WoW Forever: totem timers.** Shamans and anyone with totem-slot summons get the totem row above the cast bar with countdowns, as on Retail. Forever's own totem bar only casts totems and never showed their time left.
- **WoW Forever: crowd control and roots on auras.** Polymorph, Sap, Fear, Entangling Roots, Shackle Undead, interrupts, immunities and the rest are now recognised by the ranks Forever actually uses, including Forever's new spells such as Chastise, Confounding Flash, Counterattack and the spider pet's Web.
- **Smaller fixes on both clients.** On Forever, the execute marker waits until you have learned Execute or Hammer of Wrath, and the Retail-only "Show while skyriding" bar option is gone. On both clients, the minimap's tracking button is styled again, Bartender4 keeps its queue eye, and Blizzard's alternate power bar (used by some encounters and quests) no longer risks missing its first appearance after login.

### Development

- **A sweep for one kind of mistake.** The object-name bug came from a flag that means "the modern engine" (true on Retail and Forever) being used as "Retail only". Every place in the addon that checks which client it runs on was reviewed against Blizzard's own Retail and Forever interface code, and each claimed problem was checked again by hand before fixing. That found the missing Forever totems, the skyriding option and a minimap override that had quietly replaced the real one. It also made Forever detection fall back on Forever's own project ID, not only the TOC marker.
- **Forever spell data from Forever itself.** The aura lists and execute ranks were checked against Forever's own game tables (spells, spell effects and what each class can learn), not Classic Era lists or memory. That showed that Forever adds new class spells and lacks a few Classic ones, and that Forever's Shadow Word: Death has no health limit, so it is not an execute.
- **Tests that run as Forever.** Several offline tests had been "pretending" to be Forever with flags the real client never has, so they passed while the bugs were there. They now use Forever's real flags, and the options tests can run as either client. New tests cover the aura lists and execute ranks per client.

### Access and known limits

- **Confirmed in game on the WoW Forever stress test:** hidden object names, Show object names, and Friendly NPCs follow Friendly players with the V keys.
- **Checked offline only:** Forever totem timers (and whether they overlap Forever's own totem bar), crowd control on Forever auras, the Forever execute marker, the minimap tracking button and Bartender4 queue eye, and the alternate power bar after login.


## 5.31.4-JuNNeZ (2026-10-23) - Object Names Follow the Game's Settings

### Highlights

- **Interactable objects are only named when the game would name them.** Nodes, chests and other objects showed their name on hover or when you were close enough to interact, even when the game's own name settings hide object names, so the names appeared only with AzeriteUI enabled. Names now follow the same game settings as the default nameplates, including "always show names" on Retail. The interact icon still shows. Thanks to Luciful for the report.

### Development

- **Object plates now ask the game the same question Blizzard's plates do** before drawing a name, on both Retail and WoW Forever. If the game gives no answer, the name still shows as before. The nameplate tests cover hovering and interacting with an object when the game names no objects, and Retail's "always show names".

### Access and known limits

- Checked offline only. In-game confirmation is still owed on Retail and WoW Forever, including with NodeSight installed.


## 5.31.3-JuNNeZ (2026-10-23) - Clearer Light Options and Missing Icons

### Highlights

- **Light options are easier to read.** Under `/az -> Settings -> Appearance`, Light now uses clean text without the dark shadow or outline, sharper page and section icons, and stronger contrast for labels and help text. Changing themes updates fonts and icons in the open window. Text sizes, layout and your settings stay the same.
- **The missing options icons are filled in.** Class themes and Lite+ effects, Player (Party Style), Totems, enemy castbars, Names and Smooth bars now have matching navigation icons. Header-based sections and the Settings tab also have their missing icons, using the same recolourable style as the rest of the window.

### Development

- **Light has its own rendering of the shared artwork.** The icon shapes are preserved, with the thick dark rim and blurred shadow removed for light backgrounds. Options use their own font copies, so the cleaner Light style never changes the HUD's fonts. Tests cover icon coverage on both clients and repeated theme switches on existing text and icons.

### Access and known limits

- Checked offline on Retail and WoW Forever option tables. In-game text, icon sharpness and theme switching still need confirmation after `/reload`, including at small and large Panel Scale settings.


## 5.31.2-JuNNeZ (2026-10-23) - Panel Scale on First Open, No Bars on Forever Objects

### Highlights

- **Panel Scale works the first time you open the options window.** `/az -> Settings -> Window -> Panel Scale` was only applied from the second time you opened the window after a login or `/reload`; the first time it always opened at 100%. It now opens at your scale straight away, in the place you left it. Thanks to BrickHigh (Firo) for the report and for pinpointing the cause.
- **The options window always fits on the screen.** At a large Panel Scale the window could be taller than the screen, leaving the bottom row and some tabs out of reach. It now shrinks to fit and moves back on screen when needed. Your saved size returns at a smaller scale.
- **No more health bars on benches, barrels and other objects on WoW Forever.** Some objects, often with NodeSight installed, still drew a green health bar with a random number under the name. The number was the health of an NPC whose nameplate had been reused. These plates are now set up as objects every time. Thanks to Dcryfm and Luciful for the reports and readouts.

### Development

- **Tracking down the object bars took several live readouts.** Three plausible fixes passed the offline tests and failed in game before the cause was found. Forever says object units do not exist, and when the game also reports them as not visible, the nameplate library skips its whole update. The reused plate then kept the previous creature's bar and value. AzeriteUI now sets such a plate up itself. The nameplate tests now copy the library's real check and cover a reused plate that still shows an old bar.
- **New debug readouts** (debug companion only): `/azdebug nameplates` shows how each plate was classified and how often it was hidden and shown, and `/azdebug playerframe` reports the player frame's state, for a separate report of the player frame disappearing after release (not yet explained).

### Access and known limits

- The first-open scale is confirmed in game on Retail; the fit to screen and the Forever object fix are checked offline only.


## 5.31.1-JuNNeZ (2026-10-21) - Health Percent Clear of Every Endcap

### Highlights

- **The health percent is readable in every class theme.** In the Hunter, Mage, Paladin and Druid themes, the player and target health percentage sat under the weapon, staff, relic or antler endcap. It now moves just clear of the cap, as it already did in the Warrior theme, and follows the cap when you change its size or position under `/az -> Themes`. With the endcap set to None it returns to its usual place. Screen resolution made no difference: 1080p and 4K were equally affected.

### Development

- **One shared placement for every theme.** The Warrior theme's text placement moved into the theme engine, and each theme now gives it the measured left edge of every endcap painting for each health-bar size. Tests check the gap on player and target at each theme's default endcap size, and that None and small bars put the text back. Each new check was confirmed to fail without the fix.

### Access and known limits

- Checked offline only; not yet confirmed in game.


## 5.31.0-JuNNeZ (2026-10-21) - Warrior Theme, Smarter Enemy Castbars, Totem Timers

### Highlights

- **Warrior theme (WIP).** Pick **Warrior** under `/az -> Themes`, or type `/azwarrior on`. It reskins the casings, orb, crystal, minimap ring and other frame art in Skyhold iron and Valarjar leather. The health bars get your choice of **Strom'kar**, **Warswords** or **Wrath Rivet** as an endcap, or **None**, and the cast bar gets a Valarjar head. Each has its own size, X/Y and reset controls. The health percent moves clear of the endcap.
- **Enemy castbars tell you more.** Enemy nameplate castbars now show who the spell is aimed at, in that player's class colour. A red glow means the cast is aimed at you, and an ember glow marks casts the game flags as important. Each has its own switch under `/az -> Nameplates -> Enemy castbars`.
- **Quest marks and name rules on nameplates.** Units that belong to one of your active quests get a quest mark beside the health bar (`/az -> Nameplates -> Visibility -> Mark quest units`). It makes way for a raid marker. The new **Names** section sets how friendly and enemy players and NPCs are named: as now, full, or abbreviated ("M. Dughan"). On WoW Forever you can also show players by first name only. Separate rules can apply in cities, the open world, dungeons, Mythic+, raids, battlegrounds and arenas.
- **Totem, statue and ghoul timers on Retail.** Hiding Blizzard's player frame also took away its totem bar, so a Shaman's totems, a Monk's statue and other totem-slot summons had no icon or timer. A small row of icons with countdowns now sits above the cast bar. Move it with `/lock` ("Totems") and turn it off under `/az -> Unit Frames -> Totems`.
- **Group frames and WoW Forever extras.** The 6-25 and 26-40 raid frames glow in the debuff's colour when you can dispel it, like party frames, with a switch for each raid size. On WoW Forever, raid frames show the master looter, hunters get a thin pet experience bar under the pet frame, and `/az -> Unit Frames -> Cast Bar -> Show the game's swing timer` turns on Forever's own swing timer.
- **Works with NodeSight, and no outline on objects.** With NodeSight's sparkles turned on, the nearest gathering node got AzeriteUI's name, interact icon and a green outline the size of a health bar. AzeriteUI now stands back on its own, as NodeSight already makes Blizzard's plates do: the sparkles show, and hovering a node still shows its name. Tick NodeSight's "Keep the game's icons" to have the name and icon back. Object plates no longer draw the bar-shaped outline at all. Thanks to Dcryfm for the report.
- **Fixes.** The game's self-cast and focus-cast modifier keys now work on AzeriteUI's action bars. Arena preparation frames no longer error on the hidden opponent spec in 12.1.5. Unit frames are no longer built twice at login. Hunter, Mage and Paladin endcaps have per-weapon default sizes and positions measured in game; **Reset endcap size and position** applies them and keeps your own nudges until you do.

### Development

- **The Warrior theme was produced and fitted to the same standard as the other class themes.** 77 textures cover thirty native casings, meter layers, three endcap paintings across four health-bar tiers, a cast head and threat halos. Each endcap fully covers the end of the casing without growing past an agreed size limit. Leather wraps and rivets that cross the fill stay in front of it. Later rounds repainted the caps, fitted the cast head to its socket at 100%, quieted the iron rails and replaced the minimap ring with one painting centred on its rim. Every step has numerical checks plus a separate visual review of complete bars at 1x and 2x. The health percent fix reads the anchor each frame recorded, because the game hides the text's own position while it shows a protected health value.
- **Castbar, quest-mark and totem features were built around 12.1's hidden values.** A cast's target, whether you are its target, and whether the spell is important all reach AzeriteUI as values it is not allowed to read. They go straight to the text, colour and glow widgets untouched. The totem element follows upstream oUF 14, which hands Blizzard's own duration object to the timer, and an empty slot clears its countdown. Dedicated tests feed these features protected values that raise an error if compared, and cover the quest mark giving way to raid markers.
- **A peer UI audit turned into fixes.** Comparing AzeriteUI with other UI packs found the missing self-cast attributes, the arena spec error, the double unit frame build, a tutorial acknowledgement error and a latent party dispel glow error with secret debuff colours. The party and raid glows now share one safe helper. It also brought library updates: ChatThrottleLib 32 ignores secret chat text, LibRangeCheck 38 uses the Classic tables on Forever, and LibActionButton refreshes bar state after pet summons, folded into one update per burst.
- **Nameplate name rules** check the zone context only when you change zones, not on every name update, and use the game's city-map data with a fallback. On Forever, a player's surname comes from the game's own second name result.

### Access and known limits

- Offline tests only, apart from the Warrior health percent fix, which the maintainer confirmed in game. Everything else still needs Retail and WoW Forever checks after `/reload`: the Warrior art, castbar glows in dungeons, quest marks, the totem row, raid glows, the Forever additions and NodeSight together with AzeriteUI.
- The Warrior theme is WIP. After switching to it, use **Reset endcap size and position** under `/az -> Themes` to get its default fit.
- Totem icons do not take the mouse: no tooltip and no right-click to dismiss. The Forever swing timer bars are placed in Edit Mode, and their first position follows Blizzard's main bar. Turning NodeSight's sparkles on or off reaches AzeriteUI's plates at the next soft-target change.
- Whether the game keeps a quest mark after an objective is complete, and whether Forever fills in cast targets, still needs checking in game.
