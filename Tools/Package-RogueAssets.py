"""Package Rogue sources/art/evidence locally; this is not an addon release."""
from pathlib import Path
import importlib.util
import json
import zipfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('rogue_package_checks', ROOT/'Tools/Check-RogueAssets.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)
manifest = C.check()
C.verify_review()
installed = C.data(ROOT/'Assets/Rogue/manifest.json')
assert installed['sourceManifestSha256'] == C.sha(C.OUT/'manifest.json')
for name, item in manifest['assets'].items():
    assert C.sha(ROOT/'Assets/Rogue'/(name+'.tga')) == item['sha256']

# Sources, exact generation prompts, frozen masks and rejected fixtures travel
# with accepted exports; reproducing uses the documented existing checkout.
files = {p for folder in (C.WORK, C.OUT, ROOT/'Assets/Rogue') for p in folder.rglob('*') if p.is_file()}
files.update((ROOT/'Tools').glob('*.py'))
files.update(ROOT/name for name in ('Tools/Harness/rogue_theme_harness.lua', 'Tools/Run-Elune.ps1',
    'Core/RogueTheme.lua', 'Core/Core.xml', 'Core/ThemeEffects.lua', 'Core/ThemeEngine.lua',
    'Core/LegacyHUD.lua', 'Options/OptionsPages/Themes.lua', 'FixLog.md', 'AGENTS.md',
    'Docs/Theme Asset Geometry.json', 'Docs/Theme Asset Production Workflow.md',
    'Docs/Theme Asset Fitting Checklist.md', 'Docs/Theme Asset Style Key.md'))
files.update(p for p in (ROOT/'Docs/Research_Assets/Templates').glob('*') if p.is_file())
files.add(ROOT/'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json')
path = ROOT/'Docs/Research_Assets/Rogue-local-handoff.zip'
with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for source in sorted(files):
        if '__pycache__' not in source.parts:
            archive.write(source, source.relative_to(ROOT).as_posix())
with zipfile.ZipFile(path) as archive:
    assert archive.testzip() is None
    for name, item in manifest['assets'].items():
        assert C.hashlib.sha256(archive.read('Assets/Rogue/'+name+'.tga')).hexdigest() == item['sha256']
    entries = len(archive.infolist())
record = {'path': path.relative_to(ROOT).as_posix(), 'sha256': C.sha(path),
          'bytes': path.stat().st_size, 'entries': entries, 'crcVerified': True,
          'runtimeTexturesVerified': 77, 'addonRelease': False, 'liveValidated': False}
C.save(ROOT/'Docs/Research_Assets/Rogue-local-handoff.json', record)
print(json.dumps(record, indent=2))
