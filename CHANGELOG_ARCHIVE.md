# Changelog Archive

Released entries rotated out of [CHANGELOG.md](CHANGELOG.md) to keep the published release description under the 125000 character limit GitHub enforces on release bodies. Newest first.

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

## 5.12.0-JuNNeZ (2026-09-26) - Mythic+ Timer, Great Vault, Pandemic Timers, and Dragging Back on Forever

### Highlights

- **A Mythic+ timer.** A new frame shows the running key: dungeon and level, a timer bar with marks where the +3 and +2 upgrades run out, how long you have left for the next one, your deaths and the time they cost, and a bar for enemy forces. The bar goes from green to yellow, orange and red as the upgrades slip away. Move it with `/lock`; turn each part on or off under `/az -> Mythic+`.
- **A card when the key ends**, showing your time against the limit, how many levels the keystone went up, your new rating and what it gained, and whether it was your best time in that dungeon. Click it to close it.
- **Your keystone slots itself.** Open the Font of Power and your key goes in. Untick `/az -> Mythic+ -> Slot your keystone automatically` to do it by hand.
- **Great Vault progress on the info bar.** "Vault 2/9" sits left of the latency and turns green when rewards are waiting; hover it to see each row and what the next slot needs. Turn it off under `/az -> Info/Clock Settings`.
- **Pandemic timers on aura icons.** On the player, target, group frames and nameplates, an aura's icon lights up gold for the last stretch in which recasting it loses nothing, the game's own pandemic window. Aura countdowns also change colour as they run out: yellow under 10 seconds, orange under 3, red at the end.
- **Forever: dragging actions and flyouts are back.** Forever 1.60.1.70009 fixed the game bug that stopped addons running secure code, so on that build and later you can drag spells onto and off the action bars again, open flyouts such as Mage portals, and use bar 1's vehicle exit. The chat message saying these were unavailable no longer appears.

### Development

- **Built the Mythic+ frame on the same data Blizzard's own tracker uses:** the dungeon's world timer and time limit, the death count and the enemy forces criterion, so the numbers match the default tracker. The end-of-run card reuses the game's own completion wording, so it reads correctly in every language, and every value is checked before any arithmetic in case a later patch starts hiding it.
- **Made the aura timers work within the new secret aura rules.** The time left on an aura is hidden from addons in many places, so AzeriteUI hands the game a colour scale and the pandemic highlight and lets the game apply them, instead of reading the time itself.
- **Traced the Forever fix to Blizzard's files.** The newest Forever build changes the load order that had broken secure code since the beta began. AzeriteUI now checks each Forever build once, as it already does on Retail, and falls back to the old workaround if a later build breaks it again.
- **Added an offline test for the Mythic+ features and the vault counter.** It drives the real code through a key's stages, deaths, enemy forces, the end-of-run card, keystone slotting and the vault. It also showed that one of the existing checks had stopped running, which is fixed. These tests cannot show how anything looks in the game.

### Access and known limits

- **Verified offline only:** none of this has been seen in the game yet. The Forever fix follows Blizzard's published files for build 70009.
- The Mythic+ frame, card and Great Vault counter are Retail only. Blizzard's own completion banner still shows next to the card, and clicking the vault counter does not open the Great Vault.
- Aura countdowns now use the game's number format, which may read slightly differently from before.
- The new option text was translated without native speakers; corrections are welcome on the Discord.


## 5.11.1-JuNNeZ (2026-09-26) - Minions for Your Target, and No Names Over Corpses

### Highlights

- **Minions only for your target.** A new switch under `/az -> Nameplates -> Visibility` does for players' pets, totems and guardians what 5.11.0 did for friendly NPCs: friendly or enemy, they show a nameplate only while you target them, and tab-targeting an enemy pet counts. Ticking it turns on the game's **Enemy minions** and **Friendly minions** settings, which it needs. Both now also sit under `/az -> Nameplates -> Game settings`, so you can turn them off again there.
- **No more names floating over corpses.** Looting or skinning a dead enemy showed its name hanging over the body, because dead units have no nameplate to carry it. Untick `/az -> Nameplates -> Game settings -> Your target's floating name` to hide it. It is the game's own setting, one Blizzard's Options do not offer.

### Development

- **Found where the corpse name comes from.** The game drops a unit's nameplate when it dies, so there is nothing for AzeriteUI to draw in its place. Going through the game's name settings on both clients turned up one that shows your target's name when no other setting would, and turning it off in game hid the corpse name; the new switch passes it straight through. Minions are recognised the way Blizzard's own nameplates recognise them, and the offline nameplate test covers both switches.

### Access and known limits

- **Your target's floating name** is not limited to corpses: with it off, no target without a nameplate shows a name over it. A target with an AzeriteUI nameplate still shows its name on the plate.
- The new option text was translated without native speakers; corrections are welcome on the Discord.

