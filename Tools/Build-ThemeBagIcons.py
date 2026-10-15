"""Export original generated bag paintings for the five selectable themes.

Only the icon changes; the live button keeps its native circular mask and size.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/ThemeBagIcons-2026-10-14'
OUT = ROOT/'Assets/ThemeBagIcons'
KEYS = ('azerite', 'legacy', 'hunter', 'mage', 'paladin')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGBA', (1000,300), '#14161a')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 18)
    manifest = {'generator': 'built-in image_gen', 'liveValidated': False, 'icons': {}}
    for i, key in enumerate(KEYS):
        source = WORK/'Sources'/(key+'.png')
        paint = Image.open(source).convert('RGBA')
        box = paint.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
        assert box, key+' empty'
        paint = paint.crop(box)
        paint.thumbnail((200,200), Image.Resampling.LANCZOS)
        icon = Image.new('RGBA', (256,256))
        icon.alpha_composite(paint, ((256-paint.width)//2, (256-paint.height)//2))
        target = OUT/(key+'.tga')
        icon.save(target, compression=None)
        assert Image.open(target).convert('RGBA').tobytes() == icon.tobytes(), key+' roundtrip'
        manifest['icons'][key] = {'canvas': [256,256],
            'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
        draw.text((20+i*195,20), key.title(), font=font, fill='#c4beac')
        sheet.alpha_composite(icon.resize((140,140), Image.Resampling.LANCZOS), (20+i*195,60))
        # Same native circular icon mask as the live bag button.
        mask = Image.open(ROOT/'Assets/actionbutton-mask-circular.tga').convert('RGBA').getchannel('A')
        small = icon.resize((28,28), Image.Resampling.LANCZOS)
        from PIL import ImageChops
        small.putalpha(ImageChops.multiply(small.getchannel('A'), mask.resize((28,28), Image.Resampling.LANCZOS)))
        sheet.alpha_composite(small, (75+i*195,225))
    draw.text((20,270), 'Offline art review: enlarged / native 28px circular mask. Click route and anchors unchanged.', font=font, fill='#c4beac')
    sheet.convert('RGB').save(WORK/'Review.png')
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n', encoding='utf-8')
    print('Five themed bag icons exported and TGA roundtrips checked (offline only).')


if __name__ == '__main__':
    main()
