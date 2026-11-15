"""Inner fit is exact; outer casing tolerance cannot permit an empty pixel."""
from pathlib import Path
import sys
import unittest
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from DeathKnightRailSource import validate_gap


class ZeroGap(unittest.TestCase):
    def setUp(self):
        self.fill = Image.new('L', (64, 32))
        ImageDraw.Draw(self.fill).rectangle((12, 10, 51, 21), fill=255)
        self.rail = Image.new('RGBA', (64, 32), (80, 85, 90, 255))
        ImageDraw.Draw(self.rail).rectangle((12, 10, 51, 21), fill=(0, 0, 0, 0))

    def test_exact_join_passes(self):
        self.assertEqual(validate_gap(self.rail, self.fill)['uncoveredAdjacentContourPixels'], 0)

    def test_one_extra_pixel_below_fails(self):
        ImageDraw.Draw(self.rail).line((12, 22, 51, 22), fill=(0, 0, 0, 0))
        with self.assertRaisesRegex(ValueError, 'empty stripe'):
            validate_gap(self.rail, self.fill)

    def test_single_end_pixel_outside_sampled_straight_run_fails(self):
        self.rail.putpixel((52, 15), (0, 0, 0, 0))
        with self.assertRaisesRegex(ValueError, 'empty stripe'):
            validate_gap(self.rail, self.fill)


if __name__ == '__main__':
    unittest.main()
