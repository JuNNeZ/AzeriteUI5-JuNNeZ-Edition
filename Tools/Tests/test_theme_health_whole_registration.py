"""Whole-source mounting must retain contour alpha and reject exposed terminals."""
import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ThemeHealthEndcaps import align
from ThemeSourceIntegrity import whole_painting, verify_pixels


class WholeRegistration(unittest.TestCase):
    def setUp(self):
        self.source=Image.new("RGBA",(14,7))
        ImageDraw.Draw(self.source).rectangle((1,1,12,5),fill=(110,60,140,255))
        self.source.putpixel((13,1),(170,140,190,80))
        self.case=Image.new("RGBA",(16,16))
        ImageDraw.Draw(self.case).rectangle((2,9,13,12),fill=(70,70,70,255))
        self.fill=Image.new("L",(16,16))
        ImageDraw.Draw(self.fill).rectangle((2,5,8,7),fill=255)
        self.transform={"crop":[0,0,14,7],"scale":1,"offset":[1,7]}

    def test_exact_whole_replay_retains_translucent_outer_contour(self):
        cap,result=align(self.source,self.case,5,self.fill,source_transform=self.transform)
        verify_pixels(whole_painting(self.source,self.transform,self.case.size),cap)
        self.assertEqual(cap.getpixel((14,8)),(170,140,190,80))
        self.assertEqual(result["exposedTerminalPixelsBeyondAA"],0)

    def test_source_crop_cannot_discard_contour_paint(self):
        transform={**self.transform,"crop":[1,1,13,6]}
        with self.assertRaisesRegex(ValueError,"removes painted pixels"):
            align(self.source,self.case,5,self.fill,source_transform=transform)

    def test_toe_correct_but_exposed_upper_body_is_rejected(self):
        damaged=self.source.copy()
        ImageDraw.Draw(damaged).rectangle((10,1,13,4),fill=(0,0,0,0))
        with self.assertRaisesRegex(AssertionError,"terminal metal exposed"):
            align(damaged,self.case,5,self.fill,source_transform=self.transform)

    def test_transform_cannot_override_declared_uniform_height(self):
        with self.assertRaisesRegex(AssertionError,"scale differs"):
            align(self.source,self.case,5,self.fill,source_transform={**self.transform,"scale":1.1})

    def test_fractional_height_uses_the_same_declared_uniform_replay(self):
        transform={**self.transform,"scale":1.02}
        cap,_=align(self.source,self.case,5.1,self.fill,source_transform=transform)
        verify_pixels(whole_painting(self.source,transform,self.case.size),cap)


if __name__=="__main__":
    unittest.main()
