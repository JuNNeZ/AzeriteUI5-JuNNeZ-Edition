# Action Bars

Eight main bars plus a pet bar and a stance bar. `/az` -> Action Bars.

## Native controller bars on Forever

**Use native controller bars** is off by default. Enable it in `/az` -> Action
Bars, then accept the reload or run `/reload` outside combat. Blizzard takes over
the action, pet and stance bars for both controller and keyboard/mouse, including
its native `GamepadMainActionBarFrame`. The rest of the AzeriteUI HUD stays active.
The selected bar system stays fixed until the next reload, including when you
switch input devices in combat.

Set controller bindings in the game's native settings. This mode preserves
Blizzard's own action slots, modifiers, pages and pet/stance/possession handling;
it does not translate the native controller slots onto AzeriteUI buttons. Saved
bindings and AzeriteUI bar preferences are retained. Turn the option off and
reload to restore the AzeriteUI bars with those preferences.

Extra-action styling and the replacement vehicle-exit button also stand down.
The independent quest-item button remains available with its own explicit
binding; borrowing the Extra Action Button key is suspended for this session.

The page remains available while AzeriteUI's bars are disabled. It shows the
current session's state and any pending reload. ConsolePort (core or
ConsolePort_Bar) and Bartender4 take precedence; disable the conflicting addon and
reload before enabling this option. If the client lacks the required APIs, the
integration stays inactive and existing bar behavior is preserved. A saved
opt-in can still be turned off when either condition blocks activation.

### Manual validation checklist

The native controller integration requires in-game validation on Forever. Check:

1. Enable the option and reload: Blizzard's bars appear without duplicate
   AzeriteUI action, pet or stance bars; the rest of the HUD remains available.
2. Use the native controller bindings, including modifiers and press/release
   behavior. Confirm the intended action fires exactly once.
3. Switch between controller and keyboard/mouse outside and during combat.
   Blizzard continues to manage the bars, with no blocked-action errors.
4. Test class forms/postures, pet commands and possession, both outside and
   during combat. Confirm the displayed actions and bindings match.
5. Check Edit Mode and reload/login persistence. Switch profiles and confirm
   any change of bar system waits for a reload.
6. Disable this option and reload: the prior AzeriteUI bar preferences return,
   and saved bindings remain unchanged.
7. Repeat with ConsolePort or Bartender4 enabled: the native compatibility
   option reports the conflict, permits removing a saved opt-in, and does not
   compete with the other bar addon.

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
- **Show Range Indicator** - colour out-of-range actions on this bar; other usability colours remain active.
- **Show Item and Charge Counts** - show item quantities and spell charges on this bar; cooldown timers are separate.

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
