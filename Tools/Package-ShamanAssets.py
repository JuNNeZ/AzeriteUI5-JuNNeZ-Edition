"""Bundle Shaman sources, exports, runtime and hash-bound review evidence."""
from pathlib import Path
import importlib.util
import hashlib
import json
import zipfile

ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'Docs/Research_Assets/Shaman'
OUT=ROOT/'Assets_Draft/Shaman'
spec=importlib.util.spec_from_file_location('shaman_package_check',ROOT/'Tools/Check-ShamanAssets.py')
C=importlib.util.module_from_spec(spec);spec.loader.exec_module(C)

def main():
    manifest=C.check();C.verify_review();C.check_installed()
    files=set(p for p in WORK.rglob('*') if p.is_file() and p.suffix not in ('.zip','.pyc') and p.name!='package-verification.json')
    files.update(p for p in OUT.rglob('*') if p.is_file())
    files.update(p for p in (ROOT/'Assets/Shaman').rglob('*') if p.is_file())
    names=('Core/ShamanTheme.lua','Core/Core.xml','Core/ThemeEffects.lua','Core/LegacyHUD.lua','Options/OptionsPages/Themes.lua',
           'Tools/Build-ShamanAssets.py','Tools/Check-ShamanAssets.py','Tools/Render-ShamanAssets.py',
           'Tools/Render-ShamanMountDiagnostic.py','Tools/Package-ShamanAssets.py','Tools/Prepare-ShamanCapRepair.py',
           'Tools/Install-ShamanTheme.py','Tools/Harness/shaman_theme_harness.lua','Tools/Run-Elune.ps1','Core/ThemeEngine.lua',
           'Tools/Build-DruidArt.py','Tools/ThemeHealthEndcaps.py','Tools/ThemeOrbGlass.py','Tools/ThemeButtonShapes.py',
           'Tools/PaladinFillContracts.py','Tools/Build-RebuiltHealthArt.py','Tools/Build-ImplementedThemeSheets.py',
           'Tools/Build-ThemeConceptBase.py','Tools/Check-ThemeAssetStyle.py','Docs/Theme Asset Geometry.json',
           'Docs/Theme Asset Production Workflow.md','Docs/Theme Asset Fitting Checklist.md','Docs/Theme Asset Style Key.md',
           'Docs/Research_Assets/EndcapFit-2026-10-17/layouts.json','Docs/Research_Assets/Paladin/Rebuild-2026-10-14/layouts.json')
    files.update(ROOT/name for name in names)
    assert all(p.is_file() for p in files),'Incomplete source/runtime handoff'
    # The native geometry/template inputs are retained alongside their source
    # hashes. Reproduction uses this repository's unchanged native media.
    files.update(p for p in (ROOT/'Docs/Research_Assets/Templates').glob('*') if p.is_file())
    archive=WORK/'Shaman-Storm-Stone-and-Tides-source-pack.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for path in sorted(files): z.write(path,path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None,'ZIP CRC failure'
        for name,item in manifest['assets'].items():
            raw=z.read('Assets_Draft/Shaman/'+name+'.tga')
            assert hashlib.sha256(raw).hexdigest()==item['sha256'],name
    C.save(WORK/'package-verification.json',{'archive':archive.name,'sha256':C.sha(archive),'files':len(files),'exportedTextures':len(manifest['assets']),
           'zipCRCVerified':True,'allExportHashesVerified':True,'liveRetailValidated':False,'liveForeverValidated':False})
    print(str(archive),'files:',len(files),'bytes:',archive.stat().st_size)

if __name__=='__main__': main()
