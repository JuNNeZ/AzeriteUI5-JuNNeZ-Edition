# Aura suggestion data

The checked source of `Components/UnitFrames/NamePlates/AuraSuggestions.lua` (nameplate aura picker,
`Docs/Nameplate Aura Picker Plan - 2026-11-21.md`, step 2). Edit `curated.json`, never the Lua table by hand.

`curated.json`: one row per suggestion, `spec` (0 = group debuff), `aura`, `name`, `grant` (0 = every player
of the spec has it) and `rec` (`"once"`, `"highlight"` or null).

## Procedure (offline, Python 3, run with `python -I`)

1. Download the build's tables as CSV into an empty scratch folder (not the repo): product `wow` for Retail,
   `wowf` for Forever; builds at `https://wago.tools/api/builds`, tables at
   `https://wago.tools/db2/<Table>/csv?build=<build>`. Needed: SpellName, SpellEffect, SpecializationSpells,
   ChrSpecialization, ChrClasses, TraitDefinition, TraitNode, TraitNodeEntry, TraitNodeXTraitNodeEntry,
   TraitTreeLoadout, TraitCond, TraitNodeXTraitCond, TraitNodeGroupXTraitCond, TraitNodeGroupXTraitNode,
   SpecSetMember, SkillLine, SkillLineAbility, SkillRaceClassInfo.
2. From that folder: `perspec.py` lists each specialization's damage-over-time candidates and writes
   `grants.json` (what each specialization is offered: talent nodes its conditions allow, specialization
   spells, class abilities; Shadowlands covenant lines 2730-2733 excluded).
3. `verify.py curated.json`: every row's aura carries that name and applies an aura to an enemy, and its
   granting spell is offered to that specialization. Must print `0 bad`. `lookup.py "<name>"` shows the
   candidates for a failing row.
4. `emit.py` writes `tables.lua`; its two parts replace the bodies of `RETAIL` and `GROUP`.

## Forever (product `wowf`)

`curated_forever.json`: one row per class spell (`class`, `aura` name, optional `grants` names, `rec`), or
per group debuff (`class` = `"GROUP"`, `from` = the class that brings it). A row may give `ids` when the aura
is applied by a proc or a script the effect links do not show; each of those IDs must carry the name and
apply an aura to an enemy itself.

1. Tables as above (product `wowf`), plus Talent, TalentTab and SpellLevels.
2. `forever_candidates.py` lists each class's damage-over-time candidates with their ranks.
3. `forever_resolve.py curated_forever.json`: resolves every rank (ordered by SpellLevels), only from
   spells the class learns normally (AcquireMethod 3, "not normally learned", is the rune spells and does
   not count) and talents. Must print `0 bad`; writes `forever_resolved.json`, whose rows become `FOREVER`
   and `FOREVER_GROUP` in `AuraSuggestions.lua` (`{ { ranks }, grants or nil, rec }`).

Forever 1.60.1.71037 (2026-11-22): 43 rows, 0 bad. Left out: Deep Wound, Ignite, Faerie Fire (Feral) and
Curse of Shadow (not class spells in this build), Deadly Poison (from the poison items), and the
level-0 rune spells (Living Bomb 400613, Sunfire 414684, ...). Judgement of Wisdom/Light/the Crusader,
Shadow Vulnerability (17794) and Shadow Weaving (15258) were checked ID by ID.

## Retail results

Retail 12.1.5.70961 (2026-11-22): 100 rows, 0 bad. Rows whose spell was no longer offered to any
specialization were dropped (Festering Wound, Stellar Flare, Fungal Growth, Serpent Sting, Living Bomb,
Final Reckoning, Schism, Shattering Star, Ghostly Strike, Crimson Tempest, Subtlety Rupture). A row with
grant 0 was also checked to be reachable for its specialization (the aura itself, a same-named spell or a
spell triggering it); Ignite (Mastery: Ignite), Winter's Chill (Flurry) and Razorice (a runeforge) are
applied by the game outside those links and were kept on knowledge.
