"""Regression gates, including actual rejected Rogue exports. No live WoW claim.

python Tools/Tests/ThemeSourceIntegrity/test_integrity.py
"""
from pathlib import Path
import copy
import ast
import json
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'Tools'))
import ThemeSourceIntegrity as G

FIX = Path(__file__).resolve().parent/'Fixtures'


class Integrity(unittest.TestCase):
    def setUp(self):
        self.source = Image.new('RGBA', (32, 32))
        ImageDraw.Draw(self.source).rectangle((4, 4, 27, 27), fill=(60, 70, 80, 255), width=2)
        ImageDraw.Draw(self.source).rectangle((8, 8, 23, 23), fill=(0, 0, 0, 0))
        self.transform = {'scale': 1, 'offset': [0, 0]}

    def test_whole_rgba(self):
        G.verify_pixels(self.source, G.whole_painting(self.source, self.transform, (32, 32)))

    def test_uniform_scale_padding(self):
        expected = G.whole_painting(self.source, {'scale': 2, 'offset': [3, 2]}, (128, 128))
        self.assertEqual(expected.crop((3, 2, 67, 66)).tobytes(), self.source.resize((64, 64), Image.Resampling.LANCZOS).tobytes())

    def test_crop_cannot_delete_art(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE CROP'):
            G.whole_painting(self.source, dict(self.transform, crop=[8, 8, 24, 24]), (32, 32))

    def test_crop_margins_only(self):
        G.whole_painting(self.source, dict(self.transform, crop=[4, 4, 28, 28]), (32, 32))

    def test_cannot_clip_canvas(self):
        with self.assertRaisesRegex(ValueError, 'canvas'):
            G.whole_painting(self.source, {'scale': 1, 'offset': [-1, 0]}, (32, 32))

    def test_alpha_stencil_rejected(self):
        p = np.array(self.source); p[4:8, :, 3] = 0
        with self.assertRaisesRegex(ValueError, 'SOURCE RGBA'):
            G.verify_pixels(self.source, Image.fromarray(p))

    def test_edge_rgb_extrusion_rejected(self):
        p = np.array(self.source); p[5, 5, :3] = [230, 80, 90]
        with self.assertRaisesRegex(ValueError, 'SOURCE RGBA'):
            G.verify_pixels(self.source, Image.fromarray(p))

    def test_unpainted_native_extension_rejected(self):
        p = np.array(self.source); p[0:3, 0:3] = [60, 70, 80, 255]
        with self.assertRaisesRegex(ValueError, 'SOURCE RGBA'):
            G.verify_pixels(self.source, Image.fromarray(p))

    def test_unknown_operation_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unsupported'):
            G.whole_painting(self.source, dict(self.transform, nativeAlpha=True), (32, 32))

    def test_clear_aperture_passes(self):
        fill = Image.new('L', (32, 32)); ImageDraw.Draw(fill).rectangle((9, 9, 22, 22), fill=255)
        G.aperture(self.source, fill)

    def test_small_overlap_is_not_automatic_permission(self):
        fill = Image.new('L', (32, 32), 255)
        paint = Image.new('RGBA', (32, 32)); paint.putpixel((16, 16), (90, 80, 70, 255))
        with self.assertRaisesRegex(ValueError, 'SOURCE APERTURE'):
            G.aperture(paint, fill)

    def test_explicit_bridge_survives(self):
        fill = Image.new('L', (32, 32), 255)
        paint = Image.new('RGBA', (32, 32)); paint.putpixel((16, 16), (90, 80, 70, 255))
        bridge = Image.new('L', (32, 32)); bridge.putpixel((16, 16), 255)
        G.aperture(paint, fill, bridge)

    def test_blanket_bridge_mask_rejected(self):
        fill = Image.new('L', (32, 32), 255)
        with self.assertRaisesRegex(ValueError, 'blanket/oversized'):
            G.aperture(self.source, fill, fill)

    def test_real_rogue_clipped_cradle_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE RGBA'):
            G.verify_pixels(G.read(FIX/'pw_crystal_case-whole-source.png'), G.read(FIX/'pw_crystal_case-rejected.tga'))

    def test_real_rogue_health_mask_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE RGBA'):
            G.verify_pixels(G.read(FIX/'hp_cap_case-whole-source.png'), G.read(FIX/'hp_cap_case-rejected.tga'))

    def test_real_rogue_bad_opening_rejected_before_export(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE APERTURE'):
            G.aperture(G.read(FIX/'hp_cap_case-whole-source.png'), Image.open(FIX/'hp_cap_case-fill.png'))

    def test_frozen_fixture_hashes(self):
        manifest = json.loads((FIX/'manifest.json').read_text())
        for name, digest in manifest.items():
            self.assertEqual(G.sha(FIX/name), digest, name)


class Production(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.folder = self.root/'draft'; self.folder.mkdir()
        (self.root/'Docs').mkdir(); (self.root/'Docs/Theme Asset Geometry.json').write_text('{}')
        Image.new('RGBA', (32, 32), (40, 50, 60, 255)).save(self.root/'source.png')
        G.read(self.root/'source.png').save(self.folder/'new-casing.tga')
        self.manifest = {'assets': {'new-casing': {'sha256': G.sha(self.folder/'new-casing.tga')}}}
        self.save('manifest.json', self.manifest)
        self.proof = {'schema': 1, 'assetManifestSha256': G.sha(self.folder/'manifest.json'), 'paintings': {
            'new-casing': {'role': 'painting', 'source': {'path': 'source.png', 'sha256': G.sha(self.root/'source.png')},
                           'transform': {'scale': 1, 'offset': [0, 0]}}}}
        self.save('source-integrity.json', self.proof)
        self.review = {'assetManifestSha256': G.sha(self.folder/'manifest.json'), 'sourceIntegritySha256': G.sha(self.folder/'source-integrity.json'),
                       'numericalPassed': True, 'maintainerVisualApproved': True, 'representativeLiveApproved': True, 'evidence': {}}
        for role in ('complete-1x', 'complete-2x', 'all-tiers', 'fill-states', 'none-all-caps', 'representative-live'):
            path = self.root/(role+'.txt'); path.write_text('Test fixture only, not actual review approval')
            self.review['evidence'][role] = {'path': path.name, 'sha256': G.sha(path)}
        self.save('production-review.json', self.review)

    def save(self, name, value):
        (self.folder/name).write_text(json.dumps(value))

    def test_current_proof_passes(self):
        self.assertEqual(G.require_production(self.folder, self.root)['paintingsChecked'], 1)

    def test_missing_proof_blocks_install(self):
        (self.folder/'source-integrity.json').unlink()
        with self.assertRaisesRegex(ValueError, 'missing source-integrity'):
            G.require_production(self.folder, self.root)

    def test_missing_source_inventory_blocks(self):
        self.proof['paintings'] = {}; self.save('source-integrity.json', self.proof)
        with self.assertRaisesRegex(ValueError, 'missing painting'):
            G.verify_pack(self.folder, self.root)

    def test_stale_manifest_blocks(self):
        self.save('manifest.json', dict(self.manifest, changed=True))
        with self.assertRaisesRegex(ValueError, 'manifest binding'):
            G.require_production(self.folder, self.root)

    def test_changed_export_blocks(self):
        Image.new('RGBA', (32, 32), 'red').save(self.folder/'new-casing.tga')
        with self.assertRaisesRegex(ValueError, 'stale export'):
            G.require_production(self.folder, self.root)

    def test_stale_source_blocks(self):
        Image.new('RGBA', (32, 32), 'red').save(self.root/'source.png')
        with self.assertRaisesRegex(ValueError, 'stale evidence/source'):
            G.require_production(self.folder, self.root)

    def test_failed_gate_blocks(self):
        for key in ('numericalPassed', 'maintainerVisualApproved', 'representativeLiveApproved'):
            review = copy.deepcopy(self.review); review[key] = False; self.save('production-review.json', review)
            with self.assertRaisesRegex(ValueError, 'gates must all pass'):
                G.require_production(self.folder, self.root)

    def test_missing_review_blocks(self):
        (self.folder/'production-review.json').unlink()
        with self.assertRaisesRegex(ValueError, 'missing production-review'):
            G.require_production(self.folder, self.root)

    def test_stale_picture_blocks(self):
        (self.root/'complete-2x.txt').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'stale evidence'):
            G.require_production(self.folder, self.root)

    def test_missing_full_view_blocks(self):
        del self.review['evidence']['complete-2x']; self.save('production-review.json', self.review)
        with self.assertRaisesRegex(ValueError, 'missing full assembly'):
            G.require_production(self.folder, self.root)

    def test_preview_cannot_claim_production(self):
        self.save('production-review.json', {'runtimeInstalled': False, 'productionAccepted': False})
        with self.assertRaises(ValueError):
            G.require_production(self.folder, self.root)

    def test_production_copy_paths_invoke_guard_first(self):
        if not (ROOT/'Tools/Install-WarriorAssets.py').is_file():
            self.skipTest('Installer integration test requires the full checkout; kit contains source replay tests')
        for file, function in (
            ('Check-RogueAssets.py', 'install'), ('Repair-RogueShadows.py', 'install'),
            ('Install-WarriorAssets.py', 'main'), ('Check-ShamanAssets.py', 'install'),
            ('Install-ShamanTheme.py', 'main')):
            tree = ast.parse((ROOT/'Tools'/file).read_text(encoding='utf-8-sig'))
            fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == function)
            calls = [n for n in ast.walk(fn) if isinstance(n, ast.Call)]
            guards = [n.lineno for n in calls if isinstance(n.func, ast.Name) and n.func.id == 'require_production']
            copies = [n.lineno for n in calls if isinstance(n.func, ast.Attribute) and n.func.attr in ('copyfile', 'install')]
            self.assertTrue(guards, file)
            self.assertLess(min(guards), min(copies), file)


if __name__ == '__main__':
    unittest.main()
