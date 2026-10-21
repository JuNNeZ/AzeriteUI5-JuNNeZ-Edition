from pathlib import Path
import sys,importlib.util,json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'Tools'))
WORK=ROOT/'Docs/Research_Assets/Warrior/Material-Refinement-2026-10-20'
spec=importlib.util.spec_from_file_location('material_native_renderer',ROOT/'Tools/Render-WarriorAssets.py');V=importlib.util.module_from_spec(spec);spec.loader.exec_module(V)
class R(V.Renderer):
    def __init__(self,old=False):super().__init__();self.old=old
    def asset(self,path):
        if path is None:return None
        relative=path.replace('\\','/').split('/Assets/')[-1]
        if relative.startswith('Warrior/'):
            name=relative.split('/',1)[1];candidate=WORK/('Before/Assets/Warrior' if self.old else 'Export')/name
            p=candidate if candidate.exists() else ROOT/'Assets/Warrior'/name
        else:p=ROOT/'Assets'/relative
        return Image.open(p).convert('RGBA')
old,new=R(True),R()
def union(images):return Image.fromarray(np.maximum.reduce([np.asarray(i)[:,:,3] for i in images])).getbbox()
def put(page,im,box,x,y,scale=1):
    crop=im.crop(box)
    if scale!=1:crop=crop.resize((crop.width*scale,crop.height*scale),Image.Resampling.LANCZOS)
    assert x+crop.width<=page.width and y+crop.height<=page.height,'review clipping'
    page.alpha_composite(crop,(x,y))
page=Image.new('RGBA',(1900,1650),'#20242c');V.label(page,'WARRIOR / QUIET MATERIAL / NATIVE BEFORE-AFTER / NONE',28,20,28)
for row,tier in enumerate(('Seasoned','Hardened','Novice','Boss')):
    y=85+row*390;V.label(page,tier.upper()+' / BEFORE LEFT / AFTER RIGHT / FULL + PARTIAL',28,y,19)
    for line,flip in enumerate((False,True)):
        scenes=[r.health(True if tier=='Boss' else flip,False,.5 if flip else 1,tier=tier,prediction=flip) for r in (old,new)]
        box=union(scenes)
        for col,im in enumerate(scenes):put(page,im,box,28+col*930,y+35+line*165)
page.convert('RGB').save(WORK/'health-all-tiers.png')
page=Image.new('RGBA',(1900,1450),'#20242c');V.label(page,'WARRIOR / NEW MATERIAL / COMPLETE NONE-ON / ACTUAL EXPORTS',28,20,27)
all_scenes=[[new.health(flip,key is not None, .5 if flip else 1,resource=None if flip else 'crystal',choice=key or 'stromkar',prediction=flip) for flip in (False,True)] for key in (None,'stromkar','warswords','wrath')]
boxes=[union([row[col] for row in all_scenes]) for col in (0,1)]
for row,key in enumerate(('NONE','STROMKAR','WARSWORDS','WRATH')):
    y=85+row*330;V.label(page,key,28,y,19)
    for col,im in enumerate(all_scenes[row]):put(page,im,boxes[col],28+col*930,y+35)
page.convert('RGB').save(WORK/'health-endcaps.png')
for key in ('stromkar','warswords','wrath'):
    page=Image.new('RGBA',(1900,1800),'#20242c');V.label(page,'WARRIOR / '+key.upper()+' / COMPLETE BARS / 2x',28,20,27)
    for row,(flip,on) in enumerate(((False,False),(False,True),(True,False),(True,True))):
        scenes=[new.health(flip,c,.5 if flip else 1,choice=key,prediction=flip) for c in (False,True)]
        box=union(scenes);y=90+row*420;V.label(page,('TARGET' if flip else 'PLAYER')+(' / ON' if on else ' / NONE'),28,y,19)
        put(page,scenes[1 if on else 0],box,28,y+35,2)
    page.convert('RGB').save(WORK/('health-'+key+'-2x.png'))
page=Image.new('RGBA',(1700,1300),'#d78432');V.label(page,'MINIMAP / NATIVE VIEWPORT / MEASURED RIM + OPENING / BEFORE-AFTER',28,20,24)
for col,r in enumerate((old,new)):
    V.label(page,'BEFORE' if r.old else 'AFTER',28+col*830,70,23)
    im=r.own('minimap-border')
    for scale,y in ((1,120),(2,550)):
        # Full native border frame, fixed shared center: no independent crop.
        size=398*scale;art=im.resize((size,size),Image.Resampling.LANCZOS)
        if scale==2:
            # Use the same union crop of both complete native textures at 2x.
            box=union([r.own('minimap-border') for r in (old,new)])
            art=im.crop(box).resize(((box[2]-box[0])*2,(box[3]-box[1])*2),Image.Resampling.LANCZOS)
        assert 28+col*830+art.width<=page.width and y+art.height<=page.height
        page.alpha_composite(art,(28+col*830,y))
page.convert('RGB').save(WORK/'minimap-1x-2x.png')
print('Rendered all tiers, native None/on health+crystal, 2x caps and minimap before/after.')
