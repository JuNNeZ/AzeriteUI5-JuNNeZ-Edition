"""Own-source replay must reject erasure, unbounded grids and stale authority."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools"))
from DeathKnightRailSource import build, replay, grid, validate_gap, fill_field, validate_projection
from ThemeSourceIntegrity import aperture, sha, verify_pack
from ThemeHealthEndcaps import lowest_point

FOLDER = ROOT / "Assets_Draft/DeathKnight/Rail-Repair-2026-11-14/Assembly"


class RailSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = json.loads((FOLDER / "recipe.json").read_text())
        cls.images = build(cls.recipe, ROOT)
        cls.proof = json.loads((FOLDER / "source-integrity.json").read_text())["paintings"]

    def test_all_four_exact_sources_pass_shared_gate(self):
        self.assertEqual(verify_pack(FOLDER)["paintingsChecked"], 10)
        for name, image in self.images.items():
            self.assertEqual(replay(self.proof[name], name, ROOT).tobytes(), image.tobytes())

    def test_all_apertures_and_toes_remain_valid(self):
        for name, image in self.images.items():
            base = name[:-5].removesuffix('-target')
            aperture(image, fill_field(name[:-5],ROOT))
            native = lowest_point(Image.open(ROOT / "Assets" / (base+".tga")))
            actual = lowest_point(image)
            self.assertLessEqual(abs(native[0]-actual[0]), .5)
            self.assertEqual(native[1], actual[1])

    def test_visible_fill_meets_both_inner_rails(self):
        for name, image in self.images.items():
            validate_gap(image, fill_field(name[:-5],ROOT))

    def test_actual_default_projection_has_zero_gap_at_both_scales(self):
        for name,image in self.images.items():
            self.assertEqual(validate_projection(image,name[:-5],ROOT),{'1x':0,'2x':0})

    def test_boss_measurement_preserves_alpha_but_accounts_for_native_uv_flip(self):
        original = Image.open(ROOT/'Docs/Research_Assets/Templates/hp_boss_case-fill.png').convert('L')
        actual = fill_field('hp_boss_case',ROOT)
        self.assertEqual(actual.tobytes(),original.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes())
        self.assertEqual(sorted(actual.histogram()),sorted(original.histogram()))

    def test_rejected_live_gap_fails_despite_clear_aperture(self):
        for base in ("hp_mid_case", "hp_low_case", "hp_boss_case"):
            image = Image.open(FOLDER.parent / "Rejected-live-gap" / (base+"-over.tga")).convert("RGBA")
            mask = Image.open(ROOT / "Docs/Research_Assets/Templates" / (base+"-fill.png"))
            aperture(image, mask)
            with self.assertRaisesRegex(ValueError, "empty stripe"):
                validate_gap(image, mask)

    def test_original_obstructing_sources_still_fail(self):
        authority = json.loads((ROOT / self.recipe["authority"]["path"]).read_text())["assets"]
        for base in self.recipe["cases"]:
            image = Image.open(ROOT / authority[base.removesuffix('-target')]["path"])
            with self.assertRaisesRegex(ValueError, "SOURCE APERTURE"):
                aperture(image, fill_field(base,ROOT))

    def test_no_native_mask_or_erasure_flag(self):
        recipe = copy.deepcopy(self.recipe)
        recipe["cases"]["hp_low_case"][0]["eraseFill"] = True
        with self.assertRaisesRegex(ValueError, "unsupported DK rail operation"):
            build(recipe, ROOT)

    def test_no_stale_original_authority(self):
        recipe = copy.deepcopy(self.recipe)
        recipe["authority"]["sha256"] = "0"*64
        with self.assertRaisesRegex(ValueError, "stale"):
            build(recipe, ROOT)

    def test_no_unknown_inventory(self):
        recipe = copy.deepcopy(self.recipe)
        recipe["cases"]["orb_case_hi"] = recipe["cases"]["hp_low_case"]
        with self.assertRaisesRegex(ValueError, "inventory"):
            build(recipe, ROOT)

    def test_no_unbounded_or_folded_displacement(self):
        image = self.images["hp_low_case-over"]
        operation = copy.deepcopy(self.recipe["cases"]["hp_low_case"][0])
        operation["delta"][2] = [33]*len(operation["cross"])
        with self.assertRaisesRegex(ValueError, "bounded"):
            grid(image, operation)
        operation["delta"][2] = [32]*len(operation["cross"])
        operation["delta"][3] = [-32]*len(operation["cross"])
        with self.assertRaisesRegex(ValueError, "folded"):
            grid(image, operation)

    def test_no_completed_layer_shift(self):
        item = copy.deepcopy(self.proof["hp_low_case-over"])
        item["transform"]["offset"] = [1, 0]
        with self.assertRaisesRegex(ValueError, "repositioned"):
            replay(item, "hp_low_case-over", ROOT)

    def patched_source(self, alpha):
        with tempfile.TemporaryDirectory(dir=FOLDER) as temp:
            path = Path(temp) / "source.png"
            pixels = np.array(self.images["hp_low_case-over"])
            y, x = np.argwhere(pixels[:, :, 3] > 200)[200]
            if alpha:
                pixels[y, x, 3] = 0
            else:
                pixels[y, x, :3] = [255, 0, 255]
            Image.fromarray(pixels).save(path)
            item = copy.deepcopy(self.proof["hp_low_case-over"])
            item["source"] = {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)}
            with self.assertRaisesRegex(ValueError, "SOURCE RGBA changed"):
                replay(item, "hp_low_case-over", ROOT)

    def test_erased_source_cannot_be_rehashed_to_pass(self):
        self.patched_source(True)

    def test_repainted_pixel_cannot_be_rehashed_to_pass(self):
        self.patched_source(False)

    def bad_pack(self, change, message):
        with tempfile.TemporaryDirectory(dir=FOLDER) as temp:
            folder = Path(temp)
            recipe = copy.deepcopy(self.recipe)
            recipe["cases"] = {"hp_low_case": recipe["cases"]["hp_low_case"]}
            change(recipe["cases"]["hp_low_case"])
            recipe_path = folder / "recipe.json"
            recipe_path.write_text(json.dumps(recipe))
            image = build(recipe, ROOT)["hp_low_case-over"]
            source, target = folder/"source.png", folder/"hp_low_case-over.tga"
            image.save(source); image.save(target, compression=None)
            record = lambda path: {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)}
            item = {"role": "deathknight-rail-grid-1", "source": record(source),
                "transform": {"scale": 1, "offset": [0, 0]}, "construction": record(recipe_path)}
            manifest = folder / "manifest.json"
            manifest.write_text(json.dumps({"assets": {"hp_low_case-over": record(target)}}))
            (folder/"source-integrity.json").write_text(json.dumps({"schema": 1,
                "assetManifestSha256": sha(manifest), "paintings": {"hp_low_case-over": item}}))
            with self.assertRaisesRegex(ValueError, message):
                verify_pack(folder)

    def test_typed_source_cannot_waive_aperture(self):
        def original(operations):
            for operation in operations:
                if 'delta' in operation:
                    operation["delta"] = [[0 for _ in row] for row in operation["delta"]]
                else:
                    operation['targetKnots'] = copy.deepcopy(operation['sourceKnots'])
        self.bad_pack(original, "SOURCE APERTURE")

    def test_typed_source_cannot_move_mounting_toe(self):
        self.bad_pack(lambda operations: operations[0]["delta"].__setitem__(-2, [2]*len(operations[0]["cross"])), "SOURCE TOE")

    def test_dense_grid_rejects_clipping_fold_and_stencil(self):
        operation = copy.deepcopy(self.recipe['cases']['hp_low_case'][2])
        operation['targetKnots'][0][-1] -= 1
        with self.assertRaisesRegex(ValueError, 'cropping'):
            grid(self.images['hp_low_case-over'], operation)
        operation = copy.deepcopy(self.recipe['cases']['hp_low_case'][2])
        operation['sourceKnots'][0] = [0, 100, 90, 255]
        operation['targetKnots'][0] = [0, 90, 100, 255]
        with self.assertRaisesRegex(ValueError, 'folded'):
            grid(self.images['hp_low_case-over'], operation)
        operation = copy.deepcopy(self.recipe['cases']['hp_low_case'][2])
        operation['eraseFill'] = True
        with self.assertRaisesRegex(ValueError, 'unsupported'):
            grid(self.images['hp_low_case-over'], operation)


if __name__ == "__main__":
    unittest.main(verbosity=2)
