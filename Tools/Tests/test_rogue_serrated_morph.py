"""Requested morph replay, intact blade and complete terminal rejection tests."""
from pathlib import Path
import copy
import importlib.util
import json
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools'))
from RogueSerratedMorph import compose, split_original, morph_mount, validate
from ThemeSourceIntegrity import whole_painting
from ThemeHealthEndcaps import lowest_point

WORK = ROOT / 'Docs/Research_Assets/Rogue/Serrated-Join-2026-10-31'


class SerratedMorphTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads((WORK / 'construction.json').read_text())
        cls.recipe = cls.record['construction']
        cls.source = ROOT / cls.record['source']['path']
        cls.original = Image.open(ROOT / cls.recipe['original']['path']).convert('RGBA')
        cls.mask = Image.open(ROOT / cls.recipe['bladeMask']['path'])

    def test_complete_constructed_source_replays(self):
        self.assertTrue(validate(self.recipe, self.source, ROOT)['completeBladeRigidRgbaExact'])

    def test_partition_reconstructs_all_visible_original_rgba(self):
        mount, blade = split_original(self.original, self.mask)
        pixels = np.array(self.original)
        pixels[pixels[:, :, 3] == 0] = 0
        self.assertEqual(Image.alpha_composite(blade, mount).tobytes(), Image.fromarray(pixels).tobytes())

    def test_identity_grid_does_not_repaint_rgba(self):
        mount, _ = split_original(self.original, self.mask)
        grid = copy.deepcopy(self.recipe['mountGrid'])
        grid['dy'] = [[0] * len(grid['x']) for _ in grid['y']]
        self.assertEqual(morph_mount(mount, grid).tobytes(), mount.tobytes())

    def test_native_alpha_operation_is_not_supported(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['nativeAlphaStencil'] = 'Assets/hp_cap_case.tga'
        with self.assertRaisesRegex(ValueError, 'unsupported Serrated'):
            compose(recipe, ROOT)

    def test_native_mask_cannot_replace_component_partition(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['bladeMask']['path'] = 'Docs/Research_Assets/Rogue/Masks/hp_cap_case-terminal.png'
        with self.assertRaises(ValueError):
            compose(recipe, ROOT)

    def test_stale_original_fails(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['original']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'stale'):
            compose(recipe, ROOT)

    def test_blade_cannot_be_silently_moved_outside_scope(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['bladeTranslation'][0] = 0
        with self.assertRaisesRegex(ValueError, 'bounded source adjustment'):
            compose(recipe, ROOT)

    def test_grid_cannot_fold_mount(self):
        mount, _ = split_original(self.original, self.mask)
        grid = copy.deepcopy(self.recipe['mountGrid'])
        grid['dy'] = [[0] * len(grid['x']) for _ in grid['y']]
        grid['dy'][3] = [-160] * len(grid['x'])
        with self.assertRaisesRegex(ValueError, 'folded'):
            morph_mount(mount, grid)

    def test_grid_cannot_clip_paint_at_canvas_edge(self):
        mount, _ = split_original(self.original, self.mask)
        grid = copy.deepcopy(self.recipe['mountGrid'])
        grid['dy'][0][0] = 1
        with self.assertRaisesRegex(ValueError, 'may not crop'):
            morph_mount(mount, grid)

    def test_grid_cannot_hide_erasure_operation(self):
        mount, _ = split_original(self.original, self.mask)
        grid = copy.deepcopy(self.recipe['mountGrid'])
        grid['eraseFill'] = True
        with self.assertRaisesRegex(ValueError, 'unsupported mount'):
            morph_mount(mount, grid)

    def damaged_source(self, channel):
        pixels = np.array(Image.open(self.source).convert('RGBA'))
        y, x = np.argwhere(pixels[:, :, 3] == 255)[100]
        pixels[y, x, channel] = 0 if channel == 3 else (int(pixels[y, x, channel]) + 80) % 256
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / 'damaged.png'
            Image.fromarray(pixels).save(file)
            with self.assertRaisesRegex(ValueError, 'SOURCE RGBA changed'):
                validate(self.recipe, file, ROOT)

    def test_erased_source_pixel_fails(self):
        self.damaged_source(3)

    def test_added_rgb_patch_fails(self):
        self.damaged_source(0)

    def test_retired_unmorphed_source_cannot_substitute(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE RGBA changed'):
            validate(self.recipe, ROOT / 'Docs/Research_Assets/Rogue/Script-Edited/serrated-composed-source.png', ROOT)

    def test_uniform_export_cannot_crop_painted_edge(self):
        source = Image.open(self.source).convert('RGBA')
        transform = copy.deepcopy(self.record['transform'])
        transform['crop'][0] += 100
        with self.assertRaisesRegex(ValueError, 'CROP removes painted pixels'):
            whole_painting(source, transform, (1024, 256))

    def test_toe_correct_cut_upper_mount_still_fails_terminal(self):
        spec = importlib.util.spec_from_file_location('serrated_geometry_test', ROOT / 'Tools/Preview-RogueSerratedMorph.py')
        preview = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(preview)
        source = Image.open(self.source).convert('RGBA')
        cap = whole_painting(source, self.record['transform'], (1024, 256))
        front = Image.open(ROOT / 'Assets/Rogue/hp_cap_case-over.tga').convert('RGBA')
        self.assertEqual(preview.geometry(cap, front)['exposedOriginalTerminalBeyondAA'], 0)
        pixels = np.array(cap)
        pixels[70:105, 718:780, 3] = 0
        cut = Image.fromarray(pixels)
        self.assertEqual(lowest_point(cut), lowest_point(cap))
        with self.assertRaises(AssertionError):
            preview.geometry(cut, front)


if __name__ == '__main__':
    unittest.main(verbosity=2)
