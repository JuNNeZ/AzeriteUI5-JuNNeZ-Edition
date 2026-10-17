"""Review every rebuilt relic using real installed bars at gameplay scale."""
from pathlib import Path
import importlib.util
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/EndcapRebuild-2026-10-17'
GALLERY=ROOT/'Docs/Research_Assets/ClassConceptSheets-2026-10-17'


def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value)
    return value


R=module('review','Render-FittedEndcaps.py')
M=module('builder','Build-RebuiltHealthArt.py')


def build():
    for theme,names in M.MOTIFS.items():
        board=Image.new('RGBA',(1536,120+220*len(names)),'#14161a')
        draw=ImageDraw.Draw(board)
        def text(value,x,y,size=16):
            draw.text((x,y),value,font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',size),fill='#d9d1bc')
        text('AZERITEUI / '+theme.upper()+' / WHOLE-ART ENDCAPS',28,18,28)
        text('Actual installed textures: complete player / mirrored target. No end-only crops. Offline reconstruction.',28,65)
        for index,name in enumerate(names):
            y=110+index*220
            draw.line((24,y,1512,y),fill='#3a3e46')
            text(name.replace('endcap-','').replace('ornament-','').upper(),28,y+10,18)
            player=R.health(theme,True,motif=name+'-fitted')
            target=R.health(theme,True,.4,True,motif=name+'-fitted')
            board.alpha_composite(player,(28,y+60))
            board.alpha_composite(target,(560,y+60))
        target=WORK/(theme+'-all-endcaps.png')
        board.convert('RGB').save(target)
        board.convert('RGB').save(GALLERY/(theme.lower()+'-all-endcaps.png'))
    print('Rendered complete player and target bars at native gameplay scale.')


if __name__=='__main__':build()
