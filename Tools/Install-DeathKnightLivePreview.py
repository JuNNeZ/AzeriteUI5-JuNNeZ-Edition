"""Install the explicitly authorized DK WIP preview, retaining failed fit gates.

Requires --live-preview. This does not create production/live approval records.
Paintings stay intact; native functional recess/glass are separate underlays.
"""
from pathlib import Path
import argparse
import hashlib
import json

import numpy as np
from PIL import Image, ImageChops, ImageFilter

from ThemeHealthEndcaps import lowest_point, terminal_coverage
from ThemeSourceIntegrity import whole_painting, verify_pixels
from DeathKnightTooltipAtlas import PATCHES, pack as pack_tooltip, joins as tooltip_joins

ROOT = Path(__file__).resolve().parent.parent
DRAFT = ROOT / "Assets_Draft/DeathKnight/FullSet"
OUT = ROOT / "Assets/DeathKnight"
DOC = ROOT / "Docs/Research_Assets/DeathKnight/FullSet"
LONG = ("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case")
FRONTS = LONG + ("cast_back", "cast_back_spiked", "cast_back_wooden")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return Image.open(path).convert("RGBA")


def bounded_cap(source, case, footprint):
    crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    solid = source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    tx, ty = lowest_point(case)
    for height in range(int(footprint[3] - footprint[1]), 7, -1):
        scale = height / (solid[3] - solid[1])
        painting = source.crop(crop)
        painting = painting.resize((round(painting.width * scale), round(painting.height * scale)), Image.Resampling.LANCZOS)
        px, py = lowest_point(painting)
        offset = [round(tx - px), round(ty - py)]
        if min(offset) < 0 or offset[0] + painting.width > case.width or offset[1] + painting.height > case.height:
            continue
        transform = {"crop": list(crop), "scale": scale, "offset": offset}
        cap = whole_painting(source, transform, case.size)
        box = cap.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
        if box[0] < footprint[0] or box[1] < footprint[1] or box[2] > footprint[2] or box[3] > footprint[3]:
            continue
        return cap, transform, box
    raise ValueError("Whole source cannot fit approved footprint")


