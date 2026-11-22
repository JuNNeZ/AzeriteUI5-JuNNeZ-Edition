"""Resolve the curated Forever list (curated_forever.json) against Forever DB2 (product wowf).

Each row: class (or GROUP with "from" = the class that brings it), aura name, optional grant names, rec.
A class's granting spells: its class skill-line abilities that are normally learned (AcquireMethod not 3;
3 is "not normally learned", the rune spells) and its talents. Auras: spells with that name that apply an
aura to an enemy, reached from one of those granting spells (itself or through a triggered spell).
Ranks are ordered by SpellLevels (BaseLevel, SpellLevel, ID). Writes forever_resolved.json, prints problems.
"""
import csv, collections, json, sys
csv.field_size_limit(10**8)
def rows(name):
    with open(name + ".csv", encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)
I = lambda v: int(v or 0)
names = {I(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
classes = {r["Filename"]: I(r["ID"]) for r in rows("ChrClasses")}
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
learned = collections.defaultdict(set)
for r in rows("SkillLineAbility"):
    line = I(r["SkillLine"])
    if line in classLines and r["AcquireMethod"] != "3":
        mask = I(r["ClassMask"]) or lineMask[line]
        for cname, cid in classes.items():
            if mask & (1 << (cid - 1)):
                learned[cname].add(I(r["Spell"]))
tabClass = {}
for r in rows("TalentTab"):
    m = I(r["ClassMask"])
    for cname, cid in classes.items():
        if m & (1 << (cid - 1)):
            tabClass[I(r["ID"])] = cname
for r in rows("Talent"):
    cname = tabClass.get(I(r["TabID"]))
    for k in range(9):
        s = I(r.get("SpellRank_%d" % k))
        if s and cname:
            learned[cname].add(s)
ENEMY = {6, 15, 16, 22, 25, 28, 53, 54, 104, 110}
APPLY = {"6", "35", "128", "129"}
def reach(spell, depth=0, seen=None):
    seen = set() if seen is None else seen
    if spell in seen or depth > 3:
        return set()
    seen.add(spell)
    out = set()
    for e in effects.get(spell, []):
        if e["Effect"] in APPLY and {I(e["ImplicitTarget_0"]), I(e["ImplicitTarget_1"])} & ENEMY:
            out.add(spell)
        t = I(e["EffectTriggerSpell"])
        if t:
            out |= reach(t, depth + 1, seen)
    return out
reachable = {c: set().union(*[reach(s) for s in learned[c]]) for c in classes}
order = lambda ids: sorted(ids, key=lambda a: (level.get(a, (0, 0)), a))

rows_in = json.load(open(sys.argv[1]))
out, bad = [], 0
for row in rows_in:
    cname = row["from"] if row["class"] == "GROUP" else row["class"]
    if row.get("ids"):
        # Applied by a proc or a script the effect links do not show: each ID must exist under that name and
        # apply an aura to an enemy itself.
        auras = order([a for a in row["ids"] if names.get(a, "").lower() == row["aura"].lower()
                       and any(e["Effect"] in APPLY and {I(e["ImplicitTarget_0"]), I(e["ImplicitTarget_1"])} & ENEMY
                               for e in effects.get(a, []))])
        if len(auras) != len(row["ids"]):
            print("BAD %s %s: listed IDs failed the check" % (row["class"], row["aura"]))
    else:
        auras = order([a for a in reachable[cname] if names.get(a, "").lower() == row["aura"].lower()])
    grants = []
    for g in row.get("grants", []):
        grants += [s for s in learned[cname] if names.get(s, "").lower() == g.lower()]
    grants = order(set(grants))
    problems = []
    if not auras:
        problems.append("no reachable enemy aura")
    if row.get("grants") and not grants:
        problems.append("no learned grant")
    if problems:
        bad += 1
        print("BAD %s %s: %s" % (row["class"], row["aura"], "; ".join(problems)))
    out.append(dict(row, auraIDs=auras, grantIDs=grants))
    print("  %-11s %-26s %s%s" % (row["class"], row["aura"][:26], auras, ("  <- " + str(grants)) if grants else ""))
json.dump(out, open("forever_resolved.json", "w"), indent=0)
print("%d rows, %d bad" % (len(out), bad))
