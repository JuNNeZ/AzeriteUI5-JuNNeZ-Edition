"""Builds the Discord release image for 5.53.0-JuNNeZ (Enemy Casts and castbar sparks).

The Enemy Casts rows are drawn from the shipped textures with the geometry, layer order and
colours of Components/Misc/EnemyCasts.lua (CreateRow), so the picture matches the addon:
cast_back / cast_back_spiked casing, cast_bar fill in Colors.cast at .69 (cropped like a
StatusBar), the grey fill when uninterruptible, cast_back_outline for your target,
nameplate_glow for a cast aimed at you, the aura border and Blizzard's spark (additive).

Game textures (spell icons, raid markers, the spark) are not in the repo; export them first
(the wow MCP `wow_texture_export`) into one folder keeping the game's paths, then run:

    python -I Tools/Build-ReleaseCastsImage.py <addon root> <exported textures dir> <out.png>

Not shipped; `.pkgmeta` ignores Tools/.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT, GAME, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
FONT = "C:/Windows/Fonts/FrizQuadrataTT.ttf"

# Colours (Core/Common/Colors.lua, Layouts/Data/NamePlates.lua).
CAST = (70, 255, 131)
GRAY = (128, 128, 128)
UI = (192, 192, 192)
HIGHLIGHT = (250, 250, 250)
OFFWHITE = (196, 196, 196)
TITLE = (255, 234, 137)
NORMAL = (229, 178, 38)
VERYDARKGRAY = (69, 59, 49)
TARGET_OUTLINE = (255, 239, 169)
AIMED_GLOW = (255, 64, 64)
CLASS = {"WARRIOR": (199, 156, 110), "PRIEST": (255, 255, 255), "MAGE": (64, 199, 235)}

# Row geometry (EnemyCasts.lua).
ROW_HEIGHT, ROW_SPACING, ICON, BAR_H = 54, 6, 28, 12
CASING_SIDE = 16
BAR_LEFT = 6 + ICON + 8 + CASING_SIDE
BAR_TOP = 16
BAR_RIGHT_INSET = CASING_SIDE + 2


def asset(name):
    return Image.open(os.path.join(ROOT, "Assets", name + ".tga")).convert("RGBA")


def game(path):
    return Image.open(os.path.join(GAME, *path.split("/"))).convert("RGBA")


def tint(im, rgb, alpha=1.0):
    solid = Image.new("RGBA", im.size, rgb + (255,))
    out = ImageChops.multiply(im, solid)
    out.putalpha(im.split()[3].point(lambda v: int(v * alpha)))
    return out


def font(size):
    return ImageFont.truetype(FONT, int(round(size)))


class Canvas:
    """Draws in frame units at a scale, at an origin."""

    def __init__(self, image, scale, ox, oy):
        self.image, self.s, self.ox, self.oy = image, scale, ox, oy

    def px(self, x, y):
        return int(round(self.ox + x * self.s)), int(round(self.oy + y * self.s))

    def paste(self, im, x, y, w, h):
        w2, h2 = max(1, int(round(w * self.s))), max(1, int(round(h * self.s)))
        self.image.alpha_composite(im.resize((w2, h2), Image.LANCZOS), self.px(x, y))

    def paste_centered(self, im, cx, cy, w, h):
        self.paste(im, cx - w / 2, cy - h / 2, w, h)

    def add(self, im, x, y, w, h):
        # Additive blend, as the spark's ADD blend mode.
        w2, h2 = max(1, int(round(w * self.s))), max(1, int(round(h * self.s)))
        im = im.resize((w2, h2), Image.LANCZOS)
        px, py = self.px(x, y)
        region = self.image.crop((px, py, px + w2, py + h2))
        a = im.split()[3]
        rgb = Image.merge("RGB", im.split()[:3])
        rgb = ImageChops.multiply(rgb, Image.merge("RGB", (a, a, a)))
        base = Image.merge("RGB", region.split()[:3])
        out = ImageChops.add(base, rgb)
        out.putalpha(region.split()[3])
        self.image.paste(out, (px, py))

    def text(self, x, y, value, size, color, anchor="lm"):
        draw = ImageDraw.Draw(self.image)
        draw.text(self.px(x, y), value, font=font(size * self.s), fill=color + (255,), anchor=anchor,
                  stroke_width=max(1, int(round(self.s))), stroke_fill=(0, 0, 0, 255))


def aura_border(canvas, x, y, w, h):
    """border-aura cut into its 8 segments (AuraStyling.lua CreateAuraTextureBorder), 12px edge."""
    sheet = tint(asset("border-aura"), VERYDARKGRAY)
    inset, edge = 2, 12

    def seg(i):
        return sheet.crop((i * 32 + inset, inset, (i + 1) * 32 - inset, 32 - inset))

    canvas.paste(seg(4), x, y, edge, edge)
    canvas.paste(seg(5), x + w - edge, y, edge, edge)
    canvas.paste(seg(6), x, y + h - edge, edge, edge)
    canvas.paste(seg(7), x + w - edge, y + h - edge, edge, edge)
    canvas.paste(seg(0), x, y + edge, edge, h - 2 * edge)
    canvas.paste(seg(1), x + w - edge, y + edge, edge, h - 2 * edge)
    # The rotated texcoords AuraStyling uses for top and bottom are a 270 degree turn here
    # (both turns rendered and compared; 90 degrees leaves the edges sticking out).
    canvas.paste(seg(2).transpose(Image.ROTATE_270), x + edge, y, w - 2 * edge, edge)
    canvas.paste(seg(3).transpose(Image.ROTATE_270), x + edge, y + h - edge, w - 2 * edge, edge)


def draw_row(canvas, oy, width, row):
    bar_w = width - BAR_LEFT - BAR_RIGHT_INSET
    casing_w = (bar_w + 31.5) * 256 / 189
    cx = BAR_LEFT + bar_w / 2 + 1
    cy = oy + BAR_TOP + BAR_H / 2 - 1

    if row.get("aimed"):
        canvas.paste_centered(tint(asset("nameplate_glow"), AIMED_GLOW), cx, cy, casing_w * 189 / 256 + 28, 58)
    casing = "cast_back_spiked" if row.get("locked") else "cast_back"
    canvas.paste_centered(tint(asset(casing), UI), cx, cy, casing_w, 93)

    # StatusBar fill: the texture is cropped to the value, not stretched.
    value = row["value"]
    fill = asset("cast_bar")
    fill = fill.crop((0, 0, max(1, int(fill.size[0] * value)), fill.size[1]))
    canvas.paste(tint(fill, CAST, .69), BAR_LEFT, oy + BAR_TOP, bar_w * value, BAR_H)
    if row.get("locked"):
        canvas.paste(tint(fill, GRAY, .9), BAR_LEFT, oy + BAR_TOP, bar_w * value, BAR_H)
    spark = game("interface/castingbar/ui-castingbar-spark.png")
    canvas.add(tint(spark, (255, 242, 204), .85), BAR_LEFT + bar_w * value - 6, oy + BAR_TOP + 1, 12, BAR_H - 2 + 8)

    if row.get("target"):
        canvas.paste_centered(tint(asset("cast_back_outline"), TARGET_OUTLINE), cx, cy, casing_w, 93)

    # Icon with the aura border.
    icon = game(row["icon"])
    s = icon.size[0]
    icon = icon.crop((int(s * .08), int(s * .08), int(s * .92), int(s * .92)))
    iy = oy + BAR_TOP + BAR_H / 2 - ICON / 2
    canvas.paste(icon, 6, iy, ICON, ICON)
    aura_border(canvas, 0, iy - 6, ICON + 12, ICON + 12)

    canvas.text(BAR_LEFT + 3, oy + BAR_TOP + BAR_H / 2, row["spell"], 12, HIGHLIGHT)
    canvas.text(BAR_LEFT + bar_w - 3, oy + BAR_TOP + BAR_H / 2, row["time"], 12, OFFWHITE, "rm")

    line = oy + BAR_TOP + BAR_H + 19
    if row.get("marker"):
        sheet = game("interface/targetingframe/ui-raidtargetingicons.png")
        i = row["marker"] - 1
        cell = sheet.crop(((i % 4) * 64, (i // 4) * 64, (i % 4 + 1) * 64, (i // 4 + 1) * 64))
        canvas.paste(cell, BAR_LEFT, line - 6, 12, 12)
    canvas.text(BAR_LEFT + 15, line, row["caster"], 11, OFFWHITE)
    if row.get("spell_target"):
        canvas.text(BAR_LEFT + bar_w / 2, line, "\u00bb", 11, OFFWHITE, "mm")
        canvas.text(BAR_LEFT + bar_w / 2 + 7, line, row["spell_target"], 11, row["target_color"])


def gradient(size, top, bottom):
    w, h = size
    im = Image.new("RGBA", size)
    draw = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        draw.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def main():
    W, H = 1280, 720
    image = gradient((W, H), (24, 28, 36), (10, 11, 15))

    # A soft light behind the list.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((640, 90, 1260, 690), fill=(68, 136, 187, 70))
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))

    draw = ImageDraw.Draw(image)
    title = font(66)
    x = 64
    for part, color in (("Azerite", (68, 136, 187)), ("UI", (250, 250, 250)), (" 5.53", (204, 204, 204))):
        draw.text((x, 70), part, font=title, fill=color + (255,), stroke_width=2, stroke_fill=(0, 0, 0, 255))
        x += draw.textlength(part, font=title)
    draw.text((66, 150), "JuNNeZ Edition", font=font(30), fill=(80, 220, 90, 255), stroke_width=1, stroke_fill=(0, 0, 0, 255))
    draw.text((64, 218), "Enemy Casts and Castbar Sparks", font=font(36), fill=TITLE + (255,),
              stroke_width=2, stroke_fill=(0, 0, 0, 255))

    bullets = [
        "Every enemy cast in one movable list",
        "Raid markers and who each spell is aimed at",
        "Your target's cast outlined in gold",
        "Click a cast to target its caster (out of combat)",
        "A spark on every castbar, for every spell",
        "Your own cast overlay color and opacity",
        "Previews in /lock and in the options",
    ]
    y = 300
    for line in bullets:
        draw.polygon([(70, y + 13), (78, y + 5), (86, y + 13), (78, y + 21)], fill=NORMAL + (255,))
        draw.text((100, y), line, font=font(24), fill=OFFWHITE + (255,), stroke_width=1, stroke_fill=(0, 0, 0, 255))
        y += 44

    # Friz Quadrata has no arrow glyph.
    draw.text((64, H - 52), "Find it under  /az  >  Enemy Casts", font=font(22), fill=TITLE + (255,), stroke_width=1, stroke_fill=(0, 0, 0, 255))

    rows = [
        {"icon": "interface/icons/spell_shadow_shadowbolt.png", "spell": "Shadow Bolt", "time": "1.6", "value": .38,
         "marker": 8, "caster": "Cultist", "spell_target": "Tank", "target_color": CLASS["WARRIOR"], "target": True},
        {"icon": "interface/icons/spell_frost_frostbolt02.png", "spell": "Frostbolt", "time": "0.9", "value": .64,
         "marker": 7, "caster": "Ice Warden", "spell_target": "Healer", "target_color": CLASS["PRIEST"], "locked": True},
        {"icon": "interface/icons/spell_holy_flashheal.png", "spell": "Flash Heal", "time": "1.2", "value": .22,
         "marker": 1, "caster": "Acolyte"},
        {"icon": "interface/icons/spell_fire_flamebolt.png", "spell": "Fireball", "time": "2.1", "value": .52,
         "marker": 2, "caster": "Fire Imp", "spell_target": "You", "target_color": CLASS["MAGE"], "aimed": True},
    ]
    scale, width = 2, 260
    canvas = Canvas(image, scale, 732, 150)
    for index, row in enumerate(rows):
        draw_row(canvas, index * (ROW_HEIGHT + ROW_SPACING), width, row)

    image.convert("RGB").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
