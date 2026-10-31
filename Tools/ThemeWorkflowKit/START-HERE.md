# AzeriteUI theme workflow kit — Mesph

**2026-10-29 correction:** Read `Docs/Theme Source Integrity.md` before exporting.
Whole source paintings must survive declared uniform fitting with their own
alpha. No native silhouette stencil, RGB extension or fill-mask paint erasure.
The default draft checker requires source proof. Historical geometry examples
can use `--geometry-only`, which never authorizes installation. Production
requires hash-bound source, numeric, maintainer visual and representative live
evidence; retained rejected Rogue fixtures must fail the shared regression suite.

Prepared 2026-10-27 for making themes with the same production and review workflow
used by JuNNeZ. Start here, then give `AI-START-PROMPT.md` to your coding assistant.

This is an art/workflow workspace, not an installable addon. Extract it into a
separate working folder. Do not extract over a live AddOns folder. The included
Lua/XML files are integration references; testing a selectable theme requires a
matching complete AzeriteUI checkout and a WoW client. No AI subscription, image
generator, API keys or machine-specific MCP configuration is bundled.

## 1. Read in this order

1. This guide, especially the corrections below.
2. `Tools/ThemeAssetWorkflow.md`.
3. `Docs/Theme Asset Production Workflow.md`.
4. `Docs/Theme Asset Style Key.md` and `Docs/Theme Asset Fitting Checklist.md`.
5. `Docs/Theme Concept Sheet Guide.md`.
6. `Core/ThemeEngine.lua` and `Core/WarriorTheme.lua` for implementation patterns.

The historical documents remain intact. Their dated corrections take precedence
over older paragraphs. In particular:

- The engine exists: use `Core/ThemeEngine.lua`. The style key's older rule 10
  calling it planned is historical. `Docs/Theme Engine Plan.md` also contains
  unimplemented proposals; do not treat proposed paths, slash commands or UI as API.
- New health ornaments use each native casing's full canvas (currently 1024x256
  for the four long-bar tiers), measured pivots and
  `ThemeEngine:PlaceAlignedHealthEndcap` through the existing styling helpers.
  The older square health slot is superseded. Cast and badge slots are separate.
- An ornament study can start square, but its production health export must use
  that full casing canvas. Never enlarge tiny concept-sheet cutouts into textures.
- Historical exceptions for Paladin or a specifically approved exposed-pixel mask
  are not permission to apply those exceptions to a new theme. Use the default
  zero-exposed-terminal contract unless the maintainer explicitly approves otherwise.
- Generated candidates and example exports are reference material. Their inclusion
  in this kit is not visual approval of a new theme or current live-client proof.

## 2. Set up the tools

