"""Render the Rogue representative from exported TGAs at native rectangles.

This is offline evidence. It never installs a theme or substitutes concept
crops for the exported textures. Rejected sources are explicitly labelled.
"""
from pathlib import Path
import argparse
import copy
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from ThemeHealthEndcaps import lowest_point

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'Docs/Research_Assets/Rogue'
OUT = ROOT / 'Assets_Draft/Rogue'


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


M = module('rogue_native_renderer', 'Build-ImplementedThemeSheets.py')


class Renderer(M.Renderer):
    def __init__(self):
        self.theme = 'Rogue'
        self.sources = {}
        self.media = {p.stem for p in OUT.glob('*.tga')}
        self.data = copy.deepcopy(M.DATA)
        self.replace(self.data)

    def asset(self, path):
        if path is None:
            return None
        relative = path.replace('\\', '/').split('/Assets/')[-1]
        source = OUT / relative.split('/', 1)[1] if relative.startswith('Rogue/') else ROOT / 'Assets' / relative
        self.sources[source.relative_to(ROOT).as_posix()] = M.hashlib.sha256(source.read_bytes()).hexdigest()
        return Image.open(source).convert('RGBA')

    def health(self, flip=False, cap=None, fraction=.5, prediction=True):
        db = self.config('TargetFrame' if flip else 'PlayerFrame')
        scene = Image.new('RGBA', (1300, 600))
        owner = (280, 200, *db['Size'])
        hp = M.B.anchor(owner, db['HealthBarSize'], db['HealthBarPosition'])
        casing = M.B.anchor(owner, db['HealthBackdropSize'], db['HealthBackdropPosition'])
        self.put(scene, self.own('hp_cap_case'), casing, flip)
        self.fill(scene, db['HealthBarTexture'], hp, 1, M.COLORS['dark'], flip)
        if prediction:
            self.fill(scene, db['HealthBarTexture'], hp, min(1, fraction+.2), (.25,.58,.65), flip)
        self.fill(scene, db['HealthBarTexture'], hp, fraction, M.COLORS['red'], flip)
        self.put(scene, self.own('hp_cap_case-over'), casing, flip)
        if cap is not None:
            self.put(scene, cap, casing, flip)
        return scene

    def cast(self, enabled=True, protected=False):
        db=self.data['PlayerCastBar']
        scene=Image.new('RGBA',(500,260))
        rect=(170,110,*db['CastBarSize'])
        family='CastBarShield' if protected else 'CastBarBackground'
        case='cast_back_spiked' if protected else 'cast_back'
        casing=M.B.anchor(rect,db[family+'Size'],db[family+'Position'])
        self.put(scene,self.own(case),casing)
        self.fill(scene,db['CastBarTexture'],rect,1,M.COLORS['dark'])
        self.fill(scene,db['CastBarTexture'],rect,.65,M.COLORS['green'])
        self.put(scene,self.own(case+'-over'),casing)
        if enabled:
            x,y,w,h=rect
            self.put(scene,self.own('cast-head'),(x-32,y+h/2-24,48,48))
        return scene


def candidate(source):
    """Diagnostic only: no acceptance, clipping, source edits or installation."""
    front = Image.open(OUT / 'hp_cap_case-over.tga').convert('RGBA')
    source = Image.open(WORK / 'Sources' / source).convert('RGBA')
    source = source.crop(source.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox())
    contract = json.loads((WORK / 'contract.json').read_text())['health']['hp_cap_case']
    height = contract['approvedEnvelope'][3] - contract['approvedEnvelope'][1]
    source = source.resize((round(source.width*height/source.height), height), Image.Resampling.LANCZOS)
    tx, ty = lowest_point(front)
    ax, ay = lowest_point(source)
    cap = Image.new('RGBA', front.size)
    cap.alpha_composite(source, (round(tx-ax), ty-ay))
    return cap


def label(board, text, x, y, size=18):
    ImageDraw.Draw(board).text((x,y), text, font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',size), fill='#d8d0bd')


def render(source=None):
    r = Renderer()
    cap = candidate(source) if source else r.own('ornament-twin-guard-hp_cap_case')
    status = 'REJECTED FIT / DIAGNOSTIC ONLY' if source else 'EXPORTED REPRESENTATIVE / OFFLINE'
    scenes = [[r.health(flip, cap if enabled else None) for enabled in (False,True)] for flip in (False,True)]
    boxes = [Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for im in pair])).getbbox() for pair in scenes]
    for scale in (1,2):
        board = Image.new('RGBA', (1000, 1100 if scale == 2 else 650), '#14161a')
        label(board, 'ROGUE - VENOM & STEEL / ' + status, 28, 22, 25)
        label(board, str(scale)+'x native layout. Shared fills. Fixed viewport and rail origins in each None/on pair.', 28, 68, 17)
        for side, pair in enumerate(scenes):
            for row, scene in enumerate(pair):
                y = 115 + (side*2+row)*(230 if scale==2 else 125)
                label(board, ('TARGET / MIRRORED' if side else 'PLAYER') + (' / TWIN GUARD' if row else ' / NONE'), 28, y)
                art = scene.crop(boxes[side])
                art = art.resize((art.width*scale, art.height*scale),Image.Resampling.LANCZOS)
                assert art.width+28 <= board.width and y+35+art.height <= board.height, 'Review clips complete bar'
                board.alpha_composite(art, (28,y+35))
        name = 'Rogue-rejected-' if source else 'Rogue-representative-'
        board.convert('RGB').save(WORK / (name+str(scale)+'x.png'))
    write = {'sources':r.sources, 'layoutExport':M.LAYOUT.relative_to(ROOT).as_posix(),
             'runtimeInstalled':False, 'liveValidated':False, 'status':status,
             'rejectedSource':source, 'method':'actual exported TGAs; synthetic fill/prediction; native layout rectangles'}
    (WORK / 'review-sources.json').write_text(json.dumps(write,indent=2)+'\n',encoding='utf-8')
    print(status + ': complete health bars rendered at 1x and 2x.')


