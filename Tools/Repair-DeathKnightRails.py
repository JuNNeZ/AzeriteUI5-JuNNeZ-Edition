"""Fit a corrected whole DK rail painting; never stencil its aperture.

Stages one representative case. Installation remains separate from generation.
"""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import aperture, sha, verify_pack, verify_pixels, whole_painting, checked_file

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets_Draft/DeathKnight/Rail-Repair-2026-11-14"
SPEC = json.loads((ROOT / "Docs/Theme Asset Geometry.json").read_text())
spec = importlib.util.spec_from_file_location("style", ROOT / "Tools/Check-ThemeAssetStyle.py")
style = importlib.util.module_from_spec(spec)
spec.loader.exec_module(style)


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def record(path):
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)}


def contour_grid(image, fill, axis, soft_contact=False, contact_size=1.25):
    """Measure own lip crossings and emit numeric, full-line control points.

    The replay consumes only these points and original RGBA, not a fill mask.
    """
    alpha = np.asarray(image)[:, :, 3]
    field = np.asarray(fill.convert('L')) > 128
    if axis == 'y':
        alpha, field = alpha.T, field.T
    sources, targets = [], []
    for paint, row in zip(alpha, field):
        extent = len(paint)-1
        source, target = [0, extent], [0, extent]
        required = np.flatnonzero(row)
        solid = np.flatnonzero(paint>128)
        if len(required) and len(solid):
            center = int(np.median(required))
            if paint[center] <= 128:
                left, right = center, center
                while left>0 and paint[left-1]<=128: left -= 1
                while right<extent and paint[right+1]<=128: right += 1
                initial_left, initial_right = left, right
                # Register to the continuous painted lip, not an isolated AA
                # fleck in front of it. This changes measurement only; all
                # original RGBA (including those flecks) is still resampled.
                while left>4 and np.any(paint[left-3:left]<=128):
                    left = left-3+int(np.flatnonzero(paint[left-3:left]<=128)[0])
                while right<extent-4 and np.any(paint[right+1:right+4]<=128):
                    right = right+1+int(np.flatnonzero(paint[right+1:right+4]<=128)[-1])
                while left>0 and paint[left-1]<=128: left -= 1
                while right<extent and paint[right+1]<=128: right += 1
                if left>0 and right<extent:
                    a = left-1+(float(paint[left-1])-128)/(float(paint[left-1])-float(paint[left]))
                    b = right+(128-float(paint[right]))/(float(paint[right+1])-float(paint[right]))
                    il, ir = initial_left, initial_right
                    inner_a = il-1+(float(paint[il-1])-128)/(float(paint[il-1])-float(paint[il]))
                    inner_b = ir+(128-float(paint[ir]))/(float(paint[ir+1])-float(paint[ir]))
                    outer_left, outer_right = int(solid[0]), int(solid[-1])
                    source = [0, outer_left, a, inner_a, inner_b, b, outer_right, extent]
                    # Preserve contour flecks in the subpixel AA join instead
                    # of transporting them into the functional fill interior.
                    target = [0, min(outer_left, int(required[0])-2), float(required[0])-.5,
                        float(required[0])-.25, float(required[-1])+.25, float(required[-1])+.5,
                        max(outer_right, int(required[-1])+2), extent]
                    contact = min(contact_size, max(0, (int(required[-1])-int(required[0])-1)/4))
                    target[2] += contact; target[3] += contact
                    target[4] -= contact; target[5] -= contact
                    if soft_contact:
                        # Preserve and register the original opacity ramp too:
                        # the native widget's filtered edge needs coverage,
                        # while solid metal must stay outside the fill.
                        l200 = left-1
                        while l200>outer_left and paint[l200]<=200: l200 -= 1
                        r200 = right+1
                        while r200<outer_right and paint[r200]<=200: r200 += 1
                        if l200<left-1 and r200>right+1:
                            a200 = l200+(float(paint[l200])-200)/(float(paint[l200])-float(paint[l200+1]))
                            b200 = r200-1+(200-float(paint[r200-1]))/(float(paint[r200])-float(paint[r200-1]))
                            source = [0, outer_left, a200, a, inner_a, inner_b, b, b200, outer_right, extent]
                            target = [0, min(outer_left, int(required[0])-3), float(required[0])-.75,
                                float(required[0])+1.5, float(required[0])+1.75,
                                float(required[-1])-1.75, float(required[-1])-1.5,
                                float(required[-1])+.75, max(outer_right, int(required[-1])+3), extent]
                    unique = [i for i in range(len(source)) if i == 0 or abs(source[i]-source[i-1]) > 1e-8]
                    source, target = [source[i] for i in unique], [target[i] for i in unique]
                    if (not (np.diff(source)>0).all() or not (np.diff(target)>0).all()
                            or np.max(np.abs(np.asarray(source)-target)) > (32 if axis == 'y' else 64)):
                        source, target = [0, extent], [0, extent]
        sources.append(source); targets.append(target)
    return {'axis': axis, 'sourceKnots': sources, 'targetKnots': targets}


