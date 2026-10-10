"""Export the geometry every theme must reproduce, measured from the original art.

Writes Docs/Theme Asset Geometry.json and one guide image per replaceable
casing in Docs/Research_Assets/Templates/. A themed texture that matches this
geometry is a drop-in replacement: no layout value changes with the theme.

Meter rectangles come from the original layout export
(Docs/Research_Assets/Paladin/Revision5/layouts.json, key "original").
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'Assets'
OUT = ROOT / 'Docs/Research_Assets/Templates'
LAYOUT = json.loads((ROOT / 'Docs/Research_Assets/Paladin/Revision5/layouts.json').read_text())['original']

CASINGS = ['hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case', 'hp_critter_case', 'hp_critter_case_hi',
           'cast_back', 'cast_back_spiked', 'cast_back_wooden', 'nameplate_backdrop', 'pw_crystal_case',
           'pw_crystal_case_low', 'orb_case_hi', 'orb_case_low', 'orb-border', 'portrait_frame_hi',
           'portrait_frame_lo', 'party_portrait_border', 'actionbutton-border',
           'actionbutton-border-square', 'actionbutton-border-square-rounded', 'minimap-border',
           'minimap-onebar-backdrop', 'minimap-twobars-backdrop', 'point_plate', 'config_button',
           'config_button_bright', 'icon_exit_flight', 'options-box', 'border-tooltip', 'border-aura',
           'better-blizzard-border-small-alternate']

def anchor(rect, size, pos):
    point = pos[0]; dx, dy = pos[-2:]; x, y, w, h = rect; sw, sh = size
    fx = 0 if 'LEFT' in point else 1 if 'RIGHT' in point else .5
    fy = 0 if 'TOP' in point else 1 if 'BOTTOM' in point else .5
    return (x + fx * (w - sw) + dx, y + fy * (h - sh) - dy, sw, sh)

def meter(name, canvas):
    """Meter rectangle in canvas pixels for casings whose opening is painted, not transparent."""
    w, h = canvas
    def within(bar, back, flip=False):
        l = (bar[0] - back[0]) / back[2] * w; t = (bar[1] - back[1]) / back[3] * h
        r = l + bar[2] / back[2] * w; b = t + bar[3] / back[3] * h
        if flip: l, r = w - r, w - l
        return [round(l), round(t), round(r), round(b)]
    tiers = {'hp_cap_case': ('PlayerFrame', 'Seasoned'), 'hp_mid_case': ('PlayerFrame', 'Hardened'),
             'hp_low_case': ('PlayerFrame', 'Novice'), 'hp_boss_case': ('TargetFrame', 'Boss')}
    if name in tiers:
        kind, tier = tiers[name]; base = LAYOUT[kind]; db = dict(base); db.update(base.get(tier, {}))
        if name not in db['HealthBackdropTexture']: return None
        owner = (0, 0, *base['Size'])
        return within(anchor(owner, db['HealthBarSize'], db['HealthBarPosition']),
                      anchor(owner, db['HealthBackdropSize'], db['HealthBackdropPosition']), kind == 'TargetFrame')
    if name.startswith('cast_back'):
        db = LAYOUT['PlayerCastBar']; bar = (0, 0, *db['CastBarSize'])
        return within(bar, anchor(bar, db['CastBarBackgroundSize'], db['CastBarBackgroundPosition']))
    # nameplate_backdrop is a backing the same size as the fill, not a frame around it.
    return None

def hole(im):
    a = im.getchannel('A').point(lambda v: 255 if v > 64 else 0)
    seed = (im.width // 2, im.height // 2)
    if a.getpixel(seed): return None
    ImageDraw.floodfill(a, seed, 128)
    return list(a.point(lambda v: 255 if v == 128 else 0).getbbox())

def fillmask(name, canvas):
    """Where the fill is drawn, in this casing's canvas: the fill texture's own alpha at its layout rectangle."""
    w, h = canvas; S = Image.Resampling.LANCZOS
    def alpha(texture, coords=None):
        im = Image.open(ASSETS / texture.replace('\\', '/').split('/Assets/')[-1]).convert('RGBA').getchannel('A')
        if coords:
            l, r, t, b = coords; im = im.crop((round(l * im.width), round(t * im.height), round(r * im.width), round(b * im.height)))
        return im
    def paste(a, fill, back, flip=False):
        box = [round((fill[0] - back[0]) / back[2] * w), round((fill[1] - back[1]) / back[3] * h),
               round((fill[0] + fill[2] - back[0]) / back[2] * w), round((fill[1] + fill[3] - back[1]) / back[3] * h)]
        mask = Image.new('L', canvas); mask.paste(a.resize((box[2] - box[0], box[3] - box[1]), S), box[:2])
        return mask.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if flip else mask
    tiers = {'hp_cap_case': ('PlayerFrame', 'Seasoned'), 'hp_mid_case': ('PlayerFrame', 'Hardened'),
             'hp_low_case': ('PlayerFrame', 'Novice'), 'hp_boss_case': ('TargetFrame', 'Boss')}
    P = dict(LAYOUT['PlayerFrame']); P.update(LAYOUT['PlayerFrame']['Seasoned'])
    if name in tiers:
        kind, tier = tiers[name]; base = LAYOUT[kind]; db = dict(base); db.update(base.get(tier, {}))
        owner = (0, 0, *base['Size'])
        return paste(alpha(db['HealthBarTexture']), anchor(owner, db['HealthBarSize'], db['HealthBarPosition']),
                     anchor(owner, db['HealthBackdropSize'], db['HealthBackdropPosition']), kind == 'TargetFrame')
    if name.startswith('cast_back'):
        db = LAYOUT['PlayerCastBar']; bar = (0, 0, *db['CastBarSize'])
        return paste(alpha(db['CastBarTexture']), bar, anchor(bar, db['CastBarBackgroundSize'], db['CastBarBackgroundPosition']))
    if name == 'nameplate_backdrop':
        db = LAYOUT['NamePlates']; bar = (0, 0, *db['HealthBarSize'])
        return paste(alpha(db['HealthBarTexture'], db['HealthBarTexCoord']), bar, anchor(bar, db['HealthBackdropSize'], db['HealthBackdropPosition']))
    if name in ('orb_case_hi', 'orb_case_low'):
        orb = (0, 0, *P['ManaOrbSize'])
        return paste(alpha('Interface/Assets/orb2.tga'), orb, anchor(orb, P['ManaOrbForegroundSize'], P['ManaOrbForegroundPosition']))
    if name in ('pw_crystal_case', 'pw_crystal_case_low'):
        bar = (0, 0, *P['PowerBarSize'])
        return paste(alpha(P['PowerBarTexture'], P['PowerBarTexCoord']), bar, anchor(bar, P['PowerBarForegroundSize'], P['PowerBarForegroundPosition']))
    if name in ('actionbutton-border-square', 'actionbutton-border-square-rounded'):
        # Same shaped config as Core/API/Assets.lua, no per-theme geometry.
        deco = 93.1 if name.endswith('rounded') else 96.3
        mask = 'actionbutton-mask-square-rounded.tga' if name.endswith('rounded') else 'actionbutton-mask-square.tga'
        return paste(alpha('Interface/Assets/' + mask), (2, 2, 60, 60),
                     ((64-deco)/2, (64-deco)/2, deco, deco))
    if name == 'actionbutton-border':
        db = LAYOUT['ActionButton']; rect = (0, 0, *db['ButtonSize'])
        return paste(alpha(db['ButtonMaskTexture']), anchor(rect, db['ButtonIconSize'], db['ButtonIconPosition']),
                     anchor(rect, db['ButtonBorderSize'], db['ButtonBorderPosition']))
    return None

def main():
    OUT.mkdir(parents=True, exist_ok=True); spec = {}
    for name in CASINGS:
        im = Image.open(ASSETS / (name + '.tga')).convert('RGBA')
        painted = list(im.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox())
        item = {'canvas': list(im.size), 'painted': painted}
        atlas = name.startswith(('border-', 'better-'))  # edge atlases have cells, not one opening
        opening = None if atlas else hole(im); rect = meter(name, im.size)
        if opening: item['opening'] = opening
        if rect: item['meter'] = rect
        spec[name] = item
        # Guide: the original on mid grey, painted bounds in cyan, opening or meter in magenta.
        s = max(1, 1024 // max(im.size)); big = im.resize((im.width * s, im.height * s), Image.Resampling.LANCZOS)
        guide = Image.new('RGBA', big.size, '#5a5a5a'); guide.alpha_composite(big); d = ImageDraw.Draw(guide)
        d.rectangle([v * s for v in painted], outline='#00ffff', width=2)
        for box in (opening, rect):
            if box: d.rectangle([v * s for v in box], outline='#ff00ff', width=2)
        mask = fillmask(name, im.size)
        if mask and mask.getbbox():
            # The fill's exact contour: white on black, and tinted magenta on the guide.
            mask.save(OUT / (name + '-fill.png')); item['fill'] = list(mask.getbbox())
            big_mask = mask.resize(big.size, Image.Resampling.LANCZOS).point(lambda v: v * 110 // 255)
            guide.paste(Image.new('RGBA', big.size, '#ff00ff'), mask=big_mask)
        guide.convert('RGB').save(OUT / (name + '-guide.png'))
        big.save(OUT / (name + '.png'))
    (ROOT / 'Docs/Theme Asset Geometry.json').write_text(json.dumps(spec, indent=1) + '\n', encoding='utf-8')
    for name, item in spec.items(): print(name, item)

if __name__ == '__main__': main()
