"""Replay the approved Rogue registration repair from a frozen live-feedback baseline.

No painting, runtime geometry changes or rebuilding unrelated pending work.
The original full-pack checker retains its historical protected-tree baseline;
this gate independently checks current exports and protects the current tree.
"""
import argparse
import copy
import json
import shutil

import numpy as np
from PIL import Image, ImageDraw

from importlib.util import spec_from_file_location, module_from_spec
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = spec_from_file_location('rogue_shadow_build', ROOT/'Tools/Build-RogueAssets.py')
B = module_from_spec(spec)
spec.loader.exec_module(B)
WORK = B.WORK/'Live-Repair-2026-10-28'
BEFORE = WORK/'Before'
NAMES = tuple(case+suffix for case in B.CASES for suffix in ('', '-over')) + (
    'pw_crystal_case', 'pw_crystal_case_low', 'minimap-border')


def snapshot():
    WORK.mkdir(exist_ok=True)
    if (WORK/'baseline.json').exists():
        return
    manifest = json.loads((B.OUT/'manifest.json').read_text())
    for name, item in manifest['assets'].items():
        assert B.sha(B.OUT/(name+'.tga')) == item['sha256'], name
        assert B.sha(ROOT/'Assets/Rogue'/(name+'.tga')) == item['sha256'], name
    BEFORE.mkdir(exist_ok=True)
    for name in (*NAMES, 'manifest'):
        suffix = '.json' if name == 'manifest' else '.tga'
        shutil.copyfile(B.OUT/(name+suffix), BEFORE/(name+suffix))
    excluded = {'Assets/Rogue/'+name+'.tga' for name in NAMES} | {'Assets/Rogue/manifest.json'}
    protected = {p.relative_to(ROOT).as_posix(): B.sha(p)
                 for folder in ('Assets', 'Core', 'Layouts', 'Options', 'Components')
                 for p in (ROOT/folder).rglob('*') if p.is_file() and p.relative_to(ROOT).as_posix() not in excluded}
    B.write(WORK/'baseline.json', {'manifestSha256': B.sha(B.OUT/'manifest.json'),
        'protected': protected, 'sources': manifest['sources'],
        'terminalMasks': {case: B.sha(B.WORK/'Masks'/(case+'-terminal.png')) for case in B.CASES},
        'scope': list(NAMES), 'liveValidated': False})


def build():
    snapshot()
    manifest = json.loads((BEFORE/'manifest.json').read_text())
    fits = {}
    for case in B.CASES:
        back, front, fit = B.register_casing(case)
        # Rebuilding registration must reproduce every existing painted texel;
        # only grounding shadow is permitted to change in this revision.
        back.save(B.OUT/(case+'.tga'))
        front.save(B.OUT/(case+'-over.tga'))
        fits[case] = fit
    for name in NAMES[8:]:
        pending, fit = B.ordinary(name)
        pending[name].save(B.OUT/(name+'.tga'))
        fits[name] = fit
    for name in NAMES:
        manifest['assets'][name]['sha256'] = B.sha(B.OUT/(name+'.tga'))
    B.write(WORK/'registration.json', fits)
    manifest['visualRepair'] = {'path': (WORK/'registration.json').relative_to(ROOT).as_posix(),
        'sha256': B.sha(WORK/'registration.json'), 'scope': list(NAMES),
        'sources': {name: B.sha(WORK/name) for name in ('rail-paint.png', 'rail-paint.json')},
        'buttonTint': 'native grey retained by RogueTheme; icons and alpha unchanged',
        'liveValidated': False}
    B.write(B.OUT/'manifest.json', manifest)
    verify()


