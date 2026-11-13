"""Export/review the complete DK paintings without warping/stencilling sources.

Candidate exports stay under Assets_Draft. All failing fit checks are retained;
this tool never installs assets or writes visual/live approval.
"""
from pathlib import Path
import hashlib
import html
import importlib.util
import json
import math
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import aperture, whole_painting, verify_pixels, verify_pack

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "Docs/Research_Assets/DeathKnight/FullSet"
OUT = ROOT / "Assets_Draft/DeathKnight/FullSet"
EXPORT = OUT / "Exports"
REVIEW = OUT / "Review"
S = Image.Resampling.LANCZOS
SPEC = json.loads((ROOT / "Docs/Theme Asset Geometry.json").read_text())
STYLE_SPEC = importlib.util.spec_from_file_location("style", ROOT / "Tools/Check-ThemeAssetStyle.py")
STYLE = importlib.util.module_from_spec(STYLE_SPEC)
STYLE_SPEC.loader.exec_module(STYLE)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rec(path):
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)}


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", size)


def bounds(image, threshold=128):
    box = image.getchannel("A").point(lambda v: 255 if v > threshold else 0).getbbox()
    if box is None:
        raise ValueError("empty painting")
    return box


def register(source, name, spec):
    """Fit only a whole uniform painting; actual fit errors are reported later."""
    outer = bounds(source)
    crop = bounds(source, 8)  # shared source gate's transparent-margin rule
    target = spec.get("painted", [16, 16, spec["canvas"][0] - 16, spec["canvas"][1] - 16])
    scale = min((target[2] - target[0]) / (outer[2] - outer[0]), (target[3] - target[1]) / (outer[3] - outer[1]))
    canvas = spec["canvas"]
    # Keep the entire >8 alpha source crop inside the canvas, without clipping.
    scale = min(scale, canvas[0] / (crop[2] - crop[0]), canvas[1] / (crop[3] - crop[1]))
    size = [round((crop[i + 2] - crop[i]) * scale) for i in range(2)]
    x = round((target[0] + target[2]) / 2 - ((outer[0] + outer[2]) / 2 - crop[0]) * scale)
    y = round((target[1] + target[3]) / 2 - ((outer[1] + outer[3]) / 2 - crop[1]) * scale)
    if name in ("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case"):
        paint = source.crop(crop).resize(tuple(size), S)
        tx, ty = lowest_point(Image.open(ROOT / "Assets" / (name + ".tga")))
        px, py = lowest_point(paint)
        x, y = round(tx - px), round(ty - py)
    # If toe placement leaves the canvas, keep a centred whole candidate and
    # report its failed toe; never remove paint to get a passing position.
    x = max(0, min(x, canvas[0] - size[0]))
    y = max(0, min(y, canvas[1] - size[1]))
    transform = {"crop": list(crop), "scale": scale, "offset": [x, y]}
    return whole_painting(source, transform, canvas), transform


def save_tga(name, image, source_record, manifest):
    path = EXPORT / (name + ".tga")
    image.save(path, compression=None)
    reopened = Image.open(path).convert("RGBA")
    verify_pixels(image, reopened)
    manifest[name] = {**rec(path), "canvas": list(image.size), **source_record}
    return reopened