def silhouette_guide(guarded=False):
    """Unpainted geometry proposal, never an export or accepted source asset."""
    contract = json.loads((WORK / 'contract.json').read_text())['health']['hp_cap_case']
    cap = candidate('twin-guard-v2.png')
    required = np.asarray(Image.open(ROOT / contract['terminalMask']).convert('L')) > 128
    body = (np.asarray(cap)[:,:,3] > 128) | required
    if guarded:
        # Repaint margin in the mounting BODY only, inside the unchanged
        # exterior bound. The original terminal mask remains immutable.
        expanded = np.asarray(Image.fromarray(required.astype('uint8')*255).filter(ImageFilter.MaxFilter(7))) > 0
        yy, xx = np.indices(body.shape)
        expanded &= yy < 185
        body |= expanded
    shape = Image.new('RGBA', cap.size, '#777b80')
    shape.putalpha(Image.fromarray((body*255).astype('uint8')))
    # The original required terminal is included byte for byte in this union.
    assert not (required & ~body).any()
    limit = contract['approvedEnvelope']
    bounds = shape.getchannel('A').getbbox()
    assert bounds[0]>=limit[0] and bounds[1]>=limit[1] and bounds[2]<=limit[2] and bounds[3]<=limit[3]
    crop = shape.crop((690,32,838,198)).resize((740,830),Image.Resampling.NEAREST)
    board=Image.new('RGBA',(1024,1024))
    board.alpha_composite(crop,(140,80))
    name = 'fixed-silhouette-body-margin.png' if guarded else 'proposed-fixed-silhouette.png'
    board.save(WORK / name)
    note={'status':'GEOMETRY TEMPLATE ONLY - NOT PAINTED ART OR APPROVED EXPORT',
          'base':'Sources/twin-guard-v2.png', 'terminalMaskSha256':contract['terminalMaskSha256'],
          'bounds':bounds, 'approvedEnvelope':limit,
          'method':'whole rejected silhouette union frozen original terminal; no mask shrink or source-art clipping',
          'next':'Contour-first method approved by maintainer 2026-10-26; unchanged terminal/footprint/toe acceptance still required.'}
    if guarded:
        note['bodyMarginSourcePixels'] = 3
        note['method'] = 'unpainted body extension within approved bound; original locked terminal unchanged; no scaling of weapon ornament'
    record = 'fixed-body-margin-method.json' if guarded else 'proposed-method.json'
    (WORK/record).write_text(json.dumps(note,indent=2)+'\n',encoding='utf-8')
    print('Proposed fixed silhouette saved; no new painting or generation.')


def cast_review():
    r=Renderer()
    scenes=[[r.cast(on,protected) for on in (False,True)] for protected in (False,True)]
    box=Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for row in scenes for im in row])).getbbox()
    board=Image.new('RGBA',(1000,920),'#14161a')
    label(board,'ROGUE / COMPLETE CAST / 100% / X=0 / Y=0',28,20,25)
    label(board,'Actual exported paint; normal + protected sockets. Shared 48px head slot. Offline.',28,65,16)
    for side,row in enumerate(scenes):
        for enabled,scene in enumerate(row):
            y=110+(side*2+enabled)*195
            label(board,('PROTECTED' if side else 'NORMAL')+(' / ON' if enabled else ' / NONE'),28,y)
            for col,scale in enumerate((1,2)):
                art=scene.crop(box)
                art=art.resize((art.width*scale,art.height*scale),Image.Resampling.LANCZOS)
                x=28+col*370
                assert x+art.width<=board.width and y+35+art.height<=board.height
                board.alpha_composite(art,(x,y+35))
    board.convert('RGB').save(WORK/'Rogue-cast-defaults.png')
    print('Complete normal/protected casts rendered with fixed rail origin at 1x/2x.')


