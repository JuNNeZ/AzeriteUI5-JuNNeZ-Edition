"""Typed, exact RGBA replay for whole paintings plus native functional underlays.

This validates a separately authorized WIP preview. It never grants production,
maintainer visual or live-client acceptance, and retains all numeric failures.
"""
import json

import numpy as np
from PIL import Image, ImageChops, ImageFilter

from PriestWarlockAssetContracts import ROOT, LONG, CAST, record, sha, underlay, native_tint, native_pane_mask
from ThemeHealthEndcaps import lowest_point, terminal_coverage
from ThemeSourceIntegrity import whole_painting, verify_pixels, aperture
from PriestWarlockBorderAtlas import pack as pack_border, NAMES as BORDERS
from DeathKnightTooltipAtlas import joins


def read(path):
    return Image.open(path).convert("RGBA")


def checked(item):
    path=(ROOT/item["path"]).resolve()
    assert path.is_relative_to(ROOT.resolve()) and sha(path)==item["sha256"], "Missing/stale source: "+str(path)
    return path


def replay_painting(item):
    assert item["role"]=="whole-painting"
    optional={"bridge","bridgeApproval"} if "bridge" in item else set()
    assert set(item)=={"path","sha256","canvas","role","source","transform"}|optional, "Unsupported painting operation"
    source=checked(item["source"]);target=checked(item)
    assert source!=target
    painting=whole_painting(read(source),item["transform"],item["canvas"])
    approved_bridge(item)
    verify_pixels(painting,read(target))
    return painting


def approved_bridge(item):
    if "bridge" not in item:
        return None
    approval=json.loads(checked(item["bridgeApproval"]).read_text(encoding="utf-8"))
    assert approval.get("maintainerApproved") is True, "Foreground bridge is not approved"
    assert approval["sourceSha256"]==item["source"]["sha256"], "Bridge approval source changed"
    assert approval["bridgeSha256"]==item["bridge"]["sha256"], "Bridge approval mask changed"
    return Image.open(checked(item["bridge"])).convert("L")


def validate_native_shadows(contracts):
    for name,item in contracts.get("nativePaneExtensions",{}).items():
        assert name in ("pw_crystal_case","pw_crystal_case_low")
        assert item["construction"]=="exact-native-black-shadow-1"
        original=np.asarray(Image.open(checked(item["original"])).convert("L"))>0
        assert np.array_equal(original,np.asarray(native_pane_mask(name))>0), "Original crystal pane authority changed"
        native=np.asarray(read(checked(contracts["nativePanes"][name]["native"])))
        expected=original | ((native[:,:,:3]==0).all(axis=2) & (native[:,:,3]>0))
        actual=np.asarray(Image.open(checked(contracts["nativePanes"][name])).convert("L"))>0
        assert np.array_equal(expected,actual), "Native crystal shadow selector changed"


def replay_composed(name,item,contracts):
    method=item["construction"]
    allowed={"painting","construction","path","sha256"}
    if method!="whole-painting":allowed|={"native","field"}
    if method=="native-under-whole-painting":allowed.add("nativeTint")
    assert set(item)==allowed, "Unsupported composition operation"
    assert method in ("whole-painting","native-functional-recess","native-under-whole-painting")
    base=name.removesuffix("-over");painting=replay_painting(item["painting"]);expected=painting
    if method!="whole-painting":
        expected_field=contracts["clearance"].get(base) if method=="native-functional-recess" or base.startswith("hp_critter_case") else contracts["nativePanes"].get(base)
        assert item["field"]==expected_field, "Unrecognized native underlay field"
        assert item["native"]==expected_field["native"], "Native source differs from frozen field authority"
        native=checked(item["native"])
        assert native==(ROOT/"Assets"/(base+".tga")).resolve()
        mask=Image.open(checked(item["field"])).convert("L")
        if method=="native-functional-recess":
            assert base in LONG+CAST and name==base
            mask=mask.point(lambda a:255 if a>128 else 0);expected=underlay(base,mask)
        else:
            assert item["nativeTint"]==native_tint(base), "Native glass/shadow brightness changed"
            expected=Image.alpha_composite(underlay(base,mask,item["nativeTint"]),painting)
    verify_pixels(expected,read(checked(item)))
    return painting,expected


