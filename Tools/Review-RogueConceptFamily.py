"""Source-first four-part Rogue family review. Diagnostic exports, no installer."""
from pathlib import Path
import argparse
import importlib.util
import json
import math
import shutil

import numpy as np
from PIL import Image, ImageFilter, ImageDraw

from RogueFamilySource import extract, grounded, validate, functional_shade, validate_composites, missing_frozen_terminal
from ThemeSourceIntegrity import aperture, whole_painting, verify_pack
from ThemeHealthEndcaps import lowest_point, terminal_mask

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Concept-Family-2026-10-31'


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


A = module('rogue_family_native', 'Audit-RogueV2Fit.py')
C = module('rogue_family_contacts', 'Review-RogueCrystalCrossTheme.py')
STYLE = module('rogue_family_geometry', 'Check-ThemeAssetStyle.py')
sha, read = A.sha, A.read


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def record(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def bounds(image, threshold=128):
    return image.getchannel('A').point(lambda a: 255 if a > threshold else 0).getbbox()


class Current(A.Installed):
    def resource(self, kind, fraction=1, scene=None, owner=None, part='all'):
        scene = scene if scene is not None else Image.new('RGBA', (800, 500))
        db = self.config()
        owner = owner or (200, 150, *db['Size'])
        rect = A.R.B.anchor(owner, db['PowerBackdropSize'], db['PowerBarPosition'])
        rect = (rect[0] - 37, rect[1] + 28, *rect[2:])
        _, case = A.P.crystal_rects(db)
        case = (rect[0] + case[0], rect[1] + case[1], *case[2:])
        if part in ('all', 'body'):
            self.texture(scene, db['PowerBackdropTexture'], rect)
            self.put(scene, read(ROOT / 'Assets/Rogue/pw_crystal_case-seat.tga'), case)
            self.fill(scene, db['PowerBarTexture'], rect, fraction, db['PowerBarColors']['MANA'], vertical=True)
        if part in ('all', 'case'):
            self.texture(scene, db['PowerBarForegroundTexture'], case, db['PowerBarForegroundColor'])
        return scene


def fit_source(name, raw, source_path, revision):
    base = name.removesuffix('-over')
    native = read(ROOT / 'Assets' / (base + '.tga'))
    target, box = bounds(native), bounds(raw)
    scale = (target[2] - target[0]) / (box[2] - box[0])
    draw_scale = {'hp_cap_case-over': 716 / 1024, 'pw_crystal_case': 198 / 256,
                  'actionbutton-border': 134.295081967 / 256, 'minimap-border': 398 / 512}[name]
    fx = {'schema': 'own-outer-grounding-2' if revision >= 3 else 'own-alpha-grounding-1',
          'radius': 1.1 / (scale * draw_scale), 'strength': .28}
    source = grounded(raw, fx)
    source.save(source_path)
    crop = list(bounds(source, 8))
    sample = source.crop(crop).resize((round((crop[2] - crop[0]) * scale), round((crop[3] - crop[1]) * scale)), Image.Resampling.LANCZOS)
    sb = bounds(sample)
    if name == 'hp_cap_case-over':
        tx, ty = lowest_point(native)
        x, y = lowest_point(sample)
        offset = [round(tx - x), ty - y]
    else:
        offset = [round((target[0] + target[2] - sb[0] - sb[2]) / 2),
                  round((target[1] + target[3] - sb[1] - sb[3]) / 2)]
        if name == 'pw_crystal_case':
            # Fixed original Rogue painted top; no runtime rectangle move.
            offset[1] = 26 - sb[1]
    transform = {'crop': crop, 'scale': scale, 'offset': offset}
    placed = whole_painting(source, transform, native.size)
    return placed, transform, fx


def source_gate(name, image):
    field_path = ROOT / 'Docs/Research_Assets/Templates' / (name.removesuffix('-over') + '-fill.png')
    field = A.P.mask('pw_crystal_case', image.size) if name == 'pw_crystal_case' else Image.open(field_path) if field_path.exists() else None
    result = {'paintedBounds': bounds(image), 'canvas': image.size}
    if field:
        try:
            aperture(image, field)
            result['aperture'] = {'passed': True}
        except ValueError as error:
            inside = np.asarray(field.convert('L').filter(ImageFilter.MinFilter(3))) > 128
            intrusion = (np.asarray(image)[:, :, 3] > 200) & inside
            ys, xs = np.where(intrusion)
            result['aperture'] = {'passed': False, 'reason': str(error), 'pixelsBeyondAA': int(intrusion.sum()),
                                  'intrusionBounds': [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1] if len(xs) else None}
    return result


def health_caps(image):
    case = json.loads((ROOT / 'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    assert sha(ROOT / case['terminalMask']) == case['terminalMaskSha256']
    frozen = np.asarray(Image.open(ROOT / case['terminalMask']).convert('L')) > 128
    missing = missing_frozen_terminal(image, Image.open(ROOT / case['terminalMask']))
    actual = np.asarray(terminal_mask(image)) > 128
    exact_six = json.loads((ROOT / 'Docs/Research_Assets/Rogue/twin-guard-exposure-approval.json').read_text())['pixels']
    result = {'frozenMaskSha256': case['terminalMaskSha256'], 'sourceToe': lowest_point(image),
              'missingOriginalTerminalPixelsBeyondAA': int(missing.sum()),
              'nativeToe': lowest_point(read(ROOT / 'Assets/hp_cap_case.tga')), 'choices': {}}
    for choice in ('twinguard', 'serrated', 'venom'):
        path = ROOT / 'Assets/Rogue' / ('ornament-' + choice + '-hp_cap_case.tga')
        cap = read(path)
        cover = np.asarray(Image.fromarray((np.asarray(cap)[:, :, 3] >= 240).astype('uint8') * 255).filter(ImageFilter.MaxFilter(3))) > 0
        allowed = np.zeros(frozen.shape, dtype=bool)
        if choice == 'twinguard':
            for x, y in exact_six:
                allowed[y, x] = True
        assert np.array_equal(frozen & ~cover, allowed), 'Frozen cap/exception drift'
        box, limit = bounds(cap), case['approvedEnvelope']
        assert box[0] >= limit[0] and box[1] >= limit[1] and box[2] <= limit[2] and box[3] <= limit[3]
        result['choices'][choice] = {'capSha256': sha(path), 'frozenApprovedExposure': int(allowed.sum()),
                                    'newUnapprovedExposedPixels': int((actual & ~cover & ~allowed).sum()),
                                    'approvedEnvelope': limit, 'capBounds': box}
    return result


def family_scene(renderer, health_box):
    page = Image.new('RGBA', (1050, 485))
    hud = renderer.health(cap=True, choice='venom', resource='crystal', fraction=.5).crop(health_box)
    page.alpha_composite(hud, (12, 55))
    for index in range(6):
        button = renderer.native(A.R.B.button, False)
        x, y = 90 + index * 84 - 130, 340 - 130
        box = button.getbbox()
        assert x + box[0] >= 0 and y + box[1] >= 0 and x + box[2] <= page.width and y + box[3] <= page.height
        page.alpha_composite(button, (x, y))
    # Minimap's actual border is398/mapScale; mapScale cancels on screen.
    renderer.put(page, renderer.own('minimap-border'), (610, 18, 398, 398), tint=(192 / 255,) * 3)
    return page


def crystal_scene(renderer, fraction, ice=False, tier='Seasoned'):
    """Same native power origin/UVs, including the currently installed floor."""
    db = C.db_for(tier)
    page = Image.new('RGBA', (300, 290))
    bar = (40, 20, *db['PowerBackdropSize'])
    _, local = A.P.crystal_rects(db)
    case = (bar[0] + local[0], bar[1] + local[1], *local[2:])
    renderer.texture(page, db['PowerBackdropTextureWrath' if ice else 'PowerBackdropTexture'], bar)
    if tier != 'Novice':
        renderer.put(page, read(ROOT / 'Assets/Rogue/pw_crystal_case-seat.tga'), case)
    renderer.fill(page, db['PowerBarTextureWrath' if ice else 'PowerBarTexture'], bar, fraction,
                  (1, 1, 1) if ice else db['PowerBarColors']['MANA'], vertical=True)
    renderer.put(page, renderer.own('pw_crystal_case_low' if tier == 'Novice' else 'pw_crystal_case'), case)
    return page


def contact_overlay(image, path):
    field = np.asarray(A.P.mask('pw_crystal_case', image.size).filter(ImageFilter.MinFilter(3))) > 128
    contacts = (np.asarray(image)[:, :, 3] > 200) & field
    pixels = np.array(image)
    pixels[contacts] = (255, 45, 150, 255)
    C.sheet([image, Image.fromarray(pixels)], ['Whole source export', 'Pink: opaque facet contacts / NOT APPROVED'],
            path, 'PAINT CONTACT INSPECTION / marking only; export unchanged', columns=2, scale=4)
    mask_path = path.with_name('holder-contact-proposal-NOT-APPROVED.png')
    Image.fromarray(contacts.astype('uint8') * 255).save(mask_path)
    return {'mask': record(mask_path), 'approved': False, **C.project_contact(image)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', type=int, default=1)
    args = parser.parse_args()
    revision = args.revision
    out = ROOT / f'Assets_Draft/Rogue-Concept-Family-v{revision}-2026-10-31'
    review_dir = WORK / f'Reviews/v{revision}'
    out.mkdir(parents=True, exist_ok=True)
    review_dir.mkdir(parents=True, exist_ok=True)
    recipe = json.loads((WORK / f'Sources/atlas-v{revision}.json').read_text())
    parts = extract(recipe, ROOT)
    grounding, transforms, part_paths, source_paths, gates, images, composites = {}, {}, {}, {}, {}, {}, {}
    for name, raw in parts.items():
        part_paths[name] = WORK / f'Sources/v{revision}-{name}-raw.png'
        source_paths[name] = WORK / f'Sources/v{revision}-{name}-source.png'
        raw.save(part_paths[name])
        images[name], transforms[name], grounding[name] = fit_source(name, raw, source_paths[name], revision)
        if revision >= 3:
            complete_path = WORK / f'Sources/v{revision}-{name}-complete-native-source.png'
            images[name] = Image.alpha_composite(functional_shade(name, ROOT), images[name])
            images[name].save(complete_path)
            mask = ROOT / 'Docs/Research_Assets/Templates' / (name.removesuffix('-over') + '-fill.png')
            composites[name] = {'paintingSource': record(source_paths[name]), 'transform': transforms[name],
                                'native': record(ROOT / 'Assets' / (name.removesuffix('-over') + '.tga')),
                                'functionalMask': record(mask) if mask.exists() else None, 'completeSource': record(complete_path)}
        # Source first; retain any failures before writing diagnostic exports.
        gates[name] = source_gate(name, images[name])
    construction = validate(recipe, grounding, part_paths, source_paths, ROOT)
    if composites:
        construction.update(validate_composites(composites, ROOT))
    cap_gate = health_caps(images['hp_cap_case-over'])
    for name, image in images.items():
        path = out / (name + '.tga')
        image.save(path, compression=None)
        assert image.tobytes() == read(path).tobytes()
        errors, notes = STYLE.check(path)
        gates[name]['nativeGeometryErrors'] = errors
    numerical = all(g.get('aperture', {}).get('passed', True) and not g['nativeGeometryErrors'] for g in gates.values())
    numerical = numerical and all(c['newUnapprovedExposedPixels'] == 0 for c in cap_gate['choices'].values())
    numerical = numerical and cap_gate['missingOriginalTerminalPixelsBeyondAA'] == 0
    numerical = numerical and abs(cap_gate['sourceToe'][0] - cap_gate['nativeToe'][0]) <= .5 and cap_gate['sourceToe'][1] == cap_gate['nativeToe'][1]
    shutil.copyfile(ROOT / 'Assets/Rogue/hp_cap_case.tga', out / 'hp_cap_case.tga')
    assets = {p.stem: {'sha256': sha(p), 'canvas': list(read(p).size)} for p in out.glob('*.tga')}
    write(out / 'manifest.json', {'status': 'DIAGNOSTIC material study; FIT REJECTED; DO NOT INSTALL' if not numerical else 'DIAGNOSTIC representative; visual approval pending; DO NOT INSTALL',
                                 'numericalPassed': bool(numerical),
                                 'runtimeInstalled': False, 'productionAccepted': False, 'assets': assets})
    paintings = {name: {'role': 'painting', 'source': composites[name]['completeSource'] if composites else record(source_paths[name]),
                        'transform': {'scale': 1, 'offset': [0, 0]} if composites else transforms[name]} for name in parts}
    paintings['hp_cap_case'] = {'role': 'functional-recess', 'source': record(ROOT / 'Assets/hp_cap_case.tga')}
    write(out / 'source-integrity.json', {'schema': 1, 'assetManifestSha256': sha(out / 'manifest.json'), 'paintings': paintings})
    try:
        export_gate = {'passed': True, **verify_pack(out)}
    except ValueError as error:
        export_gate = {'passed': False, 'reason': str(error)}
    write(WORK / f'Sources/construction-v{revision}.json', {'recipe': recipe, 'grounding': grounding,
          'rawParts': {n: record(p) for n, p in part_paths.items()}, 'sources': {n: record(p) for n, p in source_paths.items()},
          'transforms': transforms, 'functionalComposites': composites,
          'validatorSha256': sha(ROOT / 'Tools/RogueFamilySource.py')})

    class Candidate(Current):
        def asset(self, path):
            if path and '/Rogue/' in path.replace('\\', '/'):
                file = out / (Path(path.replace('\\', '/')).stem + '.tga')
                if file.is_file():
                    return read(file)
            return super().asset(path)
    old, new = Current(), Candidate()
    crystal_contacts = contact_overlay(images['pw_crystal_case'], review_dir / 'holder-contact-overlay-4x.png')
    all_hud = [r.health(cap=cap, choice='venom', fraction=f, resource='crystal') for r in (old, new) for cap in (False, True) for f in (0, .5, 1)]
    hp_box = A.union(all_hud)
    for scale in (1, 2):
        for r, label in ((old, 'INSTALLED REJECTED'), (new, 'PAINTED FAMILY DRAFT')):
            scene = family_scene(r, hp_box)
            for bg, color in (('dark', '#22272d'), ('light', '#e0ad72')):
                board = Image.new('RGBA', (1050 * scale, 535 * scale), color)
                art = scene.resize((1050 * scale, 485 * scale), Image.Resampling.LANCZOS)
                board.alpha_composite(art, (0, 50 * scale))
                A.text(board, f'{label} / {scale}x / OFFLINE EXPORTED TGAs / FIT NOT APPROVED', (12 * scale, 10 * scale), 17 * scale)
                name = 'installed' if r is old else 'candidate'
                board.convert('RGB').save(review_dir / f'{name}-{bg}-{scale}x.png')
        C.sheet(all_hud[6:], [f'{"VENOM" if cap else "NONE"} / health {round(f * 100)}%' for cap in (False, True) for f in (0, .5, 1)],
                review_dir / f'health-fill-states-{scale}x.png', f'PAINTED FAMILY / {scale}x / NUMERIC FIT PENDING', scale=scale)
        C.sheet([r.health(cap=False, fraction=f) for r in (old, new) for f in (0, .5, 1)],
                [f'{label} / {round(f * 100)}%' for label in ('INSTALLED', 'PAINTED FAMILY') for f in (0, .5, 1)],
                review_dir / f'bare-health-{scale}x.png', f'BARE EXPORTED HEALTH / {scale}x / NO CAP OR CRYSTAL', scale=scale)
        C.sheet([new.health(cap=choice is not None, choice=choice or 'venom', fraction=f, resource='crystal')
                 for choice in (None, 'twinguard', 'serrated', 'venom') for f in (0, .5, 1)],
                [f'{choice or "NONE"} / {round(f * 100)}%' for choice in (None, 'twinguard', 'serrated', 'venom') for f in (0, .5, 1)],
                review_dir / f'all-caps-fill-states-{scale}x.png', f'COMPLETE ASSEMBLY / ALL RETAINED CAPS / {scale}x', scale=scale)
        C.sheet([crystal_scene(r, f, ice) for r in (old, new) for ice in (False, True) for f in (0, .5, 1)],
                [f'{label} / {"ICE" if ice else "NORMAL"} / {round(f * 100)}%'
                 for label in ('INSTALLED', 'PAINTED FAMILY') for ice in (False, True) for f in (0, .5, 1)],
                review_dir / f'crystal-fill-states-{scale}x.png', f'CRYSTAL WITH CURRENT FLOOR / NORMAL + ICE / {scale}x', scale=scale)
        C.sheet([C.scene(t, 'Seasoned', 1) for t in C.THEMES if t != 'Rogue'] +
                [crystal_scene(old, 1), crystal_scene(new, 1)],
                [t for t in C.THEMES if t != 'Rogue'] + ['ROGUE INSTALLED + FLOOR', 'ROGUE PAINTED + FLOOR'],
                review_dir / f'cross-theme-crystals-{scale}x.png', f'ALL NINE CASING SETS + FAMILY DRAFT / {scale}x', scale=scale)
    C.sheet([crystal_scene(new, f, ice, tier) for tier in ('Novice', 'Hardened', 'Seasoned') for ice in (False, True) for f in (0, .5, 1)],
            [f'{tier} / {"ICE" if ice else "NORMAL"} / {round(f * 100)}%'
             for tier in ('Novice', 'Hardened', 'Seasoned') for ice in (False, True) for f in (0, .5, 1)],
            review_dir / 'crystal-tiers-1x.png', 'ALL MAIN TIERS / NOVICE REMAINS EXISTING ART / NO EXPANSION', columns=3)
    concept = read(ROOT / 'Docs/Research_Assets/Rogue/approved-concept.png')
    concept = concept.resize((1050, round(concept.height * 1050 / concept.width)), Image.Resampling.LANCZOS)
    comparison = Image.new('RGB', (1074, concept.height + 610), '#20252b')
    A.text(comparison, 'APPROVED CONCEPT / source reference', (12, 12), 22)
    comparison.paste(concept, (12, 48))
    A.text(comparison, 'NEW FOUR-PART FAMILY / actual1x exports / geometry NOT accepted', (12, concept.height + 76), 20)
    comparison.paste(read(review_dir / 'candidate-dark-1x.png').convert('RGB'), (12, concept.height + 110))
    comparison.save(review_dir / 'concept-comparison.png')
    locked = json.loads((WORK / 'input-lock.json').read_text())
    drift = [p for p, h in locked.items() if not (ROOT / p).is_file() or sha(ROOT / p) != h]
    assert not drift, 'Current runtime changed; inspect separately: ' + str(drift)
    report = {'status': 'material study retained; fit rejected; no installation' if not numerical else 'diagnostic visual review pending; no installation',
              'numericalPassed': bool(numerical),
              'construction': construction, 'sourceGates': gates, 'capGate': cap_gate, 'exportSourceGate': export_gate,
              'crystalContact': crystal_contacts,
              'transforms': transforms, 'nativeButtonTint': old.data['ActionButton']['ButtonBorderColor'],
              'nativeButtonBorderSize': old.data['ActionButton']['ButtonBorderSize'],
              'nativeMinimapSize': [398, 398], 'nativeMinimapTint': [192 / 255] * 3,
              'protectedExistingInputsUnchanged': len(locked), 'runtimeInstalled': False,
              'maintainerVisualApproved': False, 'representativeLiveApproved': False,
              'limits': ['Static native layout projection; current client UV/effective-scale sampling not read.',
                         'Button icons, minimap world tile, prediction/absorb and Lite+ effects not simulated.',
                         'New source construction and proposed holder contacts need separate review; no approvals fabricated.'],
              'images': {p.name: sha(p) for p in review_dir.glob('*.png')}}
    write(review_dir / 'review.json', report)
    print(json.dumps({key: report[key] for key in ('sourceGates', 'capGate', 'exportSourceGate')}, indent=2))


if __name__ == '__main__':
    main()
