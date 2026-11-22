"""Forever (product wowf): per-class debuff candidates with their ranks.

A class's spells: its class skill-line abilities (any acquire method) and its talents (Talent.SpellRank_*).
A candidate: a spell whose effect applies an aura to an enemy, either itself or through a triggered spell.
Ranks: candidates of one class sharing a name, ordered by SpellLevels (BaseLevel, then SpellLevel, then ID).
Usage: forever.py [names...]  prints candidates; with names, prints those names' rows for every class.
"""
import csv, collections, json, sys
csv.field_size_limit(10**8)
def rows(name):
    with open(name + ".csv", encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)
I = lambda v: int(v or 0)
names = {I(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
classes = {I(r["ID"]): r["Filename"] for r in rows("ChrClasses")}
effects = collections.defaultdict(list)
for r in rows("SpellEffect"):
    effects[I(r["SpellID"])].append(r)
level = {}
for r in rows("SpellLevels"):
    if r["DifficultyID"] in ("0", ""):
        level[I(r["SpellID"])] = (I(r["BaseLevel"]), I(r["SpellLevel"]))
classLines = {I(r["ID"]) for r in rows("SkillLine") if r["CategoryID"] == "7"}
lineMask = collections.defaultdict(int)
for r in rows("SkillRaceClassInfo"):
    if I(r["SkillID"]) in classLines:
        lineMask[I(r["SkillID"])] |= I(r["ClassMask"])
spells = collections.defaultdict(dict)  # class -> spell -> how
for r in rows("SkillLineAbility"):
    line = I(r["SkillLine"])
    if line in classLines:
        mask = I(r["ClassMask"]) or lineMask[line]
        for cid in classes:
            if mask & (1 << (cid - 1)):
                spells[cid].setdefault(I(r["Spell"]), "class")
for r in rows("Talent"):
    cid = I(r["ClassID"])
    for k in range(9):
        s = I(r.get("SpellRank_%d" % k))
        if s:
            spells[cid][s] = "talent"
ENEMY = {6, 15, 16, 22, 25, 28, 53, 54, 104, 110}
APPLY = {"6", "35", "128", "129"}
def enemy_auras(spell, depth=0, seen=None):
    seen = set() if seen is None else seen
    if spell in seen or depth > 2:
        return []
    seen.add(spell)
    out = []
    for e in effects.get(spell, []):
        if e["Effect"] in APPLY and {I(e["ImplicitTarget_0"]), I(e["ImplicitTarget_1"])} & ENEMY:
            out.append((spell, I(e["EffectAura"])))
        t = I(e["EffectTriggerSpell"])
        if t:
            out += enemy_auras(t, depth + 1, seen)
    return out
DOT = {3, 53, 89}
result = {}
for cid, cname in classes.items():
    byName = collections.defaultdict(dict)
    for s, how in spells[cid].items():
        for aura, atype in enemy_auras(s):
            byName[names.get(aura, "?")].setdefault(aura, (s, how, atype))
    result[cname] = byName
json.dump({c: {n: {str(a): v for a, v in d.items()} for n, d in byName.items()} for c, byName in result.items()},
          open("forever_candidates.json", "w"))
want = [a.lower() for a in sys.argv[1:]]
for cname, byName in result.items():
    print("==", cname)
    for n in sorted(byName):
        d = byName[n]
        if want and n.lower() not in want:
            continue
        if not want and not any(v[2] in DOT for v in d.values()):
            continue
        order = sorted(d, key=lambda a: (level.get(a, (0, 0)), a))
        print("  %-28s %s" % (n[:28], " ".join("%d(L%d,%s,a%d)" % (a, level.get(a, (0, 0))[0], d[a][1][0], d[a][2]) for a in order)))
