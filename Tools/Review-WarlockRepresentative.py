"""Inspect a whole-source Warlock endcap inside the locked Druid footprint.

Also accepts `v1 Priest` for the second representative using the same contract.
No installation, source erasure or implicit approval. Source transforms replay
with the shared integrity gate; complete None/on viewports stay identical.
"""
from pathlib import Path
import hashlib
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from ThemeHealthEndcaps import lowest_point, terminal_coverage, terminal_mask, align
from ThemeSourceIntegrity import whole_painting, verify_pixels, verify_pack

ROOT = Path(__file__).resolve().parent.parent


def rec(path):
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    revision = sys.argv[1] if len(sys.argv) > 1 else "v1"
    theme = sys.argv[2] if len(sys.argv) > 2 else "Warlock"
    if theme not in ("Warlock", "Priest"):
        raise ValueError("Expected Warlock or Priest")
    folder = ROOT / "Assets_Draft" / theme
    motif = "ulthalesh" if theme == "Warlock" else "tuure"
    casing_revision = "v4" if theme == "Warlock" else "v7"
    ornament_name = "ornament-" + motif + "-hp_cap_case"
    if revision not in ("v1", "v2", "v3", "v4", "v5"):
        raise ValueError("Expected a retained source revision v1..v5")
    suffix = "" if revision == "v1" else "-" + revision
    bare_path = folder / "Candidates" / casing_revision / "hp_cap_case.tga"
    bare = Image.open(bare_path).convert("RGBA")
    source_path = folder / ("Sources/health-endcap-" + motif + "-" + revision + ".png")
    source = Image.open(source_path).convert("RGBA")
    crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    opaque_box = source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    contract_path = ROOT / "Docs/Research_Assets" / theme / "Contracts/approved-footprints.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))["cases"]["hp_cap_case"]
    bound = contract["approvedFootprint"]
    fill = Image.open(ROOT / "Docs/Research_Assets/Templates/hp_cap_case-fill.png").convert("L")
    toe = lowest_point(bare)
    records = []
    candidates = []
    for height in range(40, int(bound[3] - bound[1]) + 1):
        scale = height / (opaque_box[3] - opaque_box[1])
        paint = source.crop(crop).resize((round((crop[2] - crop[0]) * scale), round((crop[3] - crop[1]) * scale)), Image.Resampling.LANCZOS)
        px, py = lowest_point(paint)
        offset = [round(toe[0] - px), round(toe[1] - py)]
        if min(offset) < 0 or offset[0] + paint.width > 1024 or offset[1] + paint.height > 256:
            continue
        transform = {"crop": list(crop), "scale": scale, "offset": offset}
        cap = whole_painting(source, transform, bare.size)
        box = cap.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
        if any((box[0] < bound[0], box[1] < bound[1], box[2] > bound[2], box[3] > bound[3])):
            continue
        coverage = terminal_coverage(bare, cap)
        covered = float(((np.asarray(cap)[:, :, 3] > 200) & (np.asarray(fill) > 128)).sum() / (np.asarray(fill) > 128).sum())
        try:
            align(source, bare, height, fill)
            shared_passed, shared_error = True, None
        except (ValueError, AssertionError) as error:
            shared_passed, shared_error = False, str(error)
        record = {"height": height, "transform": transform, "bounds": list(box), "fillCovered": covered,
                  "insideApprovedFootprint": True, "sharedAlignGatePassed": shared_passed,
                  "sharedAlignFailure": shared_error, **coverage}
        record["numericPassed"] = shared_passed and coverage["exposedTerminalPixelsBeyondAA"] == 0 and covered <= .20
        records.append(record)
        candidates.append(cap)
    if not records:
        raise ValueError("No candidate fits approved footprint")
    best_index = min(range(len(records)), key=lambda i: (not records[i]["numericPassed"], records[i]["exposedTerminalPixelsBeyondAA"]))
    best, cap = records[best_index], candidates[best_index]
    export = folder / ("Candidates/representative" + suffix)
    export.mkdir(parents=True, exist_ok=True)
    cap_path = export / (ornament_name + ".tga")
    cap.save(cap_path, compression=None)
    verify_pixels(cap, Image.open(cap_path).convert("RGBA"))
    # Retain the native functional recess as its own exact layer; never use
    # its alpha to stencil the new front painting.
    native_path = ROOT / "Assets/hp_cap_case.tga"
    native = np.array(Image.open(native_path).convert("RGBA"))
    field = np.asarray(fill) > 128
    recess_pixels = np.zeros_like(native)
    recess_pixels[field] = native[field]
    recess = Image.fromarray(recess_pixels)
    back_path = export / "hp_cap_case.tga"
    front_path = export / "hp_cap_case-over.tga"
    recess.save(back_path, compression=None)
    bare.save(front_path, compression=None)
    verify_pixels(recess, Image.open(back_path).convert("RGBA"))
    verify_pixels(bare, Image.open(front_path).convert("RGBA"))
    front_proof = json.loads((folder / "Candidates" / casing_revision / "source-integrity.json").read_text(encoding="utf-8"))["paintings"]["hp_cap_case"]
    manifest_path = export / "manifest.json"
    status = "representative-numeric-pass-review-pending" if best["numericPassed"] else "representative-failed-cap-fit-not-installed"
    manifest_path.write_text(json.dumps({"schema": 1, "status": status,
        "assets": {"hp_cap_case": rec(back_path), "hp_cap_case-over": rec(front_path),
                   ornament_name: rec(cap_path)}}, indent=2) + "\n", encoding="utf-8")
    (export / "source-integrity.json").write_text(json.dumps({"schema": 1,
        "assetManifestSha256": rec(manifest_path)["sha256"], "paintings": {
            "hp_cap_case": {"role": "functional-recess", "source": rec(native_path)},
            "hp_cap_case-over": front_proof,
            ornament_name: {"role": "painting", "source": rec(source_path), "transform": best["transform"]}
        }}, indent=2) + "\n", encoding="utf-8")
    source_result = verify_pack(export)
    review = folder / "Review"
    report = {"source": rec(source_path), "bare": rec(bare_path), "footprintContract": rec(contract_path),
              "capExport": rec(cap_path), "best": best, "passingCandidates": sum(r["numericPassed"] for r in records),
              "trials": records, "sourceIntegrity": source_result, "numericPassed": best["numericPassed"],
              "productionAccepted": False, "maintainerVisualApproved": False,
              "runtimeIntegrated": False, "liveApproved": False}
    board = Image.new("RGBA", (1560, 600), "#14161a")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)
    draw.text((20, 14), f"{theme.upper()} / REPRESENTATIVE CASING + {motif.upper()} BOOT / OFFLINE CANDIDATE", font=font, fill="#e5dccb")
    draw.text((20, 44), f"Casing source gate PASS; cap exposed terminal pixels {best['exposedTerminalPixelsBeyondAA']}; within Druid limit. Not installed.", font=font, fill="#e4b18f")
    fill_texture = Image.open(ROOT / "Assets/hp_cap_bar.tga").convert("RGBA").resize((551, 55), Image.Resampling.LANCZOS)
    pixels = np.array(fill_texture)
    pixels[..., :3] = np.rint(pixels[..., :3].astype(float) * [.85, .08, .13]).astype("uint8")
    fill_texture = Image.fromarray(pixels)
    # One source-pixel union viewport for every None/on and mirrored comparison.
    viewport = (180, 25, 855, 215)
    for column, fraction in enumerate((0, .5, 1)):
        for row, (enabled, flip) in enumerate(((False, False), (True, False), (True, True))):
            scene = Image.new("RGBA", bare.size)
            scene.alpha_composite(recess)
            if fraction:
                scene.alpha_composite(fill_texture.crop((0, 0, round(551 * fraction), 55)), (236, 99))
            scene.alpha_composite(bare)
            if enabled:
                scene.alpha_composite(cap)
            scene = scene.crop(viewport)
            if flip:
                scene = scene.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            # 716x188 native Seasoned backdrop: retain its measured draw ratio.
            scene = scene.resize((round(scene.width * 716 / 1024), round(scene.height * 188 / 256)), Image.Resampling.LANCZOS)
            x, y = 20 + column * 510, 100 + row * 160
            draw.text((x, y), f"Health {fraction:.0%} / " + ("None" if not enabled else "On / target" if flip else "On / player"), font=font, fill="#d6d1c4")
            board.alpha_composite(scene, (x, y + 28))
    image_path = review / ("representative-none-on" + suffix + "-1x.png")
    board.convert("RGB").save(image_path)
    double_path = review / ("representative-none-on" + suffix + "-2x.png")
    board.resize((3120, 1200), Image.Resampling.NEAREST).convert("RGB").save(double_path)
    report["review"] = [rec(image_path), rec(double_path)]
    # Exact source-coordinate missing-body reference for a local repaint.
    # This is a separate diagnostic copy, never a source/export alpha operation.
    transform = best["transform"]
    field = Image.new("L", source.size)
    mask = terminal_mask(bare)
    field.paste(mask.resize((round(1024 / transform["scale"]), round(256 / transform["scale"])), Image.Resampling.NEAREST),
                (round(transform["crop"][0] - transform["offset"][0] / transform["scale"]),
                 round(transform["crop"][1] - transform["offset"][1] / transform["scale"])))
    missing = (np.asarray(field) > 128) & (np.asarray(source)[:, :, 3] < 240)
    guide = Image.new("RGBA", source.size, "#252830")
    guide.alpha_composite(source)
    pixels = np.array(guide)
    pixels[missing] = [0, 220, 255, 255]
    guide = Image.fromarray(pixels)
    ImageDraw.Draw(guide).text((20, 20), "CYAN: required solid mounting paint missing at measured placement. Diagnostic only.",
                              font=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20), fill="#eeeeee")
    guide_path = review / ("cap-required-repaint-" + revision + ".png")
    guide.convert("RGB").save(guide_path)
    report["sourceRepairGuide"] = rec(guide_path)
    (folder / ("endcap-fit-report" + suffix + ".json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{theme} endcap: {report['passingCandidates']} passing trials, best exposed terminal={best['exposedTerminalPixelsBeyondAA']}, fill={best['fillCovered']:.2%}")


if __name__ == "__main__":
    main()
