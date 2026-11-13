"""Export complete, unchanged source paintings and retain every failed fit gate."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json

from PIL import Image, ImageDraw

from ThemeSourceIntegrity import aperture, whole_painting, verify_pixels, verify_pack
from ThemeHealthEndcaps import lowest_point

ROOT = Path(__file__).resolve().parent.parent
loader = importlib.util.spec_from_file_location("dk_export", ROOT / "Tools/Build-DeathKnightFullSet.py")
helpers = importlib.util.module_from_spec(loader)
loader.loader.exec_module(helpers)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def build(theme):
    doc = ROOT / "Docs/Research_Assets" / theme / "FullSet"
    out = ROOT / "Assets_Draft" / theme / "FullSet"
    exports, review = out / "Exports", out / "Review"
    exports.mkdir(parents=True, exist_ok=True)
    review.mkdir(parents=True, exist_ok=True)
    jobs = json.loads((doc / "jobs.json").read_text(encoding="utf-8"))["jobs"]
    search_path = out / "registration-search.json"
    registrations = json.loads(search_path.read_text())["assets"] if search_path.exists() else {}
    contracts_path = doc / "Contracts/functional-fields.json"
    fields = json.loads(contracts_path.read_text())["clearance"] if contracts_path.exists() else {}
    assets, checks, images = {}, [], {}
    for job in jobs:
        if job["status"] != "done":
            continue
        name = job["name"]
        source = ROOT / job["source"]
        assert sha(source) == job["sourceSha256"], "Source changed: " + name
        painting = Image.open(source).convert("RGBA")
        if "transform" in job:
            transform = job["transform"]
            image = whole_painting(painting, transform, job["geometry"]["canvas"])
        elif name in registrations and registrations[name]["sourceSha256"] == sha(source) and registrations[name]["best"]:
            transform = registrations[name]["best"]["transform"]
            image = whole_painting(painting, transform, job["geometry"]["canvas"])
        else:
            geometry = dict(job["geometry"])
            if name == "actionbutton-border-hex":
                geometry["painted"] = list(helpers.bounds(Image.open(ROOT / "Assets/actionbutton-border-hex.tga")))
            elif job["role"] == "ornament-source":
                geometry["painted"] = [8, 8, 248, 248]
            image, transform = helpers.register(painting, name, geometry)
        target = exports / (name + ".tga")
        image.save(target, compression=None)
        verify_pixels(image, Image.open(target).convert("RGBA"))
        images[name] = image
        assets[name] = {"path": target.relative_to(ROOT).as_posix(), "sha256": sha(target),
            "canvas": list(image.size), "role": "whole-painting", "source": {"path": job["source"], "sha256": sha(source)}, "transform": transform}
        if "bridge" in job:
            assets[name].update(bridge=job["bridge"], bridgeApproval=job["bridgeApproval"])
        failures, notes = helpers.STYLE.check(target)
        mask = ROOT / fields[name]["path"] if name in fields else ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")
        if name in fields:
            assert sha(mask) == fields[name]["sha256"]
        if mask.exists():
            try:
                bridge = None
                if "bridge" in job:
                    approval_path = ROOT / job["bridgeApproval"]["path"]
                    assert sha(approval_path) == job["bridgeApproval"]["sha256"]
                    approval = json.loads(approval_path.read_text(encoding="utf-8"))
                    assert approval["maintainerApproved"] is True and approval["sourceSha256"] == sha(source)
                    assert approval["bridgeSha256"] == job["bridge"]["sha256"] == sha(ROOT / job["bridge"]["path"])
                    bridge = Image.open(ROOT / job["bridge"]["path"])
                aperture(image, Image.open(mask), bridge)
            except ValueError as error:
                failures.append(str(error))
        if name.startswith("hp_") and "critter" not in name:
            expected = lowest_point(Image.open(ROOT / "Assets" / (name + ".tga")))
            found = lowest_point(image)
            if abs(expected[0] - found[0]) > .5 or expected[1] != found[1]:
                failures.append(f"Native toe mismatch: {expected} -> {found}")
        if job.get("qualityStatus", "").startswith("rejected"):
            failures.append(job["qualityStatus"])
        checks.append({"name": name, "failures": failures, "notes": notes})
    manifest = {"schema": 1, "status": "candidate-exports", "assets": assets, "runtimeIntegrated": False,
        "retailTested": False, "foreverTested": False}
    write(out / "manifest.json", manifest)
    write(exports / "manifest.json", manifest)
    write(exports / "source-integrity.json", {"schema": 1, "assetManifestSha256": sha(exports / "manifest.json"),
        "paintings": {name: {"role": "painting", "source": item["source"], "transform": item["transform"],
            **({"bridge": item["bridge"], "bridgeApproval": item["bridgeApproval"]} if "bridge" in item else {})} for name, item in assets.items()}})
    try:
        gate = {"passed": True, "result": verify_pack(exports)}
    except (ValueError, KeyError, OSError) as error:
        gate = {"passed": False, "firstFailure": str(error)}
    write(out / "source-gate-result.json", gate)
    write(out / "fit-report.json", {"schema": 1, "manifestSha256": sha(out / "manifest.json"), "cases": checks,
        "pending": [j["name"] for j in jobs if j["status"] != "done"], "failingCases": sum(bool(c["failures"]) for c in checks), "accepted": False})
    board = Image.new("RGB", (1440, 50 + ((len(images) + 3) // 4) * 220), "#14161a")
    draw = ImageDraw.Draw(board)
    draw.text((15, 15), theme + " / actual reopened candidate exports", fill="white")
    for index, (name, image) in enumerate(images.items()):
        x, y = (index % 4) * 360, 50 + (index // 4) * 220
        draw.text((x + 10, y + 5), name, fill="white")
        small = image.copy()
        small.thumbnail((340, 170), Image.Resampling.LANCZOS)
        board.paste(small, (x + (360 - small.width) // 2, y + 30 + (170 - small.height) // 2), small)
    board.save(review / "all-exports.png")
    print(f"{theme}: {len(assets)}/{len(jobs)} exported; {sum(bool(c['failures']) for c in checks)} fit failures; source gate {gate['passed']}")
    for item in checks:
        if item["failures"]:
            print(item["name"] + ": " + "; ".join(item["failures"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", choices=("Priest", "Warlock", "Both"))
    args = parser.parse_args()
    for theme in ("Priest", "Warlock") if args.theme == "Both" else (args.theme,):
        build(theme)
