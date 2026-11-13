"""Render the registered Details preset offline; no game/client interaction.

First export settings with details_skin_harness.lua <Details skins.lua> <settings.json>.
All painting/mask pixels are reopened from the exported runtime TGAs. Text uses a
local serif substitute because the game's FontFamily renderer is unavailable.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Assets_Draft/Details/Export"
MANIFEST = json.loads((ART / "manifest.json").read_text())


def art(name, uv_name=None):
    image = Image.open(ART / (name + ".tga")).convert("RGBA")
    l, r, t, b = MANIFEST["paintings"][uv_name or name]["uv"]
    return image.crop((round(l*image.width), round(t*image.height), round(r*image.width), round(b*image.height)))


def tint(image, color):
    channels = image.convert("RGBA").split()
    return Image.merge("RGBA", tuple(
        channel.point(lambda value, factor=factor: round(value * factor))
        for channel, factor in zip(channels, color)
    ))


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/georgia.ttf", size)


def panel(settings, hovered=False, count=5):
    p, style = settings["props"], settings["style"]
    row = p["row_info"]
    width = 304
    title_height = p["titlebar_height"]
    stride = row["height"] + row["space"]["between"]
    height = title_height + 8 + count * stride + 5
    offset = 8
    image = Image.new("RGBA", (width + offset * 2, height + offset * 2))
    draw = ImageDraw.Draw(image)
    body_color = tuple(round(p[k] * 255) for k in ("bg_r", "bg_g", "bg_b", "bg_alpha"))
    draw.rectangle((offset, offset + title_height, offset + width, offset + height), fill=body_color)
    draw.rectangle((offset, offset, offset + width, offset + title_height),
                   fill=tuple(round(v * 255) for v in p["titlebar_texture_color"]))
    image.alpha_composite(art("header").resize((width, title_height), Image.Resampling.LANCZOS), (offset, offset))

    def text(at, value, color, anchor=None):
        draw.text((at[0] + 1, at[1] + 1), value, font=font(row["font_size"]),
                  fill=(0, 0, 0, 230), anchor=anchor)
        draw.text(at, value, font=font(row["font_size"]), fill=color, anchor=anchor)

    title_color = tuple(round(v * 255) for v in p["attribute_text"]["text_color"])
    text((offset + 16, offset + 10), "Damage Done", title_color)
    alpha = style["hoverIcons"] if hovered else style["idleIcons"]
    # Toolbar glyphs are schematic; live Details supplies its own six icons.
    for i in range(6):
        x = offset + width - 77 + i * 12
        draw.ellipse((x, offset + 14, x + 4, offset + 18), fill=(196, 196, 196, round(alpha * 255)))

    samples = [
        ("JuNNeZ", "124.6K", 1, (.999, .49, .04)),
        ("Aelora", "118.2K", .948, (.25, .78, .92)),
        ("Tharok", "109.4K", .878, (.78, .61, .43)),
        ("Nymera", "96.1K", .771, (.67, .83, .45)),
        ("Veyrin", "82.7K", .664, (.58, .51, .79)),
    ]
    material = art("fill")
    casing = art("casing")
    aperture = art("row-mask", "casing").getchannel("A")
    text_color = tuple(round(v * 255) for v in row["fixed_text_color"])
    for i, (name, value, proportion, color) in enumerate(samples[:count]):
        x, y = offset + 2, offset + title_height + 3 + i * stride
        row_width = width - 4
        shape = aperture.resize((row_width, row["height"]), Image.Resampling.LANCZOS)
        backing = tint(material.resize((row_width, row["height"])), row["fixed_texture_background_color"])
        backing.putalpha(ImageChops.multiply(backing.getchannel("A"), shape))
        image.alpha_composite(backing, (x, y))
        # Native statusbar progress clips at its percentage; it does not inspect
        # source colors or compute a custom combat-driven geometry.
        bar = tint(material.resize((row_width, row["height"])), (*color, row["alpha"]))
        progress = Image.new("L", bar.size)
        ImageDraw.Draw(progress).rectangle((0, 0, round(row_width * proportion)-1, row["height"]), fill=255)
        bar.putalpha(ImageChops.multiply(ImageChops.multiply(bar.getchannel("A"), shape), progress))
        image.alpha_composite(bar, (x, y))
        image.alpha_composite(casing.resize((row_width, row["height"]), Image.Resampling.LANCZOS), (x, y))
        text((x + 9, y + 4), name, text_color)
        text((x + row_width - 9, y + 4), value, text_color, anchor="ra")
    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--settings", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    settings = json.loads(args.settings.read_text())
    idle, hover = panel(settings, count=1), panel(settings, True)
    canvas = Image.new("RGBA", (1050, 580), (23, 26, 29, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((32, 26), "AzeriteUI Forged / Details", font=font(24), fill=(220, 220, 220))
    draw.text((32, 65), "Exported artwork · one player and five players", font=font(13), fill=(145, 149, 151))
    draw.text((32, 124), "1x / one player, idle", font=font(12), fill=(170, 170, 170))
    canvas.alpha_composite(idle, (25, 159))
    draw.text((384, 124), "2x / hover", font=font(12), fill=(170, 170, 170))
    canvas.alpha_composite(hover.resize((hover.width * 2, hover.height * 2), Image.Resampling.NEAREST), (376, 144))
    draw.text((32, 545), "Runtime textures · sample data and substitute font · live fit awaits in-game review", font=font(12), fill=(129, 134, 138))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(args.out)
    print(args.out)


if __name__ == "__main__":
    main()
