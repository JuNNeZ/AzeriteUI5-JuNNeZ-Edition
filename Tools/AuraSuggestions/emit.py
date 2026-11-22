import csv, json, collections, sys
csv.field_size_limit(10**8)
names = {}
with open("SpellName.csv", encoding="utf-8", newline="") as f:
    for r in csv.DictReader(f):
        names[int(r["ID"])] = r["Name_lang"]
g = json.load(open("grants.json"))
specs = {int(k): v for k, v in g["specs"].items()}
entries = json.load(open("curated.json"))
bySpec = collections.OrderedDict()
group = []
for e in entries:
    if e["spec"] == 0:
        group.append(e)
    else:
        bySpec.setdefault(e["spec"], []).append(e)
GROUP_CLASS = {113746: "MONK", 1490: "DEMONHUNTER", 257284: "HUNTER"}
out = []
w = out.append
w("\t-- Retail 12.1.5.70961. { aura spell ID, granting spell ID (0: every player of the spec has it), recommended }")
order = sorted(specs, key=lambda s: (specs[s][0], specs[s][1]))
for s in order:
    cls, name, _ = specs[s]
    w("\t[%d] = { class = \"%s\", -- %s %s" % (s, cls, name, cls.title()))
    for e in bySpec.get(s, []):
        rec = ("\"%s\"" % e["rec"]) if e["rec"] else "nil"
        grant = e["grant"]
        note = names[e["aura"]] + ("" if not grant else " <- " + names[grant])
        w("\t\t{ %d, %d, %s }, -- %s" % (e["aura"], grant, rec, note))
    w("\t},")
body = "\n".join(out)
grp = "\n".join("\t{ %d, \"%s\" }, -- %s" % (e["aura"], GROUP_CLASS[e["aura"]], names[e["aura"]]) for e in group)
open("tables.lua", "w", encoding="utf-8").write(body + "\n--GROUP--\n" + grp + "\n")
print(len(order), "specs", sum(len(v) for v in bySpec.values()), "entries", len(group), "group")
