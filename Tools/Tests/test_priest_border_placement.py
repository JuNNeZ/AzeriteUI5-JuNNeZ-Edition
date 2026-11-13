"""Catch the visible border-to-background moat, not just matching atlas joins."""
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PriestWarlockBorderAtlas import pack, NAMES
from PriestWarlockAssetContracts import ROOT
from DeathKnightTooltipAtlas import joins


def rail_centres(atlas):
    cell = atlas.height
    alpha = np.asarray(atlas)[:, :, 3]
    centres = []
    for edge in range(4):
        span = np.flatnonzero(alpha[cell//2, edge*cell:(edge+1)*cell] > 128)
        if not len(span):
            raise AssertionError("Empty edge")
        centres.append(float((span[0]+span[-1])/2))
    return np.array(centres)


class PriestBorders(unittest.TestCase):
    def test_native_rail_positions_and_corner_joins(self):
        for name in NAMES:
            with self.subTest(name=name):
                source = Image.open(ROOT/"Assets_Draft/Priest/FullSet/Exports"/(name+".tga")).convert("RGBA")
                native = Image.open(ROOT/"Assets"/(name+".tga")).convert("RGBA")
                fixed, recipes = pack(source, native=native)
                self.assertLessEqual(float(abs(rail_centres(fixed)-rail_centres(native)).max()), 1)
                diagnostic = fixed if fixed.height == 64 else fixed.resize((512,64), Image.Resampling.NEAREST)
                self.assertEqual(joins(diagnostic), [])
                self.assertEqual(len(recipes), 4)
                # The previous pack matched its own corners, yet moved the
                # rails away from the unchanged background and icon insets.
                rejected, _ = pack(source)
                self.assertGreater(float(abs(rail_centres(rejected)-rail_centres(native)).max()), 8)


if __name__ == "__main__":
    unittest.main()
