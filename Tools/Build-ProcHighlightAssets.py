"""Build shared neutral proc rings; geometry matches the native 256px canvas.

The native ring's opaque band is at radii 63-65. Keep its inner edge fixed
and grow only the stroke, never the icon aperture or button rectangle.
Run with Python + Pillow. These are procedural functional layers, not theme art.
"""
from pathlib import Path
import math
from PIL import Image

root = Path(__file__).resolve().parents[1]
for name, width in (("thin", 2), ("medium", 4), ("thick", 6)):
    for kind in ("outline", "glow"):
        image = Image.new("RGBA", (256, 256))
        pixels = image.load()
        for y in range(256):
            for x in range(256):
                radius = math.hypot(x - 127.5, y - 127.5)
                if kind == "outline":
                    alpha = min(1, max(0, radius - 62), max(0, 63 + width - radius))
                else:
                    alpha = math.exp(-0.5 * ((radius - (62.5 + width / 2)) / (width + 2)) ** 2)
                    alpha *= min(1, max(0, (radius - 54) / 8))
                pixels[x, y] = (255, 255, 255, round(255 * alpha))
        image.save(root / "Assets" / f"actionbutton-proc-{kind}-{name}.tga")
