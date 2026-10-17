"""Export measured full-casing health endcaps; --install copies checked TGAs.

The complete backing/front/fill stay unchanged. Whole paintings scale uniformly
and share the bare casing's lowest point. No generated bar geometry is used.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/AlignedEndcaps-2026-10-17'
S = Image.Resampling.LANCZOS
CHOICES = {
    'Druid': {'antler':'Wildheart','bear':'Guardian','owl':'Moonkin'},
    'Hunter': {'thasdorah':"Thas'dorah",'talonclaw':'Talonclaw','titanstrike':'Titanstrike',
               'thoridal':"Thori'dal",'raeshalare':"Rae'shalare"},
    'Mage': {'aluneth':'Aluneth','felomelorn':"Felo'melorn",'ebonchill':'Ebonchill',
             'atiesh':'Atiesh','dragonwrath':'Dragonwrath'},
    'Paladin': {'ashbringer':'Ashbringer','silverhand':'Silver Hand','argent':'Argent Crusade'}}
CASES = {'Novice':'hp_low_case','Hardened':'hp_mid_case','Seasoned':'hp_cap_case','Boss':'hp_boss_case'}


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Tools'/file)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


M = module('aligned_art','Build-RebuiltHealthArt.py')
R = module('aligned_layout','Render-FittedEndcaps.py')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dip(image):
    a = np.asarray(image)[:,:,3] > 128
    y = int(np.where(a)[0].max())
    return float(np.median(np.flatnonzero(a[y]))), y


def casing(theme, name):
    return name+('-fitted' if theme == 'Hunter' else '')


def source(theme, key):
    if theme == 'Druid':
        return ROOT/'Docs/Research_Assets/Druid/Endcap-Proof-2026-10-17'/(key+'-source.png')
    if theme == 'Paladin' and key == 'ashbringer':
        return ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Sources/HD/ornament-ashbringer.png'
    return WORK/'Sources'/(theme+'-'+key+'.png')


def export(theme, install=False):
    out = WORK/'Export'/theme
    out.mkdir(parents=True,exist_ok=True)
    report = {'theme':theme,'installed':install,'liveValidated':False,'sources':{},'files':{},'registrations':[]}
    for key in CHOICES[theme]:
        path = source(theme,key)
        report['sources'][path.relative_to(ROOT).as_posix()] = sha(path)
        painting = M.read(path)
        original = painting.crop(M.bounds(painting))
        for name in CASES.values():
            front = M.read(ROOT/'Assets'/theme/(casing(theme,name)+'-over.tga'))
            tx,ty = dip(front)
            height = 133 if name == 'hp_boss_case' else 136 if name == 'hp_cap_case' else 126
            art = original.resize((round(original.width*height/original.height),height),S)
            ax,ay = dip(art)
            x,y = round(tx-ax),ty-ay
            assert x>=0 and y>=0 and x+art.width<=front.width and y+art.height<=front.height
            cap = Image.new('RGBA',front.size)
            cap.alpha_composite(art,(x,y))
            px,py = dip(cap)
            a,b = np.asarray(front)[:,:,3]>128,np.asarray(cap)[:,:,3]>128
            assert abs(tx-px)<=.5 and ty==py and np.any(a[ty]&b[ty])
            assert not b[ty+1:].any(), 'extra lower point'
            mask = np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L'))>128
            coverage = np.count_nonzero((np.asarray(cap)[:,:,3]>200)&mask)/np.count_nonzero(mask)
            assert coverage<=.20, (theme,key,name,'fill coverage',coverage)
            report['registrations'].append({'choice':key,'case':name,'dip':[tx,ty],
                'capPoint':[px,py],'maxNativePixelError':abs(tx-px),'fillCovered':round(coverage,6)})
            for suffix,image in (('',cap),('-glow',M.halo(cap))):
                filename='ornament-'+key+'-'+name+suffix+'.tga'
                dest=out/filename
                image.save(dest)
                assert M.read(dest).tobytes()==image.tobytes()
                report['files'][filename]={'sha256':sha(dest),'size':list(image.size)}
                if install:
                    target=ROOT/'Assets'/theme/filename
                    if target.exists():
                        before=WORK/'Before'/theme/filename
                        if not before.exists():
                            before.parent.mkdir(parents=True,exist_ok=True)
                            shutil.copyfile(target,before)
                    shutil.copyfile(dest,target)
                    assert sha(target)==sha(dest)
    (WORK/(theme+'-manifest.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    return report


def health(theme,key=None,flip=False,tier='Seasoned',fraction=1,installed=True):
    base=R.DATA['original']['TargetFrame' if flip else 'PlayerFrame']
    db=dict(base);db.update(base[tier])
    owner=(300 if flip else 100,60,*base['Size'])
    hp=R.B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
    rect=R.B.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
    name=CASES[tier]
    scene=Image.new('RGBA',(1200,350))
    R.B.put(scene,R.read(theme,casing(theme,name)),rect,flip)
    R.B.fill(scene,db['HealthBarTexture'],hp,1,(.09,.08,.11),flip)
    R.B.fill(scene,db['HealthBarTexture'],hp,fraction,(.84,.03,.08),flip)
    R.B.put(scene,R.read(theme,casing(theme,name)+'-over'),rect,flip)
    folder=ROOT/'Assets'/theme if installed else WORK/'Export'/theme
    if key:
        R.B.put(scene,M.read(folder/('ornament-'+key+'-'+name+'.tga')),rect,flip)
    if flip:
        portrait=Path(db['PortraitBorderTexture'].replace('\\','/')).stem
        R.B.put(scene,R.read(theme,portrait),R.B.anchor(owner,db['PortraitBorderSize'],db['PortraitBorderPosition']))
    common=scene.copy()
    for choice in CHOICES[theme]:
        R.B.put(common,M.read(folder/('ornament-'+choice+'-'+name+'.tga')),rect,flip)
    return scene.crop(common.getbbox())


def review(theme, installed):
    board=Image.new('RGBA',(1536,190+200*(1+len(CHOICES[theme]))),'#14161a')
    draw=ImageDraw.Draw(board)
    def text(value,x,y,size=18):
        draw.text((x,y),value,font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size),fill='#d9d1bc')
    def put(image,x,y):
        assert x+image.width<=board.width and y+image.height<=board.height
        board.alpha_composite(image,(x,y))
    text(theme.upper()+' / ALIGNED HEALTH ENDCAPS / COMPLETE BARS',28,20,30)
    text(('Installed assets' if installed else 'Draft exports')+' / offline reconstruction; live WoW checks still owed.',28,68)
    text('PLAYER / 100% / 1x',28,110,20);text('TARGET / 40% / 1x',790,110,20)
    for index,key in enumerate((None,*CHOICES[theme])):
        y=150+200*index
        text(CHOICES[theme][key] if key else 'NONE / complete original dip',28,y,20)
        for x,flip in ((28,False),(790,True)):
            scene=health(theme,key,flip,fraction=.4 if flip else 1,installed=installed)
            rail_top=int(np.flatnonzero(np.asarray(scene)[:,100,3]>128)[0])
            put(scene,x,y+70-rail_top)
        draw.line((28,y+175,1508,y+175),fill='#454b55')
    board.convert('RGB').save(WORK/(theme+'-installed.png' if installed else theme+'-draft.png'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install',action='store_true')
    parser.add_argument('--theme',choices=CHOICES)
    args=parser.parse_args()
    WORK.mkdir(exist_ok=True)
    lock=WORK/'bare-casing-lock.json'
    protected={p.relative_to(ROOT).as_posix():sha(p) for theme in CHOICES for name in CASES.values()
               for suffix in ('','-over') for p in [ROOT/'Assets'/theme/(casing(theme,name)+suffix+'.tga')]}
    if lock.exists():
        assert protected==json.loads(lock.read_text()), 'bare casing changed during endcap export'
    else:
        lock.write_text(json.dumps(protected,indent=2)+'\n',encoding='utf-8')
    for theme in ([args.theme] if args.theme else CHOICES):
        report=export(theme,args.install)
        review(theme,args.install)
        print(theme,len(report['files']),'exports,',len(report['registrations']),'tip registrations; installed='+str(args.install))


if __name__=='__main__':
    main()
