"""Reopen intact draft casings, measure fit, and render complete failure evidence.

Uses the existing whole-source registration and source-integrity implementation.
Does not install candidates or approve missing fitting/live evidence.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from ThemeHealthEndcaps import lowest_point, terminal_mask
from ThemeSourceIntegrity import aperture, verify_pixels, verify_pack, whole_painting

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("draft_registration", ROOT / "Tools/Build-DeathKnightFullSet.py")
registration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(registration)
FONT = "C:/Windows/Fonts/segoeui.ttf"


def rec(path):
    return {"path": path.relative_to(ROOT).as_posix(),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def render(theme, revision, image, mask, failures, target):
    # 1024x256 source canvas maps to the fixed original 512x128 backdrop.
    # Complete player and mirrored target use identical viewport/rail origins.
    board = Image.new("RGBA", (1660, 540), "#14161a")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype(FONT, 18)
    draw.text((20, 14), f"{theme} / {revision} / BARE CASING CANDIDATE - NOT APPROVED", font=font, fill="#e5dccb")
    draw.text((20, 44), "Intact source. Native fill and draw rectangle. Red marker = source paint intrudes into functional fill.", font=font, fill="#b3bdca")
    meter = registration.SPEC["hp_cap_case"]["meter"]
    fill_source = Image.open(ROOT / "Assets/hp_cap_bar.tga").convert("RGBA")
    fill_source = fill_source.resize((meter[2] - meter[0], meter[3] - meter[1]), Image.Resampling.LANCZOS)
    tint = np.array(fill_source)
    tint[..., :3] = np.rint(tint[..., :3].astype(float) * [.85, .08, .13]).astype("uint8")
    fill_source = Image.fromarray(tint)
    solid = np.asarray(image)[:, :, 3] > 200
    fill_mask = np.asarray(mask.convert("L")) > 128
    intrusion = solid & fill_mask
    for col, fraction in enumerate((0, .5, 1)):
        canvas = Image.new("RGBA", image.size)
        if fraction:
            filled = fill_source.crop((0, 0, round(fill_source.width * fraction), fill_source.height))
            canvas.alpha_composite(filled, (meter[0], meter[1]))
        canvas.alpha_composite(image)
        x = 20 + col * 545
        draw.text((x, 82), f"Health {fraction:.0%} / player", font=font, fill="#e5dccb")
        board.alpha_composite(canvas.resize((512, 128), Image.Resampling.LANCZOS), (x, 110))
        draw.text((x, 249), "Mirrored target / same viewport", font=font, fill="#b3bdca")
        board.alpha_composite(canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((512, 128), Image.Resampling.LANCZOS), (x, 274))
        marked = np.array(canvas)
        marked[intrusion] = [255, 70, 40, 255]
        board.alpha_composite(Image.fromarray(marked).resize((512, 128), Image.Resampling.LANCZOS), (x, 398))
    board.convert("RGB").save(target)
    board.resize((3320, 1080), Image.Resampling.NEAREST).convert("RGB").save(target.with_stem(target.stem + "-2x"))


def main():
    for theme in ("Priest", "Warlock"):
        folder = ROOT / "Assets_Draft" / theme
        review = folder / "Review"
        review.mkdir(exist_ok=True)
        mask = Image.open(ROOT / "Docs/Research_Assets/Templates/hp_cap_case-fill.png")
        registrations_path = folder / "registrations.json"
        registrations = json.loads(registrations_path.read_text(encoding="utf-8")) if registrations_path.exists() else {}
        records = []
        for source_path in sorted((folder / "Sources").glob("hp_cap_case-v*.png")):
            revision = source_path.stem.rsplit("-", 1)[-1]
            export = folder / "Candidates" / revision
            export.mkdir(parents=True, exist_ok=True)
            source = Image.open(source_path).convert("RGBA")
            explicit = registrations.get(revision)
            if explicit:
                assert rec(source_path)["sha256"] == explicit["sourceSha256"], "Stale explicit source registration"
                transform = explicit["transform"]
                image = whole_painting(source, transform, registration.SPEC["hp_cap_case"]["canvas"])
            else:
                image, transform = registration.register(source, "hp_cap_case", registration.SPEC["hp_cap_case"])
            path = export / "hp_cap_case.tga"
            image.save(path, compression=None)
            reopened = Image.open(path).convert("RGBA")
            verify_pixels(image, reopened)
            failures, notes = registration.STYLE.check(path)
            try:
                aperture(reopened, mask)
                aperture_passed = True
            except ValueError as error:
                aperture_passed = False
                failures.append(str(error))
            native_toe = lowest_point(Image.open(ROOT / "Assets/hp_cap_case.tga"))
            candidate_toe = lowest_point(reopened)
            if abs(native_toe[0] - candidate_toe[0]) > .5 or native_toe[1] != candidate_toe[1]:
                failures.append(f"Native toe mismatch: {native_toe} -> {candidate_toe}")
            # Freeze the COMPLETE candidate termination, separately for each revision.
            terminal = review / ("terminal-" + revision + ".png")
            terminal_image = terminal_mask(reopened)
            if terminal.exists():
                with Image.open(terminal) as prior:
                    assert prior.tobytes() == terminal_image.tobytes(), "Frozen candidate terminal changed"
            else:
                terminal_image.save(terminal)
            manifest = {"schema": 1, "status": "candidate-not-installed", "assets": {
                "hp_cap_case": {**rec(path), "source": rec(source_path), "transform": transform}}}
            write(export / "manifest.json", manifest)
            write(export / "source-integrity.json", {"schema": 1,
                "assetManifestSha256": rec(export / "manifest.json")["sha256"], "paintings": {
                    "hp_cap_case": {"role": "painting", "source": rec(source_path), "transform": transform}}})
            try:
                source_gate = {"passed": True, "result": verify_pack(export)}
            except (ValueError, KeyError, OSError) as error:
                source_gate = {"passed": False, "failure": str(error)}
            image_path = review / ("complete-bars-" + revision + "-1x.png")
            render(theme, revision, reopened, mask, failures, image_path)
            # A diagnostic overlay on a COPY of the source is the next edit
            # reference; it is never applied to source/export alpha.
            guide = Image.new("RGBA", source.size, "#252830")
            guide.alpha_composite(source)
            guide_draw = ImageDraw.Draw(guide)
            meter = registration.SPEC["hp_cap_case"]["meter"]
            mapped = [transform["crop"][i % 2] +
                      (meter[i] - transform["offset"][i % 2]) / transform["scale"]
                      for i in range(4)]
            guide_draw.rectangle(mapped, outline="#00ffff", width=4)
            guide_draw.text((24, 24), "DIAGNOSTIC ONLY: cyan = required native clear opening in source coordinates",
                            font=ImageFont.truetype(FONT, 24), fill="#00ffff")
            guide_path = review / ("source-coordinate-guide-" + revision + ".png")
            guide.convert("RGB").save(guide_path)
            records.append({"revision": revision, "source": rec(source_path), "export": rec(path),
                "sourceTransform": transform, "rgbaRoundtripPassed": True,
                "aperturePassed": aperture_passed, "sourceGate": source_gate,
                "nativeToe": list(native_toe), "candidateToe": list(candidate_toe),
                "candidateTerminal": rec(terminal), "failures": failures, "notes": notes,
                "sourceCoordinateGuide": rec(guide_path),
                "review1x": rec(image_path), "review2x": rec(image_path.with_stem(image_path.stem + "-2x"))})
            print(f"{theme}/{revision}: aperture={aperture_passed}, source gate={source_gate['passed']}, failures={len(failures)}")
        write(folder / "fit-report.json", {"schema": 1, "cases": records, "productionAccepted": False,
            "runtimeIntegrated": False, "foreverValidated": False, "retailValidated": False,
            "nextGate": "Resolve representative source geometry before cap fitting and full-pack expansion"})


if __name__ == "__main__":
    main()
