"""Render recorded real widget calls, offline; native class atlases are schematic.

First run guild_manager_harness.lua with a snapshot JSON path, then:
python Tools/Preview-GuildWindow.py <snapshot.json> <preview.png>
This is a layout/art proof, never a WoW screenshot or runtime validation.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
items = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
by_id = {w["id"]: w for w in items}
window_name = sys.argv[3] if len(sys.argv)>3 else "AzTestGuildManager"
window = next(w for w in items if w["name"] == window_name)
cache = {}

def bounds(w):
    if w["id"] in cache:
        return cache[w["id"]]
    if w["fill"]:
        box = bounds(by_id[w["fill"]])
    elif w["name"] == "UIParent":
        box = (0, 0, 1920, 1080)
    else:
        relative = by_id.get(w["relative"] or w["parent"])
        px, py, pw, ph = bounds(relative) if relative else (0, 0, 1920, 1080)
        width, height = w["w"], w["h"]
        def anchor(point):
            return (0 if "LEFT" in point else 1 if "RIGHT" in point else .5,
                    0 if "TOP" in point else 1 if "BOTTOM" in point else .5)
        sx, sy = anchor(w["point"])
        rx, ry = anchor(w.get("relativePoint", w["point"]))
        box = (px+pw*rx-width*sx+w["x"], py+ph*ry-height*sy-w["y"], width, height)
    owner = by_id.get(w.get("scrollOwner", 0))
    if owner:
        box = (box[0], box[1]-owner.get("scroll", 0), box[2], box[3])
    cache[w["id"]] = box
    return box

def visible(w):
    if not w["shown"]:
        return False
    return visible(by_id[w["parent"]]) if w["parent"] else True

def rgba(color):
    return tuple(round(max(0, min(1, value))*255) for value in (color[:3]+[color[3] if len(color)>3 else 1]))

def asset_path(texture):
    normalized = texture.replace("\\", "/")
    if normalized.startswith("Assets_Draft/"):
        return ROOT / normalized
    if "/Assets/" in normalized:
        return ROOT / "Assets" / normalized.split("/Assets/",1)[1]
    return ROOT / "Assets/Guild" / normalized.split("/")[-1]

wx, wy, width, height = bounds(window)
canvas = Image.new("RGBA", (int(width), int(height)+36), (7, 9, 13, 255))
draw = ImageDraw.Draw(canvas)
fontfile = Path("C:/Windows/Fonts/segoeui.ttf")
class_colors = {"MAGE":"69ccf0", "WARRIOR":"c79c6e", "PRIEST":"ffffff", "PALADIN":"f58cba",
                "WARLOCK":"9482c9", "HUNTER":"abd473", "ROGUE":"fff569"}
children = {}
for w in items:
    children.setdefault(w["parent"], []).append(w)

def clip_bounds(w):
    """Intersect ancestor scroll viewports in canvas coordinates."""
    left, top, right, bottom = 0, 0, int(width), int(height)
    parent = by_id.get(w["parent"])
    clipped = False
    while parent:
        if parent.get("clips"):
            px, py, pw, ph = bounds(parent)
            left, top = max(left, round(px-wx)), max(top, round(py-wy))
            right, bottom = min(right, round(px+pw-wx)), min(bottom, round(py+ph-wy))
            clipped = True
        parent = by_id.get(parent["parent"])
    return (left, top, max(left, right), max(top, bottom)) if clipped else None

def ordered(w):
    regions = [c for c in children.get(w["id"],[]) if c["kind"] in ("Texture","Text","Highlight")]
    underlays = [c for c in regions if c["kind"]=="Texture" and c["fill"]==w["id"] and c["color"] and c["color"][3]==1]
    # Owned solid fills live below the frame's backdrop edges in WoW.
    for c in underlays:
        yield c
    yield w
    for c in sorted(regions,key=lambda r:r["kind"]=="Text"):
        if c not in underlays:
            yield c
    for c in children.get(w["id"],[]):
        if c not in regions:
            yield from ordered(c)

for w in ordered(window):
    if not visible(w) or w["kind"] == "Highlight":
        continue
    x, y, ww, hh = bounds(w)
    x, y, ww, hh = round(x-wx), round(y-wy), round(ww), round(hh)
    clip = clip_bounds(w)
    if clip and (clip[0] >= clip[2] or clip[1] >= clip[3]):
        continue
    base = canvas
    if clip:
        canvas = Image.new("RGBA", base.size)
        draw = ImageDraw.Draw(canvas)
    if w["kind"] in ("Frame", "Button", "EditBox") and w["bgColor"] and ww and hh:
        backdrop = asset_path(w.get("backdropTexture") or "")
        if backdrop.is_file():
            tile = Image.open(backdrop).convert("RGBA").resize((64,64),Image.Resampling.LANCZOS)
            field = Image.new("RGBA",(ww,hh))
            for ty in range(0,hh,64):
                for tx in range(0,ww,64):
                    field.alpha_composite(tile,(tx,ty))
            canvas.alpha_composite(field,(x,y))
        draw.rounded_rectangle((x,y,x+ww,y+hh), radius=4, fill=None if backdrop.is_file() else rgba(w["bgColor"]),
                               outline=rgba(w["borderColor"] or [.35,.3,.2,1]), width=1)
    if w["kind"] == "Texture" and ww>0 and hh>0:
        if w["texture"]:
            path = asset_path(w["texture"])
            if path.exists():
                art = Image.open(path).convert("RGBA")
                if w["uv"]:
                    u0,u1,v0,v1 = w["uv"]
                    art = art.crop((round(u0*art.width),round(v0*art.height),round(u1*art.width),round(v1*art.height)))
                if w.get("desaturated"):
                    gray = art.convert("L")
                    art = Image.merge("RGBA", (gray, gray, gray, art.getchannel("A")))
                tint = w.get("vertexColor")
                if tint:
                    bands = art.split()
                    art = Image.merge("RGBA",tuple(band.point(lambda value,factor=(tint[i] if i<len(tint) else 1):round(value*factor)) for i,band in enumerate(bands)))
                canvas.alpha_composite(art.resize((ww,hh), Image.Resampling.LANCZOS), (x,y))
        elif w["atlas"]:
            color = class_colors.get(w["atlas"].split("-")[-1], "aaaabb")
            rgb = tuple(int(color[i:i+2],16) for i in (0,2,4))
            if w.get("desaturated"):
                gray = round(.299*rgb[0]+.587*rgb[1]+.114*rgb[2]); rgb = (gray,gray,gray)
            tint = w.get("vertexColor") or [1,1,1]
            rgb = tuple(round(channel*tint[i]) for i,channel in enumerate(rgb))
            draw.rounded_rectangle((x,y,x+ww,y+hh), radius=3, fill=rgb, outline="#888888" if w.get("desaturated") else "#e9d7a8")
        elif w["color"]:
            layer = Image.new("RGBA", (ww,hh), rgba(w["color"]))
            canvas.alpha_composite(layer, (x,y))
    if w["text"]:
        if w["kind"] == "EditBox":
            inset = w.get("insets") or [8,8,5,5]
            x += inset[0]; y += inset[2]; ww -= inset[0]+inset[1]
        size = w["font"]
        font = ImageFont.truetype(str(fontfile), size)
        color = rgba(w["textColor"] or [.92,.88,.76,1])
        text = w["text"]
        max_lines = max(1,hh//(size+3)) if w["kind"]=="EditBox" else (w["lines"] or 10000)
        lines = []
        for paragraph in text.splitlines():
            line = ""
            for word in paragraph.split(" "):
                while ww and draw.textlength(word,font=font)>ww:
                    if line:
                        lines.append(line); line = ""
                    cut = len(word)
                    while cut>1 and draw.textlength(word[:cut],font=font)>ww:
                        cut -= 1
                    lines.append(word[:cut]); word = word[cut:]
                candidate = (line+" "+word).strip()
                if line and ww and draw.textlength(candidate,font=font)>ww:
                    lines.append(line); line = word
                else:
                    line = candidate
            lines.append(line)
        if len(lines)>max_lines:
            lines = lines[:max_lines]
            line = lines[-1]
            while line and draw.textlength(line+"...",font=font)>ww:
                line = line[:-1]
            lines[-1] = line+"..."
        for i,line in enumerate(lines):
            text_x = x+(ww-draw.textlength(line,font=font))/2 if w.get("justifyH")=="CENTER" else x
            draw.text((text_x,y+i*(size+3)-2),line,font=font,fill=color)
    if clip:
        base.alpha_composite(canvas.crop(clip), (clip[0], clip[1]))
        canvas = base
        draw = ImageDraw.Draw(canvas)

draw.rectangle((0,int(height),int(width),int(height)+36), fill=(10,12,17,255))
draw.text((15,int(height)+9), "OFFLINE LAYOUT PREVIEW  /  frame borders and class icons schematic  /  not a WoW screenshot",
          font=ImageFont.truetype(str(fontfile),12),fill=(150,155,165,255))
output = Path(sys.argv[2]); output.parent.mkdir(parents=True, exist_ok=True)
canvas.convert("RGB").save(output)
print(output.resolve())
