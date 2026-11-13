"""Fit whole cast paintings inside the unchanged 48px slot; never change a source."""
import argparse
import json

import numpy as np
from PIL import Image, ImageFilter

from PriestWarlockAssetContracts import ROOT, record, sha
from ThemeSourceIntegrity import whole_painting
from PaladinFillContracts import anchor


def fit(theme):
    docs=ROOT/"Docs/Research_Assets"/theme/"FullSet";draft=ROOT/"Assets_Draft"/theme/"FullSet"
    job_path=docs/"jobs.json";jobs=json.loads(job_path.read_text(encoding="utf-8"));job=next(j for j in jobs["jobs"] if j["name"]=="cast-head")
    source=Image.open(ROOT/job["source"]).convert("RGBA");assert sha(ROOT/job["source"])==job["sourceSha256"]
    crop=source.getchannel("A").point(lambda a:255 if a>8 else 0).getbbox()
    solid=source.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox()
    report=json.loads((draft/"Review/CastSockets/fit-report.json").read_text())
    db=json.loads((ROOT/"Docs/Research_Assets/PriestWarlock-layouts-current.json").read_text())["original"]["PlayerCastBar"]
    bar=(0,0,*db["CastBarSize"]);slot=(-32,bar[3]/2-24,48,48)
    trials=[]
    offsets=sorted(((x,y) for x in range(-3,4) for y in range(-3,4)),key=lambda p:(abs(p[0])+abs(p[1]),p))
    for span in range(240,255):
        scale=span/max(solid[2]-solid[0],solid[3]-solid[1])
        size=[round((crop[i+2]-crop[i])*scale) for i in (0,1)]
        if max(size)>256:continue
        for dx,dy in offsets:
            offset=[(256-size[0])//2+dx,(256-size[1])//2+dy]
            if min(offset)<0 or any(offset[i]+size[i]>256 for i in (0,1)):continue
            transform={"crop":list(crop),"scale":scale,"offset":offset}
            head=whole_painting(source,transform,(256,256));failures={}
            for name,pre in (("cast_back","CastBarBackground"),("cast_back_spiked","CastBarShield")):
                item=report["cases"][name];mask_path=ROOT/item["socket"]["path"];assert sha(mask_path)==item["socket"]["sha256"]
                required=np.asarray(Image.open(mask_path))>0
                case=anchor(bar,db[pre+"Size"],db[pre+"Position"])
                canvas=Image.new("RGBA",(256,128));x=round((slot[0]-case[0])/case[2]*256);y=round((slot[1]-case[1])/case[3]*128)
                canvas.alpha_composite(head.resize((round(48/case[2]*256),round(48/case[3]*128)),Image.Resampling.LANCZOS),(x,y))
                opaque=canvas.getchannel("A").point(lambda a:255 if a>=240 else 0).filter(ImageFilter.MaxFilter(3))
                failures[name]=int((required&(np.asarray(opaque)==0)).sum())
            box=head.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox()
            centre=((box[1]+box[3])/2-128)*48/256
            trials.append({"span":span,"transform":transform,"exposedSocketPixels":failures,"paintedCentreError":centre,"passed":not any(failures.values()) and abs(centre)<=1.5})
            if trials[-1]["passed"]:break
        if trials[-1]["passed"]:break
    best=min(trials,key=lambda t:(not t["passed"],sum(t["exposedSocketPixels"].values()),t["span"]))
    if best["passed"]:
        job["transform"]=best["transform"]
        job["registrationReason"]="Measured complete normal/protected painted socket at unchanged 48px slot, default scale and X/Y zero"
        job_path.write_text(json.dumps(jobs,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    (docs/"cast-head-registration.json").write_text(json.dumps({"source":record(ROOT/job["source"]),"socketReport":record(draft/"Review/CastSockets/fit-report.json"),"best":best,"trials":trials,"sourceChanged":False,"runtimeSlotChanged":False},indent=2)+"\n")
    print(theme+": cast head span="+str(best["span"])+", exposed="+str(best["exposedSocketPixels"])+", passed="+str(best["passed"]))


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("theme",choices=("Priest","Warlock","Both"));args=parser.parse_args()
    for theme in ("Priest","Warlock") if args.theme=="Both" else (args.theme,):fit(theme)
