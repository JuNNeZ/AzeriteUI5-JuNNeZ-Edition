# Slash Commands

All AzeriteUI commands are typed directly into the WoW chat box.

---

## Core Commands

| Command | Description |
|---|---|
| `/az` | Opens the AzeriteUI options menu |
| `/azerite` | Alias for `/az` |
| `/lock` | Toggles frame-moving mode — drag anchor handles to reposition AzeriteUI UI elements. Type `/lock` again to save and exit. |
| `/resetsettings` | **Emergency use only.** Erases all saved profiles and settings, then reloads the UI. Cannot be undone. |

---

## Utility Commands

| Command | Description |
|---|---|
| `/setminimaptheme [name]` | Change the minimap theme by name. Omitting the name lists available themes. |
| `/devmode` | Toggle Development Mode, which unlocks experimental features such as the Player Alternate Frame. |

---

## Debug Commands

Debug commands require **Development Mode** to be enabled first (via `/devmode` or the options menu).

| Command | Description |
|---|---|
| `/azdebug` | Opens the debug menu |
| `/azdebug aurasnapshot [unit]` | Dumps a live snapshot of aura states for the specified unit (e.g., `player`, `target`). Useful for diagnosing aura classification issues. |

---

## Options Menu Navigation

Once you open `/az`, the panel is organized into the following categories:

| Category | Contents |
|---|---|
| **Unit Frames** | Player, Target, Focus, ToT, Pet, Party, Raid, Boss, Arena, Cast Bar, Class Power |
| **Action Bars** | Global bar settings, per-bar (1–8) configuration, Pet Bar, Stance Bar |
| **Nameplates** | Visibility, scaling, aura display, interrupt colors |
| **Auras** | Aura header (top-right display), player frame aura filtering |
| **Explorer Mode** | Timing, exit conditions, which elements to fade |
| **Chat** | Fading behavior, clear-on-reload |
| **Tooltips** | Theme, anchoring, compare tooltip behavior |
| **Minimap** | Labels, clock, theme, restore defaults |
| **Bags** | Sort direction, insert point |
| **Info / Clock** | 24h mode, local vs. server time |
| **Widgets** | Top-center encounter widgets, below-minimap widgets |
| **Tracker** | Quest objective tracker |
| **World Map** | Custom border toggle |

---

## Notes

- `/lock` only affects AzeriteUI-managed frames. Use WoW's built-in **EditMode** (`Esc → EditMode`) to reposition default Blizzard frames.
- `/resetsettings` is irreversible. Back up your `WTF` folder before using it if you want to preserve current settings.
- The Blizzard AddOns settings panel (`Esc → Options → AddOns`) also lists AzeriteUI, but the most complete options are accessible only through `/az`.