## 5.11.0-JuNNeZ (2026-09-26) - Friendly Nameplates Only for Your Target, and a Castbar That Steps Back

### Highlights

- **Friendly nameplates only for your target.** Two new switches under `/az -> Nameplates -> Visibility`: **Friendly NPCs only for your target** and **Friendly players only for your target**. With one on, a city full of vendors and quest givers shows no friendly plates until you click one. That one then gets its AzeriteUI nameplate instead of the game's floating name, and loses it when you target something else. The NPC your interact key would use shows its plate too. Ticking a switch also turns on the game's own Friendly NPCs or Friendly players setting, which it needs; unticking it leaves that setting as it is.
- **The player castbar steps back when you are hit.** When damage pushed a cast back, the red delay number appeared but the bar kept filling on the old schedule, sat full, and then waited for the spell to land. The bar now steps back on each hit as Blizzard's does, a channel that loses time shows it on the bar, and the delay number no longer counts earlier hits twice.
- **Target portrait rotation no longer errors.** A rotation set for the target frame's portrait raised a Lua error on every portrait update. No layout sets one by default, so most players never saw it.

### Development

- **Worked out why no setting could do this.** Neither Retail nor Forever has a "target only" mode for friendly plates: the game makes a plate for every friendly NPC or for none, and with none, the NPC you click gets only its floating name. AzeriteUI now keeps the game making the plates and draws only the ones you target, through the same hidden state the plates already use when the game's own settings hide them. The offline nameplate test gained a step covering a vendor, a trainer, a friendly player and a follower companion through targeting, target switches, hovering, the interact key and objective bars.
- **Fixed the castbar from a player's report on GitHub.** The report traced the problem to the start and end times the bar is drawn from, which a pushback never updated, and a follow-up tested a fix in game on Forever that also rebuilds the bar's timer, since that client keeps the old span otherwise. AzeriteUI's change follows that report and the way Blizzard's own castbar recalculates on both clients. A new offline test drives the real castbar code through two pushbacks, a channel, an empowered cast and another unit's cast; the 5.10.2 code fails it with the reported symptoms.

### Access and known limits

- **Verified offline only:** none of these changes has been seen in the game yet. The castbar fix matches one the reporter ran in game on Forever.
- A hidden friendly plate is still there, only invisible, so clicking just above an NPC's head can still select it.
- Blizzard's own NPC Names setting is separate. If names still float over friendly NPCs you have not targeted, turn them off in the game's Options under Nameplates.
- The new option text was translated without native speakers; corrections are welcome on the Discord.

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


## 5.3.47-JuNNeZ (2026-04-01) — Tenebric Vital-State Decryption Protocol

### Highlights

- Fixed health percent display on WoW 12 / Midnight for both player and target frames. A chain of secret-value restrictions meant health data could not be read through normal Lua paths. The fix introduces a C-side tag formatting path that passes secret values directly to oUF's rendering pipeline, bypassing Lua arithmetic entirely.
- Fixed LibSmoothBar proxy bar receiving a coerced (wrong) min/max range, which caused health percent to permanently show 100%. Proxy bars now receive the original secret min/max and value so the C-side fill is computed correctly.
- Fixed the tag `_FRAME` context not reaching helper functions in `Tags.lua`. oUF injects `_FRAME` into tag method environments via `setfenv`, but module-scoped helpers retained `_G` where `_FRAME` is never set. All frame-cache fallbacks were silently skipping, causing empty percent text. A relay variable now bridges the oUF environment into module scope.
- Hardened Blizzard player/pet castbar suppression to stay non-invasive and stable on WoW 12. Suppressed castbars now re-apply alpha hiding after Blizzard visibility/alpha updates (`Show`, `SetShown`, `SetAlpha`) without unregistering events, clearing units, or reparenting.
- Refactored tooltip/widget/money frame safety guards from invasive function replacement to passive `hooksecurefunc` cache hooks. This keeps Blizzard execution paths secure while still giving AzeriteUI clean geometry fallbacks for tooltip rendering and money-line layout.
- Fixed the Show Health Percent toggle for the **target frame** in `/az` → Unit Frame Settings → Target. The toggle was writing to the AceDB profile but the visibility check was reading from the layout config — a completely separate data store. The check now reads from the profile first, with layout config as fallback.
- Fixed the Show Health Percent toggle for the **player** and **player alternate** frames — percent now respects the on/off setting and hides correctly when castbar text is active.
- Completed a localization coverage pass for all `/az` menu options across all 10 supported languages (enUS, deDE, esES, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW). No menu label should fall back to English in any client language.

### Access

- Player health percent: `/az` → Unit Frame Settings → Player → Show Health Percent
- Player alternate health percent: `/az` → Unit Frame Settings → Player Alternate → Show Health Percent
- Target health percent: `/az` → Unit Frame Settings → Target → Show Health Percent

