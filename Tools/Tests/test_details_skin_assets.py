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
        else:
            manifest["paintings"][name]["exportSha256"] = assets.sha(path)
        manifest_path.write_text(json.dumps(manifest))
        return folder

    def test_current_exports_replay_and_installed_files_match(self):
        assets.verify()
        for name in (*assets.NAMES, "row-mask"):
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


if __name__ == "__main__":
    unittest.main()
