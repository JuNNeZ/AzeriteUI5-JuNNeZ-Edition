# Paladin — Ashbringer / Silver Hand

## Golden Light animation - 2026-10-15

Current direction: slow golden energy waves with continuous winding threads,
plus six independent floating/pulsing light spheres on a foreground layer.
`generated-sheet-waves.png` / `prompt-waves.txt` supply the wave atlas;
`generated-sphere.png` / `prompt-sphere.txt` supply the separate neutral sprite,
tinted golden at runtime. Both were made with built-in image_gen. Earlier
detailed/electrical and simple/cartoon source sheets and prompts remain for history.

`holy-energy.tga` is one shared 1024x1024 RGBA atlas for all specializations,
used inside both the crystal and mana orb. Its 64 frames form a 32-second
loop with adjacent-frame crossfade and additive blending. The existing Holy
light strength setting controls both; zero stops the playback callbacks.
`holy-sphere.tga` is a 64x64 RGBA sprite. Each of the six foreground spheres
has its own seeded path and pulse, on a separate 48-second drift period. Wave
wrap and mana updates retain sphere phase. Both layers share the native mask.
Native crystal/ice alpha and LibOrb's fill clip plus native circular alpha
bound the light without reading resource values. Casings, fill geometry,
resource colours and saved anchors are unchanged. Existing facet/orb pulses
remain underneath the new moving Light layer.

Rebuild: `python Tools/Build-PaladinLightAtlas.py`. Built-in image_gen source,
exact prompt, hashes and isolated full/half/low-fill previews are retained in
`Docs/Research_Assets/Paladin/HolyLight-2026-10-15/`. The exporter only resizes
the complete source sheet and sphere to runtime dimensions and converts to TGA.
The GIF preview spans 96 seconds so both periods wrap together continuously.
This effect has its own
builder and source manifest, separate from the casing rebuild below.
The preview omits casings and is not a live WoW screenshot. Retail and Forever
still need `/reload`, partial/empty mana, ice, strength, Lite+ switching,
combat and BugSack checks.

Approved 2026-10-14 from the combined concept and tooltip study. Ashbringer
health rails and separate sun-disc blade ends; Silver Hand silver/gold buttons,
portraits, compact casings, low cradle, orb glass and tooltip borders. A separate
closed-libram head joins the native player cast bar.

## Access

With the Paladin artwork theme active, `/az -> Unit Frames -> Player ->
Crystal/Orb Color Source` additionally offers **Light colored**. It colours both
mana fills warm gold (1, .84, .35), independently of the animated Light effect.
Default, Enhanced Colors and Class Color remain available. A saved Light choice
is dormant outside Paladin: native default crystal/orb colours return, and the
choice is retained for switching back. Light uses the neutral crystal surface
instead of baked-blue ice art, without rewriting the saved ice/seasonal choice;
another colour source restores that choice. No art geometry or anchors change.

The approved Light effect is available without Development Mode: `/az -> Themes`,
enable Lite+, then select Paladin for Crystal effect and/or Orb effect. Holy
light strength appears while either effect is selected and controls both layers.
Changes apply live outside combat; Lite+ off returns to the selected theme's own
effects. Casing and ornament controls stay with the theme that owns them.

Enable Development Mode, `/reload`, then select Paladin under `/az -> Themes`
or use `/azpaladin on` outside combat. `/azpaladin off` restores AzeriteUI;
`status` reports the gate; `preview` opens synthetic bar tests. Theme switching
reloads; health/cast ornament placement and light strength redraw live.

## Contract

All 34 casing variants use native filenames and canvas sizes. Thirty-two keep
byte-identical native alpha. The two crystal holders use the approved concept
silhouette, uniformly scaled within the original painted width (177px), as
requested after live review; their source aspect ratio is retained. No bar, text, portrait, resource, class-power, scale, texcoord or saved
anchor geometry is changed by the theme. The old 373px health width, enlarged
castbar, shifted text and widened Holy Power layout have been removed.

Functional fills/masks/glass/glows and semantic colours remain shared. The
fifth Holy Power diamond retains its native glyph/casing; four round plates
use Silver Hand material. Native resource colours and seasonal/ice choice are
preserved. Lite+ retains three neutral Holy Light effect textures.

