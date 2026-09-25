
# Changelog

## A note on WoW 12.1 addon development

Retail 12.1 protects more combat, aura, cooldown, and unit data as secret values. Addons can often display those values only by handing them directly to Blizzard-owned widgets instead of reading or formatting them, which is why one visual layer may keep working while related text or logic disappears; safe fixes increasingly require narrow ownership boundaries between Blizzard and other addons.

Release note rule: each version entry must include only what changed since the previous release (delta-only).
Do not repeat older items from prior versions in newer entries.
Writing workflow: [Tools/CHANGELOG_GUIDE.md](Tools/CHANGELOG_GUIDE.md). Lead with player benefits, then explain substantial development work and remaining limits.


## 5.10.2-JuNNeZ (2026-09-25) - Tooltips That Line Up, and No Castbar Flicker

### Highlights

- **Compare tooltips really stop overlapping.** 5.10.1 said they no longer overlapped, but in the game they were still drawn edge to edge, one border running under the other. Shift-hovering an item now puts the tooltips side by side with every border whole and the "Equipped" tab still tucked behind it. The compare tooltips are also drawn at the same size as the tooltip they compare against, where they used to be slightly larger.
- **Buff tooltips wear the AzeriteUI theme.** Hovering the buffs at the top right, the aura row on the player frame or a nameplate aura showed Blizzard's default tooltip whatever the theme. Those tooltips now follow your Azerite or Classic theme, and go back to Blizzard's look when AzeriteUI's tooltip styling is switched off.
- **Tooltip fixes you may notice.** With `/az -> Tooltips -> Show spellID` on, hovering a buff or debuff raised a Lua error and showed no ID; IDs now show there, and on Blizzard's nameplate auras too. A unit's name is no longer written into a different tooltip than the one describing that unit, and a hidden name is no longer replaced with "Unknown". In combat inside instances, where the game hides a unit's health, the tooltip's health text now disappears instead of showing the previous unit's numbers.
- **Hide in Combat reaches action buttons and unit frames.** `/az -> Tooltips -> Hide in Combat` and its **Hide ActionBar Tooltips in Combat** and **Hide UnitFrame Tooltips in Combat** switches only ever affected the pet and stance bars. They now hide the tooltips of the action buttons and the unit frames in combat as well, and bring them back when it ends. **Show Guildname**, which never did anything, is gone.
- **No more flicker under nameplates.** Mousing over a nameplate or changing target could flash a gold bar under the health bar for a moment, sometimes carrying the name of a spell another mob had cast earlier. After a failed or interrupted cast, that bar could also come back for the rest of its brief hold. The castbar now appears only while the unit is casting.

### Development

- **Found out why the 5.10.1 compare fix did not hold, with a report built for it.** `/azdebug tooltips` prints what AzeriteUI did to each compare tooltip and whether it was still in place a frame later. The first live report showed the spacing set and the tooltips drawn edge to edge anyway: either something positioned them again afterwards, or Blizzard's own top anchor won over the spacing. Which one is still open, and the fix does not depend on it. AzeriteUI now makes each join itself inside every call that positions a compare tooltip, whichever copy of Blizzard's code makes it. That needs no one-frame delay, which is what made the 5.3.5x attempt jitter. The offline tooltip test now repeats Blizzard's positioning the way the live client did, and both earlier versions fail it where the game showed the overlap.
- **Audited the whole tooltip module against Blizzard's Retail 12.1 and Forever source.** The buff tooltips turned out to be a protected Blizzard frame that addon code cannot touch, with one styling call Blizzard exports for it, which AzeriteUI now uses. The audit also turned up the Classic-only aura call behind the spell ID error, the nameplate aura tooltips that were never hooked, the name and health text faults, and settings nothing read. The offline tooltip test covers each of these, and the 5.10.1 module fails it in every one of those areas.
- **Traced the nameplate flicker to AzeriteUI's own layout pass**, which showed the castbar every time a plate was laid out, for the castbar code to hide again a frame later. The offline nameplate test hid such bars before every snapshot, so it could never see the flash. It now checks what is on screen before that frame, and checks that a plate hidden mid-cast shows its cast again when it comes back.

### Access and known limits

- **Confirmed in game on Retail:** the compare tooltips with the Azerite theme, the buff tooltip theme, Show spellID, the unit name and the health text. **Verified offline only:** all of it on Forever, the compare tooltips with the Classic theme, Hide in Combat, and the nameplate castbar.
- **If you ticked Hide in Combat earlier, action button and unit frame tooltips will now disappear in combat.** Both of its switches start on; untick either one under `/az -> Tooltips` to keep those tooltips.
- If compare tooltips still overlap for you, type `/azdebug tooltips` straight after the shift-hover and post what it prints on the Discord.

## 5.10.1-JuNNeZ (2026-09-25) - Action Bars Back on Forever, and Friendly NPCs Sized as Such

### Highlights

- **Action bars are back on Forever.** After the Forever 1.60.1.70009 client update every action bar could be missing, the pet and stance bars too, with `'for' limit must be a number` errors from LibActionButton in BugSack. Going back to an older AzeriteUI did not help, because every version had the same flaw. The bars now load again. Retail was not affected.
- **Friendly NPC size now reaches friendly NPCs.** Most vendors, trainers and quest givers were sized as friendly players, so `/az -> Nameplates -> Size -> Friendly NPC size (%)` seemed to do nothing for them. NPCs are now told apart the way Blizzard's own nameplates do it, and the companions of follower dungeons count as players, as they do on Blizzard's plates. Friendly NPC size now starts at the friendly player size, so vendors look as they did until you change it.
- **Blizzard's nameplate settings from inside AzeriteUI.** `/az -> Nameplates -> Game settings` (it was Stacking) now also holds the game's own **Always show nameplates**, **Enemies**, **Friendly players** and **Friendly NPCs** switches; changing one there changes it in the game's Options, and AzeriteUI's plates follow at once. A new **Position** choice under Size puts plates over heads or at feet. **Use Blizzard overall scale** follows the game's Nameplate Size again, Medium matching 100%; it had stopped following anything.
- **Compare tooltips no longer overlap.** Shift-hovering an item, the AzeriteUI border covered the "Equipped" tab and overlapped the tooltip beside it. The borders now meet instead of overlapping, and the tab sits on top of the border, with both the Azerite and the Classic theme.
- **Nameplate fixes you may notice.** Blizzard's **Simplified** nameplate option no longer shrinks AzeriteUI's plates for friendly players and NPCs; the size settings decide. Changing Blizzard's nameplate size or style, or resizing the game window, no longer leaves the plates with Blizzard's spacing and click area until the next reload. **Maximum distance** now limits other players' plates too, and battlegrounds and arenas start at 60 yards so enemy players stay in range.

