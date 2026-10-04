"""Repack the Mage crystal's energy animation into one small atlas per school.

The source is the approved 128-frame animation: eight 2048px pages per school,
sixteen 512px frames each (398 MB in all), kept in Assets_Draft/MageCrystalEnergy.
The crystal only ever shows the part of a frame inside the player crystal's
texcoord crop (Layouts/Data/PlayerUnitFrame.lua PowerBarTexCoord), so each
frame is cut to that crop plus a small margin, scaled down, and packed into a
single power-of-two page per school. Every frame is kept, so the animation
timing and its frame-to-frame crossfade are unchanged.

Writes Assets/MageCrystalTest/<school>-energy.tga and prints the layout that
Core/MageCrystalPreview.lua's ENERGY table must match.

    python Tools/Build-MageEnergyAtlas.py [--page 2048x1024] [--compare]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Assets_Draft", "MageCrystalEnergy")
OUTPUT = os.path.join(ROOT, "Assets", "MageCrystalTest")
SCHOOLS = ("arcane", "fire", "frost")
FRAMES, SOURCE_PAGES, SOURCE_GRID, SOURCE_CELL = 128, 8, 4, 512

# PowerBarTexCoord in 0-255 pixel units, widened by MARGIN on every side so a
# small negative powerBarTexCoordAdjust still finds energy to show.
CROP_PX = (50, 206, 37, 219)
MARGIN = 4


def baked_crop():
    left, right, top, bottom = CROP_PX
    return (max(0, left - MARGIN) / 255, min(255, right + MARGIN) / 255,
            max(0, top - MARGIN) / 255, min(255, bottom + MARGIN) / 255)


def source_frames(school):
    for page in range(1, SOURCE_PAGES + 1):
        path = os.path.join(SOURCE, "%s-energy-%02d.tga" % (school, page))
        image = Image.open(path).convert("RGBA")
        for index in range(SOURCE_GRID * SOURCE_GRID):
            column, row = index % SOURCE_GRID, index // SOURCE_GRID
            yield image.crop((column * SOURCE_CELL, row * SOURCE_CELL,
                              (column + 1) * SOURCE_CELL, (row + 1) * SOURCE_CELL))


def layout(page_w, page_h):
    """The largest cells of the crop's aspect that fit all frames on the page."""
    left, right, top, bottom = baked_crop()
    aspect = (right - left) / (bottom - top)
    best = None
    for rows in range(1, FRAMES + 1):
        cell_h = page_h // rows
        cell_w = int(cell_h * aspect)
        if cell_w < 1:
            break
        columns = page_w // cell_w
        if columns * rows < FRAMES:
            continue
        if not best or cell_h > best[3]:
            best = (columns, rows, cell_w, cell_h)
    return best


def build(school, page_w, page_h, write=True):
    left, right, top, bottom = baked_crop()
    columns, rows, cell_w, cell_h = layout(page_w, page_h)
    page = Image.new("RGBA", (page_w, page_h), (0, 0, 0, 0))
    box = (round(left * SOURCE_CELL), round(top * SOURCE_CELL),
           round(right * SOURCE_CELL), round(bottom * SOURCE_CELL))
    count = 0
    for index, frame in enumerate(source_frames(school)):
        cell = frame.crop(box).resize((cell_w, cell_h), Image.LANCZOS)
        page.paste(cell, ((index % columns) * cell_w, (index // columns) * cell_h))
        count += 1
    assert count == FRAMES, (school, count)
    if write:
        page.save(os.path.join(OUTPUT, "%s-energy.tga" % school))
    return page, (columns, rows, cell_w, cell_h)


def compare(school, page, grid):
    """PSNR of the shown, premultiplied colour against the source, per frame."""
    left, right, top, bottom = baked_crop()
    columns, rows, cell_w, cell_h = grid
    l, r, t, b = (v / 255 for v in CROP_PX)
    scores = []
    for index, frame in enumerate(source_frames(school)):
        if index % 9:
            continue
        x0, y0 = (index % columns) * cell_w, (index // columns) * cell_h
        cell = page.crop((x0, y0, x0 + cell_w, y0 + cell_h))
        # The default crop, at source resolution, from both.
        ref = frame.crop((round(l * 512), round(t * 512), round(r * 512), round(b * 512)))
        sx, sy = cell_w / ((right - left) * 512), cell_h / ((bottom - top) * 512)
        sub = cell.crop((round((l - left) * 512 * sx), round((t - top) * 512 * sy),
                         round((r - left) * 512 * sx), round((b - top) * 512 * sy))).resize(ref.size, Image.LANCZOS)
        a = np.asarray(ref, np.float32)
        c = np.asarray(sub, np.float32)
        a = a[..., :3] * a[..., 3:] / 255
        c = c[..., :3] * c[..., 3:] / 255
        scores.append(10 * np.log10(255 ** 2 / max(((a - c) ** 2).mean(), 1e-9)))
    return sum(scores) / len(scores)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--page", default="2048x1024")
    parser.add_argument("--compare", action="store_true")
    parser.add_argument("--dry", action="store_true", help="measure without writing")
    args = parser.parse_args()
    page_w, page_h = (int(v) for v in args.page.lower().split("x"))
    if not os.path.isdir(SOURCE):
        sys.exit("missing source frames: " + SOURCE)
    for school in SCHOOLS:
        page, grid = build(school, page_w, page_h, write=not args.dry)
        line = "%s %dx%d: %d columns x %d rows of %dx%d" % ((school, page_w, page_h) + grid)
        if args.compare:
            line += ", PSNR %.1f dB" % compare(school, page, grid)
        print(line)
    left, right, top, bottom = baked_crop()
    columns, rows, cell_w, cell_h = layout(page_w, page_h)
    print("ENERGY = { frames = %d, columns = %d, cellW = %d, cellH = %d, pageW = %d, pageH = %d," % (
        FRAMES, columns, cell_w, cell_h, page_w, page_h))
    print("\tcrop = { %d/255, %d/255, %d/255, %d/255 } }" % (
        round(left * 255), round(right * 255), round(top * 255), round(bottom * 255)))


if __name__ == "__main__":
    main()
