"""Typed source-only closure of the three reported Rogue joins.

The requested morph resamples only each painting's own RGBA. Native glass is
composed afterwards, unchanged; native fill/outline masks never edit painting.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

from RogueSerratedMorph import morph_mount
from RogueFamilySource import functional_shade
from ThemeSourceIntegrity import checked_file, read, whole_painting, verify_pixels


def axis_morph(image, rule):
    if set(rule) != {'axis', 'cross', 'knots', 'delta'} or rule['axis'] not in ('x', 'y'):
        raise ValueError('unsupported source grid operation')
    delta = np.asarray(rule['delta'], dtype=float)
    if not np.isfinite(delta).all() or np.max(np.abs(delta)) > 20:
        raise ValueError('health grid exceeds bounded source displacement')
    grid = {'schema': 'vertical-mount-grid-1', 'x': rule['cross'], 'y': rule['knots'], 'dy': rule['delta']}
    if rule['axis'] == 'x':
        return morph_mount(image.transpose(Image.Transpose.TRANSPOSE), grid).transpose(Image.Transpose.TRANSPOSE)
    return morph_mount(image, grid)


def radial_morph(image, rule):
    keys = {'schema', 'center', 'radii', 'targetRadii'}
    if rule.get('schema') in ('own-ring-radius-2', 'own-ring-contour-1'):
        keys.add('sourceCenter')
    if set(rule) != keys or rule['schema'] not in ('own-ring-radius-1', 'own-ring-radius-2', 'own-ring-contour-1'):
        raise ValueError('unsupported ring operation')
    if image.size != (256, 256) or rule['center'] != [127.5, 127.5]:
        raise ValueError('ring source canvas/center changed')
    radii, target = np.asarray(rule['radii'], dtype=float), np.asarray(rule['targetRadii'], dtype=float)
    if (radii.ndim != 1 or target.shape != radii.shape or len(radii) < 3 or
            not np.isfinite(radii).all() or not np.isfinite(target).all() or
            radii[0] != 0 or target[0] != 0 or radii[-1] != target[-1] or radii[-1] < 181 or
            not (np.diff(radii) > 0).all() or not (np.diff(target) > 0).all() or
            np.max(np.abs(target - radii)) > 12):
        raise ValueError('folded/unbounded/cropping ring grid')
    if rule['schema'] == 'own-ring-radius-1' and np.array_equal(radii, target):
        return image.copy()
    yy, xx = np.indices((256, 256), dtype=float)
    cx, cy = rule['center']
    radius = np.hypot(xx - cx, yy - cy)
    old_radius = np.interp(radius, target, radii)
    if rule['schema'] == 'own-ring-contour-1':
        # Normalize the painting's OWN opaque inner contour to an analytic ring.
        # No native mask/alpha is consulted or imposed on the painting.
        source_alpha = np.asarray(image)[:, :, 3].astype(float)
        scx, scy = rule['sourceCenter']
        angles = np.arange(128) * (2 * np.pi / 128)
        scan = np.arange(24, 58.001, .125)
        contours = []
        for angle in angles:
            px, py = scx + np.cos(angle) * scan, scy + np.sin(angle) * scan
            lx, ly = np.floor(px).astype(int), np.floor(py).astype(int)
            wx, wy = px - lx, py - ly
            values = ((source_alpha[ly, lx] * (1-wx) + source_alpha[ly, lx+1] * wx) * (1-wy) +
                      (source_alpha[ly+1, lx] * (1-wx) + source_alpha[ly+1, lx+1] * wx) * wy)
            hits = np.flatnonzero(values >= 200)
            if not len(hits) or hits[0] == 0:
                raise ValueError('painting has no bounded closed opaque ring contour')
            k = int(hits[0])
            contours.append(float(scan[k-1] + (200-values[k-1]) / (values[k]-values[k-1]) * .125))
        if max(abs(np.asarray(contours) - target[2])) > 12:
            raise ValueError('own ring contour correction exceeds requested displacement')
        angle_field = np.mod(np.arctan2(yy-cy, xx-cx), 2*np.pi)
        inner = np.interp(angle_field, np.append(angles, 2*np.pi), np.append(contours, contours[0]))
        lower = (radius >= target[1]) & (radius < target[2])
        upper = (radius >= target[2]) & (radius < target[3])
        old_radius[lower] = radii[1] + (radius[lower]-target[1]) / (target[2]-target[1]) * (inner[lower]-radii[1])
        old_radius[upper] = inner[upper] + (radius[upper]-target[2]) / (target[3]-target[2]) * (radii[3]-inner[upper])
    ratio = np.divide(old_radius, radius, out=np.ones_like(radius), where=radius > 0)
    sx, sy = cx + (xx - cx) * ratio, cy + (yy - cy) * ratio
    if 'sourceCenter' in rule:
        shift = np.asarray(rule['sourceCenter'], dtype=float) - np.array([cx, cy])
        if shift.shape != (2,) or not np.isfinite(shift).all() or np.max(np.abs(shift)) > 2:
            raise ValueError('ring center correction exceeds bounded source placement')
        weight = np.clip((90 - radius) / 30, 0, 1)
        sx, sy = sx + shift[0] * weight, sy + shift[1] * weight
    if sx.min() < 0 or sy.min() < 0 or sx.max() > 255 or sy.max() > 255:
        raise ValueError('ring warp leaves complete source canvas')
    pixels = np.asarray(image).astype(float)
    pixels[:, :, :3] *= pixels[:, :, 3:4] / 255
    left, top = np.floor(sx).astype(int), np.floor(sy).astype(int)
    right, bottom = np.minimum(255, left + 1), np.minimum(255, top + 1)
    wx, wy = (sx - left)[:, :, None], (sy - top)[:, :, None]
    out = (pixels[top, left] * (1 - wx) + pixels[top, right] * wx) * (1 - wy)
    out += (pixels[bottom, left] * (1 - wx) + pixels[bottom, right] * wx) * wy
    alpha = out[:, :, 3:4] / 255
    out[:, :, :3] = np.divide(out[:, :, :3], alpha, out=np.zeros_like(out[:, :, :3]), where=alpha > 0)
    return Image.fromarray(np.clip(np.rint(out), 0, 255).astype('uint8'))


def family_paintings(authority, root):
    root = Path(root)
    path = checked_file(authority, root)
    if path != (root / 'Docs/Research_Assets/Rogue/Concept-Family-2026-10-31/Sources/construction-v3.json').resolve():
        raise ValueError('wrong retained family source authority')
    construction = json.loads(path.read_text())
    output = {}
    for name in ('hp_cap_case-over', 'actionbutton-border'):
        record = construction['functionalComposites'][name]
        native = checked_file(record['native'], root)
        if native != (root / 'Assets' / (name.removesuffix('-over') + '.tga')).resolve():
            raise ValueError('functional component must retain exact shared native source')
        if record['functionalMask'] is not None:
            mask = checked_file(record['functionalMask'], root)
            if mask != (root / 'Docs/Research_Assets/Templates' / (name.removesuffix('-over') + '-fill.png')).resolve():
                raise ValueError('functional component mask changed')
        source = read(checked_file(record['paintingSource'], root))
        canvas = (1024, 256) if name.startswith('hp_') else (256, 256)
        output[name] = whole_painting(source, record['transform'], canvas)
    return output


def build(recipe, root):
    root = Path(root)
    if set(recipe) != {'schema', 'familyAuthority', 'healthGrids', 'buttonRadius', 'floor'} or recipe['schema'] != 'rogue-fit-closure-1':
        raise ValueError('unsupported fit construction')
    if len(recipe['healthGrids']) != 2 or [g['axis'] for g in recipe['healthGrids']] != ['y', 'x']:
        raise ValueError('required health source grids missing')
    result = family_paintings(recipe['familyAuthority'], root)
    for rule in recipe['healthGrids']:
        result['hp_cap_case-over'] = axis_morph(result['hp_cap_case-over'], rule)
    ring = radial_morph(result['actionbutton-border'], recipe['buttonRadius'])
    result['actionbutton-border'] = Image.alpha_composite(functional_shade('actionbutton-border', root), ring)
    floor = recipe['floor']
    if set(floor) != {'schema', 'source', 'normal', 'ice'} or floor['schema'] != 'whole-floor-source-1':
        raise ValueError('unsupported floor construction')
    source_path = checked_file(floor['source'], root)
    if source_path != (root / 'Docs/Research_Assets/Rogue/Layered-Rebuild-2026-10-30/Sources/seat.png').resolve():
        raise ValueError('wrong original whole floor source')
    for mode, name in (('normal', 'pw_crystal_case-seat'), ('ice', 'pw_crystal_case-seat-wrath')):
        # Declared uniform whole-painting placement, never a native silhouette stencil.
        transform = floor[mode]
        if transform['scale'] != .25 or transform['offset'] != [0, 0]:
            raise ValueError('floor scale/registration outside requested closure')
        if transform['crop'] != [0, 16 if mode == 'normal' else 4, 1024, 512]:
            raise ValueError('floor source placement differs from fixed normal/ice method')
        result[name] = whole_painting(read(source_path), transform, (256, 128))
    return result


def verify_ring_composite(item, root):
    """Specific typed composition: aperture is checked on paint before glass.

    Two legal translucent layers can composite above alpha200. That does not
    turn unchanged native glass into new opaque painting. Complete output RGBA
    and the upstream own-painting morph are independently replayed here.
    """
    if set(item) != {'role', 'source', 'transform', 'construction'} or item['role'] != 'rogue-ring-native-glass-1':
        raise ValueError('unsupported ring functional composition')
    if item['transform'] != {'scale': 1, 'offset': [0, 0]}:
        raise ValueError('functional composition cannot crop or transform completed layers')
    root = Path(root)
    recipe = json.loads(checked_file(item['construction'], root).read_text())
    paintings = family_paintings(recipe['familyAuthority'], root)
    paint = radial_morph(paintings['actionbutton-border'], recipe['buttonRadius'])
    # Also validate all recipe keys/operations; no dormant stencil/erasure flag.
    expected = build(recipe, root)['actionbutton-border']
    verify_pixels(expected, read(checked_file(item['source'], root)))
    return expected, paint


def validate(recipe, sources, root):
    expected = build(recipe, root)
    if set(sources) != set(expected):
        raise ValueError('fit source inventory incomplete')
    for name, image in expected.items():
        verify_pixels(image, read(sources[name]))
    return {'ownPaintingMorphReplayed': True, 'functionalButtonGlassUnchanged': True,
            'floorWholeUniformPlacementReplayed': True, 'nativeAlphaStencilRgbExtrusionOrErasure': False}