def candidate(theme):
    draft=ROOT/"Assets_Draft"/theme/"FullSet"
    composed=json.loads((draft/"Composed/manifest.json").read_text())
    checked(composed["sourceManifest"]);contracts_path=checked(composed["functionalContracts"])
    contracts=json.loads(contracts_path.read_text())
    validate_native_shadows(contracts)
    for key in ("layoutGeometry","projection","captureTool","runtimeCrystalPlacement"):
        checked(contracts[key])
    assert composed["productionAccepted"] is False
    source_manifest=json.loads((draft/"manifest.json").read_text())
    repair_proof=None
    if theme=="Priest" and any("/GapRepair/" in item["source"]["path"] for item in source_manifest["assets"].values()):
        from PriestInnerEdgeRepair import verify_repairs, NAMES as REPAIRED
        repair_proof=verify_repairs()
        repairs=json.loads(checked(repair_proof).read_text())["assets"]
        for name in REPAIRED:
            assert source_manifest["assets"][name]["source"]==repairs[name]["editedSource"], "Unverified replacement of repaired painting"
            assert source_manifest["assets"][name]["transform"]=={"crop":[0,0,*source_manifest["assets"][name]["canvas"]],"scale":1,"offset":[0,0]}
    assert len(source_manifest["assets"])==35, "Incomplete full source set"
    assert len(composed["assets"])==42, "Incomplete foreground set"
    files,records,failures={},{},[]
    for name,item in composed["assets"].items():
        base=name.removesuffix("-over")
        painting,expected=replay_composed(name,item,contracts)
        field=contracts["clearance"].get(base)
        if field and name==base:
            try:aperture(painting,Image.open(checked(field)),approved_bridge(item["painting"]))
            except ValueError as error:failures.append(base+": "+str(error))
        files[name]=expected;records[name]={"construction":"verified-native-underlay-composition-1","candidate":item}
        if base.startswith("orb_case") and name==base:
            mask=np.asarray(Image.open(checked(contracts["nativePanes"][base])).convert("L"))>0
            native=underlay(base,Image.open(checked(contracts["nativePanes"][base])),native_tint(base))
            if np.any(np.asarray(expected)[mask]!=np.asarray(native)[mask]):
                failures.append(base+": composed RGBA changes exact native glass")
    caps=json.loads((draft/"Endcaps/fit-report.json").read_text())
    footprint_path=ROOT/"Docs/Research_Assets"/theme/"Contracts/approved-footprints.json"
    limits=json.loads(footprint_path.read_text())["cases"]
    for item in limits.values():
        for key in ("native","nativeTerminal","druidBare"):
            checked(item[key])
        for cap in item["druidCaps"]:
            checked(cap)
    motif="tuure" if theme=="Priest" else "ulthalesh"
    for base,item in caps["cases"].items():
        frozen=item["frozenTerminal"]
        assert frozen["painting"]["sha256"]==sha(draft/"Composed"/(base+"-over.tga")), "Stale frozen terminal"
        checked(frozen["mask"])
        source=read(checked(item["source"]))
        expected=whole_painting(source,item["best"]["transform"],files[base].size)
        verify_pixels(expected,read(checked(item["export"])))
        box=expected.getchannel("A").point(lambda a:255 if a>128 else 0).getbbox();limit=limits[base]["approvedFootprint"]
        assert box[0]>=limit[0] and box[1]>=limit[1] and box[2]<=limit[2] and box[3]<=limit[3], "Cap exceeds approved maximum"
        nx,ny=limits[base]["nativeToe"];x,y=lowest_point(expected)
        assert abs(nx-x)<=.5 and ny==y, "Cap misses native toe"
        actual=terminal_coverage(files[base+"-over"],expected)
        assert actual==item["best"]["paintedTerminal"]
        if not item["best"]["numericPassed"]:
            failures.append(base+" endcap: "+str(item["best"]["error"]))
        name="ornament-"+motif+"-"+base
        files[name]=expected;records[name]={"construction":"whole-source-cap-1","fit":item}
    borders=json.loads((draft/"BorderAtlases/manifest.json").read_text())
    assert borders["numericPassed"]
    for name,item in borders["assets"].items():
        source=read(checked(item["source"]))
        shifts={2:(1,0)} if theme=="Warlock" and name!="border-aura" else None
        native=None
        if theme=="Priest" or name in ("border-tooltip", "border-aura"):
            native=read(checked(item["nativeRailAuthority"]))
            assert item["nativeRailAuthority"]==record(ROOT/"Assets"/(name+".tga"))
        expected,recipes=pack_border(source,shifts,native)
        assert recipes==item["recipes"]
        diagnostic=expected if expected.height==64 else expected.resize((512,64),Image.Resampling.NEAREST)
        assert not joins(diagnostic)
        verify_pixels(expected,read(checked(item["export"])))
        files[name]=expected;records[name]={"construction":"intact-corner-rail-atlas-1","atlas":item}
    for name in list(files):
        if name in LONG or name.startswith("ornament-"):
            alpha=files.get(name+"-over",files[name]).getchannel("A")
            halo=ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(9)),alpha).filter(ImageFilter.GaussianBlur(3))
            image=Image.new("RGBA",files[name].size,(255,255,255,0));image.putalpha(halo)
            files[name+"-glow"]=image;records[name+"-glow"]={"construction":"neutral-whole-assembly-halo-1","painting":name+"-over" if name+"-over" in files else name}
    cast_path=draft/"Review/CastSockets/fit-report.json"
    casts=json.loads(cast_path.read_text())
    for name,item in casts["cases"].items():
        assert item["head"]["sha256"]==sha(draft/"Composed/cast-head.tga"), "Stale painted cast-head test"
        assert item["front"]["sha256"]==sha(draft/"Composed"/(name+"-over.tga")), "Stale painted cast-socket test"
        checked(item["socket"])
        if not item["numericPassed"]:
            failures.append(name+" cast head: painted socket/centering failed")
    # This pack-specific exception is conditional on freshly recomputed,
    # hash-bound measurements. Keep strict failures visible in every manifest.
    from PriestWarlockFitTolerance import accepted
    tolerance=accepted(theme)
    strict_failures=list(failures)
    if tolerance:
        failures=[failure for failure in failures if not any(failure.startswith(prefix) for prefix in tolerance["allowedFailurePrefixes"])]
    return files,records,{"sourceReplayPassed":True,**({"innerEdgeRepair":repair_proof} if repair_proof else {}),"functionalFailures":failures,"numericPassed":not failures,
        "strictNumericPassed":not strict_failures,"strictFunctionalFailures":strict_failures,"maintainerFitTolerance":tolerance,
        "composedManifest":record(draft/"Composed/manifest.json"),"capReport":record(draft/"Endcaps/fit-report.json"),
        "borderManifest":record(draft/"BorderAtlases/manifest.json"),"footprints":record(footprint_path),"castSockets":record(cast_path)}
