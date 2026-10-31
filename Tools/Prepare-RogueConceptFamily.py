"""Geometry-only atlas for one common painted Rogue material family.

Inputs are reference targets, never runtime exports or alpha stencils for the
new painting. Every current runtime file is hash-locked before source creation.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Concept-Family-2026-10-31'
CELLS = {'hp_cap_case-over': [128, 32, 1920, 480],
         'pw_crystal_case': [32, 544, 928, 992],
         'actionbutton-border': [992, 544, 1440, 992],
         'minimap-border': [1504, 544, 1952, 992]}
SIZE = (2048, 1152)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def main():
    (WORK / 'Sources').mkdir(parents=True, exist_ok=True)
    lock = WORK / 'input-lock.json'
    if not lock.exists():
        protected = {p.relative_to(ROOT).as_posix(): sha(p) for folder in ('Assets', 'Core', 'Layouts', 'Options')
                     for p in (ROOT / folder).rglob('*') if p.is_file()}
        lock.write_text(json.dumps(protected, indent=2) + '\n', encoding='utf-8')
    else:
        protected = json.loads(lock.read_text())
        assert all(sha(ROOT / p) == h for p, h in protected.items()), 'Concurrent runtime changes; inspect before rebuilding guides'
    import sys
    sys.path.insert(0, str(ROOT / 'Tools'))
    import PaladinFillContracts as P
    atlas = Image.new('RGBA', SIZE)
    guide = Image.new('RGBA', SIZE, '#343941')
    records = {}
    for name, box in CELLS.items():
        paint = read(ROOT / 'Assets/Rogue' / (name + '.tga'))
        if name == 'pw_crystal_case':
            paint = Image.alpha_composite(read(ROOT / 'Assets/Rogue/pw_crystal_case-seat.tga'), paint)
            fill = P.mask('pw_crystal_case', paint.size)
        else:
            field = ROOT / 'Docs/Research_Assets/Templates' / (name.removesuffix('-over') + '-fill.png')
            fill = Image.open(field).convert('L') if field.exists() else Image.new('L', paint.size)
        size = (box[2] - box[0], box[3] - box[1])
        atlas.alpha_composite(paint.resize(size, Image.Resampling.LANCZOS), tuple(box[:2]))
        grey = Image.new('RGBA', paint.size, '#747b7e')
        grey.putalpha(paint.getchannel('A'))
        grey.alpha_composite(Image.composite(Image.new('RGBA', paint.size, '#ff00bd'), Image.new('RGBA', paint.size), fill))
        guide.alpha_composite(grey.resize(size, Image.Resampling.LANCZOS), tuple(box[:2]))
        ImageDraw.Draw(guide).rectangle(box, outline='#20e9de', width=2)
        records[name] = {'cell': box, 'nativeCanvas': list(paint.size), 'referenceSha256': sha(ROOT / 'Assets/Rogue' / (name + '.tga'))}
    atlas.save(WORK / 'Sources/family-geometry-target.png')
    guide.convert('RGB').save(WORK / 'Sources/family-aperture-guide.png')
    (WORK / 'geometry-atlas.json').write_text(json.dumps({'canvas': SIZE, 'cells': records,
        'purpose': 'generation geometry references only; do not export or impose this alpha on new painting',
        'conceptSha256': sha(ROOT / 'Docs/Research_Assets/Rogue/approved-concept.png'),
        'protectedFiles': len(protected)}, indent=2) + '\n', encoding='utf-8')
    print('Four geometry references saved; installed assets unchanged.')


if __name__ == '__main__':
    main()
