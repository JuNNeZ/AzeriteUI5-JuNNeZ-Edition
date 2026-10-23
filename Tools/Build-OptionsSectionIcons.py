"""Options section glyphs: the small icons beside a page's sections, in the rail
and on each section's heading.

python Tools/Build-OptionsSectionIcons.py [--preview path.png]

The same 32-unit grid, rim, shadow, greyscale and checks as the page icons
(Tools/Build-OptionsPageIcons.py, imported, not copied), on a second 8x8 sheet:
Assets/options-sections.tga. Which section gets which cell is decided in
Options/Kit/Look.lua (SECTION_ICONS); several sections share a motif (all eight
action bars, the three raid sizes), so the sheet stays small and the icons mean
something. Navigation only: no icon on a single setting.
"""
import argparse
import importlib.util
import math
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("page_icons", HERE / "Build-OptionsPageIcons.py")
pages = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pages)

Glyph, render, S = pages.Glyph, pages.render, pages.S

KEYS = (
    "player target tot focus pet boss arena castbar "
    "classpower heal party raid corners actionbar stance proc "
    "assist bell eye eyeslash resize droplet funnel gate "
    "friendly gear wrench horseshoe clock key "
    "hunter paladin mage druid warrior crystal orb leaf moon totem smooth text sort anchor export import shield"
).split()

ALMOND = [(5.5, 16), (10, 11), (16, 9), (22, 11), (26.5, 16), (22, 21), (16, 23), (10, 21)]


def eye(g):
    g.polygon(ALMOND, width=2.5)
    g.circle((12, 12, 20, 20), fill=True)


