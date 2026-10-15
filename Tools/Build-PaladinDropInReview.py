"""Source-layout review of the exported Paladin suite, not a WoW screenshot.

Uses the real harness export, exact native fill textures and generated exports.
The measured crystal holder is the literal concept cutout explicitly requested
after live review; the other suite art retains its separate painted sources.
"""
from pathlib import Path
import importlib.util
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageChops
from PaladinFillContracts import crystal_rects

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14'
EXPORT = WORK/'Export'
LAYOUTS = json.loads((WORK/'layouts.json').read_text())
loader = importlib.util.spec_from_file_location('base', ROOT/'Tools/Build-ThemeConceptBase.py')
B = importlib.util.module_from_spec(loader)
loader.loader.exec_module(B)
NATIVE_ASSET = B.asset
FONT = 'C:/Windows/Fonts/segoeui.ttf'
HEALTH_TERMINAL = False


def asset(path):
    if path and '/Paladin/' in path.replace('\\','/'):
        name = path.replace('\\','/').split('/')[-1]
        if HEALTH_TERMINAL and name in ('hp_cap_case.tga','hp_mid_case.tga','hp_low_case.tga','hp_boss_case.tga'):
            name = name[:-4]+'-capped.tga'
        return Image.open(EXPORT/name).convert('RGBA')
    return NATIVE_ASSET(path)


B.asset = asset
NATIVE_POWER = B.power


def current_power(scene, owner, db, fraction, resource, light_strength=0):
    if resource == 'orb': return NATIVE_POWER(scene,owner,db,fraction,resource)
    # Mirror Player.lua's current backdrop-sized crystal and case compensation.
    # This is shared native geometry, not a Paladin offset to fit artwork.
    rect = B.anchor(owner,db['PowerBackdropSize'],db['PowerBarPosition'])
    rect = (rect[0]-37,rect[1]+28,*rect[2:])  # current stock baseline offsets
    local_bar,local_case = crystal_rects(db)
    case = (rect[0]+local_case[0],rect[1]+local_case[1],*local_case[2:])
    B.put(scene,asset(db['PowerBackdropTexture']),rect)
    themed = '/Paladin/' in db['PowerBarForegroundTexture'].replace('\\','/')
    B.fill(scene,db['PowerBarTexture'],rect,fraction,db['PowerBarColors']['MANA'],vertical=True)
    if themed and light_strength:
        # Include the peak of Paladin's low-opacity native-facet pulse in visual
        # checks; omitting the effect hid the old broad ribbon problem.
        glow = Image.new('RGBA', scene.size)
        B.fill(glow, db['PowerBarTexture'], rect, fraction, (1, 1, 1), vertical=True)
        glow.putalpha(glow.getchannel('A').point(lambda a: round(a*light_strength)))
        scene.alpha_composite(glow)
    B.put(scene,asset(db['PowerBarForegroundTexture']),case,tint=db['PowerBarForegroundColor'])


B.power = current_power


def current_compact(name, fraction=1, c=B.GREEN):
    # Mirror actual boss growth and front rails instead of the concept base's
    # always-right fill. This review must expose orientation at partial values.
    db = B.DATA[name]
    pre = 'MirrorTimer' if name == 'MirrorTimers' else 'Health'
    scene = Image.new('RGBA', (400, 200))
    bar = (120, 90, *db[pre+'BarSize'])
    rect = B.anchor(bar, db[pre+'BackdropSize'], db[pre+'BackdropPosition'])
    flip = db.get(pre+'BarOrientation') == 'LEFT'
    path = db[pre+'BackdropTexture']
    B.put(scene, asset(path), rect, flip, db[pre+'BackdropColor'])
    B.fill(scene, db[pre+'BarTexture'], bar, fraction, c, flip)
    if '/Paladin/' in path.replace('\\', '/'):
        over(scene, Path(path.replace('\\', '/')).stem, rect, flip)
    return scene


B.compact = current_compact


def over(scene, name, rect, flip=False):
    p = EXPORT/(name+'-over.tga')
    if p.exists():
        B.put(scene, Image.open(p).convert('RGBA'), rect, flip)


