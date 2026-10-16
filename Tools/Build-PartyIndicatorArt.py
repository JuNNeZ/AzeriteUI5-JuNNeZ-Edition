"""Build final shared glyphs and an outside-only portrait threat glow.

    python Tools/Build-PartyIndicatorArt.py

Simple silhouettes are drawn at 8x resolution, then reduced with straight alpha.
The portrait exclusion is identical to the original placeholder's cutaway.
See Docs/Party Indicator Icons Brief.md. Requires Pillow.
"""
import math
import struct
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Assets"
PREVIEW = ROOT / "Docs/Research_Assets/PartyIndicators/final-icons.png"
SS = 8
SIZE = 64


def mask():
    return Image.new("L", (SIZE * SS, SIZE * SS))


def points(coords):
    return [(round(x * SS), round(y * SS)) for x, y in coords]


def crown():
    out = mask()
    draw = ImageDraw.Draw(out)
    # One connected silhouette; no fragile detached jewels or thin base seam.
    draw.polygon(points([(16, 45), (13, 23), (24, 32), (32, 17),
                         (40, 32), (51, 23), (48, 45)]), fill=255)
    for x, y in ((13, 22), (32, 17), (51, 22)):
        draw.ellipse((int((x-2.5)*SS), int((y-2.5)*SS),
                      int((x+2.5)*SS), int((y+2.5)*SS)), fill=255)
    return out


def star():
    out = mask()
    coords = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        radius = 18 if i % 2 == 0 else 8.5
        coords.append((32 + radius * math.cos(angle), 33 + radius * math.sin(angle)))
    ImageDraw.Draw(out).polygon(points(coords), fill=255)
    return out


def portal():
    out = mask()
    draw = ImageDraw.Draw(out)
    # An inward spiral with a broad entrance reads as arrival at 32px.
    coords = []
    for i in range(241):
        t = i / 240
        angle = -math.pi / 2 + t * math.pi * 3.2
        radius = 17 - 13 * t
        coords.append((32 + radius * math.cos(angle), 32 + radius * math.sin(angle)))
    draw.line(points(coords), fill=255, width=5 * SS, joint="curve")
    for x, y in (coords[0], coords[-1]):
        draw.ellipse((int((x-2.5)*SS), int((y-2.5)*SS),
                      int((x+2.5)*SS), int((y+2.5)*SS)), fill=255)
    return out


def phase():
    out = mask()
    draw = ImageDraw.Draw(out)
    # Two clear overlapping rings, with strokes that survive 22px downsampling.
    for x in (13, 27):
        draw.ellipse((x*SS, 19*SS, (x+24)*SS, 43*SS), outline=255, width=5*SS)
    return out


def finish(shape, color):
    core = shape.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    # Finite eight-pixel halo, with genuinely transparent canvas edges.
    halo = core.filter(ImageFilter.GaussianBlur(2.5))
    halo = halo.point(lambda v: min(150, round(v * 1.35)))
    support = core.point(lambda v: 255 if v > 0 else 0).filter(ImageFilter.MaxFilter(17))
    alpha = ImageChops.lighter(core, ImageChops.multiply(halo, support))
    out = Image.new("RGBA", core.size, (*color, 0))
    out.putalpha(alpha)
    return out


def threat():
    border = Image.open(ASSETS / "party_portrait_border.tga").convert("RGBA")
    ring = border.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    hole = ring.copy()
    ImageDraw.floodfill(hole, (128, 128), 128)
    hole = hole.point(lambda v: 255 if v == 128 else 0).filter(ImageFilter.MaxFilter(13))
    # Preserve the traced contour and exclusion; refine only its falloff.
    glow = ring.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(7))
    peak = max(glow.getextrema()[1], 1)
    glow = glow.point(lambda v: round(255 * (v / peak) ** 1.2))
    glow = ImageChops.subtract(glow, hole)
    assert ImageChops.multiply(glow, hole).getbbox() is None, "Portrait opening covered"
    out = Image.new("RGBA", border.size, (255, 255, 255, 0))
    out.putalpha(glow)
    return out


def tint(image, color):
    out = Image.new("RGBA", image.size, (*color, 0))
    out.putalpha(image.getchannel("A"))
    return out


def preview(icons, glow):
    sheet = Image.new("RGBA", (900, 400), (25, 28, 33, 255))
    draw = ImageDraw.Draw(sheet)
    entries = [("Heal (original)", Image.open(ASSETS / "grouprole-icons-heal.tga")),
               ("Tank (original)", Image.open(ASSETS / "grouprole-icons-tank.tga"))]
    entries += list(icons.items())
    for i, (name, icon) in enumerate(entries):
        x = 12 + i * 148
        sheet.alpha_composite(icon.convert("RGBA").resize((112, 112)), (x, 30))
        draw.text((x, 152), name, fill="white")
        size = 32 if name == "Summon" else 22
        sheet.alpha_composite(icon.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS), (x+44, 180))
        draw.text((x, 218), f"{size}px texture", fill=(180, 185, 195))
    for i, color in enumerate(((180, 120, 255), (80, 220, 80), (220, 60, 60))):
        sheet.alpha_composite(tint(icons["Summon"], color).resize((32, 32), Image.Resampling.LANCZOS), (20+i*52, 285))
    draw.text((20, 335), "Summon: pending / accepted / declined", fill="white")
    ring = Image.open(ASSETS / "party_portrait_border.tga").convert("RGBA")
    for i, color in enumerate(((255, 220, 30), (255, 125, 0), (255, 40, 30))):
        x = 330+i*180
        sheet.alpha_composite(tint(glow, color).resize((150, 150), Image.Resampling.LANCZOS), (x, 245))
        sheet.alpha_composite(ring.resize((150, 150), Image.Resampling.LANCZOS), (x, 245))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(PREVIEW)


def main():
    icons = {"Leader": finish(crown(), (255, 208, 55)),
             "Assistant": finish(star(), (213, 225, 240)),
             "Summon": finish(portal(), (255, 255, 255)),
             "Phase": finish(phase(), (115, 202, 255))}
    assets = {f"party-indicator-{key.lower()}.tga": value for key, value in icons.items()}
    glow = threat()
    assets["party_portrait_threat.tga"] = glow
    for name, art in assets.items():
        path = ASSETS / name
        art.save(path, compression=None)
        header = path.read_bytes()[:18]
        assert header[2] == 2 and header[16] == 32 and header[17] & 15 == 8
        expected = (256, 256) if name == "party_portrait_threat.tga" else (64, 64)
        assert struct.unpack_from("<HH", header, 12) == expected
        assert art.getchannel("A").getextrema() == (0, 255)
        if "summon" in name or "threat" in name:
            assert all(art.getchannel(c).getextrema() == (255, 255) for c in "RGB")
        assert Image.open(path).convert("RGBA").tobytes() == art.tobytes()
        print(f"PASS {name}: uncompressed RGBA, {expected}, straight alpha")
    preview(icons, glow)
    print(f"Preview: {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
