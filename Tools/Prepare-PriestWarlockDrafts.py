"""Freeze approved directions and native/Druid references for two new themes.

Preparation only: creates no runtime textures, approval of exports, or Lua hooks.
Existing records are verified rather than overwritten.
"""
from pathlib import Path
import hashlib
import json
import shutil

from PIL import Image
from ThemeHealthEndcaps import lowest_point, terminal_mask

ROOT = Path(__file__).resolve().parent.parent
APPROVAL = "2026-11-07: Ja, brug begge koncepter og Druid-størrelsen"
THEMES = {
    "Priest": {
        "subtitle": "The Conclave / Netherlight",
        "material": "Dark violet stone, ivory enamel, pale brushed silver and narrow antique-gold clasps",
        "health": "T'uure-inspired split naaru reliquary on a solid silver mounting body; optional Xal'atath study later",
        "cast": "Separate small Light's Wrath staff clasp",
        "badge": "Small Conclave seal on the crystal cradle only; no floating orb icon",
        "effects": ["sanctum", "covenant", "priestvoid"],
        "avoid": "Paladin sun discs, large wings, weapons across fills, oversized gold rims",
    },
    "Warlock": {
        "subtitle": "The Black Harvest / Dreadscar",
        "material": "Pitted black fel iron, restrained violet enamel, tarnished brass and small chain clasps",
        "health": "Ulthalesh-inspired hooked scythe root on a solid opaque mounting cuff",
        "cast": "Separate compact Thal'kiel skull fitting",
        "badge": "Small Black Harvest seal on the crystal cradle only; no floating orb icon",
        "effects": ["affliction", "demonology", "destruction"],
        "avoid": "Demon Hunter glaives, giant horns, repeated skulls, green paint across functional fills",
    },
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_once(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = content.encode("utf-8")
    if path.exists():
        if path.read_bytes() != raw:
            raise ValueError(f"Existing checkpoint differs; review explicitly: {path}")
    else:
        path.write_bytes(raw)


def record(path):
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)}


