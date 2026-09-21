# Options Menu Guide

Open the custom panel with `/az` or `/azerite`. It reads the addon's AceConfig option
tables through AzeriteUI's own renderer; addon settings remain stored per profile.

## Custom panel

The custom panel provides grouped navigation, search, section tracking, changed-setting
markers, individual reset controls and live frame previews. Changing a frame-backed setting
briefly casts a golden glow around and labels the real affected frame; if no usable live frame
exists, the footer says so. `/az new` remains an alias. `/az classic` opens the retained previous
window, and `/az legacy` opens the stock Ace3 fallback. They edit the same addon profiles.

The new panel's **Settings -> Appearance** page controls theme, background opacity,
scale and position reset; **Settings -> Changelog** shows recent release notes.
Those appearance settings belong to the window, separately from addon profiles.

The released panel includes phases 1 through 4c. The post-release worktree migrates `/az`
to it while retaining the previous window and adds the live frame preview. Further artwork,
keyboard navigation and other later phases remain deferred. Change frame settings outside
combat; the panel does not provide a general deferred-write queue.

On Forever, **Minimap -> Day and Night Indicator** controls the new indicator.
Drag it around the map or right-click it to adjust its distance. Turning it off
restores Blizzard's own indicator.

## Sections, in menu order

| Section | Covers |
| --- | --- |
| Settings Profile | Select, create, duplicate, delete and reset profiles. |
| Action Bars | 8 bars plus pet and stance bars, the micro menu, assisted combat highlight. |
| Unit Frames | Every unit frame family, their auras, castbars, colors, sorting and visibility. |
| Nameplates | Scale, visibility, health text, auras, castbar interrupt colors, threat colors. |
| Auras | The top-right personal aura header only. Unit frame auras live under Unit Frames. |
| Bags | Sort direction and insert point. |
| Chat | Fade behavior and the clear-on-reload window. |
| Minimap | Enable, theme, addon and clock text. |
| World Map | The Rui-style clean map integration. |
| Objectives Tracker | AzeriteUI's tracker and how much of Blizzard's remains. |
| Widgets | Top-center encounter and zone widgets. |
| Tooltips | Style, anchoring, combat visibility, ID display. |
| Info Bar | Clock format and local vs server time. |
| Game Menu | Which addon styles the Escape game menu when more than one tries to. |
| Explorer Mode | Automatic UI fading, its timing and its exit conditions. |

## Typical setup flow

1. **Unit Frames** - enable the frame families you want, and set which group sizes
   each one is allowed to appear in. This is the setting most people need first,
   because more than one family can claim the same group size.
2. **Action Bars** - bar count, buttons per bar, layout and fading.
3. **Nameplates** - overall scale first, then the per-category sliders.
4. **Explorer Mode** - fade timing and exit conditions.
5. `/lock` - drag AzeriteUI frames into place.

## Options worth knowing about

- **Unit Frames -> (family) -> Visibility.** Each of Party, Raid (5), (25) and (40)
  declares which group sizes it appears in. Two families set to the same size will
  both appear.
- **Unit Frames -> (family) -> Sorting.** Sort By group, role, class or name, plus a
  direction. Raid (25) and (40) had role sorting silently broken until 5.3.90; if a
  raid suddenly reorders itself after updating, that is the fix landing, and Sort By
  Group restores the old join order.
- **Unit Frames -> Party / Raid (5) -> Show player in party / Show player in raid.**
  Two separate toggles since 5.3.90, so you can drop your own frame in arena while
  keeping it in a five-man.
- **Unit Frames -> Prioritize Unit Frame Auras.** Groups auras by relevance and
  remaining time rather than by application order.
- **Action Bars -> Micro Menu.** Blizzard's bottom strip and the AzeriteUI cog wheel
  in the bottom right are independent toggles. Both settings apply at load, so
  changing either prompts a reload.
- **Game Menu -> Game Menu Style.** Only matters when another addon also restyles the
  Escape menu - W2UI, GW2 UI, FeelUI, DiabolicUI3, AddOnSkins or ConsolePort's menu.
  AzeriteUI asks which one to keep the first time the menu opens in a session, and this
  is where you change it later. Keeping AzeriteUI's or Blizzard's menu turns the other
  addon off for that character. Saved per character, and every change reloads.
- **Unit Frames -> Player -> Mana Orb Texture / Glass / Rim / Pedestal.** The orb ships four
  fill artworks and three decorative layers; until now only one fill and the surrounding case
  were reachable. Glass is on by default, the rest keep the previous look.
- **Unit Frames -> Target -> Extended Classification Badges.** Off by default. Completes the
  badge set with ordinary, level-?? and dead targets.
- **Nameplates -> Health text placement.** Below the bar, inside the bar, or inside
  only while in combat.
- **Explorer Mode -> When to exit.** Every entry here has a tooltip explaining
  exactly what it watches.

## Development mode

`/devmode` toggles it and reloads. It adds a version label in the bottom left corner
and unlocks a few developer-only entries. It is **not** required for `/azdebug`, and
it is not required for the Player Alternate frame either - that group simply stays
hidden while the normal Player frame is enabled. Disable Player and it appears.

## Profiles

See [Profiles and Reset](Profiles-and-Reset.md).
