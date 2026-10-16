"""Export the neutral Wildheart layer; native geometry/fills stay unchanged."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT/'Docs/Research_Assets/Druid/Wildheart-2026-10-16/veins-source.png'
TARGET = ROOT/'Assets/Druid/wildheart-veins.tga'
source = Image.open(SOURCE).convert('RGBA').resize((512,512), Image.Resampling.LANCZOS)
grey = source.convert('L')
texture = Image.merge('RGBA', (grey,grey,grey,source.getchannel('A')))
texture.save(TARGET, compression=None)
assert Image.open(TARGET).convert('RGBA').tobytes() == texture.tobytes()
manifest = {
    'source':str(SOURCE.relative_to(ROOT)).replace('\\','/'),
    'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'texture':str(TARGET.relative_to(ROOT)).replace('\\','/'),
    'sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest(),
    'canvas':[512,512], 'bytes':TARGET.stat().st_size,
    'shared':['native crystal material/mask', 'Druid/dreamlight.tga', 'Paladin/holy-sphere.tga'],
    'liveValidated':False
}
(TARGET.parent/'wildheart-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Wildheart: one neutral 512x512 layer,', TARGET.stat().st_size, 'bytes.')
