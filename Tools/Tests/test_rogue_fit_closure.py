"""Own-painting morph, native functional glass and actual join regressions."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'Tools'))
from RogueFitClosureSource import build, validate, verify_ring_composite, axis_morph
from ThemeSourceIntegrity import verify_pack, aperture
from ThemeHealthEndcaps import lowest_point

WORK = ROOT/'Docs/Research_Assets/Rogue/Fit-Closure-2026-10-31'
OUT = ROOT/'Assets_Draft/Rogue-Fit-Closure-2026-10-31'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def record(path):
    return {'path':path.relative_to(ROOT).as_posix(),'sha256':digest(path)}


class FitClosureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert WORK.resolve().is_relative_to(ROOT.resolve())
        cls.recipe = json.loads((WORK/'source-recipe.json').read_text())
        cls.images = build(cls.recipe, ROOT)
        cls.item = json.loads((OUT/'source-integrity.json').read_text())['paintings']['actionbutton-border']
        spec = importlib.util.spec_from_file_location('closure_test_preview',ROOT/'Tools/Preview-RogueFitClosure.py')
        cls.preview = importlib.util.module_from_spec(spec); spec.loader.exec_module(cls.preview)

    def test_all_source_outputs_replay_exactly(self):
        paths = {n:WORK/'Sources'/(n+'.png') for n in self.images}
        self.assertTrue(validate(self.recipe, paths, ROOT)['functionalButtonGlassUnchanged'])

    def test_shared_gate_accepts_only_typed_exact_glass_composition(self):
        self.assertEqual(verify_pack(OUT)['paintingsChecked'],5)
        composite, painting = verify_ring_composite(self.item,ROOT)
        field=Image.open(ROOT/'Docs/Research_Assets/Templates/actionbutton-border-fill.png')
        aperture(painting,field)
        # Native glass plus legal contour AA can exceed200 after blending.
        # The old final-opacity classification must still reject that input.
        with self.assertRaisesRegex(ValueError,'SOURCE APERTURE'):
            aperture(composite,field)

    def test_glass_role_cannot_hide_generic_skip_flag(self):
        item=copy.deepcopy(self.item);item['skipAperture']=True
        with self.assertRaisesRegex(ValueError,'unsupported ring functional'):
            verify_ring_composite(item,ROOT)

    def test_completed_glass_cannot_be_repositioned(self):
        item=copy.deepcopy(self.item);item['transform']['offset']=[1,0]
        with self.assertRaisesRegex(ValueError,'cannot crop or transform'):
            verify_ring_composite(item,ROOT)

    def test_stale_family_source_fails(self):
        recipe=copy.deepcopy(self.recipe);recipe['familyAuthority']['sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'stale'):
            build(recipe,ROOT)

    def test_native_alpha_stencil_operation_fails(self):
        recipe=copy.deepcopy(self.recipe);recipe['buttonRadius']['nativeMask']='Assets/actionbutton-border.tga'
        with self.assertRaisesRegex(ValueError,'unsupported ring'):
            build(recipe,ROOT)

    def test_health_grid_cannot_hide_fill_erasure(self):
        recipe=copy.deepcopy(self.recipe);recipe['healthGrids'][0]['eraseFill']=True
        with self.assertRaisesRegex(ValueError,'unsupported source grid'):
            build(recipe,ROOT)

    def test_health_source_whole_terminal_and_caps_pass(self):
        caps={k:Image.open((ROOT/'Assets_Draft/Rogue-Serrated-Join-2026-10-31' if k=='serrated' else ROOT/'Assets/Rogue')/('ornament-'+k+'-hp_cap_case.tga')).convert('RGBA') for k in ('twinguard','serrated','venom')}
        result=self.preview.health_metrics(self.images['hp_cap_case-over'],caps)
        self.assertEqual(result['completeCasingFrozenMissingBeyondAA'],0)
        self.assertTrue(all(v['combinedFillOcclusion']<=.20 for v in result['caps'].values()))
        pixels=np.array(self.images['hp_cap_case-over']);pixels[70:96,780:806,3]=0
        cut=Image.fromarray(pixels)
        self.assertEqual(lowest_point(cut),lowest_point(self.images['hp_cap_case-over']))
        with self.assertRaises(AssertionError):self.preview.health_metrics(cut,caps)

    def test_both_native_faces_unchanged_and_floor_gaps_closed(self):
        result=self.preview.crystal_layers(self.images)
        self.assertTrue(all(v['centralFaceToSupportGapLayout'][1]<=.1 for v in result.values()))

    def test_old_floor_still_fails_gap_check(self):
        images=dict(self.images);images['pw_crystal_case-seat']=Image.open(ROOT/'Assets_Draft/Rogue-Layered-Rebuild-2026-10-30/pw_crystal_case-seat.tga').convert('RGBA')
        with self.assertRaisesRegex(AssertionError,'visible central gap'):
            self.preview.crystal_layers(images)

    def test_normal_floor_cannot_substitute_for_deeper_ice(self):
        images=dict(self.images);images['pw_crystal_case-seat-wrath']=images['pw_crystal_case-seat']
        with self.assertRaises(AssertionError):self.preview.crystal_layers(images)

    def test_icon_cut_edge_is_hidden_in_actual_runtime_projection(self):
        composite,paint=verify_ring_composite(self.item,ROOT)
        result=self.preview.button_metrics(composite,paint)
        self.assertEqual(result['visibleMaskedIconCutEdgePixelsBelow200'],0)
        old=self.preview.button_metrics(Image.open(ROOT/'Assets_Draft/Rogue-Concept-Family-v3-2026-10-31/actionbutton-border.tga').convert('RGBA'))
        self.assertGreater(old['visibleMaskedIconCutEdgePixelsBelow200'],0)

    def bad_ring_pack(self, change, expected):
        with tempfile.TemporaryDirectory(prefix='ring-negative-',dir=WORK) as folder:
            temp=Path(folder);assert temp.resolve().is_relative_to(WORK.resolve())
            recipe=copy.deepcopy(self.recipe);change(recipe)
            image=build(recipe,ROOT)['actionbutton-border']
            source=temp/'source.png';image.save(source)
            recipe_path=temp/'recipe.json';recipe_path.write_text(json.dumps(recipe))
            tga=temp/'actionbutton-border.tga';image.save(tga,compression=None)
            manifest=temp/'manifest.json';manifest.write_text(json.dumps({'assets':{'actionbutton-border':{'sha256':digest(tga),'canvas':[256,256]}}}))
            item={'role':'rogue-ring-native-glass-1','source':record(source),'transform':{'scale':1,'offset':[0,0]},'construction':record(recipe_path)}
            (temp/'source-integrity.json').write_text(json.dumps({'schema':1,'assetManifestSha256':digest(manifest),'paintings':{'actionbutton-border':item}}))
            with self.assertRaisesRegex(ValueError,expected):verify_pack(temp,ROOT)

    def test_typed_glass_cannot_waive_real_opaque_fill_intrusion(self):
        self.bad_ring_pack(lambda r:r['buttonRadius']['targetRadii'].__setitem__(2,32.5),'SOURCE APERTURE')

    def test_typed_glass_cannot_waive_native_outer_bounds(self):
        self.bad_ring_pack(lambda r:r['buttonRadius']['targetRadii'].__setitem__(3,76),'SOURCE BOUNDS')

    def test_floor_cannot_be_replaced_by_foreground_plate(self):
        recipe=copy.deepcopy(self.recipe);recipe['floor']['source']=recipe['familyAuthority']
        with self.assertRaisesRegex(ValueError,'wrong original whole floor'):
            build(recipe,ROOT)

    def test_source_rgba_patch_is_not_accepted(self):
        with tempfile.TemporaryDirectory(prefix='rgba-negative-',dir=WORK) as folder:
            temp=Path(folder);assert temp.resolve().is_relative_to(WORK.resolve())
            images={n:WORK/'Sources'/(n+'.png') for n in self.images}
            pixels=np.array(self.images['actionbutton-border']);y,x=np.argwhere(pixels[:,:,3]==255)[40]
            pixels[y,x,:3]=(255,0,255);source=temp/'patched.png';Image.fromarray(pixels).save(source)
            images['actionbutton-border']=source
            with self.assertRaisesRegex(ValueError,'SOURCE RGBA changed'):validate(self.recipe,images,ROOT)


if __name__=='__main__':unittest.main(verbosity=2)
