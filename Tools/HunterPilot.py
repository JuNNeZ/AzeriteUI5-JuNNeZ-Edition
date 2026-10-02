"""Four-piece template pilot. No per-piece stretching or runtime layout fitting."""
from pathlib import Path
import hashlib
import importlib.util
import json
import subprocess
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

NAMES = ('hp_cap_case', 'actionbutton-border', 'orb_case_hi', 'cast_back')

def build_pilot(root, halo):
    src = root/'Docs/Research_Assets/Hunter/Production'
    review = src.parent/'Pilot'
    out = root/'Assets/HunterPilot'
    out.mkdir(exist_ok=True)
    spec = json.loads((root/'Docs/Theme Asset Geometry.json').read_text())
    module = importlib.util.spec_from_file_location('themecheck', root/'Tools/Check-ThemeAssetStyle.py')
    checker = importlib.util.module_from_spec(module); module.loader.exec_module(checker)
    manifest = {}
    for name in NAMES:
        source = src/(name+'.png')
        im = Image.open(source).convert('RGBA')
        w,h = spec[name]['canvas']
        # Normalize the generator's whole-canvas resolution uniformly. The
        # 4:1 health template is returned on a 3:1 canvas: discard margins only.
        scale = w/im.width
        im = im.resize((w,round(im.height*scale)),Image.Resampling.LANCZOS)
        top = (im.height-h)//2
        im = im.crop((0,top,w,top+h))
        found = checker.hole(im)
        offset = (0,0)
        if 'opening' in spec[name] and found:
            target = spec[name]['opening']
            offset = (round((target[0]+target[2]-found[0]-found[2])/2), round((target[1]+target[3]-found[1]-found[3])/2))
            translated = Image.new('RGBA',(w,h)); translated.alpha_composite(im,offset); im=translated
        elif 'meter' in spec[name]:
            # Painted recesses have no transparent opening to register. Align
            # their painted footprint center by translation, retaining size.
            painted=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
            target=spec[name]['painted']
            offset=(round((target[0]+target[2]-painted[0]-painted[2])/2),round((target[1]+target[3]-painted[1]-painted[3])/2))
            translated=Image.new('RGBA',(w,h));translated.alpha_composite(im,offset);im=translated
        # Derive diagnostic halo BEFORE grounding shadow. Shared game glows
        # remain the functional layers in this pilot (style rule 7).
        halo(im).save(review/(name+'-pre-shadow-halo.png'))
        alpha = im.getchannel('A')
        silhouette = alpha.point(lambda a:255 if a>64 else 0)
        ImageDraw.floodfill(silhouette,(0,0),128)
        silhouette = silhouette.point(lambda a:0 if a==128 else 255)
        shadow = silhouette.filter(ImageFilter.GaussianBlur(8)).point(lambda a:round(a*.45))
        shadow = ImageChops.subtract(shadow,silhouette)
        layer = Image.new('RGBA',im.size,(0,0,0,0)); layer.putalpha(shadow); layer.alpha_composite(im)
        path = out/(name+'.tga'); layer.save(path)
        failures, notes = checker.check(path)
        manifest[name] = {'source':str(source.relative_to(root)), 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'canvas_normalization':scale, 'translation':offset, 'size':[w,h], 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'geometry_failures':failures, 'look_notes':notes}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    result = subprocess.run(['python',str(root/'Tools/Check-ThemeAssetStyle.py'),'HunterPilot'],capture_output=True,text=True,check=True)
    (review/'checker-after.txt').write_text(result.stdout,encoding='utf-8'); print(result.stdout)
    if any(x['geometry_failures'] for x in manifest.values()):
        raise RuntimeError('Regenerate failed pilot pieces; never stretch them to pass')
    render(root)

