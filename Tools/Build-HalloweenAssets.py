"""Export whole transparent sprites from the retained generated 2x2 source."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets_Draft/Halloween/source.png"
OUTPUT = ROOT / "Assets/Halloween"


def build():
    source = Image.open(SOURCE).convert("RGBA")
    width, height = source.size
    assert width == height and width % 2 == 0
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {"source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "sprites": {}}
    for name, column, row in [("pumpkin", 0, 0), ("bats", 1, 0), ("web", 0, 1), ("web-spider", 1, 1)]:
        box = (column * width // 2, row * height // 2, (column + 1) * width // 2, (row + 1) * height // 2)
        tile = source.crop(box)
        bounds = tile.getchannel("A").getbbox()
        assert bounds, name
        painting = tile.crop(bounds)
        # One uniform transform, including the original alpha; no stencil or repaint.
        scale = 120 / max(painting.size)
        size = tuple(max(1, round(value * scale)) for value in painting.size)
        painting = painting.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (128, 128))
        offset = ((128 - size[0]) // 2, (128 - size[1]) // 2)
        canvas.paste(painting, offset)
        path = OUTPUT / f"{name}.tga"
        canvas.save(path, compression=None)
        manifest["sprites"][name] = {"quadrant": box, "alpha_bounds": bounds, "scale": scale,
                                      "size": size, "offset": offset,
                                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    head_source = SOURCE.with_name("horseman-head-source.png")
    head = Image.open(head_source).convert("RGBA")
    bounds = head.getchannel("A").getbbox()
    painting = head.crop(bounds)
    scale = 240 / max(painting.size)
    size = tuple(max(1, round(value * scale)) for value in painting.size)
    canvas = Image.new("RGBA", (256, 256))
    offset = ((256-size[0])//2, (256-size[1])//2)
    canvas.paste(painting.resize(size, Image.Resampling.LANCZOS), offset)
    path = OUTPUT / "horseman-head.tga"
    canvas.save(path, compression=None)
    manifest["sprites"]["horseman-head"] = {
        "source_sha256": hashlib.sha256(head_source.read_bytes()).hexdigest(),
        "alpha_bounds": bounds, "scale": scale, "size": size, "offset": offset,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    animated_source = SOURCE.with_name("animated-sprites-source.png")
    atlas = Image.open(animated_source).convert("RGBA")
    width, height = atlas.size
    assert width == height and width % 2 == 0
    for name, column, row, dimension in [("horseman-face",0,0,256), ("soul-light",1,0,128),
                                          ("autumn-leaf",0,1,128), ("spider",1,1,64)]:
        box = (column*width//2, row*height//2, (column+1)*width//2, (row+1)*height//2)
        tile = atlas.crop(box)
        bounds = tile.getchannel("A").getbbox()
        assert bounds, name
        painting = tile.crop(bounds)
        scale = (dimension-8) / max(painting.size)
        size = tuple(max(1, round(value*scale)) for value in painting.size)
        offset = ((dimension-size[0])//2, (dimension-size[1])//2)
        canvas = Image.new("RGBA", (dimension,dimension))
        canvas.paste(painting.resize(size, Image.Resampling.LANCZOS), offset)
        path = OUTPUT / f"{name}.tga"
        canvas.save(path, compression=None)
        manifest["sprites"][name] = {"source_sha256": hashlib.sha256(animated_source.read_bytes()).hexdigest(),
            "quadrant": box, "alpha_bounds": bounds, "scale": scale, "size": size, "offset": offset,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    face_source = SOURCE.with_name("face-v2-source.png")
    painting = Image.open(face_source).convert("RGBA")
    bounds = painting.getchannel("A").getbbox()
    painting = painting.crop(bounds)
    scale = 248 / max(painting.size)
    size = tuple(max(1, round(value*scale)) for value in painting.size)
    offset = ((256-size[0])//2, (256-size[1])//2)
    canvas = Image.new("RGBA", (256,256))
    canvas.paste(painting.resize(size, Image.Resampling.LANCZOS), offset)
    path = OUTPUT / "horseman-face-v2.tga"
    canvas.save(path, compression=None)
    manifest["sprites"]["horseman-face-v2"] = {
        "source_sha256": hashlib.sha256(face_source.read_bytes()).hexdigest(),
        "alpha_bounds": bounds, "scale": scale, "size": size, "offset": offset,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Exported ten RGBA sprites; green carved face V2 retained separately")


if __name__ == "__main__":
    build()
