"""Prepare resumable whole-painting requests for the approved Priest/Warlock sets."""
from pathlib import Path
import argparse
import copy
import hashlib
import json

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MATERIAL = {
    "Priest": "pale brushed silver, narrow ivory enamel and dark violet stone inlays, with small antique-gold liturgical clasps; broad hand-painted facets, not polished white plastic",
    "Warlock": "pitted black fel iron, dark violet enamel and tarnished brass bevels, with small chain-fastened joins; broad heavy hand-painted facets, no neon green metal",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def detail(name, theme):
    join = "small gold liturgical clasp" if theme == "Priest" else "small brass chain clasp"
    if name.startswith("hp_") and "critter" not in name:
        return f"Complete long hexagonal bare HEALTH CASING FRONT, complete right upper point and descending dipped heel, ONE sole lowest native toe. Three low studs (five on boss), one {join}. The functional health aperture must be genuinely transparent and at least as large as the template's fill guide. No removable endcap/relic, no cut shoulder; this is the finished None casing."
    if "critter" in name:
        return "Small shaped critter health casing, exactly its asymmetric native silhouette and empty health aperture. Not a portrait, orb or resource crystal. No ornament."
    if name.startswith("cast_"):
        return "Small hexagonal castbar casing FRONT: identical rail, tips and empty functional aperture. Spiked variant keeps one same-height central marker. No separate cast head or large relic. Preserve the complete left socket, normal/protected geometry and closed ends."
    if name.startswith("pw_crystal"):
        return f"Open-topped broad asymmetrical crystal cradle, short native-height prongs, same low U-shape and exact empty crystal opening. One {join} at the base. No crystal painted in the hole, no towers or plate across the top."
    if name.startswith("orb_case"):
        return "Round orb casing only, same band thickness and exact circular opening, compact cap and low notch within native bounds. Inner glass/fill aperture fully transparent; exact native functional glass is preserved separately. No liquid, no floating badge or icon in the hole."
    if name.startswith("portrait_"):
        return f"Hexagonal portrait casing: identical fully empty model aperture and band thickness, broad plain facets, one tiny {join} on a vertex. No face, animal, gem in opening or newly painted glass."
    if name == "party_portrait_border":
        return f"Small circular party portrait rim, identical clear model aperture and band thickness, one {join} integrated into rim. No portrait or glass painted inside."
    if name.startswith("actionbutton-border"):
        return f"Action-button casing: EXACT reference shape (circle/square/rounded/hex), same rim width and icon opening. Two tiny {join} details integrated INSIDE the rim, no spikes, icons, extra badges or larger rim. Central icon aperture is fully transparent; native functional glass stays separate."
    if name in ("orb-border", "minimap-border"):
        return f"Thin circular rim: exact native band thickness and large clear aperture. At most four tiny {join} details inside the existing rim. No cap, map, liquid, north ornament, badge or image in the hole."
    if name.startswith("minimap-"):
        return "Original experience/reputation curved backing tracks: preserve all tracks, positions, curvature and clear open centre. Repaint physical backing only; no new map/rim, labels or symbols across tracks."
    if name.startswith(("border-", "better-")):
        return "NINE-SLICE BORDER TEXTURE ATLAS: same separate corner/straight-edge cells, exact original cell placement, canvas aspect and empty margins. These are isolated atlas parts, NOT an assembled rectangular frame. No marks outside those cells; do not join them into a bar. Newly painted physical corner/rail material only."
    if name == "options-box":
        return "Tiny square panel border, same square aperture/corners/thickness, plain material with one restrained join. Empty middle, no emblem."
    if name.startswith("config_button"):
        return "Small utility gear button: preserve same cog meaning, silhouette and button canvas; newly paint its physical casing only. Bright variant is the same object's hover state. No unrelated symbol or text."
    if name == "icon_exit_flight":
        return "Small exit-flight utility button: retain downward red arrow meaning, placement and shape; newly paint surrounding physical casing only. No replacement glyph, weapon or badge."
    if name == "point_plate":
        return "Small circular class-power point casing/slot, same opening and outline. No resource/point painted into the slot, no extra points, no large ornament."
    raise ValueError(name)


def prepare(theme):
    work = ROOT / "Docs/Research_Assets" / theme / "FullSet"
    work.mkdir(parents=True, exist_ok=True)
    draft = ROOT / "Assets_Draft" / theme
    concept = ROOT / "Docs/Research_Assets" / theme / "approved-concept.png"
    geometry = json.loads((ROOT / "Docs/Theme Asset Geometry.json").read_text(encoding="utf-8"))
    geometry["actionbutton-border-hex"] = {"canvas": [256, 256]}
    selected = "v7" if theme == "Priest" else "v4"
    original = draft / "Sources" / ("hp_cap_case-" + selected + ".png")
    # Reference extraction only, never a runtime painting/source crop. A pure
    # material swatch cannot accidentally become another UI piece's geometry.
    material_ref = work / "material-reference.png"
    concept_image = Image.open(concept).convert("RGBA")
    concept_image.crop((1358, 826, 1504, 1000)).save(material_ref)
    registration = json.loads((draft / "registrations.json").read_text(encoding="utf-8"))[selected]
    jobs = []
    for name, spec in geometry.items():
        # options-box is a flat white functional panel mask, not physical art.
        if name in ("nameplate_backdrop", "options-box"):
            continue
        template = ROOT / "Docs/Research_Assets/Templates" / (name + ".png")
        if not template.exists():
            template = work / (name + "-native.png")
            Image.open(ROOT / "Assets" / (name + ".tga")).convert("RGBA").save(template)
        refs = [template.relative_to(ROOT).as_posix()]
        guide = ROOT / "Docs/Research_Assets/Templates" / (name + "-guide.png")
        if guide.exists():
            refs.append(guide.relative_to(ROOT).as_posix())
        # Use the accepted isolated painting for material continuity. The
        # full concept remains the recorded motif authority; its coloured
        # game-data fills must not leak into a new casing's transparent hole.
        refs.append(material_ref.relative_to(ROOT).as_posix())
        prompt = (
            f"Use case precise-object-edit. ONE standalone source painting for AzeriteUI {theme}. Image 1 is native {name} edit target and the ONLY geometry authority; image 2 if present is its exact cyan/magenta guide (magenta stays empty). LAST image contains only MATERIAL SWATCHES from the approved {theme} concept, never an object to reproduce. "
            f"Repaint as NEW physical {MATERIAL[theme]}. Material must have its own facets and surface character, not a hue shift of native pixels. "
            f"PIECE: {detail(name, theme)} "
            f"Native specification in original pixels: {json.dumps(spec)}. Preserve same normalized silhouette, placement, rail thickness and fully clear aperture. Keep all physical painting OUTSIDE the functional opening. "
            "Do not recompose, stretch, shift, enlarge, add large ornaments or paint fill/glass/icons into empty openings. Complete whole painting must fit before any layer splitting; no later stencil, alpha erasure or RGB extension is allowed. "
            "Handpainted Warcraft UI, top light, broad readable slabs and restrained mid-dark values. Silver is medium grey with narrow pale highlights; no white surface, pale fog, white matte, checkerboard or coloured fringe. No glow, baked shadow, guide colours, caption, labels or watermark. Output ONE entire object on TRUE TRANSPARENT background with original transparent margins and canvas ASPECT RATIO. All empty space, both outside and inside, has alpha zero. Not a concept board or assembled HUD."
        )
        job = {"name": name, "role": "casing-source", "geometry": spec, "references": refs, "conceptAuthority": {"path": concept.relative_to(ROOT).as_posix(), "sha256": sha(concept)}, "prompt": prompt, "status": "pending"}
        if name == "hp_cap_case":
            job.update(status="done", source=original.relative_to(ROOT).as_posix(), sourceSha256=sha(original), transform=registration["transform"], authorization="Representative visually approved in chat 2026-11-07")
        jobs.append(job)
    ornaments = {
        "Priest": {
            "cast-head": "ONE compact Light's Wrath-inspired liturgical staff-clasp castbar head, distinct from the T'uure health cap. Small ivory/silver staff socket with violet enamel and tiny gold disciplinary seal. Broad OPAQUE central mounting body around a small diamond motif; no long staff or giant wings. Balanced around centre for native 48px cast-head slot.",
            "resource-badge": "ONE small Conclave crystal-cradle seal, a restrained violet liturgical knot set in silver/ivory, distinct from the health reliquary and cast clasp. Readable in a 32px shared slot, opaque simple central form, no text or intricate rings.",
            "minimap-north": "ONE narrow small silver/ivory compass north point with restrained violet inlay, plain faceted point. No rune badge, starburst or repeated health reliquary.",
            "bag-icon": "ONE small travel satchel of dark violet cloth with pale silver corners and tiny ivory/gold liturgical clasp, centred in a round-icon-safe square region. No reliquary, weapon, halo or text.",
        },
        "Warlock": {
            "cast-head": "ONE compact Thal'kiel-inspired gilded demonic skull fitting for native 48px cast head, distinct from Ulthalesh health cap. OPAQUE black iron/brass mounting socket behind small skull and muted violet eyes, no long staff, giant horns or flames; painted mass centred on socket.",
            "resource-badge": "ONE small Black Harvest crystal-cradle seal in black iron/brass with restrained violet enamel, simple compact opaque form readable at 32px. No scythe, skull, text or bright green glow.",
            "minimap-north": "ONE narrow small black fel-iron compass north point with tarnished brass facets and restrained violet inlay. No skull or repeated class badge.",
            "bag-icon": "ONE small black/violet cloth reagent satchel with tarnished brass casing/clasp and a short chain at its side, centred in round-icon-safe square. No skull, giant horns, text, spell effect or weapon.",
        },
    }
    for name, description in ornaments[theme].items():
        jobs.append({"name": name, "role": "ornament-source", "geometry": {"canvas": [256, 256]}, "references": [concept.relative_to(ROOT).as_posix()], "status": "pending", "prompt": f"Use case stylized-concept. {description} Materials: {MATERIAL[theme]}. Newly handpainted Warcraft UI with broad game-size-readable facets, top light and restrained dark values. Reference is material/motif authority only. ONE whole standalone object with generous TRUE transparent margins on square canvas. No backdrop, castbar/HUD, fill, other objects, text, watermark, glow or shadow. Entire uncut object inside canvas."})
    path = work / "jobs.json"
    if path.exists():
        old = {j["name"]: j for j in json.loads(path.read_text(encoding="utf-8"))["jobs"]}
        for job in jobs:
            prior = old.get(job["name"])
            if prior and (prior["status"] == "done" or prior.get("revision", 1) > 1):
                if prior["status"] == "done":
                    assert sha(ROOT / prior["source"]) == prior["sourceSha256"]
                job.clear()
                job.update(prior)  # Preserve actual completed prompt/reference history.
    path.write_text(json.dumps({"schema": 1, "theme": theme, "tool": "built-in image_gen.imagegen", "authorization": "Fint, gør temaerne færidge. (2026-11-07); finish both complete selectable themes, retain separate live/production status", "jobs": jobs}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{theme}: {len(jobs)} source jobs, {sum(j['status']=='done' for j in jobs)} complete")


def record(theme, name, original):
    path = ROOT / "Docs/Research_Assets" / theme / "FullSet/jobs.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    job = next(j for j in data["jobs"] if j["name"] == name)
    source = Path(original).resolve(strict=True)
    if not source.is_relative_to(Path("C:/Users/Jonas/.codex/generated_images").resolve()) or source.suffix.lower() != ".png":
        raise ValueError("Expected complete original built-in generated PNG")
    revision = job.get("revision", 1)
    target = ROOT / "Assets_Draft" / theme / "FullSet" / ("Sources" if revision == 1 else "Revisions") / (name + ("" if revision == 1 else "-v" + str(revision)) + ".png")
    target.parent.mkdir(parents=True, exist_ok=True)
    raw = source.read_bytes()
    if target.exists() and target.read_bytes() != raw:
        raise ValueError("Retain existing source; use an explicit revision instead")
    target.write_bytes(raw)
    job.update(status="done", qualityStatus="unreviewed", source=target.relative_to(ROOT).as_posix(), sourceSha256=sha(target), original=source.as_posix(), originalSha256=sha(source), actualPrompt=job["prompt"], referenceHashes={ref: sha(ROOT / ref) for ref in job["references"]})
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{theme}/{name}: intact original saved; {sum(j['status']=='done' for j in data['jobs'])}/{len(data['jobs'])}")


def revise(theme, name, request):
    path = ROOT / "Docs/Research_Assets" / theme / "FullSet/jobs.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    job = next(j for j in data["jobs"] if j["name"] == name)
    assert job["status"] == "done", "A revision must retain a completed predecessor"
    assert sha(ROOT / job["source"]) == job["sourceSha256"]
    change = json.loads(Path(request).read_text(encoding="utf-8"))
    assert change["reason"] and change["prompt"] and change["references"]
    prior = copy.deepcopy(job)
    history = prior.pop("history", [])
    prior["qualityStatus"] = "rejected: " + change["reason"]
    job.update(status="pending", revision=job.get("revision", 1) + 1,
        history=history + [prior], prompt=change["prompt"], references=change["references"], qualityStatus="revision queued: " + change["reason"])
    for key in ("source", "sourceSha256", "original", "originalSha256", "actualPrompt", "referenceHashes", "transform"):
        job.pop(key, None)
    write = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    path.write_text(write, encoding="utf-8")
    print(f"{theme}/{name}: queued revision {job['revision']}; rejected original preserved")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "record", "revise"))
    parser.add_argument("theme", choices=("Priest", "Warlock", "Both"))
    parser.add_argument("name", nargs="?")
    parser.add_argument("original", nargs="?")
    args = parser.parse_args()
    if args.command == "prepare":
        for theme in ("Priest", "Warlock") if args.theme == "Both" else (args.theme,):
            prepare(theme)
    else:
        if args.theme == "Both" or not args.name or not args.original:
            parser.error("record requires one theme, asset name and original PNG")
        if args.command == "record":
            record(args.theme, args.name, args.original)
        else:
            revise(args.theme, args.name, args.original)