def ornament(scene, name, rect, size, dx, flip=False, tint=None):
    p = EXPORT/(name+'.tga')
    if not p.exists(): return
    x, y, w, h = rect
    cx = x-dx if flip else x+w+dx
    B.put(scene, Image.open(p).convert('RGBA'), (cx-size/2, y+h/2-size/2, size, size), flip, tint)


def unit(kind, tier, fraction, resource=None, themed=True, endcap=True, threat=False):
    global HEALTH_TERMINAL
    B.DATA = LAYOUTS['paladin' if themed else 'original']
    HEALTH_TERMINAL = themed and endcap
    scene = B.unit(kind, tier, fraction, resource)
    HEALTH_TERMINAL = False
    base = B.DATA[kind]; db = dict(base); db.update(base.get(tier, {}))
    owner = (150,80,*(base.get('Size') or [550,210]))
    bar = B.anchor(owner, db['HealthBarSize'], db['HealthBarPosition'])
    rect = B.anchor(owner, db['HealthBackdropSize'], db['HealthBackdropPosition'])
    flip = kind == 'TargetFrame'
    name = Path(db['HealthBackdropTexture'].replace('\\','/')).stem
    if themed and endcap and name in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case'):
        name += '-capped'
    if themed and threat:
        glow = Image.new('RGBA',scene.size)
        B.put(glow,asset('Interface/Assets/Paladin/'+name+'-glow.tga'),rect,flip,(1,.2,.06))
        if db.get('PortraitBorderTexture'):
            portrait_name=Path(db['PortraitBorderTexture'].replace('\\','/')).stem
            B.put(glow,asset('Interface/Assets/Paladin/'+portrait_name+'-glow.tga'),
                  B.anchor(owner,db['PortraitBorderSize'],db['PortraitBorderPosition']),tint=(1,.2,.06))
        if endcap and bar[2]>=bar[3]*2:
            ornament(glow,'ornament-ashbringer-glow',bar,88*1.3*bar[3]/40,14*bar[3]/40,flip,(1,.2,.06))
        glow.alpha_composite(scene)
        scene=glow
    if themed:
        over(scene, name, rect, flip)
        if endcap and bar[2] >= bar[3]*2:
            ornament(scene, 'ornament-ashbringer', bar, 88*1.3*bar[3]/40, 14*bar[3]/40, flip)
    return scene


def cast(fraction, themed=True, protected=False, endcap=True):
    db = LAYOUTS['paladin' if themed else 'original']['PlayerCastBar']
    scene = Image.new('RGBA',(500,300))
    bar = (190,140,*db['CastBarSize'])
    prefix = 'CastBarShield' if protected else 'CastBarBackground'
    rect = B.anchor(bar, db[prefix+'Size'], db[prefix+'Position'])
    B.put(scene, asset(db[prefix+'Texture']), rect, tint=db[prefix+'Color'])
    B.fill(scene, db['CastBarTexture'], bar, 1, B.DARK)
    B.fill(scene, db['CastBarTexture'], bar, fraction, (.8,.2,.12) if protected else db['CastBarColor'])
    if themed:
        # Ordinary front lip disappears with native backdrop during protected casts.
        if not protected: over(scene, 'cast_back', rect)
        # Runtime anchors to LEFT at x=-26, without mirroring the book artwork.
        if endcap:
            B.put(scene, asset('Interface/Assets/Paladin/cast-head-libram.tga'),
                  (bar[0]-26-24,bar[1]+bar[3]/2-24,48,48))
    return scene


def label(canvas, text, xy, size=18):
    ImageDraw.Draw(canvas).text(xy, text, font=ImageFont.truetype(FONT,size), fill='#c4beac')


def paste_trim(canvas, im, xy, scale=1):
    art = im.crop(im.getbbox())
    if scale != 1: art = art.resize((round(art.width*scale),round(art.height*scale)),B.S)
    canvas.alpha_composite(art,xy)


