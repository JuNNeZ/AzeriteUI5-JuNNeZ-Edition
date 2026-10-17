"""Compose matching concept boards directly from installed TGA assets.

No generated/repainted artwork. Scene geometry comes from the layout export
and current theme hooks. This is a static offline illustration, not a client.
"""
from pathlib import Path
from functools import lru_cache
import copy
import hashlib
import importlib.util
import json
import math
import re
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'Docs/Research_Assets/ClassConceptSheets-2026-10-17'
LAYOUT = ROOT / 'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json'
DATA = json.loads(LAYOUT.read_text())['original']
spec = importlib.util.spec_from_file_location('native_board', ROOT / 'Tools/Build-ThemeConceptBase.py')
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)
S = Image.Resampling.LANCZOS
SUBTITLES = {'Mage': 'THE TIRISGARDE', 'Paladin': 'ASHBRINGER / SILVER HAND', 'Druid': 'ROOTS BENEATH THE MOON'}
CAPS = {'Mage': 'ornament-aluneth-hp_cap_case', 'Paladin': 'ornament-ashbringer-hp_cap_case', 'Druid': 'ornament-antler-hp_cap_case'}
CASTS = {'Mage': 'cast-head-fitted', 'Paladin': 'cast-head-libram', 'Druid': 'cast-head-fitted'}
COLORS = {'red': (.84,.03,.08), 'green': (.3,.65,.2), 'amber': (1,.65,.1), 'dark': (.09,.08,.11)}