### Development

- **Traced the missing bars to one changed answer in the Forever client.** The action button library looks for flyout spells by asking about every flyout number in turn, and counted on the game raising an error for a number that does not exist. Forever 70009 answers such a number with nothing instead, and that stopped the library before a single bar was built. The library now skips an empty answer as it skips an error, and does not look for flyouts on Forever at all, where AzeriteUI's own flyouts cannot open. A new offline test loads the whole library against four ways a client can answer; the old copy fails it with the reporter's exact two errors.
- **Checked every nameplate setting against Blizzard's own Retail 12.1 and Forever code.** That found the friendly NPC test Blizzard does not use, the Simplified option scaling AzeriteUI's plates from underneath, Blizzard resizing the plates over AzeriteUI's size, the friendly visibility settings under their old names, the Blizzard scale setting that no longer exists, and about ten settings AzeriteUI still wrote that the game no longer has. It now writes only settings the client has. Platynator and Plater were read for how they handle the same settings. The offline nameplate test now runs against the real 12.1 set and refuses any other, which the old test could not tell apart, and adds a vendor that cannot be assisted and a follower companion.
- **Compare tooltips are spaced inside Blizzard's own layout call.** An earlier attempt in 5.3.5x moved them a frame later, which made them jitter, and was removed. The gap is now added as Blizzard places them, from the width each theme's border really has, and the tab is tucked by the height measured from the border art. A new offline test measures the seam and the tab edge on both themes, either side, with one or two compared items.

### Access and known limits

- **Verified offline only:** none of these changes has been seen in the game yet, on either client.
- In the open world, other players' plates now stop at your **Maximum distance** (40 by default) instead of the game's 60. Raise it under `/az -> Nameplates -> Content settings` if you want them farther.
- Near the right edge of the screen, a compare tooltip the game pushes back on screen may still overlap its neighbour by up to the border's width.
- The new option text was translated without native speakers; corrections are welcome on the Discord.

## 5.10.0-JuNNeZ (2026-09-24) - Smarter Nameplates

### Highlights

- **Nameplate auras stay through the whole fight, and you choose what they show.** Auras that were on a nameplate before combat used to vanish during it and stay gone afterwards. Plates now draw their auras through Blizzard's own aura display, which keeps working in combat. `/az -> Nameplates -> Aura filters` picks the kinds: crowd control from anyone, your debuffs (optionally only the ones Blizzard highlights), important debuffs from other players, enemy buffs your group can dispel, purge or soothe, important enemy buffs such as big defensives, and your own short buffs on friendly plates.
- **Nameplates can behave differently in each kind of content.** `/az -> Nameplates -> Content settings` keeps its own maximum distance, faintest alpha and alpha behind walls for the open world, dungeons, Mythic+, raids, battlegrounds and arenas, and uses the one you are in. A Mythic+ key switches over when it starts, with no loading screen. The defaults are exactly the values used until now, so nothing changes until you change it.
- **Two new aids for busy pulls, both off until you switch them on.** **Fade enemies fighting someone else** (`/az -> Nameplates -> Other fights`) fades enemies that are in combat with no one in your group, so the pull you are in stands out; your target, focus and the plate under your cursor never fade. **Show the execute marker** (`/az -> Nameplates -> Execute range`) draws a line across enemy health bars at your execute threshold and tints the part of the bar below it once the enemy drops under it. The threshold follows your class and specialization, or can be set by hand where a talent moves it.
- **Raid markers sit beside the health bar at a sensible size.** Skulls and stars were drawn about three times the height of the bar, floating above the plate and climbing further as names and auras appeared. They now sit to the left of the bar, at size 28 by default, with **Target marker size** under Nameplates. The same page now also has Blizzard's own **Stack enemy nameplates** and **Stack friendly nameplates** switches, so they can be changed without leaving AzeriteUI.
- **AzeriteUI is in the game menu.** Escape now shows an **AzeriteUI** button under Options that opens the options window. Turn it off at `/az -> Game Menu -> Show AzeriteUI in the game menu`.
- **Fixes you may notice.** Interrupt colours on nameplate castbars now read your interrupt's cooldown correctly during combat, where they used to fall back to a guess, and a Warlock's pet interrupt now counts. A tab-targeted plate shows its name straight away. In a dungeon, changing any nameplate setting no longer put the plates back on open-world transparency until the next loading screen. Turning AzeriteUI's nameplates on or off now warns that it reloads the interface. With Platynator, Plater or another nameplate addon enabled, AzeriteUI's plates stand down without overwriting that addon's nameplate scale at every login, without reloading the interface each time a setting is changed, and the page says which addon is in charge. On Forever, Blizzard's own combo point dots no longer appear beside the hidden target frame.

### Development