def render_atlas(records, images):
    columns, cw, ch = 4, 440, 240
    board = Image.new("RGB", (columns * cw, 90 + math.ceil(len(records) / columns) * ch), "#14161a")
    draw = ImageDraw.Draw(board)
    draw.text((20, 16), "DEATH KNIGHT / EBON OATH — COMPLETE CANDIDATE EXPORTS", font=font(24), fill="#d6d1c4")
    draw.text((20, 52), "Actual reopened TGAs. Whole sources only. Fit failures remain visible; not production approval.", font=font(17), fill="#9eb1c4")
    for index, item in enumerate(records):
        name = item["name"]
        x, y = (index % columns) * cw, 90 + (index // columns) * ch
        draw.rectangle((x + 8, y + 6, x + cw - 8, y + ch - 8), fill="#202731", outline="#394553")
        draw.text((x + 18, y + 14), name, font=font(17), fill="#d6d1c4")
        image = images[name].copy()
        image.thumbnail((cw - 40, ch - 85), S)
        board.paste(image, (x + (cw - image.width) // 2, y + 44 + (ch - 85 - image.height) // 2), image)
        flag = "FIT ERRORS: " + str(len(item["failures"])) if item["failures"] else "Local checks passed; review/live pending"
        draw.text((x + 18, y + ch - 36), flag, font=font(15), fill="#e7b18c" if item["failures"] else "#a7c9b1")
    board.save(REVIEW / "all-exports.png")


def render_health(images):
    """Complete four-tier candidate bars at fixed rail origins, no crop tricks."""
    names = ["hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case"]
    if not all(name in images for name in names):
        return
    sheet = Image.new("RGBA", (1600, 1200), "#14161a")
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "OFFLINE CANDIDATES / COMPLETE BARS / NATIVE RECTANGLES", font=font(24), fill="#d6d1c4")
    for row, name in enumerate(names):
        art = images[name]
        for column, fraction in enumerate((0, .5, 1)):
            canvas = Image.new("RGBA", (1024, 256))
            texture = "hp_boss_bar" if name == "hp_boss_case" else "hp_cap_bar" if name == "hp_cap_case" else "hp_lowmid_bar"
            fill = Image.open(ROOT / "Assets" / (texture + ".tga")).convert("RGBA")
            field_box = SPEC[name]["meter"]
            # The native meter texture maps to its measured fill rectangle.
            fill = fill.resize((field_box[2] - field_box[0], field_box[3] - field_box[1]), S)
            rgba = np.array(fill)
            rgba[..., :3] = np.rint(rgba[..., :3].astype(float) * np.array([.85, .08, .13])).astype("uint8")
            fill = Image.fromarray(rgba)
            if fraction:
                canvas.alpha_composite(fill.crop((0, 0, round(fill.width * fraction), fill.height)), (field_box[0], field_box[1]))
            canvas.alpha_composite(art)
            # Both player and mirrored target retain the same whole 1024x256 viewport.
            x, y = column * 530 + 18, row * 280 + 70
            draw.text((x, y), name + f" / {fraction:.0%}", font=font(16), fill="#d6d1c4")
            sheet.alpha_composite(canvas.resize((512, 128), S), (x, y + 24))
            sheet.alpha_composite(canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((512, 128), S), (x, y + 140))
    sheet.convert("RGB").save(REVIEW / "health-states.png")
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).convert("RGB").save(REVIEW / "health-states-2x.png")


def main():
    EXPORT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    plan = json.loads((DOC / "jobs.json").read_text(encoding="utf-8"))
    records, assets, images = [], {}, {}
    pending = [job["name"] for job in plan["jobs"] if job["status"] != "done"]
    for job in plan["jobs"]:
        if job["status"] != "done":
            continue
        name = job["name"]
        path = ROOT / job["source"]
        assert sha(path) == job["sourceSha256"], "Stale source: " + name
        source = Image.open(path).convert("RGBA")
        spec = job["geometry"]
        image, transform = register(source, name, spec)
        image = save_tga(name, image, {"role": "whole-painting", "source": rec(path), "transform": transform}, assets)
        images[name] = image
        failures, notes = STYLE.check(EXPORT / (name + ".tga"))
        mask_path = ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")
        if mask_path.exists() and name != "nameplate_backdrop":
            try:
                aperture(image, Image.open(mask_path))
            except ValueError as error:
                failures.append(str(error))
        if name.startswith("hp_") and "critter" not in name:
            native = Image.open(ROOT / "Assets" / (name + ".tga"))
            expected, found = lowest_point(native), lowest_point(image)
            if abs(expected[0] - found[0]) > .5 or expected[1] != found[1]:
                failures.append(f"Native toe mismatch: {expected} -> {found}")
        item = {"name": name, "failures": failures, "notes": notes, "asset": assets[name]}
        records.append(item)
    # Every root native texture has an explicit disposition; functional art is
    # referenced by exact path/hash, not renamed and counted as new DK artwork.
    proposed = {job["name"] for job in plan["jobs"]}
    inventory = [{**rec(path), "disposition": "new-dk-source" if path.stem in proposed else "shared-native-functional-or-semantic", "candidate": path.stem + ".tga" if path.stem in images else None} for path in sorted((ROOT / "Assets").glob("*.tga"))]
    write(OUT / "coverage.json", {"jobs": len(plan["jobs"]), "paintingsCompleted": len(records), "pending": pending, "native": inventory})
    write(OUT / "manifest.json", {"schema": 1, "status": "candidate-exports-not-installed", "assets": assets, "runtimeIntegrated": False, "retailTested": False, "foreverTested": False})
    write(EXPORT / "manifest.json", {"schema": 1, "status": "candidate-exports-not-installed", "assets": assets})
    write(EXPORT / "source-integrity.json", {"schema": 1, "assetManifestSha256": sha(EXPORT / "manifest.json"),
        "paintings": {name: {"role": "painting", "source": item["source"], "transform": item["transform"]} for name, item in assets.items()}})
    try:
        gate = {"passed": True, "result": verify_pack(EXPORT)}
    except (ValueError, KeyError, OSError) as error:
        gate = {"passed": False, "firstFailure": str(error)}
    write(OUT / "source-gate-result.json", gate)
    write(OUT / "fit-report.json", {"stage": "candidate", "assetManifestSha256": sha(OUT / "manifest.json"), "pending": pending, "cases": records, "failingCases": sum(bool(r["failures"]) for r in records), "acceptance": False})
    shutil.copy2(DOC / "jobs.json", OUT / "jobs.json")
    render_atlas(records, images)
    render_health(images)
    cards = []
    for item in records:
        name = item["name"]
        # Browser previews use exactly the reopened exports, not a generated UI mockup.
        images[name].save(REVIEW / (name + ".png"))
        failures = "".join("<li>" + html.escape(message) + "</li>" for message in item["failures"])
        source_link = (ROOT / item["asset"]["source"]["path"]).relative_to(OUT).as_posix()
        cards.append(f'<article><h2>{html.escape(name)}</h2><img src="Review/{name}.png" alt="{html.escape(name)}"><p><a href="{source_link}">Whole source</a> · <a href="Exports/{name}.tga">TGA candidate</a></p><ul>{failures}</ul></article>')
    (OUT / "index.html").write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Death Knight full asset pack</title><style>body{background:#14161a;color:#d6d1c4;font:16px/1.5 system-ui;margin:30px auto;padding:20px;max-width:1760px}a{color:#9bd4ed}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}article{background:#202731;padding:14px}h2{font-size:18px}img{max-width:100%}li{color:#e7b18c;font-size:14px}aside{border-left:3px solid #e7b18c;padding:14px}</style><h1>Death Knight / Ebon Oath — full asset inventory</h1>' + f'<aside>{len(records)}/{len(plan["jobs"])} whole paintings completed. {sum(bool(r["failures"]) for r in records)} candidates fail local fit checks. Not installed or live tested.</aside><p><a href="coverage.json">Coverage</a> · <a href="fit-report.json">Fit report</a> · <a href="jobs.json">Exact prompts and provenance</a> · <a href="../index.html">Ornaments and prior concept</a></p><img src="Review/all-exports.png" alt="All actual candidate exports"><div class="grid">' + "".join(cards) + '</div></html>', encoding="utf-8")
    print(f"{len(records)}/{len(plan['jobs'])} sources exported; {sum(bool(r['failures']) for r in records)} fail fit; source/TGA roundtrips passed. No installation.")
    print(OUT / "index.html")


if __name__ == "__main__":
    main()
