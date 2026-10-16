"""Stage Druid paintings against native geometry; never installs or edits runtime layouts.

python Tools/Build-DruidArt.py --prepare-crystal
"""
from pathlib import Path
import argparse
import importlib.util
import json
import hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from ThemeOrbGlass import restore_glass
from PaladinFillContracts import LAYOUTS, crystal_rects, project, alpha, clearance_mask

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Druid/HD'
ASSETS = ROOT / 'Assets'
S = Image.Resampling.LANCZOS
SPEC = json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
ALIASES = {
    'hp_low_case':'hp_mid_case', 'hp_critter_case':'hp_critter_case_hi',
    'cast_back_wooden':'cast_back', 'orb_case_low':'orb_case_hi',
    'orb-border':'minimap-border', 'portrait_frame_lo':'portrait_frame_hi',
    'pw_crystal_case_low':'pw_crystal_case', 'config_button_bright':'config_button',
    'border-aura':'border-tooltip', 'better-blizzard-border-small-alternate':'border-tooltip'
}
SHARED = {
    'nameplate_backdrop':'neutral backing only, no outer frame',
    'minimap-onebar-backdrop':'shared functional XP/status ring',
    'minimap-twobars-backdrop':'shared functional XP/status ring',
    'options-box':'shared neutral control fill/mask'
}
METERS = {'hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case',
          'hp_critter_case','hp_critter_case_hi','cast_back','cast_back_spiked','cast_back_wooden'}


