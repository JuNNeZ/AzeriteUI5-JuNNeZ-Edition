"""Retain whole-source Rogue painting trials and rejected diagnostic exports.

No installation path. A failed aperture stays failed. Source alpha is never
stencilled, eroded or erased. All transforms are uniform, declared and replayed.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from ThemeHealthEndcaps import lowest_point, terminal_mask
from ThemeSourceIntegrity import aperture, whole_painting, verify_pixels, verify_pack

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Painted-Repair-2026-10-30'
OUT = ROOT / 'Assets_Draft/Rogue-Painted-Repair-review-2026-10-30'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def source_record(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def margin_crop(image):
    return list(image.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox())


def gate(image, mask):
    try:
        aperture(image, mask)
        return {'passed': True}
    except ValueError as error:
        return {'passed': False, 'reason': str(error)}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    locked = json.loads((WORK / 'input-lock.json').read_text())
    # Only compare our scoped assets/runtime; concurrent unrelated WIP is not
    # reverted or silently certified against this earlier snapshot.
    protected = {key: digest for key, digest in locked['protected'].items()
                 if key.startswith('Assets/Rogue/') or key in (
                     'Core/RogueTheme.lua', 'Core/ThemeEngine.lua',
                     'Components/UnitFrames/Units/Player.lua', 'Layouts/Data/PlayerUnitFrame.lua')}
    assert all(sha(ROOT / key) == digest for key, digest in protected.items())

    health_path = WORK / 'Sources/health-painted-v2.png'
    health_source = read(health_path)
    crop = margin_crop(health_source)
    scale = 122 / (crop[3] - crop[1])
    sample = health_source.crop(crop).resize((round((crop[2] - crop[0]) * scale), 122), Image.Resampling.LANCZOS)
    x, y = lowest_point(sample)
    health_transform = {'crop': crop, 'scale': scale, 'offset': [round(754 - x), 187 - y]}
    health = whole_painting(health_source, health_transform, (1024, 256))
    crystal_path = WORK / 'Sources/crystal-seat-v2.png'
    crystal_source = read(crystal_path)
    crop = margin_crop(crystal_source)
    crystal_transform = {'crop': crop, 'scale': 177 / (crop[2] - crop[0]), 'offset': [39, 26]}
    crystal = whole_painting(crystal_source, crystal_transform, (256, 128))
    back = read(ROOT / 'Assets/Rogue/hp_cap_case.tga')

    # Check the intact placed sources before any diagnostic export. These are
    # not production exports; the failed health remains a rejected fixture.
    field = Image.open(ROOT / 'Docs/Research_Assets/Templates/hp_cap_case-fill.png').convert('L')
    interior = np.asarray(field.filter(ImageFilter.MinFilter(3))) > 128
    health_gate = gate(health, field)
    health_gate['opaquePixelsInsideFillBeyondAA'] = int(((np.asarray(health)[:, :, 3] > 200) & interior).sum())
    A = load('rogue_painted_audit', 'Audit-RogueV2Fit.py')
    actual_crystal_field = A.P.mask('pw_crystal_case', (256, 128))
    crystal_gate = gate(crystal, actual_crystal_field)
    crystal_gate['note'] = 'Grip/jaw contacts require new source-bound visual review; historical bridge approval is not reused.'
    contacts = []
    bar, case = A.P.crystal_rects(A.Installed().config())
    native_front = np.asarray(read(ROOT / 'Assets/power_crystal_front.tga'))
    for col in (112, 120, 128, 136, 144):
        top = int(np.flatnonzero(np.asarray(crystal)[:, col, 3] > 200)[0])
        layout_x = case[0] + (col + .5) * case[2] / 256
        front_col = int(layout_x / bar[2] * native_front.shape[1])
        front_bottom = (int(np.flatnonzero(native_front[:, front_col, 3] > 128)[-1]) + 1) * bar[3] / native_front.shape[0]
        contacts.append({'holderSourceX': col, 'holderTopSourceY': top,
                         'gapToColoredFacetLayoutUnits': case[1] + top * case[3] / 128 - front_bottom})

    contract = json.loads((ROOT / 'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    assert sha(ROOT / contract['terminalMask']) == contract['terminalMaskSha256']
    frozen = np.asarray(Image.open(ROOT / contract['terminalMask']).convert('L')) > 128
    coverage = {}
    for choice in ('twinguard', 'serrated', 'venom'):
        cap = read(ROOT / 'Assets/Rogue' / f'ornament-{choice}-hp_cap_case.tga')
        opaque = np.asarray(cap)[:, :, 3] >= 240
        expanded = np.asarray(Image.fromarray(opaque.astype('uint8') * 255).filter(ImageFilter.MaxFilter(3))) > 0
        yy, xx = np.where(frozen & ~expanded)
        coverage[choice] = {'frozenExposedCoordinates': [[int(x), int(y)] for x, y in zip(xx, yy)]}
    extra_terminal = int(((np.asarray(terminal_mask(health)) > 128) & ~frozen).sum())
    assets = {}
    for name, image in (('hp_cap_case', back), ('hp_cap_case-over', health), ('pw_crystal_case', crystal)):
        file = OUT / (name + '.tga')
        image.save(file, compression=None)
        verify_pixels(image, read(file))
        assets[name] = {'sha256': sha(file), 'canvas': list(image.size)}
    write(OUT / 'manifest.json', {'status': 'REJECTED HEALTH / diagnostic source replay only / DO NOT INSTALL',
                                 'runtimeInstalled': False, 'productionAccepted': False, 'assets': assets})
    old_back = json.loads((ROOT / 'Assets_Draft/Rogue-Vector-Repair-v2-2026-10-30/source-integrity.json').read_text())['paintings']['hp_cap_case']
    write(OUT / 'source-integrity.json', {'schema': 1, 'assetManifestSha256': sha(OUT / 'manifest.json'), 'paintings': {
        'hp_cap_case': old_back,
        'hp_cap_case-over': {'role': 'painting', 'source': source_record(health_path), 'transform': health_transform},
        'pw_crystal_case': {'role': 'painting', 'source': source_record(crystal_path), 'transform': crystal_transform}}})
    try:
        replay_gate = {'passed': True, **verify_pack(OUT)}
    except (ValueError, KeyError) as error:
        replay_gate = {'passed': False, 'reason': str(error)}

    class Candidate(A.Installed):
        def asset(self, path):
            if path and '/Rogue/' in path.replace('\\', '/'):
                file = OUT / (Path(path.replace('\\', '/')).stem + '.tga')
                if file.is_file():
                    return read(file)
            return super().asset(path)

    old, new = A.Installed(), Candidate()

    def page(scenes, labels, path, scale, columns=3):
        box = A.union(scenes)
        w, h = (box[2] - box[0]) * scale, (box[3] - box[1]) * scale
        rows = (len(scenes) + columns - 1) // columns
        board = Image.new('RGBA', (columns * (w + 24) + 20, rows * (h + 46) + 100), '#272e36')
        A.text(board, f'ROGUE / PAINTED SOURCE REVIEW / {scale}x / NOT INSTALLED', (16, 12), 23)
        A.text(board, 'HEALTH REJECTED: source overlaps fill. Whole paint retained; no stencil/erasure. Crystal seat awaits review.', (16, 44), 18)
        for index, (scene, label) in enumerate(zip(scenes, labels)):
            x, y = 16 + index % columns * (w + 24), 100 + index // columns * (h + 46)
            A.text(board, label, (x, y - 23))
            art = scene.crop(box).resize((w, h), Image.Resampling.LANCZOS)
            assert x + w <= board.width and y + h <= board.height
            board.alpha_composite(art, (x, y))
        board.convert('RGB').save(path)

    scenes, labels = [], []
    for renderer, title, cap, resource in ((old, 'INSTALLED V2 / NONE', False, 'crystal'),
                                          (new, 'PAINTED / BARE', False, None),
                                          (new, 'PAINTED / NONE', False, 'crystal'),
                                          (new, 'PAINTED / VENOM', True, 'crystal')):
        for fraction in (0, .5, 1):
            scenes.append(renderer.health(cap=cap, resource=resource, choice='venom', fraction=fraction))
            labels.append(f'{title} / health {round(fraction * 100)}%')
    for scale in (1, 2):
        page(scenes, labels, WORK / f'complete-review-{scale}x.png', scale)
    crystal_scenes = [r.resource('crystal', f) for r in (old, new) for f in (0, .5, 1)]
    page(crystal_scenes, [f'{label} / {round(f * 100)}%' for label in ('INSTALLED', 'NEW SEAT') for f in (0, .5, 1)], WORK / 'crystal-seat-review-2x.png', 2)
    page([new.health(True, cap=cap, choice='venom', fraction=f, prediction=f == .5)
          for cap in (False, True) for f in (0, .5, 1)],
         [f'TARGET / {label} / {round(f * 100)}%' for label in ('NONE', 'VENOM') for f in (0, .5, 1)],
         WORK / 'mirrored-review-1x.png', 1)
    report = {'status': 'health source rejected after one targeted retry; crystal contact candidate pending visual review',
              'runtimeInstalled': False, 'productionAccepted': False, 'maintainerVisualApproved': False,
              'health': {'transform': health_transform, 'dip': lowest_point(health), 'aperture': health_gate,
                         'newTerminalPixelsOutsideFrozenMask': extra_terminal},
              'crystal': {'transform': crystal_transform, 'apertureWithoutNewBridgeApproval': crystal_gate,
                          'centerContacts': contacts},
              'sourceIntegrityGate': replay_gate, 'frozenTerminal': contract, 'capCoverage': coverage,
              'sources': {p.name: sha(p) for p in (WORK / 'Sources').glob('*.png')},
              'images': {p.name: sha(p) for p in WORK.glob('*review-*.png')},
              'protectedFilesCheckedUnchanged': len(protected),
              'liveRetailValidated': False, 'liveForeverValidated': False}
    assert all(sha(ROOT / key) == digest for key, digest in protected.items())
    write(WORK / 'review.json', report)
    print(json.dumps({key: report[key] for key in ('status', 'health', 'crystal', 'sourceIntegrityGate', 'protectedFilesCheckedUnchanged')}, indent=2))


if __name__ == '__main__':
    main()
