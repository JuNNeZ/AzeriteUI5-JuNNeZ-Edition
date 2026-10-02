"""Offline assembled comparison from harness-exported production layout data.

This renders real textures and native anchors. Portrait models, spell icons,
font metrics, statusbar engine clipping and animation are not WoW emulation.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'Docs/Research_Assets/Hunter'
DATA=json.loads((OUT/'layouts.json').read_text())
GEOMETRY=json.loads((ROOT/'Assets/Hunter/geometry.json').read_text())
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
def health_casing(hp,texture,flip=False):
    x,y,w,h=hp; top,bottom=3/128,100/128
    if 'hp_lowmid_bar' in texture:top,bottom=2/64,52/64
    elif 'hp_boss_bar' in texture:top,bottom=2/64,48/64
    if 'hp_critter_bar' in texture:
        l,t,r,b=GEOMETRY['critter'];sx=w/(r-l);sy=h/(b-t)
        return x-(1-r if flip else l)*sx,y-t*sy,sx,sy
    sx=w/(1910-162);sy=h*(bottom-top)/(410-287)
    return x-(2172-1910 if flip else 162)*sx,y-287*sy+h*top,2172*sx,724*sy

def unit(kind,tier,paladin,fraction=.4,orb=False):
    key='hunter' if paladin else 'original';base=DATA[key][kind];db=dict(base);db.update(base.get(tier,{}))
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
    if not paladin:
        put(scene,asset(db['HealthBackdropTexture']),anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition']),flip,db.get('HealthBackdropColor'))
    fill(scene,db['HealthBarTexture'],hp,1,(.09,.08,.11),flip)
    fill(scene,db['HealthBarTexture'],hp,fraction,(.84,.03,.08),flip)
    if paladin:
        case='hp_critter_case' if hp[2]<hp[3]*2 else 'hp_cap_case'
        put(scene,asset('Hunter/'+case+'.tga'),health_casing(hp,db['HealthBarTexture'],flip),flip)
        if hp[2]>=hp[3]*2:ornament(scene,hp,flip)
    if hp[2]>100:
        value=anchor(hp,(0,0),db['HealthValuePosition']);label(scene,'578K (0)',value[0],value[1],15,'right' if istarget else 'left')
    perc=anchor(hp,(0,0),db['HealthPercentagePosition']);label(scene,str(round(fraction*100))+'%',perc[0],perc[1],14,'left' if istarget else 'right')
    if isplayer and orb:
        rect=anchor(owner,db['ManaOrbSize'],db['ManaOrbPosition'])
        put(scene,asset(db['ManaOrbBackdropTexture']),anchor(rect,db['ManaOrbBackdropSize'],db['ManaOrbBackdropPosition']))
        path='Hunter/orb-focus.tga' if paladin else 'orb2.tga'
        fill(scene,path,rect,fraction,(1,.62,.12),vertical=True)
        put(scene,asset(db['ManaOrbForegroundTexture']),anchor(rect,db['ManaOrbForegroundSize'],db['ManaOrbForegroundPosition']),tint=db['ManaOrbForegroundColor'])
        label(scene,str(round(fraction*50))+'K',rect[0]+rect[2]/2,rect[1]+rect[3]/2,14,'center')
    else:
        rect=anchor(owner,db['PowerBackdropSize'] if paladin and isplayer else db['PowerBarSize'],db['PowerBarPosition'])
        put(scene,asset(db['PowerBackdropTexture']),anchor(rect,db['PowerBackdropSize'],db['PowerBackdropPosition']))
        tint=db['PowerBarColors']['FOCUS']
        fill(scene,db['PowerBarTexture'],rect,fraction,tint,vertical=True,coords=None if paladin and isplayer else db.get('PowerBarTexCoord'))
        if db.get('PowerBarForegroundTexture'):
            put(scene,asset(db['PowerBarForegroundTexture']),anchor(rect,db['PowerBarForegroundSize'],['BOTTOM',0,-23] if paladin and isplayer else db['PowerBarForegroundPosition']),tint=db['PowerBarForegroundColor'])
        label(scene,str(round(fraction*50))+'K',rect[0]+rect[2]/2,rect[1]+rect[3]/2,13,'center')
    return scene

def compact(paladin):
    scene=Image.new('RGBA',(780,290));layouts=DATA['hunter' if paladin else 'original']
    for i,name in enumerate(['FocusFrame','ToTFrame','BossFrames','PartyFrames','Raid5Frames','RaidFrames','ArenaFrames','MirrorTimers']):
        db=layouts[name];pre='MirrorTimer' if name=='MirrorTimers' else 'Health';w,h=db[pre+'BarSize']
        x=35+(i%4)*190;y=70+(i//4)*115;bar=(x,y,w,h)
        if not (paladin and name=='PetFrame'):put(scene,asset(db[pre+'BackdropTexture']),anchor(bar,db[pre+'BackdropSize'],db[pre+'BackdropPosition']),tint=db[pre+'BackdropColor'])
        fill(scene,db[pre+'BarTexture'],bar,.6,(.3,.65,.2))
        if paladin and name=='PetFrame':
            g=GEOMETRY['pet'];l,t,r,b=g['health'];sw,sh=g['canvas'];scale=w/(r-l)
            put(scene,asset('Hunter/pet-case.tga'),(x-l*scale,y-t*scale,sw*scale,sh*scale))
        label(scene,name.replace('Frames','').replace('Frame',''),x+w/2,y-25,12,'center')
    return scene

def nameplates(paladin):
    scene=Image.new('RGBA',(780,290));db=DATA['hunter' if paladin else 'original']['NamePlates']
    for i,p in enumerate([0,.4,1]):
        x=70+i*235;y=95;w,h=db['HealthBarSize'];hp=(x,y,w,h);cast=(x,y+h+1,w,h)
        for rect,pre,c in [(hp,'Health',(.2,.65,.18)),(cast,'Cast',(1,.65,.1))]:
            name='HealthBackdrop' if pre=='Health' else 'CastBarBackdrop'
            put(scene,asset(db[name+'Texture']),anchor(rect,db[name+'Size'],db[name+'Position']))
            fill(scene,db[pre+'BarTexture'],rect,p,c,coords=None)
        label(scene,str(round(p*100))+'% health / cast',x+w/2,y-30,13,'center')
    return scene

def buttons(paladin):
    scene=Image.new('RGBA',(780,290));db=DATA['hunter' if paladin else 'original']['ActionButton']
    states=['ready','count text','gold glow','blue glow']
    for i,state in enumerate(states):
        rect=(70+i*108,110,64,64)
        put(scene,asset(db['ButtonBackdropTexture']),anchor(rect,db['ButtonBackdropSize'],db['ButtonBackdropPosition']))
        # Shipped role marker is only a stand-in for a live spell icon.
        put(scene,media('grouprole-icons-heal'),anchor(rect,db['ButtonIconSize'],db['ButtonIconPosition']))
        put(scene,asset(db['ButtonBorderTexture']),anchor(rect,db['ButtonBorderSize'],db['ButtonBorderPosition']),tint=db['ButtonBorderColor'])
        if state in ('gold glow','blue glow'):
            put(scene,asset(('Hunter/' if paladin else '')+'actionbutton-glow-white.tga'),anchor(rect,db['ButtonBorderSize'],db['ButtonBorderPosition']),tint=(1,.8,.15) if state=='gold glow' else (.5,.7,1))
        if state=='count text':label(scene,'8.2',rect[0]+32,rect[1]+32,18,'center')
        label(scene,state,rect[0]+32,rect[1]-25,13,'center')
    return scene

def casts(paladin):
    scene=Image.new('RGBA',(780,290));db=DATA['hunter' if paladin else 'original']['PlayerCastBar']
    for i,p in enumerate([0,.4,1]):
        rect=(95,35+i*85,*db['CastBarSize']);x,y,w,h=rect
        if True:
            put(scene,asset(db['CastBarBackgroundTexture']),anchor(rect,db['CastBarBackgroundSize'],db['CastBarBackgroundPosition']),tint=db['CastBarBackgroundColor'])
        fill(scene,db['CastBarTexture'],rect,1,(.06,.05,.09))
        fill(scene,db['CastBarTexture'],rect,p,db['CastBarColor'])
        if paladin: ornament(scene,rect,False,True)
        label(scene,str(round(p*100))+'%',x+w/2,y+h/2,14,'center')
        label(scene,'Flash of Light',x+w/2,y-db['CastBarTextPosition'][2]+7,14,'center')
    return scene

def portraits(paladin):
    scene=Image.new('RGBA',(780,290));layouts=DATA['hunter' if paladin else 'original']
    for i,name in enumerate(['PartyFrames','Raid5Frames','ArenaFrames']):
        db=layouts[name];owner=(35+i*250,85,*db['UnitSize'])
        for pre in ['PortraitBackground','PortraitBorder']:
            put(scene,asset(db[pre+'Texture']),anchor(owner,db[pre+'Size'],db[pre+'Position']),tint=db[pre+'Color'])
        rect=anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
        put(scene,asset(db['HealthBackdropTexture']),anchor(rect,db['HealthBackdropSize'],db['HealthBackdropPosition']),tint=db['HealthBackdropColor'])
        fill(scene,db['HealthBarTexture'],rect,.6,(.3,.65,.2),db['HealthBarOrientation']=='LEFT')
        label(scene,name,owner[0]+100,55,14,'center')
    return scene

def ornament(scene,rect,flip=False,cast=False,key='thasdorah'):
    x,y,w,h=rect;size=min(58 if cast else 48,h*(2.35 if cast else 1.2))
    put(scene,asset('Hunter/endcap-'+key+'.tga'),(x+8-size if flip else x+w-8,y+(h-size)/2,size,size),flip)
    if cast:put(scene,asset('Hunter/eagle.tga'),(x+8-size,y+(h-size)/2,size,size))

def threat_sample(themed):
    base=DATA['hunter' if themed else 'original']['PlayerFrame'];db=dict(base);db.update(base['Seasoned'])
    scene=Image.new('RGBA',(780,290));owner=(80,60,*(base.get('Size') or [550,210]))
    hp=anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
    put(scene,asset(db['HealthThreatTexture']),health_casing(hp,db['HealthBarTexture']) if themed else anchor(owner,db['HealthThreatSize'],db['HealthThreatPosition']),tint=(1,.12,.05))
    if themed:
        x,y,w,h=hp;size=min(48,h*1.2)
        put(scene,asset('Hunter/endcap-thasdorah-glow.tga'),(x+w-8,y+(h-size)/2,size,size),tint=(1,.12,.05))
    if themed:
        power=anchor(owner,db['PowerBackdropSize'],db['PowerBarPosition'])
        x,y,w,h=power
        put(scene,asset('Hunter/crystal-group-glow.tga'),(x-w/2,y-h/4,w*2,h*2),tint=(1,.12,.05))
    scene.alpha_composite(unit('PlayerFrame','Seasoned',themed,.4))
    return scene

def trim_and_caps(themed):
    scene=Image.new('RGBA',(780,290))
    prefix='Hunter/' if themed else ''
    put(scene,asset(prefix+'minimap-border.tga'),(5,-15,360,360))
    label(scene,'Minimap casing',185,265,13,'center')
    atlas=asset(prefix+'border-tooltip.tga'); cell=atlas.height
    pieces=[atlas.crop((i*cell,0,(i+1)*cell,cell)) for i in range(8)]
    x,y,w,h,e=385,45,280,130,25
    for tile,rect in [(pieces[0],(x,y+e,e,h-2*e)),(pieces[1],(x+w-e,y+e,e,h-2*e)),
        (pieces[2].transpose(Image.Transpose.ROTATE_270),(x+e,y,w-2*e,e)),
        (pieces[3].transpose(Image.Transpose.ROTATE_270),(x+e,y+h-e,w-2*e,e)),
        (pieces[4],(x,y,e,e)),(pieces[5],(x+w-e,y,e,e)),(pieces[6],(x,y+h-e,e,e)),(pieces[7],(x+w-e,y+h-e,e,e))]:put(scene,tile,rect)
    label(scene,'Tooltip / panel edge atlas',x+w/2,y+60,15,'center')
    if themed:
        for i,key in enumerate(['thasdorah','talonclaw','titanstrike','thoridal','raeshalare']):
            put(scene,asset('Hunter/endcap-'+key+'.tga'),(345+i*80,198,65,65))
            label(scene,key,377+i*80,275,10,'center')
    return scene

def pet_sample(themed):
    scene=Image.new('RGBA',(780,290));db=DATA['hunter' if themed else 'original']['PetFrame']
    for i,p in enumerate([0,.4,1]):
        x=140;y=50+i*85;w,h=db['HealthBarSize'];rect=(x,y,w,h)
        fill(scene,db['HealthBarTexture'],rect,p,(.35,.7,.12))
        if themed:
            g=GEOMETRY['pet'];l,t,r,b=g['health'];sw,sh=g['canvas'];scale=w/(r-l)
            put(scene,asset('Hunter/pet-case.tga'),(x-l*scale,y-t*scale,sw*scale,sh*scale))
        else:put(scene,asset(db['HealthBackdropTexture']),anchor(rect,db['HealthBackdropSize'],db['HealthBackdropPosition']))
        label(scene,str(round(p*100))+'%',x+w/2,y+h/2,12,'center')
    return scene

rows=[('Connected concept pet casing: empty / partial / full',pet_sample),('Minimap, tooltip joins and optional endcaps',trim_and_caps),('Player health and focus crystal',lambda h:unit('PlayerFrame','Seasoned',h,1)),
 ('Player partial health and orb',lambda h:unit('PlayerFrame','Seasoned',h,.4,True)),
 ('Alternate player portrait',lambda h:unit('PlayerFrameAlternate','Seasoned',h,1)),
 ('Target',lambda h:unit('TargetFrame','Seasoned',h,.4)),
 ('World boss',lambda h:unit('TargetFrame','Boss',h,1)),
 ('Novice player',lambda h:unit('PlayerFrame','Novice',h,.4)),
 ('Critter',lambda h:unit('TargetFrame','Critter',h,1)),
 ('Compact units and mirror timers',compact),('Nameplate native fill samples (engine crop requires live check)',nameplates),
 ('Action buttons and semantic glow',buttons),('Player castbar 0 / 40 / 100 percent',casts),('Party / raid / arena portraits',portraits),('Health threat halo and matching endcap halo',threat_sample)]
sheet=Image.new('RGBA',(1640,130+len(rows)*330),'#161a1b')
label(sheet,'HUNTER / THE UNSEEN PATH — ASSEMBLY CHECK',30,35,25)
label(sheet,'Original (left) / Hunter (right). Actual textures and layout anchors; offline, not a game screenshot.',30,80,16)
for i,(title,render) in enumerate(rows):
 y=130+i*330;label(sheet,title,30,y+15,19)
 for j,themed in enumerate([False,True]):sheet.alpha_composite(render(themed),(j*810,y+25))
sheet.save(OUT/'Hunter-Assembled-Comparison.png')
# Complete registered texture comparison at equal scale in each original/themed pair.
manifest=json.loads((ROOT/'Assets/Hunter/manifest.json').read_text())
items=[n for n,v in manifest['originals'].items() if v['disposition']=='hunter material']
contact=Image.new('RGBA',(1600,100+((len(items)+1)//2)*240+((len(manifest['additional'])+5)//6)*280+40),'#161a1b')
label(contact,'HUNTER — REGISTERED ASSET SHEET',25,35,25)
for i,n in enumerate(items):
 x=(i%2)*800;y=100+(i//2)*240
 label(contact,n, x+25,y+10,17)
 a=media(n);b=asset('Hunter/'+n+'.tga');scale=min(350/a.width,185/a.height)
 for j,im in enumerate([a,b]):put(contact,im,(x+20+j*385,y+40,a.width*scale,a.height*scale))
y=100+((len(items)+1)//2)*240
for i,n in enumerate(manifest['additional']):
 im=asset('Hunter/'+n+'.tga');x=25+(i%6)*260;yy=y+(i//6)*280
 put(contact,im,(x,yy+45,170,170));label(contact,n,x,yy+235,15)
contact.save(OUT/'Hunter-Asset-Comparison.png')
print(OUT/'Hunter-Assembled-Comparison.png')

# Full 1:1 review: all original root assets, including retained semantic masks.
all_items=list(manifest['originals'].items())
for page in range((len(all_items)+23)//24):
    audit=Image.new('RGBA',(1600,100+8*200),'#25292c')
    label(audit,'FULL HUNTER AUDIT -- original / Hunter -- page '+str(page+1),25,35,23)
    for i,(n,item) in enumerate(all_items[page*24:(page+1)*24]):
        x=(i%3)*530;y=100+(i//3)*200
        label(audit,n,x+10,y+8,13)
        label(audit,item['disposition'],x+10,y+29,11,fill='#b6c9a5')
        a=media(n); b=Image.open(ROOT/item['path']).convert('RGBA')
        if item['disposition']=='runtime replacement':b=asset('Hunter/orb-focus.tga')
        scale=min(240/a.width,145/a.height)
        for j,im in enumerate([a,b]):put(audit,im,(x+10+j*260,y+45,a.width*scale,a.height*scale))
    audit.save(OUT/('Hunter-Full-Audit-'+str(page+1)+'.png'))
