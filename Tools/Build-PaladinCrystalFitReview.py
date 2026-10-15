"""Literal concept cutout and matched-crystal comparison requested after live review.

Screenshots are read-only; source pixels are used only for the explicitly
requested holder. The third top panel is a reconstruction, never a live result.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from PaladinFillContracts import crystal_rects, crystal_overlap

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14'
OUT = WORK/'Measured-Cradle'
SCREENSHOTS = ROOT.parents[2]/'Screenshots'
FONT = 'C:/Windows/Fonts/segoeui.ttf'


def main():
    recipe = json.loads((OUT/'cutout.json').read_text())
    reference = Image.open(WORK/'approved-concept.png').convert('RGBA')
    mask = Image.new('L', (reference.width*4, reference.height*4))
    ImageDraw.Draw(mask).polygon([(x*4, y*4) for x, y in recipe['polygon']], fill=255)
    mask = mask.resize(reference.size, Image.Resampling.LANCZOS)
    rgb = np.asarray(reference)
    alpha = np.array(mask)
    purple = (rgb[:, :, 2].astype(float) > rgb[:, :, 0]*1.4) & (rgb[:, :, 2].astype(float) > rgb[:, :, 1]*1.2) & (rgb[:, :, 2] > 60)
    alpha[purple] = 0
    cut = reference.copy(); cut.putalpha(Image.fromarray(alpha))
    cut = cut.crop(recipe['crop']); cut.save(OUT/'Concept-holder-cutout.png')
    original_crop = np.asarray(reference.crop(recipe['crop']))
    assert np.array_equal(np.asarray(cut)[:, :, :3], original_crop[:, :, :3]), 'cutout RGB changed'
    assert (WORK/'Sources/CradleVariants/1.png').read_bytes() == (OUT/'Concept-holder-cutout.png').read_bytes(), 'rebuild sources from requested literal cutout'
    loader = importlib.util.spec_from_file_location('review', ROOT/'Tools/Build-PaladinDropInReview.py')
    review = importlib.util.module_from_spec(loader); loader.loader.exec_module(review)
    db = dict(review.LAYOUTS['paladin']['PlayerFrame']); db.update(db['Seasoned'])
    sim = Image.new('RGBA', (280, 280))
    bar = (40, 10, *db['PowerBackdropSize'])
    _, local_case = crystal_rects(db)
    case = (bar[0]+local_case[0], bar[1]+local_case[1], *local_case[2:])
    review.B.put(sim, review.asset(db['PowerBackdropTexture']), bar)
    review.B.fill(sim, db['PowerBarTexture'], bar, 1, (116/255, 156/255, 1))
    review.B.put(sim, review.asset(db['PowerBarForegroundTexture'].replace('.tga', '-v1.tga')), case)
    background = Image.new('RGBA', sim.size, '#17191d'); background.alpha_composite(sim)
    new = background.crop((70, 35, 222, 205))
    images = [reference.crop((55, 195, 207, 365))]
    names = ['Approved concept / literal pixels']
    files = [SCREENSHOTS/('WoWScrnShot_101426_'+n+'.jpg') for n in ('224119', '224115', '135204', '135616')]
    shots = [Image.open(p).convert('RGBA').crop((60, 799, 212, 969)) for p in files]
    images += [shots[0], new, shots[1], shots[2], shots[3]]
    names += ['Live / 22:41:19 / BEFORE', 'NEW / native-fill reconstruction', 'Live / 22:41:15 / BEFORE', 'Live / 13:52:04 / older holder', 'Live / 13:56:16 / older holder']
    board = Image.new('RGB', (1580, 1280), '#14161a'); draw = ImageDraw.Draw(board)
    draw.text((24, 18), 'CONCEPT CUTOUT / LIVE SCREENSHOTS / NEW REGISTERED HOLDER', font=ImageFont.truetype(FONT, 24), fill='#d0c8b5')
    draw.text((24, 60), 'Same pixel scale (3x crops). Crystal origin aligned. New panel is offline, not a client screenshot.', font=ImageFont.truetype(FONT, 17), fill='#d0c8b5')
    for i, (im, name) in enumerate(zip(images, names)):
        x, y = 26+(i%3)*520, 125+(i//3)*565
        draw.text((x, y-30), name, font=ImageFont.truetype(FONT, 17), fill='#d0c8b5')
        board.paste(im.resize((456, 510), Image.Resampling.NEAREST).convert('RGB'), (x, y))
    board.save(OUT/'Comparison.png')
    manifest = json.loads((WORK/'manifest.json').read_text())
    metrics = {'conceptCrystalBounds': recipe['crystalLandmarks']['concept'],
               'liveCrystalBounds': recipe['crystalLandmarks']['game_224119'],
               'liveHolderApproxBounds': [67, 924, 199, 957],
               'nativeRenderedWidthLimit': 177*198/256,
               'screenshots': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
               'new': {}}
    for name in ('pw_crystal_case', 'pw_crystal_case_low'):
        fit = manifest['crystalFit'][name+'-v1']; box = fit['painted']
        im = Image.open(ROOT/'Assets/Paladin'/(name+'-v1.tga')).convert('RGBA')
        metrics['new'][name] = {'paintedTextureBounds': box, 'renderedWidth': (box[2]-box[0])*198/256,
            'renderedHeight': (box[3]-box[1])*98/128, 'wholeCrystalOverlap': crystal_overlap(name, im.getchannel('A'))}
    (OUT/'measurements.json').write_text(json.dumps(metrics, indent=2)+'\n')
    print(json.dumps(metrics['new'], indent=2))


if __name__ == '__main__': main()
