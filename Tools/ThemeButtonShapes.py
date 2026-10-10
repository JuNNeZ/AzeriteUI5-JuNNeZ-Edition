"""Build Square/Rounded borders from a theme's own ring, never native RGB.

Native alpha is retained byte for byte, including corners, glass and shadow.
Polar sampling preserves angular material detail and top-down illumination;
each target ray maps its solid band to the source ray's solid band.
Run Build-ThemeButtonShapes.py for the focused export and comparison sheet.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

NAMES = ('actionbutton-border-square', 'actionbutton-border-square-rounded')
ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sample(array, x, y):
    """Bilinear RGB sampling; alpha is always supplied by the native target."""
    x = np.clip(x, 0, array.shape[1] - 1)
    y = np.clip(y, 0, array.shape[0] - 1)
    xi, yi = x.astype(int), y.astype(int)
    xj, yj = np.minimum(xi + 1, array.shape[1] - 1), np.minimum(yi + 1, array.shape[0] - 1)
    fx, fy = (x - xi)[..., None], (y - yi)[..., None]
    return ((array[yi, xi] * (1-fx) + array[yi, xj] * fx) * (1-fy)
            + (array[yj, xi] * (1-fx) + array[yj, xj] * fx) * fy)


def band(alpha, angle):
    """Inner/outer solid edge on each ray, measured at quarter-pixel steps."""
    radius = np.arange(0, min(alpha.shape) * .71, .25)
    cx, cy = (alpha.shape[1]-1)/2, (alpha.shape[0]-1)/2
    x = np.clip(np.rint(cx + np.cos(angle)[..., None]*radius).astype(int), 0, alpha.shape[1]-1)
    y = np.clip(np.rint(cy + np.sin(angle)[..., None]*radius).astype(int), 0, alpha.shape[0]-1)
    solid = alpha[y, x] > 128
    if not np.all(solid.any(axis=-1)):
        raise ValueError('Source or target does not contain a closed solid band')
    inner = radius[solid.argmax(axis=-1)]
    outer = radius[len(radius)-1-solid[..., ::-1].argmax(axis=-1)]
    return inner, outer


def border(source, original):
    if source.size != original.size or source.size != (256, 256):
        raise ValueError('Button sources must be 256x256')
    src, target = np.asarray(source), np.asarray(original)
    y, x = np.indices(target.shape[:2])
    x, y = x-127.5, y-127.5
    angle = np.arctan2(y, x)
    # Quantised angles bound memory while keeping subpixel material sampling.
    directions = np.linspace(-np.pi, np.pi, 2048, endpoint=False)
    idx = np.floor((angle + np.pi)/(2*np.pi)*2048).astype(int) % 2048
    ti, to = band(target[..., 3], directions)
    si, so = band(src[..., 3], directions)
    fraction = np.clip((np.hypot(x, y)-ti[idx]) / np.maximum(to[idx]-ti[idx], 1), 0, 1)
    # Stay just inside the material band, avoiding transparent RGB at its lip.
    radius = si[idx] + .75 + fraction * np.maximum(so[idx]-si[idx]-1.5, 1)
    rgb = sample(src[..., :3].astype(float), 127.5 + np.cos(angle)*radius,
                 127.5 + np.sin(angle)*radius)
    # Expanding the lower leather/corner sectors can invert the average light.
    # A subtle top-down falloff keeps the material lit from above on straight rails.
    rgb *= (1 - .12 * np.clip(y / 81, -1, 1))[..., None]
    result = np.concatenate((np.rint(rgb).clip(0,255).astype('uint8'), target[..., 3:4]), axis=-1)
    result[target[..., 3] == 0, :3] = 0
    return Image.fromarray(result, 'RGBA')


def build_theme(root, theme, manifest=None, mapping=None):
    """Also used by the Hunter full build before writing media/manifest."""
    folder = root/'Assets'/theme
    source_path = folder/'actionbutton-border.tga'
    source = Image.open(source_path).convert('RGBA')
    if manifest is None:
        manifest = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    for name in NAMES:
        original_path = root/'Assets'/(name+'.tga')
        original = Image.open(original_path).convert('RGBA')
        result = border(source, original)
        assert result.getchannel('A').tobytes() == original.getchannel('A').tobytes()
        file = folder/(name+'.tga')
        result.save(file, compression=None)
        item = dict(path=f'Assets/{theme}/{file.name}', sha256=digest(file), bytes=file.stat().st_size,
                    source=f'Assets/{theme}/actionbutton-border.tga', sourceSha256=digest(source_path),
                    alphaSource=f'Assets/{original_path.name}', alphaSourceSha256=digest(original_path),
                    build='Tools/ThemeButtonShapes.py: polar material sampling; exact native alpha')
        if theme == 'Hunter':
            item.update(disposition='hunter material', size=list(result.size))
            manifest['originals'][name] = item
            if mapping is not None:
                mapping[name] = 'actionbutton-border'
        else:
            manifest['assets'] = [a for a in manifest['assets'] if a['path'] != item['path']]
            manifest['assets'].append(item)
    return manifest


def comparison(root, output):
    """Offline assembly using the shared action/Cooldown Manager sizes.

    Colour pattern is a synthetic icon, not a screenshot. CD samples are single
    icons: their spacing belongs to Blizzard Edit Mode, not addon defaults.
    """
    sheet = Image.new('RGBA', (980, 520), '#32383e')
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 10), 'OFFLINE: native alpha; shared masks/backdrops; synthetic icons. 1x + enlarged texture detail.', fill='white')
    yy, xx = np.indices((256,256))
    icon = Image.fromarray(np.stack((60+xx//2, 55+yy//2, 165-xx//4, np.full_like(xx,255)), axis=-1).astype('uint8'), 'RGBA')
    for row, theme in enumerate(('AzeriteUI', 'Mage', 'Hunter')):
        y = 65+row*150
        draw.text((12,y), theme, fill='white')
        for col, name in enumerate(NAMES):
            x = 120+col*420
            shape = name.replace('actionbutton-border-', '')
            deco = 93.1 if shape.endswith('rounded') else 96.3
            folder = root/'Assets'/(theme if theme != 'AzeriteUI' else '')
            art = Image.open(folder/(name+'.tga')).convert('RGBA')
            back = Image.open(root/'Assets'/('actionbutton-backdrop-'+shape+'.tga')).convert('RGBA')
            mask = Image.open(root/'Assets'/('actionbutton-mask-'+shape+'.tga')).convert('RGBA').getchannel('A')
            def assembly(icon_size, deco_size, tint):
                canvas = Image.new('RGBA', (144,144))
                for kind, layer, size in (("back",back,deco_size),("icon",icon,icon_size),("border",art,deco_size)):
                    layer = layer.resize((round(size),round(size)),Image.Resampling.LANCZOS)
                    if kind == "icon":
                        layer.putalpha(mask.resize(layer.size,Image.Resampling.LANCZOS))
                    else:
                        factor = .67 if kind == "back" else tint
                        pixels = np.asarray(layer).copy()
                        pixels[..., :3] = np.rint(pixels[..., :3]*factor).astype("uint8")
                        layer = Image.fromarray(pixels, "RGBA")
                    canvas.alpha_composite(layer,((144-layer.width)//2,(144-layer.height)//2))
                return canvas
            action = assembly(60,deco,1 if theme != "AzeriteUI" else .75)
            pet = assembly(45,deco*.75,1 if theme != "AzeriteUI" else .75)
            cd = assembly(50*(1.18 if shape.endswith('rounded') else 1.14),50*216/118,.75)
            draw.text((x,y-20), shape+' / action pair, pet, CD, detail', fill='white')
            for offset, im in ((0,action),(64,action),(132,pet),(194,cd)):
                sheet.alpha_composite(im,(x+offset-42,y-42))
            detail=art.resize((192,192),Image.Resampling.LANCZOS).crop((30,30,162,162))
            sheet.alpha_composite(detail,(x+255,y-35))
    output.parent.mkdir(parents=True,exist_ok=True)
    sheet.convert('RGB').save(output)


def main():
    for theme in ('Mage','Hunter'):
        manifest = build_theme(ROOT, theme)
        if theme == 'Mage':
            note = 'Square/Rounded borders use Mage circle material and native alpha; shared backdrops/masks/highlights; live fitting pending.'
            status = manifest['status'].replace('46 runtime textures.', '48 runtime textures.')
            if note not in status:
                status += ' ' + note
            manifest['status'] = status
        (ROOT/'Assets'/theme/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
        print(theme, 'built', ', '.join(NAMES))
    comparison(ROOT, ROOT/'Docs/Research_Assets/ButtonShapes/comparison.png')


if __name__ == '__main__':
    main()
