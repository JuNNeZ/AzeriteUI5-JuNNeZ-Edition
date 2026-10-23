"""Original options page glyphs, following Docs/Codex Handoff - Options Window Art.md.

python Tools/Build-OptionsPageIcons.py [--preview path.png]

Pillow only. Shapes use a 32-unit grid, rendered at 8x then reduced to 64px.
No external icon art: each motif below is drawn from primitives. Body, rim and
shadow are composited at high resolution before straight-alpha TGA export.
"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
S = 8
SIZE = 32 * S
KEYS = (
    "quickstart themes profiles sharing unitframes auras nameplates actionbars "
    "cooldowns minimap mythicplus worldmap tracker bags chat infobar tooltips "
    "widgets gamemenu explorer debug controltypes appearance changelog changed generic "
    "groupframes aurasounds micromenu executerange"
).split()


class Glyph:
    def __init__(self):
        self.mask = Image.new("L", (SIZE, SIZE))
        self.d = ImageDraw.Draw(self.mask)

    def box(self, xy, radius=2, width=3, fill=False):
        self.d.rounded_rectangle(tuple(round(v * S) for v in xy), radius=round(radius * S),
                                 fill=255 if fill else None, outline=None if fill else 255,
                                 width=round(width * S))

    def circle(self, xy, width=3, fill=False):
        self.d.ellipse(tuple(round(v * S) for v in xy), fill=255 if fill else None,
                       outline=None if fill else 255, width=round(width * S))

    def line(self, points, width=3):
        pts = [(round(x * S), round(y * S)) for x, y in points]
        self.d.line(pts, fill=255, width=round(width * S), joint="curve")
        r = width * S / 2
        for x, y in pts:
            self.d.ellipse((round(x-r), round(y-r), round(x+r), round(y+r)), fill=255)

    def polygon(self, points, fill=False, width=3):
        if fill:
            self.d.polygon([(round(x*S), round(y*S)) for x, y in points], fill=255)
        else:
            self.line(points + [points[0]], width)

    def arc(self, xy, start, end, width=3):
        x0, y0, x1, y1 = xy
        points = []
        for i in range(65):
            a = math.radians(start + (end-start) * i/64)
            points.append(((x0+x1)/2 + (x1-x0)/2*math.cos(a),
                           (y0+y1)/2 + (y1-y0)/2*math.sin(a)))
        self.line(points, width)


def motif(key):
    g = Glyph()
    if key == "quickstart":
        g.circle((6, 6, 26, 26))
        g.polygon([(13, 11), (21, 16), (13, 21)], fill=True)
    elif key == "themes":
        g.polygon([(7, 10), (12, 6), (21, 6), (26, 11), (25, 17),
                   (19, 18), (18, 21), (20, 24), (15, 26), (9, 23), (6, 17)], fill=True)
        for x, y in [(11, 12), (17, 10), (22, 13)]:
            g.d.ellipse((round((x-1.8)*S), round((y-1.8)*S),
                         round((x+1.8)*S), round((y+1.8)*S)), fill=0)
    elif key == "profiles":
        g.box((6, 6, 26, 26))
        g.circle((12, 9, 20, 17), width=2.5)
        g.arc((10, 18, 22, 30), 190, 350, width=2.5)
    elif key == "sharing":
        g.line([(9, 16), (23, 9)])
        g.line([(9, 16), (23, 23)])
        for x, y in [(9, 16), (23, 9), (23, 23)]:
            g.circle((x-3, y-3, x+3, y+3), fill=True)
    elif key == "unitframes":
        g.circle((6, 10, 18, 22))
        g.box((19, 12, 26, 20), radius=1, width=2.5)
    elif key == "auras":
        g.box((6, 6, 26, 26))
        g.polygon([(16, 10), (16, 16), (23, 16), (22, 12), (19, 10)], fill=True)
    elif key == "nameplates":
        g.box((7, 6, 25, 11), radius=1, width=2)
        g.circle((13, 14, 19, 20), width=2)
        g.arc((10, 21, 22, 31), 195, 345, width=3)
    elif key == "actionbars":
        for x in [6, 13, 20]:
            g.box((x, 12, x+6, 20), radius=1, width=2)
    elif key == "cooldowns":
        g.circle((6, 6, 26, 26))
        g.polygon([(16, 10), (16, 16), (23, 19), (24, 15), (21, 11)], fill=True)
    elif key == "minimap":
        g.circle((7, 8, 25, 26))
        g.line([(16, 6), (16, 10)], width=2.5)
        g.circle((17, 17, 22, 22), fill=True)
    elif key == "mythicplus":
        g.polygon([(16, 6), (25, 11), (25, 21), (16, 26), (7, 21), (7, 11)])
        g.line([(16, 11), (16, 21)], width=2.5)
        g.line([(11, 16), (21, 16)], width=2.5)
    elif key == "worldmap":
        g.polygon([(6, 10), (12, 7), (20, 10), (26, 7), (26, 23),
                   (20, 26), (12, 23), (6, 26)], width=2)
        g.line([(12, 8), (12, 22)], width=2)
        g.line([(20, 11), (20, 25)], width=2)
    elif key == "tracker":
        for y in [8, 16, 24]:
            g.box((6, y-2, 10, y+2), radius=.6, fill=True)
            g.line([(14, y), (25, y)], width=2.5)
    elif key == "bags":
        g.arc((10, 6, 22, 18), 180, 360, width=2.5)
        g.box((7, 12, 25, 26), radius=2.5)
        g.line([(9, 16), (23, 16)], width=2.5)
        g.circle((14, 17, 18, 21), fill=True)
    elif key == "chat":
        g.polygon([(7, 7), (25, 7), (25, 21), (14, 21), (9, 26), (9, 21), (7, 21)])
    elif key == "infobar":
        g.box((6, 12, 26, 20), radius=1.5, width=2)
        for x in [13, 19]:
            g.line([(x, 13), (x, 19)], width=2)
    elif key == "tooltips":
        g.polygon([(7, 12), (11, 12), (14, 7), (17, 12), (25, 12), (25, 25), (7, 25)], width=2.5)
        g.line([(11, 17), (21, 17)], width=2)
        g.line([(11, 21), (18, 21)], width=2)
    elif key == "widgets":
        g.box((6, 13, 26, 19), radius=2, width=2)
        g.polygon([(18, 9), (23, 16), (18, 23), (13, 16)], fill=True)
    elif key == "gamemenu":
        g.box((6, 6, 26, 26), radius=3, width=2.5)
        for y in [11, 16, 21]:
            g.line([(11, y), (21, y)], width=2)
    elif key == "explorer":
        g.circle((6, 6, 26, 26))
        g.polygon([(18, 10), (20, 17), (14, 23), (12, 15)], fill=True)
    elif key == "debug":
        for y in [13, 18, 23]:
            g.line([(7, y-1), (12, y+1)], width=2)
            g.line([(20, y+1), (25, y-1)], width=2)
        g.circle((13, 6, 19, 12), width=2)
        g.circle((11, 12, 21, 26), fill=True)
        g.d.line([(16*S, 14*S), (16*S, 24*S)], fill=0, width=2*S)
    elif key == "controltypes":
        g.box((8, 7, 24, 14), radius=3, width=2)
        g.circle((10, 9, 14, 12), fill=True)
        g.line([(7, 23), (25, 23)], width=2.5)
        g.circle((12, 20, 18, 26), fill=True)
    elif key == "appearance":
        g.box((6, 7, 26, 25), width=2.5)
        g.line([(8, 12), (24, 12)], width=2)
        g.circle((12, 14, 21, 23), width=2)
        g.d.pieslice((12*S, 14*S, 21*S, 23*S), 90, 270, fill=255)
    elif key == "changelog":
        g.polygon([(8, 6), (19, 6), (25, 12), (25, 26), (8, 26)], width=2.5)
        g.line([(19, 7), (19, 12), (24, 12)], width=2)
        for y, x in [(16, 21), (20, 21), (24, 17)]:
            g.line([(12, y), (x, y)], width=2)
    elif key == "changed":
        g.polygon([(6, 13), (11, 7), (21, 7), (26, 13), (16, 26)], width=2.5)
        g.line([(7, 13), (25, 13)], width=2)
        g.line([(11, 8), (16, 13), (21, 8)], width=2)
        g.line([(16, 14), (16, 24)], width=2)
    elif key == "groupframes":
        # Four party/raid tiles, each with a health fill along its top.
        for x, y in [(6, 7), (17, 7), (6, 18), (17, 18)]:
            g.box((x, y, x+9, y+7), radius=1, width=2)
            g.line([(x+2, y+2.5), (x+7, y+2.5)], width=2)
    elif key == "aurasounds":
        g.polygon([(6, 13), (10, 13), (15, 8), (15, 24), (10, 19), (6, 19)], fill=True)
        g.arc((11, 11, 21, 21), -50, 50, width=2.5)
        g.arc((11, 6, 27, 26), -50, 50, width=2.5)
    elif key == "micromenu":
        # The cog wheel in the bottom right corner.
        g.circle((9, 9, 23, 23), width=3.5)
        for i in range(8):
            a = math.radians(i * 45 + 22.5)
            g.line([(16 + 8*math.cos(a), 16 + 8*math.sin(a)),
                    (16 + 9.5*math.cos(a), 16 + 9.5*math.sin(a))], width=4.5)
    elif key == "executerange":
        # A health bar, the line at the threshold and the low end below it filled.
        g.box((5, 11, 27, 21), radius=2, width=2)
        g.box((8, 14, 12, 18), radius=.6, fill=True)
        g.line([(15, 8), (15, 24)], width=2.5)
    elif key == "generic":
        g.box((6, 6, 26, 26), radius=3, width=2.5)
        for x in [12, 20]:
            for y in [12, 20]:
                g.circle((x-2, y-2, x+2, y+2), fill=True)
    else:
        raise ValueError(key)
    # Leave room for the 2.5px rim inside the central 48px, even at round caps.
    fitted = Image.new("L", g.mask.size)
    fitted.paste(g.mask.resize((230, 230), Image.Resampling.LANCZOS), (13, 13))
    return fitted


def render(mask, light=False):
    if light:
        # Light uses a clean, tintable silhouette. A black rim and blurred
        # shadow collapse into the dark body when multiplied by its ink colour.
        white = Image.new("L", mask.size, 255)
        return Image.merge("RGBA", (white, white, white, mask)).resize((64, 64), Image.Resampling.LANCZOS)
    rim = mask.filter(ImageFilter.MaxFilter(2 * 10 + 1))  # 2.5px rim at 64
    shifted = Image.new("L", mask.size)
    shifted.paste(rim, (0, S))  # 2px down at 64, without wrapping
    shadow = shifted.filter(ImageFilter.GaussianBlur(1.5*S)).point(lambda a: round(a*.6))
    assert shadow.getextrema()[1] <= 153, "shadow exceeds 60% alpha"
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    black = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    black.putalpha(shadow)
    out.alpha_composite(black)
    edge = Image.new("RGBA", mask.size, (12, 12, 12, 0))
    edge.putalpha(rim)
    out.alpha_composite(edge)
    # Top/left-facing surfaces catch light; bottom/right-facing ones stay 185.
    behind = Image.new("L", mask.size)
    behind.paste(mask, (S, S))
    bevel = ImageChops.subtract(mask, behind).filter(ImageFilter.GaussianBlur(.3*S))
    grey = bevel.point(lambda a: 185 + round(a * 70/255))
    lo, hi = grey.getextrema()
    assert 170 <= lo <= hi <= 255, "body outside tintable luminance range"
    out.alpha_composite(Image.merge("RGBA", (grey, grey, grey, mask)))
    return out.resize((64, 64), Image.Resampling.LANCZOS)


def validate(atlas, path, rows=4):
    assert atlas.size == (512, rows * 64) and atlas.mode == "RGBA"
    assert all(r == g == b for r, g, b, a in atlas.getdata()), "non-grey pixels"
    assert len(KEYS) <= 8 * rows, "atlas capacity exceeded"
    for i in range(8 * rows):
        cell = atlas.crop((i % 8 * 64, i // 8 * 64, i % 8 * 64 + 64, i // 8 * 64 + 64))
        alpha = cell.getchannel("A")
        if i >= len(KEYS):
            assert alpha.getbbox() is None, "reserve cell must be empty"
        else:
            assert alpha.getbbox(), KEYS[i]
            solid = alpha.point(lambda a: 255 if a == 255 else 0).getbbox()
            assert solid and solid[0] >= 8 and solid[1] >= 8 and solid[2] <= 56 and solid[3] <= 56, (KEYS[i], solid)
            body = motif(KEYS[i])
            assert body.getbbox(), KEYS[i]
    header = path.read_bytes()[:18]
    assert header[2] == 2 and header[16] == 32 and header[17] & 15 == 8, "TGA must be uncompressed RGBA"
    with Image.open(path) as reopened:
        assert reopened.convert("RGBA").tobytes() == atlas.tobytes(), "TGA roundtrip"
    print(f"PASS: 512x{rows * 64} RGBA, uncompressed TGA, greyscale, {len(KEYS)} safe cells, {8 * rows - len(KEYS)} transparent reserves, exact roundtrip")


def preview(atlas, path, light_atlas=None):
    themes = [
        ("Azerite", (5, 5, 5), (196, 196, 196), (229, 178, 38)),
        ("Dark", (3, 3, 4), (199, 199, 204), (158, 189, 219)),
        ("Light", (247, 247, 250), (23, 23, 28), (92, 64, 8)),
        ("Class / Mage", (5, 5, 5), (196, 196, 196), (63, 199, 235)),
    ]
    height = 88 + len(KEYS)*32 + 20
    img = Image.new("RGB", (1120, height), (24, 25, 28))
    d = ImageDraw.Draw(img)
    d.text((20, 14), "OPTIONS PAGE ICONS / original greyscale art / 28px overview + 16px normal & selected", fill="white")
    for t, (label, bg, normal, selected) in enumerate(themes):
        x0 = t*280
        d.rectangle((x0+8, 42, x0+272, height-10), fill=bg)
        ink = (110, 110, 110) if t == 2 else (180, 180, 180)
        d.text((x0+18, 54), label, fill=ink)
        for i, key in enumerate(KEYS):
            y = 88+i*32
            source_atlas = light_atlas if t == 2 and light_atlas is not None else atlas
            cell = source_atlas.crop((i%8*64, i//8*64, i%8*64+64, i//8*64+64))
            def tint(color, size):
                r, g, b, a = cell.split()
                return Image.merge("RGBA", (r.point(lambda v: round(v*color[0]/255)),
                                             g.point(lambda v: round(v*color[1]/255)),
                                             b.point(lambda v: round(v*color[2]/255)), a)).resize((size, size), Image.Resampling.LANCZOS)
            source = tint(normal, 28)
            img.paste(source, (x0+18, y-5), source)
            for x, color in [(64, normal), (92, selected)]:
                icon = tint(color, 16)
                img.paste(icon, (x0+x, y), icon)
            d.text((x0+122, y+2), f"{i:02} {key}", fill=ink)
    img.save(path)
    print("Preview:", path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    atlas = Image.new("RGBA", (512, 256))
    light_atlas = Image.new("RGBA", atlas.size)
    for i, key in enumerate(KEYS):
        mask = motif(key)
        atlas.paste(render(mask), (i%8*64, i//8*64))
        light_atlas.paste(render(mask, light=True), (i%8*64, i//8*64))
    path = ROOT / "Assets" / "options-pages.tga"
    atlas.save(path, compression=None)
    validate(atlas, path)
    print("Wrote:", path)
    light_path = ROOT / "Assets" / "options-pages-light.tga"
    light_atlas.save(light_path, compression=None)
    validate(light_atlas, light_path)
    print("Wrote:", light_path)
    if args.preview:
        preview(atlas, args.preview, light_atlas)


if __name__ == "__main__":
    main()