### Internal

- `Components/UnitFrames/Tags.lua`: added `_tagFrame` relay for `_FRAME` context; added early-exit in both health-percent resolvers when all data is secret; added C-side secret-value tag formatting path using `UnitHealthPercent` + `AbbreviateNumbers` + `C_StringUtil.WrapString`; reordered resolvers to check `safePercent` before stale bar reads; `ResolveTargetHiddenHealthPercentForTag` now computes percent from `value/max` without requiring a readable min.
- `Components/UnitFrames/Functions.lua`: new `SecretPercentReader` hidden StatusBar utility (reads geometry ratio after C-side fills); fixed `GetSafeHealthFromCalculator` `elseif` that prevented `EvaluateCurrentHealthPercent` from ever running; removed stale `ProbeSafePercentAPI` / `GetSecretPercentFromBar` fallbacks; unified target/non-target post-write percent paths; removed race-prone `SetFormattedText` override.
- `Libs/LibSmoothBar-1.0/LibSmoothBar-1.0.lua`: `SetMinMaxValues`, `SetValue`, and `Update` now preserve and use original (possibly secret) raw min/max values so the proxy bar receives correct fill data.
- `Components/UnitFrames/Units/Target.lua`: `ShouldShowTargetHealthPercent()` reads from `TargetFrameMod.db.profile` first; `healthLabSignature` cache key includes `showHealthPercent` and `showName` to bust the fast-path cache when toggle changes.
- `Components/UnitFrames/Units/Player.lua`, `Components/UnitFrames/Units/PlayerAlternate.lua`, `Layouts/Data/PlayerUnitFrame.lua`, and `Options/OptionsPages/UnitFrames.lua`: added/connected `showHealthPercent` profile support for Player Alternate and updated health-percent anchor/visibility behavior to match player/target toggle expectations.
- `Components/UnitFrames/Units/PlayerCastBar.lua`: strengthened suppression hooks so Blizzard castbar alpha cannot pop back during animation/state updates while suppression is active.
- `Core/FixBlizzardBugs.lua` and `Components/Misc/Tooltips.lua`: migrated WoW 12 tooltip/widget/money guards toward passive hook-based geometry caching (`ns.GetSafeGeometry` / `ns.GetSafeWidth`) instead of insecure global method replacement; removed taint-prone wrapper paths (`CompactUnitFrame_UtilShouldDisplay*`, `AuraUtil.UnpackAuraData`, widget mixin method replacement), reducing risk of protected-call fallout such as `UpgradeItem()` attribution.
- Repo maintenance in the same release window: synced `.gitignore`/`.pkgmeta`, updated README badges, and removed stale internal release checklist/TODO files.
- Deleted `TODO.md` and `VERSION_CHECKLIST.md` (internal tracking files, superseded by FixLog workflow).

## 5.3.46-JuNNeZ (2026-03-31)

### Highlights

- Consolidated the addon to retail-only (WoW 12 / Midnight). Removed all Classic, Cata, and multi-version branching — the addon now targets retail exclusively, resulting in cleaner code and smaller file size.
- Fixed WoW 12 secret-value taint crash in Blizzard compact party/raid frame health color updates. The quarantine system no longer writes tracking flags directly onto Blizzard frame objects, preventing taint propagation into `CompactUnitFrame_UpdateHealthColor`.
- Fixed WoW 12 secret-value taint crash when hovering action bar trinkets/items with sell prices. Removed the insecure OnEnter/OnLeave script wrapper that was tainting the tooltip data pipeline, and re-enabled the tooltip money frame geometry guards.
- Fixed WoW 12 secret-value taint crash in Blizzard `LayoutFrame` widget layout. Removed the addon-level pcall wrapping of `RegisterForWidgetSet`/`UnregisterForWidgetSet` that was tainting all layout offset values during widget registration.
- Moved all Blizzard frame guard flags (`__AzUI_W12_*`) to weak-keyed side tables instead of writing them onto Blizzard frame objects, preventing WoW 12 taint propagation.
- Merged the WoW 12 bugfix module (`FixBlizzardBugsWow12.lua`) into the main `FixBlizzardBugs.lua` — single file for all Blizzard frame resilience work.
- Hardened BugSack integration with pcall-wrapped API calls to prevent cascading errors during error capture.
- Libraries updated for retail-only: LibActionButton-1.0-GE, LibFadingFrames, oUF, AceGUI ColorPicker all stripped of multi-version conditionals.

### Internal

