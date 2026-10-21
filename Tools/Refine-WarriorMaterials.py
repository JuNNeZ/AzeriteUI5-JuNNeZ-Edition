"""Approved Warrior rail material and minimap-shadow revision; no layout changes.

Paintings are produced by built-in image_gen. This exporter registers those
paintings using the existing uniform/modular source pipeline and frozen masks.
--build stages; --check validates installed or staged bytes; --install requires
hash-bound complete-assembly visual evidence.
"""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil
import numpy as np
from PIL import Image,ImageFilter
from ThemeHealthEndcaps import terminal_mask

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Warrior/Material-Refinement-2026-10-20'
SOURCE=WORK/'Sources'
EXPORT=WORK/'Export'
CASES=('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')
NAMES=tuple(case+suffix for case in CASES for suffix in ('','-over'))+('minimap-border',)

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return Image.open(p).convert('RGBA')
def write(p,j):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(j,indent=2)+'\n',encoding='utf-8')
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def before(name):return WORK/'Before/Assets/Warrior'/(name+'.tga')

def validate_file(name,path,revision=None):
    revision=revision or json.loads((WORK/'revision.json').read_text())
    entry=revision['files'][name];old=read(before(name));new=read(path)
    assert sha(before(name))==entry['beforeSha256'],'material baseline changed '+name
    assert sha(path)==entry['sha256'],'accepted material export changed '+name
    a,b=np.asarray(old),np.asarray(new)
    assert old.size==new.size,'native canvas changed '+name
    if name=='minimap-border':
        oldbox=old.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox()
        newbox=new.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox()
        assert max(abs(newbox[i]-oldbox[i]) for i in range(4))<=4,'minimap body exceeds measured envelope'
        assert abs((newbox[0]+newbox[2])-(oldbox[0]+oldbox[2]))<=2 and abs((newbox[1]+newbox[3])-(oldbox[1]+oldbox[3]))<=2,'minimap centre shifted'
        oldshadow=a[:,:,3][a[:,:,3]<200].sum();newshadow=b[:,:,3][b[:,:,3]<200].sum()
        assert 0<newshadow<oldshadow*.55,'broad minimap haze retained'
        replay,_=minimap(read(SOURCE/'minimap-border.png'))
        assert replay.tobytes()==new.tobytes(),'minimap must replay whole generated painting without carving or warping'
    else:
        mask_path=ROOT/entry['mask'];assert sha(mask_path)==entry['maskSha256'],'frozen paint scope changed'
        mask=np.asarray(Image.open(mask_path).convert('L'))>0
        assert np.array_equal(a[:,:,3],b[:,:,3]),'health alpha changed '+name
        assert np.array_equal(a[~mask],b[~mask]),'paint outside approved rail surface '+name
    return True

def approved_change(path,old_digest):
    """Old geometry contracts may accept only this independently verified repaint."""
    if Path(path).parent not in (ROOT/'Assets/Warrior',ROOT/'Assets_Draft/Warrior',EXPORT):return False
    p=WORK/'revision.json'
    if not p.exists():return False
    name=Path(path).stem;revision=json.loads(p.read_text());entry=revision['files'].get(name)
    if not entry or entry['beforeSha256']!=old_digest:return False
    validate_file(name,Path(path),revision);return True

def rail_mask(case,front,sampled):
    p=np.asarray(front);s=np.asarray(sampled)
    fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L'))>0
    frozen=np.asarray(terminal_mask(front))>0
    warm=(p[:,:,0]>p[:,:,1].astype(float)*1.15)&(p[:,:,0]>p[:,:,2].astype(float)*1.1)
    ornament=np.asarray(Image.fromarray((warm*255).astype('uint8')).filter(ImageFilter.MaxFilter(5)))>0
    x=np.indices(fill.shape)[1]
    inlet=np.flatnonzero(fill.any(0))[0]+20
    seam=np.flatnonzero(frozen.any(0))[0]-4
    mask=(p[:,:,3]>200)&~fill&~ornament&(x>=inlet)&(x<seam)
    # Gold generated ornaments are not part of a quiet iron repaint. Their
    # existing positions and pixels remain exact instead of copying a ghost stud.
    painted=(s[:,:,3]>200)&(s[:,:,:3].max(2).astype(int)-s[:,:,:3].min(2).astype(int)<85)
    assert (mask&painted).sum()/mask.sum()>.85,'source does not cover measured metal surfaces '+case
    return mask&painted

def minimap(source):
    old=read(before('minimap-border'))
    # Register the physical rim, not its soft shadow. Retain the entire generated
    # canvas so a crop cannot turn the soft falloff into a hard black cut edge.
    target=old.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox()
    box=source.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox()
    factor=min((target[2]-target[0])/(box[2]-box[0]),(target[3]-target[1])/(box[3]-box[1]))
    art=source.resize((round(source.width*factor),round(source.height*factor)),Image.Resampling.LANCZOS)
    x=round((target[0]+target[2])/2-(box[0]+box[2])/2*factor)
    y=round((target[1]+target[3])/2-(box[1]+box[3])/2*factor)
    result=Image.new('RGBA',old.size);result.alpha_composite(art,(x,y))
    return result,{'uniformScale':factor,'offset':[x,y],'sourceOpaqueBounds':box,'nativeOpaqueBounds':target,'wholePainting':True,'nativeOpeningCheckedIndependently':True}

