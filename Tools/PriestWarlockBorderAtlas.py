"""Pack intact painted corner bodies and repeated connecting rails into UV cells.

Only exact RGBA crops, integer translations and rail repetition. No alpha
stencil, recolouring, stretching or newly painted geometry.
"""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw

from PriestWarlockAssetContracts import ROOT, record
from DeathKnightTooltipAtlas import joins, render

NAMES=("border-tooltip","border-aura","better-blizzard-border-small-alternate")


def pack(source, corner_offsets=None, native=None):
    cell=source.height
    assert source.width==cell*8
    recipes=[];corners=[]
    for index in range(4):
        upper=index<2;right=index%2==1
        region=(cell*(4 if upper else 6),0,cell*(6 if upper else 8),cell)
        box=source.crop(region).getchannel("A").point(lambda a:255 if a>128 else 0).getbbox()
        assert box
        x0,y0,x1,y1=box
        x0=max(0,x0-1);x1=min(region[2]-region[0],x1+1)
        y0=max(0,y0-1);y1=min(cell,y1+1)
        x0+=region[0];x1+=region[0]
        middle=(x0+x1)//2
        patch=(middle-2 if right else x0,y0,x1 if right else middle+2,y1)
        body=source.crop(patch)
        assert body.width<=cell and body.height<=cell
        x=cell-body.width if right else 0;y=0 if upper else cell-body.height
        dx,dy=(corner_offsets or {}).get(index,(0,0));x+=dx;y+=dy
        assert min(x,y)>=0 and x+body.width<=cell and y+body.height<=cell
        # Keep the rails over the original background/icon insets. Packing
        # against the OUTSIDE of each cell leaves a transparent moat at runtime.
        # Only plain connecting-rail tails may be shortened at cell boundaries.
        native_shift = None
        if native is not None:
            assert native.size == source.size
            def centre(profile):
                points=np.flatnonzero(np.asarray(profile)>128)
                assert len(points), "Empty native/painted rail profile"
                return float((points[0]+points[-1])/2)
            vertical=source.crop(patch).getchannel("A")
            exit_y=max(0,body.height-3) if upper else min(2,body.height-1)
            exit_x=min(2,body.width-1) if right else max(0,body.width-3)
            edge_x=1 if right else 0;edge_y=2 if upper else 3
            target_x=centre(native.getchannel("A").crop((edge_x*cell,cell//2,(edge_x+1)*cell,cell//2+1)))
            target_y=centre(native.getchannel("A").crop((edge_y*cell,cell//2,(edge_y+1)*cell,cell//2+1)))
            dx=round(target_x-(x+centre(vertical.crop((0,exit_y,body.width,exit_y+1)))))
            dy=round(target_y-(y+centre(vertical.crop((exit_x,0,exit_x+1,body.height)))))
            x+=dx;y+=dy;native_shift=[dx,dy]
            # The cropped ends are the repeating rail exits, never the outer
            # corner body. Reject a requested move through an outside corner.
            assert (x>=0 if not right else x+body.width<=cell)
            assert (y>=0 if upper else y+body.height<=cell)
            cut=(max(0,-x),max(0,-y),min(body.width,cell-x),min(body.height,cell-y))
            body=body.crop(cut)
            patch=(patch[0]+cut[0],patch[1]+cut[1],patch[0]+cut[2],patch[1]+cut[3])
            x=max(0,x);y=max(0,y)
        corner=Image.new("RGBA",(cell,cell));corner.paste(body,(x,y))
        # Extend only a complete plain connecting-rail exit. This is repeating
        # source pixels, like edge tiling in the native Backdrop atlas.
        exit_y=max(0,body.height-3) if upper else min(2,body.height-1)
        row=body.crop((0,exit_y,body.width,exit_y+1))
        for target_y in range(y+body.height,cell) if upper else range(0,y):
            corner.paste(row,(x,target_y))
        exit_x=min(2,body.width-1) if right else max(0,body.width-3)
        column=body.crop((exit_x,0,exit_x+1,body.height))
        for target_x in range(0,x) if right else range(x+body.width,cell):
            corner.paste(column,(target_x,y))
        corners.append(corner)
        recipes.append({"cell":index+4,"wholeCornerCrop":list(patch),"offset":[x,y],"verticalRailExitRow":exit_y,"horizontalRailExitColumn":exit_x})
        if native_shift is not None:
            recipes[-1]["nativeRailShift"]=native_shift
    atlas=Image.new("RGBA",source.size)
    for index,corner in enumerate(corners):
        atlas.paste(corner,((index+4)*cell,0))
    # Native horizontal cells store their cross-section along X as well.
    for index,(corner_index,horizontal,coordinate) in enumerate(((0,False,cell-1),(1,False,cell-1),(0,True,cell-1),(2,True,cell-1))):
        corner=corners[corner_index]
        profile=corner.crop((coordinate,0,coordinate+1,cell)).transpose(Image.Transpose.ROTATE_90) if horizontal else corner.crop((0,coordinate,cell,coordinate+1))
        for y in range(cell):
            atlas.paste(profile,(index*cell,y))
    return atlas,recipes


def main(theme):
    draft=ROOT/"Assets_Draft"/theme/"FullSet";out=draft/"BorderAtlases";out.mkdir(exist_ok=True)
    review=draft/"Review/Borders";review.mkdir(parents=True,exist_ok=True)
    records={}
    board=Image.new("RGBA",(1100,950),"#292d33");draw=ImageDraw.Draw(board)
    for row,name in enumerate(NAMES):
        source_path=draft/"Exports"/(name+".tga");source=Image.open(source_path).convert("RGBA")
        shifts={2:(1,0)} if theme=="Warlock" and name!="border-aura" else None
        native=Image.open(ROOT/"Assets"/(name+".tga")).convert("RGBA") if theme=="Priest" or name in ("border-tooltip", "border-aura") else None
        atlas,recipes=pack(source,shifts,native)
        # The existing UV diagnostic uses 64px cells. Double the small aura
        # atlas only for diagnostic sampling, without changing its runtime art.
        diagnostic=atlas if atlas.height==64 else atlas.resize((512,64),Image.Resampling.NEAREST)
        failures=joins(diagnostic)
        rejected=source if source.height==64 else source.resize((512,64),Image.Resampling.NEAREST)
        try:rejected_failures=joins(rejected)
        except AssertionError as error:rejected_failures=[{"error":str(error)}]
        assert rejected_failures, "Rejected raw UV fixture unexpectedly passed"
        target=out/(name+".tga");atlas.save(target,compression=None)
        records[name]={"source":record(source_path),"export":record(target),"construction":"intact corner bodies and exact repeated rail exits","recipes":recipes,"joinFailures":failures,"rejectedRawJoinFailures":rejected_failures}
        if native is not None:
            records[name]["nativeRailAuthority"]=record(ROOT/"Assets"/(name+".tga"))
        draw.text((15,15+row*310),theme+" / "+name+" / offline UV sampling",fill="white")
        for column,(width,height) in enumerate(((280,170),(420,240),(180,100))):
            board.alpha_composite(render(diagnostic,width,height),((15,330,800)[column],50+row*310))
        print(theme+"/"+name+": join failures="+str(failures))
    board.convert("RGB").save(review/"assembled-1x.png")
    board.resize((2200,1900),Image.Resampling.NEAREST).convert("RGB").save(review/"assembled-2x.png")
    if theme=="Priest":
        runtime=Image.new("RGBA",(1000,520),"#292d33");labels=ImageDraw.Draw(runtime)
        for column,title in enumerate(("Before", "Repaired", "Native reference")):
            labels.text((15+column*330,12),title+" / actual UVs and insets",fill="white")
        retained=draft/"Review/GapRepair/Before"
        before=retained if (retained/"border-tooltip.tga").exists() else ROOT/"Assets/Priest"
        for column,folder in enumerate((before,out,ROOT/"Assets")):
            x=15+column*330
            atlas=Image.open(folder/"border-tooltip.tga").convert("RGBA")
            runtime.alpha_composite(render(atlas,280,170,insets=(8,16,8,16)),(x,40))
            labels.text((x,235),"Aura icon: 24 / 32 / 48 px; edge 12, outset 6",fill="white")
            atlas=Image.open(folder/"border-aura.tga").convert("RGBA")
            for i,size in enumerate((24,32,48)):
                runtime.alpha_composite(render(atlas,size+12,size+12,edge=12,aura=True,insets=(6,6,6,6)),(x+i*90,265))
        runtime.convert("RGB").save(review/"runtime-before-after-1x.png")
        runtime.resize((2000,1040),Image.Resampling.NEAREST).convert("RGB").save(review/"runtime-before-after-2x.png")
    (out/"manifest.json").write_text(json.dumps({"assets":records,"numericPassed":all(not x["joinFailures"] for x in records.values()),"liveApproved":False},indent=2)+"\n")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("theme",choices=("Priest","Warlock","Both"));args=parser.parse_args()
    for theme in ("Priest","Warlock") if args.theme=="Both" else (args.theme,):
        main(theme)