Backdrops contain textured neutral empty surfaces. Separate `*-over` rails
follow the actual native backdrop and stay outside the fill contour. Relic
and libram use shared engine slots, changing only non-interactive artwork.
Compact/group/boss meters and critters have no weapon ornaments. The relic's
white halo follows native threat visibility and vertex colour. Native cast
shield remains; ordinary front lip follows native backdrop visibility.

The north ornament backs the existing compass N; its letter, rotation and
anchor remain native. Other themes/layouts have their separate gates.


## Concept holder rebuild - 2026-10-14

Supersedes the native-stencil crystal splits described below. Both crystal
holders now use one complete new painting based on the approved Resources-row
holder: two gold clamps, connected segmented silver base, dark outer bevel.
Uniform contain fitting preserves the source aspect and never exceeds the
original 177px painted width; no native alpha stencil chops the new shapes.
The holder's open alpha aperture is its foreground; the obsolete duplicate
backing is no longer created. Resource fill/colours/ice and all layout anchors
stay native. Core crystal facet light remains subtle. These two casings skip
the general palette grade to retain the new concept painting's material.
Sources, before files, fit records and approved-reference comparison are in
Rebuild-2026-10-14/Concept-Cradle. Offline checked; live confirmation owed.

## Rebuild and review

`python Tools/Build-PaladinDropIn.py --install`; the familiar
`Tools/Build-PaladinAssets.py` forwards to this exporter. Sources, exact
image_gen prompts, layouts, inventory, hashes and review pages are retained in
`Docs/Research_Assets/Paladin/Rebuild-2026-10-14`. Production paintings are
generated individually against native templates, except the literal HUD
crystal-holder cutout explicitly requested after the screenshot comparison.

Run `python Tools/Check-ThemeAssetStyle.py Paladin` and
`python Tools/Check-PaladinDropIn.py` to verify the installed artwork.
Run `python Tools/Build-PaladinDropInReview.py` to rebuild the review sheets.
60 runtime textures: 34 casings, two crystal foreground lips, ten cycle variants,
seven front rails, three ornaments, one white relic halo and three retained
neutral effect layers. No geometry failures or missing casing variants.

Remaining look advice concerns six native soft-alpha fringes and point-plate
inner shading, cradle lighting and the intentionally brighter sacred endcap.
Functional alpha/glass are preserved rather than reshaped.
Historical Revision2–5 files describe retired art. Offline checks do not prove
live fit; see `Docs/Paladin Theme Coverage.md` for the Retail/Forever battery.

## Scoped concept correction — 2026-10-14

The two crystal cradles are repainted as clearer Silver Hand silver/gold.
Four main health casing variants retain their paintings with stronger concept
material lighting. A new opaque Ashbringer attachment shoulder overlaps the
bar termination inside the original ornament canvas and shared anchor. Its
texture draws on OVERLAY above the rails, native health and prediction.
The Paladin bag icon comes from `Assets/ThemeBagIcons/paladin.tga`; the other
four selectable themes have independent icons in that folder. Tooltips,
buttons, cast heads, orb casings and layouts are outside this correction.

## Small-bar fitting and crystal layers — 2026-10-14

After live screenshot review, cast_back, cast_back_spiked, cast_back_wooden
and both hp_critter_case variants are repainted and registered by their inner
lip/fill footprint. Matching the outer alpha alone was insufficient. Native
bar dimensions, contour textures, prediction and saved positions are unchanged.
Small-bar foreground clearance covers the actual cast/boss/party/raid/pet/
focus/ToT/arena/mirror families rather than only the player cast.

Crystal cradles now have a full backing below the fill and separate -front
lips above it. The lifted case no longer carries opaque grey backing over the
crystal. The split follows the existing case rectangle and hides for Mage
Lite+ or inactive Paladin. Native crystal colours, ice, fills and anchors stay
shared. Five fresh built-in image_gen sources/prompts, masks and review:
Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Fill-Correction.
Retail/Forever rendering after reload still requires live confirmation.

## Palette correction — 2026-10-14

Buttons (three shapes), both crystal cradles and all health casing families now
share a colour-only metal finish. PaladinPalette.py normalizes silver midtones
and gold warmth while retaining each painting's luminance variation and polished
highlights. Finishing runs after registration/lighting and before restoring
functional pixels; it does not generate new artwork or change alpha/geometry.
Fourteen casing variants and nine derived fronts are affected. Original source
PNGs, native glass, fill recesses, soft shadows, other artwork and runtime Lua
remain unchanged. Before/after proof: python Tools/Check-PaladinPalette.py;
review and original TGAs: Rebuild-2026-10-14/Palette-Correction.

