"""Measure an intact Unholy replacement against frozen installed terminals.

No installation or approval is performed. Retain the old cap as a rejected
fixture and render complete None/old/new bars at identical native rail origins.
"""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from ThemeHealthEndcaps import align, terminal_coverage, terminal_mask
from ThemeSourceIntegrity import verify_pixels, whole_painting

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("dk_install", ROOT / "Tools/Install-DeathKnightLivePreview.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
sha, read = installer.sha, installer.read
OUT = ROOT / "Assets_Draft/DeathKnight/Unholy-Repair-2026-11-14"


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def freeze():
    """Run before generation/fitting; an existing snapshot must remain exact."""
    OUT.mkdir(parents=True, exist_ok=True)
    records = {}
    for name in installer.LONG:
        for suffix in ("-over", ""):
            path = ROOT / "Assets/DeathKnight" / (name + suffix + ".tga")
            records[path.relative_to(ROOT).as_posix()] = sha(path)
        path = ROOT / "Assets/DeathKnight" / ("ornament-unholy-" + name + ".tga")
        records[path.relative_to(ROOT).as_posix()] = sha(path)
        mask_path = OUT / (name + "-terminal.png")
        mask = terminal_mask(read(ROOT / "Assets/DeathKnight" / (name + "-over.tga")))
        if mask_path.exists():
            assert np.array_equal(np.asarray(Image.open(mask_path)), np.asarray(mask)), "Frozen terminal changed"
        else:
            mask.save(mask_path)
        records[mask_path.relative_to(ROOT).as_posix()] = sha(mask_path)
    for relative in ("Assets_Draft/DeathKnight/Sources/health-endcap-unholy.png",
                     "Docs/Research_Assets/DeathKnight/FullSet/Contracts/approved-footprints.json"):
        records[relative] = sha(ROOT / relative)
    path = OUT / "frozen.json"
    if path.exists():
        assert json.loads(path.read_text()) == records, "Frozen repair baseline changed"
    else:
        write(path, records)
    return records


def render(caps):
    spec = importlib.util.spec_from_file_location("native", ROOT / "Tools/Build-ThemeConceptBase.py")
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    rows = [(kind, tier, fraction) for kind, tier in
            (("PlayerFrame", "Seasoned"), ("PlayerFrame", "Hardened"),
             ("PlayerFrame", "Novice"), ("TargetFrame", "Boss"))
            for fraction in (0, .5, 1)]
    board = Image.new("RGBA", (3300, len(rows) * 400 + 60), "#14161a")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)
    draw.text((20, 15), "OFFLINE / UNHOLY / complete native bars / fixed origins / None - old - candidate", font=font, fill="white")
    for row, (kind, tier, fraction) in enumerate(rows):
        db = dict(base.DATA[kind]); db.update(db.get(tier, {}))
        name = db["HealthBackdropTexture"].replace("\\", "/").rsplit("/", 1)[-1][:-4]
        owner = (250, 120, *base.DATA[kind]["Size"])
        rect = base.anchor(owner, db["HealthBackdropSize"], db["HealthBackdropPosition"])
        hp = base.anchor(owner, db["HealthBarSize"], db["HealthBarPosition"])
        flip = kind == "TargetFrame"
        for column, label in enumerate(("None", "Old", "Candidate")):
            scene = Image.new("RGBA", (1100, 400))
            base.put(scene, read(ROOT / "Assets/DeathKnight" / (name + ".tga")), rect, flip)
            base.fill(scene, db["HealthBarTexture"], hp, 1, base.DARK, flip)
            base.fill(scene, db["HealthBarTexture"], hp, fraction, base.RED, flip)
            base.put(scene, read(ROOT / "Assets/DeathKnight" / (name + "-over.tga")), rect, flip)
            if column:
                cap = caps[name] if column == 2 else read(ROOT / "Assets/DeathKnight" / ("ornament-unholy-" + name + ".tga"))
                base.put(scene, cap, rect, flip)
            box = scene.getbbox()
            assert box and box[0] > 0 and box[1] > 0 and box[2] < 1100 and box[3] < 400, "Review clipped"
            board.alpha_composite(scene, (column * 1100, row * 400 + 60))
            draw.text((column * 1100 + 20, row * 400 + 65), f"{kind} {tier} {fraction:.0%} / {label}", font=font, fill="white")
    board.convert("RGB").save(OUT / "complete-bars-1x.png")
    board.resize((board.width * 2, board.height * 2), Image.Resampling.NEAREST).convert("RGB").save(OUT / "complete-bars-2x.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    args = parser.parse_args()
    freeze()
    if not args.source:
        print("Frozen installed casings, complete terminal masks, original motif and approved maximum before fitting.")
        return
    source_path = args.source.resolve()
    source = read(source_path)
    contracts = json.loads((installer.DOC / "Contracts/approved-footprints.json").read_text())
    results, caps = {}, {}
    for name in installer.LONG:
        contract = contracts["cases"][name]
        native = read(ROOT / contract["native"])
        assert sha(ROOT / contract["native"]) == contract["nativeSha256"]
        assert sha(ROOT / contract["nativeTerminalMask"]) == contract["nativeTerminalMaskSha256"]
        cap, transform, box = installer.bounded_cap(source, native, contract["approvedFootprint"])
        verify_pixels(whole_painting(source, transform, native.size), cap)
        cap.save(OUT / ("ornament-unholy-" + name + ".tga"), compression=None)
        verify_pixels(cap, read(OUT / ("ornament-unholy-" + name + ".tga")))
        errors = []
        try:
            _, measurement = align(source, native, transform["scale"] *
                (source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()[3] -
                 source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()[1]),
                Image.open(ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")), source_transform=transform)
        except (AssertionError, ValueError) as error:
            errors.append(str(error))
            measurement = None
        installed = read(ROOT / "Assets/DeathKnight" / (name + "-over.tga"))
        fill = np.asarray(Image.open(ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")).convert("L")) > 128
        combined = ((np.asarray(installed)[:, :, 3] > 200) | (np.asarray(cap)[:, :, 3] > 200)) & fill
        occlusion = float(combined.sum() / max(1, fill.sum()))
        if occlusion > .20:
            errors.append("Combined casing/cap fill occlusion exceeds 20 percent")
        coverage = terminal_coverage(installed, cap)
        if coverage["exposedTerminalPixelsBeyondAA"]:
            errors.append("Installed complete terminal exposed")
        old = read(ROOT / "Assets/DeathKnight" / ("ornament-unholy-" + name + ".tga"))
        results[name] = {"transform": transform, "bounds": list(box), "sharedAlignment": measurement,
            "installedTerminal": coverage, "oldInstalledTerminal": terminal_coverage(installed, old),
            "combinedFillOcclusion": occlusion, "errors": errors, "passed": not errors}
        caps[name] = cap
    render(caps)
    report = {"source": source_path.as_posix(), "sourceSha256": sha(source_path),
        "frozenSha256": sha(OUT / "frozen.json"), "cases": results,
        "passed": all(item["passed"] for item in results.values()),
        "installed": False, "maintainerVisualApproved": False, "liveValidated": False}
    write(OUT / "fit-report.json", report)
    for name, item in results.items():
        print(name, "PASS" if item["passed"] else "FAIL", item["installedTerminal"], item["errors"])
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
