"""Compare revised material on identical original texture canvases and alpha."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops

root = Path(__file__).resolve().parent.parent
assets = root/'Assets'
out = root/'Docs/Research_Assets/Paladin/Revision2'
sheet = Image.new('RGBA', (1500, 1120), '#101217')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 24)
small = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 19)
draw.text((45, 25), 'PALADIN REVISION 2  /  ORIGINAL GEOMETRY', font=font, fill='#dac69b')
draw.text((410, 80), 'AzeriteUI original', font=font, fill='white')
draw.text((930, 80), 'Subtle Paladin material', font=font, fill='white')
rows = [('Action button', 'actionbutton-border', 'action-ring', 125),
        ('Utility cog', 'config_button', 'utility-cog', 355),
        ('Focus / target-of-target', 'cast_back', 'compact-case', 555),
        ('Tooltip edge atlas', 'border-tooltip', 'utility-edge', 800)]
for label, before, after, y in rows:
    a = Image.open(assets/(before+'.tga')).convert('RGBA')
    b = Image.open(assets/'Paladin'/(after+'.tga')).convert('RGBA')
    assert a.size == b.size
    assert ImageChops.difference(a.getchannel('A'), b.getchannel('A')).getbbox() is None
    draw.text((40, y+55), label, font=small, fill='#dac69b')
    # Identical scale for each pair; no alpha trimming or independent fit.
    scale = 1.5 if a.width < 512 else .92
    size = (round(a.width*scale), round(a.height*scale))
    for x, im in [(340, a), (890, b)]:
        sheet.alpha_composite(im.resize(size, Image.Resampling.LANCZOS), (x, y-55 if a.height == 256 else y))
    draw.text((40, y+110), f'{a.width} x {a.height}', font=small, fill='#8a8b99')
draw.text((45, 975), 'Matching canvas, silhouette, opening, shadow alpha and texture-cell positions.', font=font, fill='#cfced4')
draw.text((45, 1020), 'Offline texture comparison. Focus/ToT retain 112 x 11 fills and their original 193 x 93 casing layout.', font=small, fill='#9496a4')
sheet.save(out/'Original-vs-Paladin.png')
print(out/'Original-vs-Paladin.png')
