"""Search additional transparent-padding sampling phases; never alter painting.

All candidate crops retain every source texel above alpha 8, and every export
replays the same shared whole-painting operation and unchanged aperture gates.
"""
import argparse
import itertools
import json
import math

import numpy as np
from PIL import Image, ImageFilter

from PriestWarlockAssetContracts import ROOT, sha, record, underlay
from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import whole_painting, aperture


def refine(theme):
    path=ROOT/"Assets_Draft"/theme/"FullSet/registration-search.json"
    data=json.loads(path.read_text());folder=ROOT/"Docs/Research_Assets"/theme/"FullSet"
    jobs={j["name"]:j for j in json.loads((folder/"jobs.json").read_text(encoding="utf-8"))["jobs"]}
    fields=json.loads((folder/"Contracts/functional-fields.json").read_text())["clearance"]
    for name,result in data["assets"].items():
        if not result.get("best") or result["best"]["passed"]:
            continue
        job=jobs[name]
        if job["status"]!="done" or job["sourceSha256"]!=result["sourceSha256"]:
            continue
        source=Image.open(ROOT/job["source"]).convert("RGBA");canvas=job["geometry"]["canvas"]
        fill=Image.open(ROOT/fields[name]["path"]).convert("L")
        exact=name.startswith("orb_case")
        field=np.asarray(fill)>128
        interior=np.asarray(fill.filter(ImageFilter.MinFilter(3)))>128
        native_glass=underlay(name,fill,192/255) if exact else None
        glass_field=np.asarray(fill)>0 if exact else None
        base=result["best"]["transform"];crop=base["crop"]
        native=Image.open(ROOT/"Assets"/(name+".tga"));toe=lowest_point(native) if name.startswith("hp_") else None
        pads=list(dict.fromkeys([(a,b,a,b) for a in range(5) for b in range(5)]+list(itertools.product(range(3),repeat=4))))
        best=result["best"];trials=0
        for pad in pads:
            box=[max(0,crop[0]-pad[0]),max(0,crop[1]-pad[1]),min(source.width,crop[2]+pad[2]),min(source.height,crop[3]+pad[3])]
            for delta in (0,-.2,-.1,.1,.2):
                scale=base["scale"]+delta/(crop[3]-crop[1])
                painting=source.crop(box).resize((round((box[2]-box[0])*scale),round((box[3]-box[1])*scale)),Image.Resampling.LANCZOS)
                px,py=lowest_point(painting)
                offsets=[(int(x),int(toe[1]-py)) for x in sorted({math.floor(toe[0]-px),math.ceil(toe[0]-px)}) if abs(px+x-toe[0])<=.5] if toe else [(base["offset"][0]+x,base["offset"][1]+y) for x in range(-1,2) for y in range(-1,2)]
                alpha=np.asarray(painting)[:,:,3];solid=alpha>200
                bounds=painting.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox()
                for x,y in offsets:
                    if min(x,y)<0 or x+painting.width>canvas[0] or y+painting.height>canvas[1]:continue
                    found=[bounds[0]+x,bounds[1]+y,bounds[2]+x,bounds[3]+y]
                    if any(abs(found[i]-job["geometry"]["painted"][i])>max(3,round(canvas[i%2]*.04)) for i in range(4)):continue
                    count=int((solid&interior[y:y+painting.height,x:x+painting.width]).sum());trials+=1
                    glass_changed=0
                    if exact:
                        expected=native_glass.crop((x,y,x+painting.width,y+painting.height))
                        actual=Image.alpha_composite(expected,painting)
                        glass_changed=int((np.any(np.asarray(actual)!=np.asarray(expected),axis=2)&glass_field[y:y+painting.height,x:x+painting.width]).sum())
                        count+=glass_changed
                    if count>=best["solidFillIntrusionPixels"]:continue
                    transform={"crop":box,"scale":scale,"offset":[x,y]}
                    expected=whole_painting(source,transform,canvas)
                    try:aperture(expected,fill);passed=count==0
                    except ValueError:passed=False
                    best={"transform":transform,"bounds":found,"solidFillIntrusionPixels":count,"fillOcclusion":float((solid&field[y:y+painting.height,x:x+painting.width]).sum()/field.sum()),"passed":passed}
                    if exact:best["nativeGlassChangedPixels"]=glass_changed
                    if passed:break
                if best["passed"]:break
            if best["passed"]:break
        result["best"]=best
        result["transparentPaddingRefinement"]={"tool":record(__file__),"legalTrials":trials,"alphaErasure":False,"maskChanged":False}
        print(theme+"/"+name+": "+str(best["solidFillIntrusionPixels"])+" remaining; passed="+str(best["passed"]),flush=True)
    path.write_text(json.dumps(data,indent=2)+"\n")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("theme",choices=("Priest","Warlock","Both"));args=parser.parse_args()
    for theme in ("Priest","Warlock") if args.theme=="Both" else (args.theme,):refine(theme)
