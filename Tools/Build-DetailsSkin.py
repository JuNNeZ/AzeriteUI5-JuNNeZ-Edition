"""Build/verify the approved Details art for a selectable live preview.

Paintings use the shared uniform source replay without alpha/RGB repairs. The
separate functional mask is the enclosed transparent aperture of the row casing.
This Details-only construction has its own mask verifier; it is not a class pack
or a production approval. --install-preview is deliberately explicit.
"""
import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from ThemeSourceIntegrity import sha, whole_painting, verify_pixels

ROOT = Path(__file__).resolve().parents[1]
DRAFT = ROOT / "Assets_Draft/Details"
EXPORT = DRAFT / "Export"
NAMES = ("header", "casing", "fill")
RUNTIME_NAMES = (*NAMES, "row-mask", "row-mask-native", "fill-tile")


def native_mask(full_mask, uv):
    """Register the functional aperture into a full-UV mask canvas, not paint.

    Its aspect exactly matches the casing's runtime viewport. Only this derived
    functional mask is resampled; casing/source RGBA remain untouched.
    """
    l, r, t, b = uv
    box = (round(l*full_mask.width), round(t*full_mask.height), round(r*full_mask.width), round(b*full_mask.height))
    return full_mask.crop(box).resize((1024, 128), Image.Resampling.LANCZOS)


def material_tile(source, box):
    """A declared window into rectangular fill material, never a casing crop.

    The whole source painting/export is still retained and replay-verified.
    Native StatusBars need a margin-free power-of-two material because their
    progress updates own the fill texture coordinates. No pixels are repainted.
    """
    tile = source.crop(box)
    assert all(n > 0 and n & (n-1) == 0 for n in tile.size), "invalid material tile size"
    assert min(tile.getchannel("A").getextrema()) >= 240, "material tile includes transparent margin"
    return tile


def aperture(casing, uv):
    alpha = np.asarray(casing)[:, :, 3]
    field = Image.fromarray(np.where(alpha <= 8, 255, 0).astype("uint8")).copy()
    left, right, top, bottom = uv
    seed = (round((left + right) * casing.width / 2), round((top + bottom) * casing.height / 2))
    assert field.getpixel(seed) == 255, "casing has no transparent centre"
    ImageDraw.floodfill(field, seed, 128)
    pixels = np.where(np.asarray(field) == 128, 255, 0).astype("uint8")
    assert not (pixels[0].any() or pixels[-1].any() or pixels[:, 0].any() or pixels[:, -1].any()), "casing aperture leaks outside"
    area = (right-left) * casing.width * (bottom-top) * casing.height
    assert .4 < np.count_nonzero(pixels) / area < .92, "implausible casing aperture"
    assert not np.any((pixels > 0) & (alpha > 8)), "functional mask crosses casing paint"
    return Image.merge("RGBA", (Image.new("L", casing.size, 255),)*3 + (Image.fromarray(pixels),))


def verify(folder=EXPORT):
    manifest = json.loads((folder / "manifest.json").read_text())
    assert sha(DRAFT / "azerite-details-concept-v1.png") == manifest["approvedConcept"], "approved concept changed"
    for name in NAMES:
        item = manifest["paintings"][name]
        source = ROOT / item["source"]
        assert sha(source) == item["sourceSha256"], "source changed: " + name
        target = folder / (name + ".tga")
        assert sha(target) == item["exportSha256"], "export changed: " + name
        actual = Image.open(target).convert("RGBA")
        assert all(n > 0 and n & (n-1) == 0 for n in actual.size), "non-power-of-two texture"
        verify_pixels(whole_painting(Image.open(source).convert("RGBA"), item["transform"], actual.size), actual)
    expected = aperture(Image.open(folder / "casing.tga").convert("RGBA"), manifest["paintings"]["casing"]["uv"])
    mask = folder / "row-mask.tga"
    assert sha(mask) == manifest["maskSha256"], "functional mask changed"
    verify_pixels(expected, Image.open(mask).convert("RGBA"))
    target = folder / "row-mask-native.tga"
    assert sha(target) == manifest["nativeMaskSha256"], "native mask changed"
    verify_pixels(native_mask(expected, manifest["paintings"]["casing"]["uv"]), Image.open(target).convert("RGBA"))
    item = manifest["materialTile"]
    source = ROOT / item["source"]
    assert source.name == "fill.png" and sha(source) == item["sourceSha256"], "wrong material source"
    tile = folder / "fill-tile.tga"
    assert sha(tile) == item["exportSha256"], "material tile changed"
    verify_pixels(material_tile(Image.open(source).convert("RGBA"), item["crop"]), Image.open(tile).convert("RGBA"))
    return manifest


