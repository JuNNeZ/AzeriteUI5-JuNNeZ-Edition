"""Source integrity regressions for the Details-only painting/aperture pipeline."""
import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location("details_assets", TOOLS / "Build-DetailsSkin.py")
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)


class DetailsAssetTests(unittest.TestCase):
    def mutate_export(self, name, change):
        work = tempfile.TemporaryDirectory()
        self.addCleanup(work.cleanup)
        folder = Path(work.name) / "exports"
        shutil.copytree(assets.EXPORT, folder)
        path = folder / (name + ".tga")
        image = Image.open(path).convert("RGBA")
        change(image)
        image.save(path)
        # Update the file hash to simulate a bad exporter, not just disk corruption.
        manifest_path = folder / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        if name == "row-mask":
            manifest["maskSha256"] = assets.sha(path)
        elif name == "row-mask-native":
            manifest["nativeMaskSha256"] = assets.sha(path)
        elif name == "fill-tile":
            manifest["materialTile"]["exportSha256"] = assets.sha(path)
        else:
            manifest["paintings"][name]["exportSha256"] = assets.sha(path)
        manifest_path.write_text(json.dumps(manifest))
        return folder

    def test_current_exports_replay_and_installed_files_match(self):
        assets.verify()
        for name in assets.RUNTIME_NAMES:
            self.assertEqual(assets.sha(assets.EXPORT / (name + ".tga")),
                             assets.sha(assets.ROOT / "Assets/Details" / (name + ".tga")))

    def test_erased_paint_rejected_even_with_updated_hash(self):
        def erase(image):
            x, y = image.width // 2, 160
            image.putpixel((x, y), (0, 0, 0, 0))
        with self.assertRaisesRegex(ValueError, "SOURCE RGBA"):
            assets.verify(self.mutate_export("header", erase))

    def test_recoloured_fill_rejected_even_with_updated_hash(self):
        def recolour(image):
            image.putpixel((500, 140), (255, 0, 0, 255))
        with self.assertRaisesRegex(ValueError, "SOURCE RGBA"):
            assets.verify(self.mutate_export("fill", recolour))

    def test_blanket_mask_rejected_even_with_updated_hash(self):
        def fill(image):
            image.putalpha(255)
        with self.assertRaisesRegex(ValueError, "SOURCE RGBA"):
            assets.verify(self.mutate_export("row-mask", fill))

    def test_filled_centre_is_not_an_aperture(self):
        image = Image.new("RGBA", (128, 32), (40, 40, 40, 255))
        with self.assertRaisesRegex(AssertionError, "transparent centre"):
            assets.aperture(image, (0, 1, 0, 1))

    def test_open_frame_must_fail_instead_of_masking_the_world(self):
        image = Image.new("RGBA", (128, 32))
        with self.assertRaisesRegex(AssertionError, "leaks outside"):
            assets.aperture(image, (0, 1, 0, 1))

    def test_native_full_uv_material_has_no_transparent_margins(self):
        tile = Image.open(assets.EXPORT / "fill-tile.tga").convert("RGBA")
        self.assertGreaterEqual(tile.getchannel("A").getextrema()[0], 240)
        old = Image.open(assets.EXPORT / "fill.tga").convert("RGBA")
        self.assertLess(old.getpixel((old.width//2, old.height//2))[3], 8,
                        "retained old export must reproduce a transparent centre at default UVs")

    def test_material_tile_cannot_include_the_old_margin(self):
        source = Image.open(assets.DRAFT / "Sources/fill.png").convert("RGBA")
        with self.assertRaisesRegex(AssertionError, "transparent margin"):
            assets.material_tile(source, (0, 0, 1024, 128))

    def test_material_tile_pixels_cannot_be_repainted(self):
        def alter(image):
            image.putpixel((10, 10), (255, 0, 255, 255))
        with self.assertRaisesRegex(ValueError, "SOURCE RGBA"):
            assets.verify(self.mutate_export("fill-tile", alter))

    def test_full_uv_native_mask_has_open_centre_and_closed_outer_corners(self):
        native = Image.open(assets.EXPORT / "row-mask-native.tga").convert("RGBA")
        self.assertEqual(native.size, (1024, 128))
        for fraction in (.25, .5, .75):
            self.assertEqual(native.getpixel((round(native.width*fraction), native.height//2))[3], 255)
        self.assertEqual(native.getpixel((0, 0))[3], 0)
        old = Image.open(assets.EXPORT / "row-mask.tga").convert("RGBA")
        self.assertEqual(old.getpixel((old.width//2, old.height//2))[3], 0,
                         "retained uncropped-mask fixture must reproduce the empty native centre")

    def test_full_uv_mask_cannot_be_replaced_with_blanket_mask(self):
        with self.assertRaisesRegex(ValueError, "SOURCE RGBA"):
            assets.verify(self.mutate_export("row-mask-native", lambda image: image.putalpha(255)))


if __name__ == "__main__":
    unittest.main()
