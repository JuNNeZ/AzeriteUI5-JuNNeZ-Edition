"""Shaman source checkpoint and native-geometry asset production.

Generated paintings remain intact; only plain rail runs are modular. Shared
native fill/glass/alpha contracts are exported separately from fresh material.
Never installs rejected art or changes another theme.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from ThemeHealthEndcaps import align, lowest_point, terminal_mask
from ThemeOrbGlass import restore_glass
from ThemeButtonShapes import border as shaped_border

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Shaman'
SOURCE = WORK/'Sources'
OUT = ROOT/'Assets_Draft/Shaman'
TEMPLATES = ROOT/'Docs/Research_Assets/Templates'
CASES = ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')
CHOICES = ('maelstrom','tides','lava')
SHARED = {'nameplate_backdrop':'shared neutral functional backing',
          'minimap-onebar-backdrop':'shared status ring',
          'minimap-twobars-backdrop':'shared status ring',
          'options-box':'shared control/state texture'}
ALIASES = {'pw_crystal_case_low':'pw_crystal_case','orb_case_low':'orb_case_hi',
           'portrait_frame_lo':'portrait_frame_hi','orb-border':'minimap-border',
           'config_button_bright':'config_button','hp_critter_case':'hp_critter_case_hi',
           'border-aura':'border-tooltip','better-blizzard-border-small-alternate':'border-tooltip'}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return Image.open(path).convert('RGBA')

def write(path, data):
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

def module(name, file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def prepare():
    for folder in (SOURCE,OUT,WORK/'Masks',WORK/'Guides',WORK/'Rejected'):
        folder.mkdir(parents=True,exist_ok=True)
    if (WORK/'contract.json').exists():
        return contract()
    refs=('d4bd98bc-8e32-4c67-90df-680f13849b56','435ea5de-4833-4097-a37e-b446e24e18f0','67eb7ef6-3b5e-4ba9-84e0-7616273daf74')
    for i,key in enumerate(refs,1):
        shutil.copyfile(Path('C:/Users/Jonas/AppData/Local/Temp')/('codex-clipboard-'+key+'.png'),WORK/('reference-'+str(i)+'.png'))
    protected={p.relative_to(ROOT).as_posix():sha(p) for folder in ('Assets','Core','Layouts','Options')
               for p in (ROOT/folder).rglob('*') if p.is_file()}
    health={}
    for case in CASES:
        native=read(ROOT/'Assets'/(case+'.tga'))
        path=WORK/'Masks'/(case+'-terminal.png');terminal_mask(native).save(path)
        boxes=[read(ROOT/'Assets/Druid'/('ornament-'+key+'-'+case+'.tga')).getchannel('A').point(lambda a:255 if a>128 else 0).getbbox() for key in ('antler','bear','owl')]
        druid=read(ROOT/'Assets/Druid'/(case+'-over.tga'))
        shift=lowest_point(native)[0]-lowest_point(druid)[0]
        limit=[int(np.floor(min(b[0] for b in boxes)+shift)),min(b[1] for b in boxes),
               int(np.ceil(max(b[2] for b in boxes)+shift)),max(b[3] for b in boxes)]
        health[case]={'terminalMask':path.relative_to(ROOT).as_posix(),'terminalMaskSha256':sha(path),
                      'dip':lowest_point(native),'approvedEnvelope':limit}
    result={'theme':'Shaman - Storm, Stone & Tides','approval':'User approved direction, three motifs and measured Druid maximum footprint in chat 2026-10-27.',
            'references':{('reference-'+str(i)+'.png'):sha(WORK/('reference-'+str(i)+'.png')) for i in range(1,4)},
            'health':health,'protected':protected,'runtimeInstalled':False,'liveValidated':False}
    write(WORK/'contract.json',result)
    spec=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
    write(WORK/'inventory.json',{p.name:{'sha256':sha(p),'disposition':SHARED.get(p.stem,'newly painted casing' if p.stem in spec else 'shared functional, semantic, effect or unrelated media')} for p in (ROOT/'Assets').glob('*.tga')})
    (WORK/'brief.md').write_text('''# Shaman — Storm, Stone & Tides

Approved 2026-10-27. Concept 2 supplies dark faceted stone, copper joins and cyan
Maelstrom motifs. Concept 1 supplies selective wave metal and pearl details at
the resource holders. Concept 3 supplies a compact alternate lava totem.
Health: Maelstrom (default), Tides, Lava Totem. Independent compact cast totem.
Base #242d33; copper #a6663d; rope #544535; cyan #34bdd9; tide #177e91.
Keep semantic fill colours and functional effects shared. No layout changes.
All new casing art is freshly generated against the native templates.
Health terminal coverage and measured Druid maximum envelope are independent.
Native glass and prediction contours stay shared. No concept-sheet upscales.
''',encoding='utf-8')
    checkpoint('Preparing representative Maelstrom health/cast sources. No runtime integration.')
    guides(result)
    print(json.dumps(health,indent=2))
    return result

def checkpoint(stage):
    (WORK/'CHECKPOINT.md').write_text('# Shaman production checkpoint\n\n'+stage+'\n\nAsset production, offline review, runtime integration and live Retail/Forever are separate statuses.\nReproduce: python Tools/Build-ShamanAssets.py --prepare\n',encoding='utf-8')

def contract():
    data=json.loads((WORK/'contract.json').read_text())
    for name,digest in data['references'].items():
        assert sha(WORK/name)==digest
    for item in data['health'].values():
        assert sha(ROOT/item['terminalMask'])==item['terminalMaskSha256']
    drift={}
    for name,digest in data['protected'].items():
        current=sha(ROOT/name)
        if current!=digest:
            # Other chats are actively editing runtime/options files in this
            # shared checkout. Keep their changes; asset fitting only depends
            # on the immutable native media/layout files. Report runtime drift
            # separately and re-ground integration against the current files.
            assert not name.startswith(('Assets/','Layouts/')),'Protected native art/layout changed: '+name
            drift[name]={'checkpointSha256':digest,'currentSha256':current}
    write(WORK/'external-runtime-drift.json',drift)
    return data

def guides(data):
    ref=data['health']['hp_cap_case'];rx,ry=ref['dip']
    union=np.zeros((256,1024),dtype=bool)
    for case,item in data['health'].items():
        mask=Image.open(ROOT/item['terminalMask']).convert('L')
        h=item['approvedEnvelope'][3]-item['approvedEnvelope'][1]
        scale=136/h;tx,ty=item['dip']
        normal=mask.transform((1024,256),Image.Transform.AFFINE,(1/scale,0,tx-rx/scale,0,1/scale,ty-ry/scale),Image.Resampling.NEAREST)
        union|=np.asarray(normal)>128
    # Unpainted silhouette guide only. A generous compact mounting body
    # covers the unchanged four-tier terminal union without a second low tip.
    shape=Image.new('L',(1024,256))
    ImageDraw.Draw(shape).polygon([(730,53),(789,53),(817,78),(821,120),(804,154),(775,176),(754,187),(737,179),(708,160),(702,127),(703,91)],fill=255)
    field=np.asarray(shape)>0
    margin=np.asarray(Image.fromarray(union.astype('uint8')*255).filter(ImageFilter.MaxFilter(7)))>0
    margin[185:]=union[185:]
    field|=margin
    pixels=np.zeros((256,1024,4),dtype='uint8');pixels[field]=[120,126,132,255]
    guide=Image.fromarray(pixels)
    guide.crop((690,32,838,198)).resize((740,830),Image.Resampling.NEAREST).save(WORK/'Guides/health-mount-template.png')
    write(WORK/'Guides/health-mount-template.json',{'geometryOnly':True,'approvedEnvelope':ref['approvedEnvelope'],'dip':ref['dip'],'normalizedAllTierTerminals':True,'sha256':sha(WORK/'Guides/health-mount-template.png')})

def source(name, original, prompt, references):
    target=SOURCE/(name+'.png')
    assert not target.exists(),'Refusing to overwrite a retained source'
    shutil.copyfile(original,target)
    write(SOURCE/(name+'.json'),{'tool':'built-in image_gen','originalGeneratedPath':str(original),'prompt':prompt,
          'references':{str(p):sha(Path(p)) for p in references},'sha256':sha(target),'maintainerApproved':False})

def health_runs(source,native):
    D=module('shaman_material','Build-DruidArt.py')
    target=D.opaque_bounds(native)
    art=source.crop(source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())
    height=target[3]-target[1];width=target[2]-target[0]
    art=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
    delta=width-art.width
    # Only the uninterrupted straight centre rail is varied. Ends and studs
    # retain uniform scale. Large ornaments never use this function.
    a,b=round(art.width*.37),round(art.width*.64)
    if delta<0:
        cut=-delta;first=cut//2
        assert a+first<b and b+cut-first<art.width-25
        pieces=[art.crop((0,0,a,height)),art.crop((a+first,0,b,height)),art.crop((b+cut-first,0,art.width,height))]
    elif delta:
        # Boss has two additional studs: repeat one intact central rail/stud
        # module, never stretch a stud or a terminal.
        centre=round(art.width*.5);first=delta//2
        if width>750:
            pieces=[art.crop((0,0,a,height)),art.crop((centre-first//2,0,centre-first//2+first,height)),
                    art.crop((a,0,b,height)),art.crop((centre-(delta-first)//2,0,centre-(delta-first)//2+delta-first,height)),art.crop((b,0,art.width,height))]
        else:
            run=art.crop((a-10,0,a+10,height));extra=Image.new('RGBA',(delta,height))
            for x in range(0,delta,20): extra.alpha_composite(run.crop((0,0,min(20,delta-x),height)),(x,0))
            pieces=[art.crop((0,0,a,height)),extra,art.crop((a,0,art.width,height))]
    else: pieces=[art]
    result=Image.new('RGBA',(width,height));x=0
    for piece in pieces: result.alpha_composite(piece,(x,0));x+=piece.width
    assert x==width
    return result

def casing(name):
    D=module('shaman_material','Build-DruidArt.py')
    native=read(ROOT/'Assets'/(name+'.tga'))
    source_name='hp_cap_case' if name in CASES else ('cast_back' if name.startswith('cast_back') else ALIASES.get(name,name))
    painting=read(SOURCE/(source_name+'.png'))
    if name in CASES: painting=health_runs(painting,native)
    if name.startswith('cast_back'): painting=D.modular_cast(painting,native)
    if name.startswith(('border-','better-')):
        image,fit=D.atlas(painting,native)
        return {name:image},fit
    if name.startswith('portrait_frame'):
        C=module('shaman_portrait_style','Check-ThemeAssetStyle.py')
        spec=C.SPEC[name];target=spec['painted'];opening=spec['opening']
        clean=painting.copy();clean.putalpha(clean.getchannel('A').point(lambda a:0 if a<=8 else a))
        art=clean.crop(clean.getchannel('A').getbbox());n=np.asarray(native)
        for extra in range(21):
            height=target[3]-target[1]+extra
            piece=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
            for dx in (0,-1,1,-2,2,-3,3):
                for dy in (0,-1,1,-2,2,-3,3):
                    x=round((target[0]+target[2]-piece.width)/2)+dx;y=round((target[1]+target[3]-piece.height)/2)+dy
                    candidate=Image.new('RGBA',native.size);candidate.alpha_composite(piece,(x,y))
                    p=np.array(candidate);inner=np.asarray(D.closed_hole(candidate))>0
                    glass=inner&(n[:,:,3]<=200)&(p[:,:,3]==0);p[glass]=n[glass];candidate=Image.fromarray(p)
                    bounds=candidate.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox();hole=C.hole(candidate)
                    if bounds and hole and all(abs(bounds[i]-target[i])<=10 for i in range(4)) and all(abs(hole[i]-opening[i])<=4 for i in range(4)):
                        return {name:candidate},{'source':source_name+'.png','uniformScale':height/art.height,'offset':[x,y],'paintedBounds':bounds,'opening':hole,'policy':'intact whole portrait; uniform scale/translation; native glass; no stencil or radial mapping'}
        raise ValueError('Whole Shaman portrait cannot fit its native aperture; retain source and repair')
    image,fit=D.register_material(painting,native)
    n=np.asarray(native);p=np.array(image)
    pending={}
    if name in CASES or name.startswith(('cast_back','hp_critter')):
        from PaladinFillContracts import clearance_mask
        fill=np.asarray(clearance_mask(name,native.size))>0
        # These sources explicitly keep all joinery on the rails. A future
        # crossing wrap needs its own reviewed foreground bridge mask.
        back=p.copy();back[fill]=n[fill]
        front=p.copy();front[fill,3]=0
        glass=fill&(n[:,:,3]>0)&(n[:,:,3]<=200);front[glass]=n[glass]
        mask_path=WORK/'Masks'/(name+'-bridges.png')
        if not mask_path.exists(): Image.new('L',native.size).save(mask_path)
        bridges=np.asarray(Image.open(mask_path).convert('L'))>128
        assert not bridges.any(),'Crossing foreground painting requires explicit source registration'
        pending[name]=Image.fromarray(back);pending[name+'-over']=Image.fromarray(front)
        fit['explicitBridgePixels']=0;fit['bridgeMaskSha256']=sha(mask_path)
    else:
        inner=np.asarray(D.closed_hole(native))>0
        fill_path=TEMPLATES/(name+'-fill.png')
        if fill_path.exists(): inner|=np.asarray(Image.open(fill_path).convert('L'))>128
        glass=inner&(n[:,:,3]<=200);p[glass]=n[glass]
        if name=='icon_exit_flight':
            glyph=(n[:,:,0].astype(float)>n[:,:,1]*1.4)&(n[:,:,0]>45);p[glyph]=n[glyph]
        if name.startswith('config_button'):
            rgb=n[:,:,:3].astype(float);glyph=(rgb.max(2)-rgb.min(2)>12)&(rgb.max(2)>60);p[glyph]=n[glyph]
        pending[name]=restore_glass(Image.fromarray(p),ROOT,name)
    fit['source']=source_name+'.png'
    fit['policy']='fresh source painting registered on native casing alpha; native recess, glass and shared fills'
    return pending,fit

def export(pending):
    C=module('shaman_style','Check-ThemeAssetStyle.py')
    result={}
    for name,image in pending.items():
        path=OUT/(name+'.tga');image.save(path,compression=None)
        failures,notes=C.check(path)
        result[name]={'sha256':sha(path),'canvas':list(image.size),'failures':failures,'lookNotes':notes}
    return result

def build_health(all_tiers=False):
    data=contract();records={}
    H=module('shaman_halos','Build-RebuiltHealthArt.py')
    for name in CASES if all_tiers else CASES[:1]:
        pending,fit=casing(name)
        pending[name+'-glow']=H.halo(pending[name+'-over'])
        required=np.asarray(Image.open(ROOT/data['health'][name]['terminalMask']).convert('L'))>128
        n=np.asarray(read(ROOT/'Assets'/(name+'.tga')))
        assert np.array_equal(np.asarray(pending[name])[required,3],n[required,3])
        records[name]={'registration':fit,'assets':export(pending),'bareFrontSha256':sha(OUT/(name+'-over.tga'))}
    write(WORK/'health-registration.json',records)
    assert not any(v['failures'] for item in records.values() for v in item['assets'].values()),records
    print('Exported complete bare health casing(s):',list(records))

def approved_exposure(choice,case,source_path):
    if choice!='maelstrom' or case not in ('hp_mid_case','hp_low_case'): return None,None
    approval=json.loads((WORK/'maelstrom-exposure-approval.json').read_text())
    assert approval['choice']==choice and approval['sourceSha256']==sha(source_path)
    assert approval['diagnosticSha256']==sha(WORK/'mounting-defect.json')
    assert approval['imageSha256']==sha(WORK/'Shaman-mounting-defect.png')
    item=approval['cases'][case];data=json.loads((WORK/'contract.json').read_text())
    assert item['terminalMaskSha256']==data['health'][case]['terminalMaskSha256']
    assert item['bareFrontSha256']==sha(OUT/(case+'-over.tga'))
    assert item['exposedSourcePixels']==(4 if case=='hp_mid_case' else 7)
    assert len(item['sourcePixelCoordinates'])==item['exposedSourcePixels']
    mask=Image.new('L',(1024,256))
    for point in item['sourcePixelCoordinates']: mask.putpixel(tuple(point),255)
    return mask,item

def fit_cap(choice,all_tiers=False,source_name=None):
    data=contract();H=module('shaman_cap_halos','Build-RebuiltHealthArt.py')
    source_path=SOURCE/(source_name or ('ornament-'+choice+'.png'));painting=read(source_path)
    fits={};pending={};rejected={}
    for case in CASES if all_tiers else CASES[:1]:
        item=data['health'][case];limit=item['approvedEnvelope']
        front=read(OUT/(case+'-over.tga'))
        fill=Image.open(TEMPLATES/(case+'-fill.png')).convert('L');mask=np.asarray(fill)>128
        trials=[];accepted=None
        approved,specific=approved_exposure(choice,case,source_path)
        angles=(0,-.5,.5,-1,1,-1.5,1.5,-2,2,-3,3)+tuple(a for n in range(4,16) for a in (-n,n))
        orientations={}
        required=np.asarray(Image.open(ROOT/item['terminalMask']).convert('L'))>128
        prepared={}
        placements=[(specific['rotationDegrees'],specific['height'])] if specific else ((angle,height) for angle in angles for height in range(100,limit[3]-limit[1]+1))
        for angle,height in placements:
            try:
                if angle not in orientations:
                    orientations[angle]=painting.rotate(angle,resample=Image.Resampling.BICUBIC,expand=True) if angle else painting
                    prepared[angle]=orientations[angle].crop(orientations[angle].getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())
                # Reject obviously impossible placements cheaply, then invoke
                # the shared whole-painting registrar for final acceptance.
                art=prepared[angle]
                piece=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
                ax,ay=lowest_point(piece);tx,ty=item['dip'];px,py=round(tx-ax),ty-ay
                assert px>=limit[0] and py>=limit[1] and px+piece.width<=limit[2] and py+piece.height<=limit[3],'outside approved exterior footprint'
                preview=Image.new('L',(limit[2]-limit[0],limit[3]-limit[1]));preview.paste(piece.getchannel('A'),(px-limit[0],py-limit[1]))
                aa=np.asarray(Image.fromarray((np.asarray(preview)>=240).astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
                exposed=required[limit[1]:limit[3],limit[0]:limit[2]]&~aa
                allowed=np.asarray(approved)[limit[1]:limit[3],limit[0]:limit[2]]>128 if approved is not None else np.zeros_like(exposed)
                assert np.array_equal(exposed,allowed),'preflight exposed terminal pixels: '+str(int(exposed.sum()))
                cap,fit=align(orientations[angle],front,height,fill,approved_terminal_exposure=approved)
                bounds=cap.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
                assert all((bounds[0]>=limit[0],bounds[1]>=limit[1],bounds[2]<=limit[2],bounds[3]<=limit[3])),'outside approved exterior footprint'
                combined=float((((np.asarray(cap)[:,:,3]>200)|(np.asarray(front)[:,:,3]>200))&mask).sum()/mask.sum())
                assert combined<=.20,'combined foreground/cap occlusion exceeds 20%'
                fit.update({'bounds':bounds,'approvedEnvelope':limit,'height':height,'rotationDegrees':angle,'combinedFillCovered':combined,'sourceSha256':sha(source_path),'approvedTerminalExposurePixels':specific['exposedSourcePixels'] if specific else 0})
                accepted=fit
                pending['ornament-'+choice+'-'+case]=cap
                pending['ornament-'+choice+'-'+case+'-glow']=H.halo(cap)
                break
            except (AssertionError,ValueError) as e: trials.append({'height':height,'angle':angle,'failure':str(e)})
        if accepted is None: rejected[case]=trials
        else: fits[case]=accepted
    record={'accepted':not rejected,'fits':fits,'rejected':rejected,'source':source_path.name,'sourceSha256':sha(source_path)}
    write(WORK/(choice+'-registration.json'),record)
    if rejected:
        write(WORK/'Rejected'/(choice+'-'+sha(source_path)[:10]+'.json'),record)
        raise ValueError('Source fails frozen health contract; retained diagnostic: '+choice)
    export(pending)
    print(choice+': exact approved terminal mask, toe, footprint and combined fill gates passed:',list(fits))

def prepare_cast():
    P=module('shaman_projection','PaladinFillContracts.py')
    db=json.loads((ROOT/'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json').read_text())['original']['PlayerCastBar']
    rect,slot=(80,58,112,11),(48,39.5,48,48)
    union=np.zeros((256,256),dtype=bool);records={}
    for case,family in (('cast_back','CastBarBackground'),('cast_back_spiked','CastBarShield')):
        native=read(ROOT/'Assets'/(case+'.tga'));a=np.array(native.getchannel('A'))
        inlet=Image.open(TEMPLATES/(case+'-fill.png')).convert('L').getbbox()[0];a[:,inlet:]=0
        path=WORK/'Masks'/(case+'-socket.png');Image.fromarray(a).save(path)
        casing_rect=P.anchor(rect,db[family+'Size'],db[family+'Position'])
        required=np.asarray(P.project(Image.fromarray(a),casing_rect,slot,(256,256)))>128
        union|=required
        records[case]={'socketMask':path.relative_to(ROOT).as_posix(),'socketMaskSha256':sha(path),'casingDrawRect':casing_rect}
    body=Image.new('L',(256,256))
    ImageDraw.Draw(body).polygon([(100,16),(155,16),(167,40),(178,54),(175,198),(149,228),(128,240),(101,228),(76,198),(76,54),(91,40)],fill=255)
    required=np.asarray(Image.fromarray(union.astype('uint8')*255).filter(ImageFilter.MaxFilter(9)))>0
    field=(np.asarray(body)>0)|required
    pixels=np.zeros((256,256,4),dtype='uint8');pixels[field]=[120,126,132,255]
    Image.fromarray(pixels).resize((1024,1024),Image.Resampling.NEAREST).save(WORK/'Guides/cast-totem-template.png')
    write(WORK/'cast-contract.json',{'slotDrawRect':slot,'nativeCastRect':rect,'cases':records,'runtimeScale':1,'userOffsets':[0,0]})
    print('Cast socket union:',Image.fromarray(union).getbbox())

def build_cast():
    contract();D=module('shaman_cast_material','Build-DruidArt.py');H=module('shaman_cast_halos','Build-RebuiltHealthArt.py')
    P=module('shaman_cast_projection','PaladinFillContracts.py')
    data=json.loads((WORK/'cast-contract.json').read_text());pending={};fits={}
    for name in ('cast_back','cast_back_spiked','cast_back_wooden'):
        items,fit=casing(name);pending.update(items);fits[name]=fit
    # Whole-art uniform placement, with painted centering in the fixed slot.
    painting=read(SOURCE/'cast-head.png')
    art=painting.crop(painting.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())
    scale=min(240/art.width,240/art.height)
    piece=art.resize((round(art.width*scale),round(art.height*scale)),Image.Resampling.LANCZOS)
    head=Image.new('RGBA',(256,256));head.alpha_composite(piece,(round((256-piece.width)/2),round((256-piece.height)/2)))
    b=head.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    assert abs((b[1]+b[3])/2-128)<=.5,'Painted cast head not centered'
    cover=np.asarray(P.project(head.getchannel('A'),data['slotDrawRect'],(0,0,256,128),(1024,512)))>=240
    expanded=np.asarray(Image.fromarray(cover.astype('uint8')*255).filter(ImageFilter.MaxFilter(7)))>0
    sockets={}
    for name,item in data['cases'].items():
        assert sha(ROOT/item['socketMask'])==item['socketMaskSha256']
        required=np.asarray(P.project(Image.open(ROOT/item['socketMask']).convert('L'),item['casingDrawRect'],(0,0,256,128),(1024,512)))>128
        sockets[name]=int((required&~expanded).sum())
    write(WORK/'cast-diagnostic.json',{'socketsExposed':sockets,'paintedBounds':b})
    assert not any(sockets.values()),'Painted cast socket exposed at default scale and offsets'
    pending['cast-head']=head;pending['cast-head-glow']=H.halo(head)
    result={'casings':fits,'assets':export(pending),'socketsExposed':sockets,'paintedBounds':b,'sourceSha256':sha(SOURCE/'cast-head.png')}
    write(WORK/'cast-registration.json',result)
    assert not any(v['failures'] for v in result['assets'].values()),result
    print('Independent normal/protected cast assets and actual painted sockets passed.')

def build_ordinary():
    contract();H=module('shaman_halos','Build-RebuiltHealthArt.py')
    spec=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
    records={};fits={};missing=[]
    for name in spec:
        if name in SHARED or name in CASES or name.startswith(('cast_back','actionbutton-border-')): continue
        if not (SOURCE/(ALIASES.get(name,name)+'.png')).exists():
            missing.append(name);continue
        pending,fit=casing(name);fits[name]=fit
        if name in ('portrait_frame_hi','portrait_frame_lo','pw_crystal_case','pw_crystal_case_low','orb_case_hi','orb_case_low'):
            pending[name+'-glow']=H.halo(pending[name])
        records.update(export(pending))
    if (OUT/'actionbutton-border.tga').exists():
        records.update(export({name:shaped_border(read(OUT/'actionbutton-border.tga'),read(ROOT/'Assets'/(name+'.tga'))) for name in ('actionbutton-border-square','actionbutton-border-square-rounded')}))
    write(WORK/'ordinary-registration.json',{'assets':records,'casings':fits,'missing':missing})
    failures={name:item['failures'] for name,item in records.items() if item['failures']}
    print(json.dumps({'textures':len(records),'failures':failures,'missing':missing},indent=2))
    assert not failures,'Ordinary casing fit requires correction'

def resource_halos():
    P=module('shaman_resource_projection','PaladinFillContracts.py');H=module('shaman_resource_halo','Build-RebuiltHealthArt.py')
    pending={};records={}
    for low,tier in ((False,'Seasoned'),(True,'Novice')):
        db=dict(P.LAYOUTS['PlayerFrame']);db.update(db[tier]);bar,case=P.crystal_rects(db)
        padded=(-bar[2]/2,-bar[3]/2,bar[2]*2,bar[3]*2)
        holder=read(OUT/('pw_crystal_case'+('_low' if low else '')+'.tga'))
        holder_alpha=P.project(holder.getchannel('A'),case,padded,(512,512))
        for wrath,field in ((False,'PowerBarTexture'),(True,'PowerBarTextureWrath')):
            fill_alpha=P.project(P.alpha(db[field]),bar,padded,(512,512))
            whole=Image.new('RGBA',(512,512),'white');whole.putalpha(Image.fromarray(np.maximum(np.asarray(holder_alpha),np.asarray(fill_alpha))))
            name='crystal-assembly'+('-low' if low else '')+('-wrath' if wrath else '')+'-glow'
            pending[name]=H.halo(whole)
            records[name]={'drawRect':list(padded),'nativeResourceRect':list(bar),'holderRect':list(case),'canvas':[512,512],'nativeFill':db[field],'silhouette':'whole native crystal plus Shaman cradle'}
    export(pending);write(WORK/'resource-halos.json',records)

def manifest():
    data=contract();C=module('shaman_manifest_style','Check-ThemeAssetStyle.py')
    assets={};checks={}
    for path in sorted(OUT.glob('*.tga')):
        failures,notes=C.check(path);assert not failures,(path.name,failures)
        assets[path.stem]={'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'canvas':list(Image.open(path).size)}
        checks[path.stem]={'failures':failures,'lookNotes':notes}
    casings=sorted(set(C.SPEC)-set(SHARED));assert all(name in assets for name in casings),'Incomplete native casing inventory'
    assert len(assets)==77,('Incomplete asset inventory',len(assets))
    caps={key:json.loads((WORK/(key+'-registration.json')).read_text()) for key in CHOICES}
    assert all(v['accepted'] and set(v['fits'])==set(CASES) for v in caps.values())
    cast=json.loads((WORK/'cast-registration.json').read_text());assert not any(cast['socketsExposed'].values())
    result={'theme':'Shaman - Storm, Stone & Tides','casings':casings,'shared':SHARED,'assets':assets,'checks':checks,
            'healthEndcaps':caps,'cast':cast,'resourceHalos':json.loads((WORK/'resource-halos.json').read_text()),
            'sources':{p.relative_to(WORK).as_posix():sha(p) for p in sorted(SOURCE.glob('*')) if p.is_file()},
            'generationProvenance':{p.stem:json.loads(p.read_text()) for p in sorted(SOURCE.glob('*.json'))},
            'preciseTerminalException':json.loads((WORK/'maelstrom-exposure-approval.json').read_text()),
            'contractSha256':sha(WORK/'contract.json'),'nativeLayoutChanges':False,'runtimeInstalled':False,
            'liveRetailValidated':False,'liveForeverValidated':False,
            'status':'Staged; final numerical and separate exported-assembly visual review required before installation'}
    write(OUT/'manifest.json',result);print('Complete Shaman staged manifest: 77 textures, 28 casings, twelve health fits, independent cast.')

def runtime_module(fits=None):
    """Create an unreferenced theme using the existing engine integration.

    The module only becomes loadable when Core.xml is separately wired after
    exported-assembly review. Measured text edges come from the accepted art.
    """
    import re
    if fits is None:
        fits={key:json.loads((WORK/(key+'-registration.json')).read_text()) for key in CHOICES}
        assert all(item['accepted'] and set(item['fits'])==set(CASES) for item in fits.values())
    else:
        # Explicit maintainer-requested in-game WIP review. Do not promote
        # these registrations to production acceptance records.
        assert set(fits)==set(CHOICES)
        assert all(set(item['fits'])==set(CASES) for item in fits.values())
    original=ROOT/'Core/RogueTheme.lua'
    text=original.read_text(encoding='utf-8').replace('Rogue','Shaman').replace('rogue','shaman').replace('Venom & Steel','Storm, Stone & Tides')
    text=text.replace('twinguard','maelstrom').replace('serrated','tides').replace('venom','lava')
    text=text.replace('Engine:Register(Theme, 60)','Engine:Register(Theme, 70)')
    text=text.replace('"Druid", "Warrior"','"Druid", "Warrior", "Rogue"')
    text=text.replace('choices = { lava = true, none = true }, default = "lava"','choices = { totem = true, none = true }, default = "totem"')
    text=text.replace('/azshaman castendcap [lava|none]','/azshaman castendcap [totem|none]')
    edges='local capTextEdges = {\n'+',\n'.join('\t'+key+' = { '+', '.join(case+' = '+str(item['fits'][case]['bounds'][0]) for case in CASES)+' }' for key,item in fits.items())+'\n}'
    text,n=re.subn(r'local capTextEdges = \{.*?\n\}',edges,text,count=1,flags=re.S);assert n==1
    path=ROOT/'Core/ShamanTheme.lua';assert not path.exists(),'Review existing module instead of replacing it'
    path.write_text(text,encoding='utf-8',newline='\n')
    write(WORK/'runtime-module-source.json',{'enginePatternSource':'Core/RogueTheme.lua','patternSha256':sha(original),'newModuleSha256':sha(path),'measuredCapTextEdges':{key:{case:fit['bounds'][0] for case,fit in item['fits'].items()} for key,item in fits.items()}})
    print('Created Shaman module with measured per-choice/per-tier text clearance; not loaded until Core.xml integration.')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare',action='store_true')
    parser.add_argument('--health',action='store_true')
    parser.add_argument('--all-tiers',action='store_true')
    parser.add_argument('--cap',choices=CHOICES)
    parser.add_argument('--prepare-cast',action='store_true')
    parser.add_argument('--cast',action='store_true')
    parser.add_argument('--import-job')
    parser.add_argument('--cap-source')
    parser.add_argument('--ordinary',action='store_true')
    parser.add_argument('--halos',action='store_true')
    parser.add_argument('--manifest',action='store_true')
    parser.add_argument('--runtime-module',action='store_true')
    args=parser.parse_args()
    if args.prepare: prepare()
    if args.health: build_health(args.all_tiers)
    if args.cap: fit_cap(args.cap,args.all_tiers,args.cap_source)
    if args.prepare_cast: prepare_cast()
    if args.cast: build_cast()
    if args.ordinary: build_ordinary()
    if args.halos: resource_halos()
    if args.manifest: manifest()
    if args.runtime_module: runtime_module()
    if args.import_job:
        job=json.loads(Path(args.import_job).read_text(encoding='utf-8'))
        source(job['name'],Path(job['original']),job['prompt'],job['references'])
