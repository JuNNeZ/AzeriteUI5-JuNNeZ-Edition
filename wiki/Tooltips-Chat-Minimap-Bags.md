# Tooltips, Chat, Minimap, Bags

Four smaller option pages, plus the World Map, Objectives Tracker, Widgets and Info Bar
pages that sit alongside them.

## Tooltips

`/az` -> Tooltips.

- **Style** - Azerite or Classic.
- **Do not style tooltips** - hand tooltips back to Blizzard or another addon entirely.
- **Enable Anchoring** and **Position** - where tooltips appear.
- **Anchor to Cursor** - follow the mouse instead.
- **Transparent unit tooltips on nameplates**.
- **Hide UnitFrame Tooltips in Combat** and **Hide ActionBar Tooltips in Combat**.
- **Show Guildname**, **Show itemID**, **Show spellID**.

ConsolePort is detected automatically. While it is loaded, AzeriteUI does not style or
anchor tooltips at all, to stay out of its way.

## Chat

`/az` -> Chat.

- **Fade Chat**, with **Time Visible** before the fade starts and **Time Fading** for
  the fade itself.
- **Clear Chat On Reload** - suppress old messages for a moment after login or reload,
  with a configurable **Clear Delay**. Hold `Shift` while logging in to bypass it.
- `/clear` clears the chat window on demand.

## Minimap

`/az` -> Minimap.

- **Enable** - when off, AzeriteUI leaves the minimap completely alone.
- **Hide AddOn Text** and **Hide Clock Text**.
- **Restore Blizzard Default** - back to Blizzard's minimap look and position.
- `/setminimaptheme <name>` switches theme. Two ship: `Azerite` and `Blizzard`. The
  command is ignored in combat and re-applies once you leave it.

## Bags

`/az` -> Bags.

- **Sort Direction** - left to right, or right to left.
- **Insert Point** - which side new items land on.

## World Map

`/az` -> World Map. One toggle. When on, the map uses the integrated Rui-style clean
border, shrink-on-maximize behavior, and player and cursor coordinates.

## Objectives Tracker

`/az` -> Objectives Tracker. Controls AzeriteUI's tracker and how much of Blizzard's
tracker remains visible, including **Hide the Blizzard Tracker**.

## Widgets

`/az` -> Widgets. Controls the top-center encounter and zone widgets above the play
area: **Always show Top Center Widgets** and **Hide with Target**.

## Info Bar

`/az` -> Info Bar. Clock and info text in AzeriteUI's top information area.

- **24 Hour Mode**
- **Use Local Time** - your computer's time instead of the server's
