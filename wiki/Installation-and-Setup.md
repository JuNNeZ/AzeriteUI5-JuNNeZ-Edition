# Installation and Setup

## Install

1. Download from one of:
   - GitHub Releases: <https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/releases/latest>
   - CurseForge: <https://www.curseforge.com/wow/addons/azeriteui-junnez-edition-wow12>
   - Wago
2. Extract the folder `AzeriteUI5_JuNNeZ_Edition` into:
   `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart the game, or `/reload` if it was already running.

The folder name matters. If the zip extracts to something like
`AzeriteUI5_JuNNeZ_Edition-5.4.5`, rename it.

## Requirements

- **Retail only.** Interface 120100 (WoW 12.1). There are no Classic branches in this
  addon; it was consolidated to retail-only in 5.3.46-JuNNeZ.
- `Blizzard_AuraContainer` is a hard dependency and ships with the game.
- Optional and detected automatically if present: TaintLess, Clique,
  LibKeyBound-1.0, LibEditModeOverride, LibSharedMedia-3.0, !LibUIDropDownMenu,
  LibMoreEvents-1.0.

## Do not install alongside official AzeriteUI

This edition replaces it entirely. Running both will produce duplicate frames and
conflicting saved variables.

## First run

No configuration is required - the defaults are a complete UI.

- `/az` opens the options.
- `/lock` shows the movers for AzeriteUI's own frames; drag, then `/lock` again.
- Blizzard-owned frames use Blizzard's Edit Mode (Esc -> Edit Mode).
- The first thing worth setting deliberately is **Unit Frames -> (family) ->
  Visibility**, which decides which frame family appears at which group size.

## Validate the install

- The addon appears in the AddOns list at the character screen.
- AzeriteUI frames are visible after login.
- `/az` opens the settings panel.
- `/dump C_AddOns.GetAddOnMetadata("AzeriteUI5_JuNNeZ_Edition","Version")` prints the
  version you expect.

## Saved variables

Everything lives in `AzeriteUI5_DB`, with Ace3 profile support. Settings are stored
per profile. See [Profiles and Reset](Profiles-and-Reset.md).
