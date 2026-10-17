"""Check rebuilt textures and actual native-layout joints; no live-client claim."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/EndcapRebuild-2026-10-17'
manifest=json.loads((WORK/'manifest.json').read_text())
spec=importlib.util.spec_from_file_location('builder',ROOT/'Tools/Build-RebuiltHealthArt.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
spec=importlib.util.spec_from_file_location('native',ROOT/'Tools/Build-ThemeConceptBase.py')
B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)
DATA=json.loads((ROOT/'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json').read_text())
INSTALLED='--installed' in sys.argv
checks=0
measurements=[]


def check(value,label):
    global checks
    checks+=1
    assert value,label


def art(theme,name):
    return M.read((ROOT/'Assets' if INSTALLED else WORK/'Export')/theme/(name+'.tga'))


for relative,item in manifest['files'].items():
    p=ROOT/relative if INSTALLED else WORK/'Export'/Path(relative).relative_to('Assets')
    im=M.read(p);pixels=np.asarray(im)
    check(hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],'export hash '+relative)
    check(list(im.size)==item['size'],'canvas '+relative)
    if relative.endswith('-glow.tga'):
        check(np.array_equal(pixels[:,:,0],pixels[:,:,1]) and np.array_equal(pixels[:,:,1],pixels[:,:,2]),'neutral threat '+relative)
for relative,digest in manifest['sources'].items():
    check(hashlib.sha256((WORK/'Sources'/relative).read_bytes()).hexdigest()==digest,'source lock '+relative)
for relative,digest in manifest.get('protected',{}).items():
    check(hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()==digest,'native/Paladin/layout lock '+relative)
for theme,names in M.MOTIFS.items():
    for name in M.HEALTH:
        key=name+('-fitted' if theme=='Hunter' else '')
        bare=art(theme,key);front=art(theme,key+'-over');mounted=art(theme,key+'-capped-over')
        native=M.read(ROOT/'Assets'/(name+'.tga'))
        fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L'))>0
        check(bare.size==native.size,'native canvas '+theme+'/'+name)
        box=M.bounds(bare);expected=M.SPEC[name]['painted']
        check(all(abs(box[i]-expected[i])<=4 for i in range(4)),'native envelope '+theme+'/'+name)
        check(not np.any(np.asarray(front)[:,:,3][fill]>200),'clear native fill '+theme+'/'+name)
        y0,x0=np.where(np.asarray(front)[:,:,3]>128)
        check(len(y0)>100,'complete bare rails '+theme+'/'+name)
        check(np.any(np.asarray(front)[:,:,3]!=np.asarray(mounted)[:,:,3]),'separate bare dip '+theme+'/'+name)
        top=M.SPEC[name]['painted']
        row=np.asarray(front)[:,:,3][top[1]+6,top[0]+40:top[2]-40]>128
        transitions=np.diff(np.r_[False,row,False].astype(int))
        starts=np.flatnonzero(transitions==1);ends=np.flatnonzero(transitions==-1)
        studs=sum(end-start>=3 for start,end in zip(starts,ends))
        check(studs==(5 if name=='hp_boss_case' else 3),'native stud count '+theme+'/'+name)
    for name in names:
        sprite=art(theme,name+'-fitted')
        # The output must be exactly the newly authored whole object, uniformly
        # fitted once; this rejects a hidden extra socket/old-motif composite.
        check(sprite.tobytes()==M.sprite(WORK/'Sources'/(name+'.png')).tobytes(),'whole intact painting '+theme+'/'+name)
        p=np.asarray(sprite);box=M.bounds(sprite)
        check(box[0]>0 and box[1]>0 and box[2]<256 and box[3]<256,'padded complete relic '+name)
        check(p[128,97,3]>=240,'opaque health seam '+name)
        for kind in ('PlayerFrame','TargetFrame'):
            for tier in ('Novice','Seasoned','Boss'):
                base=DATA['hunter' if theme=='Hunter' else 'original'][kind]
                if tier not in base:
                    continue
                db=dict(base);db.update(base[tier])
                owner=(150,60,*base['Size'])
                hp=B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
                casing=B.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
                flip=kind=='TargetFrame'
                native_name='hp_boss_case' if tier=='Boss' else 'hp_cap_case' if tier=='Seasoned' else 'hp_low_case'
                key=native_name+('-fitted' if theme=='Hunter' else '')
                rail=art(theme,key+'-capped-over')
                if flip:rail=rail.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                x,y,w,h=hp;cx,cy,cw,ch=casing;size=88*h/40*1.3
                left=(x-14*h/40 if flip else x+w+14*h/40)-size/2;top=y+(h-size)/2
                cap=Image.new('RGBA',rail.size)
                rect=((left-cx)*rail.width/cw,(top-cy)*rail.height/ch,size*rail.width/cw,size*rail.height/ch)
                B.put(cap,sprite,rect,flip)
                mask=Image.open(ROOT/'Docs/Research_Assets/Templates'/(native_name+'-fill.png')).convert('L')
                if flip:mask=mask.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                inside=np.asarray(mask)>128
                covered=np.count_nonzero((np.asarray(cap)[:,:,3]>200)&inside)/np.count_nonzero(inside)
                check(covered<=.20,'cap covers at most 20 percent of native fill '+name+'/'+tier)
                combined=Image.fromarray(np.maximum(np.asarray(rail)[:,:,3],np.asarray(cap)[:,:,3])).point(lambda a:255 if a>128 else 0)
                # Flood-fill from the long upper rail. Cap centre must belong
                # to that same physical silhouette, not float beside it.
                a=np.asarray(combined);ys=np.flatnonzero(a[:,rail.width//2])
                seed=(rail.width//2,int(ys[0]))
                ImageDraw.floodfill(combined,seed,64)
                capbox=cap.getbbox()
                point=(round((left+size*(.4 if flip else .6)-cx)*rail.width/cw),round((y+h/2-cy)*rail.height/ch))
                connected=combined.getpixel(point)==64
                check(connected,'joined foreground silhouette '+name+'/'+tier)
                measurements.append({'theme':theme,'motif':name,'kind':kind,'tier':tier,
                                     'fillCovered':round(covered,5),'connected':connected})
    cast=art(theme,'cast-head-fitted')
    for name in ('cast_back','cast_back_spiked'):
        db=DATA['hunter' if theme=='Hunter' else 'original']['PlayerCastBar']
        hp=(160,100,*db['CastBarSize'])
        case=B.anchor(hp,db['CastBarBackgroundSize'],db['CastBarBackgroundPosition'])
        scene=Image.new('RGBA',(500,240))
        B.put(scene,M.read(ROOT/'Assets'/theme/(name+'-capped.tga')),case)
        cap=Image.new('RGBA',scene.size)
        B.put(cap,cast,(hp[0]-8-24,hp[1]+hp[3]/2-24,48,48))
        a=np.maximum(np.asarray(scene)[:,:,3],np.asarray(cap)[:,:,3])
        connected=Image.fromarray(a).point(lambda a:255 if a>128 else 0)
        ImageDraw.floodfill(connected,(round(hp[0]+hp[2]/2),round(hp[1]+hp[3]/2)),64)
        ys,xs=np.where(np.asarray(cap)[:,:,3]>200)
        index=np.argmin((xs-(hp[0]-8))**2+(ys-(hp[1]+hp[3]/2))**2)
        check(connected.getpixel((int(xs[index]),int(ys[index])))==64,'joined cast endplate '+theme+'/'+name)
    if theme=='Druid':
        light=np.asarray(art(theme,'cast-head-fitted-light'))
        check(np.all(light[:,:,3]<=np.asarray(cast)[:,:,3]),'new moonlight stays on new cast painting')
        check(np.array_equal(light[:,:,0],light[:,:,1]) and np.array_equal(light[:,:,1],light[:,:,2]),'new moonlight remains neutral for runtime colour')
(WORK/'checks.json').write_text(json.dumps({'checks':checks,'installed':INSTALLED,'joints':measurements,
    'liveValidated':False},indent=2),encoding='utf-8')
print('Rebuilt health art:',checks,'checks passed;',len(measurements),'joint measurements; live testing still owed.')
