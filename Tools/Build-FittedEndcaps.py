"""Pack image_gen socket paintings and retained motifs into removable end boots.

No procedural painting: source art is retained intact, uniformly registered and
composited. Capped casing variants only remove the old termination under the
new boot. Bare casing, fills, glass, layout geometry and existing art stay intact.
Run from the addon root: python Tools/Build-FittedEndcaps.py
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/EndcapFit-2026-10-17'
S = Image.Resampling.LANCZOS
HEALTH = ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')
MOTIFS = {
    'Hunter': ('endcap-thasdorah','endcap-talonclaw','endcap-titanstrike','endcap-thoridal','endcap-raeshalare'),
    'Mage': ('ornament-aluneth','ornament-felomelorn','ornament-ebonchill','ornament-atiesh','ornament-dragonwrath'),
    'Druid': ('ornament-antler',),
}
CAST = {'Hunter':'eagle','Mage':'cast-head-atiesh','Druid':'cast-head-moon'}


def read(path):
    return Image.open(path).convert('RGBA')


def bounds(image):
    return image.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()


def fit(image, height):
    art = image.crop(bounds(image))
    return art.resize((round(art.width*height/art.height),height),S)


def halo(image):
    alpha = image.getchannel('A').point(lambda a:255 if a>128 else 0)
    exterior = alpha.copy()
    ImageDraw.floodfill(exterior,(0,0),128)
    solid = exterior.point(lambda a:0 if a==128 else 255)
    edge = ImageChops.subtract(solid.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(3)),solid)
    result = Image.new('RGBA',image.size,'white')
    result.putalpha(edge)
    return result


def build():
    inventory = {'policy':'literal generated sockets + existing intact motifs; capped terminals retain original canvas',
                 'healthSlot':{'size':88,'x':14,'y':0,'reference':40,'defaultScale':1.3},
                 'castSlot':{'size':48,'x':-8,'y':0},'files':{}}
    for theme, names in MOTIFS.items():
        assets = ROOT/'Assets'/theme
        sources = WORK/'Inputs'/theme
        socket = fit(read(WORK/(theme+'-socket-source.png')),168)
        # Solid centre starts just inside the bar end at slot-canvas x~87.
        socket_layer = Image.new('RGBA',(256,256))
        socket_layer.alpha_composite(socket,(48,(256-socket.height)//2))

        def save(name,image):
            file = assets/(name+'.tga')
            image.save(file)
            preview = WORK/'Export'/theme/(name+'.png')
            preview.parent.mkdir(parents=True,exist_ok=True)
            image.save(preview)
            inventory['files'][str(file.relative_to(ROOT)).replace('\\','/')] = {
                'size':list(image.size),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}

        for name in names:
            motif = fit(read(sources/(name+'.png')),216)
            if motif.width>184:
                motif.thumbnail((184,216),S)
            # Socket grips the rails; the existing relic replaces its outer end.
            image = socket_layer.copy()
            image.alpha_composite(motif,(min(240-motif.width,76),(256-motif.height)//2))
            save(name+'-fitted',image)
            save(name+'-fitted-glow',halo(image))

        # Cast heads face LEFT and grip the left termination. Do not inherit
        # the health-weapon choice or add a second weapon at the cast tail.
        head = fit(read(sources/(CAST[theme]+'.png')),190)
        head.thumbnail((200,216),S)
        image = socket_layer.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        image.alpha_composite(head,(16,(256-head.height)//2))
        save('cast-head-fitted',image)
        if theme=='Druid':
            original = read(sources/(CAST[theme]+'.png'))
            light = read(assets/'cast-head-moonlight.tga').crop(bounds(original)).resize(head.size,S)
            overlay = Image.new('RGBA',(256,256))
            overlay.alpha_composite(light,(16,(256-head.height)//2))
            save('cast-head-fitted-light',overlay)

        for name in ('cast_back','cast_back_spiked'):
            for suffix in ('','-over'):
                source = assets/(name+suffix+'.tga')
                if not source.exists():
                    continue
                frozen = sources/(name+suffix+'.png')
                if not frozen.exists():
                    read(source).save(frozen)
                image = read(frozen)
                # The left boot replaces the casing's old closed left tip.
                # The meter itself is not cropped, recoloured or resized.
                alpha = image.getchannel('A')
                ImageDraw.Draw(alpha).rectangle((0,0,53,image.height),fill=0)
                image.putalpha(alpha)
                save(name+'-capped'+suffix,image)

        for native_name in HEALTH:
            name = native_name
            if theme=='Hunter':
                # Reuse the authored Hunter timber/steel painting, registered
                # to the native dipped contour instead of the old wide frame.
                original = read(ROOT/'Assets'/(native_name+'.tga'))
                geometry = json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())[native_name]
                source_path = sources/(native_name+'.png')
                if not source_path.exists():read(assets/(native_name+'.tga')).save(source_path)
                source = read(WORK/'Hunter-health-source.png')
                sb = bounds(source); tb = geometry['painted']; meter = geometry['meter']
                # Filled RGB padding is copied from nearest authored pixels,
                # not painted procedurally or recoloured from native metal.
                a = np.array(source); good_rows = np.flatnonzero((a[:,:,3]>128).any(1))
                for y in range(source.height):
                    row = y if (a[y,:,3]>128).any() else good_rows[np.abs(good_rows-y).argmin()]
                    good = np.flatnonzero(a[row,:,3]>128)
                    nearest = np.abs(np.arange(source.width)[:,None]-good).argmin(1)
                    a[y,:,:3] = a[row,good[nearest],:3]
                # Native alpha contains the actual dipped ending on both sides.
                sample = Image.fromarray(a).crop(sb).resize((tb[2]-tb[0],tb[3]-tb[1]),S)
                material = Image.new('RGBA',original.size)
                material.paste(sample,tb[:2]); material.putalpha(original.getchannel('A'))
                mask = Image.open(ROOT/'Docs/Research_Assets/Templates'/(native_name+'-fill.png')).convert('L')
                inside = np.asarray(mask)>0
                front = np.array(material); front[inside,3]=0
                native_pixels = np.asarray(original)
                glass = inside & (native_pixels[:,:,3]>0) & (native_pixels[:,:,3]<=200)
                front[glass] = native_pixels[glass]
                backing = np.array(material);backing[inside]=native_pixels[inside]
                name = native_name+'-fitted'
                save(name,Image.fromarray(backing));save(name+'-over',Image.fromarray(front))
                save(name+'-glow',halo(Image.fromarray(front)))
                for suffix,image in (('',Image.fromarray(backing)),('-over',Image.fromarray(front))):
                    image.save(sources/(name+suffix+'.png'))
            # Freeze all original inputs before any derivative export. A build
            # never uses its own previous capped output as a source.
            for suffix in ('','-over'):
                source = assets/(name+suffix+'.tga')
                if not source.exists():
                    continue
                frozen = sources/(name+suffix+'.png')
                if not frozen.exists():
                    read(source).save(frozen)
                image = read(frozen)
                if suffix=='' and theme=='Mage':
                    save(name+'-fitted-glow',halo(image))
                geometry = json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())[native_name]
                end = geometry['meter'][2]
                # Remove only the terminal being replaced, not the long rails
                # or any functional fill texture. The new sleeve overlaps it.
                alpha = image.getchannel('A')
                ImageDraw.Draw(alpha).rectangle((end-12,0,image.width,image.height),fill=0)
                # Remove the dipped lower spur under the sleeve, as Paladin's
                # shoulder variant does. None always selects the intact dip.
                rows = np.asarray(image.getchannel('A'))>128
                bottoms = image.height-1-rows[::-1].argmax(0)
                x0,y0,x1,y1 = geometry['meter']
                rail_bottom = int(np.median(bottoms[x0+60:x1-100]))
                ImageDraw.Draw(alpha).rectangle((end-90,rail_bottom+1,image.width,image.height),fill=0)
                image.putalpha(alpha)
                save(name+'-capped'+suffix,image)
            front = WORK/'Export'/theme/(name+'-capped-over.png')
            silhouette = read(front) if front.exists() else read(WORK/'Export'/theme/(name+'-capped.png'))
            save(name+'-capped-glow',halo(silhouette))
    (WORK/'manifest.json').write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8')
    print('Packed',len(inventory['files']),'fitted cap/terminal textures; original art unchanged.')


if __name__=='__main__':
    # The reviewed whole-art rebuild supersedes the socket/motif prototype.
    rebuilt=ROOT/'Docs/Research_Assets/EndcapRebuild-2026-10-17/manifest.json'
    if rebuilt.exists():
        import importlib.util
        spec=importlib.util.spec_from_file_location('rebuilt_health',ROOT/'Tools/Build-RebuiltHealthArt.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        module.build(install=True)
    else:build()
