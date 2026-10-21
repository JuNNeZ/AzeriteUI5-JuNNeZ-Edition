"""Independent exported-file acceptance for the Warrior asset pack; offline only."""
from pathlib import Path
import hashlib
import importlib.util
import json
import numpy as np
from PIL import Image, ImageFilter
from ThemeHealthEndcaps import align, terminal_coverage

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Warrior'
OUT = ROOT/'Assets_Draft/Warrior'
manifest = json.loads((OUT/'manifest.json').read_text())
material = None
if manifest.get('materialRevision'):
    spec = importlib.util.spec_from_file_location('warrior_material_export',ROOT/'Tools/Refine-WarriorMaterials.py')
    material = importlib.util.module_from_spec(spec);spec.loader.exec_module(material)
revision = None
if manifest.get('fitRevision'):
    spec = importlib.util.spec_from_file_location('warrior_revision',ROOT/'Tools/Repair-WarriorFit.py')
    R = importlib.util.module_from_spec(spec);spec.loader.exec_module(R)
    revision = R.verify()
spec = importlib.util.spec_from_file_location('warrior_acceptance',ROOT/'Tools/Check-ThemeAssetStyle.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)
checks = 0


def check(value, label):
    global checks
    checks += 1
    assert value, label


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixels(path):
    return np.asarray(Image.open(path).convert('RGBA'))


def point(p):
    mask = p[:,:,3] > 128
    y = int(np.flatnonzero(mask.any(1))[-1])
    return float(np.median(np.flatnonzero(mask[y]))), y


spec = importlib.util.spec_from_file_location('warrior_authorized_edits',ROOT/'Tools/Install-WarriorAssets.py')
installer = importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)
for relative,digest in json.loads((WORK/'protected-files.json').read_text()).items():
    if (ROOT/'Core/WarriorTheme.lua').exists() and relative in installer.AUTHORIZED:
        continue # Explicitly authorized runtime integration, checked separately.
    check(sha(ROOT/relative)==digest,'protected native/theme/runtime file '+relative)
for name,digest in json.loads((WORK/'Terminal-Repair/before-assets.json').read_text()).items():
    if revision and (name in ('cast-head.tga','cast-head-glow.tga') or any(name==case+suffix+'.tga' for case in R.CASES for suffix in ('-over','-glow'))):
        continue # Revision verifies exact bridge-only changes against the old lock.
    if not name.startswith('ornament-'):
        check(sha(OUT/name)==digest or (material and material.approved_change(OUT/name,digest)),'unrelated Warrior texture or verified material-only repaint '+name)
check(not manifest['runtimeInstalled'] and not manifest['liveValidated'],'honest asset-only status')
for name,item in manifest['sources'].items():
    check(sha(WORK/'Sources'/name)==item['sha256'],'retained source '+name)
check(sha(ROOT/manifest['concept'])==manifest['conceptSha256'],'approved concept retained')
check(set(manifest['casings']) | set(manifest['shared']) == set(C.SPEC),'every native casing has a disposition')
for name,item in manifest['assets'].items():
    path = ROOT/item['path']
    image = Image.open(path).convert('RGBA')
    p = np.asarray(image)
    check(sha(path)==item['sha256'],'export hash '+name)
    check(list(image.size)==item['canvas'],'export canvas '+name)
    check(not C.check(path)[0],'current style/geometry '+name)
    if name.endswith('-glow'):
        check(np.array_equal(p[:,:,0],p[:,:,1]) and np.array_equal(p[:,:,1],p[:,:,2]),'neutral halo '+name)
        check(np.all(p[p[:,:,3]>0,:3]==255),'pure white halo '+name)
for name in ('orb_case_hi','orb_case_low'):
    p = pixels(OUT/(name+'.tga'))
    native = pixels(ROOT/'Assets'/(name+'.tga')).copy()
    mask = np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L'))>0
    native[mask,:3] = np.rint(native[mask,:3].astype(float)*192/255).astype('uint8')
    check(np.array_equal(p[mask],native[mask]),'native glass including opaque specular '+name)
