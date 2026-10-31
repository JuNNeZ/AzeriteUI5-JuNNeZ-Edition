"""Maintainer-approved deterministic Rogue mount editing (2026-10-26).

Keep generated originals. Extend only the mounting body inside the unchanged
terminal mask. The complete Serrated blade is rigidly translated underneath
its original leather mount, never stretched or clipped. No runtime geometry.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from ThemeHealthEndcaps import align, lowest_point, terminal_coverage

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Rogue'
OUT=ROOT/'Assets_Draft/Rogue'
EDIT=WORK/'Script-Edited'


def load_module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Tools'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert('RGBA')


def write(path,data):
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')


def serrated_source():
    source=read(WORK/'Sources/serrated-v2.png')
    assert source.size==(1254,1254),'Serrated component coordinates require the retained original'
    # Left seam follows the blade's actual join underneath the olive leather.
    # All three teeth, both outer tips and the complete inner steel spine are
    # retained in the separate blade layer, including original edge alpha.
    polygon=[(852,148),(780,220),(904,300),(953,333),(913,383),(931,592),
             (935,829),(840,937),(712,1038),(815,1068),(1253,1253),(1253,0)]
    mask=Image.new('L',source.size);ImageDraw.Draw(mask).polygon(polygon,fill=255)
    field=np.asarray(mask)>0
    pixels=np.array(source)
    # Hidden RGB in alpha-zero generated PNG texels is not painting. Canonical
    # zero makes the disjoint-layer reconstruction byte-comparable.
    pixels[pixels[:,:,3]==0]=0
    blade=pixels.copy();blade[~field]=0
    body=pixels.copy();body[field]=0
    assert np.array_equal(np.asarray(Image.alpha_composite(Image.fromarray(blade),Image.fromarray(body))),pixels)
    dx,dy=-120,-35
    bounds=Image.fromarray(blade).getchannel('A').getbbox()
    assert bounds[0]+dx>=0 and bounds[1]+dy>=0 and bounds[2]+dx<=source.width and bounds[3]+dy<=source.height,'Blade would be clipped'
    moved=Image.new('RGBA',source.size);moved.alpha_composite(Image.fromarray(blade),(dx,dy))
    # Round-trip the component's full RGBA rectangle before placing the body
    # above it. Occlusion by its real mount is intentional, not blade deletion.
    shifted=moved.crop((bounds[0]+dx,bounds[1]+dy,bounds[2]+dx,bounds[3]+dy))
    assert shifted.tobytes()==Image.fromarray(blade).crop(bounds).tobytes(),'Rigid blade translation changed its pixels'
    result=Image.alpha_composite(moved,Image.fromarray(body))
    mask.save(EDIT/'serrated-blade-mask.png')
    Image.fromarray(blade).save(EDIT/'serrated-complete-blade.png')
    Image.fromarray(body).save(EDIT/'serrated-original-mount.png')
    result.save(EDIT/'serrated-composed-source.png')
    return result,{'originalSource':'Sources/serrated-v2.png','originalSha256':sha(WORK/'Sources/serrated-v2.png'),
                   'bladeMaskSha256':sha(EDIT/'serrated-blade-mask.png'),'wholeBladeRGBAUnchanged':True,
                   'bladeTranslationSourcePixels':[dx,dy],'bladeOccludedByOriginalMount':True,'transparentRGBZeroed':True}


def candidate(source,front,height):
    bbox=source.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    art=source.crop(bbox)
    art=art.resize((round(art.width*height/art.height),height),Image.Resampling.LANCZOS)
    tx,ty=lowest_point(front);ax,ay=lowest_point(art)
    x,y=round(tx-ax),ty-ay
    if x<0 or y<0 or x+art.width>front.width or y+art.height>front.height:
        raise ValueError('Whole painting leaves casing canvas')
    image=Image.new('RGBA',front.size);image.alpha_composite(art,(x,y))
    return image,{'uniformScale':height/(bbox[3]-bbox[1]),'offset':[x,y],'sourcePaintedBounds':bbox}


def extend_body(original,required):
    """Add actual new body paint below the intact source, not a coverage waiver."""
    p=np.asarray(original)
    # Sample the generated mount's interior facets, not transparent RGB or
    # bright bevels that could extrude into a second silver contour stripe.
    interior=np.asarray(original.getchannel('A').filter(ImageFilter.MinFilter(5)))>=240
    rgb=p[:,:,:3].astype(float)
    lum=rgb@np.array([.299,.587,.114])
    green=(rgb[:,:,1]>rgb[:,:,0]*1.35)&(rgb[:,:,1]>rgb[:,:,2]*1.25)
    chroma=(rgb.max(2)-rgb.min(2))/np.maximum(rgb.max(2),1)
    _,xx=np.indices(interior.shape)
    mount_x=lowest_point(original)[0]
    # Newly exposed backing is the mount's charcoal plane. Never extend a
    # gold strap or silver bevel as a vertical extrusion stripe above the rail.
    known=interior & (lum>=12) & (lum<85) & (chroma<.25) & ~green & (xx<mount_x)
    assert known.any(),'No retained dark mount material'
    material=p[:,:,:3].copy()
    needed=required & (p[:,:,3]<240)
    for _ in range(max(original.size)):
        if known[needed].all():
            break
        before=known.copy()
        for axis,step in ((0,-1),(0,1),(1,-1),(1,1)):
            neighbour=np.roll(before,step,axis)
            if axis==0:
                neighbour[0 if step==1 else -1,:]=False
            else:
                neighbour[:,0 if step==1 else -1]=False
            take=~known & neighbour
            material[take]=np.roll(material,step,axis)[take]
            known[take]=True
    assert known[needed].all(),'Mount material propagation incomplete'
    backing=np.zeros_like(p)
    backing[needed,:3]=material[needed]
    backing[needed,3]=255
    edited=Image.alpha_composite(Image.fromarray(backing),original)
    # Every existing opaque feature, including all leather and rivets, remains
    # byte-identical. Edits are confined to the frozen required body only.
    assert np.array_equal(np.asarray(edited)[p[:,:,3]>=240],p[p[:,:,3]>=240])
    assert np.array_equal(np.asarray(edited)[~required],p[~required])
    return edited,Image.fromarray(needed.astype('uint8')*255)


def main():
    B=load_module('rogue_mount_build','Build-RogueAssets.py')
    contract=B.check_contract()
    approval=json.loads((WORK/'script-method-approval.json').read_text())
    assert approval['maintainerReply']=='Ja, brug den kontrollerede scriptredigering'
    EDIT.mkdir(exist_ok=True)
    H=load_module('rogue_mount_halo','Build-RebuiltHealthArt.py')
    serrated,component=serrated_source()
    twin=read(WORK/'Sources/twin-guard-tiers-v2.png')
    current=json.loads((WORK/'choice-registration.json').read_text())
    assert current['venom']['accepted'],'Venom Vial must retain its independently accepted whole painting'
    result={'venom':current['venom']}
    for choice,source,cases in (('twinguard',twin,B.CASES[1:]),('serrated',serrated,B.CASES)):
        pending={};fits={}
        if choice=='twinguard':
            prior=json.loads((WORK/'twin-guard-fit.json').read_text())
            fits['hp_cap_case']=prior
            for suffix in ('','-glow'):
                pending['ornament-twinguard-hp_cap_case'+suffix]=read(OUT/('ornament-twin-guard-hp_cap_case'+suffix+'.tga'))
        for case in cases:
            c=contract['health'][case];limit=c['approvedEnvelope']
            assert sha(ROOT/c['terminalMask'])==c['terminalMaskSha256']
            required=np.asarray(Image.open(ROOT/c['terminalMask']).convert('L'))>128
            fill=Image.open(B.TEMPLATES/(case+'-fill.png')).convert('L');field=np.asarray(fill)>128
            front=read(OUT/(case+'-over.tga'))
            errors=[];accepted=None
            for height in range(limit[3]-limit[1],99,-1):
                try:
                    base,registration=candidate(source,front,height)
                    bounds=base.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
                    assert bounds[0]>=limit[0] and bounds[1]>=limit[1] and bounds[2]<=limit[2] and bounds[3]<=limit[3],'Whole weapon exceeds approved envelope'
                    edited,mask=extend_body(base,required)
                    box=edited.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
                    aligned,fit=align(edited,front,box[3]-box[1],fill)
                    b=aligned.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
                    assert b[0]>=limit[0] and b[1]>=limit[1] and b[2]<=limit[2] and b[3]<=limit[3],'Edited body exceeds approved envelope'
                    a=np.asarray(aligned)[:,:,3]
                    aa=np.asarray(Image.fromarray(((a>=240)*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)))>0
                    assert not (required&~aa).any(),'Frozen full terminal exposed after registration'
                    combined=float((((a>200)|(np.asarray(front)[:,:,3]>200))&field).sum()/field.sum())
                    assert combined<=.20,'Edited body exceeds combined fill limit'
                    record=dict(fit,case=case,height=height,bounds=b,approvedEnvelope=limit,
                                combinedFillCovered=combined,frozenTerminalExposedPixels=0,maintainerApprovedExposurePixels=0,
                                originalRegistration=registration,bodyAddedPixels=int((np.asarray(mask)>0).sum()),
                                mountingBodyOnly=True,originalOpaqueFeaturesUnchanged=True,
                                source='Script-Edited/'+choice+'-'+case+'.png',sourceEditingApprovalSha256=sha(WORK/'script-method-approval.json'))
                    accepted=aligned,mask,record
                    break
                except (AssertionError,ValueError) as error:
                    errors.append({'height':height,'failure':str(error)})
            assert accepted,(choice,case,errors)
            image,mask,record=accepted
            image.save(EDIT/(choice+'-'+case+'.png'))
            mask.save(EDIT/(choice+'-'+case+'-body-edit-mask.png'))
            record['sourceSha256']=sha(EDIT/(choice+'-'+case+'.png'))
            record['bodyEditMaskSha256']=sha(EDIT/(choice+'-'+case+'-body-edit-mask.png'))
            fits[case]=record
            pending['ornament-'+choice+'-'+case]=image
            pending['ornament-'+choice+'-'+case+'-glow']=H.halo(image)
        assets={}
        for name,image in pending.items():
            path=OUT/(name+'.tga');image.save(path,compression=None)
            assert read(path).tobytes()==image.tobytes()
            assets[name]={'sha256':sha(path),'canvas':list(image.size)}
        result[choice]={'accepted':True,'fits':fits,'assets':assets,'controlledScriptEditing':True}
    write(WORK/'script-edit-record.json',{'approvalSha256':sha(WORK/'script-method-approval.json'),
          'serratedComponent':component,'originalTwinSourceSha256':sha(WORK/'Sources/twin-guard-tiers-v2.png'),
          'originalTerminalMasksUnchanged':True,'runtimeGeometryChanged':False})
    write(WORK/'choice-registration.json',result)
    print(json.dumps({key:{case:{'bounds':item['bounds'],'addedBodyPixels':item.get('bodyAddedPixels',0),
                   'exposedPixels':item['frozenTerminalExposedPixels']} for case,item in value['fits'].items()}
                   for key,value in result.items()},indent=2))


if __name__=='__main__':
    main()
