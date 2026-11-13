"""Native functional fields, independent of generated painting alpha.

Masks are diagnostic/validation contracts and native-underlay selectors only.
They never stencil or erase a new painting. All source paintings stay intact.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "Docs/Research_Assets/Templates"
LAYOUT = ROOT / "Docs/Research_Assets/PriestWarlock-layouts-current.json"
LONG = ("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case")
CAST = ("cast_back", "cast_back_spiked", "cast_back_wooden")
CRITTER = ("hp_critter_case", "hp_critter_case_hi")
PANES = ("portrait_frame_hi", "portrait_frame_lo", "party_portrait_border", "minimap-border", "orb-border")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def record(path):
    return {"path": Path(path).relative_to(ROOT).as_posix(), "sha256": sha(path)}


def projection():
    loader = importlib.util.spec_from_file_location("current_fill_projection", ROOT / "Tools/PaladinFillContracts.py")
    module = importlib.util.module_from_spec(loader)
    loader.loader.exec_module(module)
    data = json.loads(LAYOUT.read_text())
    assert data["geometryOnly"] and data["coloursArePlaceholders"]
    module.LAYOUTS = data["original"]
    return module


def fill_mask(name, projected=None):
    native = Image.open(ROOT / "Assets" / (name + ".tga")).convert("RGBA")
    path = TEMPLATES / (name + "-fill.png")
    result = Image.open(path).convert("L") if path.exists() else Image.new("L", native.size)
    if name in CAST + CRITTER or name.startswith("pw_crystal_case"):
        actual = (projected or projection()).clearance_mask(name, native.size)
        result = ImageChops.lighter(result, actual)
    return result if result.getbbox() else None


def cavity(native):
    """Original closed inner pane/shadow, retaining enclosed opaque speculars."""
    wall = native.getchannel("A").point(lambda a: 255 if a > 240 else 0)
    seed = (native.width // 2, native.height // 2)
    if wall.getpixel(seed):
        raise ValueError("Native pane seed is opaque")
    ImageDraw.floodfill(wall, seed, 128)
    inner = wall.point(lambda a: 255 if a == 128 else 0)
    box = inner.getbbox()
    if not box or box[0] == 0 or box[1] == 0 or box[2] == native.width or box[3] == native.height:
        raise ValueError("Native pane is not closed")
    outside = ImageChops.invert(inner)
    ImageDraw.floodfill(outside, (0, 0), 128)
    return outside.point(lambda a: 0 if a == 128 else 255)


def native_pane_mask(name):
    native = Image.open(ROOT / "Assets" / (name + ".tga")).convert("RGBA")
    path = TEMPLATES / (name + "-fill.png")
    if path.exists() and name not in LONG + CAST:
        return Image.open(path).convert("L").point(lambda a: 255 if a > 0 else 0)
    if name in PANES:
        return cavity(native)
    if name == "point_plate":
        # Native central faceted empty-point surface; active point art is shared.
        assert native.size == (128, 128)
        mask = Image.new("L", native.size)
        ImageDraw.Draw(mask).ellipse((46, 46, 82, 82), fill=255)
        return mask
    return None


def underlay(name, mask, tint=1):
    original = np.asarray(Image.open(ROOT / "Assets" / (name + ".tga")).convert("RGBA"))
    field = np.asarray(mask.convert("L")) > 0
    pixels = np.zeros_like(original)
    pixels[field] = original[field]
    if tint != 1:
        pixels[field, :3] = np.rint(pixels[field, :3].astype(float) * tint).astype("uint8")
    return Image.fromarray(pixels)


def native_tint(name):
    # Buttons retain their live vertex tint. The independent orb rim is white.
    return 1 if name.startswith("actionbutton-border") or name == "orb-border" else 192 / 255


def freeze(theme):
    folder = ROOT / "Docs/Research_Assets" / theme / "FullSet/Contracts"
    folder.mkdir(parents=True, exist_ok=True)
    jobs = json.loads((folder.parent / "jobs.json").read_text(encoding="utf-8"))["jobs"]
    projected = projection()
    fields, panes = {}, {}
    for job in jobs:
        name = job["name"]
        native = ROOT / "Assets" / (name + ".tga")
        if not native.exists():
            continue
        for kind, mask, records in (("clearance", fill_mask(name, projected), fields), ("native-pane", native_pane_mask(name), panes)):
            if mask is None:
                continue
            digest = hashlib.sha256(mask.tobytes()).hexdigest()[:12]
            path = folder / (name + "-" + kind + "-" + digest + ".png")
            if path.exists():
                assert Image.open(path).convert("L").tobytes() == mask.tobytes()
            else:
                mask.save(path)
            records[name] = {**record(path), "native": record(native), "bounds": list(mask.getbbox())}
    result = {"schema": 1, "purpose": "native functional validation/underlays only; never a painting stencil",
        "layoutGeometry": record(LAYOUT), "projection": record(ROOT / "Tools/PaladinFillContracts.py"),
        "captureTool": record(ROOT / "Tools/Harness/priest_warlock_layout_export.lua"),
        "runtimeCrystalPlacement": record(ROOT / "Components/UnitFrames/Units/Player.lua"),
        "clearance": fields, "nativePanes": panes}
    (folder / "functional-fields.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(theme + ": frozen " + str(len(fields)) + " functional clearance fields, " + str(len(panes)) + " native panes/shadows")


if __name__ == "__main__":
    for theme in ("Priest", "Warlock"):
        freeze(theme)