- Deleted retail-irrelevant files: `HideBlizzardClassic.lua`, `EditMode.lua`, `EditModePresets.lua`, `FixBlizzardBugsWow12.lua`, `FixFlavorDifferences.lua`, `FontStyles_Classic.xml`, `TrackerVanilla.lua`, LAB backup file.
- `Core/Common/Constants.lua`: hardcoded `IsRetail=true`, `WoW10=true`, `WoW11=true`; removed `WOW_PROJECT_ID` detection.
- `Core/FixBlizzardBugs.lua`: merged all WoW 12 quarantine, castbar guard, compact aura, raid bar, tooltip geometry, and widget guard logic from the deleted companion file. Added `quarantineHooked` side table. Uncommented `GuardTooltipMoneyAdders` body. Removed `RegisterForWidgetSet`/`UnregisterForWidgetSet` mixin wrapping.
- `Components/ActionBars/Prototypes/ActionButton.lua`: removed insecure OnEnter/OnLeave wrapper; LAB's default secure handlers are now used directly.
- `Core/Compatibility.lua`: added `SafeUnpackAuraData()` with secret-value fallback handling.
- `Components/UnitFrames/Units/PlayerClassPower.lua`: simplified rune handling to retail-only logic.
- `Core/ExplorerMode.lua`, `Options/OptionsPages/ExplorerMode.lua`, `Options/OptionsPages/UnitFrames.lua`: removed version guards; all options unconditionally enabled.

## 5.3.45-JuNNeZ (2026-03-29)

### Highlights

- Fixed `ADDON_ACTION_FORBIDDEN` taint error blocking `UpgradeItem()` when confirming item upgrades. The `purgeKey()` function in HideBlizzard.lua was brute-force modifying Blizzard action bar frame tables to clear `isShownExternal`, which tainted the secure execution path through StaticPopup into the Item Upgrade UI.
- Improved Blizzard raid bar toggle reliability: the Show/Hide toggle in `/az -> Unit Frames` now uses a minimal, combat-safe Show/Hide approach instead of quarantine-based visibility. The bar restores instantly when the option is enabled in party/raid.
- Added `PlayFadeAnim` to the castbar guard list to prevent a new WoW 12 taint path.
- Neutered `UpdateShownButtons` on hidden Blizzard action bars to prevent `SetShown()` taint on reparented buttons.
- Cleared `OnEvent`/`OnUpdate` scripts on hidden Blizzard action buttons to stop residual Blizzard update paths from causing taint.

### Internal

- `Components/ActionBars/Compatibility/HideBlizzard.lua`: removed `purgeKey()` and its `isShownExternal` purge call entirely. Added script clearing for hidden buttons and `UpdateShownButtons` neutering for hidden bars.
- `Core/FixBlizzardBugsWow12.lua`: replaced quarantine-based raid bar visibility with a minimal `SetBlizzardRaidBarVisible()` / `ShouldShowBlizzardRaidBar()` pair. Removed `ApplyCompactRaidManagerVisibility()` and `GetModuleProfileValue()`. Added `PlayFadeAnim` castbar guard.
- `Options/OptionsPages/UnitFrames.lua`: updated raid bar toggle setter to call the new `SetBlizzardRaidBarVisible()` API directly.

## 5.3.43-JuNNeZ (2026-03-29)

### Highlights

- Fixed WoW 12 tooltip widget and inserted-frame geometry taint: guards now protect both the widget frame and all embedded tooltips/containers before Blizzard does any width/height arithmetic, preventing secret-value crashes.
- Added pre-guard for `GameTooltip_InsertFrame` to ensure inserted frames and their bars/statusbars are geometry-guarded, eliminating secret-value stacks in Blizzard tooltip layout.

### Internal

- `Core/FixBlizzardBugsWow12.lua`: `GuardItemDisplaySetup()` now guards the widget frame, its `widgetContainer`, and both `self.Tooltip` and `self.Item.Tooltip`.
- `Core/FixBlizzardBugsWow12.lua`: added `GuardTooltipInsertedFrames()` to pre-guard all frames and bars passed to `GameTooltip_InsertFrame`.

## 5.3.42-JuNNeZ (2026-03-29)

### Highlights

- Reduced WoW 12 nameplate and Blizzard-frame taint fallout by backing out invasive pcall-based Blizzard caller replacements that were making AzeriteUI the attributed caller in secret and protected paths.
- Fixed Blizzard raid target icons, classification markers, and level-difference badges bleeding through AzeriteUI nameplates when Blizzard child frames ignored parent alpha.
- Restored the soft-target icon above AzeriteUI nameplates after the newer Blizzard visual-hide pass started hiding the shared `SoftTargetFrame`.
- Hardened lingering secret-value health and heal-prediction reads used by Blizzard-backed nameplate updates.

### Internal

