"""Check exact WIP runtime exports, load order, retained failures and linked clients."""
import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET

from PriestWarlockAssetContracts import ROOT, record, sha
from PriestWarlockPack import candidate, checked, read
from ThemeSourceIntegrity import verify_pixels


def check(theme):
    folder=ROOT/"Assets"/theme;manifest=json.loads((folder/"manifest.json").read_text())
    assert manifest["productionAccepted"] is False and manifest["liveRetailValidated"] is False and manifest["liveForeverValidated"] is False
    checked(manifest["runtimeData"])
    files,records,evidence=candidate(theme)
    assert manifest["evidence"]==evidence, "Stale WIP evidence"
    assert set(files)==set(manifest["assets"])=={p.stem for p in folder.glob("*.tga")}
    for name,image in files.items():
        item=manifest["assets"][name]
        assert {k:v for k,v in item.items() if k not in ("path","sha256","canvas")}==records[name]
        target=checked(item);assert target==(folder/(name+".tga")).resolve()
        verify_pixels(image,read(target))
    scripts=[n.attrib["file"].replace("\\","/") for n in ET.parse(ROOT/"Core/Core.xml").iter() if n.tag.endswith("Script")]
    assert scripts.index("ThemeEngine.lua")<scripts.index(theme+"ThemeData.lua")<scripts.index(theme+"Theme.lua")<scripts.index("ThemeEffects.lua")
    clients=[]
    for client in ("_retail_","_forever_"):
        linked=Path("C:/Program Files (x86)/World of Warcraft")/client/"Interface/AddOns/AzeriteUI5_JuNNeZ_Edition"
        if not linked.exists():continue
        for relative in ("Core/Core.xml","Core/ThemeEffects.lua","Core/ThemeEngine.lua","Core/LegacyHUD.lua","Core/"+theme+"Theme.lua","Core/"+theme+"ThemeData.lua","Options/OptionsPages/Themes.lua"):
            assert sha(linked/relative)==sha(ROOT/relative), "Stale linked game file: "+client+"/"+relative
        for name,item in manifest["assets"].items():
            assert sha(linked/"Assets"/theme/(name+".tga"))==item["sha256"]
        clients.append(client)
    result={"theme":theme,"sourceReplayPassed":True,"runtimeTextures":len(files),"runtimeLoadOrderPassed":True,"linkedClients":clients,
        "numericPassed":evidence["numericPassed"],"retainedNumericIssues":evidence["functionalFailures"],"manifest":record(folder/"manifest.json"),
        "liveRetailValidated":False,"liveForeverValidated":False,"productionAccepted":False}
    path=ROOT/"Docs/Research_Assets"/theme/"FullSet/runtime-check.json";path.write_text(json.dumps(result,indent=2)+"\n")
    print(theme+": exact replay of "+str(len(files))+" installed textures, load order and linked files PASS; linked clients="+str(clients)+"; retained fit issues="+str(len(evidence["functionalFailures"])))


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("theme",choices=("Priest","Warlock","Both"));args=parser.parse_args()
    for theme in ("Priest","Warlock") if args.theme=="Both" else (args.theme,):check(theme)
