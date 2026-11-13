"""Measure painted cast sockets at the real 48px default slot, normal/protected."""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from PriestWarlockAssetContracts import ROOT, record
from PaladinFillContracts import anchor


def check(theme):
    draft=ROOT/"Assets_Draft"/theme/"FullSet";docs=ROOT/"Docs/Research_Assets"/theme/"FullSet"
    db=json.loads((ROOT/"Docs/Research_Assets/PriestWarlock-layouts-current.json").read_text())["original"]["PlayerCastBar"]
    head_path=draft/"Composed/cast-head.tga";head=Image.open(head_path).convert("RGBA")
    field=json.loads((docs/"Contracts/functional-fields.json").read_text())["clearance"]
    bar=(100,100,*db["CastBarSize"]);slot=(bar[0]-32,bar[1]+bar[3]/2-24,48,48)
    box=head.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox()
    centre_error=((box[1]+box[3])/2/head.height-.5)*48
    board=Image.new("RGBA",(900,330),"#191d23");draw=ImageDraw.Draw(board)
    font=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",16)
    records={}
    for row,(name,pre) in enumerate((("cast_back","CastBarBackground"),("cast_back_spiked","CastBarShield"))):
        front_path=draft/"Composed"/(name+"-over.tga");front=Image.open(front_path).convert("RGBA")
        back=Image.open(draft/"Composed"/(name+".tga")).convert("RGBA")
        required=np.asarray(front)[:,:,3]>128
        left=field[name]["bounds"][0];required[:,left:]=False
        frozen=Image.fromarray(required.astype("uint8")*255)
        mask_path=docs/"Contracts"/(name+"-painted-socket-"+record(front_path)["sha256"][:12]+".png")
        if mask_path.exists():assert Image.open(mask_path).tobytes()==frozen.tobytes()
        else:frozen.save(mask_path)
        case=anchor(bar,db[pre+"Size"],db[pre+"Position"])
        def project(dy):
            canvas=Image.new("RGBA",front.size)
            x=round((slot[0]-case[0])/case[2]*front.width);y=round((slot[1]+dy-case[1])/case[3]*front.height)
            size=(round(48/case[2]*front.width),round(48/case[3]*front.height))
            canvas.alpha_composite(head.resize(size,Image.Resampling.LANCZOS),(x,y))
            opaque=canvas.getchannel("A").point(lambda a:255 if a>=240 else 0).filter(ImageFilter.MaxFilter(3))
            return int((required & (np.asarray(opaque)==0)).sum())
        exposed=project(0);rejected=project(12)
        records[name]={"head":record(head_path),"front":record(front_path),"socket":record(mask_path),
            "defaultSize":48,"offset":[0,0],"paintedVerticalCentreError":centre_error,
            "exposedSocketPixelsBeyondAA":exposed,"numericPassed":exposed==0 and abs(centre_error)<=1.5,
            "rejectedBottomAlignedFixture":{"shiftGameUnits":12,"exposedSocketPixelsBeyondAA":rejected,"centreError":centre_error+12,"mustFail":True}}
        assert rejected>0 or abs(centre_error+12)>1.5
        for column,enabled in enumerate((False,True)):
            x,y=20+column*440,25+row*150
            draw.text((x,y),name+" / "+("On" if enabled else "None"),font=font,fill="white")
            scene=Image.new("RGBA",(400,120))
            for image in (back,front):
                scene.alpha_composite(image.resize(tuple(map(round,case[2:])),Image.Resampling.LANCZOS),(round(case[0]-20),round(case[1]-50)))
            if enabled:scene.alpha_composite(head.resize((48,48),Image.Resampling.LANCZOS),(round(slot[0]-20),round(slot[1]-50)))
            board.alpha_composite(scene,(x,y+25))
        print(theme+"/"+name+": painted socket exposed="+str(exposed)+", centre error="+str(round(centre_error,3)))
    out=draft/"Review/CastSockets";out.mkdir(exist_ok=True)
    board.convert("RGB").save(out/"none-on-1x.png");board.resize((1800,660),Image.Resampling.NEAREST).convert("RGB").save(out/"none-on-2x.png")
    (out/"fit-report.json").write_text(json.dumps({"cases":records,"numericPassed":all(x["numericPassed"] for x in records.values()),"liveValidated":False},indent=2)+"\n")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("theme",choices=("Priest","Warlock","Both"));args=parser.parse_args()
    for theme in ("Priest","Warlock") if args.theme=="Both" else (args.theme,):check(theme)
