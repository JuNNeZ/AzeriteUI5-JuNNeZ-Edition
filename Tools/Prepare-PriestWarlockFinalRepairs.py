"""Prepare source-space repaint instructions from frozen failed measurements.

Coloured images are diagnostics only, never export sources or alpha stencils.
Original paintings and all validation fields remain unchanged.
"""
import json
import runpy

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from PriestWarlockAssetContracts import ROOT, record


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def cap(theme):
    folder = ROOT / "Assets_Draft" / theme / "FullSet"
    docs = ROOT / "Docs/Research_Assets" / theme / "FullSet"
    report_path = folder / "Endcaps/fit-report.json"
    report = json.loads(report_path.read_text())
    save(docs / "rejected-cap-fit-before-v2.json", report)
    cases = {k:v for k,v in report["cases"].items() if k != "hp_cap_case"}
    source_path = ROOT / next(iter(cases.values()))["source"]["path"]
    source = Image.open(source_path).convert("RGBA")
    required = Image.new("L", source.size)
    for item in cases.values():
        assert item["source"] == record(source_path)
        transform = item["best"]["transform"]
        scale = transform["scale"]
        mask = Image.open(ROOT / item["frozenTerminal"]["mask"]["path"]).convert("L")
        mapped = Image.new("L", source.size)
        mapped.paste(mask.resize((round(mask.width/scale),round(mask.height/scale)),Image.Resampling.NEAREST),
            (round(transform["crop"][0]-transform["offset"][0]/scale),round(transform["crop"][1]-transform["offset"][1]/scale)))
        required = Image.fromarray(np.maximum(np.asarray(required),np.asarray(mapped)))
    missing = (np.asarray(required)>128) & (np.asarray(source)[:,:,3]<250)
    guide = Image.new("RGBA",source.size,"#252830");guide.alpha_composite(source)
    pixels = np.array(guide);pixels[missing]=[0,235,255,255]
    guide_path = folder / "Review/tier-cap-v2-measured-body.png"
    Image.fromarray(pixels).convert("RGB").save(guide_path)
    motif = "T'uure silver/ivory reliquary, violet enamel, warm diamond jewel and narrow gold clasps" if theme=="Priest" else "Ulthalesh scythe crescent of hammered black iron, brass bevels, violet enamel and integrated chain"
    prompt = (f"Use case: precise-object-edit. Image 1 is the exact {theme} whole endcap edit target. Image 2 shows its ACTUAL missing mounting metal in CYAN. Preserve the {motif}, the same overall pose, top point, central void, canvas and single bottom mounting toe. "
        "REPAINT THE LOWER OUTSIDE HEEL: it is currently too narrow and steep. Widen its left descending OUTER flank noticeably outward into a broad opaque boot, covering ALL CYAN pixels plus a continuous safety band of about 25 source pixels. Add the same small safety thickness along the upper and outside mounting rim where cyan occurs. Blend the added metal into the original continuous sculpted rim; no separate plate or second piece. Keep the current bottom toe at exactly the same position; no new pixel below it, no neighbouring second tip. The lower flank must converge smoothly to this one toe. Keep the external width/height similar, never a giant relic. Preserve the recognizable relic and open central C-shaped void. Do not merely trace the existing edge: the cyan areas MUST become part of a visibly broader opaque heel. Entire finished uncut object on actual transparent background, no cyan or diagnostic colours, no text, matte, shadow, fog, glow or added objects. Return same square canvas and transparent margins.")
    save(docs / "tier-cap-v2-request.json", {"prompt":prompt,"references":[source_path.relative_to(ROOT).as_posix(),guide_path.relative_to(ROOT).as_posix()],"referenceHashes":[record(source_path),record(guide_path)],"rejectedFit":record(docs/"rejected-cap-fit-before-v2.json")})


def aperture(theme, name):
    docs=ROOT/"Docs/Research_Assets"/theme/"FullSet";folder=ROOT/"Assets_Draft"/theme/"FullSet"
    job=next(j for j in json.loads((docs/"jobs.json").read_text(encoding="utf-8"))["jobs"] if j["name"]==name)
    best=json.loads((folder/"registration-search.json").read_text())["assets"][name]["best"]
    source_path=ROOT/job["source"];source=Image.open(source_path).convert("RGBA")
    field=json.loads((docs/"Contracts/functional-fields.json").read_text())["clearance"][name]
    mask=Image.open(ROOT/field["path"]).convert("L").point(lambda a:255 if a>(0 if name.startswith("orb") else 128) else 0)
    transform=best["transform"];scale=transform["scale"]
    mapped=Image.new("L",source.size)
    mapped.paste(mask.resize((round(mask.width/scale),round(mask.height/scale)),Image.Resampling.NEAREST),
        (round(transform["crop"][0]-transform["offset"][0]/scale),round(transform["crop"][1]-transform["offset"][1]/scale)))
    # A generation-only safety band. Frozen validation fields are untouched.
    mapped=mapped.filter(ImageFilter.MaxFilter(31))
    guide=Image.new("RGBA",source.size,"#252830");guide.alpha_composite(source);guide.paste((255,0,190,255),(0,0,*source.size),mapped)
    revision=job.get("revision",1)+1
    guide_path=folder/"Review"/(name+f"-v{revision}-measured-clearance.png");guide.convert("RGB").save(guide_path)
    prompt=(f"Use case: precise-object-edit. Image 1 is the current whole {theme} {name} casing EDIT TARGET; image 2 is the exact same source with the required aperture plus a small safety band in MAGENTA. Make ONE precise edit: open the INNER rim slightly outward until every magenta pixel is TRUE EMPTY TRANSPARENCY, including all specks and translucent fringe. "
        "Preserve the complete exterior silhouette, identical canvas placement, all exterior points, materials, inlays and studs, including the sole lowest toe of a health casing. Keep a clean narrow continuous finished inner bevel OUTSIDE the magenta region, never across it. No painted black/white recess, new glass, reflection or translucent pixel in the opening. Do not resize or recompose the casing; do not change its outside or paint another object. Remove the magenta diagnostic completely. Return ONE complete intact newly finished physical rim on genuine transparent background inside AND outside. No text, glow, shadow, matte or backdrop. Preserve exact canvas aspect and transparent margins.")
    request=docs/(name+f"-v{revision}-measured-request.json")
    save(request,{"reason":"Measured residual inner edge: repaint opening with source-space safety clearance, keep immutable validation contract", "prompt":prompt,"references":[source_path.relative_to(ROOT).as_posix(),guide_path.relative_to(ROOT).as_posix()]})
    runpy.run_path(str(ROOT/"Tools/Prepare-PriestWarlockSources.py"))["revise"](theme,name,request)


if __name__=="__main__":
    for theme in ("Priest","Warlock"):
        cap(theme);aperture(theme,"hp_boss_case")
    aperture("Priest","orb_case_hi")
