"""Search bounded uniform whole-painting registrations without changing paint."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import math

import numpy as np
from PIL import Image, ImageFilter

from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import aperture, whole_painting

ROOT = Path(__file__).resolve().parent.parent
loader = importlib.util.spec_from_file_location("source_guides", ROOT / "Tools/Search-PriestWarlockRegistration.py")
guides = importlib.util.module_from_spec(loader)
loader.loader.exec_module(guides)
LONG = ("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def search(source, name, spec, fill):
    crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    target, canvas = spec["painted"], spec["canvas"]
    tolerance = [max(3, round(n * .04)) for n in canvas]
    field = np.asarray(fill.convert("L")) > 128
    interior = np.asarray(fill.convert("L").filter(ImageFilter.MinFilter(3))) > 128
    exact_glass = name in ("orb_case_hi", "orb_case_low")
    native_glass = None
    if exact_glass:
        # Native speculars include opaque pixels. Even translucent new paint
        # changes this functional glass, so its complete field must stay clear.
        from PriestWarlockAssetContracts import underlay
        native_glass = underlay(name, fill, 192/255)
        glass_field = np.asarray(fill.convert("L")) > 0
    toe = lowest_point(Image.open(ROOT / "Assets" / (name + ".tga"))) if name in LONG else None
    best, best_score, trials, passing = None, None, 0, 0
    solid_box = source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    sizes = set()
    for tenth in range(max(4, target[3] - target[1] - 2*tolerance[1])*10, (target[3] - target[1] + 2*tolerance[1])*10 + 1):
        scale = (tenth / 10) / (solid_box[3] - solid_box[1])
        size = (round((crop[2] - crop[0])*scale), round((crop[3] - crop[1])*scale))
        if size in sizes:
            continue
        sizes.add(size)
        painting = source.crop(crop).resize(size, Image.Resampling.LANCZOS)
        height = painting.height
        if painting.width > canvas[0] or painting.height > canvas[1]:
            continue
        alpha = np.asarray(painting)[:, :, 3]
        box = painting.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
        if box is None:
            continue
        lower = [max(0, target[i] - tolerance[i] - box[i], target[i+2] - tolerance[i] - box[i+2]) for i in range(2)]
        upper = [min(canvas[i] - painting.size[i], target[i] + tolerance[i] - box[i], target[i+2] + tolerance[i] - box[i+2]) for i in range(2)]
        if any(lower[i] > upper[i] for i in range(2)):
            continue
        if toe:
            px, py = lowest_point(painting)
            offsets = [(dx, int(toe[1] - py)) for dx in sorted({math.floor(toe[0] - px), math.ceil(toe[0] - px)})]
        else:
            offsets = [(x, y) for x in range(lower[0], upper[0] + 1) for y in range(lower[1], upper[1] + 1)]
        solid = alpha > 200
        for x, y in offsets:
            if not (lower[0] <= x <= upper[0] and lower[1] <= y <= upper[1]):
                continue
            if toe and abs(px + x - toe[0]) > .5:
                continue
            count = int(np.count_nonzero(solid & interior[y:y+height, x:x+painting.width]))
            glass_changed = 0
            if exact_glass:
                expected = native_glass.crop((x,y,x+painting.width,y+height))
                actual = Image.alpha_composite(expected,painting)
                glass_changed = int((np.any(np.asarray(actual)!=np.asarray(expected),axis=2) & glass_field[y:y+height,x:x+painting.width]).sum())
                count += glass_changed
            overlap = int(np.count_nonzero(solid & field[y:y+height, x:x+painting.width])) / int(field.sum())
            passed = count == 0 and overlap <= .20
            found = [box[0] + x, box[1] + y, box[2] + x, box[3] + y]
            distance = sum(abs(found[i] - target[i]) for i in range(4))
            score = (not passed, count, distance, overlap)
            trials += 1
            passing += passed
            if best_score is None or score < best_score:
                best_score = score
                best = {"transform": {"crop": list(crop), "scale": scale, "offset": [x, y]},
                    "bounds": found, "solidFillIntrusionPixels": count, "fillOcclusion": overlap, "passed": passed}
                if exact_glass:
                    best["nativeGlassChangedPixels"] = glass_changed
    if best:
        candidate = whole_painting(source, best["transform"], canvas)
        try:
            aperture(candidate, fill)
            assert best["passed"]
        except (ValueError, AssertionError):
            best["passed"] = False
    return {"legalTrials": trials, "passingTrials": int(passing), "best": best}


def main(theme):
    doc = ROOT / "Docs/Research_Assets" / theme / "FullSet"
    out = ROOT / "Assets_Draft" / theme / "FullSet"
    review = out / "Review"
    review.mkdir(parents=True, exist_ok=True)
    jobs = json.loads((doc / "jobs.json").read_text(encoding="utf-8"))["jobs"]
    contracts_path = doc / "Contracts/functional-fields.json"
    fields = json.loads(contracts_path.read_text())["clearance"] if contracts_path.exists() else {}
    algorithm = sha(Path(__file__))
    cache_path = out / "registration-search.json"
    cache = json.loads(cache_path.read_text())["assets"] if cache_path.exists() else {}
    results = {}
    for job in jobs:
        name = job["name"]
        mask = ROOT / fields[name]["path"] if name in fields else ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")
        if name in fields:
            assert sha(mask) == fields[name]["sha256"], "Frozen functional mask changed"
        if job["status"] != "done" or not mask.exists() or "painted" not in job["geometry"] or "transform" in job:
            continue
        source_path = ROOT / job["source"]
        assert sha(source_path) == job["sourceSha256"]
        if job.get("qualityStatus", "").startswith("rejected"):
            print(theme + "/" + name + ": rejected source retained; no fit search")
            continue
        prior = cache.get(name)
        if prior and prior.get("algorithmSha256") == algorithm and prior["sourceSha256"] == sha(source_path) and prior["fillMaskSha256"] == sha(mask):
            guide = prior.get("sourceGuide")
            if not guide or ((ROOT / guide["path"]).exists() and sha(ROOT / guide["path"]) == guide["sha256"]):
                results[name] = prior
                print(theme + "/" + name + ": unchanged source/mask/algorithm; retained verified search", flush=True)
                continue
        source, fill = Image.open(source_path).convert("RGBA"), Image.open(mask).convert("L")
        result = search(source, name, job["geometry"], fill)
        result.update(source=job["source"], sourceSha256=sha(source_path), fillMaskSha256=sha(mask), algorithmSha256=algorithm)
        if result["best"]:
            path = review / (name + "-" + sha(source_path)[:12] + "-" + sha(mask)[:8] + "-source-aperture-guide.png")
            guides.source_guide(source, fill, result["best"]["transform"], path)
            result["sourceGuide"] = {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)}
        results[name] = result
        print(theme + "/" + name + ": " + str(result["passingTrials"]) + " passing registrations; best=" + str(result["best"] and result["best"]["solidFillIntrusionPixels"]), flush=True)
    (out / "registration-search.json").write_text(json.dumps({"schema": 1, "scope": "uniform scales at 0.1 solid-height-pixel intervals, unique rounded dimensions, integer translations inside existing native bounds tolerance; whole paintings only", "assets": results}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", choices=("Priest", "Warlock", "Both"))
    args = parser.parse_args()
    for theme in ("Priest", "Warlock") if args.theme == "Both" else (args.theme,):
        main(theme)
