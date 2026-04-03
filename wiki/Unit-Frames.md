# Unit Frames

AzeriteUI replaces all standard WoW unit frames with a custom, art-driven design. Every unit frame can be individually enabled or disabled through `/az → Unit Frames`.

---

## Player Frame

The centerpiece of AzeriteUI — a custom-skinned health bar with Azerite-themed artwork.

### Health Bar
- Custom Azerite backdrop textures that evolve as your character levels up (Novice, Hardened, Seasoned, etc.)
- Smooth fill animation
- Absorb overlay (shields displayed on the health bar)
- Threat glow — the bar glows when you have aggro

### Power Widget
Displayed to the left of the health bar. Three display modes:

| Mode | Description |
|---|---|
| **Automatic (By Class)** | Shows a Mana Orb for mana users, a Power Crystal for energy/rage/etc. |
| **Mana Orb Only** | Always use the circular orb style |
| **Power Crystal Only** | Always use the vertical crystal style |

**Additional power options:**
- **Ice Crystal Art** — alternate ice-themed crystal artwork (Wrath of the Lich King style)
- **Crystal/Orb Color Source** — choose between default AzeriteUI power colors or enhanced token-based colors
- **Show Power Text** — display the power value; optionally show only in combat
- **Power Text Size** and **Alpha** — readability controls
- **Power Text Style** — Short Number, Full Number, Percent, or Short + Percent

### Other Player Frame Options
- **Show Health Percent** — display a percentage next to the health value
- **Show Castbar** — overlay the castbar on the player frame
- **PvP Badge** — X/Y position offset for the PvP indicator
- **Combat Indicator** — animated icon shown when entering combat
- **Auras** — configurable player aura row (see [Auras](Auras))

---

## Player Alternate Frame

An alternative player frame style that mirrors the target frame design — a horizontal bar instead of the orb/crystal. Available when **Development Mode** is enabled (`/devmode`).

Enabling the Alternate Frame automatically disables the default Player Frame. Supports:
- Class-colored health bars
- Auras (above or below frame)
- Castbar overlay
- Health percent text
- Unit name display

---

## Target Frame

The target frame displays information about your current target.

- Health bar with **smart textures** that automatically scale for boss targets (larger) and critters (smaller)
- **Show Auras** with layout controls:
  - Auras per row, aura size, padding (X/Y)
  - Growth direction (left/right, up/down)
  - Initial anchor point
- **Show Castbar** — includes interrupt-state text coloring (see [Nameplates — Interrupt Colors](Nameplates#enemy-castbar-interrupt-colors))
- **Show Unit Name** — display the target's name
- **Show Health Percent** — numeric or percentage health display
- **Show Power Value** — power display with format and alpha options

---

## Target of Target (ToT)

Compact display of your target's current target.

- **Hide when targeting player** — makes the frame transparent when your target is targeting you
- **Hide when targeting self** — makes the frame transparent when the target is targeting itself

---

## Focus Frame

Dedicated frame for your focus target (`/focus`). Can be individually enabled/disabled via `/az → Unit Frames → Focus`.

---

## Pet Frame

Displays your pet's health. Can be individually enabled/disabled.

---

## Party Frames

Full party frame suite for groups of 2–5 players.

### Visibility Control
Choose exactly which group sizes activate the party frames:
- Party 2–5
- Raid 1–5, 6–10, 11–25, 26–40

### Health Colors
| Option | Description |
|---|---|
| Flat Green | Classic solid green health bar |
| AzeriteUI Class Colors | Health bar tinted with AzeriteUI's class color palette |
| Blizzard Class Colors | Health bar tinted with Blizzard's default class colors |
| Class Color on Mouseover | Class colors only appear when hovering over the frame |

### Aura System (Party)
- **Stock or Custom filtering** — use AzeriteUI defaults or build your own filter
- Dispellable debuffs, boss/important debuffs, other short debuffs
- Helpful externals (Ironbark, Pain Suppression, etc.)
- Raid buffs and short helpful buffs
- Aura size, debuff scale, growth direction
- **Glow for Dispellable Debuffs** — highlights the frame border with the debuff-type color (magic = blue, poison = green, bleed = red, etc.)

### Other Party Frame Options
- **Show Player** — toggle whether you appear in the party display
- **Show Player in Party** — toggle your own frame in party display

---

## Raid Frames

Three separate raid frame styles, each optimized for different group sizes:

| Frame | Intended For |
|---|---|
| Raid Frames (5-man) | Small group / mythic+ style |
| Raid Frames (25-man) | Normal/Heroic raid size |
| Raid Frames (40-man) | Legacy 40-man raids |

Each has independent visibility toggles for group sizes, health color options, and aura configurations identical to party frames, plus:

- **Range Indicator** — fades out-of-range group members
- **Big Debuff** (25-man and 40-man) — displays a large priority debuff icon with configurable size

---

## Boss Frames

Dedicated frames for boss encounter units. Can be individually enabled/disabled.

---

## Arena Enemy Frames

Displays enemy arena targets during PvP.

- **Range Indicator** — fades out-of-range enemies
- **Show in Battlegrounds** — optionally display flag carrier frames during battleground matches

---

## Player Cast Bar

A **standalone** castbar module, separate from the unit frame castbar overlay. This allows you to have a cast bar in a different screen position from the player frame.

Can be individually enabled/disabled and repositioned with `/lock`.

---

## Player Class Power

Displays class-specific secondary resources:

| Class | Resource Shown |
|---|---|
| Rogue / Druid | Combo Points |
| Paladin | Holy Power |
| Mage | Arcane Charges |
| Monk | Chi |
| Warlock | Soul Shards |
| Death Knight | Runes |
| Shaman | Maelstrom Weapon stacks |
| (others) | Appropriate class resource |

**Option:**
- **Click-Through** — ON (default): clicks pass through to frames behind. OFF: blocks clicks, preventing accidental right-click menus.

---

## Shared Unit Frame Settings

These settings apply globally to all unit frames:

| Setting | Description |
|---|---|
| **Prioritize Unit Frame Auras** | Group auras by relevance and readable timing instead of application order |
| **Show Blizzard Raid Bar** | Toggle the Blizzard raid utility bar (ready check, raid markers) |
| **Color Cast Spell Text By State** | Tint cast spell names based on interrupt/protected state |

---

## Tips

- All unit frames can be repositioned with the `/lock` command
- Disabling a frame in its settings completely removes it from the screen
- Party and Raid frames overlap — use the visibility settings to control which frame type activates for each group size, avoiding double-display
- The Player Alternate Frame requires Development Mode; it is experimental and may change in future versions
