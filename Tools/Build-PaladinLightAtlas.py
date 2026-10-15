"""Export the shared Paladin Light sheet; no repainting or per-frame effects.

python Tools/Build-PaladinLightAtlas.py
The built-in image generator's original 8x8 sheet is retained alongside its
prompt. Resize the complete regular grid to 1024 square and convert to TGA.
Core/PaladinTheme.lua samples 64 cells over 32 seconds with crossfade; separate
foreground sphere sprites drift and pulse on an independent 48-second period.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'Docs/Research_Assets/Paladin/HolyLight-2026-10-15'
TARGET = ROOT / 'Assets/Paladin/holy-energy.tga'


def preview(atlas, sphere):
    """Isolated effect preview using real native masks, not a WoW screenshot."""
    import numpy as np
    from PIL import ImageDraw

    names = [('Crystal', 'power_crystal_front'), ('Orb', 'orb2')]
    materials = [np.asarray(Image.open(ROOT / ('Assets/'+name+'.tga')).convert('RGBA')
                            .resize((160, 160), Image.Resampling.LANCZOS), dtype=float)
                 for _, name in names]
    cells = [atlas.crop(((i%8)*128, (i//8)*128, (i%8+1)*128, (i//8+1)*128))
             .convert('RGB').resize((160, 160), Image.Resampling.BILINEAR) for i in range(64)]
    frames = []
    # Both layers return continuously at 96s (3 wave loops, 2 sphere orbits).
    for tick in range(768):
        seconds = tick/8
        phase = (seconds*2)%64
        index, blend = int(phase), phase % 1
        energy = (np.asarray(cells[index], dtype=float)*(1-blend)
                  + np.asarray(cells[(index+1)%64], dtype=float)*blend)*.65
        sphere_phase = (seconds%48)*np.pi*2/48
        for i in range(1, 7):
            seed = i*2.399963
            x = .5+.26*np.sin(sphere_phase+seed)+.08*np.sin(2*sphere_phase-seed)
            y = .5+.30*np.cos(sphere_phase+seed*.7)+.08*np.sin(2*sphere_phase+seed)
            pulse = .5+.5*np.sin(sphere_phase*(6+i)+seed)
            size = max(1, round(160*(.055+.01*(i%3))*(.85+.3*pulse)))
            art = np.asarray(sphere.resize((size, size), Image.Resampling.LANCZOS), dtype=float)
            x0, y0 = round(x*160-size/2), round((1-y)*160-size/2)
            light = art[:, :, :3]*np.array([1, .84, .35])*(art[:, :, 3:]/255)*(.32+.38*pulse*pulse)
            energy[y0:y0+size, x0:x0+size] += light
        canvas = Image.new('RGB', (620, 426), (18, 20, 25))
        draw = ImageDraw.Draw(canvas)
        draw.text((14, 10), 'OFFLINE EFFECT PREVIEW - native masks; casings omitted', fill='white')
        for row, (label, _) in enumerate(names):
            material = materials[row]
            alpha = material[:, :, 3:]/255
            for col, fraction in enumerate((1, .5, .15)):
                y0 = round(160*(1-fraction))
                rgba = np.zeros((160, 160, 4), dtype=np.uint8)
                rgba[y0:, :, :3] = np.clip(material[y0:, :, :3]*.45+energy[y0:], 0, 255)
                rgba[y0:, :, 3:] = np.asarray(alpha[y0:]*255, dtype=np.uint8)
                tile = Image.fromarray(rgba, 'RGBA')
                x, y = 32+col*200, 56+row*184
                canvas.paste(tile, (x, y), tile)
                draw.text((x, y-18), label+' '+str(round(fraction*100))+'%', fill='white')
        if tick == 0:
            canvas.save(SOURCE / 'preview.png')
        frames.append(canvas.quantize(colors=128))
    # GIF's 10ms clock alternates 120/130ms for a true 96-second preview.
    frames[0].save(SOURCE / 'preview.gif', save_all=True, append_images=frames[1:],
                   duration=[120, 130]*384, loop=0, disposal=2)


def main():
    source = SOURCE / 'generated-sheet-waves.png'
    sphere_source = SOURCE / 'generated-sphere.png'
    with Image.open(source) as image:
        assert image.width == image.height, 'expected square 8x8 source sheet'
        atlas = image.convert('RGBA').resize((1024, 1024), Image.Resampling.LANCZOS)
    atlas.save(TARGET)
    sphere = Image.open(sphere_source).convert('RGBA').resize((64, 64), Image.Resampling.LANCZOS)
    sphere_target = ROOT / 'Assets/Paladin/holy-sphere.tga'
    sphere.save(sphere_target)
    alpha_min, alpha_max = sphere.getchannel('A').getextrema()
    assert alpha_min == 0 and alpha_max >= 240, 'sphere needs clear padding and a near-opaque core'
    with Image.open(sphere_target) as exported_sphere:
        assert exported_sphere.tobytes() == sphere.tobytes(), 'sphere TGA changed pixels'
    with Image.open(TARGET) as exported:
        assert exported.size == (1024, 1024) and exported.mode == 'RGBA'
        assert exported.tobytes() == atlas.tobytes(), 'TGA conversion changed pixels'
    metadata = {
        'generator': 'built-in image_gen', 'source': source.name,
        'prompt': 'prompt-waves.txt',
        'artDirection': 'slow golden light waves and winding threads, with independent pulsing floating spheres above',
        'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'atlas': 'Assets/Paladin/holy-energy.tga',
        'atlasSha256': hashlib.sha256(TARGET.read_bytes()).hexdigest(),
        'columns': 8, 'rows': 8, 'frames': 64, 'cell': 128,
        'fps': 2, 'loopSeconds': 32, 'sampling': 'half-texel inset, adjacent-frame crossfade',
        'sphere': {'source': sphere_source.name, 'prompt': 'prompt-sphere.txt',
                   'sourceSha256': hashlib.sha256(sphere_source.read_bytes()).hexdigest(),
                   'atlas': 'Assets/Paladin/holy-sphere.tga', 'size': [64, 64],
                   'sha256': hashlib.sha256(sphere_target.read_bytes()).hexdigest(),
                   'count': 6, 'driftSeconds': 48, 'tint': [1, .84, .35]},
        'processing': 'whole-sheet resize and RGBA TGA conversion only; black additive background',
        'consumers': ['Paladin crystal effect', 'Paladin orb effect'],
        'validation': 'offline only; Retail and Forever rendering require reload tests',
    }
    (SOURCE / 'atlas.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
    preview(atlas, sphere)
    print('Paladin Light: 64 frames, 32-second waves, separate 48-second drifting/pulsing spheres; TGA round-trip passed.')


if __name__ == '__main__':
    main()
