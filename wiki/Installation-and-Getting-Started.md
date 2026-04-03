# Installation & Getting Started

## Requirements

- **World of Warcraft:** Retail 12.0.x (Midnight expansion)
- **Operating System:** Windows or macOS
- **Conflicting Addons:** Do **not** install this alongside the original AzeriteUI — this fan edition fully replaces it

---

## Installation

### Method 1 — Manual (Recommended)

1. Download the latest release from [GitHub Releases](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/releases/latest) or [CurseForge](https://www.curseforge.com/wow/addons/azeriteui-junnez-edition-wow12).
2. Extract the downloaded archive.
3. Copy the `AzeriteUI5_JuNNeZ_Edition` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
4. Start WoW (or type `/reload` if already logged in).
5. On the character select screen, click **AddOns** (lower-left) and verify **AzeriteUI5 JuNNeZ Edition** is enabled.

### Method 2 — CurseForge App / Wago App

1. Open your addon manager (CurseForge App or Wago App).
2. Search for **AzeriteUI JuNNeZ Edition**.
3. Click **Install**.
4. Launch WoW.

---

## First Launch

When you first log in after installing AzeriteUI:

- Your entire default Blizzard UI is replaced. This is expected — AzeriteUI is a **full UI replacement**.
- No initial configuration is needed. The addon uses sensible defaults immediately.
- If you see any Lua errors on first load, type `/reload` once; this usually clears them.

---

## Opening the Options Menu

Type the following in chat to open the full settings panel:

```
/az
```

or

```
/azerite
```

The options panel is organized into categories (Unit Frames, Action Bars, Nameplates, Explorer Mode, etc.).

---

## Getting Your Bearings

| UI Element | Location |
|---|---|
| **Player Frame** | Lower-left — health bar + power orb/crystal |
| **Target Frame** | Lower-right |
| **Action Bars** | Bottom of the screen (up to 8 bars) |
| **Minimap** | Upper-right corner |
| **Aura Header** | Upper-right (buffs/debuffs) |
| **Chat** | Lower-left |
| **Nameplates** | Above units in the world |
| **Objectives Tracker** | Right side of the screen |

---

## Moving UI Elements

Type `/lock` to enter frame-moving mode. Draggable anchor handles appear on all AzeriteUI-managed frames. Drag them to your preferred position, then type `/lock` again to save.

For Blizzard default frames, use WoW's built-in **EditMode** (`Esc → EditMode`).

See [Moving Frames & Profiles](Moving-Frames-and-Profiles) for more details.

---

## Upgrading

When a new version is released:

1. Download and overwrite the `AzeriteUI5_JuNNeZ_Edition` folder in your AddOns directory.
2. Log in and type `/reload`.
3. Your settings are preserved — stored in `AzeriteUI5_DB` in your WTF folder.

> **Tip:** If you experience unusual behavior after an update, try `/resetsettings` as a last resort. **This erases all saved settings.**

---

## Uninstalling

1. Delete the `AzeriteUI5_JuNNeZ_Edition` folder from `Interface/AddOns/`.
2. Optionally delete `WTF/Account/.../SavedVariables/AzeriteUI5_DB.lua` to remove saved settings.
3. Reload WoW.

---

## Next Steps

- Explore the [Slash Commands](Slash-Commands) reference
- Learn about [Unit Frames](Unit-Frames)
- Configure your [Action Bars](Action-Bars)
- Understand [Explorer Mode](Explorer-Mode)
