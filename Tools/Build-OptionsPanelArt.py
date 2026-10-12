"""Builds the options window's Rounded style art into Assets/ from AzeriteUI's own borders.

    python Tools/Build-OptionsPanelArt.py [--preview <png>]

Nothing here is drawn from scratch. The two edge files are AzeriteUI's own backdrop
borders with their corners rounded off:

    options-casing-round.tga  512x64  border-tooltip.tga's eight cells. The four straight
                                      cells are copied byte for byte; the four corners are
                                      rebuilt round, each from its own cell's edge profiles,
                                      with a continuous bevel and round metal fastenings.
                                      Drawn untinted at edgeSize 32, exactly as the casing.
    options-well-round.tga    256x32  border-aura.tga, the same treatment without a stud.
                                      The rail well and the search box, tinted like the
                                      inset backdrop at edgeSize 10.

and two plain shapes, white on transparent, tinted in game:

    options-round6-fill.tga    64x64  radius 6, slice margin 8: rail, tab and result highlights
    options-shadow.tga        128x128 soft shadow, slice margin 40

A corner is rebuilt by distance from a rounded outer edge: along the straight runs a pixel
takes the corner cell's own edge profile, which is what keeps the joins to the straight
cells seamless, and round the arc the two profiles are blended by angle. Requires Pillow.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Assets")
SS = 4

# Backdrop edge files: left, right, top, bottom, then the corners TL, TR, BL, BR.
CORNERS = {4: (0, 0), 5: (1, 0), 6: (0, 1), 7: (1, 1)}  # cell -> (right?, bottom?)


def load(name):
    return Image.open(os.path.join(ASSETS, name + ".tga")).convert("RGBA")


def save(img, name):
    path = os.path.join(ASSETS, name + ".tga")
    img.save(path)
    return path


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


def premul(p):
    a = p[3] / 255.0
    return (p[0] * a, p[1] * a, p[2] * a, p[3])


def unpremul(p):
    if p[3] <= 0:
        return (0, 0, 0, 0)
    a = p[3] / 255.0
    return tuple(int(round(min(255, max(0, c)))) for c in (p[0] / a, p[1] / a, p[2] / a, p[3]))


def sample(profile, d):
    """The profile at a fractional depth, premultiplied, transparent outside it."""
    if d < 0:
        return (0, 0, 0, 0) if d < -1 else lerp((0, 0, 0, 0), profile[0], d + 1)
    i = int(d)
    if i >= len(profile) - 1:
        return profile[-1] if i == len(profile) - 1 else (0, 0, 0, 0)
    return lerp(profile[i], profile[i + 1], d - i)


def corner_profiles(cell, right, bottom):
    """The two straight profiles a corner cell joins: along its far column (the
    horizontal edge, read from the outer side inwards) and its far row (the vertical
    edge)."""
    c = cell.size[0]
    far_x = 0 if right else c - 1
    far_y = 0 if bottom else c - 1
    h = [premul(cell.getpixel((far_x, (c - 1 - d) if bottom else d))) for d in range(c)]
    v = [premul(cell.getpixel(((c - 1 - d) if right else d, far_y))) for d in range(c)]
    return h, v


def rim_start(profile):
    """Where a profile's solid rim begins: its first fully opaque pixel."""
    for i, p in enumerate(profile):
        if p[3] >= 255:
            return i
    return 0


