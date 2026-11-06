"""Whole-painting registration and independent border-thickness measurements.

No alpha stencil, edge extension, recolour or aperture erasure is permitted.
The generated sources, not a common cutout, supply every output pixel.
"""
import math
import numpy as np
from PIL import Image


def register(source):
    assert source.width == source.height
    solid = source.getchannel('A').point(lambda a:255 if a>200 else 0).getbbox()
    assert solid, 'No solid ring'
    side = round(source.width * 188 / (solid[3]-solid[1]))
    scale = side/source.width
    offset = (round(127.5-(solid[0]+solid[2]-1)/2*scale), round(127.5-(solid[1]+solid[3]-1)/2*scale))
    scaled = source.resize((side,side),Image.Resampling.LANCZOS)
    paint = scaled.getchannel('A').getbbox()
    assert paint[0]+offset[0]>=0 and paint[1]+offset[1]>=0
    assert paint[2]+offset[0]<=256 and paint[3]+offset[1]<=256, 'Whole painting would be clipped'
    out=Image.new('RGBA',(256,256));out.paste(scaled,offset)
    return out, dict(sourceSize=list(source.size),size=side,offset=list(offset),sourceSolidBounds=list(solid))


def measure(image):
    """12 fixed rays: flats and corners, in actual 96px draw units.

    Use the first and last solid pixel on each ray. Small internal inset rivet
    holes do not shorten the measured band. Glass-free aperture is mandatory.
    """
    alpha=np.asarray(image.convert('RGBA'))[...,3]
    assert alpha[128,128]==0, 'Opening is not transparent'
    box=image.getchannel('A').point(lambda a:255 if a>200 else 0).getbbox()
    result=dict(width=(box[2]-box[0])*96/256,height=(box[3]-box[1])*96/256,inner=[],outer=[],thickness=[])
    radius=np.arange(0,125,.25)
    for degrees in range(0,360,30):
        angle=math.radians(degrees)
        x=np.clip(np.rint(127.5+np.cos(angle)*radius).astype(int),0,255)
        y=np.clip(np.rint(127.5+np.sin(angle)*radius).astype(int),0,255)
        ids=np.flatnonzero(alpha[y,x]>200)
        assert len(ids),'Ring is open on a measurement ray'
        inner,outer=radius[ids[0]]*96/256,radius[ids[-1]]*96/256
        result['inner'].append(inner);result['outer'].append(outer);result['thickness'].append(outer-inner)
    return result


def validate(measurements):
    values=list(measurements.values())
    for name,item in measurements.items():
        assert abs(item['height']-70.5)<=.75, name+' height mismatch'
        # Own painted master is 60px wide; the Masque reference is61.875px.
        # Preserve the complete painting/aspect rather than stretching to it.
        assert abs(item['width']-60)<=1.5, name+' shared-master width mismatch'
        assert all(8<=v<=13.5 for v in item['thickness']), name+' thickness differs from measured Masque band'
    # Different painted bevels retain a subpixel contour allowance, not the
    # former 7-16px range. Compare each corresponding ray across every theme.
    for ray in range(12):
        band=[item['thickness'][ray] for item in values]
        assert max(band)-min(band)<=1.5, 'Theme thickness spread exceeds 1.5px on ray '+str(ray)
