# Druid - Roots beneath the Moon (WIP)

## Persistent crystal magic (current Moonvein/Dreamsap/Wildheart, 2026-10-16)

The native resource fill/body still drops. Magic now has a full-silhouette
ambient layer at 18% emission plus a second native-fill-clipped layer at 82%.
Both use the same sample/phase and masks: full resource sums to the former
intensity, while empty resource retains a faint animated magical imprint.
The ambient layer never receives the coloured body/fill. No resource values,
fill coordinates/heights or percentages are read to achieve this distinction.
The animation owner is a full-size child of the power widget; its ambient
child stays outside the fill clip, and the bright energy remains inside it.
All components hide/clear together; strength 0 removes both light layers.

This applies to the three new Lite+ materials, not the original Druid Dreamlight
default. Roots, native fill, saved anchors, palettes and activity motion stay
fixed. No new texture bytes. Cost rises to five frames, two masks and 35 textures
per reused overlay (previously two frames/18 textures). Client cost unmeasured.

Before/after GIFs at native 196px size: Docs/Research_Assets/Druid/
Wildheart-2026-10-16/Persistent-v1/<key>/<key>-persistent-comparison.gif.
Columns: 100/50/10/0%; rows: earlier clipped magic / new persistent magic.
Same installed assets, palette and real Lua samples drive both rows; offline
BLEND/ADD approximation, not client footage. Full-fill rows agree within one
RGB rounding step; the old empty crystal is static and the new one animates.
Reproduce with the harness samples command into Persistent-v1/<key>, then
python Tools/Render-WildheartDemo.py --persistent-compare --flavour <key>.

Offline harness checks full-height animation ownership, separate ambient/bright
parents, native body clip, silhouette masks, complementary intensity, identical
phase, both ADD groups above the body, cleanup, strength 0 and seven rejected
mutations. Retail/Forever live
/reload validation still owed: all three choices, normal/ice/alternate,
0/10/50/100% fill, readability, foreground ordering, hide/show and effect
switches, combat/mounted/flying, start/stop, taint/errors and performance.
Earlier preview folders below describe the retained clipped-only iterations.

## Moonvein / Dreamsap / Wildheart comparison (2026-10-16)

Three independent Lite+ crystal choices now share the existing bounded overlay:
- Moonvein: blue-violet facets, undulating silver-white ribbons and tiny orbiting
  starlights. No root veins, branch pulses or seed core.
- Dreamsap: darker jade, slow vertical golden streams and rising translucent
  globules using the shared native orb2 sprite. No root veins or seed core.
- Wildheart: the existing dynamic root-vein/seed-core material remains available.

Each choice has its own Energy strength, saved per character. Existing
wildheartStrength remains compatible; moonveinStrength/dreamsapStrength are
independent sparse settings. All share combat/mounted/flying intensity and
start/stop impulses, normal/ice native mask, cleanup and fixed root-cap geometry.
Switching flavours reuses the same frames and changes textures/palette/motion;
hidden branch/seed layers are zeroed immediately. Druid's default stays Dreamlight.
All art is shared: these two choices add zero texture bytes or atlas pages.

Comparison: Docs/Research_Assets/Druid/Wildheart-2026-10-16/Flavours-v1/
druid-three-flavours.gif. Columns are Moonvein/Dreamsap/Wildheart; rows show
quiet 100% and active 50% fill. Individual Moonvein/Dreamsap GIFs also show
0/50/100% and both states. Installed assets, palettes and animation samples
come from the actual Lua module; all previews are offline blend approximations.

Reproduce: wildheart_crystal_harness.lua . samples
<Flavours-v1>/<key>/lua-samples.json <key>, then
python Tools/Render-WildheartDemo.py --compare (or --flavour <key>).
Offline tests cover all three choices, mask/phase/frame reuse, independent
strength, distinct motion, UV/particle bounds and hiding/restoring root layers.
After /reload, choose each under Themes -> Lite+ -> Crystal effect; test
normal/ice/alternate, empty/partial/full, hiding and effect switches, combat,
movement, mount/dismount and flight/landing on Retail and Forever. Inspect
brightness, actual mask blending, taint/errors and cost in client; still owed.

## Wildheart crystal (additional Lite+ effect, 2026-10-16)

After /reload: /az -> Themes -> Lite+ -> Crystal effect -> Wildheart (WIP).
Jade facets, gold branching veins, breathing seed core, six travelling motes
and a faint silver-blue Elune reflection. Strength blends this own-colour
material over the ordinary crystal; 0 restores the ordinary appearance.
The existing Druid Dreamlight remains the theme default. Roots are unchanged.

