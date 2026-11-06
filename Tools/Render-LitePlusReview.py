"""Render real Lite+ widget recordings and native-geometry concept references.

Offline BLEND/ADD approximation, never a WoW capture or production asset.
Run the Hunter/Mage harnesses with `. samples <output.json>` first.
"""
from pathlib import Path
from functools import lru_cache
import argparse, hashlib, json, math, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parent.parent
S = Image.Resampling.LANCZOS
BG = '#141c20'
TILE = (220, 250)
MISSING = set()

@lru_cache(maxsize=96)
def texture(name):
    name = name.replace('\\', '/')
    relative = name.split('/Assets/')[-1] if '/Assets/' in name else name
    path = ROOT/'Assets'/relative
    if not path.exists():
        MISSING.add(name)
        return None
    return Image.open(path).convert('RGBA')

def arr(im):
    return np.asarray(im, dtype=np.float32)/255

def sample(name, size, coords=(0, 1, 0, 1)):
    return sample_cached(name, size, tuple(coords))

@lru_cache(maxsize=24)
def sample_cached(name, size, coords):
    im = texture(name)
    if im is None:
        return np.zeros((size[1], size[0], 4), np.float32)
    if len(coords)==4:
        l,r,t,b=coords
        transform=((r-l)*im.width/size[0],0,l*im.width,0,(b-t)*im.height/size[1],t*im.height)
    else:
        a,b,c,d,e,f,_,_=coords
        transform=((e-a)*im.width/size[0],(c-a)*im.width/size[1],a*im.width,
                   (f-b)*im.height/size[0],(d-b)*im.height/size[1],b*im.height)
    return arr(im.transform(size,Image.Transform.AFFINE,transform,Image.Resampling.BILINEAR))

def over(dst, src):
    return dst*(1-src[:, :, 3:4])+src[:, :, :3]*src[:, :, 3:4]

def put(scene, name, size, position, color=(1, 1, 1), alpha=1):
    im = texture(name)
    if im is None:
        return
    im = im.resize(tuple(round(v) for v in size), S)
    a = arr(im).copy()
    a[:, :, :3] *= color[:3]
    a[:, :, 3] *= alpha
    scene.alpha_composite(Image.fromarray(np.uint8(np.clip(a*255, 0, 255))), tuple(round(v) for v in position))

def material(frame, n, mask, fill, base):
    clip = mask.copy()
    clip[:round(n*(1-fill))] = 0
    result = base.copy()
    for layer in frame['layers']:
        if not layer['alpha']:
            continue
        x, y, w, h = layer['rect']
        iw, ih = max(1, round(w*n)), max(1, round(h*n))
        a = sample(layer['path'], (iw, ih), layer['coords']).copy()
        a[:, :, :3] *= layer['color'][:3]
        a[:, :, 3] *= layer['alpha']*frame['alpha']
        canvas = Image.new('RGBA', (n, n))
        canvas.alpha_composite(Image.fromarray(np.uint8(np.clip(a*255, 0, 255))), (round(x*n), round(y*n)))
        a = arr(canvas).copy()
        a[:, :, 3:4] *= clip
        if layer['blend'] == 'ADD':
            result += a[:, :, :3]*a[:, :, 3:4]
        else:
            result = over(result, a)
    return np.clip(result, 0, 1)

