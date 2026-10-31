"""Render exported Shaman textures with native layout rectangles, not concept crops."""
from pathlib import Path
import copy
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import importlib.util

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Shaman'
OUT = ROOT/'Assets_Draft/Shaman'
S = Image.Resampling.LANCZOS


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Tools'/filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


M = module('shaman_renderer', 'Build-ImplementedThemeSheets.py')
B = M.B
CASES = {'Novice': 'hp_low_case', 'Hardened': 'hp_mid_case', 'Seasoned': 'hp_cap_case', 'Boss': 'hp_boss_case'}
CAPS = ('maelstrom', 'tides', 'lava')


class Renderer(M.Renderer):
    def __init__(self):
        self.theme = 'Shaman'
        self.sources = {}
        self.media = {p.stem for p in OUT.glob('*.tga')}
        self.data = copy.deepcopy(M.DATA)
        self.replace(self.data)

    def asset(self, path):
        if path is None:
            return None
        relative = path.replace('\\','/').split('/Assets/')[-1]
        source = OUT/relative.split('/',1)[1] if relative.startswith('Shaman/') else ROOT/'Assets'/relative
        self.sources[source.relative_to(ROOT).as_posix()] = M.hashlib.sha256(source.read_bytes()).hexdigest()
        return Image.open(source).convert('RGBA')

    def resource(self, kind, fraction=1, scene=None, owner=None):
        if kind=='orb': return super().resource(kind,fraction,scene,owner)
        # Player.lua uses the complete native backdrop-sized StatusBar and
        # compensates the holder for the legacy 120x140-to-196x196 delta.
        # PaladinFillContracts records that actual native draw relationship.
        P=module('shaman_review_crystal_projection','PaladinFillContracts.py')
        scene=scene if scene is not None else Image.new('RGBA',(800,500))
        db=self.config();owner=owner or (200,150,*db['Size'])
        rect=B.anchor(owner,db['PowerBackdropSize'],db['PowerBarPosition'])
        self.texture(scene,db['PowerBackdropTexture'],rect)
        self.fill(scene,db['PowerBarTexture'],rect,fraction,db['PowerBarColors']['MANA'],vertical=True)
        _,relative=P.crystal_rects(db)
        self.texture(scene,db['PowerBarForegroundTexture'],(rect[0]+relative[0],rect[1]+relative[1],relative[2],relative[3]),db['PowerBarForegroundColor'])
        return scene

    def health(self, flip=False, cap=True, fraction=1, resource=None, tier='Seasoned', choice='maelstrom', prediction=False, before=False, cap_scale=1, cap_offset=(0,0)):
        base = self.data['TargetFrame' if flip else 'PlayerFrame']
        db = dict(base)
        db.update(base[tier])
        scene = Image.new('RGBA', (1300,600))
        owner = (280,200,*db['Size'])
        hp = B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
        casing = B.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
        name = CASES[tier]
        revision=WORK/'Live-Repair-2026-10-18/Before/Assets_Draft/Shaman'
        prior=revision if revision.exists() else WORK/'Terminal-Repair/Before'
        self.put(scene,self.own(name),casing,flip)
        self.fill(scene,db['HealthBarTexture'],hp,1,M.COLORS['dark'],flip)
        if prediction:
            # Synthetic shaped prediction/absorb coverage, not live unit data.
            self.fill(scene,db['HealthBarTexture'],hp,min(1,fraction+.2),(.25,.58,.65),flip)
        self.fill(scene,db['HealthBarTexture'],hp,fraction,M.COLORS['red'],flip)
        front=Image.open(prior/(name+'-over.tga')).convert('RGBA') if before and (prior/(name+'-over.tga')).exists() else self.own(name+'-over')
        self.put(scene,front,casing,flip)
        if cap:
            cap_name='ornament-'+choice+'-'+name
            image = Image.open(prior/(cap_name+'.tga')).convert('RGBA') if before else self.own(cap_name)
            px,py = {'hp_cap_case':(754/1024,187/256),'hp_mid_case':(757/1024,181/256),
                     'hp_low_case':(756.5/1024,181/256),'hp_boss_case':(872.5/1024,188/256)}[name]
            if flip:
                px=1-px
            x,y,w,h=casing
            dx,dy=cap_offset
            cap_rect=(x+px*w*(1-cap_scale)+(-dx if flip else dx),y+py*h*(1-cap_scale)-dy,w*cap_scale,h*cap_scale)
            self.put(scene,image,cap_rect,flip)
        if flip:
            self.texture(scene,db['PortraitBorderTexture'],B.anchor(owner,db['PortraitBorderSize'],db['PortraitBorderPosition']),db['PortraitBorderColor'])
        elif resource:
            self.resource(resource,1,scene,owner)
        return scene

    def cast(self, cap=True, shield=False):
        db = self.data['PlayerCastBar']
        scene = Image.new('RGBA',(500,260))
        rect = (170,110,*db['CastBarSize'])
        family = 'CastBarShield' if shield else 'CastBarBackground'
        casing = B.anchor(rect,db[family+'Size'],db[family+'Position'])
        name = 'cast_back_spiked' if shield else 'cast_back'
        self.put(scene,self.own(name),casing)
        self.fill(scene,db['CastBarTexture'],rect,1,M.COLORS['dark'])
        self.fill(scene,db['CastBarTexture'],rect,.65,M.COLORS['green'])
        self.put(scene,self.own(name+'-over'),casing)
        if cap:
            x,y,w,h = rect
            self.put(scene,self.own('cast-head'),(x-32,y+h/2-24,48,48))
        return scene

    def compact(self, name):
        scene = self.native(B.compact,name)
        db = self.data[name]
        rect = (120,90,*db['HealthBarSize'])
        casing = B.anchor(rect,db['HealthBackdropSize'],db['HealthBackdropPosition'])
        key = Path(db['HealthBackdropTexture'].replace('\\','/')).stem
        if (OUT/(key+'-over.tga')).exists():
            self.put(scene,self.own(key+'-over'),casing)
        return scene

    def group(self, name):
        scene = self.native(B.group,name)
        db = self.data[name]
        owner = (120,90,*db['UnitSize'])
        rect = B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
        casing = B.anchor(rect,db['HealthBackdropSize'],db['HealthBackdropPosition'])
        key = Path(db['HealthBackdropTexture'].replace('\\','/')).stem
        if (OUT/(key+'-over.tga')).exists():
            self.put(scene,self.own(key+'-over'),casing,db['HealthBarOrientation']=='LEFT')
        return scene


