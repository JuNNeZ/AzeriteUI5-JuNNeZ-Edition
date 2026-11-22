"""Per-spec debuff candidates from Retail DB2, with how each is obtained.

For every class talent node, the specs it is offered to come from its TraitCond rows (direct or through
its node groups) that carry a SpecSetID. Nodes with none are offered to every spec of the class.
"""
import csv, collections, json, sys
csv.field_size_limit(10**8)

def rows(name):
    with open(name + ".csv", encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)

I = int
names = {I(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
classes = {I(r["ID"]): r["Filename"] for r in rows("ChrClasses")}
specs = {}
for r in rows("ChrSpecialization"):
    cid = I(r["ClassID"])
    if 1 <= cid <= 13 and I(r["OrderIndex"]) < 4:
        specs[I(r["ID"])] = (classes[cid], r["Name_lang"], cid)
classSpecs = collections.defaultdict(set)
for s, (_, _, cid) in specs.items():
    classSpecs[cid].add(s)

effects = collections.defaultdict(list)
for r in rows("SpellEffect"):
    if r["DifficultyID"] in ("0", ""):
        effects[I(r["SpellID"])].append(r)

specSet = collections.defaultdict(set)
for r in rows("SpecSetMember"):
    specSet[I(r["SpecSet"])].add(I(r["ChrSpecializationID"]))
condSpecs = {}
for r in rows("TraitCond"):
    if I(r["SpecSetID"] or 0):
        condSpecs[I(r["ID"])] = specSet[I(r["SpecSetID"])]
nodeSpecs = collections.defaultdict(set)
for r in rows("TraitNodeXTraitCond"):
    c = I(r["TraitCondID"])
    if c in condSpecs:
        nodeSpecs[I(r["TraitNodeID"])] |= condSpecs[c]
groupSpecs = collections.defaultdict(set)
for r in rows("TraitNodeGroupXTraitCond"):
    c = I(r["TraitCondID"])
    if c in condSpecs:
        groupSpecs[I(r["TraitNodeGroupID"])] |= condSpecs[c]
for r in rows("TraitNodeGroupXTraitNode"):
    g = I(r["TraitNodeGroupID"])
    if g in groupSpecs:
        nodeSpecs[I(r["TraitNodeID"])] |= groupSpecs[g]

treeClass = {}
for r in rows("TraitTreeLoadout"):
    s = I(r["ChrSpecializationID"])
    if s in specs:
        treeClass[I(r["TraitTreeID"])] = specs[s][2]
nodeTree = {I(r["ID"]): I(r["TraitTreeID"]) for r in rows("TraitNode")}
entryDef = {I(r["ID"]): I(r["TraitDefinitionID"]) for r in rows("TraitNodeEntry")}
defSpell = {I(r["ID"]): I(r["SpellID"]) for r in rows("TraitDefinition")}

# spec -> spell -> how
grants = collections.defaultdict(dict)
talentSpecs = collections.defaultdict(set)
for r in rows("TraitNodeXTraitNodeEntry"):
    node = I(r["TraitNodeID"])
    cid = treeClass.get(nodeTree.get(node))
    spell = defSpell.get(entryDef.get(I(r["TraitNodeEntryID"]), -1), 0)
    if not cid or not spell:
        continue
    allowed = (nodeSpecs.get(node) or classSpecs[cid]) & classSpecs[cid]
    for s in allowed:
        grants[s][spell] = "talent"
        talentSpecs[spell].add(s)
for r in rows("SpecializationSpells"):
    s = I(r["SpecID"])
    if s in specs:
        grants[s].setdefault(I(r["SpellID"]), "spec")
classLines = {I(r["ID"]) for r in rows("SkillLine") if r["CategoryID"] == "7"}
lineMask = collections.defaultdict(int)
for r in rows("SkillRaceClassInfo"):
    if I(r["SkillID"]) in classLines:
        lineMask[I(r["SkillID"])] |= I(r["ClassMask"] or 0)
baselineClass = collections.defaultdict(set)
for r in rows("SkillLineAbility"):
    line = I(r["SkillLine"])
    if line in classLines and 2730 <= line <= 2733:
        continue  # Shadowlands covenant lines
    if line in classLines and r["AcquireMethod"] == "2":
        mask = I(r["ClassMask"] or 0) or lineMask[line]
        for cid in range(1, 14):
            if mask & (1 << (cid - 1)):
                baselineClass[cid].add(I(r["Spell"]))
for s, (_, _, cid) in specs.items():
    for spell in baselineClass[cid]:
        grants[s].setdefault(spell, "baseline")

DOT = {3: "dot", 53: "leech", 89: "dot%"}
ENEMY = {6, 15, 16, 25, 28, 53, 54, 104, 110}

def auras_from(spell, depth=0, seen=None):
    seen = set() if seen is None else seen
    if spell in seen or depth > 2:
        return []
    seen.add(spell)
    out = []
    for e in effects.get(spell, []):
        eff, aura = I(e["Effect"]), I(e["EffectAura"])
        if eff == 6 and aura in DOT and {I(e["ImplicitTarget_0"]), I(e["ImplicitTarget_1"])} & ENEMY:
            out.append(spell)
        trig = I(e["EffectTriggerSpell"] or 0)
        if trig:
            out += auras_from(trig, depth + 1, seen)
    return out

out = {}
for s in sorted(specs):
    found = {}
    for g, how in grants[s].items():
        for a in auras_from(g):
            if a not in found or found[a][1] == "talent":
                found[a] = (g, how)
    out[s] = found
    cls, name, _ = specs[s]
    print("== %d %s %s" % (s, cls, name))
    for a, (g, how) in sorted(found.items(), key=lambda x: names.get(x[0], "")):
        print("   %7d %-30s <- %7d %-26s %s" % (a, names.get(a, "?")[:30], g, names.get(g, "?")[:26], how))

json.dump({
    "specs": {str(k): v for k, v in specs.items()},
    "grants": {str(s): {str(k): v for k, v in g.items()} for s, g in grants.items()},
    "talentSpecs": {str(k): sorted(v) for k, v in talentSpecs.items()},
}, open("grants.json", "w"))
