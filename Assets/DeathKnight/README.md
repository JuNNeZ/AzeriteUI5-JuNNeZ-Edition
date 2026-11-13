# Death Knight / Ebon Oath — WIP runtime preview

Select Death Knight (WIP) under `/az` -> Themes, or run `/azdeathknight on`
after `/reload`. `/azdeathknight off` restores AzeriteUI. Theme selection is
per character, following the existing class-theme system.

These 63 textures are an explicitly authorized review preview. Production
geometry/source gates still fail; neither Retail nor Forever is live validated.
Source paintings and rejected evidence remain in `Assets_Draft/DeathKnight/`
and `Docs/Research_Assets/DeathKnight/FullSet/`.

Reproduce with `python Tools/Install-DeathKnightLivePreview.py --live-preview`.
The tooltip uses explicit eight-cell atlas packing of the original DK corner
and rail patches. `Tools/DeathKnightTooltipAtlas.py` records exact RGBA patch
replay, the rejected atlas, seam checks and complete offline 1x/2x assemblies.
Validate hashes, exact source/layer replay, bounds and linked clients with
`python Tools/Check-DeathKnightLivePreview.py`. Run the widget harness through
`Tools/Run-Elune.ps1 -Script Tools/Harness/deathknight_theme_harness.lua .`.
Complete live reload, switching, combat, Edit Mode, BugSack/taint and assembled
visual checks on each client before recording acceptance.
