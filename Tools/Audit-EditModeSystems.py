"""List the Blizzard frames that are Edit Mode systems on each client, and which of
them AzeriteUI replaces. Offline: reads the extracted Blizzard source in
.research/tmp/wow-ui-source (Retail) and wow-ui-source-forever (Forever).

    python Tools/Audit-EditModeSystems.py            # print the table
    python Tools/Audit-EditModeSystems.py --json     # machine readable
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLIENTS = {
    "retail": ROOT / ".research/tmp/wow-ui-source/Interface/AddOns",
    "forever": ROOT / ".research/tmp/wow-ui-source-forever/Interface/AddOns",
}
# Systems AzeriteUI draws itself (its own frame, moved through /lock).
# value: the AzeriteUI module that owns the replacement.
REPLACED = {
    "ActionBar": "ActionBars",
    "MainActionBarEndCap": "ActionBars (Forever gryphons)",
    "StatusTrackingBar": "Bars (XP/Rep)",
    "StatusTrackingBar1": "Bars (XP/Rep)",
    "StatusTrackingBar2": "Bars (XP/Rep)",
    "UnitFrame": "UnitFrames",
    "CastBar": "UnitFrames (PlayerCastBar)",
    "AuraFrame": "Auras",
    "Minimap": "Minimap",
    "ObjectiveTracker": "Tracker",
    "ChatFrame": "ChatFrames (styled, not replaced)",
    "MicroMenu": "MicroMenu",
    "Bags": "Bags / MicroMenu",
    "ExtraAbilities": "ExtraActionButtons",
    "VehicleLeaveButton": "VehicleExit",
    "TalkingHeadFrame": "TalkingHead",
    "DurabilityFrame": "Durability",
    "EncounterBar": "EncounterBar",
}

TEMPLATE_RE = re.compile(r'<Frame\s+name="(EditMode\w+SystemTemplate)"[^>]*?inherits="([^"]*)"', re.S)
SYSTEM_RE = re.compile(r'key="system"\s+value="Enum\.EditModeSystem\.(\w+)"')
USE_RE = re.compile(r'<(?:Frame|Button|Cooldown|StatusBar|ScrollFrame|CheckButton|ModelScene|Model)\b[^>]*?\bname="(\w+)"[^>]*?\binherits="([^"]*EditMode\w+SystemTemplate[^"]*)"', re.S)
# Systems with no global name, only a parentKey (Forever's MainActionBar.EndCaps.LeftEndCap and
# RightEndCap). Reported as ".<parentKey>"; the file says which frame owns them.
KEY_RE = re.compile(r'<(?:Frame|Button|StatusBar)\b(?![^>]*\bname=)[^>]*?\bparentKey="(\w+)"[^>]*?\binherits="([^"]*EditMode\w+SystemTemplate[^"]*)"', re.S)


def template_systems(addons):
    """EditMode*SystemTemplate -> system name, following inheritance."""
    xml = (addons / "Blizzard_EditMode/Shared/EditModeSystemTemplates.xml").read_text(encoding="utf-8", errors="replace")
    blocks = re.split(r'(?=<Frame\s+name="EditMode\w+SystemTemplate")', xml)
    parents, systems = {}, {}
    for block in blocks:
        head = TEMPLATE_RE.match(block)
        if not head:
            continue
        name = head.group(1)
        parents[name] = [p.strip() for p in head.group(2).split(",")]
        body = block[: block.find("</Frame>") if "</Frame>" in block else len(block)]
        found = SYSTEM_RE.search(block[:1500])
        if found:
            systems[name] = found.group(1)

    def resolve(name, seen=()):
        if name in systems:
            return systems[name]
        for parent in parents.get(name, []):
            if parent in seen:
                continue
            hit = resolve(parent, seen + (name,))
            if hit:
                return hit
        return None

    return {name: resolve(name) for name in parents}


def audit(addons):
    systems = template_systems(addons)
    rows = []
    for path in addons.rglob("*.xml"):
        if "Blizzard_EditMode" in path.parts:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        matches = [(m.group(1), m.group(2)) for m in USE_RE.finditer(text)]
        matches += [("." + m.group(1), m.group(2)) for m in KEY_RE.finditer(text)]
        for frame, inherits in matches:
            templates = [t.strip() for t in inherits.split(",") if "EditMode" in t]
            for template in templates:
                system = systems.get(template)
                if system:
                    rows.append({
                        "frame": frame,
                        "system": system,
                        "template": template,
                        "file": str(path.relative_to(addons)).replace("\\", "/"),
                    })
    return sorted(rows, key=lambda r: (r["system"], r["frame"]))


def main():
    as_json = "--json" in sys.argv
    report = {}
    for client, addons in CLIENTS.items():
        if not addons.is_dir():
            report[client] = None
            continue
        report[client] = audit(addons)

    if as_json:
        print(json.dumps(report, indent=1))
        return

    for client, rows in report.items():
        print(f"== {client}")
        if rows is None:
            print("  (source not on disk)")
            continue
        for row in rows:
            owner = REPLACED.get(row["system"], "-")
            print(f"  {row['system']:<20} {row['frame']:<38} replaced by: {owner:<28} {row['file']}")
        print(f"  {len(rows)} frames")
    retail = {r["frame"] for r in report.get("retail") or []}
    forever = {r["frame"] for r in report.get("forever") or []}
    print("== only on retail :", ", ".join(sorted(retail - forever)) or "-")
    print("== only on forever:", ", ".join(sorted(forever - retail)) or "-")


if __name__ == "__main__":
    main()
