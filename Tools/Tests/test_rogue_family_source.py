"""Complete-object atlas, intact painting and exact functional-layer regressions."""
from pathlib import Path
import copy
import hashlib
import json
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools'))
from RogueFamilySource import extract, grounded, validate, validate_composites, functional_shade, missing_frozen_terminal

WORK = ROOT / 'Docs/Research_Assets/Rogue/Concept-Family-2026-10-31'


class FamilySourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.construction = json.loads((WORK / 'Sources/construction-v3.json').read_text())
        cls.recipe = cls.construction['recipe']
        cls.parts = {n: ROOT / p['path'] for n, p in cls.construction['rawParts'].items()}
        cls.sources = {n: ROOT / p['path'] for n, p in cls.construction['sources'].items()}

    def test_whole_source_replay(self):
        result = validate(self.recipe, self.construction['grounding'], self.parts, self.sources, ROOT)
        self.assertEqual(result['wholeObjectsReplayed'], 4)
        self.assertEqual(validate_composites(self.construction['functionalComposites'], ROOT)['completeNativeSourcesReplayed'], 4)

    def test_unknown_stencil_fails(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['nativeAlphaStencil'] = 'Assets/hp_cap_case.tga'
        with self.assertRaisesRegex(ValueError, 'unsupported atlas'):
            extract(recipe, ROOT)

    def test_stale_atlas_fails(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['atlas']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'stale'):
            extract(recipe, ROOT)

    def test_cut_painting_fails(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['cells']['hp_cap_case-over'][0] = 600
        with self.assertRaisesRegex(ValueError, 'clips an actual painting'):
            extract(recipe, ROOT)

    def test_overlap_fails(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['cells']['pw_crystal_case'][1] = 200
        with self.assertRaises(ValueError):
            extract(recipe, ROOT)

    def test_missing_object_fails(self):
        recipe = copy.deepcopy(self.recipe)
        del recipe['cells']['minimap-border']
        with self.assertRaisesRegex(ValueError, 'four-object'):
            extract(recipe, ROOT)

    def test_unassigned_paint_fails(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['cells']['minimap-border'] = [0, 0, 10, 10]
        with self.assertRaises(ValueError):
            extract(recipe, ROOT)

    def damaged_raw(self, channel):
        name = 'actionbutton-border'
        im = Image.open(self.parts[name]).convert('RGBA')
        pixels = np.array(im)
        y, x = np.argwhere(pixels[:, :, 3] == 255)[20]
        pixels[y, x, channel] = 0 if channel == 3 else 255
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / 'changed.png'
            Image.fromarray(pixels).save(file)
            parts = dict(self.parts, **{name: file})
            with self.assertRaisesRegex(ValueError, 'raw atlas painting RGBA changed'):
                validate(self.recipe, self.construction['grounding'], parts, self.sources, ROOT)

    def test_alpha_erasure_fails(self):
        self.damaged_raw(3)

    def test_rgb_change_fails(self):
        self.damaged_raw(0)

    def test_unknown_grounding_operation_fails(self):
        raw = Image.open(self.parts['minimap-border']).convert('RGBA')
        rule = copy.deepcopy(self.construction['grounding']['minimap-border'])
        rule['clipPaintingToNative'] = True
        with self.assertRaisesRegex(ValueError, 'unsupported grounding'):
            grounded(raw, rule)

    def test_extreme_shadow_cannot_hide_bad_source(self):
        raw = Image.open(self.parts['minimap-border']).convert('RGBA')
        rule = copy.deepcopy(self.construction['grounding']['minimap-border'])
        rule['strength'] = 1
        with self.assertRaisesRegex(ValueError, 'invalid grounding'):
            grounded(raw, rule)

    def test_functional_component_exact_and_separate(self):
        for name in ('actionbutton-border', 'pw_crystal_case'):
            native = np.asarray(Image.open(ROOT / 'Assets' / (name + '.tga')).convert('RGBA'))
            field = np.asarray(Image.open(ROOT / 'Docs/Research_Assets/Templates' / (name + '-fill.png')).convert('L')) > 128
            layer = np.asarray(functional_shade(name, ROOT))
            keep = field & (native[:, :, 3] > 0) & (native[:, :, 3] <= 200)
            self.assertTrue(np.array_equal(layer[keep], native[keep]))
            self.assertTrue(np.all(layer[~keep] == 0))

    def test_native_glass_cannot_stencil_painting(self):
        records = copy.deepcopy(self.construction['functionalComposites'])
        records['actionbutton-border']['eraseOpening'] = True
        with self.assertRaisesRegex(ValueError, 'unsupported native composition'):
            validate_composites(records, ROOT)

    def test_stale_native_component_fails(self):
        records = copy.deepcopy(self.construction['functionalComposites'])
        records['actionbutton-border']['native']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'stale'):
            validate_composites(records, ROOT)

    def replacement_recipe(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['schema'] = 'rogue-whole-atlas-2'
        source = self.parts['minimap-border']
        recipe['wholeSourceReplacements'] = {'minimap-border': {
            'path': source.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(source.read_bytes()).hexdigest()}}
        return recipe

    def test_whole_replacement_preserves_every_rgba_pixel(self):
        recipe = self.replacement_recipe()
        actual = extract(recipe, ROOT)['minimap-border']
        expected = Image.open(self.parts['minimap-border']).convert('RGBA')
        self.assertEqual(actual.size, expected.size)
        self.assertEqual(actual.tobytes(), expected.tobytes())

    def test_replacement_cannot_crop_to_hide_paint(self):
        recipe = self.replacement_recipe()
        recipe['wholeSourceReplacements']['minimap-border']['crop'] = [10, 10, 20, 20]
        with self.assertRaisesRegex(ValueError, 'cannot crop'):
            extract(recipe, ROOT)

    def test_stale_replacement_fails(self):
        recipe = self.replacement_recipe()
        recipe['wholeSourceReplacements']['minimap-border']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'stale'):
            extract(recipe, ROOT)

    def test_extra_replacement_object_fails(self):
        recipe = self.replacement_recipe()
        recipe['wholeSourceReplacements']['extra'] = recipe['wholeSourceReplacements']['minimap-border']
        with self.assertRaisesRegex(ValueError, 'inventory'):
            extract(recipe, ROOT)

    def test_native_entire_terminal_is_retained(self):
        frozen = Image.open(ROOT / 'Docs/Research_Assets/Rogue/Masks/hp_cap_case-terminal.png')
        native = Image.open(ROOT / 'Assets/hp_cap_case.tga').convert('RGBA')
        self.assertEqual(int(missing_frozen_terminal(native, frozen).sum()), 0)

    def test_toe_aligned_family_cannot_shrink_original_terminal(self):
        frozen = Image.open(ROOT / 'Docs/Research_Assets/Rogue/Masks/hp_cap_case-terminal.png')
        rejected = Image.open(ROOT / 'Assets_Draft/Rogue-Concept-Family-v3-2026-10-31/hp_cap_case-over.tga').convert('RGBA')
        self.assertGreater(int(missing_frozen_terminal(rejected, frozen).sum()), 0)

    def test_cut_upper_terminal_is_not_hidden_by_correct_toe(self):
        frozen = Image.open(ROOT / 'Docs/Research_Assets/Rogue/Masks/hp_cap_case-terminal.png')
        native = np.array(Image.open(ROOT / 'Assets/hp_cap_case.tga').convert('RGBA'))
        native[65:92, 760:820, 3] = 0
        self.assertGreater(int(missing_frozen_terminal(Image.fromarray(native), frozen).sum()), 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