def rounded_corner(cell, right, bottom, radius, sculpted=False):
    """Rebuild the corner, retaining its own edge profiles at both joins.

    The two edges a corner joins do not start at the same depth: border-tooltip's
    top and bottom run 15px further in than its sides. So the horizontal profile is
    shifted until both rims start together, the arc is drawn in that shared space,
    and each straight run still reads its own profile at its own depth, which is
    what keeps the joins to the straight cells seamless."""
    c = cell.size[0]
    h, v = corner_profiles(cell, right, bottom)
    shift = rim_start(h) - rim_start(v)
    cu, cw = radius, shift + radius
    out = Image.new("RGBA", (c, c), (0, 0, 0, 0))
    def at(u, w):
        if u < cu and w < cw:
            du, dw = cu - u, cw - w
            d = radius - math.hypot(du, dw)
            t = math.atan2(dw, du) / (math.pi / 2)
            # The casing's broad bevel turns gently into the adjacent edge.
            # A subtle light response replaces the separate diamond fittings;
            # it fades to zero at both joins and never changes the alpha.
            blend = t * t * (3 - 2 * t) if sculpted else t
            p = lerp(sample(v, d - .5), sample(h, d + shift - .5), blend)
            if sculpted:
                light = .08 - .07 * (right + bottom)
                gain = 1 + light * math.sin(math.pi * t)
                p = (p[0] * gain, p[1] * gain, p[2] * gain, p[3])
            return p
        if u < w - shift:
            return sample(v, u - .5)
        return sample(h, w - .5)

    px = out.load()
    for y in range(c):
        for x in range(c):
            u = ((c - 1 - x) if right else x) + .5
            w = ((c - 1 - y) if bottom else y) + .5
            if sculpted and u - .5 < cu and w - .5 < cw:
                # Integrate curved pixels in premultiplied space. Leave the
                # straight runs untouched so their source profiles still join.
                samples = [at(u + (sx + .5) / SS - .5,
                              w + (sy + .5) / SS - .5)
                           for sy in range(SS) for sx in range(SS)]
                p = tuple(sum(q[i] for q in samples) / (SS * SS) for i in range(4))
            else:
                p = at(u, w)
            px[x, y] = unpremul(p)
    return out


def round_fastening(img, source, right, bottom, radius):
    """Low round rivet on the bevel, in the original tooltip fitting's metal.

    The dark washer and shallow faceted cap preserve the original sculpted
    corner character. Lighting stays top-left for all four screen corners.
    """
    c = img.size[0]
    h, v = corner_profiles(source, right, bottom)
    shift = rim_start(h) - rim_start(v)
    diagonal = (radius - 14) / math.sqrt(2)
    u, w = radius - diagonal, shift + radius - diagonal
    cx = c - u if right else u
    cy = c - w if bottom else w
    big = Image.new("RGBA", (c * SS, c * SS))
    d = ImageDraw.Draw(big)
    x, y = cx * SS, cy * SS
    def circle(r, color, dy=0):
        rr = r * SS
        d.ellipse((round(x-rr), round(y+dy*SS-rr),
                   round(x+rr), round(y+dy*SS+rr)), fill=color)
    circle(8.2, (0, 0, 0, 115), .8)
    circle(7.8, (8, 8, 7, 255))
    # A bevelled washer, with the cap seated inside its dark inner lip.
    circle(6.8, (68, 63, 55, 255))
    d.arc((round(x-6.8*SS), round(y-6.8*SS), round(x+6.8*SS), round(y+6.8*SS)),
          190, 285, fill=(153, 143, 125, 255), width=SS)
    circle(5.6, (12, 12, 10, 255))
    # Broad planes rather than a glossy sphere or a flat UI dot.
    cap = Image.new("RGBA", big.size)
    cd = ImageDraw.Draw(cap)
    r = 4.8 * SS
    points = [(x + r * math.cos(math.radians(-112.5 + i*45)),
               y + r * math.sin(math.radians(-112.5 + i*45))) for i in range(8)]
    palette = [(149, 139, 121, 255), (105, 97, 84, 255),
               (63, 58, 50, 255), (32, 30, 26, 255),
               (38, 35, 30, 255), (71, 65, 56, 255),
               (121, 112, 97, 255), (174, 163, 142, 255)]
    for i in range(8):
        cd.polygon([points[i], points[(i+1)%8], (x-.7*SS, y-.7*SS)], fill=palette[i])
    big.alpha_composite(cap)
    img.alpha_composite(big.resize((c, c), Image.LANCZOS))


def build_edge(source, cells, radius, sculpted=False):
    src = load(source)
    c = src.size[1]
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for i in range(cells):
        cell = src.crop((i * c, 0, (i + 1) * c, c))
        if i in CORNERS:
            right, bottom = CORNERS[i]
            original = cell
            cell = rounded_corner(cell, right, bottom, radius, sculpted)
            if sculpted:
                round_fastening(cell, original, right, bottom, radius)
        out.paste(cell, (i * c, 0))
    return out


def plain(size, radius):
    m = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius=radius * SS, fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    img.putalpha(m)
    return img


