"""Check a theme's textures against Docs/Theme Asset Style Key.md.

Usage: python Tools/Check-ThemeAssetStyle.py <ThemeFolder>   (e.g. Hunter)

GEOMETRY lines are failures: the texture is not a drop-in replacement for the
original, so it cannot be used without theme-specific layout code. They are
measured against Docs/Theme Asset Geometry.json (Tools/Export-ThemeGeometry.py).
"look" lines are advice on painting and are not failures.

Measures exported TGAs only. It is not a substitute for the fitting checklist
or live checks.
"""
from pathlib import Path
import json, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'Assets'
SPEC = json.loads((ROOT / 'Docs/Theme Asset Geometry.json').read_text())
TEMPLATES = ROOT / 'Docs/Research_Assets/Templates'
NEUTRAL = ('glow', 'outline', '_bar', '-absorb', 'highlight', '-fill', 'mask', 'orb-focus', 'light-', 'orb-light', 'orb-strands', 'seal', 'holy-fill')
WHITE = ('glow', 'outline')
LUMA = np.array([.299, .587, .114])

def hole(im):
    a = im.getchannel('A').point(lambda v: 255 if v > 64 else 0)
    seed = (im.width // 2, im.height // 2)
    if a.getpixel(seed): return None
    ImageDraw.floodfill(a, seed, 128)
    return a.point(lambda v: 255 if v == 128 else 0).getbbox()

def check(path):
    """Return (geometry failures, look notes) for one texture."""
    name = path.stem; im = Image.open(path).convert('RGBA'); a = np.asarray(im).astype(np.float32)
    fails, notes = [], []
    w, h = im.size
    if w & (w - 1) or h & (h - 1): fails.append(f'canvas {w}x{h} is not power-of-two')
    alpha = a[..., 3]; solid = alpha > 200
    if solid.sum() < 16: return fails, notes
    rgb = a[..., :3] / 255; lum = rgb @ LUMA
    px = rgb[solid]; mx = px.max(1); mn = px.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    original = ASSETS / path.name
    if any(k in name for k in NEUTRAL):
        if sat.mean() > .04: fails.append(f'functional layer carries pigment (mean saturation {sat.mean():.2f}); must be greyscale')
        if any(k in name for k in WHITE) and np.percentile(lum[alpha > 8], 5) < .97: fails.append('glow/outline is not pure white')
        if original.exists():
            o = Image.open(original).convert('RGBA')
            if o.size != im.size: fails.append(f'canvas differs from original {o.size}')
            elif '_bar' in name or 'fill' in name:
                oa = np.asarray(o)[..., 3] > 128; ta = alpha > 128
                iou = (oa & ta).sum() / max((oa | ta).sum(), 1)
                if iou < .97: fails.append(f'fill contour differs from the original (overlap {iou:.2f}); a themed fill changes material only')
        return fails, notes
    over = name.endswith('-over'); base = name[:-5] if over else name
    mask_path = TEMPLATES / (base + '-fill.png')
    if mask_path.exists() and (ASSETS / (base + '.tga')).exists():
        m = np.asarray(Image.open(mask_path)) > 128
        oalpha = np.asarray(Image.open(ASSETS / (base + '.tga')).convert('RGBA'))[..., 3]
        if m.shape == alpha.shape:
            cov = (alpha[m] > 200).mean() * 100; ocov = (oalpha[m] > 200).mean() * 100
            semi = ((alpha[m] > 8) & (alpha[m] <= 200)).mean() * 100; osemi = ((oalpha[m] > 8) & (oalpha[m] <= 200)).mean() * 100
            if over:
                if cov > 20: fails.append(f'over layer hides {cov:.0f}% of the fill (limit 20%)')
            elif ocov > 97:   # back layer: sits behind the fill
                if cov < 97: fails.append(f'back layer is open under {100 - cov:.0f}% of the fill; the empty bar would show through')
                inside = rgb[m & solid]; imx = inside.max(1); isat = np.where(imx > 0, (imx - inside.min(1)) / np.maximum(imx, 1e-6), 0)
                hidden = ((isat > .25) & (imx > .15)).mean() * 100
                if hidden > 3: fails.append(f'{hidden:.0f}% of the area behind the fill is coloured detail the fill will cover; move it outside the fill contour or into {base}-over.tga')
                if lum[m & solid].std() < .015: fails.append('recess behind the fill is flat; paint the empty-bar surface')
            else:             # front layer: sits over the fill
                if cov > ocov + 4: fails.append(f'opaque art covers {cov:.0f}% of the fill (original {ocov:.0f}%); the fill looks smaller than it is')
                if osemi > 20 and semi < 10: fails.append(f'inner shading or glass over the fill is missing (semi-transparent {semi:.0f}%, original {osemi:.0f}%)')
    if over:
        return fails, notes
    spec = SPEC.get(name)
    if spec:
        if list(im.size) != spec['canvas']:
            fails.append(f'canvas {list(im.size)} differs from original {spec["canvas"]}')
        else:
            painted = im.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
            tol = (max(3, round(w * .04)), max(3, round(h * .04)))
            off = [painted[i] - spec['painted'][i] for i in range(4)]
            if any(abs(off[i]) > tol[i % 2] for i in range(4)):
                fails.append(f'painted bounds {list(painted)} differ from original {spec["painted"]} by {off} px (tolerance {tol[0]} x, {tol[1]} y)')
            found = hole(im)
            if 'opening' in spec:
                t = (max(2, round(w * .015)), max(2, round(h * .015)))
                if not found: fails.append(f'original opening {spec["opening"]} is covered')
                elif any(abs(found[i] - spec['opening'][i]) > t[i % 2] for i in range(4)):
                    fails.append(f'opening {list(found)} differs from original {spec["opening"]} (tolerance {t[0]} px); band thickness changes')
            if 'meter' in spec and found:
                m = spec['meter']; slack = max(3, round(h * .03))
                if found[0] > m[0] + 2 or found[1] > m[1] + 2 or found[2] < m[2] - 2 or found[3] < m[3] - 2:
                    fails.append(f'opening {list(found)} covers part of the meter {m}')
                elif found[1] < m[1] - slack or found[3] > m[3] + slack:
                    fails.append(f'opening {list(found)} is taller than the meter {m} by more than {slack} px: a gap shows around the fill')
    # Bounds alone cannot detect a changed square/rounded corner radius.
    if name in ('actionbutton-border-square', 'actionbutton-border-square-rounded') and original.exists():
        native = Image.open(original).convert('RGBA')
        if native.size == im.size and native.getchannel('A').tobytes() != im.getchannel('A').tobytes():
            fails.append('square/rounded alpha differs from original; corners, glass and shadow must match exactly')
    if original.exists() and Image.open(original).size == im.size:
        oa = np.asarray(Image.open(original).convert('RGBA')).astype(np.float32); osolid = oa[..., 3] > 200; both = solid & osolid
        if both.sum() > 64 and both.sum() / max((solid | osolid).sum(), 1) > .9:
            corr = np.corrcoef(lum[both], ((oa[..., :3] / 255) @ LUMA)[both])[0, 1]
            if corr > .85: fails.append(f'recolour of the original (shading correlation {corr:.2f}); paint new material')
    # Look: advice only.
    l = lum[solid]; bright = (l > .6).mean() * 100
    if not original.exists():
        if bright > 15: notes.append(f'{bright:.0f}% of pixels brighter than 0.6; ornaments this bright outshine the frame')
        return fails, notes
    ys = np.arange(h)[:, None]; rows = np.where(solid.any(1))[0]; mid = (rows.min() + rows.max()) / 2
    top = lum[solid & (ys < mid)].mean(); bottom = lum[solid & (ys >= mid)].mean()
    atlas = name.startswith(('border-', 'better-'))
    if top < bottom and not atlas: notes.append(f'lit from below (top {top:.2f}, bottom {bottom:.2f})')
    mask = Image.fromarray((solid * 255).astype(np.uint8))
    edge = solid & ~(np.asarray(mask.filter(ImageFilter.MinFilter(3))) > 0)
    fringe = ((alpha > 8) & (alpha <= 200)).sum() / max(edge.sum(), 1)
    if fringe < 6 and not atlas: notes.append(f'no baked grounding shadow (soft fringe {fringe:.1f} px, original 8-17)')
    if np.median(l) > .30: notes.append(f'median luminance {np.median(l):.2f}; original casings sit at 0.10-0.17')
    return fails, notes

def main():
    if len(sys.argv) < 2: sys.exit(__doc__)
    folder = ASSETS / sys.argv[1]; files = sorted(folder.glob('*.tga')); bad = advised = 0
    for path in files:
        fails, notes = check(path)
        if fails or notes:
            print(path.stem)
            for n in fails: print('   GEOMETRY', n)
            for n in notes: print('   look    ', n)
        bad += bool(fails); advised += bool(notes)
    missing = [n for n in SPEC if not (folder / (n + '.tga')).exists()]
    print(f'{sys.argv[1]}: {len(files)} textures, {bad} not drop-in, {advised} with look notes; {len(missing)} original casings not replaced')

if __name__ == '__main__': main()
