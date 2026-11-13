"""Measure gaps against frozen fills and search intact source registrations.

Offline only. Never changes paintings, masks, layouts or saved settings.
"""
import json
import math

import numpy as np
from PIL import Image, ImageFilter

from PriestWarlockAssetContracts import ROOT, LONG, record
from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import whole_painting, aperture

NAMES = LONG + ("pw_crystal_case", "pw_crystal_case_low")


def gaps(image, fill, crystal=False):
    """Empty texels between the fill and its upper/lower mounting rails.

    Ignore the open top of a crystal and sloping ends of health bars. Keep
    missing rails as failures instead of silently dropping their columns.
    """
    solid = np.asarray(image)[:, :, 3] > 128
    field = np.asarray(fill) > 128
    xs = np.flatnonzero(field.any(axis=0))
    # The open crystal prongs have no enclosing rail at their outer extremes.
    # Measure its actual lower mounting run, separately from those open sides.
    xs = xs[len(xs)//4:len(xs)*3//4] if crystal else xs[len(xs)//5:len(xs)*4//5]
    found = []
    for x in xs:
        ys = np.flatnonzero(field[:, x])
        if not len(ys):
            continue
        for upper in ((False,) if crystal else (True, False)):
            edge = ys[0] if upper else ys[-1]
            rail = np.flatnonzero(solid[:edge+1, x]) if upper else np.flatnonzero(solid[edge:, x]) + edge
            distance = edge-rail[-1] if upper and len(rail) else rail[0]-edge if len(rail) else image.height
            found.append(max(0, int(distance)-1))
    return {"maximumGapPx": max(found), "meanGapPx": float(np.mean(found)),
            "p95GapPx": float(np.percentile(found, 95)), "samples": len(found)}


def search(name, item, fill):
    source = Image.open(ROOT/item["source"]["path"]).convert("RGBA")
    transform = item["transform"]
    current = whole_painting(source, transform, item["canvas"])
    before = gaps(current, fill, name.startswith("pw_"))
    try:
        aperture(current, fill)
        best = {"transform": transform, "gaps": before}
        score = (before["p95GapPx"], before["meanGapPx"])
    except ValueError:
        best = None
        score = (float("inf"), float("inf"))
    crop = transform["crop"]
    interior = np.asarray(fill.filter(ImageFilter.MinFilter(3))) > 128
    native = Image.open(ROOT/"Assets"/(name+".tga")).convert("RGBA")
    toe = lowest_point(native) if name in LONG else None
    oldbox = current.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    seen = set()
    for tenth in range(-100, 101):
        scale = transform["scale"] + tenth/10/(crop[3]-crop[1])
        size = (round((crop[2]-crop[0])*scale), round((crop[3]-crop[1])*scale))
        if size in seen or min(size) < 1:
            continue
        seen.add(size)
        painting = source.crop(crop).resize(size, Image.Resampling.LANCZOS)
        a = np.asarray(painting)[:, :, 3] > 200
        px, py = lowest_point(painting)
        if toe:
            offsets = [(x, int(toe[1]-py)) for x in {math.floor(toe[0]-px), math.ceil(toe[0]-px)} if abs(x+px-toe[0]) <= .5]
        else:
            ox, oy = transform["offset"]
            offsets = [(ox+x, oy+y) for x in range(-6, 7) for y in range(-10, 6)]
        for x, y in offsets:
            if min(x,y)<0 or x+size[0]>current.width or y+size[1]>current.height:
                continue
            if (a & interior[y:y+size[1], x:x+size[0]]).any():
                continue
            candidate_transform = {"crop": crop, "scale": scale, "offset": [x,y]}
            candidate = whole_painting(source, candidate_transform, item["canvas"])
            box = candidate.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
            if any(abs(box[i]-oldbox[i])>max(3,round(current.size[i%2]*.04)) for i in range(4)):
                continue
            measured = gaps(candidate, fill, name.startswith("pw_"))
            trial_score = (measured["p95GapPx"], measured["meanGapPx"])
            if trial_score < score:
                aperture(candidate, fill)
                best = {"transform": candidate_transform, "gaps": measured}
                score = trial_score
    return {"source": item["source"], "before": before, "best": best}


def main():
    folder = ROOT/"Assets_Draft/Priest/FullSet"
    manifest = json.loads((folder/"manifest.json").read_text())
    fields = json.loads((ROOT/"Docs/Research_Assets/Priest/FullSet/Contracts/functional-fields.json").read_text())["clearance"]
    results = {}
    for name in NAMES:
        fill = Image.open(ROOT/fields[name]["path"]).convert("L")
        results[name] = search(name, manifest["assets"][name], fill)
        print(name+": "+str(results[name]), flush=True)
    output = folder/"Review/GapRepair"
    output.mkdir(parents=True, exist_ok=True)
    (output/"registration-search.json").write_text(json.dumps({"tool": record(__file__), "assets": results}, indent=2)+"\n")


if __name__ == "__main__":
    main()
