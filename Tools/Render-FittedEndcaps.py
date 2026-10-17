"""Review actual exports at native layout sizes, never an invented HUD layout.

Uses the real layout tables exported by hunter_theme_harness.lua, the runtime
Hunter fitting equation and the identical fitted slots. Offline reconstruction:
no live model, secret-value clipping, native font metrics or WoW animation.
"""
from pathlib import Path
import json
import importlib.util
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/EndcapFit-2026-10-17'
DATA=json.loads((WORK/'layouts.json').read_text())
S=Image.Resampling.LANCZOS
FONT='C:/Windows/Fonts/georgia.ttf'
spec=importlib.util.spec_from_file_location('base',ROOT/'Tools/Build-ThemeConceptBase.py')
B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)
DEFAULT={'Hunter':'endcap-thasdorah-fitted','Mage':'ornament-aluneth-fitted','Druid':'ornament-antler-fitted','Paladin':'ornament-ashbringer'}
DRAFT = '--draft' in sys.argv


def source(theme,name):
    draft=ROOT/'Docs/Research_Assets/EndcapRebuild-2026-10-17/Export'/theme/(name+'.tga')
    return draft if DRAFT and draft.exists() else ROOT/'Assets'/theme/(name+'.tga')


def read(theme,name):
    return Image.open(source(theme,name)).convert('RGBA')


def text(board,string,x,y,size=18):
    ImageDraw.Draw(board).text((x,y),string,font=ImageFont.truetype(FONT,size),fill='#d9d1bc')


def health(theme,enabled,fraction=1,flip=False,tier='Seasoned',motif=None):
    layouts=DATA['hunter' if theme=='Hunter' else 'original']
    kind='TargetFrame' if flip else 'PlayerFrame'
    base=layouts[kind];db=dict(base);db.update(base[tier])
    owner=(300 if flip else 100,60,*base['Size']);hp=B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
    scene=Image.new('RGBA',(1200,350));x,y,w,h=hp
    name='hp_boss_case' if tier=='Boss' else 'hp_cap_case' if tier=='Seasoned' else 'hp_low_case'
    casing=B.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
    if theme=='Hunter':name+='-fitted'
    key=(motif or DEFAULT[theme]).removeprefix('endcap-').removeprefix('ornament-').removesuffix('-fitted')
    aligned=source(theme,'ornament-'+key+'-'+name.removesuffix('-fitted'))
    suffix='-capped' if enabled and not aligned.exists() else ''
    B.put(scene,read(theme,name+suffix),casing,flip)
    fill_path=db['HealthBarTexture']
    if theme=='Hunter':fill_path='Interface/Assets/'+Path(fill_path.replace('\\','/')).name
    B.fill(scene,fill_path,hp,1,(.09,.08,.11),flip)
    B.fill(scene,fill_path,hp,fraction,(.84,.03,.08),flip)
    overlay=source(theme,name+suffix+'-over')
    if overlay.exists():B.put(scene,Image.open(overlay).convert('RGBA'),casing,flip)
    if enabled:
        if aligned.exists():
            B.put(scene,Image.open(aligned).convert('RGBA'),casing,flip)
        else:
            size=88*h/40*1.3
            cx=x-14*h/40 if flip else x+w+14*h/40
            B.put(scene,read(theme,motif or DEFAULT[theme]),(cx-size/2,y+(h-size)/2,size,size),flip)
    if flip and db.get('PortraitBorderTexture'):
        name=Path(db['PortraitBorderTexture'].replace('\\','/')).stem
        B.put(scene,read(theme,name),B.anchor(owner,db['PortraitBorderSize'],db['PortraitBorderPosition']))
    return scene.crop(scene.getbbox())


def cast(theme,enabled,fraction=.5):
    db=DATA['hunter' if theme=='Hunter' else 'original']['PlayerCastBar']
    scene=Image.new('RGBA',(500,240));hp=(160,100,*db['CastBarSize']);x,y,w,h=hp
    casing=B.anchor(hp,db['CastBarBackgroundSize'],db['CastBarBackgroundPosition'])
    name='cast_back'+('-capped' if enabled and theme!='Paladin' else '')
    B.put(scene,read(theme,name),casing)
    B.fill(scene,db['CastBarTexture'],hp,1,(.09,.08,.11))
    B.fill(scene,db['CastBarTexture'],hp,fraction,(.3,.65,.2))
    over=source(theme,name+'-over')
    if over.exists():B.put(scene,Image.open(over).convert('RGBA'),casing)
    if enabled:
        size=48;cx=x+(-26 if theme=='Paladin' else -8)
        B.put(scene,read(theme,'cast-head-libram' if theme=='Paladin' else 'cast-head-fitted'),(cx-size/2,y+(h-size)/2,size,size))
    return scene.crop(scene.getbbox())


def build():
    for theme in (*DEFAULT,):
        board=Image.new('RGBA',(1536,1120),'#14161a')
        text(board,'AZERITEUI / '+theme.upper()+' / FITTED ENDCAPS',32,24,30)
        text(board,'Actual exported art and layout equations. Offline reconstruction; no live-client confirmation.',32,70,16)
        text(board,'ENDCAP OFF - complete themed bar',32,115,20)
        text(board,'ENDCAP ON - mounted over the termination',790,115,20)
        rows=[('Player / full',False,'Seasoned',1),('Target / partial',True,'Seasoned',.4),
              ('Target / boss',True,'Boss',1),('Player / empty',False,'Novice',0)]
        for i,(label,flip,tier,fraction) in enumerate(rows):
            y=165+i*180;text(board,label,32,y,16)
            for j,enabled in enumerate((False,True)):
                image=health(theme,enabled,fraction,flip,tier)
                B.put(board,image,(32+j*758,y+28,image.width,image.height))
        text(board,'Player castbar / partial / independent choice',32,900,18)
        for j,enabled in enumerate((False,True)):
            image=cast(theme,enabled)
            B.put(board,image,(100+j*758,945,image.width,image.height))
            B.put(board,image,(340+j*758,920,image.width*2,image.height*2))
        text(board,'Native scale at left of each cast sample; 2x detail beside it. Fills, saved anchors and base casing art retained.',32,1070,15)
        out=ROOT/'Docs/Research_Assets/EndcapRebuild-2026-10-17/Preview' if DRAFT else WORK
        out.mkdir(parents=True,exist_ok=True)
        board.convert('RGB').save(out/(theme+'-fit-review.png'))
        # Supplemental exact-art board is authoritative for established themes.
        target=ROOT/'Docs/Research_Assets/ClassConceptSheets-2026-10-17'/(theme.lower()+'-endcap-fit.png')
        if not DRAFT:board.convert('RGB').save(target)
    print('Rendered four exact-art on/off review sheets.')


if __name__=='__main__':build()
