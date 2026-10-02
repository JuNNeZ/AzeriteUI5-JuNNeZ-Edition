"""Offline assembled comparison from harness-exported production layout data.

This renders real textures and native anchors. Portrait models, spell icons,
font metrics, statusbar engine clipping and animation are not WoW emulation.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'Docs/Research_Assets/Paladin/Revision5'
DATA=json.loads((OUT/'layouts.json').read_text())
S=Image.Resampling.LANCZOS
FONT='C:/Windows/Fonts/segoeui.ttf'
def asset(path):
    if path is None:return None
    name=path.replace('\\','/').split('/Assets/')[-1]
    return Image.open(ROOT/'Assets'/name).convert('RGBA')
def media(name,paladin=False):return asset(('Paladin/' if paladin else '')+name+'.tga')
def color(im,c):
    c=tuple(round(v*255) for v in c[:3])+(255,)
    result=ImageChops.multiply(im,Image.new('RGBA',im.size,c));result.putalpha(im.getchannel('A'));return result
def anchor(rect,size,pos):
    point=pos[0];dx,dy=pos[-2:];x,y,w,h=rect;sw,sh=size
    fx=0 if 'LEFT' in point else 1 if 'RIGHT' in point else .5
    fy=0 if 'TOP' in point else 1 if 'BOTTOM' in point else .5
    return (x+fx*(w-sw)+dx,y+fy*(h-sh)-dy,sw,sh)
def put(scene,im,rect,flip=False,tint=None):
    if im is None:return
    if tint:im=color(im,tint)
    if flip:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    x,y,w,h=rect
    scene.alpha_composite(im.resize((max(1,round(w)),max(1,round(h))),S),(round(x),round(y)))
def label(scene,text,x,y,size=14,align='left',fill='#e7e3d6'):
    d=ImageDraw.Draw(scene);f=ImageFont.truetype(FONT,size)
    if align=='right':x-=d.textlength(text,font=f)
    if align=='center':x-=d.textlength(text,font=f)/2
    d.text((x,y-size/2),text,font=f,fill=fill,stroke_width=1,stroke_fill='#161419')
def fill(scene,texture,rect,fraction,c,flip=False,vertical=False,coords=None):
    im=asset(texture)
    if coords:
        l,r,t,b=coords;im=im.crop((round(l*im.width),round(t*im.height),round(r*im.width),round(b*im.height)))
    im=color(im,c).resize((max(1,round(rect[2])),max(1,round(rect[3]))),S)
    if flip:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    x,y,w,h=rect
    if vertical:
        cut=round(im.height*(1-fraction));im=im.crop((0,cut,im.width,im.height));y+=cut
    elif flip:
        cut=round(im.width*(1-fraction));im=im.crop((cut,0,im.width,im.height));x+=cut
    else:im=im.crop((0,0,round(im.width*fraction),im.height))
    if im.width and im.height:scene.alpha_composite(im,(round(x),round(y)))
def blade(scene,rect,flip=False,texture='hp_cap_bar'):
    x,y,w,h=rect
    if 'hp_lowmid_bar' in texture:name,sw,right,ft,fb='health-lowmid',2043,1786,2/64,52/64
    elif w/h>12:name,sw,right,ft,fb='health-wide',2671,2414,2/64,48/64
    elif w<200:name,sw,right,ft,fb='health-small',1821,1494,1/32,1
    elif abs(w/h-385/37)<.05:name,sw,right,ft,fb='health-portrait',2141,1884,3/128,100/128
    else:name,sw,right,ft,fb='health-case',2011,1754,3/128,100/128
    left=82 if name=='health-small' else 62
    sx=w/(right-left);sy=h*(fb-ft)/130
    put(scene,media(name,True),(x-(sw-right if flip else left)*sx,y+h*ft-306*sy,sw*sx,724*sy),flip)

def unit(kind,tier,paladin,fraction=.4,orb=False):
    key='paladin' if paladin else 'original';base=DATA[key][kind];db=dict(base);db.update(base.get(tier,{}))
    scene=Image.new('RGBA',(780,290))
    isplayer=kind=='PlayerFrame';istarget=kind=='TargetFrame';flip=istarget
    owner=(80 if isplayer else 150,60,*(base.get('Size') or [550,210]))
    hp=anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
    if db.get('PortraitBorderTexture'):
        pr=anchor(owner,db['PortraitBorderSize'],db['PortraitBorderPosition'])
        put(scene,asset(db['PortraitBorderTexture']),pr,tint=db.get('PortraitBorderColor'))
        # Neutral label is a placeholder for the live 3D model, not new art.
        model=anchor(owner,db['PortraitSize'],db['PortraitPosition'])
        label(scene,'PORTRAIT',model[0]+model[2]/2,model[1]+model[3]/2,11,'center','#85808b')
    if not paladin or hp[2]<hp[3]*2:
        put(scene,asset(db['HealthBackdropTexture']),anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition']),flip,db.get('HealthBackdropColor'))
    fill(scene,db['HealthBarTexture'],hp,1,(.09,.08,.11),flip)
    fill(scene,db['HealthBarTexture'],hp,fraction,(.84,.03,.08),flip)
    if paladin and hp[2]>=hp[3]*2:blade(scene,hp,flip,db['HealthBarTexture'])
    if hp[2]>100:
        value=anchor(hp,(0,0),db['HealthValuePosition']);label(scene,'578K (0)',value[0],value[1],15,'right' if istarget else 'left')
    perc=anchor(hp,(0,0),db['HealthPercentagePosition']);label(scene,str(round(fraction*100))+'%',perc[0],perc[1],14,'left' if istarget else 'right')
    if isplayer and orb:
        rect=anchor(owner,db['ManaOrbSize'],db['ManaOrbPosition'])
        put(scene,asset(db['ManaOrbBackdropTexture']),anchor(rect,db['ManaOrbBackdropSize'],db['ManaOrbBackdropPosition']))
        path='Interface/Assets/'+('Paladin/orb-light.tga' if paladin else 'orb2.tga')
        fill(scene,path,rect,fraction,(1,.78,.28) if paladin else (.25,.4,.95),vertical=True)
        put(scene,asset(db['ManaOrbForegroundTexture']),anchor(rect,db['ManaOrbForegroundSize'],db['ManaOrbForegroundPosition']),tint=db['ManaOrbForegroundColor'])
        label(scene,str(round(fraction*50))+'K',rect[0]+rect[2]/2,rect[1]+rect[3]/2,14,'center')
    else:
        rect=anchor(owner,db['PowerBarSize'],db['PowerBarPosition'])
        put(scene,asset(db['PowerBackdropTexture']),anchor(rect,db['PowerBackdropSize'],db['PowerBackdropPosition']))
        tint=db['PowerBarColors']['MANA']
        fill(scene,db['PowerBarTexture'],rect,fraction,tint,vertical=True,coords=db.get('PowerBarTexCoord'))
        if db.get('PowerBarForegroundTexture'):
            put(scene,asset(db['PowerBarForegroundTexture']),anchor(rect,db['PowerBarForegroundSize'],db['PowerBarForegroundPosition']),tint=db['PowerBarForegroundColor'])
        label(scene,str(round(fraction*50))+'K',rect[0]+rect[2]/2,rect[1]+rect[3]/2,13,'center')
    return scene

def compact(paladin):
    scene=Image.new('RGBA',(780,290));layouts=DATA['paladin' if paladin else 'original']
    for i,name in enumerate(['FocusFrame','ToTFrame','PetFrame','PartyFrames','Raid5Frames','RaidFrames','ArenaFrames','MirrorTimers']):
        db=layouts[name];pre='MirrorTimer' if name=='MirrorTimers' else 'Health';w,h=db[pre+'BarSize']
        x=35+(i%4)*190;y=70+(i//4)*115;bar=(x,y,w,h)
        put(scene,asset(db[pre+'BackdropTexture']),anchor(bar,db[pre+'BackdropSize'],db[pre+'BackdropPosition']),tint=db[pre+'BackdropColor'])
        fill(scene,db[pre+'BarTexture'],bar,.6,(.3,.65,.2))
        label(scene,name.replace('Frames','').replace('Frame',''),x+w/2,y-25,12,'center')
    return scene

def nameplates(paladin):
    scene=Image.new('RGBA',(780,290));db=DATA['paladin' if paladin else 'original']['NamePlates']
    for i,p in enumerate([0,.4,1]):
        x=70+i*235;y=95;w,h=db['HealthBarSize'];hp=(x,y,w,h);cast=(x,y+17,w,h)
        for rect,pre,c in [(hp,'Health',(.2,.65,.18)),(cast,'Cast',(1,.65,.1))]:
            name='HealthBackdrop' if pre=='Health' else 'CastBarBackdrop'
            put(scene,asset(db[name+'Texture']),anchor(rect,db[name+'Size'],db[name+'Position']))
            fill(scene,db[pre+'BarTexture'],rect,p,c,coords=db[pre+'BarTexCoord'])
        label(scene,str(round(p*100))+'% health / cast',x+w/2,y-30,13,'center')
    return scene

def buttons(paladin):
    scene=Image.new('RGBA',(780,290));db=DATA['paladin' if paladin else 'original']['ActionButton']
    states=['ready','count text','gold glow','blue glow']
    for i,state in enumerate(states):
        rect=(70+i*108,110,64,64)
        put(scene,asset(db['ButtonBackdropTexture']),anchor(rect,db['ButtonBackdropSize'],db['ButtonBackdropPosition']))
        # Shipped role marker is only a stand-in for a live spell icon.
        put(scene,media('grouprole-icons-heal'),anchor(rect,db['ButtonIconSize'],db['ButtonIconPosition']))
        put(scene,asset(db['ButtonBorderTexture']),anchor(rect,db['ButtonBorderSize'],db['ButtonBorderPosition']),tint=db['ButtonBorderColor'])
        if state in ('gold glow','blue glow'):
            put(scene,media('actionbutton-glow-white'),anchor(rect,db['ButtonBorderSize'],db['ButtonBorderPosition']),tint=(1,.8,.15) if state=='gold glow' else (.5,.7,1))
        if state=='count text':label(scene,'8.2',rect[0]+32,rect[1]+32,18,'center')
        label(scene,state,rect[0]+32,rect[1]-25,13,'center')
    return scene

def casts(paladin):
    scene=Image.new('RGBA',(780,290));db=DATA['paladin' if paladin else 'original']['PlayerCastBar']
    for i,p in enumerate([0,.4,1]):
        rect=(80+i*235,130,*db['CastBarSize']);x,y,w,h=rect
        if not paladin:
            put(scene,asset(db['CastBarBackgroundTexture']),anchor(rect,db['CastBarBackgroundSize'],db['CastBarBackgroundPosition']),tint=db['CastBarBackgroundColor'])
        fill(scene,db['CastBarTexture'],rect,1,(.06,.05,.09))
        fill(scene,db['CastBarTexture'],rect,p,db['CastBarColor'])
        if paladin:put(scene,media('lion-cast',True),(x-342*w/1397,y+h/32-288*h*31/32/133,2018*w/1397,724*h*31/32/133))
        label(scene,str(round(p*100))+'%',x+w/2,y-30,14,'center')
        label(scene,'Flash of Light',x+w/2,y-db['CastBarTextPosition'][2]+7,14,'center')
    return scene

def portraits(paladin):
    scene=Image.new('RGBA',(780,290));layouts=DATA['paladin' if paladin else 'original']
    for i,name in enumerate(['PartyFrames','Raid5Frames','ArenaFrames']):
        db=layouts[name];owner=(35+i*250,85,*db['UnitSize'])
        for pre in ['PortraitBackground','PortraitBorder']:
            put(scene,asset(db[pre+'Texture']),anchor(owner,db[pre+'Size'],db[pre+'Position']),tint=db[pre+'Color'])
        rect=anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
        put(scene,asset(db['HealthBackdropTexture']),anchor(rect,db['HealthBackdropSize'],db['HealthBackdropPosition']),tint=db['HealthBackdropColor'])
        fill(scene,db['HealthBarTexture'],rect,.6,(.3,.65,.2),db['HealthBarOrientation']=='LEFT')
        label(scene,name,owner[0]+100,55,14,'center')
    return scene

def holy(paladin):
    import math
    scene=Image.new('RGBA',(780,290));db=DATA['paladin' if paladin else 'original']['PlayerClassPower']
    for count in range(6):
        owner=(count*126,95,*db['ClassPowerFrameSize'])
        for j,p in enumerate(db['ClassPowerLayouts']['ComboPoints']):
            rect=anchor(owner,p['Size'],p['Position'])
            put(scene,asset(p['BackdropTexture']),anchor(rect,p['BackdropSize'],['CENTER',0,0]),tint=db['ClassPowerCaseColor'])
            im=color(asset(p['Texture']),(1,.78,.28) if j<count else db['ClassPowerSlotColor'])
            im=im.rotate(math.degrees(p.get('PointRotation',0)))
            put(scene,im,rect)
        label(scene,str(count)+' / 5',owner[0]+75,65,14,'center')
    return scene

rows=[('Player crystal — 40%','PlayerFrame','Seasoned',.4,False),('Player orb — 40%','PlayerFrame','Seasoned',.4,True),
      ('Alternate player portrait — 100%','PlayerFrameAlternate','Seasoned',1,False),('Target portrait — 40%','TargetFrame','Seasoned',.4,False),
      ('Novice target — 100%','TargetFrame','Novice',1,False),('World-boss target — 40%','TargetFrame','Boss',.4,False),
      ('Critter target — 100%','TargetFrame','Critter',1,False),('Empty crystal and health','PlayerFrame','Seasoned',0,False),
      ('Compact units and mirror timer',None,None,None,None),('Stacked nameplate health / cast',None,None,None,None),
      ('Action material, text and tint samples (not live states)',None,None,None,None),
      ('Player castbar — native meter and spell-name position',None,None,None,None),
      ('Party / raid / arena circular portraits',None,None,None,None),
      ('Holy Power — larger seals and wider arc, 0 through 5',None,None,None,None),
      ('Full crystal and health','PlayerFrame','Seasoned',1,False),
      ('Full orb and health','PlayerFrame','Seasoned',1,True)]
sheet=Image.new('RGBA',(1720,150+len(rows)*330),'#101217');d=ImageDraw.Draw(sheet)
label(sheet,'PALADIN — ASSEMBLED ORIGINAL / THEMED COMPARISON',40,40,28)
label(sheet,'Production layout export, native anchors, actual TGAs. Offline reconstruction: no live models, engine animation or combat.',40,85,18,fill='#999aa8')
for i,(title,kind,tier,fraction,orb) in enumerate(rows):
    y=140+i*330;d.line((30,y,1690,y),fill='#39313b',width=2);label(sheet,title,40,y+23,20)
    for j,paladin in enumerate([False,True]):
        x=20+j*850;label(sheet,'PALADIN' if paladin else 'ORIGINAL',x+45,y+57,14,fill='#c6ab78')
        panel=unit(kind,tier,paladin,fraction,orb) if kind else {8:compact,9:nameplates,10:buttons,11:casts,12:portraits,13:holy}[i](paladin)
        sheet.alpha_composite(panel,(x,y+50))
sheet.save(OUT/'Paladin-Assembled-Comparison.png')
sheet.convert('RGB').save(OUT/'Paladin-Assembled-Comparison.jpg',quality=95)
print(OUT/'Paladin-Assembled-Comparison.png')
