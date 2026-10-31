"""Mark missing mounting-body paint for an AI edit, never patch source art."""
from pathlib import Path
import argparse
import importlib.util
import json
import numpy as np
from PIL import Image, ImageFilter
from ThemeHealthEndcaps import lowest_point

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman'
spec=importlib.util.spec_from_file_location('shaman_repair_builder',ROOT/'Tools/Build-ShamanAssets.py')
B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)

def prepare(choice):
    data=B.contract();path=B.SOURCE/('ornament-'+choice+'.png');source=B.read(path)
    box=source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox();art=source.crop(box)
    needed=np.zeros((source.height,source.width),dtype=bool);records={}
    for case,item in data['health'].items():
        limit=item['approvedEnvelope'];tx,ty=item['dip'];best=None
        required=np.asarray(Image.open(ROOT/item['terminalMask']).convert('L'))>128
        for height in range(110,limit[3]-limit[1]+1):
            piece=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
            ax,ay=lowest_point(piece);x,y=round(tx-ax),ty-ay
            if x<limit[0] or y<limit[1] or x+piece.width>limit[2] or y+piece.height>limit[3]: continue
            cap=Image.new('RGBA',(1024,256));cap.alpha_composite(piece,(x,y))
            opaque=np.asarray(cap)[:,:,3]>=240
            aa=np.asarray(Image.fromarray(opaque.astype('uint8')*255).filter(ImageFilter.MaxFilter(3)))>0
            missing=int((required&~aa).sum())
            if best is None or missing<best[0]: best=(missing,height,x,y,piece.size)
        assert best is not None,case
        missing,height,x,y,size=best;records[case]={'missingAtGuidePlacement':missing,'height':height,'offset':[x,y]}
        sx,sy=size[0]/art.width,size[1]/art.height
        mapped=Image.fromarray(required.astype('uint8')*255).transform(source.size,Image.Transform.AFFINE,
                    (sx,0,x-box[0]*sx,0,sy,y-box[1]*sy),Image.Resampling.NEAREST)
        needed|=np.asarray(mapped)>128
    missing=needed&(np.asarray(source)[:,:,3]<240)
    margin=np.asarray(Image.fromarray(missing.astype('uint8')*255).filter(ImageFilter.MaxFilter(17)))>0
    # Preserve the original single lowest toe. The body/heel may extend to
    # either side above it; no new lower tip is proposed by this guide.
    margin[box[3]-8:]=False
    pixels=np.array(source);pixels[margin]=[230,35,155,255]
    target=WORK/'Guides'/(choice+'-mount-edit-guide.png');Image.fromarray(pixels).save(target)
    B.write(WORK/'Guides'/(choice+'-mount-edit-guide.json'),{'geometryDiagnosticOnly':True,'sourceSha256':B.sha(path),
             'markedGuidePixels':int(margin.sum()),'cases':records,'nativeMasksUnchanged':True})
    print(choice,records,'marked HD guide pixels:',int(margin.sum()))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('choice',choices=('tides','lava'));args=parser.parse_args();prepare(args.choice)