def render(folder, name, candidate):
    from DeathKnightRailSource import target_recess
    native_name = name.removesuffix('-target')
    spec = importlib.util.spec_from_file_location("native", ROOT / "Tools/Build-ThemeConceptBase.py")
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    originals = json.loads((ROOT / "Assets_Draft/DeathKnight/FullSet/manifest.json").read_text())["assets"]
    tier = {"hp_cap_case": "Seasoned", "hp_mid_case": "Hardened", "hp_low_case": "Novice", "hp_boss_case": "Boss"}[native_name]
    kinds = ("TargetFrame",) if tier == "Boss" or name.endswith('-target') else ("PlayerFrame",)
    font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)
    for ornament in ("none", "frost", "unholy"):
        board = Image.new("RGBA", (2200, len(kinds)*3*320+60), "#14161a")
        draw = ImageDraw.Draw(board)
        draw.text((20, 12), f"OFFLINE / {name} / {ornament} / fixed native origins / old - candidate", font=font, fill="white")
        for ki, kind in enumerate(kinds):
            db = dict(base.DATA[kind]); db.update(db[tier])
            owner = (250, 120, *base.DATA[kind]["Size"])
            rect = base.anchor(owner, db["HealthBackdropSize"], db["HealthBackdropPosition"])
            hp = base.anchor(owner, db["HealthBarSize"], db["HealthBarPosition"])
            flip = kind == "TargetFrame"
            for fi, fraction in enumerate((0, .5, 1)):
                row = ki*3+fi
                for column in range(2):
                    scene = Image.new("RGBA", (1100, 320))
                    back = target_recess(name,ROOT) if name.endswith('-target') else Image.open(ROOT / "Assets/DeathKnight" / (name+".tga")).convert("RGBA")
                    previous = OUT / "Rejected-live-gap" / (name+"-over.tga")
                    old_path = previous if previous.exists() else checked_file(originals[native_name], ROOT)
                    front = candidate if column else Image.open(old_path).convert("RGBA")
                    base.put(scene, back, rect, flip)
                    base.fill(scene, db["HealthBarTexture"], hp, 1, base.DARK, flip)
                    # A coloured prediction segment beneath the foreground.
                    if fraction == .5:
                        base.fill(scene, db["HealthBarTexture"], hp, .7, (.1, .65, .35), flip)
                    base.fill(scene, db["HealthBarTexture"], hp, fraction, base.RED, flip)
                    base.put(scene, front, rect, flip)
                    if ornament != "none":
                        cap = Image.open(ROOT / "Assets/DeathKnight" / ("ornament-"+ornament+"-"+native_name+".tga")).convert("RGBA")
                        base.put(scene, cap, rect, flip)
                    box = scene.getbbox()
                    assert box and box[0] > 0 and box[1] > 0 and box[2] < 1100 and box[3] < 320, "Review clipped"
                    board.alpha_composite(scene, (column*1100, row*320+60))
                    draw.text((column*1100+20, row*320+65), f"{kind} {tier} {fraction:.0%}" + (" / candidate" if column else " / old"), font=font, fill="white")
        board.convert("RGB").save(folder / ("complete-"+ornament+"-1x.png"))
        board.resize((board.width*2,board.height*2),Image.Resampling.NEAREST).convert("RGB").save(folder / ("complete-"+ornament+"-2x.png"))


