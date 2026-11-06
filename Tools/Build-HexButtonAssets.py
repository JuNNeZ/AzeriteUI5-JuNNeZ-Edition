"""Build original common-thickness Hex frames from whole source paintings.

Only uniform scaling/translation; no shared alpha stencil or copied skin pixels.
Neutral functional geometry is procedural. Local opt-in preview, not release.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw
from HexButtonGeometry import register as register_uniform, measure, validate

ROOT = Path(__file__).resolve().parents[1]
SOURCE_FOLDER = ROOT / 'Assets_Draft/HexButtons-Uniform-2026-11-06'
DEFAULT_SOURCE = SOURCE_FOLDER / 'Stock-source.png'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def register(source):
    return register_uniform(source)[0]


def register_class(source):
    return register_uniform(source)


def hex_distance(x, y, apothem):
    return max(abs(x), .5 * abs(x) + math.sqrt(3)/2 * abs(y)) - apothem


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=DEFAULT_SOURCE)
    source=parser.parse_args().source
    generation=json.loads((source.parent/'generation.json').read_text())
    outputs={};classes={};geometry={};sources={}
    for theme,record in generation['sources'].items():
        path=ROOT/record['path']
        assert digest(path)==record['sha256'], theme+' source drift'
        assert digest(ROOT/record['prompt'])==record['promptSha256'], theme+' prompt drift'
        for ref in record['inputImages']:
            assert digest(ROOT/ref['path'])==ref['sha256'], theme+' reference drift'
        painting=Image.open(path).convert('RGBA')
        output,transform=register_uniform(painting)
        geometry[theme]=measure(output)
        name='actionbutton-border-hex' if theme=='Stock' else f'HexButtons/{theme}/border'
        outputs[name]=output
        sources[name]=dict(source=record['path'],sourceSha256=record['sha256'],transform=transform,
                           construction='whole painting; uniform scale and translation; original RGBA/alpha')
        if theme!='Stock':
            classes[theme]=dict(path=record['path'],sha256=record['sha256'],export=name+'.tga',transform=transform)
    assert len(outputs)==8, 'Incomplete theme inventory'
    validate(geometry)  # Fail before touching runtime art.
    for name,size,radius,color in (('actionbutton-mask-hex',128,60,(255,255,255)),
                                   ('actionbutton-backdrop-hex',256,91,(20,24,29))):
        im=Image.new('RGBA',(size,size));pix=im.load()
        for y in range(size):
            for x in range(size):
                q=hex_distance(x-(size-1)/2,y-(size-1)/2,radius*math.sqrt(3)/2)
                pix[x,y]=color+(round(255*max(0,min(1,.5-q))),)
        outputs[name]=im
    for thickness,width in (('thin',2),('medium',4),('thick',6)):
        for kind in ('outline','glow'):
            im=Image.new('RGBA',(256,256));pix=im.load()
            for y in range(256):
                for x in range(256):
                    q=hex_distance(x-127.5,y-127.5,80)
                    if kind=='outline':
                        a=min(1,max(0,q+.5),max(0,width+.5-q))
                    else:
                        a=math.exp(-.5*((q-width/2)/(width+2))**2)*min(1,max(0,(q+8.5)/8))
                    pix[x,y]=(255,255,255,round(255*a))
            outputs[f'actionbutton-proc-hex-{kind}-{thickness}']=im
    outputs['actionbutton-spellhighlight-hex']=outputs['actionbutton-proc-hex-outline-medium'].copy()
    assets={}
    for name,image in outputs.items():
        dest=ROOT/'Assets'/(name+'.tga');dest.parent.mkdir(parents=True,exist_ok=True)
        image.save(dest,compression=None)
        actual=Image.open(dest).convert('RGBA')
        assert actual.size==image.size and actual.tobytes()==image.tobytes(), name+' RGBA changed on export'
        assert dest.read_bytes()[2]==2, 'Runtime TGA must be uncompressed'
        assets[name+'.tga']=dict(sha256=digest(dest),**sources.get(name,dict(source='Tools/Build-HexButtonAssets.py',construction='procedural neutral functional geometry')))
    folder=ROOT/'Assets/HexButtons';folder.mkdir(parents=True,exist_ok=True)
    (folder/'provenance.json').write_text(json.dumps(dict(schema=2,assets=assets,generation=generation,
        classBorders=classes,geometry=geometry,thirdPartyMediaInputs=[],
        status='Original common-thickness paintings; own geometry guide, own material references. Local opt-in review; maintainer/live/release approval pending.'),indent=2)+'\n')
    review()


def review():
    """Complete eight-button rows, 1x/2x, using actual reopened runtime TGAs."""
    themes = ('AzeriteUI', 'Hunter', 'Mage', 'Paladin', 'Druid', 'Warrior', 'Rogue', 'Shaman')
    sheet = Image.new('RGBA', (1260, 1960), '#34383d')
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 8), 'OFFLINE - intact existing art / synthetic icons / complete rows at 1x and 2x', fill='white')
    mask = Image.open(ROOT / 'Assets/actionbutton-mask-hex.tga').convert('RGBA').getchannel('A')
    for row, theme in enumerate(themes):
        y = 38 + row * 240
        draw.text((12, y), theme, fill='white')
        border_path = ROOT / ('Assets/actionbutton-border-hex.tga' if theme == 'AzeriteUI' else f'Assets/HexButtons/{theme}/border.tga')
        border = Image.open(border_path).convert('RGBA').resize((96, 96), Image.Resampling.LANCZOS)
        backdrop = Image.open(ROOT / 'Assets/actionbutton-backdrop-hex.tga').convert('RGBA').resize((96, 96), Image.Resampling.LANCZOS)
        def tint(im, factor):
            channels = im.split()
            return Image.merge('RGBA', tuple(c.point(lambda v: round(v * factor)) for c in channels[:3]) + channels[3:])
        backdrop = tint(backdrop, .67)
        if theme in ('AzeriteUI', 'Rogue', 'Shaman'):
            border = tint(border, .75)
        bar = Image.new('RGBA', (72 * 8 + 32, 112))
        pair = None
        for i in range(8):
            cx, cy = 56 + i * 72, 56
            bar.alpha_composite(backdrop, (cx - 48, cy - 48))
            icon = Image.new('RGBA', (50, 50), ('#be4030', '#2994b5', '#ad60cf', '#449839')[i % 4])
            di = ImageDraw.Draw(icon)
            di.line((5, 42, 25, 8, 44, 38), fill='#ffe68a', width=4)
            icon.putalpha(mask.resize(icon.size, Image.Resampling.LANCZOS))
            bar.alpha_composite(icon, (cx - 25, cy - 25))
            bar.alpha_composite(border, (cx - 48, cy - 48))
            ImageDraw.Draw(bar).text((cx + 13, cy + 15), str(i + 1), fill='#fff08a')
            if i == 1:
                pair = bar.crop((0, 0, 184, 112))
        sheet.alpha_composite(bar, (100, y + 5))
        # Two complete adjacent cells enlarged, preserving the same origin.
        sheet.alpha_composite(pair.resize((368, 224), Image.Resampling.NEAREST), (850, y - 5))
    out = ROOT / 'Docs/Research_Assets/HexButtons'
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / 'comparison.png')


if __name__ == '__main__':
    main()
