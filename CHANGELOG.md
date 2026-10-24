
# Changelog

## A note on WoW 12.1 addon development

Retail 12.1 protects more combat, aura, cooldown, and unit data as secret values. Addons can often display those values only by handing them directly to Blizzard-owned widgets instead of reading or formatting them, which is why one visual layer may keep working while related text or logic disappears; safe fixes increasingly require narrow ownership boundaries between Blizzard and other addons.

Release note rule: each version entry must include only what changed since the previous release (delta-only).
Do not repeat older items from prior versions in newer entries.
Writing workflow: [Tools/CHANGELOG_GUIDE.md](Tools/CHANGELOG_GUIDE.md). Lead with player benefits, then explain substantial development work and remaining limits.


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


## 5.30.1-JuNNeZ (2026-10-20) - No Health Bars on Gathering Nodes and Chests

### Highlights

- **Objects no longer get a health bar.** On WoW Forever, some gathering nodes, chests and other interactable objects drew an AzeriteUI nameplate health bar, with a chest reading "Dead" and a bank chair at full health. These plates now ask the game whether the unit is an object, as Blizzard's own nameplates do, and show only the name and interact icon when you mouse over or soft-target them. Thanks to Dcryfm for the report.

### Access and known limits

- Checked offline only; not yet confirmed in game. AzeriteUI still keeps object plates hidden until you mouse over or soft-target them, so names that another addon turns on for every node will not show through AzeriteUI's plates.


## 5.30.0-JuNNeZ (2026-10-17) - Fitted Class Endcaps, Flowing Mana Keeps Your Orb

### Highlights

- **Endcaps fit the health bar's ending.** Hunter, Mage, Paladin and Druid health ornaments now meet the casing at its existing lower point, including on mirrored target bars. Resizing an endcap keeps that joining point in place. Pick **None** for the complete themed casing without an ornament; adjust size and offsets under `/az -> Themes`.
- **More Druid and Paladin choices.** Druid now offers **Wildheart**, **Guardian** and **Moonkin**, with size, X/Y offsets and reset controls. Paladin adds **Silver Hand** and **Argent Crusade** alongside Ashbringer. Hunter keeps all five weapon choices; Mage keeps all five relics and its automatic school choice.
- **Cast endcaps have their own switch.** Hunter, Mage and Druid have refitted cast-bar ornaments, with an independent **None** choice and their own size and position settings under `/az -> Themes`. Hunter's cast ornament no longer changes with its health-bar weapon. Paladin keeps its separate libram controls.
- **Flowing mana keeps your chosen orb.** The switch under `/az -> Unit Frames -> Player -> Crystal & Mana Orb` now adds waves to the selected material and theme or Lite+ effect instead of replacing them with water. The thin bright surface line is removed. Standalone Moonwell+ keeps its lunar rim.

### Development

- **Rebuilt Hunter, Mage and Druid health artwork and cast ornaments** from whole paintings fitted to the native bars. Health and prediction keep their functional shapes, and saved frame anchors stay in place. Mage gains a matching foreground casing over the fill.
- **A shared endcap fitting method** measures each casing's lowest point and uses it as the ornament's scaling pivot. Each bar tier has matching art and a neutral threat halo that follows the game's existing threat display. Offline checks cover mirrored bars, sizes and offsets, intact bare casings, source hashes and the actual options on both clients.
- **Flowing mana now shapes the selected painting's surface** while its existing animations keep running underneath. It reuses the bounded slosh renderer without reading hidden resource values or creating a separate effect player for every wave strip. Regression checks cover material retention, effect switching and removal of the bright rim.

### Access and known limits

- These changes have been checked offline only. Retail and WoW Forever still need `/reload`, rendering, combat, Edit Mode and BugSack checks; performance has not been measured in game.
- The class themes remain WIP. If you previously adjusted an endcap, use **Reset endcap size and position** before judging its new default fit. Existing saved choices and offsets are retained.
- Hunter's wider artwork audit still has pre-existing findings outside this endcap correction.


## 5.29.0-JuNNeZ (2026-10-17) - Party Frame as Player Frame, a Gliding Mana Orb, Clearer Party Bars

### Highlights

- **Use the party frame as your player frame.** `/az -> Unit Frames -> Player (Party Style) -> Use Party Frame as Player Frame` shows you as a small party frame: the party health bar with a thin power line and the cast layer. Untick **Show Portrait** and the frame is just the bar, small enough to sit in the middle of the screen; the role, leader and raid marker icons move onto the bar. Turning it on turns off the standard player frame, and with it the mana orb, the power crystal and the auras next to the player frame. Your buffs stay at the top right. Suggested by Gravehowl.
- **Player Alternate is easy to find.** Player, Player Alternate and Player (Party Style) are now always listed under `/az -> Unit Frames`. Turning one on turns the other two off; turning Player Alternate or the party style off brings the standard player frame back. Before, Player Alternate only appeared after you had turned the player frame off.
- **Party health bars clear in more cases.** The 5.28.0 fix missed a case: a hunter's party bar stayed white-washed, and a druid's went tan again after leaving a dungeon. The casting layer on the bar now also goes away once the cast's own time has run out, whatever the game says. Thanks again to Dcryfm for the screenshots.
- **The mana orb glides.** The orb now moves smoothly to each new value like the health and power bars, and follows the same switch: `/az -> Unit Frames -> Smooth health and power` or `/azsmooth`. Thanks to Neil for spotting it.
- **Flowing mana.** `/az -> Unit Frames -> Player -> Crystal & Mana Orb -> Flowing mana` (off by default) fills the orb with flowing water and gentle waves while it shows mana, for any class and theme. It uses your resource colour and stands in for the theme's or Lite+'s orb effect while it is on.
- **Easier options.** The long Player page folds into sections, Explorer Mode is split into tabs, and searching for a setting opens the section or tab it is in.

### Development

- **The party-style player frame** is built by the party frame's own code, not a copy of it: a player flag leaves out what only a group member needs (the aura row, range fading, the Mythic+ rating). It has its own mover and settings, fades with Explorer Mode, and takes the Legacy look under the Legacy theme. The layout without the portrait lives in the party layout data, and changes wait for the end of combat, because the game does not let addons resize a unit frame in combat. New tests cover creating the frame once, the switch to the bar-only layout and back, the combat wait, Legacy and the one-at-a-time switches.
- **The cast layer.** 5.28.0 asked the game whether the unit was still casting; for some units the game kept saying yes after the cast had ended. The bar now also watches its own timer: once the cast is past its end on two checks in a row (half a second to a second late), it hides. A stop that arrives a little late still lands first, and a cast that is pushed back gets a new end time. Tests reproduce a game that keeps answering, a late stop and a pushed-back cast.
- **The orb's glide** comes from the game itself: the visible fill follows a hidden game bar, and that bar now eases. It keeps working in combat, when mana is hidden from addons. The orb still snaps to a new value on a form or vehicle change and after loading.
- **Options navigation** is a layer on top of the settings: folds and tabs only change what is drawn, so no setting disappears from search, Quick Start or Changed. Jumping to a setting opens every tab and section around it first. A new test checks this on both clients and fails on four deliberate mistakes.

### Access and known limits

- Everything in this release was checked offline only. Nothing has been tested in game yet, on Retail or WoW Forever.
- The party-style player frame has no aura row, mana orb or power crystal. Under the Legacy theme, Show Portrait does nothing: Legacy hides the portrait itself.
- On a client that does not send a cast's ID when it is pushed back, a party member's pushed-back cast can now end up to a second early on the bar.
- The orb's small spark jumps to the new value while the fill glides.
- What Flowing mana costs in frame rate has not been measured.


## 5.28.0-JuNNeZ (2026-10-16) - Druid Theme for Testing, Party Frames That Keep Up in Combat

### Highlights

- **Party health bars keep their class colour.** After a party member cast a spell (or shifted into bear form), their health bar could stay washed out for the rest of the session. A druid's orange then looked like a warrior's tan. The white "casting" layer on the bar now goes away when the cast ends. This also fixes cast bars elsewhere that stayed on screen after a cast. Thanks to Dcryfm for the report and screenshot.
- **The dispel glow and the debuff icon work in combat.** In dungeons and raids, the game hides details of debuffs from addons, and the party frame's "you can dispel this" glow and the important-debuff icon in the middle of the frame went blank, right when they were needed. Both now ask the game directly what *you* can remove, which is right for every class, spec and talent. The colour shows the debuff type. Hovering the icon shows the right debuff. Setting: `/az -> Unit Frames -> Party Frames -> Glow Frame For Dispellable Debuffs`.
- **New on party frames:** a crown for the group leader (a star for raid assistants), an icon for an incoming summon (purple while pending, green when accepted, red when declined), a mark for a member in another phase or War Mode, and a glow around the portrait when a member is tanking or has pulled aggro. They also appear under the Legacy theme.
- **The Druid theme is open for testing.** Pick **Druid (WIP)** under `/az -> Themes`: dark bark, moss and aged bronze casings, roots growing around the power crystal, a Moonwell mana orb, Dreamlight in the crystal and a Druid bag icon. Feedback on Discord is very welcome.
- **Four new Lite+ effects** under `/az -> Themes -> Lite+`, each with its own strength setting. For the orb, **Moonwell+ (WIP)** is moonlit water that sloshes as you move, and harder in combat, mounted or flying. For the crystal, **Wildheart**, **Moonvein** and **Dreamsap** are jade, blue-violet and golden energy that keeps moving, with a faint glow even when the crystal is empty.
- **Dead mobs lose their nameplate on WoW Forever.** A killed mob's plate used to stay over the corpse with "Dead" on it. Looting and skinning the corpse still work.

