"""Freeze complete painted terminals before bounded whole-source cap fitting."""
import argparse
import json
import math

import numpy as np
from PIL import Image

from PriestWarlockAssetContracts import ROOT, LONG, record, sha
from ThemeHealthEndcaps import align, lowest_point, terminal_mask, terminal_coverage
from ThemeSourceIntegrity import whole_painting, verify_pixels


def fit(theme, freeze_only=False):
    folder = ROOT / "Assets_Draft" / theme / "FullSet"
    docs = ROOT / "Docs/Research_Assets" / theme
    contracts = json.loads((docs / "Contracts/approved-footprints.json").read_text())["cases"]
    fields = json.loads((docs / "FullSet/Contracts/functional-fields.json").read_text())["clearance"]
    motif = "tuure" if theme == "Priest" else "ulthalesh"
    source_path = ROOT / "Assets_Draft" / theme / "Sources" / ("health-endcap-" + motif + "-v5.png")
    source = Image.open(source_path).convert("RGBA")
    source_box = source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    frozen = {}
    # Freeze ALL terminals first; fitting cannot change or shorten a mask.
    for name in LONG:
        path = folder / "Composed" / (name + "-over.tga")
        image = Image.open(path).convert("RGBA")
        mask = terminal_mask(image)
        target = docs / "FullSet/Contracts" / (name + "-painted-terminal-" + sha(path)[:12] + ".png")
        if target.exists():
            assert Image.open(target).tobytes() == mask.tobytes()
        else:
            mask.save(target)
        frozen[name] = {"painting": record(path), "mask": record(target), "toe": list(lowest_point(image))}
    lock_path = docs / "FullSet/Contracts/painted-terminals.json"
    lock_path.write_text(json.dumps(frozen, indent=2) + "\n")
    if freeze_only:
        print(theme + ": frozen all four complete painted terminals before fitting")
        return
    output = folder / "Endcaps"
    output.mkdir(exist_ok=True)
    results = {}
    for name in LONG:
        contract = contracts[name]
        source_paths = [ROOT / "Assets_Draft" / theme / "Sources" / ("health-endcap-" + motif + "-v5.png")]
        if name != "hp_cap_case":
            for revision in (1, 2):
                tier_result = docs / ("FullSet/tier-cap-v" + str(revision) + "-result.json")
                if tier_result.exists():
                    selected = json.loads(tier_result.read_text())["source"]
                    selected_path = ROOT / selected["path"]
                    assert sha(selected_path) == selected["sha256"]
                    source_paths.append(selected_path)
        trials, candidates = [], []
        for source_path in source_paths:
            source = Image.open(source_path).convert("RGBA")
            source_box = source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
            crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            native_path = ROOT / contract["native"]["path"]
            assert sha(native_path) == contract["native"]["sha256"]
            native = Image.open(native_path).convert("RGBA")
            bare = Image.open(ROOT / frozen[name]["painting"]["path"]).convert("RGBA")
            field = Image.open(ROOT / fields[name]["path"]).convert("L")
            bound = contract["approvedFootprint"]
            sizes_seen = set()
            for tenth in range(400, int((bound[3] - bound[1])*10) + 1):
                height = tenth / 10
                scale = height / (source_box[3] - source_box[1])
                size = (round((crop[2]-crop[0])*scale), round((crop[3]-crop[1])*scale))
                if size in sizes_seen:
                    continue
                sizes_seen.add(size)
                painting = source.crop(crop).resize(size, Image.Resampling.LANCZOS)
                tx, ty = lowest_point(bare)
                px, py = lowest_point(painting)
                # A half-pixel toe has two integer translations. Banker's rounding
                # alone can choose a cap one pixel from the native toe when the
                # intact bare painting itself is legally half a pixel away.
                placements = []
                nx, ny = contract["nativeToe"]
                for x in sorted({math.floor(tx-px), math.ceil(tx-px)}):
                    if abs(px+x-tx)>.5 or abs(px+x-nx)>.5:
                        continue
                    transform = {"crop": list(crop), "scale": scale, "offset": [x, round(ty-py)]}
                    try:
                        cap = whole_painting(source, transform, bare.size)
                    except ValueError:
                        continue
                    box = cap.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
                    if any((box[0]<bound[0], box[1]<bound[1], box[2]>bound[2], box[3]>bound[3])):
                        continue
                    placements.append((terminal_coverage(bare,cap)["exposedTerminalPixelsBeyondAA"],cap,transform))
                if not placements:
                    continue
                _,cap,transform = min(placements,key=lambda p:p[0])
                box = cap.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
                if any((box[0]<bound[0], box[1]<bound[1], box[2]>bound[2], box[3]>bound[3])):
                    continue
                painted_fit, native_fit = terminal_coverage(bare, cap), terminal_coverage(native, cap)
                combined = (np.asarray(bare)[:,:,3] > 200) | (np.asarray(cap)[:,:,3] > 200)
                overlap = float((combined & (np.asarray(field)>128)).sum() / (np.asarray(field)>128).sum())
                error = None
                try:
                    # Reject known failures before the expensive source-wide
                    # checks. Every possible pass still runs shared align().
                    assert painted_fit["exposedTerminalPixelsBeyondAA"] == 0, "cap leaves terminal metal exposed: " + str(painted_fit)
                    assert overlap <= .20, "Combined cap/foreground occlusion exceeds 20 percent"
                    align(source, bare, height, field, source_transform=transform)
                    # The original native metal is not rendered in this construction:
                    # only its recess sits below the intact NEW foreground. Retain
                    # native coverage as a diagnostic; the frozen rendered terminal
                    # is the actual coverage contract, as in approved representative v5.
                    assert overlap <= .20, "Combined cap/foreground occlusion exceeds 20 percent"
                    nx, ny = lowest_point(native)
                    assert abs(tx-nx) <= .5 and ty == ny, "Bare native toe changed"
                except (ValueError, AssertionError) as failure:
                    error = str(failure)
                trial = {"height": height, "transform": transform, "bounds": list(box), "approvedFootprint": bound,
                    "paintedTerminal": painted_fit, "nativeTerminal": native_fit, "combinedFillOcclusion": overlap,
                    "numericPassed": error is None, "error": error}
                trials.append(trial)
                candidates.append((cap, source_path))
        assert trials, "No cap fits the approved footprint: " + name
        index = min(range(len(trials)), key=lambda i: (not trials[i]["numericPassed"],
            trials[i]["paintedTerminal"]["exposedTerminalPixelsBeyondAA"], trials[i]["height"]))
        best = trials[index]
        target = output / ("ornament-" + motif + "-" + name + ".tga")
        chosen_cap, chosen_source = candidates[index]
        chosen_cap.save(target, compression=None)
        verify_pixels(chosen_cap, Image.open(target).convert("RGBA"))
        results[name] = {"source": record(chosen_source), "frozenTerminal": frozen[name], "export": record(target), "best": best, "trials": trials}
        print(theme + "/" + name + ": numeric=" + str(best["numericPassed"]) + "; exposed painted/native=" + str(best["paintedTerminal"]["exposedTerminalPixelsBeyondAA"]) + "/" + str(best["nativeTerminal"]["exposedTerminalPixelsBeyondAA"]))
    report = {"schema": 1, "theme": theme, "cases": results, "numericPassed": all(x["best"]["numericPassed"] for x in results.values()),
        "terminalContract": record(lock_path), "productionAccepted": False, "fullPackVisualApproved": False, "liveApproved": False}
    (output / "fit-report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", choices=("Priest", "Warlock", "Both"))
    parser.add_argument("--freeze-only", action="store_true")
    args = parser.parse_args()
    for theme in ("Priest", "Warlock") if args.theme == "Both" else (args.theme,):
        fit(theme, args.freeze_only)