- **Rebuilt the nameplate module in place rather than starting over**, so the object-plate, soft-target and name-only fixes of earlier releases carry across. First an offline test was built that drives the real module through ten plates and a scripted session - targeting, focus, combat, zoning, reloads, recycled plates - and records every visible detail of every plate at every step, plus a count of how much work each step costs. Each change after that had to leave that record untouched, or change it only where intended. With that in place: about 650 lines of dead code went, nine defects were fixed (two of them caught by that record after reading the code had missed them), and the 3,900-line file became ten files with one job each.
- **Nameplates do far less work.** Target, focus and soft-target changes now touch only the plates whose state changed, instead of laying out every plate; two timers that ran twenty times a second for the whole session are gone, replaced by the events Blizzard's own nameplates use; and zoning no longer lays out plates that are about to be replaced anyway. Changing target with ten plates on screen went from about 530 widget calls to about 60.
- **One interrupt check for nameplates and the target castbar.** The two used to work out your interrupt separately, from different spell lists, and the nameplates read the cooldown in the one way that the game hides during combat. They now share one resolver that reads it the way combat allows, knows the Forever spell ranks, and watches your pet's casts as well as your own.
- **Took work out of action bar key presses.** A report of action bar keys that stop responding mid-fight came with an error showing the pet bar refreshing inside a key press, whenever a macro uses `/petattack`. That refresh now waits for the next frame, the fading library no longer re-checks every faded button each time one button registers, hotkey text is worked out once per key, and the stance bar gathers bursts of shapeshift events into one refresh. Before changing anything, AzeriteUI's action bars were compared with Bartender4, Dominos, ElvUI and the upstream action button library, to copy only what fits and leave alone what those projects had to roll back.

### Access and known limits

- Tested in game on Retail: the rebuilt nameplate module, auras in combat, the raid markers and their slider, the aura filters, stacking and the game menu button. **Verified offline only:** content settings, the combat fading, the execute marker, the shared interrupt check, the nameplate-addon stand-down, the action bar changes and the Forever combo point fix. None of the nameplate work has been tried on Forever yet.
- The action bar changes remove AzeriteUI's own work from the key press; they are not yet confirmed to cure the unresponsive key. If it still happens, please report whether BugSack shows `script ran too long`.
- The execute marker is on nameplates only, not on the target frame.
- Forever nameplate auras drawn partly underneath the plate are not fixed in this release.

## 5.9.1-JuNNeZ (2026-09-23) - The Tracker Switch Works, and Every Language Is Complete

### Highlights

- **Hide the Blizzard Tracker now really hides it.** On Forever the quest tracker came back after every login, reload and loading screen while `/az -> Objectives Tracker -> Hide the Blizzard Tracker` stayed ticked. On Retail the switch had never done anything at all. It now works on both, stays hidden through boss and arena encounters, and with the switch off the tracker still fades out during those encounters as before. **If you ticked it once and forgot because nothing happened, your tracker will disappear after this update** - untick it to bring the tracker back.
- **AzeriteUI is fully translated in German, Spanish, French, Italian, Korean, Brazilian Portuguese, Russian and both Simplified and Traditional Chinese.** The options window, its Settings tab, the preview messages, the day and night indicator and the Incoming Heals and Absorbs page had been English in every language. The heals and absorbs page and the power text and crystal colour choices under Unit Frames could not be translated at all, because their text was written straight into the page; now they read through the translation table like everything else.

### Development

- **Traced the tracker switch through Blizzard's own secure frame code.** The switch sent its request to a kind of secure frame that only listens for state changes, so on Retail the request was never heard; on Forever a separate path did hide the tracker, and then the addon's own login handling faded it straight back in. Both now go through the single visibility rule that already handled bosses and arenas. A new offline test drives the real module through logins, reloads, loading screens, encounters, combat and Immersion dialogues on both clients. It failed the old code exactly where the report said, and passes the new one.
- **Translations are now checked rather than hoped for.** A new offline test loads every language file the way the game does and fails if a language is missing an English string, has an extra or duplicate one, leaves one empty, changes the placeholders a string is filled in with, or lets a preview line or tab label outgrow the options window. From now on, any new string has to arrive in all ten languages.

### Access and known limits

- Verified offline only: neither change has been seen in the game on either client yet.
- The translations were written without native speakers, following each language's existing wording for nameplates, profiles and frames. Corrections are welcome on the Discord. Longer German and French lines are the most likely to crowd the options window at its smallest size.

### Internal

- `/azdebug keys bindings` now shows what each key does right now and marks a key something else has taken, for the report of action bar keys that stop responding mid-combat.
- Removed the Export and Import Layout buttons that only appeared, permanently disabled, in the Development Mode mover options.

## 5.9.0-JuNNeZ (2026-09-22) - A Solid Window, a Combat Queue and Settings That Ask First

### Highlights

- **The options window is solid, and its border is where a border should be.** The background is fully opaque at 100% and thins out smoothly on the slider, which now moves a percent at a time rather than in five-percent notches. The sculpted edge is drawn the way AzeriteUI draws its own tooltips - same art, same weight, untinted - and it sits above everything the window holds, so no part of the header, list or footer is drawn over it any more.
- **Settings changed in combat now really do wait for combat to end.** The footer has promised this for several releases while the change went through immediately. It is a queue now: the setting keeps the value you chose, the row is marked, the footer counts what is waiting, and everything is applied the moment you leave combat - even if you closed the window in the meantime. The window's own appearance settings still apply at once, because they change nothing the game protects.
- **Deleting a profile asks first.** Delete Profile, Reset and importing settings each destroyed or overwrote something on a single click in the new window, with nothing asked. All three now confirm first, as they always did in the old dialog.
- **A setting that refuses a value says why.** Naming a new profile with an empty or duplicate name used to do nothing at all. The row now explains the refusal where its help text sits, and clears it as soon as the setting accepts what you typed.
- **The window can be driven from the keyboard.** Click the search box and press Tab to start: Tab and Shift-Tab move between settings, the arrows move within the list, Left and Right change a value, Enter does what a click does, typing searches, and Escape hands the keyboard back. Nothing is captured until you ask for it, so your movement and action keys keep working while the window is merely open.
- **Panel Scale no longer fights the cursor.** Dragging it rescaled the window under your mouse, so the slider slid away from the cursor and the value ran off. It now applies when you let go, while the slider itself still follows the cursor.

### Development

