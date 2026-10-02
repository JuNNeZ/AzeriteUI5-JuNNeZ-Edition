"""Pack authored art, opening-derived masks and assembled neutral threat layers.

No painted artwork is synthesized here. Source alpha defines every fill contour;
original neutral faceting supplies the fill material and native stripe atlases
supply prediction patterns. Runtime geometry is exported alongside the images.
"""
import json
import hashlib
from PIL import Image, ImageDraw, ImageChops


def extend_assets(root, manifest, mapping, read, halo, opening, sampling, nine_slice):
    out = root / 'Assets/Hunter'
    src = root / 'Docs/Research_Assets/Hunter/Production/v1'
    neutral = []
    geometry = {}

    def save(name, im, source, tintable=False):
        file = out / (name + '.tga')
        im.save(file)
        item = dict(size=list(im.size), source=source, path='Assets/Hunter/'+file.name,
                    sha256=hashlib.sha256(file.read_bytes()).hexdigest())
        if (root/'Assets'/file.name).exists():
            item['disposition'] = 'hunter material'
            manifest['originals'][name] = item
            mapping[name] = source
        else:
            manifest['additional'][name] = item
            mapping[name] = source
        if tintable: neutral.append(name)

    def hole_mask(im, seed=None):
        mask = im.getchannel('A').point(lambda a: 255 if a > 64 else 0)
        ImageDraw.floodfill(mask, seed or (im.width//2, im.height//2), 128)
        return mask.point(lambda a: 255 if a == 128 else 0)

    def shape_fill(name, mask, box):
        original = read(root/'Assets'/(name+'.tga'))
        w,h=original.size
        l,t,r,b=box
        target=(round(l*w),round(t*h),round(r*w),round(b*h))
        alpha=Image.new('L',original.size)
        alpha.paste(mask.resize((target[2]-target[0],target[3]-target[1]),sampling),target[:2])
        # Use the opaque middle of original faceting, avoiding old angled alpha.
        material=original.crop((round(w*.12),round(h*.1),round(w*.88),round(h*.72)))
        material=material.resize(original.size,sampling)
        material.putalpha(alpha)
        save(name,material,'new casing opening + original neutral faceting',True)
        for suffix in ('-absorb','-healabsorb'):
            pattern=read(root/'Assets'/(name+suffix+'.tga'))
            # Retain the native stripes but extend their material over the new
            # contour; their old silhouette must not cut off the new tips.
            tile=pattern.crop((w//3,0,w//3+max(8,w//8),h))
            tiled=Image.new('RGBA',(w,h))
            for x in range(0,w,tile.width): tiled.paste(tile,(x,0))
            tiled.putalpha(ImageChops.multiply(tiled.getchannel('A'),alpha))
            save(name+suffix,tiled,'new casing opening + native prediction pattern',True)
        return material

    frame=read(src/'frame.png'); fm=hole_mask(frame); fb=fm.getbbox()
    for name,top,bottom in [('hp_cap_bar',3/128,100/128),('hp_lowmid_bar',2/64,52/64),('hp_boss_bar',2/64,48/64)]:
        fill=shape_fill(name,fm.crop(fb),(0,top,1,bottom))
        if (root/'Assets'/(name+'_mirror.tga')).exists():
            save(name+'_mirror',fill.transpose(Image.Transpose.FLIP_LEFT_RIGHT),'mirrored Hunter fill',True)

    # Critter is a small hexagonal meter, not a portrait with a crystal inside.
    critter=nine_slice(read(src/'portrait.png'),read(root/'Assets/hp_critter_case.tga'),(39,42,88,87),(17,20,112,109))
    cm=hole_mask(critter); cb=cm.getbbox()
    for name in ('hp_critter_case','hp_critter_case_hi'): save(name,critter,'portrait hexagon without glass')
    save('hp_critter_case_glow',halo(critter),'critter casing alpha',True)
    shape_fill('hp_critter_bar',cm.crop(cb),(0,0,1,1))
    geometry['critter']=[v/128 for v in cb]

    # Both small-bar layers use the same packed opening and exact native anchor.
    compact=read(out/'cast_back.tga'); mask=hole_mask(compact); box=mask.getbbox()
    geometry['compact']=[box[0]/compact.width,box[1]/compact.height,box[2]/compact.width,box[3]/compact.height]
    shape_fill('cast_bar',mask.crop(box),(0,0,1,1))
    plate=read(out/'nameplate_backdrop.tga'); pm=hole_mask(plate)
    shape_fill('nameplate_bar',pm,(0,0,1,1))

    # Preserve native small-frame canvases and anchors. Party/raid have a
    # taller meter, so their opening needs its own packing, not a taller casing.
    compact_source=read(src/'compact-v3.png')
    for suffix,inner in [('party',(53,51,199,71)),('raid',(53,51,199,71))]:
        casing=nine_slice(compact_source,read(root/'Assets/cast_back.tga'),inner,(33,39,217,87))
        save('cast-back-'+suffix,casing,'compact art in original '+suffix+' footprint')
        save('cast-back-'+suffix+'-outline',halo(casing),'compact casing alpha',True)
    # Empty cavities carry the same dark faceted material as the health fill.
    for name in ('cast_back','cast_back_wooden','cast_back_spiked','cast-back-party','cast-back-raid'):
        casing=read(out/(name+'.tga')); mask=hole_mask(casing); box=mask.getbbox()
        material=read(root/'Assets/cast_bar.tga').crop((32,3,224,29)).resize((box[2]-box[0],box[3]-box[1]),sampling)
        material=ImageChops.multiply(material,Image.new('RGBA',material.size,(30,34,29,255)))
        layer=Image.new('RGBA',casing.size);layer.paste(material,box[:2]);layer.putalpha(mask)
        layer.alpha_composite(casing);save(name,layer,'Hunter casing with dark faceted cavity')

    # Glass is authored as a separate pane and packed below the opaque casing.
    glass=read(src/'portrait-glass-source.png')
    reference=read(src/'portrait.png'); gb=hole_mask(reference).getbbox()
    pane=glass.crop(gb)
    def add_glass(casing, seed=None, round_pane=False):
        mask=hole_mask(casing,seed); box=mask.getbbox()
        material=pane.resize((box[2]-box[0],box[3]-box[1]),sampling)
        layer=Image.new('RGBA',casing.size);layer.paste(material,box[:2])
        layer.putalpha(mask.point(lambda a: round(a*.22)))
        layer.alpha_composite(casing)
        return layer
    for name in ('portrait_frame_hi','portrait_frame_lo','party_portrait_border'):
        save(name,add_glass(read(out/(name+'.tga'))),'Hunter casing + translucent authored glass')

    # An opaque, subdued authored pane behind party/raid/arena portraits.
    original_back=read(root/'Assets/party_portrait_back.tga')
    backmask=original_back.getchannel('A'); box=backmask.getbbox()
    background=Image.new('RGBA',original_back.size)
    material=pane.resize((box[2]-box[0],box[3]-box[1]),sampling)
    material=ImageChops.multiply(material,Image.new('RGBA',material.size,(44,54,38,255)))
    background.paste(material,box[:2]);background.putalpha(backmask)
    save('party_portrait_back',background,'authored Hunter pane in original portrait background mask')

    pet=read(src/'pet-connected.png')
    petmask=hole_mask(pet); pb=petmask.getbbox()
    portrait_mask=hole_mask(pet,(round(pet.width*.86),pet.height//2)); portrait_box=portrait_mask.getbbox()
    geometry['pet']={'canvas':list(pet.size),'health':list(pb),'portrait':list(portrait_box)}
    # Keep the connected art's original aspect; a 144px meter yields a ~60px portrait.
    save('pet-case-glow',halo(pet.resize((1024,512),sampling)),'connected pet silhouette',True)
    save('pet-case',add_glass(pet,(round(pet.width*.86),pet.height//2)).resize((1024,512),sampling),'connected pet concept')
    # Pet uses cast_bar prediction semantics, but its own contour. Separate path
    # is recognized as cast_bar by the addon prediction renderer.
    petfill=read(out/'cast_bar.tga')
    petfill.putalpha(petmask.crop(pb).resize(petfill.size,sampling))
    save('pet-fill',petfill,'connected pet opening',True)
    for suffix in ('-absorb','-healabsorb'):
        pattern=read(out/('cast_bar'+suffix+'.tga'))
        pattern.putalpha(ImageChops.multiply(pattern.getchannel('A'),petfill.getchannel('A')))
        save('pet-fill'+suffix,pattern,'connected pet prediction',True)

    # Resource group is one outer silhouette, not overlapping rings around
    # each component. Coordinates are in a 196px native player power viewport.
    group=Image.new('RGBA',(512,512))
    group.alpha_composite(read(root/'Assets/power_crystal_back.tga'),(128,64))
    case=read(out/'pw_crystal_case.tga').resize((259,128),sampling)
    group.alpha_composite(case,(127,222))
    save('crystal-group-glow',halo(group),'union of crystal and fitted cradle',True)
    orbgroup=Image.new('RGBA',(320,320))
    orbgroup.alpha_composite(read(out/'orb_case_hi.tga'),(32,32))
    save('orb-group-glow',halo(orbgroup).resize((512,512),sampling),'complete orb casing with halo padding',True)
    (out/'geometry.json').write_text(json.dumps(geometry,indent=2)+'\n',encoding='utf-8')
    (root/'Core/HunterGeometry.lua').write_text('-- Generated opening coordinates, normalized unless noted.\nlocal _, ns = ...\nns.HunterGeometry = {\n\tcompact = { '+', '.join(str(v) for v in geometry['compact'])+' },\n\tcritter = { '+', '.join(str(v) for v in geometry['critter'])+' },\n\tpet = { '+', '.join(str(v) for v in [*pet.size,*pb,*portrait_box])+' }\n}\n',encoding='utf-8')
    for source in ('compact-v3','pet-connected','portrait-glass-source'):
        manifest['sources'][source]=hashlib.sha256((src/(source+'.png')).read_bytes()).hexdigest()
    return neutral
