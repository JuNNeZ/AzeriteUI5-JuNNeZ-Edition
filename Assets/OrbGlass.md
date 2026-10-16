# Native orb glass lighting - 2026-10-16

Hunter, Mage, Paladin and Druid orb_case_hi/low preserve the native glass
aperture, alpha and rendered stock brightness. Only the measured functional
glass area changes. Themed frames and all runtime layouts/fills remain intact.

Two defects were found: builders classified alpha >200 as frame material, but
the native white reflection includes opaque pixels. Repainting those pixels
made a black hole or a dull patch. Also, the original Case is tinted by Colors.ui
(192/255), while themed cases render white. Copying raw native glass RGB into a
white-tinted case made it brighter. ThemeOrbGlass.py copies ALL native aperture
pixels and bakes the original tint into glass RGB only, retaining native alpha.
Hunter's previously empty opening also receives the native pane/specular.

Shared export helper: Tools/ThemeOrbGlass.py. Druid, Paladin and Hunter builders
call it; the retained Mage package script does too. For existing installs or
copied legacy outputs: python Tools/Repair-ThemeOrbGlass.py --install.
The repair updates runtime manifests and Druid staging; original assets stay
untouched. Repeating it is idempotent. The retained Mage package script is an archived
source with its existing external ROOT path; the repair command also supports
any future legacy copy into Assets/Mage. Canvas sizes and asset count are unchanged.

Validation: python Tools/Check-ThemeOrbGlass.py independently checks eight
installed casings against native aperture pixels, stock tint, unchanged exterior
and manifest hashes. Executes the actual Druid/Paladin orb export paths in temp
outputs. Rejects black-highlight, overbright-RGB and missing-alpha mutants.
Check-ThemeAssetStyle.py now also enforces the orb-glass lighting contract.
Paladin/Druid installed/staging checks pass. This is offline validation.

Before/after: Docs/Research_Assets/OrbGlass-2026-10-16/comparison.png.
Backups of the eight pre-fix casings live beside that review.

Live Retail/Forever after /reload: compare original and the four themes, both
orb tiers, at 0/50/100% mana. Check the highlight on blue, dark and bright fills,
with Lite+ none/Druid/Moonwell+/Paladin, plus the optional extra glass toggle on
and off. No black patch, clipped reflection or excessive bright halo should
remain. Optional extra glass is a separate existing layer; it is not disabled or
changed by this repair. No version/release change.