- `Core/FixBlizzardBugsWow12.lua`: reverted the broad WoW 12 pcall-based caller replacements and kept the narrower sanitizers and post-hooks.
- `Core/FixBlizzardBugs.lua`: removed the dead WoW 12 research block so the live Retail 12 path is clearly isolated in the companion file.
- `Components/UnitFrames/Units/NamePlates.lua`: added the Blizzard-child hide pass for raid target/classification/level-diff visuals while exempting the shared `SoftTargetFrame`.
- `Components/UnitFrames/Functions.lua` and `Libs/oUF/elements/health.lua`: hardened the secret-safe unit comparison and health read fallbacks used by target and nameplate updates.

## 5.3.41-JuNNeZ (2026-03-29)

### Highlights

- Fixed the WoW 12 target and target-of-target comparison crash that could spam BugSack when Blizzard returned secret GUID values for compound unit tokens.
- Kept target-of-target hide/show and focus highlight logic on the same shared helper, but made its GUID fallback fail closed instead of comparing unreadable secret strings.

### Internal

- `Components/UnitFrames/Functions.lua`: reordered `ns.API.SafeUnitIsUnit(...)` so `issecretvalue(...)` guards run before any empty-string or GUID equality compare in the `UnitGUID(...)` fallback.
- `FixLog.md`: recorded the WoW 12 secret-GUID regression and the `5.3.41-JuNNeZ` hotfix prep.

## 5.3.40-JuNNeZ (2026-03-28)

### Highlights

- Fixed UI widget item display crashes caused by secret-value taint propagating through embedded tooltip dimensions and money frame button geometry.
- Fixed `SetTooltipMoney` layout crash when tooltip money frame button `GetWidth`/`GetHeight` returned tainted values.

### Internal

- `Core/FixBlizzardBugsWow12.lua`: replaced generic `UIWidgetTemplateItemDisplayMixin.Setup` pcall wrapper with a specialized `GuardItemDisplaySetup` that guards `self.Item.Tooltip` geometry just-in-time before the base `Setup` runs, preventing arithmetic-on-secret-number crashes in `Blizzard_UIWidgetTemplateBase.lua`.
- `Core/FixBlizzardBugsWow12.lua`: added `GuardWidgetFrameSetters` — hooks `SetWidth`/`SetHeight`/`SetSize` on widget frames to silently bail when given secret values, preventing `SetWidth` errors inside Blizzard's `ContinuableContainer` xpcall that BugSack captures.
- `Core/FixBlizzardBugsWow12.lua`: added `GuardMoneyFrameGeometry` — guards tooltip money frames and their Gold/Silver/Copper button children so layout arithmetic uses clean cached dimensions.
- `Core/FixBlizzardBugsWow12.lua`: wrapped `SetTooltipMoney` to guard money frame geometry before and after the layout call, and bail on secret money values.

## 5.3.39-JuNNeZ (2026-03-28)

### Highlights

- Hardened AzeriteUI's target and target-of-target unit comparisons ahead of Blizzard's 12.0.5 `UnitIsUnit(...)` restrictions, reducing the risk of broken target indicators, self-target detection, or ToT hide/show behavior when compound tokens stop comparing directly.

### Internal

- `Components/UnitFrames/Functions.lua`: added `ns.API.SafeUnitIsUnit(...)` with `pcall` wrapping and readable `UnitGUID(...)` fallback for secret/unavailable unit-token comparisons.
- `Components/UnitFrames/Units/Target.lua`: moved risky `targettarget`, self-target, and target-indicator `UnitIsUnit(...)` checks onto the shared safe helper.
- `Components/UnitFrames/Units/ToT.lua`: moved ToT focus and hide-when-targeting comparisons onto the shared safe helper.

## 5.3.38-JuNNeZ (2026-03-28)

### Highlights

- Fixed Blizzard's `PlayerCastingBarFrame` interrupt/glow animations flashing through even when the frame is suppressed by AzeriteUI.

### Internal

- `Components/UnitFrames/Units/PlayerCastBar.lua`: added `StopBlizzardCastbarAnims()` — stops all Blizzard castbar animation groups (`InterruptShakeAnim`, `InterruptGlowAnim`, `InterruptSparkAnim`, `HoldFadeOutAnim`, etc.) and hides glow/flash textures whenever the suppressed castbar tries to show.
- `Components/UnitFrames/Units/PlayerCastBar.lua`: hooked `PlayInterruptAnims` in addition to existing method hooks so interrupt effects are caught immediately.
- `Components/UnitFrames/Units/PlayerCastBar.lua`: stubbed out custom interrupt glow/shake callbacks (commented out, pending custom glow asset).

## 5.3.37-JuNNeZ (2026-03-28)

### Highlights

- Refactored WoW 12 Blizzard bug guards for clarity and reduced code duplication (~100 lines removed).
- Added `BackdropTemplateMixin.SetupTextureCoordinates` guard (adopted from ElvUI/GW2_UI) to prevent secret-value crashes in backdrop rendering across all frames.
- Wired Blizzard raid-bar "Hide Groups" toggle into AzeriteUI's own raid headers so it works when using custom raid frames.

