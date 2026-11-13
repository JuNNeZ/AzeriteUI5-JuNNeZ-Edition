"""Queue source repairs from measured failures, preserving every rejected original."""
from pathlib import Path
import json
import runpy
import shutil

ROOT = Path(__file__).resolve().parent.parent
HELPER = runpy.run_path(str(ROOT / "Tools/Prepare-PriestWarlockSources.py"))


def queue(theme):
    path = ROOT / "Docs/Research_Assets" / theme / "FullSet/jobs.json"
    jobs = json.loads(path.read_text(encoding="utf-8"))["jobs"]
    long_cases = {"hp_mid_case", "hp_low_case", "hp_boss_case"}
    crystal = {"pw_crystal_case", "pw_crystal_case_low"}
    backgrounds = {"actionbutton-border-square-rounded", "minimap-border", "point_plate"} if theme == "Priest" else set()
    buttons = {"actionbutton-border-square", "actionbutton-border-square-rounded"} if theme == "Warlock" else set()
    fresh = long_cases | ({"hp_critter_case"} if theme == "Warlock" else set())
    for job in jobs:
        name = job["name"]
        if name not in fresh | crystal | backgrounds | buttons or job.get("revision", 1) != 1:
            continue
        assert job["status"] == "done"
        template = "Docs/Research_Assets/Templates/" + name + ".png"
        if name in fresh:
            refs = [template]
            guide = "Docs/Research_Assets/Templates/" + name + "-guide.png"
            if (ROOT / guide).exists():
                refs.append(guide)
            refs.append("Docs/Research_Assets/" + theme + "/FullSet/material-reference.png")
            ratio = (job["geometry"]["painted"][2] - job["geometry"]["painted"][0]) / (job["geometry"]["painted"][3] - job["geometry"]["painted"][1])
            reason = "No whole uniform registration clears the native fill while retaining native bounds/toe" if name in long_cases else "Wrong shape; previous source was a long bar"
            prompt = (
                f"Use case precise-object-edit. Repaint ONLY image 1, the native {theme} {name} casing. This image alone defines geometry. Next image if present is its native cyan/magenta functional guide; every magenta pixel stays transparent. LAST image is pure material swatches, not another object. "
                f"New handpainted {HELPER['MATERIAL'][theme]}. {HELPER['detail'](name, theme)} "
                f"Critical NATIVE PAINTED BODY ASPECT RATIO is {ratio:.4f}:1 (width:height), distinct from the padded canvas. "
                + ("Match this exact very long, low, slender silhouette; do NOT compress its length, make it taller or thicken the rails. " if name in long_cases else "Match this one small near-square asymmetric native hexagonal critter rim. Absolutely no long health bar, portrait, orb or resource crystal. ")
                +
                f"Exact native pixel geometry: {json.dumps(job['geometry'])}. The transparent aperture must include ALL of the functional fill guide, with a thin clear margin. "
                + ("Match complete upper point, left closed socket and sole right descending heel/toe. " if name in long_cases else "Match the complete small asymmetric hexagonal native outline and its empty centre. ")
                +
                "No resources, endcap, relic, text or background. Entire complete casing, physical paint OUTSIDE the fill aperture, not a solid plank or bar. Genuine alpha-zero transparency inside and outside. No white matte, fog, checkerboard, guide colours, fringes, glow, shadow or labels. Medium-dark painted metal with narrow highlights only. No later stencil/erasure/warping; the entire source must fit intact."
            )
        elif name in backgrounds:
            reason = job["qualityStatus"]
            refs = [job["source"]]
            prompt = (
                f"Use case background-removal. Repair this rejected {theme} {name} source. Keep the ENTIRE physical silver/ivory/violet/gold object, its real painted facets, silhouette, proportions, details and placement. "
                "Remove ALL accidental grey/white fog, white matte, checkerboard and coloured fringe from outside the object AND its central aperture. They are background contamination, not glass or part of the object. The result must contain ONLY the opaque physical object with clean contour AA on genuine transparent alpha-zero empty space. "
                "No white backdrop, no shadow, no glow, no texture or dust in the empty opening; nothing else. Do not crop the physical object, narrow its aperture, add parts, enlarge the rim, change the artwork or recompose it. Output one entire cleaned source with generous transparent margins."
            )
        else:
            reason = "Solid prong wedges invade crystal fill" if name in crystal else "Painted inner rim/corner invades icon fill"
            guide = "Assets_Draft/" + theme + "/FullSet/Review/" + name + "-source-aperture-guide.png"
            frozen = path.parent / "Inputs" / (name + "-v2-aperture-guide.png")
            frozen.parent.mkdir(parents=True, exist_ok=True)
            if frozen.exists():
                assert frozen.read_bytes() == (ROOT / guide).read_bytes()
            else:
                shutil.copy2(ROOT / guide, frozen)
            guide = frozen.relative_to(ROOT).as_posix()
            refs = [job["source"], guide, template]
            repair = "The two inward upper prong wedges cross the cyan aperture. Repaint those prongs as short OUTWARD-facing faceted tips with the inner upper lips pulled back beyond the cyan contour. Keep the full broad low U-shaped cradle and all clasps/joins." if name in crystal else "The inner rim/corners cross the cyan icon aperture. Pull the inner painted lip OUTWARD until the ENTIRE cyan square/rounded-square aperture is clear. Repaint thinner inner bevels and smaller corner facets inside the unchanged outer contour; retain circle/square/rounded shape exactly."
            prompt = (
                f"Use case precise-object-edit. Image 1 is the complete existing {theme} {name} source to repaint locally. Image 2 is a diagnostic COPY only: cyan marks the exact required native functional aperture and red marks interfering opaque paint. Image 3 is native outer geometry authority. "
                f"{repair} Keep the existing material, all other facets, outer dimensions and mounting position. ALL solid red regions must move OUTSIDE the cyan opening with about one native source-pixel clearance; no physical paint, pane, crystal, icon or glass inside that contour. "
                "This is a NEW whole source repaint, not an alpha stencil. Preserve a finished continuous physical rim, no cut stump, no detached fragments. Entire object on genuine transparent alpha-zero background with the opening also truly empty. No cyan/red guide pixels, diagnostic caption, grey backdrop, fog, checkerboard, white matte, glow, labels or shadow. No stretching, enlargement or clipping."
            )
        request = {"reason": reason, "prompt": prompt, "references": refs}
        target = path.parent / (name + "-v2-request.json")
        text = json.dumps(request, indent=2, ensure_ascii=False) + "\n"
        if target.exists():
            assert target.read_text(encoding="utf-8") == text, "Existing request changed"
        else:
            target.write_text(text, encoding="utf-8")
        HELPER["revise"](theme, name, target)


if __name__ == "__main__":
    for theme in ("Priest", "Warlock"):
        queue(theme)
