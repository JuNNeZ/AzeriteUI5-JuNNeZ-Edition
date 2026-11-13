"""Verify WIP runtime wiring and exact layer construction, not production fit."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageChops, ImageFilter

from ThemeHealthEndcaps import lowest_point
from ThemeSourceIntegrity import verify_pixels, whole_painting
from DeathKnightTooltipAtlas import PATCHES, pack as pack_tooltip, joins as tooltip_joins

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets/DeathKnight"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert("RGBA")


def main():
    manifest = json.loads((OUT / "manifest.json").read_text())
    assert manifest["productionAccepted"] is False, "WIP is not production acceptance"
    assert manifest["sourceCandidateManifestSha256"] == sha(ROOT / "Assets_Draft/DeathKnight/FullSet/manifest.json")
    assert manifest["sourceFitReportSha256"] == sha(ROOT / "Assets_Draft/DeathKnight/FullSet/fit-report.json")
    assert manifest["runtimeDataSha256"] == sha(ROOT / "Core/DeathKnightThemeData.lua")
    assert manifest["approvedFootprintsSha256"] == sha(ROOT / "Docs/Research_Assets/DeathKnight/FullSet/Contracts/approved-footprints.json")
    assets = manifest["assets"]
    assert {p.stem for p in OUT.glob("*.tga")} == set(assets), "Unlisted/missing runtime textures"
    for name, item in assets.items():
        target = OUT / (name + ".tga")
        assert sha(target) == item["sha256"], "Stale runtime texture: " + name
        actual = read(target)
        method = item["construction"]
        if item.get("source"):
            source = ROOT / item["source"]
            assert sha(source) == item["sourceSha256"]
            expected = whole_painting(read(source), item["transform"], actual.size)
        elif method == "DK tooltip eight-cell packing v1":
            assert name == "border-tooltip" and item["patches"] == PATCHES
            source = ROOT / item["candidate"]
            assert sha(source) == item["candidateSha256"]
            expected = pack_tooltip(read(source))
            assert tooltip_joins(read(source)), "Rejected original tooltip must fail joins"
            assert not tooltip_joins(actual), "Tooltip join profiles do not align"
        elif method == "unchanged whole candidate":
            source = ROOT / item["candidate"]
            assert sha(source) == item["candidateSha256"]
            expected = read(source)
        elif method.startswith(("exact native functional recess", "native functional glass")):
            source = ROOT / item["candidate"]
            assert sha(source) == item["candidateSha256"]
            native = ROOT / "Assets" / (name + ".tga")
            mask = ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")
            assert sha(native) == item["nativeSha256"] and sha(mask) == item["fillMaskSha256"]
            native_pixels = np.asarray(read(native))
            threshold = 128 if method.startswith("exact native") else 0
            field = np.asarray(Image.open(mask).convert("L")) > threshold
            pixels = np.zeros_like(native_pixels)
            pixels[field] = native_pixels[field]
            if method.startswith("native functional") and name.startswith(("orb_case", "pw_crystal_case")):
                pixels[field, :3] = np.rint(pixels[field, :3].astype(float) * 192 / 255).astype("uint8")
            expected = Image.fromarray(pixels)
            if method.startswith("native functional"):
                expected = Image.alpha_composite(expected, read(source))
        elif method == "neutral halo from complete painting alpha":
            alpha = read(OUT / (item["painting"] + ".tga")).getchannel("A")
            halo = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(9)), alpha).filter(ImageFilter.GaussianBlur(3))
            expected = Image.new("RGBA", actual.size, (255, 255, 255, 0))
            expected.putalpha(halo)
        else:
            raise ValueError("Unsupported WIP construction: " + name)
        verify_pixels(expected, actual)
    for name, item in manifest["capDiagnostics"].items():
        cap = read(OUT / (name + ".tga"))
        box = cap.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
        limit = item["footprint"]
        assert box[0] >= limit[0] and box[1] >= limit[1] and box[2] <= limit[2] and box[3] <= limit[3], "Cap exceeds approved maximum"
        base = name.split("-", 2)[2]
        native = lowest_point(read(ROOT / "Assets" / (base + ".tga")))
        point = lowest_point(cap)
        assert abs(native[0] - point[0]) <= .5 and native[1] == point[1], "Native mounting toe moved"
        assert item["accepted"] is False, "Failed cap was labelled accepted"
    scripts = [node.attrib["file"].replace("\\", "/") for node in ET.parse(ROOT / "Core/Core.xml").iter() if node.tag.endswith("Script")]
    assert scripts.index("ThemeEngine.lua") < scripts.index("DeathKnightThemeData.lua") < scripts.index("DeathKnightTheme.lua") < scripts.index("ThemeEffects.lua")
    clients = []
    for client in ("_retail_", "_forever_"):
        folder = Path("C:/Program Files (x86)/World of Warcraft") / client / "Interface/AddOns/AzeriteUI5_JuNNeZ_Edition"
        if not folder.exists():
            continue
        for relative in ("Core/Core.xml", "Core/DeathKnightTheme.lua", "Core/DeathKnightThemeData.lua", "Core/ThemeEffects.lua", "Options/OptionsPages/Themes.lua"):
            assert sha(folder / relative) == sha(ROOT / relative), "Stale game file: " + client + "/" + relative
        for name, item in assets.items():
            assert sha(folder / "Assets/DeathKnight" / (name + ".tga")) == item["sha256"], "Game cannot see runtime art: " + name
        clients.append(client)
    assert clients, "No linked client could be verified"
    print(f"PASS: {len(assets)} runtime textures replay exactly; bounded WIP caps, load order, and linked clients {', '.join(clients)} verified. Live rendering untested.")


if __name__ == "__main__":
    main()