def render(root):
    review=root/'Docs/Research_Assets/Hunter/Pilot'
    data=json.loads((review/'layouts.json').read_text())['original']
    (review/'original-layouts.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    sheet=Image.new('RGBA',(2880,1600),'#202629')
    draw=ImageDraw.Draw(sheet)
    def label(text,x,y,size=20):draw.text((x,y),text,font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size),fill='#e4e4d8')
    label('HUNTER — FOUR-PIECE DROP-IN PILOT',24,18,32)
    label('All three assembled columns use ORIGINAL layout dimensions and shared original fills. Concept crops are visual references.',24,64,20)
    for i,t in enumerate(('ORIGINAL','CURRENT HUNTER / original layout','NEW HUNTER PILOT / original layout','APPROVED CONCEPT CROP')):label(t,i*720+24,110,22)
    concept=Image.open(root/'Docs/Research_Assets/Hunter/Production/v1/approved-concept.png').convert('RGBA')
    crops={'hp_cap_case':(145,181,515,282),'actionbutton-border':(189,781,272,865),'orb_case_hi':(548,375,676,503),'cast_back':(995,169,1516,295)}
    def read(name,variant):
        folder=root/'Assets' if variant==0 else review/'current' if variant==1 else root/'Assets/HunterPilot'
        return Image.open(folder/(name+'.tga')).convert('RGBA')
    def put(scene,im,rect):
        x,y,w,h=rect;scene.alpha_composite(im.resize((round(w),round(h)),Image.Resampling.LANCZOS),(round(x),round(y)))
    def tinted(name,color):
        im=Image.open(root/'Assets'/(name+'.tga')).convert('RGBA');a=im.getchannel('A')
        im=ImageChops.multiply(im,Image.new('RGBA',im.size,color));im.putalpha(a);return im
    for row,name in enumerate(NAMES):
        y=160+row*350;label(name,24,y,23)
        for variant in range(3):
            scene=Image.new('RGBA',(720,300));art=read(name,variant)
            if name=='hp_cap_case':
                d=data['PlayerFrame']['Seasoned']; bw,bh=d['HealthBackdropSize'];hw,hh=d['HealthBarSize']
                # The original layout's BOTTOMLEFT anchor relationship.
                dx=d['HealthBarPosition'][1]-d['HealthBackdropPosition'][1]
                dy=bh-hh-(d['HealthBarPosition'][2]-d['HealthBackdropPosition'][2])
                for yy,f in ((10,1),(125,.4)):
                    put(scene,art,(0,yy,bw,bh))
                    fill=tinted('hp_cap_bar',(70,180,55,255)).resize((hw,hh),Image.Resampling.LANCZOS)
                    scene.alpha_composite(fill.crop((0,0,round(hw*f),hh)),(round(dx),round(yy+dy)))
            elif name=='actionbutton-border':
                d=data['ActionButton'];w,h=d['ButtonBorderSize'];iw,ih=d['ButtonIconSize']
                icon=tinted('grouprole-icons-heal',(255,255,255,255))
                put(scene,icon,(90+(w-iw)/2,20+(h-ih)/2,iw,ih));put(scene,art,(90,20,w,h))
                put(scene,art,(340,5,w*2,h*2))
            elif name=='orb_case_hi':
                d=data['PlayerFrame']['Seasoned'];w,h=d['ManaOrbForegroundSize'];fw,fh=d['ManaOrbSize']
                for x,f in ((95,1),(390,.4)):
                    fill=tinted('orb2',(255,170,35,255)).resize((fw,fh),Image.Resampling.LANCZOS)
                    cut=round(fh*(1-f));scene.alpha_composite(fill.crop((0,cut,fw,fh)),(round(x+(w-fw)/2),round(30+(h-fh)/2)+cut))
                    put(scene,art,(x,30,w,h))
            else:
                d=data['PlayerCastBar'];bw,bh=d['CastBarBackgroundSize'];fw,fh=d['CastBarSize'];_,dx,dy=d['CastBarBackgroundPosition']
                for x,yy,m in ((50,20,1),(290,65,2)):
                    put(scene,art,(x,yy,bw*m,bh*m))
                    fill=tinted('cast_bar',(255,177,35,255)).resize((round(fw*m),round(fh*m)),Image.Resampling.LANCZOS)
                    scene.alpha_composite(fill.crop((0,0,round(fw*m*.65),round(fh*m))),(round(x+(bw-fw)*m/2-dx*m),round(yy+(bh-fh)*m/2+dy*m)))
            sheet.alpha_composite(scene,(variant*720,y+30))
        crop=concept.crop(crops[name]);crop.thumbnail((650,250),Image.Resampling.LANCZOS)
        sheet.alpha_composite(crop,(2160+(720-crop.width)//2,y+60))
        if name in ('actionbutton-border','cast_back'):label('Native size + 2x inspection view (same multiplier in all columns)',24,y+310,17)
    label('Pilot stops here. Other textures and layout overrides await approval. Offline assembly; live WoW rendering and theme-switch checks remain owed.',24,1555,19)
    sheet.save(review/'Hunter-Four-Piece-Pilot.png')
    print(review/'Hunter-Four-Piece-Pilot.png')
