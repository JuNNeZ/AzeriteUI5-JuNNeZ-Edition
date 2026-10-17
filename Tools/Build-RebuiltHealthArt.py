"""New whole paintings fitted to fixed native health envelopes and fill contours.

Uniform art scale; modular straight rail cuts; no motif/socket compositing.
Preview exports by default. --install copies approved local exports to Assets.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/EndcapRebuild-2026-10-17'
SOURCES=WORK/'Sources'
EXPORT=WORK/'Export'
S=Image.Resampling.LANCZOS
HEALTH=('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')
MOTIFS={
 'Hunter':('endcap-thasdorah','endcap-talonclaw','endcap-titanstrike','endcap-thoridal','endcap-raeshalare'),
 'Mage':('ornament-aluneth','ornament-felomelorn','ornament-ebonchill','ornament-atiesh','ornament-dragonwrath'),
 'Druid':('ornament-antler',)}
SPEC=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())


def read(path):return Image.open(path).convert('RGBA')
def bounds(im):return im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def halo(image):
    a=image.getchannel('A').point(lambda a:255 if a>128 else 0)
    outside=a.copy()
    ImageDraw.floodfill(outside,(0,0),128)
    solid=outside.point(lambda a:0 if a==128 else 255)
    ring=ImageChops.subtract(solid.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2)),solid)
    im=Image.new('RGBA',image.size,'white');im.putalpha(ring);return im


def rails(theme,name):
    native=read(ROOT/'Assets'/(name+'.tga'))
    source=read(SOURCES/(theme+'-health-fit.png'))
    art=source.crop(bounds(source))
    target=SPEC[name]['painted']
    # Same material scale on both axes. The entire vertical envelope, including
    # studs and dipped end, stays native-sized. Only plain horizontal runs vary.
    factor=(target[3]-target[1])/art.height
    art=art.resize((round(art.width*factor),round(art.height*factor)),S)
    delta=target[2]-target[0]-art.width
    if delta<0:
        cut=-delta;left=cut//2;a,b=round(art.width*.37),round(art.width*.64)
        assert a+left<b and b+cut-left<art.width-25
        parts=[art.crop((0,0,a,art.height)),art.crop((a+left,0,b,art.height)),art.crop((b+cut-left,0,art.width,art.height))]
    elif name=='hp_boss_case':
        a,b=round(art.width*.37),round(art.width*.64);middle=round(art.width*.5);first=delta//2
        parts=[art.crop((0,0,a,art.height)),
               art.crop((middle-first//2,0,middle-first//2+first,art.height)),
               art.crop((a,0,b,art.height)),
               art.crop((middle-(delta-first)//2,0,middle-(delta-first)//2+delta-first,art.height)),
               art.crop((b,0,art.width,art.height))]
    else:
        # Normal/low cases keep their three studs. Extend an undecorated run;
        # only the boss family receives two additional stud-bearing sections.
        seam=round(art.width*.37)
        run=art.crop((seam-10,0,seam+10,art.height))
        extension=Image.new('RGBA',(delta,art.height))
        for x in range(0,delta,run.width):
            width=min(run.width,delta-x)
            extension.alpha_composite(run.crop((0,0,width,run.height)),(x,0))
        parts=[art.crop((0,0,seam,art.height)),extension,art.crop((seam,0,art.width,art.height))]
    joined=Image.new('RGBA',(target[2]-target[0],art.height));cursor=0
    for part in parts:joined.alpha_composite(part,(cursor,0));cursor+=part.width
    front=Image.new('RGBA',native.size);front.alpha_composite(joined,tuple(target[:2]))
    fill=Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')
    pixels=np.array(front);old=np.array(native);inside=np.asarray(fill)>0
    pixels[inside,3]=0
    glass=inside & (old[:,:,3]>0) & (old[:,:,3]<=200)
    pixels[glass]=old[glass]
    front=Image.fromarray(pixels)
    back=pixels.copy();back[inside]=old[inside]
    return Image.fromarray(back),front


def sprite(path,cast=False):
    source=read(path);art=source.crop(bounds(source))
    factor=min(224/art.width,224/art.height)
    art=art.resize((round(art.width*factor),round(art.height*factor)),S)
    if not cast:
        # Shorten only the straight inlet extensions when a broad weapon head
        # would otherwise begin beyond the fixed health seam. Keep the full
        # sculpted body, all outer tips and both complete inlet ends intact.
        row=np.asarray(art)[:,:,3][art.height//2]
        first=int(np.flatnonzero(row>240)[0])
        trim=max(0,first+4-96)
        if trim:
            seam=max(12,first//3)
            assert seam+trim<first-3
            shortened=Image.new('RGBA',(art.width-trim,art.height))
            shortened.alpha_composite(art.crop((0,0,seam,art.height)))
            shortened.alpha_composite(art.crop((seam+trim,0,art.width,art.height)),(seam,0))
            art=shortened
    result=Image.new('RGBA',(256,256))
    # Exactly Paladin's intact-painting convention: health attaches from the
    # left, cast from the right. No backing shape or old motif is added.
    x=248-art.width if cast else 4
    result.alpha_composite(art,(x,(256-art.height)//2))
    return result


def build(install=False):
    inventory={'method':'new whole source paintings; uniform scales and modular native rail envelopes',
               'healthSlot':{'size':88,'x':14,'y':0,'reference':40,'defaultScale':1.3},
               'castSlot':{'size':48,'x':-8,'y':0},'files':{},'sources':{},
               'liveValidated':False}
    lock=WORK/'protected-sources.json'
    if not lock.exists():
        protected={p.relative_to(ROOT).as_posix():digest(p) for folder,pattern in
                   ((ROOT/'Assets','*.tga'),(ROOT/'Assets/Paladin','*.tga'),(ROOT/'Layouts/Data','*.lua'))
                   for p in folder.glob(pattern)}
        lock.write_text(json.dumps(protected,indent=2),encoding='utf-8')
    inventory['protected']=json.loads(lock.read_text(encoding='utf-8'))
    for path in SOURCES.glob('*.png'):inventory['sources'][path.name]=digest(path)
    def save(theme,name,im):
        path=EXPORT/theme/(name+'.tga');path.parent.mkdir(parents=True,exist_ok=True)
        im.save(path);im.save(path.with_suffix('.png'))
        assert read(path).tobytes()==im.tobytes()
        rel='Assets/'+theme+'/'+path.name
        inventory['files'][rel]={'size':list(im.size),'sha256':digest(path)}
        if install:
            destination=ROOT/rel
            frozen=WORK/'Before'/theme/path.name
            if destination.exists() and not frozen.exists():
                frozen.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(destination,frozen)
            shutil.copyfile(path,destination)
    for theme,names in MOTIFS.items():
        for name in names:
            im=sprite(SOURCES/(name+'.png'))
            save(theme,name+'-fitted',im);save(theme,name+'-fitted-glow',halo(im))
        cast=sprite(SOURCES/(theme+'-cast-head.png'),True)
        save(theme,'cast-head-fitted',cast)
        if theme=='Druid':
            # Neutral light follows the new painted moonstone's cool pixels;
            # never carry the old socket's differently positioned light mask.
            p=np.asarray(cast)
            moon=(p[:,:,2]>p[:,:,0]*.85)&(p[:,:,2]>p[:,:,1]*.85)&(p[:,:,0]>130)
            light=Image.new('RGBA',cast.size,'white')
            light.putalpha(Image.fromarray(np.where(moon,p[:,:,3]*.5,0).astype('uint8')))
            save(theme,'cast-head-fitted-light',light)
        for native in HEALTH:
            name=native+('-fitted' if theme=='Hunter' else '')
            back,front=rails(theme,native)
            for suffix,im in (('',back),('-over',front),('-glow',halo(front))):
                save(theme,name+suffix,im)
            if theme=='Mage':save(theme,name+'-fitted-glow',halo(front))
            # Paladin shoulder method: preserve the bar and functional fill,
            # remove only the lower dropped spur underneath the complete relic.
            opaque=np.asarray(front)[:,:,3]>128
            bottom=front.height-1-opaque[::-1].argmax(0)
            x0,y0,x1,y1=SPEC[native]['meter']
            rail_bottom=int(np.median(bottom[x0+60:x1-100]))
            for suffix,im in (('',back),('-over',front)):
                p=np.array(im);yy,xx=np.mgrid[:im.height,:im.width]
                cut=(xx>x1-90)&(yy>rail_bottom)
                p[cut,3]=0
                mounted=Image.fromarray(p);save(theme,name+'-capped'+suffix,mounted)
                if suffix:save(theme,name+'-capped-glow',halo(mounted))
    (WORK/'manifest.json').write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8')
    print('Rebuilt',len(inventory['files']),'whole-art exports; install='+str(install))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--install',action='store_true')
    build(parser.parse_args().install)
