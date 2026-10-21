"""Warrior live-feedback revision: bounded paintings, explicit strap foregrounds.

Prepare guides/snapshots with --prepare; never regenerates other theme art.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import inspect
import json
import shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
from ThemeHealthEndcaps import lowest_point,terminal_mask,terminal_coverage,align

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Warrior/Live-Repair-2026-10-18'
SOURCE=WORK/'Sources'
OUT=ROOT/'Assets_Draft/Warrior'
CASES=('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return Image.open(p).convert('RGBA')
def write(p,obj):p.write_text(json.dumps(obj,indent=2)+'\n',encoding='utf-8')


def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m


def raw_rails(case):
    H=module('warrior_raw_replay','Build-RebuiltHealthArt.py')
    env=dict(H.__dict__);env['SOURCES']=ROOT/'Docs/Research_Assets/Warrior/Sources'
    code=inspect.getsource(H.rails).replace('pixels[inside,3]=0','raw=front.copy(); pixels[inside,3]=0')
    code=code.replace('return Image.fromarray(back),front','return Image.fromarray(back),front,raw')
    exec(compile(code,'<raw whole-painting exporter>','exec'),env)
    return env['rails']('Warrior',case)[2]


def prepare():
    SOURCE.mkdir(parents=True,exist_ok=True)
    before=WORK/'Before';before.mkdir(exist_ok=True)
    for folder in ('Assets/Warrior','Assets_Draft/Warrior'):
        target=before/folder;target.mkdir(parents=True,exist_ok=True)
        for p in (ROOT/folder).iterdir():
            if p.is_file() and not (target/p.name).exists():shutil.copyfile(p,target/p.name)
    for name in ('Core/WarriorTheme.lua','Tools/Build-WarriorAssets.py','Tools/Check-WarriorIntegration.py'):
        target=before/name;target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists():shutil.copyfile(ROOT/name,target)
    audit=json.loads((ROOT/'Docs/Research_Assets/Warrior/Live-Fit-Audit-2026-10-18/audit.json').read_text())
    envelopes=audit['proposedDruidSizedEnvelopes']
    write(WORK/'envelopes.json',envelopes)
    # The guide is a compact body enclosing the ORIGINAL terminal. No casing
    # cut/shrunk mask, added socket, stretch or scaling until a coverage pass.
    front=read(ROOT/'Assets/Warrior/hp_cap_case-over.tga')
    required=np.asarray(terminal_mask(front))>0
    polygons={
      'stromkar':[(714,68),(733,62),(755,53),(780,61),(806,56),(821,84),(825,120),(808,150),(778,167),(761,187),(748,177),(726,164),(714,145)],
      'warswords':[(709,53),(735,65),(756,59),(788,59),(808,53),(823,79),(825,125),(807,150),(778,167),(761,187),(744,175),(725,164),(711,143)],
      'wrath':[(716,67),(737,62),(756,54),(795,57),(819,79),(825,119),(808,151),(778,167),(761,187),(747,176),(726,164),(714,143)]}
    for key,poly in polygons.items():
        field=Image.new('L',front.size);ImageDraw.Draw(field).polygon(poly,fill=255)
        expanded=Image.fromarray((required*255).astype('uint8')).filter(ImageFilter.MaxFilter(3))
        a=np.maximum(np.asarray(field),np.asarray(expanded)).copy()
        a[188:]=0;a[187]=0;a[187,760:762]=255
        # High-resolution geometry reference only; image_gen paints the actual art.
        crop=Image.fromarray(a).crop((698,52,829,188)).resize((786,816),Image.Resampling.NEAREST)
        mask=Image.new('L',(1024,1024));mask.paste(crop,(119,104))
        template=Image.new('RGBA',(1024,1024),'#686d76');template.putalpha(mask)
        template.save(WORK/(key+'-compact-template.png'))
    cast=Image.new('RGBA',(1024,1024))
    poly=[(10,24),(22,4),(32,6),(36,16),(38,20),(38,30),(32,42),(22,44)]
    ImageDraw.Draw(cast).polygon([(32+x*20,32+y*20) for x,y in poly],fill='#686d76')
    cast.save(WORK/'cast-compact-template.png')
    print('Before snapshot and four compact geometry templates prepared.')


def hull(points):
    points=sorted(set(points))
    def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower=[]
    for p in points:
        while len(lower)>=2 and cross(lower[-2],lower[-1],p)<=0:lower.pop()
        lower.append(p)
    upper=[]
    for p in reversed(points):
        while len(upper)>=2 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
        upper.append(p)
    return lower[:-1]+upper[:-1]


def restore_straps(case):
    before=WORK/'Before/Assets_Draft/Warrior'
    front=read(before/(case+'-over.tga'));raw=raw_rails(case)
    p=np.asarray(raw);red=(p[:,:,0]>55)&(p[:,:,0]>p[:,:,1].astype(float)*1.6)&(p[:,:,0]>p[:,:,2].astype(float)*1.2)&(p[:,:,3]>200)
    columns=np.flatnonzero(red.sum(0)>10)
    groups=[g for g in np.split(columns,np.flatnonzero(np.diff(columns)>3)+1) if len(g)>15]
    assert len(groups)==2,'two complete leather straps required'
    bridge=Image.new('L',front.size)
    for g in groups:
        mask=red.copy();mask[:,:g[0]-2]=False;mask[:,g[-1]+3:]=False
        y,x=np.where(mask)
        ImageDraw.Draw(bridge).polygon(hull(list(zip(x.tolist(),y.tolist()))),fill=255)
    bridge=bridge.filter(ImageFilter.MaxFilter(3))
    fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L'))>0
    mask=(np.asarray(bridge)>0)&fill
    q=np.array(front);q[mask]=p[mask]
    result=Image.fromarray(q)
    assert (np.asarray(result)[:,:,3]>200)[red&fill&mask].all(),'leather alpha erased'
    assert float(((q[:,:,3]>200)&fill).sum()/fill.sum())<=.20
    return result,Image.fromarray((mask*255).astype('uint8'))


def fit_cap(key,case,front,fill):
    envelopes=json.loads((WORK/'envelopes.json').read_text())
    limit=envelopes[case]['proposedBounds']
    source=read(SOURCE/(key+'-compact.png'))
    degrees=json.loads((SOURCE/(key+'-compact.json')).read_text()).get('registrationRotationDegrees',0)
    if degrees:source=source.rotate(degrees,resample=Image.Resampling.BICUBIC,expand=True)
    errors=[]
    # Explicit upper footprint bound. Never repeat the old unbounded grow-to-fit.
    for height in range(100,limit[3]-limit[1]+1):
        try:
            cap,fit=align(source,front,height,fill)
            b=cap.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
            assert b[0]>=limit[0] and b[1]>=limit[1] and b[2]<=limit[2] and b[3]<=limit[3],('outside approved envelope',b,limit)
            mask=np.asarray(fill)>128
            union=float((((np.asarray(cap)[:,:,3]>200)|(np.asarray(front)[:,:,3]>200))&mask).sum()/mask.sum())
            assert union<=.20,'combined foreground hides more than 20 percent of fill'
            return cap,dict(fit,paintedBounds=list(b),approvedEnvelope=limit,sourceRotationDegrees=degrees)
        except (AssertionError,ValueError) as error:errors.append(str(error))
    raise ValueError(key+'/'+case+' cannot satisfy compact envelope AND coverage: '+errors[0])


def cast_socket(head):
    """Project painted socket coverage at the real default slot on both casings."""
    V=module('warrior_socket_layout','Render-WarriorAssets.py');r=V.Renderer()
    D=module('warrior_socket_project','Build-DruidArt.py')
    rect=(80,58,112,11);target=(0,0,256,128);size=(1024,512)
    cover=np.asarray(D.project(head.getchannel('A'),(48,39.5,48,48),target,size))>=240
    # One casing source pixel: 193/256 layout units, at 4x sampling.
    aa=np.asarray(Image.fromarray((cover*255).astype('uint8')).filter(ImageFilter.MaxFilter(7)))>0
    result={}
    for name,family in (('cast_back','CastBarBackground'),('cast_back_spiked','CastBarShield')):
        front=read(WORK/'Before/Assets_Draft/Warrior'/(name+'-over.tga'))
        fill=Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')
        # Freeze the entire left termination up to the measured fill inlet.
        p=np.array(front.getchannel('A'));p[:,fill.getbbox()[0]:]=0
        mask=Image.fromarray(p)
        casing=V.B.anchor(rect,r.data['PlayerCastBar'][family+'Size'],r.data['PlayerCastBar'][family+'Position'])
        required=np.asarray(D.project(mask,casing,target,size))>128
        result[name]={'requiredProjectedPixels':int(required.sum()),'exposedSocketPixelsBeyondAA':int((required&~aa).sum()),
                      'nativeLeftTerminationSha256':hashlib.sha256(mask.tobytes()).hexdigest(),
                      'slot':{'size':48,'x':-8,'y':0,'userScale':1,'userOffset':[0,0]}}
    return result


def verify(folder=OUT):
    """Read exports independently; original rejected fixtures must still fail."""
    manifest=json.loads((OUT/'manifest.json').read_text())
    material=module('warrior_material_lineage','Refine-WarriorMaterials.py') if manifest.get('materialRevision') else None
    revision=json.loads((WORK/'revision.json').read_text())
    if manifest.get('conceptRepairManifest'):
        concept_path=ROOT/manifest['conceptRepairManifest']
        assert sha(concept_path)==manifest['conceptRepairManifestSha256'],'stale concept repair manifest'
        baseline=concept_path.parent/'Before/Assets_Draft/Warrior/manifest.json'
        assert revision['sourceManifestSha256']==sha(baseline),'original fit revision lineage changed'
        previous=json.loads(baseline.read_text())
        for name,item in previous['assets'].items():
            if not name.startswith('ornament-'):
                assert sha(folder/(name+'.tga'))==item['sha256'] or (material and material.approved_change(folder/(name+'.tga'),item['sha256'])),'non-health art changed outside approved material scope '+name
        concept=module('warrior_concept_revision','Repair-ConceptEndcaps.py')
        concept.verify_theme('Warrior',folder)
    else:
        assert revision['sourceManifestSha256']==sha(OUT/'manifest.json'),'stale revision contract'
    material=module('warrior_material_revision','Refine-WarriorMaterials.py') if manifest.get('materialRevision') else None
    if material:material.verify(folder)
    original=json.loads((WORK.parent/'Terminal-Repair/mask-lock.json').read_text())
    envelopes=json.loads((WORK/'envelopes.json').read_text())
    before=WORK/'Before/Assets_Draft/Warrior'
    checks=0;views=[];strap_results={}
    def check(ok,label):
        nonlocal checks
        checks+=1;assert ok,label
    for path,digest in manifest['revisionSources'].items():check(sha(ROOT/path)==digest,'retained revision source '+path)
    for case in CASES:
        contract=revision['bridges'][case];front=read(folder/(case+'-over.tga'));q=np.asarray(front)
        old=np.asarray(read(before/(case+'-over.tga')));raw=np.asarray(raw_rails(case))
        bridge=Image.open(ROOT/contract['bridgeMask']).convert('L');mask=np.asarray(bridge)>0
        fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L'))>128
        check(sha(ROOT/contract['bridgeMask'])==contract['bridgeMaskSha256'],'frozen leather bridge '+case)
        check(sha(before/(case+'-over.tga'))==contract['beforeFrontSha256']==original[case]['casingSha256'],'original casing lock '+case)
        repaint=np.zeros(mask.shape,dtype=bool)
        if material:
            record=json.loads((material.WORK/'revision.json').read_text())['files'][case+'-over']
            repaint=np.asarray(Image.open(ROOT/record['mask']).convert('L'))>0
        check(np.array_equal(q[~(mask|repaint)],old[~(mask|repaint)]),'complete bare casing unchanged outside leather and verified material scope '+case)
        check(np.array_equal(q[mask],raw[mask]),'all bridge paint including rivets preserved exactly '+case)
        check(np.all(q[fill&~mask,3]<=200),'functional aperture clear outside explicit bridges '+case)
        check(np.any((raw[mask,3]>240)&(old[mask,3]<=200)),'old erased leather fixture fails '+case)
        check(sha(folder/(case+'.tga'))==sha(before/(case+'.tga')) or (material and material.approved_change(folder/(case+'.tga'),sha(before/(case+'.tga')))),'back and full native opening unchanged or verified material-only repaint '+case)
        lock=original[case];check(sha(ROOT/lock['path'])==lock['sha256'],'original terminal mask immutable '+case)
        required=np.asarray(Image.open(ROOT/lock['path']).convert('L'))>0
        check(lowest_point(front)==lowest_point(read(before/(case+'-over.tga'))),'bare dip unchanged '+case)
        strap_results[case]={'restoredBridgePixels':int(mask.sum()),'frontFillFraction':float(((q[:,:,3]>200)&fill).sum()/fill.sum())}
        lim=envelopes[case]['proposedBounds']
        # Derive the fixed limit again from unchanged Druid art, independently
        # of both the fitted cap and the editable revision envelope JSON.
        reference=[]
        for key in ('antler','bear','owl'):
            art=read(ROOT/'Assets/Druid'/('ornament-'+key+'-'+case+'.tga'))
            reference.append(art.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())
        shift=lowest_point(front)[0]-lowest_point(read(ROOT/'Assets/Druid'/(case+'-over.tga')))[0]
        expected=[int(np.floor(min(b[0] for b in reference)+shift)),min(b[1] for b in reference),
                  int(np.ceil(max(b[2] for b in reference)+shift)),max(b[3] for b in reference)]
        check(lim==expected,'approved envelope still equals original Druid union '+case)
        for key in ('stromkar','warswords','wrath'):
            cap=read(folder/('ornament-'+key+'-'+case+'.tga'));p=np.asarray(cap)
            b=cap.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
            check(b[0]>=lim[0] and b[1]>=lim[1] and b[2]<=lim[2] and b[3]<=lim[3],'Druid-sized footprint '+key+'/'+case)
            tx,ty=lowest_point(front);px,py=lowest_point(cap)
            check(abs(px-tx)<=.5 and py==ty,'single actual toe at bare dip '+key+'/'+case)
            union=float((((p[:,:,3]>200)|(q[:,:,3]>200))&fill).sum()/fill.sum())
            check(union<=.20,'combined bridges and cap preserve functional fill '+key+'/'+case)
            for flip in (False,True):
                req=required[:,::-1] if flip else required;alpha=p[:,::-1,3] if flip else p[:,:,3]
                aa=np.asarray(Image.fromarray(((alpha>=240)*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)))>0
                check(not (req&~aa).any(),'full ORIGINAL terminal covered '+key+'/'+case+'/'+str(flip))
            check(terminal_coverage(front,cap)['exposedTerminalPixelsBeyondAA']==0,'new foreground terminal also covered '+key+'/'+case)
            oldcap=read(before/('ornament-'+key+'-'+case+'.tga'));bb=oldcap.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
            check(bb[1]<lim[1] or bb[0]<lim[0] or bb[2]>lim[2] or bb[3]>lim[3],'reject former giant cap '+key+'/'+case)
            views.append({'choice':key,'case':case,'paintedBounds':b,'combinedFillCovered':union,'exposedTerminalPixelsBeyondAA':0})
    head=read(folder/'cast-head.tga');b=head.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    check(abs((b[1]+b[3])/2-128)<=.5,'painted cast centre at zero Y')
    cast=cast_socket(head);old_cast=cast_socket(read(before/'cast-head.tga'))
    for name,item in cast.items():
        check(item['exposedSocketPixelsBeyondAA']==0,'actual painted cast socket at 100/0/0 '+name)
        check(old_cast[name]['exposedSocketPixelsBeyondAA']>0,'reject former bottom-aligned cast head '+name)
    return {'checks':checks,'bridges':strap_results,'views':views,'castSockets':cast,'geometryFailures':0,
            'maxExposedTerminalPixelsBeyondAA':0,'maxFillCovered':max(v['combinedFillCovered'] for v in views),
            'assetManifestSha256':sha(OUT/'manifest.json'),'runtimeInstalled':folder==ROOT/'Assets/Warrior','liveValidated':False}


def review():
    V=module('warrior_revision_renderer','Render-WarriorAssets.py');r=V.Renderer()
    D=V.M.Renderer('Druid')
    page=Image.new('RGBA',(1500,1250),'#14161a')
    V.label(page,'WARRIOR / LIVE FEEDBACK REPAIR / OFFLINE ASSEMBLIES',28,20,27)
    V.label(page,'Health: identical rail origin. New art fits within Druid bounds; actual gameplay-size comparison.',28,65,17)
    druid=Image.new('RGBA',(1300,600));druid.alpha_composite(D.health(),(50,50))
    scenes=[r.health(before=True),r.health(cap=False),r.health(),druid]
    box=Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for im in scenes])).getbbox()
    for i,(title,scene) in enumerate(zip(('BEFORE / giant cap, erased leather','AFTER / None, restored leather','AFTER / compact Stromkar','DRUID / Wildheart reference'),scenes)):
        y=115+i*180;V.label(page,title,28,y,18);crop=scene.crop(box)
        assert crop.width<1000 and crop.height<145
        page.alpha_composite(crop,(28,y+28))
    V.label(page,'CAST / 100% / X=0 / Y=0 / 2x detail / NORMAL AND PROTECTED',28,850,22)
    casts=[]
    for old in (True,False):
        row=[]
        for shield in (False,True):
            scene=r.cast(False,shield)
            head=read(WORK/'Before/Assets_Draft/Warrior/cast-head.tga') if old else r.own('cast-head')
            r.put(scene,head,(138,91.5,48,48));row.append(scene)
        casts.append(row)
    cb=Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for row in casts for im in row])).getbbox()
    for i,row in enumerate(casts):
        y=905+i*165;V.label(page,'BEFORE' if i==0 else 'AFTER',28,y,17)
        for j,scene in enumerate(row):
            crop=scene.crop(cb);crop=crop.resize((crop.width*2,crop.height*2),Image.Resampling.LANCZOS)
            assert crop.width<650 and y+28+crop.height<page.height,('cast comparison bounds',crop.size)
            page.alpha_composite(crop,(28+j*700,y+28))
    page.convert('RGB').save(WORK.parent/'Warrior-live-repair.png')
    # Dedicated fixed-viewport cast None/on at true 1x and 2x, both variants.
    page=Image.new('RGBA',(1500,1050),'#14161a')
    V.label(page,'CAST DEFAULTS / NONE AND ON / COMPLETE BAR / 1x + 2x',28,20,27)
    V.label(page,'Shared 48px slot at (-8,0); all user size/offset controls at 100%, 0, 0.',28,65,18)
    scenes=[[r.cast(on,shield) for on in (False,True)] for shield in (False,True)]
    box=Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for row in scenes for im in row])).getbbox()
    for i,row in enumerate(scenes):
        for j,scene in enumerate(row):
            y=115+(i*2+j)*220
            V.label(page,('PROTECTED' if i else 'NORMAL')+(' / ON' if j else ' / NONE'),28,y,18)
            for col,scale in enumerate((1,2)):
                crop=scene.crop(box);crop=crop.resize((crop.width*scale,crop.height*scale),Image.Resampling.LANCZOS)
                page.alpha_composite(crop,(28+col*600,y+35))
    page.convert('RGB').save(WORK.parent/'Warrior-cast-defaults.png')
    print('Rendered live-repair before/after, Druid reference and default cast None/on.')


def build():
    M=module('warrior_old_builder','Build-WarriorAssets.py')
    H=module('warrior_halo','Build-RebuiltHealthArt.py')
    before=WORK/'Before/Assets_Draft/Warrior'
    manifest=json.loads((before/'manifest.json').read_text())
    pending={};joins=[];bridges={}
    for case in CASES:
        front,bridge=restore_straps(case)
        fill=Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L')
        pending[case+'-over']=front;pending[case+'-glow']=H.halo(front)
        bridges[case]=bridge
        for key in ('stromkar','warswords','wrath'):
            cap,fit=fit_cap(key,case,front,fill)
            pending['ornament-'+key+'-'+case]=cap
            pending['ornament-'+key+'-'+case+'-glow']=H.halo(cap)
            joins.append(dict(choice=key,case=case,**fit))
    cast,cast_fit=M.D.contain(read(SOURCE/'cast-compact.png'),(16,16,240,240),(256,256))
    b=cast.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    assert abs((b[1]+b[3])/2-128)<=.5,'cast painting must be vertically centered at zero offset'
    pending['cast-head']=cast;pending['cast-head-glow']=H.halo(cast)
    assert all(v['exposedSocketPixelsBeyondAA']==0 for v in cast_socket(cast).values()),'cast must cover both actual sockets at 100/0/0'
    # All source shapes must satisfy the full constraints before replacing any file.
    checks={}
    for name,image in pending.items():
        M.save(name,image,manifest['assets'])
        failures,notes=M.C.check(OUT/(name+'.tga'));assert not failures,(name,failures)
        checks[name]={'failures':failures,'lookNotes':notes}
    (WORK/'Masks').mkdir(exist_ok=True)
    contracts={}
    for case,bridge in bridges.items():
        path=WORK/'Masks'/(case+'-straps.png');bridge.save(path)
        contracts[case]={'bridgeMask':path.relative_to(ROOT).as_posix(),'bridgeMaskSha256':sha(path),
                         'beforeFrontSha256':sha(before/(case+'-over.tga')),'frontSha256':sha(OUT/(case+'-over.tga'))}
    manifest['healthEndcaps']=joins;manifest['castHead']=cast_fit
    manifest['checks'].update(checks)
    manifest['status']='Compact live-feedback revision staged; separate visual acceptance required'
    manifest['fitRevision']='Live-Repair-2026-10-18'
    manifest['acceptedHealthSources']={key:(SOURCE/(key+'-compact.png')).relative_to(ROOT).as_posix() for key in ('stromkar','warswords','wrath')}
    manifest['generationProvenance'].update({p.stem:json.loads(p.read_text()) for p in SOURCE.glob('*.json')})
    manifest['revisionSources']={p.relative_to(ROOT).as_posix():sha(p) for p in SOURCE.glob('*.png')}
    write(OUT/'manifest.json',manifest)
    write(WORK/'revision.json',{'sourceManifestSha256':sha(OUT/'manifest.json'),'bridges':contracts,'health':joins,
                               'cast':dict(cast_fit,paintedBounds=list(b)),'runtimeInstalled':False,'liveValidated':False})
    print('Compact revision staged:',len(pending),'textures; twelve bounded full-terminal fits.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--build',action='store_true');parser.add_argument('--check',action='store_true');parser.add_argument('--review',action='store_true')
    args=parser.parse_args()
    if args.prepare:prepare()
    if args.build:build()
    if args.check:
        result=verify();write(WORK/'acceptance.json',result);print(json.dumps(result,indent=2))
    if args.review:review()