def resource(theme, kind, fill, frame=None, time=0, focus=False):
    scene = Image.new('RGBA', TILE, BG)
    # Resource-only classes borrow the actual native AzeriteUI casing.
    # They do not have a full class casing pack.
    casing = theme+'/' if (ROOT/'Assets'/theme/'pw_crystal_case.tga').exists() else ''
    if kind == 'crystal':
        n, pos = 196, (12, 8)
        mask = sample('power_crystal_front.tga', (n, n))[:, :, 3:4]
        put(scene, 'power_crystal_back.tga', (n, n), pos)
        base = arr(scene.crop((pos[0], pos[1], pos[0]+n, pos[1]+n)))[:, :, :3]
        a = sample('power_crystal_front.tga', (n, n)).copy()
        a[:, :, :3] *= (0.32, 0.45, 0.95)
        a[:round(n*(1-fill)), :, 3] = 0
        base = over(base, a)
        if frame:
            base = material(frame, n, mask, fill, base)
        scene.paste(Image.fromarray(np.uint8(base*255)), pos)
        # Player.lua compensates the legacy 140px viewport by +28px on BOTTOM:
        # native bottom -51 becomes -23 on the complete 196px viewport.
        # Hunter StyleCrystal uses x=0 rather than the native x=7.
        put(scene, casing+'pw_crystal_case.tga', (198, 98),
            (pos[0]-1+(0 if theme == 'Hunter' else 7), pos[1]+196+23-98))
    else:
        n, pos = 103, (58, 59)
        mask = sample('orb2.tga', (n, n))[:, :, 3:4]
        put(scene, 'orb-backdrop2.tga', (180, 180), (pos[0]-(180-n)/2, pos[1]-(180-n)/2))
        base = arr(scene.crop((pos[0], pos[1], pos[0]+n, pos[1]+n)))[:, :, :3]
        paint = 'Hunter/orb-focus.tga' if focus else 'orb2.tga'
        a = sample(paint, (n, n)).copy()
        a[:, :, :3] *= ((1, .62, .12) if focus else (.32, .45, .95))
        a[:round(n*(1-fill)), :, 3] = 0
        base = over(base, a)
        if frame:
            base = material(frame, n, mask, fill, base)
        scene.paste(Image.fromarray(np.uint8(base*255)), pos)
        put(scene, 'orb-glass.tga', (173, 173), (pos[0]-35, pos[1]-35), alpha=.9)
        put(scene, 'shade-circle.tga', (127, 127), (pos[0]-12, pos[1]-12), color=(0, 0, 0))
        put(scene, casing+'orb_case_hi.tga', (188, 188), (pos[0]-42.5, pos[1]-42.5))
    return scene.convert('RGB')

def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', size)

def build(data, out, animate=True):
    theme = data['theme']
    variants = data['variants']
    height = 190+len(variants)*270
    board = Image.new('RGB', (1420, height), BG)
    d = ImageDraw.Draw(board)
    d.text((28, 18), theme+' / Lite+ - faktiske assets og Lua-animationer', font=font(27), fill='#e2e5db')
    d.text((28, 58), 'Krystaller 196px / orbs 103px. Hele casings og samme viewport ved alle fyldniveauer.', font=font(17), fill='#a7b9b1')
    for i, label in enumerate(('Krystal 100%', 'Krystal 50%', 'Krystal 0%', 'Orb 100%', 'Orb 50%', 'Orb 0%')):
        d.text((95+i*220+110, 107), label, anchor='mm', font=font(17), fill='#c5d2c6')
    d.text((28, height-42), 'Offline til vurdering. WoW-rendering og native spark-halo er ikke gengivet fuldt.', font=font(16), fill='#a7b9b1')
    def render(index):
        result = board.copy()
        draw = ImageDraw.Draw(result)
        for row, variant in enumerate(variants):
            draw.text((18, 118+row*270), variant.get('label', variant['name'].title()), font=font(17), fill='#d8d3b8')
            for col, (kind, fill) in enumerate((('crystal', 1), ('crystal', .5), ('crystal', 0), ('orb', 1), ('orb', .5), ('orb', 0))):
                sample_frame = variant[kind][index] if kind in variant else None
                tile = resource(theme, kind, fill, sample_frame, index/data['fps'], theme == 'Hunter')
                result.paste(tile, (95+col*220, 138+row*270))
        return result
    stem = theme+'_LitePlus_Review'+('_'+variants[0]['name'] if len(variants)==1 else '')
    length=len(variants[0]['crystal'])
    still = render(min(17,length-1))
    still.save(out/(stem+'.png'))
    still.resize((still.width*2, still.height*2), Image.Resampling.NEAREST).save(out/(stem+'_2x.png'))
    if not animate:
        return [stem+'.png',stem+'_2x.png']
    # One shared palette avoids independently quantized frames and large GIFs.
    palette = still.quantize(colors=192)
    colors = (palette.getpalette()+[0]*768)[:768]
    palette_image = Image.new('RGB', (16, 16))
    palette_image.putdata([tuple(colors[i:i+3]) for i in range(0,768,3)])
    palette_path = out/(stem+'_palette.png')
    palette_image.save(palette_path)
    # Stream one RGB frame at a time to the local encoder. No retained-frame
    # collection and no network protocols; large school sheets stay bounded.
    encoder = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-threads', '1', '-filter_complex_threads', '1',
        '-protocol_whitelist', 'file,pipe', '-f', 'rawvideo', '-pixel_format', 'rgb24',
        '-video_size', f'{board.width}x{board.height}', '-framerate', str(data['fps']),
        '-i', 'pipe:0', '-i', str(palette_path),
        '-filter_complex', '[0:v][1:v]paletteuse=dither=none', '-loop', '0', str(out/(stem+'.gif'))], stdin=subprocess.PIPE)
    first = render(0)
    for index in range(len(variants[0]['crystal'])):
        result = first if index == 0 else render(index)
        if index == min(25,length-1):
            for row in range(len(variants)):
                for col in (2, 5):
                    box = (95+col*220, 138+row*270, 315+col*220, 388+row*270)
                    assert ImageChops.difference(first.crop(box), result.crop(box)).getbbox() is None, 'empty resource gained energy'
            assert ImageChops.difference(first, result).getbbox(), 'animation is static'
        encoder.stdin.write(result.tobytes())
    encoder.stdin.close()
    assert encoder.wait() == 0, 'GIF encoder failed'
    return [stem+'.png', stem+'_2x.png', stem+'.gif']