Minimap follow-up: the ring, one-/two-bar status casings and north ornament now
share that finish too. This adds four RGB-only changes; no map mask, compass
letter/rotation, XP/reputation fill, alpha or runtime layout is changed.

## Five crystal casings - live comparison

After /reload, use /az -> Themes -> Paladin -> Next crystal casing (1/5).
The button cycles 1-5, wraps to 1 and saves paladinCrystalCase per character.
It redraws tracked player/alternate/preview casing textures without reloading;
resource size, fill, colour and saved anchors are unchanged. Use out of combat.
With a Mage Lite+ crystal, the button is disabled because that effect owns its case.
Five new source paintings are exported at both native tiers (ten additional TGAs).
Each keeps its source aspect and stays inside the original 177px painted width.
Their inner rail is seated against the native crystal bottom to avoid a gap.
Review: Rebuild-2026-10-14/CradleVariants/Assemblies.png; sources: Sources/CradleVariants.

## Measured concept cutout - 2026-10-14

Candidate 1 now uses the literal HUD holder cut from the approved concept,
with unchanged RGB and a traced transparent cavity, as explicitly requested.
It is registered to the native crystal by the concept crystal landmarks at
one uniform rendered scale. The painted result is 134.6x53.6 rendered pixels
at the screenshot's native scale, inside the original 136.9px width limit;
the previous shallow candidate was approximately 132x33 in the live screenshot.
No native resource geometry, anchors or colours change. Existing shallow
choices default once to measured candidate 1 after /reload; explicit later
cycling choices remain per-character (paladinCrystalCaseRevision = 2).
Compare all four original screenshots with concept and the separately labelled
reconstruction: Rebuild-2026-10-14/Measured-Cradle/Comparison.png. Rebuild the
cutout/comparison with Tools/Build-PaladinCrystalFitReview.py. Live acceptance
of this new cutout remains owed.

## Approved crystal retained / literal concept frames - 2026-10-15

The maintainer accepted the measured crystal holder live. All 14 crystal/casing
TGAs remain byte-identical to approved-crystal-lock.json. The approved follow-up
uses literal concept rails, portrait, relic and libram via PaladinConceptFrames.py.
Covered rail/tip sections are reconstructed from unobscured concept samples, with
no baked relic or book. Functional meter geometry and native backdrop/portrait
glass alpha remain intact; separate front rails have native fill clearance.
Health relic defaults to 130% of the shared slot to match concept height; saved
sizes are respected. It draws above native healing and absorb prediction.

Health Endcap -> None and Cast Bar -> Endcap -> None are independent controls
under /az -> Themes -> Paladin. Changes apply out of combat without reload.
Concept-Frames/Comparison.png is an offline reconstruction, including ornaments
off, not a new WoW screenshot. New frame art still needs live /reload review.

## Current correction: OG contour and one approved holder - 2026-10-15

Supersedes the earlier five-choice and rectangular-front sections. Retired
crystal choices and cycle control are removed. Only the approved canonical
holder remains; its two tier textures and foreground aliases retain their
exact approved hashes. Historical research candidates are not shipped or selected.

All four long health casings now use OG foreground contour/alpha, including
the lower endpoint dip, with concept silver/gold wrapped around that contour.
Native fill/prediction, frame sizes, anchors and mirroring are unchanged.
Endcaps remain separate, with health/prediction below. Endcap None exposes the
complete OG-shaped casing on player and target. Cast, portrait, endcap and
Paladin Light artwork are outside this correction.

Review: Research_Assets/Paladin/Rebuild-2026-10-14/Contour-Repair/Comparison.png
(relative to Docs). Installed-art checks catch the previous flat rectangle.
After /reload, check endcap None on both sides, then restore it; verify native
dip at full/partial/empty health. This repair remains offline-verified.

## HD signature art and threat fitting - 2026-10-15

Supersedes the small concept-cutout endcap/portrait sources. Two 1254x1254
built-in image_gen paintings add crisp faceted silver/gold material; endcap
has an opaque stepped lower-left socket. Native export canvases, source
aspect for the relic, saved ornament placement, native portrait alpha and
glass remain fixed. Only relic/portrait art changes; the approved crystal,
OG health dip, fill/prediction and Light artwork remain byte-identical.

