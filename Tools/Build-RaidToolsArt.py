"""Export the generated raid toolbar painting and native toggle to WoW textures.

python Tools/Build-RaidToolsArt.py
Source: Assets_Draft/RaidTools/panel-source.png (built-in imagegen, 2026-10-25).
Pillow only crops/exports the painting; glyphs are deterministic UI primitives.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DRAFT = ROOT / "Assets_Draft/RaidTools"
OUT = ROOT / "Assets/RaidTools"
PREVIEW = ROOT / "Docs/Research_Assets/RaidTools"
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)

source = Image.open(DRAFT / "panel-source.png").convert("RGBA")
# Bounding measurement ignores near-invisible generator noise, not painted metal.
# Crop includes a 12px margin, and preserves every source alpha inside that crop.
box = source.getchannel("A").point(lambda a: 255 if a >= 8 else 0).getbbox()
box = (max(0, box[0]-12), max(0, box[1]-12), min(source.width, box[2]+12), min(source.height, box[3]+12))
panel = source.crop(box).resize((1024, 256), Image.Resampling.LANCZOS)
panel.save(OUT / "panel.tga")
toggle = Image.open(ROOT / "Assets_Moot/raidtoolsbutton.tga").convert("RGBA")
toggle.save(OUT / "toggle.tga")

clear = Image.new("RGBA", (128, 128))
draw = ImageDraw.Draw(clear)
draw.ellipse((24, 24, 104, 104), outline=(220, 197, 137, 255), width=9)
draw.line((36, 36, 92, 92), fill=(220, 197, 137, 255), width=10)
clear = clear.resize((32, 32), Image.Resampling.LANCZOS)
clear.save(OUT / "clear.tga")

highlight = Image.new("RGBA", (128, 128))
draw = ImageDraw.Draw(highlight)
draw.rounded_rectangle((17, 12, 111, 116), radius=16, fill=(210, 179, 93, 60), outline=(255, 215, 126, 150), width=6)
highlight = highlight.filter(ImageFilter.GaussianBlur(3)).resize((32, 32), Image.Resampling.LANCZOS)
highlight.save(OUT / "highlight.tga")

# Offline assembly uses the same dimensions, offsets and atlas cells as RaidTools.lua.
icons = Image.open(ROOT / "Assets/raid_target_icons_small.tga").convert("RGBA")
assembly = Image.new("RGBA", (340, 56))
assembly.alpha_composite(panel.resize((324, 56), Image.Resampling.LANCZOS), (16, 0))
assembly.alpha_composite(toggle.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((22, 44), Image.Resampling.LANCZOS), (0, 6))
for index in range(9):
    if index < 8:
        col, row = index % 4, index // 4
        icon = icons.crop((col*128, row*128, (col+1)*128, (row+1)*128))
    else:
        icon = clear
    assembly.alpha_composite(icon.resize((22, 22), Image.Resampling.LANCZOS), (16+37+index*29+2, 17))
assembly.save(PREVIEW / "toolbar-transparent.png")
# Lite nine-slice layout preview matches TargetMarkersLite.lua; native fonts/input need live QA.
def lite_assembly(order, layout):
    count = len(order)
    columns = (count+1)//2 if layout == "twoRows" else count
    rows = (count+columns-1)//columns
    width,height = columns*29+63,(rows-1)*29+56
    xs,ys = [0,32,width-32,width],[0,14,height-14,height]
    us,vs = [0,.1,.9,1],[0,.25,.75,1]
    back = Image.new("RGBA",(width,height))
    for row in range(3):
        for col in range(3):
            crop = panel.crop((round(us[col]*panel.width),round(vs[row]*panel.height),round(us[col+1]*panel.width),round(vs[row+1]*panel.height)))
            crop = crop.resize((xs[col+1]-xs[col],ys[row+1]-ys[row]),Image.Resampling.LANCZOS)
            back.alpha_composite(crop,(xs[col],ys[row]))
    if layout == "vertical": back = back.transpose(Image.Transpose.ROTATE_270)
    for pos,index in enumerate(order):
        if index < 9:
            col,row=(index-1)%4,(index-1)//4
            icon=icons.crop((col*128,row*128,(col+1)*128,(row+1)*128))
        else: icon=clear
        icon=icon.resize((22,22),Image.Resampling.LANCZOS)
        if layout == "vertical": point=(17,39+pos*29)
        else: point=(39+(pos%columns)*29,17+(pos//columns)*29)
        back.alpha_composite(icon,point)
    return back
lite=lite_assembly(list(range(1,10)),"horizontal")
lite.save(PREVIEW / "target-markers-lite-transparent.png")
lite_review=Image.new("RGBA",(840,650),(29,32,36,255))
ld=ImageDraw.Draw(lite_review)
ld.text((20,12),"AZUI / TARGET MARKERS LITE / OFFLINE ASSEMBLY",fill=(220,207,170))
ld.text((20,42),"All markers / horizontal / 1x",fill="white");lite_review.alpha_composite(lite,(20,60))
favorites=[8,7,5,9]
ld.text((20,135),"Skull, Cross, Moon / horizontal / 1x",fill="white")
lite_review.alpha_composite(lite_assembly(favorites,"horizontal"),(20,155))
ld.text((20,230),"Favorites / two rows / 1x",fill="white")
lite_review.alpha_composite(lite_assembly(favorites,"twoRows"),(20,250))
ld.text((400,42),"Favorites / vertical / 1x",fill="white")
lite_review.alpha_composite(lite_assembly(favorites,"vertical"),(400,65))
ld.text((20,375),"Favorites / horizontal / 2x",fill="white")
favorite=lite_assembly(favorites,"horizontal")
lite_review.alpha_composite(favorite.resize((favorite.width*2,favorite.height*2),Image.Resampling.NEAREST),(20,395))
ld.text((440,285),"Favorites / two rows / 2x",fill="white")
favorite=lite_assembly(favorites,"twoRows")
lite_review.alpha_composite(favorite.resize((favorite.width*2,favorite.height*2),Image.Resampling.NEAREST),(440,305))
ld.text((20,540),"Clear: all target markers. Shift + clear: all world markers.",fill=(220,207,170))
ld.text((20,565),"Favorites and layout preserve the mover's saved position.",fill=(220,207,170))
ld.text((20,590),"Art assembly only; client rendering and secure clicks still need live testing.",fill=(170,175,180))
lite_review.convert("RGB").save(PREVIEW / "target-markers-lite-review.png")
collapsed = Image.new("RGBA", (340, 56))
collapsed.alpha_composite(toggle.resize((22, 44), Image.Resampling.LANCZOS), (0, 6))
sheet = Image.new("RGBA", (780, 380), (29, 32, 36, 255))
draw = ImageDraw.Draw(sheet)
draw.text((24, 14), "AZERITEUI / MARKER TOOLBAR / OFFLINE ASSEMBLY", fill=(220, 207, 170))
draw.text((24, 46), "1x - expanded", fill="white")
sheet.alpha_composite(assembly, (24, 66))
draw.text((400, 46), "1x - folded", fill="white")
sheet.alpha_composite(collapsed, (400, 66))
draw.text((24, 145), "2x - expanded", fill="white")
sheet.alpha_composite(assembly.resize((680, 112), Image.Resampling.NEAREST), (24, 168))
draw.text((24, 306), "Click: target    Right-click: clear    Shift: ground markers", fill=(220, 207, 170))
draw.text((24, 332), "Art fit only. Client rendering, input and taint still require live testing.", fill=(170, 175, 180))
sheet.convert("RGB").save(PREVIEW / "toolbar-review.png")
# Full panel uses its own painting. Keep the original toolbar exports for provenance.
full_source = Image.open(DRAFT / "full-panel-source.png").convert("RGBA")
full_box = full_source.getchannel("A").point(lambda a: 255 if a >= 8 else 0).getbbox()
full_box = (max(0, full_box[0]-8), max(0, full_box[1]-8), min(full_source.width, full_box[2]+8), min(full_source.height, full_box[3]+8))
full_panel = full_source.crop(full_box).resize((512, 1024), Image.Resampling.LANCZOS)
full_panel.save(OUT / "full-panel.tga")
button_art = panel.resize((256, 64), Image.Resampling.LANCZOS)
button_art.save(OUT / "button.tga")
channels = [button_art.getchannel(c).point(lambda v: round(v*.25)) for c in "RGB"]
Image.merge("RGBA", (*channels, button_art.getchannel("A"))).save(OUT / "button-highlight.tga")

# Same rectangles as the Lua panel; sample roster is explicitly illustrative.
full = Image.new("RGBA", (274, 500))
full.alpha_composite(full_panel.resize((252,500), Image.Resampling.LANCZOS), (22,0))
full.alpha_composite(toggle.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((22,44), Image.Resampling.LANCZOS), (0,228))
font_path = Path("C:/Windows/Fonts/segoeui.ttf")
font = ImageFont.truetype(str(font_path), 11) if font_path.exists() else ImageFont.load_default()
title_font = ImageFont.truetype(str(font_path), 12) if font_path.exists() else font
paint = ImageDraw.Draw(full)
heading_width = paint.textlength("RAID", font=title_font)
count_width = paint.textlength("10", font=title_font)
heading_left = 22+126-(heading_width+8+count_width)/2
paint.text((heading_left,30), "RAID", font=title_font, anchor="lt", fill=(230,220,188))
paint.text((heading_left+heading_width+8,30), "10", font=title_font, anchor="lt", fill=(230,220,188))
for i, (role, value) in enumerate((("tank",2),("heal",2),("dps",6))):
    icon = Image.open(ROOT / ("Assets/grouprole-icons-"+role+".tga")).convert("RGBA").crop((12,12,54,56)).resize((20,20), Image.Resampling.LANCZOS)
    count_width = paint.textlength(str(value),font=title_font)
    icon_left = round(22+126+(i-1)*72-(20+6+count_width)/2)
    full.alpha_composite(icon,(icon_left,51))
    paint.text((icon_left+26,61),str(value),font=title_font,anchor="lm",fill=(230,220,188))
def sample_button(text, x, y, width):
    full.alpha_composite(button_art.resize((width,26),Image.Resampling.LANCZOS),(22+x,y))
    ImageDraw.Draw(full).text((22+x+width/2,y+13),text,font=font,anchor="mm",fill=(239,227,189))
paint.text((40,83),"RAID GROUPS",font=font,fill=(230,220,188))
for i in range(8): sample_button(str(i+1)+( " (5)" if i<2 else ""),18+(i%4)*55,102+(i//4)*31,49)
paint.text((40,174),"MARKERS",font=font,fill=(230,220,188))
sample_button("Target",18,192,104); sample_button("Ground",130,192,104)
for i in range(9):
    col,row=(i%4,i//4) if i<8 else (4,0)
    icon=icons.crop(((i%4)*128,(i//4)*128,(i%4+1)*128,(i//4+1)*128)) if i<8 else clear
    full.alpha_composite(icon.resize((24,24),Image.Resampling.LANCZOS),(22+18+col*44+3,226+row*31+2))
for text,x,y,width in [
    ("Ready check",18,290,104),("Role check",130,290,104),
    ("10s",18,320,104),("All assist",130,320,104),
    ("Party",18,350,104),("Difficulty",130,350,104),
    ("Ping permissions",18,380,216),("Hide frames",18,410,104),
    ("Settings",130,410,104),("Leave group",18,440,104),("Leave instance",130,440,104)]: sample_button(text,x,y,width)
full.save(PREVIEW / "full-panel-transparent.png")
review=Image.new("RGBA",(930,1070),(29,32,36,255))
rd=ImageDraw.Draw(review)
rd.text((16,12),"AZERITEUI / FULL RAID-PARTY PANEL / OFFLINE ASSEMBLY",font=title_font,fill=(220,207,170))
rd.text((16,37),"1x",font=font,fill="white"); review.alpha_composite(full,(16,56))
rd.text((340,37),"2x",font=font,fill="white"); review.alpha_composite(full.resize((548,1000),Image.Resampling.NEAREST),(340,56))
rd.text((16,580),"Illustrative 10-player roster.",font=font,fill=(220,207,170))
rd.text((16,600),"Fonts are an offline approximation.",font=font,fill=(180,180,180))
rd.text((16,620),"Client rendering/input/taint need live QA.",font=font,fill=(180,180,180))
review.convert("RGB").save(PREVIEW / "full-panel-review.png")

manifest = {"source_sha256": hashlib.sha256((DRAFT / "panel-source.png").read_bytes()).hexdigest(), "crop": box, "full_panel_crop": full_box, "full_panel_source_sha256": hashlib.sha256((DRAFT / "full-panel-source.png").read_bytes()).hexdigest(),
            "textures": {p.name: {"size": Image.open(p).size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(OUT.glob("*.tga"))}}
(PREVIEW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(json.dumps(manifest, indent=2))