class Renderer:
    def __init__(self, theme):
        self.theme = theme
        self.sources = {}
        lua = (ROOT / 'Core' / (theme + 'Theme.lua')).read_text(encoding='utf-8-sig')
        media = re.search(r'for _, name in ipairs\(\{(.*?)\}\) do media', lua, re.S)
        assert media, theme
        self.media = set(re.findall(r'"([^"]+)"', media[1]))
        self.data = copy.deepcopy(DATA)
        self.replace(self.data)
        if theme == 'Paladin':
            self.data['PlayerClassPower']['ClassPowerCaseColor'] = [1,1,1]

    def replace(self, table):
        if isinstance(table, list):
            for entry in table:
                if isinstance(entry, (dict,list)):
                    self.replace(entry)
        elif isinstance(table, dict):
            for key, value in list(table.items()):
                if isinstance(value, (dict,list)):
                    self.replace(value)
                elif isinstance(value, str):
                    normalized = value.replace('\\','/')
                    name = Path(normalized).stem
                    if '/Assets/' in normalized and '/' not in normalized.split('/Assets/')[-1] and name in self.media:
                        table[key] = 'Interface/Assets/' + self.theme + '/' + name + '.tga'
                        prefix = re.sub(r'Texture(?:Path)?$', '', key)
                        color = table.get(prefix + 'Color')
                        if isinstance(color, list):
                            table[prefix + 'Color'] = [1,1,1,color[3] if len(color)>3 else 1]

    @lru_cache(maxsize=None)
    def asset(self, path):
        if path is None:
            return None
        relative = path.replace('\\','/').split('/Assets/')[-1]
        source = ROOT / 'Assets' / relative
        assert source.is_file(), source
        self.sources[source.relative_to(ROOT).as_posix()] = hashlib.sha256(source.read_bytes()).hexdigest()
        return Image.open(source).convert('RGBA')

    def own(self, name):
        return self.asset('Interface/Assets/' + self.theme + '/' + name + '.tga')

    def put(self, scene, image, rect, flip=False, tint=None):
        B.put(scene, image, rect, flip, tint)

    def texture(self, scene, path, rect, tint=None, flip=False):
        self.put(scene, self.asset(path), rect, flip, tint)

    def fill(self, scene, path, rect, fraction, color, flip=False, vertical=False, coords=None):
        original = B.asset
        B.asset = self.asset
        try:
            B.fill(scene, path, rect, fraction, color, flip, vertical, coords)
        finally:
            B.asset = original

    def native(self, function, *args):
        original_asset, original_data = B.asset, B.DATA
        B.asset, B.DATA = self.asset, self.data
        try:
            return function(*args)
        finally:
            B.asset, B.DATA = original_asset, original_data

    def single(self, name, size):
        scene = Image.new('RGBA',(size,size))
        self.put(scene,self.own(name),(0,0,size,size))
        return scene

    def tooltip(self):
        # WoW edgeFile: left/right, rotated top/bottom, then four corners.
        scene = Image.new('RGBA',(250,116),'#0c0d10')
        source = self.own('border-tooltip')
        cell = source.height
        edge = 12
        cells = [source.crop((i*cell,0,(i+1)*cell,cell)).resize((edge,edge),S) for i in range(8)]
        parts = [(cells[0],(0,edge,edge,116-2*edge)),
                 (cells[1],(250-edge,edge,edge,116-2*edge)),
                 (cells[2].rotate(-90,expand=True),(edge,0,250-2*edge,edge)),
                 (cells[3].rotate(-90,expand=True),(edge,116-edge,250-2*edge,edge)),
                 (cells[4],(0,0,edge,edge)),(cells[5],(250-edge,0,edge,edge)),
                 (cells[6],(0,116-edge,edge,edge)),(cells[7],(250-edge,116-edge,edge,edge))]
        for image,rect in parts:
            self.put(scene,image,rect)
        return scene

    def config(self, name='PlayerFrame'):
        db = dict(self.data[name])
        db.update(db.get('Seasoned', {}))
        return db

    def resource(self, kind, fraction=1, scene=None, owner=None):
        scene = scene if scene is not None else Image.new('RGBA',(800,500))
        db = self.config()
        owner = owner or (200,150,*db['Size'])
        if kind == 'orb':
            rect = B.anchor(owner, db['ManaOrbSize'], db['ManaOrbPosition'])
            self.texture(scene, db['ManaOrbBackdropTexture'], B.anchor(rect, db['ManaOrbBackdropSize'], db['ManaOrbBackdropPosition']))
            self.fill(scene, 'Interface/Assets/orb2.tga', rect, fraction, (.25,.4,.95), vertical=True)
            # Native case glass and the separately configurable default glass.
            self.texture(scene, db['ManaOrbForegroundTexture'], B.anchor(rect, db['ManaOrbForegroundSize'], db['ManaOrbForegroundPosition']), db['ManaOrbForegroundColor'])
            if db.get('ManaOrbGlassTexture'):
                self.texture(scene, db['ManaOrbGlassTexture'], B.anchor(rect, db['ManaOrbGlassSize'], db['ManaOrbGlassPosition']), db['ManaOrbGlassColor'])
        else:
            # Player.lua CURRENT_POWER_CRYSTAL_LAYOUT: fill/back share the
            # backdrop-sized frame, while the holder keeps its native rectangle.
            rect = B.anchor(owner, db['PowerBackdropSize'], db['PowerBarPosition'])
            self.texture(scene, db['PowerBackdropTexture'], rect)
            if self.theme == 'Druid':
                self.put(scene, self.own('crystal-roots-back'), rect)
            self.fill(scene, db['PowerBarTexture'], rect, fraction, db['PowerBarColors']['MANA'], vertical=True, coords=db.get('PowerBarTexCoord'))
            # Static surfaces, with animated effects disabled for comparison.
            case_rect = B.anchor(rect, db['PowerBarForegroundSize'], db['PowerBarForegroundPosition'])
            if self.theme == 'Druid':
                self.put(scene, self.own('crystal-roots-front'), rect)
            else:
                self.texture(scene, db['PowerBarForegroundTexture'], case_rect, db['PowerBarForegroundColor'])
            if self.theme == 'Mage':
                cx, cy, w, h = case_rect
                self.put(scene, self.own('badge-eye'), (cx+w/2-16,cy+h/2+h*.06-16,32,32))
        return scene

    def health(self, flip=False, cap=True, fraction=1, resource=None):
        db = self.config('TargetFrame' if flip else 'PlayerFrame')
        scene = Image.new('RGBA',(1200,500))
        owner = (230,150,*db['Size'])
        hp = B.anchor(owner, db['HealthBarSize'], db['HealthBarPosition'])
        casing = B.anchor(owner, db['HealthBackdropSize'], db['HealthBackdropPosition'])
        name = 'hp_cap_case'
        self.put(scene, self.own(name), casing, flip)
        self.fill(scene, db['HealthBarTexture'], hp, 1, COLORS['dark'], flip)
        self.fill(scene, db['HealthBarTexture'], hp, fraction, COLORS['red'], flip)
        if self.theme in ('Paladin','Druid','Mage'):
            self.put(scene, self.own(name+'-over'), casing, flip)
        if cap:
            self.put(scene, self.own(CAPS[self.theme]), casing, flip)
        if flip:
            self.texture(scene, db['PortraitBorderTexture'], B.anchor(owner, db['PortraitBorderSize'], db['PortraitBorderPosition']), db['PortraitBorderColor'])
        elif resource:
            self.resource(resource, 1, scene, owner)
        return scene

    def cast(self, cap=True):
        db = self.data['PlayerCastBar']
        scene = Image.new('RGBA',(500,260))
        rect = (170,110,*db['CastBarSize'])
        casing = B.anchor(rect, db['CastBarBackgroundSize'], db['CastBarBackgroundPosition'])
        name = 'cast_back' + ('-capped' if cap and self.theme != 'Paladin' else '')
        self.put(scene, self.own(name), casing)
        self.fill(scene, db['CastBarTexture'], rect, 1, COLORS['dark'])
        self.fill(scene, db['CastBarTexture'], rect, .65, COLORS['green'])
        if self.theme in ('Paladin','Druid'):
            self.put(scene, self.own(name+'-over'), casing)
        if cap:
            x,y,w,h = rect
            cx = x + (-26 if self.theme == 'Paladin' else -8)
            self.put(scene, self.own(CASTS[self.theme]), (cx-24,y+h/2-24,48,48))
            if self.theme == 'Druid':
                light = B.color(self.own('cast-head-fitted-light'), (.59,.75,1))
                layer = Image.new('RGBA',scene.size)
                self.put(layer, light, (cx-24,y+h/2-24,48,48))
                # Additive sprite is still the installed painting.
                rgb = ImageChops.multiply(layer.convert('RGB'), layer.getchannel('A').convert('RGB'))
                added = ImageChops.add(scene.convert('RGB'), rgb).convert('RGBA')
                added.putalpha(ImageChops.lighter(scene.getchannel('A'), layer.getchannel('A')))
                scene = added
        return scene

    def compact(self, name):
        scene = self.native(B.compact, name)
        if self.theme in ('Paladin','Druid'):
            db = self.data[name]
            rect = (120,90,*db['HealthBarSize'])
            casing = B.anchor(rect,db['HealthBackdropSize'],db['HealthBackdropPosition'])
            native_name = Path(db['HealthBackdropTexture']).stem
            self.put(scene,self.own(native_name+'-over'),casing)
        if self.theme == 'Mage' and name == 'PetFrame':
            db = self.data[name]
            x,y,w,h = (120,90,*db['HealthBarSize'])
            self.put(scene, self.own('badge-water-elemental'), (x-34,y+h/2-16,32,32))
        return scene

    def group(self, name):
        scene = self.native(B.group, name)
        if self.theme in ('Paladin','Druid'):
            db = self.data[name]
            owner = (120,90,*db['UnitSize'])
            rect = B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
            casing = B.anchor(rect,db['HealthBackdropSize'],db['HealthBackdropPosition'])
            native_name = Path(db['HealthBackdropTexture']).stem
            self.put(scene,self.own(native_name+'-over'),casing,db['HealthBarOrientation']=='LEFT')
        return scene

    def points(self):
        db = self.data['PlayerClassPower']
        key = 'ArcaneCharges' if self.theme == 'Mage' else 'ComboPoints'
        scene = Image.new('RGBA',(400,400))
        owner = (120,120,*db['ClassPowerFrameSize'])
        for i,p in enumerate(db['ClassPowerLayouts'][key]):
            rect = B.anchor(owner,p['Size'],p['Position'])
            self.texture(scene,p['BackdropTexture'],B.anchor(rect,p['BackdropSize'],['CENTER',0,0]),db['ClassPowerCaseColor'])
            color = (1,.78,.28) if i<3 else db['ClassPowerSlotColor']
            art = B.color(self.asset(p['Texture']),color).rotate(math.degrees(p.get('Rotation',0)),resample=Image.Resampling.BICUBIC)
            self.put(scene,art,rect)
        return scene

    def minimap(self):
        scene = Image.new('RGBA',(300,300))
        self.put(scene,self.own('minimap-border'),(15,15,270,270))
        # Compass north uses its own native moving anchor; shown at 12 o'clock.
        self.put(scene,self.own('minimap-north'),(134,32,32,32))
        return scene

    def build(self):
        board = Image.new('RGBA',(1536,1024),'#14161a')
        draw = ImageDraw.Draw(board)
        placements = []
        def text(label,x,y,size=15,color='#c1b9a8'):
            draw.text((x,y),label,font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',size),fill=color)
        def rule(y):
            draw.line((24,y,1512,y),fill='#30343c')
        def place(scene,x,y,width=None,height=None,max_scale=1):
            art = scene.crop(scene.getbbox())
            scale = min(max_scale,width/art.width if width else 1,height/art.height if height else 1)
            if scale<1:
                art = art.resize((round(art.width*scale),round(art.height*scale)),S)
            assert x>=0 and y>=0 and x+art.width<=1536 and y+art.height<=1024
            board.alpha_composite(art,(x,y))
            placements.append({'bounds':[x,y,x+art.width,y+art.height],'uniformScale':scale})
        text('AZERITEUI - '+self.theme.upper(),40,22,40,'#e0d5bd')
        text(SUBTITLES[self.theme]+'  /  IMPLEMENTED ART',44,73,15)
        rule(103);text('1. PLAYER HUD',28,114,18)
        text('PLAYER',40,151);place(self.health(resource='crystal'),40,177,510,168,.7)
        text('TARGET',580,151);place(self.health(True),580,185,540,150,.7)
        text('PLAYER CASTBAR',1210,151);place(self.cast(),1210,191,280,75)
        text('ENDCAP OFF',1210,277,12);place(self.cast(False),1225,304,245,40)
        rule(360);text('2. RESOURCES & PET',28,370,18)
        for i,f in enumerate((1,.5,0)):
            text(str(round(f*100))+'%',50+i*140,400,13)
            place(self.resource('crystal',f),45+i*140,425,130,162)
            text(str(round(f*100))+'%',500+i*150,400,13)
            place(self.resource('orb',f),490+i*150,430,140,155)
        text('CLASS POWER',970,400,13);place(self.points(),970,426,105,160)
        text('PET FRAME',1150,437,13);place(self.compact('PetFrame'),1140,470,330,62)
        text('HEALTH ENDCAP OFF',1150,537,12);place(self.health(cap=False,resource=None),1140,559,335,36)
        rule(600);text('3. NAMEPLATES, PORTRAITS & GROUP',28,610,18)
        text('NAMEPLATE',50,648,13);place(self.native(B.nameplate),50,680,145,65)
        text('TARGET OF TARGET',220,648,13);place(self.compact('ToTFrame'),220,679,180,45)
        place(self.compact('FocusFrame'),220,734,180,40)
        text('PORTRAIT',425,635,13);place(self.single('portrait_frame_hi',150),420,663,150,125)
        text('PARTY',590,640,13);place(self.group('PartyFrames'),590,671,130,110)
        text('RAID / ARENA',750,640,13);place(self.group('Raid5Frames'),740,671,195,105)
        text('IMPLEMENTED ORNAMENTS',960,644,13)
        ornaments = [CAPS[self.theme],CASTS[self.theme],
                     'badge-eye' if self.theme=='Mage' else 'pw_crystal_case',
                     'minimap-north','orb_case_hi']
        for i,name in enumerate(ornaments):
            x=960+i*108
            draw.rectangle((x,672,x+92,764),outline='#454b55')
            art = self.own(name)
            art = art.crop(art.getbbox())
            factor = min(82/art.width,82/art.height)
            art = art.resize((round(art.width*factor),round(art.height*factor)),S)
            board.alpha_composite(art,(x+(92-art.width)//2,672+(92-art.height)//2))
        rule(800);text('4. ACTIONS, MINIMAP & PANELS',28,810,18)
        for i in range(6):
            if i==0:text('ACTION BUTTONS',40,847,13)
            place(self.native(B.button,i<2),40+i*88,879,80,90)
        text('UTILITY',590,850,13)
        place(self.single('config_button',90),590,884,80,85)
        place(self.single('icon_exit_flight',90),680,884,80,85)
        text('MINIMAP',805,828,13);place(self.minimap(),810,845,240,157)
        text('TOOLTIP BORDER',1080,832,13)
        place(self.tooltip(),1080,857)
        text('MATERIAL CROPS',1360,812,12)
        # Literal cropped source pixels, not freshly painted swatches.
        for i,name in enumerate(('hp_cap_case','pw_crystal_case','orb_case_hi','portrait_frame_hi','point_plate')):
            source=self.own(name)
            box=source.getchannel('A').point(lambda a:255 if a>220 else 0).getbbox()
            art=source.crop(box)
            thumb=art.resize((140,max(26,round(art.height*140/art.width))),S)
            crop=thumb.crop((0,max(0,(thumb.height-26)//2),140,max(0,(thumb.height-26)//2)+26))
            board.alpha_composite(crop,(1360,839+i*32))
            draw.rectangle((1360,839+i*32,1500,865+i*32),outline='#454b55')
        text('Installed textures / static surfaces, animated effects off / offline assembly, no live models / uniformly scaled to sheet slots',28,1007,11,'#92918e')
        output=OUT/(self.theme.lower()+'-implemented.png')
        board.convert('RGB').save(output)
        manifest={'theme':self.theme,'output':output.name,'size':list(board.size),
                  'outputSha256':hashlib.sha256(output.read_bytes()).hexdigest(),
                  'method':'literal installed TGA composition; no generated/repainted artwork',
                  'resourceState':'neutral crystal, sapphire orb; animated effects disabled',
                  'layout':LAYOUT.relative_to(ROOT).as_posix(),
                  'sources':self.sources,'placements':placements}
        (OUT/(self.theme.lower()+'-implemented-sources.json')).write_text(json.dumps(manifest,indent=2),encoding='utf-8')
        print(self.theme+': '+str(len(self.sources))+' installed assets -> '+str(output))


if __name__ == '__main__':
    for theme in SUBTITLES:
        Renderer(theme).build()