def build():
    EXPORT.mkdir(parents=True, exist_ok=True)
    manifest = {"schema": 1, "status": "maintainer-approved concept; live preview only",
                "approvedConcept": sha(DRAFT / "azerite-details-concept-v1.png"), "paintings": {}}
    for name in NAMES:
        path = DRAFT / "Sources" / (name + ".png")
        source = Image.open(path).convert("RGBA")
        # Keep the ENTIRE painting, including its faint alpha fringes. Only fully
        # transparent margins may be cropped. Runtime UVs ignore alpha <=8 ghost margin.
        box = source.getchannel("A").getbbox()
        scale = 1024 / (box[2]-box[0])
        height = round((box[3]-box[1]) * scale)
        canvas = (1024, 2 ** (height-1).bit_length())
        transform = {"crop": list(box), "scale": scale, "offset": [0, 0]}
        painting = whole_painting(source, transform, canvas)
        target = EXPORT / (name + ".tga")
        painting.save(target)
        solid = painting.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        # One export-pixel contour AA around the visible object, never trim solid paint.
        l, t, r, b = max(0, solid[0]-1), max(0, solid[1]-1), min(canvas[0], solid[2]+1), min(canvas[1], solid[3]+1)
        uv = [l/canvas[0], r/canvas[0], t/canvas[1], b/canvas[1]]
        manifest["paintings"][name] = {"source": path.relative_to(ROOT).as_posix(),
            "sourceSha256": sha(path), "exportSha256": sha(target), "transform": transform,
            "canvas": list(canvas), "uv": uv, "visibleAspect": (r-l)/(b-t)}
    casing = Image.open(EXPORT / "casing.tga").convert("RGBA")
    aperture(casing, manifest["paintings"]["casing"]["uv"]).save(EXPORT / "row-mask.tga")
    manifest["maskSha256"] = sha(EXPORT / "row-mask.tga")
    native_mask(Image.open(EXPORT / "row-mask.tga").convert("RGBA"),
                manifest["paintings"]["casing"]["uv"]).save(EXPORT / "row-mask-native.tga")
    manifest["nativeMaskSha256"] = sha(EXPORT / "row-mask-native.tga")
    path = DRAFT / "Sources/fill.png"
    source = Image.open(path).convert("RGBA")
    l, t, r, b = source.getchannel("A").point(lambda a: 255 if a > 240 else 0).getbbox()
    width, height = 2 ** ((r-l).bit_length()-1), 2 ** ((b-t).bit_length()-1)
    x, y = (l+r-width)//2, (t+b-height)//2
    box = [x, y, x+width, y+height]
    material_tile(source, box).save(EXPORT / "fill-tile.tga")
    manifest["materialTile"] = {"role": "rectangular-fill-material-window", "source": path.relative_to(ROOT).as_posix(),
        "sourceSha256": sha(path), "crop": box, "exportSha256": sha(EXPORT / "fill-tile.tga")}
    (EXPORT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    return verify()


def install_preview(manifest):
    dest = ROOT / "Assets/Details"
    dest.mkdir(parents=True, exist_ok=True)
    for name in RUNTIME_NAMES:
        shutil.copy2(EXPORT / (name + ".tga"), dest / (name + ".tga"))
    lines = ["-- Generated by Tools/Build-DetailsSkin.py; artwork live preview, not live-approved.",
             "local _, ns = ...", "ns.DetailsSkinArt = {"]
    for name in NAMES:
        uv = ", ".join(format(v, ".12g") for v in manifest["paintings"][name]["uv"])
        lines.append(f'\t{name} = {{ {uv} }},')
    lines.append("}")
    (ROOT / "Components/Misc/DetailsArt.lua").write_text("\n".join(lines) + "\n")
    for name in RUNTIME_NAMES:
        assert sha(dest / (name + ".tga")) == sha(EXPORT / (name + ".tga"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--install-preview", action="store_true")
    args = parser.parse_args()
    result = verify() if args.verify else build()
    if args.install_preview:
        install_preview(result)
    print(json.dumps({"sourceReplay": "PASS", "enclosedAperture": "PASS",
                      "installedPreview": args.install_preview, "liveVerified": False,
                      "aspects": {k: v["visibleAspect"] for k, v in result["paintings"].items()}}, indent=2))
