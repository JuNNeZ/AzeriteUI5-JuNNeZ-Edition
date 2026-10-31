"""Additional source/layer contract for the Rogue inner-floor construction.

This does not approve art or authorize installation. Generic PNG replay alone
cannot prove the floor clears painted faces or sits between shadow and fill.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

import PaladinFillContracts as P
from RogueLayeredSource import sha, validate_source
from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import aperture, checked_file, verify_pack

ORDER = ['native-backdrop', 'seat', 'native-fill', 'original-front']


def read(path):
    return Image.open(path).convert('RGBA')


def health_preflight(painting, root):
    root = Path(root)
    contract = json.loads((root / 'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    native = read(root / 'Assets/hp_cap_case.tga')
    assert sha(root / 'Assets/hp_cap_case.tga') == contract['nativeSha256']
    frozen_path = root / contract['terminalMask']
    assert sha(frozen_path) == contract['terminalMaskSha256']
    frozen = np.asarray(Image.open(frozen_path).convert('L')) > 128
    fill = Image.open(root / 'Docs/Research_Assets/Templates/hp_cap_case-fill.png').convert('L')
    aperture(painting, fill)
    if lowest_point(painting) != lowest_point(native):
        raise ValueError('authored health toe differs')
    # The immutable full terminal includes the shared functional recess. Check
    # that complete assembly, never redefine the frozen mask from a new front.
    whole = Image.alpha_composite(read(root / 'Assets/Rogue/hp_cap_case.tga'), painting)
    solid = np.asarray(whole)[:, :, 3] > 128
    yy, xx = np.indices(frozen.shape)
    terminal_domain = xx >= int(np.where(frozen)[1].min())
    if (frozen & ~solid).any() or (solid & terminal_domain & ~frozen).any():
        raise ValueError('complete frozen terminal was removed or enlarged')
    approval = json.loads((root / 'Docs/Research_Assets/Rogue/twin-guard-exposure-approval.json').read_text())
    field = np.asarray(fill) > 128
    caps = {}
    for choice in ('twinguard', 'serrated', 'venom'):
        path = root / 'Assets/Rogue' / ('ornament-' + choice + '-hp_cap_case.tga')
        cap = read(path)
        pixels = np.asarray(cap)[:, :, 3]
        expanded = np.asarray(Image.fromarray((pixels >= 240).astype('uint8') * 255).filter(ImageFilter.MaxFilter(3))) > 0
        ys, xs = np.where(frozen & ~expanded)
        exposed = sorted([[int(x), int(y)] for x, y in zip(xs, ys)])
        expected = sorted(approval['pixels']) if choice == 'twinguard' else []
        if exposed != expected or (choice == 'twinguard' and len(expected) != 6):
            raise ValueError('full terminal differs from exact historical exposure')
        box = cap.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
        limit = contract['approvedEnvelope']
        if not (box[0] >= limit[0] and box[1] >= limit[1] and box[2] <= limit[2] and box[3] <= limit[3]):
            raise ValueError('cap exceeds approved Druid envelope')
        coverage = float((((np.asarray(painting)[:, :, 3] > 200) | (pixels > 200)) & field).sum() / field.sum())
        if coverage > .20:
            raise ValueError('combined rail/cap occlusion exceeds ceiling')
        caps[choice] = {'sha256': sha(path), 'exposedPixels': exposed, 'bounds': box,
                        'approvedEnvelope': limit, 'combinedFillOcclusion': coverage}
    return {'fullFrozenTerminalSha256': sha(frozen_path), 'completeTerminalUnchanged': True,
            'toe': lowest_point(painting), 'caps': caps}


def validate_layers(contract, seat, holder, root):
    if set(contract) != {'schema', 'layerOrder', 'barRect', 'caseRect', 'uv', 'inputs'} or contract['schema'] != 'rogue-inner-floor-1':
        raise ValueError('unsupported layer construction')
    if contract['layerOrder'] != ORDER:
        raise ValueError('inner floor must be above backdrop shadow and below native fill')
    base = P.LAYOUTS['PlayerFrame']
    db = dict(base, **base['Seasoned'])
    bar, case = P.crystal_rects(db)
    if contract['barRect'] != list(bar) or contract['caseRect'] != list(case) or contract['uv'] != [0, 1, 0, 1]:
        raise ValueError('native geometry/UV override')
    if seat.size != (256, 128) or holder.size != seat.size:
        raise ValueError('unexpected seat/holder canvas')
    required = {'original-front', 'normal-back', 'normal-fill', 'ice-back', 'ice-fill', 'layout', 'player-runtime', 'effects-runtime'}
    if set(contract['inputs']) != required:
        raise ValueError('missing native or runtime source lock')
    for item in contract['inputs'].values():
        checked_file(item, Path(root))
    if holder.tobytes() != read(Path(root) / 'Assets/Rogue/pw_crystal_case.tga').tobytes():
        raise ValueError('original bottle/jaws/rail painting changed')
    aperture(seat, P.mask('pw_crystal_case', seat.size))
    # Central unsupported air is measured on actual projected native back and
    # normal/ice fill, not legacy cropped templates. No mask edits the export.
    sa, ha = np.asarray(seat)[:, :, 3], np.asarray(holder)[:, :, 3]
    native_holder = np.asarray(read(Path(root) / 'Assets/pw_crystal_case.tga'))[:, :, 3]
    contacts = {}
    for ice in (False, True):
        fill = P.alpha(db['PowerBarTextureWrath' if ice else 'PowerBarTexture'])
        back = P.alpha(db['PowerBackdropTextureWrath' if ice else 'PowerBackdropTexture'])
        front_field = np.asarray(P.project(fill, bar, case, seat.size))
        back_field = np.asarray(P.project(back, bar, case, seat.size))
        gaps, unsupported, heights, support_heights = 0, 0, [], []
        for x in range(110, 146):
            top = int(np.flatnonzero(ha[:, x] > 200)[0])
            bottom = int(np.flatnonzero(front_field[:, x] > 128)[-1]) + 1
            heights.append(max(0, top - bottom) * case[3] / seat.height)
            support_top = min(top, int(np.flatnonzero(sa[:, x] > 200)[0])) if (sa[:, x] > 200).any() else top
            support_heights.append((support_top - bottom) * case[3] / seat.height)
            native_top = int(np.flatnonzero(native_holder[:, x] > 200)[0])
            if support_top > native_top:
                raise ValueError('new floor remains lower than native mounting floor')
            for y in range(bottom, top):
                if back_field[y, x] <= 200:
                    gaps += 1
                    unsupported += int(sa[y, x] <= 200)
        if unsupported:
            raise ValueError('new seat leaves central unsupported air')
        contacts['ice' if ice else 'normal'] = {'gapBeforeSeatLayoutMinMax': [min(heights), max(heights)],
                                               'paintedFaceToMetalFloorLayoutMinMax': [min(support_heights), max(support_heights)],
                                               'unsupportedPixelsBefore': gaps, 'unsupportedPixelsAfter': unsupported}
    return {'contacts': contacts, 'layerOrder': ORDER, 'nativeGeometryPreserved': True,
            'originalForegroundRGBAExact': True, 'bothNativePaintedFaceAperturesClear': True}


def verify_layered_pack(folder, work, root):
    folder, work, root = Path(folder), Path(work), Path(root)
    replay = {name: validate_source(work / 'Sources' / (name + '.scene.json'), work / 'Sources' / (name + '.png'), root)
              for name in ('health', 'seat')}
    contract = json.loads((work / 'layer-contract.json').read_text())
    layers = validate_layers(contract, read(folder / 'pw_crystal_case-seat.tga'), read(folder / 'pw_crystal_case.tga'), root)
    health = health_preflight(read(folder / 'hp_cap_case-over.tga'), root)
    return {'sourceReplay': replay, 'nativeLayers': layers, 'health': health, 'exportReplay': verify_pack(folder, root)}
