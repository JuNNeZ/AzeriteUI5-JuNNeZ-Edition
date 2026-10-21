"""Verify the installed Warrior bytes, frozen joins, load order and real Lua flows.

python Tools/Check-WarriorIntegration.py
Recording-widget Lua tests are not a live WoW rendering/security test.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image
from ThemeHealthEndcaps import lowest_point,terminal_coverage
from importlib.util import module_from_spec,spec_from_file_location

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Warrior'
OUT=ROOT/'Assets/Warrior'
checks=0


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(value,label):
    global checks
    checks+=1
    assert value,label


def main():
    manifest=json.loads((OUT/'manifest.json').read_text())
    source_path=ROOT/'Assets_Draft/Warrior/manifest.json'
    source=json.loads(source_path.read_text())
    check(manifest['sourceManifestSha256']==sha(source_path),'accepted source manifest retained')
    if source.get('materialRevision'):
        spec=spec_from_file_location('warrior_material_install',ROOT/'Tools/Refine-WarriorMaterials.py')
        material=module_from_spec(spec);spec.loader.exec_module(material)
        check(sha(ROOT/source['materialRevision'])==source['materialRevisionSha256'],'current material revision')
        material.verify(OUT)
        visual=json.loads((material.WORK/'visual-review.json').read_text())
        check(visual['revisionSha256']==sha(material.WORK/'revision.json') and visual['offlineVisualReview']=='passed','current material visual acceptance')
        for name,digest in visual['evidence'].items():check(sha(material.WORK/name)==digest,'current material evidence '+name)
    else:
        check(json.loads((WORK/'acceptance.json').read_text())['assetManifestSha256']==sha(source_path),'source acceptance current')
    if source.get('conceptRepairManifest'):
        concept_path=ROOT/source['conceptRepairManifest']
        check(sha(concept_path)==source['conceptRepairManifestSha256'],'current concept manifest')
        visual=json.loads((concept_path.parent/'visual-review.json').read_text())
        check(visual['manifestSha256']==sha(concept_path) and visual['offlineVisualReview']=='passed','current concept visual review')
        required={'Warrior-all-1x.png',*(f'Warrior-{key}-2x.png' for key in ('stromkar','warswords','wrath'))}
        check(required<=visual['evidence'].keys(),'complete concept review evidence')
        for name,digest in visual['evidence'].items():
            check(sha(concept_path.parent/name)==digest,'current visual evidence '+name)
    else:
        check(json.loads((WORK/'visual-review.json').read_text())['assetManifestSha256']==sha(source_path),'source visual acceptance current')
    check(manifest['runtimeInstalled'] and not manifest['liveValidated'],'installed does not claim live validation')
    check(manifest['assets'].keys()==source['assets'].keys(),'all staged textures installed')
    for name,item in manifest['assets'].items():
        path=ROOT/item['path']
        check(path.parent==OUT and path.name==name+'.tga','scoped installed path '+name)
        check(sha(path)==item['sha256']==source['assets'][name]['sha256']==sha(ROOT/source['assets'][name]['path']),'byte-identical installed texture '+name)
    for name,digest in manifest['runtimeFiles'].items():
        check(sha(ROOT/name)==digest,'current runtime integration manifest '+name)
    spec=spec_from_file_location('warrior_install',ROOT/'Tools/Install-WarriorAssets.py')
    install=module_from_spec(spec);spec.loader.exec_module(install)
    protected=json.loads((WORK/'protected-files.json').read_text())
    for name,digest in protected.items():
        if name not in install.AUTHORIZED:
            check(sha(ROOT/name)==digest,'unrelated protected file '+name)
    masks=json.loads((WORK/'Terminal-Repair/mask-lock.json').read_text())
    revision=None
    if source.get('fitRevision'):
        spec=spec_from_file_location('warrior_fit_revision',ROOT/'Tools/Repair-WarriorFit.py')
        repair=module_from_spec(spec);spec.loader.exec_module(repair)
        revision=repair.verify(OUT)
    lua=(ROOT/'Core/WarriorTheme.lua').read_text()
    dips={name:(float(x),float(y)) for name,x,y in re.findall(r'(hp_\w+_case)\s*=\s*\{([\d.]+)/1024,([\d.]+)/256\}',lua)}
    check(dips.keys()==masks.keys(),'runtime has exactly the four measured dip families')
    for name,lock in masks.items():
        casing=Image.open(OUT/(name+'-over.tga')).convert('RGBA')
        check(sha(ROOT/lock['path'])==lock['sha256'],'frozen terminal mask '+name)
        if not revision:
            check(sha(OUT/(name+'-over.tga'))==lock['casingSha256'],'complete bare casing unchanged '+name)
        check(lowest_point(casing)==dips[name],'runtime pivot equals actual installed dip '+name)
        for key in ('stromkar','warswords','wrath'):
            cap=Image.open(OUT/('ornament-'+key+'-'+name+'.tga')).convert('RGBA')
            x,y=lowest_point(cap)
            check(abs(x-dips[name][0])<=.5 and y==dips[name][1],'installed toe '+key+'/'+name)
            check(terminal_coverage(casing,cap)['exposedTerminalPixelsBeyondAA']==0,'full installed terminal covered '+key+'/'+name)
    tree=ET.parse(ROOT/'Core/Core.xml')
    scripts=[node.attrib['file'] for node in tree.getroot() if node.tag.endswith('Script')]
    check(scripts.count('WarriorTheme.lua')==1,'Warrior loads once')
    check(scripts.index('ThemeEngine.lua')<scripts.index('WarriorTheme.lua')<scripts.index('ThemeEffects.lua'),'engine then Warrior then selector/effects')
    harnesses={}
    for name in ('warrior_theme','theme_engine','theme_effects','legacy_hud','druid_theme','mage_theme','hunter_theme','paladin_theme','theme_bar_preview'):
        result=subprocess.run(['pwsh','-NoProfile','-File',str(ROOT/'Tools/Run-Elune.ps1'),str(ROOT/'Tools/Harness'/(name+'_harness.lua')),str(ROOT)],
                              cwd=ROOT,capture_output=True,text=True)
        check(result.returncode==0,'Lua harness '+name+'\n'+result.stdout+'\n'+result.stderr)
        harnesses[name]=result.stdout.strip()
    destination=WORK/'Integration'
    destination.mkdir(exist_ok=True)
    report={'checks':checks,'installedTextures':len(manifest['assets']),'installedManifestSha256':sha(OUT/'manifest.json'),
            'runtimeInstalled':True,'liveValidated':False,'harnesses':harnesses,
            'limits':'Elune Lua 5.1 with recording widgets; no live Retail/Forever rendering or combat confirmation'}
    if revision:
        report['liveFeedbackRevision']=revision
        report['checks']+=revision['checks']
    (destination/'acceptance.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
