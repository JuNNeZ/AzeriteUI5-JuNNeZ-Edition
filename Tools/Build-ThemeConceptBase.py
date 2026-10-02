"""Build the base board a theme concept sheet is repainted from.

Usage:
  python Tools/Build-ThemeConceptBase.py                      writes the base and guide boards
  python Tools/Build-ThemeConceptBase.py --overlay <sheet.png>   writes <sheet>-overlay.png for proportion review

The board is the original AzeriteUI artwork at the original layout anchors,
arranged like the Hunter concept sheet. Proportions on it are the real ones,
so a concept repainted from it starts out correct. Live models, spell icons
and font metrics are not emulated.
"""
from pathlib import Path
import json, math, sys
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'Docs/Research_Assets/Templates'
DATA = json.loads((ROOT / 'Docs/Research_Assets/Paladin/Revision5/layouts.json').read_text())['original']
S = Image.Resampling.LANCZOS
FONT = 'C:/Windows/Fonts/georgia.ttf'
W, H = 1536, 1024
BG = '#14161a'

def asset(path):
    if path is None: return None
    return Image.open(ROOT / 'Assets' / path.replace('\\', '/').split('/Assets/')[-1]).convert('RGBA')
def media(name): return asset(name + '.tga')
def color(im, c):
    c = tuple(round(v * 255) for v in c[:3]) + (255,)
    out = ImageChops.multiply(im, Image.new('RGBA', im.size, c)); out.putalpha(im.getchannel('A')); return out
def anchor(rect, size, pos):
    point = pos[0]; dx, dy = pos[-2:]; x, y, w, h = rect; sw, sh = size
    fx = 0 if 'LEFT' in point else 1 if 'RIGHT' in point else .5
    fy = 0 if 'TOP' in point else 1 if 'BOTTOM' in point else .5
    return (x + fx * (w - sw) + dx, y + fy * (h - sh) - dy, sw, sh)
def put(scene, im, rect, flip=False, tint=None):
    if im is None: return
    if tint: im = color(im, tint)
    if flip: im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    x, y, w, h = rect
    scene.alpha_composite(im.resize((max(1, round(w)), max(1, round(h))), S), (round(x), round(y)))
def fill(scene, texture, rect, fraction, c, flip=False, vertical=False, coords=None):
    im = asset(texture)
    if coords:
        l, r, t, b = coords; im = im.crop((round(l * im.width), round(t * im.height), round(r * im.width), round(b * im.height)))
    im = color(im, c).resize((max(1, round(rect[2])), max(1, round(rect[3]))), S)
    if flip: im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    x, y, w, h = rect
    if vertical:
        cut = round(im.height * (1 - fraction)); im = im.crop((0, cut, im.width, im.height)); y += cut
    elif flip:
        cut = round(im.width * (1 - fraction)); im = im.crop((cut, 0, im.width, im.height)); x += cut
    else: im = im.crop((0, 0, round(im.width * fraction), im.height))
    if im.width and im.height: scene.alpha_composite(im, (round(x), round(y)))

RED, GREEN, AMBER, DARK = (.84, .03, .08), (.3, .65, .2), (1, .65, .1), (.09, .08, .11)

def unit(kind, tier, fraction=1, resource='crystal'):
    base = DATA[kind]; db = dict(base); db.update(base.get(tier, {}))
    scene = Image.new('RGBA', (900, 360)); flip = kind == 'TargetFrame'
    owner = (150, 80, *(base.get('Size') or [550, 210]))
    hp = anchor(owner, db['HealthBarSize'], db['HealthBarPosition'])
    if db.get('PortraitBorderTexture'):
        put(scene, asset(db['PortraitBorderTexture']), anchor(owner, db['PortraitBorderSize'], db['PortraitBorderPosition']), tint=db.get('PortraitBorderColor'))
    put(scene, asset(db['HealthBackdropTexture']), anchor(owner, db['HealthBackdropSize'], db['HealthBackdropPosition']), flip, db.get('HealthBackdropColor'))
    fill(scene, db['HealthBarTexture'], hp, 1, DARK, flip); fill(scene, db['HealthBarTexture'], hp, fraction, RED, flip)
    if kind == 'PlayerFrame' and resource: power(scene, owner, db, 1, resource)
    return scene

def power(scene, owner, db, fraction, resource):
    if resource == 'orb':
        rect = anchor(owner, db['ManaOrbSize'], db['ManaOrbPosition'])
        put(scene, asset(db['ManaOrbBackdropTexture']), anchor(rect, db['ManaOrbBackdropSize'], db['ManaOrbBackdropPosition']))
        fill(scene, 'Interface/Assets/orb2.tga', rect, fraction, (.25, .4, .95), vertical=True)
        put(scene, asset(db['ManaOrbForegroundTexture']), anchor(rect, db['ManaOrbForegroundSize'], db['ManaOrbForegroundPosition']), tint=db['ManaOrbForegroundColor'])
    else:
        rect = anchor(owner, db['PowerBarSize'], db['PowerBarPosition'])
        put(scene, asset(db['PowerBackdropTexture']), anchor(rect, db['PowerBackdropSize'], db['PowerBackdropPosition']))
        fill(scene, db['PowerBarTexture'], rect, fraction, db['PowerBarColors']['MANA'], vertical=True, coords=db.get('PowerBarTexCoord'))
        put(scene, asset(db['PowerBarForegroundTexture']), anchor(rect, db['PowerBarForegroundSize'], db['PowerBarForegroundPosition']), tint=db['PowerBarForegroundColor'])

