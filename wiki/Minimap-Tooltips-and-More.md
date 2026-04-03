# Minimap, Tooltips & More

This page covers the various miscellaneous UI modules that AzeriteUI manages beyond unit frames and action bars.

---

## Minimap

Settings: `/az → Minimap`

AzeriteUI skins and repositions the minimap to match its visual style.

| Setting | Description |
|---|---|
| **Enable** | When disabled, AzeriteUI leaves the minimap completely untouched |
| **Hide AddOn Text** | Hides the custom "AddOns" label displayed near the minimap |
| **Hide Clock Text** | Hides the AzeriteUI clock display on the minimap |
| **Restore Blizzard Default** | Resets the minimap to Blizzard's default theme and position |

### Minimap Themes
Change the visual theme of the minimap via the slash command:
```
/setminimaptheme [name]
```
Omit the name to list all available themes.

---

## Info / Clock

Settings: `/az → Info / Clock`

AzeriteUI displays a clock near the minimap.

| Setting | Description |
|---|---|
| **24 Hour Mode** | Toggle between 24h format and 12h AM/PM format |
| **Use Local Time** | Show your computer's local time instead of the WoW server time |

---

## Chat

Settings: `/az → Chat`

| Setting | Description |
|---|---|
| **Fade Chat** | Gradually fades the chat windows after a period of inactivity |
| **Time Visible** | Seconds before the fade effect begins (5–120 seconds) |
| **Time Fading** | Duration of the fade animation (1–5 seconds) |
| **Clear Chat On Reload** | Blocks old chat messages for a configurable delay after login or `/reload`, starting with a clean chat window |
| **Clear Delay** | How long (1–10 seconds) chat stays blocked after login/reload |

### Bypass Clear On Reload
Hold **Shift** during login or `/reload` to skip the Clear Chat On Reload effect — all previous messages will be visible immediately.

---

## Tooltips

Settings: `/az → Tooltips`

| Setting | Description |
|---|---|
| **Tooltip Theme** | Choose between **Azerite** (custom AzeriteUI styling) and **Classic** (minimal styling) |
| **Disable AzeriteUI Tooltips** | Let Blizzard or another addon handle tooltip styling entirely |
| **Transparent Unit Tooltips on Nameplates** | When hovering a nameplate, the unit tooltip becomes semi-transparent instead of fully opaque |

### Compare Tooltips
When hovering over equippable items, AzeriteUI manages comparison tooltip placement to prevent overlap:
- Compare tooltips are stacked with proper spacing relative to the main tooltip
- The compare stack flips sides as needed to stay within the screen edge
- Post-show relayout hooks prevent compare tooltips from overlapping after content changes size

### ConsolePort Integration
When **ConsolePort** is detected, AzeriteUI **automatically disables** its tooltip styling and cursor anchoring. ConsolePort manages its own tooltip system, and AzeriteUI will not interfere.

---

## Objectives Tracker

Settings: `/az → Tracker`

| Setting | Description |
|---|---|
| **Hide the Blizzard Tracker** | Completely disables the default Blizzard objectives tracker (quest/achievement/mission list on the right side of the screen) |

> **Note:** If you use a third-party quest tracker addon (like Kaliel's Tracker or Leatrix Maps), enable this option to remove the Blizzard tracker and let the other addon handle it.

---

## World Map

Settings: `/az → World Map`

| Setting | Description |
|---|---|
| **Enable** | When enabled, AzeriteUI applies a clean Rui-style border to the world map, enables shrink-on-maximize behavior, and adds player and cursor coordinate display |

---

## Bags

Settings: `/az → Bags`

| Setting | Description |
|---|---|
| **Sort Direction** | **Left to Right** or **Right to Left** — controls the order items are sorted in the bag display |
| **Insert Point** | Which side new items are inserted from when bags open |

---

## Top Center Widgets

Settings: `/az → Widgets`

Controls for encounter and zone widgets displayed in the top-center area of the screen (objective markers, encounter progress bars, etc.):

| Setting | Description |
|---|---|
| **Always Show** | Keep widgets visible even when you have a target selected |
| **Hide with Target** | Hide widgets when a target is selected, revealing more screen space during combat |

---

## Below-Minimap Widgets

Some encounter widgets are displayed below the minimap instead of at the top center. AzeriteUI manages their positioning to avoid overlap with the minimap.

---

## Other Managed UI Elements

AzeriteUI also manages the following UI elements. Most have no dedicated settings panel — they are automatically styled to match AzeriteUI's theme:

| Element | Description |
|---|---|
| **Mirror Timers** | Breath, fatigue, and feign death timers |
| **Quest Timers** | Objective and event countdown timers |
| **Alert Frames** | Achievement, loot alert, and progress notifications |
| **Raid Boss Emotes** | Styled broadcast text for raid encounter emotes |
| **Raid Warnings** | Formatted raid warning messages |
| **Durability** | Equipment durability display |
| **Vehicle Seat** | Vehicle passenger and ability display |
| **Game Menu** | The Blizzard Esc menu is styled to match AzeriteUI |
| **Archaeology Bar** | Archaeology skill progress bar |
| **Banners** | Zone/broadcast banner notifications |
| **Tutorials** | Blizzard tutorial popups are suppressed |
