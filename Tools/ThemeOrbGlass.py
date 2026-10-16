"""Deterministic native orb glass contract, including opaque specular pixels.

An alpha threshold cannot distinguish glass from metal: the white reflection
contains alpha 255. Use the measured native fill aperture, never RGB extraction.
"""
from pathlib import Path
import numpy as np
from PIL import Image

ORBS = ('orb_case_hi', 'orb_case_low')
# Layouts/Data/PlayerUnitFrame.lua uses Colors.ui for the original Case;
# Core/Common/Colors.lua defines it as 192/255. Themed cases render white.
NATIVE_CASE_TINT = 192/255


def glass_mask(root, name):
    assert name in ORBS, name
    return np.asarray(Image.open(Path(root)/'Docs/Research_Assets/Templates'/
                                (name+'-fill.png')).convert('L')) > 0


def restore_glass(image, root, name):
    if name not in ORBS:
        return image
    original = Image.open(Path(root)/'Assets'/(name+'.tga')).convert('RGBA')
    assert image.size == original.size, name+' orb canvas changed'
    pixels = np.array(image.convert('RGBA'))
    native = np.asarray(original)
    mask = glass_mask(root, name)
    pixels[mask] = native[mask]
    # Preserve the rendered native glass brightness without dimming class art.
    pixels[mask, :3] = np.rint(native[mask, :3].astype(float)*NATIVE_CASE_TINT).astype('uint8')
    return Image.fromarray(pixels)
