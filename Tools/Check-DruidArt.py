"""Independent staging checks; --mutations falsifies geometry/layer guards.

python Tools/Check-DruidArt.py --mutations
No client/frame emulation. No production files are modified.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw
from PaladinFillContracts import clearance_mask

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Druid/HD'
OUT = WORK/'Export'
SPEC = json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def casing_contract(name,image):
    base = name.removesuffix('-over')
    assert image.size==tuple(SPEC[base]['canvas']), name+' canvas'
    if name.endswith('-over'):
        fill = np.asarray(clearance_mask(base,image.size))>0
        a = np.asarray(image)[:,:,3]
        assert not (a[fill]>200).any(), name+' opaque foreground inside native fill'


def guide_contract(image):
    native=Image.open(ROOT/'Assets/power_crystal_front.tga').convert('RGBA').getchannel('A')
    expected=native.resize((1024,1024),Image.Resampling.LANCZOS)
    assert np.array_equal(np.asarray(image),np.asarray(expected)), 'crystal guide must use full native silhouette, not legacy crop'


def crystal_contract(front,back):
    assert front.size==back.size==(256,256),'crystal layer canvas'
    mask = np.asarray(Image.open(WORK/'Guides/crystal-native-fill.png').resize(front.size,Image.Resampling.LANCZOS))>128
    coverage = ((np.asarray(front)[:,:,3]>200)&mask).sum()/mask.sum()
    assert coverage<.20,'crystal foreground coverage'
    return float(coverage)


def main(mutations=False):
    manifest = json.loads((WORK/'manifest.json').read_text())
    for name,entry in manifest['checks'].items():
        assert not entry['failures'], name+': '+str(entry['failures'])
        path = OUT/(name+'.tga')
        assert sha(path)==entry['sha256'],name+' export hash'
        if 'glow' in name or 'moonlight' in name:
            rgb=np.asarray(Image.open(path).convert('RGBA'))[:,:,:3]
            assert (rgb==255).all(),name+' effect pigment must remain runtime-tintable white'
        if name.removesuffix('-over') in SPEC:
            casing_contract(name,Image.open(path).convert('RGBA'))
    for name,entry in manifest['inventory'].items():
        assert sha(ROOT/name)==entry['sha256'],name+' original modified'
    front = Image.open(OUT/'crystal-roots-front.tga').convert('RGBA')
    back = Image.open(OUT/'crystal-roots-back.tga').convert('RGBA')
    coverage = crystal_contract(front,back)
    guide_contract(Image.open(WORK/'Guides/crystal-native-fill.png').convert('L'))
    proof = json.loads((WORK/'crystal-verification.json').read_text())
    assert proof['drawRect']==[0,0,196,196], 'native crystal resource rect changed'
    assert proof['layerUnionMatchesWholePainting']
    # Reconstruct from the retained source and recorded rigid fit without
    # calling the builder. Every painted root pixel must survive the split.
    source=Image.open(WORK/'Sources/crystal-root-cap.png').convert('RGBA')
    source.putalpha(source.getchannel('A').point(lambda a:0 if a<=8 else a))
    source=source.crop(source.getchannel('A').getbbox())
    source=source.resize(tuple(proof['fit']['size']),Image.Resampling.LANCZOS)
    expected=Image.new('RGBA',tuple(proof['hdCanvas']))
    expected.alpha_composite(source,tuple(proof['fit']['offset']))
    expected=expected.resize(tuple(proof['canvas']),Image.Resampling.LANCZOS)
    clean=np.array(expected);clean[clean[:,:,3]==0]=0;expected=Image.fromarray(clean)
    assert Image.alpha_composite(back,front).tobytes()==expected.tobytes(),'whole root painting lost or warped'
    bounds=expected.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    assert bounds[0]>=6 and bounds[1]>=6 and bounds[2]<=250 and bounds[3]<=250,'root halo lacks padding'
    for name in ('portrait_frame_hi','portrait_frame_lo'):
        fit=manifest['casings'][name]['registration']
        source=Image.open(WORK/'Sources/portrait_frame_hi.png').convert('RGBA')
        source.putalpha(source.getchannel('A').point(lambda a:0 if a<=8 else a))
        source=source.crop(source.getchannel('A').getbbox()).resize(tuple(fit['size']),Image.Resampling.LANCZOS)
        expected=Image.new('RGBA',(256,256))
        expected.alpha_composite(source,tuple(fit['offset']))
        original=np.asarray(expected)
        actual=np.asarray(Image.open(OUT/(name+'.tga')).convert('RGBA'))
        opaque=original[:,:,3]>200
        assert np.array_equal(actual[opaque],original[opaque]),name+' whole painted planes changed'
        assert np.array_equal(actual[:,:,3]>200,opaque),name+' silhouette stencilled'
    for name in ('actionbutton-border-square','actionbutton-border-square-rounded'):
        native=Image.open(ROOT/'Assets'/(name+'.tga')).getchannel('A')
        assert Image.open(OUT/(name+'.tga')).getchannel('A').tobytes()==native.tobytes(),name+' native corner radius'
    glow=Image.open(OUT/'crystal-assembly-glow.tga').convert('RGBA')
    rgb=np.asarray(glow)[:,:,:3]
    assert (rgb==255).all(),'threat halo must be neutral white'
    rejected=[]
    if mutations:
        def reject(label,fn):
            try: fn()
            except AssertionError: rejected.append(label)
            else: raise AssertionError('survived mutant: '+label)
        over=Image.open(OUT/'hp_cap_case-over.tga').convert('RGBA')
        reject('resized canvas',lambda:casing_contract('hp_cap_case-over',over.resize((512,256))))
        # Deliberately inject opaque art at a point inside the independently
        # loaded native fill. This must fail without relying on a hash mismatch.
        bad=over.copy()
        ImageDraw.Draw(bad).rectangle((450,110,460,120),fill=(80,70,40,255))
        reject('opaque rail over health',lambda:casing_contract('hp_cap_case-over',bad))
        bad=front.copy()
        bad.putalpha(Image.open(WORK/'Guides/crystal-native-fill.png').convert('L').resize(front.size,Image.Resampling.LANCZOS))
        reject('root cap covers crystal',lambda:crystal_contract(bad,back))
        native=Image.open(ROOT/'Assets/power_crystal_front.tga').convert('RGBA').getchannel('A')
        wrong=native.crop((50,37,206,219)).resize((1024,1024),Image.Resampling.LANCZOS)
        reject('legacy crop guide',lambda:guide_contract(wrong))
    result={'textures':len(manifest['checks']),'nativeCasings':len(manifest['casings']),
            'geometryFailures':0,'crystalFrontCoverage':coverage,
            'originalAssetsUnchanged':True,'mutationsRejected':rejected,
            'liveValidated':False}
    (WORK/'verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mutations',action='store_true')
    main(parser.parse_args().mutations)
