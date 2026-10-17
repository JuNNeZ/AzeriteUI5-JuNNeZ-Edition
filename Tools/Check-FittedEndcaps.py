"""Validate installed exports, native contours, mounting sockets and source locks.

Pixel/contract checks only, not a WoW rendering or live-client acceptance test.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
import runpy
import sys

ROOT=Path(__file__).resolve().parent.parent
if (ROOT/'Docs/Research_Assets/EndcapRebuild-2026-10-17/manifest.json').exists():
    sys.argv.append('--installed')
    runpy.run_path(str(ROOT/'Tools/Check-RebuiltHealthArt.py'),run_name='__main__')
    raise SystemExit(0)
WORK=ROOT/'Docs/Research_Assets/EndcapFit-2026-10-17'
manifest=json.loads((WORK/'manifest.json').read_text())
checks=0


def check(value,label):
    global checks
    checks+=1
    assert value,label


def read(path):return Image.open(path).convert('RGBA')


for relative,item in manifest['files'].items():
    file=ROOT/relative;image=read(file);pixels=np.asarray(image)
    check(list(image.size)==item['size'],'canvas: '+relative)
    check(hashlib.sha256(file.read_bytes()).hexdigest()==item['sha256'],'hash: '+relative)
    if relative.endswith('-glow.tga'):
        check(np.all(pixels[:,:,0]==pixels[:,:,1]) and np.all(pixels[:,:,1]==pixels[:,:,2]),'neutral halo: '+relative)
    if relative.endswith('-fitted.tga') and ('endcap-' in relative or 'ornament-' in relative):
        seam=round(128-14/(88*1.3)*256)
        check(pixels[128,seam,3]>=250,'opaque socket across actual health seam: '+relative)
        a=pixels[:,:,3]>128; yy,xx=np.where(a)
        check(xx.min()>0 and xx.max()<255 and yy.min()>0 and yy.max()<255,'intact padded motif: '+relative)

for input_path in (WORK/'Inputs').glob('*/*.png'):
    original=ROOT/'Assets'/input_path.parent.name/(input_path.stem+'.tga')
    if original.exists() and '-fitted' not in input_path.stem and '-capped' not in input_path.stem:
        check(read(input_path).tobytes()==read(original).tobytes(),'retained original painting: '+str(original.relative_to(ROOT)))

for name in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case'):
    native=read(ROOT/'Assets'/(name+'.tga'))
    back=read(ROOT/'Assets/Hunter'/(name+'-fitted.tga'))
    front=read(ROOT/'Assets/Hunter'/(name+'-fitted-over.tga'))
    check(back.size==native.size and back.getchannel('A').tobytes()==native.getchannel('A').tobytes(),'Hunter exact native dipped alpha: '+name)
    inside=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L'))>0
    check(not np.any(np.asarray(front)[:,:,3][inside]>200),'no opaque front over native Hunter fill: '+name)
    # The bare dip exists; only the mounted version removes its terminal.
    geometry=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())[name]
    x1=geometry['meter'][2]
    for theme in ('Hunter','Mage','Druid'):
        key=name+('-fitted' if theme=='Hunter' else '')
        bare=read(ROOT/'Assets'/theme/(key+'.tga'))
        capped=read(ROOT/'Assets'/theme/(key+'-capped.tga'))
        check(capped.size==bare.size,'mount variant canvas: '+theme+'/'+name)
        check(not np.asarray(capped)[:,x1-12:,3].any(),'old tip concealed under socket: '+theme+'/'+name)
        check(np.any(np.asarray(bare)[:,x1-12:,3]),'None retains finished tip: '+theme+'/'+name)

print('Fitted endcaps:',checks,'checks passed; live Retail/Forever still owed.')
