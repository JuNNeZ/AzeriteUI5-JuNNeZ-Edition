"""Restore approved endcap motifs; stage and review before replacing health art.

No runtime geometry, character settings, casing or Druid changes.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from ThemeHealthEndcaps import align, terminal_mask, terminal_coverage, lowest_point

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/EndcapConceptRepair-2026-10-18'
OUT=ROOT/'Assets_Draft/EndcapConceptRepair'
CASES=('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')
CHOICES={'Hunter':('thasdorah','talonclaw','titanstrike','thoridal','raeshalare'),
         'Mage':('aluneth','felomelorn','ebonchill','atiesh','dragonwrath'),
         'Paladin':('ashbringer','silverhand','argent'),
         'Warrior':('stromkar','warswords','wrath')}
CONCEPTS={'Hunter':'Docs/Research_Assets/Hunter/Production/v1/approved-concept.png',
          'Mage':'Assets_Draft/Mage-Complete-Assets-v12/References/Approved-Concept.png',
          'Paladin':'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/approved-concept.png',
          'Warrior':'Docs/Research_Assets/Warrior/approved-concept.png'}
SOURCES={}
for key in CHOICES['Hunter']:
    SOURCES['Hunter/'+key]='Docs/Research_Assets/Hunter/Production/v1/'+({'thasdorah':'thasdorah-v2','titanstrike':'titanstrike-v2'}.get(key,key))+'.png'
for key in CHOICES['Mage']:SOURCES['Mage/'+key]='Assets_Draft/Mage-Complete-Assets-v12/Sources/ornament-'+key+'.png'
for key in CHOICES['Warrior']:SOURCES['Warrior/'+key]='Docs/Research_Assets/Warrior/Sources/ornament-'+key+'.png'
SOURCES['Paladin/ashbringer']='Docs/Research_Assets/Paladin/Rebuild-2026-10-14/Sources/HD/ornament-ashbringer.png'
for key in ('silverhand','argent'):SOURCES['Paladin/'+key]='Docs/Research_Assets/AlignedEndcaps-2026-10-17/Sources/Paladin-'+key+'.png'

# Scope corrected by the maintainer: ONLY Warrior receives new paintings.
# Earlier H/M/P experiments remain rejected local evidence, never installable.
CHOICES = {'Warrior': ('stromkar','warswords','wrath')}


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return Image.open(p).convert('RGBA')
def write(p,j):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(j,indent=2)+'\n',encoding='utf-8')
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def casing(theme,case):return case+('-fitted' if theme=='Hunter' else '')
def bounds(im):return im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()


def fit_rotation(theme,key):
    """Try rigid whole-painting orientations, with the same angle at all tiers."""
    contracts=json.loads((WORK/'contracts.json').read_text())[theme]
    source=read(WORK/'Sources'/(theme+'-'+key+'.png'));best=None
    prepared={}
    for case,c in contracts.items():
        f=read(ROOT/'Assets'/theme/(casing(theme,case)+'-over.tga'));lim=c['limit'];fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L'))>128
        front=np.asarray(f)[:,:,3]>200
        prepared[case]=(c,np.asarray(Image.open(ROOT/c['mask']).crop(tuple(lim)))>0,
                        fill[lim[1]:lim[3],lim[0]:lim[2]],front[lim[1]:lim[3],lim[0]:lim[2]],int((front&fill).sum()),int(fill.sum()))
    for degrees in [0]+[a for n in range(1,16) for a in (-n,n)]:
        art=source.rotate(degrees,resample=Image.Resampling.BICUBIC,expand=True);art=art.crop(bounds(art))
        a=np.asarray(art)[:,:,3]>128;columns=np.flatnonzero(a[-max(2,round(art.height*.03)):].any(0))
        if len(np.split(columns,np.flatnonzero(np.diff(columns)>2)+1))!=1:continue
        errors={};all_pass=True
        for case,(c,req,mask,front,base,denom) in prepared.items():
            lim=c['limit'];lw,lh=lim[2]-lim[0],lim[3]-lim[1];closest=None;passed=False
            for h in range(100,lh+1):
                piece=art.resize((round(art.width*h/art.height),h),Image.Resampling.LANCZOS)
                ax,ay=lowest_point(piece);x=round(c['dip'][0]-ax)-lim[0];y=c['dip'][1]-ay-lim[1]
                if x<0 or y<0 or x+piece.width>lw or y+piece.height>lh:continue
                alpha=Image.new('L',(lw,lh));alpha.paste(piece.getchannel('A'),(x,y));pa=np.asarray(alpha)
                combined=(base+int(((pa>200)&mask&~front).sum()))/denom
                if combined>.20:continue
                expanded=np.asarray(Image.fromarray(((pa>=240)*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)))>0
                missing=int((req&~expanded).sum())
                if closest is None or missing<closest['missing']:closest={'height':h,'missing':missing,'combined':combined}
                if missing==0:passed=True;break
            errors[case]=closest
            if not passed:all_pass=False
        score=sum(e['missing'] if e else 100000 for e in errors.values())
        if best is None or score<best['score']:best={'degrees':degrees,'score':score,'cases':errors}
        if all_pass:
            path=WORK/'Sources'/(theme+'-'+key+'.json');meta=json.loads(path.read_text());meta['rotationDegrees']=degrees;write(path,meta)
            print(theme,key,'rigid orientation',degrees,'fits all tiers',flush=True);build(theme,key);return
    print(theme,key,'best bounded fit:',json.dumps(best),flush=True)


def prepare():
    WORK.mkdir(exist_ok=True);(WORK/'Sources').mkdir(exist_ok=True)
    replace={'Assets/'+theme+'/ornament-'+key+'-'+case+suffix+'.tga'
             for theme,keys in CHOICES.items() for key in keys for case in CASES for suffix in ('','-glow')}
    paths=[p for p in (ROOT/'Assets').rglob('*') if p.is_file()]
    paths += [p for directory in ('Core','Layouts','Options') for p in (ROOT/directory).rglob('*') if p.suffix in ('.lua','.xml')]
    protected={p.relative_to(ROOT).as_posix():sha(p) for p in paths if p.relative_to(ROOT).as_posix() not in replace}
    lock=WORK/'protected.json'
    if lock.exists():assert json.loads(lock.read_text())==protected,'protected art/runtime changed'
    else:write(lock,protected)
    for relative in sorted(replace):
        dest=WORK/'Before'/relative
        if not dest.exists():dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/relative,dest)
    contracts={}
    for theme in CHOICES:
        per_case={}
        for case in CASES:
            front=read(ROOT/'Assets'/theme/(casing(theme,case)+'-over.tga'))
            tx,ty=lowest_point(front)
            df=read(ROOT/'Assets/Druid'/(case+'-over.tga'));dtx,dty=lowest_point(df);shift=tx-dtx;shift_y=ty-dty
            boxes=[bounds(read(ROOT/'Assets/Druid'/('ornament-'+key+'-'+case+'.tga'))) for key in ('antler','bear','owl')]
            limit=[int(np.floor(min(b[0] for b in boxes)+shift)),min(b[1] for b in boxes)+shift_y,
                   int(np.ceil(max(b[2] for b in boxes)+shift)),max(b[3] for b in boxes)+shift_y]
            assert limit[3]==ty+1,'reference footprint must share this casing dip on BOTH axes'
            path=WORK/'Masks'/theme/(case+'.png');path.parent.mkdir(parents=True,exist_ok=True)
            required=terminal_mask(front)
            if path.exists():assert np.array_equal(np.asarray(Image.open(path)),np.asarray(required)),'frozen full terminal changed'
            else:required.save(path)
            per_case[case]={'mask':path.relative_to(ROOT).as_posix(),'sha256':sha(path),
                            'casingSha256':sha(ROOT/'Assets'/theme/(casing(theme,case)+'-over.tga')),
                            'dip':[tx,ty],'limit':limit}
        contracts[theme]=per_case
        # Fit guide is the actual required terminal, not a substitute shield.
        ref=per_case['hp_cap_case'];lim=ref['limit'];mask=Image.open(ROOT/ref['mask']).convert('L').filter(ImageFilter.MaxFilter(3))
        guide=Image.new('RGBA',(1024,1024))
        cropped=mask.crop(tuple(lim)).resize((786,816),Image.Resampling.NEAREST)
        magenta=Image.new('RGBA',cropped.size,'#d93d8e');magenta.putalpha(cropped)
        guide.alpha_composite(magenta,(119,104))
        draw=ImageDraw.Draw(guide);draw.rectangle((118,103,905,920),outline='#22cddd',width=3)
        px=119+(ref['dip'][0]-lim[0])*6;py=104+(ref['dip'][1]-lim[1])*6
        draw.ellipse((px-5,py-5,px+5,py+5),fill='#ffffb0')
        guide.save(WORK/(theme+'-mount-guide.png'))
    path=WORK/'contracts.json'
    if path.exists():assert json.loads(path.read_text())==contracts,'contract changed after fitting'
    else:write(path,contracts)
    write(WORK/'design-inputs.json',{'concepts':{k:{'path':v,'sha256':sha(ROOT/v)} for k,v in CONCEPTS.items()},
          'sources':{k:{'path':v,'sha256':sha(ROOT/v)} for k,v in SOURCES.items()},
          'authority':'Original approved class concepts; mounting edits do not authorize motif redesign',
          'defaults':{'healthScale':1.3,'x':0,'y':0},'liveValidated':False})
    print('Frozen full terminal and Druid-sized limits for four themes; 128 old cap/halo textures retained.')


def build(theme,key):
    contracts=json.loads((WORK/'contracts.json').read_text())[theme]
    source=WORK/'Sources'/(theme+'-'+key+'.png');meta=source.with_suffix('.json')
    provenance=json.loads(meta.read_text());rotation=provenance.get('rotationDegrees',0)
    painting=read(source)
    assert provenance.get('tool')=='built-in image_gen','Production edits require image_gen provenance; original references are not accepted exports'
    if rotation:painting=painting.rotate(rotation,resample=Image.Resampling.BICUBIC,expand=True)
    H=module('concept_halo','Build-RebuiltHealthArt.py')
    pending={};fits=[]
    for case,contract in contracts.items():
        front=read(ROOT/'Assets'/theme/(casing(theme,case)+'-over.tga'))
        assert sha(ROOT/'Assets'/theme/(casing(theme,case)+'-over.tga'))==contract['casingSha256']
        fill=Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L');inside=np.asarray(fill)>128
        lim=contract['limit'];failures=[]
        for height in range(100,lim[3]-lim[1]+1):
            try:
                cap,fit=align(painting,front,height,fill);b=bounds(cap)
                assert all((b[0]>=lim[0],b[1]>=lim[1],b[2]<=lim[2],b[3]<=lim[3])),'outside approved footprint'
                combined=float((((np.asarray(cap)[:,:,3]>200)|(np.asarray(front)[:,:,3]>200))&inside).sum()/inside.sum())
                assert combined<=.20,'combined fill coverage'
                break
            except (AssertionError,ValueError) as error:failures.append(str(error))
        else:raise ValueError(theme+'/'+key+'/'+case+': '+failures[-1])
        name='ornament-'+key+'-'+case
        pending[name]=cap;pending[name+'-glow']=H.halo(cap)
        fits.append(dict(fit,case=case,height=height,rotationDegrees=rotation,bounds=b,limit=lim,combinedFillCovered=combined))
    folder=OUT/theme;folder.mkdir(parents=True,exist_ok=True)
    files={}
    for name,image in pending.items():
        path=folder/(name+'.tga');image.save(path);files[path.relative_to(ROOT).as_posix()]=sha(path)
    write(WORK/'Fits'/(theme+'-'+key+'.json'),{'theme':theme,'choice':key,'source':source.relative_to(ROOT).as_posix(),
         'sourceSha256':sha(source),'provenanceSha256':sha(meta),'files':files,'fits':fits,'liveValidated':False})
    print(theme,key,'all four compact whole-terminal fits staged')


def verify_theme(theme,folder=None,keys=None):
    folder=folder or OUT/theme;keys=keys or CHOICES[theme]
    contracts=json.loads((WORK/'contracts.json').read_text())[theme]
    material=module('concept_material_gate','Refine-WarriorMaterials.py') if theme=='Warrior' else None
    checks=0;views=[]
    def check(ok,label):
        nonlocal checks
        checks+=1;assert ok,label
    for key in keys:
        record=json.loads((WORK/'Fits'/(theme+'-'+key+'.json')).read_text())
        source=ROOT/record['source'];check(sha(source)==record['sourceSha256'],'retained source '+theme+'/'+key)
        check(sha(source.with_suffix('.json'))==record['provenanceSha256'],'exact prompt/provenance '+theme+'/'+key)
        for fit in record['fits']:
            case=fit['case'];contract=contracts[case];front_path=ROOT/'Assets'/theme/(casing(theme,case)+'-over.tga')
            check(sha(front_path)==contract['casingSha256'] or (material and material.approved_change(front_path,contract['casingSha256'])),'whole bare casing retained or verified material-only repaint '+theme+'/'+case)
            check(sha(ROOT/contract['mask'])==contract['sha256'],'frozen full-terminal mask '+theme+'/'+case)
            front=read(front_path);name='ornament-'+key+'-'+case
            cap=read(folder/(name+'.tga'));p=np.asarray(cap);q=np.asarray(front);b=bounds(cap);lim=contract['limit']
            expected=record['files'][(OUT/theme/(name+'.tga')).relative_to(ROOT).as_posix()]
            check(sha(folder/(name+'.tga'))==expected,'accepted export bytes '+theme+'/'+name)
            check(b[0]>=lim[0] and b[1]>=lim[1] and b[2]<=lim[2] and b[3]<=lim[3],'bounded external footprint '+name)
            tx,ty=lowest_point(front);px,py=lowest_point(cap)
            check(abs(px-tx)<=.5 and py==ty,'actual toe shares bare dip '+name)
            check(not (p[ty+1:,:,3]>128).any(),'no extra lower point '+name)
            required=np.asarray(Image.open(ROOT/contract['mask']).convert('L'))>0
            for flip in (False,True):
                req=required[:,::-1] if flip else required;alpha=p[:,::-1,3] if flip else p[:,:,3]
                aa=np.asarray(Image.fromarray(((alpha>=240)*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)))>0
                check(not (req&~aa).any(),'complete frozen terminal covered '+name+'/'+str(flip))
            fill=Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L');mask=np.asarray(fill)>128
            combined=float((((p[:,:,3]>200)|(q[:,:,3]>200))&mask).sum()/mask.sum())
            check(combined<=.20,'combined foreground preserves fill '+name)
            painting=read(source)
            if fit['rotationDegrees']:painting=painting.rotate(fit['rotationDegrees'],resample=Image.Resampling.BICUBIC,expand=True)
            replay,_=align(painting,front,fit['height'],fill)
            check(replay.tobytes()==cap.tobytes(),'whole original painting replay; no warp or masking '+name)
            H=module('concept_verify_halo','Build-RebuiltHealthArt.py')
            check(read(folder/(name+'-glow.tga')).tobytes()==H.halo(cap).tobytes(),'complete neutral halo '+name)
            views.append({'choice':key,'case':case,'paintedBounds':b,'combinedFillCovered':combined,'exposedTerminalPixelsBeyondAA':0})
    return {'checks':checks,'views':views,'geometryFailures':0,'maxExposedTerminalPixelsBeyondAA':0,
            'maxFillCovered':max(v['combinedFillCovered'] for v in views),'runtimeInstalled':folder==ROOT/'Assets'/theme,
            'assetManifestSha256':sha(ROOT/'Assets_Draft/Warrior/manifest.json') if theme=='Warrior' else None,'liveValidated':False}


def verify(proof=False,installed=False):
    protected=json.loads((WORK/'protected.json').read_text())
    installation=json.loads((WORK/'installation.json').read_text()) if (WORK/'installation.json').exists() else {}
    defaults=json.loads((WORK/'authorized-defaults.json').read_text())
    assert set(defaults)=={'Core/ThemeEngine.lua','Core/HunterTheme.lua','Core/MageTheme.lua','Core/PaladinTheme.lua'}
    text_path=WORK/'authorized-health-text.json'
    text_placement=json.loads(text_path.read_text()) if text_path.exists() else {}
    if text_placement:
        assert set(text_placement)=={'Core/WarriorTheme.lua'},'unexpected health-text edit scope'
    for relative,digest in protected.items():
        if relative in text_placement:
            edit=text_placement[relative]
            assert edit['beforeSha256']==digest==sha(ROOT/edit['baseline']),'health-text baseline changed '+relative
            assert sha(ROOT/relative)==edit['afterSha256'],'health-text edit changed after review '+relative
        elif relative in defaults:
            assert defaults[relative]['beforeSha256']==digest,'default-edit baseline changed '+relative
            assert sha(ROOT/relative)==defaults[relative]['afterSha256'],'default edit changed after review '+relative
        elif relative in installation.get('metadata',{}):
            assert sha(WORK/'Before'/relative)==digest,'original metadata baseline changed '+relative
            assert sha(ROOT/relative)==installation['metadata'][relative],'installed metadata changed '+relative
        else:
            current=sha(ROOT/relative)
            material=module('concept_material_scope','Refine-WarriorMaterials.py') if relative.startswith('Assets/Warrior/') and current!=digest else None
            assert current==digest or (material and material.approved_change(ROOT/relative,digest)),'unrelated art/runtime changed '+relative
    for theme in ('Hunter','Mage','Paladin'):
        for original in (WORK/'Before/Assets'/theme).glob('*.tga'):
            assert sha(original)==sha(ROOT/'Assets'/theme/original.name),'existing class cap changed '+theme+'/'+original.name
    reports={}
    for theme,keys in CHOICES.items():reports[theme]=verify_theme(theme,ROOT/'Assets'/theme if installed else OUT/theme,keys[:1] if proof else keys)
    files={}
    for theme,keys in CHOICES.items():
        for key in (keys[:1] if proof else keys):
            record=json.loads((WORK/'Fits'/(theme+'-'+key+'.json')).read_text())
            for source,digest in record['files'].items():
                files['Assets/'+theme+'/'+Path(source).name]={'source':source,'sha256':digest}
    report={'checks':sum(r['checks'] for r in reports.values()),'themes':reports,'files':files,
            'contractsSha256':sha(WORK/'contracts.json'),'designInputsSha256':sha(WORK/'design-inputs.json'),
            'unchangedProtectedFiles':len(protected),'proofOnly':proof,'geometryFailures':0,'runtimeInstalled':installed,'liveValidated':False}
    write(WORK/('proof-acceptance.json' if proof else 'installed-acceptance.json' if installed else 'acceptance.json'),report)
    if not proof and not installed:write(WORK/'manifest.json',report)
    print('Concept endcaps:',report['checks'],'checks;',len(files),'textures; protected files',len(protected),'; live unverified.')
    return report


def install():
    report=verify();visual=json.loads((WORK/'visual-review.json').read_text())
    assert visual['manifestSha256']==sha(WORK/'manifest.json') and visual['offlineVisualReview']=='passed'
    for theme,keys in CHOICES.items():
        assert theme+'-all-1x.png' in visual['evidence'],'complete native-size evidence required'
        for key in keys:assert theme+'-'+key+'-2x.png' in visual['evidence'],'every complete 2x assembly required'
    for relative,digest in visual['evidence'].items():assert sha(WORK/relative)==digest,'stale inspected evidence '+relative
    # Validate all bytes and evidence before replacing any installed texture.
    for relative,item in report['files'].items():
        assert sha(ROOT/item['source'])==item['sha256']
        assert relative=='Assets/'+Path(relative).parts[1]+'/'+Path(relative).name
    for relative in ('Assets/Warrior/manifest.json','Assets/Warrior/README.md','Assets_Draft/Warrior/manifest.json'):
        before=WORK/'Before'/relative
        if not before.exists():before.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/relative,before)
    for relative,item in report['files'].items():shutil.copyfile(ROOT/item['source'],ROOT/relative)
    # Keep the existing Warrior source/installed inventories truthful. Its
    # leather, cast and other 53 art entries are retained, not regenerated.
    draft=ROOT/'Assets_Draft/Warrior';source=json.loads((draft/'manifest.json').read_text())
    joins=[]
    for key in CHOICES['Warrior']:
        record=json.loads((WORK/'Fits'/('Warrior-'+key+'.json')).read_text())
        for fit in record['fits']:joins.append(dict(fit,choice=key))
        source['acceptedHealthSources'][key]=record['source']
        source['revisionSources'][record['source']]=record['sourceSha256']
        source['generationProvenance']['concept-'+key]=json.loads((ROOT/record['source']).with_suffix('.json').read_text())
    for relative,item in report['files'].items():
        if not relative.startswith('Assets/Warrior/'):continue
        name=Path(relative).stem;dest=draft/Path(relative).name;shutil.copyfile(ROOT/item['source'],dest)
        source['assets'][name]={'path':dest.relative_to(ROOT).as_posix(),'canvas':list(read(dest).size),'sha256':sha(dest)}
    source['healthEndcaps']=joins;source['conceptRepairManifest']=(WORK/'manifest.json').relative_to(ROOT).as_posix()
    source['conceptRepairManifestSha256']=sha(WORK/'manifest.json')
    source['status']='Original concept motifs restored; compact full-terminal health fits; live review pending'
    write(draft/'manifest.json',source)
    installed=json.loads((ROOT/'Assets/Warrior/manifest.json').read_text())
    installed['sourceManifestSha256']=sha(draft/'manifest.json');installed['healthEndcaps']=joins
    installed['conceptRepairManifest']=source['conceptRepairManifest'];installed['conceptRepairManifestSha256']=source['conceptRepairManifestSha256']
    for name,item in source['assets'].items():installed['assets'][name]=dict(item,path='Assets/Warrior/'+name+'.tga')
    write(ROOT/'Assets/Warrior/manifest.json',installed)
    readme=ROOT/'Assets/Warrior/README.md'
    note='\n## Concept restoration - 2026-10-18\n\nThe shield-plaque health revision is superseded. Original Stromkar, Warswords\nand Wrath fittings are restored with compact full-terminal mounting bodies.\nCurrent sources, exact prompts, checks and complete None/on evidence are in\nDocs/Research_Assets/EndcapConceptRepair-2026-10-18/. Other Warrior art, leather\nbridges, cast fit, runtime geometry and saved settings are unchanged.\nLive Retail/Forever confirmation is still pending.\n'
    if '## Concept restoration - 2026-10-18' not in readme.read_text(encoding='utf-8-sig'):readme.write_text(readme.read_text(encoding='utf-8-sig')+note,encoding='utf-8')
    metadata={p:sha(ROOT/p) for p in ('Assets/Warrior/manifest.json','Assets/Warrior/README.md')}
    write(WORK/'installation.json',{'metadata':metadata,'manifestSha256':sha(WORK/'manifest.json'),'runtimeInstalled':True,'liveValidated':False})
    verify(installed=True)
    print('Installed 24 Warrior cap/halo textures; all other theme art, casings, layouts and saved settings retained.')


def scene(theme,key=None,flip=False,tier='Seasoned',fraction=1,before=False):
    M=module('concept_native_layout','Build-ImplementedThemeSheets.py');B=M.B
    base=M.DATA['TargetFrame' if flip else 'PlayerFrame'];db=dict(base);db.update(base[tier])
    canvas=Image.new('RGBA',(1300,500));owner=(280,180,*base['Size'])
    hp=B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
    rect=B.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
    # Explicit names avoid confusing Novice/Hardened with equal-looking textures.
    case={'Seasoned':'hp_cap_case','Hardened':'hp_mid_case','Novice':'hp_low_case','Boss':'hp_boss_case'}[tier]
    B.put(canvas,read(ROOT/'Assets'/theme/(casing(theme,case)+'.tga')),rect,flip)
    B.fill(canvas,db['HealthBarTexture'],hp,1,(.09,.08,.11),flip)
    if fraction==.5:B.fill(canvas,db['HealthBarTexture'],hp,.7,(.25,.58,.65),flip)
    B.fill(canvas,db['HealthBarTexture'],hp,fraction,(.84,.03,.08),flip)
    B.put(canvas,read(ROOT/'Assets'/theme/(casing(theme,case)+'-over.tga')),rect,flip)
    if key:
        folder=WORK/'Before/Assets'/theme if before else OUT/theme
        B.put(canvas,read(folder/('ornament-'+key+'-'+case+'.tga')),rect,flip)
    if flip:
        name=Path(db['PortraitBorderTexture'].replace('\\','/')).stem
        B.put(canvas,read(ROOT/'Assets'/theme/(name+'.tga')),B.anchor(owner,db['PortraitBorderSize'],db['PortraitBorderPosition']))
    return canvas


def label(page,text,x,y,size=18):ImageDraw.Draw(page).text((x,y),text,font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',size),fill='#d9d1bc')


def edit_target(theme,key):
    """Diagnostic guide only: magenta marks missing opaque mounting material."""
    contract=json.loads((WORK/'contracts.json').read_text())[theme]['hp_cap_case'];lim=contract['limit']
    src=read(WORK/'Sources'/(theme+'-'+key+'.png'))
    front=read(ROOT/'Assets'/theme/(casing(theme,'hp_cap_case')+'-over.tga'))
    fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates/hp_cap_case-fill.png').convert('L'))>128
    frozen=Image.open(ROOT/contract['mask']).convert('L')
    # A diagnostic safety margin tapers into the actual dip. A blanket dilation
    # truncated at the toe drew a false flat foot in earlier rejected guides.
    req=frozen.copy();ra=np.array(req);ty=int(contract['dip'][1])
    for radius in range(1,5):
        expanded=np.asarray(frozen.filter(ImageFilter.MaxFilter(radius*2+1)))
        rows=np.arange(frozen.height)<=ty-radius*3
        ra[rows]=np.maximum(ra[rows],expanded[rows])
    req=Image.fromarray(ra)
    required=np.asarray(req)>0;best=None
    for degrees in (0,-4,4,-8,8,-12,12):
        art=src.rotate(degrees,resample=Image.Resampling.BICUBIC,expand=True);art=art.crop(bounds(art))
        for height in range(90,137):
            piece=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
            tx,ty=lowest_point(front);ax,ay=lowest_point(piece);x,y=round(tx-ax),ty-ay
            im=Image.new('RGBA',front.size);im.alpha_composite(piece,(x,y));b=bounds(im)
            if b[0]<lim[0] or b[1]<lim[1] or b[2]>lim[2] or b[3]>lim[3]:continue
            p=np.asarray(im);union=((p[:,:,3]>=240)|required)
            combined=float(((union|(np.asarray(front)[:,:,3]>200))&fill).sum()/fill.sum())
            if combined>.20:continue
            missing=required&(p[:,:,3]<240)
            score=int(missing.sum())+abs(degrees)*5
            if best is None or score<best[0]:best=(score,im,degrees,height)
    assert best,theme+' no compact guide'
    _,im,degrees,height=best;p=np.array(im);missing=required&(p[:,:,3]<240)
    yy,xx=np.indices(missing.shape);missing &= (xx>=lim[0])&(xx<lim[2])&(yy>=lim[1])&(yy<lim[3])
    p[missing]=[225,45,154,255]
    # Mark the intended toe, avoiding a dilated extra lower tip in the guide.
    ty=int(contract['dip'][1]);p[ty+1:,:,3]=0;p[ty,:,3]=0;p[ty,round(contract['dip'][0]),:]=[100,100,100,255]
    crop=Image.fromarray(p).crop(tuple(lim));crop=crop.resize((786,816),Image.Resampling.NEAREST)
    target=Image.new('RGBA',(1024,1024));target.alpha_composite(crop,(119,104));target.save(WORK/(theme+'-'+key+'-edit-target.png'))
    write(WORK/(theme+'-'+key+'-edit-target.json'),{'guideOnly':True,'rotationDegrees':degrees,'height':height,'missingPixels':int(missing.sum())})
    print(theme,'target:',height,'px, rotation',degrees,'missing body pixels',int(missing.sum()))


def review(proof=False):
    themes=CHOICES
    if proof:themes={theme:keys[:1] for theme,keys in CHOICES.items()}
    for theme,keys in themes.items():
        images=[[scene(theme,key,flip,fraction=.5 if flip else 1) for flip in (False,True)] for key in (None,*keys)]
        boxes=[Image.fromarray(np.maximum.reduce([np.asarray(row[col])[:,:,3] for row in images])).getbbox() for col in (0,1)]
        page=Image.new('RGBA',(1800,170+260*len(images)),'#14161a')
        label(page,theme.upper()+' / ORIGINAL MOTIFS / COMPLETE BARS AT DEFAULT SETTINGS',28,20,27)
        label(page,'Offline exports; health baseline 130%, X=0, Y=0. Full casing retained. Target: 50% plus synthetic prediction.',28,65,16)
        for row,key in enumerate((None,*keys)):
            y=115+row*260;label(page,key.upper() if key else 'NONE',28,y,20)
            for col in (0,1):
                crop=images[row][col].crop(boxes[col]);assert crop.width<870 and crop.height<210
                page.alpha_composite(crop,(28+col*890,y+35))
        page.convert('RGB').save(WORK/(theme+('-proof' if proof else '-all')+'-1x.png'))
        for key in keys:
            images=[[scene(theme,key if on else None,flip,fraction=.5 if flip else 1) for on in (False,True)] for flip in (False,True)]
            boxes=[Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for im in row])).getbbox() for row in images]
            page=Image.new('RGBA',(1900,1800),'#14161a');label(page,theme.upper()+' / '+key.upper()+' / COMPLETE NONE-ON / 2x',28,20,28)
            for i,row in enumerate(images):
                for j,im in enumerate(row):
                    y=100+i*800+j*390;label(page,('TARGET' if i else 'PLAYER')+(' / ON' if j else ' / NONE'),28,y,19)
                    crop=im.crop(boxes[i]);crop=crop.resize((crop.width*2,crop.height*2),Image.Resampling.LANCZOS)
                    assert crop.width+28<=page.width and crop.height+y+40<=page.height
                    page.alpha_composite(crop,(28,y+40))
            page.convert('RGB').save(WORK/(theme+'-'+key+'-2x.png'))
    print('Rendered complete native bars, fixed None/on viewports and 2x detail.')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');p.add_argument('--theme',choices=CHOICES);p.add_argument('--key');p.add_argument('--review',action='store_true');p.add_argument('--proof',action='store_true');p.add_argument('--edit-target',action='store_true');p.add_argument('--fit-rotation',action='store_true');p.add_argument('--check',action='store_true');p.add_argument('--installed',action='store_true');p.add_argument('--install',action='store_true')
    args=p.parse_args()
    if args.prepare:prepare()
    if args.theme and args.key:
        if args.edit_target:edit_target(args.theme,args.key)
        elif args.fit_rotation:fit_rotation(args.theme,args.key)
        else:build(args.theme,args.key)
    if args.review:review(args.proof)
    if args.check:verify(args.proof,args.installed)
    if args.install:install()
