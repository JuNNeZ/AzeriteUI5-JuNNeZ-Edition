"""Explicitly requested local mount morph; whole Serrated blade stays rigid.

This source construction replaces the retired RGB-propagated backing recipe.
Only the retained original's own RGBA is resampled, using a monotonic vertical
control grid. It cannot read native masks, erase paint or extrapolate RGB.
"""
from pathlib import Path
import numpy as np
from PIL import Image

from ThemeSourceIntegrity import checked_file, read, verify_pixels


def split_original(original, component_mask):
    if original.size != (1254, 1254) or component_mask.size != original.size:
        raise ValueError('wrong retained Serrated source/component canvas')
    values = np.asarray(component_mask.convert('L'))
    if not np.isin(values, [0, 255]).all():
        raise ValueError('component partition must be binary')
    pixels = np.array(original)
    pixels[pixels[:, :, 3] == 0] = 0
    blade, mount = pixels.copy(), pixels.copy()
    blade[values == 0] = 0
    mount[values != 0] = 0
    if not np.array_equal(np.asarray(Image.alpha_composite(Image.fromarray(blade), Image.fromarray(mount))), pixels):
        raise ValueError('component partition lost original painting')
    return Image.fromarray(mount), Image.fromarray(blade)


def morph_mount(image, grid):
    if set(grid) != {'schema', 'x', 'y', 'dy'} or grid['schema'] != 'vertical-mount-grid-1':
        raise ValueError('unsupported mount operation')
    xs, ys, delta = np.asarray(grid['x'], dtype=float), np.asarray(grid['y'], dtype=float), np.asarray(grid['dy'], dtype=float)
    width, height = image.size
    if (xs.ndim != 1 or ys.ndim != 1 or delta.shape != (len(ys), len(xs)) or
            len(xs) < 2 or len(ys) < 2 or not np.isfinite(delta).all() or
            xs[0] != 0 or xs[-1] != width - 1 or ys[0] != 0 or ys[-1] != height - 1 or
            not (np.diff(xs) > 0).all() or not (np.diff(ys) > 0).all()):
        raise ValueError('invalid full-canvas control grid')
    if not np.all(delta[[0, -1]] == 0) or np.max(np.abs(delta)) > 160:
        raise ValueError('grid may not crop source or exceed bounded mount displacement')
    if not np.all(np.diff(ys[:, None] + delta, axis=0) > 1):
        raise ValueError('folded mount grid')
    if np.all(delta == 0):
        return image.copy()
    source = np.asarray(image).astype(float)
    alpha = source[:, :, 3:4] / 255
    premultiplied = np.concatenate((source[:, :, :3] * alpha, source[:, :, 3:4]), axis=2)
    output = np.zeros_like(premultiplied)
    coordinates = np.arange(height)
    for x in range(width):
        displacement = np.array([np.interp(x, xs, row) for row in delta])
        inverse_y = np.interp(coordinates, ys + displacement, ys)
        low = np.floor(inverse_y).astype(int)
        high = np.minimum(height - 1, low + 1)
        weight = (inverse_y - low)[:, None]
        output[:, x] = premultiplied[low, x] * (1 - weight) + premultiplied[high, x] * weight
    visible_alpha = output[:, :, 3:4] / 255
    output[:, :, :3] = np.divide(output[:, :, :3], visible_alpha,
                                 out=np.zeros_like(output[:, :, :3]), where=visible_alpha > 0)
    return Image.fromarray(np.clip(np.rint(output), 0, 255).astype('uint8'))


def compose(recipe, root):
    if set(recipe) != {'schema', 'original', 'bladeMask', 'bladeTranslation', 'mountGrid'} or recipe['schema'] != 'rogue-serrated-mount-morph-1':
        raise ValueError('unsupported Serrated construction')
    root = Path(root)
    original_path, mask_path = checked_file(recipe['original'], root), checked_file(recipe['bladeMask'], root)
    if original_path != (root / 'Docs/Research_Assets/Rogue/Sources/serrated-v2.png').resolve():
        raise ValueError('wrong original Serrated painting')
    if mask_path != (root / 'Docs/Research_Assets/Rogue/Script-Edited/serrated-blade-mask.png').resolve():
        raise ValueError('component mask cannot be replaced by native geometry')
    shift = recipe['bladeTranslation']
    if (len(shift) != 2 or any(type(v) is not int for v in shift) or
            abs(shift[0] + 120) > 48 or abs(shift[1] + 35) > 64):
        raise ValueError('complete blade rigid shift exceeds bounded source adjustment')
    mount, blade = split_original(read(original_path), Image.open(mask_path))
    moved = Image.new('RGBA', blade.size)
    box = blade.getchannel('A').getbbox()
    dx, dy = recipe['bladeTranslation']
    if box[0] + dx < 0 or box[1] + dy < 0 or box[2] + dx > blade.width or box[3] + dy > blade.height:
        raise ValueError('blade translation clips painting')
    moved.alpha_composite(blade, (dx, dy))
    if moved.crop((box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy)).tobytes() != blade.crop(box).tobytes():
        raise ValueError('rigid blade RGBA changed')
    return Image.alpha_composite(moved, morph_mount(mount, recipe['mountGrid']))


def validate(recipe, source_path, root):
    expected = compose(recipe, root)
    verify_pixels(expected, read(source_path))
    return {'originalPaintingPartitionReconstructs': True, 'completeBladeRigidRgbaExact': True,
            'mountMorphReplayed': True, 'nativeAlphaStencilOrRgbPropagation': False,
            'paintingErasureOrClipping': False}