def motif(key):
    g = Glyph()
    if key == "player":
        g.circle((11.5, 4, 20.5, 13), fill=True)
        g.polygon([(7, 28), (8.5, 20), (12, 16), (20, 16), (23.5, 20), (25, 28)], fill=True)
    elif key == "target":
        g.circle((7, 7, 25, 25), width=2.5)
        for a, b in [((16, 5.5), (16, 10)), ((16, 22), (16, 26.5)), ((5.5, 16), (10, 16)), ((22, 16), (26.5, 16))]:
            g.line([a, b], width=2.5)
        g.circle((14, 14, 18, 18), fill=True)
    elif key == "tot":
        # Your target's target: a ring leading to a second, marked one.
        g.circle((5, 13, 17, 25), width=2.5)
        g.line([(15, 15), (17.5, 12.5)], width=2.5)
        g.circle((15, 5, 27, 17), width=2.5)
        g.circle((19, 9, 23, 13), fill=True)
    elif key == "focus":
        for pts in [[(6, 11), (6, 6), (11, 6)], [(21, 6), (26, 6), (26, 11)],
                    [(26, 21), (26, 26), (21, 26)], [(11, 26), (6, 26), (6, 21)]]:
            g.line(pts, width=2.5)
        g.circle((13, 13, 19, 19), fill=True)
    elif key == "pet":
        g.d.ellipse(tuple(round(v * S) for v in (9.5, 15, 22.5, 26.5)), fill=255)
        for box in [(4.5, 10, 9.5, 15.5), (10, 4.5, 15, 10), (17, 4.5, 22, 10), (22.5, 10, 27.5, 15.5)]:
            g.circle(box, fill=True)
    elif key == "boss":
        g.circle((6.5, 3.5, 25.5, 22), fill=True)
        g.box((11, 17, 21, 27.5), radius=1.2, fill=True)
        for box in [(10, 10, 14.5, 15), (17.5, 10, 22, 15)]:
            g.d.ellipse(tuple(round(v * S) for v in box), fill=0)
        for x in [14.3, 17.7]:
            g.d.line([(round(x * S), 22 * S), (round(x * S), 28 * S)], fill=0, width=round(1.4 * S))
    elif key == "arena":
        g.line([(6, 6), (23, 23)], width=2.5)
        g.line([(19, 24), (24, 19)], width=2.5)
        g.circle((23, 23, 28, 28), fill=True)
        g.line([(26, 6), (9, 23)], width=2.5)
        g.line([(8, 19), (13, 24)], width=2.5)
        g.circle((4, 23, 9, 28), fill=True)
    elif key == "castbar":
        g.box((4, 11.5, 28, 20.5), radius=1.5, width=2)
        g.box((6.5, 14, 17.5, 18), radius=.5, fill=True)
        g.line([(20, 8), (20, 24)], width=2.5)
    elif key == "classpower":
        for x in [8.5, 16, 23.5]:
            g.polygon([(x, 11.5), (x + 4, 16), (x, 20.5), (x - 4, 16)], fill=True)
    elif key == "heal":
        g.box((12.5, 5, 19.5, 27), radius=1.2, fill=True)
        g.box((5, 12.5, 27, 19.5), radius=1.2, fill=True)
    elif key == "party":
        g.circle((12.5, 4, 19.5, 11), fill=True)
        g.box((10, 13, 22, 26), radius=4, fill=True)
        g.circle((5, 10, 10, 15), fill=True)
        g.circle((22, 10, 27, 15), fill=True)
        g.box((4.5, 17, 10, 25), radius=2.5, fill=True)
        g.box((22, 17, 27.5, 25), radius=2.5, fill=True)
    elif key == "raid":
        for x in [5, 13, 21]:
            for y in [5, 13, 21]:
                g.box((x, y, x + 6, y + 6), radius=.8, fill=True)
    elif key == "corners":
        # A group frame with an aura dot in each corner.
        g.box((5, 5, 27, 27), radius=2.5, width=2)
        for x, y in [(8, 8), (19, 8), (8, 19), (19, 19)]:
            g.circle((x, y, x + 5, y + 5), fill=True)
    elif key == "actionbar":
        for x in [4.5, 12.5, 20.5]:
            g.box((x, 11, x + 7, 21), radius=1.5, width=2)
    elif key == "stance":
        g.polygon([(16, 6), (25, 9.5), (24, 18), (16, 26), (8, 18), (7, 9.5)], width=2.5)
        g.line([(16, 9), (16, 23)], width=2)
    elif key == "proc":
        g.polygon([(16, 5), (18.8, 13.2), (27, 16), (18.8, 18.8), (16, 27), (13.2, 18.8), (5, 16), (13.2, 13.2)], fill=True)
    elif key == "assist":
        g.circle((9, 3.5, 23, 17.5), width=2.5)
        g.box((12, 19, 20, 23), radius=1, fill=True)
        g.line([(13, 26.5), (19, 26.5)], width=2)
    elif key == "bell":
        g.polygon([(8, 22), (9, 13), (12, 8), (16, 6), (20, 8), (23, 13), (24, 22)], fill=True)
        g.line([(5.5, 22), (26.5, 22)], width=2.5)
        g.circle((14, 23, 18, 27), fill=True)
    elif key == "eye":
        eye(g)
    elif key == "eyeslash":
        eye(g)
        g.d.line([(6 * S, 27 * S), (26 * S, 5 * S)], fill=0, width=round(5.5 * S))
        g.line([(7, 26), (25, 6)], width=2.5)
    elif key == "resize":
        g.line([(9, 23), (23, 9)], width=2.5)
        g.polygon([(26.5, 5.5), (26.5, 14), (18, 5.5)], fill=True)
        g.polygon([(5.5, 26.5), (5.5, 18), (14, 26.5)], fill=True)
    elif key == "droplet":
        g.polygon([(16, 3.5), (23.5, 14), (24.5, 19), (21.5, 25.5), (16, 28), (10.5, 25.5), (7.5, 19), (8.5, 14)], fill=True)
    elif key == "funnel":
        g.polygon([(4.5, 6), (27.5, 6), (19, 16), (19, 25), (13, 28.5), (13, 16)], fill=True)
    elif key == "gate":
        # Content settings: a dungeon's doorway.
        g.arc((7, 6.5, 25, 24.5), 180, 360, width=2.5)
        g.line([(7, 15.5), (7, 25)], width=2.5)
        g.line([(25, 15.5), (25, 25)], width=2.5)
        g.line([(5.5, 26), (26.5, 26)], width=2)
        g.line([(16, 10), (16, 25)], width=2)
    elif key == "friendly":
        g.circle((7.5, 4, 15.5, 12), fill=True)
        g.box((4, 14, 19, 27), radius=4.5, fill=True)
        g.polygon([(22.5, 26), (18, 20.5), (18, 17), (20.25, 15), (22.5, 17), (24.75, 15), (27, 17), (27, 20.5)], fill=True)
    elif key == "gear":
        g.circle((9, 9, 23, 23), width=3.5)
        for i in range(8):
            a = math.radians(i * 45 + 22.5)
            g.line([(16 + 8 * math.cos(a), 16 + 8 * math.sin(a)),
                    (16 + 9.5 * math.cos(a), 16 + 9.5 * math.sin(a))], width=4.5)
    elif key == "wrench":
        # An open-ended spanner, its jaw open to the top right.
        g.line([(6.5, 25.5), (16.5, 15.5)], width=3.5)
        g.arc((14.5, 5.5, 25.5, 16.5), 0, 270, width=3)
    elif key == "horseshoe":
        g.arc((7, 6.5, 25, 24.5), 180, 360, width=3.5)
        g.line([(7, 15.5), (9, 25)], width=3.5)
        g.line([(25, 15.5), (23, 25)], width=3.5)
        for x, y in [(9.5, 12), (22.5, 12), (10, 20), (22, 20)]:
            g.d.ellipse((round((x - .8) * S), round((y - .8) * S), round((x + .8) * S), round((y + .8) * S)), fill=0)
    elif key == "clock":
        g.circle((5, 5, 27, 27), width=2.5)
        g.line([(16, 16), (16, 9)], width=2.5)
        g.line([(16, 16), (21, 19)], width=2.5)
    elif key == "key":
        g.circle((4.5, 10, 16, 21.5), width=3)
        g.line([(16, 16), (26, 16)], width=3)
        g.line([(22, 16), (22, 21)], width=2.5)
        g.line([(26, 16), (26, 20)], width=2.5)
    elif key == "hunter":
        g.arc((2, 5, 26, 27), -80, 80, width=2.5)
        g.line([(16, 5), (16, 27)], width=2)
        g.line([(5, 16), (27, 16)], width=2.5)
        g.line([(23, 12), (27, 16), (23, 20)], width=2)
    elif key == "paladin":
        g.line([(16, 12), (16, 26)], width=3.5)
        g.box((7, 8, 25, 16), radius=1.5, fill=True)
        for x, y in [(8, 6), (16, 5), (24, 6)]:
            g.line([(x, y), (x, y + 2)], width=1.8)
    elif key == "mage":
        g.line([(10, 26), (20, 10)], width=3)
        g.polygon([(21, 5), (26, 10), (21, 15), (16, 10)], width=2)
    elif key == "druid":
        g.polygon([(6, 24), (7, 14), (15, 7), (27, 5), (25, 17), (18, 25), (9, 26)], width=2.5)
        g.line([(5, 26.5), (22, 11)], width=2.5)
        g.line([(12, 21), (12, 15)], width=2)
    elif key == "warrior":
        g.line([(7, 26), (23, 7)], width=3.5)
        g.polygon([(13, 6), (23, 7), (28, 15), (22, 21), (18, 13), (10, 11)], fill=True)
    elif key == "crystal":
        g.polygon([(16, 5), (25, 11), (23, 22), (16, 26.5), (9, 22), (7, 11)], width=2.5)
        g.line([(16, 6), (12, 13), (16, 26), (20, 13), (16, 6)], width=1.8)
        g.line([(8, 12), (24, 12)], width=1.8)
    elif key == "orb":
        g.circle((5, 5, 27, 27), width=2.5)
        g.arc((10, 9, 22, 23), 185, 270, width=2.5)
        g.line([(8, 22), (24, 22)], width=2)
    elif key == "leaf":
        g.polygon([(7, 22), (9, 12), (26, 5), (24, 21), (16, 26)], fill=True)
        g.d.line([(8*S, 25*S), (22*S, 11*S)], fill=0, width=2*S)
    elif key == "moon":
        g.circle((5, 4, 27, 28), fill=True)
        g.d.ellipse((13*S, 2*S, 31*S, 23*S), fill=0)
    elif key == "totem":
        g.box((12, 5, 20, 27), radius=1, width=2.5)
        g.polygon([(5, 9), (27, 9), (23, 15), (9, 15)], width=2)
        g.line([(8, 27), (24, 27)], width=2.5)
        g.circle((14.5, 18, 17.5, 21), fill=True)
    elif key == "smooth":
        g.line([(5, 6), (5, 26), (27, 26)], width=2)
        g.line([(8, 22), (11, 21), (14, 17), (18, 11), (21, 9), (26, 8)], width=2.5)
    elif key == "text":
        for y, end in [(7, 26), (16, 22), (25, 18)]:
            g.line([(6, y), (end, y)], width=2.5)
    elif key == "sort":
        for y, end in [(7, 18), (16, 22), (25, 26)]:
            g.line([(12, y), (end, y)], width=2.5)
        g.line([(7, 6), (7, 25)], width=2)
        g.line([(4.5, 22), (7, 25), (9.5, 22)], width=2)
    elif key == "anchor":
        g.circle((13, 4, 19, 10), width=2)
        g.line([(16, 10), (16, 27)], width=2.5)
        g.line([(10, 14), (22, 14)], width=2)
        g.arc((6, 9, 26, 27), 0, 180, width=2.5)
        g.line([(6, 18), (6, 22)], width=2)
        g.line([(26, 18), (26, 22)], width=2)
    elif key in ("export", "import"):
        g.line([(7, 19), (7, 27), (25, 27), (25, 19)], width=2.5)
        g.line([(16, 5), (16, 21)], width=2.5)
        tip, back = (5, 10) if key == "export" else (21, 16)
        g.line([(11, back), (16, tip), (21, back)], width=2.5)
    elif key == "shield":
        g.polygon([(16, 5), (26, 8), (24, 21), (16, 26.5), (8, 21), (6, 8)], width=2.5)
        g.line([(16, 9), (16, 21)], width=2.5)
    else:
        raise ValueError(key)
    fitted = Image.new("L", g.mask.size)
    fitted.paste(g.mask.resize((230, 230), Image.Resampling.LANCZOS), (13, 13))
    return fitted


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    # validate() and preview() read KEYS and motif from their own module.
    pages.KEYS, pages.motif = KEYS, motif
    atlas = Image.new("RGBA", (512, 512))
    light_atlas = Image.new("RGBA", atlas.size)
    for i, key in enumerate(KEYS):
        mask = motif(key)
        atlas.paste(render(mask), (i % 8 * 64, i // 8 * 64))
        light_atlas.paste(render(mask, light=True), (i % 8 * 64, i // 8 * 64))
    path = HERE.parent / "Assets" / "options-sections.tga"
    atlas.save(path, compression=None)
    pages.validate(atlas, path, rows=8)
    print("Wrote:", path)
    light_path = HERE.parent / "Assets" / "options-sections-light.tga"
    light_atlas.save(light_path, compression=None)
    pages.validate(light_atlas, light_path, rows=8)
    print("Wrote:", light_path)
    if args.preview:
        pages.preview(atlas, args.preview, light_atlas)


if __name__ == "__main__":
    main()
