# Warrior - Skyhold / the Valarjar (WIP)

Installed 2026-10-18: 77 byte-identical accepted textures from Assets_Draft/Warrior.
The main theme selector and /azwarrior now use these files. Runtime integration
is offline-verified; actual Retail/Forever rendering and combat are unverified.

## Use

1. /reload to load the new module.
2. /azwarrior on, or /az -> Themes -> Warrior (WIP). Selecting reloads the UI.
3. Choose Strom'kar, Warswords, Wrath Rivet or None for health. Cast Valarjar/None
   has independent size, offsets and reset controls on the same Themes page.
4. /azwarrior preview opens the existing synthetic bar tests for the active theme.
5. /azwarrior status reports selection; /azwarrior off returns to AzeriteUI.

Commands also accept /azwarrior endcap stromkar|warswords|wrath|none and
/azwarrior castendcap valarjar|none. A bare /azwarrior toggles the theme.
Settings are per character. Theme/placement changes are refused in combat.
Other AzeriteUI layout variants remain under their existing layout rules.

## Art and placement

28 native casing names resolve to this folder; functional fills, masks,
nameplate backing, minimap status rings and semantic icons remain shared.
There is no separate Warrior animation/effect; Lite+ effects remain available.
The bag uses the engine's existing AzeriteUI fallback identity.

Each health endcap uses the actual backdrop rectangle and its frozen measured
dip at default scale 1.3 (the exact accepted full-casing export, not an enlarged
square slot). All three options retain the full bare ending underneath. Health
and prediction stay below the rails/cap. Cast head uses the reviewed shared
48px slot at x=-8. Threat follows native visibility/colour, including complete
health ornaments and padded normal/ice/low crystal-plus-cradle silhouettes.
The source pack's whole-painting registration, geometry and texture bytes are
kept byte-identical between staging and installation; no saved frame position,
native fill or hit area is replaced.

## Live-feedback repair - 2026-10-18

Thirty textures revised: leather/rivet foregrounds survive health/prediction,
all twelve health caps fit within Druid's measured footprint, and the cast head
is centered and covers normal/protected sockets at 100%, X=0, Y=0. Forty-seven
other Warrior textures and all 818 unrelated protected files are unchanged.
Whole terminal masks and back casings remain intact. New paintings and exact
built-in image_gen prompts live in the research folder's Live-Repair-2026-10-18.

After /reload, reset health and cast placement with their existing Reset controls
under Themes. Your saved nudges are intentionally preserved; the old cast
140%, X=-2, Y=13 compensation remains until reset. Defaults now target
100%, X=0, Y=0. Do not move actionbars to accommodate the art.
Offline: 1541 export checks, 1166 integration checks and nine Lua harnesses pass.
Live /reload and client visual/combat confirmation are still required.

## Validate

python Tools/Install-WarriorAssets.py validates source acceptance and installs
only these accepted files. python Tools/Check-WarriorIntegration.py validates
installed hashes, all four frozen joins, load order and nine Elune Lua harnesses.
Integration evidence: Docs/Research_Assets/Warrior/Integration/acceptance.json.
The original production acceptance and rejected old cap fixtures remain separate.

Live checks still required after /reload on each client: theme selection and
return, None/all three choices, default/reset placement, mirrored targets and
all tiers, partial health/prediction, normal/protected casts, resource modes,
threat, Lite+, combat, Edit Mode, saved anchors and BugSack. Synthetic bar tests
and recording-widget harnesses do not establish live rendering/combat safety.

## Concept restoration - 2026-10-18

The shield-plaque health revision is superseded. Original Stromkar, Warswords
and Wrath fittings are restored with compact full-terminal mounting bodies.
Current sources, exact prompts, checks and complete None/on evidence are in
Docs/Research_Assets/EndcapConceptRepair-2026-10-18/. Other Warrior art, leather
bridges, cast fit, runtime geometry and saved settings are unchanged.
Live Retail/Forever confirmation is still pending.

## Approved quiet materials - 2026-10-20

Four main health rails and minimap use the approved quieter iron material.
Health alpha/bridges/terminals, caps and runtime percent placement remain intact.
The complete new minimap painting replaces the old extruded native-alpha halo;
viewport, centre, envelope and opening are checked separately. Reproduce with
Tools/Refine-WarriorMaterials.py. Current source/visual/acceptance evidence:
Docs/Research_Assets/Warrior/Material-Refinement-2026-10-20/. Live confirmation pending.