### Access

- No new menu path. Internal refactor and stability improvements.

### Internal

- `Core/FixBlizzardBugsWow12.lua`: hoisted `Pack` to file scope (was redefined 6 times locally).
- `Core/FixBlizzardBugsWow12.lua`: consolidated three identical castbar wrapper factories (`MakeSafeStopFinishAnims`, `MakeSafeCastbarVisualMethod`, `MakeSafeUpdateShownState`) into a single `MakeSafeVoidMethod`; replaced per-method flag blocks with a table-driven `CASTBAR_GUARDS` loop.
- `Core/FixBlizzardBugsWow12.lua`: consolidated three identical widget Setup guards into a single `GuardWidgetMixinMethod` factory called from `GuardWidgetSetups()`.
- `Core/FixBlizzardBugsWow12.lua`: extracted `SilenceWidgetObject` helper to deduplicate field-clearing logic in `HideSecretWidgetTarget` (removed duplicated `widgetContainer.Hide` block).
- `Core/FixBlizzardBugsWow12.lua`: added `GuardBackdropSetupTextureCoordinates()` — skips `BackdropTemplateMixin.SetupTextureCoordinates` when frame dimensions are tainted, matching the approach used by ElvUI and GW2_UI.
- `Core/FixBlizzardBugsWow12.lua`: added raid-manager hidden-mode mirror (`ApplyAzeriteRaidGroupVisibility`, `HookRaidManagerHiddenMode`) so the Blizzard raid-bar "Hide Groups" toggle controls AzeriteUI raid headers by alpha.

## 5.3.36-JuNNeZ (2026-03-28)

### Highlights

- Expanded tooltip geometry guard to cover all position/size methods (GetLeft, GetRight, GetTop, GetBottom, GetCenter, GetRect, GetScale), fixing shopping-tooltip comparison crashes caused by tainted position values.
- Added embedded widget tooltips (UIWidgetBaseItemEmbeddedTooltip) to the geometry guard, fixing secret-value errors in Blizzard's UIWidgetTemplateItemDisplay code.

### Access

- No new menu path. This is a retail tooltip stability hotfix for Blizzard-owned tooltip layout and widget rendering.

### Internal

- `Core/FixBlizzardBugsWow12.lua`: expanded `GuardTooltipFrameGeometry` from dimension-only (GetWidth/GetHeight/GetSize) to full geometry coverage (+ GetLeft, GetRight, GetTop, GetBottom, GetCenter, GetRect, GetScale) using a generic `MakeSafeSingleGetter` pattern.
- `Core/FixBlizzardBugsWow12.lua`: added `UIWidgetBaseItemEmbeddedTooltip1`–`10` to the guard list to cover dynamically created embedded item tooltips.

## 5.3.35-JuNNeZ (2026-03-28)

### Highlights

- Fixed a broader Retail WoW 12 tooltip secret-number crash path by guarding tooltip width and height reads at the tooltip frame itself, so Blizzard tooltip layout code now falls back to the last known clean dimensions instead of erroring.
- Simplified AzeriteUI's tooltip styling follow-up now that tooltip dimension caching is handled centrally at the Blizzard guard layer.

### Access

- No new menu path. This is a retail tooltip stability hotfix for Blizzard-owned tooltip layout and widget rendering.

### Internal

- `Core/FixBlizzardBugsWow12.lua`: added `GuardTooltipDimensions()` to hook `GetWidth`, `GetHeight`, and `GetSize` on live tooltip instances such as `GameTooltip`, `ItemRefTooltip`, `ShoppingTooltip1/2`, and related Blizzard tooltip frames, returning the last known good cached dimension when Blizzard exposes a secret/tainted number.
- `Core/FixBlizzardBugsWow12.lua`: removed the older `GuardTooltipInsertFrame` / `IsSecretTooltipInsertFrameError` whack-a-mole path in favor of the single dimension-guard interception point that protects current and future Blizzard tooltip readers.
- `Components/Misc/Tooltips.lua`: removed the redundant `TooltipDimensionCache` / `CacheTooltipDimensions()` helper path and simplified `UpdateBackdropTheme()` so it only sanity-checks `tooltip:GetWidth() > 0` before styling.

## 5.3.34-JuNNeZ (2026-03-28)

### Highlights

- Fixed Blizzard tooltip sell-price crashes on Retail WoW 12 where some loot, compare, and item tooltips could error instead of showing their money line.
- Hardened the Blizzard item-widget fallback so broken Area POI and embedded item-display tooltip widgets fail closed instead of surfacing secret-value errors.
- Removed the raid-manager hotfix path that could trigger a protected-action warning in grouped play.

