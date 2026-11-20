"""Export an icon-free Guild Manager header from the existing metal and slate painting."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / "Assets_Draft/Guild/Banner-v2/banner-source.png").convert("RGBA")
assert source.size == (2172, 724)
# Mirror the clean right termination to replace the emblem end. The Lua
# three-slice keeps both end pieces at the same scale as the vertical trim.
end = source.crop((1958, 148, 2172, 576)).resize((64, 128), Image.Resampling.LANCZOS)
field = source.crop((540, 148, 1958, 576)).resize((896, 128), Image.Resampling.LANCZOS)
banner = Image.new("RGBA", (1024, 128))
banner.paste(end.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (0, 0))
banner.paste(field, (64, 0))
banner.paste(end, (960, 0))
banner.save(root / "Assets/Guild/workspace-header.tga")
