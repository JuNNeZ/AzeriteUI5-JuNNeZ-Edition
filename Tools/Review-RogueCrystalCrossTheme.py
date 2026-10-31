"""Cross-theme crystal contact audit and whole-source Rogue draft. No install.

All existing casings are read-only comparisons, never shape stencils. Source
replay, actual normal/ice contact and visual acceptance are separate evidence.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import math

import numpy as np
from PIL import Image, ImageFilter

from ThemeSourceIntegrity import aperture, whole_painting, verify_pixels, verify_pack

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Crystal-CrossTheme-2026-10-30'
OUT = ROOT / 'Assets_Draft/Rogue-Crystal-SingleRail-2026-10-30'
THEMES = ('OG', 'Hunter', 'Mage', 'Paladin', 'Druid', 'Warrior', 'Rogue', 'Shaman', 'MageCrystalTest')


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


A = load('rogue_cross_contact_audit', 'Audit-ThemeCrystalCasings.py')
V = load('rogue_cross_native_renderer', 'Audit-RogueV2Fit.py')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def db_for(tier):
    base = A.P.LAYOUTS['PlayerFrame']
    return dict(base, **base[tier])


def case_rect(theme, db):
    bar, case = A.P.crystal_rects(db)
    return bar, (-1, 121, 198, 98) if theme == 'Hunter' else case


def file_for(theme, name):
    return ROOT / 'Assets' / (theme if theme != 'OG' else '') / (name + '.tga')


def project_contact(image, theme='Rogue', tier='Seasoned'):
    db = db_for(tier)
    bar, case = case_rect(theme, db)
    solid = np.asarray(image)[:, :, 3] > 200
    output = {'contacts': {}, 'sourceCanvas': list(image.size)}
    for ice in (False, True):
        label = 'ice' if ice else 'normal'
        path = db['PowerBarTextureWrath' if ice else 'PowerBarTexture']
        front = A.P.alpha(path)
        field = A.P.project(front, bar, case, image.size)
        inside = np.asarray(field.filter(ImageFilter.MinFilter(3))) > 128
        central = np.zeros_like(inside)
        central[:, round(110 * image.width / 256):round(146 * image.width / 256)] = True
        alpha = np.asarray(front)
        columns = []
        for native_x in range(110, 146):
            x = min(image.width - 1, round(native_x * image.width / 256))
            ys = np.flatnonzero(solid[:, x])
            if not len(ys):
                continue
            world_x = case[0] + (x + .5) * case[2] / image.width
            fill_x = int(world_x / bar[2] * front.width)
            fill_rows = np.flatnonzero(alpha[:, fill_x] > 128)
            if not len(fill_rows):
                continue
            bottom = (int(fill_rows[-1]) + 1) * bar[3] / front.height
            top = case[1] + int(ys[0]) * case[3] / image.height
            columns.append({'x': native_x, 'seatTop': top, 'facetBottom': bottom, 'gap': top - bottom})
        output['contacts'][label] = {
            'columns': columns,
            'minGapLayoutUnits': min(p['gap'] for p in columns) if columns else None,
            'maxGapLayoutUnits': max(p['gap'] for p in columns) if columns else None,
            'centralOpaqueIntrusionBeyondAA': int((solid & inside & central).sum()),
            # Broad lower-body check, across the entire canvas, separate from
            # the two intentional gripping jaws above the seat.
            'lowerBodyIntrusionBeyondAA': int((solid & inside)[round(53 * image.height / 128):].sum()),
            'allOpaqueIntrusionBeyondAA': int((solid & inside).sum())}
    return output


def scene(theme, tier, fraction, ice=False, holder=None):
    db = db_for(tier)
    r = A.M.Renderer.__new__(A.M.Renderer)
    r.asset = lambda path: read(ROOT / 'Assets' / path.replace('\\', '/').split('/Assets/')[-1])
    image = Image.new('RGBA', (300, 290))
    bar = (40, 20, *db['PowerBackdropSize'])
    r.texture(image, db['PowerBackdropTextureWrath' if ice else 'PowerBackdropTexture'], bar)
    if theme == 'Druid':
        r.put(image, read(file_for(theme, 'crystal-roots-back')), bar)
    r.fill(image, db['PowerBarTextureWrath' if ice else 'PowerBarTexture'], bar, fraction,
           (1, 1, 1) if ice else db['PowerBarColors']['MANA'], vertical=True)
    if theme == 'Druid':
        r.put(image, read(file_for(theme, 'crystal-roots-front')), bar)
    else:
        _, case = case_rect(theme, db)
        case = (bar[0] + case[0], bar[1] + case[1], *case[2:])
        name = 'pw_crystal_case_low' if tier == 'Novice' else 'pw_crystal_case'
        r.put(image, holder if holder is not None else read(file_for(theme, name)), case,
              tint=db['PowerBarForegroundColor'] if theme == 'OG' else None)
    return image


def sheet(images, labels, path, title, columns=3, scale=1):
    box = V.union(images)
    width, height = (box[2] - box[0]) * scale, (box[3] - box[1]) * scale
    rows = math.ceil(len(images) / columns)
    # Keep true 1x art, but reserve enough label space; narrow resource crops
    # must not cause adjacent captions or the page title to overwrite each other.
    stride = max(width + 28, 420)
    page = Image.new('RGBA', (columns * stride + 20, rows * (height + 52) + 100), '#252b33')
    V.text(page, title, (16, 12), 22)
    V.text(page, 'OFFLINE / fixed union viewport / unchanged fills, UV contract and frame rectangles / no installation', (16, 44), 16)
    for i, (image, label) in enumerate(zip(images, labels)):
        x, y = 16 + i % columns * stride, 100 + i // columns * (height + 52)
        V.text(page, label, (x, y - 24), 17)
        art = image.crop(box).resize((width, height), Image.Resampling.LANCZOS)
        assert x + width <= page.width and y + height <= page.height, 'Review clips a complete assembly'
        page.alpha_composite(art, (x, y))
    page.convert('RGB').save(path)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    before = json.loads((WORK / 'protected-before.json').read_text())
    source_path = WORK / 'Sources/single-rail-v2.png'
    source = read(source_path)
    crop = list(source.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox())
    # Native casings are ~70px tall. Uniformly fit the intact painting to that
    # density/height family, preserving its aspect ratio; no frame adjustment.
    # The resulting 188x70 paint stays within the existing per-edge geometry
    # tolerance. This also clears the deeper ice contour without cutting paint.
    transform = {'crop': crop, 'scale': 188 / (crop[2] - crop[0]), 'offset': [34, 26]}
    placed = whole_painting(source, transform, (256, 128))
    # Source preflight before any draft export; visual review is still required.
    candidate_contacts = project_contact(placed)
    assert all(v['lowerBodyIntrusionBeyondAA'] == 0 for v in candidate_contacts['contacts'].values()), 'Body covers normal/ice facets'
    # Meaningful negative control: the previous close-to-normal fit failed to
    # check the deeper ice silhouette. It must still fail this body inspection.
    rejected = read(ROOT / 'Assets_Draft/Rogue-Painted-Repair-review-2026-10-30/pw_crystal_case.tga')
    rejected_contacts = project_contact(rejected)
    assert rejected_contacts['contacts']['ice']['lowerBodyIntrusionBeyondAA'] > 0
    textures, metrics = {}, {}
    for theme in THEMES:
        metrics[theme] = {}
        for low in (False, True):
            name = 'pw_crystal_case_low' if low else 'pw_crystal_case'
            path = file_for(theme, name)
            texture = read(path)
            textures[path.relative_to(ROOT).as_posix()] = sha(path)
            metrics[theme][name] = {**A.metric(path, file_for('OG', name)),
                                   **project_contact(texture, theme, 'Novice' if low else 'Seasoned'),
                                   'active': theme != 'Druid'}
    for name in ('crystal-roots-front', 'crystal-roots-back'):
        path = file_for('Druid', name)
        textures[path.relative_to(ROOT).as_posix()] = sha(path)
    # Both variants of all nine sets are displayed. Druid roots are shown as
    # active assembly; its two ordinary (hidden) casings remain in the metrics.
    for tier in ('Novice', 'Seasoned'):
        for scale in (1, 2):
            sheet([scene(t, tier, 1) for t in THEMES], list(THEMES), WORK / f'all-themes-{tier.lower()}-{scale}x.png',
                  f'ALL 9 CASING SETS / {tier} / {scale}x', scale=scale)
        sheet([scene(t, tier, f, ice) for t in THEMES for ice in (False, True) for f in (0, .5, 1)],
              [f'{t} / {"ICE" if ice else "NORMAL"} / {round(f * 100)}%' for t in THEMES for ice in (False, True) for f in (0, .5, 1)],
              WORK / f'all-states-{tier.lower()}-1x.png', f'ALL 9 SETS / {tier} / NORMAL + ICE / 0,50,100%', columns=6)
    # Unassembled raw textures, equal canvases: no independent tight crops.
    raw = [read(file_for(t, name)).resize((512, 256), Image.Resampling.LANCZOS)
           for t in THEMES for name in ('pw_crystal_case', 'pw_crystal_case_low')]
    sheet(raw, [f'{t} / {name}' for t in THEMES for name in ('high', 'low')],
          WORK / 'all-18-casing-textures.png', '18 INSTALLED CASINGS / equal normalized canvases / Druid ordinary cases hidden at runtime', columns=3)

    file = OUT / 'pw_crystal_case.tga'
    placed.save(file, compression=None)
    verify_pixels(placed, read(file))
    assert placed.tobytes() == read(file).tobytes(), 'TGA RGBA round-trip drift'
    assert file.read_bytes()[2] == 2 and file.read_bytes()[16] == 32
    write(OUT / 'manifest.json', {'status': 'single-rail crystal draft / visual and contact review pending / not installed',
                                 'runtimeInstalled': False, 'productionAccepted': False,
                                 'assets': {'pw_crystal_case': {'sha256': sha(file), 'canvas': [256, 128]}}})
    write(OUT / 'source-integrity.json', {'schema': 1, 'assetManifestSha256': sha(OUT / 'manifest.json'), 'paintings': {
        'pw_crystal_case': {'role': 'painting', 'source': {'path': source_path.relative_to(ROOT).as_posix(), 'sha256': sha(source_path)}, 'transform': transform}}})
    try:
        source_gate = {'passed': True, **verify_pack(OUT)}
    except (ValueError, KeyError) as error:
        source_gate = {'passed': False, 'reason': str(error)}

    old = read(file_for('Rogue', 'pw_crystal_case'))
    bad = rejected
    for scale in (1, 2):
        sheet([scene('Rogue', 'Seasoned', f, ice, holder) for holder in (old, bad, placed) for ice in (False, True) for f in (0, .5, 1)],
              [f'{label} / {"ICE" if ice else "NORMAL"} / {round(f * 100)}%' for label in ('INSTALLED', 'REJECTED WALL', 'SINGLE RAIL DRAFT') for ice in (False, True) for f in (0, .5, 1)],
              WORK / f'rogue-crystal-before-after-{scale}x.png', f'ROGUE / INSTALLED, REJECTED, NEW SOURCE / {scale}x', columns=3, scale=scale)
    # Place the new case in the installed V2 HUD, isolating this repair from the
    # separately rejected health painting. No unrelated art is swapped.
    class Draft(V.Installed):
        def asset(self, path):
            if path and path.replace('\\', '/').endswith('/Rogue/pw_crystal_case.tga'):
                return read(file)
            return super().asset(path)
    hud = Draft()
    hud_scenes = [r.health(cap=cap, fraction=f, resource='crystal', choice='venom')
                  for r in (V.Installed(), hud) for cap in (False, True) for f in (0, .5, 1)]
    hud_labels = [f'{label} / {"VENOM" if cap else "NONE"} / health {round(f * 100)}%'
                  for label in ('INSTALLED V2', 'NEW CASE / V2 HEALTH') for cap in (False, True) for f in (0, .5, 1)]
    for scale in (1, 2):
        sheet(hud_scenes, hud_labels, WORK / f'complete-hud-{scale}x.png', f'COMPLETE HUD / CRYSTAL REPAIR ONLY / {scale}x', scale=scale)
    # Additional caps use identical installed health and native origins. The
    # low texture remains unchanged; only the high representative is drafted.
    sheet([r.health(cap=choice is not None, resource='crystal', choice=choice or 'venom', fraction=.5)
           for r in (V.Installed(), hud) for choice in (None, 'twinguard', 'serrated', 'venom')],
          [f'{label} / {choice}' for label in ('INSTALLED', 'NEW CASE') for choice in ('NONE', 'TWIN GUARD', 'SERRATED', 'VENOM')],
          WORK / 'all-endcaps-complete-hud-1x.png', 'ALL RETAINED CAPS / SAME INSTALLED HEALTH / 1x', columns=4)
    sheet([scene('Rogue', tier, f, holder=placed if tier != 'Novice' else None)
           for tier in ('Novice', 'Hardened', 'Seasoned') for f in (0, .5, 1)],
          [f'{tier} / {"LOW UNCHANGED" if tier == "Novice" else "HIGH DRAFT"} / {round(f * 100)}%'
           for tier in ('Novice', 'Hardened', 'Seasoned') for f in (0, .5, 1)],
          WORK / 'rogue-tiers-1x.png', 'ROGUE / ALL MAIN PLAYER TIERS / LOW REMAINS INSTALLED ART', scale=1)

    # Highlight aperture/contact only on a separate inspection overlay. Never
    # apply these diagnostic masks to the source or exported texture.
    mask = A.P.mask('pw_crystal_case', (256, 128))
    actual_intrusion = (np.asarray(placed)[:, :, 3] > 200) & (np.asarray(mask.filter(ImageFilter.MinFilter(3))) > 128)
    proposal = Image.fromarray(actual_intrusion.astype('uint8') * 255)
    proposal.save(WORK / 'new-source-contact-proposal-NOT-APPROVED.png')
    # This checks only geometry with a proposed contact mask. It creates NO
    # approval record and cannot satisfy verify_pack/production by itself.
    aperture(placed, mask, proposal)
    legacy_mask = Image.open(ROOT / 'Docs/Research_Assets/Templates/pw_crystal_case-fill.png').convert('L')
    aperture(placed, legacy_mask, proposal)
    new_metric = A.metric(file, file_for('OG', 'pw_crystal_case'))
    assert new_metric['paintedHeight'] == 70
    box = new_metric['normalizedBounds']
    assert all(abs(box[i] - (39, 21, 216, 91)[i]) <= (10, 5, 10, 5)[i] for i in range(4))
    # Show the exact actual native contact regions, including every jaw pixel.
    marked = placed.copy()
    pixels = np.array(marked)
    pixels[actual_intrusion] = [255, 45, 150, 255]
    marked = Image.fromarray(pixels)
    sheet([placed, marked], ['Whole source export', 'Pink: proposed gripping contacts / NOT approved'],
          WORK / 'contact-overlay-4x.png', 'SOURCE CONTACT INSPECTION / no mask applied to exported art', columns=2, scale=4)
    sheet([scene(t, 'Seasoned', 1) for t in ('OG', 'Paladin', 'Warrior', 'Shaman')] +
          [scene('Rogue', 'Seasoned', 1, holder=old), scene('Rogue', 'Seasoned', 1, holder=placed)],
          ['Native', 'Paladin', 'Warrior', 'Shaman', 'Rogue installed', 'Rogue single-rail draft'],
          WORK / 'closest-comparison-2x.png', 'SAME CRYSTAL / SAME POWER ORIGIN / SOURCE-SPECIFIC HOLDERS / 2x', scale=2)
    scoped = {key: digest for key, digest in before.items() if key.startswith('Assets/Rogue/') or key in (
        'Core/RogueTheme.lua', 'Core/ThemeEngine.lua', 'Core/ThemeEffects.lua',
        'Components/UnitFrames/Units/Player.lua', 'Layouts/Data/PlayerUnitFrame.lua')}
    drift = [key for key, digest in before.items() if not (ROOT / key).is_file() or sha(ROOT / key) != digest]
    assert not set(scoped).intersection(drift), 'Installed Rogue/runtime changed during review'
    assert all(sha(ROOT / path) == digest for path, digest in textures.items()), 'Comparison art changed during audit'
    report = {'status': 'source adjustment drafted; visual review pending; no installation',
              'source': {'path': source_path.relative_to(ROOT).as_posix(), 'sha256': sha(source_path), 'transform': transform},
              'draft': new_metric, 'candidateContact': candidate_contacts, 'sourceIntegrityGate': source_gate,
              'wholeSourceRGBAReplayExact': True, 'TgaRoundTripRGBAExact': True,
              'geometryWithProposedJawContactsPassed': True,
              'proposedJawContactsApproved': False,
              'proposedJawContactMask': {'path': (WORK / 'new-source-contact-proposal-NOT-APPROVED.png').relative_to(ROOT).as_posix(),
                                         'sha256': sha(WORK / 'new-source-contact-proposal-NOT-APPROVED.png')},
              'rejectedPlateIceBodyIntrusionRegression': rejected_contacts['contacts']['ice']['lowerBodyIntrusionBeyondAA'],
              'wholeCrystalCombinedContactFraction': A.P.crystal_overlap('pw_crystal_case', placed.getchannel('A')),
              'comparisonTextures': textures, 'comparisonSets': metrics,
              'druidActiveAssembly': 'crystal-roots-back/front at power rectangle; ordinary case hidden',
              'mageLimit': 'Static holder comparison; school badge/energy not simulated',
              'normalUVContract': [0, 1, 0, 1], 'currentLiveUVReadPerformed': False,
              'protectedFilesChecked': len(before), 'unrelatedConcurrentDrift': drift,
              'scopedFilesVerifiedUnchanged': len(scoped),
              'maintainerVisualApproved': False, 'representativeLiveApproved': False,
              'runtimeInstalled': False, 'liveRetailValidated': False, 'liveForeverValidated': False,
              'images': {p.name: sha(p) for p in WORK.glob('*.png')},
              'retainedSources': {p.name: sha(p) for p in (WORK / 'Sources').glob('*.png')}}
    write(WORK / 'review.json', report)
    rows = ['| Set | Variant | Center top / height (native px) | Normal gap min..max (layout) | Ice gap min..max |',
            '| --- | --- | --- | --- | --- |']
    for theme, variants in metrics.items():
        for name, data in variants.items():
            n, i = data['contacts']['normal'], data['contacts']['ice']
            rows.append(f'| {theme} | {name} | {data["centreRailTop"]} / {data["centreOpaqueSpan"]} | {n["minGapLayoutUnits"]:.2f}..{n["maxGapLayoutUnits"]:.2f} | {i["minGapLayoutUnits"]:.2f}..{i["maxGapLayoutUnits"]:.2f} |')
    (WORK / 'comparison-table.md').write_text('\n'.join(rows) + '\n', encoding='utf-8')
    summary = {key: report[key] for key in ('draft', 'sourceIntegrityGate', 'scopedFilesVerifiedUnchanged', 'unrelatedConcurrentDrift')}
    summary['contact'] = {key: {k: v for k, v in value.items() if k != 'columns'} for key, value in candidate_contacts['contacts'].items()}
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
