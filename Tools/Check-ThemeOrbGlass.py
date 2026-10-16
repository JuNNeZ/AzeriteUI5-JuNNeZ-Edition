"""Independent installed orb lighting checks and adversarial specular mutants.

python Tools/Check-ThemeOrbGlass.py
Checks on-disk art, not WoW client rendering or user-selected extra glass layers.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import tempfile
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/OrbGlass-2026-10-16'
THEMES = ('Hunter', 'Mage', 'Paladin', 'Druid')
NAMES = ('orb_case_hi', 'orb_case_low')
colors = (ROOT/'Core/Common/Colors.lua').read_text()
tint = float(re.search(r'Colors\.ui = createColor\((\d+)/255', colors)[1])/255


def expected_glass(name):
    native = np.array(Image.open(ROOT/'Assets'/(name+'.tga')).convert('RGBA'))
    mask = np.array(Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')) > 0
    expected = native.copy()
    expected[mask, :3] = np.rint(native[mask, :3].astype(float)*tint).astype('uint8')
    return expected, mask


def validate(pixels, name):
    expected, mask = expected_glass(name)
    assert pixels.shape == expected.shape, 'native canvas'
    assert np.array_equal(pixels[mask], expected[mask]), 'native rendered glass/specular'


def hashes(data):
    if isinstance(data, dict):
        for key, value in data.items():
            if key == 'sha256':
                yield value
            else:
                yield from hashes(value)
    elif isinstance(data, list):
        for value in data:
            yield from hashes(value)


checked = 0
for theme in THEMES:
    folder = ROOT/'Assets'/theme
    manifest_hashes = set(hashes(json.loads((folder/'manifest.json').read_text())))
    for name in NAMES:
        target = folder/(name+'.tga')
        pixels = np.array(Image.open(target).convert('RGBA'))
        validate(pixels, name)
        assert hashlib.sha256(target.read_bytes()).hexdigest() in manifest_hashes, theme+' manifest hash'
        before = np.array(Image.open(WORK/('Assets-'+theme+'-'+name+'.tga')).convert('RGBA'))
        _, mask = expected_glass(name)
        assert np.array_equal(pixels[~mask], before[~mask]), theme+' casing outside glass changed'
        if theme != 'Hunter':
            assert np.array_equal(pixels[:, :, 3], before[:, :, 3]), theme+' alpha changed'
        checked += 1

# Rebuilding Druid and Paladin must invoke the real export path, not merely
# repair an already-installed file. Temp outputs cannot touch other artwork.
for filename, function in [('Build-DruidArt.py', 'casing'), ('Build-PaladinDropIn.py', 'export_casing')]:
    spec = importlib.util.spec_from_file_location('orb_builder', ROOT/'Tools'/filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.TemporaryDirectory() as temp:
        outputs = {}
        def capture(name, image):
            outputs[name] = np.array(image)
        if function == 'casing':
            # Keep the real save_texture implementation, which owns glass.
            module.WORK = Path(temp)
            (module.WORK/'Sources').mkdir()
            for name in NAMES:
                source = ROOT/'Docs/Research_Assets/Druid/HD/Sources/orb_case_hi.png'
                (module.WORK/'Sources/orb_case_hi.png').write_bytes(source.read_bytes())
                module.casing(name)
                validate(np.array(Image.open(module.WORK/'Export'/(name+'.tga')).convert('RGBA')), name)
        else:
            module.save = capture
            for name in NAMES:
                module.export_casing(name)
                validate(outputs[name], name)

rejected = []
base, mask = expected_glass('orb_case_hi')
native = np.array(Image.open(ROOT/'Assets/orb_case_hi.tga').convert('RGBA'))
specular = mask & (native[:, :, :3].min(2)>230) & (native[:, :, 3]>200)
assert specular.sum()>30, 'test must include opaque reflection pixels'
for label in ('black highlight', 'raw overbright glass', 'missing glass alpha'):
    bad = base.copy()
    if label == 'black highlight': bad[specular, :3] = 0
    elif label == 'raw overbright glass': bad[mask, :3] = native[mask, :3]
    else: bad[mask, 3] = 0
    try:
        validate(bad, 'orb_case_hi')
    except AssertionError:
        rejected.append(label)
    else:
        raise AssertionError('surviving mutant: '+label)
print(json.dumps({'installedOrbs':checked, 'nativeTint':tint, 'buildersChecked':['Druid','Paladin'],
                  'mutationsRejected':rejected, 'outsideGlassUnchanged':True, 'liveValidated':False}, indent=2))
