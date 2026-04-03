# AzeriteUI — JuNNeZ Edition

[![WoW Version](https://img.shields.io/badge/WoW-12.0%20Midnight-blue)](https://worldofwarcraft.blizzard.com/)
[![Interface](https://img.shields.io/badge/Interface-120000-1f6feb)](#)
[![Lua](https://img.shields.io/badge/Lua-WoW%20API%2012-2c2d72)](#)
[![Maintainer](https://img.shields.io/badge/Maintainer-JuNNeZ-0a7d32)](https://github.com/JuNNeZ)
[![Addon Version](https://img.shields.io/badge/Addon-v5.3.54--JuNNeZ-informational)](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/tags)
[![GitHub Release](https://img.shields.io/github/v/release/JuNNeZ/AzeriteUI5-JuNNeZ-Edition?display_name=release)](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/releases/latest)
[![CurseForge](https://img.shields.io/badge/CurseForge-Project-orange)](https://www.curseforge.com/wow/addons/azeriteui-junnez-edition-wow12)
[![CurseForge Downloads](https://img.shields.io/badge/dynamic/json?color=orange&label=downloads&query=%24.downloads.total&url=https%3A%2F%2Fapi.cfwidget.com%2Fwow%2Faddons%2Fazeriteui-junnez-edition-wow12)](https://www.curseforge.com/wow/addons/azeriteui-junnez-edition-wow12)

**This is an unofficial fan-edited version of [AzeriteUI 5](https://github.com/goldpawsstuff/AzeriteUI5) by GoldpawsStuff.**

AzeriteUI is a complete custom World of Warcraft user interface replacement for Retail (WoW 12 — Midnight). This JuNNeZ Edition includes additional bug fixes, compatibility patches, and quality-of-life improvements not found in the original release.

> **Note:** This is a personal project maintained independently. For official support, use the original AzeriteUI or visit the Discord where JuNNeZ has a channel for this addon.

---

## Table of Contents

- [Installation](#installation)
- [Getting Started](#getting-started)
- [Slash Commands](#slash-commands)
- [Features Overview](#features-overview)
  - [Unit Frames](#unit-frames)
  - [Action Bars](#action-bars)
  - [Nameplates](#nameplates)
  - [Explorer Mode](#explorer-mode)
  - [Aura Header](#aura-header)
  - [Minimap](#minimap)
  - [Chat](#chat)
  - [Tooltips](#tooltips)
  - [Objectives Tracker](#objectives-tracker)
  - [World Map](#world-map)
  - [Bags](#bags)
  - [Info / Clock](#info--clock)
  - [Top Center Widgets](#top-center-widgets)
- [Detailed Options Reference](#detailed-options-reference)
- [JuNNeZ Edition Changes](#junnez-edition-changes)
- [FAQ](#faq)
- [Compatibility](#compatibility)
- [Credits & Original Author](#credits--original-author)

---

## Installation

1. Download the latest release from [GitHub Releases](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/releases/latest) or [CurseForge](https://www.curseforge.com/wow/addons/azeriteui-junnez-edition-wow12).
2. Extract the `AzeriteUI5_JuNNeZ_Edition` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory.
3. **Do NOT install this alongside the official AzeriteUI.** This edition replaces it entirely.
4. Restart WoW or type `/reload` in the chat if the game was already running.

---

## Getting Started

Once installed, AzeriteUI replaces your entire default user interface. No initial configuration is required — the addon works out of the box with sensible defaults.

To customize the UI, open the options menu:

```
/az
```

or

```
/azerite
```

This opens a comprehensive settings panel powered by Ace3, where you can fine-tune every aspect of the interface.

---

## Slash Commands

| Command | Description |
|---|---|
| `/az` or `/azerite` | Opens the AzeriteUI options menu |
| `/lock` | Toggles movable frame anchors — drag UI elements to reposition them. Use Blizzard's EditMode for default frames. |
| `/resetsettings` | Full settings reset (emergency use only — **erases all profiles**) |
| `/azdebug` | Opens the debug menu (requires Development Mode to be enabled in options) |
| `/setminimaptheme [name]` | Change the minimap theme |

---

## Features Overview

### Unit Frames

AzeriteUI replaces all standard unit frames with a custom, art-driven design. Every unit frame listed below can be individually enabled or disabled.

#### Player Frame

The centerpiece of AzeriteUI — a custom-skinned health bar with Azerite-themed artwork:

- **Health Bar** — a styled horizontal health bar with custom Azerite backdrop textures that evolve as your character levels up (Novice, Hardened, Seasoned, etc.), with smooth fill, absorb overlays, and threat glow
- **Power Widget** — displayed to the left of the health bar, with three display modes:
  - **Automatic (By Class)** — shows a Mana Orb for mana users, a Power Crystal for energy/rage/etc.
  - **Mana Orb Only** — always use the circular orb style
  - **Power Crystal Only** — always use the vertical crystal style
- **Ice Crystal Art** — optional alternate crystal artwork (Wrath-style)
- **Crystal/Orb Color Source** — choose between default AzeriteUI power colors or enhanced token-based colors
- **Show Health Percent** — display a percentage next to the health value
- **Show Power Text** — display power value text; optionally show only in combat
- **Power Text Size** and **Alpha** — customize readability
- **Power Text Style** — Short Number, Full Number, Percent, or Short + Percent
- **Castbar** — overlay castbar on the player frame (can be toggled)
- **Auras** — configurable player aura row attached to the frame (see [Player Aura Filtering](#player-aura-filtering) below)
- **PvP Badge** — position offset (X/Y) for the PvP indicator on the player frame
- **Combat Indicator** — animated icon shown when in combat
- **Threat Glow** — health bar and power widget glow when you have threat

#### Player Alternate Frame

An alternative player frame style that mirrors the target frame design. Available when Development Mode is enabled. Switching to this automatically disables the default player frame and vice versa. Supports:

- Class-colored health bars
- Auras (above or below frame)
- Castbar overlay
- Health percent text
- Unit name display

#### Target Frame

- Health bar with smart texture that changes size for bosses and critters
- **Show Auras** with detailed layout controls:
  - Auras per row, aura size, padding (X/Y)
  - Growth direction (left/right, up/down)
  - Initial anchor point
- **Show Castbar** — overlay castbar on target; interrupt-state text coloring
- **Show Unit Name**, **Health Percent**, **Power Value** (with format and alpha options)
- **Texture Variations** — use a larger texture for boss targets and a smaller one for critters

#### Target of Target

- Compact display of your target's target
- **Hide when targeting player** — make transparent when the ToT is you
- **Hide when targeting self** — make transparent when the target is targeting itself

#### Focus Frame

- Dedicated frame for your focus target
- Can be individually enabled/disabled

#### Pet Frame

- Shows your pet's health
- Can be individually enabled/disabled

#### Party Frames

Full party frame suite with extensive options:

- **Show Player** — toggle whether you appear in the party display
- **Visibility** — choose exactly which group sizes activate party frames (party 2-5, raid 1-5, 6-10, 11-25, 26-40)
- **Health Colors** — flat green, AzeriteUI class colors, Blizzard class colors, or class color on mouseover only
- **Aura System** with stock or custom filtering:
  - Dispellable debuffs, boss/important debuffs, other short debuffs
  - Helpful externals (Ironbark, Pain Suppression, etc.)
  - Raid buffs and short helpful buffs
  - Aura size, debuff scale, growth direction
  - **Glow for Dispellable Debuffs** — highlight the frame border with the debuff-type color

#### Raid Frames (5-man, 25-man, 40-man)

Three separate raid frame styles optimized for different group sizes:

- **Visibility toggles** — fine-grained control over which group sizes each frame type activates for
- **Health Colors** — same options as party frames
- **Range Indicator** — fade out-of-range units
- **Big Debuff** (25 and 40-man) — large priority debuff icon with configurable size

#### Boss Frames

- Dedicated frames for boss encounter units
- Can be individually enabled/disabled

#### Arena Enemy Frames

- Shows enemy arena targets
- **Range Indicator** — fade out-of-range enemies
- **Show in Battlegrounds** — optionally display flag carrier frames in BGs

#### Player Cast Bar

- Standalone player cast bar (separate from the unit frame overlay)
- Can be individually enabled/disabled and repositioned

#### Player Class Power

- Displays class-specific resources: Combo Points, Holy Power, Arcane Charges, Chi, Soul Shards, Runes, Maelstrom Weapon stacks, etc.
- **Click-Through** — ON (default): clicks pass through to frames behind; OFF: blocks clicks to prevent accidental right-click menu

#### Shared Unit Frame Settings

- **Prioritize Unit Frame Auras** — group auras by relevance and readable timing (vs. application order)
- **Show Blizzard Raid Bar** — toggle the Blizzard raid utility bar (ready check, ground markers)
- **Color Cast Spell Text By State** — tint cast spell names by interrupt/protected state

---

### Action Bars

Up to **8 action bars** (Retail) with per-bar configuration:

#### Global Settings

- **Hide Hotkeys** — remove keybind text from all action buttons (also affects pet and stance bars)
- **Cast on Key Down** — trigger abilities on key press instead of release
- **Use Command Bindings for Hold Cast** — route keybinds through Blizzard action commands first; recommended for press-and-hold behavior
- **Dim When Inactive** — desaturate and dim buttons when out of combat with no target
- **Dim Only When Resting** — restrict the dimming to resting areas (inns/cities)

#### Per-Bar Settings

Each of the 8 action bars supports:

- **Enable/Disable** — toggle individual bars
- **Bar Fading** — fade out buttons; configure which button fading starts from
- **Don't Fade In Other Bars** — isolate bar hover to just that bar
- **Only Show on Mouseover** — faded bars only appear on hover, not forced in combat
- **Bar Layout** — Grid or ZigZag pattern
- **Number of Buttons** — 0 to 12 per bar
- **Button Padding** and **Line Padding** — spacing between buttons and rows
- **Line Break** — where to start a new row (grid mode)
- **Growth Direction** — horizontal/vertical initial expansion
- **Horizontal Growth** — left or right
- **Vertical Growth** — up or down

#### Pet Bar

Same layout and fading options as main action bars, tailored for pet abilities.

#### Stance Bar

Same layout and fading options, dynamically adjusting to your class's number of stances/forms.

#### Removing Abilities

Hold `Alt + Ctrl + Shift` and drag with the left mouse button to remove abilities from the action bars.

---

### Nameplates

Custom-styled nameplates replacing Blizzard's default:

#### Visibility

- **Always Show Names** — keep unit names visible without hovering
- **Health Text Placement** — below the bar, inside the bar, or inside only during combat
- **Show Auras** — display buffs/debuffs on nameplates
- **Only Show Auras on Target** — reduce clutter by limiting auras to your current target

#### Size & Scaling

- **Use Blizzard Overall Scale** — follow Blizzard's global nameplate scale slider
- **Overall Size (%)** — base size for AzeriteUI nameplates
- **Maximum Distance** — how far away nameplates appear (default: 40)
- **Castbar Vertical Offset** — nudge the castbar up or down
- **Friendly/Player Size**, **Friendly NPC Size**, **Enemy Size** — independent scale sliders
- **Friendly Target Size** and **Enemy Target Size** — how much plates grow when targeted

#### Friendly Players

- **Names Only for Friendly Players** — show class-colored names and hide the health bar
- **Friendly Name Size** and **Name Target Size** — dedicated scale for name-only plates

#### Enemy Castbar Interrupt Colors

Enemy nameplate castbars use a color-coded system:

| Color | Meaning |
|---|---|
| **Yellow** | Your primary interrupt is ready |
| **Red** | Your primary interrupt is on cooldown |
| **Gray** | The cast cannot be interrupted |
| **Default** | Interrupt state is unknown |

#### Advanced

- **Show Blizzard Widgets** — display Blizzard's encounter and objective widgets on plates

---

### Explorer Mode

An immersive system that fades UI elements when they are not needed, giving you a cleaner view of the game world.

#### Timing

Control delays before Explorer Mode activates:

- After logging in (0-15 seconds)
- After reloading the UI (0-15 seconds)
- After loading screens (0-15 seconds)
- After combat ends (0-15 seconds)

#### Exit Conditions

Choose which situations disable Explorer Mode (show the UI):

- While in combat
- While having low health (configurable threshold: 30-90%)
- While having low mana (configurable threshold, with separate Druid form threshold)
- While in a group
- While in an instance
- While targeting a friendly unit
- While targeting a hostile unit
- While targeting a dead unit
- While having a focus target
- While in a vehicle or replacement actionbar

#### Elements to Fade

Individually toggle which elements are affected:

- Action Bars
- Pet Bar
- Stance Bar
- Player Unit Frame
- Player Class Power
- Pet Unit Frame
- Focus Unit Frame
- Objectives Tracker
- Chat Windows

---

### Aura Header

The top-right aura display (your buffs and debuffs), separate from unit frame auras:

- **Enable/Disable**
- **Fade When Idle** — fade the header when not interacting
- **Only Show With Modifier Key** — require Alt, Shift, or Ctrl to reveal
- **Keep Visible While Targeting** — prevent the target frame from hiding your auras
- **Anchor Point** — any of the 9 standard positions (top-left, center, bottom-right, etc.)
- **Growth direction** and **spacing** options

---

### Minimap

- **Enable/Disable** — when disabled, the minimap is untouched by AzeriteUI
- **Hide AddOn Text** — hide the custom "AddOns" label
- **Hide Clock Text** — hide the AzeriteUI clock display
- **Restore Blizzard Default** — reset to the default Blizzard minimap theme and position

---

### Chat

- **Fade Chat** — fade the chat after a period of inactivity
  - **Time Visible** — seconds before fading starts (5-120)
  - **Time Fading** — seconds the fade animation takes (1-5)
- **Clear Chat On Reload** — suppress old messages for a configurable delay after login/reload
  - Hold `Shift` during login/reload to bypass this
  - **Clear Delay** — how long chat stays blocked (1-10 seconds)

---

### Tooltips

- **Tooltip Theme** — choose between "Azerite" (custom styled) and "Classic"
- **Disable AzeriteUI Tooltips** — let Blizzard or other addons handle tooltip styling
- **Transparent Unit Tooltips on Nameplates** — make unit tooltips see-through when anchored to nameplates
- ConsolePort is automatically detected — AzeriteUI will not style or anchor tooltips when ConsolePort is active

---

### Objectives Tracker

- **Hide the Blizzard Tracker** — completely disable the default objectives tracker

---

### World Map

- **Enable/Disable** — when enabled, the world map uses a clean Rui-style border, shrink-on-maximize behavior, and player/cursor coordinates

---

### Bags

- **Sort Direction** — Left to Right or Right to Left
- **Insert Point** — from which side new items are inserted

---

### Info / Clock

- **24 Hour Mode** — toggle between 24h and 12h (AM/PM) clock
- **Use Local Time** — show your computer's time instead of server time

---

### Top Center Widgets

Controls for encounter and zone widgets displayed above the play area:

- **Always Show** — keep visible even with a target
- **Hide with Target** — hide when you have a target selected

---

## Detailed Options Reference

### Player Aura Filtering

The player frame aura row has two modes:

1. **Stock Behavior** — AzeriteUI's default mixed bright/dim styling
2. **Custom Filtering** — build your own filter from these categories:
   - Always Show Debuffs (magic, poison, bleed, boss debuffs)
   - Important Buffs (Ice Block, Barkskin, externals) with sub-categories:
     - Defensive Cooldowns
     - External Defensives
     - Control / Immunity Auras
     - Stealable / Priority Auras
   - Raid-Relevant Buffs (Bloodlust, Power Infusion, encounter buffs) with sub-categories:
     - General Raid Buffs
     - Raid-In-Combat Flags
   - Stacking Buffs (Maelstrom Weapon, Arcane Harmony, etc.)
   - Short Buffs In Combat (Clearcasting, Enrage, trinket procs) with sub-categories:
     - Player / Self Combat Buffs
     - Non-Cancelable Combat Buffs
   - Short Buffs Out Of Combat (pre-pull procs) with sub-categories:
     - Player / Self Temporary Buffs
     - Non-Cancelable Temporary Buffs
   - Long Utility Buffs (Sign of Battle, reputation buffs)
   - **Always Show Full Brightness** — no dimmed icons

### Movable Frames

Use `/lock` to enter frame-moving mode. This reveals anchor handles on all AzeriteUI-managed frames that you can drag to reposition. For default Blizzard frames, use WoW's built-in EditMode (Esc > EditMode).

### Profiles

AzeriteUI uses a single saved variable database (`AzeriteUI5_DB`) with Ace3 profile support. All settings are stored per-profile and can be managed through the options panel.

---

## JuNNeZ Edition Changes

This fan edition includes the following over the original AzeriteUI 5:

- **Retail-only WoW 12 codebase** — consolidated after the 5.3.46-JuNNeZ release
- **WoW 12 secret-value compatibility fixes** — adapting to Blizzard's API changes for the Midnight expansion
- **Actionbar live-update fixes** — action buttons refresh correctly during play
- **Decursive compatibility** — fixes for interoperability with the Decursive addon
- **Additional bug fixes** not present in the official release
- **Custom tweaks and quality-of-life improvements**
- **Experimental features and refinements**

---

## FAQ

### General

**Q: How do I open the options menu?**
A: Type `/az` or `/azerite` in the chat. You can also find AzeriteUI in the Blizzard AddOns settings panel (Esc > Options > AddOns).

**Q: How do I remove abilities from the action bars?**
A: Hold `Alt + Ctrl + Shift` and drag with the left mouse button.

**Q: How do I move UI elements around?**
A: Type `/lock` in chat. This shows movable anchor handles that you can drag. Type `/lock` again to save and exit. For default Blizzard frames, use WoW's built-in EditMode.

**Q: How do I reset everything to defaults?**
A: Type `/resetsettings` in chat. **Warning:** this erases all profiles and saved settings permanently.

**Q: Is this compatible with the official AzeriteUI?**
A: No. Do not install both versions simultaneously. This fan edition fully replaces the official addon.

**Q: Where can I get support?**
A: This is a personal fan project. JuNNeZ has a channel in GoldpawsStuff's Discord for this edition. For official AzeriteUI support, use the links in the Credits section below.

### Unit Frames

**Q: How do I switch between the orb-style player frame and the bar-style player frame?**
A: Enable Development Mode in the options, then go to Unit Frames > Player Alternate to toggle between the two styles.

**Q: Can I show health percentages on the player and target frames?**
A: Yes. Go to `/az` > Unit Frames > Player (or Target) and enable "Show Health Percent".

**Q: How do I choose between the Power Crystal and the Mana Orb?**
A: In Unit Frames > Player, look for "Player Power Style". Choose Automatic (switches by class), Mana Orb Only, or Power Crystal Only.

**Q: What is the "Ice Crystal Art" option?**
A: It swaps the power crystal's default artwork for an alternate ice-themed crystal design (Wrath of the Lich King style).

**Q: Can I hide the player castbar from the unit frame?**
A: Yes. Under Unit Frames > Player, disable "Show Castbar". You can still use the standalone Cast Bar module.

### Action Bars

**Q: How many action bars can I use?**
A: Up to 8 action bars (on Retail), plus a Pet Bar and a Stance Bar.

**Q: What is the ZigZag layout?**
A: An alternating offset pattern for buttons, creating a staggered look instead of a straight grid. You can choose which button the zigzag pattern starts from.

**Q: My bars are invisible — what happened?**
A: Check if "Enable Bar Fading" is turned on for that bar. Also check Explorer Mode settings — it may be fading your bars. Hover over the bar area to see if they appear.

**Q: How do I make bars only show when I mouse over them?**
A: Enable "Enable Bar Fading" on the bar, then enable "Only show on mouseover".

### Explorer Mode

**Q: What is Explorer Mode?**
A: It's an immersive feature that fades UI elements (action bars, unit frames, chat, tracker) when they're not needed — such as when you're out of combat with no target. The UI reappears automatically when needed.

**Q: My UI keeps fading away in dungeons. How do I stop that?**
A: In Explorer Mode settings, enable the exit conditions for "While in a group" and "While in an instance".

**Q: Can I keep certain elements visible while fading others?**
A: Yes. The "Elements to Fade" section lets you pick exactly which components are affected by Explorer Mode.

### Nameplates

**Q: What do the enemy nameplate castbar colors mean?**
A: Yellow = your primary interrupt is ready; Red = your interrupt is on cooldown; Gray = the cast cannot be interrupted; Default color = interrupt state unknown.

**Q: How do I make nameplates bigger or smaller?**
A: In Nameplate settings, adjust the "Overall size (%)" slider, or fine-tune separate sliders for friendly, enemy, and NPC plates.

**Q: Can I hide health bars on friendly player nameplates?**
A: Yes. Enable "Use names only for friendly players" in the Friendly Players section of nameplate options.

### Auras

**Q: What's the difference between the "Aura Header" and unit frame auras?**
A: The Aura Header is the top-right buff/debuff display (your personal buffs). Unit frame auras are the icons shown on individual unit frames (player, target, party, etc.). They have separate settings.

**Q: How do I customize which buffs show on my player frame?**
A: Under Unit Frames > Player, find the "Player Aura Row" section. Disable "Use AzeriteUI Stock Behavior" to unlock custom category toggles for fine-grained filtering.

**Q: Can I hide the top-right aura header?**
A: Yes. You can disable it entirely, set it to fade when idle, or require a modifier key to reveal it.

### Chat

**Q: Why is my chat empty after logging in?**
A: The "Clear Chat On Reload" feature temporarily blocks old messages. Hold `Shift` while logging in to bypass it. You can also disable it or adjust the delay in Chat settings.

### Compatibility

**Q: Does this work with Clique?**
A: Yes. Clique is listed as an optional dependency and is fully supported.

**Q: Does this work with Decursive?**
A: Yes. The JuNNeZ Edition includes specific compatibility fixes for Decursive.

**Q: Does this work with ConsolePort (controller support)?**
A: Partially. When ConsolePort is detected, AzeriteUI automatically disables tooltip styling and anchoring to avoid conflicts.

**Q: Does this work with other nameplate addons like Plater?**
A: You should disable AzeriteUI's nameplates (Nameplate settings > uncheck "Enable Azerite Nameplates") if using another nameplate addon.

---

## Compatibility

### Supported Optional Dependencies

These addons are recognized and integrate with AzeriteUI:

- **Clique** — click-casting on unit frames
- **Decursive** — dispel management (JuNNeZ compatibility patch)

### Libraries Included

AzeriteUI bundles the following libraries:

- Ace3 (AceAddon, AceDB, AceConsole, AceConfig, AceLocale, AceHook)
- oUF (unit frame framework)
- LibMoreEvents
- LibEditModeOverride
- LibKeyBound
- TaintLess

---

## GitHub Cloud Dev Environment

This repository includes a GitHub Codespaces dev container:

- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile`

### Start in Codespaces

1. Open the repository on GitHub.
2. Click `Code` > `Codespaces` > `Create codespace on main`.
3. Wait for container build to finish.

The container installs:

- Lua 5.1 (`lua`, `luac`)
- `luarocks`
- `ripgrep`
- Recommended WoW/Lua VS Code extensions used in this project

---

## Credits & Original Author

**AzeriteUI** is created and maintained by **GoldpawsStuff**. Design by Daniel Troko and Lars Norberg. Code by Lars Norberg. LibOrb System by Arahort. Nameplate and World Map optimization by Rui.

### Support JuNNeZ

- **Patreon:** [patreon.com/JuNNeZ](https://www.patreon.com/JuNNeZ)

### Support the Original Author

- **GitHub Sponsors:** [github.com/sponsors/goldpawsstuff](https://github.com/sponsors/goldpawsstuff)
- **Patreon:** [patreon.com/goldpawsstuff](https://www.patreon.com/goldpawsstuff)
- **Ko-fi:** [ko-fi.com/GoldpawsStuff](https://ko-fi.com/GoldpawsStuff)
- **PayPal:** [paypal.me/goldpawsstuff](https://www.paypal.me/goldpawsstuff)

### Connect with the Original Author

- **Discord:** [discord.gg/RwcSm8V3Dy](https://discord.gg/RwcSm8V3Dy) *(Official AzeriteUI Community)*
- **X (Twitter):** [@goldpawsstuff](https://x.com/goldpawsstuff)

---

## Fan Edition Notes

This fan edition is maintained independently and includes:

- WoW 12 secret-value compatibility fixes
- Actionbar live-update fixes
- Retail-only compatibility for WoW 12 (Midnight expansion) and future updates
- Decursive compatibility patch
- Personal tweaks and experimental features
- Additional bug fixes not present in the official release

---

**Disclaimer:** This is an unofficial modification. All credit for the original AzeriteUI codebase, design, and architecture goes to GoldpawsStuff and Blakmane_. This fan edition is provided as-is without warranty. For the official, supported version, please use the original AzeriteUI from the links above. I have permission from the original author.