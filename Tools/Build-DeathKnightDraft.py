"""Package the unapproved Death Knight source studies; never install textures.

Run from any directory: python Tools/Build-DeathKnightDraft.py
Pillow is required. Sources and internal documentation are local-only.
"""
from pathlib import Path
import hashlib
import html
import json
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets_Draft/DeathKnight"
DOC = ROOT / "Docs/Research_Assets/DeathKnight"
ITEMS = [
    ("health-endcap-frost", "Frost / paired blade guard", 48),
    ("health-endcap-unholy", "Unholy / chipped blade guard", 48),
    ("cast-head-blood", "Blood / axe-jaw cast head", 48),
    ("resource-badge", "Ebon Blade / resource badge", 32),
    ("minimap-north", "Runesteel / north marker", 20),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def record(path):
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)}


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", size)


def main():
    review = OUT / "Review"
    review.mkdir(parents=True, exist_ok=True)
    provenance_path = DOC / "prompts.json"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
    jobs = {job["name"]: job for job in provenance["jobs"]}
    reference = ROOT / provenance["reference"]
    assert sha(reference) == sha(OUT / "concept-reference.png"), "Changed concept copy"
    board = Image.new("RGB", (1536, 1500), "#14161a")
    board.paste(Image.open(reference).convert("RGB"), (0, 0))
    draw = ImageDraw.Draw(board)
    draw.rectangle((0, 1000, 1536, 1066), fill="#14161a")
    draw.text((28, 1008), "EBON OATH / NEW WHOLE-PAINTING SOURCE STUDIES", font=font(24), fill="#d6d1c4")
    draw.text((28, 1040), "Above: prior concept reference. Below: unfitted art; no gameplay or export acceptance.", font=font(17), fill="#adb6c0")
    sources = []
    cards = []
    for index, (name, label, small_size) in enumerate(ITEMS):
        path = OUT / "Sources" / (name + ".png")
        original = Path(jobs[name]["original"])
        assert sha(original) == sha(path), "Source copy differs: " + name
        image = Image.open(path)
        assert image.mode == "RGBA", "Missing real alpha: " + name
        alpha = image.getchannel("A")
        bounds = alpha.getbbox()
        assert bounds and alpha.getextrema() == (0, 255), "Invalid transparency: " + name
        solid = alpha.point(lambda value: 255 if value > 200 else 0).getbbox()
        assert solid and solid[0] > 0 and solid[1] > 0 and solid[2] < image.width and solid[3] < image.height, "Clipped solid source: " + name
        edges = [alpha.crop(box).getextrema()[1] for box in [(0, 0, image.width, 1), (0, image.height - 1, image.width, image.height), (0, 0, 1, image.height), (image.width - 1, 0, image.width, image.height)]]
        assert max(edges) <= 1, "Paint reaches canvas edge: " + name
        # Review framing only: retain a 16px margin around solid paint. No export
        # or registration is produced; whole unmodified sources remain linked.
        frame = (max(0, solid[0] - 16), max(0, solid[1] - 16), min(image.width, solid[2] + 16), min(image.height, solid[3] + 16))
        art = image.crop(frame)
        large = art.copy()
        large.thumbnail((270, 240), Image.Resampling.LANCZOS)
        x = 22 + index * 304
        draw.rectangle((x, 1080, x + 288, 1480), fill="#1d232c", outline="#394553")
        board.paste(large, (x + (288 - large.width) // 2, 1098 + (240 - large.height) // 2), large)
        draw.text((x + 10, 1350), label, font=font(16), fill="#d6d1c4")
        small = art.copy()
        small.thumbnail((small_size, small_size), Image.Resampling.LANCZOS)
        board.paste(small, (x + 12, 1388), small)
        double = small.resize((small.width * 2, small.height * 2), Image.Resampling.NEAREST)
        board.paste(double, (x + 84, 1380), double)
        draw.text((x + 10, 1452), f"{small_size}px box / 2x inspection", font=font(15), fill="#a5b2bf")
        preview = review / (name + "-small.png")
        small.save(preview)
        sources.append({**record(path), "name": name, "canvas": list(image.size), "alphaBounds": list(bounds), "solidAlphaBounds": list(solid), "maxCanvasEdgeAlpha": max(edges), "reviewOnlyCrop": list(frame), "originalSha256": sha(original), "reviewBoxPx": small_size})
        cards.append(f'<article><h2>{html.escape(label)}</h2><a href="Sources/{name}.png"><img src="Sources/{name}.png" alt="{html.escape(label)}"></a><p>Small source study ({small_size}px box): <img class="small" src="Review/{name}-small.png" alt="Small preview"></p></article>')
    board.save(review / "death-knight-set-review.png")

    geometry = json.loads((ROOT / "Docs/Theme Asset Geometry.json").read_text(encoding="utf-8"))
    inventory = []
    for path in sorted((ROOT / "Assets").glob("*.tga")):
        name = path.stem
        if name == "nameplate_backdrop":
            disposition = "shared-native: backing only, no ornamental border"
        elif name in geometry:
            disposition = "TODO native-template painting after concept and footprint approval"
        else:
            disposition = "shared-native: functional, semantic or non-theme art; no replacement proposed"
        inventory.append({**record(path), "disposition": disposition, "geometry": geometry.get(name)})
    missing = sorted(set(geometry) - {p.stem for p in (ROOT / "Assets").glob("*.tga")})
    assert not missing, "Missing geometry sources: " + str(missing)
    write_json(OUT / "native-inventory.json", inventory)
    (OUT / "brief.md").write_bytes((DOC / "brief.md").read_bytes())
    (OUT / "prompts.json").write_bytes(provenance_path.read_bytes())
    write_json(OUT / "draft-manifest.json", {
        "schema": 1, "theme": "Death Knight / Ebon Oath", "stage": "unapproved-source-studies",
        "tool": provenance["tool"], "reference": record(reference), "sources": sources,
        "brief": record(DOC / "brief.md"), "prompts": record(provenance_path),
        "nativeInventory": record(OUT / "native-inventory.json"), "review": record(review / "death-knight-set-review.png"),
        "nativeTextureCount": len(inventory), "geometryEntryCount": len(geometry),
        "acceptance": {"conceptApproved": False, "footprintApproved": False, "sourceToExportPassed": False,
                       "numericalFitPassed": False, "maintainerVisualApproved": False, "representativeLiveApproved": False},
        "runtimeIntegrated": False, "retailTested": False, "foreverTested": False,
        "protectedContext": [record(ROOT / p) for p in ["Core/ThemeEngine.lua", "Options/OptionsPages/Themes.lua", "Core/API/Assets.lua", "Docs/Theme Asset Geometry.json"]],
    })
    (OUT / "README.md").write_text(
        "# Death Knight / Ebon Oath — source-study draft\n\n"
        "Open index.html or Review/death-knight-set-review.png. Five original transparent paintings, "
        "a prior concept reference, small previews, exact prompts, source hashes and native inventory.\n\n"
        "These are not production TGAs or a selectable theme. The earlier concept board is shown "
        "as a reference; its assemblies do not use the new paintings. Review sizes are study boxes, "
        "not measured runtime footprints. No source was stencilled, alpha-erased or distorted.\n\n"
        "TODO: approve concept AND maximum cap footprint before fitting; follow brief.md. "
        "Source-to-export, terminal coverage, fixed-view assembly review and live approval are pending. "
        "No /reload test applies to these unwired PNGs; Retail and Forever remain untested.\n\n"
        "Rebuild: python Tools/Build-DeathKnightDraft.py from the checkout. Pillow required. "
        "Sources/docs are gitignored and local-only. The ZIP preserves their full content.\n",
        encoding="utf-8")
    (OUT / "index.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">'
        '<title>Death Knight — Ebon Oath draft</title><style>body{background:#14161a;color:#d6d1c4;font:17px/1.5 system-ui;max-width:1500px;margin:32px auto;padding:20px}a{color:#9bd4ed}img{max-width:100%}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}article{background:#202731;padding:16px}h2{font-size:18px}article img{width:100%}article img.small{width:auto;vertical-align:middle}aside{padding:16px;border-left:3px solid #9bd4ed}</style>'
        '<h1>Death Knight / Ebon Oath</h1><aside>Source studies for concept review. Not installed. Concept, cap footprint, source-to-export, fit and Retail/Forever validation remain pending.</aside>'
        '<p><a href="brief.md">Brief and approval gates</a> · <a href="prompts.json">Exact built-in imagegen prompts</a> · <a href="draft-manifest.json">Hashes and status</a> · <a href="native-inventory.json">Native inventory</a></p>'
        '<h2>Prior concept reference</h2><img src="concept-reference.png" alt="Earlier Death Knight proposal; not a runtime screenshot">'
        '<h2>New intact source paintings</h2><div class="grid">' + ''.join(cards) + '</div></html>', encoding="utf-8")
    archive = DOC / "DeathKnight-EbonOath-source-studies.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(OUT.rglob("*")):
            if path.is_file():
                z.write(path, path.relative_to(ROOT).as_posix())
        for path in [Path(__file__), DOC / "brief.md", DOC / "prompts.json", ROOT / "Docs/Theme Asset Geometry.json"]:
            z.write(path, path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None, "Archive CRC failure"
        for path in OUT.rglob("*"):
            if path.is_file():
                assert hashlib.sha256(z.read(path.relative_to(ROOT).as_posix())).hexdigest() == sha(path), "Archive mismatch"
    print(f"5 intact RGBA sources; {len(inventory)} native textures; {len(geometry)} geometry entries; ZIP CRC and hashes passed.")
    print(review / "death-knight-set-review.png")
    print(archive)


if __name__ == "__main__":
    main()
