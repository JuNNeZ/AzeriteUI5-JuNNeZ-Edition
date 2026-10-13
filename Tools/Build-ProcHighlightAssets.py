"""Build shared neutral proc rings; geometry matches the native 256px canvas.

The native ring's opaque band is at radii 63-65. Keep its inner edge fixed
and grow only the stroke, never the icon aperture or button rectangle.

The square set is for the Legacy HUD (Core/LegacyHUD.lua ResolveMedia). It
follows Assets/Legacy/actionbutton-spellhighlight-square-rounded.tga, measured:
a rounded square whose band starts 63.75px from the centre with a 16px corner.
Legacy draws it at (size - 8) * 256 / 122, about 0.38 of the canvas against
Azerite's 0.52, so its strokes are wider in texels to read the same on screen.
Run with Python + Pillow. These are procedural functional layers, not theme art.
"""
from pathlib import Path
import math
from PIL import Image

root = Path(__file__).resolve().parents[1]


def rounded_box(x, y, half, corner):
    """Signed distance from a rounded square centred on the canvas, outward positive."""
    qx = abs(x - 127.5) - (half - corner)
    qy = abs(y - 127.5) - (half - corner)
    outside = math.hypot(max(qx, 0), max(qy, 0))
    return outside + min(max(qx, qy), 0) - corner


def build(path, edge, width, kind):
    image = Image.new("RGBA", (256, 256))
    pixels = image.load()
    for y in range(256):
        for x in range(256):
            q = edge(x, y)
            if kind == "outline":
                alpha = min(1, max(0, q + 0.5), max(0, width + 0.5 - q))
            else:
                alpha = math.exp(-0.5 * ((q - width / 2) / (width + 2)) ** 2)
                alpha *= min(1, max(0, (q + 8.5) / 8))
            pixels[x, y] = (255, 255, 255, round(255 * alpha))
    image.save(path)


round_edge = lambda x, y: math.hypot(x - 127.5, y - 127.5) - 62.5
square_edge = lambda x, y: rounded_box(x, y, 63.75, 16)
for name, width, square in (("thin", 2, 3), ("medium", 4, 5.5), ("thick", 6, 8)):
    for kind in ("outline", "glow"):
        build(root / "Assets" / f"actionbutton-proc-{kind}-{name}.tga", round_edge, width, kind)
        build(root / "Assets" / f"actionbutton-proc-square-{kind}-{name}.tga", square_edge, square, kind)