def label(board, value, x, y, size=17):
    ImageDraw.Draw(board).text((x,y),value,font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',size),fill='#d8d0bd')


def place(board, scene, x, y, scale=1, maximum=None):
    art = scene.crop(scene.getbbox())
    if maximum:
        scale = min(scale,maximum[0]/art.width,maximum[1]/art.height)
    if scale != 1:
        art = art.resize((max(1,round(art.width*scale)),max(1,round(art.height*scale))),S)
    assert min(x,y)>=0 and x+art.width<=board.width and y+art.height<=board.height, 'review clips complete art'
    board.alpha_composite(art,(x,y))


def suite(r, representative_only=False):
    board = Image.new('RGBA',(1536,1100),'#14161a')
    draw = ImageDraw.Draw(board)
    label(board,'AZERITEUI - SHAMAN',32,20,38)
    label(board,'STORM, STONE & TIDES - EXPORTED ASSET REVIEW',35,70,17)
    label(board,'Offline native-layout assemblies; no live models, effects or client confirmation.',35,98,14)
    for y in (130,370,620,840):
        draw.line((24,y,1512,y),fill='#363b42')
    label(board,'1. PLAYER HUD',28,140,18)
    label(board,'PLAYER / MAELSTROM',40,178,14)
    place(board,r.health(resource='crystal'),40,208,.7,(515,145))
    label(board,'TARGET / '+('MAELSTROM' if representative_only else 'TIDES')+' / 50% + PREDICTION',590,178,14)
    place(board,r.health(True,fraction=.5,choice='maelstrom' if representative_only else 'tides',prediction=True),590,220,.7,(545,135))
    label(board,'CAST / ON + NONE',1190,178,14)
    place(board,r.cast(),1190,220,1,(300,65))
    place(board,r.cast(False),1210,305,1,(260,45))
    label(board,'2. RESOURCES & SMALL FRAMES',28,382,18)
    for i,f in enumerate((1,.5,0)):
        label(board,str(round(f*100))+'%',45+i*145,418,14)
        place(board,r.resource('crystal',f),40+i*145,445,1,(135,165))
        label(board,str(round(f*100))+'%',500+i*150,418,14)
        place(board,r.resource('orb',f),490+i*150,452,1,(140,155))
    label(board,'POWER SOCKET',970,418,12)
    place(board,r.single('point_plate',100),980,450,1,(95,95))
    label(board,'PET / TARGET OF TARGET',1150,418,13)
    place(board,r.compact('PetFrame'),1130,460,1,(340,50))
    place(board,r.compact('ToTFrame'),1130,535,1,(340,50))
    label(board,'3. PORTRAITS, GROUPS & ORNAMENTS',28,632,18)
    label(board,'NAMEPLATE / SHARED',40,668,12)
    place(board,r.native(B.nameplate),40,700,1,(145,70))
    label(board,'PORTRAIT',240,668,13)
    place(board,r.single('portrait_frame_hi',155),225,695,1,(150,130))
    label(board,'PARTY',430,668,13)
    place(board,r.group('PartyFrames'),420,700,1,(135,120))
    label(board,'RAID / ARENA',610,668,13)
    place(board,r.group('Raid5Frames'),590,700,1,(190,115))
    choices=zip(CAPS,("MAELSTROM",'TIDES','LAVA TOTEM'))
    if representative_only:
        choices=[('maelstrom','MAELSTROM / REPRESENTATIVE')]
        label(board,'Tides / Lava: pending mounting-method gate',840,815,13)
    for i,(key,name) in enumerate(choices):
        x = 840+i*220
        label(board,name,x,668,13)
        place(board,r.own('ornament-'+key+'-hp_cap_case'),x,704,1,(160,112))
    label(board,'4. ACTIONS, MINIMAP & TOOLTIP',28,852,18)
    for i in range(5):
        place(board,r.native(B.button,i<2),36+i*100,905,1,(90,90))
    for i,name in enumerate(('config_button','icon_exit_flight')):
        place(board,r.single(name,100),565+i*95,905,1,(85,85))
    place(board,r.single('minimap-border',280),790,882,1,(240,180))
    place(board,r.tooltip(),1080,910,1,(260,135))
    label(board,'Shaman WIP / native layouts and shared fills / offline rendering; live client checks pending',28,1070,14)
    board.convert('RGB').save(WORK/('Shaman-casings-review.png' if representative_only else 'Shaman-asset-sheet.png'))


def endcaps(r):
    # Identical viewport per column and fixed rail height; do not crop each
    # option independently, which would hide a dip/size/alignment difference.
    images = [[r.health(flip,cap=key is not None,choice=key or 'maelstrom',fraction=.5 if flip else 1,prediction=flip)
               for flip in (False,True)] for key in (None,*CAPS)]
    boxes = []
    for col in (0,1):
        boxes.append(Image.fromarray(np.maximum.reduce([np.asarray(row[col])[:,:,3] for row in images])).getbbox())
    board = Image.new('RGBA',(1800,1100),'#14161a')
    label(board,'SHAMAN / COMPLETE HEALTH BARS / NONE AND ALL THREE',28,20,30)
    label(board,'1x native layout units. Same viewports and rail positions. Right: mirrored target, partial health + synthetic prediction.',28,68,16)
    for row,key in enumerate((None,*CAPS)):
        y = 130+row*230
        label(board,'NONE / complete bare dip' if key is None else key.upper(),28,y,20)
        for col in (0,1):
            art = images[row][col].crop(boxes[col])
            assert art.width<875 and art.height<180
            board.alpha_composite(art,(28+col*890,y+45))
    board.convert('RGB').save(WORK/'Shaman-endcaps-1x.png')
    # One separate 2x sheet per variant, always the whole health assembly.
    for key in CAPS:
        page = Image.new('RGBA',(1900,1850),'#14161a')
        label(page,key.upper()+' / COMPLETE PLAYER AND TARGET / 2x DETAIL',30,25,28)
        for i,flip in enumerate((False,True)):
            pair=[r.health(flip,cap=enabled,choice=key,fraction=.5 if flip else 1,prediction=flip) for enabled in (False,True)]
            box=Image.fromarray(np.maximum.reduce([np.asarray(scene)[:,:,3] for scene in pair])).getbbox()
            for j,enabled in enumerate((False,True)):
                label(page,('TARGET' if flip else 'PLAYER')+(' / ON' if enabled else ' / NONE'),30,90+i*820+j*400,18)
                art=pair[j].crop(box).resize(((box[2]-box[0])*2,(box[3]-box[1])*2),S)
                x,y=30,130+i*820+j*400
                assert x+art.width<=page.width and y+art.height<=page.height,'2x fixed viewport clips complete bar'
                page.alpha_composite(art,(x,y))
        page.convert('RGB').save(WORK/('Shaman-'+key+'-2x.png'))
    # All native health tiers and partial/empty/full states; no ornaments crop.
    page = Image.new('RGBA',(1800,1500),'#14161a')
    label(page,'ALL HEALTH TIERS / NATIVE PLAYER + MIRRORED TARGET / 0, 50, 100%',28,18,26)
    for row,tier in enumerate(CASES):
        label(page,tier.upper(),28,80+row*345,20)
        for col,fraction in enumerate((0,.5,1)):
            for side,flip in enumerate((False,True)):
                if tier not in r.data['TargetFrame' if flip else 'PlayerFrame']:
                    label(page,'No native player Boss tier',25+col*595,130+row*345+side*140,14)
                    continue
                scene=r.health(flip,choice=CAPS[col],tier=tier,fraction=fraction,prediction=fraction==.5)
                place(page,scene,25+col*595,130+row*345+side*140,.7,(570,130))
    page.convert('RGB').save(WORK/'Shaman-health-tiers.png')


def main():
    r = Renderer()
    suite(r)
    endcaps(r)
    custom=Image.new('RGBA',(2700,1500),'#14161a')
    label(custom,'COMPLETE BARS / NONE, DEFAULT, CUSTOM 120% + X=5 Y=-3 / FIXED UNION VIEWPORT',20,15,24)
    for row,(key,flip) in enumerate((key,flip) for key in CAPS for flip in (False,True)):
        scenes=[r.health(flip,choice=key,cap=False),r.health(flip,choice=key),
                r.health(flip,choice=key,cap_scale=1.2,cap_offset=(5,-3))]
        box=Image.fromarray(np.maximum.reduce([np.asarray(s)[:,:,3] for s in scenes])).getbbox()
        label(custom,key.upper()+(' TARGET' if flip else ' PLAYER'),20,70+row*230,17)
        for col,scene in enumerate(scenes):
            art=scene.crop(box)
            assert art.width<875 and art.height<200,'Custom fixed viewport clips complete bar'
            custom.alpha_composite(art,(20+col*895,100+row*230))
    custom.convert('RGB').save(WORK/'Shaman-custom-placement.png')
    contact = Image.new('RGBA',(1600,950),'#30363d')
    label(contact,'NATIVE ATLAS CELLS / EXPORTED SHAMAN CELLS',20,10,24)
    for row,folder in enumerate((ROOT/'Assets',OUT)):
        atlas = Image.open(folder/'border-tooltip.tga').convert('RGBA')
        for i in range(8):
            label(contact,str(i),i*200+15,50+row*220,16)
            image=atlas.crop((i*64,0,(i+1)*64,64)).resize((180,180),S)
            contact.alpha_composite(image,(i*200+10,80+row*220))
    label(contact,'CAST / PROTECTED CAST / SMALL CASINGS / 2x',20,520,22)
    for i,scene in enumerate((r.cast(),r.cast(shield=True),r.compact('PetFrame'),r.compact('ToTFrame'))):
        place(contact,scene,20+i*395,580,2,(370,130))
    label(contact,'SQUARE / ROUNDED / CRITTER CASE',20,745,20)
    for i,name in enumerate(('actionbutton-border-square','actionbutton-border-square-rounded','hp_critter_case_hi')):
        place(contact,r.own(name),20+i*395,790,1,(150,150))
    contact.convert('RGB').save(WORK/'Shaman-small-art-detail.png')
    (WORK/'review-sources.json').write_text(json.dumps({'sources':r.sources,'layout':M.LAYOUT.relative_to(ROOT).as_posix(),
        'liveValidated':False,'method':'exported TGAs at native rectangles; synthetic fill/prediction'},indent=2)+'\n',encoding='utf-8')
    print('Rendered suite, full-bar 1x, three full-bar 2x pages and all-tier sheet.')


def cast_review():
    r=Renderer()
    rows=[(shield,on,r.cast(on,shield)) for shield in (False,True) for on in (False,True)]
    box=Image.fromarray(np.maximum.reduce([np.asarray(row[2])[:,:,3] for row in rows])).getbbox()
    board=Image.new('RGBA',(1000,900),'#14161a')
    label(board,'SHAMAN / CAST DEFAULTS / 100% / X=0 / Y=0',24,20,25)
    for i,(shield,on,scene) in enumerate(rows):
        label(board,('PROTECTED' if shield else 'NORMAL')+(' / TOTEM' if on else ' / NONE'),24,90+i*190,18)
        for col,scale in enumerate((1,2)):
            art=scene.crop(box).resize(((box[2]-box[0])*scale,(box[3]-box[1])*scale),S)
            assert art.width+24+col*400<=1000
            board.alpha_composite(art,(24+col*400,125+i*190))
    board.convert('RGB').save(WORK/'Shaman-cast-defaults.png')


def representative():
    r=Renderer()
    rows=[(flip,enabled,r.health(flip,cap=enabled,choice='maelstrom',fraction=.5,prediction=True)) for flip in (False,True) for enabled in (False,True)]
    boxes={flip:Image.fromarray(np.maximum.reduce([np.asarray(row[2])[:,:,3] for row in rows if row[0]==flip])).getbbox() for flip in (False,True)}
    for scale in (1,2):
        board=Image.new('RGBA',(1900,1600),'#14161a')
        label(board,'SHAMAN / REPRESENTATIVE / EXPORTED TGAs / '+str(scale)+'x',24,20,27)
        label(board,'Complete health bars, fixed union viewport, 50% health + synthetic prediction. Offline.',24,65,18)
        for i,(flip,on,scene) in enumerate(rows):
            box=boxes[flip]
            label(board,('TARGET' if flip else 'PLAYER')+(' / MAELSTROM' if on else ' / NONE'),24,110+i*350,20)
            art=scene.crop(box).resize(((box[2]-box[0])*scale,(box[3]-box[1])*scale),S)
            assert art.width+24<=board.width and art.height+155+i*350<=board.height
            board.alpha_composite(art,(24,155+i*350))
        board.convert('RGB').save(WORK/('Shaman-representative-'+str(scale)+'x.png'))
    print('Representative complete health bars rendered at 1x/2x; fixed viewport.')


if __name__ == '__main__':
    import sys
    if '--casings' in sys.argv:
        suite(Renderer(),True)
    elif '--cast' in sys.argv:
        cast_review()
    elif '--representative' in sys.argv:
        representative()
    else:
        main()
