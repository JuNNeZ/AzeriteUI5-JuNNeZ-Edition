# FAQ

## Is this the official AzeriteUI?

No. This is the JuNNeZ fan-maintained edition based on AzeriteUI 5 by GoldpawsStuff.
It is not affiliated with the original project. For official AzeriteUI support, use
the original addon's channels.

## Which game version is supported?

Retail only, Interface 120100 (WoW 12.1). The codebase was consolidated to
retail-only in 5.3.46-JuNNeZ.

## How do I open settings?

`/az` or `/azerite`.

## How do I move frames?

`/lock` for AzeriteUI-owned frames. Blizzard's Edit Mode for Blizzard-owned frames.

## How do I remove an ability from a bar?

Hold `Alt + Ctrl + Shift` and drag with the left mouse button.

## How do I reset everything?

`/resetsettings`. This is destructive and resets **all** profiles. Reset the current
profile from `/az` -> Settings Profile first; that is usually what you actually want.

## Does it support profiles?

Yes. `/az` -> Settings Profile for select, create, duplicate, delete and reset.

## Why did my raid frames reorder themselves after updating?

Role sorting on the Raid (25) and Raid (40) frames was fixed in 5.3.90. Those frames
had shipped with role sorting nominally enabled while quietly sorting by raid index,
because the setting named the main-tank flag rather than the tank/healer/damage role.
Set **Sort By** to Group under that frame family to get the old order back.

## Can I hide my own frame in arena but keep it in a dungeon?

Yes, since 5.3.90. Party frames and Raid (5) frames each have **Show player in party**
and **Show player in raid** as separate toggles. Arenas and battlegrounds are raid
groups, which is why they follow the raid half.

## How do I switch between the orb player frame and the bar-style one?

`/az` -> Unit Frames -> Player, and turn **Enable** off. The **Player Alternate** group
appears once the normal Player frame is disabled. Development mode is not required.

## Why do some values behave differently in WoW 12?

Retail 12.1 marks more combat, aura, cooldown and unit data as secret values. Addons
can often display those values only by handing them straight to Blizzard-owned
widgets, never by reading or formatting them. That is why one visual layer can keep
working while its text disappears. AzeriteUI includes guarded handling so this
degrades rather than errors.

## What if nameplate interrupt colors look wrong?

Check the Nameplates options first, then test with other nameplate addons disabled,
then capture `/azdebug nameplates <unit>` output for one sample cast.

## Do I need development mode?

No. `/azdebug` works without it - it just prints a notice that some features are
limited. Development mode (`/devmode`) adds the version label and a few
developer-only entries.

## Does it work with Plater or other nameplate addons?

Turn off **Enable Azerite Nameplates** in `/az` -> Nameplates first. Two addons cannot
own the same nameplate.

## Does it work with Clique, Decursive, ConsolePort?

- **Clique**: yes, supported as an optional dependency.
- **Decursive**: yes. This edition carries a specific compatibility patch that keeps
  Decursive receiving usable debuff data under Retail 12.1's secret-value rules.
- **ConsolePort**: partially. When ConsolePort is loaded, AzeriteUI stops styling and
  anchoring tooltips, and its ConsolePort_Bar disables the AzeriteUI action bars.

## Where do I report problems?

GitHub Issues: <https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/issues>

See [Troubleshooting](Troubleshooting.md) for what to include.
