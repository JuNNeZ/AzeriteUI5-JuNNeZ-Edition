"""Complete matched-scale original/Paladin inventory from actual exported TGAs."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parent.parent
A = ROOT/'Assets'
OUT = ROOT/'Docs/Research_Assets/Paladin/Revision5'
S = Image.Resampling.LANCZOS

def read(name, paladin=False):
    return Image.open(A/('Paladin' if paladin else '')/(name+'.tga')).convert('RGBA')

def tint(im, color):
    result = ImageChops.multiply(im, Image.new('RGBA', im.size, color))
    result.putalpha(im.getchannel('A'))
    return result

def bar(name, paladin, flip=False, boss=False):
    health = name.startswith('health-')
    boss = boss or 'small' in name
    w,h = ((533,40) if 'wide' in name else (385,37) if 'portrait' in name or 'lowmid' in name else (385,40)) if health and not boss else (112,11)
    if paladin and name in ('health-case','health-glow'):w=373
    if paladin and name=='lion-cast':w,h=w*2.25,h*2.25
    result = Image.new('RGBA', (800,270))
    x,y = (800-w)//2, 120
    if paladin:
        if 'wide' in name:sw,r,ft,fb=2671,2414,2/64,48/64
        elif 'portrait' in name:sw,r,ft,fb=2141,1884,3/128,100/128
        elif 'lowmid' in name:sw,r,ft,fb=2043,1786,2/64,52/64
        elif 'small' in name:sw,r,ft,fb=1821,1494,1/32,1
        else:sw,r,ft,fb=2011,1754,3/128,100/128
        sh,l,t,b=724,(82 if 'small' in name else 62),306,436
        if not health:sw,sh,l,t,r,b,ft,fb=2018,724,342,288,1739,421,1/32,1
        sx,sy=w/(r-l),h*(fb-ft)/(b-t)
        art = read(name, True).resize((round(sw*sx),round(sh*sy)), S)
        if flip: art = art.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        result.alpha_composite(art,(round(x-(sw-r if flip else l)*sx), round(y+h*ft-t*sy)))
    else:
        original = ('hp_cap_case_glow' if name.endswith('glow') else 'hp_cap_case') if health and not boss else 'cast_back'
        if 'wide' in name: original = 'hp_boss_case_glow' if name.endswith('glow') else 'hp_boss_case'
        size = ((697,192) if 'wide' in name else (716,188)) if health and not boss else (193,93)
        art = read(original).resize(size,S)
        if flip: art = art.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        # Player anchors: bar bottom-left148,27; casing bottom-left-17,-48.
        px,py = (x-165,y-73) if health and not boss else (round(x+(w-size[0])/2+1),round(y+(h-size[1])/2+2))
        if 'portrait' in name: px,py = x-163.5,y-74.5
        if 'wide' in name: px,py = x-82,y-76.5
        result.alpha_composite(art,(round(px),round(py)))
    return result

rows = [
 ('Player health casing','hp_cap_case','health-case','Player meter shortened from 385 to 373; fitted opening'),
 ('Target / alternate health casing','hp_cap_case','health-portrait','Native 385 x 37 meter; mirrored casing'),
 ('Boss health casing','cast_back','health-small','Native 112 x 11 meter; same ornate family'),
 ('Player castbar casing','cast_back','lion-cast','Player cast meter at 225% of original; lion scales with fill'),
 ('Nameplate health / cast / power','nameplate_backdrop','plate-case','Exact original canvas + alpha; background layer'),
 ('Portrait frame: high detail','portrait_frame_hi','portrait-case','Exact original hexagon + glass alpha'),
 ('Portrait frame: low detail','portrait_frame_lo','portrait-case-low','Separate original low-detail alpha'),
 ('Minimap ring','minimap-border','minimap-ring','Exact original circle, opening and padding'),
 ('Action / pet / stance / extra buttons','actionbutton-border','action-ring','Exact original ring + icon opening'),
 ('Utility cog / hover','config_button','utility-cog','Original cog size; hover adds a gentle highlight'),
 ('Focus / target-of-target','cast_back','compact-case','Exact original casing + native layout'),
 ('Tooltip / menu border atlas','border-tooltip','utility-edge','Eight original cells; same gutters and alpha'),
 ('Earlier star study (unused)','point_crystal','seal','Retained source export; replaced by the sacred seal below'),
 ('Mana crystal casing','pw_crystal_case','crystal-holder','Original painted width; detailed lion retained'),
 ('Mana orb casing','orb_case_hi','orb-case','Existing 188 x 188 layout; detailed lion retained'),
 ('Crystal mana fill','power_crystal_front',None,'Same original facets; blue mana / runtime Holy Light'),
 ('Orb rotating body','orb2','orb-light','Original orb mask; neutral body before runtime tint'),
 ('Orb light strands',None,'orb-strands','New white layer; follows native orb clipping'),
 ('Crystal light strands',None,'light-strands','New white layer; crystal mask applied in game'),
 ('Neutral light source',None,'light-body','Source export; not assigned directly to crystal fill'),
 ('Health threat silhouette','hp_cap_case_glow','health-glow','Neutral tintable silhouette of the revised casing'),
 ('Crystal threat silhouette','pw_crystal_case_glow','crystal-holder-glow','Neutral silhouette; follows corrected holder size'),
 ('Orb threat silhouette','orb_case_glow','orb-case-glow','Neutral silhouette of detailed orb casing'),
 ('Utility backing','point_plate','utility-plate','Original circular plate alpha; subdued material'),
 ('Earlier final-point backing','point_diamond',None,'Reference only; Holy Power now uses a dedicated casing'),
]
rows.extend([
 ('Wide target health','hp_boss_case','health-wide','Native 533 x 40 world-boss target meter'),
 ('Portrait health threat','hp_cap_case_glow','health-portrait-glow','Neutral silhouette; portrait meter proportions'),
 ('Wide health threat','hp_boss_case_glow','health-wide-glow','Neutral silhouette; wide meter proportions'),
 ('Party / raid / arena portrait','party_portrait_border','party-case','Exact original circular opening and canvas'),
 ('Vehicle exit','icon_exit_flight','vehicle-exit','Original silhouette; red arrow retained'),
 ('Experience / reputation backdrop','minimap-onebar-backdrop','status-backdrop','Exact original radial backdrop alpha'),
 ('Critter target casing','hp_critter_case','critter-case','Exact original compact shape and canvas'),
])
rows.extend([
 ('Novice / hardened health','hp_low_case','health-lowmid','Opening inset into the native angled fill'),
 ('Novice / hardened threat','hp_low_case_glow','health-lowmid-glow','Same corrected geometry as its casing'),
 ('Boss unit threat silhouette','cast_back','health-small-glow','Neutral source export for the compact blade'),
 ('Holy Power sacred casing','point_plate','holy-case','Upright cartoon diamond and flame crown'),
 ('Holy Power charged center','point_crystal','holy-fill','Neutral star/lozenge; runtime Holy Power tint'),
])
manifest = json.loads((A/'Paladin/manifest.json').read_text())
assert {r[2] for r in rows if r[2]} == {n for n in manifest if not n.startswith('_')}
exact = {'plate-case','portrait-case','portrait-case-low','minimap-ring','action-ring','utility-cog','compact-case','utility-edge','seal','party-case','utility-plate','vehicle-exit','status-backdrop','critter-case'}
W,CELLW,CELLH = 2400,1160,290
sheet = Image.new('RGBA',(W,180+((len(rows)+1)//2)*CELLH+80),'#101217')
d=ImageDraw.Draw(sheet)
def text(x,y,s,size=21,color='#c4c4ce',bold=False):
    font=ImageFont.truetype('C:/Windows/Fonts/'+('segoeuib.ttf' if bold else 'segoeui.ttf'),size)
    d.text((x,y),s,font=font,fill=color)
text(45,25,'AZERITEUI  /  PALADIN — COMPLETE ASSET COMPARISON',38,'#e1c47e',True)
text(45,82,'Original on the left of every pair. Paladin on the right. Same scale within each pair; no independent stretching.',23)
text(45,118,'Actual exported textures • revised secondary frames • original gameplay masks • offline artwork review, not a WoW screenshot',21,'#9697a8')
for i,(title,before,after,note) in enumerate(rows):
    x=40+(i%2)*1180; y=180+(i//2)*CELLH
    d.line((x,y,x+CELLW-20,y),fill='#39333b',width=2)
    text(x+8,y+10,f'{i+1:02}  {title}',23,'#e1c47e',True)
    text(x+8,y+45,note,18)
    text(x+80,y+78,'AZERITEUI ORIGINAL',16,'#91949e')
    text(x+635,y+78,'PALADIN',16,'#bba770')
    if after and (after.startswith('health-') or after=='lion-cast'):
        aa=bar(after,False,flip=i==1,boss=i==2); bb=bar(after,True,flip=i==1,boss=i==2)
    else:
        aa=read(before) if before else None
        bb=read(after,True) if after else aa.copy()
        if i==15:
            aa=tint(aa,(45,110,255,255)); bb=tint(bb,(255,199,71,255))
        if i==24: bb=tint(bb,(41,36,46,255))
        if after in exact:
            assert aa.size==bb.size,after
            assert ImageChops.difference(aa.getchannel('A'),bb.getchannel('A')).getbbox() is None,after
    # Shared crop, including runtime bar canvases; never fit variants separately.
    if aa and aa.size==bb.size:
        union=ImageChops.lighter(aa.getchannel('A'),bb.getchannel('A')).point(lambda v:255 if v>32 else 0).getbbox()
        aa=aa.crop(union);bb=bb.crop(union)
    imgs=[im for im in (aa,bb) if im]
    scale=min(500/max(im.width for im in imgs),150/max(im.height for im in imgs))
    for col,im in enumerate((aa,bb)):
        cx=x+280+col*550;cy=y+183
        if im is None:
            text(cx-175,cy-10,'No original equivalent — added layer',18,'#737684')
            continue
        im=im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),S)
        sheet.alpha_composite(im,(round(cx-im.width/2),round(cy-im.height/2)))
    text(x+8,y+259,(before or 'new layer')+'  →  '+(after or 'original texture + runtime color'),16,'#838693')
text(45,sheet.height-52,'35 exported Paladin textures accounted for. Detailed main HUD; simple secondary frames. Live scaling / clipping still needs /reload verification.',20)
sheet.save(OUT/'Paladin-Full-Comparison.png')
sheet.convert('RGB').save(OUT/'Paladin-Full-Comparison.jpg',quality=95)
print(OUT/'Paladin-Full-Comparison.png')
