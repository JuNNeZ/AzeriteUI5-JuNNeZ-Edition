"""Bounded, backed-up WIP installation of the reviewed Rogue fit closure.

No production approval, release, geometry change or saved-variable write.
Default is read-only preflight; --install-wip performs the authorized preview.
"""
from pathlib import Path
from datetime import datetime
import argparse
import hashlib
import importlib.util
import json
import uuid

from ThemeSourceIntegrity import checked_file, read, verify_pack
from RogueFitClosureSource import validate as source_replay

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Rogue/Fit-Closure-2026-10-31'
DRAFT = ROOT/'Assets_Draft/Rogue-Fit-Closure-2026-10-31'
NAMES = {'hp_cap_case-over','hp_cap_case-glow','actionbutton-border',
         'pw_crystal_case-seat','pw_crystal_case-seat-wrath',
         'ornament-serrated-hp_cap_case','ornament-serrated-hp_cap_case-glow'}
NEW = 'Assets/Rogue/pw_crystal_case-seat-wrath.tga'
RUNTIME = {'Core/RogueTheme.lua','Core/ThemeEffects.lua'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digest(contents):
    return hashlib.sha256(contents).hexdigest()


def data(path):
    return json.loads(path.read_text(encoding='utf-8'))


def encoded(value):
    return (json.dumps(value,indent=2,ensure_ascii=False)+'\n').encode('utf-8')


def write_owned(path, contents):
    assert path.resolve().is_relative_to(ROOT.resolve())
    temporary=path.with_name(path.name+'.rogue-fit-'+uuid.uuid4().hex+'.tmp')
    try:
        with temporary.open('xb') as stream:stream.write(contents)
        temporary.replace(path)
    finally:
        if temporary.exists():temporary.unlink()


def validate():
    auth=data(WORK/'live-preview-authorization.json')
    assert auth['livePreviewAuthorized'] is True and auth['productionAccepted'] is False
    assert auth['userContinuation']=='Forsæt.' and auth['priorLiveInstruction']=='Fedt, gør dem live.'
    assert auth['installerSha256']==sha(Path(__file__)),'Installer changed after review'
    frozen=data(checked_file(auth['reviewManifest'],ROOT))
    for path,expected in frozen['files'].items():
        checked_file({'path':path,'sha256':expected},ROOT)
    review=data(WORK/'review.json')
    assert review['sharedSourceGate']['passed'] and not review['productionAccepted']
    assert not review['representativeLiveApproved']
    baseline=data(WORK/'Runtime/baseline.json')['files']
    assert set(baseline)==RUNTIME
    proposed={}
    for path,record in baseline.items():
        assert sha(ROOT/path)==record['beforeSha256'],'Concurrent runtime change: '+path
        staged=WORK/'Runtime'/Path(path).name
        assert sha(staged)==record['proposedSha256']
        proposed[path]=staged.read_bytes()
    source_gate=verify_pack(DRAFT)
    draft=data(DRAFT/'manifest.json')
    assert set(draft['assets'])==NAMES and draft['numericalPassed'] is True
    assert source_gate['assetManifestSha256']==review['sharedSourceGate']['assetManifestSha256']
    assert source_gate['sourceIntegritySha256']==review['sharedSourceGate']['sourceIntegritySha256']
    construction=data(WORK/'construction.json')
    replay=source_replay(construction['recipe'],
        {n:checked_file(p,ROOT) for n,p in construction['sources'].items()},ROOT)
    for name in sorted(NAMES):
        asset=DRAFT/(name+'.tga')
        assert sha(asset)==draft['assets'][name]['sha256']
        assert asset.read_bytes()[2]==2 and asset.read_bytes()[16]==32
        assert list(read(asset).size)==draft['assets'][name]['canvas']
        proposed['Assets/Rogue/'+name+'.tga']=asset.read_bytes()
    # Replay geometry/contact checks from the frozen source and exported cap.
    spec=importlib.util.spec_from_file_location('closure_install_checks',ROOT/'Tools/Preview-RogueFitClosure.py')
    preview=importlib.util.module_from_spec(spec);spec.loader.exec_module(preview)
    images={n:read(checked_file(p,ROOT)) for n,p in construction['sources'].items()}
    caps={k:read((DRAFT if k=='serrated' else ROOT/'Assets/Rogue')/('ornament-'+k+'-hp_cap_case.tga')) for k in ('twinguard','serrated','venom')}
    health=preview.health_metrics(images['hp_cap_case-over'],caps)
    crystal=preview.crystal_layers(images)
    assert json.loads(json.dumps(health))==review['health'] and crystal==review['crystal']
    manifest=data(ROOT/'Assets/Rogue/manifest.json')
    prior={p.stem:sha(p) for p in (ROOT/'Assets/Rogue').glob('*.tga')}
    assert len(prior)==78 and set(prior)==set(manifest['assets'])
    assert all(manifest['assets'][n]['sha256']==h for n,h in prior.items())
    assert not (ROOT/NEW).exists(),'New floor path already exists'
    locked=data(WORK/'input-lock.json')
    for path,expected in locked.items():
        assert (ROOT/path).is_file() and sha(ROOT/path)==expected,'Reviewed input drift: '+path
    return auth,review,source_gate,replay,draft,manifest,prior,proposed


def install():
    auth,review,gate,replay,draft,manifest,prior,proposed=validate()
    folder=WORK/('Live-Preview-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8])
    backup=folder/'Before';backup.mkdir(parents=True)
    manifest_path='Assets/Rogue/manifest.json'
    targets=set(proposed)|{manifest_path}
    assert targets=={'Assets/Rogue/'+n+'.tga' for n in NAMES}|RUNTIME|{manifest_path}
    before={p:(ROOT/p).read_bytes() if (ROOT/p).exists() else None for p in sorted(targets)}
    assert {p for p,b in before.items() if b is None}=={NEW}
    for path,contents in before.items():
        if contents is None:continue
        copy=backup/path;copy.parent.mkdir(parents=True,exist_ok=True)
        copy.write_bytes(contents);assert sha(copy)==digest(contents)
    (backup/'previously-absent.json').write_bytes(encoded([NEW]))
    protected={p.relative_to(ROOT).as_posix():sha(p)
        for directory in ('Assets','Core','Layouts','Options','Components','Locale','WoW11')
        for p in (ROOT/directory).rglob('*') if p.is_file()}
    (folder/'protected-before.json').write_bytes(encoded(protected))
    (folder/'authorization.json').write_bytes(encoded(auth))
    record={'status':'Rogue fit closure WIP installed; awaiting WoW reload and visual feedback',
        'clientDate':'2026-10-31','installedAtHostTime':datetime.now().astimezone().isoformat(),
        'backup':backup.relative_to(ROOT).as_posix(),'authorization':auth,
        'sourceGate':gate,'sourceReplay':replay,'candidateNumericalPassed':True,
        'productionAccepted':False,'representativeLiveApproved':False,'liveReloadPerformed':False,
        'liveRetailValidated':False,'liveForeverValidated':False,'nativeLayoutChanges':False,
        'runtimeLuaChanged':True,'runtimeChange':'Existing normal/ice fill path selects matching cosmetic floor only.',
        'scope':{'replacedTextures':6,'addedTextures':1,'runtimeFiles':sorted(RUNTIME)},
        'files':{p:{'beforeSha256':digest(before[p]) if before[p] is not None else None,
                    'installedSha256':digest(b)} for p,b in proposed.items()},
        'remaining':['WoW effective-scale sampling and dynamic icon/cooldown/proc rendering.',
                     'Normal/ice changing, partial resources and all cap/saved-nudge combinations in client.',
                     'Existing minimap/other tiers and outer crystal jaw contacts unchanged by this revision.',
                     'No representative live or whole-pack production approval.']}
    prior_checks={n:manifest.get('checks',{}).get(n) for n in NAMES}
    manifest.setdefault('historicalPreviewChecks',[]).append({'revision':'before-fit-closure','checks':prior_checks})
    for name in sorted(NAMES):
        manifest['assets'][name]={'path':'Assets/Rogue/'+name+'.tga',**draft['assets'][name]}
        manifest.setdefault('inventory',{})[name+'.tga']='Fit closure WIP; source checked, client review pending'
        manifest.setdefault('checks',{})[name]={'failures':[],'scope':'Current fit-closure source replay and static fit only; live unconfirmed'}
    manifest.update({'status':record['status'],'runtimeInstalled':True,'liveValidated':False,
        'productionAccepted':False,'sourceManifestSha256':sha(DRAFT/'manifest.json'),
        'representativeLivePreview':record,'fitClosure':{'sourceProofSha256':sha(DRAFT/'source-integrity.json'),
        'reviewManifest':auth['reviewManifest'],'candidateNumericalPassed':True},
        'metadataScope':'Earlier base-pack/sourceOverrides/visualRepair entries are historical. Current seven fit-closure exports and two minimal Lua changes are bound in fitClosure and representativeLivePreview. Whole-pack production acceptance remains absent.'})
    proposed[manifest_path]=encoded(manifest)
    written=[]
    try:
        for path,contents in proposed.items():
            target=ROOT/path
            assert (target.read_bytes() if target.exists() else None)==before[path],'Concurrent target change: '+path
            write_owned(target,contents);written.append(path)
            assert sha(target)==digest(contents)
        drift=[p for p,h in protected.items() if p not in targets and (not (ROOT/p).is_file() or sha(ROOT/p)!=h)]
        assert not drift,'Unrelated concurrent changes; refusing certification: '+str(drift)
        current={p.stem:sha(p) for p in (ROOT/'Assets/Rogue').glob('*.tga')}
        assert len(current)==79 and set(current)==set(prior)|{'pw_crystal_case-seat-wrath'}
        assert all(current[n]==h for n,h in prior.items() if n not in NAMES)
        assert all(current[n]==draft['assets'][n]['sha256'] for n in NAMES)
    except BaseException:
        for path in reversed(written):
            target=ROOT/path
            if target.exists() and sha(target)==digest(proposed[path]):
                if before[path] is None:target.unlink()
                else:write_owned(target,before[path])
        (folder/'FAILED-rollback.json').write_bytes(encoded({'backup':record['backup'],'status':'Restored unchanged owned writes only; inspect any concurrent changes.'}))
        raise
    record.update({'installedManifestSha256':sha(ROOT/manifest_path),'installedTgaCount':79,
                   'otherRogueTexturesUnchanged':72,'protectedExistingFilesChecked':len(protected),
                   'unrelatedExistingFilesUnchanged':True})
    (folder/'installed.json').write_bytes(encoded(record))
    (WORK/'live-preview-installed.json').write_bytes(encoded(record))
    print(json.dumps({k:record[k] for k in ('status','backup','scope','installedTgaCount','otherRogueTexturesUnchanged','unrelatedExistingFilesUnchanged')},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install-wip',action='store_true')
    if parser.parse_args().install_wip:install()
    else:
        validate()
        print('Frozen sources, current inputs, exact staged Lua and seven candidate exports pass preflight; no installation performed.')
