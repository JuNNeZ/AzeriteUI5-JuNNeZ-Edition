"""Build the approved Warrior asset pack. No runtime theme/layout is installed.

python Tools/Build-WarriorAssets.py
Outputs Assets_Draft/Warrior, source hashes, geometry results and native-layout reviews.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from ThemeHealthEndcaps import align
from ThemeOrbGlass import restore_glass
from ThemeButtonShapes import border as shaped_border
from PaladinFillContracts import clearance_mask

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/Warrior'
SOURCE = WORK/'Sources'
OUT = ROOT/'Assets_Draft/Warrior'
SPEC = json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
S = Image.Resampling.LANCZOS
HEALTH = ('hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case')
CAPS = ('stromkar', 'warswords', 'wrath')
CAP_SOURCES = {'stromkar':'ornament-stromkar-terminal-fit-v4.png',
               'warswords':'ornament-warswords-terminal-fit-v2.png',
               'wrath':'ornament-wrath-terminal-fit-v3.png'}
# One rigid whole-painting orientation for all four Strom'kar tiers. No skew,
# per-axis scaling or runtime offsets; the single toe is measured afterwards.
CAP_ROTATIONS = {'stromkar':12}
TERMINAL_CONTRACT = 'Frozen full ending mask from first descending dip edge through upper point/outer tip; zero exposed metal beyond one source-pixel contour AA; independent visual review required'
REJECTED_SOURCES = {'ornament-warswords.png':'competing lower blade tips',
                    'ornament-wrath.png':'competing lower blade tips'}
REJECTED_SOURCES.update({name:'toe-only fit is insufficient; full casing terminal remains exposed' for name in (
    'ornament-stromkar.png','ornament-warswords-v2.png','ornament-wrath-v2.png',
    'ornament-stromkar-terminal-fit.png','ornament-warswords-terminal-fit.png','ornament-wrath-terminal-fit.png',
    'ornament-stromkar-terminal-fit-v2.png','ornament-wrath-terminal-fit-v2.png',
    'ornament-stromkar-terminal-fit-v3.png')})
SHARED = {'nameplate_backdrop': 'shared neutral backing without an ornamental border',
          'minimap-onebar-backdrop': 'shared functional XP/status ring',
          'minimap-twobars-backdrop': 'shared functional XP/status ring',
          'options-box': 'shared options-control opening and state art'}
ALIASES = {'hp_critter_case': 'hp_critter_case_hi', 'cast_back_spiked': 'cast_back',
           'cast_back_wooden': 'cast_back', 'pw_crystal_case_low': 'pw_crystal_case',
           'orb_case_low': 'orb_case_hi', 'orb-border': 'minimap-border',
           'portrait_frame_lo': 'portrait_frame_hi', 'config_button_bright': 'config_button',
           'border-aura': 'border-tooltip', 'better-blizzard-border-small-alternate': 'border-tooltip'}


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Tools'/filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


D = module('warrior_registration', 'Build-DruidArt.py')
H = module('warrior_health_rails', 'Build-RebuiltHealthArt.py')
C = module('warrior_style', 'Check-ThemeAssetStyle.py')


def read(path):
    return Image.open(path).convert('RGBA')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def save(name, image, records):
    path = OUT/(name+'.tga')
    image.save(path, compression=None)
    assert read(path).tobytes() == image.tobytes()
    records[name] = {'path': path.relative_to(ROOT).as_posix(), 'canvas': list(image.size), 'sha256': sha(path)}


def atlas(source, native):
    result = Image.new('RGBA', native.size)
    fits = []
    for i in range(8):
        cell = native.crop((i*native.height, 0, (i+1)*native.height, native.height))
        if i < 4:
            piece = source.crop((round(i*source.width/8),0,round((i+1)*source.width/8),source.height))
        else:
            # Generator retains four strips but places its four intact Ls in
            # a two-by-two block in the right half. Extract those objects, not
            # arbitrary eighths that mix a corner with its neighbour's arm.
            col, row = (i-4)%2, (i-4)//2
            piece = source.crop((round(source.width*(.5+col*.25)),round(source.height*row*.5),
                                 round(source.width*(.75+col*.25)),round(source.height*(row+1)*.5)))
            piece = piece.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            piece = piece.crop(H.bounds(piece))
            box = H.bounds(cell)
            factor = (box[3]-box[1])/piece.height
            piece = piece.resize((round(piece.width*factor),box[3]-box[1]),S)
            width = box[2]-box[0]
            if piece.width>width:
                left = 0 if col==0 else piece.width-width
                piece = piece.crop((left,0,left+width,piece.height))
        painted, fit = D.register_material(piece, cell)
        result.paste(painted, (i*native.height, 0))
        fits.append(fit)
    return result, {'cells': fits, 'policy': 'four strips and four whole L corners extracted from source; native orientation and exact cell alpha'}


def ordinary(name, records):
    native = read(ROOT/'Assets'/(name+'.tga'))
    key = ALIASES.get(name, name)
    source = read(SOURCE/(key+'.png'))
    if name.startswith('cast_back'):
        # Fit the rail height and shorten plain straight runs. Width-only
        # containment leaves unpainted strips along the native top/bottom lip.
        source = D.modular_cast(source, native)
    if name.startswith(('border-', 'better-')):
        image, fit = atlas(source, native)
    else:
        image, fit = D.register_material(source, native)
    p, n = np.array(image), np.asarray(native)
    if name.startswith('cast_back') or name.startswith('hp_critter'):
        inside = np.asarray(clearance_mask(name, native.size)) > 0
        # Functional empty-bar shading is shared; no coloured detail behind fill.
        p[inside] = n[inside]
        image = Image.fromarray(p)
        front = p.copy()
        front[inside, 3] = 0
        glass = inside & (n[:, :, 3] > 0) & (n[:, :, 3] <= 200)
        front[glass] = n[glass]
        save(name+'-over', Image.fromarray(front), records)
    else:
        inner = np.asarray(D.closed_hole(native)) > 0
        mask = ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')
        if mask.exists():
            inner |= np.asarray(Image.open(mask).convert('L')) > 0
        # Native glass/highlights are functional layers, not casing material.
        glass = inner & (n[:, :, 3] <= 200)
        p[glass] = n[glass]
        if name == 'icon_exit_flight':
            glyph = (n[:, :, 0].astype(float) > n[:, :, 1]*1.4) & (n[:, :, 0] > 45)
            p[glyph] = n[glyph]
        if name.startswith('config_button'):
            rgb = n[:, :, :3].astype(float)
            glyph = (rgb.max(2)-rgb.min(2) > 12) & (rgb.max(2) > 60)
            p[glyph] = n[glyph]
        image = restore_glass(Image.fromarray(p), ROOT, name)
    save(name, image, records)
    return {'source': key+'.png', 'registration': fit}


def resource_halos(records):
    contracts = {}
    for low,tier in ((False,'Seasoned'),(True,'Novice')):
        db = dict(D.LAYOUTS['PlayerFrame'])
        db.update(db[tier])
        bar,case = D.crystal_rects(db)
        # Match native resource texel density with a half-resource margin on
        # every side; the cradle can extend below the fill's own draw frame.
        padded = (-bar[2]/2,-bar[3]/2,bar[2]*2,bar[3]*2)
        holder = read(OUT/('pw_crystal_case'+('_low' if low else '')+'.tga'))
        holder_alpha = D.project(holder.getchannel('A'),case,padded,(512,512))
        for wrath,field in ((False,'PowerBarTexture'),(True,'PowerBarTextureWrath')):
            fill_alpha = D.project(D.alpha(db[field]),bar,padded,(512,512))
            whole = Image.new('RGBA',(512,512),'white')
            whole.putalpha(Image.fromarray(np.maximum(np.asarray(holder_alpha),np.asarray(fill_alpha))))
            name = 'crystal-assembly'+('-low' if low else '')+('-wrath' if wrath else '')+'-glow'
            save(name,H.halo(whole),records)
            contracts[name] = {'drawRect':list(padded),'nativeResourceRect':list(bar),'holderRect':list(case),'canvas':[512,512],
                               'nativeFill':db[field],'silhouette':'whole native crystal plus Warrior cradle'}
    return contracts


def fitted_cap(key, name, front, mask):
    """Choose a rigid whole-art fit satisfying toe AND complete terminal coverage."""
    source = read(SOURCE/CAP_SOURCES[key])
    degrees = CAP_ROTATIONS.get(key,0)
    if degrees:
        source = source.rotate(degrees,resample=Image.Resampling.BICUBIC,expand=True)
    failures = []
    for height in range(120 if name in ('hp_cap_case','hp_boss_case') else 110,189):
        try:
            cap,fit=align(source,front,height,mask)
            return cap,dict(fit,sourceRotationDegrees=degrees)
        except (AssertionError,ValueError) as error:
            failures.append(str(error))
    raise ValueError(key+'/'+name+' has no complete-terminal fit: '+failures[-1])


def repair_endcaps():
    manifest = json.loads((OUT/'manifest.json').read_text())
    protected = json.loads((WORK/'protected-files.json').read_text())
    assert all(sha(ROOT/p)==h for p,h in protected.items()), 'protected source changed'
    mask_lock = json.loads((WORK/'Terminal-Repair/mask-lock.json').read_text())
    pending, joins = {}, []
    # Validate every variant/tier before writing any export. A failed new source
    # cannot leave half of the prior pack replaced.
    for name in HEALTH:
        lock = mask_lock[name]
        assert sha(OUT/(name+'-over.tga'))==lock['casingSha256'], 'bare casing changed'
        assert sha(ROOT/lock['path'])==lock['sha256'], 'frozen terminal mask changed'
        front = read(OUT/(name+'-over.tga'))
        mask = Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')
        for key in CAPS:
            cap, fit = fitted_cap(key,name,front,mask)
            pending['ornament-'+key+'-'+name] = cap
            pending['ornament-'+key+'-'+name+'-glow'] = H.halo(cap)
            joins.append(dict(choice=key,case=name,**fit))
    for name,image in pending.items():
        save(name,image,manifest['assets'])
    manifest['healthEndcaps'] = joins
    manifest['acceptedHealthSources'] = CAP_SOURCES
    manifest['status'] = 'Staged asset pack; complete terminal coverage repair; runtime/live checks pending'
    for path in sorted(SOURCE.glob('*.png')):
        manifest['sources'][path.name] = {'sha256':sha(path),'canvas':list(Image.open(path).size)}
    for metadata in sorted(SOURCE.glob('*.json')):
        manifest['generationProvenance'][metadata.stem] = json.loads(metadata.read_text(encoding='utf-8'))
    manifest['terminalContract'] = TERMINAL_CONTRACT
    manifest['rejectedSources'] = REJECTED_SOURCES
    for name in pending:
        fails,notes = C.check(OUT/(name+'.tga'))
        assert not fails,(name,fails)
        manifest['checks'][name] = {'failures':fails,'lookNotes':notes}
    write_json(OUT/'manifest.json',manifest)
    write_json(WORK/'Terminal-Repair/fit-results.json',{'registrations':joins,'runtimeInstalled':False,'liveValidated':False})
    write_json(WORK/'verification.json', {
        'assetManifestSha256':sha(OUT/'manifest.json'),
        'geometryFailures':{n:c['failures'] for n,c in manifest['checks'].items() if c['failures']},
        'textureCount':len(manifest['assets']),'healthRegistrations':len(joins),
        'maxDipError':max(j['maxNativePixelError'] for j in joins),
        'maxExposedTerminalPixelsBeyondAA':max(j['exposedTerminalPixelsBeyondAA'] for j in joins),
        'protectedFiles':len(protected),'runtimeInstalled':False,'liveValidated':False,
        'visualAcceptance':'Separate current exported-assembly review required'})
    print(json.dumps({'updatedTextures':len(pending),'registrations':len(joins),
                      'maxExposedTerminalPixels':max(j['exposedTerminalPixelsBeyondAA'] for j in joins)},indent=2))


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    # Protect every existing theme, native texture and runtime/layout file.
    protected_paths = [p for p in (ROOT/'Assets').rglob('*') if p.is_file() and OUT not in p.parents]
    protected_paths += [p for folder in ('Core', 'Layouts', 'Options') for p in (ROOT/folder).rglob('*.lua')]
    lock_path = WORK/'protected-files.json'
    protected = {p.relative_to(ROOT).as_posix(): sha(p) for p in protected_paths}
    if lock_path.exists():
        assert protected == json.loads(lock_path.read_text()), 'protected artwork/runtime changed'
    else:
        write_json(lock_path, protected)
    records, casings, joins = {}, {}, []
    H.SOURCES = SOURCE
    # Existing modular rail exporter preserves whole end paintings and varies
    # only straight rail runs; this alias is byte-identical to the source.
    shutil.copyfile(SOURCE/'hp_cap_case.png', SOURCE/'Warrior-health-fit.png')
    for name in HEALTH:
        back, front = H.rails('Warrior', name)
        shadow = Image.new('RGBA', back.size)
        shadow.putalpha(back.getchannel('A').filter(ImageFilter.GaussianBlur(7)).point(lambda a: round(a*.38)))
        back = Image.alpha_composite(shadow, back)
        save(name, back, records)
        save(name+'-over', front, records)
        save(name+'-glow', H.halo(front), records)
        casings[name] = {'source': 'hp_cap_case.png', 'construction': 'uniform source height; modular straight rail runs; complete bare dip'}
        mask = Image.open(ROOT/'Docs/Research_Assets/Templates'/(name+'-fill.png')).convert('L')
        for key in CAPS:
            cap, fit = fitted_cap(key,name,front,mask)
            for suffix, im in (('', cap), ('-glow', H.halo(cap))):
                save('ornament-'+key+'-'+name+suffix, im, records)
            joins.append(dict(choice=key, case=name, **fit))
    for name in SPEC:
        if name in SHARED or name in HEALTH or name.startswith('actionbutton-border-'):
            continue
        casings[name] = ordinary(name, records)
    ring = read(OUT/'actionbutton-border.tga')
    for name in ('actionbutton-border-square', 'actionbutton-border-square-rounded'):
        native = read(ROOT/'Assets'/(name+'.tga'))
        save(name, shaped_border(ring, native), records)
        casings[name] = {'source': 'actionbutton-border.tga', 'construction': 'shared ThemeButtonShapes material mapping; exact native alpha'}
    for name in ('portrait_frame_hi', 'portrait_frame_lo', 'pw_crystal_case', 'pw_crystal_case_low', 'orb_case_hi', 'orb_case_low'):
        save(name+'-glow', H.halo(read(OUT/(name+'.tga'))), records)
    resource_contracts = resource_halos(records)
    head, fit = D.contain(read(SOURCE/'cast-head.png'), (16,16,240,240), (256,256))
    save('cast-head', head, records)
    save('cast-head-glow', H.halo(head), records)
    checks = {}
    for path in sorted(OUT.glob('*.tga')):
        failures, notes = C.check(path)
        checks[path.stem] = {'failures': failures, 'lookNotes': notes}
    inventory = {p.relative_to(ROOT).as_posix(): {'sha256': sha(p), 'disposition':
                  'new Warrior casing' if p.stem in casings else SHARED.get(p.stem, 'shared functional, semantic or other media')}
                 for p in sorted((ROOT/'Assets').glob('*.tga'))}
    manifest = {'theme': 'Warrior - Skyhold / The Valarjar', 'runtimeInstalled': False,
                'liveValidated': False, 'nativeLayoutChanges': False,
                'status': 'Staged asset pack; complete terminal coverage repair; runtime/live checks pending',
                'concept': 'Docs/Research_Assets/Warrior/approved-concept.png',
                'conceptSha256': sha(WORK/'approved-concept.png'),
                'assets': records, 'casings': casings, 'shared': SHARED, 'inventory': inventory,
                'healthEndcaps': joins, 'castHead': fit, 'checks': checks,
                'resourceHaloContracts': resource_contracts,
                'generationTool': 'built-in image_gen',
                'generationProvenance': {p.stem: json.loads(p.read_text(encoding='utf-8')) for p in sorted(SOURCE.glob('*.json'))},
                'acceptedHealthSources': CAP_SOURCES,
                'terminalContract':TERMINAL_CONTRACT,'rejectedSources':REJECTED_SOURCES,
                'sources': {p.name: {'sha256': sha(p), 'canvas': list(Image.open(p).size)} for p in sorted(SOURCE.glob('*.png'))}}
    write_json(OUT/'manifest.json', manifest)
    write_json(WORK/'verification.json', {'geometryFailures': {n:c['failures'] for n,c in checks.items() if c['failures']},
               'textureCount': len(records), 'healthRegistrations': len(joins),
               'maxDipError': max(j['maxNativePixelError'] for j in joins),
               'assetManifestSha256':sha(OUT/'manifest.json'),
               'maxExposedTerminalPixelsBeyondAA':max(j['exposedTerminalPixelsBeyondAA'] for j in joins),
               'protectedFiles': len(protected), 'liveValidated': False})
    assert all(sha(ROOT/p) == h for p,h in protected.items()), 'protected source changed'
    print(json.dumps({'textures': len(records), 'geometryFailures': {n:c['failures'] for n,c in checks.items() if c['failures']},
                      'healthRegistrations': len(joins)}, indent=2))


if __name__ == '__main__':
    if (OUT/'manifest.json').exists() and json.loads((OUT/'manifest.json').read_text()).get('fitRevision'):
        raise SystemExit('Superseded exporter: use Tools/Repair-WarriorFit.py --build. Do not restore erased straps, giant caps or bottom-aligned cast art.')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--endcaps-only',action='store_true',help='validate all twelve repaired fits before replacing only caps/halos')
    repair_endcaps() if parser.parse_args().endcaps_only else build()
