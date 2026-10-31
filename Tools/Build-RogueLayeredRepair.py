"""Build and inspect one layered Rogue representative. No installation path."""
from pathlib import Path
import json
import shutil
import difflib

import numpy as np
from PIL import Image, ImageFilter

from RogueLayeredSource import author_health, author_seat, rasterize, validate_source, sha
from ThemeSourceIntegrity import whole_painting, verify_pixels, verify_pack
from ThemeHealthEndcaps import lowest_point, terminal_mask
from RogueLayeredContract import ORDER, health_preflight, validate_layers, verify_layered_pack

import importlib.util

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Layered-Rebuild-2026-10-30'
OUT = ROOT / 'Assets_Draft/Rogue-Layered-Rebuild-2026-10-30'


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


A = load('rogue_layered_native_layout', 'Audit-RogueV2Fit.py')
C = load('rogue_layered_crystal_review', 'Review-RogueCrystalCrossTheme.py')


def read(path):
    return Image.open(path).convert('RGBA')


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def record(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def stage_runtime_patch():
    staged = WORK / 'Runtime/RogueCrystalSeat.lua'
    text = staged.read_text()
    body = text.split('-- BEGIN INTEGRATION\n', 1)[1].split('-- END INTEGRATION', 1)[0]
    originals = {file: (ROOT / file).read_text() for file in ('Core/RogueTheme.lua', 'Core/ThemeEffects.lua')}
    theme_anchor = 'Theme.RefreshEndcaps = function(self)'
    effect_anchor = '\tLiftCap(power, power.Case)\n'
    assert originals['Core/RogueTheme.lua'].count(theme_anchor) == 1
    assert originals['Core/ThemeEffects.lua'].count(effect_anchor) == 1
    changed = {'Core/RogueTheme.lua': originals['Core/RogueTheme.lua'].replace(theme_anchor, body + '\n' + theme_anchor),
               'Core/ThemeEffects.lua': originals['Core/ThemeEffects.lua'].replace(effect_anchor,
                   '\tlocal rogue = ns.RogueTheme\n\tif (rogue and rogue.StyleCrystal) then rogue:StyleCrystal(power, casePath, useMage) end\n' + effect_anchor)}
    patch = ''.join(''.join(difflib.unified_diff(originals[file].splitlines(True), changed[file].splitlines(True),
                                               fromfile='a/' + file, tofile='b/' + file)) for file in originals)
    (WORK / 'Runtime/RogueCrystalSeat-review.patch').write_text(patch, encoding='utf-8', newline='\n')
    return {'status': 'staged only / not applied / not loaded', 'source': record(staged),
            'patch': record(WORK / 'Runtime/RogueCrystalSeat-review.patch'),
            'baseline': {file: sha(ROOT / file) for file in originals},
            'layerContract': 'Owned BORDER 0 between native BACKGROUND backdrop and ARTWORK fill; all custom sublevels retained.'}


class Draft(A.Installed):
    def asset(self, path):
        if path and '/Rogue/' in path.replace('\\', '/'):
            file = OUT / (Path(path.replace('\\', '/')).stem + '.tga')
            if file.is_file():
                return read(file)
        return super().asset(path)

    def resource(self, kind, fraction=1, scene=None, owner=None, part='all', ice=False, seat=True):
        assert kind == 'crystal'
        scene = scene if scene is not None else Image.new('RGBA', (800, 500))
        db = self.config()
        owner = owner or (200, 150, *db['Size'])
        rect = A.R.B.anchor(owner, db['PowerBackdropSize'], db['PowerBarPosition'])
        rect = (rect[0] - 37, rect[1] + 28, *rect[2:])
        _, local_case = A.P.crystal_rects(db)
        case = (rect[0] + local_case[0], rect[1] + local_case[1], *local_case[2:])
        if part in ('all', 'body'):
            self.texture(scene, db['PowerBackdropTextureWrath' if ice else 'PowerBackdropTexture'], rect)
            if seat:
                self.put(scene, read(OUT / 'pw_crystal_case-seat.tga'), case)
            self.fill(scene, db['PowerBarTextureWrath' if ice else 'PowerBarTexture'], rect, fraction,
                      (1, 1, 1) if ice else db['PowerBarColors']['MANA'], vertical=True)
        if part in ('all', 'case'):
            self.texture(scene, db['PowerBarForegroundTexture'], case, db['PowerBarForegroundColor'])
        return scene


def crystal_scene(fraction, ice=False, seat=True, tier='Seasoned'):
    if not seat or tier == 'Novice':
        return C.scene('Rogue', tier, fraction, ice)
    db = C.db_for(tier)
    _, case = A.P.crystal_rects(db)
    result = Image.new('RGBA', (300, 290))
    r = Draft()
    bar = (40, 20, *db['PowerBackdropSize'])
    case = (40 + case[0], 20 + case[1], *case[2:])
    r.texture(result, db['PowerBackdropTextureWrath' if ice else 'PowerBackdropTexture'], bar)
    r.put(result, read(OUT / 'pw_crystal_case-seat.tga'), case)
    r.fill(result, db['PowerBarTextureWrath' if ice else 'PowerBarTexture'], bar, fraction,
           (1, 1, 1) if ice else db['PowerBarColors']['MANA'], vertical=True)
    r.put(result, read(OUT / 'pw_crystal_case.tga'), case)
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    materials = {'steel': record(WORK / 'Sources/steel-smooth-material.png'),
                 'leather': record(WORK / 'Sources/leather-material.png')}
    native_path = ROOT / 'Assets/hp_cap_case.tga'
    fill_path = ROOT / 'Docs/Research_Assets/Templates/hp_cap_case-fill.png'
    native, fill = read(native_path), Image.open(fill_path).convert('L')
    construction = {}
    for name, scene in (
        ('health', author_health(native, fill, materials, {'native': record(native_path), 'functionalOpening': record(fill_path)})),
        ('seat', author_seat(materials))):
        scene_path = WORK / 'Sources' / (name + '.scene.json')
        source_path = WORK / 'Sources' / (name + '.png')
        write(scene_path, scene)
        rasterize(scene, ROOT).save(source_path)
        construction[name] = validate_source(scene_path, source_path, ROOT)
    health = whole_painting(read(WORK / 'Sources/health.png'), {'scale': .25, 'offset': [0, 0]}, (1024, 256))
    seat = whole_painting(read(WORK / 'Sources/seat.png'), {'scale': .25, 'offset': [0, 0]}, (256, 128))
    db = A.Installed().config()
    bar, case = A.P.crystal_rects(db)
    asset_path = lambda path: ROOT / 'Assets' / path.replace('\\', '/').split('/Assets/')[-1]
    layer_contract = {'schema': 'rogue-inner-floor-1', 'layerOrder': ORDER,
                      'barRect': list(bar), 'caseRect': list(case), 'uv': [0, 1, 0, 1], 'inputs': {
        'original-front': record(ROOT / 'Assets/Rogue/pw_crystal_case.tga'),
        'normal-back': record(asset_path(db['PowerBackdropTexture'])),
        'normal-fill': record(asset_path(db['PowerBarTexture'])),
        'ice-back': record(asset_path(db['PowerBackdropTextureWrath'])),
        'ice-fill': record(asset_path(db['PowerBarTextureWrath'])),
        'layout': record(ROOT / 'Layouts/Data/PlayerUnitFrame.lua'),
        'player-runtime': record(ROOT / 'Components/UnitFrames/Units/Player.lua'),
        'effects-runtime': record(ROOT / 'Core/ThemeEffects.lua')}}
    write(WORK / 'layer-contract.json', layer_contract)
    # Entire intact sources must pass before any draft TGA export.
    health_contract = health_preflight(health, ROOT)
    layer_metrics = validate_layers(layer_contract, seat, read(ROOT / 'Assets/Rogue/pw_crystal_case.tga'), ROOT)
    # Reuse both existing layers byte-for-byte. No new fit acceptance is inferred.
    for name in ('hp_cap_case', 'pw_crystal_case'):
        shutil.copyfile(ROOT / 'Assets/Rogue' / (name + '.tga'), OUT / (name + '.tga'))
    for name, paint in (('hp_cap_case-over', health), ('pw_crystal_case-seat', seat)):
        file = OUT / (name + '.tga')
        paint.save(file, compression=None)
        verify_pixels(paint, read(file))
        assert paint.tobytes() == read(file).tobytes()
        assert file.read_bytes()[2] == 2 and file.read_bytes()[16] == 32
    assets = {p.stem: {'sha256': sha(p), 'canvas': list(read(p).size)} for p in OUT.glob('*.tga')}
    write(OUT / 'manifest.json', {'status': 'layered representative / visual review pending / not installed',
                                 'runtimeInstalled': False, 'productionAccepted': False, 'assets': assets})
    old = json.loads((ROOT / 'Assets_Draft/Rogue-Vector-Repair-v2-2026-10-30/source-integrity.json').read_text())['paintings']
    proof = {key: old[key] for key in ('hp_cap_case', 'pw_crystal_case')}
    for name, source in (('hp_cap_case-over', 'health'), ('pw_crystal_case-seat', 'seat')):
        proof[name] = {'role': 'painting', 'source': record(WORK / 'Sources' / (source + '.png')),
                       'transform': {'scale': .25, 'offset': [0, 0]}}
    write(OUT / 'source-integrity.json', {'schema': 1, 'assetManifestSha256': sha(OUT / 'manifest.json'), 'paintings': proof})
    try:
        source_gate = {'passed': True, **verify_pack(OUT)}
    except ValueError as error:
        source_gate = {'passed': False, 'reason': str(error)}
    contract = json.loads((ROOT / 'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    assert sha(ROOT / contract['terminalMask']) == contract['terminalMaskSha256']
    frozen = np.asarray(Image.open(ROOT / contract['terminalMask']).convert('L')) > 128
    terminal = np.asarray(terminal_mask(health)) > 128
    interior = np.asarray(fill.filter(ImageFilter.MinFilter(3))) > 128
    health_metrics = {'toe': lowest_point(health), 'nativeToe': lowest_point(native),
                      'opaqueIntrusionBeyondAA': int(((np.asarray(health)[:, :, 3] > 200) & interior).sum()),
                      'newMetalBeyondFrozenTerminal': int((terminal & ~frozen).sum()),
                      'frozenTerminalSha256': sha(ROOT / contract['terminalMask'])}
    # Reopened TGA previews, with the original foreground and cap assets.
    old_renderer, draft = A.Installed(), Draft()
    scenes = [renderer.health(cap=cap, choice='venom', fraction=f, resource='crystal')
              for renderer in (old_renderer, draft) for cap in (False, True) for f in (0, .5, 1)]
    labels = [f'{name} / {"VENOM" if cap else "NONE"} / health {round(f * 100)}%'
              for name in ('INSTALLED V2', 'LAYERED DRAFT') for cap in (False, True) for f in (0, .5, 1)]
    for scale in (1, 2):
        C.sheet(scenes, labels, WORK / f'complete-hud-{scale}x.png', f'COMPLETE HUD / {scale}x / VISUAL REVIEW PENDING', scale=scale)
        C.sheet([draft.health(cap=cap, choice='venom', fraction=f, resource='crystal') for f in (0, .5, 1) for cap in (False, True)],
                [f'Health {round(f * 100)}% / {"VENOM" if cap else "NONE"}' for f in (0, .5, 1) for cap in (False, True)],
                WORK / f'candidate-{scale}x.png', f'LAYERED ROGUE REPRESENTATIVE / {scale}x / NOT INSTALLED', columns=2, scale=scale)
        C.sheet([renderer.health(cap=False, fraction=f) for renderer in (old_renderer, draft) for f in (0, .5, 1)],
                [f'{name} / BARE / {round(f * 100)}%' for name in ('INSTALLED V2', 'LAYERED DRAFT') for f in (0, .5, 1)],
                WORK / f'bare-health-{scale}x.png', f'BARE HEALTH / NO RESOURCE OR CAP / {scale}x', scale=scale)
        C.sheet([crystal_scene(f, ice, seat) for seat in (False, True) for ice in (False, True) for f in (0, .5, 1)],
                [f'{name} / {"ICE" if ice else "NORMAL"} / {round(f * 100)}%' for name in ('ORIGINAL FRONT', 'FRONT + INNER FLOOR') for ice in (False, True) for f in (0, .5, 1)],
                WORK / f'crystal-{scale}x.png', f'UNCHANGED CRYSTAL + ORIGINAL HOLDER / {scale}x', scale=scale)
    for scale in (1, 2):
        C.sheet([draft.health(cap=choice is not None, choice=choice or 'venom', fraction=.5, resource='crystal')
                 for choice in (None, 'twinguard', 'serrated', 'venom')],
                ['None', 'Twin Guard', 'Serrated', 'Venom'], WORK / f'all-caps-{scale}x.png',
                f'ALL RETAINED ENDCAPS / {scale}x', columns=2, scale=scale)
    C.sheet([draft.health(flip=True, cap=cap, choice='venom', fraction=f, prediction=f == .5)
             for cap in (False, True) for f in (0, .5, 1)],
            [f'TARGET / {"VENOM" if cap else "NONE"} / {round(f * 100)}%' for cap in (False, True) for f in (0, .5, 1)],
            WORK / 'mirrored-health-1x.png', 'MIRRORED / 50% WITH SYNTHETIC PREDICTION / 1x')
    C.sheet([crystal_scene(f, ice, tier=tier) for tier in ('Novice', 'Hardened', 'Seasoned') for ice in (False, True) for f in (0, .5, 1)],
            [f'{tier} / {"ICE" if ice else "NORMAL"} / {round(f * 100)}%' for tier in ('Novice', 'Hardened', 'Seasoned') for ice in (False, True) for f in (0, .5, 1)],
            WORK / 'crystal-tiers-1x.png', 'LOW UNCHANGED / HIGH INNER FLOOR / ALL NATIVE STATES', columns=3)
    C.sheet([C.scene(t, 'Seasoned', 1) for t in C.THEMES] + [crystal_scene(1)],
            list(C.THEMES) + ['ROGUE + INNER FLOOR'], WORK / 'all-casings-plus-draft-2x.png',
            'ALL 9 INSTALLED CASING SETS + INNER-FLOOR DRAFT / 2x', columns=2, scale=2)
    C.sheet([draft.health(tier=tier, flip=tier == 'Boss', cap=cap, choice='venom', fraction=.5) for tier in A.R.CASES for cap in (False, True)],
            [f'{tier} / {"VENOM" if cap else "NONE"} / {"DRAFT" if tier == "Seasoned" else "UNCHANGED"}' for tier in A.R.CASES for cap in (False, True)],
            WORK / 'health-tiers-1x.png', 'ONE REPRESENTATIVE REPAIRED / OTHER HEALTH TIERS UNCHANGED', columns=2)
    protected = json.loads((WORK / 'protected-before.json').read_text())
    drift = [file for file, digest in protected.items() if not (ROOT / file).is_file() or sha(ROOT / file) != digest]
    scoped = [file for file in protected if file.startswith('Assets/Rogue/') or file in (
        'Core/RogueTheme.lua', 'Core/ThemeEngine.lua', 'Components/UnitFrames/Units/Player.lua', 'Layouts/Data/PlayerUnitFrame.lua')]
    assert not set(scoped).intersection(drift), 'Installed Rogue or owning runtime changed; do not claim this baseline'
    report = {'status': 'visual review pending; not installed', 'construction': construction,
              'sourceIntegrity': source_gate, 'health': health_metrics,
              'originalForegroundHolderByteIdentical': sha(OUT / 'pw_crystal_case.tga') == sha(ROOT / 'Assets/Rogue/pw_crystal_case.tga'),
              'nativeFunctionalRecessByteIdentical': sha(OUT / 'hp_cap_case.tga') == sha(ROOT / 'Assets/Rogue/hp_cap_case.tga'),
              'layerOrder': ORDER, 'healthContract': health_contract, 'seatContract': layer_metrics,
              'combinedSourceAndLayerGate': verify_layered_pack(OUT, WORK, ROOT),
              'runtimeProposal': stage_runtime_patch(),
              'constructionMethodMaintainerReviewed': False,
              'tools': {file: sha(ROOT / file) for file in (
                  'Tools/Build-RogueLayeredRepair.py', 'Tools/RogueLayeredSource.py', 'Tools/RogueLayeredContract.py',
                  'Tools/Tests/test_rogue_layered_source.py', 'Tools/Harness/rogue_crystal_seat_harness.lua')},
              'materialPrompts': record(WORK / 'material-prompts.json'),
              'protectedFileCount': len(protected), 'scopedFilesUnchanged': len(scoped), 'concurrentDriftPreserved': drift,
              'currentLiveFrameReadPerformed': False, 'maintainerVisualApproved': False,
              'representativeLiveApproved': False, 'runtimeInstalled': False,
              'images': {p.name: sha(p) for p in WORK.glob('*.png')}}
    write(WORK / 'review.json', report)
    print(json.dumps({k: report[k] for k in ('sourceIntegrity', 'health', 'originalForegroundHolderByteIdentical')}, indent=2))


if __name__ == '__main__':
    main()
