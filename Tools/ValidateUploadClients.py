"""Fail before uploading if CurseForge cannot label both supported clients."""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
versions = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
if not isinstance(versions, list):
    raise SystemExit("CurseForge did not return a game-version list")

addon = "AzeriteUI5_JuNNeZ_Edition"
release_version = None
for suffix, flavor, version_type in (("", "Retail", 517), ("_Camelot", "Forever", 88568)):
    toc = (root / (addon + suffix + ".toc")).read_text(encoding="utf-8-sig")
    metadata = dict(re.findall(r"^## ([^:]+):\s*(.+)$", toc, re.MULTILINE))
    version = metadata["Version"].strip()
    if "@" in version or not version:
        raise SystemExit(f"{flavor}: missing or unstamped addon version")
    if release_version is not None and version != release_version:
        raise SystemExit("Retail and Forever addon versions differ")
    release_version = version
    interface = int(metadata["Interface"])
    game_version = f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}"
    matches = [item for item in versions
               if item.get("gameVersionTypeID") == version_type and item.get("name") == game_version]
    if not matches:
        raise SystemExit(f"CurseForge has no {flavor} {game_version} entry; refusing a partial-client upload")
    print(f"{flavor}: addon {version}, interface {interface}, game {game_version}, CurseForge version ID {matches[0]['id']}")
