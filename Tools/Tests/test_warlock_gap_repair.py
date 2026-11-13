"""Catch the outward atlas rails and empty space beside unchanged native fills."""
import importlib.util
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PriestWarlockAssetContracts import ROOT
from PriestWarlockBorderAtlas import pack

spec = importlib.util.spec_from_file_location("warlock_gaps", ROOT / "Tools/Repair-WarlockGaps.py")
gaps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gaps)


def rail_centres(image):
    a = np.asarray(image)[:, :, 3] > 128
    cell = image.height
    centres = []
    for index in range(4):
        positions = np.flatnonzero(a[cell//2, index*cell:(index+1)*cell])
        centres.append((positions[0]+positions[-1])/2)
    return np.array(centres)


class WarlockGaps(unittest.TestCase):
    def test_native_registration_closes_the_old_border_moat(self):
        for name in ("border-tooltip", "border-aura"):
            with self.subTest(name=name):
                source = Image.open(ROOT / "Assets_Draft/Warlock/FullSet/Exports" / (name+".tga")).convert("RGBA")
                native = Image.open(ROOT / "Assets" / (name+".tga")).convert("RGBA")
                offsets = {2: (1, 0)} if name == "border-tooltip" else None
                rejected, _ = pack(source, offsets)
                repaired, _ = pack(source, offsets, native)
                self.assertGreater(np.max(abs(rail_centres(rejected)-rail_centres(native))), 8)
                self.assertLessEqual(np.max(abs(rail_centres(repaired)-rail_centres(native))), 1)

    def test_clear_aperture_alone_does_not_prove_contact(self):
        field = np.zeros((40, 80), dtype=bool)
        field[15:25, 10:70] = True
        rails = np.zeros(field.shape, dtype="uint8")
        rails[10, :] = rails[29, :] = 255
        self.assertEqual(gaps.metrics(rails, field)["maximumGapPx"], 4)
        rails[14, :] = rails[25, :] = 255
        self.assertEqual(gaps.metrics(rails, field)["maximumGapPx"], 0)
        rails[:15, :] = 0
        self.assertGreater(gaps.metrics(rails, field)["maximumGapPx"], 4)


if __name__ == "__main__":
    unittest.main()
