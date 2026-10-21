"""Read-only live-feedback audit; writes diagnostics, never installed artwork/code.

python Tools/Audit-WarriorFit.py
Screenshots are evidence of the reported appearance; composites remain offline.
"""
from pathlib import Path
import copy
import hashlib
import importlib.util
import inspect
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from ThemeHealthEndcaps import lowest_point,terminal_mask

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Warrior/Live-Fit-Audit-2026-10-18'
S=Image.Resampling.LANCZOS


def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):return Image.open(path).convert('RGBA')


def bounds(im):return im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()


def label(board,text,x,y,size=18):
    ImageDraw.Draw(board).text((x,y),text,font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size),fill='#e4dfd1')


def main():
    WORK.mkdir(parents=True,exist_ok=True)
    protected=[p for folder in ('Assets/Warrior','Assets/Druid') for p in (ROOT/folder).glob('*') if p.is_file()]
    protected += [ROOT/name for name in ('Core/WarriorTheme.lua','Core/DruidTheme.lua','Core/ThemeEngine.lua',
                                        'Layouts/Data/PlayerUnitFrame.lua','Layouts/Data/PlayerCastBar.lua')]
    before={p.relative_to(ROOT).as_posix():sha(p) for p in protected}
    R=module('audit_warrior_renderer','Render-WarriorAssets.py')
    class Installed(R.Renderer):
        def __init__(self,theme):
            super().__init__();self.theme=theme
            self.data=copy.deepcopy(R.M.DATA);self.replace(self.data)
        def asset(self,path):
            return read(ROOT/'Assets'/path.replace('\\','/').split('/Assets/')[-1])
    renderers={theme:Installed(theme) for theme in ('Warrior','Druid')}
    pairs=(('stromkar','antler'),('warswords','bear'),('wrath','owl'))
    stats={}
    for theme,keys in (('Warrior',('stromkar','warswords','wrath')),('Druid',('antler','bear','owl'))):
        stats[theme]={}
        for case in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case'):
            stats[theme][case]={}
            for key in keys:
                im=read(ROOT/'Assets'/theme/('ornament-'+key+'-'+case+'.tga'));b=bounds(im)
                stats[theme][case][key]={'bounds':list(b),'width':b[2]-b[0],'height':b[3]-b[1],
                                        'opaquePixels':int((np.asarray(im)[:,:,3]>128).sum())}
    scenes=[[renderers[theme].health(choice=pair[i]) for i,theme in enumerate(('Warrior','Druid'))] for pair in pairs]
    box=Image.fromarray(np.maximum.reduce([np.asarray(scene)[:,:,3] for row in scenes for scene in row])).getbbox()
    page=Image.new('RGBA',(1600,980),'#171b20')
    label(page,'INSTALLED ASSETS / SAME HEALTH RECTANGLE / 1x',26,20,28)
    label(page,'Warrior (left) versus Druid (right). Fixed viewport and rail origin. Offline composites, no replacement art.',26,65,16)
    for row,pair in enumerate(pairs):
        y=120+row*205
        for col,theme in enumerate(('Warrior','Druid')):
            label(page,theme+' / '+pair[col],26+col*790,y)
            page.alpha_composite(scenes[row][col].crop(box),(26+col*790,y+35))
    w=stats['Warrior']['hp_cap_case']['stromkar'];d=stats['Druid']['hp_cap_case']['antler']
    comparison={'heightRatio':w['height']/d['height'],'widthRatio':w['width']/d['width'],
                'opaqueAreaRatio':w['opaquePixels']/d['opaquePixels']}
    envelopes={}
    for case in stats['Druid']:
        reference=stats['Druid'][case]
        front=read(ROOT/'Assets/Warrior'/(case+'-over.tga'))
        druid_front=read(ROOT/'Assets/Druid'/(case+'-over.tga'))
        shift=lowest_point(front)[0]-lowest_point(druid_front)[0]
        envelope=[int(np.floor(min(v['bounds'][0] for v in reference.values())+shift)),
                  min(v['bounds'][1] for v in reference.values()),
                  int(np.ceil(max(v['bounds'][2] for v in reference.values())+shift)),
                  max(v['bounds'][3] for v in reference.values())]
        required=terminal_mask(front).getbbox()
        assert envelope[0]<=required[0] and envelope[1]<=required[1] and envelope[2]>=required[2] and envelope[3]>=required[3]
        envelopes[case]={'proposedBounds':envelope,'maxWidth':envelope[2]-envelope[0],
                         'maxHeight':envelope[3]-envelope[1],'containsExistingFullTerminalBounds':True,
                         'status':'proposal only; not an approved or repainted asset'}
    label(page,'Default Stromkar vs Wildheart: 170 vs 136 px high; 157 vs 108 px wide; 2.14x opaque painted area.',26,800,20)
    label(page,'These are source-canvas measurements; both are drawn on the same native casing rectangle.',26,840,17)
    label(page,'Recommended next design: compact whole painting inside an agreed Druid-sized envelope, while covering the full bare dip.',26,885,17)
    page.convert('RGB').save(WORK/'health-footprint-comparison.png')

    # Replay the actual rail exporter in an isolated namespace, capturing its
    # raw whole painting immediately before its blanket fill-mask erasure.
    H=module('audit_rail_exporter','Build-RebuiltHealthArt.py')
    replay=dict(H.__dict__);replay['SOURCES']=ROOT/'Docs/Research_Assets/Warrior/Sources'
    source=inspect.getsource(H.rails)
    assert source.count('pixels[inside,3]=0')==1
    source=source.replace('pixels[inside,3]=0','raw_before_cut=front.copy(); pixels[inside,3]=0')
    source=source.replace('return Image.fromarray(back),front','return Image.fromarray(back),front,raw_before_cut')
    exec(compile(source,'<isolated read-only exporter replay>','exec'),replay)
    leather={}
    for case in ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case'):
        _,front,raw=replay['rails']('Warrior',case)
        current=read(ROOT/'Assets/Warrior'/(case+'-over.tga'))
        assert current.tobytes()==front.tobytes(),'export replay differs from installed front'
        p=np.asarray(raw);q=np.asarray(current)
        fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L'))>0
        red=(p[:,:,0]>55)&(p[:,:,0]>p[:,:,1].astype(float)*1.6)&(p[:,:,0]>p[:,:,2].astype(float)*1.2)&(p[:,:,3]>200)
        lost=red&fill&(q[:,:,3]<=200)
        leather[case]={'opaqueRedMaterialLostInsideFill':int(lost.sum()),'totalOpaqueRedMaterial':int(red.sum())}
        if case=='hp_cap_case':
            assert lost.any(),'red leather loss not reproduced'
            board=Image.new('RGBA',(1600,1200),'#171b20')
            label(board,'HEALTH FOREGROUND / SOURCE PAINTING AND EXPORTED ALPHA',26,20,26)
            label(board,'Raw paint before fill cut (top); installed front (middle); removed red material highlighted (bottom).',26,64,17)
            bbox=(200,45,850,198)
            for row,im in enumerate((raw,current,current.copy())):
                if row==2:
                    mark=Image.new('RGBA',im.size,'#ef43bd');mark.putalpha(Image.fromarray((lost*255).astype('uint8')))
                    im=Image.alpha_composite(im,mark)
                board.alpha_composite(im.crop(bbox).resize((1300,306),S),(26,100+row*350))
            board.convert('RGB').save(WORK/'leather-alpha-loss.png')

    cast_stats={}
    cast_scenes=[]
    for theme,scale,dx,dy in (('Warrior',1,0,0),('Warrior',1.4,-2,13),('Druid',1,0,0)):
        r=renderers[theme];scene=r.cast(cap=False)
        name='cast-head' if theme=='Warrior' else 'cast-head-fitted'
        im=r.own(name);b=bounds(im)
        size=48*scale;x,y=170,110
        r.put(scene,im,(x-8-dx-size/2,y+11/2-size/2-dy,size,size))
        cast_scenes.append(scene)
        center_y=(b[1]+b[3])/2-im.height/2
        cast_stats[theme+str(scale)]={'bounds':list(b),'scale':scale,'offset':[dx,dy],
            'paintCenterBelowTextureCenterSourcePixels':center_y,
            'paintCenterBelowSlotLayoutUnitsBeforeOffset':center_y*size/im.height}
    box=Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for im in cast_scenes])).getbbox()
    board=Image.new('RGBA',(1400,960),'#171b20')
    label(board,'CAST HEAD / CURRENT DEFAULT, SCREENSHOT SETTINGS, DRUID',26,20,26)
    for row,title in enumerate(('Warrior default: 100%, X=0, Y=0','Warrior screenshot settings: 140%, X=-2, Y=+13','Druid default: 100%, X=0, Y=0')):
        label(board,title,26,100+row*240,20)
        crop=cast_scenes[row].crop(box)
        board.alpha_composite(crop.resize((crop.width*3,crop.height*3),S),(26,140+row*240))
    label(board,'3x detail with one fixed viewport. Warrior paint sits +8.81 layout units below centre at 100%, +12.34 at 140%.',26,860,18)
    label(board,'Your +13 Y corrects this baked-in bottom alignment. Shared slot position alone did not validate a physical socket join.',26,900,17)
    board.convert('RGB').save(WORK/'cast-default-and-screenshot-settings.png')
    assert before=={p.relative_to(ROOT).as_posix():sha(p) for p in protected},'audit changed installed files'
    report={'installedAndReferenceFilesUnchanged':len(before),'protected':before,'health':stats,
            'defaultStromkarVsWildheart':comparison,'proposedDruidSizedEnvelopes':envelopes,'leather':leather,'cast':cast_stats,
            'screenshots':{'castSettings':{'scale':1.4,'x':-2,'y':13}},
            'findings':['Blanket alpha erasure removes red leather within the native fill aperture.',
                        'Cap search grows paintings until coverage succeeds, without an approved exterior footprint bound.',
                        'Cast contain() bottom-aligns the wide Warrior painting; the shared slot is centred.',
                        'Current harnesses check frame levels/slot dimensions but not leather survival, footprint, or physical cast socket join.'],
            'runtimeChanged':False,'artChanged':False,'liveFixConfirmed':False}
    (WORK/'audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'comparisons':comparison,'leather':leather,'cast':cast_stats,'unchangedFiles':len(before)},indent=2))


if __name__=='__main__':main()
