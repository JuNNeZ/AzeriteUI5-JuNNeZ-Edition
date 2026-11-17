"""Export the new painting and assemble a DRAFT header in recorded widget calls.

python Tools/Build-GuildBannerPreview.py <current-members-snapshot.json>
No runtime asset, mapping or geometry is modified. Rendering uses the existing
Preview-GuildWindow.py. The seal/end retain uniform scale; only the quiet middle
stretches horizontally, as a future three-slice runtime drawing would.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DRAFT = ROOT / "Assets_Draft/Guild/Banner-v2"
SOURCE = DRAFT / "banner-source.png"
source = Image.open(SOURCE).convert("RGBA")
assert source.size == (2172, 724), "Review a changed painting before exporting"
# Remove the generated black letterbox, keeping the complete painted rails.
band = source.crop((0, 148, 2172, 576))
assert band.height == 428
atlas = Image.new("RGBA", (1024, 128))
# Native-height square on the left preserves all facets of the crystal seal.
atlas.paste(band.crop((0, 0, 428, 428)).resize((128, 128), Image.Resampling.LANCZOS), (0, 0))
atlas.paste(band.crop((428, 0, 1958, 428)).resize((832, 128), Image.Resampling.LANCZOS), (128, 0))
atlas.paste(band.crop((1958, 0, 2172, 428)).resize((64, 128), Image.Resampling.LANCZOS), (960, 0))
atlas.save(DRAFT / "header.tga")
atlas.save(DRAFT / "header-preview.png")

items = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
header = next(w for w in items if w.get("texture", "").replace("\\", "/").endswith("/Guild/header.tga"))
original = dict(header)
draw_height, draw_width = original["h"], original["w"]
left, right = draw_height, draw_height / 2
next_id = max(w["id"] for w in items) + 1
for index, (offset, width, u0, u1) in enumerate([
    (0, left, 0, 128/1024),
    (left, draw_width-left-right, 128/1024, 960/1024),
    (draw_width-right, right, 960/1024, 1),
]):
    region = header if index == 0 else dict(original)
    region.update(texture="Assets_Draft/Guild/Banner-v2/header.tga", x=original["x"]+offset,
                  w=width, uv=[u0, u1, 0, 1])
    if index:
        region["id"] = next_id
        next_id += 1
        items.append(region)
snapshot = DRAFT / "assembled-members.json"
snapshot.write_text(json.dumps(items, ensure_ascii=False), encoding="utf-8")
subprocess.run([sys.executable, str(ROOT / "Tools/Preview-GuildWindow.py"), str(snapshot),
                str(DRAFT / "assembled-members-preview.png")], check=True)
proof = {
    "status": "draft - awaiting assembled visual approval; not installed",
    "sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    "exportSha256": hashlib.sha256((DRAFT / "header.tga").read_bytes()).hexdigest(),
    "sourceSize": list(source.size), "bandCrop": [0, 148, 2172, 576],
    "exportSize": [1024, 128], "sliceSourceX": [0, 428, 1958, 2172],
    "sliceExportX": [0, 128, 960, 1024],
    "drawSize": [draw_width, draw_height],
    "drawSlices": [left, draw_width-left-right, right],
    "runtimeHeaderSha256": hashlib.sha256((ROOT / "Assets/Guild/header.tga").read_bytes()).hexdigest(),
}
(DRAFT / "proof.json").write_text(json.dumps(proof, indent=2), encoding="utf-8")
print("Guild banner v2 draft only; source and export hashes recorded")
