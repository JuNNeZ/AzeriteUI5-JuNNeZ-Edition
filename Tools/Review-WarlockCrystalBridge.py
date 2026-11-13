"""Review native-shaped crystal lips as explicit foreground bridges, never install.

The native casing already crosses the fill. Preserve a new whole painting and
measure its exact crossing mask for maintainer review instead of erasing it.
"""
import importlib.util
import json

import numpy as np
from PIL import Image, ImageFilter, ImageDraw

from PriestWarlockAssetContracts import ROOT, record, projection, underlay, native_tint
from ThemeSourceIntegrity import whole_painting

spec = importlib.util.spec_from_file_location("warlock_gaps", ROOT / "Tools/Repair-WarlockGaps.py")
gaps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gaps)


def review(name):
    folder = ROOT / "Assets_Draft/Warlock/FullSet/Review/GapRepair"
    source_path = folder / "pw_crystal_case-native-repaint-v1.png"
    source = Image.open(source_path).convert("RGBA")
    crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    body = source.crop(crop)
    native = Image.open(ROOT / "Assets" / (name+".tga")).convert("RGBA")
    box = native.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    contracts = json.loads((ROOT / "Docs/Research_Assets/Warlock/FullSet/Contracts/functional-fields.json").read_text())
    field = np.asarray(Image.open(ROOT / contracts["clearance"][name]["path"]).convert("L")) > 128
    native_solid = native.getchannel("A").point(lambda a: 255 if a > 200 else 0)
    # Allow the new facets three pixels around the original foreground lips,
    # solely for REVIEW. This creates no approval or runtime exception.
    native_band = np.asarray(native_solid.filter(ImageFilter.MaxFilter(7))) > 0
    best = None
    best_score = (float("inf"),) * 4
    seen = set()
    for tenth in range(600, 801):
        scale = tenth / 10 / body.height
        size = (round(body.width*scale), round(body.height*scale))
        if size in seen:
            continue
        seen.add(size)
        painting = body.resize(size, Image.Resampling.LANCZOS)
        alpha = np.asarray(painting)[:, :, 3]
        for x in range(30, 47):
            for y in range(14, 30):
                if x+size[0] > native.width or y+size[1] > native.height:
                    continue
                solid = np.zeros(field.shape, dtype=bool)
                solid[y:y+size[1], x:x+size[0]] = alpha > 200
                crossing = solid & field
                if (crossing & ~native_band).any() or crossing.sum()/field.sum() > .20:
                    continue
                full_alpha = np.zeros(field.shape, dtype="uint8")
                full_alpha[y:y+size[1], x:x+size[0]] = alpha
                found = painting.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
                bounds = (x+found[0], y+found[1], x+found[2], y+found[3])
                if any(abs(bounds[i]-box[i]) > round(native.size[i%2]*.04) for i in range(4)):
                    continue
                measured = gaps.metrics(full_alpha, field, True)
                score = (measured["maximumGapPx"], measured["p95GapPx"], measured["meanGapPx"], int(crossing.sum()))
                if score < best_score:
                    best_score = score
                    best = {"transform": {"crop": list(crop), "scale": scale, "offset": [x, y]},
                            "gaps": measured, "crossingPixels": int(crossing.sum()),
                            "clippedFillOcclusion": float(crossing.sum()/field.sum())}
    assert best, "No bounded native-shaped bridge preview"
    image = whole_painting(source, best["transform"], native.size)
    target = folder / (name+"-bridge-preview.png")
    image.save(target)
    crossing = (np.asarray(image)[:, :, 3] > 200) & field
    bridge = folder / (name+"-bridge-mask.png")
    Image.fromarray(crossing.astype("uint8")*255).save(bridge)
    best.update(source=record(source_path), export=record(target), bridge=record(bridge),
                native=record(ROOT / "Assets" / (name+".tga")), maintainerApproved=False,
                installed=False, geometryAuthority="maintainer approved native geometry guide 2026-11-08")
    (folder / (name+"-bridge-preview.json")).write_text(json.dumps(best, indent=2)+"\n")
    print(name + ": pending foreground review " + str(best))


