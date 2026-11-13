"""Check DK source coverage/replay; default also rejects failed fitting."""
from pathlib import Path
import argparse
import hashlib
import json

from PIL import Image

from ThemeSourceIntegrity import whole_painting, verify_pixels

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets_Draft/DeathKnight/FullSet"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources-only", action="store_true", help="Source/replay inventory only; never production acceptance")
    args = parser.parse_args()
    plan = json.loads((OUT / "jobs.json").read_text(encoding="utf-8"))
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    assets = manifest["assets"]
    assert len(plan["jobs"]) == 33 and all(job["status"] == "done" for job in plan["jobs"]), "Incomplete source inventory"
    assert {job["name"] for job in plan["jobs"]} == set(assets), "Missing/unlisted export"
    assert {path.stem for path in (OUT / "Exports").glob("*.tga")} == set(assets), "Unlisted/orphan TGA"
    for job in plan["jobs"]:
        source = ROOT / job["source"]
        assert sha(source) == job["sourceSha256"] == job["originalSha256"], "Altered source copy: " + job["name"]
        original = Path(job["original"])
        if original.exists():
            assert sha(original) == job["originalSha256"], "Changed original: " + job["name"]
        record = assets[job["name"]]
        path = ROOT / record["path"]
        assert sha(path) == record["sha256"], "Stale export: " + job["name"]
        actual = Image.open(path).convert("RGBA")
        expected = whole_painting(Image.open(source).convert("RGBA"), record["transform"], actual.size)
        verify_pixels(expected, actual)
    contracts = json.loads((ROOT / "Docs/Research_Assets/DeathKnight/FullSet/Contracts/approved-footprints.json").read_text(encoding="utf-8"))
    assert contracts["schema"] == 2 and contracts["maintainerApproved"] is True
    for item in contracts["cases"].values():
        assert sha(ROOT / item["native"]) == item["nativeSha256"]
        assert sha(ROOT / item["nativeTerminalMask"]) == item["nativeTerminalMaskSha256"]
        assert sha(ROOT / item["druidBare"]) == item["druidBareSha256"]
        for reference in item["druidReferences"]:
            assert sha(ROOT / reference["path"]) == reference["sha256"]
    print("PASS: 33/33 source paintings, exact original hashes and uniform source-to-TGA replay; frozen contracts unchanged.")
    if args.sources_only:
        print("SOURCE INVENTORY ONLY; no fit, production, integration or live acceptance.")
        return 0
    report = json.loads((OUT / "fit-report.json").read_text(encoding="utf-8"))
    assert report["assetManifestSha256"] == sha(OUT / "manifest.json"), "Stale fit report"
    gate = json.loads((OUT / "source-gate-result.json").read_text(encoding="utf-8"))
    errors = []
    if report["failingCases"]:
        errors.append(str(report["failingCases"]) + " casing candidates fail local fit")
    if gate["passed"] is not True:
        errors.append("shared source gate: " + gate["firstFailure"])
    for filename, label in (("endcap-fit-acceptance.json", "endcap full-terminal/footprint acceptance"), ("cast-socket-acceptance.json", "painted cast-socket acceptance")):
        path = OUT / filename
        if not path.exists() or json.loads(path.read_text()).get("passed") is not True:
            errors.append(label + " pending")
    runtime_path = ROOT / "Assets/DeathKnight/manifest.json"
    runtime = json.loads(runtime_path.read_text(encoding="utf-8")) if runtime_path.exists() else {}
    if not runtime or not (ROOT / "Core/DeathKnightTheme.lua").exists():
        errors.append("runtime integration pending")
    else:
        print("INFO: WIP runtime integration exists; validate separately with Check-DeathKnightLivePreview.py.")
    if manifest.get("retailTested") is not True or manifest.get("foreverTested") is not True:
        errors.append("representative Retail/Forever validation pending")
    for error in errors:
        print("FAIL: " + error)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
