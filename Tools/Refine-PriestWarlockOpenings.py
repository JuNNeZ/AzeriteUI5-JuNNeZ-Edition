"""Curated source-only inner-contour repairs; retain rejected attempts intact."""
import json
import runpy

from PriestWarlockAssetContracts import ROOT

helper=runpy.run_path(str(ROOT/"Tools/Prepare-PriestWarlockSources.py"))


def jobs(theme):
    path=ROOT/"Docs/Research_Assets"/theme/"FullSet/jobs.json"
    return path,{j["name"]:j for j in json.loads(path.read_text(encoding="utf-8"))["jobs"]}


def reuse(theme,target,selected):
    path,items=jobs(theme);old,source=items[target],items[selected]
    request=path.parent/(target+f"-v{old.get('revision',1)+1}-reuse.json")
    request.write_text(json.dumps({"reason":"Intact whole same-class painting independently fits this native tier", "prompt":source["actualPrompt"],"references":source["references"],"selectedWholeSource":source["source"]},indent=2)+"\n")
    helper["revise"](theme,target,request)
    helper["record"](theme,target,source["original"])


def queue(theme,name,change,old_revision=None):
    path,items=jobs(theme);job=items[name];selected=job
    if old_revision:
        selected=next(j for j in job["history"] if j.get("revision",1)==old_revision)
    prompt=(f"Use case: precise-object-edit. Edit this ONE {theme} UI casing painting. "+change+
        " Keep its entire OUTER contour, outer dimensions, placement, proportions, lowest outer toe, materials, colours and physical details unchanged. Change only the INSIDE edge of the empty opening. "
        "The output is one complete finished continuous casing. ALL empty space inside AND outside is genuinely transparent alpha zero: no pane, glass, mist, smoke, matte, checkerboard, shadow, glow, loose specks or other objects. No red/cyan marks or text. Do not crop, stretch or resize the whole object. Keep the same canvas aspect and padding.")
    revision=job.get("revision",1)+1;request=path.parent/(name+f"-v{revision}-source-only-request.json")
    assert not request.exists()
    request.write_text(json.dumps({"reason":"Measured residual aperture/glass interference; source-only repaint avoids copying diagnostic colours", "prompt":prompt,"references":[selected["source"]]},indent=2)+"\n")
    helper["revise"](theme,name,request)


if __name__=="__main__":
    reuse("Warlock","orb_case_hi","orb_case_low")
    queue("Priest","hp_mid_case","Make the central EMPTY health opening 30 percent TALLER and 3 percent WIDER inside the unchanged outside body. Repaint thinner inner bevels, with the top lip farther up, bottom lip farther down, and both inner end diagonals farther outward. No clasp may enter the hole.",2)
    for theme in ("Priest","Warlock"):
        queue(theme,"hp_boss_case","Make the long EMPTY health opening 15 percent TALLER and 3 percent WIDER inside the unchanged outside body. In particular pull the RIGHT inner diagonal toward the outer right tip, leaving only a narrow metal bevel there. Keep the lower left notch and the sole outer right mounting heel.")
    queue("Priest","orb_case_hi","Make the EMPTY circular opening a further 6 percent LARGER in diameter inside the same outside rim, thinning only the inner dark metal bevel. Its centre stays fixed. Remove all faint translucent dust and pane from the opening; there must be no painted alpha at all there.")
    queue("Warlock","actionbutton-border-square","Make the EMPTY icon opening 10 percent LARGER in both width and height inside the same outside rim. It must be a TRUE SQUARE with four exact 90-degree INNER corners, no diagonal cuts or corner radius. Move the inner lips outward, thinning the violet and brass rim locally. Both chain clasps stay entirely on the remaining rim.")
