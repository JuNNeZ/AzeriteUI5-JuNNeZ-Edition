# Legacy HUD media

Original AzeriteUI 3.2.569-RC / GoldpawUI media, imported from commit
`0663cc39e9749cdb5d7dc57029f97762915ea535` of the legacy AzeriteUI repository.
Source files: `AzeriteUI/front-end/media/`; layout reference:
`tinkertown/schematic-unitframes-legacy.lua` and `schematic-actionbars-legacy.lua`.
Copyright attribution: Daniel Troconis and Lars Norberg; see SOURCE-LICENSE.md.

The maintainer explicitly confirmed permission to add this alternative HUD.
The source license covers code and explicitly excludes artwork. These assets
are included under that separately obtained permission, not under the code's
MIT-style grant. This file grants no additional rights to the artwork.

Ten source textures are unmodified copies (including the rectangular power
fill used for health, `aura_border` for aura buttons and `state-grid` for the
combat icon). The absorb and heal-absorb files reuse the same original
rectangular fill so modern native prediction masks fit the same aperture.

Use `/go legacy` outside combat. `/go azerite` restores Azerite's saved layout.
This is a compact layout port using current AzeriteUI/oUF elements, not a
reinstallation of the old addon or its secure action-bar implementation.
