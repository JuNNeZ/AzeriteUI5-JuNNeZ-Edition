"""Read-only comparison of complete player resource/health joins.

Use current layout export and installed TGAs. No client control or asset edits.
Health endcaps/effects/text are omitted explicitly to isolate the resource join.
"""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from PriestWarlockAssetContracts import ROOT, record, projection

OUT = ROOT/"Assets_Draft/Priest/OrbJoinAudit"
THEMES = ("Azerite", "Priest", "Mage", "Paladin", "Druid")
SIZE = (650,310)
OWNER = (30,65,560,180)
CASE_FOLDER = None
INPUTS = {}

loader = importlib.util.spec_from_file_location("join_base",ROOT/"Tools/Build-ThemeConceptBase.py")
base = importlib.util.module_from_spec(loader)
loader.loader.exec_module(base)
LAYOUT = json.loads((OUT/"layouts-current.json").read_text())["original"]["PlayerFrame"]
FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",16)


def asset(theme, name, tint=None):
    themed = ROOT/"Assets"/theme/(name+".tga")
    native = ROOT/"Assets"/(name+".tga")
    path = themed if theme!="Azerite" and themed.exists() else native
    if theme=="Priest" and name in ("orb_case_hi","orb_case_low") and CASE_FOLDER is not None:
        path = CASE_FOLDER/(name+".tga")
    INPUTS[path.relative_to(ROOT).as_posix()] = record(path)
    image = Image.open(path).convert("RGBA")
    if path==native and tint:
        image = base.color(image,tint)
    return image


def stem(path):
    return path.replace("\\","/").rsplit("/",1)[-1].removesuffix(".tga")


def scene(theme, tier, resource="orb", pedestal=False):
    db = dict(LAYOUT);db.update(LAYOUT[tier])
    image = Image.new("RGBA",SIZE)
    hp = base.anchor(OWNER,db["HealthBarSize"],db["HealthBarPosition"])
    casing = base.anchor(OWNER,db["HealthBackdropSize"],db["HealthBackdropPosition"])
    name = stem(db["HealthBackdropTexture"])
    base.put(image,asset(theme,name,db["HealthBackdropColor"]),casing)
    base.fill(image,db["HealthBarTexture"],hp,1,base.DARK)
    base.fill(image,db["HealthBarTexture"],hp,.65,base.RED)
    if theme!="Azerite":
        front = ROOT/"Assets"/theme/(name+"-over.tga")
        if front.exists():base.put(image,Image.open(front).convert("RGBA"),casing)
    if resource=="orb":
        rect = base.anchor(OWNER,db["ManaOrbSize"],db["ManaOrbPosition"])
        # Actual Player.lua order: pedestal behind backdrop; fill; optional
        # glass/rim; shade; case above the native resource and health rails.
        if pedestal:
            base.put(image,asset("Azerite",stem(db["ManaOrbArtworkTexture"])),base.anchor(rect,db["ManaOrbArtworkSize"],db["ManaOrbArtworkPosition"]))
        base.put(image,asset("Azerite",stem(db["ManaOrbBackdropTexture"])),base.anchor(rect,db["ManaOrbBackdropSize"],db["ManaOrbBackdropPosition"]))
        base.fill(image,db["ManaOrbTexture"][0],rect,.65,(.25,.4,.95),vertical=True)
        base.put(image,asset("Azerite",stem(db["ManaOrbGlassTexture"])),base.anchor(rect,db["ManaOrbGlassSize"],db["ManaOrbGlassPosition"]),tint=db["ManaOrbGlassColor"])
        base.put(image,asset("Azerite",stem(db["ManaOrbShadeTexture"])),base.anchor(rect,db["ManaOrbShadeSize"],db["ManaOrbShadePosition"]),tint=db["ManaOrbShadeColor"])
        case = base.anchor(rect,db["ManaOrbForegroundSize"],db["ManaOrbForegroundPosition"])
        base.put(image,asset(theme,stem(db["ManaOrbForegroundTexture"]),db["ManaOrbForegroundColor"]),case)
    else:
        rect = base.anchor(OWNER,db["PowerBackdropSize"],db["PowerBarPosition"])
        _,relative = projection().crystal_rects(db)
        case = (rect[0]+relative[0],rect[1]+relative[1],*relative[2:])
        base.put(image,asset("Azerite",stem(db["PowerBackdropTexture"])),rect)
        base.fill(image,db["PowerBarTexture"],rect,.65,(.25,.4,.95),vertical=True)
        base.put(image,asset(theme,stem(db["PowerBarForegroundTexture"]),db["PowerBarForegroundColor"]),case)
    bounds = image.getbbox()
    assert bounds and min(bounds[:2])>0 and bounds[2]<SIZE[0] and bounds[3]<SIZE[1], "Clipped complete assembly"
    return image


