"""Register generated Hunter materials to original AzeriteUI texture contracts.

Artwork comes from image_gen. This only crops, registers and packs it; original
canvas sizes, atlas cells, resource masks and semantic glyphs are retained.
Generated casing silhouettes replace the old artwork; halos follow the new alpha.
Every original root TGA receives an explicit inventory disposition.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'Docs/Research_Assets/Hunter/Production/v1'
OUT = ROOT / 'Assets/Hunter'
S = Image.Resampling.LANCZOS

GROUPS = {
    'frame': ['hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case',
              ],
    'portrait': ['portrait_frame_hi', 'portrait_frame_lo', 'hp_critter_case', 'hp_critter_case_hi'],
    'rings': ['actionbutton-border', 'party_portrait_border', 'point_plate', 'minimap-onebar-backdrop', 'minimap-twobars-backdrop'],
    'compact-v3': ['cast_back', 'cast_back_wooden', 'cast_back_spiked', 'nameplate_backdrop'],
    'exit-v2': ['icon_exit_flight'],
    'box-v2': ['options-box'],
    'minimap-v2': ['minimap-border'],
    'orb-case-v2': ['orb_case_hi', 'orb_case_low', 'orb-border'],
    'cradle-v2': ['pw_crystal_case', 'pw_crystal_case_low'],
    'paw': ['orb-art2'],
    'cog': ['config_button', 'config_button_bright'],
}
ENDCAPS = ['thasdorah', 'talonclaw', 'titanstrike', 'thoridal', 'raeshalare']

def read(path): return Image.open(path).convert('RGBA')
def bounds(im): return im.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def opening(im):
    a = im.getchannel('A').point(lambda v: 255 if v > 64 else 0)
    seed = (im.width//2, im.height//2)
    if a.getpixel(seed): return None
    ImageDraw.floodfill(a,seed,128)
    return a.point(lambda v:255 if v==128 else 0).getbbox()

def nine_slice(art, original, inner, outer):
    # Register the opening and rails independently: readable rails do not
    # enlarge the meter or consume the adjacent castbar's space.
    src=opening(art); edge=bounds(art)
    xs=[edge[0],src[0],src[2],edge[2]]; ys=[edge[1],src[1],src[3],edge[3]]
    xt=[outer[0],inner[0],inner[2],outer[2]]; yt=[outer[1],inner[1],inner[3],outer[3]]
    result=Image.new('RGBA',original.size)
    for y in range(3):
        for x in range(3):
            tile=art.crop((xs[x],ys[y],xs[x+1],ys[y+1]))
            tile=tile.resize((xt[x+1]-xt[x],yt[y+1]-yt[y]),S)
            result.alpha_composite(tile,(xt[x],yt[y]))
    return result

def register(art, original, name=''):
    # New material and alpha only: never composite over old artwork.
    if name.startswith('cast_back'): return nine_slice(art,original,(53,54,202,69),(33,39,217,87))
    if name=='nameplate_backdrop': return nine_slice(art,original,(26,18,230,46),(6,3,250,61))
    target = bounds(original)
    source = bounds(art)
    hole = opening(art)
    if name.startswith('hp_') and name in GROUPS['frame']:
        return art.resize(original.size,S) # opening fitted to native meter in Lua
    desired = None
    if name == 'actionbutton-border': desired = (86,86,170,170)
    elif name == 'minimap-border': desired = (145,144,372,371)
    elif name in ('orb_case_hi','orb_case_low'): desired = (58,58,198,198)
    elif name == 'orb-border': desired = (44,44,212,212)
    elif name.startswith('portrait_frame'): desired = opening(original)
    elif name.startswith('cast_back'): desired = (54,57,202,72)
    elif name == 'nameplate_backdrop': desired = (26,24,230,40)
    if desired and hole:
        sx=(desired[2]-desired[0])/(hole[2]-hole[0]); sy=(desired[3]-desired[1])/(hole[3]-hole[1])
        # Round apertures remain round; compass and clasps stay outside them.
        if name in ('minimap-border','actionbutton-border','orb_case_hi','orb_case_low','orb-border'):
            sx=sy=max(sx,sy)
        size=(round(art.width*sx),round(art.height*sy))
        xy=(round((desired[0]+desired[2]-(hole[0]+hole[2])*sx)/2),round((desired[1]+desired[3]-(hole[1]+hole[3])*sy)/2))
        crop=art.resize(size,S)
    else:
        crop=art.crop(source).resize((target[2]-target[0],target[3]-target[1]),S); xy=target[:2]
    result=Image.new('RGBA',original.size)
    result.alpha_composite(crop,xy)
    return result

def halo(im):
    # Fill enclosed holes before expanding: this is an OUTER fuzzy outline.
    a=im.getchannel('A').point(lambda v:255 if v>64 else 0)
    ImageDraw.floodfill(a,(0,0),128)
    solid=a.point(lambda v:0 if v==128 else 255)
    radius=max(2,round(min(im.size)*.02))
    edge=solid.filter(ImageFilter.MaxFilter(radius*2+1)).filter(ImageFilter.GaussianBlur(radius))
    edge=ImageChops.subtract(edge,solid)
    result=Image.new('RGBA',im.size,'white');result.putalpha(edge)
    return result

def tooltip_atlas(art, original):
    # WoW edgeFile: left/right/top/bottom, then four corners. Each cell retains
    # its exact original mask and gutters. Extract matching material sections
    # from the generated rectangular border; no full frame in an atlas cell.
    art = art.crop(bounds(art)); w,h = art.size; c = round(min(w,h)*.22)
    pieces = [art.crop((0,c,c,h-c)), art.crop((w-c,c,w,h-c)),
              art.crop((c,0,w-c,c)).transpose(Image.Transpose.ROTATE_90),
              art.crop((c,h-c,w-c,h)).transpose(Image.Transpose.ROTATE_90),
              art.crop((0,0,c,c)), art.crop((w-c,0,w,c)),
              art.crop((0,h-c,c,h)), art.crop((w-c,h-c,w,h))]
    result = Image.new('RGBA', original.size)
    side = original.height
    edges = []
    for i,piece in enumerate(pieces[:4]):
        tile = original.crop((i*side,0,(i+1)*side,side))
        packed=register(piece,tile)
        result.paste(packed,(i*side,0))
        edges.append(rim_span(packed))
    # Corners are not stretched into the native corner's bounds: the art's
    # chamfer is longer than its rim, and stretching made solid wedges that
    # filled the tooltip's inner corner and met the rims 4-5x too wide. Each
    # corner is the whole frame, scaled by the factors that sized the rims and
    # placed with its outer edges on theirs, so the rims run straight into the
    # neighbouring edge cells. The frame must be longer than a cell past its
    # chamfer, which every edgeFile here is.
    rim = rim_width(art)
    left,right,top,bottom = edges
    for i,(vertical,horizontal,at_right,at_bottom) in enumerate(
            [(left,top,False,False),(right,top,True,False),(left,bottom,False,True),(right,bottom,True,True)]):
        kx = (vertical[1]-vertical[0]+1)/rim; ky = (horizontal[1]-horizontal[0]+1)/rim
        frame = art.resize((round(w*kx),round(h*ky)),S)
        x = vertical[1]+1-frame.width if at_right else vertical[0]
        y = horizontal[1]+1-frame.height if at_bottom else horizontal[0]
        cell = Image.new('RGBA',(side,side))
        cell.paste(frame.crop((-x,-y,side-x,side-y)),(0,0))
        result.paste(cell,((4+i)*side,0))
    return result

def rim_span(cell):
    # Solid columns of an edge cell: top/bottom are stored rotated, so every
    # edge is a vertical strip.
    a = cell.getchannel('A'); y = cell.height//2
    solid = [x for x in range(cell.width) if a.getpixel((x,y)) >= 128]
    return solid[0], solid[-1]

def rim_width(art):
    a = art.getchannel('A'); y = art.height//2
    x = 0
    while a.getpixel((x,y)) < 128: x += 1
    start = x
    while a.getpixel((x,y)) >= 128: x += 1
    return x-start

def build():
    OUT.mkdir(exist_ok=True)
    manifest = {'sources': {}, 'originals': {}, 'additional': {}}
    materials = {key: read(SOURCE/(key+'.png')) for key in dict.fromkeys([*GROUPS,'tooltip','paw','eagle',*ENDCAPS,'thasdorah-v2','titanstrike-v2','orb-faceted'])}
    for key in materials: manifest['sources'][key] = digest(SOURCE/(key+'.png'))
    mapping = {name: key for key,names in GROUPS.items() for name in names}
    for name in ['border-tooltip','better-blizzard-border-small-alternate','border-aura']: mapping[name] = 'tooltip'
    for original_path in sorted((ROOT/'Assets').glob('*.tga')):
        name = original_path.stem; original = read(original_path)
        if name in mapping:
            key = mapping[name]
            result = tooltip_atlas(materials[key],original) if key == 'tooltip' else register(materials[key],original,name)
            if name == 'orb-art2':
                # Optional pedestal becomes a small paw badge with a dedicated
                # runtime anchor; retaining the old figurine silhouette here
                # would leave unrelated artwork protruding around the new art.
                badge = materials[key].crop(bounds(materials[key]))
                badge.thumbnail((round(original.width*.9),round(original.height*.9)),S)
                result = Image.new('RGBA',original.size)
                result.alpha_composite(badge,((original.width-badge.width)//2,(original.height-badge.height)//2))
            if name == 'border-aura':
                alpha=result.getchannel('A'); result=ImageOps.grayscale(result).convert('RGBA'); result.putalpha(alpha)
            if name == 'config_button_bright':
                alpha = result.getchannel('A'); result = ImageEnhance.Brightness(result).enhance(1.3); result.putalpha(alpha)
            result.save(OUT/original_path.name, compression=None)
            manifest['originals'][name] = {'disposition':'hunter material', 'source':key,
                'path':'Assets/Hunter/'+original_path.name, 'size':list(result.size),
                'alpha':'generated silhouette; opening registered to native meter or icon', 'sha256':digest(OUT/original_path.name)}
        else:
            # Shared functional art is already the correct asset for this skin.
            # Do not duplicate it or reroute health paths recognized by prediction.
            if any(x in name for x in ['glow','highlight','outline','Alert','mask','shade','absorb']):
                reason = 'Neutral mask/highlight: preserve native geometry and runtime color'
            elif name.startswith(('hp_','power','orb','bar-','cast_bar','party_mana','minimap-bars')):
                reason = 'Native fill/backing: preserve resource clipping, prediction and runtime color'
            elif name.startswith(('point_','partyrole','grouprole','raid_target','icon_','icon-','group-finder','options-','plus')):
                reason = 'Semantic glyph: preserve recognizable symbol, atlas coordinates and state colors'
            else:
                reason = 'Shared supporting/seasonal art: original asset retained'
            if name.startswith('power-crystal-ice') or name.startswith('power-bar-') or name=='power_bar_glow':
                reason='Other layout variant: ice crystal disabled in Hunter; flat power bar belongs to excluded SaiyaRatt'
            elif name.startswith('seasonal_'):
                reason='Optional Winter Veil lights: seasonal decoration retained over themed casing'
            elif name in ('GoldpawKapow','JuNNeZKapow'):
                reason='Addon author artwork: branding retained'
            elif name.startswith('minimap-diel'):
                reason='Optional day/night sky: existing sun/moon imagery fits the outdoor Hunter theme'
            elif name.startswith('point_'):
                reason='Other-class resource symbol/fill: native activation and clipping retained; Hunter has Focus'
            elif name.startswith('partyrole') or name.startswith('grouprole'):
                reason='Role identification: retain recognizable tank/healer/damage symbols and colors'
            elif name.startswith('group-finder'):
                reason='Queue-state eye: retain distinct state colors and recognizable animated queue symbol'
            manifest['originals'][name] = {'disposition':'shared original' , 'reason':reason,
                'path':'Assets/'+original_path.name, 'size':list(original.size), 'sha256':digest(original_path)}
    glow_sources = {'hp_cap_case_glow':'hp_cap_case','hp_mid_case_glow':'hp_mid_case','hp_low_case_glow':'hp_low_case',
        'hp_boss_case_glow':'hp_boss_case','hp_critter_case_glow':'hp_critter_case',
        'portrait_frame_glow':'portrait_frame_hi','pw_crystal_case_glow':'pw_crystal_case',
        'orb_case_glow':'orb_case_hi','cast_back_outline':'cast_back',
        'nameplate_glow':'nameplate_backdrop','nameplate_outline':'nameplate_backdrop',
        'actionbutton-glow-white':'actionbutton-border'}
    for name,source in glow_sources.items():
        result=halo(read(OUT/(source+'.tga'))); result.save(OUT/(name+'.tga'))
        mapping[name]=source
        manifest['originals'][name]={'disposition':'hunter material','source':source,'purpose':'neutral tintable outer halo',
            'path':'Assets/Hunter/'+name+'.tga','size':list(result.size),'sha256':digest(OUT/(name+'.tga'))}
    orb=materials['orb-faceted']; orb=orb.crop(bounds(orb)).resize((512,512),S)
    orb.save(OUT/'orb-focus.tga')
    manifest['additional']['orb-focus']={'size':[512,512],'source':'orb-faceted','purpose':'neutral faceted resource fill; native clipping and runtime color','sha256':digest(OUT/'orb-focus.tga')}
    for key in ['eagle','paw',*ENDCAPS]:
        source = key+'-v2' if key in ('thasdorah','titanstrike') else key
        art = materials[source].crop(bounds(materials[source])); art.thumbnail((240,240),S)
        canvas = Image.new('RGBA',(256,256))
        canvas.alpha_composite(art,((256-art.width)//2,(256-art.height)//2))
        name = 'endcap-'+key if key in ENDCAPS else key
        canvas.save(OUT/(name+'.tga'),compression=None)
        manifest['additional'][name] = {'size':[256,256], 'source':source,'sha256':digest(OUT/(name+'.tga'))}
        if key in ENDCAPS:
            # A neutral halo registered to the ornament, tinted by native threat.
            glow = halo(canvas)
            glow.save(OUT/(name+'-glow.tga'), compression=None)
            manifest['additional'][name+'-glow'] = {'size':[256,256], 'source':key,
                'purpose':'neutral threat halo', 'sha256':digest(OUT/(name+'-glow.tga'))}
    for n in ['orb1','orb2','orb3','orb4']:
        manifest['originals'][n].update(disposition='runtime replacement', reason='Hunter StyleOrb uses orb-focus for both native LibOrb layers')
    from HunterAssetGeometry import extend_assets
    neutral = extend_assets(ROOT, manifest, mapping, read, halo, opening, S, nine_slice)
    from ThemeButtonShapes import build_theme
    build_theme(ROOT, 'Hunter', manifest, mapping)
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    lua = '-- Generated by Tools/Build-HunterAssets.py. Decorative replacements only.\nlocal _, ns = ...\nns.HunterMedia = {\n'
    lua += ''.join('\t["'+name+'"] = true,\n' for name in sorted(mapping))+'}\n'
    lua += 'ns.HunterTintable = {\n' + ''.join('\t["'+n+'"] = true,\n' for n in sorted([*glow_sources,'border-aura',*neutral])) + '}\n'
    (ROOT/'Core/HunterMedia.lua').write_bytes(lua.replace('\n','\r\n').encode())
    lines = ['# Hunter original asset inventory', '', '| Original | Disposition | Asset / reason |', '| --- | --- | --- |']
    for name,item in manifest['originals'].items():
        lines.append('| '+name+' | '+item['disposition']+' | '+item.get('reason',item['path'])+' |')
    (SOURCE.parent.parent/'Asset Inventory.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('Hunter:',len(mapping),'registered materials,',len(manifest['additional']),'ornaments;',len(manifest['originals']),'original textures accounted for')

if __name__ == '__main__':
    import sys
    if '--pilot' in sys.argv:
        from HunterPilot import build_pilot
        build_pilot(ROOT, halo)
    else:
        build()
