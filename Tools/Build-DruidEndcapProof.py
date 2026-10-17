"""Three review-only Druid endcaps, registered to the actual casing dip.

Writes only the research folder. Does not install textures or change Lua.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT/'Docs/Research_Assets/Druid/Endcap-Proof-2026-10-17'
EXPORT = OUT/'Aligned-Export'
S = Image.Resampling.LANCZOS
VARIANTS = {'antler':'Gevir', 'bear':'Bjørn', 'owl':'Ugle'}
CASES = {'Novice':'hp_low_case', 'Hardened':'hp_mid_case',
         'Seasoned':'hp_cap_case', 'Boss':'hp_boss_case'}


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT/'Tools'/file)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


R = module('proof_review', 'Render-FittedEndcaps.py')
M = module('proof_art', 'Build-RebuiltHealthArt.py')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    EXPORT.mkdir(exist_ok=True)
    files = {}
    sources = {}
    caps = {}
    registrations = []

    def dip(image):
        opaque = np.asarray(image)[:, :, 3] > 128
        y = int(np.where(opaque)[0].max())
        x = float(np.median(np.flatnonzero(opaque[y])))
        return x, y

    def save(name, image):
        path = EXPORT/(name+'.tga')
        image.save(path)
        files[path.name] = sha(path)

    for key in VARIANTS:
        source = OUT/(key+'-source.png')
        painting = Image.open(source).convert('RGBA')
        caps[key] = painting.crop(M.bounds(painting))
        sources[source.name] = sha(source)
    for name in M.HEALTH:
        front = M.read(ROOT/'Assets/Druid'/(name+'-over.tga'))
        tx, ty = dip(front)
        # Keep the existing material size. Only translate the intact painting
        # until its bottom point coincides with the casing's measured point.
        # Both textures use the SAME native backdrop canvas/rectangle, so this
        # remains aligned on player, target, all tiers and horizontal mirrors.
        height = 133 if name == 'hp_boss_case' else 136 if name == 'hp_cap_case' else 126
        for key, source_art in caps.items():
            factor = height/source_art.height
            art = source_art.resize((round(source_art.width*factor),height), S)
            ax, ay = dip(art)
            left, top = round(tx-ax), ty-ay
            assert left >= 0 and top >= 0
            assert left+art.width <= front.width and top+art.height <= front.height
            cap = Image.new('RGBA',front.size)
            cap.alpha_composite(art,(left,top))
            px, py = dip(cap)
            assert abs(px-tx) <= .5 and py == ty, (key,name,'misaligned point')
            # The two lowest silhouettes must share a literal opaque pixel,
            # and the ornament must not introduce a second, lower ending.
            fa = np.asarray(front)[:,:,3] > 128
            ca = np.asarray(cap)[:,:,3] > 128
            assert np.any(fa[ty] & ca[ty]), (key,name,'points do not overlap')
            assert not ca[ty+1:].any(), (key,name,'second lower tip')
            save('ornament-'+key+'-'+name,cap)
            save('ornament-'+key+'-'+name+'-glow',M.halo(cap))
            registrations.append({'variant':key,'casing':name,'dip':[tx,ty],
                                  'capPoint':[px,py],'translation':[left,top],
                                  'wholeArtSize':list(art.size),'maxNativePixelError':abs(px-tx)})

    def render(key=None, fraction=1, flip=False, tier='Seasoned'):
        base = R.DATA['original']['TargetFrame' if flip else 'PlayerFrame']
        db = dict(base)
        db.update(base[tier])
        owner = (300 if flip else 100,60,*base['Size'])
        hp = R.B.anchor(owner,db['HealthBarSize'],db['HealthBarPosition'])
        casing = R.B.anchor(owner,db['HealthBackdropSize'],db['HealthBackdropPosition'])
        name = CASES[tier]
        scene = Image.new('RGBA',(1200,350))
        # No shoulder cut: None and every cap share the identical complete bar.
        R.B.put(scene,M.read(ROOT/'Assets/Druid'/(name+'.tga')),casing,flip)
        R.B.fill(scene,db['HealthBarTexture'],hp,1,(.09,.08,.11),flip)
        R.B.fill(scene,db['HealthBarTexture'],hp,fraction,(.84,.03,.08),flip)
        R.B.put(scene,M.read(ROOT/'Assets/Druid'/(name+'-over.tga')),casing,flip)
        if key:
            R.B.put(scene,M.read(EXPORT/('ornament-'+key+'-'+name+'.tga')),casing,flip)
        if flip:
            portrait = Path(db['PortraitBorderTexture'].replace('\\','/')).stem
            R.B.put(scene,R.read('Druid',portrait),R.B.anchor(owner,db['PortraitBorderSize'],db['PortraitBorderPosition']))
        # Identical viewport for None/all variants: a cap must not make the
        # comparison move the underlying bar or target portrait on the page.
        common = scene.copy()
        for variant in VARIANTS:
            R.B.put(common,M.read(EXPORT/('ornament-'+variant+'-'+name+'.tga')),casing,flip)
        return scene.crop(common.getbbox())

    joints = []
    for kind in ('PlayerFrame', 'TargetFrame'):
        base = R.DATA['original'][kind]
        flip = kind == 'TargetFrame'
        for tier in ('Novice', 'Hardened', 'Seasoned', 'Boss'):
            if tier not in base:
                continue
            db = dict(base)
            db.update(base[tier])
            hp = R.B.anchor((150, 60, *base['Size']), db['HealthBarSize'], db['HealthBarPosition'])
            case = R.B.anchor((150, 60, *base['Size']), db['HealthBackdropSize'], db['HealthBackdropPosition'])
            native = CASES[tier]
            rail = M.read(ROOT/'Assets/Druid'/(native+'-over.tga'))
            mask = Image.open(ROOT/'Docs/Research_Assets/Templates'/(native+'-fill.png')).convert('L')
            if flip:
                rail = rail.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                mask = mask.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            x, y, w, h = hp
            cx, cy, cw, ch = case
            for key in caps:
                fitted = M.read(EXPORT/('ornament-'+key+'-'+native+'.tga'))
                if flip:
                    fitted = fitted.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                inside = np.asarray(mask) > 128
                a = np.asarray(fitted)[:, :, 3] > 200
                covered = np.count_nonzero(a & inside)/np.count_nonzero(inside)
                assert covered <= .20, (key, kind, tier, covered)
                ra = np.asarray(rail)[:, :, 3] > 128
                assert np.any(a & ra), (key, kind, tier, 'detached')
                tip_x, tip_y = dip(rail)
                cap_x, cap_y = dip(fitted)
                assert abs(tip_x-cap_x) <= .5 and tip_y == cap_y
                joints.append({'variant':key,'unit':kind,'tier':tier,'fillCovered':round(covered, 5),
                               'dip':[tip_x,tip_y],'capPoint':[cap_x,cap_y],
                               'maxLayoutUnitError':round(abs(tip_x-cap_x)*cw/rail.width,5)})

    board = Image.new('RGBA', (1536, 1024), '#14161a')
    draw = ImageDraw.Draw(board)

    def text(label, x, y, size=18):
        draw.text((x,y), label, font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size), fill='#d9d1bc')

    def put_whole(canvas, scene, x, y, scale=1):
        whole = scene.resize((round(scene.width*scale),round(scene.height*scale)),S)
        assert x >= 0 and y >= 0 and x+whole.width <= canvas.width and y+whole.height <= canvas.height
        canvas.alpha_composite(whole,(x,y))

    text('DRUID / TRE ENDCAPS / SAMME DIP MED OG UDEN', 28, 22, 30)
    text('Spidser registreret på den komplette casing. Bar og dip er uændrede under endcappen. Ikke installeret.', 28, 68)
    text('PLAYER / 100% / 1×', 28, 112, 21)
    text('TARGET / 40% / 1×', 790, 112, 21)
    for index, key in enumerate((None, *VARIANTS)):
        y = 150+index*200
        text(VARIANTS[key].upper() if key else 'UDEN ENDCAP / komplet afslutning med dip',28,y,19)
        for x, flip in ((28,False),(790,True)):
            scene = render(key,.4 if flip else 1,flip)
            # Align the long upper rail, not each ornament's cropped bounds.
            rail_top = int(np.flatnonzero(np.asarray(scene)[:,100,3] > 128)[0])
            put_whole(board,scene,x,y+70-rail_top)
        draw.line((28,y+175,1508,y+175),fill='#454b55')
    text('Hele bars, inklusive afslutning og portræt. Offline samling af eksport — ikke screenshots fra WoW.',28,990,16)
    board.convert('RGB').save(OUT/'Druid-three-aligned.png')

    # Enlarge the complete assemblies, never a crop of their ending. The full
    # bare dip remains visible above each mounted player/target comparison.
    for key, label in VARIANTS.items():
        enlarged = Image.new('RGBA',(1536,1120),'#14161a')
        bigdraw = ImageDraw.Draw(enlarged)
        def bigtext(value,x,y,size=20):
            bigdraw.text((x,y),value,font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size),fill='#d9d1bc')
        bigtext('DRUID / '+label.upper()+' / HELE BAREN VED 2×',28,22,30)
        bigtext('UDEN ENDCAP / hele dippet og afslutningen',28,100)
        put_whole(enlarged,render(),28,145,2)
        bigtext('PLAYER / MED ENDCAP / 100%',28,370)
        put_whole(enlarged,render(key),28,415,2)
        bigtext('TARGET / MED ENDCAP / 40% / spejlet med portræt',28,670)
        put_whole(enlarged,render(key,.4,True),28,715,2)
        bigtext('Hele den oprindelige bar bevares under endcappen. Begge spidser deler samme position. Ingen bar er beskåret.',28,1070,17)
        enlarged.convert('RGB').save(OUT/('Druid-'+key+'-aligned-full-2x.png'))

    original_sources = json.loads((OUT/'verification.json').read_text())['sources']
    assert sources == original_sources, 'use the three existing whole paintings unchanged'
    report = {'installed':False,'sources':sources,
              'method':'intact uniform art registered by bottom point on the identical complete casing canvas; no dip removal',
              'bareCasings':{p.name:sha(p) for name in M.HEALTH for suffix in ('','-over')
                             for p in [ROOT/'Assets/Druid'/(name+suffix+'.tga')]},
              'exportHashes':files,'registrations':registrations,'joints':joints,'liveValidated':False}
    (OUT/'aligned-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Three review-only endcaps;',len(files),'exported textures;',len(joints),'native-layout checks. No install.')


if __name__ == '__main__':
    build()
