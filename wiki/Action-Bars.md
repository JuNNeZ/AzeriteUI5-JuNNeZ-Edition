# Action Bars

AzeriteUI provides up to **8 fully configurable action bars** on Retail, plus a dedicated Pet Bar and Stance Bar. All action bar settings are accessible via `/az → Action Bars`.

---

## Global Settings

These settings apply to **all** action bars simultaneously.

| Setting | Description |
|---|---|
| **Hide Hotkeys** | Remove keybind text labels from all action buttons (also affects Pet and Stance bars) |
| **Cast on Key Down** | Trigger abilities on key press instead of key release — reduces apparent cast latency |
| **Use Command Bindings for Hold Cast** | Routes keybinds through Blizzard action commands first; recommended for press-and-hold abilities |
| **Dim When Inactive** | Desaturates and dims buttons when out of combat with no target |
| **Dim Only When Resting** | Restricts the dimming effect to resting areas (inns and cities) |

---

## Per-Bar Settings (Bars 1–8)

Each of the 8 action bars is configured independently.

### Enable / Disable
Toggle individual bars on or off. Disabled bars are completely hidden.

### Bar Fading
| Setting | Description |
|---|---|
| **Enable Bar Fading** | The bar fades out when not in use |
| **Fade From Button** | Which button number the fade effect starts from (e.g., fade from button 7 onward) |
| **Don't Fade In Other Bars** | Mouse hover on this bar will not un-fade other bars — keeps bars independent |
| **Only Show on Mouseover** | The bar is fully invisible until the mouse is over it, even in combat |

### Layout
| Setting | Description |
|---|---|
| **Bar Layout** | **Grid** (straight rows) or **ZigZag** (alternating offset pattern) |
| **Number of Buttons** | 0 to 12 buttons per bar |
| **Button Padding** | Horizontal spacing between buttons |
| **Line Padding** | Vertical spacing between rows |
| **Line Break** | How many buttons before starting a new row (Grid mode) |
| **Growth Direction** | Whether the bar expands horizontally or vertically first |
| **Horizontal Growth** | Left or Right |
| **Vertical Growth** | Up or Down |

---

## Pet Bar

The Pet Bar shows your pet's abilities and follows the same layout and fading options as the main action bars.

- Automatically scales to show only the abilities your pet currently has
- Can be faded, shown only on mouseover, or always visible
- Use `/lock` to reposition it

---

## Stance Bar

The Stance Bar shows stances, forms, and presences for classes that have them (Warriors, Druids, Monks, etc.).

- Dynamically adjusts the number of buttons based on your class
- Same layout and fading options as the main action bars
- Can be repositioned with `/lock`

---

## Removing Abilities from Bars

Hold **Alt + Ctrl + Shift** and **left-click drag** an ability off the bar to remove it.

> This is the only way to remove abilities in AzeriteUI — the usual drag-to-remove behavior requires this modifier combination.

---

## Layout Patterns Explained

### Grid Layout
Buttons are arranged in a simple rectangular grid. The **Line Break** setting determines how many buttons appear per row.

Example — 12 buttons with Line Break = 6:
```
[1][2][3][4][5][6]
[7][8][9][10][11][12]
```

### ZigZag Layout
Buttons are arranged in an alternating offset pattern, creating a staggered appearance. The **Fade From Button** setting determines where the zigzag offset starts.

```
[1] [3] [5] [7]
  [2] [4] [6] [8]
```

---

## Bar Positioning

All action bars can be repositioned using `/lock`. This reveals drag handles for each bar. When you're done positioning, type `/lock` again to save.

> Tip: If a faded bar is hard to grab, temporarily disable fading in settings while repositioning.

---

## Explorer Mode Integration

Action bars are one of the elements that **Explorer Mode** can fade. If your bars seem to disappear unexpectedly, check your [Explorer Mode](Explorer-Mode) settings — particularly the **Elements to Fade** section.

---

## Compatibility

- **Bartender4** — If you prefer Bartender for your action bars, disable AzeriteUI's action bars and manage bars entirely in Bartender. Some visual integration may be lost.
- **ConsolePort** — AzeriteUI detects ConsolePort automatically. If ConsolePort manages your bars, AzeriteUI defers to it.

See [Compatibility](Compatibility) for more addon interaction details.