Threat halos derive from final silhouettes, anchored to actual casing/border
regions. The relic halo stays behind the entire health assembly, separately
hidden by None and synchronized to native show/colour/alpha updates. Native
threat logic is unchanged. New checks reject mismatched anchors, interior
halo placement and disabled-halo resurrection. Rendering remains offline-only.

Review and exact built-in prompts: Docs/Research_Assets/Paladin/Rebuild-2026-10-14/
HD-Repair (paths from repository root). Production sources: Sources/HD there.
After /reload, check actual threat on/off, endcap None/restore, join, model
aperture, user scales/anchors and combat on Retail and Forever.


## 2026-10-15 - Intact HD portrait and matching health terminals (offline correction)

Supersedes the radial portrait export and tiny concept health crops described
above. The approved portrait attachment is now the literal locked source,
uniformly contained in the native canvas: original painted height, source
aspect, no radial remap or native metal stencil. Its narrower natural width
is intentional; the saved frame rectangle and live model stay unchanged.
Native glass is copied only into its actual transparent aperture.

A new 2169x725 template-guided built-in image_gen painting supplies all four
health variants. One uniform material scale preserves finished end facets;
plain runs are shortened or stud sections inserted for native bar lengths.
Normal/boss retain three/five studs. Native fill and prediction are untouched.
A complete closed dipped termination is shown with Endcap None. Enabling the
separate foreground relic selects its mounting shoulder and matching halo,
so the old lower tip does not protrude through the fitting. Both sides mirror
as a unit; runtime size, offset, layer order and saved settings are retained.

Four approved crystal/cradle TGAs, endcap painting, cast art, Light/effect art
and every unrelated existing texture remain byte-identical to this iteration's
baseline. Sixteen existing health/portrait TGAs change; twelve matching capped
back/front/glow textures are added. No version/release action in this repair.

Review, exact built-in prompts, approved portrait lock and hash inventory:
Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Whole-Asset-Repair/.
Assembly.png uses actual exports and native layouts at empty/partial/full,
normal/novice/boss, both terminals and threat. Source-to-export.png compares
the intact approved border with the exported sprite at the same height.
These are offline reconstructions, not screenshots of the live WoW client.

After /reload, compare player/target Endcap None and Ashbringer, including
health/prediction underneath, dipped bare ending, portrait model, actual threat,
UI scale, saved positions and combat/BugSack. Retail and Forever still need
visual acceptance. Older exact-native-alpha passes did not prove fidelity.


## Protected player castbar spike - 2026-10-15

The protected casing now combines the unchanged ordinary rails with an intact
HD Paladin stud, replacing the old shadow-only spike. Its separate front layer
follows Shield at the native rectangle; ordinary backdrop visibility selects
the matching shield state within Paladin only. Fill, text, colour logic and
optional libram remain unchanged. Both protected TGAs change; all other 68
textures retain their hashes. This leaves 25 native casing alphas exact, with
the painted cast spike using its own alpha within native bounds. Offline
comparison/tests: Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Cast-Spike-Repair.
After /reload, validate ordinary/protected casts and channels, state changes,
libram None/restore and BugSack in Retail/Forever. Live acceptance remains owed.


## HD player castbar and Silver Hand libram - 2026-10-15 (offline)

The ordinary and protected player cast casings now use a dedicated HD painting,
exported at 1024x512 (4x density) for both back and front layers. This is a
scoped canvas-density exception: normalized native openings, draw rectangles,
fill, text, anchors and optional book placement are unchanged. Straight rail
runs are shortened at one material scale; finished tips remain intact. The
protected variant keeps its separate painted stud and matching foreground.

The libram is newly painted in HD, with a silver armored fist and gold sunburst
representing the Order of the Silver Hand embossed between its gold straps.
Its export remains 256x256 in the existing shared slot. Five existing TGAs
change; all other 65 Paladin TGAs, including the approved crystal, health,
portrait and wooden compact casting case, retain their pre-task hashes.

Installed asset checks pass, style has zero geometry failures (21 advisory look
notes); Paladin/preview/effects harnesses pass 2209/550/53 checks. Old 256x128
cast pair is rejected by the HD density guard. Sources, generation prompts,
actual-export comparison and hash evidence are retained in
Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Cast-HD-Repair/.

Still owed in Retail and Forever: /reload, ordinary/protected casts and channels,
transitions, libram None/restore, scaled and moved layouts, text/fill and BugSack.
The comparison is an offline reconstruction; no live client confirmation.