### Development

- **Cast bar fix.** The stuck cast layer was traced in the oUF cast bar. When a cast starts it remembers an ID, but the game does not always send that ID when the cast stops, so the bar never learned the cast had ended. The bar now asks the game whether the unit is still casting. A test reproduces casts and channels without the ID, and fails with the old code.
- **Party frame audit.** Incoming heals, absorbs and heal absorbs were already drawn on party frames and nameplates on both clients. The dispel glow and the debuff icon read debuff details that Retail 12 can hide in combat, and they used a hand-made per-spec dispel list that was also wrong for WoW Forever. They now use the game's own "what can I dispel" filter and its debuff colour curve, and pass hidden values straight to the textures. A new test feeds them hidden values and fails on five deliberate mistakes.
- **New indicator art.** Leader, assistant, summon, phase and the threat glow were drawn to match the existing role icons. The threat glow is traced from the portrait ring itself and stays outside it, so it never covers the portrait. A brief and a mockup for the art are in the repository.
- **Druid theme and the new effects.** The Druid art is built on the original casings, so frames keep their size and place. The crystal roots were refitted after a first look in game. The effects only paint over the game's own crystal and orb fill, and never read your mana or power.
- **Glass orbs in the themes.** Orbs in the Hunter, Mage, Paladin and Druid themes had a black hole and an overbright reflection. The glass is now copied from the original orb with the right tint, and a check stops it from breaking again.

### Access and known limits

- Everything in this release was checked offline only. Nothing has been tested in game yet, on Retail or WoW Forever.
- The Druid theme and Moonwell+ are marked WIP: expect rough edges, and on WoW Forever their art has not been checked at all. Switching to or from a theme reloads the interface. How much the new effects cost in frame rate has not been measured.
- The dispel glow now lights only for debuffs you can remove yourself. It used to also light for debuffs someone else in the group could remove.
- The debuff colours in combat come from the game's colour curve. Whether every debuff type gets the right colour still has to be confirmed in game.


## 5.27.1-JuNNeZ (2026-10-15) - Paladin Theme for Testing, Anchored Frames Stay Put, Reset Layout in /lock

### Highlights

- **The Paladin theme is open for testing.** Pick **Paladin (WIP)** under `/az -> Themes` (or type `/azpaladin`) to try the full Paladin look: casings rebuilt from the approved concept, the Ashbringer health endcap and libram cast endcap (each can be resized, moved or turned off), the Light-filled crystal and orb, and Paladin rings for the Cooldown Manager. It no longer needs Development Mode. It is still a work in progress, so screenshots and reports on Discord are very welcome.
- **Anchored frames keep their place after logging out.** Frames anchored to each other could end up somewhere else after a full logout and login: action bars slid off the bottom of the screen. Linked frames are no longer re-placed while the game loads. Everything now loads exactly where it was saved, and anchors pick up from there. If your bars already moved, drag them back once in `/lock` and they stay put. Thanks to Luciful for the report and screenshot.
- **Reset in `/lock` resets only the layout.** The Reset button in the `/lock` window used to reset every AzeriteUI setting, the same as the Profiles page. It is now **Reset layout**: every frame goes back to its default position, anchors and AzeriteUI Scale are removed, and all other settings stay as they are. The interface reloads. The full reset is still under `/az -> Profiles -> Reset`. Suggested by Luciful.
- **Target health glides cleanly.** On the target frame, the health spark now rides the moving edge of the bar instead of jumping to the end, and stays visible in dungeons and raids. The shaped health art keeps following until the glide is finished. Target power now obeys the **Smooth health and power** switch and `/azsmooth`.

### Development

