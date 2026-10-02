# Paladin development preview

Generated transparent artwork for the main AzeriteUI theme. The reference is the
maintainer's selected Ashbringer health casing and compact Judgment lion castbar,
with the existing AzeriteUI crystal silhouette, health fills and icon masks.

## Access

Enable Development Mode, reload, then use `/azpaladin on`. The command reloads
the UI outside combat. `/azpaladin off` restores the standard theme; `status`
reports the current gate. The preference is per character. SaiyaRatt is excluded.

## Texture contracts

- `health-case` and `lion-cast`: colored foreground casings, transparent openings.
  Registration uses measured source apertures in `Core/PaladinTheme.lua`.
- Revision 3 shortens their plain center runs instead of stretching the end
  ornaments to the native player meter aspect. Boss frames retain their native
  112x11 meter; that aspect differs slightly from the player's 385x40.
- `plate-case`: decorative material on the existing nameplate background layer.
- `portrait-case`, `action-ring`, `minimap-ring`, `crystal-holder`, `orb-case`:
  colored material artwork registered to the existing texture canvases.
- `seal`, `light-body`, `light-strands`, `orb-light`, `orb-strands`: neutral
  functional textures. Mana gets its warm color at runtime; strands stay white.
- `health-glow`, `crystal-holder-glow`, `orb-case-glow`: white alpha silhouettes
  for runtime threat tinting. They contain no gold pigment.
- `action-ring`, `utility-cog`, `compact-case`, `utility-edge`: restrained edits
  registered to the original action border, cog, compact casing and eight-cell
  tooltip atlas. Output dimensions and alpha channels match the originals exactly.
  Focus and target-of-target retain their original sizes, anchors and highlights.
- `minimap-ring`, `portrait-case`, `portrait-case-low`, `plate-case`, `seal`:
  simple cartoon-like edits using exact original dimensions and alpha. Portrait
  high/low variants retain separate original masks. Nameplate material occupies
  the native background, without a separate foreground casing. Holy Power uses dedicated aligned casing/fill canvases and a wider arc.
- The crystal holder uses the original 177px painted width on its 256px padded
  canvas; the detailed lion's extra height is retained without stretching.

The crystal's light clips to the native StatusBar texture. The orb uses LibOrb's
existing native clipping and rotating body layers, with a separate pulsing white
layer. No addon calculation of mana percentages is added. This is layered texture
animation, not a fluid simulation.

Mana uses Holy Light before the saved enhanced/class crystal color mode is
applied. Saved preferences are not changed, and resume when the preview is off.

## Rebuild and review

Run `python Tools/Build-PaladinAssets.py`, then `python Tools/Build-PaladinSheet.py`
from the addon root (Pillow required). Original generated PNGs and the exact
built-in image_gen prompt scripts are retained locally in
`Docs/Research_Assets/Paladin/Production/`. The final bar correction prompts
supersede the first bar designs. `manifest.json` records source/output hashes.
Revision 2 sources and built-in generation prompts are retained in
`Docs/Research_Assets/Paladin/Revision2/`. Run `python Tools/Build-PaladinComparison.py`
for the original-versus-revised geometry comparison.
Revision 3 sources and exact built-in image_gen prompts are in
`Docs/Research_Assets/Paladin/Revision3/`. `Build-PaladinSheet.py` now publishes
the complete matched-scale comparison from `Build-PaladinFullComparison.py`.
It accounts for every exported texture and labels newly added light layers.

The generated sheet shows actual textures and offline fill examples, not a WoW
screenshot. Source PNGs and internal docs are excluded from release packaging.

## Verification

`Tools/Harness/paladin_theme_harness.lua` exercises layout isolation, runtime
palette preservation, dev/profile gates, command behavior and clip ownership.
It includes the real namespace finalization and the player color resolver's
default/enhanced/class modes. The normal nameplate harness also passes with the
feature disabled.

**Live Retail and Forever verification remains required.** Check player, target,
boss and alternate-player portraits; health at full/partial/empty; absorbs and
threat; player casts and channels; the stacked nameplate pair and idle plates;
all five seals; crystal/orb at empty/partial/full mana; icon cooldowns/highlights;
the minimap, gear and options/menu borders. Verify scaling, Edit Mode and a
main-profile/SaiyaRatt round trip. Record BugSack errors and screenshots.

## Revision 4: assembled coverage

The package now contains 29 RGBA textures. Separate health-portrait and
health-wide casings fit 385x37 and 533x40 meters; critters retain their original
compact casing geometry. Their threat silhouettes follow the same dimensions.
Pet, party, raid, arena and mirror-timer casings share the restrained compact
material. Circular group portraits, vehicle exit, utility plates and the status
wheel now have matching registered material. Fourteen secondary exports have
pixel-identical original alpha channels and canvas sizes.

Player and alternate-player mana use the holy palette. During this preview,
Wrath and Winter Veil ice artwork is bypassed so it cannot force baked blue;
those saved choices resume when the preview is disabled. Other units retain
resource colors. Main health percentage and cast text have ornament clearance.

Revision4 contains retained generated sources, exact prompts, the exported
production layouts and both final comparison sheets. To regenerate assemblies:

    lua Tools/Harness/paladin_theme_harness.lua . Docs/Research_Assets/Paladin/Revision4/layouts.json
    python Tools/Build-PaladinAssembly.py

See Docs/Paladin Theme Coverage.md for coverage and the outstanding live battery.

## Revision 5: painted bounds and sacred seals

Current exports: 35 textures. Revision5 supersedes the earlier bar registration
and Holy Power treatment. Health casings now follow each original texture's
painted body, not its padded height; low/mid and small-boss variants are separate.
The remade lion castbar has symmetric pointed ends and a matching empty cavity.
Dedicated holy-case and holy-fill layers replace round Holy Power plates while
using a wider arc with 20% larger seals and preserving existing activation logic. The old seal
star export is retained for reference but is no longer assigned at runtime.

Build-PaladinSheet.py and Build-PaladinAssembly.py now publish Revision5. Export
layouts to Revision5/layouts.json with the harness before rebuilding assemblies.
Theme harness: 163 checks passed, offline only. See the Revision5 README and
Docs/Paladin Theme Coverage.md for /reload acceptance checks.

## Live screenshot follow-up: endpoints and seal size

The main player meter is now 373 pixels wide (12 fewer); target and alternate
portrait meters retain their widths. Main blade openings and threat outlines
are inset into the native angled fill. Pixel sampling found no uncovered
aperture pixels for cap, portrait, low/mid and world-boss variants. Holy Power
casings and fills are both 20% larger, on a wider arc. Current comparison sheets
were rebuilt from the updated layouts. These are offline results; /reload and
live scaling, resource changes and prediction checks remain required.
