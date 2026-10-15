"""Approved-sheet rails and HD signature parts on native meter apertures.

The maintainer approved these cutouts on 2026-10-15. Keep the crystal build
separate: its already approved bytes are a locked input, not regenerated here.
No concept health/cast colour is exported. The game's functional fill remains.
The 2026-10-15 quality correction repaints the endcap/portrait at source HD;
the small concept crops remain reference material, never enlarged production.
"""
from pathlib import Path
from functools import lru_cache
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14'
REFERENCE = WORK/'approved-concept.png'
PARTS = WORK/'Concept-Frames'
HD = WORK/'Sources/HD'
S = Image.Resampling.LANCZOS
HEALTH = {'hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case'}
CAST = {'cast_back', 'cast_back_spiked', 'cast_back_wooden'}
PORTRAIT = {'portrait_frame_hi', 'portrait_frame_lo'}


def cut(points, holes=()):
    """Hard traced alpha; RGB stays identical to the reference sheet."""
    image = Image.open(REFERENCE).convert('RGBA')
    alpha = Image.new('L', image.size)
    draw = ImageDraw.Draw(alpha)
    draw.polygon(points, fill=255)
    for hole in holes:
        draw.polygon(hole, fill=0)
    image.putalpha(alpha)
    return image


@lru_cache(maxsize=1)
def sources():
    PARTS.mkdir(exist_ok=True)
    # Target's portrait-facing end is unobscured. Mirror it for the player's
    # crystal-facing end; the separately drawn relic covers the opposite end.
    health = cut([(632,213),(680,213),(686,205),(694,213),
                  (784,213),(793,202),(802,213),(896,213),(905,204),(914,213),
                  (976,213),(995,243),(978,276),(632,276)],
                 [[(638,228),(978,228),(986,243),(977,262),(637,262)]])
    # Remove every pixel of the left relic before rebuilding the part beneath
    # it. Merely cropping at its shoulder leaves gold fragments in the opening.
    continuation = health.crop((644,199,656,280))
    alpha = health.getchannel('A')
    ImageDraw.Draw(alpha).rectangle((0,0,643,health.height), fill=0)
    health.putalpha(alpha)
    health.alpha_composite(continuation, (632,199))
    # Supply a closed tip under the removable endcap, from the unobscured tip.
    tip = health.crop((975,213,996,277)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    health.alpha_composite(tip, (616,213))
    health = health.crop((616,199,997,280)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    health.save(PARTS/'health-rails.png')
    cast = cut([(1245,209),(1338,209),(1355,224),(1340,239),(1245,239)],
               [[(1245,216),(1336,216),(1345,224),(1337,232),(1245,232)]])
    # The book obscures the left end in the sheet. Reconstruct that small
    # underlying section from the unobscured rails and mirrored opposite tip;
    # never bake a strip of the removable book into the ordinary casing.
    cast.alpha_composite(cast.crop((1245,209,1275,240)), (1215,209))
    cast.alpha_composite(cast.crop((1335,209,1356,240)).transpose(Image.Transpose.FLIP_LEFT_RIGHT), (1204,209))
    cast = cast.crop((1200,199,1361,248))
    cast.save(PARTS/'cast-rails.png')
    relic = cut([(520,303),(539,295),(545,288),(573,277),(568,300),
                 (586,319),(570,340),(548,371),(535,344),(530,326)])
    relic = relic.crop((518,275,589,374))
    relic.save(PARTS/'ornament-ashbringer.png')
    book = cut([(1216,203),(1226,203),(1230,201),(1237,202),(1243,204),
                (1244,242),(1234,244),(1225,243),(1216,243)])
    book = book.crop((1213,199,1248,247))
    book.save(PARTS/'cast-head-libram.png')
    portrait = cut([(976,205),(1024,176),(1032,168),(1041,179),(1087,199),
                    (1091,269),(1040,297),(1033,306),(1025,296),(976,272)],
                   [[(992,210),(1033,186),(1075,210),(1076,262),(1034,286),(992,262)]])
    portrait = portrait.crop((970,164,1097,310))
    portrait.save(PARTS/'portrait.png')
    return health, cast, relic, book, portrait


def project(source, source_fill, target_fill, size):
    """Register aperture edges; the native meter is never resized or moved."""
    sx = (target_fill[2]-target_fill[0])/(source_fill[2]-source_fill[0])
    sy = (target_fill[3]-target_fill[1])/(source_fill[3]-source_fill[1])
    art = source.resize((round(source.width*sx), round(source.height*sy)), S)
    canvas = Image.new('RGBA', size)
    canvas.alpha_composite(art, (round(target_fill[0]-source_fill[0]*sx),
                               round(target_fill[1]-source_fill[1]*sy)))
    return canvas


def inner_hole(image, seed=None):
    field = image.getchannel('A').point(lambda a:255 if a>128 else 0)
    seed = seed or (image.width//2,image.height//2)
    assert field.getpixel(seed) == 0, 'aperture seed is covered'
    ImageDraw.floodfill(field,seed,128)
    hole = field.point(lambda a:255 if a==128 else 0)
    box = hole.getbbox()
    assert box and box[0]>0 and box[2]<image.width, 'unclosed aperture'
    return hole


def portrait_art(native):
    """The approved painting, uniformly contained as ONE intact object."""
    source = Image.open(HD/'portrait.png').convert('RGBA')
    box = source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    target = native.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    art = source.crop(box)
    scale = min((target[2]-target[0])/art.width,(target[3]-target[1])/art.height)
    art = art.resize((round(art.width*scale),round(art.height*scale)),S)
    result = Image.new('RGBA',native.size)
    result.alpha_composite(art,(round((target[0]+target[2]-art.width)/2),target[1]))
    return result


def hd_portrait(native):
    art = portrait_art(native)
    # Glass is copied ONLY into the new painting's actual aperture. Never use
    # native metal/alpha as a stencil for the newly approved border.
    original = np.asarray(native)
    glass = np.zeros_like(original)
    inside = np.asarray(inner_hole(art))>0
    take = inside & (original[:,:,3]<=200) & (np.asarray(art)[:,:,3]==0)
    glass[take] = original[take]
    result = Image.fromarray(glass)
    result.alpha_composite(art)
    return result


def health_front(native, fill):
    """HD rails assembled at one material scale, with intact finished ends.

    Shorten plain rail runs or insert whole stud-bearing sections for boss
    width. No radial mapping, per-column contour projection or tiny cutouts.
    Only the native functional fill clearance clips the foreground layer.
    """
    source = Image.open(HD/'health-rails.png').convert('RGBA')
    hole = inner_hole(source,(source.width//2,300))
    srcbox = source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    source = source.crop(srcbox)
    hole = hole.crop(srcbox)
    target = fill.getbbox()
    srcmask = np.asarray(hole)>0
    destmask = np.asarray(fill)>128
    sy = np.flatnonzero(srcmask[:,hole.width//2])
    ty = np.flatnonzero(destmask[:,fill.width//2])
    factor = len(ty)/len(sy)
    art = source.resize((round(source.width*factor),round(source.height*factor)),S)
    hbox = hole.getbbox()
    opening_width = round((hbox[2]-hbox[0])*factor)
    delta = (target[2]-target[0])-opening_width
    if delta < 0:
        # Two cuts in undecorated straight runs, between the three studs.
        cut = -delta
        a,b = round(art.width*.36),round(art.width*.65)
        first = cut//2
        pieces = (art.crop((0,0,a,art.height)),
                  art.crop((a+first,0,b,art.height)),
                  art.crop((b+cut-first,0,art.width,art.height)))
    else:
        # Add two evenly sized stud sections for the longer boss casing.
        a,b = round(art.width*.38),round(art.width*.62)
        first = delta//2
        center = round(art.width*.5)
        pieces = (art.crop((0,0,a,art.height)),
                  art.crop((center-first//2,0,center-first//2+first,art.height)),
                  art.crop((a,0,b,art.height)),
                  art.crop((center-(delta-first)//2,0,center-(delta-first)//2+delta-first,art.height)),
                  art.crop((b,0,art.width,art.height)))
    joined = Image.new('RGBA',(art.width+delta,art.height))
    cursor = 0
    for piece in pieces:
        joined.alpha_composite(piece,(cursor,0)); cursor += piece.width
    canvas = Image.new('RGBA',native.size)
    x = round(target[0]-hbox[0]*factor)
    y = round(ty[0]-sy[0]*factor)
    canvas.alpha_composite(joined,(x,y))
    return np.array(canvas)


def outline(image):
    """Neutral exterior threat halo from the final, hole-filled opaque shape."""
    alpha = image.getchannel('A').point(lambda a:255 if a>128 else 0)
    exterior = alpha.copy()
    ImageDraw.floodfill(exterior,(0,0),128)
    silhouette = exterior.point(lambda a:0 if a==128 else 255)
    outer = silhouette.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
    ring = np.maximum(0,np.asarray(outer).astype(int)-np.asarray(silhouette).astype(int)).astype('uint8')
    glow = Image.new('RGBA',image.size,(255,255,255,0))
    glow.putalpha(Image.fromarray(ring))
    return glow


def casing(name, native, fill, clearance):
    health, cast, _, _, portrait = sources()
    if name in PORTRAIT:
        return hd_portrait(native), None
    source = health if name in HEALTH else cast
    # Coordinates are local to the retained, mirrored/cropped source above.
    source_fill = (19,29,359,63) if name in HEALTH else (19,17,137,33)
    target = fill.getbbox()
    front = health_front(native,fill) if name in HEALTH else np.array(project(source, source_fill, target, native.size))
    original = np.asarray(native)
    inside = np.asarray(clearance) > 0
    front[inside,3] = 0
    # Keep the native translucent inner lip above the functional fill.
    glass = inside & (original[:,:,3] > 0) & (original[:,:,3] <= 200)
    front[glass] = original[glass]
    # A neutral textured recess keeps the native back footprint and underfill.
    yy, xx = np.mgrid[:native.height,:native.width]
    grey = np.clip(19+5*np.sin(xx/23)+5*np.sin(yy/3.7),6,32).astype('uint8')
    back = np.dstack((grey,grey,grey,original[:,:,3]))
    # Front metal also belongs behind the meter, so the ordinary backdrop
    # remains complete if a consumer has no foreground hook (compact frames).
    back_image = Image.fromarray(back)
    back_image.alpha_composite(Image.fromarray(front))
    back = np.array(back_image)
    # Preserve the new metal's own silhouette; native recess only backs fill.
    if name in HEALTH:
        back[:,:,3] = np.maximum(front[:,:,3],np.where(np.asarray(fill)>0,255,0)).astype('uint8')
    else:
        back[:,:,3] = original[:,:,3]
    return Image.fromarray(back), Image.fromarray(front)


def ornament(name):
    _, _, relic, book, _ = sources()
    source = Image.open(HD/'ornament-ashbringer.png').convert('RGBA') if name == 'ornament-ashbringer' else book
    box = source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    art = source.crop(box)
    factor = 224/max(art.size)
    art = art.resize((round(art.width*factor),round(art.height*factor)),S)
    canvas = Image.new('RGBA',(256,256))
    # Relic attaches on the left side of the shared health slot. The book
    # attaches toward the right of the left-hand cast slot, over its rail.
    x = 8 if name == 'ornament-ashbringer' else 248-art.width
    canvas.alpha_composite(art,(x,(256-art.height)//2))
    return canvas
