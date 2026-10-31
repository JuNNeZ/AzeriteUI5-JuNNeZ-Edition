"""Editable textured face construction, not a stencil on an existing painting.

The recipe contains authored geometric faces and new material swatches. Rendering
has no access to native textures/masks. Geometry references are measured once by
the recipe author and hash-locked separately. PNG export is a uniform replay.
"""
from pathlib import Path
import hashlib
import json
import math

import numpy as np
from PIL import Image, ImageDraw


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rasterize(scene, root):
    if scene.get('schema') != 'rogue-textured-faces-1':
        raise ValueError('unsupported source construction')
    if set(scene) - {'schema', 'canvas', 'density', 'materials', 'faces', 'rivets', 'geometryReferences', 'intent'}:
        raise ValueError('undeclared construction operation')
    density = scene['density']
    if density != 4 or scene['canvas'] not in ([1024, 256], [256, 128]):
        raise ValueError('unsupported source density/canvas')
    size = tuple(v * density for v in scene['canvas'])
    image = Image.new('RGBA', size)
    materials = {}
    for name, item in scene['materials'].items():
        file = (Path(root) / item['path']).resolve()
        if not file.is_relative_to(Path(root).resolve()) or sha(file) != item['sha256']:
            raise ValueError('missing/stale material')
        materials[name] = np.asarray(Image.open(file).convert('RGB'))
    for face in scene['faces']:
        if set(face) != {'points', 'material', 'light', 'slope', 'origin'}:
            raise ValueError('unsupported face operation')
        points = [(round(x * density), round(y * density)) for x, y in face['points']]
        x0, y0 = min(x for x, _ in points), min(y for _, y in points)
        x1, y1 = max(x for x, _ in points) + 1, max(y for _, y in points) + 1
        if min(x0, y0) < 0 or x1 > size[0] or y1 > size[1]:
            raise ValueError('authored face leaves source canvas')
        mask = Image.new('L', (x1 - x0, y1 - y0))
        ImageDraw.Draw(mask).polygon([(x - x0, y - y0) for x, y in points], fill=255)
        yy, xx = np.indices((y1 - y0, x1 - x0))
        texture = materials[face['material']]
        ox, oy = face['origin']
        pixels = texture[(yy + y0 + oy) % texture.shape[0], (xx + x0 + ox) % texture.shape[1]].astype(float)
        # Lighting belongs to the new face, not to a retinted old casing.
        tx = xx / max(1, x1 - x0 - 1) - .5
        ty = yy / max(1, y1 - y0 - 1) - .5
        light = np.maximum(.05, face['light'] + face['slope'][0] * tx + face['slope'][1] * ty)
        pixels = np.clip(pixels * light[:, :, None], 0, 255).astype('uint8')
        paint = Image.fromarray(pixels).convert('RGBA')
        paint.putalpha(mask)
        image.alpha_composite(paint, (x0, y0))
    draw = ImageDraw.Draw(image)
    for rivet in scene['rivets']:
        if set(rivet) != {'center', 'radius'}:
            raise ValueError('unsupported rivet operation')
        x, y = (v * density for v in rivet['center'])
        radius = rivet['radius'] * density
        for fraction, offset, color in ((1.18, (0, .4), '#101312'), (1, (0, 0), '#74603b'),
                                         (.76, (0, -.14), '#b29a61'), (.57, (.05, .02), '#6d5732'),
                                         (.27, (-.2, -.35), '#d0bd85')):
            r = radius * fraction
            dx, dy = offset[0] * radius, offset[1] * radius
            draw.ellipse((x + dx - r, y + dy - r, x + dx + r, y + dy + r), fill=color)
    return image


def face(points, material='steel', light=1, slope=(0, 0), origin=(0, 0)):
    return {'points': points, 'material': material, 'light': light, 'slope': list(slope), 'origin': list(origin)}


def spans(mask):
    result = {}
    for x in np.flatnonzero(mask.any(0)):
        y = np.flatnonzero(mask[:, x])
        result[int(x)] = (int(y[0]), int(y[-1]) + 1)
    return result


