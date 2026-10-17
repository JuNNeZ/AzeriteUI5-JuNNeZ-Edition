"""Verify installed overlays, bare-case locks, runtime pivots and native views."""
from pathlib import Path
import importlib.util
import json
import re
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('aligned',ROOT/'Tools/Build-AlignedHealthEndcaps.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
checks=0
joints=[]


def check(value,label):
    global checks
    checks+=1
    assert value,label


for relative,digest in json.loads((M.WORK/'bare-casing-lock.json').read_text()).items():
    check(M.sha(ROOT/relative)==digest,'complete bare casing retained '+relative)
for theme,choices in M.CHOICES.items():
    report=json.loads((M.WORK/(theme+'-manifest.json')).read_text())
    check(report['installed'],'installed manifest '+theme)
    for relative,digest in report['sources'].items():
        check(M.sha(ROOT/relative)==digest,'whole source retained '+relative)
    for name,item in report['files'].items():
        path=ROOT/'Assets'/theme/name
        check(M.sha(path)==item['sha256'],'installed export '+str(path))
        im=M.M.read(path)
        check(list(im.size)==item['size'],'canvas '+name)
        if '-glow.' in name:
            a=np.asarray(im)
            check(np.array_equal(a[:,:,0],a[:,:,1]) and np.array_equal(a[:,:,1],a[:,:,2]),'neutral halo '+name)
    lua=(ROOT/'Core'/(theme+'Theme.lua')).read_text(encoding='utf-8-sig')
    pivots={name:(float(x),float(y)) for name,x,y in re.findall(
        r'(hp_\w+_case)\s*=\s*\{([\d.]+)/1024,([\d.]+)/256\}',lua)}
    for case in M.CASES.values():
        front=M.M.read(ROOT/'Assets'/theme/(M.casing(theme,case)+'-over.tga'))
        tx,ty=M.dip(front)
        check(pivots.get(case)==(tx,ty),'runtime pivot matches measured casing '+theme+'/'+case)
    for kind in ('PlayerFrame','TargetFrame'):
        base=M.R.DATA['original'][kind]
        flip=kind=='TargetFrame'
        for tier,case in M.CASES.items():
            if tier not in base:
                continue
            db=dict(base);db.update(base[tier])
            width=db['HealthBackdropSize'][0]
            front=M.M.read(ROOT/'Assets'/theme/(M.casing(theme,case)+'-over.tga'))
            if flip:
                front=front.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            tx,ty=M.dip(front)
            for key in choices:
                cap=M.M.read(ROOT/'Assets'/theme/('ornament-'+key+'-'+case+'.tga'))
                if flip:
                    cap=cap.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                px,py=M.dip(cap)
                check(abs(px-tx)<=.5 and py==ty,'shared bottom point '+theme+'/'+key+'/'+kind+'/'+tier)
                check(not np.any(np.asarray(cap)[ty+1:,:,3]>128),'no second lower tip '+theme+'/'+key+'/'+tier)
                joints.append({'theme':theme,'choice':key,'unit':kind,'tier':tier,
                               'maxLayoutUnitError':round(abs(px-tx)*width/front.width,6)})
proof=ROOT/'Docs/Research_Assets/Druid/Endcap-Proof-2026-10-17/Aligned-Export'
for path in proof.glob('*.tga'):
    check(M.sha(path)==M.sha(ROOT/'Assets/Druid'/path.name),'approved Druid export unchanged '+path.name)
summary={'checks':checks,'nativeViews':len(joints),'maxLayoutUnitError':max(j['maxLayoutUnitError'] for j in joints),
         'maxFillCovered':max(reg['fillCovered'] for theme in M.CHOICES
            for reg in json.loads((M.WORK/(theme+'-manifest.json')).read_text())['registrations']),
         'installed':True,'liveValidated':False,'joints':joints}
(M.WORK/'verification.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print('Aligned health endcaps:',checks,'checks;',len(joints),'native views; max point error',summary['maxLayoutUnitError'])
