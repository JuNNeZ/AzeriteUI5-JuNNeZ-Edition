"""Render complete draft frames at current native anchors, with fixed comparisons.

Offline RGBA composition only: models, spell icons and client text are not emulated.
"""
import argparse
import importlib.util
import json

from PIL import Image, ImageDraw, ImageFont

from PriestWarlockAssetContracts import ROOT, LONG, projection


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", size)


def render(theme, installed=False):
    draft = ROOT / "Assets_Draft" / theme / "FullSet"
    output = draft / ("Review/GapRepair/BeforeAssemblies" if installed else "Review/Assemblies")
    output.mkdir(parents=True, exist_ok=True)
    if installed and (output/"complete-1x.png").exists():
        print("Retained existing before-repair assemblies: "+str(output))
        return
    media_folders = (ROOT/"Assets"/theme,) if installed else (draft/"Composed", draft/"Endcaps")
    loader = importlib.util.spec_from_file_location("native_scene_" + theme, ROOT / "Tools/Build-ThemeConceptBase.py")
    base = importlib.util.module_from_spec(loader)
    loader.loader.exec_module(base)
    base.DATA = json.loads((ROOT / "Docs/Research_Assets/PriestWarlock-layouts-current.json").read_text())["original"]
    native_asset, native_put = base.asset, base.put
    motif = "tuure" if theme == "Priest" else "ulthalesh"
    def asset(path):
        if path is None:
            return None
        name = path.replace("\\", "/").rsplit("/", 1)[-1]
        for folder in media_folders:
            candidate = folder / name
            if candidate.exists():
                image = Image.open(candidate).convert("RGBA")
                image.info["wholeClassPainting"] = True
                image.info["nativeButtonTint"] = name.startswith("actionbutton-border")
                return image
        return native_asset(path)
    base.asset = asset
    def put(scene, image, rect, flip=False, tint=None):
        if image is not None and image.info.get("wholeClassPainting") and not image.info.get("nativeButtonTint"):
            tint = None
        native_put(scene, image, rect, flip, tint)
    base.put = put
    def rails(scene, name, rect, flip=False, enabled=True):
        path = media_folders[0] / (name + "-over.tga")
        if path.exists():
            put(scene, Image.open(path).convert("RGBA"), rect, flip)
        if enabled and name in LONG:
            cap = (media_folders[0] if installed else draft/"Endcaps") / ("ornament-" + motif + "-" + name + ".tga")
            if cap.exists():
                put(scene, Image.open(cap).convert("RGBA"), rect, flip)
    def power(scene, owner, db, fraction, kind):
        if kind == "orb":
            rect = base.anchor(owner, db["ManaOrbSize"], db["ManaOrbPosition"])
            put(scene, asset(db["ManaOrbBackdropTexture"]), base.anchor(rect, db["ManaOrbBackdropSize"], db["ManaOrbBackdropPosition"]))
            base.fill(scene, "Interface/Assets/orb2.tga", rect, fraction, (.25,.4,.95), vertical=True)
            put(scene, asset(db["ManaOrbForegroundTexture"]), base.anchor(rect, db["ManaOrbForegroundSize"], db["ManaOrbForegroundPosition"]))
            return
        rect = base.anchor(owner, db["PowerBackdropSize"], db["PowerBarPosition"])
        local_bar, local_case = projection().crystal_rects(db)
        case = (rect[0]+local_case[0], rect[1]+local_case[1], *local_case[2:])
        put(scene, asset(db["PowerBackdropTexture"]), rect)
        base.fill(scene, db["PowerBarTexture"], rect, fraction, (.25,.4,.95), vertical=True)
        put(scene, asset(db["PowerBarForegroundTexture"]), case)
        put(scene, asset("resource-badge.tga"), (case[0]+case[2]/2-16,case[1]+case[3]*.56-16,32,32))
    def unit(kind, tier, fraction, enabled=True, resource=None):
        db = dict(base.DATA[kind]);db.update(db[tier])
        # One common review-only translation and viewport for every tier/state.
        # The former 900px scene clipped the far edge of complete boss frames.
        scene = Image.new("RGBA", (1200,400))
        owner = (300,80,*base.DATA[kind]["Size"])
        flip = kind == "TargetFrame"
        hp = base.anchor(owner,db["HealthBarSize"],db["HealthBarPosition"])
        if db.get("PortraitBorderTexture"):
            put(scene,asset(db["PortraitBorderTexture"]),base.anchor(owner,db["PortraitBorderSize"],db["PortraitBorderPosition"]),tint=db.get("PortraitBorderColor"))
        put(scene,asset(db["HealthBackdropTexture"]),base.anchor(owner,db["HealthBackdropSize"],db["HealthBackdropPosition"]),flip,db.get("HealthBackdropColor"))
        base.fill(scene,db["HealthBarTexture"],hp,1,base.DARK,flip)
        base.fill(scene,db["HealthBarTexture"],hp,fraction,base.RED,flip)
        name = db["HealthBackdropTexture"].replace("\\","/").rsplit("/",1)[-1].removesuffix(".tga")
        rails(scene,name,base.anchor(owner,db["HealthBackdropSize"],db["HealthBackdropPosition"]),kind=="TargetFrame",enabled)
        if resource:
            power(scene,owner,db,fraction,resource)
        box=scene.getbbox()
        assert box and box[0]>1 and box[1]>1 and box[2]<scene.width-1 and box[3]<scene.height-1, "Clipped complete unit: "+kind+"/"+tier
        return scene
    def compact(name, fraction=.65):
        scene = base.compact(name,fraction)
        db=base.DATA[name];pre="MirrorTimer" if name=="MirrorTimers" else "Health"
        bar=(120,90,*db[pre+"BarSize"])
        casing=db[pre+"BackdropTexture"].replace("\\","/").rsplit("/",1)[-1].removesuffix(".tga")
        rails(scene,casing,base.anchor(bar,db[pre+"BackdropSize"],db[pre+"BackdropPosition"]),enabled=False)
        return scene
    def group(name):
        scene=base.group(name);db=base.DATA[name]
        owner=(120,90,*db["UnitSize"])
        bar=base.anchor(owner,db["HealthBarSize"],db["HealthBarPosition"])
        casing=db["HealthBackdropTexture"].replace("\\","/").rsplit("/",1)[-1].removesuffix(".tga")
        rails(scene,casing,base.anchor(bar,db["HealthBackdropSize"],db["HealthBackdropPosition"]),enabled=False)
        return scene
    def cast(protected=False,enabled=True):
        db=base.DATA["PlayerCastBar"];scene=Image.new("RGBA",(500,300))
        bar=(190,140,*db["CastBarSize"])
        name="cast_back_spiked" if protected else "cast_back"
        pre="CastBarShield" if protected else "CastBarBackground"
        rect=base.anchor(bar,db[pre+"Size"],db[pre+"Position"])
        put(scene,asset(name+".tga"),rect)
        base.fill(scene,db["CastBarTexture"],bar,1,base.DARK)
        base.fill(scene,db["CastBarTexture"],bar,.65,base.AMBER)
        rails(scene,name,rect,enabled=False)
        if enabled:
            put(scene,asset("cast-head.tga"),(bar[0]-8-24,bar[1]+bar[3]/2-24,48,48))
        return scene
    board=Image.new("RGBA",(1600,1250),"#14161a");draw=ImageDraw.Draw(board)
    draw.text((20,15),theme.upper()+" / COMPLETE DRAFT ASSEMBLIES",font=font(26),fill="#e2d9c7")
    draw.text((20,53),"Current native geometry; illustrative fill colours. Offline rendering, no client approval.",font=font(16),fill="#d8b18d")
    def place(scene,x,y,label):
        draw.text((x,y),label,font=font(16),fill="#c0cbd4")
        box=scene.getbbox()
        if box:
            board.alpha_composite(scene.crop(box),(x,y+26))
    place(unit("PlayerFrame","Seasoned",.65,resource="crystal"),20,105,"Player / crystal")
    place(unit("TargetFrame","Seasoned",.65),560,105,"Target / mirrored")
    place(cast(),1150,105,"Normal cast / 100%, X/Y 0")
    place(cast(True),1150,225,"Protected cast / 100%, X/Y 0")
    db=dict(base.DATA["PlayerFrame"]);db.update(db["Seasoned"])
    for i,fraction in enumerate((0,.5,1)):
        for j,kind in enumerate(("crystal","orb")):
            scene=Image.new("RGBA",(900,500));power(scene,(300,150,*db["Size"]),db,fraction,kind)
            place(scene,20+i*170+j*560,370,kind+" "+str(round(fraction*100))+"%")
    place(base.points(),1170,390,"Class power")
    for i,name in enumerate(("PetFrame","FocusFrame","ToTFrame","RaidFrames")):
        place(compact(name),20+i*245,650,name)
    place(group("PartyFrames"),1030,630,"Party")
    place(group("Raid5Frames"),1260,630,"Arena / raid party")
    place(base.single("portrait_frame_hi",150),20,800,"Portrait")
    place(base.single("portrait_frame_lo",150),210,800,"Low portrait")
    place(unit("TargetFrame","Critter",1),410,800,"Critter / native complete frame")
    for i in range(4):
        place(base.button(i==0),20+i*95,1040,"Actions" if i==0 else "")
    place(base.single("minimap-border",270),730,910,"Minimap")
    place(base.single("config_button",90),1100,1030,"Utility")
    place(base.single("icon_exit_flight",90),1260,1030,"Exit flight")
    board.convert("RGB").save(output/"complete-1x.png")
    board.resize((3200,2500),Image.Resampling.NEAREST).convert("RGB").save(output/"complete-2x.png")
    for tier in ("Seasoned","Hardened","Novice","Boss"):
        pairs=Image.new("RGBA",(3600,1680),"#14161a");pd=ImageDraw.Draw(pairs)
        pd.text((20,10),theme+" / "+tier+" / fixed 1200x400 viewport, same rail origin in every None/on pair",font=font(23),fill="#e2d9c7")
        for row,(kind,enabled) in enumerate((("PlayerFrame",False),("PlayerFrame",True),("TargetFrame",False),("TargetFrame",True))):
            # Boss uses target geometry in both directions; normal player tiers
            # compare real player and target configurations independently.
            actual_kind="TargetFrame" if tier=="Boss" else kind
            for column,fraction in enumerate((0,.5,1)):
                scene=unit(actual_kind,tier,fraction,enabled)
                if tier=="Boss" and kind=="PlayerFrame":
                    scene=scene.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                x,y=column*1200,55+row*405
                pd.text((x+15,y),kind+" / "+("On" if enabled else "None")+" / "+str(round(fraction*100))+"%",font=font(16),fill="#bfcbd3")
                pairs.alpha_composite(scene,(x,y+20))
        pairs.convert("RGB").save(output/(tier.lower()+"-none-on-1x.png"))
        pairs.resize((7200,3360),Image.Resampling.NEAREST).convert("RGB").save(output/(tier.lower()+"-none-on-2x.png"))
    print(output)


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme",choices=("Priest","Warlock","Both"))
    parser.add_argument("--installed-before",action="store_true");args=parser.parse_args()
    for theme in ("Priest","Warlock") if args.theme=="Both" else (args.theme,):
        render(theme,args.installed_before)
