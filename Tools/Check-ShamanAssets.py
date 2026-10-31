"""Validate actual Shaman exports; offline geometry is not live-client evidence."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil
import numpy as np
from PIL import Image, ImageFilter
from ThemeHealthEndcaps import align, lowest_point, terminal_coverage

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman'
OUT=ROOT/'Assets_Draft/Shaman'

def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def data(path): return json.loads(path.read_text(encoding='utf-8'))
def image(path): return Image.open(path).convert('RGBA')
def save(path,value): path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')

def inside(bounds,limit):
    return bounds[0]>=limit[0] and bounds[1]>=limit[1] and bounds[2]<=limit[2] and bounds[3]<=limit[3]

def check():
    B=load('shaman_builder_check','Build-ShamanAssets.py');C=load('shaman_style_check','Check-ThemeAssetStyle.py')
    contract=B.contract();manifest=data(OUT/'manifest.json')
    assert manifest['contractSha256']==sha(WORK/'contract.json')
    assert len(manifest['assets'])==77
    assert set(manifest['casings'])==set(C.SPEC)-set(B.SHARED)
    for name,item in manifest['assets'].items():
        path=OUT/(name+'.tga');assert sha(path)==item['sha256'],name
        assert list(Image.open(path).size)==item['canvas'],name
        assert not C.check(path)[0],(name,C.check(path)[0])
    for name,digest in manifest['sources'].items(): assert sha(WORK/name)==digest,name
    fits={}
    for choice in B.CHOICES:
        for case in B.CASES:
            cap=image(OUT/('ornament-'+choice+'-'+case+'.tga'));front=image(OUT/(case+'-over.tga'))
            item=contract['health'][case];required=np.asarray(Image.open(ROOT/item['terminalMask']))>128
            opaque=np.asarray(cap)[:,:,3]>=240
            expanded=np.asarray(Image.fromarray(opaque.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
            registration=manifest['healthEndcaps'][choice]
            approved,specific=B.approved_exposure(choice,case,B.SOURCE/registration['source'])
            expected=np.asarray(approved)>128 if approved is not None else np.zeros_like(required)
            assert np.array_equal(required&~expanded,expected),(choice,case,'terminal differs from exact approved mask')
            assert np.array_equal(np.fliplr(required)&~np.fliplr(expanded),np.fliplr(expected)),(choice,case,'mirror terminal differs')
            x,y=lowest_point(cap);dx,dy=item['dip'];assert abs(x-dx)<=.5 and y==dy
            bounds=cap.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
            assert inside(bounds,item['approvedEnvelope']),(choice,case,'oversized')
            fill=np.asarray(Image.open(B.TEMPLATES/(case+'-fill.png')).convert('L'))>128
            native=np.asarray(image(ROOT/'Assets'/(case+'.tga')))[:,:,3]
            protected_rail=(native>200)&~fill
            assert np.array_equal(np.asarray(front)[:,:,3][protected_rail],native[protected_rail]),(case,'foreground rail erased')
            combined=float((((np.asarray(cap)[:,:,3]>200)|(np.asarray(front)[:,:,3]>200))&fill).sum()/fill.sum())
            assert combined<=.20
            fits[choice+'/'+case]={'exposedTerminalPixels':int(expected.sum()),'unapprovedTerminalPixels':0,'dipError':abs(x-dx),'combinedFillOcclusion':combined,'bounds':bounds}
    # The approval is a locked pixel pattern, never a numeric allowance. A
    # one-pixel change to the approved mask must fail the shared registrar.
    for case in ('hp_mid_case','hp_low_case'):
        cap=image(OUT/('ornament-maelstrom-'+case+'.tga'));front=image(OUT/(case+'-over.tga'))
        expected,specific=B.approved_exposure('maelstrom',case,B.SOURCE/manifest['healthEndcaps']['maelstrom']['source'])
        bounds=cap.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
        fill=Image.open(B.TEMPLATES/(case+'-fill.png')).convert('L')
        align(cap,front,bounds[3]-bounds[1],fill,approved_terminal_exposure=expected)
        wrong=expected.copy();point=tuple(specific['sourcePixelCoordinates'][0]);wrong.putpixel(point,0)
        try:
            align(cap,front,bounds[3]-bounds[1],fill,approved_terminal_exposure=wrong)
        except AssertionError: pass
        else: raise AssertionError('Changed exception mask was accepted: '+case)
    P=load('shaman_projection_check','PaladinFillContracts.py');cast=data(WORK/'cast-contract.json')
    head=image(OUT/'cast-head.tga');bounds=head.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    assert abs((bounds[1]+bounds[3])/2-128)<=.5
    def socket_exposure(paint):
        cover=np.asarray(P.project(paint.getchannel('A'),cast['slotDrawRect'],(0,0,256,128),(1024,512)))>=240
        aa=np.asarray(Image.fromarray(cover.astype('uint8')*255).filter(ImageFilter.MaxFilter(7)))>0
        result={}
        for case,item in cast['cases'].items():
            assert sha(ROOT/item['socketMask'])==item['socketMaskSha256']
            required=np.asarray(P.project(Image.open(ROOT/item['socketMask']).convert('L'),item['casingDrawRect'],(0,0,256,128),(1024,512)))>128
            result[case]=int((required&~aa).sum())
        return result
    sockets=socket_exposure(head);assert not any(sockets.values())
    # Persist fixtures that must fail the same production constraints.
    cap=image(OUT/'ornament-maelstrom-hp_cap_case.tga');front=image(OUT/'hp_cap_case-over.tga')
    broken=np.array(cap);broken[70:150,730:800,3]=0
    fixture=Image.fromarray(broken);fixture.save(WORK/'Rejected/toe-correct-upper-body-cutout.png')
    assert lowest_point(fixture)==lowest_point(cap)
    assert terminal_coverage(front,fixture)['exposedTerminalPixelsBeyondAA']>0
    item=contract['health']['hp_cap_case'];big=cap.resize((1536,384),Image.Resampling.LANCZOS)
    bigger=Image.new('RGBA',cap.size);bigger.alpha_composite(big,(-round(item['dip'][0]*.5),-round(item['dip'][1]*.5)))
    bigger.save(WORK/'Rejected/oversized-cap.png')
    assert not inside(bigger.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox(),item['approvedEnvelope'])
    low=Image.new('RGBA',head.size);low.alpha_composite(head,(0,35));low.save(WORK/'Rejected/low-painted-cast.png')
    assert any(socket_exposure(low).values())
    # The same protected-rail assertion rejects a stripped foreground fixture.
    damaged=np.array(front);damaged[60:100,220:720,3]=0
    Image.fromarray(damaged).save(WORK/'Rejected/erased-foreground-rail.png')
    native=np.asarray(image(ROOT/'Assets/hp_cap_case.tga'))[:,:,3]
    fill=np.asarray(Image.open(B.TEMPLATES/'hp_cap_case-fill.png').convert('L'))>128
    protected_rail=(native>200)&~fill
    assert not np.array_equal(damaged[:,:,3][protected_rail],native[protected_rail])
    result={'assetManifestSha256':sha(OUT/'manifest.json'),'textures':77,'healthFits':fits,'castExposedPixelsAtDefaultSlot':sockets,
            'rejectedFixtureCases':4,'geometryFailures':0,'unapprovedTerminalPixels':0,'approvedTerminalPixels':11,'passed':True,'liveRetailValidated':False,'liveForeverValidated':False}
    save(WORK/'acceptance.json',result)
    print('Shaman: 77 textures, 12 bounded health fits with exact 4/7-pixel approval, both cast sockets, source hashes and rejection fixtures passed.')
    return manifest

REVIEW_IMAGES=('Shaman-asset-sheet.png','Shaman-endcaps-1x.png','Shaman-maelstrom-2x.png','Shaman-tides-2x.png',
              'Shaman-lava-2x.png','Shaman-health-tiers.png','Shaman-custom-placement.png','Shaman-small-art-detail.png','Shaman-cast-defaults.png')

def verify_review():
    review=data(WORK/'visual-review.json')
    assert review['assetManifestSha256']==sha(OUT/'manifest.json')
    assert review['agentOfflineVisualReviewPassed'] is True
    assert set(review['images'])==set(REVIEW_IMAGES)
    for name,digest in review['images'].items(): assert sha(WORK/name)==digest,'Stale review: '+name

def install(manifest):
    from ThemeSourceIntegrity import require_production
    require_production(OUT)
    verify_review();target=ROOT/'Assets/Shaman';target.mkdir(exist_ok=True)
    for name,item in manifest['assets'].items():
        dest=target/(name+'.tga')
        if dest.exists(): assert sha(dest)==item['sha256'],'Refusing different installed painting: '+name
        shutil.copyfile(OUT/(name+'.tga'),dest);assert sha(dest)==item['sha256']
    installed=dict(manifest,runtimeInstalled=True,sourceManifestSha256=sha(OUT/'manifest.json'),status='Installed WIP; live Retail and Forever checks pending')
    for name,item in installed['assets'].items(): item['path']='Assets/Shaman/'+name+'.tga'
    save(target/'manifest.json',installed)
    print('Installed 77 reviewed, byte-verified Shaman textures. Runtime integration/live testing tracked separately.')

def check_installed():
    import re
    import xml.etree.ElementTree as ET
    verify_review();staged=data(OUT/'manifest.json');installed=data(ROOT/'Assets/Shaman/manifest.json')
    assert installed['sourceManifestSha256']==sha(OUT/'manifest.json') and installed['runtimeInstalled']
    assert set(installed['assets'])==set(staged['assets'])
    for name,item in installed['assets'].items():
        path=ROOT/item['path'];assert path.parent==ROOT/'Assets/Shaman'
        assert sha(path)==item['sha256']==staged['assets'][name]['sha256']
    runtime=data(WORK/'installed-integration.json')
    assert runtime['moduleSha256']==sha(ROOT/'Core/ShamanTheme.lua')
    for name,item in runtime['files'].items(): assert sha(ROOT/name)==item['afterSha256'],'Integration changed after verification: '+name
    tree=ET.parse(ROOT/'Core/Core.xml');scripts=[node.attrib['file'] for node in tree.getroot() if node.tag.endswith('Script')]
    assert scripts.count('ShamanTheme.lua')==1
    assert scripts.index('ThemeEngine.lua')<scripts.index('ShamanTheme.lua')<scripts.index('ThemeEffects.lua')
    lua=(ROOT/'Core/ShamanTheme.lua').read_text(encoding='utf-8')
    block=re.search(r'local capTextEdges = \{(.*?)\n\}',lua,re.S)[1]
    for choice,item in staged['healthEndcaps'].items():
        line=re.search(r'\b'+choice+r' = \{(.*?)\}',block)[1]
        edges={key:int(value) for key,value in re.findall(r'(hp_\w+_case) = (\d+)',line)}
        assert edges=={key:fit['bounds'][0] for key,fit in item['fits'].items()},'Painted text clearance differs: '+choice
    save(WORK/'installed-verification.json',{'installedTextureHashes':77,'loadOrderVerified':True,'measuredTextEdgesVerified':True,
          'runtimeHashesVerified':True,'passed':True,'liveRetailValidated':False,'liveForeverValidated':False})
    print('Installed Shaman: all 77 hashes, exact-once load order, runtime hashes and measured text edges verified.')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--install',action='store_true');parser.add_argument('--installed',action='store_true');args=parser.parse_args()
    manifest=check()
    if args.install: install(manifest)
    if args.installed: check_installed()