- **Measured the border art instead of guessing at it.** The sculpted rim sits one to ten pixels into a side edge and eleven to nineteen into the top or bottom, which is why the old drawing let the background show past it. The casing now hangs outside the window by the same offsets the addon's tooltips use, with the fill tucked underneath, and the offline checks compare the panel's numbers against the tooltip's own layout data so the two cannot drift apart. The window's fill was also moved off Blizzard's tooltip background texture, whose opacity is not ours to control, onto one that takes exactly the alpha the slider asks for.
- **Built the confirmation and refusal handling against the Ace3 library's own source** rather than from an idea of how those fields work, because a text string in either of them means something different from what it looks like. Two cases deliberately fail safe: a confirmation the panel cannot work out is still asked, and a question that cannot be shown changes nothing.
- **Added the three control types no setting in this addon uses yet** - a colour swatch that opens the game's own picker, a keybinding button, and a multi-choice setting drawn as one toggle per option - together with a page to test them on, which appears only with Development Mode enabled. Adding any of these to a real settings page will now draw a working control instead of a blank space.
- **Extended the offline checks to 527 for the panel and 186 deliberately broken versions**, covering the border's layering, the combat queue, the keyboard, confirmations and refusals, the new control types and slider dragging. Five separate faults in the test scaffolding itself were found and fixed along the way, including one that had made every slider drag untestable. None of this emulates rendering, taint or protected execution in the game.

### Access and known limits

- Tested in game on Retail, over a written checklist covering the window, the combat queue, confirmations, the keyboard, previews and a regression sweep. **Not yet tested on Forever**, and the new control types have not been exercised in game since the page for them was added.
- A change queued during combat is not saved anywhere until it is applied, so reloading the interface mid-combat discards it.
- Typing to search works while the keyboard is being used to walk the window, which is also when letters stop reaching the game, exactly as they do when any text box has focus. Press Escape to hand the keyboard back.
- Each theme still wears the same bronze casing; per-theme, per-class and per-race window art remains deferred.

## 5.8.0-JuNNeZ (2026-09-22) - Quick Start, Truer Previews and Chattynator

### Highlights

- **Chattynator's editbox position setting works again.** AzeriteUI re-anchored the chat input line under its own chat window on every login and reload, overriding Chattynator's choice to put it at the top. With Chattynator enabled, AzeriteUI now leaves chat alone, as it already does for Prat, ls_Glass and BigInputBox. That also stops AzeriteUI from fading out the chat menu, channel and voice buttons Chattynator places in its own button bar, and from blanking and resizing the editbox artwork that Chattynator's Blizzard skin uses.
- **`/az` now opens on Quick Start.** A new first page in the Setup band gathers ten of the settings that change the most, from Explorer Mode and the action bars to nameplates, incoming heals and chat fading. Each one is still on its own page as well, and settings your client or character cannot use are left out.
- **Everything you have changed, in one list.** When any setting differs from its default, the header count (for example "349 settings, 12 changed") becomes a link. Click it to see every changed setting grouped by page and section; resetting one removes it from the list, and clicking the count again takes you back. The change markers and the count now update as soon as you change something, not the next time the panel opens.
- **Live previews glow the frames a setting actually changes.** Settings shared between frames used to flash the player frame. Incoming heal and absorb settings now glow every visible health bar, Color Cast Spell Text By State glows the target frame and nameplates, and page-wide action bar settings such as Hide Hotkeys glow every bar. Explorer Mode's timing and conditions glow the elements it fades, and nameplate size settings pick a plate of the right kind. When several frames glow, the footer counts them.
- **When nothing on screen can show a change, the footer says why.** Show Blizzard Raid Bar explains that the bar only appears in a party or raid, and Cast action keybinds on key down explains that it changes key presses rather than looks. Tooltip, world map, game menu and bag settings are outlined only while that window is open; otherwise the footer asks you to open it.

### Development