for name in ('actionbutton-border-square','actionbutton-border-square-rounded','border-tooltip','border-aura','better-blizzard-border-small-alternate'):
    check(np.array_equal(pixels(OUT/(name+'.tga'))[:,:,3],pixels(ROOT/'Assets'/(name+'.tga'))[:,:,3]),'exact corner/cell alpha '+name)
for name,contract in manifest['resourceHaloContracts'].items():
    p = pixels(OUT/(name+'.tga'))
    # A cradle-only halo leaves no contour near the tall crystal's top.
    check(np.any(p[80:210,:,3]>32),'halo includes upper crystal '+name)
    check(not np.any(p[[0,-1],:,3]>8) and not np.any(p[:,[0,-1],3]>8),'resource halo has transparent padding '+name)

layouts = json.loads((ROOT/'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json').read_text())['original']
cases = {'Novice':'hp_low_case','Hardened':'hp_mid_case','Seasoned':'hp_cap_case','Boss':'hp_boss_case'}
mask_lock = json.loads((WORK/'Terminal-Repair/mask-lock.json').read_text())
views = []
for tier,name in cases.items():
    front = pixels(OUT/(name+'-over.tga'))
    native = pixels(ROOT/'Assets'/(name+'.tga'))
    mask = np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L'))>128
    bridge=np.asarray(Image.open(R.WORK/'Masks'/(name+'-straps.png')).convert('L'))>0 if revision else np.zeros(mask.shape,dtype=bool)
    check(np.all(front[mask&~bridge,3]<=200),'functional health contour clear outside explicit foreground bridges '+name)
    required_path=ROOT/mask_lock[name]['path']
    check(sha(required_path)==mask_lock[name]['sha256'],'terminal mask frozen before fitting '+name)
    if not revision:
        check(sha(OUT/(name+'-over.tga'))==mask_lock[name]['casingSha256'],'full bare terminal retained '+name)
    required_canonical=np.asarray(Image.open(required_path).convert('L'))>0
    for key in ('stromkar','warswords','wrath'):
        cap = pixels(OUT/('ornament-'+key+'-'+name+'.tga'))
        coverage = float(((cap[:,:,3]>200)&mask).sum()/mask.sum())
        check(coverage<=.20,'cap coverage '+key+'/'+name)
        for flip in (False,True):
            f = front[:,::-1] if flip else front
            c = cap[:,::-1] if flip else cap
            tx,ty = point(f)
            px,py = point(c)
            check(abs(px-tx)<=.5 and py==ty,'whole cap meets bare dip '+key+'/'+name)
            check(not np.any(c[ty+1:,:,3]>128),'no adjacent lower point '+key+'/'+name)
            check(np.any((c[ty,:,3]>128)&(f[ty,:,3]>128)),'shared opaque toe '+key+'/'+name)
            # Independently reconstruct the whole terminal after mirroring.
            # Matching only the bottom point was the original false positive.
            required = required_canonical[:,::-1] if flip else required_canonical
            cover = c[:,:,3]>=240
            aa_cover = np.asarray(Image.fromarray(cover.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
            exposed = int((required & ~aa_cover).sum())
            check(exposed==0,'whole upper point, terminal and dip covered '+key+'/'+name+'/'+str(flip))
            unit = 'TargetFrame' if flip else 'PlayerFrame'
            base = layouts[unit]
            if tier not in base:
                continue
            db = dict(base)
            db.update(base[tier])
            # Three display scales, with the artwork sharing the same native
            # backdrop rectangle. No claim about a not-yet-built Lua theme.
            for scale in (.75,1,1.5):
                error = abs(px-tx)*db['HealthBackdropSize'][0]/front.shape[1]*scale
                check(error<=.75,'half-texel join at native/custom display scale')
                views.append({'choice':key,'case':name,'unit':unit,'displayScale':scale,'layoutUnitError':error,'fillCovered':coverage,
                              'exposedTerminalPixelsBeyondAA':exposed})

# Mutation checks: an independently shifted cap and a second lower point must
# fail the exported-file join conditions, rather than silently pass the audit.
front = pixels(OUT/'hp_cap_case-over.tga')
cap = pixels(OUT/'ornament-stromkar-hp_cap_case.tga').copy()
tx,ty = point(front)
shifted = np.roll(cap,3,axis=0)
check(point(shifted)[1]!=ty,'reject cap shifted down three source pixels')
cap[ty+3,round(tx)+9] = [255,255,255,255]
check(point(cap)[1]!=ty,'reject extra neighbouring lower point')
bad_source = Image.fromarray(pixels(OUT/'ornament-stromkar-hp_cap_case.tga').copy())
bad_pixels = np.array(bad_source)
bad_pixels[ty-3:ty+1,round(tx)+20:round(tx)+24] = [255,255,255,255]
try:
    align(Image.fromarray(bad_pixels),Image.fromarray(front),116,Image.new('L',(1024,256)))
except AssertionError as error:
    check('two adjacent lower tips' in str(error),'reject two equally low tips before fitting')
else:
    check(False,'two-tip source was accepted')
# Every rejected old export must fail the new gate although its toe still fits.
before = WORK/'Terminal-Repair/Before'
for old in sorted(before.glob('ornament-*.tga')):
    if old.stem.endswith('-glow'):
        continue
    name = next(case for case in cases.values() if old.stem.endswith(case))
    old_cap = Image.open(old).convert('RGBA')
    casing = Image.open(OUT/(name+'-over.tga')).convert('RGBA')
    ox,oy=point(np.asarray(old_cap))
    tx,ty=point(np.asarray(casing))
    check(abs(ox-tx)<=.5 and oy==ty,'old incomplete fixture still has a correct toe '+old.name)
    check(terminal_coverage(casing,old_cap)['exposedTerminalPixelsBeyondAA']>0,'reject previously passing incomplete cap '+old.name)
hole = pixels(OUT/'ornament-stromkar-hp_cap_case.tga').copy()
front = pixels(OUT/'hp_cap_case-over.tga')
tx,ty = point(front)
ys,xs = np.where((front[:,:,3]>128)&(np.indices(front.shape[:2])[1]>=int(np.floor(tx))))
y,x = int(ys[0]),int(xs[0])
hole[max(0,y-4):y+6,max(0,x-4):x+6,3] = 0
check(point(hole)[1]==ty,'upper-gap mutant retains its toe')
check(terminal_coverage(Image.fromarray(front),Image.fromarray(hole))['exposedTerminalPixelsBeyondAA']>0,'reject upper terminal hole despite perfect toe')
report = {'checks':checks,'nativeAndScaledViews':len(views),'geometryFailures':0,
          'assetManifestSha256':sha(OUT/'manifest.json'),
          'maxLayoutUnitError':max(v['layoutUnitError'] for v in views),
          'maxFillCovered':max(v['fillCovered'] for v in views),
          'maxExposedTerminalPixelsBeyondAA':max(v['exposedTerminalPixelsBeyondAA'] for v in views),
          'terminalCoverageGate':'whole terminal, including upper point and dip; one source-pixel contour AA only',
          'runtimeInstalled':False,'liveValidated':False,'views':views}
if revision:
    report['liveFeedbackRevision']=revision
    report['checks']+=revision['checks']
    report['maxFillCovered']=max(report['maxFillCovered'],revision['maxFillCovered'])
(WORK/'acceptance.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if revision:
    historical=R.WORK/'Before/verification.json'
    if not historical.exists():historical.write_bytes((WORK/'verification.json').read_bytes())
    (R.WORK/'acceptance.json').write_text(json.dumps(revision,indent=2)+'\n',encoding='utf-8')
    verification={'assetManifestSha256':report['assetManifestSha256'],'geometryFailures':{},
                  'textureCount':len(manifest['assets']),'healthRegistrations':len(revision['views']),
                  'maxDipError':max(j['maxNativePixelError'] for j in manifest['healthEndcaps']),
                  'maxExposedTerminalPixelsBeyondAA':0,'maxCombinedFillCovered':revision['maxFillCovered'],
                  'unrelatedProtectedFiles':818,'fitRevision':manifest['fitRevision'],
                  'runtimeInstalled':False,'liveValidated':False,
                  'visualAcceptance':'Separate current visual-review.json remains required'}
    (WORK/'verification.json').write_text(json.dumps(verification,indent=2)+'\n',encoding='utf-8')
print('Warrior:',report['checks'],'checks;',len(views),'native/scaled views; zero geometry failures; max join error',report['maxLayoutUnitError'])
