"""Pack existing DK tooltip components into BackdropTemplate's eight cells.

This is atlas assembly, not repainting: exact RGBA patches, integer translation,
quarter-turns and edge tiling only. Original paintings/candidates stay unchanged.
WIP-only construction; no production or live approval is granted.
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
REVIEW = ROOT / "Docs/Research_Assets/DeathKnight/FullSet/Review/tooltip"
# Cuts through the plain connecting rails, outside corner facets/wraps. Each
# complete corner body moves together. Strip ends are not part of a repeat tile.
PATCHES = [
    {"cell": 0, "crop": [7, 10, 71, 54], "turn": 0},
    {"cell": 1, "crop": [63, 10, 127, 54], "turn": 0},
    {"cell": 2, "crop": [294, 0, 346, 64], "turn": 90},
    {"cell": 3, "crop": [406, 0, 458, 64], "turn": 90},
    {"cell": 4, "crop": [250, 0, 314, 64], "turn": 0},
    {"cell": 5, "crop": [314, 0, 378, 64], "turn": 0},
    {"cell": 6, "crop": [378, 0, 442, 64], "turn": 0},
    {"cell": 7, "crop": [442, 0, 506, 64], "turn": 0},
]


def pack(source):
    assert source.size == (512, 64)
    atlas = Image.new("RGBA", source.size)
    for patch in PATCHES:
        part = source.crop(patch["crop"])
        if patch["turn"]:
            part = part.transpose(Image.Transpose.ROTATE_90)
        assert part.width == 64
        # All painted pixels of the declared patch are retained. Repeated edge
        # tiles may finish partway through the next repeat, as in the game.
        for y in range(0, 64, part.height):
            atlas.paste(part.crop((0, 0, 64, min(part.height, 64-y))), (patch["cell"]*64, y))
    return atlas


def joins(atlas):
    """Compare solid join profiles at the UVs WoW actually samples (4..60)."""
    a = np.asarray(atlas)[:, :, 3] > 128
    def span(values):
        where = np.flatnonzero(values)
        assert len(where), "Empty tooltip join"
        return np.array([where[0], where[-1]])
    # Native strip order: left, right, top, bottom, TL, TR, BL, BR.
    errors = []
    for edge in range(4):
        tile = a[:, edge*64:(edge+1)*64]
        if not tile.any(axis=1).all():
            errors.append({"edge": edge, "emptyRepeatRows": int((~tile.any(axis=1)).sum())})
    for corner, edge, horizontal, coordinate in (
        (4, 0, False, 59), (5, 1, False, 59),
        (6, 0, False, 4), (7, 1, False, 4),
        (4, 2, True, 59), (5, 2, True, 4),
        (6, 3, True, 59), (7, 3, True, 4),
    ):
        c = a[:, corner*64:(corner+1)*64]
        e = a[:, edge*64:(edge+1)*64]
        actual = span(c[:, coordinate] if horizontal else c[coordinate])
        # Ignore lighting variation along the strip; compare its median span.
        expected = np.median([span(row) for row in e if row.any()], axis=0)
        delta = float(np.max(np.abs(actual-expected)))
        if delta > 2:
            errors.append({"corner": corner, "edge": edge, "delta": delta})
    return errors


def render(atlas, width, height, edge=32, aura=False, insets=None):
    """Offline sampling of local Blizzard_SharedXML/Backdrop.lua UVs, edge=32.

    Does not emulate the client. Uses bilinear RGBA and unchanged 32px corners,
    including edge-repeat phase, half-cell orientation and the 4px UV inset.
    """
    pixels = np.asarray(atlas).astype(float)
    cell = atlas.height
    inset = cell/16
    out = Image.new("RGBA", (width, height)) if insets is not None else Image.new("RGBA", (width, height), "#101010")
    if insets is not None:
        left, top, right, bottom = insets
        ImageDraw.Draw(out).rectangle((left, top, width-right-1, height-bottom-1), fill="#333c54" if aura else "#101010")
    def sample(cell_index, x, y, w, h, horizontal=False, corner=False):
        xx, yy = np.meshgrid((np.arange(w)+.5)/w, (np.arange(h)+.5)/h)
        if corner or aura:
            u, v = inset + (cell-2*inset)*xx, inset + (cell-2*inset)*yy
            if horizontal:
                u, v = inset + (cell-2*inset)*yy, cell-inset-(cell-2*inset)*xx
        elif horizontal:
            u = inset + (cell-2*inset)*yy
            v = ((width/edge - 2 - .0625)*cell)*(1-xx) + inset*xx
        else:
            u = inset + (cell-2*inset)*xx
            v = inset*(1-yy) + ((height/edge - 2 - .0625)*cell)*yy
        u, v = cell*cell_index+u-.5, v-.5
        ix, iy = np.floor(u).astype(int), np.floor(v).astype(int)
        fx, fy = (u-ix)[..., None], (v-iy)[..., None]
        rgba = (pixels[iy % cell, ix % atlas.width]*(1-fx)*(1-fy)
                + pixels[iy % cell, (ix+1) % atlas.width]*fx*(1-fy)
                + pixels[(iy+1) % cell, ix % atlas.width]*(1-fx)*fy
                + pixels[(iy+1) % cell, (ix+1) % atlas.width]*fx*fy)
        out.alpha_composite(Image.fromarray(np.rint(rgba).clip(0, 255).astype("uint8")), (x, y))
    for cell_index, x, y in ((4, 0, 0), (5, width-edge, 0), (6, 0, height-edge), (7, width-edge, height-edge)):
        sample(cell_index, x, y, edge, edge, corner=True)
    sample(0, 0, edge, edge, height-2*edge)
    sample(1, width-edge, edge, edge, height-2*edge)
    sample(2, edge, 0, width-2*edge, edge, horizontal=True)
    sample(3, edge, height-edge, width-2*edge, edge, horizontal=True)
    return out


def review(before, after):
    REVIEW.mkdir(parents=True, exist_ok=True)
    before.save(REVIEW / "rejected-atlas.tga", compression=None)
    rows = [(270, 142), (420, 240), (180, 100)]
    board = Image.new("RGBA", (920, 620), "#292d33")
    draw = ImageDraw.Draw(board)
    draw.text((16, 12), "OFFLINE Backdrop UV sampling / before (left) - repacked (right)", fill="white")
    y = 42
    for width, height in rows:
        for column, atlas in enumerate((before, after)):
            board.alpha_composite(render(atlas, width, height), (16+column*460, y))
        y += height+35
    board.convert("RGB").save(REVIEW / "assembled-1x.png")
    board.resize((1840, 1240), Image.Resampling.NEAREST).convert("RGB").save(REVIEW / "assembled-2x.png")
    compact = Image.new("RGBA", (588, 182), "#292d33")
    labels = ImageDraw.Draw(compact)
    labels.text((12, 10), "Before / offline", fill="white")
    labels.text((306, 10), "Repacked / offline", fill="white")
    compact.alpha_composite(render(before, 270, 142), (12, 32))
    compact.alpha_composite(render(after, 270, 142), (306, 32))
    compact.convert("RGB").save(REVIEW / "comparison.png")
    report = {"construction": "DK tooltip eight-cell packing v1", "patches": PATCHES,
              "rejectedJoinFailures": joins(before), "repackedJoinFailures": joins(after),
              "liveValidated": False}
    assert report["rejectedJoinFailures"], "Original broken fixture must fail"
    assert not report["repackedJoinFailures"], report["repackedJoinFailures"]
    (REVIEW / "joins.json").write_text(json.dumps(report, indent=2)+"\n")


if __name__ == "__main__":
    source = Image.open(ROOT / "Assets_Draft/DeathKnight/FullSet/Exports/border-tooltip.tga").convert("RGBA")
    review(source, pack(source))
    print("Tooltip assembly review:", REVIEW)