def references(out):
    rows = {'Warrior': ('Forge', 'Valarjar', 'Battleheart'),
            'Rogue': ('Venom', 'Shadow', 'Nightblood'),
            'Shaman': ('Tides', 'Magma', 'Storm')}
    files = []
    for theme, labels in rows.items():
        board = Image.new('RGB', (1536, 1280), BG)
        d = ImageDraw.Draw(board)
        d.text((35, 18), theme.upper()+' / LITE+ - RESOURCE EFFECT STUDY', font=font(34), fill='#e4e6db')
        d.text((35, 69), 'Reference geometry and existing casings. Change interior effects only.', font=font(20), fill='#b0bfb3')
        for row, label in enumerate(labels):
            y = 125+row*350
            d.text((22, y+115), label, font=font(23), fill='#d8d3b8')
            for col, (kind, fill) in enumerate((('crystal', 1), ('orb', 1), ('orb', .5))):
                tile = resource(theme, kind, fill).resize((352, 400), S)
                board.paste(tile, (230+col*400, y-24))
            d.text((230, y+272), 'Exact native silhouette / full crystal', font=font(15), fill='#b0bfb3')
            d.text((630, y+272), 'Full orb', font=font(15), fill='#b0bfb3')
            d.text((1030, y+272), 'Half orb / empty upper half', font=font(15), fill='#b0bfb3')
        d.text((35, 1240), 'CONCEPT TEMPLATE - preserve shape, opening, casing, scale and positions', font=font(20), fill='#c9c8af')
        name = theme+'_LitePlus_Reference.png'
        board.save(out/name); files.append(name)
    return files

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--samples', nargs='*', type=Path, default=[])
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--references', action='store_true')
    p.add_argument('--variant', help='Render one material at native size with bounded memory')
    p.add_argument('--still-only', action='store_true')
    p.add_argument('--preview-fps', type=int, help='Downsample recording for a lighter preview; runtime cadence is unchanged')
    args = p.parse_args();args.out.mkdir(parents=True, exist_ok=True)
    files = []
    for path in args.samples:
        print('Rendering '+str(path), flush=True)
        data=json.loads(path.read_text())
        if args.variant:
            data['variants']=[v for v in data['variants'] if v['name'].lower()==args.variant.lower()]
            assert data['variants'], 'unknown variant'
        if args.preview_fps and args.preview_fps<data['fps']:
            stride=round(data['fps']/args.preview_fps)
            for variant in data['variants']:
                for kind in ('crystal','orb'):
                    if kind in variant:variant[kind]=variant[kind][::stride]
            data['fps']=data['fps']/stride
        files.extend(build(data,args.out,animate=not args.still_only))
    if args.references:
        files.extend(references(args.out))
    manifest = {'liveCapture': False, 'files': files, 'missingTextures': sorted(MISSING),
        'limitations': ['Pillow BLEND/ADD approximation; WoW renderer and secure behavior not emulated.',
            'Hunter orb shown with actual static focus painting; native LibOrb rotation is not simulated.',
            'WoW casting-bar spark halo omitted; actual point_gem particle cores are rendered.',
            'Eight-second recordings; particle/drift periods need not loop at the clip boundary.'],
        'sourceHashes': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in [ROOT/'Core/HunterTheme.lua', ROOT/'Core/MageCrystalPreview.lua', ROOT/'Core/ClassResourceEffects.lua',
                *[p.resolve() for p in args.samples], *sorted((ROOT/'Assets/LitePlus').glob('*.tga'))]}}
    (args.out/'review-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps({'output': str(args.out.resolve()), 'files': files, 'missing': sorted(MISSING)}))

if __name__ == '__main__':
    main()