def fit(source, name):
    """Search whole-source uniform registration around the native mounting toe."""
    native = Image.open(ROOT / "Assets" / (name + ".tga")).convert("RGBA")
    target = SPEC[name]
    mask = Image.open(ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png"))
    interior = np.asarray(mask.convert("L").filter(ImageFilter.MinFilter(3))) > 128
    crop = source.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    solid = source.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()
    factor = (target["painted"][2] - target["painted"][0]) / (solid[2] - solid[0])
    tx, ty = lowest_point(native)
    best = None
    for scale in np.linspace(factor * .85, factor * 1.15, 151):
        paint = source.crop(crop).resize((round((crop[2]-crop[0])*scale), round((crop[3]-crop[1])*scale)), Image.Resampling.LANCZOS)
        px, py = lowest_point(paint)
        transform = {"crop": list(crop), "scale": float(scale), "offset": [round(tx-px), round(ty-py)]}
        try:
            image = whole_painting(source, transform, native.size)
        except ValueError:
            continue
        box = image.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()
        errors = []
        for i in range(4):
            if abs(box[i]-target["painted"][i]) > max(3, round(native.size[i % 2]*.04)):
                errors.append("Painted exterior differs from native bounds")
        point = lowest_point(image)
        if abs(point[0]-tx) > .5 or point[1] != ty:
            errors.append("Mounting toe differs from native")
        hole = style.hole(image)
        meter = target["meter"]
        if not hole or hole[0] > meter[0]+2 or hole[1] > meter[1]+2 or hole[2] < meter[2]-2 or hole[3] < meter[3]-2:
            errors.append("Opening covers meter")
        if hole and (hole[1] < meter[1]-8 or hole[3] > meter[3]+8):
            errors.append("Opening leaves a gap above/below meter")
        try:
            aperture(image, mask)
        except ValueError as error:
            errors.append(str(error))
        obstruction = int(((np.asarray(image)[:, :, 3] > 200) & interior).sum())
        score = (len(errors), obstruction, sum(abs(box[i]-target["painted"][i]) for i in range(4)))
        if best is None or score < best[0]:
            best = (score, image, transform, {"errors": errors, "painted": list(box), "opening": list(hole) if hole else None,
                "nativeToe": [tx, ty], "toe": list(point), "solidFillInteriorPixels": obstruction})
    if best is None:
        raise ValueError("No unclipped uniform placement")
    return best[1:]


def assemble():
    from DeathKnightRailSource import build, CASES, TARGET_CASES, validate_gap, fill_field, target_recess
    folder = OUT / "Assembly"
    folder.mkdir(parents=True, exist_ok=True)
    authority = ROOT / "Assets_Draft/DeathKnight/FullSet/manifest.json"
    originals = json.loads(authority.read_text())["assets"]
    recipe = {"schema": "deathknight-rail-grid-1", "authority": record(authority), "cases": {}}
    for name in CASES+TARGET_CASES:
        native_name = name.removesuffix('-target')
        image = Image.open(checked_file(originals[native_name], ROOT)).convert("RGBA")
        hole, target = style.hole(image), SPEC[native_name]
        bounds = image.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
        toe = lowest_point(image)
        meter = target["meter"]
        own_alpha = np.asarray(image)[:, :, 3]
        own_center = (hole[0]+hole[2])//2
        own_rows = np.flatnonzero(own_alpha[hole[1]:hole[3], own_center] < 64)+hole[1]
        knots = [0, bounds[1], int(own_rows[0]), int(own_rows[-1])+1, toe[1], 255]
        # These analytic control lines reposition the painted rails. No native
        # mask participates in the construction or modifies painting alpha.
        field = np.asarray(fill_field(name, ROOT)) > 128
        center_rows = np.flatnonzero(field[:, (meter[0]+meter[2])//2])
        # The full texture rectangle includes transparent padding below the
        # straight run. Retain the deeper shaped terminal only near the end.
        flat_bottom = int(center_rows[-1])+3
        cross = [0, hole[0], hole[0]+(90 if name == "hp_boss_case" else 30), hole[2]-50, hole[2]-20, hole[2], 1023]
        bottoms = [meter[3]+(4 if name == "hp_boss_case" else 3)]*2 + [flat_bottom]*2 + [meter[3]+3]*3
        destinations = [0, target["painted"][1], meter[1]-3, None, toe[1], 255]
        vertical = {"axis": "y", "cross": cross, "knots": knots,
            "delta": [[(bottoms[i] if d is None else d)-k for i in range(len(cross))] for k, d in zip(knots, destinations)]}
        knots = [0, bounds[0], hole[0], hole[2], bounds[2], 1023]
        destinations = [0, target["painted"][0], meter[0]-3, meter[2]+3, target["painted"][2], 1023]
        horizontal = {"axis": "x", "cross": [0, meter[3]+4, toe[1]-3, toe[1], 255], "knots": knots,
            "delta": [[(d-k)*weight for weight in (1, 1, 0, 0, 0)] for k, d in zip(knots, destinations)]}
        operations = [vertical, horizontal]
        from DeathKnightRailSource import grid
        initial = grid(grid(image, vertical), horizontal)
        fill = fill_field(name, ROOT)
        from DeathKnightRailSource import validate_projection
        contacts = (1.25,1.3125,1.375,1.4375,1.5,1.5625,1.625,1.1875) if name.endswith('-target') else (1.25,)
        failure = None
        for contact in contacts:
            operations = [vertical,horizontal]
            placed = initial
            for axis in ('y', 'x')*6:
                soft_contact = (name in ('hp_mid_case-target', 'hp_low_case-target')
                    or (name == 'hp_boss_case' and axis == 'x'))
                operation = contour_grid(placed, fill, axis, soft_contact, contact)
                operations.append(operation)
                placed = grid(placed, operation)
            try:
                aperture(placed,fill)
                validate_gap(placed,fill)
                validate_projection(placed,name,ROOT)
                failure = None
                print(name+': source and 1x/2x projection PASS',flush=True)
                break
            except ValueError as error:
                failure = error
        if failure is not None:
            raise failure
        recipe["cases"][name] = operations
    recipe_path = folder / "recipe.json"
    write(recipe_path, recipe)
    images = build(recipe, ROOT)
    assets, proof, metrics = {}, {}, {}
    for name, image in images.items():
        source, export = folder / (name+".png"), folder / (name+".tga")
        image.save(source); image.save(export, compression=None)
        verify_pixels(image, Image.open(export).convert("RGBA"))
        assets[name] = record(export)
        proof[name] = {"role": "deathknight-rail-grid-1", "source": record(source),
            "transform": {"scale": 1, "offset": [0, 0]}, "construction": record(recipe_path)}
        base = name[:-5]
        native_name = base.removesuffix('-target')
        mask = fill_field(base, ROOT)
        aperture(image, mask)
        field = np.asarray(mask) > 128
        pixels = np.asarray(image)[:, :, 3] > 200
        original = Image.open(checked_file(originals[native_name], ROOT)).convert("RGBA")
        old_pixels = np.asarray(original)[:, :, 3] > 200
        metrics[base] = {"nativeToe": list(lowest_point(Image.open(ROOT / "Assets" / (native_name+".tga")))),
            "toe": list(lowest_point(image)), "oldFillOcclusion": float(old_pixels[field].mean()),
            "newFillOcclusion": float(pixels[field].mean()), "solidFillInteriorPixels": 0,
            "sourcePainting": originals[native_name]["source"], **validate_gap(image, mask)}
        render(folder, base, image)
        # Keep per-case image names: render() uses the same fixed names.
        for path in list(folder.glob("complete-*.png")):
            path.replace(folder / (base+"-"+path.name))
    for name in TARGET_CASES:
        path = folder/(name+'.tga')
        target_recess(name,ROOT).save(path,compression=None)
        assets[name] = record(path)
        proof[name] = {'role':'deathknight-target-recess-1', 'source':record(ROOT/'Assets'/(name.removesuffix('-target')+'.tga'))}
    write(folder / "manifest.json", {"schema": 1, "assets": assets})
    write(folder / "source-integrity.json", {"schema": 1, "assetManifestSha256": sha(folder / "manifest.json"), "paintings": proof})
    gate = verify_pack(folder)
    report = {"sourceGate": gate, "cases": metrics, "healthAperturesPassed": True,
        "endcapFitAccepted": False, "productionAccepted": False, "liveValidated": False}
    write(folder / "fit-report.json", report)
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--assemble", action="store_true", help="Replay authorized original-source rail grids")
    parser.add_argument("--case", choices=("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case"), default="hp_low_case")
    args = parser.parse_args()
    if args.assemble:
        assemble()
        return
    if not args.source:
        parser.error("Choose --source or --assemble")
    folder = OUT / args.case
    folder.mkdir(parents=True, exist_ok=True)
    source_path = args.source.resolve()
    image, transform, result = fit(Image.open(source_path).convert("RGBA"), args.case)
    path = folder / (args.case + "-over.tga")
    image.save(path, compression=None)
    verify_pixels(image, Image.open(path).convert("RGBA"))
    write(folder / "manifest.json", {"schema": 1, "assets": {path.stem: record(path)}})
    write(folder / "source-integrity.json", {"schema": 1, "assetManifestSha256": sha(folder / "manifest.json"),
        "paintings": {path.stem: {"role": "painting", "source": record(source_path), "transform": transform}}})
    try:
        verify_pack(folder)
        result["sourceGatePassed"] = True
    except (ValueError, AssertionError) as error:
        result["sourceGatePassed"] = False
        result["errors"].append(str(error))
    result["errors"] = list(dict.fromkeys(result["errors"]))
    result.update(source=record(source_path), transform=transform, passed=not result["errors"], installed=False)
    render(folder, args.case, image)
    write(folder / "fit-report.json", result)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
