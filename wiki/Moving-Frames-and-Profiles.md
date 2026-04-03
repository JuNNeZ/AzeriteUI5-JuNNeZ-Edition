# Moving Frames & Profiles

## Moving Frames

AzeriteUI supports fully repositioning its UI elements using a built-in frame-moving system.

### Entering Frame-Move Mode

Type in chat:
```
/lock
```

This reveals **drag handles** on all AzeriteUI-managed frames. Each handle is a small colored anchor that you can click and drag to reposition its frame.

### Saving Positions

Type `/lock` again to **save all positions** and exit frame-move mode. Positions are immediately stored in your saved variables.

### Resetting Positions

To reset a specific frame to its default position, drag it back to approximately the default location, or use `/resetsettings` to reset all settings (including positions) to defaults.

> **Warning:** `/resetsettings` resets **everything** — all settings, all profiles, and all positions. Use it only as a last resort.

### Blizzard Default Frames

The `/lock` command only affects **AzeriteUI-managed frames**. For default Blizzard frames (like the minimap when not managed by AzeriteUI, the experience bar, etc.), use WoW's built-in **EditMode**:

```
Esc → EditMode
```

### Positions Storage

All frame positions are stored per-character in the `AzeriteUI5_DB` saved variable file located at:
```
WTF/Account/[AccountName]/[ServerName]/[CharacterName]/SavedVariables/AzeriteUI5_DB.lua
```

---

## Profiles

AzeriteUI uses **Ace3's profile system** to manage multiple settings configurations.

### What is a Profile?

A profile is a named set of all your AzeriteUI settings. You can create multiple profiles for different characters, specs, or purposes (e.g., a "Raiding" profile and a "PvP" profile).

### Accessing Profiles

Profiles are managed through the Ace3 options panel:

1. Type `/az` to open the options menu
2. Navigate to the **Profiles** section (typically at the bottom of the panel)

From here you can:
- **Create** a new profile
- **Copy** settings from another profile
- **Delete** a profile
- **Switch** to a different profile
- **Reset** the current profile to defaults

### Default Profile Behavior

By default, AzeriteUI uses a single shared profile for all characters. If you want per-character settings, create a new profile on each character.

### Profile Switching and Edit Mode

AzeriteUI includes an optional integration with WoW's **Edit Mode layouts**. When switching profiles, AzeriteUI can automatically load an associated Edit Mode layout. This is configured in the profile settings area of `/az`.

### Saved Variable File

All profiles are stored in:
```
AzeriteUI5_DB.lua
```

Located at:
```
WTF/Account/[AccountName]/SavedVariables/AzeriteUI5_DB.lua
```

This is the **global** saved variable — it applies across all characters on the account. Per-character overrides are stored in the character-specific SavedVariables folder.

---

## Tips

- When repositioning bars, temporarily disable **bar fading** if the bar is hard to click on while invisible
- Use `/lock` before a major UI layout session — reposition everything, then save at the end
- The `/lock` command does not affect chat frames — WoW's chat frame positioning is managed by Blizzard
- Backing up your `WTF` folder preserves all your saved positions and settings across reinstalls or addon updates
