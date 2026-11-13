"""Fit intact Priest orb paintings to the native exterior; never move the HUD.

Only uniform whole-source registration changes. Native functional glass and
fill/health anchors retain their independent contracts. WIP, offline only.
"""
import argparse
import copy
import json

import numpy as np
from PIL import Image

from PriestWarlockAssetContracts import ROOT, record, sha, underlay, native_tint
from ThemeSourceIntegrity import whole_painting, aperture, verify_pixels

NAMES = ("orb_case_hi","orb_case_low")
OUT = ROOT/"Assets_Draft/Priest/OrbJoinAudit"


def bounds(image):
    return image.getchannel("A").point(lambda a:255 if a>200 else 0).getbbox()


def fit(item, native, fill, pane, name):
    source=Image.open(ROOT/item["source"]["path"]).convert("RGBA")
    assert sha(ROOT/item["source"]["path"])==item["source"]["sha256"]
    crop=item["transform"]["crop"]
    target=bounds(native)
    source_bounds=bounds(source)
    centre=((target[0]+target[2])/2,(target[1]+target[3])/2)
    glass=underlay(name,pane,native_tint(name))
    glass_mask=np.asarray(pane)>0
    best=None;score=None;seen=set()
    for tenth in range((target[3]-target[1]-4)*10,(target[3]-target[1]+11)*10+1):
        scale=(tenth/10)/(source_bounds[3]-source_bounds[1])
        size=(round((crop[2]-crop[0])*scale),round((crop[3]-crop[1])*scale))
        if size in seen:continue
        seen.add(size)
        part=source.crop(crop).resize(size,Image.Resampling.LANCZOS)
        b=bounds(part)
        ox=round(centre[0]-(b[0]+b[2])/2);oy=round(centre[1]-(b[1]+b[3])/2)
        for dx in range(-3,4):
            for dy in range(-3,4):
                transform={"crop":crop,"scale":scale,"offset":[ox+dx,oy+dy]}
                painting=Image.new("RGBA",native.size);painting.paste(part,(ox+dx,oy+dy))
                try:aperture(painting,fill)
                except ValueError:continue
                box=bounds(painting)
                errors=[abs(box[i]-target[i]) for i in range(4)]
                if max(errors)>5:continue
                composed=Image.alpha_composite(glass,painting)
                delta=np.asarray(composed).astype(int)-np.asarray(glass).astype(int)
                rgb_changed=int((np.any(delta[:,:,:3]!=0,axis=2)&glass_mask).sum())
                alpha_delta=int(abs(delta[:,:,3][glass_mask]).max())
                changed=int((np.any(delta!=0,axis=2)&glass_mask).sum())
                trial=(rgb_changed,alpha_delta,changed,max(errors),sum(errors))
                if score is None or trial<score:
                    score=trial;best=(painting,composed,{"transform":transform,"nativeSolidBounds":list(target),
                        "paintedSolidBounds":list(box),"maximumExteriorEdgeErrorPx":max(errors),"nativeGlassChangedPixels":changed,
                        "nativeGlassRGBChangedPixels":rgb_changed,"maximumNativeGlassAlphaDelta255":alpha_delta,
                        "strictNativeGlassPassed":changed==0})
    assert best,"No whole-source registration fits native exterior and clear aperture"
    # A closer outside edge is never worth painting over the reflection.
    # Preserve exact glass RGB; retain alpha rounding as a strict WIP failure,
    # never as production acceptance or an extension of the old 10px waiver.
    assert best[2]["nativeGlassRGBChangedPixels"]==0,"Native glass RGB would change: "+str(best[2])
    assert best[2]["maximumNativeGlassAlphaDelta255"]<=1,"Native glass alpha would change beyond rounding"
    verify_pixels(whole_painting(source,best[2]["transform"],native.size),best[0])
    return best


def main(apply=False):
    OUT.mkdir(parents=True,exist_ok=True)
    before=OUT/"Before";before.mkdir(exist_ok=True)
    draft=ROOT/"Assets_Draft/Priest/FullSet"
    jobs_path=ROOT/"Docs/Research_Assets/Priest/FullSet/jobs.json"
    manifest=json.loads((draft/"manifest.json").read_text())
    fields=json.loads((ROOT/"Docs/Research_Assets/Priest/FullSet/Contracts/functional-fields.json").read_text())
    for source,label in ((draft/"manifest.json","source-manifest.json"),(ROOT/"Assets/Priest/manifest.json","runtime-manifest.json"),(jobs_path,"jobs.json")):
        if not (before/label).exists():(before/label).write_bytes(source.read_bytes())
    authority=json.loads((before/"source-manifest.json").read_text())["assets"]
    old_runtime=json.loads((before/"runtime-manifest.json").read_text())
    for name in NAMES:
        saved=before/(name+".tga")
        if not saved.exists():
            original=ROOT/"Assets/Priest"/(name+".tga")
            assert sha(original)==old_runtime["assets"][name]["sha256"]
            saved.write_bytes(original.read_bytes())
    jobs=json.loads(jobs_path.read_text(encoding="utf-8"))
    candidate=OUT/"Candidate";candidate.mkdir(exist_ok=True)
    records={}
    for name in NAMES:
        painting,composed,item=fit(authority[name],Image.open(ROOT/"Assets"/(name+".tga")).convert("RGBA"),
            Image.open(ROOT/fields["clearance"][name]["path"]).convert("L"),
            Image.open(ROOT/fields["nativePanes"][name]["path"]).convert("L"),name)
        target=candidate/(name+".tga");composed.save(target,compression=None)
        verify_pixels(composed,Image.open(target).convert("RGBA"))
        item.update(source=authority[name]["source"],originalTransform=authority[name]["transform"],candidate=record(target))
        records[name]=item
        if apply:
            job=next(j for j in jobs["jobs"] if j["name"]==name)
            if job.get("transform")!=item["transform"]:
                prior=copy.deepcopy(job);history=prior.pop("history",[])
                job["history"]=history+[prior]
            job.update(transform=item["transform"],registrationReason="Native exterior match; maintainer-reported orb height and health join")
        print(name+": native="+str(item["nativeSolidBounds"])+", fitted="+str(item["paintedSolidBounds"])+", glass changes="+str(item["nativeGlassChangedPixels"]))
    if apply:jobs_path.write_text(json.dumps(jobs,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    (OUT/"orb-fit.json").write_text(json.dumps({"tool":record(__file__),"originalManifest":record(before/"source-manifest.json"),
        "assets":records,"sourceJobsUpdated":apply,"hudGeometryChanged":False,"liveValidated":False},indent=2)+"\n")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--apply",action="store_true")
    main(parser.parse_args().apply)
