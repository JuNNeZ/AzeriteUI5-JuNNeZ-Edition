"""Fail-closed source-to-export gate for new/revised production theme packs.

See Docs/Theme Source Integrity.md. Existing installed art is never modified.
The geometry-only checker remains usable for diagnostics; production installers
must additionally call require_production before copying any export.
"""
from pathlib import Path
import argparse
import hashlib
import json

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def checked_file(record, root=ROOT):
    path = (root/record['path']).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError('missing/unsafe evidence: '+str(path))
    if sha(path) != record['sha256']:
        raise ValueError('stale evidence/source: '+str(path))
    return path


def whole_painting(source, transform, canvas):
    """Replay uniform scale/translation, preserving the painting's own alpha."""
    if set(transform)-{'crop', 'scale', 'offset'}:
        raise ValueError('unsupported source transform; no warp/stencil/extension')
    box = transform.get('crop', [0, 0, source.width, source.height])
    if len(box) != 4 or any(type(v) is not int for v in box):
        raise ValueError('crop must contain four integer coordinates')
    left, top, right, bottom = box
    if not (0 <= left < right <= source.width and 0 <= top < bottom <= source.height):
        raise ValueError('source crop leaves canvas')
    outside = np.asarray(source)[:, :, 3] > 8
    outside = outside.copy(); outside[top:bottom, left:right] = False
    if outside.any():
        raise ValueError('SOURCE CROP removes painted pixels')
    scale = transform['scale']
    if type(scale) not in (int, float) or not np.isfinite(scale) or scale <= 0:
        raise ValueError('invalid uniform scale')
    painting = source.crop(box)
    size = (round(painting.width*scale), round(painting.height*scale))
    if min(size) < 1:
        raise ValueError('painting shrinks to zero')
    if size != painting.size:
        painting = painting.resize(size, Image.Resampling.LANCZOS)
    x, y = transform['offset']
    if type(x) is not int or type(y) is not int or x < 0 or y < 0 or x+size[0] > canvas[0] or y+size[1] > canvas[1]:
        raise ValueError('whole painting leaves export canvas')
    expected = Image.new('RGBA', tuple(canvas))
    expected.paste(painting, (x, y))  # no alpha stencil or RGB propagation
    return expected


def verify_pixels(expected, actual):
    if expected.size != actual.size:
        raise ValueError('export canvas differs from replay')
    e, a = np.asarray(expected), np.asarray(actual)
    visible = (e[:, :, 3] > 0) | (a[:, :, 3] > 0)
    # RGB of fully transparent texels has no rendering meaning. Alpha and all
    # visible RGBA must match exactly, including translucent contour pixels.
    if not np.array_equal(e[:, :, 3], a[:, :, 3]) or not np.array_equal(e[visible], a[visible]):
        raise ValueError('SOURCE RGBA changed: clipped alpha, erased paint, RGB extension or undeclared operation')


def aperture(expected, fill, bridge=None, ornament=False):
    field = np.asarray(fill.convert('L')) > 128
    paint = np.asarray(expected)[:, :, 3] > 200
    if field.shape != paint.shape or not field.any():
        raise ValueError('invalid functional aperture mask')
    allowed = np.asarray(bridge.convert('L')) > 128 if bridge else np.zeros_like(field)
    if allowed.shape != field.shape:
        raise ValueError('bridge canvas differs')
    if (allowed & field).sum()/field.sum() > .20:
        raise ValueError('blanket/oversized bridge mask cannot waive aperture clearance')
    # 20% is a combined foreground/ornament ceiling, not permission for an
    # unmeasured rail to consume 5-20% of the opening. Allow one pixel of AA.
    interior = np.asarray(Image.fromarray(field.astype('uint8')*255).filter(ImageFilter.MinFilter(3))) > 0
    if not ornament and (paint & interior & ~allowed).any():
        raise ValueError('SOURCE APERTURE: undeclared solid paint covers functional fill')
    if (paint & field).sum()/field.sum() > .20:
        raise ValueError('SOURCE APERTURE: foreground exceeds 20% ceiling')


