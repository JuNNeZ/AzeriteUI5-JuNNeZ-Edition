"""Whole-image neutral emission atlas exports for the authorized Lite+ WIP.

No casing, native alpha stencil, source crop or resource geometry is edited.
The documented conversion is grayscale emission + one uniform full-image
resize. Runtime resource masks clip the field; the exported atlas is opaque.
This is not the production casing-pack approval gate.
"""
from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
DRAFT=ROOT/'Assets_Draft/LitePlus-2026-11-05'
FAMILIES=('Warrior','Rogue','Shaman','DeathKnight','DemonHunter','Priest','Warlock','Monk','Evoker')
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def expected(path):
    with Image.open(path) as opened:
        source=opened.copy()
    assert source.width==source.height and source.width%2==0, 'source must be a square 2x2 field atlas'
    rgba=np.asarray(source.convert('RGBA'),dtype=np.int16)
    assert rgba[:,:,3].min()==255, 'field atlas must remain opaque'
    # Recovered DeathKnight original has a small neutral-cast spread (19/255).
    # Keep its bytes intact; this explicit grayscale conversion removes that cast.
    assert np.ptp(rgba[:,:,:3],axis=2).max()<=20, 'source must be near-neutral emission'
    return source.convert('L').convert('RGBA').resize((1024,1024),Image.Resampling.LANCZOS)
def verify(manifest,installed=False):
    assert len(manifest['atlases'])==len(FAMILIES) and {item['family'] for item in manifest['atlases']}==set(FAMILIES), 'incomplete or duplicate atlas family inventory'
    for item in manifest['atlases']:
        source=ROOT/item['source'];output=ROOT/item['export']
        assert digest(source)==item['sourceSha256'], 'source changed'
        assert digest(output)==item['exportSha256'], 'export changed'
        actual=Image.open(output).convert('RGBA')
        assert actual.size==(1024,1024)
        assert np.array_equal(np.asarray(actual),np.asarray(expected(source))), 'whole-source replay mismatch'
        if installed:
            assert digest(ROOT/item['installed'])==item['exportSha256'], 'installed WIP differs'
    return len(manifest['atlases'])
def main():
    p=argparse.ArgumentParser();p.add_argument('--install-wip',action='store_true');p.add_argument('--verify',action='store_true');a=p.parse_args()
    manifest_path=DRAFT/'resource-field-manifest.json'
    if a.verify:
        print('Verified',verify(json.loads(manifest_path.read_text()),installed=a.install_wip),'complete field atlases');return
    exports=DRAFT/'Exports';exports.mkdir(parents=True,exist_ok=True)
    manifest={'kind':'neutral-resource-field-atlas','status':'authorized WIP; live visual review pending',
        'conversion':'complete source -> grayscale emission -> RGBA -> uniform 1024x1024 resize; no crop/stencil',
        'productionApproved':False,'liveApproved':False,'atlases':[]}
    for family in FAMILIES:
        source=DRAFT/(family+'-source.png');output=exports/(family.lower()+'-materials.tga')
        im=expected(source);im.save(output,compression=None)
        installed=ROOT/'Assets/LitePlus'/output.name
        manifest['atlases'].append({'family':family,'source':str(source.relative_to(ROOT)),
            'sourceSha256':digest(source),'export':str(output.relative_to(ROOT)),
            'exportSha256':digest(output),'installed':str(installed.relative_to(ROOT))})
    verify(manifest)
    if a.install_wip:
        (ROOT/'Assets/LitePlus').mkdir(parents=True,exist_ok=True)
        for item in manifest['atlases']:shutil.copy2(ROOT/item['export'],ROOT/item['installed'])
        verify(manifest,installed=True)
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    print('Built and replay-verified',len(manifest['atlases']),'whole-source atlases;', 'installed WIP' if a.install_wip else 'draft only')
if __name__=='__main__':main()
