"""Correct transparent-canvas registration only; preserve whole Shaman paint."""
from pathlib import Path
import importlib.util
import json
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman/Crystal-Fit-2026-10-29'
NAMES=('pw_crystal_case','pw_crystal_case_low','pw_crystal_case-glow','pw_crystal_case_low-glow',
       'crystal-assembly-glow','crystal-assembly-wrath-glow','crystal-assembly-low-glow','crystal-assembly-low-wrath-glow')

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

L=module('shaman_crystal_live','Install-ShamanLivePreview.py')

def build():
    WORK.mkdir(parents=True,exist_ok=True)
    before=WORK/'Before';before.mkdir(exist_ok=True)
    installed=ROOT/'Assets/Shaman'
    assert not (WORK/'repair.json').exists(),'Repair already built; use --install or inspect retained evidence'
    for name in (*NAMES,'manifest'):
        filename=name+('.json' if name=='manifest' else '.tga')
        shutil.copyfile(installed/filename,before/filename)
    prior=json.loads((installed/'manifest.json').read_text())
    for name,item in prior['assets'].items(): assert L.sha(installed/(name+'.tga'))==item['sha256']
    H=module('shaman_crystal_halo','Build-RebuiltHealthArt.py')
    original=Image.open(L.WORK/'Sources/pw_crystal_case.png').convert('RGBA')
    paint=L.crystal_canvas(original)
    for name in NAMES[:2]:
        path=L.OUT/(name+'.tga');paint.save(path,compression=None)
        L.verify_crystal(Image.open(path).convert('RGBA'),original)
        H.halo(paint).save(L.OUT/(name+'-glow.tga'),compression=None)
    B=module('shaman_crystal_build','Build-ShamanAssets.py');B.OUT=L.OUT;B.WORK=WORK;B.resource_halos()
    manifest=json.loads((L.OUT/'manifest.json').read_text())
    for name in NAMES:
        path=L.OUT/(name+'.tga')
        manifest['assets'][name]={'sha256':L.sha(path),'canvas':list(Image.open(path).size)}
    manifest['crystal']='Whole original paint translated on transparent canvas to native centre-rail y; no scaling, masking or runtime geometry change'
    manifest['crystalOffset']=list(L.CRYSTAL_OFFSET)
    L.save(L.OUT/'manifest.json',manifest)
    L.save(WORK/'repair.json',{'before':prior['assets'],'after':manifest['assets'],
        'runtimeSnapshot':{name:L.sha(ROOT/name) for name in json.loads((L.WORK/'installed-integration.json').read_text())['files']},
        'sourceSha256':L.sha(L.WORK/'Sources/pw_crystal_case.png'),
        'offsetBefore':[137,68],'offsetAfter':list(L.CRYSTAL_OFFSET),
        'translationHD':[0,-81],'nativeCentreRailY':65,'sourceCentreRailY':533,
        'allVisibleSourceRGBAUnchanged':True,'nativeLayoutsChanged':False,'liveValidated':False})
    render()

def render():
    R=module('shaman_crystal_review','Render-ShamanAssets.py');R.OUT=L.OUT
    P=module('shaman_crystal_contract','PaladinFillContracts.py')
    base=P.LAYOUTS['PlayerFrame'];scenes=[]
    for tier in ('Seasoned','Novice'):
        db=dict(base);db.update(base[tier])
        r=R.Renderer();r.replace(db);r.config=lambda:db
        for old in (True,False):
            current=r.asset
            if old:
                def before(path,delegate=current):
                    name=Path(path.replace('\\','/')).stem
                    file=WORK/'Before'/(name+'.tga')
                    return Image.open(file).convert('RGBA') if file.exists() else delegate(path)
                r.asset=before
            for fraction in (1,.5,0):
                scenes.append((tier,old,fraction,r.resource('crystal',fraction)))
            r.asset=current
    box=Image.fromarray(np.maximum.reduce([np.asarray(row[3])[:,:,3] for row in scenes])).getbbox()
    for scale in (1,2):
        cellw=(box[2]-box[0])*scale+70;cellh=(box[3]-box[1])*scale+50
        page=Image.new('RGBA',(cellw*3,cellh*4+55),'#161a20')
        draw=ImageDraw.Draw(page);draw.text((15,15),'SHAMAN CRYSTAL / BEFORE + CORRECTED / '+str(scale)+'x / OFFLINE',fill='white')
        for i,(tier,old,fraction,scene) in enumerate(scenes):
            x=(i%3)*cellw+20;y=(i//3)*cellh+55
            draw.text((x,y),tier+(' BEFORE ' if old else ' CORRECTED ')+str(round(fraction*100))+'%',fill='white')
            art=scene.crop(box).resize(((box[2]-box[0])*scale,(box[3]-box[1])*scale),Image.Resampling.LANCZOS)
            page.alpha_composite(art,(x,y+25))
        page.convert('RGB').save(WORK/('crystal-before-after-'+str(scale)+'x.png'))
    # Complete health/crystal join at fixed origins and union viewports.
    r=R.Renderer();delegate=r.asset
    def old_asset(path):
        name=Path(path.replace('\\','/')).stem
        file=WORK/'Before'/(name+'.tga')
        return Image.open(file).convert('RGBA') if file.exists() else delegate(path)
    whole=[]
    for old in (True,False):
        r.asset=old_asset if old else delegate
        whole.append(r.health(resource='crystal',fraction=.72))
    box=Image.fromarray(np.maximum.reduce([np.asarray(scene)[:,:,3] for scene in whole])).getbbox()
    for scale in (1,2):
        w=(box[2]-box[0])*scale;h=(box[3]-box[1])*scale
        page=Image.new('RGBA',(w+60,2*(h+60)+40),'#161a20');draw=ImageDraw.Draw(page)
        for i,scene in enumerate(whole):
            y=20+i*(h+60);draw.text((20,y),'BEFORE' if i==0 else 'CORRECTED / SAME FRAME ORIGIN',fill='white')
            page.alpha_composite(scene.crop(box).resize((w,h),Image.Resampling.LANCZOS),(20,y+25))
        page.convert('RGB').save(WORK/('whole-health-before-after-'+str(scale)+'x.png'))

def install():
    record=json.loads((WORK/'repair.json').read_text());target=ROOT/'Assets/Shaman'
    for name,item in record['before'].items():
        allowed={item['sha256'],record['after'][name]['sha256']} if name in NAMES else {item['sha256']}
        assert L.sha(target/(name+'.tga')) in allowed,'Installed art changed since repair build: '+name
        if name not in NAMES: assert record['after'][name]==item,'Out-of-scope texture changed'
    for name in NAMES:
        src=L.OUT/(name+'.tga');assert L.sha(src)==record['after'][name]['sha256']
        shutil.copyfile(src,target/src.name)
    manifest=json.loads((L.OUT/'manifest.json').read_text())
    L.save(target/'manifest.json',dict(manifest,runtimeInstalled=True,sourceManifestSha256=L.sha(L.OUT/'manifest.json')))
    L.verify_installed(record['runtimeSnapshot'])
    L.save(WORK/'installed.json',{'changedTextures':list(NAMES),'unchangedTextures':69,
        'verifiedManifestSha256':L.sha(target/'manifest.json'),'liveValidated':False})
    print('Installed crystal registration repair; 8 holder/halo TGAs updated, 69 other textures unchanged.')

if __name__=='__main__':
    if '--install' in sys.argv: install()
    elif '--verify' in sys.argv:
        L.verify_installed(json.loads((WORK/'repair.json').read_text())['runtimeSnapshot'])
    elif '--render' in sys.argv: render()
    else: build()
