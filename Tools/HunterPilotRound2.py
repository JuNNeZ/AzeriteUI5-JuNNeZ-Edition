"""Round-two pilot: explicit back/fill/over compositing, never reshape a widget."""
from pathlib import Path
import json, subprocess, hashlib, re
import numpy as np
from PIL import Image, ImageOps, ImageChops, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parent.parent
A=ROOT/'Assets'; O=A/'HunterPilot'
R=ROOT/'Docs/Research_Assets/Hunter/Pilot/Round2'
T=ROOT/'Docs/Research_Assets/Templates'
S=Image.Resampling.LANCZOS
def read(p): return Image.open(p).convert('RGBA')
def save(im,n): im.save(O/(n+'.tga'))
def mask(n): return np.asarray(Image.open(T/(n+'-fill.png'))) > 0
def build():
    for n in ('hp_cap_case','cast_back'):
        old=read(R/(n+'-round1.png')); a=np.array(old)
        m=mask(n); rgb=a[:,:,:3].astype(float)
        sat=(rgb.max(2)-rgb.min(2))/np.maximum(rgb.max(2),1)
        green=(rgb[:,:,1]>rgb[:,:,0]*1.05)&(rgb[:,:,1]>rgb[:,:,2]*1.15)&(sat>.25)
        # Split existing authored lip/wrap into its correct layer. Only the
        # binding crosses the meter; timber inside the fill contour is removed.
        over=a.copy(); over[:,:,3]=np.where((sat>.25)&((~m)|green),a[:,:,3],0)
        save(Image.fromarray(over),n+'-over')
        # Newly painted slate is used as the empty surface, clipped to the
        # exact supplied mask. Outside it, round-one silhouette is unchanged.
        source=read(R/(n+'-back-source.png'))
        k=old.width/source.width
        source=source.resize((old.width,round(source.height*k)),S)
        top=(source.height-old.height)//2
        source=source.crop((0,top,old.width,top+old.height))
        gray=np.asarray(ImageOps.grayscale(source))
        for c in range(3): a[:,:,c][m]=gray[m]
        a[:,:,3][m]=255
        # Remove overlay-only colour from the backing outside the meter too.
        detail=(over[:,:,3]>0)&~m
        for c in range(3): a[:,:,c][detail]=np.maximum(20,gray[detail])
        save(Image.fromarray(a),n)
    for n in ('orb_case_hi','actionbutton-border'):
        a=np.array(read(R/(n+'-round1.png')))
        original=np.array(read(A/(n+'.tga')))
        m=mask(n)
        # Exact original glass, specular point, and inner shading. Preserve
        # opaque original edge pixels too: they are the mask's native lip.
        a[m]=original[m]
        save(Image.fromarray(a),n)
    for n,original in (('hp_cap_bar','hp_cap_bar'),('cast_bar','cast_bar'),('orb-focus','orb2')):
        base=read(A/(original+'.tga'))
        material=read(A/'Hunter'/(n+'.tga')).resize(base.size,S)
        material=ImageOps.grayscale(material).convert('RGBA')
        material.putalpha(base.getchannel('A')); save(material,n)
    for n in ('eagle','endcap-thasdorah'):
        save(read(A/'Hunter'/(n+'.tga')),n)
    # Backdrops remain shared originals, not duplicate theme replacements.
    report=subprocess.check_output(['python',str(ROOT/'Tools/Check-ThemeAssetStyle.py'),'HunterPilot'],text=True)
    (R/'checker-after.txt').write_text(report);print(report)
    manifest={p.stem:{'size':read(p).size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in O.glob('*.tga')}
    (O/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    if 'GEOMETRY' in report: raise RuntimeError('Pilot contour/layer check failed')
    render(report)

def render(report):
    data=json.loads((R.parent/'original-layouts.json').read_text())
    spec=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
    slots={}
    for name,size,x,y in re.findall(r'(\w+) = \{ size = (\d+), x = (-?\d+), y = (-?\d+) \}',(ROOT/'Core/ThemeOrnamentSlots.lua').read_text()):
        slots[name]=(int(size),int(x),int(y))
    (R/'ornament-slots.json').write_text(json.dumps(slots,indent=2))
    sheet=Image.new('RGBA',(2880,2200),'#242b2e');d=ImageDraw.Draw(sheet)
    def label(s,x,y,z=20): d.text((x,y),s,font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',z),fill='#e4e3d6')
    def put(scene,im,x,y,w,h):scene.alpha_composite(im.resize((round(w),round(h)),S),(round(x),round(y)))
    def tint(im,color):return ImageChops.multiply(im,Image.new('RGBA',im.size,(*color,255)))
    def art(n,v):
        if v==0:return read(A/(n+'.tga'))
        if v==1:return read(A/'Hunter'/(n+'.tga')) if (A/'Hunter'/(n+'.tga')).exists() else read(A/(n+'.tga'))
        return read(O/(n+'.tga'))
    def meter(im,frac,vertical=False):
        out=Image.new('RGBA',im.size)
        if frac:
            if vertical:
                y=round(im.height*(1-frac));out.alpha_composite(im.crop((0,y,im.width,im.height)),(0,y))
            else:out.alpha_composite(im.crop((0,0,round(im.width*frac),im.height)))
        return out
    label('HUNTER — PILOT ROUND TWO',24,18,34)
    label('Original layout sizes • back / fill / over / text • empty, 40%, full • staged review, not live-client validation',24,67)
    for i,t in enumerate(('ORIGINAL','CURRENT HUNTER / original layout','ROUND TWO / original layout','APPROVED CONCEPT')):
        label(t,i*720+20,110,22)
    concept=read(ROOT/'Docs/Research_Assets/Hunter/Production/v1/approved-concept.png')
    crops={'hp_cap_case':(145,181,515,282),'actionbutton-border':(189,781,272,865),'orb_case_hi':(548,375,676,503),'cast_back':(995,169,1516,295)}
    ys={'hp_cap_case':160,'orb_case_hi':680,'actionbutton-border':1080,'cast_back':1420}
    for n,y0 in ys.items():
        label(n,24,y0,23)
        for v in range(3):
            scene=Image.new('RGBA',(720,480 if n=='hp_cap_case' else 360))
            casing=art(n,v)
            if n in ('hp_cap_case','cast_back'):
                health=n=='hp_cap_case';db=data['PlayerFrame']['Seasoned'] if health else data['PlayerCastBar']
                bw,bh=db['HealthBackdropSize' if health else 'CastBarBackgroundSize']
                fw,fh=db['HealthBarSize' if health else 'CastBarSize']
                if health:
                    fx=db['HealthBarPosition'][1]-db['HealthBackdropPosition'][1]
                    fy=bh-fh-(db['HealthBarPosition'][2]-db['HealthBackdropPosition'][2])
                else:
                    fx=(bw-fw)/2-db['CastBarBackgroundPosition'][1];fy=(bh-fh)/2+db['CastBarBackgroundPosition'][2]
                for j,f in enumerate((0,.4,1)):
                    xx=0 if health else 210; yy=j*(125 if health else 95)
                    put(scene,casing,xx,yy,bw,bh)
                    fill=art('hp_cap_bar' if health else 'cast_bar',v)
                    put(scene,meter(tint(fill,(80,185,55) if health else (255,180,40)),f),xx+fx,yy+fy,fw,fh)
                    if v==2:put(scene,art(n+'-over',v),xx,yy,bw,bh)
                    if v:
                        size,ox,oy=slots['HealthEndcap' if health else 'CastHead']
                        put(scene,art('endcap-thasdorah' if health else 'eagle',v),xx+fx+(fw if health else 0)+ox-size/2,yy+fy+fh/2-oy-size/2,size,size)
                    sd=ImageDraw.Draw(scene); font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',14 if health else 11)
                    sd.text((xx+fx+fw/2,yy+fy+fh/2),str(round(f*100))+'%',font=font,fill='white',anchor='mm',stroke_width=1,stroke_fill='black')
                if health and v==2:
                    # A mirrored target sample proves the ornament faces away
                    # from the right-side portrait. Same canvas and sizes.
                    mirror=Image.new('RGBA',(720,188))
                    put(mirror,casing,0,0,bw,bh)
                    put(mirror,meter(tint(art('hp_cap_bar',v),(80,185,55)),.4),fx,fy,fw,fh)
                    put(mirror,art(n+'-over',v),0,0,bw,bh)
                    sz,ox,oy=slots['HealthEndcap']
                    put(mirror,art('endcap-thasdorah',v),fx+fw+ox-sz/2,fy+fh/2-sz/2,sz,sz)
                    scene.alpha_composite(ImageOps.mirror(mirror),(0,360))
            elif n=='orb_case_hi':
                db=data['PlayerFrame']['Seasoned'];bw,bh=db['ManaOrbForegroundSize'];fw,fh=db['ManaOrbSize']
                for j,f in enumerate((0,.4,1)):
                    xx=15+j*230; yy=35
                    put(scene,read(A/'orb-backdrop2.tga'),xx+(bw-fw)/2,yy+(bh-fh)/2,fw,fh)
                    fill=art('orb-focus',v) if v else read(A/'orb2.tga')
                    put(scene,meter(tint(fill,(255,180,40)),f,True),xx+(bw-fw)/2,yy+(bh-fh)/2,fw,fh)
                    put(scene,casing,xx,yy,bw,bh)
            else:
                db=data['ActionButton'];bw,bh=db['ButtonBorderSize'];fw,fh=db['ButtonIconSize']
                icon=read(R/'ability_hunter_aimedshot.jpg').resize((round(fw),round(fh)),S)
                icon.putalpha(read(A/'actionbutton-mask-circular.tga').getchannel('A').resize(icon.size,S))
                for xx,yy,k in ((90,35,1),(350,10,2)):
                    put(scene,read(A/'actionbutton-backdrop.tga'),xx,yy,bw*k,bh*k)
                    put(scene,icon,xx+(bw-fw)*k/2,yy+(bh-fh)*k/2,fw*k,fh*k)
                    put(scene,casing,xx,yy,bw*k,bh*k)
            sheet.alpha_composite(scene,(v*720,y0+35))
        crop=concept.crop(crops[n]);crop.thumbnail((670,290),S)
        sheet.alpha_composite(crop,(2160+(720-crop.width)//2,y0+65))
    label('Health: empty / 40% / full; extra mirrored target below the round-two player samples.',24,650,17)
    label('Orb: empty / 40% / full. Original glass + specular + inner shading restored above the faceted fill.',24,1035,18)
    label('Action button: Aimed Shot, native size and 2x inspection (same multiplier in each column).',24,1370,18)
    label('Cast: empty / 40% / full at native size. Eagle only at the left; no second health endcap.',24,1790,18)
    label('CHECKER — staged HunterPilot',24,1850,25)
    for j,line in enumerate(report.strip().splitlines()):label(line,24,1890+j*25,18)
    label('Baseline: four casings failed fill occlusion / hidden decoration / missing glass. Wider Hunter rework remains paused.',24,2090,19)
    label('No release or live activation. Review this sheet before proceeding. Source, layer masks, slot table and reports are saved beside it.',24,2130,19)
    sheet.save(R/'Hunter-Pilot-Round2.png')
if __name__=='__main__':build()
