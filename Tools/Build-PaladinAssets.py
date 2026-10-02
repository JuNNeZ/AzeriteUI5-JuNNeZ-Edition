"""Register generated art to WoW texture canvases; no artwork is painted here.

Run from the addon root with Pillow installed. Source PNGs are retained locally
under Docs/Research_Assets/Paladin/Production; the resulting TGAs ship in Assets.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'Docs/Research_Assets/Paladin/Production'
REVISION = ROOT / 'Docs/Research_Assets/Paladin/Revision2'
REVISION3 = ROOT / 'Docs/Research_Assets/Paladin/Revision3'
REVISION4 = ROOT / 'Docs/Research_Assets/Paladin/Revision4'
REVISION5 = ROOT / 'Docs/Research_Assets/Paladin/Revision5'
OUT = ROOT / 'Assets/Paladin'
OUT.mkdir(exist_ok=True)
LANCZOS = Image.Resampling.LANCZOS
manifest = {}


def source(name):
    return Image.open(SOURCE / (name + '.png')).convert('RGBA')


def save(name, image):
    image.save(OUT / (name + '.tga'), compression=None)
    manifest[name] = {'size': list(image.size), 'sha256': hashlib.sha256(
        (OUT / (name + '.tga')).read_bytes()).hexdigest()}


def register(name, output, canvas, size, center):
    art = source(name).resize(size, LANCZOS)
    result = Image.new('RGBA', canvas)
    result.alpha_composite(art, (round(center[0] - size[0]/2), round(center[1] - size[1]/2)))
    save(output, result)


# Keep full source canvases for bars; their measured apertures are registered in
# Core/PaladinTheme.lua, independently of the original gameplay fill geometry.
def reflow_bar(name, left, right, removed, output=None, folder=SOURCE):
    # Shorten only the plain middle run. End ornaments retain equal X/Y scale
    # at the native meter aspect, instead of being stretched tall in the client.
    art = Image.open(folder/(name+'.png')).convert('RGBA')
    result = Image.new('RGBA', (art.width-removed, art.height))
    result.paste(art.crop((0, 0, left, art.height)), (0, 0))
    result.paste(art.crop((left, 0, right, art.height)).resize((right-left-removed, art.height), LANCZOS), (left, 0))
    result.paste(art.crop((right, 0, art.width, art.height)), (right-removed, 0))
    save(output or name, result.resize((1024, 512), LANCZOS))

# Registration follows the painted body, not the full texture rectangle.
# Native health art has a transparent lower strip plus an extended right tip.
reflow_bar('health-case', 350, 1500, 160)
reflow_bar('health-case', 350, 1500, 30, 'health-portrait')
reflow_bar('health-case', 350, 1500, -500, 'health-wide')
reflow_bar('health-case', 350, 1500, 128, 'health-lowmid')
reflow_bar('health-case', 350, 1500, 350, 'health-small')
reflow_bar('lion-cast', 500, 1750, 154, folder=REVISION5)
# The seal casing is centered on its aperture, not its flame-tipped silhouette.
# Fill and casing share one pixel grid; only the inner aperture lights up.
# The existing point StatusBar continues to own activation.
holy = Image.open(REVISION5/'holy-case.png').convert('RGBA')
scale = .17
case = Image.new('RGBA', (256,256))
case.alpha_composite(holy.resize((round(holy.width*scale),round(holy.height*scale)),LANCZOS),
                     (round(128-554*scale),round(128-729*scale)))
save('holy-case',case)
glyph = Image.open(REVISION5/'holy-fill.png').convert('RGBA')
# The star junction is at (531.5,809), above the old crop's midpoint.
# Register that junction to the casing aperture center, not the glyph bounds.
material = glyph.crop((110,254,953,1364)).convert('L').convert('RGBA')
material = material.resize((375,506),LANCZOS)
registered = Image.new('RGBA',holy.size)
registered.paste(material,(367,476))
fill = Image.new('RGBA',case.size)
fill.alpha_composite(registered.resize((round(holy.width*scale),round(holy.height*scale)),LANCZOS),
                     (round(128-554*scale),round(128-729*scale)))
# Isolate the enclosed opening from the final exported casing. Its inverse
# alpha gives the fill the very same antialiased boundary, without any offset.
region = case.getchannel('A').point(lambda a:255 if a>=240 else 0)
ImageDraw.floodfill(region,(128,128),128)
aperture = region.point(lambda a:255 if a==128 else 0)
fill.putalpha(ImageChops.multiply(aperture,ImageChops.invert(case.getchannel('A'))))
save('holy-fill',fill)
# Orb casing opening: 803 / 1254 * 216 / 256 * 188 ~= 102px.
register('orb-case', 'orb-case', (256, 256), (216, 216), (128, 128))
holder = source('crystal-holder').crop((419, 52, 1756, 699))
holder = holder.crop(holder.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox())
# Original holder's painted width is 177px, not its padded 256px canvas.
# Keep the detailed lion's aspect; its extra height is intentional ornament.
holder = holder.resize((177, round(holder.height*177/holder.width)), LANCZOS)
holder_canvas = Image.new('RGBA', (256, 128))
holder_canvas.alpha_composite(holder, (39, round(56-holder.height/2)))
save('crystal-holder', holder_canvas)

# The body and strands remain grayscale. Clip with the original masks, so
# applying a game color cannot multiply a gold pigment into another resource.
body = source('light-body').resize((512, 512), LANCZOS)
strands = source('light-strands').resize((512, 512), LANCZOS)
save('light-body', body)
save('light-strands', strands)
orb_mask = Image.open(ROOT / 'Assets/orb2.tga').convert('RGBA').getchannel('A').resize((512, 512), LANCZOS)
for name, art in [('orb-light', body), ('orb-strands', strands)]:
    art = art.copy()
    art.putalpha(ImageChops.multiply(art.getchannel('A'), orb_mask))
    save(name, art)

def fit_original(art, original):
    """Register generated material to the original opaque bounds and alpha.

    Generative margins are not reliable texture coordinates. The original
    silhouette, holes, shadow falloff and canvas are the registration contract.
    """
    bounds = lambda im: im.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
    target = bounds(original)
    material = art.crop(bounds(art)).resize((target[2]-target[0], target[3]-target[1]), LANCZOS)
    result = original.copy()
    result.alpha_composite(material, target[:2])
    result.putalpha(original.getchannel('A'))
    assert ImageChops.difference(result.getchannel('A'), original.getchannel('A')).getbbox() is None
    return result


revision_sources = {}
for output, edit, template in [('action-ring', 'action-subtle', 'actionbutton-border'),
                               ('utility-cog', 'utility-subtle', 'config_button'),
                               ('compact-case', 'compact-subtle', 'cast_back')]:
    art = Image.open(REVISION / (edit+'.png')).convert('RGBA')
    original = Image.open(ROOT / 'Assets' / (template+'.tga')).convert('RGBA')
    save(output, fit_original(art, original))
    revision_sources[edit+'.png'] = hashlib.sha256((REVISION/(edit+'.png')).read_bytes()).hexdigest()

# Preserve all eight original atlas cells, including their gutters and rotated
# horizontal strips. Register each cell independently, not the padded AI canvas.
art = Image.open(REVISION/'tooltip-subtle.png').convert('RGBA')
original = Image.open(ROOT/'Assets/border-tooltip.tga').convert('RGBA')
atlas = Image.new('RGBA', original.size)
for i in range(8):
    cell = art.crop((round(i*art.width/8), 0, round((i+1)*art.width/8), art.height))
    atlas.paste(fit_original(cell, original.crop((i*64, 0, (i+1)*64, 64))), (i*64, 0))
save('utility-edge', atlas)
revision_sources['tooltip-subtle.png'] = hashlib.sha256((REVISION/'tooltip-subtle.png').read_bytes()).hexdigest()

revision3_sources = {}
for output, edit, template in [('minimap-ring', 'minimap-simple', 'minimap-border'),
                               ('portrait-case', 'portrait-simple', 'portrait_frame_hi'),
                               ('portrait-case-low', 'portrait-simple', 'portrait_frame_lo'),
                               ('plate-case', 'plate-simple', 'nameplate_backdrop'),
                               ('seal', 'seal-simple', 'point_crystal')]:
    art = Image.open(REVISION3/(edit+'.png')).convert('RGBA')
    original = Image.open(ROOT/'Assets'/(template+'.tga')).convert('RGBA')
    save(output, fit_original(art, original))
    revision3_sources[edit+'.png'] = hashlib.sha256((REVISION3/(edit+'.png')).read_bytes()).hexdigest()
revision4_sources = {}
for output, template in [('party-case','party_portrait_border'), ('utility-plate','point_plate'),
                         ('vehicle-exit','icon_exit_flight'), ('status-backdrop','minimap-onebar-backdrop')]:
    art = Image.open(REVISION4/(output+'.png')).convert('RGBA')
    original = Image.open(ROOT/'Assets'/(template+'.tga')).convert('RGBA')
    save(output, fit_original(art, original))
    revision4_sources[output+'.png'] = hashlib.sha256((REVISION4/(output+'.png')).read_bytes()).hexdigest()
save('critter-case', fit_original(Image.open(REVISION3/'portrait-simple.png').convert('RGBA'),
                                Image.open(ROOT/'Assets/hp_critter_case.tga').convert('RGBA')))
# Runtime threat feedback needs a neutral alpha silhouette of the exact casing.
for original, output in [('health-case', 'health-glow'),
                         ('health-portrait', 'health-portrait-glow'), ('health-wide', 'health-wide-glow'),
                         ('health-lowmid', 'health-lowmid-glow'), ('health-small', 'health-small-glow'),
                         ('crystal-holder', 'crystal-holder-glow'), ('orb-case', 'orb-case-glow')]:
    image = Image.open(OUT / (original + '.tga')).convert('RGBA')
    matte = Image.new('RGBA', image.size, (255, 255, 255, 0))
    matte.putalpha(image.getchannel('A').filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2)))
    save(output, matte)
source_names = ['health-case', 'lion-cast', 'portrait-case', 'plate-case',
                'action-ring', 'minimap-ring', 'utility-frame', 'seal',
                'crystal-holder', 'orb-case', 'light-body', 'light-strands']
manifest['_sources'] = {name+'.png': hashlib.sha256((SOURCE/(name+'.png')).read_bytes()).hexdigest()
                        for name in source_names}
manifest['_revision2_sources'] = revision_sources
manifest['_revision3_sources'] = revision3_sources
manifest['_revision4_sources'] = revision4_sources
manifest['_revision5_sources'] = {name+'.png': hashlib.sha256((REVISION5/(name+'.png')).read_bytes()).hexdigest()
                                 for name in ('lion-cast','holy-case','holy-fill')}
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print('Packaged', sum(not name.startswith('_') for name in manifest), 'RGBA textures in', OUT)
