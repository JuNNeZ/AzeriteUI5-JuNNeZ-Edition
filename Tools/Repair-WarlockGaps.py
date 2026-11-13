"""Search intact Warlock paintings for close rails without changing native fills.

Produces review candidates only. No alpha edits, layout changes or installation.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from PriestWarlockAssetContracts import ROOT, LONG, record
from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import whole_painting, aperture
from PriestWarlockFitTolerance import edge_distance, LIMIT

FOLDER = ROOT / "Assets_Draft/Warlock/FullSet"
NAMES = LONG + ("pw_crystal_case", "pw_crystal_case_low")


def gap_samples(alpha, field, crystal=False):
    solid = alpha > 128
    xs = np.flatnonzero(field.any(axis=0))
    if not crystal:
        xs = xs[len(xs)//5:len(xs)*4//5]
    columns = field[:, xs]
    upper = columns.argmax(axis=0)
    lower = field.shape[0] - 1 - columns[::-1].argmax(axis=0)
    yy = np.arange(field.shape[0])[:, None]
    below = np.where(solid[:, xs] & (yy >= lower), yy, field.shape[0]).min(axis=0)
    gaps = np.maximum(0, below - lower - 1)
    if not crystal:
        above = np.where(solid[:, xs] & (yy <= upper), yy, -1).max(axis=0)
        gaps = np.concatenate((gaps, np.maximum(0, upper - above - 1)))
    return gaps


def metrics(alpha, field, crystal=False):
    samples = gap_samples(alpha, field, crystal)
    return {"maximumGapPx": int(samples.max()), "p95GapPx": float(np.percentile(samples, 95)),
            "meanGapPx": float(samples.mean())}


def search(name, extra=None):
    manifest = json.loads((FOLDER / "manifest.json").read_text())["assets"]
    item = manifest[name]
    contracts = json.loads((ROOT / "Docs/Research_Assets/Warlock/FullSet/Contracts/functional-fields.json").read_text())
    fill = Image.open(ROOT / contracts["clearance"][name]["path"]).convert("L")
    field = np.asarray(fill) > 128
    interior = np.asarray(fill.filter(ImageFilter.MinFilter(3))) > 128
    current = Image.open(ROOT / item["path"]).convert("RGBA")
    # Only the boss opening participates in the existing pack-specific edge
    # exception. Record its exact new painting/export binding before install.
    boss_depth = LIMIT if name == "hp_boss_case" else 0
    before = metrics(np.asarray(current)[:, :, 3], field, name.startswith("pw_"))
    native = Image.open(ROOT / "Assets" / (name + ".tga")).convert("RGBA")
    oldbox = native.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    paths = [ROOT / item["source"]["path"]]
    if extra:
        paths.append(Path(extra).resolve())
    else:
        paths += sorted((FOLDER / "Revisions").glob(name + "-v*.png"))
        paths += sorted((FOLDER / "Sources").glob(name + ".png"))
    best, best_score = None, (float("inf"),) * 3
    nearest, nearest_score = None, (float("inf"),) * 4
    toe = lowest_point(Image.open(ROOT / "Assets" / (name + ".tga"))) if name in LONG else None
    cap_toe = lowest_point(Image.open(FOLDER / "Endcaps" / ("ornament-ulthalesh-"+name+".tga"))) if toe else None
    for path in dict.fromkeys(paths):
        source = Image.open(path).convert("RGBA")
        crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if not crop:
            continue
        body = source.crop(crop)
        # Preserve the native exterior envelope and search uniform scale only.
        seen = set()
        for tenth in range(max(1, oldbox[3]-oldbox[1]-12)*10, (oldbox[3]-oldbox[1]+13)*10):
            height = tenth / 10
            scale = height / body.height
            size = (round(body.width*scale), round(body.height*scale))
            if size in seen:
                continue
            seen.add(size)
            painting = body.resize(size, Image.Resampling.LANCZOS)
            alpha = np.asarray(painting)[:, :, 3]
            box = painting.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
            if not box:
                continue
            if toe:
                px, py = lowest_point(painting)
                offsets = [(x, int(toe[1]-py)) for x in {math.floor(toe[0]-px), math.ceil(toe[0]-px)}
                           if abs(x+px-toe[0]) <= .5 and abs(x+px-cap_toe[0]) <= .5]
            else:
                centre_x = round((oldbox[0]+oldbox[2]-size[0])/2)
                centre_y = round((oldbox[1]+oldbox[3]-size[1])/2)
                offsets = [(x, y) for x in range(centre_x-8, centre_x+9) for y in range(centre_y-16, centre_y+9)]
            for x, y in offsets:
                if min(x, y) < 0 or x+size[0] > current.width or y+size[1] > current.height:
                    continue
                found = (x+box[0], y+box[1], x+box[2], y+box[3])
                if any(abs(found[i]-oldbox[i]) > max(3, round(current.size[i%2]*.04)) for i in range(4)):
                    continue
                intrusion = int(((alpha > 200) & interior[y:y+size[1], x:x+size[0]]).sum())
                depth = 0
                if intrusion:
                    trial_score = (intrusion, abs(size[0]-(oldbox[2]-oldbox[0])), abs(size[1]-(oldbox[3]-oldbox[1])), x)
                    if trial_score < nearest_score:
                        nearest_score = trial_score
                        nearest = {"source": record(path), "solidIntrusionPixels": intrusion,
                                   "transform": {"crop": list(crop), "scale": scale, "offset": [x, y]}}
                    if name != "hp_boss_case":
                        continue
                    query = np.zeros(field.shape, dtype=bool)
                    query[y:y+size[1], x:x+size[0]] = (alpha > 200) & interior[y:y+size[1], x:x+size[0]]
                    try:
                        depth = edge_distance(~field, query)
                    except AssertionError:
                        continue
                    if depth > boss_depth or intrusion / field.sum() > .20:
                        continue
                canvas = np.zeros(field.shape, dtype="uint8")
                canvas[y:y+size[1], x:x+size[0]] = alpha
                measured = metrics(canvas, field, toe is None)
                score = (measured["maximumGapPx"], measured["p95GapPx"], measured["meanGapPx"])
                if score >= best_score:
                    continue
                transform = {"crop": list(crop), "scale": scale, "offset": [x, y]}
                expected = whole_painting(source, transform, current.size)
                if not intrusion:
                    aperture(expected, fill)
                best = {"source": record(path), "transform": transform, "gaps": measured,
                        "strictAperturePassed": not intrusion, "maximumIntrusionEdgeDistancePx": depth}
                best_score = score
    result = {"before": before, "original": item, "best": best, "rejectedNearest": nearest}
    output = FOLDER / "Review/GapRepair"
    output.mkdir(parents=True, exist_ok=True)
    (output / (name + "-search.json")).write_text(json.dumps(result, indent=2)+"\n")
    if best:
        whole_painting(Image.open(ROOT / best["source"]["path"]).convert("RGBA"), best["transform"], current.size).save(output / (name + "-candidate.png"))
    print(name + ": " + str(before) + " -> " + str(best), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", choices=NAMES + ("all",))
    parser.add_argument("--source")
    args = parser.parse_args()
    for name in NAMES if args.name == "all" else (args.name,):
        search(name, args.source)