def assemblies():
    spec = importlib.util.spec_from_file_location("warlock_scene", ROOT / "Tools/Build-ThemeConceptBase.py")
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    base.DATA = json.loads((ROOT / "Docs/Research_Assets/PriestWarlock-layouts-current.json").read_text())["original"]
    folder = ROOT / "Assets_Draft/Warlock/FullSet/Review/GapRepair"
    fields = json.loads((ROOT / "Docs/Research_Assets/Warlock/FullSet/Contracts/functional-fields.json").read_text())
    board = Image.new("RGBA", (1280, 820), "#30363b")
    draw = ImageDraw.Draw(board)
    draw.text((15, 12), "INSTALLED (left) / NATIVE-SHAPED CRYSTAL PROPOSAL (right) / offline 1x, same fill and anchors", fill="white")
    for row, (tier, name) in enumerate((("Seasoned", "pw_crystal_case"), ("Novice", "pw_crystal_case_low"))):
        db = dict(base.DATA["PlayerFrame"])
        db.update(db[tier])
        scenes = []
        for proposed in (False, True):
            scene = Image.new("RGBA", (1200, 400))
            owner = (300, 80, *base.DATA["PlayerFrame"]["Size"])
            hp = base.anchor(owner, db["HealthBarSize"], db["HealthBarPosition"])
            rect = base.anchor(owner, db["HealthBackdropSize"], db["HealthBackdropPosition"])
            case_name = db["HealthBackdropTexture"].replace("\\", "/").rsplit("/", 1)[-1]
            def installed(texture):
                return Image.open(ROOT / "Assets/Warlock" / texture).convert("RGBA")
            base.put(scene, installed(case_name), rect)
            base.fill(scene, db["HealthBarTexture"], hp, 1, base.DARK)
            base.fill(scene, db["HealthBarTexture"], hp, .65, base.RED)
            base.put(scene, installed(case_name.removesuffix(".tga")+"-over.tga"), rect)
            base.put(scene, installed("ornament-ulthalesh-"+case_name), rect)
            bar = base.anchor(owner, db["PowerBackdropSize"], db["PowerBarPosition"])
            _, local = projection().crystal_rects(db)
            case = (bar[0]+local[0], bar[1]+local[1], *local[2:])
            base.put(scene, base.asset(db["PowerBackdropTexture"]), bar)
            base.fill(scene, db["PowerBarTexture"], bar, 1, (.25, .4, .95), vertical=True)
            front = installed(name+".tga")
            if proposed:
                pane = Image.open(ROOT / fields["nativePanes"][name]["path"]).convert("L")
                native = np.asarray(Image.open(ROOT / "Assets" / (name+".tga")).convert("RGBA"))
                # Exact original black functional shading, including the two
                # shadow texels between native fill and the physical seat.
                shadow = (native[:, :, :3] == 0).all(axis=2) & (native[:, :, 3] > 0)
                mask = Image.fromarray(((np.asarray(pane)>0) | shadow).astype("uint8")*255)
                mask_path = folder / (name+"-proposed-native-pane.png")
                mask.save(mask_path)
                front = Image.alpha_composite(underlay(name, mask, native_tint(name)), Image.open(folder / (name+"-bridge-preview.png")).convert("RGBA"))
            base.put(scene, front, case)
            base.put(scene, installed("resource-badge.tga"), (case[0]+case[2]/2-16, case[1]+case[3]*.56-16, 32, 32))
            scenes.append(scene)
        # Fixed union viewport; preserve identical rail origin in both states.
        box = Image.alpha_composite(*scenes).getbbox()
        assert box and box[2]-box[0] < 620
        for column, scene in enumerate(scenes):
            x, y = 15+column*640, 70+row*380
            draw.text((x, y-23), tier + (" / proposed, not installed" if column else " / installed"), fill="white")
            board.alpha_composite(scene.crop(box), (x, y))
    board.convert("RGB").save(folder / "crystal-native-proposal-1x.png")
    board.resize((2560, 1640), Image.Resampling.NEAREST).convert("RGB").save(folder / "crystal-native-proposal-2x.png")


if __name__ == "__main__":
    frozen = ROOT / "Assets_Draft/Warlock/FullSet/Review/GapRepair"
    if list(frozen.glob("*-bridge-approval.json")):
        raise SystemExit("This crystal proposal is approved and frozen; use a new revision folder for another proposal")
    for name in ("pw_crystal_case", "pw_crystal_case_low"):
        review(name)
    assemblies()