def verify():
    baseline = json.loads((WORK/'baseline.json').read_text())
    original = json.loads((BEFORE/'manifest.json').read_text())
    manifest = json.loads((B.OUT/'manifest.json').read_text())
    C = B.module('rogue_shadow_style', 'Check-ThemeAssetStyle.py')
    assert B.sha(ROOT/manifest['visualRepair']['path']) == manifest['visualRepair']['sha256'], 'Registration record changed'
    for name, digest in manifest['visualRepair']['sources'].items():
        assert B.sha(WORK/name) == digest, 'Repair source changed: '+name
    for relative, digest in baseline['protected'].items():
        followup = WORK/'layering-followup.json'
        if relative == 'Core/ThemeEffects.lua' and followup.exists():
            revision = json.loads(followup.read_text())
            assert revision['beforeSha256'] == digest and B.sha(ROOT/relative) == revision['afterSha256'], 'Layering follow-up changed'
        else:
            assert B.sha(ROOT/relative) == digest, 'Unrelated file changed: '+relative
    for relative, digest in baseline['sources'].items():
        assert B.sha(B.WORK/relative) == digest, 'Source painting changed: '+relative
    for case, digest in baseline['terminalMasks'].items():
        assert B.sha(B.WORK/'Masks'/(case+'-terminal.png')) == digest, 'Frozen mask changed'
    assert set(original['assets']) == set(manifest['assets']) and len(manifest['assets']) == 77
    records = {}
    for name, item in manifest['assets'].items():
        path = B.OUT/(name+'.tga')
        assert B.sha(path) == item['sha256'], name
        failures, notes = C.check(path)
        assert not failures, (name, failures)
        if name not in NAMES:
            assert item['sha256'] == original['assets'][name]['sha256'], 'Unrelated art changed: '+name
        else:
            old, new = np.asarray(B.read(BEFORE/(name+'.tga'))), np.asarray(B.read(path))
            assert old.shape == new.shape
            if name != 'minimap-border':
                # Solid paint and all glass/fill pixels must remain exact.
                native = np.asarray(B.read(ROOT/'Assets'/(name.replace('-over','')+'.tga')))
                base = name.replace('-over','')
                allowed = (native[:, :, 3] <= 200) & (native[:, :, :3].max(2) == 0)
                fill_path = B.TEMPLATES/(base+'-fill.png')
                if fill_path.exists():
                    allowed &= np.asarray(Image.open(fill_path).convert('L')) == 0
                if base in B.CASES:
                    terminal = np.asarray(Image.open(B.WORK/'Masks'/(base+'-terminal.png')).convert('L')) > 0
                    allowed &= ~terminal
                    registration = np.asarray(Image.open(B.WORK/'Masks'/(base+'-registration-rgb.png')).convert('L')) > 0
                    assert not (registration & terminal).any(), 'Terminal material changed'
                    assert np.array_equal(old[registration, 3], new[registration, 3]), 'Native rail alpha changed'
                    allowed |= registration
                assert np.array_equal(old[~allowed], new[~allowed]), 'Paint/glass/terminal changed: '+name
                if base not in B.CASES:
                    assert np.array_equal(old[:, :, :3], new[:, :, :3]), 'Material changed: '+name
            records[name] = {'sha256': item['sha256'], 'changedPixels': int(np.any(old != new, axis=2).sum()), 'lookNotes': notes}
    report = {'assetManifestSha256': B.sha(B.OUT/'manifest.json'), 'texturesChecked': 77,
        'protectedFiles': len(baseline['protected']), 'files': records,
        'unchangedEndcapsCastGlowsAndSources': True, 'terminalFillGlassAndSolidPaintAlphaUnchanged': True,
        'historicalFullPackGate': 'Pre-existing protected-tree drift from unrelated RaidTools work; baseline not rewritten',
        'passed': True, 'liveValidated': False}
    B.write(WORK/'acceptance.json', report)
    print('Rogue repair: 77 textures pass style/hash checks; only missing rail RGB and shadows change; fills, glass, terminals, endcaps and unrelated tree preserved.')
    return manifest


