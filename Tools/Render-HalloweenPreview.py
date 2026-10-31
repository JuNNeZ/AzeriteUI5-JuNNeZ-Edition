"""Offline default-layout projection; does not emulate WoW rendering or endcaps."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Docs/Research_Assets/Halloween"
FONT = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 15)
THEMES = ["AzeriteUI", "Hunter", "Mage", "Paladin", "Druid", "Warrior", "Rogue", "Shaman", "Legacy"]


def sprite(name, size):
    return Image.open(ROOT / f"Assets/Halloween/{name}.tga").convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)


def panel(theme, enabled):
    canvas = Image.new("RGBA", (900, 300), (27, 31, 37, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 12), f"{theme} | Halloween {'ON' if enabled else 'OFF'} | default layout projection, endcaps off", font=FONT, fill="white")
    def put(im, x, bottom, additive=False):
        position = (round(x), round(270 - bottom - im.height))
        if additive:
            layer = Image.new("RGBA", canvas.size)
            layer.alpha_composite(im, position)
            light = ImageChops.multiply(layer.convert("RGB"), layer.getchannel("A").convert("RGB"))
            canvas.paste(ImageChops.add(canvas.convert("RGB"),light).convert("RGBA"))
        else:
            canvas.alpha_composite(im, position)
    def asset(name, size, x, bottom, tint=None, alpha=1):
        base = ROOT / "Assets"
        path = base / theme / f"{name}.tga" if theme != "AzeriteUI" else base / f"{name}.tga"
        if not path.exists():
            path = base / f"{name}.tga"
        im = Image.open(path).convert("RGBA").resize(size, Image.Resampling.LANCZOS)
        if tint:
            r, g, b, a = im.split()
            im = Image.merge("RGBA", (r.point(lambda v: int(v*tint[0])), g.point(lambda v: int(v*tint[1])), b.point(lambda v: int(v*tint[2])), a))
        if alpha != 1:
            im.putalpha(im.getchannel("A").point(lambda value: round(value*alpha)))
        put(im, x, bottom)
    def face(size, x, bottom):
        painting=sprite("horseman-face-v2",size)
        r,g,b,a=painting.split()
        recess=Image.merge("RGBA",(r.point(lambda v:round(v*.03)),g.point(lambda v:round(v*.05)),
                                  b.point(lambda v:round(v*.03)),a.point(lambda v:round(v*.20))))
        put(recess,x,bottom)
        glow=Image.merge("RGBA",(r.point(lambda v:round(v*.45)),g,b.point(lambda v:round(v*.30)),
                                a.point(lambda v:round(v*.30))))
        put(glow,x,bottom,True)
    if theme == "Legacy":
        hx, hy, hw, hh = 210, 65, 300, 58
        px, py = hx, 37
        draw.rounded_rectangle((202, 270-131, 518, 270-29), radius=8, fill="#111419", outline="#777b82", width=3)
        draw.rectangle((hx,270-hy-hh,hx+hw,270-hy), fill="#387955")
        draw.rectangle((px,270-py-12,px+hw,270-py), fill="#486da2")
    else:
        hx, hy, hw, hh = 228, 67, 385, 40
        px, py = 100, 78
        # Health.Backdrop is created by the unit frame, not by Health.
        asset("hp_cap_case", (716,188), hx-148-17, hy-27-48)
        asset("hp_cap_bar", (385,40), hx, hy, (.28,.7,.4))
        # Native default crystal draw rectangles, including its original crop.
        asset("power_crystal_back", (196,196), px+60-98, py+70-98)
        im = Image.open(ROOT / "Assets/power_crystal_front.tga").convert("RGBA")
        w,h = im.size
        im = im.crop((round(w*50/255),round(h*37/255),round(w*206/255),round(h*219/255))).resize((120,140), Image.Resampling.LANCZOS)
        r,g,b,a = im.split()
        im = Image.merge("RGBA",(r.point(lambda v:round(v*.48)),g.point(lambda v:round(v*.32)),b,a))
        put(im, px, py)
        asset("pw_crystal_case", (198,98), px+60+7-99, py-51)
        # Native themed foreground, where one is supplied.
        over = ROOT / f"Assets/{theme}/hp_cap_case-over.tga"
        if over.exists():
            put(Image.open(over).convert("RGBA").resize((716,188),Image.Resampling.LANCZOS), hx-148-17, hy-27-48)
    draw.text((hx+hw//2-26,270-hy-hh//2-8), "100%", font=FONT, fill="white")
    if theme != "Legacy":
        # Static resource projection only: live fills/effect frames are not emulated.
        if enabled:
            face(102,px+60-51,py+70+3-51-20)
            asset("power_crystal_back",(196,196),px+60-98,py+70-98,alpha=.14)
        ox, oy = 760, 115
        asset("orb-backdrop2", (180,180), ox-90, oy-90)
        asset("orb2", (103,103), ox-51, oy-51, (.4,.45,.9))
        asset("orb_case_hi", (188,188), ox-94, oy-94)
        if enabled:
            face(84,ox-42,oy-42)
        asset("orb-glass",(173,173),ox-86,oy-86,alpha=.9)
        draw.text((ox-18,270-oy-7), "100%", font=FONT, fill="white")
    elif enabled:
        # Legacy has a thin horizontal power strip, no crystal or orb aperture.
        face(6,px+hw//2-3,py+6-3)
    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1800, 300*len(THEMES)))
    for row, theme in enumerate(THEMES):
        for column, enabled in enumerate((False, True)):
            sheet.alpha_composite(panel(theme, enabled), (900*column,300*row))
    sheet.convert("RGB").save(OUT / "all-themes-1x.png")
    sheet.resize((3600,5400), Image.Resampling.NEAREST).convert("RGB").save(OUT / "all-themes-2x.png")
    sample = Image.new("RGBA", (900,900))
    for row, theme in enumerate(("AzeriteUI","Rogue","Legacy")):
        sample.alpha_composite(panel(theme,True),(0,300*row))
    sample.convert("RGB").save(OUT / "preview.png")
    corners = Image.new("RGBA", (900,450),(27,31,37,255))
    draw = ImageDraw.Draw(corners)
    draw.text((20,12), "Menu / tooltip corner and minimap projection (offline)", font=FONT, fill="white")
    for box, size, title in [((80,100,440,360),56,"AzeriteUI options"),((540,150,800,255),44,"Tooltip text")]:
        left,top,right,bottom = box
        draw.rectangle(box,fill="#121419",outline="#888b90",width=3)
        draw.text((left+14,top+14),title,font=FONT,fill="white")
        web = sprite("web",size)
        web.putalpha(web.getchannel("A").point(lambda v:round(v*.6)))
        corners.alpha_composite(web,(left-1,top-1))
        corners.alpha_composite(web.rotate(180),(right+1-size,bottom+1-size))
        corners.alpha_composite(sprite("spider",7),(left+4,top+4))
    corners.convert("RGB").save(OUT / "windows-minimap-preview.png")
    # Fixed minimap snapshots of the configured native paths, not a client capture.
    import math
    states = Image.new("RGBA",(900,340),(27,31,37,255))
    sd = ImageDraw.Draw(states)
    ring = Image.open(ROOT / "Assets/minimap-border.tga").convert("RGBA").resize((394,394),Image.Resampling.LANCZOS)
    for column,t in enumerate((.3,2.4,4.6)):
        cx,cy,unit = 150+300*column,180,196
        sd.text((cx-120,12),f"OFFLINE masked gust t~{t}s",font=FONT,fill="white")
        def centred(im,x,y):
            states.alpha_composite(im,(round(x-im.width/2),round(y-im.height/2)))
        sd.ellipse((cx-98,cy-98,cx+98,cy+98),fill="#454a32")
        gust=Image.new("RGBA",states.size)
        for i in range(1,8):
            progress=(t-(i-1)*.22)/4.8
            if not 0 <= progress <= 1:
                continue
            opacity=min(1,progress*12,(1-progress)*12)*.75
            leaf=sprite("autumn-leaf",round(unit*(.085+.01*(i%3))))
            leaf.putalpha(leaf.getchannel("A").point(lambda v:round(v*opacity)))
            leaf=leaf.rotate(math.degrees(i*.8)+(110+i*23)*progress,expand=True)
            x=cx+unit*(-.56+1.12*progress)
            y=cy-unit*(.30-.09*i+.03*math.sin(progress*2*math.pi))
            gust.alpha_composite(leaf,(round(x-leaf.width/2),round(y-leaf.height/2)))
        mask=Image.new("L",states.size)
        mask.paste(Image.open(ROOT/"Assets/orb2.tga").convert("RGBA").getchannel("A").resize((196,196),Image.Resampling.LANCZOS),(cx-98,cy-98))
        gust.putalpha(ImageChops.multiply(gust.getchannel("A"),mask))
        outside=ImageChops.multiply(gust.getchannel("A"),mask.point(lambda v:255 if v == 0 else 0))
        assert outside.getbbox() is None, "leaf paint outside map mask"
        states.alpha_composite(gust)
        centred(ring,cx,cy)
    states.convert("RGB").save(OUT / "Inside-Map-Repair/minimap-mask-states.png")
    print("Wrote fixed-viewport off/on sheets for nine themes at 1x/2x")


if __name__ == "__main__":
    main()
