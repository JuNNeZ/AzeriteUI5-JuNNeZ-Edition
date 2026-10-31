"""Prepare the maintainer-requested Shaman in-game WIP, without forging acceptance.

The intact crystal PNG is converted with transparent padding only. Tides/Lava
use retained diagnostic whole paintings; their production failures stay recorded.
The later whole-HUD Tides concept is not a functional separable texture.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman'
OUT=ROOT/'Assets_Draft/Shaman/Live-Preview'
REVIEW=WORK/'Live-Preview-2026-10-29'
# Native centre rail begins at y=65/128. The source rail begins at
# y=533/887; on the 8x canvas its offset is 65*8-533 = -13.
# Centring the PNG at y=68 leaves an 81-HD-pixel gap at the crystal base.
CRYSTAL_OFFSET=(137,-13)

def crystal_canvas(original):
    padded=Image.new('RGBA',(2048,1024));padded.paste(original,CRYSTAL_OFFSET)
    verify_crystal(padded,original)
    return padded

def verify_crystal(image,original):
    # Only empty transparent source margin may lie outside the canvas.
    # Preserve every nonzero-alpha source pixel, including faint edge AA.
    box=original.getchannel('A').getbbox();dx,dy=CRYSTAL_OFFSET
    placed=tuple(v+(dx if i%2==0 else dy) for i,v in enumerate(box))
    assert placed[0]>=0 and placed[1]>=0 and placed[2]<=image.width and placed[3]<=image.height
    assert image.crop(placed).tobytes()==original.crop(box).tobytes()
    column=image.getchannel('A').crop((1024,0,1025,1024))
    first=next(y for y,a in enumerate(column.getdata()) if a>200)
    assert first==65*8,'Crystal centre rail does not meet the native y=65 mounting line'

def registered_crystal(original,registration):
    piece=original.resize(tuple(registration['resizedCanvas']),Image.Resampling.LANCZOS)
    canvas_size=tuple(registration.get('canvas',[2048,1024]))
    x,y=registration['offset'];canvas=Image.new('RGBA',canvas_size);canvas.paste(piece,(x,y))
    box=piece.getchannel('A').getbbox();placed=(box[0]+x,box[1]+y,box[2]+x,box[3]+y)
    assert min(placed)>=0 and placed[2]<=canvas.width and placed[3]<=canvas.height
    assert canvas.crop(placed).tobytes()==piece.crop(box).tobytes()
    return canvas

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,data): path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def prepare():
    OUT.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)
    B=module('shaman_live_builder','Build-ShamanAssets.py')
    H=module('shaman_live_halos','Build-RebuiltHealthArt.py')
    fits={};sources={}
    for path in (ROOT/'Assets_Draft/Shaman').glob('*.tga'):
        shutil.copyfile(path,OUT/path.name)
    for choice in B.CHOICES:
        if choice=='maelstrom':
            fits[choice]=json.loads((WORK/'maelstrom-registration.json').read_text())
            continue
        fits[choice]={'accepted':False,'status':'Live review only; prior fit/visual rejection retained','fits':{}}
        for case in B.CASES:
            source=WORK/'Rejected'/(choice+'-'+case+'-unmodified-ai-diagnostic.png')
            paint=Image.open(source).convert('RGBA')
            assert paint.size==(1024,256)
            name='ornament-'+choice+'-'+case
            paint.save(OUT/(name+'.tga'),compression=None)
            H.halo(paint).save(OUT/(name+'-glow.tga'),compression=None)
            fits[choice]['fits'][case]={'bounds':paint.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()}
            sources[source.relative_to(ROOT).as_posix()]=sha(source)
    registration=None
    shape=WORK/'Crystal-Shape-2026-10-29'
    if (shape/'installed.json').exists():
        registration=json.loads((shape/'registration.json').read_text())
    weight=WORK/'Crystal-Weight-2026-10-30'
    if (weight/'installed.json').exists():
        registration=json.loads((weight/'registration.json').read_text())
    source=ROOT/registration['source'] if registration else WORK/'Sources/pw_crystal_case.png'
    original=Image.open(source).convert('RGBA')
    if registration: assert sha(source)==registration['sourceSha256']
    padded=registered_crystal(original,registration) if registration else crystal_canvas(original)
    for name in ('pw_crystal_case','pw_crystal_case_low'):
        path=OUT/(name+'.tga');padded.save(path,compression=None)
        reopened=Image.open(path).convert('RGBA')
        if registration: assert reopened.tobytes()==padded.tobytes()
        else: verify_crystal(reopened,original)
        H.halo(padded).save(OUT/(name+'-glow.tga'),compression=None)
    sources[source.relative_to(ROOT).as_posix()]=sha(source)
    # Generate whole-assembly neutral threat silhouettes from the actual new
    # high-density holder and the original shared crystal fills.
    B.OUT=OUT;B.WORK=REVIEW;B.resource_halos()
    assets={p.stem:{'sha256':sha(p),'canvas':list(Image.open(p).size)} for p in sorted(OUT.glob('*.tga'))}
    assert len(assets)==77,('incomplete live-review inventory',len(assets))
    manifest={'status':'Maintainer-requested in-game WIP; production acceptance pending',
              'assets':assets,'sources':sources,'healthEndcaps':fits,
              'crystal':'Lossless source pixels on transparent 2048x1024 canvas; original runtime draw rectangle',
              'integratedTidesStudyInstalled':False,'liveRetailValidated':False,'liveForeverValidated':False}
    if registration:
        manifest['crystalRegistration']=registration
        manifest['crystal']='AI-corrected contact lips; whole-source uniform fit on native draw rectangle'
        if registration.get('canvas')==[256,128]:
            manifest['crystal']='Heavier whole AI painting, native 256x128 density; WIP live review only'
            manifest['sourceApertureStatus']='Production gate fails at gripping horns; retained source-check.json; no bridge approval claimed'
    save(OUT/'manifest.json',manifest)
    return manifest,fits

def install(manifest):
    target=ROOT/'Assets/Shaman';target.mkdir(exist_ok=True)
    for name,item in manifest['assets'].items():
        source=OUT/(name+'.tga');assert sha(source)==item['sha256']
        dest=target/source.name
        assert not dest.exists() or sha(dest)==sha(source),'Different installed Shaman art requires explicit update'
        shutil.copyfile(source,dest);assert sha(dest)==item['sha256']
    save(target/'manifest.json',dict(manifest,runtimeInstalled=True,sourceManifestSha256=sha(OUT/'manifest.json')))

def render():
    R=module('shaman_live_renderer','Render-ShamanAssets.py')
    R.OUT=OUT;R.WORK=REVIEW
    R.main();R.cast_review()
    print('77 live-review assets prepared; intact crystal and all choices rendered. Not production acceptance.')

def verify_installed(runtime_snapshot=None):
    import re
    import xml.etree.ElementTree as ET
    manifest=json.loads((OUT/'manifest.json').read_text())
    target=ROOT/'Assets/Shaman'
    installed=json.loads((target/'manifest.json').read_text())
    assert installed['sourceManifestSha256']==sha(OUT/'manifest.json')
    assert set(installed['assets'])==set(manifest['assets'])
    for name,item in manifest['assets'].items():
        path=target/(name+'.tga')
        assert sha(path)==item['sha256'] and Image.open(path).size==tuple(item['canvas']),name
        header=path.read_bytes()[:18]
        assert header[2]==2 and header[16]==32,(name,'requires uncompressed 32-bit TGA')
    for name,digest in manifest['sources'].items(): assert sha(ROOT/name)==digest,name
    registration=manifest.get('crystalRegistration')
    source=ROOT/registration['source'] if registration else WORK/'Sources/pw_crystal_case.png'
    original=Image.open(source).convert('RGBA')
    if registration: assert sha(source)==registration['sourceSha256']
    for name in ('pw_crystal_case','pw_crystal_case_low'):
        image=Image.open(target/(name+'.tga')).convert('RGBA')
        if registration: assert image.tobytes()==registered_crystal(original,registration).tobytes()
        else: verify_crystal(image,original)
    scripts=[n.attrib['file'] for n in ET.parse(ROOT/'Core/Core.xml').getroot() if n.tag.endswith('Script')]
    assert scripts.count('ShamanTheme.lua')==1
    assert scripts.index('ThemeEngine.lua')<scripts.index('ShamanTheme.lua')<scripts.index('ThemeEffects.lua')
    lua=(ROOT/'Core/ShamanTheme.lua').read_text(encoding='utf-8')
    block=re.search(r'local capTextEdges = \{(.*?)\n\}',lua,re.S)[1]
    for key,item in manifest['healthEndcaps'].items():
        line=re.search(r'\b'+key+r' = \{(.*?)\}',block)[1]
        edges={case:int(edge) for case,edge in re.findall(r'(hp_\w+_case) = (\d+)',line)}
        assert edges=={case:fit['bounds'][0] for case,fit in item['fits'].items()}
    record=json.loads((WORK/'installed-integration.json').read_text())
    assert record['moduleSha256']==sha(ROOT/'Core/ShamanTheme.lua')
    if runtime_snapshot is not None:
        assert set(runtime_snapshot)==set(record['files'])
    drift={}
    for name,item in record['files'].items():
        current=sha(ROOT/name)
        assert current==(runtime_snapshot[name] if runtime_snapshot is not None else item['afterSha256']),name
        if current!=item['afterSha256']:
            drift[name]={'originalIntegrationSha256':item['afterSha256'],'currentSha256':current}
    assert not json.loads((WORK/'tides-registration.json').read_text())['accepted']
    assert not json.loads((WORK/'lava-registration.json').read_text())['accepted']
    save(REVIEW/'installed-verification.json',{'installedTextureHashes':77,'loadOrderVerified':True,
        'crystalSourcePixelsAndAlphaIdentical':not registration,'wholeCrystalSourceRegistrationVerified':True,
        'measuredTextEdgesVerified':True,
        'runtimeHashesVerified':not drift,'runtimeRepairSnapshotVerified':runtime_snapshot is not None,
        'historicalIntegrationRuntimeDrift':drift,'productionAcceptancePending':True,
        'liveRetailValidated':False,'liveForeverValidated':False})
    print('77 installed TGA hashes/headers, whole crystal painting registration, sources, load order, runtime hashes and twelve text edges verified.')

if __name__=='__main__':
    if '--verify' in sys.argv: verify_installed()
    else:
        prepare()
        if '--render' in sys.argv: render()
