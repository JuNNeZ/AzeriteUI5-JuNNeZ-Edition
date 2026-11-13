"""Freeze the maintainer-approved Druid footprint, translated by mounting toe."""
from pathlib import Path
import hashlib
import json
from PIL import Image

from ThemeHealthEndcaps import lowest_point, terminal_mask

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Docs/Research_Assets/DeathKnight/FullSet/Contracts"
OUT.mkdir(parents=True, exist_ok=True)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    path = OUT / "approved-footprints.json"
    if path.exists():
        existing = json.loads(path.read_text())
        if existing.get("schema") == 2:
            for item in existing["cases"].values():
                assert sha(ROOT / item["native"]) == item["nativeSha256"]
                assert sha(ROOT / item["nativeTerminalMask"]) == item["nativeTerminalMaskSha256"]
                assert sha(ROOT / item["druidBare"]) == item["druidBareSha256"]
                for reference in item["druidReferences"]:
                    assert sha(ROOT / reference["path"]) == reference["sha256"]
            print("Frozen footprint/native masks unchanged; no rewrite.")
            return
    cases = {}
    for name in ("hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case"):
        native = ROOT / "Assets" / (name + ".tga")
        druid_bare = ROOT / "Assets/Druid" / (name + "-over.tga")
        target = OUT / (name + "-terminal.png")
        terminal_mask(Image.open(native)).save(target)
        references = sorted((ROOT / "Assets/Druid").glob("ornament-*-" + name + ".tga"))
        assert references
        boxes = [Image.open(ref).convert("RGBA").getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox() for ref in references]
        union = [min(box[0] for box in boxes), min(box[1] for box in boxes), max(box[2] for box in boxes), max(box[3] for box in boxes)]
        toe, druid_toe = lowest_point(Image.open(native)), lowest_point(Image.open(druid_bare))
        delta = [toe[axis] - druid_toe[axis] for axis in (0, 1)]
        translated = [union[index] + delta[index % 2] for index in range(4)]
        cases[name] = {
            "native": native.relative_to(ROOT).as_posix(), "nativeSha256": sha(native),
            "nativeTerminalMask": target.relative_to(ROOT).as_posix(), "nativeTerminalMaskSha256": sha(target),
            "druidBare": druid_bare.relative_to(ROOT).as_posix(), "druidBareSha256": sha(druid_bare),
            "druidToe": list(druid_toe), "nativeToe": list(toe), "druidUnion": union,
            "toeTranslation": delta, "approvedFootprint": translated,
            "druidReferences": [{"path": ref.relative_to(ROOT).as_posix(), "sha256": sha(ref)} for ref in references],
        }
    path.write_text(json.dumps({"schema": 2, "maintainerApproved": True,
        "approval": "Maintainer answered 'Ja, brug Druid-størrelsen' to the maximum-footprint question in this chat, 2026-11-07.",
        "scope": "Maximum exterior footprint only. Not asset, source, numeric, visual, or live approval.",
        "cases": cases}, indent=2) + "\n", encoding="utf-8")
    print("Frozen four native terminal masks and toe-translated Druid maximum footprints.")


if __name__ == "__main__":
    main()