def assemblies():
    scenarios = [('PlayerFrame',t,'crystal') for t in ['Novice','Hardened','Seasoned']]
    scenarios += [('PlayerFrame','Seasoned','orb'), ('PlayerFrameAlternate','Seasoned',None)]
    scenarios += [('TargetFrame',t,None) for t in ['Novice','Hardened','Seasoned','Boss','Critter']]
    for page in range(2):
        cases = scenarios[page*5:(page+1)*5]
        canvas = Image.new('RGBA',(1800,1650),'#14161a')
        label(canvas, 'PALADIN: REAL EXPORTED ART / NATIVE LAYOUT - EMPTY, PARTIAL, FULL', (28,18),24)
        label(canvas, 'Offline reconstruction; no live portraits, animation or combat. No per-theme geometry.', (28,58),16)
        for row,(kind,tier,res) in enumerate(cases):
            y = 105+row*305
            label(canvas, f'{kind} / {tier} / {res or "portrait"}', (28,y))
            for col,f in enumerate([0,.4,1]):
                x = 28+col*590
                label(canvas, f'{int(f*100)}%', (x,y+30),16)
                paste_trim(canvas, unit(kind,tier,f,res), (x,y+65))
        canvas.convert('RGB').save(WORK/f'Assemblies-{page+1}.png')
    canvas = Image.new('RGBA',(1800,1480),'#14161a')
    label(canvas,'PALADIN: COMPACT FRAMES, CASTS, CLASS POWER AND BUTTONS',(28,18),24)
    B.DATA = LAYOUTS['paladin']
    compact = ['PetFrame','FocusFrame','ToTFrame','RaidFrames','MirrorTimers']
    for row,name in enumerate(compact):
        y = 75+row*115; label(canvas,name,(28,y))
        for col,f in enumerate([0,.4,1]):
            paste_trim(canvas,B.compact(name,f),(320+col*320,y),2)
    for col,f in enumerate([0,.4,1]):
        paste_trim(canvas,cast(f),(40+col*300,710),2)
    label(canvas,'Cast / normal',(28,660))
    paste_trim(canvas,cast(.6,protected=True),(1020,710),2)
    label(canvas,'Protected cast: native shield',(1020,660))
    for col,name in enumerate(['PartyFrames','Raid5Frames','ArenaFrames']):
        paste_trim(canvas,B.group(name),(28+col*280,950),1.4)
    for i in range(6):
        paste_trim(canvas,B.points(i),(1040+i*115,880),.9)
    for i,name in enumerate(['actionbutton-border','actionbutton-border-square','actionbutton-border-square-rounded']):
        im = Image.open(EXPORT/(name+'.tga')).convert('RGBA')
        paste_trim(canvas,im,(80+i*240,1230),1.2)
    label(canvas,'Circle / Square / Rounded (native aperture and alpha)',(28,1170))
    canvas.convert('RGB').save(WORK/'Assemblies-3.png')


def raw():
    spec = json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
    names = list(spec)
    names += ['options-casing-round','options-well-round']
    for page in range(math.ceil(len(names)/8)):
        canvas = Image.new('RGBA',(1600,1280),'#14161a')
        label(canvas,'NATIVE / PALADIN: ALL CASING VARIANTS, SAME CANVAS AND ALPHA',(28,18),24)
        for row,name in enumerate(names[page*8:(page+1)*8]):
            y = 82+row*146
            label(canvas,name,(28,y),16)
            for col,folder in enumerate([ROOT/'Assets',EXPORT]):
                im = Image.open(folder/(name+'.tga')).convert('RGBA')
                im.thumbnail((700,100),B.S)
                canvas.alpha_composite(im,(28+col*780,y+25))
        canvas.convert('RGB').save(WORK/f'Casings-{page+1}.png')


def resources():
    B.DATA = LAYOUTS['paladin']
    canvas = Image.new('RGBA',(1500,1220),'#14161a')
    label(canvas,'PALADIN RESOURCES: NATIVE FILL / GLASS / CRADLE - 0%, 40%, 100%',(28,18),22)
    for row,(kind,tier) in enumerate([('crystal','Novice'),('crystal','Seasoned'),('orb','Novice'),('orb','Seasoned')]):
        y = 80+row*250; label(canvas,f'{kind} / {tier}',(28,y))
        for col,fraction in enumerate([0,.4,1]):
            db = dict(B.DATA['PlayerFrame']); db.update(db[tier])
            scene = Image.new('RGBA',(900,500))
            B.power(scene,(300,150,*B.DATA['PlayerFrame']['Size']),db,fraction,kind)
            paste_trim(canvas,scene,(70+col*430,y+45),1.1)
    label(canvas,'NAMEPLATE HEALTH / CAST: NATIVE BACKING ONLY',(28,1080))
    paste_trim(canvas,B.nameplate(),(40,1125),3)
    canvas.convert('RGB').save(WORK/'Resources.png')


