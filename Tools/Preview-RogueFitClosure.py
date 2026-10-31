"""Joint button/health/crystal source fitting; staged assets/runtime, no install."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import difflib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

from RogueFitClosureSource import build, validate, family_paintings, radial_morph
from ThemeSourceIntegrity import read, whole_painting, verify_pixels, verify_pack
from ThemeHealthEndcaps import lowest_point, terminal_mask

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue/Fit-Closure-2026-10-31'
OUT = ROOT / 'Assets_Draft/Rogue-Fit-Closure-2026-10-31'
SERRATED = ROOT / 'Assets_Draft/Rogue-Serrated-Join-2026-10-31'
CAP = 'ornament-serrated-hp_cap_case'
S = Image.Resampling.LANCZOS


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


F = load('closure_family', 'Review-RogueConceptFamily.py')
J = load('closure_join', 'Preview-RogueSerratedMorph.py')
P = F.A.P
H = load('closure_glow', 'Build-RebuiltHealthArt.py')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def record(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def stage_runtime():
    """Select art using the already chosen fill path; preserve dirty Lua bytes."""
    folder = WORK / 'Runtime'
    folder.mkdir(exist_ok=True)
    edits = {
        'Core/RogueTheme.lua': [
            (b'Theme.StyleCrystal = function(self, power, casePath, useMage)',
             b'Theme.StyleCrystal = function(self, power, casePath, useMage, texturePath)'),
            (b'\t\tseat:SetTexture(path("pw_crystal_case-seat"))\n', b''),
            (b'\tseat.Enabled = true', b'\tlocal ice = type(texturePath) == "string" and texturePath:find("ice", 1, true)\n'
             b'\tseat:SetTexture(path("pw_crystal_case-seat"..(ice and "-wrath" or "")))\n\tseat.Enabled = true')],
        'Core/ThemeEffects.lua': [
            (b'rogue:StyleCrystal(power, casePath, useMage)',
             b'rogue:StyleCrystal(power, casePath, useMage, texturePath)')]
    }
    baseline, patches = {}, []
    for name, replacements in edits.items():
        before = (ROOT/name).read_bytes()
        newline = b'\r\n' if b'\r\n' in before else b'\n'
        after = before
        for old, new in replacements:
            old, new = old.replace(b'\n', newline), new.replace(b'\n', newline)
            assert after.count(old) == 1, 'Runtime proposal stale: '+name
            after = after.replace(old, new, 1)
        (folder/Path(name).name).write_bytes(after)
        (folder/('Before-'+Path(name).name)).write_bytes(before)
        baseline[name] = {'beforeSha256':hashlib.sha256(before).hexdigest(),
                          'proposedSha256':hashlib.sha256(after).hexdigest()}
        patches.extend(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),
                       fromfile='a/'+name,tofile='b/'+name))
    (folder/'RogueFloorModes.patch').write_text(''.join(patches), encoding='utf-8', newline='')
    write(folder/'baseline.json', {'files':baseline,'installed':False,'geometryWritesAdded':False,
        'change':'Forward existing ThemeEffects texturePath and select normal/ice cosmetic floor on every style call.',
        'sourceEvidence':'Player.lua:2925,3010 selects and forwards normal/ice fill; PlayerAlternate.lua:795 forwards its normal path. No new WoW API reads.'})


def native_path(path):
    return ROOT / 'Assets' / path.replace('\\', '/').split('/Assets/')[-1]


class Candidate(F.Current):
    def asset(self, path):
        if path and '/Rogue/' in path.replace('\\', '/'):
            file = OUT / (Path(path.replace('\\', '/')).stem + '.tga')
            if file.is_file():
                return read(file)
        return super().asset(path)

    def resource(self, kind, fraction=1, scene=None, owner=None, part='all'):
        scene = scene if scene is not None else Image.new('RGBA', (800, 500))
        db = self.config()
        owner = owner or (200, 150, *db['Size'])
        rect = F.A.R.B.anchor(owner, db['PowerBackdropSize'], db['PowerBarPosition'])
        rect = (rect[0] - 37, rect[1] + 28, *rect[2:])
        _, local = P.crystal_rects(db)
        case = (rect[0] + local[0], rect[1] + local[1], *local[2:])
        if part in ('all', 'body'):
            self.texture(scene, db['PowerBackdropTexture'], rect)
            self.put(scene, self.own('pw_crystal_case-seat'), case)
            self.fill(scene, db['PowerBarTexture'], rect, fraction, db['PowerBarColors']['MANA'], vertical=True)
        if part in ('all', 'case'):
            self.texture(scene, db['PowerBarForegroundTexture'], case, db['PowerBarForegroundColor'])
        return scene


def crystal_scene(renderer, fraction, ice=False, new=False):
    db = renderer.config()
    page = Image.new('RGBA', (300, 290))
    bar = (40, 20, *db['PowerBackdropSize'])
    _, local = P.crystal_rects(db)
    case = (bar[0] + local[0], bar[1] + local[1], *local[2:])
    renderer.texture(page, db['PowerBackdropTextureWrath' if ice else 'PowerBackdropTexture'], bar)
    floor = 'pw_crystal_case-seat' + ('-wrath' if ice and new else '')
    renderer.put(page, renderer.own(floor), case)
    renderer.fill(page, db['PowerBarTextureWrath' if ice else 'PowerBarTexture'], bar, fraction,
                  (1, 1, 1) if ice else db['PowerBarColors']['MANA'], vertical=True)
    renderer.texture(page, db['PowerBarForegroundTexture'], case, db['PowerBarForegroundColor'])
    return page


def button_scene(renderer, tile='ice', cooldown=False):
    db = renderer.data['ActionButton']
    scene = Image.new('RGBA', (150, 150))
    rect = ((150-db['ButtonSize'][0])/2, (150-db['ButtonSize'][1])/2, *db['ButtonSize'])
    renderer.texture(scene, db['ButtonBackdropTexture'], F.A.R.B.anchor(rect, db['ButtonBackdropSize'], db['ButtonBackdropPosition']), db['ButtonBackdropColor'])
    if tile == 'ice':
        icon = read(ROOT / 'Assets/power-crystal-ice-icon.tga')
    else:
        yy, xx = np.indices((128, 128)); pixels = np.empty((128, 128, 4), dtype='uint8')
        pixels[:] = (255, 80, 15, 255); pixels[((xx//16+yy//16)%2)==0] = (255, 240, 70, 255)
        icon = Image.fromarray(pixels)
    iw, ih = map(round, db['ButtonIconSize'])
    icon = icon.resize((iw, ih), S)
    mask = renderer.asset(db['ButtonMaskTexture']).getchannel('A').resize((iw, ih), S)
    icon.putalpha(ImageChops.multiply(icon.getchannel('A'), mask))
    x, y, _, _ = F.A.R.B.anchor(rect, db['ButtonIconSize'], db['ButtonIconPosition'])
    scene.alpha_composite(icon, (round(x), round(y)))
    if cooldown:
        overlay = Image.new('RGBA', (iw, ih), (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay); draw.pieslice((0, 0, iw-1, ih-1), -90, 90, fill=(0, 0, 0, 170))
        overlay.putalpha(ImageChops.multiply(overlay.getchannel('A'), mask))
        scene.alpha_composite(overlay, (round(x), round(y)))
    renderer.texture(scene, db['ButtonBorderTexture'], F.A.R.B.anchor(rect, db['ButtonBorderSize'], db['ButtonBorderPosition']), db['ButtonBorderColor'])
    return scene


def button_metrics(image, painting=None):
    mask = read(ROOT / 'Assets/actionbutton-mask-circular.tga').getchannel('A')
    field = Image.new('L', (256, 256)); field.paste(mask.resize((84, 84), S), (86, 86))
    inside = np.asarray(field.filter(ImageFilter.MinFilter(3))) > 128
    screen = Image.new('L', (150, 150)); screen.paste(mask.resize((44, 44), S), (53, 53))
    ma = np.asarray(screen); edge = (ma >= 32) & (ma <= 200)
    rim = Image.new('L', (150, 150)); rim.paste(image.getchannel('A').resize((134, 134), S), (8, 8))
    legacy = np.asarray(Image.open(ROOT / 'Docs/Research_Assets/Templates/actionbutton-border-fill.png').convert('L').filter(ImageFilter.MinFilter(3))) > 128
    alpha = np.asarray(image)[:, :, 3]
    paint_alpha = np.asarray(painting if painting is not None else image)[:, :, 3]
    return {'actualIconApertureIntrusionBeyondAA': int(((paint_alpha > 200) & inside).sum()),
            'combinedGlassAndContourAlphaAbove200InsideField': int(((alpha > 200) & inside).sum()),
            'apertureChecksPaintingBeforeExactNativeFunctionalGlass': painting is not None,
            'visibleMaskedIconCutEdgePixelsBelow200': int((edge & (np.asarray(rim) < 200)).sum()),
            'legacyTemplateIntrusionBeyondAA': int(((alpha > 200) & legacy).sum()),
            'paintedBounds': F.bounds(image), 'nativeIconSize': [44, 44], 'nativeBorderSize': [134.295081967]*2}


def projected_rgba(image, bar, case):
    return Image.merge('RGBA', [P.project(image.getchannel(c), bar, case, (256, 128)) for c in 'RGBA'])


def crystal_layers(images):
    db = F.Current().config(); bar, case = P.crystal_rects(db)
    holder = read(ROOT / 'Assets/Rogue/pw_crystal_case.tga')
    old_floor = read(ROOT / 'Assets_Draft/Rogue-Layered-Rebuild-2026-10-30/pw_crystal_case-seat.tga')
    result = {}
    for ice, name in ((False, 'normal'), (True, 'ice')):
        suffix = 'Wrath' if ice else ''
        fill = read(native_path(db['PowerBarTexture'+suffix]))
        back = projected_rgba(read(native_path(db['PowerBackdropTexture'+suffix])), bar, case)
        footprint = P.project(fill.getchannel('A'), bar, case, (256, 128))
        protected = np.asarray(footprint.filter(ImageFilter.MinFilter(3))) > 200
        floor = images['pw_crystal_case-seat' + ('-wrath' if ice else '')]
        intrude = int(((np.asarray(floor)[:, :, 3] > 200) & (np.asarray(footprint.filter(ImageFilter.MinFilter(3))) > 128)).sum())
        assert intrude == 0, 'New floor covers actual normal/ice painted face'
        states = {}
        for fraction in (0, .5, 1):
            cut = fill.copy(); alpha = np.array(fill.getchannel('A')); alpha[:round(fill.height*(1-fraction))] = 0
            cut.putalpha(Image.fromarray(alpha)); projected = projected_rgba(cut, bar, case)
            scenes = []
            for seat in (old_floor, floor):
                page = Image.alpha_composite(back, seat)
                page = Image.alpha_composite(page, projected)
                scenes.append(Image.alpha_composite(page, holder))
            changed = int(np.any(np.asarray(scenes[0])[protected] != np.asarray(scenes[1])[protected], axis=1).sum())
            assert changed == 0, 'Native painted crystal facets changed at ' + name + str(fraction)
            states[str(fraction)] = {'nativePaintedFaceRgbaPixelsChanged': changed}
        contact = F.C.project_contact(Image.alpha_composite(floor, holder))['contacts'][name]
        assert -.1 <= contact['minGapLayoutUnits'] <= contact['maxGapLayoutUnits'] <= .1, 'Floor leaves a visible central gap'
        result[name] = {'states': states, 'opaqueFloorFaceIntrusionBeyondAA': intrude,
                        'centralFaceToSupportGapLayout': [contact['minGapLayoutUnits'], contact['maxGapLayoutUnits']]}
    return result


def health_metrics(image, caps):
    fill = Image.open(ROOT / 'Docs/Research_Assets/Templates/hp_cap_case-fill.png').convert('L')
    field = np.asarray(fill) > 128; inner = np.asarray(fill.filter(ImageFilter.MinFilter(3))) > 128
    a = np.asarray(image)[:, :, 3]
    assert not ((a > 200) & inner).any(), 'Health source still intrudes on native fill'
    contract = json.loads((ROOT / 'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    assert sha(ROOT / contract['terminalMask']) == contract['terminalMaskSha256']
    frozen = np.asarray(Image.open(ROOT / contract['terminalMask']).convert('L')) > 128
    full = Image.alpha_composite(read(ROOT / 'Assets/Rogue/hp_cap_case.tga'), image)
    solid = np.asarray(Image.fromarray((np.asarray(full)[:, :, 3] > 128).astype('uint8')*255).filter(ImageFilter.MaxFilter(3))) > 0
    assert not (frozen & ~solid).any(), 'Full back+front terminal missing'
    actual = np.asarray(terminal_mask(full)) > 128
    toe = lowest_point(image)
    assert abs(toe[0]-754) <= .5 and toe[1] == 187
    results = {}
    for choice in ('twinguard', 'serrated', 'venom'):
        cap = caps[choice]; ca = np.asarray(cap)[:, :, 3]
        cover = np.asarray(Image.fromarray((ca >= 240).astype('uint8')*255).filter(ImageFilter.MaxFilter(3))) > 0
        allowed = np.zeros_like(frozen)
        if choice == 'twinguard':
            for x, y in ((718,169),(718,170),(719,170),(720,170),(721,171),(723,172)): allowed[y,x] = True
        assert np.array_equal(frozen & ~cover, allowed), 'Original cap exposure differs from exact recorded pixels'
        assert not (actual & ~cover & ~allowed).any(), 'Revised terminal exposed past cap'
        combined = float((((a > 200) | (ca > 200)) & field).sum()/field.sum())
        assert combined <= .20, 'Combined foreground/cap hides fill'
        box, limit = F.bounds(cap), contract['approvedEnvelope']
        assert box[0] >= limit[0] and box[1] >= limit[1] and box[2] <= limit[2] and box[3] <= limit[3]
        results[choice] = {'unapprovedExposedTerminal': 0, 'combinedFillOcclusion': combined, 'bounds': box}
    return {'sourceOpaqueIntrusionBeyondAA': 0, 'completeCasingFrozenMissingBeyondAA': 0,
            'toe': toe, 'centerLowerOpaqueLipSourceY': int(np.flatnonzero(a[135:,400] > 200)[0])+135,
            'terminalMaskSha256': contract['terminalMaskSha256'], 'caps': results}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    stage_runtime()
    recipe = json.loads((WORK / 'source-recipe.json').read_text())
    images = build(recipe, ROOT)
    sources = {}
    for name, image in images.items():
        source = WORK / 'Sources' / (name + '.png'); image.save(source); sources[name] = source
    source_replay = validate(recipe, sources, ROOT)
    caps = {k: read((SERRATED if k == 'serrated' else ROOT/'Assets/Rogue') / ('ornament-'+k+'-hp_cap_case.tga')) for k in ('twinguard','serrated','venom')}
    health = health_metrics(images['hp_cap_case-over'], caps)
    crystal = crystal_layers(images)
    own_ring = radial_morph(family_paintings(recipe['familyAuthority'], ROOT)['actionbutton-border'], recipe['buttonRadius'])
    button = button_metrics(images['actionbutton-border'], own_ring)
    assert button['actualIconApertureIntrusionBeyondAA'] == button['visibleMaskedIconCutEdgePixelsBelow200'] == 0
    full = Image.alpha_composite(read(ROOT/'Assets/Rogue/hp_cap_case.tga'), images['hp_cap_case-over'])
    images['hp_cap_case-glow'] = H.halo(full)
    for name, image in images.items():
        file = OUT / (name + '.tga'); image.save(file, compression=None)
        assert read(file).tobytes() == image.tobytes()
        assert file.read_bytes()[2] == 2 and file.read_bytes()[16] == 32
    for name in (CAP, CAP+'-glow'): shutil.copyfile(SERRATED/(name+'.tga'), OUT/(name+'.tga'))
    assets = {p.stem: {'sha256': sha(p), 'canvas': list(read(p).size)} for p in OUT.glob('*.tga')}
    write(OUT/'manifest.json', {'status': 'joint fitting candidate; visual/API layer review pending; NOT INSTALLED',
          'runtimeInstalled': False, 'productionAccepted': False, 'numericalPassed': True,
          'projectedRuntimeFitChecksPassed': True,
          'combinedNativeGlassAndContourOpacityCount': button['legacyTemplateIntrusionBeyondAA'], 'assets': assets})
    serrated_proof = json.loads((SERRATED/'source-integrity.json').read_text())['paintings'][CAP]
    paintings = {name: {'role': 'painting', 'source': record(path), 'transform': {'scale':1,'offset':[0,0]}} for name,path in sources.items()}
    paintings['actionbutton-border'].update(role='rogue-ring-native-glass-1', construction=record(WORK/'source-recipe.json'))
    paintings[CAP] = serrated_proof
    write(OUT/'source-integrity.json', {'schema':1,'assetManifestSha256':sha(OUT/'manifest.json'),'paintings':paintings})
    try:
        shared_gate = {'passed': True, **verify_pack(OUT)}
    except ValueError as error:
        shared_gate = {'passed': False, 'reason': str(error), 'legacyTemplateDiscrepancyNotWaived': True}
    old, new = F.Current(), Candidate()
    for scale in (1,2):
        scenes = [r.health(cap=cap, choice='serrated', fraction=f, prediction=f==.5, resource='crystal') for r in (old,new) for cap in (False,True) for f in (0,.5,1)]
        labels = [f'{label} / {"SERRATED" if cap else "NONE"} / {round(f*100)}%'+(' + synthetic prediction' if f==.5 else '') for label in ('INSTALLED','CANDIDATE') for cap in (False,True) for f in (0,.5,1)]
        for bg,color in (('dark','#22272d'),('light','#dba974')):
            J.sheet(scenes,labels,WORK/f'health-{bg}-{scale}x.png',f'JOINT FIT / full HUD / {scale}x',scale,color)
        J.sheet([r.health(cap=False,fraction=f) for r in (old,new) for f in (0,.5,1)],
                [f'{label} / {int(f*100)}%' for label in ('INSTALLED','CANDIDATE') for f in (0,.5,1)],WORK/f'bare-health-{scale}x.png',f'NO ENDCAP / {scale}x',scale)
        J.sheet([new.health(cap=k is not None,choice=k or 'serrated',fraction=.5,resource='crystal') for k in (None,'twinguard','serrated','venom')],
                ['None','Twin Guard','Serrated','Venom'],WORK/f'all-caps-{scale}x.png',f'ALL CAPS / {scale}x',scale,columns=2)
        J.sheet([new.health(flip=True,cap=cap,choice='serrated',fraction=f,prediction=f==.5) for cap in (False,True) for f in (0,.5,1)],
                [f'MIRRORED / {"SERRATED" if cap else "NONE"} / {int(f*100)}%'+(' + synthetic prediction' if f==.5 else '') for cap in (False,True) for f in (0,.5,1)],
                WORK/f'mirrored-{scale}x.png',f'MIRRORED HEALTH / fixed union viewport / {scale}x',scale)
        J.sheet([crystal_scene(r,f,ice,r is new) for r in (old,new) for ice in (False,True) for f in (0,.5,1)],
                [f'{label} / {"ICE" if ice else "NORMAL"} / {int(f*100)}%' for label in ('INSTALLED','CANDIDATE') for ice in (False,True) for f in (0,.5,1)],WORK/f'crystal-states-{scale}x.png',f'NORMAL + ICE / {scale}x / unchanged native facets',scale)
        J.sheet([button_scene(r,tile,cool) for r in (old,new) for tile,cool in (('ice',False),('grid',False),('grid',True))],
                [f'{label} / {state}' for label in ('INSTALLED','CANDIDATE') for state in ('Native ice icon','Square test pattern','Synthetic50% cooldown')],WORK/f'buttons-{scale}x.png',f'ICON44 + native circular mask / actual runtime sizes / {scale}x',scale)
    # One coherent representative at actual sizes, plus a2x copy. No minimap change.
    huds = [r.health(choice='serrated',fraction=.5,resource='crystal') for r in (old,new)]
    box = F.A.union(huds)
    focus = Image.new('RGBA',(1240,550),'#dba974')
    F.A.text(focus,'JOINT SOURCE FIT / OFFLINE CANDIDATE / NOT INSTALLED',(16,12),22)
    for i,r in enumerate((old,new)):
        x=16+i*610;F.A.text(focus,'INSTALLED V3' if i==0 else 'CANDIDATE + SERRATED REPAIR',(x,48),19)
        focus.alpha_composite(huds[i].crop(box),(x,80))
        for j in range(6):
            b=button_scene(r,'ice' if j%2==0 else 'grid')
            focus.alpha_composite(b,(x+j*84-42,300))
    focus.convert('RGB').save(WORK/'joint-review-1x.png')
    focus.resize((2480,1100),S).convert('RGB').save(WORK/'joint-review-2x.png')
    locked=json.loads((WORK/'input-lock.json').read_text())
    assert all((ROOT/p).is_file() and sha(ROOT/p)==h for p,h in locked.items()),'Current installed inputs changed'
    write(WORK/'construction.json', {'recipe':recipe,'sources':{n:record(p) for n,p in sources.items()},
          'validator':record(ROOT/'Tools/RogueFitClosureSource.py'),'orthogonalGridHelper':record(ROOT/'Tools/RogueSerratedMorph.py'),
          'originalFamilyHelper':record(ROOT/'Tools/RogueFamilySource.py'),'proof':source_replay})
    write(WORK/'review.json', {'status':'joint source-fit candidate, visual review pending, not installed',
          'health':health,'crystal':crystal,'button':button,
          'nativeButtonReference':button_metrics(read(ROOT/'Assets/actionbutton-border.tga')),
          'installedButtonReference':button_metrics(read(ROOT/'Assets/Rogue/actionbutton-border.tga')),
          'sharedSourceGate':shared_gate,'sourceReplay':source_replay,
          'protectedExistingInputsUnchanged':len(locked),'runtimeInstalled':False,'maintainerVisualApproved':False,
          'representativeLiveApproved':False,'productionAccepted':False,
          'runtimeProposal':record(WORK/'Runtime/baseline.json'),
          'limits':['Exact native glass and own paint verified separately; combined opacity counts retained as layer diagnostics.',
                    'Actual icon projection uses unchanged44px icon, native mask and134.295px border; source AA only.',
                    'Static default layout; effective client sampling, saved nudges, combat and all Forever tests unconfirmed.',
                    'Prediction/absorb textures and values unchanged; no live dynamic prediction or proc animation demonstrated.',
                    'Minimap and other tiers remain existing art. Crystal front/jaw contacts remain unchanged.'],
          'images':{p.name:sha(p) for p in WORK.glob('*.png')}})
    print(json.dumps({'health':health,'crystal':crystal,'button':button,'sharedSourceGate':shared_gate,'runtimeInstalled':False},indent=2))


if __name__ == '__main__':
    main()
