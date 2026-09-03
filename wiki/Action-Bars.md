# Action Bars

Eight main bars plus a pet bar and a stance bar. `/az` -> Action Bars.

## Global settings

- **Hide Hotkeys** - remove keybind text from every action button, pet and stance bars included.
- **Cast action keybinds on key down** - trigger on press instead of release. This
  mirrors the `ActionButtonUseKeyDown` CVar rather than fighting it.
- **Use Command Bindings for Hold Cast** - route keybinds through Blizzard's action
  commands first. Recommended if you use press-and-hold abilities.
- **Dim the actionbuttons when inactive** - desaturate and dim out of combat.
- **Only dim the actionbuttons when resting** - restrict that dimming to inns and cities.

## Assisted Combat Highlight

AzeriteUI draws its own circular glow for Blizzard's assisted combat suggestion, kept
separate from the proc glow so the button stays circular. **Highlight Color** picks
the color it uses.

## Micro Menu

Two independent toggles:

- **Show Blizzard's Micro Menu** - the strip of buttons along the bottom of the screen.
  Off by default, which is what every prior version did.
- **Show AzeriteUI Cog Wheel** - the cog in the bottom right corner that opens the same
  set of buttons.

Both apply when the interface loads, so changing either one prompts a reload.

## Per-bar settings

Each of the eight bars has its own:

- **Enable**
- **Number of buttons** - 0 to 12
- **Layout** - Grid or ZigZag
- **First ZigZag Button** - which button the stagger starts from
- **Line Break** and **Line Padding** - where rows wrap and how far apart they sit
- **Button Padding**
- **Initial Growth** - horizontal or vertical
- **Horizontal Growth** - left or right
- **Vertical Growth** - up or down
- **Enable Bar Fading** and **Start Fading from** - which button fading begins at
- **Don't fade in other bars** - hovering this bar reveals only this bar
- **Only show on mouseover** - a faded bar stays hidden in combat until hovered
- **Ignore clicks while faded** - a faded bar stops swallowing clicks
- **Show while mounted**

## Pet and stance bars

Same layout and fading controls. The stance bar sizes itself to your class's number
of forms.

## Ability pings

Pinging an ability on an AzeriteUI bar announces the spell or item along with its
cooldown and whether you can afford it, the same callout Blizzard's own bars give.
This works on all bars, including pet and stance. Pings aimed past an empty slot pass
through to the world rather than dying on the button.

## Removing abilities from a bar

Hold `Alt + Ctrl + Shift` and drag with the left mouse button.

## Practical tips

- Start with fewer active bars and add as needed; fading rules get confusing fast
  across eight bars.
- Use `/lock` to check anchors while tuning layouts.
- `/reload` after structural changes, especially micro menu toggles.
- If a bar has vanished, check **Enable Bar Fading** on that bar first, then
  Explorer Mode's **Fade ActionBars**.