Core/WildheartCrystal.lua draws using native CreateTexture, AddMaskTexture,
SetTexCoord, SetPoint, SetAlpha and OnUpdate. The native StatusBar texture top
anchors a clipping frame; no resource values or fill geometry are read.
Combat, mounted and flying share activity 1; moving .6, idle .22, eased between
states. Updates cap at 30Hz; optional state queries at 4Hz. Hidden/cleared
effects unregister events and stop updates. Settings changes remain OOC.
Dynamic v2 adds two counter-circulating mist layers using eight-coordinate UVs,
six curved branch pulses intersected with the native AND vein masks, and six
returning/orbiting motes. The core drifts slightly. Movement starts/stops add
opposite impulses which settle; activity eases circulation from normal speed
to double speed in combat/mounted/flying without resetting phase. These are
texture effects, not fluid simulation or deforming the approved root casing.
Dynamic v2 used two frames, two masks and 18 textures. The current persistent
version adds the ambient group as described above, all reused on refresh.

One new neutral 512x512 TGA adds 1,048,620 bytes (about 1 MiB) of art storage.
Dreamlight and the Paladin sphere are shared. Client memory/CPU/GPU cost is
unmeasured. Rebuild with python Tools/Build-Wildheart.py; its separate manifest
does not replace the main Druid casing manifest.

Offline dynamic demo:
Docs/Research_Assets/Druid/Wildheart-2026-10-16/Dynamic-v2/wildheart-dynamic.gif.
Earlier wildheart-demo.gif is retained as the initial pulse-only comparison.
Actual installed TGA exports and samples from the real Lua Sample function;
Pillow approximates WoW blending. This is not a live WoW recording. Reproduce
using the family export/render commands above. Dynamic-v2 is the retained
historical Wildheart preview. Source/prompt retained in its parent folder.

Offline tests cover clipping anchors/masks, state transitions, combat ticking,
cleanup, ice refresh, strength, loop closure, curved pulse travel, UV bounds,
movement impulses, speed changes, options Retail/Forever and five rejected
mutations. The GIF shows steady quiet/active loops; start/stop impulses are
exercised in the Lua harness and still need live visual assessment.
Live Retail/Forever checks remain: /reload, normal/ice and
alternate crystal, 0/1/50/100% fill, moving/stopping, combat, mount/dismount,
flight/landing, visibility hiding and Lite+ switches. Judge clipping softness,
text/foreground ordering, brightness, errors/taint and performance in client.
No native geometry, cap, saved anchors or release version changed.

Select `/az -> Themes -> Druid (WIP)`. The approved moss, vines, aged bronze,
dark bark and Elune concept supplies the native casing replacements, antler
health terminal, lunar cast head, compass leaf and two-layer root crystal cap.
The existing crystal lies between the back roots and foreground roots.
Native frame dimensions, saved anchors, fill apertures and prediction stay intact.
Four contracts intentionally retain shared native art; see manifest.json.

Moonwell replaces BOTH native LibOrb fill textures with neutral water caustics,
using the same SetStatusBarTexture route as Hunter's hexagons. LibOrb supplies
counter-rotation/crossfade; two masked reflections add slow blue/green motion
inside its native resource clip. The water retains the exact native orb2 alpha.
Resource colour remains controlled by the existing Crystal/Orb Color Source.
Dreamlight adds masked silver/green wisps inside the crystal's native fill clip.
Animation uses elapsed time only and never reads health, power or percentages.

Both effects are also selectable as Druid under Lite+ on other themes, with
independent crystal/orb strength. Switching effects removes old callbacks;
zero orb strength returns fill ownership to Player.lua. Lite+ keeps the selected
theme's casing and bag. Druid has its own bark/moss/bronze backpack in
Assets/ThemeBagIcons/druid.tga; all six selectable themes now have a variant.

Rebuild: python Tools/Build-DruidRuntime.py (after Build-DruidArt.py).
Generated HD sources/prompts: Docs/Research_Assets/Druid/HD.
Effect sources/prompts: Docs/Research_Assets/Druid/Effects/generation.json.
Bag source/prompts: Docs/Research_Assets/ThemeBagIcons-2026-10-14/Sources.
Offline preview: Docs/Research_Assets/Druid/Effects/Moonwell-review.png.