def metrics(theme,tier):
    db = dict(LAYOUT);db.update(LAYOUT[tier])
    rect = base.anchor(OWNER,db["ManaOrbSize"],db["ManaOrbPosition"])
    case = base.anchor(rect,db["ManaOrbForegroundSize"],db["ManaOrbForegroundPosition"])
    hp = base.anchor(OWNER,db["HealthBarSize"],db["HealthBarPosition"])
    name = stem(db["ManaOrbForegroundTexture"])
    image = asset(theme,name)
    box = image.getchannel("A").point(lambda a:255 if a>200 else 0).getbbox()
    painted = [case[0]+box[0]/image.width*case[2],case[1]+box[1]/image.height*case[3],case[0]+box[2]/image.width*case[2],case[1]+box[3]/image.height*case[3]]
    return {"orbFrame":list(rect),"orbCaseFrame":list(case),"healthFill":list(hp),"solidCaseSourceBounds":list(box),
        "solidCaseRenderedBounds":painted,"caseBelowHealthFillPx":painted[3]-(hp[1]+hp[3])}


def main(candidate=False):
    global CASE_FOLDER
    CASE_FOLDER = OUT/"Candidate" if candidate else None
    output = OUT/"Proposed" if candidate else OUT
    output.mkdir(exist_ok=True)
    metrics_by_tier = {}
    for tier in ("Seasoned","Hardened","Novice"):
        board = Image.new("RGBA",(1320,70+len(THEMES)*340),"#242a32")
        draw = ImageDraw.Draw(board)
        draw.text((15,10),tier+" / SAME owner, orb, crystal and health anchors / bare health casing (None)",font=FONT,fill="white")
        draw.text((15,36),"Orb: default glass ON, rim/pedestal OFF; static fill only. No live effects or client emulation.",font=FONT,fill="white")
        metrics_by_tier[tier] = {}
        for row,theme in enumerate(THEMES):
            y=70+row*340
            draw.text((15,y),theme+" / orb + complete health",font=FONT,fill="white")
            draw.text((675,y),theme+" / crystal + complete health",font=FONT,fill="white")
            for col,kind in enumerate(("orb","crystal")):
                board.alpha_composite(scene(theme,tier,kind),(col*660,y+20))
            metrics_by_tier[tier][theme] = metrics(theme,tier)
        board.convert("RGB").save(output/(tier.lower()+"-assembled-1x.png"))
        board.resize((board.width*2,board.height*2),Image.Resampling.NEAREST).convert("RGB").save(output/(tier.lower()+"-assembled-2x.png"))
    board=Image.new("RGBA",(1320,370),"#242a32");draw=ImageDraw.Draw(board)
    for col,pedestal in enumerate((False,True)):
        draw.text((15+col*660,10),"Priest / pedestal "+("ON" if pedestal else "OFF")+" / same anchors",font=FONT,fill="white")
        board.alpha_composite(scene("Priest","Seasoned",pedestal=pedestal),(col*660,45))
    board.convert("RGB").save(output/"priest-pedestal-toggle-1x.png")
    if not candidate and (OUT/"Before/orb_case_hi.tga").exists():
        CASE_FOLDER=OUT/"Before"
        old=scene("Priest","Seasoned")
        CASE_FOLDER=None
        scenes=(old,scene("Priest","Seasoned"),scene("Azerite","Seasoned"))
        boxes=[im.getbbox() for im in scenes]
        union=(min(b[0] for b in boxes)-8,min(b[1] for b in boxes)-8,max(b[2] for b in boxes)+8,max(b[3] for b in boxes)+8)
        width,height=union[2]-union[0],union[3]-union[1]
        comparison=Image.new("RGBA",((width+24)*3,height+60),"#242a32");labels=ImageDraw.Draw(comparison)
        for col,(title,image) in enumerate(zip(("Priest BEFORE","Priest AFTER","Native reference"),scenes)):
            labels.text((12+col*(width+24),10),title+" / same orb and health anchors",font=FONT,fill="white")
            comparison.alpha_composite(image.crop(union),(12+col*(width+24),42))
        comparison.convert("RGB").save(output/"complete-before-after-1x.png")
        comparison.resize((comparison.width*2,comparison.height*2),Image.Resampling.NEAREST).convert("RGB").save(output/"complete-before-after-2x.png")
        (output/"join-viewports.json").write_text(json.dumps({"owner":OWNER,"sharedUnionViewport":union},indent=2)+"\n")
    result={"layout":record(OUT/"layouts-current.json"),"tool":record(__file__),"metrics":metrics_by_tier,"assetInputs":list(INPUTS.values()),
        "notes":["All themes use the same layout rectangles; only casing art differs","This renderer does not change saved variables or runtime assets","Pedestal is opt-in, default false; its enabled state on the maintainer character is unknown"],"liveValidated":False}
    (output/"comparison.json").write_text(json.dumps(result,indent=2)+"\n")
    for tier,items in metrics_by_tier.items():
        a,b=items["Azerite"]["solidCaseRenderedBounds"],items["Priest"]["solidCaseRenderedBounds"]
        print(tier+": Priest solid art above native="+str(round(a[1]-b[1],2))+"px; below native="+str(round(b[3]-a[3],2))+"px")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--candidate",action="store_true")
    main(parser.parse_args().candidate)
