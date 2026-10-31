"""Readable Tides/Lava comparison on the complete, unchanged native health HUD.

Uses intact AI candidate paintings at the measured diagnostic registration.
No art repair, acceptance, installer or runtime mutation is performed.
"""
from pathlib import Path
import importlib.util
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman'
spec=importlib.util.spec_from_file_location('shaman_choice_preview',ROOT/'Tools/Render-ShamanAssets.py')
R=importlib.util.module_from_spec(spec);spec.loader.exec_module(R)

class Renderer(R.Renderer):
    def own(self,name):
        for choice in ('tides','lava'):
            prefix='ornament-'+choice+'-'
            if name.startswith(prefix):
                case=name[len(prefix):]
                return Image.open(WORK/'Rejected'/(choice+'-'+case+'-unmodified-ai-diagnostic.png')).convert('RGBA')
        return super().own(name)

def label(page,text,x,y,size=22,color='#ded6c5'):
    ImageDraw.Draw(page).text((x,y),text,font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',size),fill=color)

def main():
    r=Renderer();choices=('tides','lava')
    scenes={key:r.health(resource='crystal',choice=key,fraction=.72) for key in choices}
    box=Image.fromarray(np.maximum.reduce([np.asarray(scene)[:,:,3] for scene in scenes.values()])).getbbox()
    # Identical native size and crop for both choices at each magnification.
    for scale in (1,2):
        width=max(850,(box[2]-box[0])*scale+100)
        row_height=(box[3]-box[1])*scale+105
        page=Image.new('RGBA',(width,2*row_height+135),'#14181d')
        label(page,'SHAMAN — TIDES / LAVA TOTEM',32,20,28)
        label(page,'Samme player-frame, krystal og 72% health · '+str(scale)+'× · offline preview',32,65,16)
        for i,key in enumerate(choices):
            y=115+i*row_height
            label(page,'Tides' if key=='tides' else 'Lava Totem',32,y,24)
            art=scenes[key].crop(box).resize(((box[2]-box[0])*scale,(box[3]-box[1])*scale),Image.Resampling.LANCZOS)
            assert 32+art.width<=page.width and y+45+art.height<=page.height
            page.alpha_composite(art,(32,y+45))
        page.convert('RGB').save(WORK/('Shaman-Tides-Lava-healthframe-'+str(scale)+'x.png'))
    (WORK/'healthframe-choice-preview.json').write_text(json.dumps({'status':'AI painting preview; pending maintainer fit approval; not installed',
        'nativeLayoutChanged':False,'fraction':.72,'sourceFiles':r.sources,'viewport':box,'liveValidated':False},indent=2)+'\n',encoding='utf-8')
    print('Complete player HUD comparison rendered at 1x/2x with an identical viewport and native layout.')

if __name__=='__main__': main()
