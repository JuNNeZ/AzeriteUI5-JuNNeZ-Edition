"""Recheck unchanged Warlock endcaps against repaired, fully frozen casings.

Preserve the previous strict report and every old mask. Never resize a cap,
change its placement or reduce the Druid maximum to accommodate new rails.
"""
import copy
import json
import runpy

import numpy as np
from PIL import Image

from PriestWarlockAssetContracts import ROOT, LONG, record
from ThemeHealthEndcaps import align, terminal_coverage


def refresh():
    folder = ROOT / "Assets_Draft/Warlock/FullSet"
    docs = ROOT / "Docs/Research_Assets/Warlock/FullSet/Contracts"
    path = folder / "Endcaps/fit-report.json"
    previous = folder / "Review/GapRepair/endcaps-before.json"
    if not previous.exists():
        previous.write_bytes(path.read_bytes())
    report = json.loads(previous.read_text())
    # Freeze all complete replacement terminals BEFORE checking fixed caps.
    runpy.run_path(str(ROOT / "Tools/Fit-PriestWarlockEndcaps.py"))["fit"]("Warlock", freeze_only=True)
    frozen = json.loads((docs / "painted-terminals.json").read_text())
    fields = json.loads((docs / "functional-fields.json").read_text())["clearance"]
    for name in LONG:
        item = report["cases"][name]
        bare = Image.open(folder / "Composed" / (name+"-over.tga")).convert("RGBA")
        cap = Image.open(ROOT / item["export"]["path"]).convert("RGBA")
        fill = Image.open(ROOT / fields[name]["path"]).convert("L")
        item["previousFrozenTerminal"] = item["frozenTerminal"]
        item["frozenTerminal"] = frozen[name]
        best = copy.deepcopy(item["best"])
        best["paintedTerminal"] = terminal_coverage(bare, cap)
        combined = (np.asarray(bare)[:, :, 3] > 200) | (np.asarray(cap)[:, :, 3] > 200)
        best["combinedFillOcclusion"] = float((combined & (np.asarray(fill)>128)).sum() / (np.asarray(fill)>128).sum())
        assert best["combinedFillOcclusion"] <= .20
        error = None
        try:
            align(Image.open(ROOT / item["source"]["path"]), bare, best["height"], fill, source_transform=best["transform"])
        except (AssertionError, ValueError) as failure:
            error = str(failure)
        best.update(numericPassed=error is None, error=error)
        item["best"] = best
        item["trials"] = [best]
        print(name + ": fixed cap / strict=" + str(best["numericPassed"]) + "; exposed=" + str(best["paintedTerminal"]["exposedTerminalPixelsBeyondAA"]))
    report.update(numericPassed=all(c["best"]["numericPassed"] for c in report["cases"].values()),
                  terminalContract=record(docs / "painted-terminals.json"),
                  previousStrictReport=record(previous), repairTool=record(__file__), unchangedCapPlacements=True)
    path.write_text(json.dumps(report, indent=2)+"\n")


if __name__ == "__main__":
    refresh()
