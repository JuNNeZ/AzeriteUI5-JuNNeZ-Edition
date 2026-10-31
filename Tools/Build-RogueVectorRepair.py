"""Approved measured vector-source Rogue representative. Drafts only.

Native art supplies geometry measurements, never RGB or an alpha stencil for
an existing painting. All steel/leather/brass faces are newly authored vectors.
The editable scene, SVG and high-resolution source raster are retained.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import random
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from ThemeHealthEndcaps import lowest_point, terminal_coverage, terminal_mask
from ThemeSourceIntegrity import aperture, whole_painting, verify_pixels, verify_pack

ROOT = Path(__file__).resolve().parent.parent
OLD = ROOT/'Docs/Research_Assets/Rogue/Source-Rebuild-2026-10-29'
WORK = ROOT/'Docs/Research_Assets/Rogue/Vector-Repair-2026-10-30'
OUT = ROOT/'Assets_Draft/Rogue-Vector-Repair-2026-10-30'
SCALE = 4
REVISION = 1
CRYSTAL_REVIEW = ROOT/'Docs/Research_Assets/Rogue/Vector-Repair-2026-10-30'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def write(path, data):
    path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Tools'/file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def spans(field):
    result = {}
    for x in np.flatnonzero(field.any(0)):
        rows = np.flatnonzero(field[:, x])
        result[int(x)] = (int(rows[0]), int(rows[-1])+1)
    return result


def scene():
    contract = json.loads((ROOT/'Docs/Research_Assets/Rogue/contract.json').read_text())['health']['hp_cap_case']
    native_path = ROOT/'Assets/hp_cap_case.tga'
    terminal_path = ROOT/contract['terminalMask']
    assert sha(native_path) == contract['nativeSha256']
    assert sha(terminal_path) == contract['terminalMaskSha256']
    native = read(native_path)
    geometry = spans(np.asarray(native)[:, :, 3] > 128)
    fill_path = ROOT/'Docs/Research_Assets/Templates/hp_cap_case-fill.png'
    # V1 left an extra source pixel of clearance. V2 authors the complete inner
    # lip directly at the measured fill contour. No painted pixels are erased.
    fill = Image.open(fill_path).convert('L')
    if REVISION == 1:
        fill = fill.filter(ImageFilter.MaxFilter(3))
    opening = spans(np.asarray(fill) > 128)
    faces = []

    def polygon(points, color, material):
        faces.append({'points': points, 'fill': color, 'material': material})

    def strip(x, lo, hi, colors, material):
        if hi <= lo:
            return
        cuts = (lo, lo+(hi-lo)*.18, lo+(hi-lo)*.76, hi)
        for i, color in enumerate(colors):
            polygon([(x,cuts[i]), (x+1,cuts[i]), (x+1,cuts[i+1]), (x,cuts[i+1])], color, material)

    for x, (top, bottom) in geometry.items():
        if x in opening:
            inner_top, inner_bottom = opening[x]
            strip(x, top, inner_top, ('#727b7e','#303537','#525c60'), 'steel-upper-rail')
            strip(x, inner_bottom, bottom, ('#697275','#292e30','#101619'), 'steel-lower-rail')
        else:
            strip(x, top, bottom, ('#697476','#303638','#141b1d'), 'steel-closed-end')

    # Large hand-cut planes and restrained highlights. Clipped only to the
    # vector construction's own union, like ordinary editable vector artwork.
    details = []
    def detail(points, color, material):
        details.append({'points': points, 'fill': color, 'material': material})

    for left, right in ((255,386),(393,494),(502,618),(625,710)):
        detail([(left,83),(right-7,83),(right,87),(left+9,88)], '#454e51', 'broad-steel-facet')
        detail([(left+10,159),(right-4,158),(right,163),(left+3,165)], '#394245', 'broad-steel-facet')
        detail([(left+17,90),(left+47,90),(left+40,91),(left+12,91)], '#596164', 'hammered-edge')
        detail([(left+23,163),(left+64,162),(left+53,163),(left+19,164)], '#596264', 'hammered-edge')
        # Broken planes, small chips and diagonal seams are individually drawn,
        # never sampled/extruded from an old texture's RGB edge.
        detail([(left,88),(left+17,88),(left+30,94),(right-10,93),(right-14,97),(left+5,97)], '#24292c', 'recessed-steel-plane')
        detail([(left+2,148),(right-10,148),(right-17,152),(left+25,153)], '#465154', 'lower-inner-facet')
        detail([(right-7,81),(right-4,82),(right-13,94),(right-8,98),(right-11,98),(right-16,94)], '#11191c', 'slab-fracture')
        detail([(right-3,82),(right-2,84),(right-11,94),(right-7,97),(right-8,97),(right-13,94)], '#838e8f', 'fracture-lit-lip')
        detail([(left+13,156),(left+23,158),(left+29,166),(left+26,167),(left+20,160)], '#131b1e', 'lower-slab-fracture')
    for x in (367,508,650):
        detail([(x-11,81),(x-1,68),(x-1,83)], '#7c888a', 'stud-left-bevel')
        detail([(x,68),(x+11,80),(x+2,85)], '#272f32', 'stud-front-plane')
        detail([(x,69),(x+1,81),(x+9,82),(x+13,85),(x-1,85)], '#4e5b5e', 'stud-descending-facet')
    rng = random.Random(301026)
    for _ in range(180):
        x = rng.uniform(250,716)
        y = rng.choice((rng.uniform(84,97),rng.uniform(147,166)))
        length = rng.uniform(.7,3.2)
        color = rng.choice(('#454e51','#4a5558','#20282b','#1b2326'))
        detail([(x,y),(x+length,y-.5),(x+length-.3,y),(x-.3,y+.4)], color, 'hand-hammered-grain')
    # Fresh end facets follow the measured complete closed construction.
    detail([(214,122),(235,84),(240,89),(224,123),(239,163),(233,164)], '#667174', 'left-bevel')
    detail([(790,70),(807,111),(798,117),(781,81)], '#657174', 'right-upper-bevel')
    detail([(798,117),(809,114),(760,184),(755,184)], '#3f4c50', 'right-descending-bevel')
    detail([(719,167),(751,185),(757,185),(736,170)], '#606d70', 'right-inner-heel')
    for x in (302,686):
        if REVISION == 1:
            detail([(x-6,79),(x+9,79),(x+5,99),(x-10,99)], '#756646', 'leather-brass-edge')
            detail([(x-4,80),(x+6,80),(x+2,98),(x-8,98)], '#3d402c', 'olive-leather')
            detail([(x-4,82),(x-2,82),(x-5,96),(x-7,96)], '#687052', 'leather-worn-edge')
            detail([(x-9,145),(x+5,145),(x+13,169),(x-1,169)], '#716244', 'leather-brass-edge')
            detail([(x-6,146),(x+3,146),(x+10,168),(x+1,168)], '#3c402c', 'olive-leather')
            detail([(x-5,147),(x-3,147),(x+4,166),(x+2,166)], '#656c4f', 'leather-worn-edge')
        else:
            # Concept-sized leather construction. Full authored faces are kept;
            # the same vector rail union bounds all fittings outside the meter.
            detail([(x-13,79),(x+19,79),(x+14,101),(x-18,101)], '#85734b', 'leather-brass-edge')
            detail([(x-10,80),(x+15,80),(x+10,100),(x-15,100)], '#535b37', 'olive-leather')
            detail([(x-9,81),(x-5,81),(x-10,99),(x-14,99)], '#87916a', 'leather-worn-edge')
            detail([(x+11,82),(x+14,82),(x+10,98),(x+7,98)], '#343b26', 'leather-fold-shadow')
            detail([(x-17,142),(x+15,142),(x+23,169),(x-9,169)], '#7b6946', 'leather-brass-edge')
            detail([(x-13,143),(x+12,143),(x+19,168),(x-6,168)], '#515a35', 'olive-leather')
            detail([(x-12,144),(x-8,144),(x-1,167),(x-5,167)], '#818c62', 'leather-worn-edge')
            detail([(x+8,145),(x+11,145),(x+17,166),(x+14,166)], '#343c25', 'leather-fold-shadow')
    rivets = []
    for x, y in ((302,88),(306,158),(686,88),(690,158)):
        factor = 1 if REVISION == 1 else 1.3
        rivets.append({'center':[x,y], 'radius':3.2*factor, 'fill':'#171c19', 'material':'rivet-shadow'})
        rivets.append({'center':[x-.3,y-.4], 'radius':2.4*factor, 'fill':'#9b8050', 'material':'brass-rivet'})
        rivets.append({'center':[x-.8,y-1], 'radius':1.1*factor, 'fill':'#c2ac76', 'material':'rivet-top-light'})
    return {'canvas':[1024,256], 'rasterScale':SCALE,
            'geometryReference':{'path':native_path.relative_to(ROOT).as_posix(), 'sha256':sha(native_path),
                                 'terminalMaskSha256':sha(terminal_path), 'fillSha256':sha(fill_path)},
            'sourceMethod':'New measured vector faces; original pixels provide geometry only, no RGB/alpha paint transfer',
            'approval':'Ja, brug den målfaste vektorkilde',
            'faces':faces, 'detailsClippedToVectorFaces':details, 'rivetsClippedToVectorFaces':rivets}


def rasterize(data):
    size = tuple(v*SCALE for v in data['canvas'])
    painting = Image.new('RGBA', size)
    draw = ImageDraw.Draw(painting)
    mask = Image.new('L', size)
    md = ImageDraw.Draw(mask)
    for face in data['faces']:
        points = [(round(x*SCALE), round(y*SCALE)) for x,y in face['points']]
        draw.polygon(points, fill=face['fill'])
        md.polygon(points, fill=255)
    details = Image.new('RGBA', size)
    dd = ImageDraw.Draw(details)
    for face in data['detailsClippedToVectorFaces']:
        dd.polygon([(round(x*SCALE),round(y*SCALE)) for x,y in face['points']], fill=face['fill'])
    for rivet in data['rivetsClippedToVectorFaces']:
        x,y = rivet['center']; r = rivet['radius']
        dd.ellipse(tuple(round(v*SCALE) for v in (x-r,y-r,x+r,y+r)), fill=rivet['fill'])
    # This is the vector source's own construction clip, not native raster alpha
    # imposed on a painting. SVG uses the same editable face union as clipPath.
    details.putalpha(Image.fromarray(np.minimum(np.asarray(details)[:,:,3], np.asarray(mask))))
    return Image.alpha_composite(painting, details)


def svg(data):
    namespace = 'http://www.w3.org/2000/svg'
    ET.register_namespace('', namespace)
    root = ET.Element('svg', xmlns=namespace, width='4096', height='1024', viewBox='0 0 1024 256')
    defs = ET.SubElement(root, 'defs')
    clip = ET.SubElement(defs, 'clipPath', id='authored-face-union')
    def poly(parent, face):
        return ET.SubElement(parent, 'polygon', points=' '.join(f'{x},{y}' for x,y in face['points']), fill=face['fill'])
    for face in data['faces']:
        poly(root, face); poly(clip, face)
    details = ET.SubElement(root, 'g', {'clip-path':'url(#authored-face-union)'})
    for face in data['detailsClippedToVectorFaces']:
        poly(details, face)
    for item in data['rivetsClippedToVectorFaces']:
        ET.SubElement(details,'circle',cx=str(item['center'][0]),cy=str(item['center'][1]),r=str(item['radius']),fill=item['fill'])
    ET.ElementTree(root).write(WORK/f'Sources/health-vector-v{REVISION}.svg', encoding='utf-8', xml_declaration=True)


def review_renderer(draft=None):
    draft = draft or OUT
    render = module('rogue_vector_contact_renderer','Render-RogueSuite.py')
    class Review(render.Renderer):
        def asset(self,path):
            if path is not None and '/Rogue/' in path.replace('\\','/'):
                name = Path(path.replace('\\','/')).stem
                return read((draft if name in ('hp_cap_case','hp_cap_case-over','pw_crystal_case') else ROOT/'Assets/Rogue')/(name+'.tga'))
            return super().asset(path)
    return render, Review()


def render_contacts():
    render, r = review_renderer()
    plain = r.resource('crystal',1)
    marked = plain.copy()
    db = r.config()
    owner = (200,150,*db['Size'])
    rect = render.B.anchor(owner,db['PowerBackdropSize'],db['PowerBarPosition'])
    case_rect = render.B.anchor(rect,db['PowerBarForegroundSize'],db['PowerBarForegroundPosition'])
    contact = Image.new('RGBA',(256,128),'#ff3296')
    contact.putalpha(Image.open(WORK/'crystal-contact-proposal.png').convert('L'))
    r.put(marked,contact,case_rect)
    box = plain.getbbox()
    page = Image.new('RGB',(1100,650),'#59616d')
    draw = ImageDraw.Draw(page)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    draw.text((20,16),'WHOLE CRYSTAL HOLDER / NATIVE RECTANGLES / CONTACT REVIEW ONLY',font=font,fill='white')
    for x,scene,label in ((20,plain,'Complete painting'),(550,marked,'Pink: jaws over crystal fill')):
        draw.text((x,62),label,font=font,fill='white')
        art = scene.crop(box).resize(((box[2]-box[0])*2,(box[3]-box[1])*2),Image.Resampling.LANCZOS)
        assert art.width<=510 and art.height<=500
        page.paste(art,(x,100),art)
    status = 'crystal source accepted; health review pending' if REVISION == 2 else 'original proposal review'
    draw.text((20,606),'216 source pixels / 2.88% of crystal fill / '+status,font=font,fill='white')
    page.save(WORK/'crystal-contact-review.png')


def render_health_fit():
    _, previous = review_renderer(ROOT/'Assets_Draft/Rogue-Vector-Repair-2026-10-30')
    _, current = review_renderer()
    scenes = [[renderer.health(cap=False,fraction=value) for value in (0,.5,1)] for renderer in (previous,current)]
    union = Image.fromarray(np.maximum.reduce([np.asarray(s)[:,:,3] for row in scenes for s in row])).getbbox()
    page = Image.new('RGB',(1500,410),'#59616d')
    draw = ImageDraw.Draw(page)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
    draw.text((20,15),'ACTUAL EXPORTED HEALTH / 1x / SAME RAIL ORIGIN / NO CRYSTAL OR CAP HIDING THE FIT',font=font,fill='white')
    for row,label in enumerate(('REJECTED V1 / small straps + one-pixel clearance','REVISED V2 / wider straps + inner lip at fill contour')):
        top = 72+row*165
        for col,value in enumerate((0,.5,1)):
            x = 20+col*495
            draw.text((x,top),str(round(value*100))+'% / '+('V1' if row==0 else 'V2'),font=small,fill='white')
            art = scenes[row][col].crop(union)
            assert art.width<=475 and art.height<=125
            page.paste(art,(x,top+28),art)
        draw.text((20,top+126),label,font=small,fill='white')
    page.save(WORK/'health-fit-review.png')


def main():
    global REVISION, WORK, OUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision',type=int,choices=(1,2),default=2)
    args = parser.parse_args()
    REVISION = args.revision
    if REVISION == 2:
        WORK = ROOT/'Docs/Research_Assets/Rogue/Vector-Repair-v2-2026-10-30'
        OUT = ROOT/'Assets_Draft/Rogue-Vector-Repair-v2-2026-10-30'
    (WORK/'Sources').mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    # Lock installed art before doing any source work. No production copy path.
    installed = {p.name:sha(p) for p in (ROOT/'Assets/Rogue').glob('*.tga')}
    data = scene()
    write(WORK/f'Sources/health-vector-v{REVISION}.scene.json', data)
    svg(data)
    source_path = WORK/f'Sources/health-vector-v{REVISION}.png'
    source = rasterize(data)
    source.save(source_path)
    reloaded_scene = json.loads((WORK/f'Sources/health-vector-v{REVISION}.scene.json').read_text())
    assert rasterize(reloaded_scene).tobytes() == read(source_path).tobytes(), 'Editable scene raster replay differs'
    health_transform = {'scale':.25, 'offset':[0,0]}
    health = whole_painting(read(source_path), health_transform, (1024,256))
    crystal_path = OLD/'Sources/crystal-v1.png'
    crystal_transform = {'crop':[199,190,1601,703], 'scale':177/1402, 'offset':[39,26]}
    crystal = whole_painting(read(crystal_path), crystal_transform, (256,128))
    native_path = ROOT/'Assets/hp_cap_case.tga'
    native = read(native_path)
    fill_path = ROOT/'Docs/Research_Assets/Templates/hp_cap_case-fill.png'
    fill = np.asarray(Image.open(fill_path).convert('L')) > 128
    pixels = np.zeros_like(np.asarray(native)); pixels[fill] = np.asarray(native)[fill]
    assets = {}
    for name, painting in (('hp_cap_case',Image.fromarray(pixels)),('hp_cap_case-over',health),('pw_crystal_case',crystal)):
        path = OUT/(name+'.tga'); painting.save(path, compression=None)
        verify_pixels(painting, read(path))
        assert painting.tobytes() == read(path).tobytes(), 'TGA RGBA roundtrip changed pixels'
        assert path.read_bytes()[2] == 2 and path.read_bytes()[16] == 32
        assets[name] = {'sha256':sha(path), 'canvas':list(painting.size)}
    write(OUT/'manifest.json', {'assets':assets})
    def record(path):
        return {'path':path.relative_to(ROOT).as_posix(), 'sha256':sha(path)}
    crystal_record = {'role':'painting','source':record(crystal_path),'transform':crystal_transform}
    if REVISION == 2:
        approval_path = CRYSTAL_REVIEW/'crystal-visual-approval.json'
        bridge_path = CRYSTAL_REVIEW/'crystal-contact-proposal.png'
        approval = json.loads(approval_path.read_text(encoding='utf-8'))
        assert approval['maintainerApproved'] is True
        assert approval['sourceSha256'] == sha(crystal_path) and approval['bridgeSha256'] == sha(bridge_path)
        crystal_record.update({'bridge':record(bridge_path),'bridgeApproval':record(approval_path)})
    write(OUT/'source-integrity.json', {'schema':1,'assetManifestSha256':sha(OUT/'manifest.json'), 'paintings':{
        'hp_cap_case':{'role':'functional-recess','source':record(native_path)},
        'hp_cap_case-over':{'role':'painting','source':record(source_path),'transform':health_transform},
        'pw_crystal_case':crystal_record}})
    try:
        integrity = {'passed':True, **verify_pack(OUT)}
    except ValueError as error:
        integrity = {'passed':False,'error':str(error)}
    coverage = {}
    frozen_path = ROOT/'Docs/Research_Assets/Rogue/Masks/hp_cap_case-terminal.png'
    frozen = np.asarray(Image.open(frozen_path).convert('L')) > 128
    new_terminal = np.asarray(terminal_mask(health)) > 128
    assert not (new_terminal & ~frozen).any(), 'New metal extends outside the frozen whole terminal'
    for choice in ('twinguard','serrated','venom'):
        cap = read(ROOT/'Assets/Rogue'/('ornament-'+choice+'-hp_cap_case.tga'))
        current = terminal_coverage(health,cap)
        opaque = np.asarray(cap)[:,:,3] >= 240
        expanded = np.asarray(Image.fromarray(opaque.astype('uint8')*255).filter(ImageFilter.MaxFilter(3))) > 0
        yy,xx = np.where(frozen & ~expanded)
        coverage[choice] = {'actualPainting':current,
            'frozenTerminalPixels':int(frozen.sum()),
            'frozenExposedPixelsBeyondAA':len(xx),
            'frozenExposedCoordinates':[[int(x),int(y)] for x,y in zip(xx,yy)]}
    aperture_checks = {}
    for name,image in (('hp_cap_case-over',health),('pw_crystal_case',crystal)):
        field_path = ROOT/'Docs/Research_Assets/Templates'/(name.removesuffix('-over')+'-fill.png')
        field = Image.open(field_path).convert('L')
        try:
            bridge = Image.open(CRYSTAL_REVIEW/'crystal-contact-proposal.png') if name == 'pw_crystal_case' and REVISION == 2 else None
            aperture(image,field,bridge)
            aperture_checks[name] = {'passed':True}
        except ValueError as error:
            aperture_checks[name] = {'passed':False,'error':str(error)}
        overlap = (np.asarray(image)[:,:,3] > 200) & (np.asarray(field)>128)
        aperture_checks[name].update({'overlapPixels':int(overlap.sum()),
            'overlapFraction':float(overlap.sum()/(np.asarray(field)>128).sum())})
        if name == 'pw_crystal_case':
            # Proposal only: no bridgeApproval sidecar or pass is fabricated.
            Image.fromarray(overlap.astype('uint8')*255).save(WORK/'crystal-contact-proposal.png')
            aperture_checks[name]['proposedContactMaskSha256'] = sha(WORK/'crystal-contact-proposal.png')
            aperture_checks[name]['maintainerBridgeApproved'] = REVISION == 2
    alpha = np.asarray(health)[:,:,3]
    report = {'runtimeInstalled':False,'productionAccepted':False,'sourceIntegrity':integrity,
              'sourceConstruction':{name:sha(WORK/'Sources'/name) for name in
                  (f'health-vector-v{REVISION}.scene.json',f'health-vector-v{REVISION}.svg',f'health-vector-v{REVISION}.png')},
              'revision':REVISION,
              'innerLipExtraSourcePixelClearance':1 if REVISION == 1 else 0,
              'strapFaceWidthSourcePixels':15 if REVISION == 1 else 32,
              'crystalMatchesPriorDraftExactly':sha(OUT/'pw_crystal_case.tga')==sha(ROOT/'Assets_Draft/Rogue-Vector-Repair-2026-10-30/pw_crystal_case.tga'),
              'editableSceneRasterReplayExact':True,'builderSha256':sha(Path(__file__)),
              'nativeDip':lowest_point(native),'candidateDip':lowest_point(health),
              'fillOverlapFraction':float(((alpha>200)&fill).sum()/fill.sum()),
              'capCoverage':coverage,'apertureChecks':aperture_checks,
              'frozenTerminalMaskSha256':sha(frozen_path),'newMetalOutsideFrozenTerminal':0,'codecRGBAExact':True,
              'installedRogueUnchanged':all(sha(ROOT/'Assets/Rogue'/name)==digest for name,digest in installed.items()),
              'installedRogueTexturesChecked':len(installed),
              'approval':'Ja, brug den målfaste vektorkilde','maintainerVisualApproved':False,'liveValidated':False}
    assert report['installedRogueUnchanged']
    write(WORK/'review-manifest.json',report)
    preview = module('rogue_vector_preview','Preview-RogueSourceRepair.py')
    preview.WORK = WORK; preview.OUT = OUT
    preview.render('REVISED HEALTH + ACCEPTED CRYSTAL / health visual review pending' if REVISION == 2 else
                   'VECTOR HEALTH + WHOLE CRYSTAL / original rejected health draft')
    render_contacts()
    if REVISION == 2:
        render_health_fit()
    write(WORK/'review-images.json',{name:sha(WORK/name) for name in
        ('assembled-1x.png','assembled-2x.png','complete-bars.png','fill-states.png','crystal-contact-review.png')+
        (('health-fit-review.png',) if REVISION == 2 else ())})
    print(json.dumps(report,indent=2))


if __name__ == '__main__':
    main()
