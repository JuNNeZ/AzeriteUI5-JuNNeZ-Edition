# Nameplates and Auras

Two separate systems that happen to both be about auras. Nameplates are `/az` ->
Nameplates. The personal aura header is `/az` -> Auras. Auras attached to unit frames
are under Unit Frames, not here.

## Nameplates

`/az` -> Nameplates. **Enable Azerite Nameplates** is the master switch - turn it off
if you run Plater or another nameplate addon.

### Visibility

- **Always show names**
- **Health text placement** - below the bar, inside the bar, or inside only in combat
- **Show auras**
- **Only show auras on your target**
- **Maximum distance** - how far plates remain visible

### Size

- **Use Blizzard overall scale** - follow Blizzard's own nameplate scale slider
- **Overall size (%)**
- **Enemy size (%)** and **Enemy target size (%)**
- **Friendly/player size (%)** and **Friendly/player target size (%)**
- **Friendly NPC size (%)**
- **Friendly name size (%)** and **Friendly name target size (%)** for name-only plates
- **Castbar vertical offset**

### Friendly players

**Use names only for friendly players** replaces friendly player plates with a
class-colored name and no health bar.

### Castbar interrupt colors

Enemy castbars are colored by whether you can actually stop the cast:

| Color | Meaning |
| --- | --- |
| Yellow | Your primary interrupt is ready |
| Red | Your primary interrupt is on cooldown |
| Gray | The cast cannot be interrupted |
| Base | Interrupt state unknown |

### Enemy threat colors

Health-bar threat colors are configured separately from the castbar interrupt colors.
AzeriteUI's deep yellow keeps the non-target combat health yellow darker than the
castbar's ready-interrupt yellow, so the two never read as the same signal.

### Advanced

- **Show Blizzard widgets** - encounter and objective widgets on plates.

## The personal aura header

`/az` -> Auras. This is the top-right block of your own buffs and debuffs. It has no
effect on aura rows attached to Player, Target, Party or any other unit frame.

- **Enable**
- **Fade When Idle**
- **Only Show With Modifier Key**, plus **Required Modifier Key**
- **Keep Visible While Targeting** - stop the target frame from covering it. Holding
  the modifier key overrides this.
- **Anchor Point** - any of the nine standard points
- **Buttons Per Row**, **Horizontal/Vertical Growth**, **Horizontal/Vertical Padding**

A permanent aura with no duration draws as a full bar rather than an empty trough.
That is deliberate: Blizzard's duration bar has no zero check, so the header draws the
bar inverted to get the right result.

## Auras and Retail 12.1 secret values

Retail 12.1 marks more aura and cooldown data as secret. Values that are secret cannot
be read or formatted by an addon, only handed straight to a Blizzard-owned widget.
AzeriteUI routes aura data through a guarded unpacker so a secret field degrades to a
missing number rather than a Lua error, which is why a bar sometimes keeps working
while its text does not.

If you see `Secret values are only allowed during untainted execution` in BugSack,
that is worth reporting with the full stack.