## 5.3.33-JuNNeZ (2026-03-28)

### Localization

- Full translation pass across all nine shipped locale files (deDE, esES, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW): every previously untranslated string now has a proper translation.
- Added the missing Soul Fragments display-mode strings (Demon Hunter Devourer toggle, count toggle, display-mode selector, and all four mode options) to all non-English locales.

## 5.3.32-JuNNeZ (2026-03-28)

### The big castbar gimmick update
- Enemy nameplate castbars now use the rebuilt interrupt-color path again, with yellow when your main interrupt is ready, red when it is unavailable, and gray for protected casts.
- Added a shared Unit Frames option to color supported enemy cast spell names by interrupt/protected state, while keeping spell names stable by default if you prefer plain text.
- Cleaned up the target castbar options: the dead reverse-growth toggle is gone, and the temporary full-bar target interrupt tint option is hidden until the target protected-cast path is reliable again.
- Updated the castbar option text and interrupt legend translations across all shipped locale files.

### Access
- Cast spell text coloring: `/az -> Unit Frames -> Color Cast Spell Text By State`
- Enemy castbar interrupt legend: `/az -> Nameplates`
- Target full-bar interrupt tint: temporarily disabled while the target follow-up continues

### Internal
- Added the AzeriteUI-owned `NameplateInterruptDB.lua` fallback helper and seeded it from existing Plater interruptible-spell data when available, without requiring Plater to remain installed.
- Expanded `/azdebug nameplates` for the interrupt-state investigation and kept the TODO/FixLog notes aligned with the current castbar state.

## 5.3.31-JuNNeZ (2026-03-28)

### Highlights
- Fixed another WoW 12 Blizzard player castbar regression where the hidden Blizzard castbar could still throw forbidden-table and invalid texture errors while AzeriteUI's custom player castbar was active.

### Access
- No new menu path. This is a retail stability hotfix for the existing AzeriteUI player castbar replacement.

### Internal
- `Core/FixBlizzardBugsWow12.lua`: restored and expanded the WoW 12 castbar fail-closed guards for `GetTypeInfo`, finish/spark visual helpers, and live `OverlayPlayerCastingBarFrame` instances.
- `Components/UnitFrames/Units/PlayerCastBar.lua`: reverted Blizzard player/pet castbar suppression back to alpha-only hiding so Blizzard keeps its internal event/unit state intact.

## 5.3.30-JuNNeZ (2026-03-27)

### Highlights
- Fixed a WoW 12 compact raid-manager taint that could still trigger `ADDON_ACTION_BLOCKED` with protected `UNKNOWN()` calls when AzeriteUI hid the Blizzard raid utility bar.

### Access
- No new menu path. This is a retail hotfix for the existing `/az -> Unit Frames -> Show Blizzard Raid Bar` toggle.

### Internal
- `Core/FixBlizzardBugsWow12.lua`: stopped mutating `CompactRaidFrameManager` anchors and parent from the WoW 12 quarantine helper, and now suppresses the disabled manager bar through alpha/mouse handling instead.

## 5.3.29-JuNNeZ (2026-03-27)

### The Interrupt Conumdrum
- Continued the retail interrupt-state cleanup for unitframes and nameplates, but this pass is still work-in-progress.
- Nameplate health text can now sit below the bar, inside the bar, or move inside only while you are in combat.
- Added an optional Blizzard raid utility bar toggle in `/az -> Unit Frames` for ready check and world marker access.
- Hardened another WoW 12 Blizzard widget path and removed a taint-prone minimap widget override that could still feed secret-value widget errors.
- Boss and arena health bars were pushed back toward a plain native fill path while the reverse-fill follow-up continues.

### Access
- Nameplate health text placement: `/az -> Nameplates -> Visibility`
- Blizzard raid utility bar: `/az -> Unit Frames`

### Internal
- WIP interrupt follow-up: nameplates now use the simpler plain/oUF interrupt path again while the shared interrupt probe also learns from the live Blizzard castbar lock state.
- Added broader `/azdebug` tooling for keys, target fill inspection, and solo raidbar testing.
- Expanded the retail widget fail-closed guards to cover additional item-display/minimap-widget secret-value paths.

## 5.3.28-JuNNeZ (2026-03-27)

### Highlights
- Restored soft-target icons and names for interactable world objects such as mining nodes, herbs, chairs, and similar object-like nameplates.

### Access
- No new menu path. Soft-target an interactable object in the world and its icon/name should appear again.

### Internal
- The retail nameplate object-plate path now keeps a minimal visible overlay while the plate is soft-targeted, hovered, or hard-targeted instead of forcing the entire plate and `SoftTargetFrame` alpha to zero.

## 5.3.27-JuNNeZ (2026-03-27)

