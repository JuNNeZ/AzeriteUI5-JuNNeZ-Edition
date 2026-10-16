"""Placeholder art for the party frame indicators (FixLog 2026-10-16).

TEMPORARY. These are stand-ins so the new indicators work in game while final art is
made; the brief for the final set is Docs/Party Indicator Icons Brief.md. The final art
may replace these files in place (same names, sizes and colour rules) with no code change.

Style follows Assets/grouprole-icons-*.tga: a flat glyph about half the 64x64 canvas
with a soft glow of its own colour on a transparent background. The threat glow is
traced from Assets/party_portrait_border.tga, so it fits that ring exactly.

    python Tools/Build-PartyIndicatorPlaceholders.py
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Assets"
SIZE = 64
SS = 4  # supersampling for smooth edges


def glyph_canvas():
    return Image.new("L", (SIZE * SS, SIZE * SS), 0)


def finish(mask, color, glow=0.85):
    """A coloured glyph with a soft glow of the same colour, like the role icons."""
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    halo = mask.filter(ImageFilter.GaussianBlur(4)).point(lambda v: int(min(255, v * 1.6 * glow)))
    alpha = ImageChops.lighter(mask, halo)
    r, g, b = color
    # The glyph itself is a touch brighter than its glow.
    core = mask.point(lambda v: v / 255)
    out = Image.new("RGBA", (SIZE, SIZE))
    px, cp, ap = out.load(), core.load(), alpha.load()
    for y in range(SIZE):
        for x in range(SIZE):
            k = cp[x, y]
            px[x, y] = (
                int(r + (255 - r) * .35 * k),
                int(g + (255 - g) * .35 * k),
                int(b + (255 - b) * .35 * k),
                ap[x, y],
            )
    return out


def S(v):
    return v * SS


def crown():
    m = glyph_canvas()
    d = ImageDraw.Draw(m)
    d.polygon([(S(14), S(44)), (S(12), S(22)), (S(23), S(32)), (S(32), S(16)),
               (S(41), S(32)), (S(52), S(22)), (S(50), S(44))], fill=255)
    d.rectangle([S(14), S(46), S(50), S(51)], fill=255)
    for cx, cy in ((12, 20), (32, 13), (52, 20)):
        d.ellipse([S(cx - 3), S(cy - 3), S(cx + 3), S(cy + 3)], fill=255)
    return m


def star():
    m = glyph_canvas()
    d = ImageDraw.Draw(m)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rad = 20 if i % 2 == 0 else 8.5
        pts.append((S(32 + rad * math.cos(a)), S(33 + rad * math.sin(a))))
    d.polygon(pts, fill=255)
    return m


def portal():
    """A swirl: a ring with three inward hooks, read as 'arriving'."""
    m = glyph_canvas()
    d = ImageDraw.Draw(m)
    d.ellipse([S(12), S(12), S(52), S(52)], outline=255, width=S(5))
    for k in range(3):
        start = k * 120
        d.arc([S(19), S(19), S(45), S(45)], start, start + 80, fill=255, width=S(4))
    d.ellipse([S(28), S(28), S(36), S(36)], fill=255)
    return m


def phase():
    """Two offset rings: 'not in the same place'."""
    m = glyph_canvas()
    d = ImageDraw.Draw(m)
    d.ellipse([S(10), S(16), S(40), S(46)], outline=255, width=S(5))
    d.ellipse([S(24), S(16), S(54), S(46)], outline=255, width=S(5))
    return m


def threat_glow():
    """White glow hugging Assets/party_portrait_border.tga, tinted by threat at runtime."""
    border = Image.open(ASSETS / "party_portrait_border.tga").convert("RGBA")
    a = border.getchannel("A")
    ring = a.point(lambda v: 255 if v > 40 else 0)
    glow = ring.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(7))
    peak = max(glow.getextrema()[1], 1)
    glow = glow.point(lambda v: int(min(255, v * 255 / peak)))
    # The glow layer sits above the portrait model in game, so nothing may fall
    # inside the ring: cut away the hole (flood-filled from the centre), grown a
    # little so the inner stone edge stays clean.
    hole = ring.copy()
    w, h = hole.size
    ImageDraw.floodfill(hole, (w // 2, h // 2), 128)
    hole = hole.point(lambda v: 255 if v == 128 else 0).filter(ImageFilter.MaxFilter(13))
    glow = ImageChops.subtract(glow, hole)
    out = Image.new("RGBA", border.size, (255, 255, 255, 0))
    out.putalpha(glow)
    return out


def save(img, name):
    path = ASSETS / name
    img.save(path)  # uncompressed 32-bit TGA
    print("wrote", path.relative_to(ROOT), img.size)


def main():
    save(finish(crown(), (255, 200, 40)), "party-indicator-leader.tga")
    save(finish(star(), (200, 215, 235)), "party-indicator-assistant.tga")
    save(finish(portal(), (255, 255, 255)), "party-indicator-summon.tga")  # tinted per status
    save(finish(phase(), (110, 190, 255)), "party-indicator-phase.tga")
    save(threat_glow(), "party_portrait_threat.tga")


if __name__ == "__main__":
    raise SystemExit("RETIRED: final art is installed. Use Tools/Build-PartyIndicatorArt.py instead.")
