"""Show rejected AI-paint mounting pixels without editing production artwork.

Search only rigid registration inside the frozen Druid footprint. Diagnostic
paintings and highlights are explicitly rejected evidence, never runtime art.
"""
from pathlib import Path
import importlib.util
import json
import hashlib
import argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from ThemeHealthEndcaps import lowest_point

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman'
OUT=ROOT/'Assets_Draft/Shaman'

def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

R=load('shaman_diagnostic_renderer','Render-ShamanAssets.py')
contract=json.loads((WORK/'contract.json').read_text())
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--choice',choices=('maelstrom','tides','lava'),default='maelstrom')
args=parser.parse_args();CHOICE=args.choice
source_path=WORK/('Sources/ornament-'+CHOICE+'-v2.png')
source=Image.open(source_path).convert('RGBA')

def find(case):
    item=contract['health'][case];limit=item['approvedEnvelope'];tx,ty=item['dip']
    width,height=limit[2]-limit[0],limit[3]-limit[1]
    required=np.asarray(Image.open(ROOT/item['terminalMask']).convert('L'))>128
    req=required[limit[1]:limit[3],limit[0]:limit[2]]
    fill=np.asarray(Image.open(ROOT/'Docs/Research_Assets/Templates'/(case+'-fill.png')).convert('L'))>128
    front=np.asarray(Image.open(OUT/(case+'-over.tga')).convert('RGBA'))[:,:,3]>200
    base=int((fill&front).sum());mask=fill[limit[1]:limit[3],limit[0]:limit[2]]
    rail=front[limit[1]:limit[3],limit[0]:limit[2]]
    best=None
    angles=(0,-.5,.5,-1,1,-1.5,1.5,-2,2,-3,3)
    candidates=None
    if CHOICE!='maelstrom':
        record=json.loads((WORK/(CHOICE+'-registration.json')).read_text())
        trials=[t for t in record['rejected'][case] if t['failure'].startswith('preflight exposed terminal pixels:')]
        trials.sort(key=lambda t:int(t['failure'].split(': ')[-1]))
        candidates={(t['angle'],t['height']) for t in trials[:50]}
        angles=tuple(dict.fromkeys(t['angle'] for t in trials[:50]))
    for angle in angles:
        art=source.rotate(angle,resample=Image.Resampling.BICUBIC,expand=True) if angle else source
        art=art.crop(art.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox())
        for size in range(100,height+1):
            if candidates is not None and (angle,size) not in candidates: continue
            piece=art.resize((round(art.width*size/art.height),size),Image.Resampling.LANCZOS)
            ax,ay=lowest_point(piece);x,y=round(tx-ax)-limit[0],ty-ay-limit[1]
            if x<0 or y<0 or x+piece.width>width or y+piece.height>height: continue
            field=Image.new('RGBA',(width,height));field.alpha_composite(piece,(x,y));a=np.asarray(field)[:,:,3]
            px,py=lowest_point(field)
            if abs(px+limit[0]-tx)>.5 or py+limit[1]!=ty: continue
            combined=(base+int(((a>200)&mask&~rail).sum()))/int(fill.sum())
            if combined>.20: continue
            aa=np.asarray(Image.fromarray((a>=240).astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
            exposed=req&~aa;count=int(exposed.sum())
            if best is None or count<best[0]:
                cap=Image.new('RGBA',(1024,256));cap.alpha_composite(field,(limit[0],limit[1]))
                full=np.zeros((256,1024),dtype=bool);full[limit[1]:limit[3],limit[0]:limit[2]]=exposed
                best=(count,cap,full,{'height':size,'rotationDegrees':angle,'combinedFillOcclusion':combined,
                                    'dip':[tx,ty],'actualCapToe':[px+limit[0],py+limit[1]],'insideApprovedEnvelope':True})
    assert best is not None
    return best

def label(page,text,x,y,size=18):
    ImageDraw.Draw(page).text((x,y),text,font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',size),fill='#e1dbd0')

cases=('hp_mid_case','hp_low_case') if CHOICE=='maelstrom' else ('hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case')
results={case:find(case) for case in cases}

class DiagnosticRenderer(R.Renderer):
    def own(self,name):
        for case,result in results.items():
            if name=='ornament-'+CHOICE+'-'+case: return result[1]
        return super().own(name)

r=DiagnosticRenderer()
layouts={};cursor=120
for case in cases:
    tier={v:k for k,v in R.CASES.items()}[case]
    pair=[r.health(tier=='Boss',cap=on,tier=tier,choice=CHOICE,fraction=.5,prediction=True) for on in (False,True)]
    box=Image.fromarray(np.maximum.reduce([np.asarray(im)[:,:,3] for im in pair])).getbbox()
    h=box[3]-box[1];step=max(115,h+45);detail=max(320,160+h*2,150+step+h)
    layouts[case]=(cursor,pair,box,step,detail);cursor+=detail+200
page=Image.new('RGBA',(2700 if CHOICE!='maelstrom' else 1800,cursor+60),'#16191e')
label(page,'SHAMAN / '+CHOICE.upper()+' / PRECISE MOUNTING DIAGNOSTIC / AI PAINT RETAINED',24,20,25)
label(page,'REJECTED FITS. Red marks are inspection overlays only. No source painting, native mask or runtime asset was patched.',24,65,19)
records={}
for row,(case,result) in enumerate(results.items()):
    count,cap,exposed,fit=result;tier={v:k for k,v in R.CASES.items()}[case]
    y,pair,box,step,detail_y=layouts[case]
    label(page,case+' / '+str(count)+' exposed SOURCE pixels after the 1px contour-AA allowance',24,y,23)
    label(page,'Best bounded rigid fit: height '+str(fit['height'])+'px; rotation '+str(fit['rotationDegrees'])+' degrees; toe aligned; fill occlusion '+str(round(fit['combinedFillOcclusion']*100,2))+'%',24,y+35,17)
    for i,scene in enumerate(pair):
        label(page,'1x / '+('AI END CAP' if i else 'NONE / UNCHANGED CASING'),24,y+78+i*step,16)
        art=scene.crop(box);page.alpha_composite(art,(24,y+105+i*step))
    label(page,'2x / COMPLETE BAR / SAME RAIL ORIGIN',600,y+78,16)
    art=pair[1].crop(box).resize(((box[2]-box[0])*2,(box[3]-box[1])*2),Image.Resampling.LANCZOS)
    assert art.width+600<=page.width,'Complete bar needs a larger diagnostic viewport'
    page.alpha_composite(art,(600,y+105))
    # Source-coordinate heel view, held fixed across unmarked/marked images.
    coords=[(int(x),int(yy)) for yy,x in zip(*np.where(exposed))]
    xs=[p[0] for p in coords];ys=[p[1] for p in coords]
    crop=(min(xs)-8,min(ys)-8,max(xs)+9,max(ys)+9)
    native=Image.open(OUT/(case+'-over.tga')).convert('RGBA')
    close=Image.new('RGBA',native.size,'#262b33');close.alpha_composite(native);close.alpha_composite(cap)
    marked=close.copy();pixels=np.array(marked);pixels[exposed]=[255,42,74,255];marked=Image.fromarray(pixels)
    scale=min(8,350//(crop[2]-crop[0]),150//(crop[3]-crop[1]));scale=max(2,scale)
    label(page,'Exact exposed pixels / nearest-neighbour magnification',600,y+detail_y-30,16)
    for i,im in enumerate((close,marked)):
        detail=im.crop(crop).resize(((crop[2]-crop[0])*scale,(crop[3]-crop[1])*scale),Image.Resampling.NEAREST)
        page.alpha_composite(detail,(600+i*460,y+detail_y))
    records[case]=dict(fit,exposedSourcePixels=count,sourcePixelCoordinates=coords,sourcePixelCrop=crop,
                      diagnosticOnly=True,productionAccepted=False)
    cap.save(WORK/'Rejected'/(CHOICE+'-'+case+'-unmodified-ai-diagnostic.png'))
label(page,'This is an offline source-pixel test. Screen visibility depends on in-game scale; it is not a live WoW screenshot.',24,page.height-45,18)
suffix='' if CHOICE=='maelstrom' else '-'+CHOICE
page.convert('RGB').save(WORK/('Shaman-mounting-defect'+suffix+'.png'))
records['source']=source_path.relative_to(WORK).as_posix();records['sourceSha256']=hashlib.sha256(source_path.read_bytes()).hexdigest()
(WORK/('mounting-defect'+suffix+'.json')).write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
print(json.dumps(records,indent=2))