def author_health(native, functional, materials, references):
    # Only the author reads reference geometry. The renderer replays the saved
    # coordinates, independently of native alpha, and never edits old painting.
    outer = spans(np.asarray(native)[:, :, 3] > 128)
    opening = spans(np.asarray(functional.convert('L')) > 128)
    faces = []

    def band(x, top, bottom, lights):
        if bottom <= top:
            return
        # Narrow actual bevels and a deep material face, not V2's three broad
        # constant-color stripes. The material has its own painted detail.
        height = bottom - top
        cuts = [top, min(top + 1.2, bottom), min(top + 3.2, bottom), max(top + 3.2, bottom - 2.2), bottom]
        cuts = sorted(min(bottom, max(top, v)) for v in cuts)
        for index, (lo, hi) in enumerate(zip(cuts, cuts[1:])):
            if hi > lo:
                faces.append(face([[x, lo], [x + 1, lo], [x + 1, hi], [x, hi]],
                                  light=lights[index], slope=(0, -.12), origin=(71, 13)))

    for x, (top, bottom) in outer.items():
        if x in opening:
            a, b = opening[x]
            band(x, top, a, (2.1, 1.45, .8, .94))
            band(x, b, bottom, (1.6, .96, .7, .35))
        else:
            band(x, top, bottom, (1.7, 1.05, .74, .43))
    # New coherent bevel facets, seams and local worn chips. Each face is
    # authored inside the measured source construction; no fill-mask erasure.
    for left, right in ((249, 380), (391, 495), (506, 613), (624, 713)):
        faces += [face([[left, 84], [right - 8, 83], [right, 87], [left + 11, 89]], light=1.0, slope=(.12, -.4)),
                  face([[left + 5, 90], [right - 3, 89], [right - 9, 97], [left + 15, 96]], light=.7, slope=(0, -.2)),
                  face([[left + 8, 148], [right - 7, 149], [right - 17, 158], [left + 21, 155]], light=.78, slope=(.2, -.15)),
                  face([[left + 17, 157], [right - 14, 160], [right - 4, 166], [left + 4, 165]], light=.55),
                  face([[left + 18, 84], [left + 48, 84], [left + 39, 85], [left + 13, 85]], light=1.85),
                  face([[right - 6, 84], [right - 3, 85], [right - 14, 94], [right - 10, 97], [right - 15, 97], [right - 18, 93]], light=.2),
                  face([[right - 4, 85], [right - 3, 86], [right - 13, 94], [right - 10, 97], [right - 11, 97], [right - 15, 94]], light=1.55),
                  face([[left + 21, 151], [left + 25, 152], [left + 32, 164], [left + 30, 166], [left + 27, 158]], light=.25),
                  face([[left + 19, 150], [left + 21, 150], [left + 28, 158], [left + 29, 164], [left + 27, 162]], light=1.45),
                  face([[left + 40, 163], [left + 68, 162], [left + 60, 163], [left + 38, 164]], light=1.4)]
    # End turns need a connected bevel of their own. Horizontal column lighting
    # alone makes the closed ends look like flat slabs, even with good texture.
    faces += [face([[217, 121], [236, 85], [240, 90], [224, 122], [240, 160], [234, 161]], light=1.55, slope=(.25, -.5)),
              face([[224, 122], [240, 92], [243, 96], [230, 123], [243, 154], [239, 158]], light=.77, slope=(.2, -.2)),
              face([[791, 73], [805, 108], [799, 113], [784, 79]], light=1.6, slope=(-.3, -.2)),
              face([[799, 118], [805, 117], [759, 182], [756, 181]], light=.98, slope=(-.3, -.35)),
              face([[722, 168], [750, 183], [754, 183], [737, 170]], light=1.45, slope=(-.15, -.25))]
    # Match the native small stud locations; no additional ornaments.
    for x in (367, 508, 650):
        faces += [face([[x - 9, 80], [x, 69], [x, 82]], light=1.9),
                  face([[x, 69], [x + 10, 80], [x + 1, 83]], light=.66)]
    rivets = []
    for x in (302, 686):
        for top, bottom, shear in ((80, 99, -4), (144, 168, 6)):
            faces += [face([[x - 14, top], [x + 17, top], [x + 17 + shear, bottom], [x - 14 + shear, bottom]],
                           'leather', .52, (.12, -.15), (913, 53)),
                      face([[x - 12, top + 1], [x + 14, top + 1], [x + 14 + shear, bottom - 1], [x - 12 + shear, bottom - 1]],
                           'leather', 1.18, (.35, -.22), (913, 53)),
                      face([[x - 10, top + 1], [x - 7, top + 1], [x - 7 + shear, bottom - 1], [x - 10 + shear, bottom - 1]],
                           'leather', 1.6, (0, -.4), (913, 53)),
                      face([[x + 9, top + 2], [x + 14, top + 1], [x + 14 + shear, bottom - 1], [x + 8 + shear, bottom - 2]],
                           'leather', .58, (-.2, -.2), (913, 53))]
            rivets.append({'center': [x + (2 if shear > 0 else 0), (top + bottom) / 2], 'radius': 3.2})
    return {'schema': 'rogue-textured-faces-1', 'canvas': [1024, 256], 'density': 4,
            'materials': materials, 'faces': faces, 'rivets': rivets, 'geometryReferences': references,
            'intent': 'New textured steel/leather face construction around unchanged functional fill; no prior casing painting is masked.'}


def author_seat(materials):
    # A low interior floor at native center lip Y65; no raised second rim.
    # Clear both actual normal/ice painted-face silhouettes; cover only the
    # flat backdrop foot/shadow beneath them. Original lip Y72 stays intact.
    faces = [face([[83, 72], [96, 65], [162, 65], [176, 72], [174, 76], [85, 76]], light=.35),
             face([[86, 72], [99, 66], [161, 66], [173, 72], [170, 75], [90, 75]], light=.85, slope=(0, -.24)),
             face([[90, 73], [102, 67], [157, 67], [169, 73], [166, 75], [93, 75]], light=.56, slope=(.2, -.2))]
    return {'schema': 'rogue-textured-faces-1', 'canvas': [256, 128], 'density': 4,
            'materials': materials, 'faces': faces, 'rivets': [], 'geometryReferences': {},
            'intent': 'Low inner metal floor above flat backdrop foot/shadow, below unchanged native fill; clear both painted-face silhouettes.'}


def validate_source(scene_path, png_path, root):
    scene = json.loads(Path(scene_path).read_text())
    for reference in scene['geometryReferences'].values():
        path = (Path(root) / reference['path']).resolve()
        if not path.is_relative_to(Path(root).resolve()) or sha(path) != reference['sha256']:
            raise ValueError('stale construction geometry reference')
    expected = rasterize(scene, root)
    actual = Image.open(png_path).convert('RGBA')
    if expected.size != actual.size or expected.tobytes() != actual.tobytes():
        raise ValueError('authored source raster differs from declared face/material recipe')
    return {'sceneSha256': sha(scene_path), 'sourceSha256': sha(png_path), 'exactRasterReplay': True}
