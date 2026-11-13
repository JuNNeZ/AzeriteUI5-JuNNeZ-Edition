"""Map frozen complete tier terminals and approved bounds into source space."""
import json
import hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from PriestWarlockAssetContracts import ROOT, record
from ThemeHealthEndcaps import lowest_point


def prepare(theme):
    docs=ROOT/"Docs/Research_Assets"/theme;draft=ROOT/"Assets_Draft"/theme/"FullSet"
    motif="tuure" if theme=="Priest" else "ulthalesh"
    source_path=ROOT/"Assets_Draft"/theme/"Sources"/("health-endcap-"+motif+"-v5.png")
    source=Image.open(source_path).convert("RGBA")
    box=source.getchannel("A").point(lambda a:255 if a>8 else 0).getbbox()
    solid=source.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox()
    contracts=json.loads((docs/"Contracts/approved-footprints.json").read_text())["cases"]
    frozen=json.loads((docs/"FullSet/Contracts/painted-terminals.json").read_text())
    required=np.zeros((source.height,source.width),dtype=bool)
    allowed=np.ones_like(required)
    recipes={}
    for name in ("hp_mid_case","hp_low_case","hp_boss_case"):
        footprint=contracts[name]["approvedFootprint"]
        height=int(footprint[3]-footprint[1])-2
        scale=height/(solid[3]-solid[1])
        paint=source.crop(box).resize((round((box[2]-box[0])*scale),round((box[3]-box[1])*scale)),Image.Resampling.LANCZOS)
        px,py=lowest_point(paint);tx,ty=frozen[name]["toe"]
        offset=[round(tx-px),round(ty-py)]
        def mapped(mask):
            field=Image.new("L",source.size)
            field.paste(mask.resize((round(mask.width/scale),round(mask.height/scale)),Image.Resampling.NEAREST),(round(box[0]-offset[0]/scale),round(box[1]-offset[1]/scale)))
            return np.asarray(field)>128
        mask=Image.open(ROOT/frozen[name]["mask"]["path"]).convert("L")
        required|=mapped(mask)
        bounds=Image.new("L",mask.size);ImageDraw.Draw(bounds).rectangle(footprint,fill=255)
        allowed&=mapped(bounds)
        recipes[name]={"height":height,"scale":scale,"offset":offset,"terminal":frozen[name],"footprint":footprint}
    guide=Image.new("RGBA",source.size,"#252830");guide.alpha_composite(source)
    p=np.array(guide)
    # Diagnostics only, never a source/export stencil.
    p[required & (np.asarray(source)[:,:,3]<240)]=[0,230,255,255]
    from PIL import ImageFilter
    boundary=np.asarray(Image.fromarray(allowed.astype("uint8")*255).filter(ImageFilter.MaxFilter(7)))!=np.asarray(Image.fromarray(allowed.astype("uint8")*255).filter(ImageFilter.MinFilter(7)))
    p[boundary]=[255,70,220,255]
    guide=Image.fromarray(p)
    ImageDraw.Draw(guide).text((18,12),"CYAN: missing solid mounting body. MAGENTA: approved maximum; all paint stays inside. Diagnostic only.",font=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",20),fill="white")
    digest=hashlib.sha256(guide.tobytes()).hexdigest()[:12]
    path=draft/"Review"/("tier-cap-required-body-"+digest+".png");guide.convert("RGB").save(path)
    data={"source":record(source_path),"guide":record(path),"cases":recipes,"requiredOutsideCommonBoundPixels":int((required&~allowed).sum())}
    (docs/"FullSet/tier-cap-source-contract.json").write_text(json.dumps(data,indent=2)+"\n")
    print(theme+": required outside common source-space limit="+str(data["requiredOutsideCommonBoundPixels"]))


if __name__=="__main__":
    for theme in ("Priest","Warlock"):
        prepare(theme)
