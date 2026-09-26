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
- **Friendly NPCs only for your target** - only your target's friendly NPC plate shows, and the one
  your interact key would use. Ticking it turns on the game's Friendly NPCs setting, which it needs
- **Friendly players only for your target** - the same for friendly player plates
- **Maximum distance** - how far plates remain visible

### Aura filters

Which kinds of aura a plate shows, each a switch. They fill the two aura rows in this
order, and they keep showing in combat:

- **Crowd control** - stuns, fears, roots and the like, from anyone
- **Your debuffs**, optionally **Only the ones Blizzard highlights**
- **Important debuffs from others** - what Blizzard flags to show on every nameplate
- **Buffs you can dispel** - purge, spellsteal or soothe
- **Important enemy buffs** - such as big defensive cooldowns
- **Your short buffs** - 30 seconds or less, on friendly plates

### Game settings

Blizzard's own nameplate settings, shown here so you do not have to go to the game's
Options for them. Changing one here changes it there, and AzeriteUI's plates follow
them. A change made in combat applies when combat ends.

- **Always show nameplates** - off, plates only show while you are in combat
- **Enemies**, **Friendly players** and **Friendly NPCs** - which plates show at all. With
  friendly NPCs off, a friendly NPC still gets its plate while it is your soft target or
  has an objective bar, as with Blizzard's plates.
- **Stack enemy nameplates** and **Stack friendly nameplates**

### Size

- **Use Blizzard overall scale** - follow Blizzard's Nameplate Size setting instead of
  **Overall size**; Medium matches 100%
- **Overall size (%)**
- **Castbar vertical offset**
- **Position** - over the unit's head, or at its feet
- **Enemy size (%)** and **Enemy target size (%)**
- **Friendly/player size (%)** - friendly players, and the companions of follower dungeons,
  which the game draws as players
- **Friendly NPC size (%)** - vendors, trainers, quest givers and every other friendly NPC
- **Friendly/player target size (%)** - how much larger any friendly plate grows when targeted
- **Friendly name size (%)** and **Friendly name target size (%)** for name-only plates
- **Target marker size** - the raid target icon (skull, cross, star...) beside the health bar

Blizzard's **Simplified** nameplate option does not shrink AzeriteUI's plates; the size
settings above decide.

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