def square_slot(source):
    crop = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    scale = 240 / max(crop[2] - crop[0], crop[3] - crop[1])
    size = [round((crop[i + 2] - crop[i]) * scale) for i in (0, 1)]
    transform = {"crop": list(crop), "scale": scale, "offset": [(256 - size[0]) // 2, (256 - size[1]) // 2]}
    return whole_painting(source, transform, (256, 256)), transform


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-preview", action="store_true")
    args = parser.parse_args()
    if not args.live_preview:
        parser.error("Explicit --live-preview authorization is required; production gates remain failed")
    source_manifest = json.loads((DRAFT / "manifest.json").read_text())
    contracts = json.loads((DOC / "Contracts/approved-footprints.json").read_text())
    assert contracts["maintainerApproved"] is True
    files, records = {}, {}
    media = []
    for name, item in source_manifest["assets"].items():
        path = ROOT / item["path"]
        assert sha(path) == item["sha256"], "Stale candidate: " + name
        painting = read(path)
        files[name] = painting
        records[name] = {"candidate": item["path"], "candidateSha256": sha(path), "construction": "unchanged whole candidate"}
        if name == "border-tooltip":
            files[name] = pack_tooltip(painting)
            assert not tooltip_joins(files[name]), "Tooltip corner/edge mismatch"
            records[name].update(construction="DK tooltip eight-cell packing v1", patches=PATCHES)
        if name not in ("bag-icon", "options-box"):
            media.append(name)
        native_path = ROOT / "Assets" / (name + ".tga")
        fill_path = ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")
        if name in FRONTS:
            mask = np.asarray(Image.open(fill_path).convert("L")) > 128
            native = np.asarray(read(native_path))
            pixels = np.zeros_like(native)
            pixels[mask] = native[mask]
            files[name] = Image.fromarray(pixels)
            files[name + "-over"] = painting
            records[name].update(construction="exact native functional recess; complete painting in separate foreground", nativeSha256=sha(native_path), fillMaskSha256=sha(fill_path))
            records[name + "-over"] = {"candidate": item["path"], "candidateSha256": sha(path), "construction": "unchanged whole candidate"}
        elif native_path.exists() and fill_path.exists():
            # Exact native glass/shading below, never substituted for paint alpha.
            native = np.array(read(native_path))
            mask = np.asarray(Image.open(fill_path).convert("L")) > 0
            under = np.zeros_like(native)
            under[mask] = native[mask]
            if name.startswith(("orb_case", "pw_crystal_case")):
                under[mask, :3] = np.rint(under[mask, :3].astype(float) * 192 / 255).astype("uint8")
            files[name] = Image.alpha_composite(Image.fromarray(under), painting)
            records[name].update(construction="native functional glass/shading under unchanged whole painting", nativeSha256=sha(native_path), fillMaskSha256=sha(fill_path))
    dips, edges, fits = {}, {"frost": {}, "unholy": {}}, {}
    for name in LONG:
        contract = contracts["cases"][name]
        native_path = ROOT / contract["native"]
        assert sha(native_path) == contract["nativeSha256"]
        assert sha(ROOT / contract["nativeTerminalMask"]) == contract["nativeTerminalMaskSha256"]
        native = read(native_path)
        tx, ty = lowest_point(native)
        dips[name] = [tx / native.width, ty / native.height]
        for key, relative in (("frost", "FullSet/Revisions/health-endcap-frost-v2.png"), ("unholy", "Sources/health-endcap-unholy.png")):
            path = ROOT / "Assets_Draft/DeathKnight" / relative
            cap, transform, box = bounded_cap(read(path), native, contract["approvedFootprint"])
            output_name = "ornament-" + key + "-" + name
            files[output_name] = cap
            edges[key][name] = box[0]
            records[output_name] = {"source": path.relative_to(ROOT).as_posix(), "sourceSha256": sha(path), "transform": transform, "construction": "whole painting, bounded WIP registration"}
            fits[output_name] = {"bounds": list(box), "footprint": contract["approvedFootprint"], "accepted": False, **terminal_coverage(native, cap)}
    for name, source_name in (("cast-head", "cast-head-blood"), ("resource-badge", "resource-badge"), ("minimap-north", "minimap-north")):
        path = ROOT / "Assets_Draft/DeathKnight/Sources" / (source_name + ".png")
        files[name], transform = square_slot(read(path))
        records[name] = {"source": path.relative_to(ROOT).as_posix(), "sourceSha256": sha(path), "transform": transform, "construction": "whole painting in shared square slot"}
    for name, image in list(files.items()):
        if name in LONG or name.startswith("ornament-"):
            painting = files.get(name + "-over", image)
            alpha = painting.getchannel("A")
            halo = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(9)), alpha).filter(ImageFilter.GaussianBlur(3))
            glow = Image.new("RGBA", image.size, (255, 255, 255, 0))
            glow.putalpha(halo)
            files[name + "-glow"] = glow
            records[name + "-glow"] = {"construction": "neutral halo from complete painting alpha", "painting": name + "-over" if name + "-over" in files else name}
    # Preflight existing task-owned exports before any copy, retaining user edits.
    old = json.loads((OUT / "manifest.json").read_text()) if (OUT / "manifest.json").exists() else None
    data_path = ROOT / "Core/DeathKnightThemeData.lua"
    if data_path.exists():
        assert old and sha(data_path) == old["runtimeDataSha256"], "Existing runtime data changed"
    for path in OUT.glob("*.tga") if OUT.exists() else []:
        assert old and path.stem in old["assets"] and sha(path) == old["assets"][path.stem]["sha256"], "Existing runtime painting changed: " + str(path)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, image in files.items():
        path = OUT / (name + ".tga")
        image.save(path, compression=None)
        verify_pixels(image, read(path))
        records[name].update(sha256=sha(path), canvas=list(image.size))
    # Data only: the runtime module uses the shared engine for placement/settings.
    def lua_map(mapping):
        return "{ " + ", ".join('["' + key + '"] = ' + ("{ " + ", ".join(str(v) for v in value) + " }" if isinstance(value, list) else str(value)) for key, value in sorted(mapping.items())) + " }"
    data = "-- Generated by Tools/Install-DeathKnightLivePreview.py; WIP, not production accepted.\nlocal _, ns = ...\nns.DeathKnightThemeData = {\n\tmedia = { " + ", ".join('["' + name + '"] = true' for name in sorted(media)) + " },\n\tdips = " + lua_map(dips) + ",\n\tedges = { frost = " + lua_map(edges["frost"]) + ", unholy = " + lua_map(edges["unholy"]) + " }\n}\n"
    data_path.write_text(data, encoding="utf-8", newline="\n")
    manifest = {"schema": 1, "installationMode": "explicitly authorized WIP live preview, 2026-11-07", "productionAccepted": False,
        "sourceCandidateManifestSha256": sha(DRAFT / "manifest.json"), "sourceFitReportSha256": sha(DRAFT / "fit-report.json"),
        "approvedFootprintsSha256": sha(DOC / "Contracts/approved-footprints.json"), "runtimeDataSha256": sha(data_path),
        "assets": records, "capDiagnostics": fits, "liveRetailValidated": False, "liveForeverValidated": False}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (DOC / "live-preview-install.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Installed {len(files)} WIP textures, {len(media)} native media entries; RGBA roundtrips passed. Production gates retained as failed.")


if __name__ == "__main__":
    main()
