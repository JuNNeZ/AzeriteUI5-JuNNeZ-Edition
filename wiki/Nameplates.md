# Nameplates

AzeriteUI provides custom-styled nameplates that replace Blizzard's default nameplates. Settings are accessible via `/az → Nameplates`.

---

## Visibility

| Setting | Description |
|---|---|
| **Always Show Names** | Keep unit names permanently visible without needing to hover |
| **Health Text Placement** | Where the health value appears: **Below the bar**, **Inside the bar**, or **Inside only during combat** |
| **Show Auras** | Display buffs and debuffs on nameplates |
| **Only Show Auras on Target** | Limit aura display to your currently selected target only — reduces visual clutter in large pulls |

---

## Size & Scaling

### Global Scale

| Setting | Description |
|---|---|
| **Use Blizzard Overall Scale** | Follow Blizzard's global nameplate scale slider instead of AzeriteUI's custom scale |
| **Overall Size (%)** | Base size multiplier for all AzeriteUI nameplates |
| **Maximum Distance** | How far away (in yards) nameplates appear. Default: 40 |
| **Castbar Vertical Offset** | Nudge the castbar element up or down relative to the nameplate |

### Per-Type Scale

Fine-tune the size of individual nameplate types:

| Setting | Description |
|---|---|
| **Friendly Player Size** | Scale for friendly player nameplates |
| **Friendly NPC Size** | Scale for friendly NPC nameplates |
| **Enemy Size** | Scale for enemy nameplates |
| **Friendly Target Size** | Additional scale boost when a friendly unit is targeted |
| **Enemy Target Size** | Additional scale boost when an enemy is targeted |

---

## Friendly Players

| Setting | Description |
|---|---|
| **Names Only for Friendly Players** | Show class-colored names and hide the health bar for friendly players — cleaner group environments |
| **Friendly Name Size** | Scale for the name-only display |
| **Name Target Size** | Scale boost when a friendly player is targeted in name-only mode |

---

## Enemy Castbar Interrupt Colors

AzeriteUI's enemy castbars use a color-coded system to communicate your interrupt readiness at a glance:

| Color | Meaning |
|---|---|
| 🟡 **Yellow** | Your primary interrupt is ready — you can interrupt this cast |
| 🔴 **Red** | Your primary interrupt is on cooldown — cannot interrupt right now |
| ⬜ **Gray** | This cast cannot be interrupted (immune/protected) |
| Default | Interrupt state is unknown |

This color system makes it easier to quickly identify actionable interrupts without needing to track your interrupt cooldown manually.

---

## Advanced

| Setting | Description |
|---|---|
| **Show Blizzard Widgets** | Display Blizzard's encounter and objective widgets on nameplates (e.g., health bars for vehicles) |

---

## Using with Other Nameplate Addons

If you use a dedicated nameplate addon like **Plater Nameplates** or **KuiNameplates**, you should let that addon handle nameplates instead of AzeriteUI. To do this:

1. Open `/az → Nameplates`
2. Disable AzeriteUI's nameplate customization (uncheck the enable toggle if present)
3. Configure your other nameplate addon normally

See [Compatibility](Compatibility) for more details.

---

## Tips

- The **Only Show Auras on Target** option is highly recommended for melee DPS players in large pulls to avoid aura clutter from many nearby enemies.
- **Names Only for Friendly Players** is great for PvP environments where health bars on allies add visual noise.
- Use **Maximum Distance** to reduce nameplate pop-in on low-spec systems.
- The **Enemy Target Size** boost makes it easy to spot your current target in a crowd without clicking around.
