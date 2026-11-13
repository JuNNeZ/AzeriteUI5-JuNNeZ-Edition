"""Complete before/after frames, with shared origins and union viewports."""
import json

import numpy as np
from PIL import Image, ImageDraw

from PriestWarlockAssetContracts import ROOT, record


def main():
    root = ROOT/"Assets_Draft/Priest/FullSet/Review"
    folders = (root/"GapRepair/BeforeAssemblies",root/"Assemblies")
    output = root/"GapRepair"
    rows = []
    records = {}
    for tier in ("seasoned","hardened","novice","boss"):
        # Both source pages have the same 1200x400 scene and rail origin.
        # Exclude the review label above the frame, never any frame artwork.
        parts = [Image.open(folder/(tier+"-none-on-1x.png")).convert("RGB").crop((0,510,1200,780)) for folder in folders]
        masks = [np.any(np.asarray(im)!=[20,22,26],axis=2) for im in parts]
        union = masks[0]|masks[1]
        yy,xx = np.where(union)
        box = (max(0,int(xx.min())-8),max(0,int(yy.min())-8),min(1200,int(xx.max())+9),min(270,int(yy.max())+9))
        assert box[0]>0 and box[1]>0 and box[2]<1200 and box[3]<270, "Clipped complete frame"
        rows.append((tier,[im.crop(box) for im in parts]))
        records[tier] = {"sourceScene":[0,510,1200,780],"sharedUnionViewport":list(box)}
    column = max(560, max(parts[0].width for _,parts in rows)+30)
    height = 300+sum(max(im.height for im in parts)+50 for _,parts in rows)
    board = Image.new("RGB",(column*2,height),"#14161a")
    draw = ImageDraw.Draw(board)
    draw.text((15,12),"Priest / BEFORE (left) - REPAIRED (right) / complete frames, common viewport per pair",fill="white")
    draw.text((15,36),"Player + crystal / 65% / native size",fill="white")
    for col,folder in enumerate(folders):
        image = Image.open(folder/"complete-1x.png").convert("RGB").crop((20,140,545,360))
        board.paste(image,(15+col*column,60))
    y = 300
    for tier,parts in rows:
        draw.text((15,y),tier+" / complete health + cap / empty",fill="white")
        y+=24
        for col,part in enumerate(parts):
            board.paste(part,(15+col*column,y))
        y+=max(im.height for im in parts)+26
    board.save(output/"complete-before-after-1x.png")
    board.resize((board.width*2,board.height*2),Image.Resampling.NEAREST).save(output/"complete-before-after-2x.png")
    (output/"comparison-viewports.json").write_text(json.dumps(records,indent=2)+"\n")
    print(record(output/"complete-before-after-1x.png"))


if __name__ == "__main__":
    main()
