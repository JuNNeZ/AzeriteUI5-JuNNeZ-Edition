"""Native-density whole-painting Shaman cradle weight correction, WIP live review."""
from pathlib import Path
import importlib.util
import json
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman/Crystal-Weight-2026-10-30'
OUT=ROOT/'Assets_Draft/Shaman/Crystal-Weight-2026-10-30'

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

L=module('shaman_weight_live','Install-ShamanLivePreview.py')
I=module('shaman_weight_integrity','ThemeSourceIntegrity.py')
OLD=module('shaman_weight_old','Repair-ShamanCrystalFit.py')

def prepare():
    OUT.mkdir(parents=True,exist_ok=True);before=WORK/'Before';before.mkdir(exist_ok=True)
    installed=ROOT/'Assets/Shaman'
    prior=json.loads((installed/'manifest.json').read_text())
    assert not (WORK/'repair.json').exists(),'Retained build exists; inspect rather than overwrite'
    for name in OLD.NAMES:
        shutil.copyfile(installed/(name+'.tga'),before/(name+'.tga'))
    source=WORK/'holder-weight-source.png';original=Image.open(source).convert('RGBA')
    bounds=original.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    # Native total height restores visual mass; up to 4% canvas tolerance
    # on each outer edge permits the concept's heavier horns without warping.
    scale=min(70/(bounds[3]-bounds[1]),197/(bounds[2]-bounds[0]))
    size=(round(original.width*scale),round(original.height*scale))
    piece=original.resize(size,Image.Resampling.LANCZOS)
    b=piece.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    x=round(127.5-(b[0]+b[2])/2)
    rail=int(np.flatnonzero(np.asarray(piece)[:,128-x,3]>200)[0]);y=65-rail
    transform={'scale':scale,'offset':[x,y]}
    canvas=I.whole_painting(original,transform,(256,128))
    H=module('shaman_weight_halos','Build-RebuiltHealthArt.py')
    for name in OLD.NAMES[:2]:
        canvas.save(OUT/(name+'.tga'),compression=None)
        I.verify_pixels(canvas,Image.open(OUT/(name+'.tga')).convert('RGBA'))
        H.halo(canvas).save(OUT/(name+'-glow.tga'),compression=None)
    B=module('shaman_weight_builder','Build-ShamanAssets.py');B.OUT=OUT;B.WORK=WORK;B.resource_halos()
    assets={p.stem:{'sha256':L.sha(p),'canvas':list(Image.open(p).size)} for p in OUT.glob('*.tga')}
    assert len(assets)==8
    registration={'source':source.relative_to(ROOT).as_posix(),'sourceSha256':L.sha(source),
        'uniformScale':scale,'resizedCanvas':size,'offset':[x,y],'canvas':[256,128],
        'policy':'whole source own alpha at native density; uniform scale and translation only'}
    L.save(OUT/'manifest.json',{'status':'Authorized WIP live review; no production acceptance',
        'assets':assets,'crystalRegistration':registration,'liveValidated':False})
    proof={'schema':1,'assetManifestSha256':L.sha(OUT/'manifest.json'),
        'paintings':{name:{'role':'painting','source':{'path':registration['source'],'sha256':registration['sourceSha256']},'transform':transform} for name in OLD.NAMES[:2]}}
    L.save(OUT/'source-integrity.json',proof)
    P=module('shaman_weight_projection','PaladinFillContracts.py')
    measurements={}
    for label,file in [('native',ROOT/'Assets/pw_crystal_case.tga'),('previous',installed/'pw_crystal_case.tga'),('new',OUT/'pw_crystal_case.tga')]:
        im=Image.open(file).convert('RGBA');bbox=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
        measurements[label]={'normalizedBounds':[bbox[i]/(im.width/256 if i%2==0 else im.height/128) for i in range(4)],'canvas':im.size}
    measurements['wholeCrystalOpaqueOverlap']=P.crystal_overlap('pw_crystal_case',canvas.getchannel('A'))
    assert measurements['wholeCrystalOpaqueOverlap']<.2
    try: integrity={'passed':True,**I.verify_pack(OUT)}
    except ValueError as error: integrity={'passed':False,'failure':str(error),'wholeSourceReplayPassed':True}
    L.save(WORK/'source-check.json',integrity)
    L.save(WORK/'registration.json',registration);L.save(WORK/'measurements.json',measurements)
    L.save(WORK/'repair.json',{'before':prior['assets'],'after':assets,'registration':registration,
        'runtimeSnapshot':{name:L.sha(ROOT/name) for name in json.loads((L.WORK/'installed-integration.json').read_text())['files']},'liveValidated':False})
    render()
    print(json.dumps({'measurements':measurements,'sourceIntegrity':integrity},indent=2))

