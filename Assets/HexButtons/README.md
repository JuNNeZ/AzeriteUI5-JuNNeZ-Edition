# Original Hex buttons - common border thickness

Select /az -> Action Bars -> Action Bar N -> Button Shape -> Hex and reload.
Pet/stance use their proportional sizes; extra/zone use Extra Button Shape.
Native cells, saved frame anchors, bar scale and secure actions are unchanged.

## Current artwork and geometry

Eight original paintings now follow one shared point-up Hex guide: Stock,
Hunter, Mage, Paladin, Druid, Warrior, Rogue and Shaman. Their metal, wood,
obsidian, bark/vines, leather, brass and copper identities remain distinct.
They are purpose-painted action-button rims, replacing the former portrait
reuse that had different opening sizes and rail thicknesses.

Sources, exact prompts, input roles and hashes are retained locally in
Assets_Draft/HexButtons-Uniform-2026-11-06. Built-in image_gen produced one
painting per theme, using our mathematical geometry guide / original Hex
master and our existing theme material references. Masque art is NOT an input
and no Masque pixels ship. Its border is only a read-only size measurement
reference, approx10-12px radial thickness at our96px draw size.

Every output is a whole-source uniform resize and translation to256x256 with
188px target solid height. Original source alpha/facets survive; no common
alpha stencil, aperture erasure, edge propagation, recolour or nonuniform
stretch. The source replay checker and negative fixtures enforce this.

Current measurements at96px draw size: all solid heights70.125px; widths
58.5-60.375px. Rails approx9-10px on flat directions and10-12px at corners.
Maximum corresponding-ray thickness spread is1.22px between theme paintings;
this is a shared construction with contour/facet tolerance, NOT pixel-identical
alpha. Source art is retained intact rather than stencilled to force equality.
No existing original class/HUD painting was overwritten.

## Runtime and tests

All themes use the same96px border/glow rectangle and50px icon at64px cell
size. The icon correction is retained: the former63px rectangle hid too much
icon detail beneath the rim. Masks, cooldown, hover/proc and assisted behavior
are unchanged. Stock/Rogue/Shaman inherit native grey tint; other themes retain
their native action-button tint. No blanket metal-reflection dimming.

Reproduce:
- python Tools/Build-HexButtonAssets.py
- python Tools/Check-HexButtonAssets.py
- python Tools/Render-HexButtonComparison.py

HexButtonGeometry.py measures12 rays (flats and corners), opening, outer bounds
and inter-theme thickness spread. Check-HexButtonAssets verifies8 whole-source
RGBA replays,17 output hashes/uncompressed TGA formats, source/prompt/reference
hashes, default cell bounds and6 negative controls: erased paint, changed RGB,
and four real rejected portrait-based variants. Lua5.1 shape/theme572 and
proc/assisted456 checks pass. No release/version/commit/push is claimed.

Source/research folders are local-only under repo ignore rules; retain them
with release records. Runtime exports and provenance are under Assets.

## Review and live status

Complete reopened-TGA rows at1x and pairs at2x, actual-Lua-config comparisons,
uniform-thickness-review.png and per-ray measurements are under
Docs/Research_Assets/HexButtons. Images use synthetic icons. Offline review is
bound to the current manifest/image hashes, separate from maintainer approval.
Live owed on Retail/Forever: /reload, every theme, real icons and label edges,
custom padding/scales/positions, pet/stance/extra, cooldowns/charges, hover/proc,
combat, Edit Mode and BugSack. No live or100% tonal/pixel-identity claim.
