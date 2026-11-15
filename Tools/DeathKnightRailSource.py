"""Explicitly authorized own-painting rail assembly, without aperture erasure.

Monotonic grids move/resample the original rail RGBA. Functional masks are
validation inputs only; this construction cannot load or stencil with them.
"""
import json
import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from RogueSerratedMorph import morph_mount
from ThemeSourceIntegrity import checked_file, read, verify_pixels, whole_painting

CASES = ("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case")
TARGET_CASES = tuple(name+'-target' for name in CASES[:3])


def fill_field(name, root):
    if name in TARGET_CASES:
        base = name.removesuffix('-target')
        tier = dict(zip(CASES[:3], ('Seasoned', 'Hardened', 'Novice')))[base]
        layout = json.loads((Path(root)/'Docs/Research_Assets/Paladin/Revision5/layouts.json').read_text())['original']['TargetFrame']
        config = {**layout, **layout[tier]}
        def anchor(size, position):
            width, height = layout['Size']; sw, sh = size
            point, dx, dy = position
            fx = 0 if 'LEFT' in point else 1 if 'RIGHT' in point else .5
            fy = 0 if 'TOP' in point else 1 if 'BOTTOM' in point else .5
            return fx*(width-sw)+dx, fy*(height-sh)-dy, sw, sh
        hp = anchor(config['HealthBarSize'], config['HealthBarPosition'])
        case = anchor(config['HealthBackdropSize'], config['HealthBackdropPosition'])
        # Match the separate pixel placement of the native fill and casing;
        # rounding only their relative offset loses half-pixel target anchors.
        hp = tuple(round(v) for v in hp)
        case = tuple(round(v) for v in case)
        box = [round((hp[0]-case[0])*1024/case[2]), round((hp[1]-case[1])*256/case[3]),
            round((hp[0]+hp[2]-case[0])*1024/case[2]), round((hp[1]+hp[3]-case[1])*256/case[3])]
        texture = config['HealthBarTexture'].replace('\\','/').rsplit('/',1)[-1]
        alpha = Image.open(Path(root)/'Assets'/texture).convert('RGBA').getchannel('A').transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        field = Image.new('L',(1024,256))
        field.paste(alpha.resize((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS),box[:2])
        return field.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    field = Image.open(Path(root)/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')
    if name == 'hp_boss_case':
        # Export-ThemeGeometry flipped the completed target mask but did not
        # first mirror its fill UVs. Target.lua's production FakeFill uses
        # SetTexCoord(1,0,0,1). Correct the measurement, leaving the frozen
        # template and the runtime fill asset untouched (same alpha inventory).
        field = field.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return field


def validate_gap(image, fill):
    """Require zero extra pixels around the entire visible fill contour.

    Exterior casing size tolerance is separate and cannot waive this check.
    """
    field = np.asarray(fill.convert("L")) > 128
    paint = np.asarray(image)[:, :, 3] > 128
    columns = np.flatnonzero(field.any(axis=0))
    if image.size != fill.size or not len(columns):
        raise ValueError("invalid DK rail gap field")
    start, end = int(columns[0]), int(columns[-1])
    upper, lower = [], []
    for x in range(round(start+(end-start)*.25), round(start+(end-start)*.65), 4):
        rows = np.flatnonzero(field[:, x])
        top, bottom = int(rows[0]), int(rows[-1])
        above = np.flatnonzero(paint[:top, x])
        below = np.flatnonzero(paint[bottom+1:, x])
        if not len(above) or not len(below):
            raise ValueError("DK rail missing beside visible fill")
        upper.append(top-int(above[-1])-1)
        lower.append(int(below[0]))
    # Check every contour pixel, including shaped ends, rather than approving
    # a sample of the straight rails. This mask only measures the result;
    # it must never erase or stencil the source painting.
    expanded = np.asarray(Image.fromarray(field.astype('uint8')*255).filter(ImageFilter.MaxFilter(3))) > 0
    contour = expanded & ~field
    missing = int((contour & ~paint).sum())
    result = {"maximumUpperGapNativePixels": max(upper), "maximumLowerGapNativePixels": max(lower),
        "uncoveredAdjacentContourPixels": missing, "allowedExtraGapPixels": 0}
    if missing or max(upper+lower) != 0:
        raise ValueError("DK rail empty stripe beside visible fill: "+str(result))
    return result


def validate_projection(image, name, root):
    """Check actual default draw rectangles at 1x/2x, not only source pixels."""
    root = Path(root)
    spec = importlib.util.spec_from_file_location('dk_native_projection',root/'Tools/Build-ThemeConceptBase.py')
    base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
    original = name.removesuffix('-target')
    tier = dict(zip(CASES,('Seasoned','Hardened','Novice','Boss')))[original]
    kind = 'TargetFrame' if name.endswith('-target') or tier == 'Boss' else 'PlayerFrame'
    db = {**base.DATA[kind], **base.DATA[kind][tier]}
    owner = (250,120,*db['Size'])
    casing = base.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
    hp = base.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
    results = {}
    for scale in (1,2):
        fill = Image.new('RGBA',(1100*scale,320*scale)); paint = fill.copy()
        base.put(fill,base.asset(db['HealthBarTexture']),tuple(v*scale for v in hp),kind=='TargetFrame')
        base.put(paint,image,tuple(v*scale for v in casing),kind=='TargetFrame')
        field = np.asarray(fill)[:,:,3]>128
        contour = (np.asarray(Image.fromarray(field.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0)&~field
        missing = int((contour & ~(np.asarray(paint)[:,:,3]>128)).sum())
        results[str(scale)+'x'] = missing
    if any(results.values()):
        raise ValueError('DK projected rail gap: '+str(results))
    return results


def grid(image, rule):
    if set(rule) == {"axis", "sourceKnots", "targetKnots"}:
        return line_grid(image, rule)
    if set(rule) != {"axis", "cross", "knots", "delta"} or rule["axis"] not in ("x", "y"):
        raise ValueError("unsupported DK rail operation")
    delta = np.asarray(rule["delta"], dtype=float)
    limit = 64 if rule["axis"] == "x" else 32
    if not np.isfinite(delta).all() or np.max(np.abs(delta)) > limit:
        raise ValueError("DK rail displacement exceeds bounded assembly")
    control = {"schema": "vertical-mount-grid-1", "x": rule["cross"], "y": rule["knots"], "dy": rule["delta"]}
    if rule["axis"] == "x":
        return morph_mount(image.transpose(Image.Transpose.TRANSPOSE), control).transpose(Image.Transpose.TRANSPOSE)
    return morph_mount(image, control)


def line_grid(image, rule):
    """Full-line monotonic resampling of own RGBA, never alpha substitution."""
    if rule["axis"] not in ("x", "y"):
        raise ValueError("unsupported DK rail operation")
    transpose = rule["axis"] == "y"
    pixels = np.asarray(image).astype(float)
    if transpose:
        pixels = pixels.transpose(1, 0, 2)
    height, width = pixels.shape[:2]
    if len(rule["sourceKnots"]) != height or len(rule["targetKnots"]) != height:
        raise ValueError("invalid full-canvas line grid")
    pixels[:, :, :3] *= pixels[:, :, 3:4]/255
    output = np.zeros_like(pixels)
    for row, (source, target) in enumerate(zip(rule["sourceKnots"], rule["targetKnots"])):
        source, target = np.asarray(source, dtype=float), np.asarray(target, dtype=float)
        if (source.ndim != 1 or source.shape != target.shape or len(source) not in (2, 4, 5, 6, 7, 8, 9, 10)
                or not np.isfinite(source).all() or not np.isfinite(target).all()
                or source[0] != 0 or target[0] != 0 or source[-1] != width-1 or target[-1] != width-1
                or not (np.diff(source)>0).all() or not (np.diff(target)>0).all()):
            raise ValueError("folded/cropping DK rail line grid")
        if np.max(np.abs(source-target)) > (32 if transpose else 64):
            raise ValueError("DK rail displacement exceeds bounded assembly")
        coordinates = np.interp(np.arange(width), target, source)
        low = np.floor(coordinates).astype(int)
        high = np.minimum(width-1, low+1)
        weight = (coordinates-low)[:, None]
        output[row] = pixels[row, low]*(1-weight)+pixels[row, high]*weight
    alpha = output[:, :, 3:4]/255
    output[:, :, :3] = np.divide(output[:, :, :3], alpha, out=np.zeros_like(output[:, :, :3]), where=alpha>0)
    if transpose:
        output = output.transpose(1, 0, 2)
    return Image.fromarray(np.clip(np.rint(output), 0, 255).astype('uint8'))


def build(recipe, root, only=None):
    root = Path(root)
    if set(recipe) != {"schema", "authority", "cases"} or recipe["schema"] != "deathknight-rail-grid-1":
        raise ValueError("unsupported DK rail construction")
    authority = checked_file(recipe["authority"], root)
    if authority != (root / "Assets_Draft/DeathKnight/FullSet/manifest.json").resolve():
        raise ValueError("wrong original DK rail authority")
    originals = json.loads(authority.read_text())["assets"]
    if not recipe["cases"] or not set(recipe["cases"]) <= set(CASES+TARGET_CASES):
        raise ValueError("unsupported DK rail inventory")
    output = {}
    for name, operations in recipe["cases"].items():
        if len(operations) not in (2, 4, 6, 8, 10, 12, 14) or [item["axis"] for item in operations] != ["y", "x"]*(len(operations)//2):
            raise ValueError("required DK rail assembly axes missing")
        if only is not None and name != only:
            continue
        original = originals[name.removesuffix('-target')]
        image = whole_painting(read(checked_file(original["source"], root)), original["transform"], original["canvas"])
        verify_pixels(image, read(checked_file(original, root)))
        for operation in operations:
            image = grid(image, operation)
        output[name + "-over"] = image
    return output


def replay(item, name, root):
    if set(item) != {"role", "source", "transform", "construction"} or item["role"] != "deathknight-rail-grid-1":
        raise ValueError("unsupported DK rail source proof")
    if item["transform"] != {"scale": 1, "offset": [0, 0]}:
        raise ValueError("completed DK rail cannot be repositioned or cropped")
    recipe = json.loads(checked_file(item["construction"], root).read_text())
    images = build(recipe, root, only=name.removesuffix('-over'))
    if name not in images:
        raise ValueError("DK rail is absent from source construction")
    expected = images[name]
    verify_pixels(expected, read(checked_file(item["source"], root)))
    return expected


def target_recess(name, root):
    base = name.removesuffix('-target')
    if name not in TARGET_CASES:
        raise ValueError('unsupported DK target recess')
    native = np.asarray(read(Path(root)/'Assets'/(base+'.tga')))
    field = np.asarray(fill_field(name,root))>128
    pixels = np.zeros_like(native); pixels[field] = native[field]
    return Image.fromarray(pixels)
