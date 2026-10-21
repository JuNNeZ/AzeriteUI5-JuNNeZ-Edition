"""Archive Warrior sources, staged exports and offline reproduction evidence.

This is an art handoff/backup, not a release ZIP or standalone addon.
The existing addon checkout/native assets are required for rebuilding.
"""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Warrior'
OUT = ROOT/'Assets_Draft/Warrior'
ARCHIVE = WORK/'Warrior-assets-2026-10-18.zip'
TOOLS = ('Build-WarriorAssets.py','Check-WarriorAssets.py','Render-WarriorAssets.py',
         'Package-WarriorAssets.py','ThemeHealthEndcaps.py','ThemeAssetWorkflow.md',
         'Build-DruidArt.py','Build-RebuiltHealthArt.py','ThemeOrbGlass.py',
         'ThemeButtonShapes.py','PaladinFillContracts.py','Check-ThemeAssetStyle.py',
         'Build-ImplementedThemeSheets.py','Build-ThemeConceptBase.py')
TOOLS += ('Prepare-WarriorEndcapRepair.py','Repair-WarriorFit.py','Audit-WarriorFit.py',
          'Install-WarriorAssets.py','Check-WarriorIntegration.py')


def main():
    manifest = json.loads((OUT/'manifest.json').read_text())
    acceptance = json.loads((WORK/'acceptance.json').read_text())
    assert acceptance['geometryFailures']==0 and not acceptance['liveValidated']
    manifest_hash=hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest()
    assert acceptance.get('assetManifestSha256')==manifest_hash,'stale numerical acceptance; rerun current exported-file checks'
    assert acceptance.get('maxExposedTerminalPixelsBeyondAA')==0,'full-terminal coverage has not passed'
    visual=json.loads((WORK/'visual-review.json').read_text())
    assert visual.get('assetManifestSha256')==manifest_hash and visual.get('agentOfflineVisualReview')=='passed','missing/stale separate offline visual review'
    required={'Warrior-endcaps-1x.png','Warrior-health-tiers.png','Warrior-terminal-before-after.png'}
    required.update('Warrior-'+key+'-2x.png' for key in ('stromkar','warswords','wrath'))
    if manifest.get('fitRevision'):
        required.update(('Warrior-live-repair.png','Warrior-cast-defaults.png'))
        assert acceptance['liveFeedbackRevision']['geometryFailures']==0,'live feedback revision not verified'
    assert required<=visual['evidence'].keys(),'visual review must cover all complete-bar evidence'
    for name,digest in visual['evidence'].items():
        assert hashlib.sha256((WORK/name).read_bytes()).hexdigest()==digest,'stale visual evidence '+name
    paths = set(p for p in OUT.rglob('*') if p.is_file())
    paths.update(p for p in WORK.rglob('*') if p.is_file() and p.suffix!='.zip' and p.name!='bundle-report.json')
    paths.update(ROOT/'Tools'/name for name in TOOLS)
    paths.update(ROOT/'Docs'/name for name in ('Theme Asset Production Workflow.md','Theme Asset Style Key.md',
                                               'Theme Asset Fitting Checklist.md','Theme Asset Geometry.json'))
    paths.update(p for p in (ROOT/'Docs/Research_Assets/Templates').glob('*.png'))
    paths.update(ROOT/name for name in ('Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json',
                                        'Docs/Research_Assets/Paladin/Revision5/layouts.json',
                                        'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/layouts.json'))
    with zipfile.ZipFile(ARCHIVE,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for path in sorted(paths):
            archive.write(path,path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(ARCHIVE) as archive:
        assert archive.testzip() is None, 'ZIP CRC check failed'
        for item in manifest['assets'].values():
            assert hashlib.sha256(archive.read(item['path'])).hexdigest()==item['sha256'],item['path']
    report = {'archive':ARCHIVE.name,'sha256':hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(),
              'bytes':ARCHIVE.stat().st_size,'files':len(paths),'verifiedTextureHashes':len(manifest['assets']),
              'crcPassed':True,'runtimeInstalled':False,'liveValidated':False}
    (WORK/'bundle-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
