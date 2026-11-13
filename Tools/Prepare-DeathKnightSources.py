"""Write resumable, one-painting-per-job requests for the full DK source pack."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "Docs/Research_Assets/DeathKnight/FullSet"
REF = "Docs/Research_Assets/ClassConceptSheets-2026-10-17/death-knight-v2.png"


def detail(name):
    if name.startswith("hp_") and "critter" not in name:
        return "Complete long hexagonal HEALTH CASING FRONT with a fully closed bare dipped right end. Preserve the single lowest mounting toe at the native dip. Keep three small squared grave-nail studs (five on boss). Both upper and lower rails and the full descending inner heel remain intact. The functional meter recess alone is genuinely transparent; no paint, wraps or runes cross that opening. No endcap ornament; this is the complete finished None casing."
    if "critter" in name:
        return "Small shaped critter-health casing, not a portrait or crystal. Preserve this exact asymmetric functional silhouette; no extra ornament."
    if name.startswith("cast_"):
        return "Small hexagonal CAST CASING FRONT; original rail, tips and functional opening. Paint the actual meter aperture transparent. No weapon/head ornament. The spiked version retains only its same-height small central axe-ridge."
    if name.startswith("pw_crystal"):
        return "Open-topped crystal cradle, same low U shape, same two short horns and exact clear crystal aperture. Short broken-runesteel prongs with narrow bone facets, no towering plate and no crystal painted into this casing."
    if name.startswith("orb_case"):
        return "Orb casing only: identical round aperture and rim thickness, compact angular cap and lower-right notch inside native bounds. Paint the inner circular glass/fill aperture fully transparent; exact native functional glass is kept separately. No orb, no badge inside the aperture."
    if name.startswith("portrait_"):
        return "Hexagonal portrait casing with identical empty model opening, broad plain metal facets and one tiny funerary corner clasp. No face, no creature, no skulls, no new glass painting."
    if name == "party_portrait_border":
        return "Small round party portrait ring with identical open model aperture, one subtle squared clasp on upper rim. No portrait/face/glass painted into opening."
    if name.startswith("actionbutton-border"):
        return "Action-button casing with EXACT original shape, band thickness and icon aperture. Newly painted forged metal and two tiny bone-inlaid squared funerary fastenings integrated in the rim, not outside it. Empty icon hole fully transparent; native functional glass remains a separate layer. No icon, rune badge, spikes or enlarged rim. Square/rounded/hex geometry must match the provided native template, not a circular substitute."
    if name == "orb-border":
        return "Thin circular resource rim, exact same band thickness and large empty aperture. Two small squared funerary joins within the existing ring; no cap or badge."
    if name == "minimap-border":
        return "Thin circular minimap rim at the native size and thickness with four small squared fastenings. Empty map aperture, no map art and no north ornament; north remains separate."
    if name.startswith("minimap-"):
        return "Original minimap experience/reputation arc backing assembly. Preserve every curved track, its position and open centre; only repaint physical backing material. No new minimap ring or map, no symbols or decoration across tracks."
    if name.startswith(("border-", "better-")):
        return "This is a NINE-SLICE BORDER TEXTURE ATLAS, not an assembled rectangular frame. Preserve each separate corner/edge cell at its exact place and size in this long canvas, fully transparent elsewhere. Repaint cells in cold runesteel with narrow bone edge details, no text and no added parts. Do not join cells into one bar."
    if name == "options-box":
        return "Tiny square options-panel border with exact empty square aperture, plain dark forged metal, narrow dull bone bevel, same thickness and corners; no ornament."
    if name.startswith("config_button"):
        return "Small utility gear button casing with unchanged semantic cog glyph. New cold runesteel facets and tiny bone-inlay detail on casing, same canvas/silhouette. Bright variant stays recognizably the hover state."
    if name == "icon_exit_flight":
        return "Small utility exit-flight button casing. Keep the semantic downward red arrow unchanged in meaning, position and shape, repaint only physical casing. No new symbol."
    if name == "point_plate":
        return "Small class-power point casing, exact circular plate/slot and opening. Dark rune-forged rim with one compact bone facet; no full rune or resource painted into the slot, no extra point or spike."
    return "Small round bag icon: one runeforged iron travel satchel with narrow bone clasp and short violet binding, no skull, no text; centred object inside a circular icon-safe region."


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    geometry = json.loads((ROOT / "Docs/Theme Asset Geometry.json").read_text())
    geometry["actionbutton-border-hex"] = {"canvas": [256, 256]}
    jobs = []
    for name, spec in geometry.items():
        if name == "nameplate_backdrop":
            continue  # Shared functional backing; it is not an ornamental frame.
        template = ROOT / "Docs/Research_Assets/Templates" / (name + ".png")
        if not template.exists():
            template = WORK / (name + "-native.png")
            Image.open(ROOT / "Assets" / (name + ".tga")).convert("RGBA").save(template)
        refs = [template.relative_to(ROOT).as_posix()]
        guide = ROOT / "Docs/Research_Assets/Templates" / (name + "-guide.png")
        if guide.exists():
            refs.append(guide.relative_to(ROOT).as_posix())
        refs.append(REF)
        prompt = (
            "Use case: precise-object-edit. Asset type: ONE standalone production-source painting for the full AzeriteUI Death Knight Ebon Oath set.\n"
            f"Edit target: image 1, native {name} texture. "
            "If image 2 is a geometry guide it marks bounds in cyan and the functional fill/aperture in magenta; do not paint those guide colours. The LAST reference is the existing DK concept, a material/identity reference only.\n"
            "Repaint this exact UI piece as NEW cold blackened runeforged iron, broad worn dull-steel facets, narrow aged bone-white inlays, squared funerary fastenings and very sparse muted blue-violet binding. Material needs its own hammering/chipped planes, not a hue shift. Top light, chunky hand-painted Warcraft UI. Dark restrained values, no glossy white rim, no photorealism. No glow or baked shadow; functional emission and shadow remain separate.\n"
            f"PIECE: {detail(name)}\n"
            f"Native geometry in original pixels: {json.dumps(spec)}. Maintain the same normalized geometry, same size in the full canvas, same silhouette family, same rail/band thickness and exact functional aperture. "
            "Do not recompose, move, enlarge, stretch, add a shield, skull, weapon, long spike, or replace this piece with a different object. Keep complete original ends; do not crop painted facets. "
            "Source art around every aperture must already be clear; no later stencil/erasure is allowed.\n"
            "Output a single complete object on a TRUE TRANSPARENT canvas matching the original canvas ASPECT RATIO. No black rectangle, no checkerboard painting, no scene, no caption, no label, no lettering, no watermark, no conceptual assembly or extra study. Preserve generous original transparent margins and the template's exact piece placement."
        )
        jobs.append({"name": name, "role": "casing-source", "geometry": spec, "references": refs, "prompt": prompt, "status": "pending"})
    jobs.append({"name": "bag-icon", "role": "icon-source", "references": [REF], "geometry": {"canvas": [256, 256]}, "status": "pending", "prompt": "Use case: stylized-concept. ONE small round-icon-safe Death Knight travel satchel, newly hand-painted cold blackened runeforged iron plates and violet cloth, one compact bone-white clasp, broad dull steel bevels. Top light, chunky Warcraft UI, few readable facets at 28px. Reference is material authority only. Whole centred satchel with generous true transparent margin on square canvas, no skull, no weapon, no scene, no text, no lettering, no glow or shadow. This is a standalone bag icon, not a frame or crest."})
    path = WORK / "jobs.json"
    if path.exists():
        prior = {job["name"]: job for job in json.loads(path.read_text(encoding="utf-8"))["jobs"]}
        for job in jobs:
            if job["name"] in prior:
                job.update({key: value for key, value in prior[job["name"]].items() if key in ("status", "original", "source", "sourceSha256", "outputHint")})
    path.write_text(json.dumps({"schema": 1, "tool": "built-in image_gen.imagegen", "jobs": jobs}, indent=2) + "\n", encoding="utf-8")
    print(f"{len(jobs)} individual painting jobs; " + str(sum(j['status'] == 'done' for j in jobs)) + " complete")


if __name__ == "__main__":
    main()
