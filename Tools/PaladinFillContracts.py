"""Source-derived fill footprints for the reported Paladin fitting correction.

Player.lua currently draws the crystal at PowerBackdropSize, not legacy
PowerBarSize, and compensates its case anchor for that size delta. Keep this
offline contract separate from the historical global geometry templates.
"""
from pathlib import Path
import json
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14'
FIT = WORK/'Fill-Correction'
LAYOUTS = json.loads((WORK/'layouts.json').read_text())['original']
S = Image.Resampling.LANCZOS


def anchor(rect, size, pos):
    x,y,w,h = rect; sw,sh = size; token = pos[0]; dx,dy = pos[-2:]
    fx = 0 if 'LEFT' in token else 1 if 'RIGHT' in token else .5
    fy = 0 if 'TOP' in token else 1 if 'BOTTOM' in token else .5
    return x+fx*(w-sw)+dx, y+fy*(h-sh)-dy, sw,sh


def alpha(path, coords=None):
    im = Image.open(ROOT/'Assets'/path.replace('\\','/').split('/Assets/')[-1]).convert('RGBA').getchannel('A')
    if coords:
        l,r,t,b = coords; im = im.crop((round(l*im.width),round(t*im.height),round(r*im.width),round(b*im.height)))
    return im


def project(a, fill, case, canvas, flip=False):
    w,h = canvas
    x0,y0 = round((fill[0]-case[0])/case[2]*w), round((fill[1]-case[1])/case[3]*h)
    x1,y1 = round((fill[0]+fill[2]-case[0])/case[2]*w), round((fill[1]+fill[3]-case[1])/case[3]*h)
    mask = Image.new('L',canvas)
    mask.paste(a.resize((x1-x0,y1-y0),S),(x0,y0))
    return mask.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if flip else mask


def crystal_rects(db):
    bar = (0,0,*db['PowerBackdropSize'])
    pos = list(db['PowerBarForegroundPosition'])
    oldw,oldh = db['PowerBarSize']; w,h = db['PowerBackdropSize']; token = pos[0]
    hx = -1 if 'LEFT' in token else 1 if 'RIGHT' in token else 0
    vy = -1 if 'BOTTOM' in token else 1 if 'TOP' in token else 0
    pos[-2] -= hx*(w-oldw)*.5; pos[-1] -= vy*(h-oldh)*.5
    return bar,anchor(bar,db['PowerBarForegroundSize'],pos)


def mask(name, canvas):
    if name.startswith('pw_crystal_case'):
        base = LAYOUTS['PlayerFrame']; db = dict(base)
        db.update(base['Novice' if name.endswith('_low') else 'Seasoned'])
        bar,case = crystal_rects(db)
        # Native StatusBar's full-canvas silhouette is the one visible in the
        # supplied live screenshots. Treat the old requested texture crop as
        # legacy metadata, not a second enlarged crystal for the foreground.
        return ImageChops.lighter(project(alpha(db['PowerBarTexture']),bar,case,canvas),
                                  project(alpha(db['PowerBarTextureWrath']),bar,case,canvas))
    if name.startswith('hp_critter_case'):
        base = LAYOUTS['TargetFrame']; db = dict(base); db.update(base['Critter'])
        owner = (0,0,*base['Size'])
        return project(alpha(db['HealthBarTexture']),anchor(owner,db['HealthBarSize'],db['HealthBarPosition']),
                       anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition']),canvas,True)
    result = Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')
    return result if result.size == canvas else result.resize(canvas,S)


def crystal_overlap(name, foreground_alpha):
    """Foreground coverage of the WHOLE crystal, not its cropped lower slice.

    The casing canvas only intersects the bottom of the tall resource. Counting
    that clipped mask as the whole fill overstates overlap for concept-height jaws.
    """
    import numpy as np
    base = LAYOUTS['PlayerFrame']; db = dict(base)
    db.update(base['Novice' if name.endswith('_low') else 'Seasoned'])
    bar, case = crystal_rects(db)
    width, height = foreground_alpha.size
    pad_x, pad_y = width//2, height*2
    canvas = (width*2, height*4)
    full_case = (case[0]-pad_x*case[2]/width, case[1]-pad_y*case[3]/height,
                 canvas[0]*case[2]/width, canvas[1]*case[3]/height)
    fill = ImageChops.lighter(project(alpha(db['PowerBarTexture']), bar, full_case, canvas),
                             project(alpha(db['PowerBarTextureWrath']), bar, full_case, canvas))
    front = Image.new('L', canvas); front.paste(foreground_alpha, (pad_x, pad_y))
    inside = np.asarray(fill) > 128
    return float(((np.asarray(front) > 200) & inside).sum()/inside.sum())


def clearance_mask(name, canvas):
    result = mask(name,canvas)
    if name.startswith('cast_back'):
        # The same art serves meters with different native height/backdrop ratios.
        # Foreground clearance must cover every actual family, not only cast.
        for key in ('BossFrames','PetFrame','FocusFrame','ToTFrame','PartyFrames','Raid5Frames',
                    'RaidFrames','ArenaFrames','MirrorTimers'):
            db = LAYOUTS.get(key)
            if not db: continue
            pre = 'MirrorTimer' if key == 'MirrorTimers' else 'Health'
            bar = (0,0,*db[pre+'BarSize'])
            case = anchor(bar,db[pre+'BackdropSize'],db[pre+'BackdropPosition'])
            result = ImageChops.lighter(result,project(alpha(db[pre+'BarTexture']),bar,case,canvas))
        db = LAYOUTS['PlayerCastBar']; bar = (0,0,*db['CastBarSize'])
        result = ImageChops.lighter(result,project(alpha(db['CastBarTexture']),bar,
            anchor(bar,db['CastBarShieldSize'],db['CastBarShieldPosition']),canvas))
    return result


def write_guides():
    FIT.mkdir(parents=True,exist_ok=True)
    for name in ('cast_back','cast_back_spiked','cast_back_wooden','hp_critter_case','hp_critter_case_hi',
                 'pw_crystal_case','pw_crystal_case_low'):
        native = Image.open(ROOT/'Assets'/(name+'.tga')).convert('RGBA')
        fill = mask(name,native.size); fill.save(FIT/(name+'-fill.png'))
        clearance_mask(name,native.size).save(FIT/(name+'-clearance.png'))
        scale = max(1,1024//max(native.size)); guide = Image.new('RGBA',native.size,'#5a5a5a')
        guide.alpha_composite(native)
        guide.paste(Image.new('RGBA',native.size,'#ff00ff'),mask=fill.point(lambda v:v*150//255))
        guide = guide.resize((native.width*scale,native.height*scale),S)
        guide.convert('RGB').save(FIT/(name+'-guide.png'))


if __name__ == '__main__':
    write_guides()
