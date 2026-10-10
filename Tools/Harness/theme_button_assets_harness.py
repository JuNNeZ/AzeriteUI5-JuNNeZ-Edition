"""Verify four exported borders, provenance, determinism and corner rejection.

Run: python Tools/Harness/theme_button_assets_harness.py
No live rendering evidence. Rebuild focused assets before running this harness.
"""
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'Tools'))
from ThemeButtonShapes import NAMES, border, digest, build_theme

spec = importlib.util.spec_from_file_location('style', ROOT/'Tools/Check-ThemeAssetStyle.py')
style = importlib.util.module_from_spec(spec)
spec.loader.exec_module(style)
checks = []
for theme in ('Mage', 'Hunter'):
    folder = ROOT/'Assets'/theme
    manifest = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    source = Image.open(folder/'actionbutton-border.tga').convert('RGBA')
    for name in NAMES:
        path = folder/(name+'.tga')
        im = Image.open(path).convert('RGBA')
        native = Image.open(ROOT/'Assets'/(name+'.tga')).convert('RGBA')
        assert im.size == native.size == (256, 256)
        assert im.getchannel('A').tobytes() == native.getchannel('A').tobytes()
        assert not style.check(path)[0], (theme, name, style.check(path))
        result = border(source, native)
        buffer = io.BytesIO()
        result.save(buffer, format='TGA', compression=None)
        assert buffer.getvalue() == path.read_bytes(), 'non-deterministic export'
        item = (next(x for x in manifest['assets'] if x['path'].endswith(name+'.tga'))
                if theme == 'Mage' else manifest['originals'][name])
        assert item['sha256'] == digest(path) and item['bytes'] == path.stat().st_size
        assert item['sourceSha256'] == digest(ROOT/item['source'])
        assert item['alphaSourceSha256'] == digest(ROOT/item['alphaSource'])
        pixels = np.asarray(im)
        lum = pixels[..., :3] @ np.array([.299, .587, .114])
        solid = pixels[..., 3] > 200
        assert lum[:128][solid[:128]].mean() > lum[128:][solid[128:]].mean(), 'light from below'
        painted = im.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
        deco = 93.1 if name.endswith('rounded') else 96.3
        gap = 64 - (painted[2]-painted[0])*deco/256
        assert gap > 0
        checks.append(dict(theme=theme, name=name, exactAlpha=True, deterministic=True,
                           manifest=True, styleFailures=[], solidGap64=round(gap, 3)))

# The full-Hunter-build hook adds registrations without dropping other entries.
manifest = json.loads((ROOT/'Assets/Hunter/manifest.json').read_text(encoding='utf-8'))
before = json.dumps(manifest, sort_keys=True)
mapping = {}
build_theme(ROOT, 'Hunter', manifest, mapping)
assert set(mapping) == set(NAMES) and json.dumps(manifest, sort_keys=True) == before

# Wrong corner inside the bounds: aperture/bounding-box checks cannot detect it.
with tempfile.TemporaryDirectory() as temporary:
    path = Path(temporary)/'actionbutton-border-square-rounded.tga'
    im = Image.open(ROOT/'Assets/Mage'/path.name).convert('RGBA')
    im.putpixel((49, 49), (150, 150, 150, 255))
    im.save(path)
    assert any('alpha differs' in f for f in style.check(path)[0])

report = dict(borders=checks, hunterBuildHook=True, cornerMutationRejected=True, liveValidation=False)
(ROOT/'Docs/Research_Assets/ButtonShapes/verification.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('Theme button assets: four exact-alpha/provenance/rebuild/style/light/gap checks; build hook and corner mutation pass (offline only)')
