"""Verify original Hex source replay, output hashes and shipping inventory."""
import importlib.util
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hex_builder', ROOT / 'Tools/Build-HexButtonAssets.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def same_rgba(actual, expected):
    assert actual.size == expected.size and actual.tobytes() == expected.tobytes(), 'Whole-source RGBA replay differs'


def main():
    manifest = json.loads((ROOT / 'Assets/HexButtons/provenance.json').read_text(encoding='utf-8'))
    assert manifest['thirdPartyMediaInputs'] == []
    for record in manifest['generation']['sources'].values():
        assert builder.digest(ROOT/record['path'])==record['sha256'], 'Source painting changed'
        assert builder.digest(ROOT/record['prompt'])==record['promptSha256'], 'Exact prompt changed'
        for reference in record['inputImages']:
            assert builder.digest(ROOT / reference['path']) == reference['sha256'], 'Edit/material reference changed'
    assert not (ROOT / 'Assets/HexButtons/Masque_Azerite_Hex-LICENSE.txt').exists(), 'Retired third-party import is still shipping'
    assert builder.digest(builder.DEFAULT_SOURCE) == manifest['generation']['sources']['Stock']['sha256']
    original = Image.open(builder.DEFAULT_SOURCE).convert('RGBA')
    registered = builder.register(original)
    exported = Image.open(ROOT / 'Assets/actionbutton-border-hex.tga').convert('RGBA')
    same_rgba(exported, registered)
    # Both regressions keep the canvas and almost all geometry intact.
    x, y = next((x, y) for y in range(256) for x in range(256) if exported.getpixel((x, y))[3] == 255)
    for replacement in ((0, 0, 0, 0), (255, 0, 255, 255)):
        broken = exported.copy(); broken.putpixel((x, y), replacement)
        try:
            same_rgba(broken, registered)
        except AssertionError:
            pass
        else:
            raise AssertionError('Negative source-replay control unexpectedly passed')
    for name, item in manifest['assets'].items():
        path = ROOT / 'Assets' / name
        assert builder.digest(path) == item['sha256'], name + ' hash drift'
        assert path.read_bytes()[2] == 2, name + ' must be uncompressed TGA'
        assert Image.open(path).size in ((128, 128), (256, 256)), name + ' invalid canvas'
    geometry={'Stock':builder.measure(exported)}
    for theme,item in manifest['classBorders'].items():
        assert builder.digest(ROOT / item['path']) == item['sha256'], 'Existing class painting changed'
        source = Image.open(ROOT / item['path']).convert('RGBA')
        expected, transform = builder.register_class(source)
        assert transform == item['transform'], 'Class registration transform changed'
        output = Image.open(ROOT / 'Assets' / item['export']).convert('RGBA')
        same_rgba(output, expected)
        geometry[theme]=builder.measure(output)
        box = output.getchannel('A').point(lambda a:255 if a>200 else 0).getbbox()
        assert abs((box[3]-box[1])*96/256-70.5) <= .75, 'Class solid height differs from reference'
        assert max(box[2]-box[0],box[3]-box[1])*96/256 <= 72, 'Class casing exceeds default 64+8 cell pitch'
    mask = Image.open(ROOT / 'Assets/actionbutton-mask-hex.tga').convert('RGBA')
    assert mask.getpixel((64, 64))[3] == 255 and mask.getpixel((0, 0))[3] == 0
    assert exported.getpixel((128, 128))[3] == 0, 'Painted opening is not transparent'
    solid = exported.getchannel('A').point(lambda a: 255 if a > 200 else 0).getbbox()
    # Reference HEX solid height is 188/256 * 96 = 70.5px. The existing 64px
    # cells have 8px padding; artwork may occupy that gutter without moving cells.
    assert abs((solid[3] - solid[1]) * 96 / 256 - 70.5) < .5, 'Solid border differs from Masque reference height'
    mask_bounds = mask.getchannel('A').point(lambda a: 255 if a > 200 else 0).getbbox()
    assert mask_bounds == (12, 5, 116, 123), 'Procedural mask differs from reference visible dimensions'
    builder.validate(geometry)
    assert geometry==manifest['geometry'], 'Measured border geometry drift'
    # Real old varying-width/glass-containing portraits must fail the new gate.
    from HexButtonGeometry import register as whole_register,measure
    rejected=0
    for theme in ('Hunter','Paladin','Rogue','Shaman'):
        previous=Image.open(ROOT/f'Assets/{theme}/portrait_frame_hi.tga').convert('RGBA')
        try:
            fixture=measure(whole_register(previous)[0])
            builder.validate({'previous-'+theme:fixture, 'Stock':geometry['Stock']})
        except AssertionError:
            rejected+=1
    assert rejected==4, 'Old width/aperture fixtures unexpectedly accepted'
    print('Original Hex: 8 source replays, 17 output hashes/formats, common thickness/aperture measurements and 6 negative controls pass (offline only)')


if __name__ == '__main__':
    main()
