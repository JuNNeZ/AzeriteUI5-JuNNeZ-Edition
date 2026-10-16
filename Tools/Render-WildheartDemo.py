"""Actual installed textures + real Wildheart Lua samples. Offline approximation.
Export samples with wildheart_crystal_harness.lua . samples <OUT>/lua-samples.json.
BLEND/ADD, UVs and masks are reproduced in Pillow; not a WoW client capture.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--compare',action='store_true')
parser.add_argument('--persistent-compare',action='store_true')
parser.add_argument('--flavour',choices=('wildheart','moonvein','dreamsap'),default='wildheart')
args=parser.parse_args()
BASE=ROOT/'Docs/Research_Assets/Druid/Wildheart-2026-10-16'
assert not (args.compare and args.persistent_compare)
FAMILY=BASE/('Persistent-v1' if args.persistent_compare else 'Flavours-v1')
OUT=FAMILY if args.compare else FAMILY/args.flavour
KEYS=('moonvein','dreamsap','wildheart') if args.compare else (args.flavour,)
DATA={key:json.loads((FAMILY/key/'lua-samples.json').read_text()) for key in KEYS}
S=Image.Resampling.LANCZOS
N=196 if args.persistent_compare else 256  # full native canvas, never legacy crop
SIZE=(960,680) if args.persistent_compare else (960,780)
FILLS=(1,.5,.1,0) if args.persistent_compare else (1,.5,0)
paths={'native':'power_crystal_front.tga','back':'power_crystal_back.tga',
       'rootsBack':'Druid/crystal-roots-back.tga','rootsFront':'Druid/crystal-roots-front.tga',
       'veins':'Druid/wildheart-veins.tga','moon':'Druid/dreamlight.tga','sphere':'Paladin/holy-sphere.tga','globule':'orb2.tga'}
imgs={k:Image.open(ROOT/'Assets'/v).convert('RGBA') for k,v in paths.items()}

def array(im): return np.asarray(im,dtype=np.float32)/255
def tint(im,color):
    a=array(im).copy();a[:,:,:3]*=color;return a
def premult(a): return a[:,:,:3]*a[:,:,3:4]
def over(dst,src): return dst*(1-src[:,:,3:4])+premult(src)

native=imgs['native'].resize((N,N),S)
mask=array(native)[:,:,3:4]
veinMask=array(imgs['veins'].resize((N,N),S))[:,:,3:4]
veins=premult(array(imgs['veins'].resize((N,N),S)))
front=array(imgs['rootsFront'].resize((N,N),S))
background=np.full((N,N,3),[18/255,26/255,29/255],dtype=np.float32)
for k in ('back','rootsBack'): background=over(background,array(imgs[k].resize((N,N),S)))
clips={}
for fill in FILLS:
    edge=np.ones((N,N,1),dtype=np.float32);edge[:round(N*(1-fill))]=0
    clips[fill]=mask*edge
bases={}
for key,data in DATA.items():
    bases[key]={}
    for fill in FILLS:
        edge=np.ones((N,N,1),dtype=np.float32);edge[:round(N*(1-fill))]=0
        a=tint(native,(.48,.28,.95));a[:,:,3:4]*=edge
        b=over(background,a)
        a=tint(native,data['palette']['body']);a[:,:,3:4]*=.92*mask*edge
        bases[key][fill]=over(b,a)

def sprite(position,size,texture='sphere'):
    sprite=imgs[texture].resize((max(1,round(size[0])),max(1,round(size[1]))),S)
    canvas=Image.new('RGBA',(N,N));canvas.alpha_composite(sprite,(round(N*position[0]-sprite.width/2),round(N*(1-position[1])-sprite.height/2)))
    return premult(array(canvas))

def uv(coords):
    # Same affine UV quad used by Texture:SetTexCoord(UL,LL,UR,LR).
    w,h=imgs['moon'].size
    a,b,c,d,e,f,g,j=coords
    return imgs['moon'].transform((N,N),Image.Transform.AFFINE,
        ((e-a)*w/N,(c-a)*w/N,a*w,(f-b)*h/N,(d-b)*h/N,b*h),Image.Resampling.BILINEAR)

def emission(s,palette):
    light=veins*palette['veins']*s['veins']
    for mist,color in zip(s['mist'],palette['mist']):
        light=light+premult(tint(uv(mist['coords']),color))*mist['alpha']
    u,v=s['u'],s['v']
    moon=uv((u,v,u,v+.95,u+.95,v,u+.95,v+.95))
    light+=premult(tint(moon,palette['moon']))*s['moonAlpha']
    for pulse in s['pulses']:
        if pulse['alpha']:
            light+=sprite((pulse['x'],pulse['y']),(N*.22,N*.25))*palette['pulse']*pulse['alpha']*veinMask
    if s['coreAlpha']:
        light+=sprite((s['coreX'],s['coreY']),(N*.12*s['coreScale'],N*.17*s['coreScale']))*palette['core']*s['coreAlpha']
    for m in s['motes']:
        texture='globule' if palette['moteTexture']=='orb2.tga' else 'sphere'
        light+=sprite((m['x'],m['y']),(N*m['size'],N*m['size']),texture)*palette['mote']*m['alpha']
    return light

font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14)
head=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',27)
board=Image.new('RGB',SIZE,'#121a1d');d=ImageDraw.Draw(board)
title='Druid · '+('tre levende krystaller' if args.compare else args.flavour.title())
d.text((30,16),title, font=head,fill='#e2e6d8')
d.text((30,55),'Fyldet falder · magien fortsætter gennem krystallen' if args.persistent_compare else ('Sølvstrømme · gylden drømmesaft · levende rodårer' if args.compare else 'Samme godkendte rødder, størrelse og native fyldmaske'),font=font,fill='#a8bbb5')
if args.persistent_compare:
    for col,fill in enumerate(FILLS):d.text((120+col*240,94),str(round(fill*100))+' %',anchor='mt',font=font,fill='#d4ddc9')
    for row,label in enumerate(('Tidligere: fyld og effekt falder sammen','Ny: svag magi i hele krystallen + ekstra lys i fyldet')):
        d.text((30,116+row*260),label,font=small,fill='#d4ddc9')
if args.compare:
    for col,key in enumerate(KEYS):d.text((160+col*320,88),key.title(),anchor='mt',font=font,fill='#d4ddc9')
for row,label in enumerate(() if args.persistent_compare else (('Rolig · 100 % fyld','Combat / mounted / flying · 50 % fyld') if args.compare else ('Rolig strømning','Combat / mounted / flying · hurtigere strømning'))):
    y=(145 if args.compare else 125)+row*320;d.text((30,y-29),label,font=small if args.compare else font,fill='#d4ddc9')
    for col,fill in enumerate((1,.5,0)):
        if not args.compare:d.text((160+col*320,y+258),str(round(fill*100))+'%',font=small,anchor='mt',fill='#a8bbb5')
d.text((480,SIZE[1]-21),'Installerede assets + Lua-samples · '+('196px native størrelse' if args.persistent_compare else '1,31×')+' · offline, ikke WoW-optagelse',font=small,anchor='ms',fill='#90a5a0')

def frame(index):
    result=board.copy()
    if args.persistent_compare:
        key=KEYS[0];data=DATA[key]
        light=emission(data['quiet'][index],data['palette'])
        for row in range(2):
            for col,fill in enumerate(FILLS):
                energy=clips[fill] if row==0 else mask*data['emptyEnergy']+clips[fill]*(1-data['emptyEnergy'])
                crystal=over(np.clip(bases[key][fill]+light*energy,0,1),front)
                result.paste(Image.fromarray(np.uint8(np.clip(crystal*255,0,255))),(22+col*240,145+row*260))
        return result
    for row,mode in enumerate(('quiet','active')):
        for key in KEYS:
            data=DATA[key];light=emission(data[mode][index],data['palette'])
            for col,fill in enumerate((1,.5,0)):
                if args.compare:
                    if fill!=(1 if row==0 else .5):continue
                    col=KEYS.index(key)
                empty=data.get('emptyEnergy',0)
                crystal=over(np.clip(bases[key][fill]+light*(mask*empty+clips[fill]*(1-empty)),0,1),front)
                result.paste(Image.fromarray(np.uint8(np.clip(crystal*255,0,255))),(32+col*320,(145 if args.compare else 125)+row*320))
    return result

raw=OUT/'frames.mkv';output=OUT/(args.flavour+'-persistent-comparison.gif' if args.persistent_compare else ('druid-three-flavours.gif' if args.compare else args.flavour+'-dynamic.gif'))
meta=DATA[KEYS[0]]
proc=subprocess.Popen(['ffmpeg','-v','error','-y','-f','rawvideo','-pixel_format','rgb24','-video_size',f'{SIZE[0]}x{SIZE[1]}','-framerate',str(meta['fps']),'-i','pipe:0','-c:v','ffv1',str(raw)],stdin=subprocess.PIPE)
for i in range(len(meta['quiet'])):
    im=frame(i)
    if i in (0,40,80,120):im.save(OUT/('frame-'+str(i)+'.png'))
    proc.stdin.write(im.tobytes())
proc.stdin.close();assert proc.wait()==0
subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-filter_complex','[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(output)],check=True)
gif=Image.open(output);assert gif.n_frames==160 and gif.size==SIZE
duration=0
for i in range(gif.n_frames):gif.seek(i);gif.load();duration+=gif.info.get('duration',0)
assert duration==8000
assert ImageChops.difference(frame(0).crop((32,125,288,381)),frame(40).crop((32,125,288,381))).getbbox()
if args.persistent_compare:
    before,after=frame(0),frame(40)
    assert ImageChops.difference(before.crop((742,145,938,341)),after.crop((742,145,938,341))).getbbox() is None
    assert ImageChops.difference(before.crop((742,405,938,601)),after.crop((742,405,938,601))).getbbox()
    # At full fill ambient+bright equals the former single light layer.
    fullOld=np.asarray(before.crop((22,145,218,341)),dtype=int)
    fullNew=np.asarray(before.crop((22,405,218,601)),dtype=int)
    assert np.max(np.abs(fullOld-fullNew))<=1
elif not args.compare:
    emptyDiff=ImageChops.difference(frame(0).crop((672,125,928,381)),frame(40).crop((672,125,928,381))).getbbox()
    assert bool(emptyDiff)==bool(meta.get('emptyEnergy',0))
manifest={'liveCapture':False,'frames':160,'fps':20,'seconds':8,'bytes':output.stat().st_size,
    'samples':'real material sampler and palettes; quiet rate 1, active rate 2; no movement impulse in this loop',
    'flavours':list(KEYS),
    'persistentComparison':args.persistent_compare,
    'emptyEnergy':meta.get('emptyEnergy',0),
    'limitations':'Offline BLEND/ADD approximation; WoW mask intersection, combat rendering and cost need client tests.',
    'luaSha256':hashlib.sha256((ROOT/'Core/WildheartCrystal.lua').read_bytes()).hexdigest(),
    'sources':{v:hashlib.sha256((ROOT/'Assets'/v).read_bytes()).hexdigest() for v in paths.values()}}
(OUT/'demo-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(output)
