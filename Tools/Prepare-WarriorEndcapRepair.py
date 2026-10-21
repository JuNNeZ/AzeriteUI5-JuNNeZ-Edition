"""Prepare measured terminal masks and generator guides; never changes art."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw
from ThemeHealthEndcaps import lowest_point,terminal_mask

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Warrior/Terminal-Repair'
OUT=ROOT/'Assets_Draft/Warrior'


def main():
    WORK.mkdir(parents=True,exist_ok=True)
    lock={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.tga')}
    path=WORK/'before-assets.json'
    if not path.exists():
        path.write_text(json.dumps(lock,indent=2)+'\n',encoding='utf-8')
    masks={}
    (WORK/'Masks').mkdir(exist_ok=True)
    for name in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case'):
        reference=Image.open(OUT/(name+'-over.tga')).convert('RGBA')
        required=terminal_mask(reference)
        path=WORK/'Masks'/(name+'.png')
        if path.exists():
            assert np.array_equal(np.asarray(Image.open(path)),np.asarray(required)),'frozen terminal mask changed'
        else:
            required.save(path)
        masks[name]={'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                     'pixels':int((np.asarray(required)>0).sum()),'bounds':list(required.getbbox()),
                     'casingSha256':hashlib.sha256((OUT/(name+'-over.tga')).read_bytes()).hexdigest()}
    lock_path=WORK/'mask-lock.json'
    if lock_path.exists():
        assert masks==json.loads(lock_path.read_text()),'frozen mask/casing contract changed'
    else:
        lock_path.write_text(json.dumps(masks,indent=2)+'\n',encoding='utf-8')
    native=Image.open(OUT/'hp_cap_case-over.tga').convert('RGBA')
    tx,ty=lowest_point(native)
    solid=np.asarray(native)[:,:,3]>128
    yy,xx=np.indices(solid.shape)
    terminal=np.asarray(terminal_mask(native))>0
    mask=Image.fromarray((terminal*255).astype('uint8'))
    mask.save(WORK/'terminal-mask.png')
    # A rigid whole-painting envelope with its toe near the inlet, leaving
    # enough solid body to the right to cover the native pointed termination.
    guide=Image.new('RGBA',(1024,1024),'#30343b')
    draw=ImageDraw.Draw(guide)
    poly=[(176,280),(384,210),(736,128),(896,360),(868,704),
          (720,832),(512,832),(384,928),(176,832)]
    draw.polygon(poly,fill='#525c67',outline='#00ffff',width=4)
    factor=144/800
    origin=(tx-(384-176)*factor,ty-144)
    # Map the measured full terminal into the generator's envelope coordinates.
    terminal_guide=Image.new('RGBA',(1024,1024))
    for y,x in zip(*np.where(terminal)):
        gx=round((x-origin[0])/factor+176)
        gy=round((y-origin[1])/factor+128)
        if 0<=gx<1024 and 0<=gy<1024:
            ImageDraw.Draw(terminal_guide).rectangle((gx-3,gy-3,gx+3,gy+3),fill='#c33dba')
    guide.alpha_composite(terminal_guide)
    draw=ImageDraw.Draw(guide)
    draw.ellipse((376,920,392,936),fill='#ffde49')
    draw.text((35,30),'CYAN: complete cap envelope / MAGENTA: existing terminal MUST be covered',fill='white')
    draw.text((35,55),'YELLOW: only lowest mounting toe / no art below / bar enters from left',fill='white')
    guide.save(WORK/'mount-envelope-guide.png')
    for key in ('stromkar','warswords','wrath'):
        outline=poly if key!='warswords' else [(176,180),(400,290),(580,250),(736,128),(896,360),
                                               (868,704),(720,832),(512,832),(384,928),(176,832)]
        template=Image.new('RGBA',(1024,1024))
        ImageDraw.Draw(template).polygon(outline,fill='#50545b')
        template.save(WORK/(key+'-shape-template.png'))
    whole=Image.new('RGBA',(1024,256),'#20252b')
    whole.alpha_composite(Image.open(OUT/'hp_cap_case.tga').convert('RGBA'))
    whole.alpha_composite(native)
    whole.save(WORK/'bare-casing.png')
    report={'dip':[tx,ty],'terminalPixels':int(terminal.sum()),'terminalBounds':list(mask.getbbox()),
            'terminalPolicy':'all solid foreground from first descending lower dip edge outward, including upper point and full dip slope',
            'sourceEnvelope':poly,'sourceToe':[384,928],'referenceHeight':144,'liveValidated':False}
    (WORK/'guide-contract.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
