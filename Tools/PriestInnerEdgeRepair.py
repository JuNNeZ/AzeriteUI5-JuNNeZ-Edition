"""Maintainer-authorized, additive inner-edge painting on native-size copies.

Authorization, 2026-11-08: "Ja, ret inderkanterne præcist med Python".
This is a narrowly scoped source-art edit, not a native casing-alpha stencil.
Existing opaque paint, outer contours, functional fills and anchors stay intact.
The original high-resolution paintings and their registrations remain authority.
"""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from PriestWarlockAssetContracts import ROOT, LONG, record, sha
from ThemeSourceIntegrity import whole_painting, verify_pixels, aperture
from ThemeHealthEndcaps import lowest_point

NAMES = LONG + ("pw_crystal_case", "pw_crystal_case_low")
AUTHORIZATION = "Ja, ret inderkanterne præcist med Python"


def inner_opening(painting, crystal=False):
    solid = painting.getchannel("A").point(lambda a: 255 if a > 128 else 0)
    box = solid.getbbox()
    wall = solid.copy()
    if crystal:
        # The cradle is deliberately open at the top. A diagnostic closing
        # segment between its two existing tips isolates only its inner recess;
        # it is NEVER painted into the source.
        a = np.asarray(solid)
        mid = (box[0]+box[2])//2
        left = np.where(a[:, box[0]:mid] > 0)[0].min()
        right = np.where(a[:, mid:box[2]] > 0)[0].min()
        top = int(max(left, right)+1)
        ImageDraw.Draw(wall).line((box[0], top, box[2]-1, top), fill=255)
        seed = (mid, top+2)
    else:
        seed = ((box[0]+box[2])//2, (box[1]+box[3])//2)
    assert wall.getpixel(seed) == 0, "Opening seed is painted"
    ImageDraw.floodfill(wall, seed, 128)
    opening = wall.point(lambda a: 255 if a == 128 else 0)
    bounds = opening.getbbox()
    assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<painting.width and bounds[3]<painting.height, "Open/incorrect recess"
    return opening


def repair(painting, fill, crystal=False):
    original = np.asarray(painting)
    opening = np.asarray(inner_opening(painting, crystal)) > 0
    field = np.asarray(fill.convert("L")) > 128
    add = opening & ~field & (original[:, :, 3] < 129)
    # The permitted paint operation is only the inner seam. Even a malformed
    # opening/guide cannot turn it into an exterior repaint or filled aperture.
    field_image = Image.fromarray(field.astype("uint8")*255)
    # Diagonal sockets have a wider horizontal gap than the straight rails.
    distance_band = np.asarray(field_image.filter(ImageFilter.MaxFilter(49))) > 0
    assert not (add & ~distance_band).any(), "Repair exceeds the measured inner-edge band"
    pixels = original.copy()
    solid = original[:, :, 3] > 128
    for y, x in zip(*np.where(add)):
        # Paint a recessed dark bevel using this painting's local material.
        # Copying one edge texel repeatedly produces visible extrusion stripes
        # and extends gold rivets into dots. Keep the added lip broad and quiet.
        # No pixels come from the native casing or functional fill.
        radius = 26
        y0, x0 = max(0,y-radius), max(0,x-radius)
        yy, xx = np.where(solid[y0:y+radius+1, x0:x+radius+1])
        assert len(yy), "Missing local painted bevel"
        nearest = int(np.argmin((yy+y0-y)**2+(xx+x0-x)**2))
        sy,sx = yy[nearest]+y0,xx[nearest]+x0
        patch = original[max(0,sy-3):sy+4,max(0,sx-3):sx+4]
        colour = np.median(patch[patch[:,:,3]>128,:3],axis=0)
        pixels[y,x,:3] = np.rint(colour*.12+np.array([25,23,29])*.88).astype("uint8")
        pixels[y,x,3] = 255
    result = Image.fromarray(pixels)
    assert np.array_equal(pixels[~add], original[~add])
    assert np.array_equal(pixels[solid], original[solid]), "Existing solid paint changed"
    assert not (add & field).any()
    # Adding only inside the isolated recess keeps the complete outside fixed.
    assert result.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox() == painting.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox()
    assert lowest_point(result) == lowest_point(painting)
    return result, Image.fromarray(add.astype("uint8")*255)


def verify_repairs():
    folder = ROOT/"Assets_Draft/Priest/FullSet/GapRepair"
    report = json.loads((folder/"inner-edge-repair.json").read_text())
    assert report["authorization"] == AUTHORIZATION
    assert report["tool"] == record(__file__), "Stale pixel-repair recipe"
    fields = json.loads((ROOT/"Docs/Research_Assets/Priest/FullSet/Contracts/functional-fields.json").read_text())["clearance"]
    assert set(report["assets"]) == set(NAMES)
    authority = ROOT/report["originalManifest"]["path"]
    assert record(authority) == report["originalManifest"]
    original_assets = json.loads(authority.read_text())["assets"]
    for name, item in report["assets"].items():
        original = item["originalPainting"]
        assert original == original_assets[name], "Original painting authority changed"
        source = ROOT/original["source"]["path"]
        assert sha(source) == original["source"]["sha256"]
        painting = whole_painting(Image.open(source).convert("RGBA"), original["transform"], original["canvas"])
        result, mask = repair(painting, Image.open(ROOT/fields[name]["path"]).convert("L"), name.startswith("pw_"))
        target = ROOT/item["editedSource"]["path"]
        assert record(target) == item["editedSource"]
        verify_pixels(result, Image.open(target).convert("RGBA"))
        mask_path = ROOT/item["addedPaint"]["path"]
        assert record(mask_path) == item["addedPaint"]
        assert mask.tobytes() == Image.open(mask_path).convert("L").tobytes()
    return record(folder/"inner-edge-repair.json")


def main(apply=False):
    draft = ROOT/"Assets_Draft/Priest/FullSet"
    docs = ROOT/"Docs/Research_Assets/Priest/FullSet"
    manifest_path = draft/"manifest.json"
    manifest = json.loads(manifest_path.read_text())
    jobs_path = docs/"jobs.json"
    jobs = json.loads(jobs_path.read_text(encoding="utf-8"))
    fields = json.loads((docs/"Contracts/functional-fields.json").read_text())["clearance"]
    output = draft/"GapRepair"
    output.mkdir(exist_ok=True)
    authority = output/"original-manifest.json"
    if not authority.exists():
        authority.write_bytes(manifest_path.read_bytes())
    originals = json.loads(authority.read_text())["assets"]
    records = {}
    for name in NAMES:
        item = originals[name]
        painting = whole_painting(Image.open(ROOT/item["source"]["path"]).convert("RGBA"), item["transform"], item["canvas"])
        fill = Image.open(ROOT/fields[name]["path"]).convert("L")
        result, mask = repair(painting, fill, name.startswith("pw_"))
        source = output/(name+"-inner-edge.png")
        result.save(source)
        verify_pixels(result, Image.open(source).convert("RGBA"))
        mask_path = output/(name+"-added-paint.png")
        mask.save(mask_path)
        strict_failure = None
        try:
            aperture(result, fill)
        except ValueError as error:
            strict_failure = str(error)
        records[name] = {"originalPainting": item, "editedSource": record(source), "addedPaint": record(mask_path),
            "addedPixels": int((np.asarray(mask)>0).sum()), "outerContourAndOpaquePaintUnchanged": True,
            "strictApertureFailure": strict_failure}
        if apply:
            job = next(j for j in jobs["jobs"] if j["name"] == name)
            if job.get("source") != source.relative_to(ROOT).as_posix():
                prior = dict(job)
                history = prior.pop("history", [])
                job["history"] = history+[prior]
            job.update(source=source.relative_to(ROOT).as_posix(), sourceSha256=record(source)["sha256"],
                transform={"crop": [0,0,*result.size], "scale": 1, "offset": [0,0]},
                status="done", qualityStatus="maintainer-authorized additive inner-edge pixel repair",
                repairAuthorization=AUTHORIZATION, repairRecipe="Tools/PriestInnerEdgeRepair.py")
        print(name+": added "+str(records[name]["addedPixels"])+" inner-edge pixels; strict aperture="+str(strict_failure), flush=True)
    report = {"schema": 1, "authorization": AUTHORIZATION, "date": "2026-11-08", "tool": record(__file__),
        "originalManifest": record(authority), "assets": records, "sourceJobsUpdated": apply, "liveValidated": False}
    (output/"inner-edge-repair.json").write_text(json.dumps(report, indent=2)+"\n")
    if apply:
        jobs_path.write_text(json.dumps(jobs, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    main(parser.parse_args().apply)