def verify_pack(folder, root=ROOT):
    folder = Path(folder).resolve()
    proof_path = folder/'source-integrity.json'
    if not proof_path.is_file():
        raise ValueError('missing source-integrity.json; geometry-only/historical acceptance cannot authorize production installation')
    proof = json.loads(proof_path.read_text(encoding='utf-8'))
    manifest_path = folder/'manifest.json'
    if proof.get('schema') != 1 or proof.get('assetManifestSha256') != sha(manifest_path):
        raise ValueError('missing/stale source-integrity manifest binding')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    assets = manifest['assets']
    names = {p.stem for p in folder.glob('*.tga')}
    if names != set(assets):
        raise ValueError('export inventory differs from manifest (unlisted/missing textures)')
    for name in names:
        if sha(folder/(name+'.tga')) != assets[name]['sha256']:
            raise ValueError('stale export: '+name)
    # Functional halos retain their separate existing validators. Every actual
    # casing/ornament export must account for its source; no generic skip flag.
    required = {n for n in names if not n.endswith(('-glow', '_glow', '-outline', '_outline'))}
    records = proof.get('paintings', {})
    if not required <= records.keys():
        raise ValueError('missing painting/source proof: '+', '.join(sorted(required-records.keys())))
    spec = json.loads((root/'Docs/Theme Asset Geometry.json').read_text())
    for name in sorted(required):
        item = records[name]
        source_path = checked_file(item['source'], root)
        target = folder/(name+'.tga')
        if source_path == target or sha(target) != assets[name]['sha256']:
            raise ValueError('self-referencing source or stale export: '+name)
        source, actual = read(source_path), read(target)
        role = item.get('role', 'painting')
        base = name.removesuffix('-over')
        fill_path = root/'Docs/Research_Assets/Templates'/(base+'-fill.png')
        if role in ('shared-native', 'functional-recess'):
            if source_path != (root/'Assets'/(base+'.tga')).resolve():
                raise ValueError('functional exception must reference the exact shared native asset: '+name)
            expected = source
            if role == 'functional-recess':
                if name.endswith('-over') or not base.startswith(('hp_', 'cast_')) or not fill_path.is_file():
                    raise ValueError('invalid recess-only exception: '+name)
                field = np.asarray(Image.open(fill_path).convert('L')) > 128
                pixels = np.zeros_like(np.asarray(source)); pixels[field] = np.asarray(source)[field]
                expected = Image.fromarray(pixels)
        elif role == 'painting':
            expected = whole_painting(source, item['transform'], actual.size)
            bridge = None
            if item.get('bridge'):
                bridge_path = checked_file(item['bridge'], root)
                approval = json.loads(checked_file(item['bridgeApproval'], root).read_text())
                if approval.get('maintainerApproved') is not True or approval.get('bridgeSha256') != sha(bridge_path) or approval.get('sourceSha256') != sha(source_path):
                    raise ValueError('bridge approval not bound to this source/mask')
                bridge = Image.open(bridge_path)
            if fill_path.is_file():
                aperture(expected, Image.open(fill_path), bridge)
            if base in ('hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case'):
                from ThemeHealthEndcaps import lowest_point
                native = read(root/'Assets'/(base+'.tga'))
                a, b = lowest_point(expected), lowest_point(native)
                if abs(a[0]-b[0]) > .5 or a[1] != b[1]:
                    raise ValueError('SOURCE TOE differs from frozen native dip: '+name)
            if base in spec:
                box = expected.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
                bounds = spec[base]['painted']; canvas = spec[base]['canvas']
                if list(actual.size) != canvas or box is None or any(abs(box[i]-bounds[i]) > max(3, round(canvas[i % 2]*.04)) for i in range(4)):
                    raise ValueError('SOURCE BOUNDS differ from native geometry: '+name)
        elif role == 'rogue-ring-native-glass-1':
            if name != 'actionbutton-border' or not fill_path.is_file():
                raise ValueError('ring functional composition only supports the measured round action border')
            from RogueFitClosureSource import verify_ring_composite
            expected, painting = verify_ring_composite(item, root)
            aperture(painting, Image.open(fill_path))
            box = expected.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
            bounds, canvas = spec[base]['painted'], spec[base]['canvas']
            if list(actual.size) != canvas or box is None or any(abs(box[i]-bounds[i]) > max(3, round(canvas[i % 2]*.04)) for i in range(4)):
                raise ValueError('SOURCE BOUNDS differ from native geometry: '+name)
        else:
            raise ValueError('unsupported source operation; add a reviewed validator, never bypass: '+role)
        verify_pixels(expected, actual)
    return {'sourceIntegritySha256': sha(proof_path), 'assetManifestSha256': sha(manifest_path), 'paintingsChecked': len(required)}


def require_production(folder, root=ROOT):
    result = verify_pack(folder, root)
    review_path = Path(folder)/'production-review.json'
    if not review_path.is_file():
        raise ValueError('missing production-review.json; installation blocked')
    review = json.loads(review_path.read_text())
    for key in ('sourceIntegritySha256', 'assetManifestSha256'):
        if review.get(key) != result[key]:
            raise ValueError('stale production review: '+key)
    if any(review.get(k) is not True for k in ('numericalPassed', 'maintainerVisualApproved', 'representativeLiveApproved')):
        raise ValueError('numerical, maintainer visual and representative live gates must all pass')
    required = {'complete-1x', 'complete-2x', 'all-tiers', 'fill-states', 'none-all-caps', 'representative-live'}
    if not required <= review.get('evidence', {}).keys():
        raise ValueError('missing full assembly/live evidence')
    for item in review['evidence'].values():
        checked_file(item, root)
    if len({item['path'] for item in review['evidence'].values()}) != len(review['evidence']):
        raise ValueError('review roles must reference separate evidence files')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--production', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps((require_production if args.production else verify_pack)(args.folder), indent=2))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, 'FAIL: '+str(error)+'\n')