def ornament_guides():
    contract=json.loads((WORK/'contract.json').read_text())['health']
    reference=contract['hp_cap_case']
    union=np.zeros((256,1024),dtype=bool)
    for case,item in contract.items():
        mask=Image.open(ROOT/item['terminalMask']).convert('L')
        height=item['approvedEnvelope'][3]-item['approvedEnvelope'][1]
        scale=136/height
        tx,ty=item['dip'];rx,ry=reference['dip']
        normal=mask.transform((1024,256),Image.Transform.AFFINE,
                              (1/scale,0,tx-rx/scale,0,1/scale,ty-ry/scale),
                              Image.Resampling.NEAREST)
        union |= np.asarray(normal)>128
    expanded=union.copy()
    # Additional source-art body width, not ornament scale. The unchanged
    # original masks and exterior bounds remain independent acceptance gates.
    for shift in range(-13,4):
        if shift<0:
            expanded[:,:shift] |= union[:,-shift:]
        elif shift>0:
            expanded[:,shift:] |= union[:,:-shift]
    expanded=np.asarray(Image.fromarray(expanded.astype('uint8')*255).filter(ImageFilter.MaxFilter(7)))>0
    expanded[185:]=union[185:]
    polygons={
        'twin-guard-tiers':None,
        'serrated':[(799,53),(815,73),(807,90),(818,106),(807,124),(804,146),(774,170),(754,187),(742,179),(718,165),(711,145),(711,82)],
        'venom-vial':[(782,52),(798,52),(806,65),(806,72),(818,90),(818,143),(800,164),(774,177),(754,187),(735,175),(711,165),(705,148),(705,82),(730,80),(760,67),(782,65)]}
    records={}
    for key,polygon in polygons.items():
        if polygon is None:
            field=np.asarray(candidate('twin-guard-fixed-v2.png'))[:,:,3]>128
        else:
            field_image=Image.new('L',(1024,256));ImageDraw.Draw(field_image).polygon(polygon,fill=255)
            field=np.asarray(field_image)>128
        body=field|expanded
        assert not (union&~body).any()
        image=Image.new('RGBA',(1024,256),'#777b80');image.putalpha(Image.fromarray(body.astype('uint8')*255))
        b=image.getchannel('A').getbbox();limit=reference['approvedEnvelope']
        assert b[0]>=limit[0] and b[1]>=limit[1] and b[2]<=limit[2] and b[3]<=limit[3],(key,b,limit)
        crop=image.crop((690,32,838,198)).resize((740,830),Image.Resampling.NEAREST)
        board=Image.new('RGBA',(1024,1024));board.alpha_composite(crop,(140,80))
        path=WORK/(key+'-fixed-template.png');board.save(path)
        records[key]={'bounds':b,'templateSha256':M.hashlib.sha256(path.read_bytes()).hexdigest(),
                      'geometryOnly':True,'allNativeTerminalsNormalized':True}
    (WORK/'ornament-guide-contracts.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
    print('Three unpainted motif guides cover the full four-tier terminal union with a compact body margin.')


def twin_edit_guide():
    source=Image.open(WORK/'Sources/twin-guard-tiers.png').convert('RGBA')
    bbox=source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    art=source.crop(bbox)
    contracts=json.loads((WORK/'contract.json').read_text())['health']
    required=np.zeros((source.height,source.width),dtype=bool)
    for case,item in contracts.items():
        if case=='hp_cap_case':
            continue
        height=item['approvedEnvelope'][3]-item['approvedEnvelope'][1]
        piece=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
        ax,ay=lowest_point(piece);tx,ty=item['dip'];x,y=round(tx-ax),ty-ay
        field=Image.open(ROOT/item['terminalMask']).convert('L')
        scale_x,scale_y=piece.width/art.width,piece.height/art.height
        mapped=field.transform(source.size,Image.Transform.AFFINE,
                               (scale_x,0,x-bbox[0]*scale_x,0,scale_y,y-bbox[1]*scale_y),
                               Image.Resampling.NEAREST)
        required |= np.asarray(mapped)>128
    missing=required & (np.asarray(source)[:,:,3]<240)
    p=np.array(source);p[missing]=[225,45,154,255]
    Image.fromarray(p).save(WORK/'twin-guard-tiers-edit-guide.png')
    (WORK/'twin-guard-tiers-edit-guide.json').write_text(json.dumps({
        'geometryOnly':True,'sourceSha256':M.hashlib.sha256((WORK/'Sources/twin-guard-tiers.png').read_bytes()).hexdigest(),
        'missingHDPixelsMarked':int(missing.sum()),'changesFrozenMasks':False},indent=2)+'\n',encoding='utf-8')
    print('Source-space guide marks missing mounting paint; original source and native contracts unchanged.')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rejected-source')
    parser.add_argument('--silhouette-guide',action='store_true')
    parser.add_argument('--body-margin-guide',action='store_true')
    parser.add_argument('--cast',action='store_true')
    parser.add_argument('--ornament-guides',action='store_true')
    parser.add_argument('--twin-edit-guide',action='store_true')
    args=parser.parse_args()
    if args.twin_edit_guide:
        twin_edit_guide()
    elif args.ornament_guides:
        ornament_guides()
    elif args.cast:
        cast_review()
    elif args.silhouette_guide or args.body_margin_guide:
        silhouette_guide(args.body_margin_guide)
    else:
        render(args.rejected_source)