### Highlights
- Fixed another WoW 12 Blizzard widget crash that could still throw `Blizzard_UIWidgetTemplateTextWithState.lua:35` when delve, map, or tooltip text/state widgets exposed secret text sizing values.
- Broadened the existing tooltip widget protection so related Blizzard secret-value geometry errors from shared tooltip layout code are also suppressed instead of surfacing as Lua errors.

### Access
- No new menu path. This is a stability patch for Blizzard-owned widget/tooltip rendering on retail WoW 12.

### Internal
- Extended the fail-closed widget guard in `Core/FixBlizzardBugsWow12.lua` from `GameTooltip_AddWidgetSet(...)` to the live text-with-state and widget-manager registration paths, hiding the failed widget/container on confirmed secret-value errors.

## 5.3.26-JuNNeZ (2026-03-26)

### Highlights
- Removed the unused Classic/Cata/Wrath tracker, aura, and library baggage from this retail-only edition to keep the shipped addon focused on WoW 12.
- Hardened retail aura handling again so nil/late aura payloads do not crash AzeriteUI aura widgets, and Blizzard buff-frame updates are no longer forced through the WoW 12 secret-value `expirationTime` path before being hidden.
- Continued the active retail follow-up on nameplate interrupt visuals, health-percentage caching, and reverse-fill bar behavior.

### Access
- Added `/azdebug nameplates [unit]` as a targeted debug helper for the current nameplate interrupt-state investigation.

### Known Not Working
- `GetInterruptCastVisualState` / `Castbar_RefreshInterruptVisuals`: some protected enemy nameplate casts can still show yellow instead of grey.
- `ResolveDisplayHealthPercent`: some unitframe health percentages can still stick at `100%` or another stale snapshot like `91%`.
- Target castbar reverse-fill path: right-to-left cast fill still needs a dedicated fake-fill solution instead of the current native reverse-fill behavior.
- Boss/Arena reverse-fill path: fake-fill and native `SetReverseFill(true)` are still fighting each other and can make bars look like they fill from the wrong side.

### Internal
- The retail cleanup deletes the unused Classic compatibility payloads listed in `TODO.md`, including dead tracker variants, non-retail aura datasets, and `oUF_Classic`/Classic-only support libs that are not loaded by the retail XML path.

## 5.3.25-JuNNeZ (2026-03-25)

### Highlights
- Fixed a retail tooltip/widget crash that could throw `Blizzard_UIWidgetTemplateTextWithState.lua:35` errors when Blizzard tooltip widgets hit WoW 12 secret-value text sizing.
- Enemy nameplate interrupt castbars are now partially working again, with clearer interrupt-ready and interrupt-on-cooldown visuals plus a right-side interrupt marker.
- Interrupt castbars are still work-in-progress.
- Known issue: some non-interruptible enemy casts can still show yellow as if they were interruptible.

### Access
- No new menu path. This release combines a tooltip crash fix with a WIP hostile nameplate castbar follow-up.

### Internal
- Added a narrow tooltip-widget fail-closed guard for the Blizzard secret-value text-height crash path on WoW 12.
- Simplified the hostile interrupt visual resolver back toward a Platynator-style state model and isolated the live cast payload while the remaining non-interruptible-state bug is still under investigation.

## 5.3.24-JuNNeZ (2026-03-25)

### Highlights
- Fixed action button cooldowns throwing "Secret values are only allowed during untainted execution" errors in WoW 12.0.1, which caused 100+ errors per session during normal play.
- Fixed BugSack copy-session snapshot showing a stale hardcoded AzeriteUI version instead of the actual running version.

### Internal
- `LibActionButton-1.0-GE`: On WoW 12.0+, `UpdateCooldown` now uses `C_ActionBar.GetActionCooldownDuration` + `SetCooldownFromDurationObject` for action buttons, bypassing the secret-value taint restriction entirely. Falls back to `ActionButton_ApplyCooldown` on older API, and adds `IsSafeNumber` guards on the legacy path.
- `BugSack.lua`: Replace hardcoded `AZERITEUI_VERSION` string with a live `C_AddOns.GetAddOnMetadata` lookup so the exported version always matches the running TOC.

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
## 5.3.44-JuNNeZ (2026-03-29)

### Highlights

- Added a minimal, reliable toggle for the Blizzard raid utility bar: `/az -> Unit Frames -> Show Blizzard Raid Bar` now instantly shows or hides the Blizzard raid bar in party/raid using only Show/Hide (no quarantine or event unregistration).
- Toggle is reload-safe and does not interfere with Blizzard or AzeriteUI raid frames.

### Internal

- `Core/FixBlizzardBugsWow12.lua`, `Options/OptionsPages/UnitFrames.lua`: replaced previous quarantine/toggle logic with a direct Show/Hide implementation for the Blizzard raid bar toggle.
