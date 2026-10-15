"""Independent before/after proof of the scoped RGB-only palette correction."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
import numpy as np
from PaladinPalette import CASES, ORNAMENTS
from PaladinFillContracts import mask as fitted_mask

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Palette-Correction'
BEFORE = WORK/'Before'
AFTER = ROOT/'Assets/Paladin'
changed = []
for path in sorted(BEFORE.glob('*.tga')):
    old = np.asarray(Image.open(path).convert('RGBA'))
    current = np.asarray(Image.open(AFTER/path.name).convert('RGBA'))
    assert old.shape == current.shape, path.name+' canvas'
    assert np.array_equal(old[:,:,3],current[:,:,3]), path.name+' alpha/layer geometry'
    base = path.stem.removesuffix('-over').removesuffix('-front')
    if base not in CASES and base not in ORNAMENTS:
        assert np.array_equal(old,current), path.name+' outside palette scope'
        continue
    native = old if base in ORNAMENTS else np.asarray(Image.open(ROOT/'Assets'/(base+'.tga')).convert('RGBA'))
    allowed = native[:,:,3] > 200
    template = ROOT/'Docs/Research_Assets/Templates'/(base+'-fill.png')
    if base.startswith(('pw_crystal_case','hp_critter_case')):
        allowed &= np.asarray(fitted_mask(base,(old.shape[1],old.shape[0]))) == 0
    elif template.exists():
        allowed &= np.asarray(Image.open(template).convert('L')) == 0
    assert np.array_equal(old[~allowed],current[~allowed]), path.name+' functional/glass/shadow pixels'
    assert not np.array_equal(old,current), path.name+' expected colour correction'
    changed.append(path.name)
(WORK/'Verification.json').write_text(json.dumps({'rgbOnlyChanged':changed,'allAlphaIdentical':True,
    'functionalPixelsIdentical':True,'otherArtIdentical':True,'liveValidated':False},indent=2)+'\n')

board = Image.new('RGBA',(1200,1170),'#14161a'); draw = ImageDraw.Draw(board)
font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
draw.text((24,18),'PALADIN PALETTE MATCH - SAME ARTWORK / RGB ONLY',font=font,fill='#c4beac')
draw.text((290,62),'Before',font=font,fill='#c4beac'); draw.text((850,62),'After',font=font,fill='#c4beac')
rows = [('Buttons',['actionbutton-border','actionbutton-border-square','actionbutton-border-square-rounded']),
        ('Crystal casing',['pw_crystal_case','pw_crystal_case_low']),
        ('Health casing',['hp_cap_case']),('Small health',['cast_back']),('Critter health',['hp_critter_case']),
        ('Minimap',['minimap-border','minimap-north']),
        ('XP / reputation',['minimap-onebar-backdrop','minimap-twobars-backdrop'])]
for row,(label,names) in enumerate(rows):
    y = 125+row*145; draw.text((24,y),label,font=font,fill='#c4beac')
    for col,folder in enumerate((BEFORE,AFTER)):
        x = 210+col*560
        for name in names:
            im = Image.open(folder/(name+'.tga')).convert('RGBA'); im = im.crop(im.getbbox())
            im.thumbnail((420 if len(names)==1 else 125,105),Image.Resampling.LANCZOS)
            board.alpha_composite(im,(x,y+28)); x += im.width+22
board.convert('RGB').save(WORK/'Review.png')
print(f'Palette correction: {len(changed)} RGB-only textures; all 50 alpha/canvases and protected pixels unchanged; other art unchanged.')
