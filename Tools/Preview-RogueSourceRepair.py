"""Uninstalled whole-painting Rogue repair review; never stencil source alpha.

The two generated paintings and their prompts are retained beside the review.
Export only complete, uniformly scaled paintings. Report geometric failures;
neither the native silhouette nor the functional mask may trim the painting.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Rogue/Source-Rebuild-2026-10-29'
OUT = ROOT/'Assets_Draft/Rogue-Rebuild-2026-10-29'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Tools'/file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def whole(source, width, xy, canvas):
    bounds = source.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    art = source.crop(bounds)
    height = round(art.height*width/art.width)
    painting = art.resize((width, height), Image.Resampling.LANCZOS)
    x, y = xy
    assert x >= 0 and y >= 0 and x+width <= canvas[0] and y+height <= canvas[1]
    result = Image.new('RGBA', canvas)
    result.paste(painting, xy)
    # The whole resized RGBA painting survives, including its own alpha.
    assert result.crop((x, y, x+width, y+height)).tobytes() == painting.tobytes()
    return result, {'sourceBoundsAlphaAbove8': bounds, 'uniformScale': width/art.width,
                    'offset': xy, 'resized': painting.size, 'paintedRGBAUnchangedAfterPlacement': True}


def save(name, image):
    path = OUT/(name+'.tga')
    image.save(path, compression=None)
    assert read(path).tobytes() == image.tobytes(), 'TGA codec changed RGBA'
    header = path.read_bytes()[:18]
    assert header[2] == 2 and header[16] == 32
    return {'sha256': sha(path), 'canvas': image.size, 'codecRGBAExact': True}


def build():
    contract = json.loads((WORK/'contract.json').read_text())
    unrelated_drift = []
    checked = 0
    for path, digest in contract['protected'].items():
        # Shaman is concurrently being worked on in this shared checkout.
        # Preserve the frozen snapshot and report its drift, never rebaseline
        # it or claim those out-of-scope files passed this Rogue check.
        if path.startswith('Assets/Shaman/'):
            if sha(ROOT/path) != digest:
                unrelated_drift.append(path)
            continue
        assert sha(ROOT/path) == digest, 'Protected runtime/art/layout changed: '+path
        checked += 1
    OUT.mkdir(exist_ok=True)
    fields = ROOT/'Docs/Research_Assets/Templates'
    fill = np.asarray(Image.open(fields/'hp_cap_case-fill.png').convert('L')) > 128
    # Replay the separately recorded bounded rigid fit. It retains the entire
    # source and native bottom row; failing aperture/toe checks stay failures.
    candidate = json.loads((WORK/'candidate-fit.json').read_text())
    health, hf = whole(read(WORK/'Sources/health-v2.png'), candidate['width'], tuple(candidate['offset']), (1024, 256))
    crystal, cf = whole(read(WORK/'Sources/crystal-v1.png'), 177, (39, 26), (256, 128))
    native = np.asarray(read(ROOT/'Assets/hp_cap_case.tga'))
    back = np.zeros_like(native)
    # Shared empty-meter recess is the only copied native component. It is
    # below health, never a mask applied to either new casing painting.
    back[fill] = native[fill]
    assets = {name: save(name, image) for name, image in (
        ('hp_cap_case', Image.fromarray(back)), ('hp_cap_case-over', health), ('pw_crystal_case', crystal))}
    H = load('rogue_repair_coverage', 'ThemeHealthEndcaps.py')
    hp = np.asarray(health)[:, :, 3]
    occlusion = float(((hp > 200) & fill).sum()/fill.sum())
    native_dip = H.lowest_point(read(ROOT/'Assets/hp_cap_case.tga'))
    actual_dip = H.lowest_point(health)
    caps = {}
    for choice in ('twinguard', 'serrated', 'venom'):
        cap = read(ROOT/'Assets/Rogue'/('ornament-'+choice+'-hp_cap_case.tga'))
        caps[choice] = H.terminal_coverage(health, cap)
    report = {'runtimeInstalled': False, 'installationAuthorized': False,
        'method': 'whole source uniform scale/translation, own alpha, no native casing stencil or RGB extension',
        'assets': assets, 'registration': {'health': hf, 'crystal': cf},
        'sources': {p.name: sha(p) for p in sorted((WORK/'Sources').glob('*'))},
        'fillOverlapFraction': occlusion, 'nativeDip': native_dip, 'candidateDip': actual_dip,
        'capCoverageAgainstNewPainting': caps, 'protectedRuntimeFilesVerified': checked,
        'unrelatedConcurrentShamanDriftNotValidated': unrelated_drift,
        'productionAccepted': False,
        'remaining': ['Health opening still overlaps native fill; no post-export erasure allowed',
                      'New health lowest toe and terminal must fit the frozen native mounting contract',
                      'No other tiers generated before representative geometry and visual acceptance',
                      'Targeted aperture retry retained; resolve exact contour-edit method before further generation'],
        'liveValidated': False}
    write(WORK/'review-manifest.json', report)
    print(json.dumps({k: report[k] for k in ('fillOverlapFraction', 'nativeDip', 'candidateDip', 'capCoverageAgainstNewPainting', 'runtimeInstalled')}, indent=2))


def render(review_label=None):
    R = load('rogue_repair_review', 'Render-RogueSuite.py')

    class Review(R.Renderer):
        def __init__(self, repaired):
            super().__init__()
            self.repaired = repaired

        def asset(self, path):
            if path is None:
                return None
            normalized = path.replace('\\', '/')
            name = Path(normalized).stem
            if '/Rogue/' in normalized and self.repaired and name in ('hp_cap_case', 'hp_cap_case-over', 'pw_crystal_case'):
                return read(OUT/(name+'.tga'))
            if '/Rogue/' in normalized:
                return read(ROOT/'Assets/Rogue'/(name+'.tga'))
            return super().asset(path)

    old, new = Review(False), Review(True)
    labels = ['INSTALLED / current textures', review_label or 'NEW WHOLE PAINTINGS / review only; aperture and toe fit still pending']
    def text(board, label, pos, size=18):
        ImageDraw.Draw(board).text(pos, label, font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf', size), fill='#eee5d6')
    # One union viewport and identical rail origin for all comparisons.
    scenes = [r.health(resource='crystal', choice='venom') for r in (old, new)]
    union = Image.fromarray(np.maximum.reduce([np.asarray(s)[:, :, 3] for s in scenes])).getbbox()
    for scale in (1, 2):
        width = max(1100, (union[2]-union[0])*scale+40)
        height = (union[3]-union[1])*scale
        page = Image.new('RGBA', (width, height*2+190), '#59616d')
        text(page, 'ROGUE SOURCE REBUILD / '+str(scale)+'x / OFFLINE / NOT INSTALLED', (20, 14), 23)
        for row, scene in enumerate(scenes):
            y = 83+row*(height+65)
            text(page, labels[row], (20, y-29))
            art = scene.crop(union).resize(((union[2]-union[0])*scale, height), Image.Resampling.LANCZOS)
            page.alpha_composite(art, (20, y))
        page.convert('RGB').save(WORK/('assembled-'+str(scale)+'x.png'))
    # Full None/each existing ornament on both directions, fixed viewport.
    page = Image.new('RGBA', (1800, 1400), '#59616d')
    text(page, 'NEW PAINTINGS / COMPLETE PLAYER + TARGET / NATIVE RECTANGLES / REVIEW ONLY', (20, 12), 24)
    pairs = []
    for choice in (None, 'twinguard', 'serrated', 'venom'):
        pairs.append([new.health(flip, cap=choice is not None, choice=choice or 'venom', fraction=.5 if flip else 1,
                                prediction=flip, resource=None if flip else 'crystal') for flip in (False, True)])
    boxes = [Image.fromarray(np.maximum.reduce([np.asarray(p[i])[:, :, 3] for p in pairs])).getbbox() for i in (0, 1)]
    for row, choice in enumerate(('NONE', 'TWIN GUARD', 'SERRATED', 'VENOM VIAL')):
        y = 65+row*320
        text(page, choice, (20, y))
        for col in (0, 1):
            image = pairs[row][col].crop(boxes[col])
            assert image.width <= 875 and image.height <= 300, image.size
            page.alpha_composite(image, (20+col*890, y+30))
    page.convert('RGB').save(WORK/'complete-bars.png')
    # Partial/empty/full values expose actual aperture rather than hiding it.
    page = Image.new('RGBA', (1800, 1000), '#59616d')
    text(page, 'UNCLIPPED EXPORTS / 0, 50, 100% / CURRENT NATIVE FILLS / REVIEW ONLY', (20, 12), 24)
    for col, fraction in enumerate((0, .5, 1)):
        text(page, str(round(fraction*100))+'%', (20+col*595, 58))
        for row, r in enumerate((old, new)):
            scene = r.health(cap=False, fraction=fraction, prediction=fraction==.5)
            art = scene.crop(scene.getbbox())
            factor = min(1, 560/art.width, 170/art.height)
            art = art.resize((round(art.width*factor), round(art.height*factor)), Image.Resampling.LANCZOS)
            text(page, 'INSTALLED' if row == 0 else 'NEW / UNTRIMMED ALPHA', (20+col*595, 105+row*240))
            page.alpha_composite(art, (20+col*595, 138+row*240))
        scene = Image.new('RGBA', (800, 500))
        new.resource('crystal', fraction, scene)
        art = scene.crop(scene.getbbox())
        assert 550+art.height <= page.height, 'Crystal cradle clipped by review viewport'
        page.alpha_composite(art, (20+col*595, 550))
    page.convert('RGB').save(WORK/'fill-states.png')
    names = ('assembled-1x.png', 'assembled-2x.png', 'complete-bars.png', 'fill-states.png')
    write(WORK/'review-images.json', {name: sha(WORK/name) for name in names})
    print('Rendered 1x/2x fixed-view complete assembly, None/all caps, mirrored target and fill states. No runtime installation.')


if __name__ == '__main__':
    build()
    render()