def tooltip():
    def frame(w,h,file='border-tooltip',edge=32):
        native = Image.open(EXPORT/(file+'.tga')).convert('RGBA')
        cell = native.height; gutter = cell//16
        im = Image.new('RGBA',(w,h))
        ImageDraw.Draw(im).rectangle((10,18,w-10,h-18),fill=(13,13,14,245))
        # Backdrop.lua uses the per-cell gutters (UV .0078125/.0625),
        # never the whole atlas cell. Edge UVs rotate the horizontal strips.
        parts = [native.crop((i*cell+gutter,gutter,(i+1)*cell-gutter,cell-gutter)).resize((edge,edge),B.S) for i in range(8)]
        # Blizzard atlas order: left, right, top, bottom, TL, TR, BL, BR.
        for i,rect in [(0,(0,edge,edge,h-edge)),(1,(w-edge,edge,w,h-edge)),
                       (2,(edge,0,w-edge,edge)),(3,(edge,h-edge,w-edge,h))]:
            part = parts[i].transpose(Image.Transpose.ROTATE_270) if i in (2,3) else parts[i]
            # Tile the straight rails, never stretch their grain with panel size.
            x0,y0,x1,y1 = rect
            for y in range(y0,y1,edge):
                for x in range(x0,x1,edge):
                    im.alpha_composite(part.crop((0,0,min(edge,x1-x),min(edge,y1-y))),(x,y))
        for i,xy in [(4,(0,0)),(5,(w-edge,0)),(6,(0,h-edge)),(7,(w-edge,h-edge))]: im.alpha_composite(parts[i],xy)
        return im
    canvas = Image.new('RGBA',(1500,920),'#14161a')
    label(canvas,'PALADIN TOOLTIPS: ACTUAL EXPORTED EIGHT-CELL ATLAS',(28,18),24)
    for i,(w,h,title) in enumerate([(330,170,'Holy Light'),(400,290,'Sacred Steel'),(300,235,'Equipped'),(300,235,'Tempered Plate')]):
        panel = frame(w,h); label(panel,title,(22,24),22)
        label(panel,'Readable text on native dark background',(22,66),14)
        canvas.alpha_composite(panel,([(40,100),(460,100),(120,470),(450,470)])[i])
    canvas.convert('RGB').save(WORK/'Tooltips.png')
    panel = Image.new('RGBA',(1150,850),'#14161a')
    label(panel,'ROUNDED OPTIONS: ACTUAL PALADIN ATLASES / NATIVE CORNER ALPHA',(28,18),22)
    panel.alpha_composite(frame(980,650,'options-casing-round'),(70,100))
    panel.alpha_composite(frame(230,430,'options-well-round',10),(110,225))
    label(panel,'THEMES',(380,155),24)
    label(panel,'Paladin - Ashbringer / Silver Hand',(380,215),22)
    label(panel,'Health endcap / cast head placement',(380,280),20)
    label(panel,'Holy Light strength',(380,330),20)
    label(panel,'Shared icons, fonts and controls remain native.',(380,440),17)
    panel.convert('RGB').save(WORK/'Rounded-Options.png')


