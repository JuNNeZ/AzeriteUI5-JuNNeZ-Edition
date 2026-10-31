"""Whole-painting health caps on the native casing canvas (2026-10-17 contract).

No cut shoulders, stretched ornaments or invented mounting geometry. Reuse this
registration for new asset packs; runtime must follow the actual backdrop and
scale around the returned normalized dip with the shared theme engine.
"""
import numpy as np
from PIL import Image, ImageFilter


def lowest_point(image):
    solid = np.asarray(image.convert('RGBA'))[:, :, 3] > 128
    rows = np.flatnonzero(solid.any(axis=1))
    if not len(rows):
        raise ValueError('Cannot register an empty casing/ornament')
    y = int(rows[-1])
    return float(np.median(np.flatnonzero(solid[y]))), y


def terminal_mask(casing):
    """Full ending from the dip's first descending edge through its outer tip."""
    tx, _ = lowest_point(casing)
    p = np.asarray(casing.convert('RGBA'))
    solid = p[:,:,3]>128
    columns = np.flatnonzero(solid.any(0))
    x0,x1 = int(columns[0]),int(columns[-1])+1
    bottom = solid.shape[0]-1-solid[::-1].argmax(0)
    rail_bottom = int(np.median(bottom[round(x0+(x1-x0)*.3):round(x0+(x1-x0)*.65)]))
    y,x = np.indices(solid.shape)
    descending = solid & (x>x0+(x1-x0)*.75) & (y>rail_bottom+1)
    seam = min(int(np.where(descending)[1].min()) if descending.any() else int(tx),int(np.floor(tx)))
    return Image.fromarray((solid & (x>=seam)).astype('uint8')*255)


def terminal_coverage(casing, cap):
    """A one-source-pixel AA tolerance is allowed only at the cap contour."""
    required = np.asarray(terminal_mask(casing))>0
    opaque = np.asarray(cap.convert('RGBA'))[:,:,3]>=240
    # No percentage threshold may hide a thin but long exposed casing point.
    expanded = np.asarray(Image.fromarray(opaque.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
    exposed = required & ~expanded
    return {'terminalPixels':int(required.sum()),
            'terminalCoveredFraction':float((required & opaque).sum()/max(1,required.sum())),
            'exposedTerminalPixelsBeyondAA':int(exposed.sum()),'edgeToleranceSourcePixels':1}


def align(source, casing, height, fill_mask, approved_terminal_exposure=None):
    """Uniformly downsample the whole object, then translate its toe to the dip."""
    source = source.convert('RGBA')
    box = source.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
    if not box:
        raise ValueError('Empty ornament painting')
    painting = source.crop(box)
    # The last 3 percent must contain one toe, not two neighbouring blade tips.
    # A median over two disconnected bottom islands would invent a false join.
    solid_source = np.asarray(painting)[:, :, 3] > 128
    low_columns = np.flatnonzero(solid_source[-max(2, round(painting.height*.03)):].any(axis=0))
    assert len(np.split(low_columns, np.flatnonzero(np.diff(low_columns)>2)+1)) == 1, 'two adjacent lower tips; correct the source painting'
    factor = height / painting.height
    painting = painting.resize((round(painting.width * factor), height), Image.Resampling.LANCZOS)
    tx, ty = lowest_point(casing)
    ax, ay = lowest_point(painting)
    x, y = round(tx - ax), ty - ay
    if min(x, y) < 0 or x + painting.width > casing.width or y + painting.height > casing.height:
        raise ValueError('Whole cap does not fit the native canvas')
    cap = Image.new('RGBA', casing.size)
    cap.alpha_composite(painting, (x, y))
    px, py = lowest_point(cap)
    solid = np.asarray(cap)[:, :, 3] > 128
    native = np.asarray(casing)[:, :, 3] > 128
    mask = np.asarray(fill_mask.convert('L')) > 128
    covered = float(((np.asarray(cap)[:, :, 3] > 200) & mask).sum() / max(1, mask.sum()))
    assert abs(px - tx) <= .5 and py == ty, 'cap toe misses the bare dip'
    assert np.any(solid[ty] & native[ty]), 'toe and dip do not share an opaque pixel'
    assert not solid[ty + 1:].any(), 'second lower point'
    assert covered <= .20, 'cap hides more than 20 percent of the functional fill'
    terminal = terminal_coverage(casing, cap)
    if approved_terminal_exposure is None:
        assert terminal['exposedTerminalPixelsBeyondAA']==0, 'cap leaves terminal metal exposed: '+str(terminal)
    else:
        # A maintainer may approve a specific observed defect. Match its exact
        # pixels; never turn that exception into a larger numeric tolerance.
        required = np.asarray(terminal_mask(casing)) > 0
        opaque = np.asarray(cap)[:, :, 3] >= 240
        expanded = np.asarray(Image.fromarray(opaque.astype('uint8')*255).filter(ImageFilter.MaxFilter(3))) > 0
        expected = np.asarray(approved_terminal_exposure.convert('L')) > 128
        assert expected.shape == required.shape and np.array_equal(required & ~expanded, expected), 'terminal exposure differs from the explicitly approved pixel mask'
        terminal['approvedTerminalExposurePixels'] = int(expected.sum())
    return cap, {'dip': [tx, ty], 'normalizedDip': [tx/casing.width, ty/casing.height],
                 'capPoint': [px, py], 'maxNativePixelError': abs(px-tx),
                 'fillCovered': covered, 'uniformScale': factor,
                 'offset': [x, y], 'wholePainting': True, **terminal}