def render():
    R=module('shaman_weight_render','Render-ShamanAssets.py')
    P=module('shaman_weight_layouts','PaladinFillContracts.py')
    resources=[];health=[]
    for choice in ('OG','Previous','New'):
        r=R.Renderer();delegate=r.asset
        def asset(path,delegate=delegate,choice=choice):
            name=Path(path.replace('\\','/')).stem
            if name in OLD.NAMES[:2]:
                file=(ROOT/'Assets' if choice=='OG' else WORK/'Before' if choice=='Previous' else OUT)/(name+'.tga')
                return Image.open(file).convert('RGBA')
            return delegate(path)
        r.asset=asset
        for tier in ('Seasoned','Novice'):
            db=dict(P.LAYOUTS['PlayerFrame']);db.update(db[tier]);r.replace(db);r.config=lambda:db
            for fraction in (1,.5,0): resources.append((choice,tier,fraction,r.resource('crystal',fraction)))
        db=dict(P.LAYOUTS['PlayerFrame']);db.update(db['Seasoned']);r.replace(db);r.config=lambda:db
        health.append((choice,r.health(resource='crystal',fraction=.72)))
    box=Image.fromarray(np.maximum.reduce([np.asarray(row[3])[:,:,3] for row in resources])).getbbox()
    for scale in (1,2):
        w=(box[2]-box[0])*scale;h=(box[3]-box[1])*scale
        page=Image.new('RGBA',(3*(w+45),6*(h+40)+40),'#171b20');draw=ImageDraw.Draw(page)
        for i,(choice,tier,fraction,scene) in enumerate(resources):
            col=i//6;row=i%6;x=15+col*(w+45);y=15+row*(h+40)
            draw.text((x,y),choice+' / '+tier+' / '+str(round(fraction*100))+'%',fill='white')
            page.alpha_composite(scene.crop(box).resize((w,h),Image.Resampling.LANCZOS),(x,y+22))
        page.convert('RGB').save(WORK/('resource-comparison-'+str(scale)+'x.png'))
    box=Image.fromarray(np.maximum.reduce([np.asarray(row[1])[:,:,3] for row in health])).getbbox()
    for scale in (1,2):
        w=(box[2]-box[0])*scale;h=(box[3]-box[1])*scale
        page=Image.new('RGBA',(w+50,3*(h+50)+20),'#171b20');draw=ImageDraw.Draw(page)
        for i,(choice,scene) in enumerate(health):
            y=15+i*(h+50);draw.text((15,y),choice+' / SAME CRYSTAL, HUD AND VIEWPORT / OFFLINE',fill='white')
            page.alpha_composite(scene.crop(box).resize((w,h),Image.Resampling.LANCZOS),(15,y+22))
        page.convert('RGB').save(WORK/('health-comparison-'+str(scale)+'x.png'))

def install():
    record=json.loads((WORK/'repair.json').read_text());target=ROOT/'Assets/Shaman'
    for name,item in record['before'].items():
        assert L.sha(target/(name+'.tga'))==item['sha256'],'Installed art changed since retained comparison: '+name
    registration=record['registration'];original=Image.open(ROOT/registration['source']).convert('RGBA')
    assert L.sha(ROOT/registration['source'])==registration['sourceSha256']
    expected=I.whole_painting(original,{'scale':registration['uniformScale'],'offset':registration['offset']},(256,128))
    for name in OLD.NAMES[:2]: I.verify_pixels(expected,Image.open(OUT/(name+'.tga')).convert('RGBA'))
    for name,item in record['after'].items():
        path=OUT/(name+'.tga');assert L.sha(path)==item['sha256']
    manifest=json.loads((target/'manifest.json').read_text())
    for name,item in record['after'].items():
        path=OUT/(name+'.tga');shutil.copyfile(path,target/path.name);shutil.copyfile(path,L.OUT/path.name)
        manifest['assets'][name]=item
    manifest['sources'][registration['source']]=registration['sourceSha256']
    manifest['crystalRegistration']=registration
    manifest['crystal']='Heavier whole AI painting, native 256x128 density; WIP live review only'
    manifest['sourceApertureStatus']='Production gate fails at gripping horns; retained source-check.json; no bridge approval claimed'
    L.save(L.OUT/'manifest.json',manifest)
    L.save(target/'manifest.json',dict(manifest,runtimeInstalled=True,sourceManifestSha256=L.sha(L.OUT/'manifest.json')))
    L.verify_installed(record['runtimeSnapshot'])
    L.save(WORK/'installed.json',{'changedTextures':list(record['after']),'unchangedTextures':69,
        'runtimeSnapshot':record['runtimeSnapshot'],'mode':'Previously authorized WIP live preview',
        'productionAccepted':False,'liveValidated':False,'manifestSha256':L.sha(target/'manifest.json')})
    print('Installed native-density WIP cradle and halos; 69 other textures unchanged. Production aperture approval remains pending.')

if __name__=='__main__':
    if '--install' in sys.argv: install()
    elif '--render' in sys.argv: render()
    elif '--verify' in sys.argv: L.verify_installed(json.loads((WORK/'installed.json').read_text())['runtimeSnapshot'])
    else: prepare()