def fitting_review():
    B.DATA = LAYOUTS['paladin']
    board = Image.new('RGBA',(1500,1490),'#14161a')
    label(board,'PALADIN FILL FIT / LAYER CORRECTION - 0%, 40%, 100%',(24,18),23)
    label(board,'Offline reconstruction: native anchors/fills; inner-lip registration, separate crystal backing.',(24,52),16)
    for row,key in enumerate(('BossFrames','PetFrame','FocusFrame','ToTFrame','RaidFrames','MirrorTimers')):
        y = 95+row*105; label(board,key,(24,y))
        for col,fraction in enumerate((0,.4,1)):
            paste_trim(board,B.compact(key,fraction),(230+col*380,y),2)
    for row,name in enumerate(('hp_critter_case','hp_critter_case_hi')):
        y = 745+row*130; label(board,name,(24,y))
        base = B.DATA['TargetFrame']; db = dict(base); db.update(base['Critter'])
        owner = (150,80,*base['Size']); bar = B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
        case = B.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
        for col,fraction in enumerate((0,.4,1)):
            scene = Image.new('RGBA',(900,360))
            B.put(scene,Image.open(EXPORT/(name+'.tga')).convert('RGBA'),case,True)
            B.fill(scene,db['HealthBarTexture'],bar,fraction,B.RED,True)
            paste_trim(board,scene,(230+col*380,y),1.1)
    label(board,'Crystal: dark backing below fill / silver-gold lip above',(24,1040),20)
    for row,ice in enumerate((False,True)):
        db = dict(B.DATA['PlayerFrame']); db.update(db['Seasoned'])
        if ice:
            db['PowerBarTexture'] = db['PowerBarTextureWrath']; db['PowerBackdropTexture'] = db['PowerBackdropTextureWrath']
            db['PowerBarColors'] = {'MANA':(1,1,1)}
        for col,fraction in enumerate((0,.4,1)):
            scene = Image.new('RGBA',(900,500))
            current_power(scene,(300,150,*B.DATA['PlayerFrame']['Size']),db,fraction,'crystal')
            paste_trim(board,scene,(220+col*390,1085+row*180),.95)
    board.convert('RGB').save(WORK/'Fill-Correction/Review.png')


def concept_cradle_review():
    """Approved reference beside runtime-sized source-layout reconstructions."""
    B.DATA = LAYOUTS['paladin']
    folder = WORK/'Concept-Cradle'
    folder.mkdir(exist_ok=True)
    board = Image.new('RGBA', (1500, 1230), '#14161a')
    label(board, 'CONCEPT CRADLE / NATIVE WIDTH LIMIT / UNIFORM ASPECT', (24, 18), 23)
    label(board, 'Offline reconstruction; complete painting, unchanged native resource and anchors.', (24, 54), 16)
    reference = Image.open(WORK/'approved-concept.png').convert('RGBA').crop((64, 432, 212, 605))
    label(board, 'Approved reference', (28, 100), 18)
    board.alpha_composite(reference, (45, 138))
    label(board, '0%', (315, 100)); label(board, '40%', (700, 100)); label(board, '100%', (1085, 100))
    for row, (tier, ice) in enumerate((('Novice', False), ('Seasoned', False), ('Novice', True), ('Seasoned', True))):
        y = 145+row*250
        if row: label(board, tier+(' / ice' if ice else ' / native'), (28, y+30), 18)
        else: label(board, 'Novice / native', (28, 335), 18)
        db = dict(B.DATA['PlayerFrame']); db.update(db[tier])
        if ice:
            db['PowerBarTexture'] = db['PowerBarTextureWrath']
            db['PowerBackdropTexture'] = db['PowerBackdropTextureWrath']
            db['PowerBarColors'] = {'MANA': (1, 1, 1)}
        for col, fraction in enumerate((0, .4, 1)):
            scene = Image.new('RGBA', (900, 500))
            current_power(scene, (300, 150, *B.DATA['PlayerFrame']['Size']), db, fraction, 'crystal', light_strength=.1)
            paste_trim(board, scene, (300+col*385, y), 1.1)
    fits = json.loads((WORK/'manifest.json').read_text())['crystalFit']
    for i, name in enumerate(('pw_crystal_case', 'pw_crystal_case_low')):
        fit = fits[name]; actual = fit['painted']; native = fit['nativePainted']
        label(board, f"{name}: painted width {actual[2]-actual[0]} / native {native[2]-native[0]} px", (28, 1160+i*28), 16)
    board.convert('RGB').save(folder/'Assemblies.png')


