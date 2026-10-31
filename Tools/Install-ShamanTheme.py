"""Install the reviewed Shaman pack and minimally wire the existing theme UI."""
from pathlib import Path
import importlib.util
import json
import shutil

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman'

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def replace_once(text,old,new):
    assert text.count(old)==1,'Integration context changed; re-read before editing: '+old
    return text.replace(old,new,1)

def harness(B, fits=None):
    """Exercise the real theme/selector with recording widgets and secrets.

    Reuse the established integration scenarios; only motif choices and the
    independently measured expected painted edge change for Shaman.
    """
    source=ROOT/'Tools/Harness/rogue_theme_harness.lua'
    text=source.read_text(encoding='utf-8').replace('Rogue','Shaman').replace('ROGUE','SHAMAN').replace('rogue','shaman')
    text=text.replace('twinguard','maelstrom').replace('serrated','tides').replace('venom','lava').replace('Serrated','Tides').replace('Venom Vial','Lava Totem')
    text=text.replace('"Druid","Warrior"','"Druid","Warrior","Rogue"')
    text=text.replace('SetCastEndcap("lava")','SetCastEndcap("totem")')
    text=text.replace('args.castEndcap.values.lava=="Lava Totem"','args.castEndcap.values.totem=="Ancestral Totem"')
    edge=json.loads((WORK/'maelstrom-registration.json').read_text())['fits']['hp_cap_case']['bounds'][0]
    text=text.replace('1-716/1024',f'1-{edge}/1024').replace('or 716/1024',f'or {edge}/1024')
    old='check((flip and textBar.Percent.points[1][4]>textPoint[4]) or (not flip and textBar.Percent.points[1][4]<textPoint[4]),"each motif reserves its own measured mounting body")'
    alternate=(fits or {'lava':json.loads((WORK/'lava-registration.json').read_text())})['lava']['fits']['hp_cap_case']['bounds'][0]
    new=f'local alternateEdge=casingLeft+(flip and 1-{alternate}/1024 or {alternate}/1024)*716\n\tcheck(math.abs(healthLeft+(flip and 0 or 385)+textBar.Percent.points[1][4]-alternateEdge)==8,"alternate motif reserves its measured painted body")'
    assert old in text;text=text.replace(old,new)
    path=ROOT/'Tools/Harness/shaman_theme_harness.lua';assert not path.exists()
    path.write_text(text,encoding='utf-8',newline='\n')

