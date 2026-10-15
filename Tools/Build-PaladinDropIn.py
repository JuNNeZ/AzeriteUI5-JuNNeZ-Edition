"""Export the approved Ashbringer / Silver Hand art on native texture contracts.

Sources are retained paintings, literal concept holder/rails/libram cutouts,
and high-resolution endcap/portrait repaints made after live quality review.
Native alpha, glass, fill contours, shadows and atlas cells are registration
data. Geometry and gameplay layout are not changed to fit a generated image.
Run without arguments to build staging; --install requires every source.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from PaladinFillContracts import mask as fitted_mask, clearance_mask, crystal_rects, LAYOUTS, write_guides
from PaladinPalette import CASES as PALETTE_CASES, grade as grade_metal
from PaladinPalette import ORNAMENTS as PALETTE_ORNAMENTS
import PaladinConceptFrames as concept_frames

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'Assets'
WORK = ROOT / 'Docs/Research_Assets/Paladin/Rebuild-2026-10-14'
SOURCE = WORK / 'Sources'
OUT = WORK / 'Export'
SPEC = json.loads((ROOT / 'Docs/Theme Asset Geometry.json').read_text())
for name in ('options-casing-round', 'options-well-round'):
    im = Image.open(ASSETS/(name+'.tga')).convert('RGBA')
    SPEC[name] = {'canvas': list(im.size), 'painted': list(im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())}
ATLAS_PREFIXES = ('border-', 'better-', 'options-casing-round', 'options-well-round')
TEMPLATES = ROOT / 'Docs/Research_Assets/Templates'
BACK = {'hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case',
        'cast_back', 'cast_back_spiked', 'cast_back_wooden'}
CRITTER = {'hp_critter_case', 'hp_critter_case_hi'}
CRYSTAL = {'pw_crystal_case', 'pw_crystal_case_low'}
ORNAMENTS = ['ornament-ashbringer', 'cast-head-libram', 'minimap-north']
EFFECTS = ['light-strands', 'orb-light', 'orb-strands']
OBSOLETE = {
    'action-ring', 'compact-case', 'critter-case', 'crystal-holder-glow', 'crystal-holder',
    'health-case', 'health-glow', 'health-lowmid-glow', 'health-lowmid',
    'health-portrait-glow', 'health-portrait', 'health-small-glow', 'health-small',
    'health-wide-glow', 'health-wide', 'holy-case', 'holy-fill', 'light-body',
    'lion-cast', 'minimap-ring', 'orb-case-glow', 'orb-case', 'party-case', 'plate-case',
    'portrait-case-low', 'portrait-case', 'seal', 'status-backdrop', 'utility-cog',
    'utility-edge', 'utility-plate', 'vehicle-exit',
    *{name+'-v'+str(i) for name in CRYSTAL for i in range(1,6)}
}
S = Image.Resampling.LANCZOS
# Retain the approved concept's bright silver/gold on its signature pieces.
# Other suite surfaces keep the already reviewed gameplay tone.
SIGNATURE = {'pw_crystal_case', 'pw_crystal_case_low',
             'hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bounds(im):
    return im.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()


def register(source, native):
    """Uniform high-resolution downsample and registration, no aspect stretch.

    Native alpha is the final fixed footprint. Generated art is aligned at its
    opaque bounds, and the neutral surface supplies any subpixel uncovered edge.
    """
    source = source.convert('RGBA')
    box, target = bounds(source), bounds(native)
    if not box:
        raise ValueError('empty generated source')
    art = source.crop(box)
    tw, th = target[2]-target[0], target[3]-target[1]
    factor = max(tw/art.width, th/art.height)
    art = art.resize((max(1, round(art.width*factor)), max(1, round(art.height*factor))), S)
    # No stretching: register centre of the uniform source to the native centre.
    base = Image.new('RGBA', native.size, (31, 33, 37, 255))
    x = round((target[0]+target[2]-art.width)/2)
    y = round((target[1]+target[3]-art.height)/2)
    base.alpha_composite(art, (x, y))
    base.putalpha(native.getchannel('A'))
    return base


def atlas_register(source, native):
    # Generated atlas and original contain eight horizontal cells. The native
    # alpha of every individual cell is retained, including seams and gutters.
    out = Image.new('RGBA', native.size)
    cell = native.height
    for i in range(8):
        gen = source.crop((round(i*source.width/8), 0, round((i+1)*source.width/8), source.height))
        # Backdrop stores top/bottom rails vertically. Some generators paint a
        # horizontal strip despite the guide; rotate that one source cell back
        # before registration, never rotate/reshape native alpha or its cell.
        box = bounds(gen)
        if i < 4 and box and box[2]-box[0] > box[3]-box[1]:
            gen = gen.transpose(Image.Transpose.ROTATE_90)
        orig = native.crop((i*cell, 0, (i+1)*cell, cell))
        out.paste(register(gen, orig), (i*cell, 0))
    return out


def register_fill(source,native,name):
    """Register the source's inner lip to the actual fill, not its outer shadow.

    Uniform scaling, no stretch or Lua refit. The freshly painted source has
    a closed dark/transparent cavity enclosed by its silver/gold lip. Its
    width sets scale; the cavity centre sets translation. Native alpha and
    later fill clearance still determine the exact functional footprint.
    """
    rgba = np.asarray(source.convert('RGBA'))
    lum = rgba[:,:,:3].astype(float) @ np.array([.2126,.7152,.0722])
    gold = (rgba[:,:,0].astype(float) > rgba[:,:,2]*1.3) & (rgba[:,:,1].astype(float) > rgba[:,:,2]*1.15)
    barrier = ((lum >= 100) | gold) & (rgba[:,:,3] > 64)
    # Close subpixel paint cracks in the lip for registration only. This field
    # never becomes exported alpha or artwork.
    field = Image.fromarray(np.where(barrier,255,0).astype('uint8'),'L').filter(ImageFilter.MaxFilter(9))
    box = bounds(source); seed = ((box[0]+box[2])//2,(box[1]+box[3])//2)
    assert field.getpixel(seed) == 0, name+' source cavity seed'
    ImageDraw.floodfill(field,seed,128)
    hole = field.point(lambda v:255 if v==128 else 0).getbbox()
    assert hole and hole[0]>0 and hole[1]>0 and hole[2]<source.width and hole[3]<source.height, name+' closed inner lip'
    target = fitted_mask(name,native.size).getbbox()
    factor = (target[2]-target[0])/(hole[2]-hole[0])
    art = source.resize((round(source.width*factor),round(source.height*factor)),S)
    x = round((target[0]+target[2])/2-(hole[0]+hole[2])/2*factor)
    y = round((target[1]+target[3])/2-(hole[1]+hole[3])/2*factor)
    base = Image.new('RGBA',native.size,(31,33,37,255))
    base.alpha_composite(art,(x,y)); base.putalpha(native.getchannel('A'))
    return base


def aperture(native):
    a = native.getchannel('A').point(lambda v: 255 if v > 64 else 0)
    seed = (native.width//2, native.height//2)
    if a.getpixel(seed):
        return np.zeros((native.height, native.width), dtype=bool)
    ImageDraw.floodfill(a, seed, 128)
    return np.asarray(a) == 128


crystal_fits = {}


def export_crystal(name, source, native):
    """Only the approved literal holder; no retired candidate silhouettes."""
    src, target = bounds(source), bounds(native)
    base = LAYOUTS['PlayerFrame']; db = dict(base)
    db.update(base['Novice' if name.endswith('_low') else 'Seasoned'])
    bar, case = crystal_rects(db)
    native_fill = Image.open(ASSETS/Path(db['PowerBarTexture'].replace('\\', '/')).name).convert('RGBA')
    fill_box = bounds(native_fill)
    reference = json.loads((WORK/'Measured-Cradle/cutout.json').read_text())
    concept = reference['crystalLandmarks']['concept']
    crop = reference['crop']
    native_height = (fill_box[3]-fill_box[1])*bar[3]/native_fill.height
    render_scale = native_height/(concept[3]-concept[1])
    max_scale = (target[2]-target[0])*case[2]/native.width/(src[2]-src[0])
    render_scale = min(render_scale, max_scale)
    sx, sy = render_scale*native.width/case[2], render_scale*native.height/case[3]
    art = source.resize((round(source.width*sx), round(source.height*sy)), S)
    world_x = bar[0]+fill_box[0]*bar[2]/native_fill.width+(crop[0]-concept[0])*render_scale
    world_y = bar[1]+fill_box[1]*bar[3]/native_fill.height+(crop[1]-concept[1])*render_scale
    x = round((world_x-case[0])*native.width/case[2])
    y = round((world_y-case[1])*native.height/case[3])
    canvas = Image.new('RGBA', native.size)
    canvas.alpha_composite(art, (x, y))
    painted = bounds(canvas)
    assert painted and painted[2]-painted[0] <= target[2]-target[0], name+' wider than native'
    save(name, canvas)
    save(name+'-front', canvas)
    crystal_fits[name] = {'sourcePainted': list(src), 'nativePainted': list(target),
                         'painted': list(painted), 'uniformScale': render_scale,
                         'policy': 'literal concept cutout; uniform rendered scale; crystal-landmark registration'}


def export_casing(name):
    native = Image.open(ASSETS / (name+'.tga')).convert('RGBA')
    generated = Image.open(SOURCE / (name+'.png')).convert('RGBA')
    if name in CRYSTAL:
        export_crystal(name, generated, native)
        return
    if name in concept_frames.HEALTH | concept_frames.CAST | concept_frames.PORTRAIT:
        fill = fitted_mask(name, native.size) if name not in concept_frames.PORTRAIT else None
        clearance = clearance_mask(name, native.size) if fill is not None else None
        back, front = concept_frames.casing(name, native, fill, clearance)
        save(name, back)
        if front is not None:
            save(name+'-over', front)
        if name in concept_frames.HEALTH | concept_frames.PORTRAIT:
            save(name+'-glow', concept_frames.outline(front if front is not None else back))
        if name in concept_frames.HEALTH:
            # A closed OG dip when bare; a straight mounting shoulder beneath
            # the removable relic. Keep fill/recess unchanged in either state.
            for suffix, image in (('', back), ('-over', front)):
                pixels = np.array(image)
                hole = np.asarray(fill)>0
                x0,y0,x1,y1 = fill.getbbox()
                yy,xx = np.mgrid[:image.height,:image.width]
                shoulder = (xx>x1-52) & (yy>y1+12) & ~hole
                pixels[shoulder,3] = 0
                capped = Image.fromarray(pixels)
                save(name+'-capped'+suffix,capped)
                if suffix: save(name+'-capped-glow',concept_frames.outline(capped))
        return
    if name.startswith('cast_back') or name in CRITTER:
        result = register_fill(generated,native,name)
    else:
        result = atlas_register(generated, native) if name.startswith(ATLAS_PREFIXES) else register(generated, native)
    pixels = np.array(result)
    original = np.array(native)
    # The paintings are lit brighter than gameplay framing. Attenuate only the
    # newly generated material, not native functional glass or game colours.
    tone = .82 if name in SIGNATURE else .64
    pixels[:, :, :3] = np.clip(pixels[:, :, :3].astype(float)*tone, 0, 255).astype('uint8')
    if not name.startswith(ATLAS_PREFIXES):
        top, bottom = bounds(native)[1], bounds(native)[3]
        yy = np.arange(native.height)[:, None, None]
        light = 1.12 - .30*np.clip((yy-top)/max(1,bottom-top), 0, 1)
        pixels[:, :, :3] = np.clip(pixels[:, :, :3].astype(float)*light, 0, 255).astype('uint8')
    maskfile = TEMPLATES / (name+'-fill.png')
    fill = np.asarray(Image.open(maskfile).convert('L')) if maskfile.exists() else None
    if name in CRYSTAL or name in CRITTER:
        fill = np.asarray(fitted_mask(name,native.size))
    if name in PALETTE_CASES:
        metal = original[:,:,3] > 200
        if fill is not None:
            metal &= fill == 0
        pixels = grade_metal(pixels,metal)
    if name in BACK or name in CRITTER or name == 'nameplate_backdrop':
        cavity = fill > 0 if fill is not None else original[:, :, 3] > 0
        y, x = np.mgrid[0:native.height, 0:native.width]
        rng = np.random.default_rng(14010)
        recess = 17 + 7*np.sin(y/3.7) + 4*np.sin(x/23) + rng.normal(0, 2, y.shape)
        # Newly painted neutral empty-bar surface, never a flat black void.
        grey = np.clip(recess, 5, 42).astype('uint8')
        pixels[cavity, :3] = np.repeat(grey[cavity, None], 3, axis=1)
    else:
        inner = aperture(native)
        if fill is not None:
            inner |= fill > 0
        # Inner functional shading and glass come from native pixels, not AI.
        glass = inner & (original[:, :, 3] <= 200)
        pixels[glass, :3] = original[glass, :3]
    pixels[:, :, 3] = original[:, :, 3]
    if name == 'icon_exit_flight':
        # The down arrow is a shared semantic glyph, not Paladin pigment.
        # Only its housing is repainted; retain its native red pixels exactly.
        arrow = (original[:, :, 0] > original[:, :, 1]*1.4) & (original[:, :, 0] > 45)
        pixels[arrow, :3] = original[arrow, :3]
    result = Image.fromarray(pixels, 'RGBA')
    assert result.getchannel('A').tobytes() == native.getchannel('A').tobytes(), name
    save(name, result)
    if name in BACK:
        front = pixels.copy()
        # Foreground opaque rails stay completely outside the exact fill
        # contour, with the native translucent inner shading restored over it.
        foreground_fill = np.asarray(clearance_mask(name,native.size)) if name.startswith('cast_back') else fill
        outside = foreground_fill == 0
        front[:, :, 3] = np.where(outside, original[:, :, 3],
                                 np.where(original[:, :, 3] <= 200, original[:, :, 3], 0))
        inner = (foreground_fill > 0) & (original[:, :, 3] <= 200)
        front[inner, :3] = original[inner, :3]
        save(name+'-over', Image.fromarray(front, 'RGBA'))


exports = {}


def save(name, im):
    target = OUT / (name+'.tga')
    im.save(target, compression=None)
    roundtrip = Image.open(target).convert('RGBA')
    assert roundtrip.tobytes() == im.tobytes(), name+' TGA roundtrip'
    exports[name] = {'canvas': list(im.size), 'sha256': digest(target)}


def ornament(name):
    if name in ('ornament-ashbringer', 'cast-head-libram'):
        canvas = concept_frames.ornament(name)
        save(name, canvas)
        if name == 'ornament-ashbringer':
            save(name+'-glow', concept_frames.outline(canvas))
        return
    source = Image.open(SOURCE / (name+'.png')).convert('RGBA')
    art = source.crop(bounds(source))
    scale = min(224/art.width, 224/art.height)
    art = art.resize((round(art.width*scale), round(art.height*scale)), S)
    canvas = Image.new('RGBA', (256, 256))
    # The left attachment plate overlaps the native bar tip inside the shared
    # slot. Move artwork within its canvas, never the bar or the shared anchor.
    x = max(8, (256-art.width)//2-24) if name == 'ornament-ashbringer' else (256-art.width)//2
    canvas.alpha_composite(art, (x, (256-art.height)//2))
    rgb = np.array(canvas)
    tone = .82 if name == 'ornament-ashbringer' else .68
    rgb[:, :, :3] = (rgb[:, :, :3].astype(float)*tone).astype('uint8')
    if name in PALETTE_ORNAMENTS:
        rgb = grade_metal(rgb,rgb[:,:,3] > 200)
    canvas = Image.fromarray(rgb, 'RGBA')
    save(name, canvas)
    if name == 'ornament-ashbringer':
        alpha = canvas.getchannel('A').filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(4))
        glow = Image.new('RGBA', canvas.size, (255, 255, 255, 0))
        glow.putalpha(alpha)
        save(name+'-glow', glow)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    write_guides()
    required = list(SPEC) + ORNAMENTS
    missing = [n for n in required if not (SOURCE/(n+'.png')).exists()]
    missing += ['HD/'+n for n in ('ornament-ashbringer.png','portrait.png','health-rails.png') if not (concept_frames.HD/n).exists()]
    if args.install and missing:
        raise SystemExit('Incomplete sources: '+', '.join(missing))
    for name in SPEC:
        if (SOURCE/(name+'.png')).exists():
            export_casing(name)
    for name in ORNAMENTS:
        if (SOURCE/(name+'.png')).exists():
            ornament(name)
    manifest = {
        'theme': 'Ashbringer / Silver Hand', 'concept': 'Concepts-2026-10-14',
        'geometry': '26 exact native casing alphas; 4 modular HD health rails on native fills; 2 intact HD portraits; 2 approved crystal holders; unchanged runtime geometry',
        'crystalFit': crystal_fits,
        'measuredCrystal': {'revision': 2, 'reference': 'approved-concept.png',
                            'cutout': 'Measured-Cradle/Concept-holder-cutout.png',
                            'referenceSha256': digest(WORK/'approved-concept.png'),
                            'cutoutSha256': digest(WORK/'Measured-Cradle/Concept-holder-cutout.png')},
        'conceptFrames': {'reference': 'approved-concept.png', 'referenceSha256': digest(concept_frames.REFERENCE),
                          'recipe': 'Tools/PaladinConceptFrames.py',
                          'recipeSha256': digest(ROOT/'Tools/PaladinConceptFrames.py'),
                          'parts': {n+'.png': digest(concept_frames.PARTS/(n+'.png')) for n in
                                    ('health-rails', 'cast-rails', 'portrait', 'ornament-ashbringer', 'cast-head-libram')}},
        'hdSources': {p.name: {'sha256':digest(p), 'canvas':list(Image.open(p).size)}
                      for p in sorted(concept_frames.HD.glob('*.png'))},
        'sources': {p.stem: {'sha256': digest(p)} for p in sorted(SOURCE.glob('*.png'))},
        'textures': exports,
        'inventory': {p.stem: {
                          'disposition': 'replaced casing' if p.stem in SPEC else 'shared functional/semantic/other media',
                          'canvas': list(Image.open(p).size), 'originalSha256': digest(p)}
                      for p in sorted(ASSETS.glob('*.tga'))},
        'sharedEffects': EFFECTS, 'missingSources': missing,
        'liveValidated': False
    }
    (WORK/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    if args.install:
        target = ASSETS/'Paladin'
        # Remove only superseded old Paladin artwork; the three neutral effect
        # textures remain for Lite+. No root/shared/other-theme art is touched.
        for p in target.glob('*.tga'):
            if p.stem in OBSOLETE:
                p.unlink()
        for name in OBSOLETE:
            stale = OUT/(name+'.tga')
            if stale.exists(): stale.unlink()
        for name in exports:
            (target/(name+'.tga')).write_bytes((OUT/(name+'.tga')).read_bytes())
        (target/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(f'{len(exports)} textures exported; {len(missing)} sources pending; install={args.install}')


if __name__ == '__main__':
    main()
