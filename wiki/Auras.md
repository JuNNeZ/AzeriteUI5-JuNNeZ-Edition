# Auras

AzeriteUI has two separate aura systems that work independently:

1. **Aura Header** — The top-right buff/debuff display (your personal buffs and debuffs)
2. **Unit Frame Auras** — Auras shown directly on unit frames (player, target, party, raid, etc.)

---

## Aura Header

The Aura Header is the collection of buff/debuff icons in the upper-right area of the screen — equivalent to Blizzard's default buff display, but styled to match AzeriteUI.

Settings: `/az → Auras`

### Enable / Disable
Toggle the entire Aura Header on or off. When disabled, AzeriteUI does not manage the buff/debuff display in that area.

### Visibility Options

| Setting | Description |
|---|---|
| **Fade When Idle** | Gradually fades the aura header when you haven't interacted with the UI recently |
| **Only Show With Modifier Key** | Requires holding **Alt**, **Shift**, or **Ctrl** to reveal the aura header — useful for maximally clean screens |
| **Keep Visible While Targeting** | Prevents the header from fading when you have a target selected |

### Position & Layout

| Setting | Description |
|---|---|
| **Anchor Point** | Any of the 9 standard positions (Top-Left, Top-Center, Top-Right, Center-Left, Center, Center-Right, Bottom-Left, Bottom-Center, Bottom-Right) |
| **Growth Direction** | Which direction the aura icons expand from the anchor (left/right, up/down) |
| **Spacing** | Horizontal and vertical gap between aura icons |

---

## Unit Frame Auras

Unit frame auras appear directly on individual unit frames: player, target, party, raid, boss, and arena frames. Each frame type has its own independent aura settings.

### Player Frame Aura Row

The player frame includes a dedicated aura row that can be configured in two modes:

#### Mode 1: Stock Behavior (Default)
AzeriteUI uses its default mixed bright/dim styling, classifying auras by type and priority automatically. Helpful auras and important debuffs are shown at full brightness; less important auras are dimmed.

- **Always Show Full Brightness** — Optional override to disable dimming entirely; all icons display at full opacity regardless of priority

During combat, secret-value windows in WoW 12 may cause brief classification uncertainty. AzeriteUI fails open during these windows (shows auras at full brightness) to prevent flickering.

#### Mode 2: Custom Filtering
Build your own filter from these categories. Enable only the categories you want to track:

| Category | What It Shows |
|---|---|
| **Always Show Debuffs** | Magic, poison, bleed, and boss debuffs on you |
| **Defensive Cooldowns** | Ice Block, Divine Shield, Barkskin, and similar personal defensives |
| **External Defensives** | Ironbark, Pain Suppression, Blessing of Protection cast on you |
| **Control / Immunity Auras** | Crowd control effects and immunities |
| **Stealable / Priority Auras** | High-priority buffs and Spellstealable buffs |
| **General Raid Buffs** | Bloodlust/Heroism, Power Infusion, Augmentation buffs |
| **Raid-In-Combat Flags** | Important combat encounter flags |
| **Stacking Buffs** | Maelstrom Weapon, Arcane Harmony, and other resource stacks |
| **Player / Self Combat Buffs** | Clearcasting, Enrage, trinket procs — short in-combat buffs |
| **Non-Cancelable Combat Buffs** | Combat buffs that cannot be right-clicked off |
| **Player / Self Temporary Buffs** | Pre-pull and out-of-combat procs |
| **Non-Cancelable Temporary Buffs** | Temporary effects that cannot be removed |
| **Long Utility Buffs** | Sign of Battle, reputation buffs, and similar long-duration utilities |

### Target Frame Auras

The target frame aura row has standard layout controls:

| Setting | Description |
|---|---|
| **Auras Per Row** | How many icons appear in a row before wrapping |
| **Aura Size** | Icon size in pixels |
| **Padding X / Y** | Horizontal and vertical spacing between icons |
| **Growth Direction** | Left/Right and Up/Down expansion direction |
| **Initial Anchor Point** | Where on the frame the aura row starts |

### Party & Raid Frame Auras

Party and raid frames support both stock and custom filtering (same category system as the player frame), plus additional group-specific options:

| Setting | Description |
|---|---|
| **Show Dispellable Debuffs** | Highlight debuffs you can dispel |
| **Show Boss / Important Debuffs** | Large icons for high-priority encounter debuffs |
| **Show Other Short Debuffs** | Short-duration debuffs from other sources |
| **Glow for Dispellable Debuffs** | Adds a colored border glow to the frame for the debuff type |
| **Show Helpful Externals** | Ironbark, Pain Suppression, and similar externals cast on the member |
| **Aura Size** and **Debuff Scale** | Icon size and relative debuff icon size |
| **Growth Direction** | Expansion direction for aura rows |

### Big Debuff (25-man / 40-man Raid Frames)

For 25-man and 40-man raid frames, a **Big Debuff** display shows a single large-format priority debuff icon when an important encounter debuff is active on the unit. Configurable size slider available.

---

## Debuff Type Color Coding

AzeriteUI uses standard color coding for debuff types across all frames:

| Color | Debuff Type |
|---|---|
| 🔵 Blue | Magic |
| 🟢 Green | Poison |
| 🔴 Red | Bleed / Physical |
| 🟣 Purple | Curse |
| 🟤 Brown | Disease |

---

## Tips

- For healers, enable **Glow for Dispellable Debuffs** on party/raid frames to instantly see who needs a dispel.
- For DPS players, Custom Filtering with only **Defensive Cooldowns** and **Important Debuffs** keeps the player aura row clean and relevant.
- The `/azdebug aurasnapshot player` command dumps a live aura state snapshot — useful if aura classification seems wrong.
- If auras flicker or misclassify after WoW 12 patches, check for new JuNNeZ Edition updates — WoW 12 secret-value handling sometimes needs maintenance.