Validation: druid_theme_harness.lua (including mutations), theme effects/engine,
bag button, Legacy, real options Retail/Forever and Lua syntax. Staging geometry
mutations reject resizing, opaque health apertures and covered crystal openings.
Check-ThemeAssetStyle.py reports zero geometry failures; brightness notes need
visual client assessment. These checks are not live-client confirmation.

After /reload on Retail and Forever: select Druid; inspect all health tiers,
mirrored target/prediction, crystal/orb at 0/50/100%, protected casts, threat,
compass, bag click/drop/count/hover. Toggle Lite+ Druid/Hunter/Paladin/none and
strength 0/50/100%, including ice crystal, alternate player and profile reload.
Confirm no roots obscure the resource and no glow remains above an empty fill.
No release/version change was requested.

## Moonwell+ (reactive Lite+ orb, WIP)

After /reload: /az -> Themes -> Lite+ -> Orb effect -> Moonwell+ (WIP).
This is an additional orb effect, not a new full casing theme. Plain Druid
Moonwell and all existing theme/effect defaults remain available. It has its
own Energy strength (0 restores the ordinary native material).

Core/MoonwellSlosh.lua uses 32 thin clipped columns and the existing neutral
water texture, native circle mask and WHITE8X8 moonlit rim. No new image files
or atlases: extra art storage is zero bytes. There are 65 frames, 32 masks and
64 textures per constructed orb; client CPU/GPU/memory cost is unmeasured.
Animation is capped at 30 updates/second; optional state queries at 4/second.
Columns are reused; events and updates stop on clear and parent hide. Colour
is forwarded from the native orb resolver. Native orb size and anchors stay put.

Quiet target .22; moving .6; combat OR mounted OR flying all use target 1.
Transitions ease; movement start/stop adds a decaying opposite impulse.
Movement/combat events and capability/secret-guarded player state queries own
only cosmetic activity, never saved settings or resource calculations.

First implementation is conservative: troughs deform the water BELOW its
native horizontal fill edge. No crest extends above it. This differs from the
symmetric GIF target and slightly lowers apparent water level, but retains the
native empty-fill clipping instead of guessing secret mana/percentage values.
It is a visual experiment, not a fluid simulation. Near-empty clipping,
32-column seams, silhouette mask softness, full fill and combat anchor writes
must be judged in the actual client; offline mocks do not prove WoW rendering.

Offline: lua Tools/Harness/moonwell_slosh_harness.lua . mutations
checks real effect/dispatcher anchors, no resource reads, events, state fallback,
combat ticking, mounted/flying equivalence, cleanup, colour and four mutants.
Real options tests include the actual dropdown label and strength closures on
Retail and Forever. No version/release bump.

Live battery (Retail + Forever): select Moonwell+ OOC, test standing/start/stop,
enter/leave combat, mount/dismount and flight/landing (including Druid flight
form where available). Check 0/1/25/50/80/100% resource and normal colour modes,
strength 0/50/100%, alternate player, hidden/explorer visibility, then switch to
Druid/Hunter/Paladin/none and toggle Lite+ off. Verify no residue/flat fill,
BugSack/taint errors or noticeable FPS cost. Mounted/flying should match combat
whether moving or stationary. Keep the earlier crystal fitting issue separate.

## Crystal root fit/material correction - 2026-10-16

Live screenshot showed a cap/material mismatch. New source was edited through
built-in image_gen using the old cap, native crystal silhouette and current
health casing as references. Muted bark/bronze/olive and broader painted detail
replace shiny fine grain; the cavity follows the full native faceted crystal.
Old source retained in Docs/Research_Assets/Druid/Crystal-Fit-2026-10-16.

Root back/front and assembly glow are now 256x256 at the unchanged 196px rect
(1.31 texels/UI unit; health casing 1024/716 = 1.43), instead of 1024 at 196.
HD source remains 1280px. Three textures save 11.25 MiB uncompressed.
Foreground coverage 6.07% (previous 8.34%), with exact reconstructed whole art.
Native fill, anchors, layer order, effects, other artwork and palettes unchanged.
The first GIF used a wrong legacy crop; live screenshot confirms full canvas.
Preview inputs are corrected; older GIFs remain historical pre-fix snapshots.

Offline: Check-DruidArt geometry/layer/hash checks and four mutants pass,
including a new rejection of legacy-cropped fill guides. Druid Lua harness and
orb-glass check pass. After /reload verify the revised roots hug the crystal
at 0/50/100%, including normal/ice and alternate player, and match health
casings at the same UI scale. Recheck threat glow. Live confirmation owed.
