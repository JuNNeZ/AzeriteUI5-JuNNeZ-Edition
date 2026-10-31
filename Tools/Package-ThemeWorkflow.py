"""Build Mesph's local workflow handoff; no runtime changes or release actions.

Run from any directory: python Tools/Package-ThemeWorkflow.py
The archive includes only the explicit allowlist below, never local configs,
credentials, SavedVariables, unrelated drafts or the full research history.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT/'Tools/ThemeWorkflowKit'
OUT = ROOT/'Docs/Research_Assets/Mesph-ThemeWorkflow-2026-10-27'
NAME = 'AzeriteUI-Theme-Workflow-Mesph-2026-10-27'

VERIFY = '''"""Verify delivered payload hashes before making edits; standard library only."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent
manifest = json.loads((root/'PACKAGE-MANIFEST.json').read_text(encoding='utf-8'))
for relative, item in manifest['files'].items():
    path = (root/relative).resolve()
    if not path.is_relative_to(root) or not path.is_file():
        raise SystemExit('FAIL: missing/unsafe path '+relative)
    data = path.read_bytes()
    if len(data) != item['bytes'] or hashlib.sha256(data).hexdigest() != item['sha256']:
        raise SystemExit('FAIL: changed file '+relative)
print('PASS:', len(manifest['files']), 'payload files; visual and live acceptance remain separate')
'''


def main():
    payload = {}

    def add(path, destination=None):
        if not path.is_file():
            raise FileNotFoundError(path)
        name = destination or path.relative_to(ROOT).as_posix()
        if name in payload:
            raise ValueError('duplicate payload path: '+name)
        payload[name] = path.read_bytes()

    for name in ('START-HERE.md', 'AI-START-PROMPT.md'):
        add(SOURCE/name, name)
    for name in ('BRIEF.md', 'EVIDENCE.md', 'provenance-template.json'):
        add(SOURCE/name, 'Templates/'+name)
    add(SOURCE/'warrior-shared-casings.json', 'Examples/Warrior/shared-casings.json')
    add(SOURCE/'Check-ThemeDraft.py', 'Tools/Check-ThemeDraft.py')
    for name in ('Theme Asset Production Workflow.md', 'Theme Asset Style Key.md',
                 'Theme Asset Fitting Checklist.md', 'Theme Concept Sheet Guide.md',
                 'Theme Asset Geometry.json', 'Theme Engine Plan.md'):
        add(ROOT/'Docs'/name)
    for name in ('ThemeAssetWorkflow.md', 'Export-ThemeGeometry.py',
                 'Build-ThemeConceptBase.py', 'Check-ThemeAssetStyle.py',
                 'ThemeHealthEndcaps.py', 'ThemeOrbGlass.py', 'ThemeButtonShapes.py',
                 'PaladinFillContracts.py', 'ThemeSourceIntegrity.py'):
        add(ROOT/'Tools'/name)
    add(ROOT/'Docs/Theme Source Integrity.md')
    for path in sorted((ROOT/'Tools/Tests/ThemeSourceIntegrity').rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts:
            add(path)
    for folder in ('Assets', 'Assets/Warrior', 'Assets/Druid'):
        for path in sorted((ROOT/folder).iterdir()):
            if path.is_file() and path.suffix.lower() in ('.tga', '.json', '.md'):
                add(path)
    templates = ROOT/'Docs/Research_Assets/Templates'
    for path in sorted(templates.glob('*.png')):
        add(path)
    for relative in ('Docs/Research_Assets/Paladin/Revision5/layouts.json',
                     'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/layouts.json',
                     'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json'):
        add(ROOT/relative)
    for relative in ('Core/ThemeEngine.lua', 'Core/WarriorTheme.lua',
                     'Core/ThemeEffects.lua', 'Core/Core.xml', 'Core/Common/Colors.lua',
                     'Options/OptionsPages/Themes.lua',
                     'Components/UnitFrames/Units/Player.lua',
                     'Components/UnitFrames/Units/Target.lua',
                     'Components/UnitFrames/Units/PlayerCastBar.lua',
                     'LICENSE', 'LICENSE.txt'):
        add(ROOT/relative)
    for path in sorted((ROOT/'Layouts').rglob('*')):
        if path.is_file() and path.suffix in ('.lua', '.xml'):
            add(path)
    for name in ('brief.md', 'approved-concept.png'):
        add(ROOT/'Docs/Research_Assets/Warrior'/name, 'Examples/Warrior/'+name)

    # Include a real whole painting, its exact prompt and its actual image inputs.
    # Keep machine-specific original provenance intact and add portable copies.
    provenance = ROOT/'Docs/Research_Assets/Warrior/Live-Repair-2026-10-18/Sources/cast-reference-pass.json'
    add(provenance, 'Examples/Warrior/SourceJob/provenance-original.json')
    add(provenance.with_suffix('.png'), 'Examples/Warrior/SourceJob/output.png')
    job = json.loads(provenance.read_text(encoding='utf-8'))
    portable = {'status': 'historical-example-not-new-approval', 'prompt': job['prompt'], 'inputs': []}
    for index, reference in enumerate(job['refs']):
        path = Path(reference)
        if not path.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError('example input outside checkout')
        name = f'Examples/Warrior/SourceJob/input-{index+1}{path.suffix}'
        add(path, name)
        portable['inputs'].append({'path': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    portable['output'] = {'path': 'Examples/Warrior/SourceJob/output.png',
                          'sha256': hashlib.sha256(provenance.with_suffix('.png').read_bytes()).hexdigest()}
    payload['Examples/Warrior/SourceJob/portable-provenance.json'] = (json.dumps(portable, indent=2)+'\n').encode()
    payload['Verify-Package.py'] = VERIFY.encode()
    payload['requirements.txt'] = b'Pillow>=10.0,<12\nnumpy>=1.23,<3\n'

    geometry = json.loads(payload['Docs/Theme Asset Geometry.json'])
    import csv
    import io
    stream = io.StringIO(newline='')
    writer = csv.writer(stream)
    writer.writerow(('native_file', 'disposition', 'reason', 'export_path', 'source_path', 'notes'))
    for name in sorted(payload):
        if name.startswith('Assets/') and name.count('/') == 1 and name.endswith('.tga'):
            writer.writerow((name, 'TODO', 'TODO replace/shared/not-applicable', '', '',
                             'measured casing' if Path(name).stem in geometry else 'inventory required'))
    payload['Templates/inventory.csv'] = stream.getvalue().encode('utf-8')
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    status = subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)
    manifest = {'name': NAME, 'date': '2026-10-27', 'baseCommit': revision,
                'workingTreeDirty': bool(status.strip()),
                'snapshot': 'allowlisted working-tree bytes, including local modifications; hashes are authoritative',
                'kind': 'workflow-kit-not-addon-or-accepted-theme',
                'liveRetailValidated': False, 'liveForeverValidated': False,
                'files': {name: {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
                          for name, data in sorted(payload.items())}}
    payload['PACKAGE-MANIFEST.json'] = (json.dumps(manifest, indent=2)+'\n').encode()
    OUT.mkdir(parents=True, exist_ok=True)
    archive_path = OUT/(NAME+'.zip')
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, data in sorted(payload.items()):
            archive.writestr(name, data)
    with zipfile.ZipFile(archive_path) as archive:
        if archive.testzip() is not None:
            raise RuntimeError('ZIP CRC failed')
        if len(archive.namelist()) != len(payload):
            raise RuntimeError('ZIP file count mismatch')
        for name, data in payload.items():
            if archive.read(name) != data:
                raise RuntimeError('ZIP content mismatch: '+name)
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    (OUT/(NAME+'.sha256')).write_text(digest+'  '+archive_path.name+'\n', encoding='ascii')
    report = {'archive': archive_path.name, 'bytes': archive_path.stat().st_size,
              'files': len(payload), 'payloadHashesVerified': len(manifest['files']),
              'zipCrcPassed': True, 'sha256': digest, 'liveValidated': False}
    (OUT/'package-report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    (OUT/'START-HERE.md').write_bytes(payload['START-HERE.md'])
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