- **Audited every setting for what it changes on screen, not where it is saved.** A setting records which profile stores it. For shared unit frame, action bar and Explorer Mode settings, that pointed the preview at one representative frame. The audit produced a table giving each such setting an exact frame, a family of frames or an explanation. A setting added later without an entry previews nothing rather than the player frame. Nameplate previews read only the flags the nameplate code already sanitises, never protected unit data.
- **Built pages gathered from settings on other pages.** Quick Start and the changed list draw each row from the setting's real location, with its own control, change marker and reset, and gather again on every refresh, so a reset setting drops out at once. Only the page that changed is recounted, so dragging a slider does not recount the whole panel.
- **Extended the offline checks.** The panel checks now cover the preview table (failing if an entry names a setting that no longer exists or drifts from Explorer Mode's own list), explanations fitting the footer at the smallest window, both new pages against the real Retail and Forever option tables, and live counts. Deliberately broken versions confirm the checks catch regressions. A new check covers the chat addon exclusion. None of this emulates rendering or protected execution in WoW.

### Access and known limits

- Everything in this release is verified against source and offline checks only; nothing is confirmed in game yet. The Quick Start selection may still change.
- With Chattynator enabled, AzeriteUI's Chat options (fading and message timing) no longer apply and are left out of Quick Start; use Chattynator's own settings. Explorer Mode's chat fading does not reach Chattynator windows.
- Chattynator's social (Quick Join) button may still be hidden, because AzeriteUI hides Blizzard's micro buttons by default. Turning on **Action Bars -> Micro Menu -> Show Blizzard's Micro Menu** should bring it back; this is untested.


## 5.7.2-JuNNeZ (2026-09-22) - Forever Combo Points, Take Two

### Highlights

- **Forever Rogues and Druids now actually see their combo points.** Forever hands combo points to addons as hidden ("secret") values, even out of combat, and AzeriteUI read them as zero, so the display never appeared. The game now fills the points directly: filled points are bright, empty sockets half-faded, the display is hidden with no points, and a full set still fades after combat unless **Unit Frames -> Class Power -> Show Full Class Power Out of Combat** is on. Retail is unchanged.

### Development

- A player's `/dump` showed 5.7.1 had the cause wrong: the count was correct but secret, not zero. Each point now takes the secret value through its own range, and visibility comes from Blizzard's curve-based percent API, so addon code never reads or compares the number.
- Added an offline test that runs the real class power code against a stand-in secret value that fails on any arithmetic or comparison, plus deliberate-break checks proving each part of the fix is covered and Retail keeps its old path.

### Access and known limits

- Verified offline only; not yet confirmed in game.
- With Class Power Click-Through turned off, the invisible zero-point display still blocks clicks in its area.


## 5.7.1-JuNNeZ (2026-09-21) - Forever Combo Points

### Highlights

- **Forever Rogues and Druids now see their combo points.** Forever keeps classic combo points on the target, and the display was reading them the Retail way, so it always saw zero and stayed hidden. It now reads the points on your current target and updates when you change target. Retail is unchanged.

### Access and known limits

- Fixed from Blizzard's Forever interface source and a player report; not yet confirmed in game.


## 5.7.0-JuNNeZ (2026-09-21) - New Options, Predictions and Forever Fixes

### Highlights

- **The new options panel now opens with `/az`.** It includes search, grouped navigation, changed-setting markers and individual resets. `/az new` remains an alias, `/az classic` keeps the previous skinned window, and `/az legacy` opens stock Ace3.
- **Changed frame settings briefly identify their live frame with a golden glow.** The preview never moves, resizes, shows or hides the target. When no usable frame exists, the panel explains that in its footer instead of drawing a simulated frame.
- **Incoming heals and absorbs now use shaped overlays that fit AzeriteUI health bars.** Under `/az` -> Unit Frames -> Incoming Heals and Absorbs, incoming heals, overheal cues, damage absorbs and healing absorbs can be controlled independently. Damage absorbs can show their total size or follow current health and incoming healing.
- **Forever Druids can see combo points without a specific rank of Shred.** Cat Form's Energy now gates the display on Forever, while Retail keeps its existing Shred requirement.
- **Forever's day/night indicator has two artwork themes.** Right-click the minimap indicator to choose between the existing Sky scenes and the supplied Sun & Moon artwork, alongside its saved distance control.
- **Forever nameplate interrupt colors recognize classic spell IDs and ranks.** Pummel, Kick, Silence, Earth Shock, Counterspell and pet Spell Lock use a Forever-specific resolver; Retail remains unchanged.

### Development

- **Moved the custom panel from preview to the normal settings route while preserving both fallbacks.** Opening, closing and refreshing cover the new panel, retained window and stock dialog. The live-frame resolver handles numbered action bars, Explorer Mode elements, shared unit-frame settings and active AzeriteUI nameplates, with mutation-tested failure paths.
- **Built an addon-owned health-prediction renderer around Blizzard's native measurement widgets.** Fixed shaped artwork is revealed by masks while oUF retains event and lifecycle ownership, avoiding addon arithmetic on protected unit values. Separate caches preserve existing numeric absorb text and target-layout behavior.
- **Expanded client-specific regression coverage.** The panel, prediction geometry, Diel themes, real Retail and Forever option tables, client capability gates and deliberately broken variants are checked offline. Those checks do not emulate protected execution or GPU rendering in WoW.

### Access and known limits

- The retained options window remains at `/az classic`; deleting it is deferred by maintainer choice.
- Some policy settings do not own one visible frame. `Show Blizzard Raid Bar` and `Color Cast Spell Text By State`, for example, currently glow the player frame as the shared Unit Frames representative. More precise targets or explanatory previews are planned.
- Health-prediction rendering received live iteration for shield proportions, but the final overheal option, all frame families, combat behavior and Forever rendering still need broader in-game coverage.
- The Forever Druid combo-point gate and classic interrupt resolver pass offline checks but still need live class/rank testing. Forever action dragging, custom flyouts and Clique click-casting remain unavailable.


## 5.6.0-JuNNeZ (2026-09-20) - Forever and the New Options Panel

### Highlights

- **Try the new options panel with `/az new`.** Search across settings, browse grouped pages and sections, and see which supported settings differ from their defaults, with individual reset controls.
- **Make the panel your own.** Open `/az new` -> Settings -> Appearance for themes, background opacity, scale and position reset. Settings -> Changelog shows recent release notes in game.
- **Forever action bars and group frames work around the beta's broken secure execution.** Adds fallback paths for bar paging, visibility, player aura switching and party/raid frame setup, and avoids the startup probe that generated a Blizzard error.
- **Forever's cog-wheel menu respects character unlocks** and uses a compatible open/close path. The objective tracker also uses the beta-compatible visibility path.
- **A day/night indicator for the Forever minimap.** Drag it around the ring, right-click to adjust its distance, or turn it off under `/az` -> Minimap -> Day and Night Indicator to restore Blizzard's indicator.

### Development

- **Built the new panel's controls and layout system around the existing settings.** The preview draws its own sliders, switches, menus and pages while sharing the same settings tables and profiles with the classic dialog. The layout work also handles wrapped help text and recalculates page spacing when the window is resized.
- **Traced Forever's startup errors to Blizzard's secure execution and developed alternate paths.** Bar paging and visibility use Blizzard's native state drivers, while group-frame setup requested during combat waits until combat ends. Retail retains its existing secure path; the Forever workaround has the limitations listed below.
- **Developed and refined the minimap's day/night presentation.** New sun and moon artwork sits in an AzeriteUI housing, with saved placement, distance adjustment, tooltips and an option to restore Blizzard's indicator.
- **Added regression checks for the panel and both clients.** Tests exercise the real settings tables, navigation, controls, compatibility gates and day/night behavior. Deliberately broken versions were also tested to confirm that the checks detect regressions; these offline checks do not replace in-game testing.

### Access and known limits

- `/az` keeps the existing window; `/az classic` opens the stock Ace3 dialog. The new panel is an opt-in preview; later panel phases, including migration of `/az`, are deferred. Change frame settings outside combat.
- On the current Forever beta, action drag-and-drop, custom flyouts and Clique click-casting remain unavailable. Newly created group frames during combat finish setup after combat ends.
- Offline checks passed for both clients. Live `/reload`, combat and visual regression testing of this combined release is still needed.


## 5.5.0-JuNNeZ (2026-09-19) - Retail and Forever

### Highlights

- **One download for Retail and WoW Forever.** Adds the Forever beta load entry alongside Retail 12.1, with automatic client detection.
- **Settings match your client.** Forever omits arena frames, archaeology, the vehicle-seat display, specialization inspection and Retail-only class resources. Rogue and Druid combo points remain available. Unsupported settings are hidden in `/az`.
- **The cog-wheel menu follows the client.** Forever includes its Spellbook, Talents and Legacy buttons, while entries disabled by the game are omitted.
- **Shared UI compatibility fixes** keep modern aura safety, keybinding and dropdown behavior active on Forever despite its lower interface number.

Forever support is new and has passed offline checks; in-game beta testing is still needed.


## 5.4.13-JuNNeZ (2026-09-17) - Friendly Names Closer to Their Heads

### Fixed

- **Friendly player names sit just above the character again.** With names only turned on, player
  names floated well above heads, as if the hidden health bar and castbar still took up room. They
  now sit just over the head, and a bigger Friendly name size (%) makes the name grow upwards
  instead of down over the character.
  `/az` -> Nameplates -> Friendly Players -> Use names only for friendly players.
- **Mailbox and other object names no longer show up oversized.** They could appear at the larger
  friendly player name size when their nameplate had last shown a friendly player's name.


## 5.4.12-JuNNeZ (2026-09-15) - An Aura Toggle for Raid Frames (5)

### Added

- **Raid Frames (5) can now hide their aura row.** Since 5.4.11 the buffs you can apply and the
  debuffs you can dispel stay on these frames through combat, with no way to turn them off. Show
  Auras is on by default, so nothing changes unless you switch it off. Blizzard's boss mechanic icons
  in the middle of the health bar still show either way.
  `/az` -> Unit Frame Settings -> Raid Frames (5) -> Show Auras.


## 5.4.11-JuNNeZ (2026-09-14) - Party Auras That Last Through Combat

### Fixed

- **Party frame auras no longer vanish the moment combat starts.** Heal-over-time spells such as
  Rejuvenation, Regrowth and Lifebloom, along with the other buffs and debuffs on your party members,
  disappeared from the party frames as soon as a fight began and came back once it ended. The game no
  longer lets addons read aura data during combat, so the party aura row now uses the same
  game-driven aura display as the player and target frames, which keeps updating mid fight. Your own
  buffs are drawn first.
- **Raid Frames (5) get the same fix.** They show the buffs you can apply and the debuffs you can
  dispel, in and out of combat.
- **"Player / Self Buffs" and "Other Temporary Buffs" now split by who cast the buff.** With only
  "Player / Self Buffs" on, buffs other players put on you no longer slip in; with only "Other
  Temporary Buffs" on, those buffs now show instead of being hidden.
  `/az` -> Unit Frame Settings -> Player -> Player Aura Row, with Use AzeriteUI Stock Behavior off.

### Changed

- **The Party Aura Row options now pick from the game's own aura categories.** Stock behavior shows
  your own castable buffs, dispellable, boss and other debuffs, and externals and raid buffs from
  other players. The custom toggles switch those categories on and off as before. "Show Short Helpful
  Buffs" on its own keeps your buffs to under a minute and "Show Other Short Debuffs" keeps other
  debuffs to about five minutes; stacks no longer count as short, and other players' buffs are no
  longer dimmed. `/az` -> Unit Frame Settings -> Party Frames -> Party Aura Row.

### Known limitations

- The dispellable-debuff glow around a party frame and the priority-debuff icon in its middle still
  read aura data the old way, so they go blank during combat.
- Where the game keeps aura data secret, in dungeons and raids, changing Aura Size or Debuff Size %
  only reaches aura icons drawn after the change.

### Internal

- `/azdebug aurasnapshot party|raid5` and `/azdebug unitmenu [trace on|off]`, for the combat aura
  and raid right-click menu reports.


## 5.4.10-JuNNeZ (2026-09-13) - When Another Addon Styles the Game Menu

### Added

- **AzeriteUI now asks what to do when another addon restyles the game menu too.** The menu you
  open with Escape could end up with two addons' looks stacked on top of each other. If W2UI,
  GW2 UI, FeelUI, DiabolicUI3, AddOnSkins or ConsolePort's menu is styling it as well, AzeriteUI
  asks the first time you open the menu in a session:
  - **AzeriteUI** keeps AzeriteUI's look and turns the other addon off for this character.
  - **The other addon's name** keeps its look and turns AzeriteUI's game menu style off.
  - **Blizzard** turns both off and gives you the plain game menu.
  - **Decide Later** changes nothing, and neither does pressing Escape.

  Every choice reloads the interface. AzeriteUI and Blizzard switch the whole other addon off, not
  just its game menu, and you can turn it back on from the AddOns list. If you want AzeriteUI's menu
  but the rest of the other addon, some of these addons can switch their own game menu styling off
  in their settings instead - AzeriteUI does not ask while that is off.
- **Change the game menu style whenever you like.** `/az` -> Game Menu -> Game Menu Style lists the
  same choices and asks before reloading.


## 5.4.9-JuNNeZ (2026-09-12) - A Dismount Button You Can Place

### Added

- **The dismount button can now have a position of its own.** The round exit icon that shows up
  while you are mounted, in a vehicle or on a taxi normally rides the upper left of the minimap
  ring. Turn this on and it comes off the map, so you can put it anywhere on screen - useful if you
  have moved the minimap, replaced it with another addon's, or turned this one's minimap off
  entirely and been left with a button floating where the map used to be. Switch it back off and the
  button returns to the ring.
  `/az` -> Action Bars -> Dismount Button -> Use a custom position, then `/lock` to drag it into
  place and the mouse wheel over it to resize it.
- **A dismount button you have placed yourself no longer hides with the minimap.** Auto-hide takes
  the button along only while it is still sitting on the map ring, which was the point of hiding it
  in 5.4.8. Once it is somewhere else on screen it stays visible and clickable in arenas,
  battlegrounds and anywhere else the map hides itself - so you keep your click to dismount or to
  leave a battleground vehicle.


## 5.4.8-JuNNeZ (2026-09-09) - The Dismount Button and the Empty Slots

### Fixed

- **Empty action bar slots no longer sit there at full brightness while the rest of the bar fades
  away.** Slots you have not put anything on were being forced back to full opacity every time the
  UI reapplied your settings, which is why fading a bar appeared to fade only the buttons you
  actually use and leave a row of empty frames behind. Empty slots are now hidden by default, on
  every action bar, and they stay hidden through settings changes, mounting, vehicles and bar
  swaps.
- **The dismount button now goes with the hidden minimap.** The round exit icon that appears at the
  upper left of the minimap ring when you are mounted, in a vehicle or on a taxi is this UI's own
  button, and it hangs off the screen rather than off the map, so auto-hide never reached it and it
  sat there on its own. It now goes with everything else, and stops taking clicks while it is gone.
  Worth knowing: that button is how you click to dismount or to leave a battleground vehicle, so
  with the map hidden you will want your Dismount keybind or `/leavevehicle` instead.
  `/az` -> Minimap -> Auto-Hide, unchanged otherwise.

### Added

- **Show empty buttons.** If you liked seeing the full grid on your action bars, turn it back on and
  the empty slots come back - and this time they fade along with the rest of the bar instead of
  staying put. `/az` -> Action Bars -> Show empty buttons. Off by default.


## 5.4.7-JuNNeZ (2026-09-08) - The Blips the Hidden Minimap Left Behind

### Fixed

- **A hidden minimap no longer leaves your player arrow and your group's dots floating on an empty
  screen.** Auto-hide faded out the map and everything sitting on it, but the game paints the player
  arrow, the party and raid dots and the tracking icons over the map rather than inside it, and
  those ignore transparency entirely. The map is now taken off screen outright while auto-hide has
  it hidden, which takes its blips with it. Nothing about the option itself changes -
  `/az` -> Minimap -> Auto-Hide works exactly as before, and the map still comes straight back when
  you leave.


## 5.4.6-JuNNeZ (2026-09-08) - A Minimap That Gets Out of the Way

### Added

- **The minimap can now hide itself in the content you choose.** Switch on
  `/az` -> Minimap -> Auto-Hide -> **Hide the Minimap Automatically**, then tick where it should
  disappear: **Arenas**, **Battlegrounds**, **Dungeons** or **Raid Instances**. Arenas and
  battlegrounds are ticked to begin with, so the common case takes a single click. The map comes
  back the moment you leave, and stays on screen while the frame mover is open so you can still
  position it. Off by default - nothing changes until you turn it on.
- Auto-hide covers the minimap and everything sitting on it, addon minimap buttons included. The
  clock and coordinate panel is a separate frame under `/az` -> Info and stays where it is.


## 5.4.5-JuNNeZ (2026-09-06) - Less Work on Every Target Swap

### Fixed

- **Changing targets in a raid no longer rebuilds the target aura row from scratch.** A boss and an
  ordinary target differ only in how wide that row is and how many icons it holds, but every swap
  between the two also re-applied the row's anchors, all seven of its group layouts and its filters,
  and that last step makes the game re-evaluate every aura on the spot. Those steps now run only
  when something they depend on actually changes, so retargeting in a raid does less work each time.
  Nothing about the row you see changes.

### Internal

- The aura access guard added in 5.4.4 now falls back to `C_Secrets.ShouldAurasBeSecret` where the
  per-object access query is unavailable, so it fails closed instead of open. No behaviour change on
  a current client.
- `/azdebug` aura snapshots list helpful auras again. The debug code kept a private copy of the aura
  group list that stopped matching the six helpful groups the player row registers, and had been
  quietly dumping harmful auras only. It now reads the list the containers actually register.


## 5.4.4-JuNNeZ (2026-09-06) - The Raid Freeze on Target Auras

### Fixed

- **The UI no longer locks up when you change targets in a raid.** Switching between a boss and
  anything else rebuilds the target's aura row, and in a raid that rebuild threw an error part-way
  through. Because it never finished, the next target change started it over and threw again, so it
  compounded with every swap - at its worst on a boss reset, when the whole raid retargets at once.
  Target auras now leave those icons alone in content where the game keeps aura information private.

### Known limitation

- **In a raid, the player aura brightness toggle only reaches icons drawn after you change it.** The
  game will not let us restyle an aura icon that is already on screen there, so
  `/az -> Unit Frame Settings -> Player -> Player Aura Row -> Always Show Full Brightness` may not
  take hold until those icons are redrawn. Everywhere else it applies at once, as before.


## 5.4.3-JuNNeZ (2026-09-05) - Range Fading at Your Own Distance

### Added

- **The range indicator can fade at a distance you choose.** Party, Raid (5), Raid (25),
  Raid (40) and Arena each get their own slider beside the range toggle. 40 yards is the
  game's own group check and stays the default, so nothing changes until you move it.
  Shorter distances are measured with the spells and items your class currently has, and
  settle on the nearest range one of them covers - ask for 30 and you may get 28, depending
  on what you can cast. If nothing reaches that far, group frames fall back to the 40 yard
  check rather than fading the whole group out.

- `/az -> Unit Frame Settings -> Party Frames -> Fade Distance (yards)`
- `/az -> Unit Frame Settings -> Raid Frames (5) -> Fade Distance (yards)`
- `/az -> Unit Frame Settings -> Raid Frames (25) -> Fade Distance (yards)`
- `/az -> Unit Frame Settings -> Raid Frames (40) -> Fade Distance (yards)`
- `/az -> Unit Frame Settings -> Arena Enemy Frames -> Fade Distance (yards)`

### Fixed

- **The arena range indicator now actually fades.** It had never done anything: the check
  behind it only answers for units in your own group, and arena enemies never are. Enemy
  frames now measure at every distance, the default 40 yards included, so the existing
  toggle at `/az -> Unit Frame Settings -> Arena Enemy Frames -> Use Range Indicator` starts
  working for the first time.

### Changed

- **Export and import moved to their own page.** They sat above the settings tree, where two
  multiline text boxes crowded every settings page into the lower third of the window. They
  are now the last entry in the tree, at `/az -> Export & Import`, with room for larger boxes.


## 5.4.2-JuNNeZ (2026-09-05) - Portrait Alpha and the Party Frame Error

A patch release for one error report from 5.4.1 and the two older bugs found sitting
underneath it. All three are in the 3D portraits.

### Fixed

- **Party frames threw a `SetAlpha` error on entering a scenario, dungeon or raid.**
  Six of them at login, from the portrait's alpha handling. It asked the game for the
  frame's on-screen opacity, and inside an instance Retail 12.1 is allowed to refuse the
  question and answer with nothing at all - which the portrait then tried to use. It no
  longer needs to ask.

- **Portraits were losing their 85% opacity and rendering solid.** The same code
  overwrote the portrait's configured transparency with the unit frame's the first time
  the frame faded for any reason, so portraits drifted to fully opaque and stayed there.

- **Raid and arena portraits stayed bright when the unit went out of range.** Both frame
  types dim to 60% at range, and the portrait was the one piece that never dimmed with
  them. It does now, matching party and target frames.

### Internal

- The portrait alpha fix is a single shared helper in `UnitFrames/Functions.lua`, wired
  into all five stylers that own a 3D portrait, replacing the closure pairs each of them
  carried. It writes to the model's own alpha channel rather than the widget's, so the
  configured `PortraitAlpha` is no longer in the path of the fade.
- Unit frames no longer hook `UIParent:SetAlpha` at all - nothing in the addon or in
  Blizzard's own interface calls it. Nameplates still need the hook and keep one shared
  handler over the plate registry, instead of a fresh closure for every plate created in
  a session.

### Fixed

- **Party frames threw `bad argument #1 to 'SetAlpha'` on restricted maps.** The 3D portrait alpha hook fed `GetEffectiveAlpha()` straight into `SetAlpha`, and in 12.1 that getter is allowed to return *nothing at all* - it carries the `RequiresScriptObjectAlphaAccess` precondition, which fails by returning no values once anything in the frame's parent chain owns the secret Alpha aspect, as it does inside a scenario, dungeon or raid. The party frames' new range indicator was what finally drove the hook down that path: turning the option off disables the range element, which sets the frame's alpha on its way out, which fires the hook. Six errors at login in a scenario.

- **Portraits were losing their configured 85% opacity.** The same hook wrote the unit frame's alpha over the portrait's own, so `PortraitAlpha` survived only until the first time a frame's alpha changed. The portrait's own alpha is now left alone, and the fade rides a separate channel.

- **Raid and arena portraits never faded with the frame.** Both frame types dim to 60% when the unit is out of range, and both have a 3D portrait that stayed at full brightness while everything around it faded. They had no portrait alpha handling at all; they now share the same one as party, target and the alternate player frame.

### Changed

- **Fewer hooks on `UIParent`.** Every unit frame and every nameplate used to install its own closure on `UIParent:SetAlpha`, none of which were ever removed - dozens of them by the end of a session, all doing the same work. The unit frame ones are gone outright (nothing in this addon or in Blizzard's interface calls `UIParent:SetAlpha`), and the nameplate one, which has a real job to do, is now a single hook that updates every plate instead of one hook per plate.

## 5.4.1-JuNNeZ (2026-09-04) - Profile Sharing, Keybind Mode, and Target Markers

The first phase of the roadmap rebuilt in `FEATURE_PLAN.md` on 2026-09-04, and
deliberately the low-risk phase: three of the four items surface behaviour the addon
already had but never exposed.

**Please stress test the profile strings.** Export and import are new, they touch every
module's settings at once, and the machinery underneath them shipped unfinished upstream
and had to be repaired before it could run at all. Duplicate your profile before
importing anything.

### Profile export and import

The profile page can finally share a setup. **Generate Export String** packs the active
profile, frame positions included, into one printable string; paste someone else's string
into the import box and press Accept to apply it. Importing overwrites the active profile
and prompts for a reload, and a string from a newer version of AzeriteUI is rejected with
its own message rather than half-applied.

This shipped unfinished upstream. `ns.Export`, `ns.ExportLayouts` and `ns.Import` had
empty bodies, the options entries were dev-mode only and permanently disabled, and three
supporting bugs had to be fixed before any of it could work:

- `ns:PurgeKeys` and `ns:PurgeOtherKeys` mutated their table but returned nothing, so
  every caller assigned nil. `PurgeOtherKeys` also recursed into subtables asking the
  opposite question, leaving branches standing that it was meant to strip.
- `GetDefaults()` returns the AceDB wrapper, `{ profile = ... }`, not the profile itself.
  The merge and export paths walked it alongside `self.db.profile`, which would have
  nested the whole settings tree under a bogus `profile` key. They now go through a new
  `Module:GetProfileDefaults()`.
- `MergeSettings` recursed with a nil target when a branch was missing, and a nil target
  falls back to the module's entire profile - so a missing subtable would have merged its
  defaults onto the top level.

Export is opt out rather than opt in. Every module holding a settings profile takes part
unless it says otherwise; the debug, development, experimental and options modules never
do. Layouts only come from modules that actually save a position.

### Keybind mode is documented

`/kb` has worked since the bars were written - LibKeyBound ships with the addon, every
action, pet and stance button already carries a bind target, and the library registers the
slash command itself. Nothing said so. It is now in the README slash table and has an
**Action Bars > Keybind Mode** button that closes the options window first, since the
window sits on top of the bars you are trying to hover.

### Unit frames

- **Party frames now have the range indicator.** Every other group frame has had one for
  years and the party layout has always declared `OutOfRangeAlpha`; only the element was
  missing. Off by default, under Party > Use Range Indicator.
- **Target markers on party, raid (5) and target frames.** The skull, cross and star icons
  were only ever drawn on the 25 and 40 player raid frames. On by default, with a
  **Show Target Markers** toggle on each of the three.

### Housekeeping

- README and the badge workflow said 12.0 / Interface 120000. The TOC has been 120100
  since 12.1. Both are corrected; the workflow was the one that mattered, since it rewrites
  those lines in the README on every run.
- Eleven new locale keys, present in all ten locales. The German, Spanish, French,
  Italian, Portuguese, Russian, Korean and Chinese strings are new translations and have
  not been reviewed by the locale contributors.


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

## Older releases

Entries before `5.4.0-JuNNeZ` live in [CHANGELOG_ARCHIVE.md](CHANGELOG_ARCHIVE.md).
This file is published verbatim as the release description on GitHub, CurseForge, Wago and WowInterface, and GitHub rejects a body over 125000 characters, so older entries are rotated out rather than kept here forever.
