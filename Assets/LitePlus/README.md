# Class Lite+ interiors (WIP)

Implemented on the maintainer's 2026-11-05 instruction to build the missing
effects from the revised native-shape concepts. This is an authorized WIP for
live review, not a claim of production or live visual approval.

After `/reload`: `/az` -> Themes -> Lite+ -> Crystal effect / Orb effect.

| Class | Materials |
| --- | --- |
| Warrior | Forge, Valarjar, Battleheart |
| Rogue | Venom, Shadow, Nightblood |
| Shaman | Tides, Magma, Storm |
| Death Knight | Crimson Oath, Rime, Gravebound |
| Demon Hunter | Fel Fury, Soulfire, Abyss |
| Priest | Sanctum, Covenant, Void |
| Warlock | Affliction, Demonology, Destruction |
| Monk | Brew, Mists, Wind |
| Evoker | Verdant, Azure, Ebon Resonance |

Each material can be picked for either resource on any main-layout theme.
Crystal and orb strength are separate; zero stops that effect. Existing theme
defaults, saved placements, casings, resource values and fill masks are intact.

`Core/ClassResourceEffects.lua` draws two moving field samples and six bounded
particles inside native resource clips. Materials differ in source field,
motion and particle construction, not just colour: heat seams/sparks,
stormlight/runes, drifting cinders, rising poison globules, folding shadow,
fluid veins, flowing water/bubbles, slow basalt seams, and sparse lightning.
Motion reacts smoothly to readable moving/combat/mount/flying state. Hidden
or cleared frames stop callbacks and event subscriptions. Native LibOrb owns
the fill level; Flowing mana's trough remains above all these effects.

Nine opaque 1024x1024 RGBA atlases, 4 MiB each. Each has four square cells:
three material fields and one glyph/particle source. UVs stay inside their
cell with a margin at every tested angle and phase. Rogue's globule is also
used by Tides. Native functional crystal/orb masks are applied at runtime;
no casing alpha is imposed on a painting or modified in the exporter.

Generated sources, exact prompts and replay manifest:
`Assets_Draft/LitePlus-2026-11-05/`. `Tools/Build-ClassResourceArt.py` explicitly
converts the complete near-neutral source to neutral grayscale emission and
uniformly scales the whole atlas, without cropping or native stencilling.
Replay verifies reopened TGA pixels and installed bytes against that operation.
This resource-field conversion is distinct from production casing source proof.

Rebuild/verify:

```powershell
python Tools/Build-ClassResourceArt.py --install-wip
python Tools/Build-ClassResourceArt.py --verify --install-wip
python Tools/Tests/test_class_resource_art.py
lua Tools/Harness/class_resource_effects_harness.lua .
lua Tools/Harness/class_resource_effects_harness.lua . samples .research/tmp/liteplus-review
```

The six additional families finish the maintainer's "Lav dem alle" request.
Death Knight, Demon Hunter, Monk and Evoker originals were recovered from the
earlier chat, byte-preserved in the draft directory. Priest and Warlock were
generated with built-in image_gen; exact prompts are retained there. The
recovered originals' exact prompts are unavailable; `source-recovery.json`
records that limitation and source hashes. Runtime colours and distinct motions
reuse the partial implementation already present before this continuation.
These are resource effects on existing casings, not six new full casing themes.

Live checks owed on Retail and Forever: all 27 selections, 0/50/100 strength,
full/half/empty resources, ice, moving/mount/flying/combat, Flowing mana, switching
to None/other families, and hidden/shown frames. Check text, glass, casings,
saved placements, BugSack and blocked actions. No version bump or release.
