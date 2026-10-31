"""Read-only installed crystal/orb audit. Static art is not live frame-level proof."""
from pathlib import Path
import importlib.util
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/ThemeCrystalAudit-2026-10-30'
THEMES=('OG','Hunter','Mage','Paladin','Druid','Warrior','Rogue','Shaman')

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

P=module('crystal_audit_projection','PaladinFillContracts.py')
M=module('crystal_audit_render','Build-ImplementedThemeSheets.py')

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def asset(theme,name):return ROOT/'Assets'/(theme if theme!='OG' else '')/(name+'.tga')
def image(path):return Image.open(path).convert('RGBA')

def metric(path,native):
    im=image(path);a=np.asarray(im)[:,:,3];n=image(native);na=np.asarray(n)[:,:,3]
    b=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    normalized=[b[i]/(im.width/n.width if i%2==0 else im.height/n.height) for i in range(4)] if b else None
    ys=np.flatnonzero(a[:,im.width//2]>200)
    return {'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'canvas':im.size,
        'normalizedBounds':normalized,'paintedWidth':normalized[2]-normalized[0] if b else None,
        'paintedHeight':normalized[3]-normalized[1] if b else None,
        'centreOpaqueSpan':float((ys[-1]-ys[0]+1)/(im.height/n.height)) if len(ys) else None,
        'centreRailTop':float(ys[0]/(im.height/n.height)) if len(ys) else None,
        'alphaEqualsNative':im.size==n.size and np.array_equal(a,na)}

def crystal(theme,tier,fraction):
    base=P.LAYOUTS['PlayerFrame'];db=dict(base);db.update(base[tier])
    r=M.Renderer.__new__(M.Renderer);r.theme=theme;r.sources={}
    def read(path):
        relative=path.replace('\\','/').split('/Assets/')[-1]
        return image(ROOT/'Assets'/relative)
    r.asset=read
    scene=Image.new('RGBA',(290,270));bar=(40,10,*db['PowerBackdropSize'])
    r.put(scene,read(db['PowerBackdropTexture']),bar)
    if theme=='Druid':r.put(scene,image(asset(theme,'crystal-roots-back')),bar)
    r.fill(scene,db['PowerBarTexture'],bar,fraction,db['PowerBarColors']['MANA'],vertical=True)
    if theme=='Druid':
        r.put(scene,image(asset(theme,'crystal-roots-front')),bar)
    else:
        _,case=P.crystal_rects(db)
        if theme=='Hunter':case=(-1,121,198,98) # actual HunterTheme:StyleCrystal hook
        rect=(bar[0]+case[0],bar[1]+case[1],case[2],case[3])
        name='pw_crystal_case_low' if tier=='Novice' else 'pw_crystal_case'
        r.put(scene,image(asset(theme,name)),rect,tint=db['PowerBarForegroundColor'] if theme=='OG' else None)
    return scene

def main():
    WORK.mkdir(parents=True,exist_ok=True)
    protected={p.relative_to(ROOT).as_posix():sha(p) for folder in ('Assets','Core','Layouts','Options') for p in (ROOT/folder).rglob('*') if p.is_file()}
    report={};scenes={}
    names=('pw_crystal_case','pw_crystal_case_low','orb_case_hi','orb_case_low')
    for theme in THEMES:
        report[theme]={'textures':{},'runtime':'whole resource roots hide ordinary casing' if theme=='Druid' else 'native holder rectangle with Hunter hook offset' if theme=='Hunter' else 'native holder rectangle'}
        for name in names:
            path=asset(theme,name)
            if path.exists():report[theme]['textures'][name]=metric(path,ROOT/'Assets'/(name+'.tga'))
        for tier in ('Seasoned','Novice'):
            for fraction in (1,.5,0):scenes[(theme,tier,fraction)]=crystal(theme,tier,fraction)
    box=Image.fromarray(np.maximum.reduce([np.asarray(scene)[:,:,3] for scene in scenes.values()])).getbbox()
    w=box[2]-box[0];h=box[3]-box[1]
    for tier in ('Seasoned','Novice'):
        for scale in (1,2):
            page=Image.new('RGBA',(4*(w*scale+35),2*(h*scale+65)+55),'#171b20');draw=ImageDraw.Draw(page)
            draw.text((15,15),'INSTALLED CRYSTAL CASINGS / '+tier+' / '+str(scale)+'x / SAME RESOURCE SIZE / OFFLINE',fill='white')
            for i,theme in enumerate(THEMES):
                x=15+(i%4)*(w*scale+35);y=55+(i//4)*(h*scale+65)
                draw.text((x,y),theme+(' / actual root assembly' if theme=='Druid' else ''),fill='white')
                art=scenes[(theme,tier,1)].crop(box).resize((w*scale,h*scale),Image.Resampling.LANCZOS)
                page.alpha_composite(art,(x,y+25))
            page.convert('RGB').save(WORK/('overview-'+tier.lower()+'-'+str(scale)+'x.png'))
    for theme in THEMES:
        page=Image.new('RGBA',(3*(w+35),2*(h+55)+45),'#171b20');draw=ImageDraw.Draw(page)
        draw.text((15,10),theme+' / INSTALLED ART / SHARED NATIVE FILL / 1x / STATIC EFFECTS',fill='white')
        for row,tier in enumerate(('Seasoned','Novice')):
            for col,fraction in enumerate((1,.5,0)):
                x=15+col*(w+35);y=45+row*(h+55)
                draw.text((x,y),tier+' / '+str(round(fraction*100))+'%',fill='white')
                page.alpha_composite(scenes[(theme,tier,fraction)].crop(box),(x,y+22))
        page.convert('RGB').save(WORK/(theme.lower()+'-fill-states.png'))
    after={p.relative_to(ROOT).as_posix():sha(p) for folder in ('Assets','Core','Layouts','Options') for p in (ROOT/folder).rglob('*') if p.is_file()}
    assert after==protected,'Read-only audit detected concurrent protected-file change; rerun snapshot'
    result={'themes':report,'protectedFilesVerifiedUnchanged':len(protected),'layoutExport':'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/layouts.json',
        'limitations':['static casing/roots and native fills; animated effects, Mage badge, live layering and saved user offsets not simulated',
                       'matching native alpha/bounds is not intact-source proof or visual approval'],
        'liveRetailValidated':False,'liveForeverValidated':False}
    (WORK/'audit.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('Audited eight themes, two crystal variants and orb geometry. Protected files unchanged:',len(protected))

if __name__=='__main__':main()
