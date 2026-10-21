# Class asset workflow

The maintainer-approved production sequence is documented locally in
`Docs/Theme Asset Production Workflow.md`. Read that, the Theme Asset Style Key,
the Theme Asset Fitting Checklist and the latest accepted concept before art.
Docs and source paintings are local-only under this repository's ignore policy.

Rules to carry into every future class pack:

1. Keep the approved class materials, resource-cap silhouette and weapon/relic
   motifs recognizable at gameplay size. Template geometry is a functional
   contract, not permission to reduce the class to a native recolour.
2. Measure actual layout rectangles, fills, glass, masks and cropped viewports.
   Inventory all native casings and deliberate shared functional/semantic art.
3. Generate one painting per job from native templates/guides, preserving exact
   prompts, inputs, whole originals and hashes. Do not enlarge concept-sheet
   cutouts or warp whole ornaments/portraits into a different shape.
4. Finish a complete bare health casing and dip. None and enabled use identical
   casing art. Health and prediction remain beneath removable foreground caps.
5. Use `ThemeHealthEndcaps.py` to register whole cap paintings on each tier's
   casing canvas. The intended toe is the single actual lowest point, within
   half a source pixel of the bare dip. Reject adjacent low blade tips, cut
   shoulders and coverage above 20 percent. Record normalized pivots; runtime
   uses the shared engine's aligned placement, mirrors and pivot scaling.
   **Toe alignment alone is never acceptance.** Freeze a mask of the entire
   casing termination BEFORE fitting: upper point, outer end and the complete
   descending dip, including its inboard slope/heel. Require zero exposed solid
   terminal pixels beyond one source-pixel contour antialiasing. A percentage
   score must not hide a long thin exposed rail. Keep the mask and bare casing
   hash locked; do not shrink the mask or cut the casing to make a cap pass.
   Source art must have an opaque mounting body covering that entire mask.
   Freeze an approved exterior footprint before fitting as a separate limit.
   Warrior uses Druid's measured union at each tier, translated to its own dip.
   Search only inside that bound; full-terminal coverage never permits growing
   a cap until it overwhelms the HUD. Repaint a compact body/heel if necessary.
   Protect explicit leather/rivet bridges in front of the fill. Check the exact
   raw painting survives there, the aperture stays clear elsewhere, and the
   combined cap/bridge occlusion stays below the 20-percent limit.
6. Run geometry checks, then inspect actual exported assemblies. Show complete
   bars at 1x/2x, None/all choices, native tiers, both sides, partial/full/empty
   health, prediction and custom scales. Fix viewport clipping rather than
   cropping the evidence. Inspect small rail seams/stripes and glass by eye.
   None/on pairs at BOTH 1x and 2x use a union viewport and the same rail origin;
   independently cropped images can conceal a fit or anchor error. A close-up
   of a cropped end cannot replace complete-bar evidence. Include a regression
   fixture whose toe fits but whose upper end/heel is exposed; it must fail.
   Keep numerical acceptance and a separate inspected visual-review record
   bound to the current asset-manifest hash; bind the review to image hashes.
   Packaging must reject missing/stale evidence or missing complete-bar pages.
   Cast checks project the painted head onto BOTH actual native casings at
   100%, X=0, Y=0. Check painted centering and the full left socket coverage;
   a 48px texture-frame assertion alone proves neither. Include None/on at
   1x/2x, plus rejected erased-strap, oversized-cap and low cast-head fixtures.
   Preserve user nudges and reset controls for the live default comparison.
7. Keep unintegrated packs in `Assets_Draft/`, sources/evidence under
   `Docs/Research_Assets/<Theme>/`, and a complete local handoff archive with
   sources, prompts, manifests, exports and reproduction instructions.
8. Report asset production, runtime integration, offline checks, live Retail
   and live Forever separately. Release authorization remains separate.

Scope correction (2026-10-18): Hunter, Mage and Paladin need default size/offset
corrections using maintainer screenshots/SavedVariables, NOT new artwork. Only
Warrior receives new concept endcaps. Preserve explicit saved overrides; Reset
restores the selected motif's defaults. Never infer repaint permission from a
fitting report. The earlier H/M/P painting experiments are rejected drafts.

Concept-repair gate (2026-10-18): lock each motif to its approved original
painting before editing. A class label or matching colours do not authorize a
new universal plate, shield plaque or repeated stacked mounting point. Compare
the original and complete exported bar at gameplay size as a separate identity
check. Prove one representative fit per affected theme before generating the
remaining choices. If targeted generation still misses the frozen mounting
edge, stop the generation batch and record the failed source and exposed-pixel
evidence; agree a precise editing method before spending more generation calls.
Never use a failed redesign as the next design authority. The repair currently
staged by `Repair-ConceptEndcaps.py` is incomplete and must not be installed or
described as an accepted replacement.

Warrior reference implementation (2026-10-18): `Repair-WarriorFit.py --build`,
`Check-WarriorAssets.py`, `Render-WarriorAssets.py`, and
`Repair-WarriorFit.py --review`; local brief/evidence in
`Docs/Research_Assets/Warrior/Live-Repair-2026-10-18/`. The earlier
`Build-WarriorAssets.py` is superseded and refuses to overwrite a revised pack.
`Install-WarriorAssets.py` and `Check-WarriorIntegration.py` validate the
installed `/azwarrior` / Themes integration. Live Retail/Forever remains separate.
`Package-WarriorAssets.py` creates the complete local source/export/evidence
archive and verifies ZIP CRC plus every exported texture hash.
