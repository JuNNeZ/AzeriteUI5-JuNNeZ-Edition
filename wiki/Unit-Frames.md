# Unit Frames

Every family below is a separate module with its own enable toggle, its own options,
and its own saved settings. `/az` -> Unit Frames.

## Families

| Family | Notes |
| --- | --- |
| Player | The orb-and-crystal centerpiece. Health bar art changes with level tier. |
| Player Alternate | A mirrored target-style player frame. Hidden while Player is enabled. |
| Target | Health art changes by classification tier: Critter, Novice, Hardened, Seasoned, Boss. Classification badges are boss/elite/rare, and optionally ordinary, level-?? and dead. |
| Target of Target | Compact, with its own hide rules. |
| Focus | Standalone focus frame. |
| Pet | Pet health and power. |
| Boss | Encounter boss units. |
| Arena | Enemy arena units, optionally reused for battleground flag carriers. |
| Party | Party-style frames. |
| Raid (5) | Five separate frames driven by unit attribute drivers, not a group header. |
| Raid (25) | Compact raid layout. |
| Raid (40) | Compact raid layout for the largest groups. |
| Player Castbar | The standalone castbar, separate from the player frame overlay. |
| Player Class Power | Combo points, Holy Power, Chi, Runes, Soul Shards, Maelstrom, Stagger. |

## Visibility - the setting to get right first

Party, Raid (5), (25) and (40) each declare which group sizes they are allowed to
appear in:

- Show in Party (2-5)
- Show in Raid (1-5)
- Show in Raid (6-10)
- Show in Raid (11-25)
- Show in Raid (26-40)

More than one family can claim the same size, and if you enable two for the same
range you will see both. Arena frames additionally have **Show in Battlegrounds**.

Note that arenas and battlegrounds put you in a *raid* group, not a party, which is
why arena setups are configured under the raid ranges.

## Sorting

Party, Raid (5), (25) and (40) all expose:

- **Sort By** - Group, Role, Class or Name
- **Sort Direction** - ascending or descending

Role sorting on Raid (25) and (40) was fixed in 5.3.90. Those frames had shipped with
role sorting nominally on for years while quietly sorting by raid index instead, so
the first raid after updating will visibly reorder into tanks, healers, damage. Set
Sort By to Group to get the old order back.

## Showing your own frame

Party and Raid (5) each carry two toggles since 5.3.90:

- **Show player in party**
- **Show player in raid**

They are separate because arenas and battlegrounds are raid groups. Hiding yourself
in arena, where your own frame is already the big orb, no longer costs you your frame
in a five-man dungeon.

## Health colors

Party, Raid (5), (25) and (40) share one set of coloring modes:

- Flat health green
- AzeriteUI class colors
- Blizzard class colors
- Class color only on mouseover

## Specialization icons

- **Party** and **Raid (5)**: replaces the portrait with the member's specialization icon.
- **Raid (25)** and **Raid (40)**: puts the specialization icon on the role badge beside
  the health bar, including damage dealers, who normally have no badge at all.

Specialization can only be read by inspecting a unit, and inspection needs them
connected, visible, in range and inspectable. Until that resolves, the frame keeps
showing the portrait or the plain role icon. Followers keep their portraits
permanently: they are NPCs and cannot be inspected.

## Auras on unit frames

These are separate from the top-right personal aura header, which lives under
`/az` -> Auras.

Player and Target expose full layout control: auras per row, size, padding, growth
direction and initial anchor. Party frames add a dedicated aura row with dispellable
debuff emphasis and an optional frame glow in the debuff-type color.

The player aura row has two modes. **Use AzeriteUI Stock Behavior** is the default
mixed bright/dim styling. Turning it off unlocks custom categories built only from
native Retail 12.1 filters that stay safe in combat:

- Always Show Debuffs
- Nameplate-highlighted buffs
- Stealable buffs
- Player / self buffs
- Raid-relevant buffs
- Short helpful buffs
- Other short debuffs
- Long utility buffs
- Other temporary buffs, with a maximum temporary duration cap
- **Always Show Full Brightness** - no dimmed icons

## Castbars

- **Color Cast Spell Text By State** tints the spell name by interrupt state.
- **Color Entire Target Castbar By State** is the full-bar version. It is currently
  held disabled while protected target casts still resolve unreliably.
- The target castbar renders as an overlay on the health bar and takes its fill
  direction from the same layout data, so both bars always fill the same way.
  `/azdebugtarget status` prints both directions and flags a mismatch.

## Player frame specifics

- **Player Power Style** - Automatic by class, Mana Orb only, or Power Crystal only.
- **Crystal/Orb Color Source** - AzeriteUI power colors, or class color.
- **Use Ice Crystal Art** - alternate Wrath-style crystal artwork.
- **Mana Orb Texture** - Clouds (default), Galaxy, Moon or Sphere. All four have shipped in the
  addon's art folder since the fork; only Clouds was ever reachable.
- **Mana Orb Glass** - a glass dome over the orb, on by default. The frame had been creating this
  layer on every login and hiding it again because the layout carried no texture for it.
- **Mana Orb Rim** - a heavy ring at the orb's edge. Off by default.
- **Mana Orb Pedestal** - a sculpted plinth beneath the orb. Off by default.
- **Elemental Crystal/Bar Resource Split** - Shaman-specific resource presentation.
- **Show Power Text**, with style (short, full, percent, short + percent), size and alpha.
- **PvP Badge** X/Y offsets, with a reset button.
- Pinging your own frame calls out health and mana, the same callout Blizzard puts on
  its player frame. Holding the ping key over the frame gives the callout rather than
  the radial wheel, because the frame has no portrait for the wheel to live on.

## Class Power

Shows the class resource that applies to your specialization: combo points, Holy
Power, Arcane Charges, Chi, Soul Shards, Runes, Maelstrom Weapon stacks, Stagger.
**Class Power Click-Through** is on by default so clicks pass through to whatever is
behind; turn it off to stop accidental right-clicks landing on the resource frame.