- The anchoring fix comes from replaying a fresh login offline: Retail creates the action bars late, and a UI scale change before that scaled their anchor distances while the bars themselves were not rescaled, so linked bars were placed from mismatched numbers and saved there, a little further off at every login. At login and after a profile change, AzeriteUI now waits a frame and then reads each anchor's distance from the saved positions instead of moving frames. A new test replays that login order and fails with the old code.
- Reset layout shares its rules with Copy layout from: the same saved positions (including Legacy's), anchors and AzeriteUI Scale, and nothing else.
- An audit of the smooth bars and the target's mirrored health bar found and fixed eight issues, including a percent read as a fraction (very low health could draw as full for a moment) and health updates syncing the bar three times each. A new test runs the target's real health code.
- Before opening it up, the Paladin theme got an intact HD portrait, health casing ends that match with and without the Ashbringer endcap, and a studded protected-cast casing. Its theme, effects, Cooldown Manager and options tests now check that it is offered without Development Mode.

### Access and known limits

- Everything in this release was checked offline only; nothing has been tested in game yet, on Retail or WoW Forever.
- The Paladin theme is marked WIP: expect rough edges, especially on WoW Forever, where its art has not been checked in game. Switching to or from it reloads the interface.
- Frames that were already saved in the wrong place are not moved back automatically.


## 5.27.0-JuNNeZ (2026-10-15) - Anchored Frames, Frame Settings on Click and Smooth Bars

### Highlights

- **Anchor frames to each other.** In `/lock` (and in Blizzard's Edit Mode), pick a frame and choose **Anchor To**: another AzeriteUI frame, the point on each frame and the distance between them. When the frame you anchored to moves, everything anchored to it moves along, so you can chain bar 3 to bar 2 to bar 1 and move all three by dragging bar 1. Dragging an anchored frame changes its distance; Shift-click removes the anchor.
- **Frame settings on click.** Left-click a frame's mover in `/lock` or Edit Mode and a small panel opens beside it, like Edit Mode's own dialog: its position, a few of its most used settings, and **More settings** to jump to its full `/az` page (this also leaves Edit Mode, with Blizzard's usual question if you have unsaved changes there). Right-click, Esc or the X closes it, and the panel stays put while you scale or drag the frame.
- **Copy a layout from another profile.** `/lock -> Copy layout from` takes frame positions, anchors and AzeriteUI Scale from another profile into the one you use. Every other setting stays as it is. The interface reloads afterwards.
- **Smooth health, power and cast bars.** Health and power bars glide to each new value instead of jumping, and a cast that is pushed back slides to its new place. A new target, a new group member or a new cast still shows at once. Both are on by default and can be switched off under `/az -> Unit Frames` (**Smooth health and power**, **Smooth castbar pushback**) or with `/azsmooth`. The game does the gliding itself, so it also works in dungeons and raids where addons cannot read health and power.
- **Paladin Light for everyone.** `/az -> Themes -> Lite+` now offers **Paladin** for the crystal and the orb: slow golden waves of Light with small floating spheres, with the same strength setting as the other effects. It no longer needs Development Mode.
- **No more blocked-action errors from the world map in combat.** Opening the map in combat after having it maximized could raise `ADDON_ACTION_BLOCKED` errors (`SetPropagateMouseClicks`, `SetPassThroughButtons`), and hovering event markers on the map could raise `LayoutFrame.lua:491` errors. AzeriteUI no longer makes Blizzard redraw the map from addon code. Thanks to the player who sent the BugSack report.

### Fixes

- **Target castbar when you target yourself.** The castbar on the target frame squeezed and stretched while you cast with yourself targeted. It now fills like the player's.
- **Smoother combat.** Cooldown numbers on buttons and auras are only redrawn when they change, and Explorer Mode no longer re-checks every frame on each power and health tick.
- **Retail 12.1.5** is listed in the addon's TOC.

### Development

- Anchoring is built into AzeriteUI's frame manager. Anchors are saved per HUD (Azerite and Legacy separately), anchored frames wait for combat to end before moving, and positions keep their existing saved format, so older profiles and every place that reads them still work. Snapping now ignores a dragged frame's own followers and builds its guide lines once per drag instead of many times a second.
- Raid 25 and Raid 40 now share one body of code instead of two near-copies. Their names, saved settings and layouts are unchanged; a new test compared every group size, sort order and button position against the old files. The one intended difference is that Raid 40 gets Raid 25's safer column fallback.
- The smooth bars use the game's own bar easing, which accepts the hidden values. Making it look right took several rounds: refreshes and absorb updates were snapping bars mid-glide, writing the bar's range reset each glide, and the target frame's shaped health art had to follow a hidden helper bar so it does not stretch. `/azdebug` has a side-by-side Smooth bars preview and `/azsmooth trace` explains each write.
- The world map errors were traced to one Blizzard redraw call our map module made. It left the map's zoom values marked as addon-written, and Blizzard's own code kept that marking alive until the next reload. A new isolated taint test reproduces this and shows the fix stays clean. Other map addons were compared: some hide the same error by wrapping Blizzard's map pins, which AzeriteUI avoids.
- The Paladin theme (still a Development Mode preview) was rebuilt from its approved concept: new health, portrait and castbar casings at the original sizes, a measured crystal holder, an Ashbringer health endcap and a libram cast endcap that can each be turned off, sharper endcap and portrait art with matching threat outlines, and a Light-coloured crystal and orb option. The art is generated and checked by scripts in the repository.

### Access and known limits

- Confirmed in game on Retail: anchoring frames to each other, and the Paladin crystal holder. Everything else was checked offline only, and nothing in this release has been tested on WoW Forever yet.
- Smooth bars do not apply to nameplates, the target-of-target frame or the target castbar. A hit right after a target change shows at once.
- Players who saw the world map errors need one `/reload` after updating; updating normally includes one.
- The Paladin theme still needs Development Mode. Its Light-coloured crystal and orb option appears only while the Paladin art is active.


## 5.26.0-JuNNeZ (2026-10-14) - Pushback Time Toggle and Cast Bar Endcap Placement

### Highlights

- **Hide the pushback time.** When taking damage pushes your cast back, AzeriteUI shows the delay as red `+time` text to the right of the player cast bar. You can now turn it off: `/az -> Unit Frames -> Cast Bar -> Show Pushback Time`. It is on by default, so nothing changes unless you switch it off, and it applies at once. Requested by Neil.
- **Resize and move the cast bar's endcaps.** The Hunter theme (the bow tip and the eagle) and the Mage theme (Atiesh's head) now have cast bar endcap settings under `/az -> Themes`: size (50-200%), X and Y offset, and a reset. They are separate from the health bar endcap settings, apply at once and are saved per character. The endcaps grow and shrink around their own centre, and X moves them outward from the ends of the bar. Requested by Yarko.

### Development

- The themes' endcap settings were generalised so a theme can carry a second set that only has size and position. The cast bar endcaps use it in both themes, which keeps them independent of the health bar endcaps. The Hunter eagle is now anchored by its centre, so it scales in place; at 100% it sits where it did before. New offline tests check the size, outward movement and reset of the cast bar endcaps in both themes, and the locale check covers the seven new texts in all ten languages.

### Access and known limits

- Stock AzeriteUI, Legacy and the Paladin preview draw no cast bar endcap, so the new endcap settings appear only on the Hunter and Mage themes.
- The toggle covers the player cast bar. The target cast bar shows its delay inside its own time text and is unchanged.
- Checked offline only; not yet confirmed in game on Retail or WoW Forever.

## 5.25.0-JuNNeZ (2026-10-13) - Execute Range Page, Group Indicators, Aura Sounds and a Tidier Options Window

### Highlights

- **Execute range has its own page and stays inside the bar.** Every execute marker setting is now in one place, `/az -> Execute range`: a switch for nameplates, a separate one for the target frame, and the threshold, lead and colours they share. The nameplate line is cut from the bar's own art, so it no longer reaches above and below the health bar. New: **Only enemies you are fighting** (nameplates, on by default) shows the marker only on enemies that have you or your pet on their threat list. **Show from above the threshold** brings the line in early, for example 5% before your execute; the red tint still waits for the execute itself. **Own colours** sets the line and tint colours for both nameplates and the target frame.
- **Sated and corner aura dots on group frames.** `/az -> Group Frames -> Group Indicators`. **Show Sated** puts a small Bloodlust-used icon with a countdown on each party and raid member, in combat as well. **Show Corner Dots** shows your own buffs (or anyone's) in the four corners of each group frame, from spell lists you choose per corner, with a size setting and suggestions for your class. Both are off by default.
- **Aura sounds (Retail).** `/az -> Aura Sounds`: six slots that play a sound when a buff or debuff is gained, stacks or fades on you, your target or your focus. The game plays the sound itself, so it works in combat, raids and keys. Pick from **Common auras** (defensives and external cooldowns of every class, Bloodlust, and "Bloodlust ready again" when Sated fades) or type spell names or IDs. AzeriteUI looks up the aura each spell actually gives, which is not always the spell's own ID. A line under each slot says what the game answered. AzeriteUI now also adds eight of the game's own sounds to the list, so it is not empty without a sound pack.
- **Combat text works again.** Hit and heal numbers on unit frames now show in dungeons and raids, where the game hides the amounts from addons. Critical hits are drawn large again; they had been drawn like ordinary hits. New switch: `/az -> Unit Frames -> Show Combat Text`.
- **A tidier options window.** Party and raid settings moved to their own **Group Frames** page, with **Aura Sounds**, **Micro Menu** and **Execute range** also on their own pages. The Dismount Button is now on the Minimap page, and the Info Bar and Widgets pages are under World. Long pages, the page list and long dropdown lists now have a visible scroll bar, drawn like AzeriteUI's sliders, so nothing below the fold goes unnoticed. In the Rounded look, the sections under each page (Player, Target, Action Bar 1, Raid Frames, Visibility and so on) have small icons, the same in the page list and on the page; settings themselves get none.
- **Legacy is a theme like the others, and its proc styles differ again.** `/az -> Themes -> Theme -> Legacy` switches to it and back, as `/go legacy` does. Under Legacy, every proc and assisted highlight style and thickness had drawn the same square ring (reported by Luciful); each now has its own art.

### Fixes

- **Great Vault on the info bar opens the vault.** Left-click the vault counter to open or close Blizzard's Great Vault window. Nothing happens in combat.
- **No more Lua errors from aura tooltips on nameplates in dungeons** with Show spellID on, and none from the Sated icon in dungeons.
- **Player aura brightness catches up after a raid.** In raids the game does not let addons change existing aura icons, so a brightness change made there only reached new auras until `/reload`. The skipped icons now update when the restriction ends.

### Development

- The debug tools (`/azdebug`, its probes and test menus, about a fifth of the addon's code) are now a separate addon, **AzeriteUI5 JuNNeZ Edition Debug Tools**, packaged beside the main folder and loaded only on first use. Saved debug switches, script errors and the debug commands keep working from the main addon. New probes measure native radial fills, addon SVG files and the execute marker's geometry (`/azdebug radial`, `svg`, `onupdatemode`, `execute`).
- The Hunter, Mage and Paladin themes now run on one shared theme engine instead of the Paladin theme forwarding calls to the other two. Every themed layout and media lookup was compared before and after the move, and all of them were identical.
- Aura sounds required research into a new 12.1 function. It is the renamed private-aura sound function, it matches the aura's own ID, and registering waits only for combat, encounters, keys and PvP matches; the restriction tied to the map is active in the open world and had kept every slot waiting. Aura IDs that differ from their spell's are looked up in Blizzard's own Cooldown Manager data for your spells. The Common auras IDs were checked against other addons' aura lists.
- The scroll bars reuse the sliders' own art turned upright. The 30 section icons were drawn as an original set, generated by a script with the same rules and checks as the page icons. New offline tests cover combat text with hidden amounts, the group indicators, aura sounds, the debug loader, the theme engine, aura brightness in raids, the execute page and the scroll bars.

### Access and known limits

- Confirmed in game on Retail: the two-folder package and the debug tools loading on demand, combat text, Sated, corner dots, every execute marker change, Legacy from the Themes page and `/go`, the themes on the new engine, and aura brightness outdoors.
- Checked offline only: aura sounds (in testing the sound came only after combat; the latest changes address this but are not yet confirmed), the vault click, aura brightness in and after a raid, corner dot Only Mine and placement, the scroll bars and the section icons. Nothing has been tested on WoW Forever yet.
- Corner dots need the game's native aura containers, so they are Retail only; Sated shows on both clients. Corner dots show buffs only: the game does not filter friendly debuffs by spell.
- Aura sounds need Retail 12.1. A change made in combat applies when the fight ends.

## 5.24.0-JuNNeZ (2026-10-12) - Assisted Highlight, Rounded Options Window and Group Frame Fixes

### Highlights

- **The Assisted Highlight is yours to style again.** `/az -> Action Bars -> Assisted Combat Highlight` sets how Blizzard's suggested next spell is marked on your buttons: Highlight Style (Current glow, Solid outline, Soft glow, Outline + glow or Off), Thickness, Colour source (default blue, class colour or a custom colour) and Opacity, with a Preview and Reset. The old colour setting had been hidden because it no longer changed anything; this one does. By default the highlight looks as before.
- **A rounded options window.** `/az` now opens in a **Rounded** style built from AzeriteUI's own tooltip and aura borders, with a soft-cornered metal casing, a sunken page list, rounded highlights and an icon for every page. The previous look is still there: `Settings -> Appearance -> Window Style -> Classic` (asks to reload).
- **Party auras: choose how many per row, and the third one is back.** `/az -> Unit Frames -> Party -> Auras Per Row` (Automatic, or 1-6). Party frames showed two auras per row where there was room for three: the row was a hair narrower than three icons and the game wrapped the third.
- **Party mana no longer looks full while a healer drinks.** In group content the game hides mana values from addons; AzeriteUI then measured the hidden value against a stand-in maximum of 100, so the bar filled. The bar now gets the real (hidden) maximum, as health already did. This affects every power bar that uses the same code.
- **No more blocked-action errors when someone joins a raid mid-fight.** Setting up the new member's frame for right-clicks is not allowed in combat and raised an `ADDON_ACTION_BLOCKED` error per frame. It now waits until combat ends; left-click targeting works at once.
- **Legacy: an optional centred player frame, and no empty class power box.** Under `/go legacy`, `/az -> Unit Frames -> Player -> Center Without a Target` (off by default, suggested by Luciful) moves the player frame to the middle of the screen while you have no target and back beside the target frame when you pick one. The class power casing no longer stays on screen empty out of combat at full Holy Power, all runes ready or no Stagger.

### Development

- The proc highlight and the assisted highlight now come from one shared piece of code, so both offer the same styles while keeping their settings apart; the action button library only shows and hides the highlight, so it was not changed. The old colour values, which never reached the screen, are cleared on load.
- The Rounded window's art was rebuilt from AzeriteUI's own border images rather than new drawings: the straight edges are copied unchanged and only the corners are redrawn, rounded and with metal fittings, so the edges and joins still match the original art. The 26 page icons were drawn as an original set, in grey so they take each theme's colour. Both are generated by scripts in the repository, so they can be rebuilt and checked.
- The centred player frame had to work in combat, when addons may not move unit frames. A small piece of secure code run by the game moves it there, so in combat it jumps instead of sliding.
- New offline tests cover the assisted highlight (every style, thickness and colour, kept apart from the proc settings), hidden power maximums, the centred frame's positions, combat handling and secure code, the Legacy class power casing, the Rounded window in both styles, and opening "All release notes" from What's New before the options window exists. That last one raised an error, which is fixed in this release.

### Access and known limits

- All of this release is checked offline only (Lua syntax and the automated tests); none of it has yet been seen in game. Please report anything that looks out of place.
- A raid member who joins during a fight can be targeted at once, but their right-click menu works only after combat.
- Why mana went hidden while drinking specifically is not proven; the fix covers any hidden maximum.
- The centred Legacy player frame keeps its normal height, so in the middle it can cover the Legacy class power bar and touch the cast bar; its auras and the pet frame stay where they are. Where the game's secure code is unavailable (some WoW Forever builds), it moves only out of combat.
- `/az -> Nameplates -> Friendly Players` now notes that in dungeons and raids the game draws friendly plates itself; addons cannot change them, and their size follows the game's own nameplate Size setting.

## 5.23.0-JuNNeZ (2026-10-11) - AzeriteUI Scale, Dungeon Names and Legacy Fixes

### Highlights

- **Resize the whole UI with one slider.** `/lock` now has **AzeriteUI Scale** under Moving Frames (50-200%). It scales every AzeriteUI frame at once and keeps the layout's proportions: each frame grows together with its distance from its screen edge, so bars keep their spacing and corner frames stay in their corners. Each frame's own scale still applies on top, and Reset puts a frame back to its default at the chosen size. Nameplates keep their own size settings.
- **Friendly players' names are whole again in dungeons and raids.** There the game draws friendly nameplates itself, inside the plate size AzeriteUI sets for its own compact plates, so name-only players showed one letter and "..." (most visible with Chinese and Korean names). In dungeons and raids, while friendly players' plates are shown, the plate now takes Blizzard's own width.
- **Legacy: party and raid role icons no longer cover other frames.** Under `/go legacy`, the party role plate sat on top of the name and health value; it now sits on the frame's left edge. On raid frames the plate hung outside the frame onto its neighbour; it is now a small icon inside the bar's bottom right, and Dead/Offline moved to the bottom left so it no longer prints over the name.
- **Legacy: spell highlights show on the action buttons again.** Proc highlights, every proc style, the assisted highlight and the pet and stance highlights were drawn as a hairline square in the middle of the icon. They now ring the icon as they did in AzeriteUI 3.x.
- **Legacy: tidier frames.** Names stay on one line (long and Chinese names wrapped onto the text below), an empty power bar keeps its dark fill instead of a black strip, and the arena spec icon sits beside the frame instead of over the health value.
- **No more aura tooltip errors, and the world map no longer blocks quest pins in combat.** Hovering some auras in combat or restricted content raised "Secret values are only allowed during untainted execution"; those auras now show no tooltip, as Blizzard does not let addons look them up. Opening the map in combat could report a blocked `Button:SetPassThroughButtons()`; AzeriteUI no longer rewrites the maximized map's panel settings, which it did on every maximize.

### Development

- The master scale reuses the mover system's own answer to a change of the game's UI scale: every mover's scale and position, current and default, are multiplied by the change and each module saves the result as it does after a drag. The master scale is also part of the scale every default layout is built from, so a reload, a reset and the Legacy layout all agree with it. Tooltips had their scale applied twice and the micro menu, which has no mover, did not follow it; both were fixed along the way.
- For the dungeon names, Blizzard's nameplate source on both clients showed how its name-only friendly plates fit their name to the plate's width, and that one plate size serves every nameplate in the game. Outside instances, and in arenas and battlegrounds, AzeriteUI's plate size is unchanged.
- The Legacy layout converts each frame's normal settings, so pieces placed for Azerite's larger frames (role plates, status text, the arena spec icon) landed on or beside the much smaller Legacy bars. Every positioned element of each Legacy unit frame was compared with the Legacy frame sizes to find them. The square highlight ring fills only the middle half of its image; AzeriteUI 3.x drew it at about twice the button size, and Legacy now uses the same measure.
- New offline tests cover the master scale (the real scale code and frame handlers), the dungeon plate width (entering and leaving instances, toggling friendly plates, clients without Blizzard's width), and the Legacy role, status, spec icon and highlight placement. Each new check was confirmed to fail when its fix is removed.

### Access and known limits

- All of this release is checked offline only (Lua syntax and the automated tests); none of it has yet been seen in game. Please report anything that looks out of place.
- AzeriteUI Scale cannot be changed in combat. Switching to a profile saved with a different scale reloads the interface. A module that is turned off, and the theme you are not using (Azerite or Legacy), only have their default positions rescaled until you next use them, as with a change of the game's UI scale.
- In dungeons and raids, the wider plate also widens the space the game uses to stack overlapping enemy plates, so plates in a large pull may stack a little higher. Scenarios and delves are unchanged.
- The world map fix removes the most likely cause of the blocked action; other changes the map module makes could in principle still taint it. Please report it if the error comes back.

## 5.22.1-JuNNeZ (2026-10-10) - Release Notes Fit on GitHub

### Highlights

- **No changes to the addon itself.** The 5.22.0 release notes had grown past the size GitHub accepts, so that release could not be published there automatically. Older notes now live in the changelog archive, and every download page gets the full notes again. If you already have 5.22.0, this update changes nothing in game.

### Internal

- The nine oldest entries (5.4.0 to 5.4.8) moved to `CHANGELOG_ARCHIVE.md`. The in-game changelog still shows the 12 newest releases.

## 5.22.0-JuNNeZ (2026-10-10) - Edit Mode, Snapping and Mythic+ Extras

### Highlights

- **AzeriteUI's frames move in Blizzard's Edit Mode.** Open Edit Mode and every frame you would move with `/lock` shows up there too, so Blizzard's frames and AzeriteUI's are arranged in one place. Turn it off with **Show in Edit Mode** in the `/lock` window. `/lock` itself is unchanged and stays available.
- **Frames snap into place.** A frame you drag, in Edit Mode or `/lock`, snaps to the screen's edges and center, to other AzeriteUI frames, and to the Edit Mode grid when it is shown, with a gold guide line where it lines up. In Edit Mode it follows Blizzard's **Enable Snap** box; hold **Alt** to place a frame freely, or turn snapping off in the `/lock` window.
- **A cleaner Edit Mode.** Blizzard's outlines no longer show for frames AzeriteUI replaces: the cast bar, party frames, extra ability buttons, encounter bar, durability figure, the queue eye on the minimap, the tooltip position while AzeriteUI places tooltips, and on WoW Forever the two action bar gryphons.
- **Square and Rounded buttons in Mage and Hunter metal.** The Rounded and Square button shapes (`/az` -> Action Bars -> Button Shape) and the Cooldown Manager's square and rounded icons now wear the Mage or Hunter border while that theme is active, instead of AzeriteUI's.
- **Mythic+ extras** (`/az` -> Mythic+): the group's **battle rez charges** under the key timer, with the time until the next one, and an option to **hide Blizzard's completion banner** so only AzeriteUI's end-of-run card shows. Explorer Mode gets **During a Mythic+ key**, which keeps the interface up during a key even if you let it fade in other dungeons.
- **Mythic+ rating** for each party member, in the top right corner of their frame (`/az` -> Unit Frames -> Party Frames) and in player tooltips (`/az` -> Tooltips). Both are off by default.
- **Aura timer colors can be turned off.** `/az` -> Unit Frames -> **Color Aura Timers** keeps aura countdowns white instead of turning yellow, orange and red. Changing it reloads the interface.

### Development

- AzeriteUI does not register its frames as Edit Mode systems, which would taint Edit Mode for every frame in it. It listens for Edit Mode opening and closing instead, and copies Blizzard's own snapping rules (an 8 pixel range, the screen, the grid and other frames) for its movers. An offline taint test models Blizzard's callback registry and confirms Edit Mode stays secure.
- The leftover Edit Mode outlines on WoW Forever were found with a new `/azdebug editmode` report that lists every Blizzard frame whose outline is on screen. It showed that Forever's gryphons are Edit Mode systems of their own, which the tools had missed.
- The Mage and Hunter square borders were built from each theme's own round border material and keep the exact shape and transparency of AzeriteUI's square borders, so button sizes, spacing and saved layouts do not change. Tests check the art's outline, the rebuild and the routing for every bar, viewer and skin.
- Two future features were measured before being built. A test command showed that 160 aura trackers, enough for corner indicators on a 40-player raid, cost no measurable frame time in combat, so corner aura dots can go ahead. A second test showed that Blizzard's aura trackers cannot pick out Sated or Exhaustion, but those debuffs can be read directly, in combat too, so a "can lust again" indicator for group frames can be built that way.

### Access and known limits

- Edit Mode movers, snapping with the grid and Alt, and the hidden gryphon and cast bar outlines were confirmed live on WoW Forever. The other hidden outlines, and everything on Retail, are offline-tested.
- The Mythic+ additions (battle rez, banner, rating and Explorer Mode in a key) have not yet been seen in a key. Rating needs Retail.
- Square and Rounded Mage and Hunter borders are offline-tested only.
- Edit Mode still shows Blizzard's outlines for the objective tracker (moved in Edit Mode), Loss of Control and, on Forever, the totem bar; those frames belong to Blizzard.

## 5.21.0-JuNNeZ (2026-10-10) - What's New Popup and Even Aura Rows

### Highlights

- **A What's New window after updates.** A few seconds into your first login after an update, a small window lists what changed in a few short lines, each with a button that takes you straight to the setting. **Got it** hides it until the next update, **Remind me later** keeps it for next time, and you can turn it off for good on `/az` → Changelog. `/az whatsnew` opens it any time. It never appears after a `/reload`, waits until you leave combat, and stays quiet on a fresh install.
- **Target auras no longer get cut off.** With smaller aura icons or an auras-per-row limit, the target's auras wrap onto extra rows, and anything below the second row used to be clipped. The aura area now grows to fit.
- **Even aura rows everywhere.** The gap between some auras was twice as wide as the rest, so rows ended at different places and could wrap one icon early. Every gap is now your chosen spacing, on the target and player rows, party and raid frames, nameplates and the top-right buff row.
- **No empty class power box on Legacy.** Under `/go legacy`, classes without class power (such as Hunters and Warriors) showed an empty hexagonal box in the middle of the screen; it now only appears when there is something to show.

### Development

- The uneven rows came from how Blizzard's aura layout adds an extra gap between aura groups on the same line. AzeriteUI splits auras into several groups (important, boss, personal and so on), so a row with several group changes became wider; that extra group gap is now zero in every aura layout.
- The What's New notes are written by hand, separate from this changelog, so the popup stays short; the release build warns when a version has none. It comes with its own offline test suite, and its seven new strings are translated in all ten languages.

### Access and known limits

- The What's New window was checked live on Retail; the aura and Legacy fixes are offline-tested only.

## 5.20.1-JuNNeZ (2026-10-10) - Legacy Keybinds and Proc Highlights

### Highlights

- **Keybinds are back on Legacy action buttons.** Under `/go legacy` the hexagonal button casing was drawn over the keybind text, stack counts and spell activation (proc) highlights, so hotkeys vanished and procs barely showed. The casing now sits beneath them, on action, pet, stance and extra buttons.
- **Proc highlight options work under Legacy.** With the highlight no longer hidden, style, colour source, colour and opacity under `/az` → Action Bars → Proc Highlight take effect. Thickness is hidden while Legacy is active, because Legacy draws every proc style with its own square highlight.

### Development

- AzeriteUI's own copy of LibSharedMedia is now the latest version, the same one the published download already carried, so local builds match what players run. That version reports addons that register fonts or sounds that don't exist; AzeriteUI's own 50 media files were checked and all exist.

### Access and known limits

- Offline-tested only; not yet confirmed in game.
- If another addon registers a missing font or sound, LibSharedMedia now reports it as an error naming that file. The fix belongs to the addon that registers it.

## 5.20.0-JuNNeZ (2026-10-10) - Target Execute Marker and Cooldown-Ready Alerts

### Highlights

- **Execute marker on the target frame.** Turn it on under `/az` → Unit Frames → Target → **Execute range**: a line marks your execute threshold on the target's health bar, and the part below it turns red once the target drops into range. It follows every target tier (normal, elite, boss, critter, and the SaiyaRatt art), hides on friendly or non-attackable targets, and shares its threshold with the nameplate marker, so **Automatic** (your class and spec's execute) or **By hand** set on either page moves both. Off by default.
- **Cooldown-ready alerts in the Cooldown Manager.** Under `/az` → Cooldown Manager → **Cooldown-ready alerts**, choose Essential and/or Utility cooldowns and their icon flashes gold around its whole casing the moment the cooldown comes back, with an optional sound. It only fires on a cooldown you actually watched recover, never at login, on the global cooldown, or for an icon that was already ready. Off by default; it needs AzeriteUI's Cooldown Manager styling.

### Development

- Both features were built to work with Retail 12.1's hidden combat numbers. The execute marker hands Blizzard's own health curve to the red zone instead of reading the target's health, and the alerts watch a hidden copy of each cooldown rather than reading cooldown times. Where a client lacks what either needs, the option is greyed out with an explanation and nothing is built.
- The alert flash was redone twice after in-game reports that it was too faint, and spells that can hold charges now alert when their ordinary cooldown recovers. The `/azdebug cdready` probe on the Debug tools page was used on Retail to compare how a spell's cooldown is reported in and out of combat.
- New offline test suites cover the execute marker on every tier and fill direction and the alerts across both cooldown viewers, charge spells, combat and cleanup, including runs that simulate a tainted caller. Ten new strings are translated in all ten languages.

### Access and known limits

- Offline-tested. The alert flash and charge-spell recovery were seen live on Retail during development; the finished features still need a full in-game pass on Retail and Forever.
- Alerts are for an ordinary cooldown coming back, not for each charge of a multi-charge spell.

## 5.19.3-JuNNeZ (2026-10-10) - Aura Size, Target Power and SaiyaRatt Imbues

### Highlights

- **Smaller aura icons no longer overlap.** Setting the target's aura size below about 34 under `/az` → Unit Frames → Target left the icons at their default size while spacing them for the smaller one, so they piled on top of each other, and icons added later could come out a different size. Every icon now follows the size you pick, on the target, the player row and group frames.
- **Auras per row works on the target.** The setting had no effect on Retail's target auras; it now limits each row to the number you choose. 0 still fills the frame's width.
- **Aura timers fit small icons.** Duration and stack numbers now shrink with the icon instead of spilling over their neighbours. The default size looks the same as before.
- **Legacy target power bar shows its fill again.** Under `/go legacy` the target's power bar showed only its dark background; the coloured fill was hidden underneath it.
- **Weapon enchants on the SaiyaRatt profile.** Imbues, poisons and oils now show in the SaiyaRatt player aura row too, as they do on the standard player frame.

### Development

- The aura problems came from buttons being sized once, at creation, from the layout default while the chosen size only reached their placement. Sizes now flow through to every button and text, and the offline aura tests cover size, per-row width and text size.
- Fixing a Debug tools page error (a test status line formatting a missing spell ID) let the options panel test run in full again; it then showed that Extra Button Shape had no preview, which it now has.

### Access and known limits

- Offline-tested only; not yet confirmed in game. SaiyaRatt's player auras still use the standard filtering, as before.

## 5.19.2-JuNNeZ (2026-10-10) - Legacy HUD Repairs and a Full Profile Reset

### Highlights

- **Switching to Legacy no longer erases your Azerite action bar settings.** On Retail, going to `/go legacy` and back could silently reset bar fading, bar direction and bar anchors in your normal layout to their defaults. It no longer does. Settings already lost this way have to be set once more under `/az` → Action Bars.
- **Legacy keeps its own minimap and cast bar spots.** Moving the minimap or the cast bar under Legacy no longer changes where they sit in your Azerite layout, and both now start in their original 3.x places (minimap top right, cast bar bottom centre).
- **The Legacy minimap shows its own ring.** It was drawing the Azerite ring art shrunk inside the map; the old Legacy stone ring now sits around the map edge.
- **Cleaner Legacy unit frames.** The target portrait (the 3D model as well as the flat picture) no longer peeks out under the target frame; Target, Target of Target, Focus and Boss show their names again; the small frames get the 3.x hex casing without the dark square corners.
- **Cast bar.** Fishing, channels and casts that can't be interrupted no longer show a stray casing poking out of the Legacy cast bar.
- **Minimap Enable works straight away.** If the minimap was turned off when you logged in, switching `/az` → Minimap → **Enable** on now applies at once instead of after a reload.
- **Profiles → Reset now really resets everything.** It also clears settings kept for modules that were not loaded at the time (such as Legacy's own layout) and this character's own choices (theme, Lite+, Mage crystal, addon conflict and game menu picks), then reloads so every page shows its defaults. Account-wide settings, game options and your Edit Mode layout are left alone. The confirmation now says plainly that everything goes back to default.

### Development

- The action bar and minimap problems were traced through the saved settings themselves: comparing saves before and after a Legacy round trip showed the lost values were exactly those that matched Legacy's defaults. The cause was Retail's delayed start for the action bars and minimap, which bypassed Legacy's separate settings.
- Legacy's offline tests now load that Retail start-up code directly, and also cover the portrait, names, casing sizes, cast bar and cast bar position (76 checks). The tests also exposed and fixed a Lua error Legacy would have raised for a module that had never saved settings, such as on a fresh install.

### Access and known limits

- Offline-tested. The causes were confirmed with live readouts and saved settings from Retail; the fixes themselves still need checking in game, and on Forever.
- The full reset is offline-tested only; it has not yet been run in game.

## 5.19.1-JuNNeZ (2026-10-10) - Legacy Portrait and Minimap Fixes

### Highlights

- **No more stray portrait under the Legacy target frame.** When a target's 3D model was not ready yet, AzeriteUI showed a flat picture of the target instead, and Legacy did not hide it. It is now hidden along with the model.
- **Turning the minimap back on brings the AzeriteUI minimap back.** If you had used **Restore Blizzard Default** (for example while running another minimap addon), switching `/az` → Minimap → **Enable** back on kept Blizzard's look, and the page had no way to change it. Enable now restores the AzeriteUI look. This affected every layout, not just Legacy. Without updating, `/setminimaptheme azerite` does the same.

### Access and known limits

- Offline-checked only; not yet confirmed in game.
- Two more Legacy reports are still under investigation: an extra background showing around the cast bar, and the target-of-target frame's background.

## 5.19.0-JuNNeZ (2026-10-09) - Legacy HUD, Button Shapes and Debug Tools

### Highlights

- **The original compact AzeriteUI / GoldpawUI look is back as the Legacy HUD.** Type `/go legacy` out of combat to switch, `/go azerite` to return, `/go status` to check; switching reloads. You get rectangular unit bars instead of the crystal and orb, rounded square buttons with the hexagonal casing that lights up on hover, the old minimap ring, aura borders and combat icon. You can also choose it on the Themes page once it is active.
- **Your normal layout is left alone.** Legacy keeps its own saved positions. By default the minimap sits top right with its text and widgets underneath, the buff row beside it, and tooltips, durability and vehicle seat in their old spots. Move anything you like; going back with `/go azerite` restores your Azerite profile exactly as it was.
- **Square and rounded buttons.** Every action bar, the pet bar and the stance bar has a **Button Shape** choice (Circle, Rounded, Square) under `/az` → Action Bars, and the extra action and zone ability buttons have **Extra Button Shape**. Circle stays the default; a change asks you to reload. Spacing is unchanged, and pet and stance buttons are scaled to their smaller size.
- **`/azdebug` now opens a Debug tools page in the `/az` window.** Five sections (Cooldown tests, Health and unit frames, Keybindings, Raid utility bar, Utilities) replace the crowded old debug popup. Debug output goes to the _DebugLog addon's AzeriteUI tab when it is installed, and to chat otherwise. Development Mode is required for most tools.

### Development

- Legacy is a port of the AzeriteUI 3.x layout onto today's code, not a reinstall of the old addon. Its sizes, art and positions come from the 3.x source and its art is used with separately granted permission. Today's unit frames, health prediction, auras and secure action paging keep running underneath. Every 3.x Legacy layout setting and texture was audited against the port. Chat and tracker placement, the old pull-out bar panels, faster fading and the split aura filters were left out on purpose, as layout or behaviour rather than look.
- Legacy layouts live in separate saved settings per module. Your usual choices, such as aura filters and text, carry over once; positions never do. Hunter, Mage and Paladin theme art and Lite+ effects stand aside while Legacy is on.
- The button shape art and sizing are shared by all button types and scale to each button's cell, so the Circle look and spacing are untouched.
- The Debug page's cooldown tests compare several cooldown sources for one spell through a real recovery, to investigate spells whose ready state Blizzard reports inconsistently. Start, status and stop work in combat; they never cast anything.
- Offline harnesses cover the Legacy layout and profile isolation, the shape sizes, and the Debug page's controls, combat gating and log routing.

### Access and known limits

- Everything here is offline-tested only. Legacy rendering, the shapes' fit in game and the Debug page still need live confirmation on Retail and Forever.
- Nameplates keep their modern look under Legacy. The tracker (Edit Mode) and chat stay where you put them.
- Legacy is for the main AzeriteUI profile; it refuses to switch on while a variant such as SaiyaRatt is selected, and never in combat.

## 5.18.2-JuNNeZ (2026-10-09) - Imbue Tooltip Taint Fix

### Highlights

- **Hovering a weapon imbue icon no longer raises a taint error.** On Forever, the imbue icons added in 5.18.1 showed their tooltip in a way the client refused ("Anchoring disallowed ... UntrustedLayoutScriptExecution"). The tooltip is now anchored to the screen at the icon's top-left corner, so it sits slightly differently from before.

### Access and known limits

- Offline-checked only; not yet confirmed in game. Retail is unchanged.

## 5.18.1-JuNNeZ (2026-10-08) - Shaman Imbues on Forever

### Highlights

- **WoW Forever: Shaman imbues now show in the player aura row.** Flametongue, Windfury, Rockbiter and other weapon imbues get their own icon at the start of the row, with a countdown, charges and the weapon tooltip, even while you have a target. In 5.18.0 Forever showed only oils and stones there. **Show Weapon Enchants** and **Show Debuffs Only** control them too.

### Development

- On Forever an imbue is its own enchant type that Blizzard's aura container never receives. Several current Forever addons draw imbues themselves for the same reason. The row now reads every weapon enchant through Forever's own API and draws AzeriteUI icons for the ones the container leaves out, skipping the oil it already shows. Every value is checked for secrecy before use, and anything unreadable is skipped. The offline harness gained a Forever section, including fake secret values and three more deliberately broken copies.

### Access and known limits

- Offline-tested only; not yet confirmed in game on Forever. If you recast an imbue in combat, its icon updates at once, but the row only makes room for it when combat ends. Imbue icons have no right-click cancel, and the top-right buff list still cannot show Forever imbues. Retail is unchanged.

## 5.18.0-JuNNeZ (2026-10-08) - Weapon Enchants on the Player Aura Row

### Highlights

- **Weapon enchants now show in the aura row above your health bar.** Shaman imbues such as Flametongue, Rogue poisons, oils and whetstones appear right after your debuffs, with their timer, even while you have a target. Before, they only appeared in the top-right buff list, which hides while you have a target and fades out unless you hover it. Turn them off with `/az` → Unit Frames → Player → **Show Weapon Enchants**. The setting applies at once, with no reload. **Show Debuffs Only** hides them too.
- **`/azdebug aurasnapshot topright` works again.** It now reads the current top-right list, including its weapon-enchant buttons and the fade and visibility settings, instead of always reporting zero buttons. The aura snapshots no longer raise "boolean test on a secret boolean value" on Blizzard's aura buttons.

### Development

- Weapon enchants are not auras, so no buff filter could ever include them. The row now registers Blizzard's own item-enchantment slots on its player container. Retail 12.1.0 cannot remove a slot once added, so turning the option off swaps the row to a second container without slots; 12.1.5 and Forever switch the slots off in place. A new offline harness checks both shapes, combat deferral and the vehicle row, and is itself tested by ten deliberately broken copies.
- The investigation started from a player report (Shaman, Flametongue not visible). It confirmed that the row's other filters work as designed: buffs longer than five minutes or without a timer stay in the top-right list in stock mode.

### Access and known limits

- The enchant icon and the top-right snapshot were confirmed live on Retail. Turning the option off and on without a reload, Show Debuffs Only and everything on Forever are offline-tested only. On Forever it is not yet known whether Blizzard's container receives Shaman imbues at all.
- The Player Alternate frame (SaiyaRatt profile) does not show weapon enchants yet.

## 5.17.2-JuNNeZ (2026-10-07) - Pet Health Background and Edit Mode Fixes

### Highlights

- **Pet health loss now has a dark background**, matching the other unit frames instead of showing the world through the empty part of the bar.
- **Blizzard's replaced party, raid, arena and personal-resource previews no longer show in Edit Mode.** Their selection outlines and checkboxes are hidden too, including arena member debuff icons and cast bars. The minimap and Vehicle Exit button selection outlines are hidden as well.
- **AzeriteUI stops adding power-update events to Blizzard's alternate power bar**, avoiding the nil maximum-power error reported when the counter is not initialized.

### Development

- Edit Mode suppression uses post-hooks and alpha-only hiding, restoring preview alpha on exit without changing Blizzard's Edit Mode registry. `/azdebug editmode` reports preview, overlay, checkbox and arena-member state. The Elune harness checks that the selection hook leaves the registry untouched.

### Access and known limits

- Edit Mode hiding was confirmed live on Retail 12.1; Forever is not yet confirmed. The pet background and alternate-power change have not yet been confirmed in game.

## 5.17.1-JuNNeZ (2026-10-06) - Pet Bar Keybinds Actually Cast

### Highlights

- **Pet action bar keybinds now cast the ability instead of doing nothing.** Pressing a keybind on a pet bar button (reported on Warlock) silently toggled autocast instead of using the action, so most presses appeared to do nothing even though the correct keybind was shown on the button. Mouse clicks on the pet bar were unaffected. Left-click and the assigned keybind now behave the same.

### Development

- Root cause: pet buttons use Blizzard's own `PetActionButtonTemplate`, whose click handler only calls `CastPetAction` when the click's button name is literally `"LeftButton"` and otherwise calls `TogglePetAutocast`. The pet bar's keybind-to-click simulation used a virtual `"Keybind"` button name (the convention our LAB-driven action and stance bars use, where it is recognized and mapped back to `"LeftButton"`), which Blizzard's plain pet button mixin does not recognize, so every keybind press fell into the autocast-toggle branch. `Components/ActionBars/Elements/PetBar.lua`'s retail keybind path now simulates a `"LeftButton"` click for pet buttons specifically.

### Access and known limits

- Verified offline (`luac -p`, lint). Live `/reload` confirmation of pet bar keybind casting on a pet class is still owed.

## 5.17.0-JuNNeZ (2026-10-06) - Plays Nice with Other Addons

### Highlights

- **AzeriteUI asks which addon you want when ArcUI or BetterCooldownManager is enabled.** Both restyle Blizzard's Cooldown Manager the same way AzeriteUI does, and two styles on the same icons do not work together. Until now AzeriteUI quietly stepped aside. A few seconds after login you now choose: **AzeriteUI** (turns the other addon off for this character and reloads), **the other addon** (AzeriteUI steps aside, no reload), **Both** (both keep styling, unsupported, reloads) or **Decide Later**. Change your answer under `/az -> Cooldown Manager -> Choose again`.
- **CooldownManagerCentered and AzeriteUI's Cooldown Manager style now work together.** Out of the box that addon only centres the rows, so AzeriteUI no longer steps aside for it.
- **Baganator and BetterBags are left alone.** While either is enabled AzeriteUI no longer moves Blizzard's bag slots, the same as with AdiBags, Bagnon and the other bag addons. The bag button beside the cog opens them as before.
- **The info bar colours the zone name by PvP type on Forever too.**
- **The Hunter theme's protected-cast preview keeps its frame** in `/az -> Themes -> Bar tests`, matching the 5.16.4 castbar fix.

### Development

- Went through the roadmap's planned compatibility list against each addon's newest source. Only real clashes get the question, where the other addon changes the same frames in a way that breaks AzeriteUI's version; addons that only add tooltip lines (RaiderIO, ArchonTooltip) need nothing. Cell's newest release no longer ships a Retail or Forever version, and OmniCD's is still marked for an older game version on both clients, so neither needed a change. The question is a shared piece other features can use for future clashes.
- Action buttons, the chat setup at login and the keybinding mode's open-chat key now use the game's current functions instead of names that only exist while Blizzard's deprecation fallbacks are on. This also fixes range colouring for actions that check a specific unit.
- Regression tests cover the question's four answers, each answer being remembered or asked again, and which addons count as a clash.

### Access and known limits

- Verified offline only; live confirmation on Retail and Forever is still owed, including each answer with ArcUI and CooldownManagerCentered with the Circular icon style.

## 5.16.4-JuNNeZ (2026-10-06) - Hunter Castbar Fix

### Highlights

- **The Hunter theme castbar keeps its frame on every cast.** Casts that cannot be interrupted, such as planting herbalism seeds, making mulch or Dismiss Pet, showed the fill with no frame around it. AzeriteUI swaps in a spiked frame for these casts, and the Hunter theme hides that one, so nothing was left. The Hunter theme now keeps its normal frame; the red fill still marks the cast as uninterruptible. Other themes are unchanged.

### Development

- Explorer Mode and the vehicle exit button now ask for the vehicle, override, possess and bonus bar state through the game's current action bar functions. The old names only exist while Blizzard's deprecation fallbacks are switched on, which they are by default, so nothing changes today; this keeps both working if that setting is turned off or removed.

### Access and known limits

- Verified offline only; live confirmation on Retail and Forever is still owed.

## 5.16.3-JuNNeZ (2026-10-05) - Explorer Mode and Cooldown Manager Follow-ups

### Highlights

- **Explorer Mode no longer stays visible after combat because of old health readings.** 5.16.2 fixed this for mana; health could do the same. In combat the game hides health from addons, so AzeriteUI fell back on the last value the player frame could read. After the fight that value could still look low even at full health, and no further health update came to correct it. Explorer Mode now asks the game directly whenever it can.
- **Tracked Buffs stack counts show above the Cooldown Manager border.** Since 5.16.0, the stack numbers and debuff border on Tracked Buffs icons were drawn under the AzeriteUI border.
- **Blizzard's pandemic effect on Tracked Buffs icons shows above the border**, like the proc glow fix in 5.16.2.

### Development

- An audit of the 5.16.2 fixes found these three. The Cooldown Manager regression test now also covers the pandemic effect, the Tracked Buffs counts and border, and putting them back when styling is turned off. Offline tests of the Explorer Mode health and mana checks pass.

### Access and known limits

- Verified offline only; live confirmation on Retail and Forever is still owed.

## 5.16.2-JuNNeZ (2026-10-05) - Proc Glow and Explorer Mode Fixes

### Highlights

- **Proc glows show on top of Cooldown Manager buttons again.** With the Cooldown Manager styled, Blizzard's proc glow drew behind the AzeriteUI border. It now sits over the border, with charges and stacks still readable on top.
- **Explorer Mode fades out again after combat.** On mana classes and Druids, the action bars and other faded elements could stay visible after a fight until `/reload`. In combat the game hides current mana from addons, and that hidden value was being treated as low mana. With mana full, nothing cleared it afterwards. Hidden mana now counts as unknown, and health and mana are checked again when combat ends.

### Development

- Traced both problems through Blizzard's own code: the proc glow is created on first use, one frame level above the button, and current and maximum mana are hidden under separate rules. The Cooldown Manager regression test now covers the glow sitting above the border, both for glows that existed before styling and ones created after, and that it goes back to Blizzard's layer when styling is turned off.

### Access and known limits

- Verified offline only; live confirmation on Retail and Forever is still owed.

## 5.16.1-JuNNeZ (2026-10-05) - Cooldown Manager Font Fix

### Highlights

- **Fixed "Font not set" errors from the Cooldown Manager.** Utility ability keybind labels now use a shipped font instead of requesting a missing size, allowing the viewer to finish styling on login and when refreshed.

### Development

- The regression check now uses the addon's actual font definitions and rejects text writes without a configured font. It reproduced the reported error before the fix and passes afterward.

### Access and known limits

- Verified offline; please reload and check Utility keybind labels in the client. Live confirmation on Retail and Forever is still owed.

## 5.16.0-JuNNeZ (2026-10-05) - Cooldown Manager Skin and Alternate-Power Fix

### Highlights

- **Blizzard's Cooldown Manager in AzeriteUI style.** `/az -> Cooldown Manager` skins the Cooldown Manager's four viewers with circular, square or rounded buttons. The circular style has its own skin setting: follow the interface theme (default), AzeriteUI, Mage or Hunter (Paladin in Development Mode), so it can differ from the theme in use. Square and rounded buttons use new AzeriteUI backdrop and border art. Changes apply at once.
- **Cooldown Manager follows Explorer Mode.** A new "Cooldown Manager" fade option on the Explorer Mode page fades the viewers with the rest of the interface, without touching Blizzard's own alpha or Edit Mode opacity.
- **Fixed an alternate-power bar error flood.** The player's alternate power bar (boss and encounter resources) no longer has its event handler called from AzeriteUI, which tainted the bar and made its per-frame update compare secret power values. Blizzard's own events now set it up.

### Development

- **Built the skin on proxies the module owns instead of altering Blizzard's viewers.** Offline tests cover each skin choice, old profiles with no skin saved, missing theme modules, the options dropdown and Development Mode availability; all ten locales were updated and kept at parity. Added harnesses for the Cooldown Manager and the alternate-power bar.

### Access and known limits

- Offline results only; live confirmation in the client is still owed for the Cooldown Manager (all four viewers, newly pooled icons, combat, Edit Mode) and the alternate-power fix.

## 5.15.0-JuNNeZ (2026-10-05) - Proc Highlights, Skyriding Bars, and Theme Bar Tests

### Highlights

- **Make ability procs easier to see.** `/az -> Action Bars -> Proc Highlight` lets you choose how a proc lights up an action button: the current ring (still the default), a solid outline, a soft glow, outline and glow together, or off. The new styles come in thin, medium and thick, in the default gold, your class colour or a colour of your own, at any opacity. A preview button shows a sample without casting anything, and a reset button puts it back. Changes apply at once, without a reload.
- **Keep a secondary bar while skyriding.** Each Retail secondary action bar now has "Show while skyriding", next to "Show while mounted". Until now "Show while mounted" could not keep a bar during skyriding, when bar 1 switches to the riding abilities. The two settings are now separate, and both descriptions say which kind of riding they cover.
- **Test every bar shape in a theme.** `/az -> Themes -> Bar tests`, or `/azmage preview`, opens a preview window with 23 sample bars in the real layouts: player and target at each level stage, boss, critter, focus, target of target, pet, party, raid, arena, cast bars (protected casts too), nameplates, crystals and orbs. Set the fill or let it cycle to see each theme's casings empty, partly full and full. It shows sample bars only and closes in combat.
- **More of the Mage theme (WIP).** A new crystal cap in dark violet and antique gold; a smaller Atiesh head on the cast bar that sits beside the bar instead of over it; a Mage north marker on the minimap that turns with the compass; and a water elemental seal at the end of the pet bar. The Mage crystal can now follow your specialization's school ("Follow specialization" on the Themes page or `/azmagecrystal auto`, the new default if you never picked a school), with a slider for the energy's strength and a switch for its particles.
- **Hunter pet frame.** The pet's health bar now has the same faceted finish as the other health bars, and on Forever the pet's happiness shows as a green, yellow or red paw in the pet casing, with Blizzard's own tooltip when you hover it.

### Development

- **Built the proc styles around the action button library instead of replacing its alert.** The library still decides when a proc shows and hides; AzeriteUI only changes what it looks like, so turning the highlight off and on again during an active proc keeps it in step. Six new textures keep the inner edge of the existing ring, so the outline never covers the spell icon. An offline test covers each style, the preview, reset and every combination of the two riding settings, and fails when any of six deliberate faults is put in.
- **Found why mounted bars disappeared while skyriding.** The bar's visibility rule checks skyriding before it checks mounts, so the mounted setting never got a say. Rather than change that order, the skyriding setting each bar already had is now shown in the options.
- **Made the bar tests from the real layouts.** The preview window draws each sample from the same layout tables and casing art the frames use, without reading any unit or touching the real frames, so a casing that does not fit shows up before it reaches the game. An offline check of the art found that the Hunter theme's older textures do not yet match the native shapes everywhere; that art is unchanged in this release.

### Access and known limits

- **Not yet tested in the game:** all of this release is checked offline only, on Retail and Forever alike.
- "Show while skyriding" is for Retail; Forever has no skyriding.
- The themes remain works in progress. Parts of the Mage art set are still unused: the glowing inlays, the orb materials and the panel tint. The Paladin theme is still being redone.
- The new option text was translated without native speakers; corrections are welcome on the Discord.


## 5.14.1-JuNNeZ (2026-10-04) - The Mage Crystal Moves

### Highlights

- **The Mage crystal's energy moves.** In 5.14.0 the Mage crystal showed a still pattern; now the energy inside it flows again: drifting flames for Fire, cold mist and ice motes for Frost, and orbiting currents for Arcane. Turn it on or off with "Moving energy" and set its pace with "Animation speed" in the Mage crystal section of `/az -> Themes`, or with `/azmagecrystal flow`, `static` and `speed`.

### Development

- **Made the animation small enough to ship.** It was 398 MB, far too large to ask anyone to download. The crystal only ever shows the middle third of each frame, and the soft, volumetric energy loses nothing visible at a lower resolution, so each frame is now cut to the part the crystal shows and all 128 frames for a school share one texture. That comes to 24 MB for all three schools, about 8 MB in the download. Every frame is kept, so the motion and its smooth blending between frames are as they were. A script rebuilds the textures from the original frames and measures them against the source.

### Access and known limits

- **Tested in the game:** the maintainer confirmed that the animation looks right with the smaller textures.
- The themes remain works in progress, as described for 5.14.0.


## 5.14.0-JuNNeZ (2026-10-04) - A Themes Page, Lite+ Effects, and a Mage Theme Preview

### Highlights

- **Themes have their own page.** `/az -> Themes` has a dropdown for the art AzeriteUI is drawn with: AzeriteUI, Hunter, Mage, and Paladin in Development Mode. It shows only the settings of the theme you use. Every theme but AzeriteUI's own is marked (WIP) and may still change.
- **Lite+: mix crystal and orb effects.** Tick Lite+ on the Themes page to use another theme's power crystal or mana orb effect on the theme you are using, or on AzeriteUI's own art: the Mage crystal, or the Paladin or Hunter orb. Only the settings of the effects you pick are shown.
- **A Mage theme to try (WIP).** The Tirisgarde in Dalaran violet and Kirin Tor gold: every casing the theme replaces, from health, cast and nameplate bars to portraits, action buttons, the minimap, tooltips and the options window, painted to the same shapes as the originals. A staff caps the end of the health bars (by default the one for your crystal's school: Aluneth, Felo'melorn or Ebonchill, or pick Atiesh, Dragonwrath or none), Atiesh sits on the player cast bar, and a school badge on the crystal. Choose it on the Themes page or type `/azmage on`.
- **Hunter endcaps you can size and move.** Under the Hunter section, set the endcap's size and nudge it sideways or up and down; it grows and shrinks around its own centre, so it no longer drifts outward when made larger. `/azhunter endcapscale 0.5-2` does the same from chat.
- **Fewer reloads.** Only switching theme reloads the interface now. Endcap choice, size and position, Lite+ and its effects, and the Mage crystal's school apply at once; a new Hunter endcap used to reload.
- **Crystal and orb in front on Hunter and Paladin.** Their crystal and orb casings now sit in front of the health bar's ornate end instead of underneath it, where it covered part of them.

### Development

- **Separated a theme's layout from its effects.** Each theme still rebuilds the frame art when it is chosen, which is why switching theme reloads. The crystal and orb effects are now a separate layer that the player frame redraws on the spot, which is what lets Lite+ mix them and why everything except the theme itself changes without a reload.
- **Fitted the Mage art without moving anything.** The Mage pack replaces textures by name, on the same canvas and openings as AzeriteUI's own, so bars, fills and colours that change in play work as before. A new offline test walks the real layouts and fails if any size or position changes, and checks that every texture the theme asks for is shipped. The staves, cast head and badge use the anchor points the art was drawn for.
- **Retired the Hunter pilot and test art sets.** The art kept is the Hunter theme as it shipped, so `/azhunter pilot` and `/azhunter test` are gone along with their art, which also makes the download smaller.

### Access and known limits

- **Not yet tested in the game:** all of this release is checked offline only, on Retail and Forever alike. The Mage theme's fit in particular, the staves, cast head and badge, still needs live checking.
- **The themes are works in progress.** The Paladin theme is still for Development Mode only and is being redone.
- **The Mage crystal is static for now.** Its moving energy is not in this release; its textures are too large to ship until they are made smaller. With the Mage crystal on, the player power widget shows the crystal.
- Parts of the Mage art set are not used yet: the glowing inlays, the orb materials, the minimap north marker and the pet badge.
- The new option text was translated without native speakers; corrections are welcome on the Discord.


## 5.13.0-JuNNeZ (2026-10-03) - A Hunter Theme, Affixes and Bosses in Mythic+, a Bag Button, and Gamepad Glyphs

### Highlights

- **A Hunter theme to try.** Type `/azhunter on` to repaint the main AzeriteUI theme in Unseen Path colours: the health, cast and resource casings, portraits, the crystal and orb, action buttons, tooltips, the minimap and the options window, with a Hunter pet frame whose portrait moves like the target's. `/azhunter endcap` followed by `thasdorah`, `talonclaw`, `titanstrike`, `thoridal`, `raeshalare` or `none` picks the ornament at the end of the health bar. It is saved per character and reloads the interface outside combat; `/azhunter off` brings back the usual art and `/azhunter status` shows which set is on. `/azhunter pilot` and `/azhunter test` show two newer art sets that are still being worked on.
- **Mythic+ shows affixes and bosses.** The key frame now has a row of affix icons with their names (hover for the description, and a red note when the key was not charged), and each boss under the enemy forces bar, ticked off with the time of the kill. Blizzard's own key block no longer shows underneath it during the key. Each part can be switched off under `/az -> Mythic+`.
- **A bag button.** A round button in the action button art sits beside the cog: click it to open your bags, or to drop the item on your cursor into the backpack, and it shows your free slots, in red when the bags are full. It works in combat. Turn it off under `/az -> Action Bars -> Micro Menu`.
- **Controller buttons on your action bars, even without ConsolePort.** When you play with a controller, keys bound to it show the controller's own button icons on the action, pet and stance bars and the extra button, in the style of the pad you use; keyboard keys keep their text.
- **ConsolePort and DialogueUI fixes.** With ConsolePort, action buttons that showed the key as text instead of a gamepad icon now get ConsolePort's icons, with modifiers, and respect its setting to turn hotkey icons off. With DialogueUI, the 3D target portrait (and the party, raid, arena and alternate player portraits) now fades out with the rest of the interface during a conversation.
- **The orb follows your colour setting.** `/az -> Unit Frames -> Player -> Crystal/Orb Color Source` now colours the mana orb as well as the crystal; until now the orb was painted back to mana blue whatever you chose. On "Mana Orb Only", a class without mana sees its own resource in the orb (a Hunter's Focus) instead of an empty one.
- **Forever: action bar 1 swaps with your stance.** Bar 1 now pages for Warrior stances, and for every other class Blizzard gives a stance bar on Forever, as it already did for Druid forms and Rogue stealth. Your Shift+number paging still works on top.
- **More for Forever.** Blizzard's totem bar is no longer hidden (place it in Edit Mode), Hunters see their pet's happiness beside the pet frame, quest timers stay visible when the objective tracker is hidden, and the keybinding window no longer throws an error at login.

### Development

- **Made the Hunter art without changing how the frames work.** Each texture is painted to the size, openings and transparency of the one it replaces, so bars fill where they did and colours that change in play (health, power, threat) still come from the game. Scripts measure every texture against the original before it reaches the game; they also found and fixed tooltip and aura borders whose corners had been stretched into solid wedges.
- **Reworked how the orb picks and colours its resource.** It now asks which power the player actually uses instead of guessing from the mana value, and takes its colour from the same place as the crystal. The colour bug turned out to be a later step in every frame update that repainted the orb, which is why earlier attempts never reached the screen.
- **Made the unit frame stages work on every client and language.** Novice, Hardened and Seasoned art and the critter frame were decided by English names and one way of finding the level cap; they now use the game's creature type numbers and several fallbacks, switch on level-up without a `/reload`, and enemy level colours match Blizzard's own thresholds on both clients.
- **Kept the new buttons and icons out of protected code.** The bag button opens the bags through Blizzard's own backpack button, so no addon code runs in that chain. The controller icons are only redrawn as text, which is safe in combat. New offline tests cover the bag button, the controller icons, the ConsolePort and DialogueUI fixes, the unit frame stages and the Mythic+ additions, and fail when the key pieces are removed. They cannot show how anything looks in the game.

### Access and known limits

- **Tested in the game:** the Hunter theme and the orb colours on Retail. Everything else is verified offline only so far, and none of it has been tried on Forever yet.
- The Hunter theme applies to the main AzeriteUI theme only and switches off on the SaiyaRatt profile and the other layout variants. The `/azhunter` commands are temporary until a theme picker arrives in the options. A Paladin preview exists for development mode only (`/azpaladin`).
- With Blizzard's key block hidden, its buttons can still be clicked where it would be, as with the other ways the tracker is hidden.
- The download is larger than usual because it carries the theme art.
- The new option text was translated without native speakers; corrections are welcome on the Discord.
