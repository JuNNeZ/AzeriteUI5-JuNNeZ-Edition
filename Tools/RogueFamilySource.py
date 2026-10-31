"""Replay complete separate paintings from one generated atlas, with own-alpha FX.

Every >8-alpha atlas pixel must belong to exactly one whole-object cell. No
painting is clipped/stencilled, and grounding uses only that painting's alpha.
"""
from pathlib import Path
import math

import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageChops

from ThemeSourceIntegrity import checked_file, read, verify_pixels, whole_painting

NAMES = {'hp_cap_case-over', 'pw_crystal_case', 'actionbutton-border', 'minimap-border'}


def missing_frozen_terminal(image, frozen):
    """The original entire terminal is required even if a cap hides shrinkage."""
    if image.size != frozen.size:
        raise ValueError('terminal canvas changed')
    solid = image.getchannel('A').point(lambda a: 255 if a > 128 else 0)
    coverage = np.asarray(solid.filter(ImageFilter.MaxFilter(3))) > 0
    return (np.asarray(frozen.convert('L')) > 128) & ~coverage


def extract(recipe, root):
    version = recipe.get('schema')
    keys = {'schema', 'atlas', 'cells'}
    if version == 'rogue-whole-atlas-2':
        keys.add('wholeSourceReplacements')
    if set(recipe) != keys or version not in ('rogue-whole-atlas-1', 'rogue-whole-atlas-2'):
        raise ValueError('unsupported atlas operation')
    if set(recipe['cells']) != NAMES:
        raise ValueError('exact four-object inventory required')
    atlas = read(checked_file(recipe['atlas'], Path(root)))
    assigned = np.zeros((atlas.height, atlas.width), dtype='uint8')
    parts = {}
    for name, rect in recipe['cells'].items():
        if len(rect) != 4 or any(type(v) is not int for v in rect):
            raise ValueError('invalid object cell')
        l, t, r, b = rect
        if not (0 <= l < r <= atlas.width and 0 <= t < b <= atlas.height):
            raise ValueError('cell leaves atlas')
        assigned[t:b, l:r] += 1
        part = atlas.crop(tuple(rect))
        box = part.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
        if not box or min(box[0], box[1], part.width - box[2], part.height - box[3]) < 2:
            raise ValueError('cell clips an actual painting or has no transparent separation')
        parts[name] = part
    if (assigned > 1).any():
        raise ValueError('overlapping painting cells')
    if ((np.asarray(atlas)[:, :, 3] > 8) & (assigned != 1)).any():
        raise ValueError('unassigned atlas paint; object crop would remove pixels')
    if version == 'rogue-whole-atlas-2':
        replacements = recipe['wholeSourceReplacements']
        if not replacements or not set(replacements) <= NAMES:
            raise ValueError('invalid whole-source replacement inventory')
        for name, item in replacements.items():
            if set(item) != {'path', 'sha256'}:
                raise ValueError('whole-source replacement cannot crop or transform paint')
            source = read(checked_file(item, Path(root)))
            box = source.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
            if not box or min(box[0], box[1], source.width - box[2], source.height - box[3]) < 2:
                raise ValueError('whole-source replacement clips paint or is empty')
            # Entire alternative PNG replaces one whole logical object. The
            # retired atlas painting remains accounted for and intact on disk.
            parts[name] = source
    return parts


def grounded(raw, recipe):
    if set(recipe) != {'schema', 'radius', 'strength'} or recipe['schema'] not in ('own-alpha-grounding-1', 'own-outer-grounding-2'):
        raise ValueError('unsupported grounding operation')
    radius, strength = recipe['radius'], recipe['strength']
    if not (0 < radius <= 20 and 0 <= strength <= .35):
        raise ValueError('invalid grounding parameters')
    pad = math.ceil(radius * 4) + 4
    paint = Image.new('RGBA', (raw.width + pad * 2, raw.height + pad * 2))
    paint.paste(raw, (pad, pad))
    shadow = Image.new('RGBA', paint.size)
    field = paint.getchannel('A')
    if recipe['schema'] == 'own-outer-grounding-2':
        exterior = field.point(lambda a: 255 if a > 128 else 0)
        ImageDraw.floodfill(exterior, (0, 0), 128)
        outside = exterior.point(lambda a: 255 if a == 128 else 0)
        field = ImageChops.invert(outside)
        alpha = ImageChops.multiply(field.filter(ImageFilter.GaussianBlur(radius)), outside)
    else:
        alpha = field.filter(ImageFilter.GaussianBlur(radius))
    shadow.putalpha(alpha.point(lambda a: round(a * strength)))
    return Image.alpha_composite(shadow, paint)


def functional_shade(name, root):
    # Exact original native inner shading is an independent functional layer.
    # Its mask never touches the new painting or supplies a casing outline.
    root = Path(root)
    native = read(root / 'Assets' / (name.removesuffix('-over') + '.tga'))
    pixels = np.zeros_like(np.asarray(native))
    if name in ('pw_crystal_case', 'actionbutton-border'):
        field = Image.open(root / 'Docs/Research_Assets/Templates' / (name + '-fill.png')).convert('L')
        source = np.asarray(native)
        keep = (np.asarray(field) > 128) & (source[:, :, 3] > 0) & (source[:, :, 3] <= 200)
        pixels[keep] = source[keep]
    return Image.fromarray(pixels)


def validate_composites(records, root):
    if set(records) != NAMES:
        raise ValueError('incomplete functional construction')
    for name, item in records.items():
        if set(item) != {'paintingSource', 'transform', 'native', 'functionalMask', 'completeSource'}:
            raise ValueError('unsupported native composition operation')
        native = checked_file(item['native'], Path(root))
        if native != (Path(root) / 'Assets' / (name.removesuffix('-over') + '.tga')).resolve():
            raise ValueError('functional shade must use exact shared native asset')
        field = Path(root) / 'Docs/Research_Assets/Templates' / (name.removesuffix('-over') + '-fill.png')
        if item['functionalMask'] is not None:
            if checked_file(item['functionalMask'], Path(root)) != field.resolve():
                raise ValueError('functional mask replaced')
        elif name in ('pw_crystal_case', 'actionbutton-border'):
            raise ValueError('functional mask missing')
        painting = whole_painting(read(checked_file(item['paintingSource'], Path(root))), item['transform'], read(native).size)
        expected = Image.alpha_composite(functional_shade(name, root), painting)
        verify_pixels(expected, read(checked_file(item['completeSource'], Path(root))))
    return {'completeNativeSourcesReplayed': 4, 'nativeShadeCopiedExactlyAsSeparateLayer': True,
            'newPaintingClippedByNativeMask': False}


def validate(recipe, grounding, part_paths, source_paths, root):
    parts = extract(recipe, root)
    if set(grounding) != NAMES or set(part_paths) != NAMES or set(source_paths) != NAMES:
        raise ValueError('incomplete construction proof')
    for name, raw in parts.items():
        # Full raw tile RGBA, including translucent contours, survives intact.
        actual = read(part_paths[name])
        if actual.size != raw.size or actual.tobytes() != raw.tobytes():
            raise ValueError('raw atlas painting RGBA changed')
        verify_pixels(grounded(raw, grounding[name]), read(source_paths[name]))
    return {'wholeObjectsReplayed': 4, 'allVisibleAtlasPaintAccountedFor': True,
            'wholeSourceReplacements': sorted(recipe.get('wholeSourceReplacements', {})),
            'paintStencilErasureOrExtrusion': False, 'groundingSource': 'each new painting own alpha only'}
