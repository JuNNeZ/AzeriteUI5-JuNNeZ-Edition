"""Offline atlas feasibility experiment; never changes runtime assets.

Run: python Tools/Test-AssetAtlases.py
Outputs go to Docs/Research_Assets/AtlasExperiment (excluded from releases).
"""
from pathlib import Path
from collections import defaultdict
from io import BytesIO
import hashlib
import json
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Docs/Research_Assets/AtlasExperiment'


def zip_size(files):
    stream = BytesIO()
    with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in files:
            z.writestr(name, data)
    return len(stream.getvalue())


def tga_bytes(image):
    stream = BytesIO()
    image.save(stream, format='TGA', compression=None)
    return stream.getvalue()


def pack(items):
    # Deterministic free-rectangle packing, 2px gutters, POT pages <=2048.
    best = None
    for width in (256, 512, 1024, 2048):
        for height in (256, 512, 1024, 2048):
            positions = []
            free = [(0, 0, width, height)]
            for name, image, box in sorted(items, key=lambda v: (-v[1].width*v[1].height, v[0])):
                w, h = image.width + 4, image.height + 4
                candidates = [r for r in free if r[2]-r[0] >= w and r[3]-r[1] >= h]
                if not candidates:
                    break
                x, y, _, _ = min(candidates, key=lambda r: (min(r[2]-r[0]-w, r[3]-r[1]-h), r[1], r[0]))
                split = []
                for l, t, r, b in free:
                    if x >= r or x+w <= l or y >= b or y+h <= t:
                        split.append((l,t,r,b))
                        continue
                    if l < x: split.append((l,t,x,b))
                    if r > x+w: split.append((x+w,t,r,b))
                    if t < y: split.append((l,t,r,y))
                    if b > y+h: split.append((l,y+h,r,b))
                unique = list(dict.fromkeys(split))
                free = [a for a in unique if not any(a != b and b[0] <= a[0] and b[1] <= a[1] and b[2] >= a[2] and b[3] >= a[3] for b in unique)]
                positions.append((name,image,box,x+2,y+2))
            else:
                if best is None or width * height < best[0] * best[1]:
                    best = width, height, positions
    if best is None:
        raise ValueError('group needs multiple pages')
    width, height, positions = best
    page = Image.new('RGBA', (width, height))
    entries = {}
    for name, image, box, x, y in positions:
        w, h = image.size
        page.paste(image, (x, y))
        # Extrude edge pixels rather than letting bilinear filtering see neighbours.
        for delta in (1, 2):
            page.paste(image.crop((0, 0, w, 1)), (x, y - delta))
            page.paste(image.crop((0, h - 1, w, h)), (x, y + h - 1 + delta))
            page.paste(image.crop((0, 0, 1, h)), (x - delta, y))
            page.paste(image.crop((w - 1, 0, w, h)), (x + w - 1 + delta, y))
        for dx in (-2, -1, w, w + 1):
            for dy in (-2, -1, h, h + 1):
                page.putpixel((x + dx, y + dy), image.getpixel((0 if dx < 0 else w - 1, 0 if dy < 0 else h - 1)))
        entries[name] = dict(rect=[x, y, x+w, y+h], crop=list(box),
                             uv=[x/width, (x+w)/width, y/height, (y+h)/height])
    return page, entries


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    folders = defaultdict(lambda: [0, 0])
    hashes = defaultdict(list)
    textures = []
    all_bytes = 0
    for path in sorted((ROOT / 'Assets').rglob('*')):
        if not path.is_file():
            continue
        size = path.stat().st_size
        all_bytes += size
        folders[path.parent.relative_to(ROOT).as_posix()][0] += size
        folders[path.parent.relative_to(ROOT).as_posix()][1] += 1
        if path.suffix.lower() in ('.tga', '.blp'):
            data = path.read_bytes()
            hashes[hashlib.sha256(data).hexdigest()].append((path.relative_to(ROOT).as_posix(), size))
            with Image.open(path) as im:
                textures.append(dict(path=path.relative_to(ROOT).as_posix(), bytes=size,
                                     size=list(im.size), mode=im.mode))
    groups = {
        'proc': sorted((ROOT / 'Assets').glob('actionbutton-proc-*.tga')),
        'mage-borders': sorted((ROOT / 'Assets/Mage').glob('actionbutton-border*.tga')),
        'hunter-borders': sorted((ROOT / 'Assets/Hunter').glob('actionbutton-border*.tga')),
    }
    # Native decorative casings: large transparent canvases are a contrasting example.
    groups['native-health-cases'] = sorted((ROOT / 'Assets').glob('hp_*case*.tga'))[:8]
    groups['combined-themed-borders'] = groups['mage-borders'] + groups['hunter-borders']
    groups['paladin-health'] = sorted((ROOT / 'Assets/Paladin').glob('health*.tga'))
    results = []
    checks = 0
    for group, paths in groups.items():
        if not paths:
            continue
        source = [(p.relative_to(ROOT).as_posix(), p.read_bytes()) for p in paths]
        originals = {name: Image.open(BytesIO(data)).convert('RGBA') for name, data in source}
        before = sum(len(data) for _, data in source)
        for trim in (False, True):
            items = []
            for name, image in originals.items():
                box = image.getchannel('A').getbbox() if trim else (0, 0, *image.size)
                box = box or (0, 0, 1, 1)
                # Keep 2 transparent pixels around artwork where the canvas permits.
                if trim:
                    l, t, r, b = box
                    box = max(0,l-2), max(0,t-2), min(image.width,r+2), min(image.height,b+2)
                items.append((name, image.crop(box), box))
            label = group + ('-trimmed' if trim else '-full')
            try:
                page, entries = pack(items)
            except ValueError:
                results.append(dict(group=label, skipped='needs multiple pages'))
                continue
            payload = tga_bytes(page)
            (OUT / (label + '.tga')).write_bytes(payload)
            with Image.open(BytesIO(payload)) as decoded:
                for name, entry in entries.items():
                    original = originals[name]
                    cell = decoded.crop(entry['rect']).convert('RGBA')
                    assert cell.tobytes() == original.crop(entry['crop']).tobytes(), name
                    restored = Image.new('RGBA', original.size)
                    restored.paste(cell, tuple(entry['crop'][:2]))
                    assert restored.getchannel('A').tobytes() == original.getchannel('A').tobytes(), name
                    # RGB of alpha-zero pixels outside the crop can legitimately differ.
                    ref = original.copy()
                    for bg in ((18,18,18,255), (128,128,128,255)):
                        assert Image.alpha_composite(Image.new('RGBA', original.size, bg), ref).tobytes() == Image.alpha_composite(Image.new('RGBA', original.size, bg), restored).tobytes(), name
                    checks += 4
                    entry['originalSize'] = list(original.size)
            metadata = json.dumps(entries, indent=2).encode()
            (OUT / (label + '.json')).write_bytes(metadata)
            after = len(payload) + len(metadata)
            results.append(dict(group=label, count=len(paths), page=list(page.size),
                                beforeBytes=before, afterBytes=after,
                                savingPercent=round((1-after/before)*100,2),
                                zipBefore=zip_size(source),
                                zipAfter=zip_size([(label+'.tga',payload), (label+'.json',metadata)])))
            if group == 'proc' and trim:
                bg = Image.new('RGBA', page.size, (28,28,28,255))
                Image.alpha_composite(bg,page).convert('RGB').save(OUT / 'proc-preview.png')
    duplicates = [v for v in hashes.values() if len(v) > 1]
    report = dict(assetBytes=all_bytes, textureBytes=sum(t['bytes'] for t in textures),
                  textureCount=len(textures), folders=dict(folders),
                  largest=sorted(textures,key=lambda t:-t['bytes'])[:20],
                  duplicates=duplicates,
                  duplicateBytes=sum(sum(s for _,s in group[1:]) for group in duplicates),
                  results=results, pixelChecks=checks)
    (OUT / 'results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    # Standalone opt-in client test, distributed as a ZIP, never added to our TOCs.
    entries = json.loads((OUT / 'proc-trimmed.json').read_text())
    rows = []
    for name, entry in entries.items():
        rows.append('{ name = "%s", uv = { %s }, crop = { %s } }' % (
            Path(name).stem, ', '.join(map(str,entry['uv'])), ', '.join(map(str,entry['crop']))))
    template = (ROOT / 'Tools/AssetAtlasSmoke.lua').read_text(encoding='utf-8')
    lua = template.replace('-- GENERATED_ROWS', ',\n'.join(rows))
    (OUT / 'AtlasSmoke.generated.lua').write_text(lua,encoding='utf-8')
    toc = '## Interface: 120100, 120105\n## Title: AzeriteUI Atlas Smoke Test\n## Notes: Optional original versus atlas comparison; /azatlastest\nAtlasSmoke.lua\n'
    with zipfile.ZipFile(OUT / 'AzeriteUI_AtlasSmoke.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        z.writestr('AzeriteUI_AtlasSmoke/AzeriteUI_AtlasSmoke.toc',toc)
        z.writestr('AzeriteUI_AtlasSmoke/AzeriteUI_AtlasSmoke_Camelot.toc',toc.replace('120100, 120105','16001'))
        z.writestr('AzeriteUI_AtlasSmoke/AtlasSmoke.lua',lua)
        z.writestr('AzeriteUI_AtlasSmoke/proc-trimmed.tga',(OUT / 'proc-trimmed.tga').read_bytes())
        for name,data in [(p.name,p.read_bytes()) for p in groups['proc']]:
            z.writestr('AzeriteUI_AtlasSmoke/'+name,data)
    print(json.dumps({k:v for k,v in report.items() if k not in ('duplicates', 'folders')},indent=2))


if __name__ == '__main__':
    main()