def install():
    from ThemeSourceIntegrity import require_production
    require_production(B.OUT)
    manifest = verify()
    review = json.loads((B.WORK/'visual-review.json').read_text())
    assert review['assetManifestSha256'] == B.sha(B.OUT/'manifest.json') and review['agentOfflineVisualReviewPassed']
    for name, digest in review['images'].items():
        assert B.sha(B.WORK/name) == digest, 'Stale review: '+name
    old = json.loads((BEFORE/'manifest.json').read_text())
    for name in NAMES:
        target = ROOT/'Assets/Rogue'/(name+'.tga')
        assert B.sha(target) in (old['assets'][name]['sha256'], manifest['assets'][name]['sha256']), 'Installed art changed: '+name
        shutil.copyfile(B.OUT/(name+'.tga'), target)
    installed = copy.deepcopy(manifest)
    installed.update(runtimeInstalled=True, sourceManifestSha256=B.sha(B.OUT/'manifest.json'),
        status='Rogue WIP registration/shadow repair installed; live feedback pending')
    for name, item in installed['assets'].items():
        item['path'] = 'Assets/Rogue/'+name+'.tga'
        assert B.sha(ROOT/item['path']) == item['sha256'], name
    B.write(ROOT/'Assets/Rogue/manifest.json', installed)
    print('Installed 11 scoped texture exports; all 77 installed hashes verified. Live /reload still required.')


def preview():
    R = B.module('rogue_shadow_render', 'Render-RogueSuite.py')

    class BeforeRenderer(R.Renderer):
        def asset(self, path):
            if path:
                name = Path(path.replace('\\', '/')).stem
                if '/Rogue/' in path.replace('\\', '/') and name in NAMES:
                    return B.read(BEFORE/(name+'.tga'))
            return super().asset(path)

    old, new = BeforeRenderer(), R.Renderer()
    scenes = [r.health(resource='crystal', cap=False) for r in (old, new)]
    box = Image.fromarray(np.maximum.reduce([np.asarray(im)[:, :, 3] for im in scenes])).getbbox()
    for scale in (1, 2):
        width = max(1100, (box[2]-box[0])*scale+40)
        height = (box[3]-box[1])*scale
        board = Image.new('RGBA', (width, height*2+180), '#766044')
        draw = ImageDraw.Draw(board)
        draw.text((20, 15), 'ROGUE SHADOW REGISTRATION / complete assembly / '+str(scale)+'x / offline', fill='white')
        for row, scene in enumerate(scenes):
            y = 60+row*(height+70)
            draw.text((20, y-20), 'BEFORE' if row == 0 else 'AFTER / repaired rail RGB; fixed fill, glass, geometry and anchors', fill='white')
            art = scene.crop(box).resize(((box[2]-box[0])*scale, height), Image.Resampling.LANCZOS)
            board.alpha_composite(art, (20, y))
        board.convert('RGB').save(WORK/('health-'+str(scale)+'x.png'))
    board = Image.new('RGBA', (1120, 540), '#766044')
    draw = ImageDraw.Draw(board)
    for col, r in enumerate((old, new)):
        x = 10+col*560
        draw.text((x+20, 20), 'BEFORE' if col == 0 else 'AFTER / native button tint (75%)', fill='white')
        board.alpha_composite(r.single('minimap-border', 398), (x, 50))
        for row, shape in enumerate(('', '-square', '-square-rounded')):
            rim = r.own('actionbutton-border'+shape)
            pixels = np.array(rim)
            pixels[:, :, :3] = np.rint(pixels[:, :, :3] * (1 if col == 0 else .75)).astype('uint8')
            board.alpha_composite(Image.fromarray(pixels).resize((96,96), Image.Resampling.LANCZOS), (x+410, 60+row*140))
        # Enlarged minimap detail on the same background reveals extrusion.
        rim = r.own('minimap-border').crop((95,95,415,200)).resize((480,158), Image.Resampling.LANCZOS)
        board.alpha_composite(rim, (x+20, 370))
    board.convert('RGB').save(WORK/'minimap-buttons.png')
    print('Rendered complete before/after health/resource at 1x/2x and minimap/button comparison.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    if args.build:
        build()
    elif args.install:
        install()
    elif args.preview:
        preview()
    else:
        verify()