def concept_frames_review():
    board = Image.new('RGBA', (1400, 1070), '#14161a')
    label(board, 'APPROVED CONCEPT / NATIVE-LAYOUT RECONSTRUCTION', (24, 18), 24)
    label(board, 'Offline art review. Portrait model omitted. Native fills, meter sizes and saved anchors retained.', (24, 58), 16)
    reference = Image.open(WORK/'approved-concept.png').convert('RGBA')
    label(board, 'Concept pixels', (28, 100), 19)
    label(board, 'Exported textures / default endcap sizes', (720, 100), 19)
    cases = [('Player', (55,195,590,375), unit('PlayerFrame','Seasoned',1,'crystal'), 145),
             ('Target', (574,165,1097,310), unit('TargetFrame','Seasoned',1), 390),
             ('Cast', (1200,198,1361,248), cast(.6), 615)]
    for text, crop, actual, y in cases:
        label(board, text, (28,y), 18)
        board.alpha_composite(reference.crop(crop), (28,y+30))
        paste_trim(board, actual, (720,y+30))
    label(board, 'Endcaps OFF: the underlying casing and functional bar remain complete', (28, 760), 20)
    paste_trim(board, unit('PlayerFrame','Seasoned',.6,'crystal',endcap=False), (28,805))
    paste_trim(board, cast(.6,endcap=False), (720,855), 2)
    board.convert('RGB').save(WORK/'Concept-Frames/Comparison.png')


def contour_review():
    board = Image.new('RGBA',(1600,980),'#14161a')
    label(board,'ENDCAPS OFF / ORIGINAL SHAPE AND DIP',(28,18),26)
    label(board,'Offline reconstruction using the same native fill, canvas, scale and anchors in both columns.',(28,62),17)
    label(board,'OG AzeriteUI',(28,108),21)
    label(board,'Paladin concept material / OG contour',(810,108),21)
    cases = [('PlayerFrame','Seasoned',1),('TargetFrame','Seasoned',1),
             ('PlayerFrame','Seasoned',.4),('TargetFrame','Boss',.4)]
    for row,(kind,tier,fraction) in enumerate(cases):
        y=160+row*195
        label(board,f'{kind} / {tier} / {int(fraction*100)}%',(28,y),18)
        for col,themed in enumerate((False,True)):
            scene=unit(kind,tier,fraction,themed=themed,endcap=False)
            paste_trim(board,scene,(28+col*782,y+40),1.2)
    folder=WORK/'Contour-Repair';folder.mkdir(exist_ok=True)
    board.convert('RGB').save(folder/'Comparison.png')


def hd_review():
    folder=WORK/'HD-Repair'
    board=Image.new('RGBA',(1600,1300),'#14161a')
    label(board,'HD SOURCES / NATIVE CANVASES / FITTED THREAT OUTLINES',(28,20),24)
    label(board,'Offline reconstruction; enlarged exports for detail, native-layout views below. No live threat or portrait model.',(28,60),16)
    columns=[('Old endcap','ornament-ashbringer',True),('HD endcap','ornament-ashbringer',False),
             ('Old portrait','portrait_frame_hi',True),('HD portrait','portrait_frame_hi',False)]
    for col,(text,name,before) in enumerate(columns):
        x=28+col*395
        label(board,text,(x,110),20)
        path=folder/(name+'-before.tga') if before else EXPORT/(name+'.tga')
        im=Image.open(path).convert('RGBA')
        B.put(board,im,(x,155,320,320))
    label(board,'Normal / native geometry',(28,510),20)
    label(board,'Threat shown / final silhouettes',(810,510),20)
    for row,(kind,cap) in enumerate((('PlayerFrame',True),('TargetFrame',True),('TargetFrame',False))):
        y=560+row*235
        label(board,kind+(' / endcap ON' if cap else ' / endcap OFF'),(28,y),18)
        for col,threat in enumerate((False,True)):
            paste_trim(board,unit(kind,'Seasoned',.65,endcap=cap,threat=threat),(28+col*782,y+38),1.15)
    board.convert('RGB').save(folder/'Comparison.png')


if __name__ == '__main__':
    assemblies(); raw(); resources(); tooltip(); fitting_review(); concept_cradle_review()
    concept_frames_review()
    contour_review()
    hd_review()
    print('Three assembly pages, five casing pages, resource states and actual tooltip atlas review written.')