def shadow():
    m = Image.new("L", (128 * SS, 128 * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([28 * SS, 30 * SS, 100 * SS, 102 * SS], radius=12 * SS, fill=170)
    m = m.filter(ImageFilter.GaussianBlur(10 * SS)).resize((128, 128), Image.LANCZOS)
    img = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
    img.putalpha(m)
    return img


# Radii are in source pixels of each edge file. The casing is drawn at edgeSize 32 from
# 64px cells, so 40 puts the tooltip's rim on a curve of about 16px on screen, and the
# rim's inner edge lands well inside the window's own corner, so the window's square
# fill (Kit.WindowFill, unchanged) never shows past it.
# Keep this radius: it tucks the unchanged square fill under the inner bevel.
#
# border-aura's rim starts 15px in and is 9px deep, so a radius of 30 leaves a 15px
# (about 5px on screen at edgeSize 10) outer curve. Its fill has to start 7px in
# (Look.InsetBackdrop's insets) or the square fill's corner shows past the curve.
CASING_RADIUS = 40
WELL_RADIUS = 30


def build():
    written = [
        save(build_edge("border-tooltip", 8, CASING_RADIUS, sculpted=True), "options-casing-round"),
        save(build_edge("border-aura", 8, WELL_RADIUS), "options-well-round"),
        save(plain(64, 6), "options-round6-fill"),
        save(shadow(), "options-shadow"),
    ]
    for path in written:
        print("wrote", os.path.relpath(path, ROOT))


# ---------------------------------------------------------------------------
# Preview: the casing and the well drawn the way a Backdrop draws them, so a
# corner can be judged at its real size before anything reaches the game.
# ---------------------------------------------------------------------------
def backdrop(canvas, box, edge_file, edge_size, tint=(255, 255, 255)):
    src = load(edge_file)
    c = src.size[1]
    cell = [src.crop((i * c, 0, (i + 1) * c, c)).resize((edge_size, edge_size), Image.LANCZOS) for i in range(8)]
    if tint != (255, 255, 255):
        for i, im in enumerate(cell):
            r, g, b, a = im.split()
            r = r.point(lambda v: v * tint[0] // 255)
            g = g.point(lambda v: v * tint[1] // 255)
            b = b.point(lambda v: v * tint[2] // 255)
            cell[i] = Image.merge("RGBA", (r, g, b, a))
    x0, y0, x1, y1 = box
    e = edge_size
    w, h = x1 - x0, y1 - y0
    left = cell[0].resize((e, max(1, h - 2 * e)))
    right = cell[1].resize((e, max(1, h - 2 * e)))
    top = cell[2].rotate(-90, expand=True).resize((max(1, w - 2 * e), e))
    bottom = cell[3].rotate(-90, expand=True).resize((max(1, w - 2 * e), e))
    for im, pos in ((left, (x0, y0 + e)), (right, (x1 - e, y0 + e)), (top, (x0 + e, y0)), (bottom, (x0 + e, y1 - e)),
                    (cell[4], (x0, y0)), (cell[5], (x1 - e, y0)), (cell[6], (x0, y1 - e)), (cell[7], (x1 - e, y1 - e))):
        canvas.alpha_composite(im, pos)


def preview(path):
    W, H = 760, 420
    img = Image.new("RGBA", (W, H), (58, 52, 44, 255))
    win = (60, 50, 700, 370)
    sh = shadow().resize((win[2] - win[0] + 44, win[3] - win[1] + 44))
    sh = Image.merge("RGBA", (*[Image.new("L", sh.size, 0)] * 3, sh.split()[3].point(lambda v: v * 8 // 10)))
    img.alpha_composite(sh, (win[0] - 22, win[1] - 22))
    ImageDraw.Draw(img).rectangle([win[0] - 2, win[1] - 2, win[2] + 2, win[3] + 2], fill=(8, 8, 8, 255))
    rail = (win[0] + 8, win[1] + 90, win[0] + 204, win[3] - 64)
    ImageDraw.Draw(img).rectangle([rail[0] + 7, rail[1] + 7, rail[2] - 7, rail[3] - 7], fill=(5, 5, 5, 255))
    backdrop(img, rail, "options-well-round", 10, (89, 89, 89))
    backdrop(img, (win[0] - 10, win[1] - 18, win[2] + 10, win[3] + 18), "options-casing-round", 32)
    img.save(path)
    print("preview", path)


if __name__ == "__main__":
    build()
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