def load_checker():
    spec = importlib.util.spec_from_file_location('theme_style',ROOT/'Tools/Check-ThemeAssetStyle.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def closed_hole(image):
    field = image.getchannel('A').point(lambda a:255 if a>64 else 0)
    seed = (image.width//2,image.height//2)
    if field.getpixel(seed):
        return Image.new('L',image.size)
    ImageDraw.floodfill(field,seed,128)
    hole = field.point(lambda a:255 if a==128 else 0)
    box = hole.getbbox()
    if not box or box[0]==0 or box[1]==0 or box[2]==image.width or box[3]==image.height:
        return Image.new('L',image.size)
    return hole


def register_material(source,native):
    """Uniformly register a fresh painting. Native alpha is the casing contract.

    Used only for ordinary casing material, never the whole root assembly or
    relics. Record removed/missing paint rather than hiding it in a pass claim.
    """
    image, fit = contain(source,opaque_bounds(native),native.size)
    a = np.asarray(image.getchannel('A'))
    n = np.asarray(native.getchannel('A'))
    fit['paintOutsideNativeFraction'] = float(((a>200)&(n<64)).sum()/max(1,(a>200).sum()))
    fit['missingNativeSurfaceFraction'] = float(((n>200)&(a<64)).sum()/max(1,(n>200).sum()))
    pixels = np.array(image)
    # Extend only actual painted edge RGB into native AA/shadow texels.
    # Transparent generated pixels may contain random red/magenta RGB; never
    # expose those by replacing alpha or applying a maximum-RGB filter.
    rgb = pixels[:,:,:3].copy()
    known = a>128
    for _ in range(max(native.size)):
        wanted = (n>200)&~known
        if not wanted.any():
            break
        before = known.copy()
        for axis,step in ((0,-1),(0,1),(1,-1),(1,1)):
            neighbour = np.roll(before,step,axis)
            if axis==0: neighbour[0 if step==1 else -1,:] = False
            else: neighbour[:,0 if step==1 else -1] = False
            take = ~known & neighbour
            rgb[take] = np.roll(rgb,step,axis)[take]
            known[take] = True
    pixels[:,:,:3] = rgb
    pixels[n<=200,:3] = 0  # native grounding shadows are black, not extruded wood
    pixels[:,:,3] = n
    return Image.fromarray(pixels),fit


def atlas(source,native):
    """Register all eight cells independently; never scale a joined U as an L."""
    a = np.asarray(source.getchannel('A'))>128
    cols = np.flatnonzero(a.any(0))
    groups = np.split(cols,np.where(np.diff(cols)>1)[0]+1)
    groups = [g for g in groups if len(g)>8]
    assert len(groups)==6, 'atlas source must have four strips and two paired corners'
    pieces = []
    for index,group in enumerate(groups):
        piece = source.crop((int(group[0]),0,int(group[-1])+1,source.height))
        piece = piece.crop(piece.getchannel('A').getbbox())
        if index<4:
            pieces.append(piece)
        else:
            pieces.extend((piece.crop((0,0,piece.width//2,piece.height)),
                           piece.crop((piece.width//2,0,piece.width,piece.height))))
    result = Image.new('RGBA',native.size)
    fits = []
    for i,piece in enumerate(pieces):
        n = native.crop((i*native.height,0,(i+1)*native.height,native.height))
        image, fit = register_material(piece,n)
        result.paste(image,(i*native.height,0))
        fits.append(fit)
    return result,{'policy':'eight independent cells with exact native alpha','cells':fits}


def modular_cast(source,native):
    """Fit rail HEIGHT; shorten two plain runs, preserving tips and centre bud.

    Width-only contain made this thin generated source too short vertically.
    Native alpha then exposed material-extension stripes on the upper rail.
    This is the same whole-ended modular rail construction used for Paladin.
    """
    source=source.copy()
    source.putalpha(source.getchannel('A').point(lambda a:0 if a<=8 else a))
    source=source.crop(source.getchannel('A').getbbox())
    target=opaque_bounds(native)
    height=target[3]-target[1]
    factor=height/source.height
    art=source.resize((round(source.width*factor),height),S)
    width=target[2]-target[0]
    cut=art.width-width
    assert cut>=0,'cast source needs more straight rail length'
    first=cut//2
    a,b=round(art.width*.25),round(art.width*.75)
    pieces=(art.crop((0,0,a,art.height)),art.crop((a+first,0,b,art.height)),
            art.crop((b+cut-first,0,art.width,art.height)))
    out=Image.new('RGBA',(width,height))
    x=0
    for piece in pieces:
        out.alpha_composite(piece,(x,0))
        x+=piece.width
    return out


def casing(name):
    native = Image.open(ASSETS/(name+'.tga')).convert('RGBA')
    source_name = ALIASES.get(name,name)
    source = Image.open(WORK/'Sources'/(source_name+'.png')).convert('RGBA')
    original = np.array(native)
    if name.startswith('portrait_frame'):
        # Preserve the complete portrait painting and its own alpha, as with
        # the accepted Paladin whole-art method; never radial-map its planes.
        result,fit = contain(source,opaque_bounds(native),native.size)
        pixels = np.array(result)
        hole = np.asarray(closed_hole(result))>0
        glass = hole & (original[:,:,3]<=200) & (pixels[:,:,3]==0)
        pixels[glass] = original[glass]
        result = Image.fromarray(pixels)
    elif name.startswith(('border-','better-')):
        result,fit = atlas(source,native)
    else:
        if name.startswith('cast_back'):
            source=modular_cast(source,native)
        result,fit = register_material(source,native)
        if name.startswith('cast_back'):
            fit['construction']='uniform source rail height; two shortened plain runs; both whole tips and centre bud retained'
        pixels = np.array(result)
        fill_file = ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')
        fill = np.asarray(Image.open(fill_file).convert('L'))>0 if fill_file.exists() else None
        if name in METERS:
            fill = np.asarray(clearance_mask(name,native.size))>0
            # Empty surface is the generated grain in neutral greyscale.
            grey = np.clip(np.asarray(result.convert('L')).astype(float)*.55,8,52).astype('uint8')
            pixels[fill,:3] = grey[fill,None]
            result = Image.fromarray(pixels)
            front = pixels.copy()
            front[fill,3] = 0
            glass = fill & (original[:,:,3]>0) & (original[:,:,3]<=200)
            front[glass] = original[glass]
            save_texture(name+'-over',Image.fromarray(front))
        else:
            inner = np.asarray(closed_hole(native))>0
            if fill is not None:
                inner |= fill
            glass = inner & (original[:,:,3]<=200)
            pixels[glass] = original[glass]
            if name=='icon_exit_flight':
                glyph = (original[:,:,0].astype(float)>original[:,:,1]*1.4)&(original[:,:,0]>45)
                pixels[glyph] = original[glyph]
            if name.startswith('config_button'):
                rgb = original[:,:,:3].astype(float)
                glyph = (rgb.max(2)-rgb.min(2)>12)&(rgb.max(2)>60)
                pixels[glyph] = original[glyph]
            result = Image.fromarray(pixels)
    save_texture(name,result)
    return {'source':source_name+'.png','canvas':list(result.size),'registration':fit}


def ornaments():
    for name in ('ornament-antler','cast-head-moon','minimap-north'):
        source = Image.open(WORK/'Sources'/(name+'.png')).convert('RGBA')
        image,fit = contain(source,(16,16,240,240),(256,256))
        if name=='cast-head-moon':
            pixels=np.array(image)
            rgb=pixels[:,:,:3].astype(float)
            yy=np.arange(256)[:,None]
            moon=(rgb[:,:,2]>rgb[:,:,0]*1.1)&(rgb[:,:,2]>rgb[:,:,1]*1.04)&(rgb[:,:,2]>120)&(yy<190)&(pixels[:,:,3]>0)
            grey=np.asarray(image.convert('L'))
            pixels[moon,:3]=grey[moon,None]
            light=Image.new('RGBA',image.size,(255,255,255,0))
            light.putalpha(Image.fromarray(np.where(moon,pixels[:,:,3]*.6,0).astype('uint8')))
            save_texture('cast-head-moonlight',light)
            image=Image.fromarray(pixels)
        save_texture(name,image)
        if name=='ornament-antler':
            save_texture(name+'-glow',halo(image.getchannel('A')))


def halo(alpha_image):
    image=Image.new('RGBA',alpha_image.size,(255,255,255,0))
    image.putalpha(alpha_image.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2)))
    return image


def build_suite():
    records = {}
    for name in SPEC:
        if name not in SHARED:
            records[name] = casing(name)
            if name.startswith('portrait_frame'):
                image=Image.open(WORK/'Export'/(name+'.tga')).convert('RGBA')
                save_texture(name+'-glow',halo(image.getchannel('A')))
    ornaments()
    build_crystal()
    checker = load_checker()
    checks = {}
    for path in sorted((WORK/'Export').glob('*.tga')):
        failures,notes = checker.check(path)
        checks[path.stem] = {'failures':failures,'lookNotes':notes,'sha256':digest(path)}
    # Hash every native root texture. No other theme is written by this tool.
    inventory = {str(p.relative_to(ROOT)).replace('\\','/'):{
        'sha256':digest(p),'disposition':SHARED.get(p.stem,
           'repaint staged' if p.stem in records else 'shared functional/semantic/other media')}
        for p in sorted(ASSETS.glob('*.tga'))}
    manifest = {'theme':'Druid - Roots beneath the Moon','status':'HD art staging; runtime not installed',
        'concept':'../concept-sheet-v2.png','conceptSha256':digest(WORK.parent/'concept-sheet-v2.png'),
        'casings':records,'shared':SHARED,'inventory':inventory,'checks':checks,
        'nativeLayoutChanges':False,'liveValidated':False,
        'sources':{p.name:{'canvas':list(Image.open(p).size),'sha256':digest(p)} for p in sorted((WORK/'Sources').glob('*.png'))}}
    (WORK/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    failed = {n:c['failures'] for n,c in checks.items() if c['failures']}
    print(json.dumps({'casings':len(records),'textures':len(checks),'failures':failed},indent=2))


def review():
    """Render exported art with native fills and native layout rectangles."""
    export = WORK/'Export'
    b.asset = asset
    font = 'C:/Windows/Fonts/segoeui.ttf'
    from PIL import ImageFont
    board = Image.new('RGBA',(1536,1700),'#171b20')
    draw = ImageDraw.Draw(board)
    def label(text,x,y,size=18):
        draw.text((x,y),text,font=ImageFont.truetype(font,size),fill='#d7d1c4')
    def place(scene,x,y):
        box = scene.getchannel('A').getbbox()
        if box: board.alpha_composite(scene.crop(box),(x,y))
    label('DRUID - HD EXPORT REVIEW',24,15,30)
    label('Native draw rectangles and fills; offline assembly, not a WoW screenshot',24,56)
    for row,name in enumerate(('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')):
        native = Image.open(ASSETS/(name+'.tga')).convert('RGBA')
        back = Image.open(export/(name+'.tga')).convert('RGBA')
        front = Image.open(export/(name+'-over.tga')).convert('RGBA')
        mask = Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')
        label(name,24,100+row*120)
        for j,f in enumerate((0,.5,1)):
            scene = back.copy()
            m = np.array(mask)
            box = mask.getbbox()
            m[:,round(box[0]+f*(box[2]-box[0])):] = 0
            fill = Image.new('RGBA',scene.size,(175,12,28,0))
            fill.putalpha(Image.fromarray(m))
            scene.alpha_composite(fill)
            scene.alpha_composite(front)
            scene = scene.crop((max(0,opaque_bounds(native)[0]-3),40,min(native.width,opaque_bounds(native)[2]+3),210))
            factor = min(470/scene.width,85/scene.height)
            scene = scene.resize((round(scene.width*factor),round(scene.height*factor)),S)
            board.alpha_composite(scene,(j*505+24,128+row*120))
            label(f'{round(f*100)}%',j*505+420,104+row*120,14)
    label('Native cast / pet / group / mirror meter family',24,590)
    for i,name in enumerate(('cast_back','cast_back_spiked','cast_back_wooden')):
        back = Image.open(export/(name+'.tga')).convert('RGBA')
        front = Image.open(export/(name+'-over.tga')).convert('RGBA')
        for j,f in enumerate((0,.5,1)):
            scene=back.copy()
            mask=clearance_mask(name,scene.size)
            a=np.array(mask)
            a[:,round(scene.width*f) :]=0
            fill=Image.new('RGBA',scene.size,(45,140,52,0))
            fill.putalpha(Image.fromarray(a))
            scene.alpha_composite(fill)
            scene.alpha_composite(front)
            place(scene,24+j*500,625+i*80)
    label('Whole HD portrait, orb and button exports at native canvas sizes',24,890)
    for i,name in enumerate(('portrait_frame_hi','orb_case_hi','party_portrait_border','actionbutton-border','actionbutton-border-square','actionbutton-border-square-rounded')):
        image=Image.open(export/(name+'.tga')).convert('RGBA')
        if name.startswith('orb_case'):
            # Native orb under the exported case, same original layout ratio.
            inside = Image.new('RGBA',image.size)
            fill=Image.open(ASSETS/'orb2.tga').convert('RGBA').resize((140,140),S)
            fill.putalpha(fill.getchannel('A'))
            tint=np.array(fill)
            tint[:,:,:3]=(tint[:,:,:3].astype(float)*np.array([.25,.4,.95])).astype('uint8')
            inside.alpha_composite(Image.fromarray(tint),(58,58))
            inside.alpha_composite(image)
            image=inside
        board.alpha_composite(image,(i*250,925))
        label(name,i*250+8,1180,13)
    label('Whole ornaments in their shared 256px canvases',24,1220)
    for i,name in enumerate(('ornament-antler','cast-head-moon','minimap-north')):
        image=Image.open(export/(name+'.tga')).convert('RGBA')
        if name=='cast-head-moon':
            light=Image.open(export/'cast-head-moonlight.tga').convert('RGBA')
            pixels=np.array(light)
            pixels[:,:,:3]=[150,190,255]
            image.alpha_composite(Image.fromarray(pixels))
        board.alpha_composite(image,(i*275+20,1250))
        label(name,i*275+30,1510,14)
    for i,name in enumerate(('point_plate','config_button','icon_exit_flight')):
        image=Image.open(export/(name+'.tga')).convert('RGBA')
        board.alpha_composite(image,(900+i*200,1260))
        label(name,900+i*200,1420,14)
    label('All native canvases retained. Tall crystal root layers use the existing resource rect; see Crystal-layer-review.png.',24,1620,16)
    board.convert('RGB').save(WORK/'HD-export-review.png')
    print(WORK/'HD-export-review.png')


def prepare_crystal():
    out = WORK / 'Guides'
    out.mkdir(parents=True, exist_ok=True)
    db = dict(LAYOUTS['PlayerFrame'])
    db.update(db['Seasoned'])
    bar, case = crystal_rects(db)
    size = (1024, 1024)
    fill = project(alpha(db['PowerBarTexture']), bar, bar, size)
    fill.save(out / 'crystal-native-fill.png')
    holder = Image.open(ASSETS / 'pw_crystal_case.tga').convert('RGBA')
    native = Image.new('RGBA', size)
    rect = [round((case[i] - bar[i]) / bar[i+2] * size[i]) for i in range(2)]
    dims = [round(case[i+2] / bar[i+2] * size[i]) for i in range(2)]
    native.alpha_composite(holder.resize(dims, S), tuple(rect))
    native.save(out / 'crystal-holder-native.png')
    native_fill = Image.open(ASSETS / 'power_crystal_front.tga').convert('RGBA').resize(size, S)
    assembly = Image.new('RGBA', size)
    assembly.alpha_composite(native_fill)
    assembly.alpha_composite(native)
    assembly.save(out / 'crystal-native-assembly.png')
    guide = Image.new('RGBA', size, '#34383d')
    guide.alpha_composite(assembly)
    guide.paste('#ff00ff', mask=fill.point(lambda v: round(v*.55)))
    # The requested tall roots use the existing full 196x196 resource rect.
    # Retain the low holder measurement as a reference, not its fit boundary.
    a = holder.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
    low_bounds = [rect[0]+round(a[0]*dims[0]/holder.width), 110,
              rect[0]+round(a[2]*dims[0]/holder.width), rect[1]+round(a[3]*dims[1]/holder.height)]
    bounds = [24,24,1000,1000]
    ImageDraw.Draw(guide).rectangle(bounds, outline='#00ffff', width=3)
    guide.convert('RGB').save(out / 'crystal-root-guide.png')
    (out / 'crystal-contract.json').write_text(json.dumps({
        'resourceDrawRect': list(bar), 'nativeHolderDrawRect': list(case),
        'HDCanvas': list(size), 'rootBounds': bounds, 'lowHolderReferenceBounds':low_bounds,
        'fillBounds': list(fill.getbbox()),
        'policy': 'new root back/front use the existing resource rectangle; native crystal and native holder layout unchanged'
    }, indent=2)+'\n', encoding='utf-8')
    print(out / 'crystal-root-guide.png')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def opaque_bounds(image):
    return image.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()


def contain(source, target, canvas):
    """Uniform fit of a whole painting, preserving all tips and its aspect."""
    # image_gen can leave alpha=1 specks across the transparent canvas. They
    # are not painted bounds and must not shrink the whole retained object.
    source = source.copy()
    source.putalpha(source.getchannel('A').point(lambda a:0 if a<=8 else a))
    art = source.crop(source.getchannel('A').getbbox())
    scale = min((target[2]-target[0])/art.width, (target[3]-target[1])/art.height)
    art = art.resize((round(art.width*scale), round(art.height*scale)), S)
    x = round((target[0]+target[2]-art.width)/2)
    y = target[3]-art.height
    result = Image.new('RGBA', canvas)
    result.alpha_composite(art, (x,y))
    return result, {'scale': scale, 'offset': [x,y], 'size': list(art.size),
                    'policy': 'whole painting, uniform scale, no warp or native-alpha stencil'}


def save_texture(name, image):
    image = restore_glass(image, ROOT, name)
    out = WORK / 'Export'
    out.mkdir(exist_ok=True)
    image.save(out / (name+'.png'))
    image.save(out / (name+'.tga'), compression=None)
    assert Image.open(out/(name+'.tga')).convert('RGBA').tobytes() == image.tobytes()


def build_crystal():
    contract = json.loads((WORK/'Guides/crystal-contract.json').read_text())
    source = Image.open(WORK/'Sources/crystal-root-cap.png').convert('RGBA')
    # This approved tall assembly belongs to the EXISTING full resource rect,
    # not the short stock holder's painted width. Constraining tall roots to
    # the old low-U width shrinks the cavity and places them inside the crystal.
    whole_hd, fit = contain(source, (24,24,1000,1000), (1024,1024))
    # Match native resource/health texel density at the unchanged 196px rect.
    # Keep the HD source and rigid fit; downsample the whole painting BEFORE
    # splitting, so front+back reconstruct the complete runtime image exactly.
    whole = whole_hd.resize((256,256), S)
    clean = np.array(whole)
    clean[clean[:,:,3]==0] = 0
    whole = Image.fromarray(clean)
    field = np.asarray(Image.open(WORK/'Guides/crystal-native-fill.png').convert('L').resize(whole.size,S)) > 128
    # Partition one intact painting. Nothing is cut away: inner root pixels
    # go behind the crystal, edge grips stay in front. Union is byte-exact.
    core = np.asarray(Image.fromarray((field*255).astype('uint8')).filter(ImageFilter.MinFilter(9))) > 128
    pixels = np.array(whole)
    front = pixels.copy()
    front[core] = 0
    back = pixels.copy()
    back[~core] = 0
    assert np.array_equal(np.asarray(Image.alpha_composite(Image.fromarray(back),Image.fromarray(front))), pixels)
    overlap = float(((front[:,:,3]>200) & field).sum()/field.sum())
    assert overlap < .20, 'root fingers hide too much native crystal'
    for name, image in [('crystal-roots-back',Image.fromarray(back)),
                        ('crystal-roots-front',Image.fromarray(front))]:
        save_texture(name,image)
    # Greyscale halo includes the entire resource assembly, not only its base.
    silhouette = Image.fromarray(np.maximum(pixels[:,:,3],field.astype('uint8')*255))
    halo = silhouette.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.25))
    glow = Image.new('RGBA',whole.size,(255,255,255,0))
    glow.putalpha(halo)
    save_texture('crystal-assembly-glow',glow)
    native = Image.open(ASSETS/'power_crystal_front.tga').convert('RGBA').resize(whole.size,S)
    backdrop = Image.open(ASSETS/'power_crystal_back.tga').convert('RGBA').resize(whole.size,S)
    tint = np.array(native)
    tint[:,:,:3] = (tint[:,:,:3].astype(float)*np.array([.48,.28,.95])).astype('uint8')
    native = Image.fromarray(tint)
    board = Image.new('RGBA',(1536,1000),'#171b20')
    d = ImageDraw.Draw(board)
    for i,f in enumerate((0,.5,1)):
        scene = Image.new('RGBA',whole.size)
        scene.alpha_composite(backdrop)
        scene.alpha_composite(Image.fromarray(back))
        filled = native.copy()
        a = np.array(filled.getchannel('A'))
        a[:round(whole.height*(1-f))] = 0
        filled.putalpha(Image.fromarray(a))
        scene.alpha_composite(filled)
        scene.alpha_composite(Image.fromarray(front))
        board.alpha_composite(scene.resize((480,480),S),(i*512+16,60))
        d.text((i*512+24,20),f'{round(f*100)}% native crystal - root back / fill / root front',fill='white')
        # Actual 196 layout-unit resource rectangle, beside its native assembly.
        board.alpha_composite(scene.resize((196,196),S),(i*512+20,600))
        original = Image.open(WORK/'Guides/crystal-native-assembly.png').convert('RGBA')
        board.alpha_composite(original.resize((196,196),S),(i*512+260,600))
        d.text((i*512+20,820),'Druid at 196px     |     native at 196px',fill='white')
    board.convert('RGB').save(WORK/'Crystal-layer-review.png')
    (WORK/'crystal-verification.json').write_text(json.dumps({
        'sourceSha256':digest(WORK/'Sources/crystal-root-cap.png'),
        'fit':fit, 'frontCoverageFraction':overlap,
        'layerUnionMatchesWholePainting':True,
        'resourceRectUnchanged':True, 'nativeFillUnchanged':True,
        'canvas':list(whole.size), 'hdCanvas':[1024,1024],
        'runtimeDensity':'native 256 canvas at unchanged 196 resource rect',
        'drawRect':contract['resourceDrawRect'],
        'layerOrder':['native backdrop','crystal-roots-back','native crystal fill','crystal-roots-front'],
        'liveValidated':False
    },indent=2)+'\n',encoding='utf-8')
    print('Crystal layers staged; opaque front overlap:',round(overlap*100,2),'percent')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-crystal', action='store_true')
    parser.add_argument('--crystal', action='store_true')
    parser.add_argument('--suite', action='store_true')
    parser.add_argument('--review', action='store_true')
    args = parser.parse_args()
    if args.prepare_crystal:
        prepare_crystal()
    if args.crystal:
        build_crystal()
    if args.suite:
        build_suite()
    if args.review:
        review()