def resource(kind, fraction):
    base = DATA['PlayerFrame']; db = dict(base); db.update(base['Seasoned'])
    scene = Image.new('RGBA', (900, 500)); power(scene, (300, 150, *base['Size']), db, fraction, kind); return scene

def compact(name, fraction=1, c=GREEN):
    db = DATA[name]; pre = 'MirrorTimer' if name == 'MirrorTimers' else 'Health'; w, h = db[pre + 'BarSize']
    scene = Image.new('RGBA', (400, 200)); bar = (120, 90, w, h)
    put(scene, asset(db[pre + 'BackdropTexture']), anchor(bar, db[pre + 'BackdropSize'], db[pre + 'BackdropPosition']), tint=db[pre + 'BackdropColor'])
    fill(scene, db[pre + 'BarTexture'], bar, fraction, c); return scene

def nameplate():
    db = DATA['NamePlates']; scene = Image.new('RGBA', (300, 160)); w, h = db['HealthBarSize']
    for rect, pre, c, p in [((100, 50, w, h), 'Health', RED, 1), ((100, 67, w, h), 'Cast', AMBER, .6)]:
        name = 'HealthBackdrop' if pre == 'Health' else 'CastBarBackdrop'
        put(scene, asset(db[name + 'Texture']), anchor(rect, db[name + 'Size'], db[name + 'Position']))
        fill(scene, db[pre + 'BarTexture'], rect, p, c, coords=db[pre + 'BarTexCoord'])
    return scene

def castbar(fraction=.65):
    db = DATA['PlayerCastBar']; scene = Image.new('RGBA', (500, 300)); rect = (190, 140, *db['CastBarSize'])
    put(scene, asset(db['CastBarBackgroundTexture']), anchor(rect, db['CastBarBackgroundSize'], db['CastBarBackgroundPosition']), tint=db['CastBarBackgroundColor'])
    fill(scene, db['CastBarTexture'], rect, 1, DARK); fill(scene, db['CastBarTexture'], rect, fraction, db['CastBarColor']); return scene

def button(icon=False):
    db = DATA['ActionButton']; scene = Image.new('RGBA', (260, 260)); rect = (98, 98, 64, 64)
    put(scene, asset(db['ButtonBackdropTexture']), anchor(rect, db['ButtonBackdropSize'], db['ButtonBackdropPosition']))
    if icon: put(scene, media('grouprole-icons-dps'), anchor(rect, db['ButtonIconSize'], db['ButtonIconPosition']))
    put(scene, asset(db['ButtonBorderTexture']), anchor(rect, db['ButtonBorderSize'], db['ButtonBorderPosition']), tint=db['ButtonBorderColor']); return scene

def group(name):
    db = DATA[name]; scene = Image.new('RGBA', (400, 300)); owner = (120, 90, *db['UnitSize'])
    for pre in ['PortraitBackground', 'PortraitBorder']:
        put(scene, asset(db[pre + 'Texture']), anchor(owner, db[pre + 'Size'], db[pre + 'Position']), tint=db[pre + 'Color'])
    rect = anchor(owner, db['HealthBarSize'], db['HealthBarPosition'])
    put(scene, asset(db['HealthBackdropTexture']), anchor(rect, db['HealthBackdropSize'], db['HealthBackdropPosition']), tint=db['HealthBackdropColor'])
    fill(scene, db['HealthBarTexture'], rect, .8, GREEN, db['HealthBarOrientation'] == 'LEFT'); return scene

def points(lit=3):
    db = DATA['PlayerClassPower']; scene = Image.new('RGBA', (400, 400)); owner = (120, 120, *db['ClassPowerFrameSize'])
    for j, p in enumerate(db['ClassPowerLayouts']['ComboPoints']):
        rect = anchor(owner, p['Size'], p['Position'])
        put(scene, asset(p['BackdropTexture']), anchor(rect, p['BackdropSize'], ['CENTER', 0, 0]), tint=db['ClassPowerCaseColor'])
        put(scene, color(asset(p['Texture']), (1, .78, .28) if j < lit else db['ClassPowerSlotColor']).rotate(math.degrees(p.get('PointRotation', 0))), rect)
    return scene

def single(name, size, tint=(.75, .75, .75)):
    scene = Image.new('RGBA', (size, size)); put(scene, media(name), (0, 0, size, size), tint=tint); return scene

