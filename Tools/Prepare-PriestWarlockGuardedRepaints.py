"""Queue fresh whole paintings with an explicit measured clearance guard band."""
import json
import runpy

from PIL import Image, ImageDraw, ImageFilter

from PriestWarlockAssetContracts import ROOT

helper=runpy.run_path(str(ROOT/"Tools/Prepare-PriestWarlockSources.py"))


def prepare(theme,name):
    folder=ROOT/"Docs/Research_Assets"/theme/"FullSet"
    jobs=json.loads((folder/"jobs.json").read_text(encoding="utf-8"))["jobs"]
    job=next(j for j in jobs if j["name"]==name);revision=job.get("revision",1)+1
    contract=json.loads((folder/"Contracts/functional-fields.json").read_text())["clearance"][name]
    native=Image.open(ROOT/"Assets"/(name+".tga")).convert("RGBA")
    mask=Image.open(ROOT/contract["path"]).convert("L").point(lambda a:255 if a>(0 if name.startswith("orb_case") else 128) else 0)
    guard=mask.filter(ImageFilter.MaxFilter(7))
    guide=Image.new("RGBA",native.size,"#252830");guide.alpha_composite(native)
    guide.paste((255,0,190,255),(0,0,*native.size),guard)
    scale=2 if native.width==1024 else 4
    guide=guide.resize((native.width*scale,native.height*scale),Image.Resampling.NEAREST)
    guide_path=folder/"Inputs"/(name+f"-v{revision}-native-guard-guide.png")
    assert not guide_path.exists();guide.convert("RGB").save(guide_path)
    spec=job["geometry"];bounds=spec["painted"];ratio=(bounds[2]-bounds[0])/(bounds[3]-bounds[1])
    prompt=(f"Use case: precise-object-edit. Create ONE NEW {theme} {name} physical casing. Image 1 is the native geometry target; image 2 is the SAME native target with a MAGENTA clearance guide, including three native pixels of safety space; image 3 is pure {theme} material swatches. "
        f"Replace all native grey metal with newly handpainted {helper['MATERIAL'][theme]}. {helper['detail'](name,theme)} "
        f"Exact OUTSIDE physical-body width/height ratio {ratio:.5f}:1. Keep native outside silhouette, height, points, placement and lowest mounting toe. "
        "REMOVE the native black recess, glass, reflection, icon and any other pixels from the ENTIRE magenta area. Every single magenta pixel including its outer guard band becomes TRUE EMPTY TRANSPARENCY, not black/white paint or translucent glass. Paint only the physical rim OUTSIDE magenta. A narrow finished inner bevel may follow the OUTSIDE of the magenta contour, never enter it. "
        "Return the entire complete rim, one continuous uncut object. No resources, relics or endcaps. Genuine alpha-zero background both inside and outside, no grey/white matte, fog, smoke, glow, shadow, specks, magenta/cyan/red guide colours, text or labels. Preserve canvas aspect with transparent padding. New broad readable handpainted facets; not a hue shift of native pixels.")
    refs=["Docs/Research_Assets/Templates/"+name+".png",guide_path.relative_to(ROOT).as_posix(),"Docs/Research_Assets/"+theme+"/FullSet/material-reference.png"]
    request=folder/(name+f"-v{revision}-guarded-request.json")
    request.write_text(json.dumps({"reason":"Residual inner-edge interference; use an explicitly measured 3px guard band in generation only, unchanged validation mask", "prompt":prompt,"references":refs,"validationContract":contract},indent=2)+"\n")
    helper["revise"](theme,name,request)
    print(guide_path)


if __name__=="__main__":
    for theme,name in (("Priest","hp_boss_case"),("Warlock","hp_boss_case"),("Priest","orb_case_hi"),("Warlock","actionbutton-border-square")):
        prepare(theme,name)
