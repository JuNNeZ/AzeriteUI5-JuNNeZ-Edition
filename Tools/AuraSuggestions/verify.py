"""Verify a curated aura list against Retail DB2.

Each entry: spec, aura ID, expected aura name, granting spell ID (0 = always on for the spec), recommendation.
Checks: the aura's name; that the aura spell applies an aura to an enemy (any aura type); that the granting
spell's name is known and the spell is offered to that spec (talent node, spec spell or class baseline).
For a failing ID it lists the spells with that name that do apply an enemy aura, to pick from.
"""
import csv, json, collections, sys
csv.field_size_limit(10**8)
def rows(name):
    with open(name + ".csv", encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)
I = int
names = {I(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
byName = collections.defaultdict(list)
for k, v in names.items():
    byName[v.lower()].append(k)
ENEMY = {6, 15, 16, 25, 28, 53, 54, 104, 110}
enemyAura = set()
for r in rows("SpellEffect"):
    if r["DifficultyID"] in ("0", "") and r["Effect"] in ("6", "35", "128", "129") and \
            {I(r["ImplicitTarget_0"]), I(r["ImplicitTarget_1"])} & ENEMY:
        enemyAura.add(I(r["SpellID"]))
g = json.load(open("grants.json"))
grants = {I(s): {I(k): v for k, v in d.items()} for s, d in g["grants"].items()}
anyGrant = collections.defaultdict(set)  # spell -> specs (talent/spec/baseline incl. acquire 3)
for s, d in grants.items():
    for k in d:
        anyGrant[k].add(s)
# all class-line abilities regardless of acquire method, per class
specs = {I(k): v for k, v in g["specs"].items()}
classLines = {I(r["ID"]) for r in rows("SkillLine") if r["CategoryID"] == "7"}
lineMask = collections.defaultdict(int)
for r in rows("SkillRaceClassInfo"):
    if I(r["SkillID"]) in classLines:
        lineMask[I(r["SkillID"])] |= I(r["ClassMask"] or 0)
classAbility = collections.defaultdict(set)
for r in rows("SkillLineAbility"):
    line = I(r["SkillLine"])
    if line in classLines and not (2730 <= line <= 2733):
        mask = I(r["ClassMask"] or 0) or lineMask[line]
        for cid in range(1, 14):
            if mask & (1 << (cid - 1)):
                classAbility[cid].add(I(r["Spell"]))

entries = json.load(open(sys.argv[1]))
bad = 0
for e in entries:
    spec, aura, name, grant = e["spec"], e["aura"], e["name"], e.get("grant", 0)
    problems = []
    if names.get(aura, "").lower() != name.lower():
        problems.append("aura name is %r" % names.get(aura))
    if aura not in enemyAura:
        problems.append("no enemy aura effect")
    if grant:
        cid = specs[spec][2] if spec in specs else None
        offered = spec in anyGrant.get(grant, set()) or (cid and grant in classAbility[cid])
        if not offered:
            problems.append("grant %d %r not offered to spec" % (grant, names.get(grant)))
        if grant not in names:
            problems.append("grant missing")
    if problems:
        bad += 1
        alts = [a for a in byName.get(name.lower(), []) if a in enemyAura]
        print("BAD %s %d %s: %s | enemy-aura IDs named so: %s" % (specs.get(spec, ("GROUP",))[0] + "/" + (specs.get(spec, ("", "-"))[1]), aura, name, "; ".join(problems), alts[:12]))
print("%d entries, %d bad" % (len(entries), bad))
