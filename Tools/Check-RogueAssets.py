"""Independent final export checks. --install requires hash-bound visual review."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil

import numpy as np
from PIL import Image, ImageFilter
from ThemeHealthEndcaps import align, lowest_point

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Rogue'
OUT = ROOT/'Assets_Draft/Rogue'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Tools'/file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def data(path):
    return json.loads(path.read_text(encoding='utf-8'))


def image(path):
    return Image.open(path).convert('RGBA')


def save(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def rejected(fn):
    try:
        fn()
    except (AssertionError, ValueError):
        return
    raise AssertionError('Rejected fixture unexpectedly passed')


def check():
    B = load('rogue_final_build', 'Build-RogueAssets.py')
    C = load('rogue_final_style', 'Check-ThemeAssetStyle.py')
    contract = B.check_contract()
    manifest = data(OUT/'manifest.json')
    assert manifest['terminalAndFootprintContractSha256'] == sha(WORK/'contract.json')
    assert len(manifest['assets']) == 77
    for name, item in manifest['assets'].items():
        path = OUT/(name+'.tga')
        assert sha(path) == item['sha256'], name
        assert list(Image.open(path).size) == item['canvas'], name
        assert not C.check(path)[0], name
    for name, digest in manifest['sources'].items():
        assert sha(WORK/name) == digest, name
    approval = data(WORK/'twin-guard-exposure-approval.json')
    assert approval['maintainerReply'] == 'De 6 pixels er okay'
    expected = np.zeros((256, 1024), dtype=bool)
    for x, y in approval['pixels']:
        expected[y, x] = True
    assert int(expected.sum()) == 6
    fits = {}
    for choice in ('twinguard', 'serrated', 'venom'):
        for case in B.CASES:
            name = 'ornament-'+choice+'-'+case
            cap = image(OUT/(name+'.tga'))
            front = image(OUT/(case+'-over.tga'))
            required = np.asarray(Image.open(ROOT/contract['health'][case]['terminalMask'])) > 128
            opaque = np.asarray(cap)[:, :, 3] >= 240
            expanded = np.asarray(Image.fromarray(opaque.astype('uint8')*255).filter(ImageFilter.MaxFilter(3))) > 0
            exposed = required & ~expanded
            allowed = expected if choice == 'twinguard' and case == 'hp_cap_case' else np.zeros_like(expected)
            assert np.array_equal(exposed, allowed), name
            # Mirror the exact frozen contract and exception with the painting.
            assert np.array_equal(np.fliplr(exposed), np.fliplr(allowed)), name
            x, y = lowest_point(cap)
            dx, dy = contract['health'][case]['dip']
            assert abs(x-dx) <= .5 and y == dy, name
            box = cap.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
            limit = contract['health'][case]['approvedEnvelope']
            assert box[0] >= limit[0] and box[1] >= limit[1] and box[2] <= limit[2] and box[3] <= limit[3], name
            fill = np.asarray(Image.open(B.TEMPLATES/(case+'-fill.png')).convert('L')) > 128
            fraction = float((((np.asarray(cap)[:, :, 3] > 200) | (np.asarray(front)[:, :, 3] > 200)) & fill).sum()/fill.sum())
            assert fraction <= .20, name
            fits[name] = {'observedExposedPixels': int(exposed.sum()), 'approvedPixels': int(allowed.sum()), 'combinedFillOcclusion': fraction, 'bounds': box}
    # Default remains strict, and even this exception cannot grow or shrink.
    cap = image(OUT/'ornament-twinguard-hp_cap_case.tga')
    front = image(OUT/'hp_cap_case-over.tga')
    fill = Image.open(B.TEMPLATES/'hp_cap_case-fill.png')
    height = cap.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
    height = height[3]-height[1]
    rejected(lambda: align(cap, front, height, fill))
    align(cap, front, height, fill, Image.fromarray(expected.astype('uint8')*255))
    for value in (False, True):
        wrong = expected.copy()
        wrong[169, 718] = False
        if value:
            wrong[169, 717] = True
        rejected(lambda: align(cap, front, height, fill, Image.fromarray(wrong.astype('uint8')*255)))
    # Upper-body cutout: a toe-aligned fixture must fail full terminal coverage.
    broken = np.array(image(OUT/'ornament-serrated-hp_cap_case.tga'))
    original_box = Image.fromarray(broken).getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
    broken[90:150, 735:790, 3] = 0
    rejected(lambda: align(Image.fromarray(broken), front, original_box[3]-original_box[1], fill))
    D = load('rogue_final_projection', 'Build-DruidArt.py')
    cast = data(WORK/'cast-contract.json')
    head = image(OUT/'cast-head.tga')
    bounds = head.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
    assert abs((bounds[1]+bounds[3])/2-128) <= .5
    painted = np.asarray(D.project(head.getchannel('A'), cast['slotDrawRect'], (0, 0, 256, 128), (1024, 512))) >= 240
    aa = np.asarray(Image.fromarray(painted.astype('uint8')*255).filter(ImageFilter.MaxFilter(7))) > 0
    sockets = {}
    for case, item in cast['cases'].items():
        assert sha(ROOT/item['socketMask']) == item['socketMaskSha256']
        required = np.asarray(D.project(Image.open(ROOT/item['socketMask']).convert('L'), item['casingDrawRect'], (0, 0, 256, 128), (1024, 512))) > 128
        sockets[case] = int((required & ~aa).sum())
        assert sockets[case] == 0, case
    result = {'assetManifestSha256': sha(OUT/'manifest.json'), 'textures': 77, 'healthFits': fits,
              'unapprovedTerminalPixels': 0, 'explicitlyApprovedTerminalPixels': 6,
              'castExposedPixelsAtDefaultSlot': sockets, 'strictExceptionRegressionCases': 4,
              'passed': True, 'liveValidated': False}
    save(WORK/'acceptance.json', result)
    print('Rogue: 77 textures, 12 bounded health fits, exact 6-pixel exception, both cast sockets and strict exception regressions passed.')
    return manifest


def verify_review():
    review = data(WORK/'visual-review.json')
    assert review['assetManifestSha256'] == sha(OUT/'manifest.json')
    assert review['agentOfflineVisualReviewPassed'] is True
    assert len(review['images']) >= 8
    for name, digest in review['images'].items():
        assert sha(WORK/name) == digest, 'Stale visual review: '+name
    return review


def install(manifest):
    from ThemeSourceIntegrity import require_production
    require_production(OUT)
    verify_review()
    target = ROOT/'Assets/Rogue'
    target.mkdir(exist_ok=True)
    for name, item in manifest['assets'].items():
        source, dest = OUT/(name+'.tga'), target/(name+'.tga')
        if dest.exists():
            assert sha(dest) == item['sha256'], 'Refusing to overwrite different installed art: '+name
        shutil.copyfile(source, dest)
        assert sha(dest) == item['sha256']
    installed = dict(manifest, runtimeInstalled=True, sourceManifestSha256=sha(OUT/'manifest.json'),
                     status='Installed WIP; live Retail and Forever validation pending')
    for name, item in installed['assets'].items():
        item['path'] = 'Assets/Rogue/'+name+'.tga'
    save(target/'manifest.json', installed)
    print('Installed 77 reviewed, byte-verified Rogue textures. Live validation remains pending.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    manifest = check()
    if args.install:
        install(manifest)
