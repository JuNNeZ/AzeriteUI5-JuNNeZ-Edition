"""Queue local source repaints against the frozen current-layout apertures."""
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
helper = runpy.run_path(str(ROOT / "Tools/Prepare-PriestWarlockSources.py"))


def queue(theme):
    folder = ROOT / "Docs/Research_Assets" / theme / "FullSet"
    jobs = json.loads((folder / "jobs.json").read_text(encoding="utf-8"))["jobs"]
    searches = json.loads((ROOT / "Assets_Draft" / theme / "FullSet/registration-search.json").read_text())["assets"]
    for job in jobs:
        result = searches.get(job["name"])
        if job["status"] != "done" or not result or (result.get("best") and result["best"]["passed"]):
            continue
        if result["sourceSha256"] != job["sourceSha256"]:
            continue
        name = job["name"]
        if name == "hp_mid_case" and theme == "Warlock":
            reuse = next(j for j in jobs if j["name"] == "hp_low_case")
            request = folder / (name + "-whole-source-reuse-v4.json")
            request.write_text(json.dumps({"reason": "Reuse intact same-class health painting; independently measured 41 legal mid-tier registrations", "prompt": reuse["actualPrompt"], "references": reuse["references"], "selectedWholeSource": {"path": reuse["source"], "sha256": reuse["sourceSha256"]}}, indent=2) + "\n")
            helper["revise"](theme, name, request)
            helper["record"](theme, name, reuse["original"])
            continue
        selected_source = job["source"]
        guide = result.get("sourceGuide")
        if not guide:
            # The rejected opaque-background attempt has no valid registration.
            # Return to its intact, correctly proportioned predecessor for edit.
            prior = job["history"][-1]
            selected_source = prior["source"]
            guide = {"path": prior["references"][-1], "sha256": helper["sha"](ROOT / prior["references"][-1])}
        assert helper["sha"](ROOT / guide["path"]) == guide["sha256"]
        if name.startswith("hp_"):
            change = "Make the EMPTY opening clear all the way through BOTH end diagonals. The right inner diagonal needs to move RIGHT by 5 native pixels; the left inner diagonal needs to move LEFT by 3 native pixels. Deepen the right inner heel by 3 pixels without moving the sole OUTER toe. Preserve the long top and bottom rails, thinning their inner bevel only as needed. The opening must be truly transparent, with NO smoky translucent pane."
        elif name.startswith("cast_"):
            change = "Make the EMPTY cast opening about 30 percent TALLER inside the UNCHANGED outer body: pull the upper inner lip UP, lower inner lip DOWN. Thin the inner ivory/brass bevels and shorten any inward clasp tip. Cyan is the union of all real cast slots, including the taller compact unit frames. Preserve complete closed left and right sockets."
        elif name.startswith("pw_"):
            change = "Shorten BOTH inward-pointing upper tips by a further 50 source pixels: repaint as small OUTWARD-facing bevels. The upper inner corners must end well OUTSIDE the cyan diagonals, not touch them. Move inner left sloping lip LEFT and right lip RIGHT; retain the outside points and broad low base. Keep the lower cyan flat edge clear. Finished continuous cradle, no cut stumps."
        elif name.startswith("orb_case"):
            change = "Enlarge the EMPTY circular opening by 6 percent in diameter, centred exactly on the cyan circle, inside the SAME outer rim. Thin only the inner dark bevel; retain every outer facet and detail. Remove all translucent dust, smoke and glass from the entire opening. Even the faintest painted alpha inside cyan is forbidden because original functional glass will sit beneath this rim."
        else:
            change = "Replace the clipped/diagonal INNER top-left and bottom-right opening corners with TRUE right-angle SQUARE inner corners. Cyan top-left and bottom-right must be entirely empty, not a diagonal bevel or clasp. Pull inner edges OUTWARD by 2 native pixels; retain exact outer dimensions. Consume a little of the violet inlay if needed. Gold chain clasps stay on the rim."
        prompt = (
            f"Use case: precise-object-edit. Image 1 is the COMPLETE existing {theme} {name} painting to edit. Image 2 is ONLY a diagnostic copy of that SAME painting: cyan traces the required empty aperture; solid red marks forbidden overlapping paint. "
            + change + " ALL cyan AND red regions must become genuinely alpha-zero empty space, with a generous clear margin of 3 native game pixels beyond the cyan line. Repaint the physical inner contour smoothly outside that margin; simply recolouring red does not repair it. "
            "INVARIANTS: exact same outer silhouette, width, height, lowest toe, upper point, placement, material colours, clasps and class identity; change only the inner bevel/aperture. No global resizing, stretching or re-composition. Output the entire uncut finished painting on true transparency, both inside and outside. Never reproduce the diagnostic's dark background, cyan, red, text or caption. No glass, fill, fog, shadow, glow, matte, specks, separate parts or extra objects. Preserve the existing canvas aspect ratio and transparent padding."
        )
        revision = job.get("revision", 1) + 1
        request = folder / (name + f"-v{revision}-request.json")
        data = {"reason": "Current-layout functional aperture or exact native glass still overlaps source paint", "references": [selected_source, guide["path"]], "prompt": prompt, "failedSearch": result}
        assert not request.exists(), "Never overwrite an immutable repaint request"
        request.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        helper["revise"](theme, name, request)


if __name__ == "__main__":
    for theme in ("Priest", "Warlock"):
        queue(theme)
