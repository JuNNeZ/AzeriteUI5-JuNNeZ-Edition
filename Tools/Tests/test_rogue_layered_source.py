"""Source destruction, false layer placement and geometry override regressions."""
from pathlib import Path
import copy
import importlib.util
import json
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools'))
from RogueLayeredSource import rasterize, validate_source
from RogueLayeredContract import health_preflight, validate_layers, verify_layered_pack
from ThemeSourceIntegrity import require_production

WORK = ROOT / 'Docs/Research_Assets/Rogue/Layered-Rebuild-2026-10-30'
OUT = ROOT / 'Assets_Draft/Rogue-Layered-Rebuild-2026-10-30'


def read(path):
    return Image.open(path).convert('RGBA')


class RogueLayeredSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((WORK / 'layer-contract.json').read_text())
        cls.seat = read(OUT / 'pw_crystal_case-seat.tga')
        cls.holder = read(OUT / 'pw_crystal_case.tga')
        cls.health = read(OUT / 'hp_cap_case-over.tga')
        spec = importlib.util.spec_from_file_location('rogue_layered_test_renderer', ROOT / 'Tools/Build-RogueLayeredRepair.py')
        cls.build = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.build)

    def test_complete_source_export_and_layer_contract(self):
        result = verify_layered_pack(OUT, WORK, ROOT)
        self.assertTrue(result['health']['completeTerminalUnchanged'])
        for state in result['nativeLayers']['contacts'].values():
            self.assertGreater(state['unsupportedPixelsBefore'], 0)
            self.assertEqual(state['unsupportedPixelsAfter'], 0)

    def damaged_source(self, channel):
        original = read(WORK / 'Sources/seat.png')
        pixels = np.array(original)
        y, x = np.argwhere(pixels[:, :, 3] == 255)[20]
        pixels[y, x, channel] = 0 if channel == 3 else 255
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / 'damaged.png'
            Image.fromarray(pixels).save(file)
            with self.assertRaisesRegex(ValueError, 'raster differs'):
                validate_source(WORK / 'Sources/seat.scene.json', file, ROOT)

    def test_removed_source_paint_fails(self):
        self.damaged_source(3)

    def test_changed_source_rgb_fails(self):
        self.damaged_source(0)

    def test_material_hash_change_fails(self):
        scene = json.loads((WORK / 'Sources/seat.scene.json').read_text())
        scene['materials']['steel']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'stale material'):
            rasterize(scene, ROOT)

    def test_stale_native_geometry_reference_fails(self):
        scene = json.loads((WORK / 'Sources/health.scene.json').read_text())
        scene['geometryReferences']['native']['sha256'] = '0' * 64
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / 'scene.json'
            file.write_text(json.dumps(scene))
            with self.assertRaisesRegex(ValueError, 'stale construction geometry'):
                validate_source(file, WORK / 'Sources/health.png', ROOT)

    def test_unsupported_stencil_operation_fails(self):
        scene = json.loads((WORK / 'Sources/seat.scene.json').read_text())
        scene['nativeAlphaStencil'] = 'Assets/pw_crystal_case.tga'
        with self.assertRaisesRegex(ValueError, 'undeclared construction'):
            rasterize(scene, ROOT)

    def test_undeclared_face_operation_fails(self):
        scene = json.loads((WORK / 'Sources/seat.scene.json').read_text())
        scene['faces'][0]['eraseFillAfterPainting'] = True
        with self.assertRaisesRegex(ValueError, 'unsupported face'):
            rasterize(scene, ROOT)

    def test_source_intrusion_into_health_fill_fails(self):
        pixels = np.array(self.health)
        pixels[110:120, 500:510] = [60, 60, 60, 255]
        with self.assertRaisesRegex(ValueError, 'SOURCE APERTURE'):
            health_preflight(Image.fromarray(pixels), ROOT)

    def test_frozen_terminal_cannot_be_cut_to_pass(self):
        frozen = np.asarray(Image.open(ROOT / 'Docs/Research_Assets/Rogue/Masks/hp_cap_case-terminal.png')) > 128
        fill = np.asarray(Image.open(ROOT / 'Docs/Research_Assets/Templates/hp_cap_case-fill.png')) > 128
        pixels = np.array(self.health)
        y, x = np.argwhere(frozen & ~fill & (pixels[:, :, 3] > 200))[100]
        pixels[y, x, 3] = 0
        with self.assertRaisesRegex(ValueError, 'frozen terminal'):
            health_preflight(Image.fromarray(pixels), ROOT)

    def test_incorrect_layer_orders_fail(self):
        for order in (['seat', 'native-backdrop', 'native-fill', 'original-front'],
                      ['native-backdrop', 'native-fill', 'seat', 'original-front']):
            data = copy.deepcopy(self.contract)
            data['layerOrder'] = order
            with self.assertRaisesRegex(ValueError, 'above backdrop shadow and below native fill'):
                validate_layers(data, self.seat, self.holder, ROOT)

    def test_layout_compensation_fails(self):
        data = copy.deepcopy(self.contract)
        data['caseRect'][1] -= 7
        with self.assertRaisesRegex(ValueError, 'geometry/UV override'):
            validate_layers(data, self.seat, self.holder, ROOT)

    def test_bottle_or_jaw_repaint_fails(self):
        pixels = np.array(self.holder)
        y, x = np.argwhere(pixels[:, :, 3] == 255)[20]
        pixels[y, x, 0] = (int(pixels[y, x, 0]) + 1) % 256
        with self.assertRaisesRegex(ValueError, 'painting changed'):
            validate_layers(self.contract, self.seat, Image.fromarray(pixels), ROOT)

    def test_missing_seat_keeps_gap_and_fails(self):
        with self.assertRaisesRegex(ValueError, 'lower than native mounting floor|unsupported air'):
            validate_layers(self.contract, Image.new('RGBA', self.seat.size), self.holder, ROOT)

    def test_painted_facets_survive_all_states(self):
        b = self.build
        db = b.C.db_for('Seasoned')
        for ice in (False, True):
            for fraction in (0, .5, 1):
                old = b.crystal_scene(fraction, ice, False)
                new = b.crystal_scene(fraction, ice, True)
                mask = b.A.P.project(b.A.P.alpha(db['PowerBarTextureWrath' if ice else 'PowerBarTexture']),
                                     (40, 20, 196, 196), (0, 0, 300, 290), old.size)
                # Protect the native painted-face silhouette even at 0%, when
                # its dark backdrop facet painting is visible. The separate
                # flat foot/shadow outside that silhouette receives the floor.
                protected = np.asarray(mask.filter(ImageFilter.MinFilter(3))) > 200
                self.assertTrue(np.array_equal(np.asarray(old)[protected], np.asarray(new)[protected]), (ice, fraction))

    def test_previous_wall_cannot_be_reclassified_as_floor(self):
        wall = read(ROOT / 'Assets_Draft/Rogue-Painted-Repair-review-2026-10-30/pw_crystal_case.tga')
        with self.assertRaisesRegex(ValueError, 'SOURCE APERTURE'):
            validate_layers(self.contract, wall, self.holder, ROOT)

    def test_production_is_blocked_without_visual_and_live_approval(self):
        with self.assertRaisesRegex(ValueError, 'production-review'):
            require_production(OUT, ROOT)


if __name__ == '__main__':
    unittest.main(verbosity=2)