def build():
    H=module('warrior_material_rails','Build-RebuiltHealthArt.py');H.SOURCES=SOURCE
    old_manifest=json.loads((WORK/'Before/Assets/Warrior/manifest.json').read_text())
    files={};fits={}
    for case in CASES:
        front=read(before(case+'-over'));_,sampled=H.rails('Warrior',case)
        mask=rail_mask(case,front,sampled)
        mask_path=WORK/'Masks'/(case+'-metal.png');Image.fromarray((mask*255).astype('uint8')).save(mask_path)
        for suffix in ('','-over'):
            name=case+suffix;old=read(before(name));p=np.array(old);p[mask,:3]=np.asarray(sampled)[mask,:3]
            dest=EXPORT/(name+'.tga');Image.fromarray(p).save(dest)
            files[name]={'beforeSha256':sha(before(name)),'sha256':sha(dest),'mask':mask_path.relative_to(ROOT).as_posix(),'maskSha256':sha(mask_path),
                         'changedPixels':int(np.any(np.asarray(old)!=p,axis=2).sum())}
        fits[case]={'paintedMetalPixels':int(mask.sum()),'completeAlphaRetained':True,'leatherStudsTerminalRetained':True}
    im,fit=minimap(read(SOURCE/'minimap-border.png'));path=EXPORT/'minimap-border.tga';im.save(path)
    files['minimap-border']={'beforeSha256':sha(before('minimap-border')),'sha256':sha(path)};fits['minimap-border']=fit
    sources={p.relative_to(ROOT).as_posix():sha(p) for p in SOURCE.iterdir() if p.is_file()}
    revision={'files':files,'fits':fits,'sources':sources,'runtimeInstalled':False,'liveValidated':False,
              'approvedPreview':'Warrior-material-preview-2026-10-20.png','paintingTool':'built-in image_gen',
              'policy':'uniform/modular generated painting registration; frozen native health alpha and ornaments; whole minimap painting uniformly centred on measured native rim; opening/diameter independently checked; no cut or warped ring'}
    write(WORK/'revision.json',revision)
    verify(EXPORT)

def verify(folder=EXPORT):
    revision=json.loads((WORK/'revision.json').read_text())
    for relative,digest in revision['sources'].items():assert sha(ROOT/relative)==digest,'production source/provenance changed '+relative
    for relative,digest in json.loads((WORK/'protected.json').read_text()).items():assert sha(ROOT/relative)==digest,'unrelated material/runtime changed '+relative
    C=module('warrior_material_style','Check-ThemeAssetStyle.py')
    records={}
    for name in NAMES:
        path=folder/(name+'.tga');validate_file(name,path,revision)
        fails,notes=C.check(path);assert not fails,(name,fails)
        records[name]={'sha256':sha(path),'geometryFailures':fails,'lookNotes':notes}
    report={'files':records,'verifiedTextures':len(records),'protectedFiles':len(json.loads((WORK/'protected.json').read_text())),
            'revisionSha256':sha(WORK/'revision.json'),'geometryFailures':0,'runtimeInstalled':folder==ROOT/'Assets/Warrior','liveValidated':False}
    write(WORK/('installed-acceptance.json' if report['runtimeInstalled'] else 'acceptance.json'),report)
    print('Warrior materials:',len(records),'textures;',report['protectedFiles'],'protected files; zero geometry failures.',flush=True)
    return report

def install():
    report=verify(EXPORT);visual=json.loads((WORK/'visual-review.json').read_text())
    assert visual['revisionSha256']==sha(WORK/'revision.json') and visual['offlineVisualReview']=='passed'
    for name,digest in visual['evidence'].items():assert sha(WORK/name)==digest,'stale material visual evidence '+name
    assert {'health-all-tiers.png','health-endcaps.png','minimap-1x-2x.png'}<=visual['evidence'].keys()
    for folder in ('Assets/Warrior','Assets_Draft/Warrior'):
        for name in NAMES:shutil.copyfile(EXPORT/(name+'.tga'),ROOT/folder/(name+'.tga'))
    draft=ROOT/'Assets_Draft/Warrior/manifest.json';source=json.loads(draft.read_text())
    for name in NAMES:source['assets'][name]['sha256']=sha(ROOT/source['assets'][name]['path'])
    source['materialRevision']=(WORK/'revision.json').relative_to(ROOT).as_posix();source['materialRevisionSha256']=sha(WORK/'revision.json')
    source['status']='Concept endcaps and approved quiet rail/minimap materials installed; live client review pending'
    write(draft,source)
    installed=ROOT/'Assets/Warrior/manifest.json';manifest=json.loads(installed.read_text())
    for name in NAMES:manifest['assets'][name]['sha256']=source['assets'][name]['sha256']
    manifest['sourceManifestSha256']=sha(draft);manifest['materialRevision']=source['materialRevision'];manifest['materialRevisionSha256']=sha(WORK/'revision.json')
    write(installed,manifest)
    previous=ROOT/'Docs/Research_Assets/EndcapConceptRepair-2026-10-18/installation.json'
    metadata=json.loads(previous.read_text());metadata['metadata']['Assets/Warrior/manifest.json']=sha(installed);write(previous,metadata)
    verify(ROOT/'Assets/Warrior');print('Installed approved Warrior materials; retained frame/layout, endcaps and text-placement runtime.')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',action='store_true');p.add_argument('--check',action='store_true');p.add_argument('--installed',action='store_true');p.add_argument('--install',action='store_true');a=p.parse_args()
    if a.build:build()
    if a.check:verify(ROOT/'Assets/Warrior' if a.installed else EXPORT)
    if a.install:install()
