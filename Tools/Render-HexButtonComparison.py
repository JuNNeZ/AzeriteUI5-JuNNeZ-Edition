"""Compare real Lua-resolved button configs; no guessed theme tints or geometry.

Masque is an optional offline dimension reference only. No reference pixels are
copied into Assets or consumed by the original-art builder.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Docs/Research_Assets/HexButtons'


def local_path(path):
    if Path(path).is_absolute():
        return Path(path)
    return ROOT / 'Assets' / path.split('Assets\\', 1)[1].replace('\\', '/')


def tint(im, color):
    data = np.asarray(im).copy()
    data[..., :3] = np.rint(data[..., :3] * np.array(color)).clip(0, 255).astype('uint8')
    return Image.fromarray(data, 'RGBA')


def assembly(cfg):
    canvas = Image.new('RGBA', (112, 112))
    icon_size = round(cfg['iconSize'])
    icon = Image.new('RGBA', (icon_size, icon_size), '#378b95')
    draw = ImageDraw.Draw(icon)
    draw.polygon([(icon_size*.2, icon_size*.8), (icon_size*.5, icon_size*.15), (icon_size*.8, icon_size*.8)], fill='#cbe3a1')
    mask = Image.open(local_path(cfg['mask'])).convert('RGBA').getchannel('A')
    icon.putalpha(mask.resize(icon.size, Image.Resampling.LANCZOS))
    for path, size, color in ((cfg['backdrop'], cfg['backSize'], cfg['backTint']), (None, icon_size, None), (cfg['border'], cfg['borderSize'], cfg['tint'])):
        layer = icon if path is None else tint(Image.open(local_path(path)).convert('RGBA'), color).resize((round(size), round(size)), Image.Resampling.LANCZOS)
        canvas.alpha_composite(layer, ((112-layer.width)//2, (112-layer.height)//2))
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default=r'C:/Users/Jonas/.vscode/extensions/actboy168.lua-debug-2.3.0-win32-x64/runtime/win32-x64/lua51/lua.exe')
    args = parser.parse_args()
    result = subprocess.run([args.lua, 'Tools/Harness/theme_button_shapes_harness.lua', '.', 'export'], cwd=ROOT, capture_output=True, text=True, check=True)
    configs = {}
    for row in result.stdout.splitlines():
        if not row.startswith('REVIEW|'):
            continue
        _, theme, shape, border, size, r,g,b, mask, icon, backdrop, back_size, br,bg,bb = row.split('|')
        configs.setdefault(theme, {})[shape] = dict(border=border, borderSize=float(size), tint=list(map(float,(r,g,b))), mask=mask,
            iconSize=float(icon), backdrop=backdrop, backSize=float(back_size), backTint=list(map(float,(br,bg,bb))))
    sheet = Image.new('RGBA', (1600, 2080), '#30373d')
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 10), 'OFFLINE: real Lua configs / same synthetic icon / circle, square, rounded, Hex / 1x + 2x', fill='white')
    metrics = {}
    for index, (theme, choices) in enumerate(configs.items()):
        y = 48 + index*250
        draw.text((12,y), theme, fill='white')
        metrics[theme] = {}
        for col, (shape, cfg) in enumerate(choices.items()):
            x = 125+col*360
            draw.text((x,y), shape, fill='white')
            sample = assembly(cfg)
            sheet.alpha_composite(sample, (x-30,y+20))
            sheet.alpha_composite(sample.resize((224,224), Image.Resampling.NEAREST), (x+82,y+2))
            data = np.asarray(tint(Image.open(local_path(cfg['border'])).convert('RGBA'), cfg['tint']))
            yy,xx = np.indices(data.shape[:2])
            # Solid outer material only; exclude central portrait glass/specular.
            inner = 42 if shape == 'circle' else 60
            selected = (data[...,3]>240) & (np.hypot(xx-127.5,yy-127.5)>inner)
            assert selected.any(), theme + shape + ' has no measurable solid casing'
            rgb = data[...,:3][selected]/255
            luma = rgb @ np.array([.2126,.7152,.0722])
            metrics[theme][shape] = dict(tint=cfg['tint'], meanRGB=np.mean(rgb,axis=0).tolist(),
                lumaP10P50P90=np.percentile(luma,[10,50,90]).tolist(), borderSize=cfg['borderSize'], iconSize=cfg['iconSize'])
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT/'theme-colour-comparison.png')
    (OUT/'runtime-configs.json').write_text(json.dumps(configs,indent=2)+'\n')
    (OUT/'colour-measurements.json').write_text(json.dumps(metrics,indent=2)+'\n')
    manifest = json.loads((ROOT/'Assets/HexButtons/provenance.json').read_text())
    dimensions = {}
    for theme, item in manifest['classBorders'].items():
        values = {}
        for label, path in (('before', ROOT/f'Assets/{theme}/portrait_frame_hi.tga'), ('after', ROOT/'Assets'/item['export'])):
            im = Image.open(path).convert('RGBA')
            box = im.getchannel('A').point(lambda a:255 if a>200 else 0).getbbox()
            values[label] = [round((box[i+2]-box[i])*96/256,3) for i in (0,1)]
        dimensions[theme] = values
    (OUT/'class-size-measurements.json').write_text(json.dumps(dimensions,indent=2)+'\n')
    for theme, shapes in metrics.items():
        c,h = shapes['circle'], shapes['hex']
        print(theme, 'circle/hex luma p10/50/90:', [round(v,3) for v in c['lumaP10P50P90']], [round(v,3) for v in h['lumaP10P50P90']], 'tint equal:',c['tint']==h['tint'])
    # Read-only local size reference: displayed here, never exported into Assets.
    reference = Path(r'C:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/Masque_Azerite_Hex/media')
    if reference.is_dir():
        ref = dict(configs['azerite']['hex'])
        ref.update(border=str(reference/'actionbutton-border.tga'), mask=str(reference/'actionbutton_circular_mask.tga'),
                   backdrop=str(reference/'actionbutton-backdrop.tga'), iconSize=63, tint=[1,1,1], backTint=[1,1,1])
        before = dict(configs['azerite']['hex'], borderSize=80, iconSize=46, backSize=80)
        # Reconstruct our rejected procedural radius-54 mask in research only.
        mask = Image.new('RGBA',(128,128))
        from math import sqrt
        for y in range(128):
            for x in range(128):
                xx,yy=abs(x-63.5),abs(y-63.5)
                q=max(xx,.5*xx+sqrt(3)/2*yy)-54*sqrt(3)/2
                mask.putpixel((x,y),(255,255,255,round(255*max(0,min(1,.5-q)))))
        old_mask=OUT/'rejected-radius54-mask.png';mask.save(old_mask)
        before['mask']=str(old_mask)
        size_sheet=Image.new('RGBA',(900,340),'#30373d');d=ImageDraw.Draw(size_sheet)
        d.text((12,8),'OFFLINE size reference only; synthetic icons; 1x + 2x',fill='white')
        sizes={}
        for col,(label,cfg) in enumerate((('Old 80/46 layout',before),('Masque HEX reference',ref),('Original corrected',configs['azerite']['hex']))):
            x=20+col*300
            d.text((x,35),label,fill='white');sample=assembly(cfg)
            size_sheet.alpha_composite(sample,(x,60));size_sheet.alpha_composite(sample.resize((224,224),Image.Resampling.NEAREST),(x+70,110))
            values={}
            for kind,key,draw_size in (('border','border',cfg['borderSize']),('mask','mask',cfg['iconSize'])):
                im=Image.open(local_path(cfg[key])).convert('RGBA')
                box=im.getchannel('A').point(lambda a:255 if a>200 else 0).getbbox()
                values[kind]=[round((box[i+2]-box[i])*draw_size/im.size[i],4) for i in (0,1)]
            sizes[label]=values
        size_sheet.save(OUT/'masque-size-comparison.png')
        (OUT/'size-reference.json').write_text(json.dumps(sizes,indent=2)+'\n')


if __name__ == '__main__':
    main()
