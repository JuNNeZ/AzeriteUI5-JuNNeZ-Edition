"""Diagnose installed V2 without changing artwork, layout or historical reviews.

Projections are offline evidence, not live frame reads. Crystal uses the native
full-canvas silhouette documented in PaladinFillContracts, plus Player.lua's
size-delta anchor correction. Keep the old preview as a separate comparison.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Live-Fit-Diagnosis-2026-10-30'
V2 = ROOT / 'Docs/Research_Assets/Rogue/Vector-Repair-v2-2026-10-30'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def read(path):
    return Image.open(path).convert('RGBA')


R = load('rogue_v2_diagnostic_renderer', 'Render-RogueSuite.py')
P = load('rogue_v2_native_crystal', 'PaladinFillContracts.py')


class Installed(R.Renderer):
    def asset(self, path):
        if path is None:
            return None
        return read(ROOT / 'Assets' / path.replace('\\', '/').split('/Assets/')[-1])

    def resource(self, kind, fraction=1, scene=None, owner=None, part='all'):
        assert kind == 'crystal'
        scene = scene if scene is not None else Image.new('RGBA', (800, 500))
        db = self.config()
        owner = owner or (200, 150, *db['Size'])
        rect = R.B.anchor(owner, db['PowerBackdropSize'], db['PowerBarPosition'])
        # Player.lua's profile defaults move the whole resource, independently
        # of the holder's size-delta correction. Never write those settings.
        rect = (rect[0] - 37, rect[1] + 28, *rect[2:])
        if part in ('all', 'body'):
            self.texture(scene, db['PowerBackdropTexture'], rect)
            self.fill(scene, db['PowerBarTexture'], rect, fraction,
                      db['PowerBarColors']['MANA'], vertical=True)
        _, local_case = P.crystal_rects(db)
        case = (rect[0] + local_case[0], rect[1] + local_case[1], *local_case[2:])
        if part in ('all', 'case'):
            self.texture(scene, db['PowerBarForegroundTexture'], case, db['PowerBarForegroundColor'])
        return scene

    def health(self, *args, resource=None, **kwargs):
        health = super().health(*args, resource=None, **kwargs)
        if not resource:
            return health
        owner = (280, 200, *self.config()['Size'])
        scene = Image.new('RGBA', health.size)
        self.resource(resource, 1, scene, owner, part='body')
        scene.alpha_composite(health)
        self.resource(resource, 1, scene, owner, part='case')
        return scene


def text(page, label, xy, size=17):
    ImageDraw.Draw(page).text(xy, label, fill='#e6e3dc',
                             font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf', size))


def union(scenes):
    return Image.fromarray(np.maximum.reduce([np.asarray(s)[:, :, 3] for s in scenes])).getbbox()


def panel(scenes, labels, path, scale, columns=3):
    box = union(scenes)
    w, h = (box[2] - box[0]) * scale, (box[3] - box[1]) * scale
    rows = (len(scenes) + columns - 1) // columns
    page = Image.new('RGBA', (columns * (w + 24) + 16, rows * (h + 55) + 68), '#272e36')
    text(page, f'INSTALLED ROGUE V2 / {scale}x layout units / OFFLINE DIAGNOSIS / ART UNCHANGED', (16, 12), 21)
    text(page, 'Fixed union viewport and rail origin. Native crystal silhouette; effects/text/threat off.', (16, 40), 16)
    for index, (scene, label) in enumerate(zip(scenes, labels)):
        x, y = 16 + (index % columns) * (w + 24), 78 + (index // columns) * (h + 55)
        text(page, label, (x, y - 21))
        art = scene.crop(box).resize((w, h), Image.Resampling.LANCZOS)
        assert x + w <= page.width and y + h <= page.height
        page.alpha_composite(art, (x, y))
    page.convert('RGB').save(path)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    paths = [p for folder in ('Assets', 'Core', 'Layouts', 'Options')
             for p in (ROOT / folder).rglob('*') if p.is_file()]
    protected = {p: sha(p) for p in paths}
    installed = json.loads((ROOT / 'Assets/Rogue/manifest.json').read_text())['assets']
    assert len(installed) == 77
    for name, item in installed.items():
        assert sha(ROOT / 'Assets/Rogue' / (name + '.tga')) == item['sha256'], name
    record = json.loads((V2 / 'live-preview-installed.json').read_text())
    for name, item in record['files'].items():
        assert sha(ROOT / 'Assets/Rogue' / (name + '.tga')) == item['installedSha256']

    r = Installed()
    db = r.config()
    scenes, labels = [], []
    for cap, resource, label in ((False, None, 'NONE / bare casing'),
                                 (False, 'crystal', 'NONE / complete HUD'),
                                 (True, 'crystal', 'VENOM / complete HUD')):
        for fraction in (0, .5, 1):
            scenes.append(r.health(cap=cap, resource=resource, choice='venom', fraction=fraction))
            labels.append(f'{label} / health {round(fraction * 100)}%')
    for scale in (1, 2):
        panel(scenes, labels, WORK / f'installed-health-{scale}x.png', scale)

    # Historical recipe versus source-derived native silhouette and case anchor.
    old = R.Renderer()
    old.asset = r.asset
    crystal_scenes = [renderer.resource('crystal', fraction)
                      for renderer in (old, r) for fraction in (0, .5, 1)]
    crystal_labels = [f'{label} / {round(fraction * 100)}%'
                      for label in ('OLD PREVIEW recipe', 'NATIVE contract projection') for fraction in (0, .5, 1)]
    panel(crystal_scenes, crystal_labels, WORK / 'crystal-renderer-comparison-2x.png', 2)

    # Continuous layout coordinates; no round-trip through an enlarged screenshot.
    bar, case = P.crystal_rects(db)
    front = read(ROOT / 'Assets/power_crystal_front.tga')
    back = read(ROOT / 'Assets/power_crystal_back.tga')
    holder = read(ROOT / 'Assets/Rogue/pw_crystal_case.tga')
    contacts = []
    for x in (112, 120, 128, 136, 144):
        col = np.flatnonzero(np.asarray(holder)[:, x, 3] > 200)
        hx = case[0] + (x + .5) * case[2] / holder.width
        entry = {'holderSourceX': x, 'layoutX': hx,
                 'holderTopLayoutY': case[1] + int(col[0]) * case[3] / holder.height}
        for label, image in (('front', front), ('back', back)):
            cx = int((hx - bar[0]) / bar[2] * image.width)
            ys = np.flatnonzero(np.asarray(image)[:, cx, 3] > 128)
            bottom = (int(ys[-1]) + 1) * bar[3] / image.height
            entry[label + 'BottomLayoutY'] = bottom
            entry[label + 'GapLayoutUnits'] = entry['holderTopLayoutY'] - bottom
        contacts.append(entry)

    field = np.asarray(Image.open(ROOT / 'Docs/Research_Assets/Templates/hp_cap_case-fill.png').convert('L')) > 128
    hp_front = np.asarray(read(ROOT / 'Assets/Rogue/hp_cap_case-over.tga'))
    # Choose a straight rail away from studs and leather.
    center = np.flatnonzero(field[:, 400])
    solid = hp_front[:, :, 3] > 200
    rail_top = np.flatnonzero(solid[:center[0], 400])[0]
    rail_bottom = np.flatnonzero(solid[center[-1] + 1:, 400])[-1] + center[-1] + 1
    materials = {}
    for label, name in (('casing', 'hp_cap_case-over'), ('venomEndcap', 'ornament-venom-hp_cap_case')):
        pixels = np.asarray(read(ROOT / 'Assets/Rogue' / (name + '.tga')))
        luminance = pixels[:, :, :3] @ np.array([.2126, .7152, .0722]) / 255
        materials[label] = {'medianEncodedLuma': float(np.median(luminance[pixels[:, :, 3] > 240]))}
    terminal = json.loads((ROOT / 'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    assert sha(ROOT / terminal['terminalMask']) == terminal['terminalMaskSha256']
    frozen = np.asarray(Image.open(ROOT / terminal['terminalMask']).convert('L')) > 128
    approval = json.loads((ROOT / 'Docs/Research_Assets/Rogue/twin-guard-exposure-approval.json').read_text())
    exposure = {}
    for choice in R.CAPS:
        cap = read(ROOT / 'Assets/Rogue' / f'ornament-{choice}-hp_cap_case.tga')
        opaque = np.asarray(cap)[:, :, 3] >= 240
        aa = np.asarray(Image.fromarray(opaque.astype('uint8') * 255).filter(ImageFilter.MaxFilter(3))) > 0
        ys, xs = np.where(frozen & ~aa)
        coordinates = [[int(x), int(y)] for x, y in zip(xs, ys)]
        assert sorted(coordinates) == sorted(approval['pixels'] if choice == 'twinguard' else [])
        exposure[choice] = coordinates

    assert all(sha(p) == digest for p, digest in protected.items()), 'Concurrent protected-file change; rerun snapshot'
    report = {
        'status': 'diagnosis only; V2 visual fit rejected by current live feedback',
        'liveFrameReadPerformed': False, 'newArtGenerated': False, 'runtimeInstalled': False,
        'installedTextureHashesVerified': 77, 'protectedFilesUnchanged': len(protected),
        'health': {'barSize': db['HealthBarSize'], 'casingSize': db['HealthBackdropSize'],
                   'texcoords': [0, 1, 0, 1], 'centerOpeningSourceYExclusive': [int(center[0]), int(center[-1]) + 1],
                   'centerOpeningLayoutHeight': len(center) * 188 / 256,
                   'straightRailSourceX': 400,
                   'upperRailLayoutHeight': (int(center[0]) - int(rail_top)) * 188 / 256,
                   'lowerRailLayoutHeight': (int(rail_bottom) + 1 - int(center[-1]) - 1) * 188 / 256,
                   'centerUpperRailSourceSpan': [int(rail_top), int(center[0])],
                   'centerLowerRailSourceSpan': [int(center[-1]) + 1, int(rail_bottom) + 1],
                   'opaqueOverlapWithTemplate': int((field & solid).sum()),
                   'interpretation': 'Alpha fit is close at center; this does not approve visual fit. Lower rail and dark fill facets cause apparent oversize.'},
        'materials': materials,
        'crystal': {'nativeBarRectRelativeToPower': bar, 'nativeCaseRectRelativeToPower': case,
                    'defaultWholeResourceOffsetXYWoW': [-37, -28],
                    'nativeHolderCenterTopSourceY': int(np.flatnonzero(np.asarray(read(ROOT / 'Assets/pw_crystal_case.tga'))[:, 128, 3] > 200)[0]),
                    'rogueHolderCenterTopSourceY': int(np.flatnonzero(np.asarray(holder)[:, 128, 3] > 200)[0]),
                    'oldPreviewCaseRect': R.B.anchor(bar, db['PowerBarForegroundSize'], db['PowerBarForegroundPosition']),
                    'legacyRequestedTexcoords': db['PowerBarTexCoord'], 'projectionTexcoords': [0, 1, 0, 1],
                    'basis': 'PaladinFillContracts.py documents prior live full-canvas silhouette; current client UV remains a live verification item',
                    'positiveGapMeansAirNegativeMeansOverlap': True, 'contacts': contacts},
        'terminalContract': terminal, 'terminalExposureCoordinates': exposure,
        'inputHashes': {p.relative_to(ROOT).as_posix(): digest for p, digest in protected.items()
                        if '/Rogue/' in p.as_posix() or p.name in ('Player.lua', 'UnitFrame.lua', 'ThemeEffects.lua', 'ThemeEngine.lua', 'PlayerUnitFrame.lua')},
        'reviewImages': {p.name: sha(p) for p in WORK.glob('*.png')},
        'diagnosticInputs': {name: sha(ROOT / name) for name in (
            'Tools/Audit-RogueV2Fit.py', 'Tools/Render-RogueSuite.py',
            'Tools/Build-ImplementedThemeSheets.py', 'Tools/Build-ThemeConceptBase.py',
            'Tools/PaladinFillContracts.py', 'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json')},
        'limitations': ['Static default geometry; saved live frame positions, effective scale and GPU sampling not read.',
                        'Native StatusBar partial-fill UV, Lite+ effects, prediction and live layering need client verification.',
                        'Historical approval records retained; no new approval or production acceptance.']}
    (WORK / 'measurements.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('health', 'materials', 'crystal', 'protectedFilesUnchanged')}, indent=2))


if __name__ == '__main__':
    main()
