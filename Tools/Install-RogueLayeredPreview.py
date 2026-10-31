"""Install the explicitly authorized layered Rogue WIP preview, with backup.

This is separate from production acceptance. It preserves the frozen review,
all native/saved geometry and every other Rogue texture. No build/regeneration.
"""
from pathlib import Path
import argparse
from datetime import datetime
import difflib
import hashlib
import json
import shutil
import uuid

from RogueLayeredContract import verify_layered_pack
from ThemeSourceIntegrity import checked_file

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Layered-Rebuild-2026-10-30'
DRAFT = ROOT / 'Assets_Draft/Rogue-Layered-Rebuild-2026-10-30'
RUNTIME = ('Core/RogueTheme.lua', 'Core/ThemeEffects.lua')
TEXTURES = ('hp_cap_case-over', 'pw_crystal_case-seat')
AUTHORIZATION = 'Så få den live please.'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha(path):
    return digest(path.read_bytes())


def data(path):
    return json.loads(path.read_text(encoding='utf-8'))


def encoded(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode('utf-8')


def write_owned(target, contents):
    assert target.resolve().is_relative_to(ROOT.resolve())
    temporary = target.with_name(target.name + '.rogue-live-' + uuid.uuid4().hex + '.tmp')
    try:
        with temporary.open('xb') as stream:
            stream.write(contents)
        temporary.replace(target)
    finally:
        if temporary.exists():
            temporary.unlink()


def validate():
    authorization = data(WORK / 'live-preview-authorization.json')
    assert authorization['userAuthorization'] == AUTHORIZATION and authorization['livePreviewAuthorized'] is True
    for key, path in (('reviewManifestSha256', WORK / 'review-manifest.json'),
                      ('assetManifestSha256', DRAFT / 'manifest.json'),
                      ('sourceIntegritySha256', DRAFT / 'source-integrity.json'),
                      ('runtimePatchSha256', WORK / 'Runtime/RogueCrystalSeat-review.patch')):
        assert authorization[key] == sha(path), 'Stale live-preview authorization: ' + key
    review_manifest = data(WORK / 'review-manifest.json')
    for path, expected in review_manifest['files'].items():
        checked_file({'path': path, 'sha256': expected}, ROOT)
    proof = verify_layered_pack(DRAFT, WORK, ROOT)
    review = data(WORK / 'review.json')
    current = {path: (ROOT / path).read_bytes() for path in RUNTIME}
    for path, contents in current.items():
        assert digest(contents) == review['runtimeProposal']['baseline'][path], 'Runtime changed since reviewed patch: ' + path
    body = (WORK / 'Runtime/RogueCrystalSeat.lua').read_text().split('-- BEGIN INTEGRATION\n', 1)[1].split('-- END INTEGRATION', 1)[0]
    proposed, patch = {}, ''
    for path, contents in current.items():
        newline = b'\r\n' if contents.count(b'\r\n') > contents.count(b'\n') / 2 else b'\n'
        if path == 'Core/RogueTheme.lua':
            anchor = b'Theme.RefreshEndcaps = function(self)'
            insert = body.replace('\n', newline.decode()).encode() + newline + anchor
        else:
            anchor = b'\tLiftCap(power, power.Case)' + newline
            insert = newline.join((b'\tlocal rogue = ns.RogueTheme',
                b'\tif (rogue and rogue.StyleCrystal) then rogue:StyleCrystal(power, casePath, useMage) end')) + newline + anchor
        assert contents.count(anchor) == 1, 'Ambiguous patch anchor: ' + path
        proposed[path] = contents.replace(anchor, insert, 1)
        before_text = contents.decode().replace('\r\n', '\n')
        after_text = proposed[path].decode().replace('\r\n', '\n')
        patch += ''.join(difflib.unified_diff(before_text.splitlines(True), after_text.splitlines(True),
                                            fromfile='a/' + path, tofile='b/' + path))
    assert patch == (WORK / 'Runtime/RogueCrystalSeat-review.patch').read_text(), 'Projected edit differs from reviewed patch'
    manifest_path = ROOT / 'Assets/Rogue/manifest.json'
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    prior = {p.stem: sha(p) for p in (ROOT / 'Assets/Rogue').glob('*.tga')}
    assert len(prior) == 77 and set(prior) == set(manifest['assets']), 'Unexpected installed inventory'
    for name, expected in prior.items():
        assert manifest['assets'][name]['sha256'] == expected, 'Installed asset manifest drift: ' + name
    draft_assets = data(DRAFT / 'manifest.json')['assets']
    assert set(draft_assets) == {'hp_cap_case', 'hp_cap_case-over', 'pw_crystal_case', 'pw_crystal_case-seat'}
    assert not (ROOT / 'Assets/Rogue/pw_crystal_case-seat.tga').exists(), 'Preview floor already installed'
    for name in ('hp_cap_case', 'pw_crystal_case'):
        assert draft_assets[name]['sha256'] == prior[name], 'Unchanged review layer differs: ' + name
    for name in TEXTURES:
        proposed['Assets/Rogue/' + name + '.tga'] = (DRAFT / (name + '.tga')).read_bytes()
    baseline = {path: digest(contents) for path, contents in current.items()}
    baseline.update({'Assets/Rogue/manifest.json': digest(manifest_bytes),
                     'Assets/Rogue/hp_cap_case-over.tga': prior['hp_cap_case-over'],
                     'Assets/Rogue/pw_crystal_case-seat.tga': None})
    return authorization, proof, manifest, prior, proposed, baseline


def install():
    authorization, proof, manifest, prior, proposed, baseline = validate()
    stamp = datetime.now().astimezone().strftime('%Y%m%d-%H%M%S')
    record_dir = WORK / ('Live-Preview-' + stamp + '-' + uuid.uuid4().hex[:8])
    backup = record_dir / 'Before'
    backup.mkdir(parents=True)
    manifest_relative = 'Assets/Rogue/manifest.json'
    paths = list(proposed) + [manifest_relative]
    before = {name: (ROOT / name).read_bytes() if (ROOT / name).exists() else None for name in paths}
    assert all((digest(contents) if contents is not None else None) == baseline[name]
               for name, contents in before.items()), 'Target changed after validation; no runtime writes performed'
    for name, contents in before.items():
        if contents is not None:
            target = backup / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contents)
            assert sha(target) == digest(contents), 'Backup verification failed: ' + name
    shutil.copyfile(WORK / 'live-preview-authorization.json', record_dir / 'authorization.json')
    protected = {p.relative_to(ROOT).as_posix(): sha(p) for folder in ('Assets', 'Core', 'Layouts', 'Options')
                 for p in (ROOT / folder).rglob('*') if p.is_file()}
    (record_dir / 'protected-before.json').write_bytes(encoded(protected))
    record = {'status': 'authorized WIP live preview installed; awaiting client reload and visual test',
              'userAuthorization': AUTHORIZATION, 'installedAt': datetime.now().astimezone().isoformat(),
              'installerSha256': sha(Path(__file__)),
              'backup': backup.relative_to(ROOT).as_posix(), 'authorization': authorization,
              'reviewManifestSha256': sha(WORK / 'review-manifest.json'), 'numericSourceLayerProof': proof,
              'nativeLayoutChanges': False, 'productionAccepted': False, 'maintainerVisualApproved': False,
              'representativeLiveApproved': False, 'liveReloadPerformed': False,
              'liveRetailValidated': False, 'liveForeverValidated': False,
              'files': {name: {'beforeSha256': digest(before[name]) if before[name] is not None else None,
                               'installedSha256': digest(contents)} for name, contents in proposed.items()},
              'previouslyAbsent': [name for name, contents in before.items() if contents is None]}
    draft_assets = data(DRAFT / 'manifest.json')['assets']
    for name in TEXTURES:
        manifest['assets'][name] = {'path': 'Assets/Rogue/' + name + '.tga', **draft_assets[name]}
    manifest.update({'status': record['status'], 'runtimeInstalled': True, 'liveValidated': False,
                     'productionAccepted': False, 'representativeLivePreview': record,
                     'supplementalRuntimeMedia': ['pw_crystal_case-seat']})
    proposed[manifest_relative] = encoded(manifest)
    written = []
    try:
        for name, contents in proposed.items():
            target = (ROOT / name).resolve()
            assert target.is_relative_to(ROOT.resolve())
            actual = target.read_bytes() if target.exists() else None
            assert actual == before[name], 'Concurrent target edit; stop: ' + name
            write_owned(target, contents)
            written.append(name)
            assert sha(target) == digest(contents), 'Installed bytes differ: ' + name
        drift = [name for name, expected in protected.items() if name not in proposed
                 and (not (ROOT / name).is_file() or sha(ROOT / name) != expected)]
        assert not drift, 'Unrelated concurrent drift; installation not certified: ' + str(drift)
        for name, expected in prior.items():
            assert sha(ROOT / 'Assets/Rogue' / (name + '.tga')) == (draft_assets[name]['sha256'] if name in TEXTURES else expected)
        assert {p.stem for p in (ROOT / 'Assets/Rogue').glob('*.tga')} == set(prior) | {'pw_crystal_case-seat'}
    except BaseException:
        for name in reversed(written):
            target = ROOT / name
            if target.exists() and sha(target) == digest(proposed[name]):
                if before[name] is None:
                    target.unlink()
                else:
                    write_owned(target, before[name])
        (record_dir / 'FAILED-rollback.json').write_bytes(encoded({'status': 'install failed; restored owned writes when unchanged', 'backup': record['backup']}))
        raise
    record.update({'installedManifestSha256': sha(ROOT / manifest_relative), 'installedTgaCount': 78,
                   'previousRogueTexturesUnchanged': 76, 'protectedExistingFilesChecked': len(protected),
                   'unrelatedExistingFilesUnchanged': True})
    (record_dir / 'installed.json').write_bytes(encoded(record))
    (WORK / 'live-preview-installed.json').write_bytes(encoded(record))
    print(json.dumps({key: record[key] for key in ('status', 'backup', 'installedTgaCount',
                     'previousRogueTexturesUnchanged', 'unrelatedExistingFilesUnchanged')}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    if args.install:
        install()
    else:
        validate()
        print('Frozen review, source/layer checks and exact runtime patch verified. No installation performed.')