def main():
    geometry = json.loads((ROOT / "Docs/Theme Asset Geometry.json").read_text())
    geometry["actionbutton-border-hex"] = {"canvas": [256, 256]}
    for theme, direction in THEMES.items():
        draft = ROOT / "Assets_Draft" / theme
        research = ROOT / "Docs/Research_Assets" / theme
        concept = ROOT / "Docs/Research_Assets/ClassConceptSheets-2026-10-17" / (theme.lower() + "-v2.png")
        approved = research / "approved-concept.png"
        approved.parent.mkdir(parents=True, exist_ok=True)
        if approved.exists() and sha(approved) != sha(concept):
            raise ValueError(f"Existing approved concept differs: {approved}")
        if not approved.exists():
            shutil.copy2(concept, approved)
        cases = {}
        for name in ("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case"):
            native = ROOT / "Assets" / (name + ".tga")
            druid = ROOT / "Assets/Druid" / (name + "-over.tga")
            refs = sorted((ROOT / "Assets/Druid").glob("ornament-*-" + name + ".tga"))
            if not refs:
                raise ValueError(f"Missing Druid cap reference: {name}")
            boxes = [Image.open(p).convert("RGBA").getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox() for p in refs]
            union = [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]
            toe, reference_toe = lowest_point(Image.open(native)), lowest_point(Image.open(druid))
            delta = [toe[i] - reference_toe[i] for i in (0, 1)]
            mask_path = research / "Contracts" / (name + "-native-terminal.png")
            mask_path.parent.mkdir(parents=True, exist_ok=True)
            mask = terminal_mask(Image.open(native))
            if mask_path.exists():
                with Image.open(mask_path) as saved:
                    assert saved.tobytes() == mask.tobytes(), "Frozen native terminal changed"
            else:
                mask.save(mask_path)
            cases[name] = {"native": record(native), "nativeTerminal": record(mask_path),
                           "druidBare": record(druid), "druidCaps": [record(p) for p in refs],
                           "nativeToe": list(toe), "druidToe": list(reference_toe),
                           "approvedFootprint": [union[i] + delta[i % 2] for i in range(4)]}
        inventory = []
        for native in sorted((ROOT / "Assets").glob("*.tga")):
            spec = geometry.get(native.stem)
            replace = spec is not None and native.stem != "nameplate_backdrop"
            inventory.append({**record(native), "geometry": spec,
                              "disposition": "new whole painting required" if replace else "shared native functional/semantic asset; retain"})
        brief = f"""# {theme} — {direction['subtitle']}

Status: approved design direction; representative source production pending.
Priority: Forever first, then Retail. {APPROVAL}.
Approval covers the existing concept and Druid maximum footprint only.
It does not approve generated paintings, fitting, installation or live rendering.

- Base/inlay/joinery: {direction['material']}.
- Health endcap: {direction['health']}.
- Cast head: {direction['cast']}.
- Resource badge: {direction['badge']}.
- Existing Lite+ keys: {', '.join(direction['effects'])}.
- Bare health endings: complete closed dipped termination, identical with None/on.
- Rail studs: three low native-size studs, five on boss; no large added plates.
- Crystal cradle: short native-height prongs in the approved material, clear open top.
- Orb: native circular opening and exact native glass; compact cap/notch.
- Portrait: native hexagonal opening, one small vertex clasp, native glass.
- North marker: one small material-matched compass tip inside native bounds.
- Set piece: none; retain existing class-resource and pet layouts.
- Avoid: {direction['avoid']}.

## Next required evidence

1. Paint one representative hp_cap_case and one independent whole endcap.
2. Validate intact source aperture before layer splitting; never stencil native alpha.
3. Freeze the new bare casing's entire terminal before fitting; native masks here
   are immutable reference baselines, not a substitute for the new painting mask.
4. Respect the toe-translated Druid envelope and <=20% combined cap/bridge overlap.
5. Render complete player/mirrored target None/on at 1x/2x in fixed union viewports,
   empty/half/full health and prediction; retain failures.
6. Obtain representative visual/live review before expanding to all sizes.
7. Deliver a selectable theme through ThemeEngine/ThemeEffects, Themes controls,
   loader and enable command; preserve saved anchors and independent cast settings.
8. Test Forever and Retail /reload, combat, Edit Mode, threat, prediction and BugSack.

Concept is material/motif authority only, never a source of production texture crops.
See Docs/Theme Asset Production Workflow.md and Docs/Theme Source Integrity.md.
"""
        write_once(research / "brief.md", brief)
        write_once(draft / "README.md", f"# {theme} draft\n\nApproved direction and frozen reference contracts: Docs/Research_Assets/{theme}/.\nSources and candidate exports belong here. No runtime assets installed yet.\n")
        for path, data in (
            (draft / "native-inventory.json", inventory),
            (research / "Contracts/approved-footprints.json", {"schema": 1, "approval": APPROVAL, "scope": "maximum endcap exterior only", "cases": cases}),
            (research / "checkpoint.json", {"schema": 1, "theme": theme, "status": "representative-source-pending", "approval": APPROVAL,
                "concept": record(approved), "originalConcept": record(concept), "direction": direction,
                "productionAccepted": False, "representativeLiveApproved": False,
                "foreverValidated": False, "retailValidated": False}),
        ):
            if path.name == "checkpoint.json" and path.exists():
                current = json.loads(path.read_text(encoding="utf-8"))
                assert current["theme"] == theme and current["approval"] == APPROVAL
                assert current["concept"] == record(approved), "Approved concept changed"
                continue  # Preserve production progress on preparation reruns.
            write_once(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        print(f"{theme}: concept hash locked; {len(inventory)} native textures inventoried; four Druid footprint contracts frozen")


if __name__ == "__main__":
    main()
