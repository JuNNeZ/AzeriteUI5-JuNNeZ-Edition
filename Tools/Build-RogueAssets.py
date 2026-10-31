"""Rogue production checkpoint and representative exported-assembly gate.

Art is generated separately with built-in image_gen. This tool freezes the
native contracts, registers paintings and renders actual TGA exports; it never
installs a partially reviewed theme or changes any existing theme.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from ThemeHealthEndcaps import align, lowest_point, terminal_mask
from ThemeOrbGlass import restore_glass
from ThemeButtonShapes import border as shaped_border

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue'
SOURCE = WORK / 'Sources'
OUT = ROOT / 'Assets_Draft/Rogue'
TEMPLATES = ROOT / 'Docs/Research_Assets/Templates'
CASES = ('hp_cap_case', 'hp_mid_case', 'hp_low_case', 'hp_boss_case')
RUNTIME_PATHS = ('Core/Core.xml','Core/ThemeEffects.lua','Core/LegacyHUD.lua','Options/OptionsPages/Themes.lua')
CONCEPT = Path('C:/Users/Jonas/AppData/Local/Temp/codex-clipboard-2ebd1fd4-91a9-4868-a606-2274f801b7a0.png')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def prepare():
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    (WORK / 'Masks').mkdir(exist_ok=True)
    if not (WORK / 'approved-concept.png').exists():
        shutil.copyfile(CONCEPT, WORK / 'approved-concept.png')
    if (WORK / 'contract.json').exists():
        check_contract()
        print('Existing immutable Rogue contract retained.')
        return
    protected = {p.relative_to(ROOT).as_posix(): sha(p)
                 for folder in ('Assets', 'Core', 'Layouts', 'Options')
                 for p in (ROOT / folder).rglob('*') if p.is_file()}
    contracts = {}
    for case in CASES:
        native = read(ROOT / 'Assets' / (case + '.tga'))
        required = terminal_mask(native)
        path = WORK / 'Masks' / (case + '-terminal.png')
        required.save(path)
        reference = []
        for key in ('antler', 'bear', 'owl'):
            art = read(ROOT / 'Assets/Druid' / ('ornament-' + key + '-' + case + '.tga'))
            reference.append(art.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox())
        druid = read(ROOT / 'Assets/Druid' / (case + '-over.tga'))
        shift = lowest_point(native)[0] - lowest_point(druid)[0]
        limit = [int(np.floor(min(b[0] for b in reference) + shift)),
                 min(b[1] for b in reference),
                 int(np.ceil(max(b[2] for b in reference) + shift)),
                 max(b[3] for b in reference)]
        contracts[case] = {'terminalMask': path.relative_to(ROOT).as_posix(),
                           'terminalMaskSha256': sha(path),
                           'nativeSha256': sha(ROOT / 'Assets' / (case + '.tga')),
                           'dip': lowest_point(native), 'approvedEnvelope': limit}
    write(WORK / 'contract.json', {
        'theme': 'Rogue - Venom & Steel', 'approvedConceptSha256': sha(WORK / 'approved-concept.png'),
        'approval': 'Maintainer approved direction and maximum Druid envelope in chat 2026-10-26.',
        'health': contracts, 'protected': protected,
        'layoutExportSha256': sha(ROOT / 'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json'),
        'runtimeInstalled': False, 'liveValidated': False})
    inventory = {p.name: 'pending newly painted Rogue casing' if p.stem in json.loads((ROOT / 'Docs/Theme Asset Geometry.json').read_text())
                 else 'shared functional, semantic, effect or unrelated media'
                 for p in (ROOT / 'Assets').glob('*.tga')}
    for name in ('nameplate_backdrop.tga', 'minimap-onebar-backdrop.tga', 'minimap-twobars-backdrop.tga', 'options-box.tga'):
        inventory[name] = 'intentionally shared functional backing/state art'
    write(WORK / 'inventory.json', inventory)
    # Geometry reference only; no generated painting is manufactured here.
    case = 'hp_cap_case'
    item = contracts[case]
    native = read(ROOT / 'Assets' / (case + '.tga'))
    page = Image.new('RGBA', (1024, 1024), '#17191d')
    draw = ImageDraw.Draw(page)
    draw.text((24, 20), 'ROGUE TWIN GUARD - GEOMETRY GUIDE ONLY', fill='white')
    box = (690, 32, 838, 198)
    region = native.crop(box).resize((740, 830), Image.Resampling.NEAREST)
    page.alpha_composite(region, (140, 80))
    limit = item['approvedEnvelope']
    draw.rectangle((140 + (limit[0]-box[0])*5, 80 + (limit[1]-box[1])*5,
                    140 + (limit[2]-box[0])*5, 80 + (limit[3]-box[1])*5), outline='cyan', width=3)
    mask = read(WORK / 'Masks' / (case + '-terminal.png')).getchannel('R').crop(box).resize((740, 830), Image.Resampling.NEAREST)
    overlay = Image.new('RGBA', mask.size, '#ff40b0')
    overlay.putalpha(mask.point(lambda a: round(a*.7)))
    page.alpha_composite(overlay, (140, 80))
    draw.text((24, 940), 'CYAN: maximum footprint. MAGENTA: entire terminal to cover.', fill='white')
    draw.text((24, 968), 'One lowest mounting toe. No blade may descend below it.', fill='white')
    page.save(WORK / 'twin-guard-guide.png')
    (WORK / 'CHECKPOINT.md').write_text(
        '# Rogue - Venom & Steel\n\n'
        'Approved direction and Druid maximum footprint: 2026-10-26.\n'
        'Current stage: source generation for one representative health/cast assembly.\n'
        'No runtime integration and no live Retail/Forever validation.\n\n'
        'Next: retain one whole generated painting per job and provenance; export '
        'health None/Twin Guard and normal/protected cast None/on at 1x/2x. '
        'Require frozen terminal coverage, bounded footprint, <=20% combined '
        'fill occlusion, explicit bridge preservation and actual painted cast fit. '
        'Inspect the complete exported assemblies before expanding production.\n\n'
        'Run: `python Tools/Build-RogueAssets.py --prepare`.\n', encoding='utf-8')
    print('Frozen concept, native terminal masks, Druid bounds, inventory and protected files.')
    print(json.dumps(contracts, indent=2))


def check_contract():
    contract = json.loads((WORK / 'contract.json').read_text())
    assert sha(WORK / 'approved-concept.png') == contract['approvedConceptSha256']
    for item in contract['health'].values():
        assert sha(ROOT / item['terminalMask']) == item['terminalMaskSha256']
    runtime_path=WORK/'authorized-runtime-changes.json'
    runtime=json.loads(runtime_path.read_text()) if runtime_path.exists() else {}
    assert set(runtime)<=set(RUNTIME_PATHS),'Unexpected runtime edit scope'
    for name, digest in contract['protected'].items():
        current=sha(ROOT/name)
        if name in runtime:
            assert runtime[name]['beforeSha256']==digest and runtime[name]['afterSha256']==current,'Runtime edit changed after review: '+name
        else:
            assert current == digest, 'Protected file changed: ' + name
    return contract


def record_runtime_changes():
    contract=json.loads((WORK/'contract.json').read_text())
    edits={name:{'beforeSha256':contract['protected'][name],'afterSha256':sha(ROOT/name)}
           for name in RUNTIME_PATHS if sha(ROOT/name)!=contract['protected'][name]}
    write(WORK/'authorized-runtime-changes.json',edits)
    check_contract()
    print('Recorded exact authorized Rogue runtime edits; unrelated original files remain protected.')


def prepare_cast():
    check_contract()
    P = module('rogue_cast_projection', 'PaladinFillContracts.py')
    data = json.loads((ROOT / 'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json').read_text())['original']['PlayerCastBar']
    rect, slot = (80,58,112,11), (48,39.5,48,48)
    required = np.zeros((256,256), dtype=bool)
    record = {}
    for case, family in (('cast_back','CastBarBackground'),('cast_back_spiked','CastBarShield')):
        native = read(ROOT / 'Assets' / (case+'.tga'))
        pixels = np.array(native.getchannel('A'))
        inlet = Image.open(TEMPLATES / (case+'-fill.png')).convert('L').getbbox()[0]
        pixels[:,inlet:] = 0
        mask = Image.fromarray(pixels)
        path = WORK / 'Masks' / (case+'-socket.png')
        if path.exists():
            assert np.array_equal(np.asarray(Image.open(path)), pixels), 'Cast mask changed'
        else:
            mask.save(path)
        casing = P.anchor(rect, data[family+'Size'], data[family+'Position'])
        field = np.asarray(P.project(mask,casing,slot,(256,256))) > 128
        required |= field
        record[case] = {'nativeSha256':sha(ROOT / 'Assets' / (case+'.tga')),
                        'socketMask':path.relative_to(ROOT).as_posix(), 'socketMaskSha256':sha(path),
                        'casingDrawRect':casing, 'requiredPixels':int(field.sum())}
    # A measured geometry template, not painted art: one upright vial with
    # opaque leather mounting ears covering both native sockets.
    body = Image.new('L',(256,256))
    draw = ImageDraw.Draw(body)
    draw.polygon([(109,16),(140,16),(147,36),(147,53),(159,64),(159,195),
                  (145,217),(141,240),(109,240),(103,217),(90,195),(90,64),
                  (104,53),(104,36)],fill=255)
    a = np.maximum(np.asarray(body), required.astype('uint8')*255)
    template = Image.new('RGBA',(256,256),'#777b80')
    template.putalpha(Image.fromarray(a))
    template.resize((1024,1024),Image.Resampling.NEAREST).save(WORK / 'cast-vial-fixed-template.png')
    contract_path = WORK / 'cast-contract.json'
    record = {'slotDrawRect':slot, 'nativeCastRect':rect, 'cases':record,
              'templateSha256':sha(WORK / 'cast-vial-fixed-template.png'),
              'runtimeScale':1,'userOffsets':[0,0]}
    if contract_path.exists():
        assert json.loads(contract_path.read_text()) == json.loads(json.dumps(record)), 'Cast contract changed'
    else:
        write(contract_path,record)
    print('Cast normal/protected sockets frozen; fixed vial template prepared.')


def health_runs(source,native,name):
    """Keep complete ends/studs at uniform scale; vary plain rail runs only."""
    spec=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())[name]
    target=spec['painted']
    art=source.crop(source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())
    height=target[3]-target[1]
    art=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
    width=target[2]-target[0]
    delta=width-art.width
    a,b=round(art.width*.37),round(art.width*.64)
    if delta<0:
        cut=-delta; first=cut//2
        assert a+first<b and b+cut-first<art.width-25,'Insufficient straight rail material'
        parts=[art.crop((0,0,a,height)),art.crop((a+first,0,b,height)),art.crop((b+cut-first,0,art.width,height))]
    elif delta and name=='hp_boss_case':
        middle=round(art.width*.5);first=delta//2
        parts=[art.crop((0,0,a,height)),art.crop((middle-first//2,0,middle-first//2+first,height)),
               art.crop((a,0,b,height)),art.crop((middle-(delta-first)//2,0,middle-(delta-first)//2+delta-first,height)),
               art.crop((b,0,art.width,height))]
    elif delta:
        run=art.crop((a-10,0,a+10,height))
        extension=Image.new('RGBA',(delta,height))
        for x in range(0,delta,run.width):
            extension.alpha_composite(run.crop((0,0,min(run.width,delta-x),height)),(x,0))
        parts=[art.crop((0,0,a,height)),extension,art.crop((a,0,art.width,height))]
    else:
        parts=[art]
    joined=Image.new('RGBA',(width,height));x=0
    for part in parts:
        joined.alpha_composite(part,(x,0));x+=part.width
    assert x==width
    return joined


def quiet_shadow(image, native, name, foreground=False):
    """Register grounding once, without changing paint, glass or frozen ends."""
    p, n = np.array(image), np.asarray(native)
    shadow = (n[:, :, 3] <= 200) & (n[:, :, :3].max(2) == 0)
    fill_path = TEMPLATES / (name + '-fill.png')
    if fill_path.exists():
        shadow &= np.asarray(Image.open(fill_path).convert('L')) == 0
    if name in CASES:
        mask = WORK / 'Masks' / (name + '-terminal.png')
        shadow &= np.asarray(Image.open(mask).convert('L')) == 0
    # The backdrop already grounds the assembly. A second shadow above the
    # fill doubled its darkness, including at the crystal/health-rail join.
    p[shadow, 3] = 0 if foreground else np.rint(p[shadow, 3] * .45).astype('uint8')
    return Image.fromarray(p)


def minimap_painting(source, native):
    """Fit the whole painted rim, not native shadow pixels filled with RGB."""
    target = native.getchannel('A').point(lambda a: 255 if a > 200 else 0).getbbox()
    box = source.getchannel('A').point(lambda a: 255 if a > 200 else 0).getbbox()
    scale = min((target[2]-target[0])/(box[2]-box[0]),
                (target[3]-target[1])/(box[3]-box[1]))
    art = source.resize((round(source.width*scale), round(source.height*scale)), Image.Resampling.LANCZOS)
    x = round((target[0]+target[2]-(box[0]+box[2])*scale)/2)
    y = round((target[1]+target[3]-(box[1]+box[3])*scale)/2)
    paint = Image.new('RGBA', native.size)
    paint.alpha_composite(art, (x, y))
    shadow = Image.new('RGBA', native.size)
    shadow.putalpha(paint.getchannel('A').filter(ImageFilter.GaussianBlur(1.2)).point(lambda a: round(a*.3)))
    return Image.alpha_composite(shadow, paint), {
        'uniformScale': scale, 'offset': [x, y], 'wholePainting': True,
        'policy': 'whole source rim; compact 1.2px grounding; no native-alpha extrusion'}


def register_casing(name):
    """Fresh paint on the native alpha; retain native recess/glass below fills.

    No fill-wide erasure of source detail: explicit rail/bridge masks are saved
    before layer partition, and the exact registered paint survives there.
    """
    D = module('rogue_registration', 'Build-DruidArt.py')
    native = read(ROOT / 'Assets' / (name + '.tga'))
    source_name = 'hp_cap_case' if name in CASES else ('cast_back' if name.startswith('cast_back') and not (SOURCE/(name+'.png')).exists() else name)
    source = read(SOURCE / (source_name + '.png'))
    construction = 'whole source painting'
    if name in CASES:
        # Match rail height first. Vary only two plain straight runs; preserve
        # the full terminal, stud count and both end paintings. Width-first
        # contain left an 8px strip without actual source paint above the rail.
        # The already locked representative uses the original two-run replay;
        # the remaining widths also need extension and the five-stud boss run.
        source = D.modular_cast(source, native) if name=='hp_cap_case' else health_runs(source,native,name)
        construction = 'uniform rail height; plain run cuts/extensions; intact ends; native three/five-stud family'
    elif name.startswith('cast_back'):
        source = D.modular_cast(source, native)
        construction = 'uniform rail height; two plain runs shortened; native cast silhouette'
    painted, fit = D.register_material(source, native)
    fit['construction'] = construction
    fit['policy'] = 'whole painting uniformly registered; exact native casing alpha, measured edge RGB extension and shared recess/glass'
    if name.startswith('cast_back'):
        from PaladinFillContracts import clearance_mask
        fill = np.asarray(clearance_mask(name,native.size)) > 0
    else:
        fill = np.asarray(Image.open(TEMPLATES / (name + '-fill.png')).convert('L')) > 128
    raw = np.array(painted)
    n = np.asarray(native)
    # The approved casing wraps live on the rails, outside the meter. Should a
    # future painting cross the opening, it needs an explicit approved mask;
    # it cannot silently disappear into a clearance operation.
    raw_fit, _ = D.contain(source, D.opaque_bounds(native), native.size)
    source_pixels = np.asarray(raw_fit)
    if name in CASES:
        # Source shadow is not painted metal. The general registrar accepted
        # alpha>128 black fringe as a colour seed, extending it into solid
        # native rail pixels. Extend opaque PAINT RGB only; retain native alpha.
        terminal = np.asarray(Image.open(WORK/'Masks'/(name+'-terminal.png')).convert('L')) > 0
        missing = (n[:, :, 3] > 200) & (source_pixels[:, :, 3] < 200) & ~fill & ~terminal
        repair = read(WORK/'Live-Repair-2026-10-28/rail-paint.png')
        repair = D.modular_cast(repair, native) if name == 'hp_cap_case' else health_runs(repair, native, name)
        registered, repair_fit = D.contain(repair, D.opaque_bounds(native), native.size)
        rp = np.asarray(registered)
        # Sample genuine generated paint at the edge, rather than duplicating
        # columns of its shadow into a synthetic metal surface.
        known = (rp[:, :, 3] >= 200) & (rp[:, :, :3].max(2) > 20)
        edge = known & ~(np.asarray(Image.fromarray(known.astype('uint8')*255).filter(ImageFilter.MinFilter(3))) > 0)
        ey, ex = np.where(edge)
        rgb = rp[:, :, :3].copy()
        my, mx = np.where(missing & ~known)
        for offset in range(0, len(mx), 128):
            yy, xx = my[offset:offset+128], mx[offset:offset+128]
            nearest = ((yy[:, None]-ey)**2 + (xx[:, None]-ex)**2).argmin(1)
            rgb[yy, xx] = rp[ey[nearest], ex[nearest], :3]
        raw[missing, :3] = rgb[missing]
        mask_path = WORK/'Masks'/(name+'-registration-rgb.png')
        if mask_path.exists():
            assert np.array_equal(np.asarray(Image.open(mask_path).convert('L')) > 0, missing), 'Frozen RGB repair mask changed'
        else:
            Image.fromarray(missing.astype('uint8')*255).save(mask_path)
        fit['opaquePaintRegistrationMaskSha256'] = sha(mask_path)
        fit['opaquePaintRegistrationPixels'] = int(missing.sum())
        fit['repairPaintingSha256'] = sha(WORK/'Live-Repair-2026-10-28/rail-paint.png')
        fit['repairPaintingRegistration'] = repair_fit
    visible_native_metal = (n[:, :, 3] > 200) & ~fill
    fit['missingVisibleMetalFraction'] = float((visible_native_metal & (source_pixels[:, :, 3] < 64)).sum() /
                                              max(1, visible_native_metal.sum()))
    proposed_crossing = (source_pixels[:, :, 3] > 240) & fill & (n[:, :, 3] <= 200)
    bridge = np.zeros(fill.shape, dtype=bool)
    bridge_path = WORK / 'Masks' / (name + '-bridges.png')
    if bridge_path.exists():
        bridge = np.asarray(Image.open(bridge_path).convert('L')) > 128
    # Preserve native glass and empty recess below the functional meter.
    back = raw.copy()
    back[fill] = n[fill]
    front = raw.copy()
    front[fill, 3] = 0
    glass = fill & (n[:, :, 3] > 0) & (n[:, :, 3] <= 200)
    front[glass] = n[glass]
    front[bridge] = source_pixels[bridge]
    if not bridge_path.exists():
        Image.fromarray(bridge.astype('uint8') * 255).save(bridge_path)
    assert np.array_equal(front[bridge], source_pixels[bridge]), 'Bridge paint lost'
    fit.update({'proposedPaintOverGlassPixels': int(proposed_crossing.sum()),
                'explicitBridgePixels': int(bridge.sum()),
                'bridgeMaskSha256': sha(bridge_path),
                'registeredPaintSha256': hashlib.sha256(raw.tobytes()).hexdigest()})
    if name in CASES:
        return (quiet_shadow(Image.fromarray(back), native, name),
                quiet_shadow(Image.fromarray(front), native, name, foreground=True), fit)
    return Image.fromarray(back), Image.fromarray(front), fit


def build_cast():
    check_contract()
    D = module('rogue_cast_registration','Build-DruidArt.py')
    H = module('rogue_cast_halo','Build-RebuiltHealthArt.py')
    C = module('rogue_cast_checker','Check-ThemeAssetStyle.py')
    contract = json.loads((WORK / 'cast-contract.json').read_text())
    pending = {}
    fits = {}
    for case in ('cast_back','cast_back_spiked','cast_back_wooden'):
        back, front, fit = register_casing(case)
        pending[case], pending[case+'-over'] = back, front
        fits[case] = fit
    # Project actual paint at the exact shared default 48px slot, not merely
    # its texture-frame rectangle. Read the frozen normal/protected masks.
    target, canvas = (0,0,256,128), (1024,512)
    # Uniform registration inside the existing 240px painted slot limit; the
    # runtime frame stays exactly 48px at 100%, with X/Y=0.
    for margin in range(16,7,-1):
        head,fit=D.contain(read(SOURCE/'cast-head.png'),(margin,margin,256-margin,256-margin),(256,256))
        bounds=head.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
        assert abs((bounds[1]+bounds[3])/2-128)<=.5,'Actual painted cast head is not vertically centred'
        cover=np.asarray(D.project(head.getchannel('A'),contract['slotDrawRect'],target,canvas))>=240
        aa=np.asarray(Image.fromarray((cover*255).astype('uint8')).filter(ImageFilter.MaxFilter(7)))>0
        sockets={}
        for case,item in contract['cases'].items():
            assert sha(ROOT/item['socketMask'])==item['socketMaskSha256']
            mask=Image.open(ROOT/item['socketMask']).convert('L')
            required=np.asarray(D.project(mask,item['casingDrawRect'],target,canvas))>128
            sockets[case]={'requiredPixels':int(required.sum()),'exposedPixels':int((required&~aa).sum())}
        if all(item['exposedPixels']==0 for item in sockets.values()):
            break
    if any(item['exposedPixels'] for item in sockets.values()):
        # Register the whole upright painting horizontally against the actual
        # socket. This is source placement inside the unchanged shared slot,
        # not a compensating runtime offset or a deformation of the vial.
        centred=head
        for dx in (1,-1,2,-2,3,-3,4,-4):
            shifted=Image.new('RGBA',head.size)
            shifted.alpha_composite(centred,(dx,0))
            b=shifted.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
            if b[0]<8 or b[2]>248:
                continue
            cover=np.asarray(D.project(shifted.getchannel('A'),contract['slotDrawRect'],target,canvas))>=240
            aa=np.asarray(Image.fromarray((cover*255).astype('uint8')).filter(ImageFilter.MaxFilter(7)))>0
            proposed={}
            for case,item in contract['cases'].items():
                mask=Image.open(ROOT/item['socketMask']).convert('L')
                required=np.asarray(D.project(mask,item['casingDrawRect'],target,canvas))>128
                proposed[case]={'requiredPixels':int(required.sum()),'exposedPixels':int((required&~aa).sum())}
            if all(item['exposedPixels']==0 for item in proposed.values()):
                head,bounds,sockets=shifted,b,proposed
                fit['sourceRegistrationX']=dx
                break
    write(WORK/'cast-registration-diagnostic.json',{'paintedBounds':bounds,'socketCoverage':sockets,'casings':fits})
    assert all(item['exposedPixels']==0 for item in sockets.values()),'Cast vial does not cover both frozen sockets at 100%, X/Y=0'
    pending['cast-head'],pending['cast-head-glow'] = head,H.halo(head)
    records = {}
    for name,image in pending.items():
        path = OUT/(name+'.tga')
        image.save(path,compression=None)
        assert read(path).tobytes()==image.tobytes()
        failures,notes=C.check(path)
        assert not failures,(name,failures)
        records[name]={'sha256':sha(path),'lookNotes':notes}
    write(WORK/'cast-registration.json',{'assets':records,'head':fit,'paintedBounds':bounds,
          'socketCoverage':sockets,'casings':fits,'runtimeInstalled':False,'liveValidated':False})
    print(json.dumps({'exportedCastTextures':len(records),'paintedBounds':bounds,'socketCoverage':sockets},indent=2))


ALIASES = {'pw_crystal_case_low':'pw_crystal_case', 'orb_case_low':'orb_case_hi',
           'portrait_frame_lo':'portrait_frame_hi', 'orb-border':'minimap-border',
           'config_button_bright':'config_button', 'hp_critter_case':'hp_critter_case_hi',
           'border-aura':'border-tooltip','better-blizzard-border-small-alternate':'border-tooltip'}


def ordinary(name):
    D=module('rogue_ordinary_registration','Build-DruidArt.py')
    native=read(ROOT/'Assets'/(name+'.tga'))
    source_name=ALIASES.get(name,name)
    if name.startswith('portrait_frame') and (SOURCE/'portrait_frame_hi-v2.png').exists():
        source_name='portrait_frame_hi-v2'
    source=read(SOURCE/(source_name+'.png'))
    n=np.asarray(native)
    pending={}
    if name == 'minimap-border':
        result, fit = minimap_painting(source, native)
    elif name.startswith(('border-','better-')):
        result,fit=D.atlas(source,native)
    elif name.startswith('portrait_frame'):
        # Uniform whole-painting registration inside the existing style-key
        # tolerances, never radial/per-axis mapping of the portrait planes.
        C=module('rogue_portrait_geometry','Check-ThemeAssetStyle.py')
        spec=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())[name]
        target=spec['painted'];opening=spec['opening']
        clean=source.copy();clean.putalpha(clean.getchannel('A').point(lambda a:0 if a<=8 else a))
        art=clean.crop(clean.getchannel('A').getbbox())
        found=None
        for extra in range(21):
            height=target[3]-target[1]+extra
            piece=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
            for dx in (0,-1,1,-2,2,-3,3):
                for dy in (0,-1,1,-2,2,-3,3):
                    x=round((target[0]+target[2]-piece.width)/2)+dx
                    y=round((target[1]+target[3]-piece.height)/2)+dy
                    candidate=Image.new('RGBA',native.size);candidate.alpha_composite(piece,(x,y))
                    p=np.array(candidate);inner=np.asarray(D.closed_hole(candidate))>0
                    glass=inner & (n[:,:,3]<=200) & (p[:,:,3]==0)
                    p[glass]=n[glass];candidate=Image.fromarray(p)
                    b=candidate.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
                    hole=C.hole(candidate)
                    if b and hole and all(abs(b[i]-target[i])<=10 for i in range(4)) and all(abs(hole[i]-opening[i])<=4 for i in range(4)):
                        found=(candidate,{'uniformScale':height/art.height,'offset':[x,y],
                                         'paintedBounds':b,'opening':hole,'policy':'intact whole portrait, uniform scale/translation within native style tolerance; native glass'})
                        break
                if found:
                    break
            if found:
                break
        assert found,'Whole portrait cannot fit native aperture without changing its planes'
        result,fit=found
    else:
        result,fit=D.register_material(source,native)
        fit['policy']='new source material on exact native alpha; no native RGB recolour'
        p=np.array(result)
        inner=np.asarray(D.closed_hole(native))>0
        fill_path=TEMPLATES/(name+'-fill.png')
        fill=np.asarray(Image.open(fill_path).convert('L'))>128 if fill_path.exists() else None
        if name.startswith('hp_critter'):
            from PaladinFillContracts import clearance_mask
            field=np.asarray(clearance_mask(name,native.size))>0
            p[field]=n[field]
            front=p.copy()
            front[field,3]=0
            glass=field & (n[:,:,3]>0) & (n[:,:,3]<=200)
            front[glass]=n[glass]
            pending[name+'-over']=Image.fromarray(front)
        else:
            if fill is not None:
                inner |= fill
            glass=inner & (n[:,:,3]<=200)
            p[glass]=n[glass]
            if name=='icon_exit_flight':
                glyph=(n[:,:,0].astype(float)>n[:,:,1]*1.4)&(n[:,:,0]>45)
                p[glyph]=n[glyph]
            if name.startswith('config_button'):
                rgb=n[:,:,:3].astype(float)
                glyph=(rgb.max(2)-rgb.min(2)>12)&(rgb.max(2)>60)
                p[glyph]=n[glyph]
        result=Image.fromarray(p)
    if name in ('pw_crystal_case', 'pw_crystal_case_low'):
        result = quiet_shadow(result, native, name)
    pending[name]=restore_glass(result,ROOT,name)
    return pending,{'source':source_name+'.png','registration':fit}


def build_ordinary():
    check_contract()
    C=module('rogue_ordinary_checker','Check-ThemeAssetStyle.py')
    H=module('rogue_ordinary_halo','Build-RebuiltHealthArt.py')
    spec=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
    skip=set(CASES)|{'cast_back','cast_back_spiked','cast_back_wooden','nameplate_backdrop',
                    'minimap-onebar-backdrop','minimap-twobars-backdrop','options-box',
                    'actionbutton-border-square','actionbutton-border-square-rounded'}
    records={}
    fits={}
    for name in spec:
        if name in skip or not (SOURCE/(ALIASES.get(name,name)+'.png')).exists():
            continue
        pending,fit=ordinary(name)
        fits[name]=fit
        for key,image in pending.items():
            path=OUT/(key+'.tga')
            image.save(path,compression=None)
            failures,notes=C.check(path)
            records[key]={'sha256':sha(path),'failures':failures,'lookNotes':notes}
        if name in ('portrait_frame_hi','portrait_frame_lo','pw_crystal_case','pw_crystal_case_low','orb_case_hi','orb_case_low'):
            glow=H.halo(pending[name]);path=OUT/(name+'-glow.tga');glow.save(path,compression=None)
            records[name+'-glow']={'sha256':sha(path),'failures':[],'lookNotes':[]}
    if (OUT/'actionbutton-border.tga').exists():
        for name in ('actionbutton-border-square','actionbutton-border-square-rounded'):
            image=shaped_border(read(OUT/'actionbutton-border.tga'),read(ROOT/'Assets'/(name+'.tga')))
            path=OUT/(name+'.tga');image.save(path,compression=None)
            failures,notes=C.check(path)
            records[name]={'sha256':sha(path),'failures':failures,'lookNotes':notes}
    result={'assets':records,'casings':fits,'runtimeInstalled':False,'liveValidated':False}
    write(WORK/'ordinary-registration.json',result)
    failures={name:item['failures'] for name,item in records.items() if item['failures']}
    print(json.dumps({'exportedTextures':len(records),'failures':failures},indent=2))
    assert not failures,'Ordinary Rogue source fit needs repair; no installation authorized by this pass'


def build_resource_halos():
    check_contract()
    W=module('rogue_shared_resource_halos','Build-WarriorAssets.py')
    W.OUT=OUT
    assets={}
    contracts=W.resource_halos(assets)
    for item in contracts.values():
        item['silhouette']='whole native crystal plus Rogue cradle'
    write(WORK/'resource-halos.json',{'assets':assets,'contracts':contracts})
    print('Four neutral whole-crystal/cradle halos exported on unchanged resource rectangles.')


def build_manifest():
    contract=check_contract()
    C=module('rogue_manifest_checker','Check-ThemeAssetStyle.py')
    choices=json.loads((WORK/'choice-registration.json').read_text())
    assert set(choices)=={'twinguard','serrated','venom'} and all(v['accepted'] for v in choices.values())
    cast=json.loads((WORK/'cast-registration.json').read_text())
    assert all(not v['exposedPixels'] for v in cast['socketCoverage'].values())
    ordinary=json.loads((WORK/'ordinary-registration.json').read_text())
    assert all(not v['failures'] for v in ordinary['assets'].values())
    assets={};checks={}
    for path in sorted(OUT.glob('*.tga')):
        if path.stem.startswith('ornament-twin-guard-'):
            continue # retained representative evidence; canonical key is twinguard
        failures,notes=C.check(path)
        assert not failures,(path.stem,failures)
        assets[path.stem]={'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'canvas':list(Image.open(path).size)}
        checks[path.stem]={'failures':failures,'lookNotes':notes}
    assert len(assets)==77,('Incomplete runtime texture inventory',len(assets))
    shared={'nameplate_backdrop':'shared neutral backing, no ornamental frame',
            'minimap-onebar-backdrop':'shared functional XP/status ring',
            'minimap-twobars-backdrop':'shared functional XP/status ring',
            'options-box':'shared options control/state art'}
    spec=json.loads((ROOT/'Docs/Theme Asset Geometry.json').read_text())
    casings=sorted(set(spec)-set(shared))
    assert all(name in assets for name in casings)
    fits={choice:item['fits'] for choice,item in choices.items()}
    manifest={'theme':'Rogue - Venom & Steel','runtimeInstalled':False,'liveValidated':False,
              'nativeLayoutChanges':False,'assets':assets,'casings':casings,'shared':shared,
              'healthEndcaps':fits,'cast':cast,'checks':checks,
              'resourceHalos':json.loads((WORK/'resource-halos.json').read_text()),
              'conceptSha256':contract['approvedConceptSha256'],
              'terminalAndFootprintContractSha256':sha(WORK/'contract.json'),
              'maintainerApprovedExposure':json.loads((WORK/'twin-guard-exposure-approval.json').read_text()),
              'controlledEditing':json.loads((WORK/'script-edit-record.json').read_text()),
              'sources':{p.relative_to(WORK).as_posix():sha(p) for folder in (SOURCE,WORK/'Script-Edited') for p in sorted(folder.glob('*')) if p.is_file()},
              'generationProvenance':{p.stem:json.loads(p.read_text()) for p in sorted(SOURCE.glob('*.json'))},
              'inventory':json.loads((WORK/'inventory.json').read_text()),
              'status':'Complete staged pack; numerical and separate current exported-assembly visual review required before installation'}
    write(OUT/'manifest.json',manifest)
    print('Rogue staged manifest:',len(assets),'runtime textures; 28 casings; twelve health fits and independent cast.')


def build_health():
    contract = check_contract()
    H = module('rogue_halo', 'Build-RebuiltHealthArt.py')
    C = module('rogue_checker', 'Check-ThemeAssetStyle.py')
    case = 'hp_cap_case'
    back, front, fit = register_casing(case)
    pending = {case: back, case + '-over': front, case + '-glow': H.halo(front)}
    records = {}
    for name, image in pending.items():
        path = OUT / (name + '.tga')
        image.save(path, compression=None)
        assert read(path).tobytes() == image.tobytes()
        failures, notes = C.check(path)
        records[name] = {'sha256': sha(path), 'failures': failures, 'lookNotes': notes}
    # All native bare terminal paint survives the layer partition. Freeze its
    # hash before any ornament fitting. Never replace it to make a fit pass.
    required = np.asarray(Image.open(ROOT / contract['health'][case]['terminalMask']).convert('L')) > 0
    native = read(ROOT / 'Assets' / (case + '.tga'))
    native_alpha = np.asarray(native)[:, :, 3]
    fill = np.asarray(Image.open(TEMPLATES / (case + '-fill.png')).convert('L')) > 128
    metal = required & ~fill
    assert np.array_equal(np.asarray(front)[metal, 3], native_alpha[metal])
    assert np.array_equal(np.asarray(back)[required, 3], native_alpha[required])
    result = {'case': case, 'registration': fit, 'assets': records,
              'sourceSha256': sha(SOURCE / (case + '.png')),
              'bareFrontSha256': sha(OUT / (case + '-over.tga')),
              'nativeLayoutChanges': False, 'runtimeInstalled': False, 'liveValidated': False}
    write(WORK / 'health-registration.json', result)
    print(json.dumps(result, indent=2))


def build_health_tiers():
    contract=check_contract()
    C=module('rogue_health_tier_checker','Check-ThemeAssetStyle.py')
    H=module('rogue_health_tier_halo','Build-RebuiltHealthArt.py')
    records={}
    for case in CASES:
        if case=='hp_cap_case':
            continue
        back,front,fit=register_casing(case)
        required=np.asarray(Image.open(ROOT/contract['health'][case]['terminalMask']).convert('L'))>128
        n=np.asarray(read(ROOT/'Assets'/(case+'.tga')))
        assert np.array_equal(np.asarray(back)[required,3],n[required,3]),'Native terminal alpha changed'
        assets={}
        for suffix,image in (('',back),('-over',front),('-glow',H.halo(front))):
            path=OUT/(case+suffix+'.tga');image.save(path,compression=None)
            failures,notes=C.check(path)
            assert not failures,(case+suffix,failures)
            assets[case+suffix]={'sha256':sha(path),'lookNotes':notes}
        records[case]={'registration':fit,'assets':assets,'bareFrontSha256':sha(OUT/(case+'-over.tga'))}
    write(WORK/'health-tier-registration.json',records)
    print('Three additional bare native health families exported; original masks and dips preserved.')


def fit_health_cap(source_name='twin-guard.png'):
    contract = check_contract()
    case = 'hp_cap_case'
    front = read(OUT / (case + '-over.tga'))
    baseline = json.loads((WORK / 'health-registration.json').read_text())
    assert sha(OUT / (case + '-over.tga')) == baseline['bareFrontSha256']
    fill = Image.open(TEMPLATES / (case + '-fill.png')).convert('L')
    mask = np.asarray(fill) > 128
    required = np.asarray(Image.open(ROOT / contract['health'][case]['terminalMask']).convert('L')) > 128
    limit = contract['health'][case]['approvedEnvelope']
    assert Path(source_name).name == source_name and source_name.endswith('.png')
    source = read(SOURCE / source_name)
    approval_path = WORK / 'twin-guard-exposure-approval.json'
    approval = json.loads(approval_path.read_text()) if approval_path.exists() else None
    approved = None
    if approval and approval['case'] == case and Path(approval['source']).name == source_name:
        approved = Image.new('L',front.size)
        for point in approval['pixels']:
            approved.putpixel(tuple(point),255)
        expected = {'sourceSha256':sha(SOURCE / source_name),
                    'bareFrontSha256':sha(OUT / (case+'-over.tga')),
                    'originalTerminalMaskSha256':contract['health'][case]['terminalMaskSha256'],
                    'approvalSha256':sha(approval_path),
                    'approvedPixelMaskSha256':hashlib.sha256(approved.tobytes()).hexdigest()}
        lock_path = WORK / 'twin-guard-exception-lock.json'
        if lock_path.exists():
            assert json.loads(lock_path.read_text()) == expected, 'Approved six-pixel exception changed'
        else:
            write(lock_path,expected)
            approved.save(WORK / 'Masks/twin-guard-hp_cap_case-approved-exposure.png')
    trials = []
    H = module('rogue_cap_halo', 'Build-RebuiltHealthArt.py')
    for height in range(80, limit[3] - limit[1] + 1):
        try:
            exposure = approved if approved is not None and height == approval['height'] else None
            cap, fit = align(source, front, height, fill, approved_terminal_exposure=exposure)
            bounds = cap.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
            p = np.asarray(cap)
            aa = np.asarray(Image.fromarray(((p[:, :, 3] >= 240)*255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0
            exposed = int((required & ~aa).sum())
            outside = not (bounds[0] >= limit[0] and bounds[1] >= limit[1] and bounds[2] <= limit[2] and bounds[3] <= limit[3])
            occlusion = float((((p[:, :, 3] > 200) | (np.asarray(front)[:, :, 3] > 200)) & mask).sum() / mask.sum())
            trials.append({'height': height, 'bounds': bounds, 'exposed': exposed,
                           'outside': outside, 'occlusion': occlusion})
            allowed = np.asarray(exposure) > 128 if exposure is not None else np.zeros(required.shape,dtype=bool)
            if not np.array_equal(required & ~aa, allowed) or outside or occlusion > .20:
                continue
            for suffix, image in (('', cap), ('-glow', H.halo(cap))):
                image.save(OUT / ('ornament-twin-guard-' + case + suffix + '.tga'), compression=None)
            result = dict(fit, case=case, height=height, bounds=bounds,
                          approvedEnvelope=limit, combinedFillCovered=occlusion,
                          frozenTerminalExposedPixels=exposed, source=source_name,
                          maintainerApprovedExposurePixels=int(allowed.sum()),
                          sourceSha256=sha(SOURCE / source_name))
            write(WORK / 'twin-guard-fit.json', result)
            print(json.dumps(result, indent=2))
            return
        except (ValueError, AssertionError) as error:
            trials.append({'height': height, 'failure': str(error)})
    write(WORK / (Path(source_name).stem + '-rejected-fit.json'), {'sourceSha256': sha(SOURCE / source_name),
          'approvedEnvelope': limit, 'trials': trials, 'runtimeInstalled': False})
    raise ValueError('Twin Guard has no fit within the frozen contract; rejected source and evidence retained.')


def fit_choices(venom_only=False):
    contract=check_contract()
    H=module('rogue_choice_halos','Build-RebuiltHealthArt.py')
    choices={'twinguard':'twin-guard-tiers-v2.png' if (SOURCE/'twin-guard-tiers-v2.png').exists() else 'twin-guard-tiers.png',
             'serrated':'serrated-v2.png' if (SOURCE/'serrated-v2.png').exists() else 'serrated.png','venom':'venom-vial.png'}
    result=json.loads((WORK/'choice-registration.json').read_text()) if venom_only and (WORK/'choice-registration.json').exists() else {}
    for choice,source_name in choices.items():
        if venom_only and choice!='venom':
            continue
        original_source=read(SOURCE/source_name)
        orientations_path=WORK/'choice-orientations.json'
        orientations=json.loads(orientations_path.read_text()) if orientations_path.exists() else {}
        pending={};fits={};rejected={}
        for case in CASES:
            if choice=='twinguard' and case=='hp_cap_case':
                # This exact representative alone carries the six-pixel
                # maintainer exception; don't reuse it as a numeric tolerance.
                prior=json.loads((WORK/'twin-guard-fit.json').read_text())
                assert prior['source']=='twin-guard-fixed-v2.png' and prior['maintainerApprovedExposurePixels']==6
                fits[case]=prior
                for suffix in ('','-glow'):
                    pending['ornament-twinguard-'+case+suffix]=read(OUT/('ornament-twin-guard-'+case+suffix+'.tga'))
                continue
            orientation=orientations.get(choice,{})
            current=orientation.get('sourceSha256')==sha(SOURCE/source_name)
            rotation=orientation.get('caseRotations',{}).get(case,orientation.get('rotation',0)) if current else 0
            source=original_source.rotate(rotation,resample=Image.Resampling.BICUBIC,expand=True) if rotation else original_source
            front=read(OUT/(case+'-over.tga'))
            fill=Image.open(TEMPLATES/(case+'-fill.png')).convert('L');mask=np.asarray(fill)>128
            c=contract['health'][case];limit=c['approvedEnvelope']
            required=np.asarray(Image.open(ROOT/c['terminalMask']).convert('L'))>128
            trials=[]
            for height in range(100,limit[3]-limit[1]+1):
                try:
                    cap,fit=align(source,front,height,fill)
                    bounds=cap.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
                    assert bounds[0]>=limit[0] and bounds[1]>=limit[1] and bounds[2]<=limit[2] and bounds[3]<=limit[3],'Outside approved footprint'
                    p=np.asarray(cap);aa=np.asarray(Image.fromarray(((p[:,:,3]>=240)*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)))>0
                    assert not (required&~aa).any(),'Frozen original terminal is exposed'
                    combined=float((((p[:,:,3]>200)|(np.asarray(front)[:,:,3]>200))&mask).sum()/mask.sum())
                    assert combined<=.20,'Combined fill occlusion exceeds limit'
                    fits[case]=dict(fit,case=case,height=height,bounds=bounds,approvedEnvelope=limit,
                                    combinedFillCovered=combined,frozenTerminalExposedPixels=0,
                                    maintainerApprovedExposurePixels=0,source=source_name,sourceSha256=sha(SOURCE/source_name),rotationDegrees=rotation)
                    pending['ornament-'+choice+'-'+case]=cap
                    pending['ornament-'+choice+'-'+case+'-glow']=H.halo(cap)
                    break
                except (ValueError,AssertionError) as error:
                    trials.append({'height':height,'failure':str(error)})
            else:
                rejected[case]=trials
        if rejected:
            write(WORK/(choice+'-tier-rejection.json'),{'sourceSha256':sha(SOURCE/source_name),'cases':rejected})
            result[choice]={'accepted':False,'failedCases':list(rejected)}
            continue
        records={}
        for name,image in pending.items():
            path=OUT/(name+'.tga');image.save(path,compression=None)
            assert read(path).tobytes()==image.tobytes()
            records[name]={'sha256':sha(path),'canvas':list(image.size)}
        result[choice]={'accepted':True,'fits':fits,'assets':records}
    write(WORK/'choice-registration.json',result)
    print(json.dumps({key:{'accepted':item['accepted'],'failedCases':item.get('failedCases',[])} for key,item in result.items()},indent=2))
    assert all(item['accepted'] for item in result.values()),'Some Rogue variants have no approved four-tier registration'


def choice_orientations():
    """Bounded rigid whole-art search, same angle across a motif's native tiers."""
    contract=check_contract()['health']
    records={}
    choices={'twinguard':'twin-guard-tiers-v2.png' if (SOURCE/'twin-guard-tiers-v2.png').exists() else 'twin-guard-tiers.png',
             'serrated':'serrated-v2.png' if (SOURCE/'serrated-v2.png').exists() else 'serrated.png','venom':'venom-vial.png'}
    for choice,source_name in choices.items():
        source=read(SOURCE/source_name)
        cases=[case for case in CASES if not (choice=='twinguard' and case=='hp_cap_case')]
        prepared={}
        for case in cases:
            c=contract[case];limit=c['approvedEnvelope'];box=tuple(limit)
            fill=np.asarray(Image.open(TEMPLATES/(case+'-fill.png')).convert('L'))>128
            front=np.asarray(read(OUT/(case+'-over.tga')))[:,:,3]>200
            req=np.asarray(Image.open(ROOT/c['terminalMask']).convert('L').crop(box))>128
            prepared[case]=(c,req,fill[limit[1]:limit[3],limit[0]:limit[2]],front[limit[1]:limit[3],limit[0]:limit[2]],int((fill&front).sum()),int(fill.sum()))
        best=None;accepted=None;individual={}
        for angle in [0]+[a for n in range(1,16) for a in (-n,n)]:
            art=source.rotate(angle,resample=Image.Resampling.BICUBIC,expand=True) if angle else source
            art=art.crop(art.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())
            columns=np.flatnonzero((np.asarray(art)[:,:,3]>128)[-max(2,round(art.height*.03)):].any(0))
            if len(np.split(columns,np.flatnonzero(np.diff(columns)>2)+1))!=1:
                continue
            fits={};score=0
            for case,(c,req,mask,front,base,denom) in prepared.items():
                limit=c['approvedEnvelope'];width,height=limit[2]-limit[0],limit[3]-limit[1]
                closest=None
                for size in range(100,height+1):
                    piece=art.resize((round(art.width*size/art.height),size),Image.Resampling.LANCZOS)
                    ax,ay=lowest_point(piece)
                    x=round(c['dip'][0]-ax)-limit[0];y=c['dip'][1]-ay-limit[1]
                    if x<0 or y<0 or x+piece.width>width or y+piece.height>height:
                        continue
                    field=Image.new('L',(width,height));field.paste(piece.getchannel('A'),(x,y));alpha=np.asarray(field)
                    combined=(base+int(((alpha>200)&mask&~front).sum()))/denom
                    if combined>.20:
                        continue
                    aa=np.asarray(Image.fromarray(((alpha>=240)*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)))>0
                    missing=int((req&~aa).sum())
                    if closest is None or missing<closest['missing']:
                        closest={'height':size,'missing':missing,'combinedFillCovered':combined}
                    if not missing:
                        break
                fits[case]=closest
                if closest is not None and (case not in individual or closest['missing']<individual[case]['missing']):
                    individual[case]=dict(closest,rotation=angle)
                score+=closest['missing'] if closest else 100000
            if best is None or score<best['score']:
                best={'rotation':angle,'score':score,'cases':fits}
            if score==0:
                accepted=best
                break
        records[choice]=dict(accepted or best,sourceSha256=sha(SOURCE/source_name),allTiersCovered=accepted is not None)
        # Each exported native family may rigidly orient its intact painting
        # against that family's slope. No per-axis deformation or runtime
        # frame/anchor change is involved. Prefer one common angle when it fits.
        if accepted is None and len(individual)==len(cases) and all(not item['missing'] for item in individual.values()):
            records[choice].update(allTiersCovered=True,caseRotations={case:item['rotation'] for case,item in individual.items()},
                                   cases=individual,score=0)
        print(choice,json.dumps(records[choice]),flush=True)
    write(WORK/'choice-orientations.json',records)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--health', action='store_true')
    parser.add_argument('--cap', action='store_true')
    parser.add_argument('--cap-source', default='twin-guard.png')
    parser.add_argument('--prepare-cast', action='store_true')
    parser.add_argument('--cast', action='store_true')
    parser.add_argument('--ordinary', action='store_true')
    parser.add_argument('--health-tiers', action='store_true')
    parser.add_argument('--choices', action='store_true')
    parser.add_argument('--venom-only', action='store_true', help='Rebuild intact Venom only; preserve controlled-edit mount records')
    parser.add_argument('--orientations', action='store_true')
    parser.add_argument('--resource-halos', action='store_true')
    parser.add_argument('--record-runtime', action='store_true')
    parser.add_argument('--manifest', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        prepare()
    if args.health:
        build_health()
    if args.cap:
        fit_health_cap(args.cap_source)
    if args.prepare_cast:
        prepare_cast()
    if args.cast:
        build_cast()
    if args.ordinary:
        build_ordinary()
    if args.health_tiers:
        build_health_tiers()
    if args.choices:
        fit_choices()
    if args.venom_only:
        fit_choices(venom_only=True)
    if args.orientations:
        choice_orientations()
    if args.resource_halos:
        build_resource_halos()
    if args.record_runtime:
        record_runtime_changes()
    if args.manifest:
        build_manifest()
