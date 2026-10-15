"""Independent installed-art contracts for the Paladin rebuild (offline only)."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
from PaladinFillContracts import clearance_mask, crystal_overlap

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT/'Assets'
THEME = ASSETS/'Paladin'
manifest = json.loads((THEME/'manifest.json').read_text())


def check_health_contour(name, actual):
    native = np.asarray(Image.open(ASSETS/(name+'.tga')).convert('RGBA'))
    mask = np.asarray(clearance_mask(name,actual.size)) > 0
    pixels = np.asarray(actual)
    assert not (pixels[:,:,3][mask]>200).any(), name+' opaque metal covers functional fill'
    original_box = Image.fromarray(native[:,:,3]).point(lambda a:255 if a>128 else 0).getbbox()
    box = actual.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    assert all(abs(box[i]-original_box[i]) <= (41 if i%2==0 else 10) for i in range(4)), name+' outside native footprint'
    # Three ordinary studs / five on boss: native identity slots, HD planes.
    solid = pixels[:,:,3]>200
    tops = np.where(solid.any(0),solid.argmax(0),actual.height)
    columns = np.flatnonzero(solid.any(0))
    lo,hi = columns[0]+65,columns[-1]-65
    baseline = np.median(tops[lo:hi])
    indices = np.flatnonzero((tops<baseline-5)&(np.arange(actual.width)>=lo)&(np.arange(actual.width)<hi))
    groups = np.split(indices,np.where(np.diff(indices)>1)[0]+1)
    assert len([g for g in groups if len(g)>4]) == (5 if name=='hp_boss_case' else 3), name+' stud identity/count changed'
    if name == 'hp_cap_case':
        # The supplied endcap-off screenshot exposes this native lower-right
        # drop. A flat concept rectangle leaves it black or completely absent.
        metal = pixels[173:179,747:758]
        opaque = metal[:,:,3]>200
        assert opaque.sum()>=10 and (metal[:,:,:3].max(2)[opaque]>35).mean()>.8, name+' dip lacks concept metal'


def check_portrait(name, actual):
    # Independent fixed landmarks on the exact painting approved in chat.
    source = Image.open(work/'Sources/HD/portrait.png').convert('RGBA').crop((139,17,1115,1222))
    native = Image.open(ASSETS/(name+'.tga')).convert('RGBA')
    bounds = native.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    height = bounds[3]-bounds[1]
    art = source.resize((round(source.width*height/source.height),height),Image.Resampling.LANCZOS)
    expected = Image.new('RGBA',native.size)
    expected.alpha_composite(art,(round((bounds[0]+bounds[2]-art.width)/2),bounds[1]))
    reference,pixels = np.asarray(expected),np.asarray(actual)
    metal = reference[:,:,3]>200
    assert metal.sum()>1000 and np.array_equal(reference[metal],pixels[metal]), name+' approved HD planes were resampled/warped/stencilled'
    assert np.array_equal(reference[:,:,3]>200,pixels[:,:,3]>200), name+' approved silhouette was replaced'
    # The live model remains open and native functional glass survives inside
    # the new opening, without old opaque metal or exterior glass fragments.
    hole = expected.getchannel('A').point(lambda a:255 if a>128 else 0)
    ImageDraw.floodfill(hole,(128,128),128)
    original = np.asarray(native)
    glass = (np.asarray(hole)==128)&(reference[:,:,3]==0)&(original[:,:,3]<=200)
    assert np.array_equal(pixels[glass],original[glass]), name+' native glass missing inside intact aperture'


def check_cast_spike(plain, spiked):
    assert plain.shape == spiked.shape == (512,1024,4), 'castbar still uses a low-resolution runtime texture'
    density = 4
    outside_spike = np.ones(plain.shape[:2],dtype=bool)
    outside_spike[23*density:58*density,108*density:143*density] = False
    assert np.array_equal(plain[outside_spike],spiked[outside_spike]), 'protected cast changes ordinary rails outside spike'
    tip = spiked[31*density:48*density,116*density:135*density]
    metal = tip[:,:,3]>200
    gold = metal & (tip[:,:,0]>90) & (tip[:,:,0].astype(float)>tip[:,:,2]*1.3)
    assert gold.sum()>30*density*density, 'protected cast spike is only the old dark shadow, missing painted Paladin metal'


assert not manifest['missingSources'], 'incomplete source manifest'
casings = 0
for name, entry in manifest['textures'].items():
    target = THEME/(name+'.tga')
    assert hashlib.sha256(target.read_bytes()).hexdigest() == entry['sha256'], name+' installed hash'
    original = ASSETS/(name+'.tga')
    density = manifest.get('hdDensity',{}).get(name,1)
    if name.removesuffix('-over') in ('cast_back','cast_back_spiked'):
        assert density==4 and Image.open(target).size==(1024,512), name+' HD runtime density missing'
    if original.exists():
        actual = Image.open(target).convert('RGBA')
        native = Image.open(original).convert('RGBA')
        assert actual.size == tuple(v*density for v in native.size), name+' canvas/density'
        if name not in ('pw_crystal_case', 'pw_crystal_case_low','portrait_frame_hi','portrait_frame_lo',
                        'hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case','cast_back','cast_back_spiked'):
            assert actual.getchannel('A').tobytes() == native.getchannel('A').tobytes(), name+' alpha'
        casings += 1
assert casings == 34, 'native casing coverage'
check_cast_spike(np.asarray(Image.open(THEME/'cast_back-over.tga').convert('RGBA')),
                 np.asarray(Image.open(THEME/'cast_back_spiked-over.tga').convert('RGBA')))
for name, entry in manifest['inventory'].items():
    assert hashlib.sha256((ASSETS/(name+'.tga')).read_bytes()).hexdigest() == entry['originalSha256'], name+' shared root changed'
for target in THEME.glob('*-over.tga'):
    base = target.stem[:-5].removesuffix('-capped')
    mask = np.asarray(clearance_mask(base,Image.open(target).size)) > 0
    alpha = np.asarray(Image.open(target).convert('RGBA'))[:, :, 3]
    assert not (alpha[mask] > 200).any(), target.stem+' covers fill'
    if base in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case') and '-capped' not in target.stem:
        check_health_contour(base,Image.open(target).convert('RGBA'))
for name in ('pw_crystal_case', 'pw_crystal_case_low'):
    actual = Image.open(THEME/(name+'-front.tga')).convert('RGBA')
    native = Image.open(ASSETS/(name+'.tga')).convert('RGBA')
    source = Image.open(ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Sources'/(name+'.png')).convert('RGBA')
    def painted(im):
        return im.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
    box, limit, src = painted(actual), painted(native), painted(source)
    assert actual.size == native.size, name+' native canvas'
    assert box and box[2]-box[0] <= limit[2]-limit[0], name+' wider than native'
    assert box[0] >= limit[0] and box[2] <= limit[2], name+' outside native width'
    assert box[1] >= 0 and box[3] <= native.height, name+' clipped concept holder'
    ratio = (box[2]-box[0])/(box[3]-box[1])
    source_ratio = (src[2]-src[0])/(src[3]-src[1])
    assert abs(ratio/source_ratio-1) < .025, name+' aspect ratio changed'
    base = Image.open(THEME/(name+'.tga')).convert('RGBA')
    assert base.tobytes() == actual.tobytes(), name+' holder was cut by native stencil'
    mask = np.asarray(clearance_mask(name, actual.size)) > 0
    alpha = np.asarray(actual)[:, :, 3]
    assert crystal_overlap(name, actual.getchannel('A')) < .20, name+' foreground hides too much crystal'
    assert not alpha[30:40, 115:140].any(), name+' cavity is not transparent'
measured = manifest['measuredCrystal']
work = ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14'
approved_portrait = json.loads((work/'Whole-Asset-Repair/approved-portrait-lock.json').read_text())
assert hashlib.sha256((work/approved_portrait['source']).read_bytes()).hexdigest() == approved_portrait['sha256'], 'approved portrait source replaced'
assert hashlib.sha256((work/measured['reference']).read_bytes()).hexdigest() == measured['referenceSha256']
cutout = (work/measured['cutout']).read_bytes()
assert hashlib.sha256(cutout).hexdigest() == measured['cutoutSha256']
for file, sha in json.loads((work/'approved-crystal-lock.json').read_text()).items():
    if '-v' in Path(file).stem:
        assert not (ROOT/file).exists(), 'obsolete candidate retained: '+file
        continue
    assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest() == sha, 'approved crystal changed: '+file
frames = manifest['conceptFrames']
assert hashlib.sha256((work/frames['reference']).read_bytes()).hexdigest() == frames['referenceSha256']
assert hashlib.sha256((ROOT/frames['recipe']).read_bytes()).hexdigest() == frames['recipeSha256']
for file, sha in frames['parts'].items():
    assert hashlib.sha256((work/'Concept-Frames'/file).read_bytes()).hexdigest() == sha, 'concept part '+file
for file, entry in manifest['hdSources'].items():
    source = work/'Sources/HD'/file
    assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['sha256'], 'HD source '+file
    size = Image.open(source).size
    assert max(size)>=1024 and min(size)>=512, 'small source used for HD art: '+file
for file,minimum in (('cast-rails.png',(1000,150)),('cast-head-libram.png',(500,900))):
    source = Image.open(work/'Sources/HD'/file).convert('RGBA')
    box = source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    assert box[2]-box[0]>=minimum[0] and box[3]-box[1]>=minimum[1], file+' production art still comes from a small concept crop'
for name in ('portrait_frame_hi','portrait_frame_lo'):
    check_portrait(name,Image.open(THEME/(name+'.tga')).convert('RGBA'))
for name in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case'):
    bare = np.asarray(Image.open(THEME/(name+'-over.tga')).convert('RGBA'))
    capped = np.asarray(Image.open(THEME/(name+'-capped-over.tga')).convert('RGBA'))
    mask = np.asarray(clearance_mask(name,(bare.shape[1],bare.shape[0])))>0
    assert np.array_equal(bare[mask],capped[mask]), name+' mounting shoulder changed health clearance/glass'
    assert (bare[:,:,3]>capped[:,:,3]).sum()>20, name+' capped terminal still exposes the bare dip'
for name in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case',
             'hp_cap_case-capped','hp_mid_case-capped','hp_low_case-capped','hp_boss_case-capped',
             'portrait_frame_hi','portrait_frame_lo','ornament-ashbringer'):
    front = THEME/(name+('-over' if name.startswith('hp_') else '')+'.tga')
    image = Image.open(front).convert('RGBA')
    glow = Image.open(THEME/(name+'-glow.tga')).convert('RGBA')
    assert glow.size == image.size, name+' outline canvas'
    opaque = image.getchannel('A').point(lambda a:255 if a>128 else 0)
    ImageDraw.floodfill(opaque,(0,0),128)
    closed = opaque.point(lambda a:0 if a==128 else 255)
    ga = np.asarray(glow)[:,:,3]
    assert not ga[np.asarray(closed)>0].any(), name+' outline crosses the interior'
    assert not ga[np.asarray(closed.filter(ImageFilter.MaxFilter(21)))==0].any(), name+' outline is detached'
    near = (np.asarray(closed.filter(ImageFilter.MaxFilter(5)))>0)&(np.asarray(closed)==0)
    assert (ga[near]>8).mean()>.95, name+' outline misses its actual silhouette'
    assert (np.asarray(glow)[:,:,:3][ga>0]==255).all(), name+' outline is not neutral white'
assert 'cradleVariants' not in manifest, 'obsolete variants still in manifest'
native = np.asarray(Image.open(ASSETS/'icon_exit_flight.tga').convert('RGBA'))
actual = np.asarray(Image.open(THEME/'icon_exit_flight.tga').convert('RGBA'))
arrow = (native[:, :, 0] > native[:, :, 1]*1.4) & (native[:, :, 0] > 45)
assert np.array_equal(native[arrow], actual[arrow]), 'semantic exit arrow changed'
# Approved shared box is 88px, centred 14px beyond a 40px healthbar.
# The last six pixels of health at centre height must sit behind opaque metal,
# not beside a floating badge. Mirroring the texture/anchor gives the target
# exactly the same overlap without modifying either fill contour.
endcap = np.asarray(Image.open(THEME/'ornament-ashbringer.tga').convert('RGBA'))[:, :, 3]
x0 = round((.5+(-6-14)/88)*256)
x1 = round((.5-14/88)*256)
assert (endcap[120:136, x0:x1+1] > 200).all(), 'endcap does not cover health termination'
print('Paladin installed art: hashes, 24 exact native casing alphas, 4x HD cast layers, painted protected cast spike, intact approved portrait planes/silhouette/glass, HD rail clearance/dip/paired terminals, crystal lock, shared root and exterior threat passed (offline only).')
