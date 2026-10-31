"""Fit the retained AI contact-lip repair as one intact painting; no alpha stencil."""
from pathlib import Path
import json
import shutil
import importlib.util
import sys
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman/Crystal-Shape-2026-10-29'
OUT=ROOT/'Assets_Draft/Shaman/Crystal-Shape-2026-10-29'

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

L=module('shaman_shape_live','Install-ShamanLivePreview.py')
R=module('shaman_shape_previous','Repair-ShamanCrystalFit.py')

def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    before=WORK/'Before';before.mkdir(exist_ok=True)
    for p in (ROOT/'Assets/Shaman').glob('*.tga'): shutil.copyfile(p,OUT/p.name)
    for name in R.NAMES:
        p=ROOT/'Assets/Shaman'/(name+'.tga')
        if not (before/p.name).exists(): shutil.copyfile(p,before/p.name)
    prior=json.loads((ROOT/'Assets/Shaman/manifest.json').read_text())
    source=WORK/'holder-inner-fit.png';original=Image.open(source).convert('RGBA')
    bounds=original.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    # Original native painted width: 177 source pixels. Retain this envelope
    # using a SINGLE scale factor for the entire source canvas and its alpha.
    scale=177*8/(bounds[2]-bounds[0])
    size=(round(original.width*scale),round(original.height*scale))
    piece=original.resize(size,Image.Resampling.LANCZOS)
    b=piece.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    x=round(127.5*8-(b[0]+b[2])/2)
    centre=round(1024-x)
    column=np.asarray(piece)[:,centre,3];rail=int(np.flatnonzero(column>200)[0])
    y=65*8-rail
    canvas=Image.new('RGBA',(2048,1024));canvas.paste(piece,(x,y))
    visible=piece.getchannel('A').getbbox()
    placed=(visible[0]+x,visible[1]+y,visible[2]+x,visible[3]+y)
    assert min(placed)>=0 and placed[2]<=2048 and placed[3]<=1024
    assert canvas.crop(placed).tobytes()==piece.crop(visible).tobytes()
    registration={'source':source.relative_to(ROOT).as_posix(),'sourceSha256':L.sha(source),
        'uniformScale':scale,'resizedCanvas':size,'offset':[x,y],
        'policy':'whole painting and own alpha; one uniform scale; no stencil, crop, extrusion or aperture erasure'}
    H=module('shaman_shape_halos','Build-RebuiltHealthArt.py')
    for name in R.NAMES[:2]:
        canvas.save(OUT/(name+'.tga'),compression=None)
        assert Image.open(OUT/(name+'.tga')).convert('RGBA').tobytes()==canvas.tobytes()
        H.halo(canvas).save(OUT/(name+'-glow.tga'),compression=None)
    B=module('shaman_shape_builder','Build-ShamanAssets.py');B.OUT=OUT;B.WORK=WORK;B.resource_halos()
    manifest=json.loads((L.OUT/'manifest.json').read_text())
    for name in R.NAMES:
        p=OUT/(name+'.tga');manifest['assets'][name]={'sha256':L.sha(p),'canvas':list(Image.open(p).size)}
    manifest['sources'][registration['source']]=registration['sourceSha256']
    manifest['crystalRegistration']=registration
    manifest['crystal']='AI-corrected contact lips; whole-source uniform fit on native draw rectangle'
    L.save(OUT/'manifest.json',manifest)
    L.save(WORK/'registration.json',registration)
    L.save(WORK/'shape-repair.json',{'before':prior['assets'],'after':manifest['assets'],
        'runtimeSnapshot':{name:L.sha(ROOT/name) for name in json.loads((L.WORK/'installed-integration.json').read_text())['files']},
        'liveValidated':False})
    R.L.OUT=OUT;R.WORK=WORK;R.render()
    print(json.dumps(registration,indent=2))

def install():
    record=json.loads((WORK/'shape-repair.json').read_text());target=ROOT/'Assets/Shaman'
    for name,item in record['before'].items():
        assert L.sha(target/(name+'.tga'))==item['sha256'],'Installed art changed since build: '+name
        if name not in R.NAMES: assert item==record['after'][name]
    for name in R.NAMES:
        p=OUT/(name+'.tga');assert L.sha(p)==record['after'][name]['sha256'];shutil.copyfile(p,target/p.name)
        shutil.copyfile(p,L.OUT/p.name)
    manifest=json.loads((OUT/'manifest.json').read_text());shutil.copyfile(OUT/'manifest.json',L.OUT/'manifest.json')
    L.save(target/'manifest.json',dict(manifest,runtimeInstalled=True,sourceManifestSha256=L.sha(L.OUT/'manifest.json')))
    L.verify_installed(record['runtimeSnapshot'])
    L.save(WORK/'installed.json',{'changedTextures':list(R.NAMES),'unchangedTextures':69,
        'manifestSha256':L.sha(target/'manifest.json'),'runtimeSnapshot':record['runtimeSnapshot'],'liveValidated':False})
    print('AI-contact repair installed; all 77 hashes verified, 69 other textures unchanged.')

if __name__=='__main__':
    if '--install' in sys.argv: install()
    elif '--verify' in sys.argv: L.verify_installed(json.loads((WORK/'installed.json').read_text())['runtimeSnapshot'])
    else: prepare()
