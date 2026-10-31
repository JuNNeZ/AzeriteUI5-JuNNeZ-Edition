"""Source-first Serrated upper-join repair; offline review only, never installs."""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageFilter, ImageOps

from RogueSerratedMorph import compose, validate
from ThemeHealthEndcaps import lowest_point, terminal_mask
from ThemeSourceIntegrity import read, whole_painting, verify_pack

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Serrated-Join-2026-10-31'
OUT = ROOT / 'Assets_Draft/Rogue-Serrated-Join-2026-10-31'
NAME = 'ornament-serrated-hp_cap_case'


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


F = load('serrated_current_family', 'Review-RogueConceptFamily.py')
H = load('serrated_existing_halo', 'Build-RebuiltHealthArt.py')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def record(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def sheet(scenes, labels, path, title, scale=1, bg='#22272d', columns=3):
    box = F.A.union(scenes)
    width, height = (box[2] - box[0]) * scale, (box[3] - box[1]) * scale
    stride = max(width + 28, 470)
    rows = (len(scenes) + columns - 1) // columns
    page = Image.new('RGBA', (columns * stride + 20, rows * (height + 54) + 100), bg)
    F.A.text(page, title, (16, 12), 22)
    F.A.text(page, 'OFFLINE / same rail origin + union viewport / UI130% = texture1:1 / no installation', (16, 43), 16)
    for index, (scene, label) in enumerate(zip(scenes, labels)):
        x, y = 16 + index % columns * stride, 100 + index // columns * (height + 54)
        F.A.text(page, label, (x, y - 24), 17)
        art = scene.crop(box).resize((width, height), Image.Resampling.LANCZOS)
        assert x + width <= page.width and y + height <= page.height, 'Whole assembly clipped'
        page.alpha_composite(art, (x, y))
    page.convert('RGB').save(path)


def geometry(image, case_front):
    contract = json.loads((ROOT / 'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    mask_path = ROOT / contract['terminalMask']
    assert sha(mask_path) == contract['terminalMaskSha256']
    frozen = np.asarray(Image.open(mask_path).convert('L')) > 128
    a = np.asarray(image)[:, :, 3]
    cover = np.asarray(Image.fromarray(((a >= 240) * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0
    field = np.asarray(Image.open(ROOT / 'Docs/Research_Assets/Templates/hp_cap_case-fill.png').convert('L')) > 128
    box = image.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
    limit = contract['approvedEnvelope']
    result = {'toe': lowest_point(image), 'nativeToe': contract['dip'], 'bounds': box, 'approvedEnvelope': limit,
              'frozenTerminalMaskSha256': contract['terminalMaskSha256'],
              'exposedOriginalTerminalBeyondAA': int((frozen & ~cover).sum()),
              'exposedActualV3TerminalBeyondAA': int(((np.asarray(terminal_mask(case_front)) > 128) & ~cover).sum()),
              'capFillFraction': float(((a > 200) & field).sum() / field.sum()),
              'combinedCapAndExistingHealthFillFraction': float((((a > 200) | (np.asarray(case_front)[:, :, 3] > 200)) & field).sum() / field.sum()),
              'serratedExposureExceptionUsed': False}
    assert result['exposedOriginalTerminalBeyondAA'] == result['exposedActualV3TerminalBeyondAA'] == 0
    assert result['capFillFraction'] <= .20
    assert abs(result['toe'][0] - contract['dip'][0]) <= .5 and result['toe'][1] == contract['dip'][1]
    assert box[0] >= limit[0] and box[1] >= limit[1] and box[2] <= limit[2] and box[3] <= limit[3]
    # Same original-mask coverage after mirroring; no second-side waiver.
    mirrored = np.asarray(ImageOps.mirror(Image.fromarray(cover.astype('uint8') * 255))) > 0
    assert not (np.fliplr(frozen) & ~mirrored).any()
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (WORK / 'Sources').mkdir(exist_ok=True)
    choice = json.loads((WORK / 'morph-v4.json').read_text())
    recipe, transform = choice['construction'], choice['transform']
    source = compose(recipe, ROOT)
    source_path = WORK / 'Sources/serrated-mount-morph-source.png'
    source.save(source_path)
    proof = validate(recipe, source_path, ROOT)
    cap = whole_painting(source, transform, (1024, 256))
    front = read(ROOT / 'Assets/Rogue/hp_cap_case-over.tga')
    measures = geometry(cap, front)
    for name, image in ((NAME, cap), (NAME + '-glow', H.halo(cap))):
        file = OUT / (name + '.tga')
        image.save(file, compression=None)
        assert read(file).tobytes() == image.tobytes()
        assert file.read_bytes()[2] == 2 and file.read_bytes()[16] == 32
    assert read(OUT / (NAME + '-glow.tga')).tobytes() == H.halo(read(OUT / (NAME + '.tga'))).tobytes()
    write(OUT / 'manifest.json', {'status': 'Serrated upper-join candidate; offline visual review pending; NOT INSTALLED',
                                 'localSerratedGeometryPassed': True, 'numericalPassed': False,
                                 'globalKnownHealthFailuresRemain': True, 'productionAccepted': False, 'runtimeInstalled': False,
                                 'assets': {p.stem: {'sha256': sha(p), 'canvas': list(read(p).size)} for p in OUT.glob('*.tga')}})
    write(OUT / 'source-integrity.json', {'schema': 1, 'assetManifestSha256': sha(OUT / 'manifest.json'), 'paintings': {
        NAME: {'role': 'painting', 'source': record(source_path), 'transform': transform}}})
    source_proof = verify_pack(OUT)
    write(WORK / 'construction.json', {'schema': 1, 'userRequestedMethod': 'local morph/push; source mount only, complete blade rigid',
          'construction': recipe, 'source': record(source_path), 'transform': transform,
          'sourceValidator': record(ROOT / 'Tools/RogueSerratedMorph.py'),
          'glowOperation': {'method': 'existing Build-RebuiltHealthArt.halo on reopened cap',
                            'builder': record(ROOT / 'Tools/Build-RebuiltHealthArt.py')}, 'proof': proof})

    class Candidate(F.Current):
        def asset(self, path):
            if path and path.replace('\\', '/').endswith('/Rogue/' + NAME + '.tga'):
                return read(OUT / (NAME + '.tga'))
            return super().asset(path)

    old, new = F.Current(), Candidate()
    scenes = [old.health(cap=False, fraction=f, resource='crystal') for f in (0, .5, 1)]
    scenes += [r.health(choice='serrated', fraction=f, resource='crystal') for r in (old, new) for f in (0, .5, 1)]
    labels = [f'{label} / {round(f * 100)}%' for label in ('NONE', 'INSTALLED SERRATED', 'MORPH CANDIDATE') for f in (0, .5, 1)]
    for scale in (1, 2):
        for bg, color in (('dark', '#22272d'), ('light', '#dba974')):
            sheet(scenes, labels, WORK / f'complete-{bg}-{scale}x.png', f'SERRATED UPPER JOIN / full native HUD / {scale}x', scale, color)
        mirror = [old.health(flip=True, cap=False, fraction=f) for f in (0, .5, 1)]
        mirror += [r.health(flip=True, choice='serrated', fraction=f) for r in (old, new) for f in (0, .5, 1)]
        sheet(mirror, labels, WORK / f'mirrored-{scale}x.png', f'MIRRORED TARGET / None, installed, morph / {scale}x', scale)
    detail = Image.new('RGBA', (1240,700), '#dba974')
    for i, (image, label) in enumerate(((read(ROOT / 'Assets/Rogue' / (NAME + '.tga')), 'INSTALLED / extruded backing'), (cap, 'MORPH / painted mount'))):
        F.A.text(detail, label, (16 + i * 610, 12), 22)
        art = Image.alpha_composite(front, image).crop((685, 45, 830, 195)).resize((580, 600), Image.Resampling.NEAREST)
        detail.alpha_composite(art, (16 + i * 610, 55))
    detail.convert('RGB').save(WORK / 'upper-join-before-after-4x.png')
    focus = Image.new('RGBA', (1240, 1050), '#dba974')
    F.A.text(focus, 'SERRATED UPPER JOIN / OFFLINE SOURCE REPAIR / NOT INSTALLED', (16, 12), 22)
    pair = [scenes[5], scenes[8]]
    box = F.A.union(pair)
    for index, (scene, label) in enumerate(zip(pair, ('INSTALLED / complete HUD at1x', 'MORPH CANDIDATE / complete HUD at1x'))):
        F.A.text(focus, label, (16 + index * 610, 48), 18)
        art = scene.crop(box)
        assert art.width <= 600 and art.height <= 210
        focus.alpha_composite(art, (16 + index * 610, 80))
    focus.alpha_composite(detail, (0, 315))
    focus.convert('RGB').save(WORK / 'review-focus.png')
    sheet([read(ROOT / 'Assets/Rogue' / (NAME + '-glow.tga')), read(OUT / (NAME + '-glow.tga'))],
          ['INSTALLED halo', 'NEW own-silhouette halo'], WORK / 'halo-comparison-2x.png', 'Neutral cap halo / same full native canvas', 2, columns=2)
    base = json.loads((WORK / 'input-lock.json').read_text())
    assert all((ROOT / p).is_file() and sha(ROOT / p) == h for p, h in base.items()), 'Installed files changed during review'
    write(WORK / 'review.json', {'status': 'local upper-join candidate; separate visual review pending; no install',
          'localSerratedGeometryPassed': True, 'globalHealthGeometryPassed': False,
          'sourceReplay': proof, 'standardUniformExportProof': source_proof, 'measurements': measures,
          'draftManifest': record(OUT / 'manifest.json'), 'construction': record(WORK / 'construction.json'),
          'protectedExistingInputsUnchanged': len(base), 'runtimeInstalled': False,
          'maintainerVisualApproved': False, 'representativeLiveApproved': False, 'productionAccepted': False,
          'runtimeScale': 'Rogue default1.3 / engine1.3 = actual1:1; no scale mismatch',
          'limits': ['High hp_cap_case representative only; other tiers unchanged.',
                     'Existing health22% fill occlusion/missing casing-terminal painting and other V3 failures remain.',
                     'No current client UV/effective scale/saved offsets read; static default projection only.',
                     'Additional requested-morph source construction validator still needs review before production.'],
          'images': {p.name: sha(p) for p in WORK.glob('*.png')}})
    print(json.dumps({'measurements': measures, 'sourceProof': source_proof, 'protectedUnchanged': len(base), 'runtimeInstalled': False}, indent=2))


if __name__ == '__main__':
    main()
