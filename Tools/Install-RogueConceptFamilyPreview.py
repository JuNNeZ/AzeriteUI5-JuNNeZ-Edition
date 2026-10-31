"""Install only the four explicitly requested V3 WIP textures, with backup.

Known failed fit is retained as evidence. No production gate is weakened and no
painting, runtime code, native fill or saved placement is edited by this tool.
"""
from pathlib import Path
from datetime import datetime
import argparse
import hashlib
import json
import uuid

from RogueFamilySource import NAMES, validate as replay, validate_composites
from ThemeSourceIntegrity import checked_file, read, verify_pixels, whole_painting, verify_pack

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Concept-Family-2026-10-31'
DRAFT = ROOT / 'Assets_Draft/Rogue-Concept-Family-v3-2026-10-31'
AUTHORIZATION = 'Fedt, gør dem live.'


def digest(contents):
    return hashlib.sha256(contents).hexdigest()


def sha(path):
    return digest(path.read_bytes())


def data(path):
    return json.loads(path.read_text(encoding='utf-8'))


def encoded(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode('utf-8')


def write_owned(path, contents):
    assert path.resolve().is_relative_to(ROOT.resolve())
    temporary = path.with_name(path.name + '.rogue-family-' + uuid.uuid4().hex + '.tmp')
    try:
        with temporary.open('xb') as stream:
            stream.write(contents)
        temporary.replace(path)
    finally:
        if temporary.exists():
            temporary.unlink()


def validate():
    auth = data(WORK / 'live-preview-authorization.json')
    assert auth['userAuthorization'] == AUTHORIZATION and auth['livePreviewAuthorized'] is True
    assert auth['revision'] == 3 and set(auth['textures']) == NAMES
    assert auth['installerSha256'] == sha(Path(__file__)), 'Installer changed after authorization snapshot'
    assert auth['productionAccepted'] is False and auth['knownFitFailuresAcknowledged'] is True
    targets = {'Assets/Rogue/' + n + '.tga' for n in NAMES} | {'Assets/Rogue/manifest.json'}
    assert set(auth['liveTargetsBefore']) == targets
    for path, expected in auth['liveTargetsBefore'].items():
        assert sha(ROOT / path) == expected, 'Live target changed after authorization snapshot: ' + path
    for path, expected in auth['frozenFiles'].items():
        checked_file({'path': path, 'sha256': expected}, ROOT)
    frozen = data(WORK / 'review-manifest.json')
    for path, expected in frozen['tools'].items():
        checked_file({'path': path, 'sha256': expected}, ROOT)
    review = data(checked_file(frozen['revisions']['v3']['review'], ROOT))
    construction = data(checked_file(frozen['revisions']['v3']['sourceConstruction'], ROOT))
    for name, expected in review['images'].items():
        assert sha(WORK / 'Reviews/v3' / name) == expected, 'Preview changed: ' + name
    assert sha(ROOT / 'Tools/RogueFamilySource.py') == construction['validatorSha256']
    proof = replay(construction['recipe'], construction['grounding'],
                   {n: checked_file(p, ROOT) for n, p in construction['rawParts'].items()},
                   {n: checked_file(p, ROOT) for n, p in construction['sources'].items()}, ROOT)
    proof.update(validate_composites(construction['functionalComposites'], ROOT))
    draft = data(DRAFT / 'manifest.json')
    integrity = data(DRAFT / 'source-integrity.json')
    assert set(draft['assets']) == NAMES | {'hp_cap_case'}
    assert integrity['assetManifestSha256'] == sha(DRAFT / 'manifest.json')
    assert draft['numericalPassed'] is False and review['numericalPassed'] is False
    proposed = {}
    for name in sorted(NAMES):
        file = DRAFT / (name + '.tga')
        assert sha(file) == draft['assets'][name]['sha256'] == auth['textures'][name]
        entry = integrity['paintings'][name]
        source = checked_file(entry['source'], ROOT)
        assert entry['source'] == construction['functionalComposites'][name]['completeSource']
        expected = whole_painting(read(source), entry['transform'], tuple(draft['assets'][name]['canvas']))
        verify_pixels(expected, read(file))
        assert expected.tobytes() == read(file).tobytes(), 'TGA RGBA changed: ' + name
        proposed['Assets/Rogue/' + name + '.tga'] = file.read_bytes()
    try:
        verify_pack(DRAFT)
    except ValueError as error:
        assert str(error) == review['exportSourceGate']['reason'], 'Unexpected source failure'
        proof['knownSourceFitFailure'] = str(error)
    else:
        raise AssertionError('Frozen failing source result changed; review before installation')
    manifest = data(ROOT / 'Assets/Rogue/manifest.json')
    prior = {p.stem: sha(p) for p in (ROOT / 'Assets/Rogue').glob('*.tga')}
    assert len(prior) == 78 and set(prior) == set(manifest['assets']), 'Unexpected live inventory'
    for name, expected in prior.items():
        assert manifest['assets'][name]['sha256'] == expected, 'Installed manifest drift: ' + name
    assert prior['hp_cap_case'] == draft['assets']['hp_cap_case']['sha256'], 'Unchanged health back differs'
    # The reviewed scene includes this existing layer and these runtime mappings.
    baseline = data(WORK / 'input-lock.json')
    relevant = {p: h for p, h in baseline.items() if p.startswith(('Assets/Rogue/', 'Layouts/')) or p in (
        'Core/RogueTheme.lua', 'Core/ThemeEngine.lua', 'Core/ThemeEffects.lua')}
    for path, expected in relevant.items():
        assert sha(ROOT / path) == expected, 'Reviewed runtime/art changed: ' + path
    return auth, review, construction, proof, draft, manifest, prior, proposed


def install():
    auth, review, construction, proof, draft, manifest, prior, proposed = validate()
    stamp = datetime.now().astimezone().strftime('%Y%m%d-%H%M%S')
    folder = WORK / ('Live-Preview-' + stamp + '-' + uuid.uuid4().hex[:8])
    backup = folder / 'Before'
    backup.mkdir(parents=True)
    manifest_name = 'Assets/Rogue/manifest.json'
    before = {p: (ROOT / p).read_bytes() for p in [*proposed, manifest_name]}
    assert {p: digest(b) for p, b in before.items()} == auth['liveTargetsBefore'], 'Live targets changed before backup'
    for path, contents in before.items():
        target = backup / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(contents)
        assert sha(target) == digest(contents), 'Backup differs: ' + path
    protected = {p.relative_to(ROOT).as_posix(): sha(p)
                 for name in ('Assets', 'Core', 'Layouts', 'Options', 'Components', 'Locale', 'WoW11')
                 for p in (ROOT / name).rglob('*') if p.is_file()}
    (folder / 'protected-before.json').write_bytes(encoded(protected))
    (folder / 'authorization.json').write_bytes(encoded(auth))
    record = {'status': 'explicit V3 WIP live preview installed; known fit failures; awaiting client reload/test',
              'userAuthorization': AUTHORIZATION, 'clientDate': '2026-10-31',
              'installedAtHostTime': datetime.now().astimezone().isoformat(),
              'installerSha256': sha(Path(__file__)), 'revision': 3,
              'backup': backup.relative_to(ROOT).as_posix(), 'authorization': auth,
              'sourceReplay': proof, 'numericalPassed': False, 'sourceFitAccepted': False,
              'productionAccepted': False, 'maintainerVisualApproved': False, 'representativeLiveApproved': False,
              'liveReloadPerformed': False, 'liveRetailValidated': False, 'liveForeverValidated': False,
              'nativeLayoutChanges': False, 'runtimeLuaChanged': False,
              'knownFailures': {'sourceGates': review['sourceGates'], 'capGate': review['capGate'],
                                'exportSourceGate': review['exportSourceGate']},
              'files': {p: {'beforeSha256': digest(before[p]), 'installedSha256': digest(contents)}
                        for p, contents in proposed.items()}}
    for name in sorted(NAMES):
        manifest['assets'][name] = {'path': 'Assets/Rogue/' + name + '.tga', **draft['assets'][name]}
        failures = list(review['sourceGates'][name]['nativeGeometryErrors'])
        if not review['sourceGates'][name].get('aperture', {}).get('passed', True):
            failures.append(review['sourceGates'][name]['aperture']['reason'])
        if name == 'hp_cap_case-over':
            failures.append('Original terminal paint missing beyond AA: ' + str(review['capGate']['missingOriginalTerminalPixelsBeyondAA']))
        manifest['checks'][name] = {'failures': failures, 'lookNotes': ['V3 WIP live preview; production acceptance absent']}
        manifest['inventory'][name + '.tga'] = 'concept-family V3 WIP; known fit failures; live review pending'
    manifest.update({'status': record['status'], 'runtimeInstalled': True, 'liveValidated': False,
                     'productionAccepted': False, 'numericalPassed': False, 'nativeLayoutChanges': False,
                     'sourceManifestSha256': sha(DRAFT / 'manifest.json'), 'representativeLivePreview': record,
                     'sourceOverrides': construction['functionalComposites'],
                     'metadataScope': 'Base pack sources/generation/visualRepair fields are historical. Four current overrides and failures are recorded in representativeLivePreview, sourceOverrides and checks.'})
    proposed[manifest_name] = encoded(manifest)
    written = []
    try:
        for path, contents in proposed.items():
            target = ROOT / path
            assert target.read_bytes() == before[path], 'Concurrent target change: ' + path
            write_owned(target, contents)
            written.append(path)
            assert sha(target) == digest(contents), 'Installed bytes differ: ' + path
        drift = [p for p, expected in protected.items() if p not in proposed and
                 (not (ROOT / p).is_file() or sha(ROOT / p) != expected)]
        assert not drift, 'Unrelated concurrent change; installation not certified: ' + str(drift)
        assert {p.stem for p in (ROOT / 'Assets/Rogue').glob('*.tga')} == set(prior)
        for name, expected in prior.items():
            assert sha(ROOT / 'Assets/Rogue' / (name + '.tga')) == (auth['textures'][name] if name in NAMES else expected)
    except BaseException:
        for path in reversed(written):
            target = ROOT / path
            if target.exists() and sha(target) == digest(proposed[path]):
                write_owned(target, before[path])
        (folder / 'FAILED-rollback.json').write_bytes(encoded({'status': 'failed; restored owned writes when still unchanged', 'backup': record['backup']}))
        raise
    record.update({'installedManifestSha256': sha(ROOT / manifest_name), 'installedTgaCount': len(prior),
                   'otherRogueTexturesUnchanged': len(prior) - len(NAMES),
                   'protectedExistingFilesChecked': len(protected), 'unrelatedExistingFilesUnchanged': True})
    (folder / 'installed.json').write_bytes(encoded(record))
    (WORK / 'live-preview-installed.json').write_bytes(encoded(record))
    print(json.dumps({k: record[k] for k in ('status', 'backup', 'installedTgaCount',
          'otherRogueTexturesUnchanged', 'unrelatedExistingFilesUnchanged')}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true')
    if parser.parse_args().install:
        install()
    else:
        validate()
        print('V3 frozen source/image replay and live target inventory verified; known fit failures retained; no install.')
