"""Export the generated guild painting and small UI glyphs. No source edits.

python Tools/Build-GuildArt.py
The source painting and generation prompt live in Assets_Draft/Guild/.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets_Draft/Guild/banner-source.png"
OUT = ROOT / "Assets/Guild"
OUT.mkdir(parents=True, exist_ok=True)
art = Image.open(SOURCE).convert("RGBA")
w, h = art.size
# Export a calm slate field, keeping the shield at its natural aspect ratio.
header = art.crop((int(w*.20), int(h*.12), int(w*.90), int(h*.85))).resize((1024, 128), Image.Resampling.LANCZOS)
crest = art.crop((0, int(h*.22), int(w*.17), int(h*.66)))
crest.thumbnail((116, 116), Image.Resampling.LANCZOS)
header.alpha_composite(crest, (8, (128-crest.height)//2))
# Native bronze rules finish the edge without stretching the painted corners.
d = ImageDraw.Draw(header)
d.line((0, 0, 1023, 0), fill=(123, 94, 49, 255))
d.line((0, 127, 1023, 127), fill=(83, 65, 37, 255))
header.save(OUT / "header.tga")
header.save(ROOT / "Assets_Draft/Guild/header-preview.png")

status = Image.new("RGBA", (64, 32))
for index, color in enumerate(((80, 222, 155), (112, 112, 116))):
    glow = Image.new("RGBA", (32, 32)); g = ImageDraw.Draw(glow)
    g.ellipse((7, 7, 25, 25), fill=(*color, 120 if index == 0 else 30))
    glow = glow.filter(ImageFilter.GaussianBlur(4))
    g = ImageDraw.Draw(glow); g.ellipse((12, 12, 20, 20), fill=(*color, 255))
    g.ellipse((13, 12, 17, 15), fill=(210, 255, 233, 220 if index == 0 else 70))
    status.alpha_composite(glow, (index*32, 0))
status.save(OUT / "status.tga")
star = Image.new("RGBA", (32, 32)); d = ImageDraw.Draw(star)
points = []
for i in range(10):
    a = -math.pi/2+i*math.pi/5; r = 13 if i%2 == 0 else 5.8
    points.append((16+math.cos(a)*r, 16+math.sin(a)*r))
d.polygon(points, fill=(220, 176, 77, 255), outline=(255, 226, 139, 255))
star.save(OUT / "favorite.tga")

# Existing AzeriteUI RaidTools painting, not a newly invented casing. Runtime
# three-slicing leaves each 32-source-pixel end at its natural 34/64 scale.
button = Image.open(ROOT / "Assets/RaidTools/button.tga").convert("RGBA")
assert button.size == (256, 64)
atlas = Image.new("RGBA", (256, 512))
states = []
for index, (brightness, warmth) in enumerate(((1.0, False), (1.4, False), (1.25, True), (.68, True), (.5, False), (1.65, True))):
    rgb = button.convert("RGB")
    if index == 4:
        rgb = ImageOps.grayscale(rgb).convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    if warmth:
        r, g, b = rgb.split()
        rgb = Image.merge("RGB", (r.point(lambda v:min(255, int(v*1.12))), g, b.point(lambda v:int(v*.66))))
    state = rgb.convert("RGBA"); state.putalpha(button.getchannel("A"))
    atlas.paste(state, (0, index*64)); states.append(state)
atlas.save(OUT / "button-states.tga")
well = art.crop((int(w*.3), int(h*.25), int(w*.3)+128, int(h*.25)+128))
well = ImageEnhance.Brightness(well).enhance(.6)
well.save(OUT / "input-well.tga")

def three_slice(source, width, height=34):
    result = Image.new("RGBA", (width, height))
    cap = round(32*height/64)
    for box, x, target_width in [((0,0,32,64),0,cap), ((32,0,224,64),cap,width-2*cap), ((224,0,256,64),width-cap,cap)]:
        result.alpha_composite(source.crop(box).resize((target_width,height),Image.Resampling.LANCZOS),(x,0))
    return result

proof = Image.new("RGBA", (900, len(states)*70), (21,23,28,255)); d = ImageDraw.Draw(proof)
for index, state in enumerate(states):
    d.text((10,index*70+8),["Normal","Hover","Selected","Pressed","Disabled","Selected hover"][index],fill=(225,220,205,255))
    proof.alpha_composite(three_slice(state,180),(100,index*70+5))
    proof.alpha_composite(three_slice(state,590),(300,index*70+5))
proof.save(ROOT / "Assets_Draft/Guild/button-states-preview.png")
print("Guild art: header, status, favorite; native button state atlas 256x512; slate well 128x128")
