"""Install the approved staged Druid art and generated neutral resource effects.

python Tools/Build-DruidRuntime.py
No layout data or other theme art is changed.
"""
from pathlib import Path
import hashlib
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Druid'
OUT=ROOT/'Assets/Druid'
S=Image.Resampling.LANCZOS


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(exist_ok=True)
    manifest=json.loads((WORK/'HD/manifest.json').read_text())
    assert all(not e['failures'] for e in manifest['checks'].values())
    for name,entry in manifest['checks'].items():
        source=WORK/'HD/Export'/(name+'.tga')
        assert sha(source)==entry['sha256'],name
        shutil.copyfile(source,OUT/source.name)
    native=Image.open(ROOT/'Assets/orb2.tga').convert('RGBA')
    water=Image.open(WORK/'Effects/Sources/moonwell.png').convert('L').resize(native.size,S)
    image=Image.merge('RGBA',(water,water,water,native.getchannel('A')))
    image.save(OUT/'orb-moonwell.tga',compression=None)
    assert image.getchannel('A').tobytes()==native.getchannel('A').tobytes()
    light=Image.open(WORK/'Effects/Sources/dreamlight.png').convert('RGBA').resize((512,512),S)
    grey=light.convert('L')
    image=Image.merge('RGBA',(grey,grey,grey,light.getchannel('A')))
    image.save(OUT/'dreamlight.tga',compression=None)
    manifest['status']='Installed Druid WIP art and Lite+ effects; live validation pending'
    manifest['effects']={p.name:{'canvas':list(Image.open(p).size),'sha256':sha(p)}
                         for p in (OUT/'orb-moonwell.tga',OUT/'dreamlight.tga')}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    board=Image.new('RGBA',(1100,700),'#14161a')
    draw=ImageDraw.Draw(board)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    draw.text((20,12),'Druid Moonwell: actual water fill, native orb alpha / 0, 50, 100%',font=font,fill='white')
    fill=Image.open(OUT/'orb-moonwell.tga').convert('RGBA')
    rgba=np.array(fill)
    rgba[:,:,:3]=(rgba[:,:,:3]*np.array([.30,.55,1.0])).astype('uint8')
    fill=Image.fromarray(rgba)
    for i,f in enumerate((0,.5,1)):
        scene=Image.new('RGBA',(256,256))
        base=Image.open(ROOT/'Assets/orb-backdrop2.tga').convert('RGBA').resize((256,256),S)
        scene.alpha_composite(base)
        art=fill.resize((140,140),S)
        a=np.array(art.getchannel('A')); a[:round(140*(1-f))]=0
        art.putalpha(Image.fromarray(a))
        scene.alpha_composite(art,(58,58))
        scene.alpha_composite(Image.open(OUT/'orb_case_hi.tga').convert('RGBA'))
        board.alpha_composite(scene,(20+i*350,65))
        draw.text((95+i*350,335),str(round(f*100))+'%',font=font,fill='white')
    draw.text((20,400),'Water phases: LibOrb counter-rotation (offline static samples)',font=font,fill='white')
    for i,angle in enumerate((0,90,180)):
        art=fill.rotate(angle,Image.Resampling.BICUBIC).resize((180,180),S)
        board.alpha_composite(art,(60+i*350,450))
    board.convert('RGB').save(WORK/'Effects/Moonwell-review.png')
    print('Installed 47 staged art textures plus Moonwell/Dreamlight; native orb alpha unchanged.')


if __name__=='__main__': main()