Use Python 3.10+ (the kit was checked with Python 3.11), Pillow and NumPy. On Windows,
from the extracted folder:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
python Verify-Package.py
.\.venv\Scripts\python.exe Tools/Export-ThemeGeometry.py
.\.venv\Scripts\python.exe Tools/Build-ThemeConceptBase.py
```

The last two commands regenerate measured templates and the concept board from
the bundled native art and historical original-layout export. They write only to
this extracted workspace. The concept builder uses Windows' Georgia font at
`C:/Windows/Fonts/georgia.ttf`; on another OS change its `FONT` constant to a local
TrueType font. Already-rendered PNGs are included so you can start without Python.

After regeneration the original package hashes may differ: `Verify-Package.py`
checks the delivered snapshot, not your subsequent edits. Run it before editing.

Templates preserve the historical measurement baseline. Before fitting a new
theme for another addon revision, compare the included `Layouts/` and actual unit
frame drawing code with your target checkout. Canvas size alone is insufficient.

## 3. Build a theme in reviewable stages

1. **Brief and inventory.** Copy `Templates/BRIEF.md` into
   `Docs/Research_Assets/<Theme>/brief.md`. Copy the inventory CSV and record every
   native texture as replaced, deliberately shared, or not applicable with a reason.
   Decide materials, joinery, class motifs and any proposed set piece. Agree the
   concept and scope with the maintainer before generating the full suite.
2. **Concept.** Use `Docs/Research_Assets/Templates/concept-base.png` and its guide.
   Study separate ornaments; edit the measured board instead of inventing a HUD.
   Run the overlay command below, compare at gameplay size, and record approval
   with the concept file's SHA-256. Approval of a concept is separate from approval
   of exported art.
3. **One representative assembly.** Generate a whole source painting for each job
   using the matching native PNG and guide. Save exact prompt, actual input files,
   original output, hashes and editing history using the provenance template.
   Finish one complete health assembly, including its cap, before batch production.
   Stop after a targeted retry still misses the frozen mounting edge; resolve the
   editing method with the maintainer before further generation.
4. **Export.** Work under `Assets_Draft/<Theme>/`. Write a theme-specific builder
   using the included helpers; no universal class-art generator is supplied.
   Keep back/fill/front layers separate, native glass intact and semantic fills
   neutral. Retain whole paintings and uniformly fit ornaments. Never fix a bad
   export by moving runtime frames or changing saved anchors.
5. **Geometry and visual review.** Run the checks below, then render the actual
   exported TGAs on measured runtime rectangles with native fills. Review complete
   None/on bars at 1x and 2x, all choices/tiers, both sides, 0/50/100% health,
   prediction, absorbs and custom scales. Keep the same rail origin and union
   viewport in comparisons. Check class identity against the approved concept.
6. **Handoff.** Return sources, prompts/inputs, reproducible builder/checker/renderer,
   inventory, draft TGAs, manifest, locked masks and review pages. Bind numeric
   results and a separate visual-review record to the export-manifest hash; bind
   image review to the actual image hashes. Reject missing/stale evidence.
7. **Integration and client tests.** In a complete checkout, integrate through
   the engine, module load order, theme selection and localization using existing
   patterns. Move only approved exports to `Assets/<Theme>/`. Test `/reload`,
   theme switching, independent health/cast None, saved anchors/nudges, custom
   scales, combat, Edit Mode, threat and BugSack on Retail and Forever separately.
   Explicitly reset old nudges for default-fit tests, preserving saved overrides
   in normal use. Release/version changes require separate authorization.

```powershell
.\.venv\Scripts\python.exe Tools/Build-ThemeConceptBase.py --overlay "Docs/Research_Assets/MyTheme/concept.png"
.\.venv\Scripts\python.exe Tools/Check-ThemeAssetStyle.py ../Assets_Draft/MyTheme
.\.venv\Scripts\python.exe Tools/Check-ThemeDraft.py Assets_Draft/MyTheme
```

Replace `MyTheme` with your folder name. The historical style checker prints
findings but does not fail its process for geometry errors or an empty directory.
`Check-ThemeDraft.py` adds a nonzero exit for errors, an empty/missing folder and
missing measured casings. Deliberately shared casings must be listed in a JSON
file containing an object of casing names and reasons, passed with `--shared`.
This wrapper is a basic gate, not the full endcap or visual acceptance suite.
For an existing example, run:

```powershell
.\.venv\Scripts\python.exe Tools/Check-ThemeDraft.py Assets/Warrior --shared Examples/Warrior/shared-casings.json
```

Its four omitted native casings are deliberately shared, not missing new art.
For your own theme, decide and document each shared casing rather than blindly
copying that list.

## 4. Non-negotiable mounting checks

- Finish the bare casing and dip first. None and on retain identical bare art.
- Freeze/hash the entire terminal mask: upper point, outer end and descending
  dip including the inner heel. Never shrink the mask or cut the casing to pass.
- Freeze a separately approved maximum cap footprint BEFORE fitting. Warrior's
  historical reference uses the measured Druid union; a new theme needs its own
  recorded approval. Oversizing to get coverage is invalid.
- Use `Tools/ThemeHealthEndcaps.py` for whole-art registration. The intended toe
  is the actual lowest point; no second low tip. Match the dip within half a
  source pixel and cover all solid terminal pixels with at most one source-pixel
  contour AA. Preserve the locked mask separately; the helper alone does not
  enforce your saved mask, maximum footprint or every acceptance requirement.
- Explicit foreground masks preserve leather/rivets crossing the fill. Combined
  bridge/cap occlusion is at most 20%. Blanket aperture erasure is invalid.
- Inspect the PAINTED cast socket at 100%, X/Y=0 on normal and protected casings.
  The current fitted slot is 48px; a correct texture frame does not prove painted
  centering or socket coverage. Render complete None/on casts at 1x/2x.
- Retain rejected fixtures: toe-correct/exposed-terminal cap, cutout mounting
  body, oversized cap, erased bridge and low cast-head painting. They must fail
  the relevant theme-specific acceptance checks.

## 5. What the kit includes

`Assets/` contains the native top-level media plus Warrior and Druid reference
exports. The existing manifests are historical snapshots, not new acceptance.
`Docs/Research_Assets/Templates/` contains ready-to-use native guides and concept
boards. Required historical layout JSON files are included at their original paths.
`Examples/Warrior/` contains a brief and concept. These examples illustrate class
direction; the old Warrior rebuild pipeline and its full generation history are
not bundled. The current installed exports and engine are the implementation
reference. `Core/`, `Layouts/`, the selected unit files and options references are
read-only reference copies, not a complete addon.

The shared tools are real source copies. `ThemeButtonShapes.py` includes a
historical main function that writes Mage/Hunter files: use its functions in your
own builder, do not run it directly in this kit. `ThemeOrbGlass.py` preserves
native glass/specular lighting. `PaladinFillContracts.py` provides a historical
projection reference and needs the included Paladin layout JSON.

`Templates/EVIDENCE.md` and the inventory/provenance templates define the return
format. Keep production, integration, numeric checks, offline visual inspection,
maintainer approval, live Retail and live Forever as separate statuses.

`PACKAGE-MANIFEST.json` lists every delivered payload file with its SHA-256 and
size. `Verify-Package.py` verifies that manifest after extraction. Neither proves
visual quality or client behavior. The original license files travel with this
kit; it grants no additional artwork redistribution rights.
