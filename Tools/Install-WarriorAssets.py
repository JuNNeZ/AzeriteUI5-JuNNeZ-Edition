"""Install only the accepted Warrior texture bytes; no art regeneration/release.

python Tools/Install-WarriorAssets.py
The staged production snapshots remain immutable; installation has its own manifest.
"""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent.parent
DRAFT = ROOT/'Assets_Draft/Warrior'
WORK = ROOT/'Docs/Research_Assets/Warrior'
OUT = ROOT/'Assets/Warrior'
RUNTIME = ('Core/WarriorTheme.lua','Core/Core.xml','Core/ThemeEffects.lua',
           'Core/LegacyHUD.lua','Options/OptionsPages/Themes.lua')
AUTHORIZED = set(RUNTIME)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Separate, user-requested H/M/P placement defaults are allowed only with their
# original and final hashes locked; this grants no permission to repaint art.
defaults_path = ROOT/'Docs/Research_Assets/EndcapConceptRepair-2026-10-18/authorized-defaults.json'
if defaults_path.exists():
    defaults = json.loads(defaults_path.read_text())
    allowed = {'Core/ThemeEngine.lua','Core/HunterTheme.lua','Core/MageTheme.lua','Core/PaladinTheme.lua'}
    protected = json.loads((WORK/'protected-files.json').read_text())
    assert set(defaults)==allowed,'unexpected placement-default edit scope'
    for name,item in defaults.items():
        assert protected[name]==item['beforeSha256'],'placement-default baseline changed '+name
        assert sha(ROOT/name)==item['afterSha256'],'placement-default edit changed '+name
    AUTHORIZED.update(allowed)


def main():
    from ThemeSourceIntegrity import require_production
    require_production(DRAFT)
    manifest_path = DRAFT/'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    digest = sha(manifest_path)
    numerical = json.loads((WORK/'acceptance.json').read_text())
    visual = json.loads((WORK/'visual-review.json').read_text())
    assert numerical['assetManifestSha256']==digest and numerical['geometryFailures']==0
    assert numerical['maxExposedTerminalPixelsBeyondAA']==0
    assert visual['assetManifestSha256']==digest and visual['agentOfflineVisualReview']=='passed'
    required = {'Warrior-endcaps-1x.png','Warrior-health-tiers.png','Warrior-terminal-before-after.png'}
    required.update('Warrior-'+key+'-2x.png' for key in ('stromkar','warswords','wrath'))
    if manifest.get('fitRevision'):
        required.update(('Warrior-live-repair.png','Warrior-cast-defaults.png'))
        assert numerical['liveFeedbackRevision']['geometryFailures']==0,'compact/strap/cast revision not verified'
    assert required<=visual['evidence'].keys(),'missing complete-bar visual evidence'
    for name,h in visual['evidence'].items():
        assert sha(WORK/name)==h,'stale visual evidence '+name
    protected = json.loads((WORK/'protected-files.json').read_text())
    unchanged = {name:h for name,h in protected.items() if name not in AUTHORIZED}
    for name,h in unchanged.items():
        assert sha(ROOT/name)==h,'unrelated existing artwork/runtime changed: '+name
    # Check every source before copying any texture. Installation never rebuilds
    # or repaints the accepted artwork and never touches other theme folders.
    for name,item in manifest['assets'].items():
        source = ROOT/item['path']
        assert source.parent==DRAFT and source.name==name+'.tga','unexpected staged path'
        assert sha(source)==item['sha256'],'staged export changed: '+name
    OUT.mkdir(parents=True,exist_ok=True)
    assets = {}
    for name,item in manifest['assets'].items():
        target = OUT/(name+'.tga')
        shutil.copyfile(ROOT/item['path'],target)
        assert sha(target)==item['sha256'],'installed texture differs: '+name
        assets[name] = dict(item,path=target.relative_to(ROOT).as_posix())
    installed = {'theme':manifest['theme'],'runtimeInstalled':True,'liveValidated':False,
                 'sourceManifestSha256':digest,'assets':assets,'casings':list(manifest['casings']),
                 'shared':manifest['shared'],'healthEndcaps':manifest['healthEndcaps'],
                 'resourceHaloContracts':manifest['resourceHaloContracts'],
                 'runtimeFiles':{name:sha(ROOT/name) for name in RUNTIME},
                 'unchangedProtectedFiles':len(unchanged),
                 'status':'Installed for /azwarrior and Themes; live Retail/Forever checks pending'}
    if manifest.get('fitRevision'):
        installed['fitRevision']=manifest['fitRevision']
    (OUT/'manifest.json').write_text(json.dumps(installed,indent=2)+'\n',encoding='utf-8')
    print('Warrior installed:',len(assets),'byte-identical textures;',len(unchanged),'unrelated protected files unchanged; live unverified.')


if __name__=='__main__':
    main()