def build():
    board = Image.new('RGBA', (W, H), BG); guide_marks = []; d = ImageDraw.Draw(board)
    def text(s, x, y, size=17, fill='#c9c1ad'): d.text((x, y), s, font=ImageFont.truetype(FONT, size), fill=fill)
    def place(scene, x, y, label=None):
        box = scene.getbbox(); art = scene.crop(box); board.alpha_composite(art, (x, y))
        if label: text(label, x, y - 24, 14, '#9a958a')
        return (x, y, x + art.width, y + art.height)
    def slot(x, y, w, h, label):
        guide_marks.append((x, y, x + w, y + h, label))
    def rule(y): d.line((24, y, W - 24, y), fill='#2b2f36', width=1)

    text('AZERITEUI  -  THEME NAME', 40, 26, 40, '#d8d2c2'); text('SUBTITLE', 44, 76, 15, '#9a958a')
    rule(104); text('1. PLAYER HUD', 28, 114, 18)
    p = place(unit('PlayerFrame', 'Seasoned'), 40, 176, 'PLAYER')
    slot(p[2] - 22, p[3] - 84, 48, 48, 'health endcap')
    t = place(unit('TargetFrame', 'Seasoned'), 560, 150, 'TARGET')
    c = place(castbar(), 1200, 190, 'PLAYER CASTBAR')
    slot(c[0] - 40, c[1] - 6, 44, 44, 'cast head')
    rule(360); text('2. RESOURCES & PET', 28, 370, 18)
    for i, f in enumerate([1, .5, 0]): place(resource('crystal', f), 50 + i * 140, 420, ['100%', '50%', '0%'][i])
    for i, f in enumerate([1, .5, 0]): place(resource('orb', f), 500 + i * 150, 420, ['100%', '50%', '0%'][i])
    place(points(), 990, 410, 'CLASS POWER')
    pet = place(compact('PetFrame'), 1150, 470, 'PET FRAME')
    slot(1130, 430, 330, 110, 'class set piece (optional)')
    rule(600); text('3. NAMEPLATES, PORTRAITS & GROUP', 28, 610, 18)
    place(nameplate(), 50, 670, 'NAMEPLATE')
    place(compact('ToTFrame'), 220, 670, 'TARGET OF TARGET'); place(compact('FocusFrame'), 220, 725, None)
    place(single('portrait_frame_hi', 150), 420, 640, 'PORTRAIT'); place(group('PartyFrames'), 590, 655, 'PARTY')
    place(group('Raid5Frames'), 730, 670, 'RAID / ARENA'); place(compact('RaidFrames', .6), 760, 730, None)
    text('ORNAMENT STUDIES', 960, 646, 14, '#9a958a')
    for i in range(5): slot(960 + i * 108, 672, 92, 92, 'ornament')
    rule(800); text('4. ACTIONS, MINIMAP & PANELS', 28, 810, 18)
    for i in range(6): place(button(i < 2), 40 + i * 88, 880, 'ACTION BUTTONS' if i == 0 else None)
    place(single('config_button', 90), 590, 890, 'UTILITY'); place(single('icon_exit_flight', 90), 680, 890, None)
    m = place(single('minimap-border', 270), 820, 838, None); text('MINIMAP', 790, 846, 14, '#9a958a')
    slot((m[0] + m[2]) // 2 - 18, m[1] - 8, 36, 36, 'north')
    d.rectangle((1080, 850, 1330, 960), fill='#0c0d10', outline='#3a3e46', width=3); text('TOOLTIP', 1080, 826, 14, '#9a958a')
    for i in range(5): d.rectangle((1360, 830 + i * 34, 1500, 856 + i * 34), outline='#3a3e46', width=1)
    text('MATERIALS', 1360, 806, 14, '#9a958a')
    OUT.mkdir(parents=True, exist_ok=True)
    board.convert('RGB').save(OUT / 'concept-base.png')
    g = board.copy(); gd = ImageDraw.Draw(g)
    for x0, y0, x1, y1, label in guide_marks:
        gd.rectangle((x0, y0, x1, y1), outline='#00ffff', width=2)
        gd.text((x0 + 3, y1 + 2), label, font=ImageFont.truetype(FONT, 12), fill='#00ffff')
    g.convert('RGB').save(OUT / 'concept-base-guide.png')
    print(OUT / 'concept-base.png'); print(OUT / 'concept-base-guide.png')

def overlay(path):
    path = Path(path); base = Image.open(OUT / 'concept-base.png').convert('RGB')
    sheet = Image.open(path).convert('RGB').resize(base.size, S)
    edges = ImageChops.invert(base.convert('L').point(lambda v: 255 if v > 38 else 0)).convert('L')
    out = Image.blend(sheet, base, .35); tint = Image.new('RGB', base.size, '#00ffff')
    outline = base.convert('L').point(lambda v: 255 if v > 38 else 0)
    from PIL import ImageFilter
    ring = ImageChops.subtract(outline.filter(ImageFilter.MaxFilter(3)), outline)
    out.paste(tint, mask=ring); target = path.with_name(path.stem + '-overlay.png'); out.save(target); print(target)

if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--overlay': overlay(sys.argv[2])
    else: build()
