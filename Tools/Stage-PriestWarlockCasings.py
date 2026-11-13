"""Compose draft casings with exact native functional underlays; never install."""
from pathlib import Path
import argparse
import importlib.util
import json

import numpy as np
from PIL import Image

from PriestWarlockAssetContracts import ROOT, LONG, CAST, CRITTER, underlay, native_tint, record, sha
from ThemeSourceIntegrity import aperture, verify_pixels
from PriestWarlockPack import approved_bridge

loader = importlib.util.spec_from_file_location("case_style", ROOT / "Tools/Check-ThemeAssetStyle.py")
style = importlib.util.module_from_spec(loader)
loader.loader.exec_module(style)


def stage(theme):
    draft = ROOT / "Assets_Draft" / theme / "FullSet"
    contracts = json.loads((ROOT / "Docs/Research_Assets" / theme / "FullSet/Contracts/functional-fields.json").read_text())
    source_manifest = json.loads((draft / "manifest.json").read_text())
    out, review = draft / "Composed", draft / "Review/Composed"
    out.mkdir(parents=True, exist_ok=True)
    review.mkdir(parents=True, exist_ok=True)
    records, checks = {}, []
    for name, item in source_manifest["assets"].items():
        path = ROOT / item["path"]
        assert sha(path) == item["sha256"]
        painting = Image.open(path).convert("RGBA")
        failures = []
        field = contracts["clearance"].get(name)
        if field:
            assert sha(ROOT / field["path"]) == field["sha256"]
            try:
                aperture(painting, Image.open(ROOT / field["path"]), approved_bridge(item))
            except ValueError as error:
                failures.append(str(error))
        piece = {"painting": item, "construction": "whole-painting"}
        image = painting
        if name in LONG + CAST:
            mask = Image.open(ROOT / field["path"]).convert("L").point(lambda a: 255 if a > 128 else 0)
            image = underlay(name, mask)
            piece.update(construction="native-functional-recess", native=record(ROOT / "Assets" / (name + ".tga")), field=field)
            foreground = out / (name + "-over.tga")
            painting.save(foreground, compression=None)
            verify_pixels(painting, Image.open(foreground).convert("RGBA"))
            records[name + "-over"] = {"painting": item, "construction": "whole-painting", **record(foreground)}
        else:
            pane = contracts["nativePanes"].get(name)
            if name in CRITTER:
                pane = field
            if pane:
                assert sha(ROOT / pane["path"]) == pane["sha256"]
                tint = native_tint(name)
                image = Image.alpha_composite(underlay(name, Image.open(ROOT / pane["path"]), tint), painting)
                piece.update(construction="native-under-whole-painting", native=record(ROOT / "Assets" / (name + ".tga")), field=pane, nativeTint=tint)
        target = out / (name + ".tga")
        image.save(target, compression=None)
        verify_pixels(image, Image.open(target).convert("RGBA"))
        records[name] = {**piece, **record(target)}
        complete = Image.alpha_composite(image, painting) if name in LONG + CAST else image
        complete_path = review / (name + ".tga")
        complete.save(complete_path, compression=None)
        geometry, notes = style.check(complete_path)
        checks.append({"name": name, "sourceFailures": failures, "assembledStyleFailures": geometry, "notes": notes})
    manifest = {"schema": 1, "theme": theme, "status": "draft-composition-only", "assets": records,
        "sourceManifest": record(draft / "manifest.json"), "functionalContracts": record(ROOT / "Docs/Research_Assets" / theme / "FullSet/Contracts/functional-fields.json"),
        "productionAccepted": False, "runtimeIntegrated": False, "retailValidated": False, "foreverValidated": False}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (out / "fit-report.json").write_text(json.dumps({"cases": checks, "accepted": False}, indent=2) + "\n")
    print(theme + ": composed " + str(len(records)) + " draft layers; no runtime installation")
    for case in checks:
        if case["sourceFailures"] or case["assembledStyleFailures"]:
            print(case["name"] + ": " + "; ".join(case["sourceFailures"] + case["assembledStyleFailures"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", choices=("Priest", "Warlock", "Both"))
    args = parser.parse_args()
    for theme in ("Priest", "Warlock") if args.theme == "Both" else (args.theme,):
        stage(theme)
