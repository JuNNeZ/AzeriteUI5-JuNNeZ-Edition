"""Read-only search for legal whole-source registration; never alter paint.

Searches integer resized heights at uniform scale, toe-aligns the whole source,
then applies the existing aperture and bounds gates. Results are diagnostic.
"""
from pathlib import Path
import hashlib
import json
import math

import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont
from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import aperture, whole_painting

ROOT = Path(__file__).resolve().parent.parent
SPEC = json.loads((ROOT / "Docs/Theme Asset Geometry.json").read_text())["hp_cap_case"]


def source_guide(source, fill, transform, path):
    """Diagnostic copy only: never mutate the source or use a guide as a stencil."""
    field = Image.new("L", source.size)
    mapped = fill.resize((round(fill.width / transform["scale"]), round(fill.height / transform["scale"])), Image.Resampling.NEAREST)
    field.paste(mapped, (round(transform["crop"][0] - transform["offset"][0] / transform["scale"]),
                         round(transform["crop"][1] - transform["offset"][1] / transform["scale"])))
    field = field.point(lambda a: 255 if a > 128 else 0)
    edge = (np.asarray(field.filter(ImageFilter.MaxFilter(7))) > 0) & (np.asarray(field.filter(ImageFilter.MinFilter(7))) == 0)
    intrude = (np.asarray(source)[:, :, 3] > 200) & (np.asarray(field) > 0)
    guide = Image.new("RGBA", source.size, "#252830")
    guide.alpha_composite(source)
    pixels = np.array(guide)
    pixels[edge] = [0, 255, 255, 255]
    pixels[intrude] = [255, 70, 40, 255]
    guide = Image.fromarray(pixels)
    ImageDraw.Draw(guide).text((24, 24), "DIAGNOSTIC: exact native aperture contour = cyan; interfering paint = red. Repaint red OUTWARD.",
                              font=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 23), fill="#dce4ef")
    guide.convert("RGB").save(path)


def main():
    fill = Image.open(ROOT / "Docs/Research_Assets/Templates/hp_cap_case-fill.png").convert("L")
    interior = np.asarray(fill.filter(ImageFilter.MinFilter(3))) > 128
    toe = lowest_point(Image.open(ROOT / "Assets/hp_cap_case.tga"))
    for theme in ("Priest", "Warlock"):
        result = []
        for path in sorted((ROOT / "Assets_Draft" / theme / "Sources").glob("hp_cap_case-v*.png")):
            source = Image.open(path).convert("RGBA")
            crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            trials = []
            # Any passing exterior fits in this range: native painted height
            # plus twice the source gate's 4%-of-canvas edge allowance.
            for height in range(80, 151):
                scale = height / (crop[3] - crop[1])
                paint = source.crop(crop).resize((round((crop[2] - crop[0]) * scale), height), Image.Resampling.LANCZOS)
                px, py = lowest_point(paint)
                # A half-pixel source toe has two legal integer translations.
                # Check both; the existing <=0.5 source-pixel gate stays exact.
                for dx in sorted({math.floor(toe[0] - px), math.ceil(toe[0] - px)}):
                    offset = [dx, round(toe[1] - py)]
                    if min(offset) < 0 or offset[0] + paint.width > 1024 or offset[1] + paint.height > 256:
                        continue
                    transform = {"crop": list(crop), "scale": scale, "offset": offset}
                    candidate = whole_painting(source, transform, SPEC["canvas"])
                    found = lowest_point(candidate)
                    if abs(found[0] - toe[0]) > .5 or found[1] != toe[1]:
                        continue
                    box = candidate.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
                    if any(abs(box[i] - SPEC["painted"][i]) > max(3, round(SPEC["canvas"][i % 2] * .04)) for i in range(4)):
                        continue
                    count = int(((np.asarray(candidate)[:, :, 3] > 200) & interior).sum())
                    try:
                        aperture(candidate, fill)
                        passed = True
                    except ValueError:
                        passed = False
                    trials.append({"transform": transform, "bounds": list(box), "solidFillIntrusionPixels": count, "aperturePassed": passed})
            trials.sort(key=lambda t: t["solidFillIntrusionPixels"])
            item = {"source": path.relative_to(ROOT).as_posix(),
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "legalBoundsAndToeTrials": len(trials), "passingTrials": sum(t["aperturePassed"] for t in trials),
                    "bestTrial": trials[0] if trials else None}
            if trials:
                revision = path.stem.rsplit("-", 1)[-1]
                guide_path = path.parent.parent / "Review" / ("exact-aperture-source-guide-" + revision + ".png")
                source_guide(source, fill, trials[0]["transform"], guide_path)
                item["sourceGuide"] = {"path": guide_path.relative_to(ROOT).as_posix(),
                                       "sha256": hashlib.sha256(guide_path.read_bytes()).hexdigest()}
            result.append(item)
            print(f"{theme}/{path.stem}: {item['passingTrials']} passing registrations; " +
                  (f"best still intrudes {trials[0]['solidFillIntrusionPixels']} solid pixels" if trials else "no legal bounds/toe trials"))
        (ROOT / "Assets_Draft" / theme / "registration-search.json").write_text(
            json.dumps({"schema": 1, "scope": "integer source-resize heights 80..150, whole uniform painting, native toe and current bounds gate; not proof over every real-valued scale", "sources": result}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