def main(live_preview=False):
    if not live_preview:
        from ThemeSourceIntegrity import require_production
        require_production(ROOT/'Assets_Draft/Shaman')
    C=module('shaman_install_checks','Check-ShamanAssets.py');B=module('shaman_install_builder','Build-ShamanAssets.py')
    live=None;fits=None
    if live_preview:
        live=module('shaman_live_install','Install-ShamanLivePreview.py')
        manifest,fits=live.prepare()
    else:
        manifest=C.check();C.verify_review()
    assert not (ROOT/'Core/ShamanTheme.lua').exists(),'Existing Shaman integration requires review rather than another install'
    files={name:(ROOT/name).read_text(encoding='utf-8-sig') for name in ('Core/Core.xml','Core/ThemeEffects.lua','Core/LegacyHUD.lua','Options/OptionsPages/Themes.lua')}
    before=dict(files)
    files['Core/Core.xml']=replace_once(files['Core/Core.xml'],'\t<Script file="RogueTheme.lua"/>','\t<Script file="RogueTheme.lua"/>\n\t<Script file="ShamanTheme.lua"/>')
    s=files['Core/ThemeEffects.lua']
    s=s.replace('rogue = "none" }','rogue = "none", shaman = "none" }')
    pairs=(('\tif (ns.RogueTheme) then list[#list + 1] = "rogue" end','\n\tif (ns.ShamanTheme) then list[#list + 1] = "shaman" end'),
           ('\tif (ns.RogueTheme and ns.RogueTheme:IsActive()) then return "rogue" end','\n\tif (ns.ShamanTheme and ns.ShamanTheme:IsActive()) then return "shaman" end'),
           ('\tif (ns.RogueTheme and (ns.RogueTheme.loadedActive or false) ~= (theme == "rogue")) then return true end','\n\tif (ns.ShamanTheme and (ns.ShamanTheme.loadedActive or false) ~= (theme == "shaman")) then return true end'),
           ('\tchar.roguePreview = theme == "rogue"','\n\tchar.shamanPreview = theme == "shaman"'))
    for old,tail in pairs: s=replace_once(s,old,old+tail)
    s=replace_once(s,'or (ns.RogueTheme and ns.RogueTheme:IsActive()) or false','or (ns.RogueTheme and ns.RogueTheme:IsActive())\n\t\tor (ns.ShamanTheme and ns.ShamanTheme:IsActive()) or false')
    files['Core/ThemeEffects.lua']=s
    s=files['Core/LegacyHUD.lua']
    s=replace_once(s,'or char.warriorPreview or char.roguePreview))','or char.warriorPreview or char.roguePreview or char.shamanPreview))')
    s=replace_once(s,'\tchar.roguePreview = false','\tchar.roguePreview = false\n\tchar.shamanPreview = false')
    files['Core/LegacyHUD.lua']=s
    s=files['Options/OptionsPages/Themes.lua']
    old='\tif (key == "rogue") then return ClassName("ROGUE", "Rogue") end'
    s=replace_once(s,old,old+'\n\tif (key == "shaman") then return ClassName("SHAMAN", "Shaman") end')
    old='\t\tor theme == ns.RogueTheme and "rogue"'
    s=replace_once(s,old,old+'\n\t\tor theme == ns.ShamanTheme and "shaman"')
    s=replace_once(s,'venom = "Venom Vial" }','venom = "Venom Vial", totem = "Ancestral Totem" }')
    start=s.index('local GenerateRogue = function(order)');end=s.index('local GenerateMoonwell = function(order)',start)
    block=s[start:end].replace('Rogue','Shaman').replace('rogue','shaman').replace('twinguard','maelstrom').replace('serrated','tides').replace('venom','lava').replace('Twin Guard','Maelstrom').replace('Serrated','Tides').replace('Venom Vial','Lava Totem')
    s=s[:end]+block+s[end:]
    s=replace_once(s,'\t\t\trogue = GenerateRogue(27),','\t\t\trogue = GenerateRogue(27),\n\t\t\tshaman = GenerateShaman(28),')
    files['Options/OptionsPages/Themes.lua']=s
    # All contexts resolve before the first runtime mutation. Preserve current
    # unrelated changes; the record binds only this task's small additions.
    backup=WORK/'Installed-Integration-Before';records={}
    for name in files:
        dest=backup/name;dest.parent.mkdir(parents=True,exist_ok=True)
        assert not dest.exists(),'Existing integration backup retained'
        shutil.copyfile(ROOT/name,dest)
    if live: live.install(manifest)
    else: C.install(manifest)
    B.runtime_module(fits);harness(B,fits)
    for name,text in files.items():
        path=ROOT/name;before_sha=C.sha(path)
        path.write_text(text,encoding='utf-8',newline='\n')
        records[name]={'beforeSha256':before_sha,'afterSha256':C.sha(path)}
    C.save(WORK/'installed-integration.json',{'files':records,'moduleSha256':C.sha(ROOT/'Core/ShamanTheme.lua'),
           'assetManifestSha256':C.sha(live.OUT/'manifest.json' if live else ROOT/'Assets_Draft/Shaman/manifest.json'),'nativeLayoutChanges':False,
           'installationMode':'live-review WIP' if live else 'reviewed production',
           'runtimeIntegrated':True,'liveRetailValidated':False,'liveForeverValidated':False})
    print('Shaman integrated: theme selector, /azshaman, independent endcaps, Lite+ and Legacy switching. Live client checks pending.')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live-preview',action='store_true',help='Explicit in-game WIP review; preserves failed production gates')
    main(parser.parse_args().live_preview)
