import csv, json, collections, sys
csv.field_size_limit(10**8)
def rows(name):
    with open(name + ".csv", encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)
I = int
names = {I(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
ENEMY = {6, 15, 16, 25, 28, 53, 54, 104, 110}
effects = collections.defaultdict(list)
for r in rows("SpellEffect"):
    if r["DifficultyID"] in ("0", ""):
        effects[I(r["SpellID"])].append(r)
g = json.load(open("grants.json"))
specs = {I(k): v for k, v in g["specs"].items()}
offered = collections.defaultdict(set)
for s, d in g["grants"].items():
    for k in d:
        offered[I(k)].add(specs[I(s)][1][:5] + str(s))
def desc(sid):
    out = []
    for e in effects.get(sid, []):
        t = {I(e["ImplicitTarget_0"]), I(e["ImplicitTarget_1"])}
        out.append("e%s/a%s%s%s" % (e["Effect"], e["EffectAura"], "*" if t & ENEMY else "", ("->" + e["EffectTriggerSpell"]) if e["EffectTriggerSpell"] not in ("0", "") else ""))
    return " ".join(out)
for q in sys.argv[1:]:
    print("##", q)
    ids = [int(q)] if q.isdigit() else [k for k, v in names.items() if v.lower() == q.lower()]
    for sid in sorted(ids):
        if offered.get(sid) or q.isdigit() or any(("*" in x) for x in desc(sid).split()):
            print("  %8d %-26s offered=%s  %s" % (sid, names.get(sid), sorted(offered.get(sid, [])), desc(sid)[:150]))
