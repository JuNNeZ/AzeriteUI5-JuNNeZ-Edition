"""The authorized source edit must add inner paint without touching anything else."""
from pathlib import Path
import json
import runpy
import sys
import unittest

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PriestInnerEdgeRepair import repair
from ThemeSourceIntegrity import aperture, verify_pixels
from PriestWarlockAssetContracts import ROOT


class InnerEdges(unittest.TestCase):
    def test_actual_six_paintings_close_the_previously_visible_seams(self):
        measure = runpy.run_path(str(ROOT/"Tools/Repair-PriestGaps.py"))["gaps"]
        folder = ROOT/"Assets_Draft/Priest/FullSet"
        originals = json.loads((folder/"GapRepair/original-manifest.json").read_text())["assets"]
        fields = json.loads((ROOT/"Docs/Research_Assets/Priest/FullSet/Contracts/functional-fields.json").read_text())["clearance"]
        from ThemeSourceIntegrity import whole_painting
        for name in ("hp_cap_case","hp_mid_case","hp_low_case","hp_boss_case","pw_crystal_case","pw_crystal_case_low"):
            with self.subTest(name=name):
                field = Image.open(ROOT/fields[name]["path"]).convert("L")
                item = originals[name]
                old = whole_painting(Image.open(ROOT/item["source"]["path"]).convert("RGBA"),item["transform"],item["canvas"])
                new = Image.open(folder/"GapRepair"/(name+"-inner-edge.png")).convert("RGBA")
                self.assertGreaterEqual(measure(old,field,name.startswith("pw_"))["maximumGapPx"],3)
                self.assertEqual(measure(new,field,name.startswith("pw_"))["maximumGapPx"],0)

    def test_health_closes_inner_gap_and_retains_outer_paint(self):
        source = Image.new("RGBA", (40,24))
        draw = ImageDraw.Draw(source)
        draw.rectangle((2,2,37,21), fill=(130,100,150,255))
        draw.rectangle((6,6,33,17), fill=(0,0,0,0))
        fill = Image.new("L", source.size)
        ImageDraw.Draw(fill).rectangle((8,8,31,15), fill=255)
        result, mask = repair(source, fill)
        old, new = np.asarray(source), np.asarray(result)
        changed = np.asarray(mask)>0
        self.assertTrue(changed.any())
        self.assertTrue(np.array_equal(old[~changed],new[~changed]))
        self.assertTrue(np.array_equal(old[old[:,:,3]>128],new[old[:,:,3]>128]))
        self.assertEqual(result.getpixel((8,7))[3],255)
        self.assertEqual(result.getpixel((8,8))[3],0)
        aperture(result, fill)

    def test_crystal_top_stays_open(self):
        source = Image.new("RGBA", (40,24))
        draw = ImageDraw.Draw(source)
        draw.rectangle((3,5,6,20), fill=(130,100,150,255))
        draw.rectangle((33,5,36,20), fill=(130,100,150,255))
        draw.rectangle((3,18,36,21), fill=(130,100,150,255))
        fill = Image.new("L", source.size)
        ImageDraw.Draw(fill).rectangle((7,0,32,15), fill=255)
        result, mask = repair(source, fill, True)
        self.assertEqual(result.getpixel((20,16))[3],255)
        self.assertEqual(result.getpixel((20,0))[3],0)
        self.assertEqual(int(np.asarray(mask)[:6].sum()),0)
        aperture(result, fill)

    def test_empty_fill_cannot_turn_into_a_filled_plate(self):
        source = Image.new("RGBA", (80,40))
        draw = ImageDraw.Draw(source)
        draw.rectangle((2,2,77,37), fill=(130,100,150,255))
        draw.rectangle((6,6,73,33), fill=(0,0,0,0))
        with self.assertRaisesRegex(AssertionError,"measured inner-edge band"):
            repair(source,Image.new("L",source.size))

    def test_erasing_source_after_repair_is_detected(self):
        source = Image.new("RGBA", (40,24))
        draw = ImageDraw.Draw(source)
        draw.rectangle((2,2,37,21), fill=(130,100,150,255))
        draw.rectangle((6,6,33,17), fill=(0,0,0,0))
        fill = Image.new("L", source.size)
        ImageDraw.Draw(fill).rectangle((8,8,31,15), fill=255)
        expected,_ = repair(source,fill)
        erased = expected.copy()
        erased.putpixel((3,3),(0,0,0,0))
        with self.assertRaisesRegex(ValueError,"SOURCE RGBA changed"):
            verify_pixels(expected,erased)


if __name__ == "__main__":
    unittest.main()
