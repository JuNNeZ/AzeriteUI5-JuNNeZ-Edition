# Action Bars

Eight main bars plus a pet bar and a stance bar. `/az` -> Action Bars.

## Native controller bars on Forever

AzeriteUI offers a **Yes/No prompt automatically while you play**. The feature is
enabled by default on supported Forever clients and does not require opening
settings or enabling native bars beforehand.

- With the normal AzeriteUI bars active, controller movement can offer a switch
  to Blizzard's controller bars.
- With Blizzard's controller bars active, keyboard movement or disconnection of
  the last controller can offer a return to AzeriteUI's keyboard/mouse bars.
- **Yes** saves the matching bar ownership and native input style, then reloads
  the interface. Other AzeriteUI HUD elements stay active.
- **No** keeps the current bars. A declined suggestion is suppressed until input
  settles and a new interaction is detected; holding the same stick should not
  keep reopening the prompt.
- No change or reload happens merely because an input event fires. During combat
  the prompt is hidden, and leaving combat revalidates the current evidence.

The prompt stays available while you move the mouse to click Yes or No. It is a
choice to confirm, not a guarantee of the last physical input device. Mouse
movement, controller mouse emulation and modifier changes alone must not force a
bar change. The private prompt does not capture keyboard/gamepad input or enter
Blizzard's popup and controller-navigation stacks; its buttons can be clicked
with the mouse.

Device IDs are logical entries: one physical controller can expose several IDs,
and a cached active ID can remain after unplugging. That cached ID is not proof
that a controller is connected. Losing one of several connected controllers must
not be treated as losing all controllers.

### What changes after accepting

For a controller suggestion, Yes selects Blizzard's native input style and native
bar ownership for the next session. Blizzard then controls the action, pet and
stance bars, including `GamepadMainActionBarFrame`, and the extra-action and
vehicle-exit controls. It preserves Blizzard's own action slots, modifiers, pages
and pet/stance/possession handling. Set controller bindings in the game's native
settings; native controller slots are not translated onto AzeriteUI buttons.

For a keyboard/mouse suggestion, Yes selects MnK and restores AzeriteUI bar
ownership on reload, using your saved bar preferences and bindings. The rest of
the HUD remains AzeriteUI in both modes. The bar system remains fixed during each
session; switching modes never transfers protected frames in place.

The independent quest-item button remains available in both modes. During native
bar ownership it uses its own explicit binding and does not borrow the Extra
Action Button key.

### Compatibility and client behavior

The workflow uses the on-screen Yes/No prompt directly. The AzeriteUI menu has no
native-bar or input-change configuration sections. Quest-item and binding
controls remain available while AzeriteUI's replacement bars are inactive.

ConsolePort, ConsolePort_Bar and Bartender4 take precedence; remove that conflict
before accepting a takeover. GamePadReadySet pauses prompts so the two addons do
not compete to choose a mode. It does not disable an already active native-bar
session. A detected external style change also pauses prompts.

On Forever 1.60.1 build 70938, the diagnostic click changed the stored CVar before
the game reloaded into Gamepad style. Its timer attempt raised
`ADDON_ACTION_BLOCKED` but still saved Gamepad while the effective style remained
MnK. A successful setter return or a matching CVar is therefore not proof that
the style was applied. Events and timers only detect and suggest; the explicit
Yes callback saves the choice and reloads.

A failed change is reported in the prompt and is not retried automatically.
Because the client can save a style even when its application was blocked, a
previously blocked style transition can take effect on a later reload.

### Manual validation checklist

The maintainer has tested and approved the normal controller-to-keyboard round
trip through the automatic Yes/No prompts in game. The broader scenarios below
remain a regression checklist; that approval does not establish that every
combination of devices, combat state and addon has been tested.

1. Start in the usual AzeriteUI keyboard/mouse layout without opening settings.
   Connect a controller and walk with its stick. A Yes/No prompt should appear.
2. Choose No. The interface must not reload or change bars, and holding the stick
   must not repeatedly reopen the prompt. Let input settle, then move again.
3. Choose Yes on a fresh controller prompt. After reload, Blizzard's controller
   bars should appear without duplicate AzeriteUI action/pet/stance bars. The
   rest of the HUD and independent quest button must remain available.
4. Use native controller bindings, modifiers and press/release behavior. Confirm
   each intended action fires once. Test pets, forms/postures and possession.
5. Move with keyboard movement keys, including rebound movement keys. Accept the
   return prompt. After reload, AzeriteUI bars and their previous settings and
   bindings must return.
6. Repeat the return using controller disconnection. Test Bluetooth reconnects
   and two physical controllers; losing only one must not mean losing all.
7. Try idle stick drift, controller mouse emulation, modifiers, simultaneous input
   and typing in chat. These must not cause automatic writes/reloads or repeated
   false prompts. Confirm prompts remain clickable while using the mouse.
8. Enter combat with a prompt visible. It must hide; no input may apply a mode or
   reload during combat. Leaving combat must revalidate evidence without
   automatically applying a queued change.
9. Check login/reload persistence, Edit Mode and profile/reset changes. Pending
   candidates from the old profile must not execute. Confirm the AzeriteUI menu
   has no native-bar/input-change sections and retains quest-item/binding controls.
10. Test external manual choices, GamePadReadySet and conflicting bar addons.
    Confirm no competing takeover prompts appear and that existing ownership
    remains intact until an explicit reload.
11. Verify a failed write or reload is visible and does not retry indefinitely.
    The failure message must remain in the prompt without requiring a settings
    page to report it.

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
