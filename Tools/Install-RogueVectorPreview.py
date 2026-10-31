"""Install only the maintainer-approved V2 representative for live review.

Explicit WIP path, never production acceptance or a waiver of the production
guard. Backs up all changed files and leaves 74 other Rogue textures untouched.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import uuid

from ThemeSourceIntegrity import checked_file, verify_pack

ROOT = Path(__file__).resolve().parent.parent
DRAFT = ROOT/'Assets_Draft/Rogue-Vector-Repair-v2-2026-10-30'
WORK = ROOT/'Docs/Research_Assets/Rogue/Vector-Repair-v2-2026-10-30'
TARGET = ROOT/'Assets/Rogue'
NAMES = ('hp_cap_case','hp_cap_case-over','pw_crystal_case')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')


def validate():
    result = verify_pack(DRAFT)
    approval_path = WORK/'maintainer-visual-review.json'
    approval = json.loads(approval_path.read_text(encoding='utf-8'))
    assert approval['maintainerVisualApproved'] is True
    for key in ('assetManifestSha256','sourceIntegritySha256'):
        assert approval[key] == result[key], 'Stale V2 approval: '+key
    for record in approval['evidence'].values():
        checked_file(record)
    for name,digest in approval['sourceConstruction'].items():
        assert sha(WORK/'Sources'/name) == digest
    for choice,digest in approval['referencedEndcaps'].items():
        assert sha(TARGET/('ornament-'+choice+'-hp_cap_case.tga')) == digest
    assets = json.loads((DRAFT/'manifest.json').read_text())['assets']
    assert set(assets) == set(NAMES), 'Only the three approved representative exports may install'
    return assets, approval_path, result


def install():
    assets, approval_path, proof = validate()
    manifest_path = TARGET/'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    prior = {p.name:sha(p) for p in TARGET.glob('*.tga')}
    assert len(prior) == 77
    for name,item in manifest['assets'].items():
        assert prior[name+'.tga'] == item['sha256'], 'Installed manifest drift: '+name
    runtime_paths = [ROOT/p for p in ('Core/RogueTheme.lua','Core/ThemeEffects.lua','Components/UnitFrames/Units/Player.lua')]
    runtime = {p:sha(p) for p in runtime_paths}
    record_dir = WORK/('Live-Preview-'+uuid.uuid4().hex[:8])
    backup = record_dir/'Before'
    backup.mkdir(parents=True)
    changed = [name+'.tga' for name in NAMES]+['manifest.json']
    for name in changed:
        shutil.copyfile(TARGET/name,backup/name)
    authorization = 'Installer den in-game sammen med den nye casing'
    record = {'userAuthorization':authorization,'status':'explicitly authorized representative WIP live preview',
        'approvalSha256':sha(approval_path), **proof,
        'backup':backup.relative_to(ROOT).as_posix(),
        'productionAccepted':False,'liveRetailValidated':False,'liveForeverValidated':False,
        'files':{name:{'beforeSha256':prior[name+'.tga'],'installedSha256':assets[name]['sha256']} for name in NAMES}}
    try:
        for name in NAMES:
            shutil.copyfile(DRAFT/(name+'.tga'),TARGET/(name+'.tga'))
            manifest['assets'][name].update(assets[name])
        manifest.update({'status':'Rogue V2 representative WIP live preview installed; client confirmation pending',
            'runtimeInstalled':True,'liveValidated':False,'productionAccepted':False,
            'representativeLivePreview':record})
        write(manifest_path,manifest)
        for name,digest in prior.items():
            expected = assets[Path(name).stem]['sha256'] if Path(name).stem in NAMES else digest
            assert sha(TARGET/name) == expected, 'Installed verification failed: '+name
        for path,digest in runtime.items():
            assert sha(path) == digest, 'Runtime changed during install: '+str(path)
    except BaseException:
        for name in changed:
            shutil.copyfile(backup/name,TARGET/name)
        raise
    record.update({'installedTextureHashesVerified':77,'otherRogueTexturesUnchanged':74,
                   'runtimeFilesUnchanged':True,'installedManifestSha256':sha(manifest_path)})
    write(record_dir/'installed.json',record)
    write(WORK/'live-preview-installed.json',record)
    print('Installed approved V2 health back/front and whole crystal holder. 77 hashes verified, 74 textures unchanged.')
    print('Backup: '+str(backup))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install',action='store_true',help='Perform the explicitly requested WIP live install')
    args = parser.parse_args()
    if args.install:
        install()
    else:
        validate()
        print('Approved representative verified; no files installed. Use --install for the requested live test.')
