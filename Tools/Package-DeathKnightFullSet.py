"""Archive the complete DK WIP sources/candidates, including failed evidence.

This is a resumable source handoff, explicitly not a production-install package.
No failed checks are waived and no production acceptance records are written.
"""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Docs/Research_Assets/DeathKnight/FullSet"
PACK = ROOT / "Assets_Draft/DeathKnight"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    jobs = json.loads((OUT / "jobs.json").read_text(encoding="utf-8"))["jobs"]
    assert len(jobs) == 33 and all(job["status"] == "done" for job in jobs), "Incomplete source set"
    manifest = json.loads((PACK / "FullSet/manifest.json").read_text(encoding="utf-8"))
    report = json.loads((PACK / "FullSet/fit-report.json").read_text(encoding="utf-8"))
    assert report["assetManifestSha256"] == sha(PACK / "FullSet/manifest.json"), "Stale fit report"
    files = set(path for path in PACK.rglob("*") if path.is_file())
    files.update(path for path in OUT.rglob("*") if path.is_file() and path.suffix != ".zip" and path.name != "archive-result.json")
    for name in ("brief.md", "prompts.json"):
        files.add(ROOT / "Docs/Research_Assets/DeathKnight" / name)
    for pattern in ("*DeathKnight*.py", "ThemeHealthEndcaps.py", "ThemeSourceIntegrity.py", "Check-ThemeAssetStyle.py", "Build-ThemeConceptBase.py"):
        files.update((ROOT / "Tools").glob(pattern))
    # Exact native references make rendering/source verification resumable.
    files.update((ROOT / "Assets").glob("*.tga"))
    files.update(path for path in (ROOT / "Docs/Research_Assets/Templates").glob("*") if path.is_file())
    files.add(ROOT / "Docs/Theme Asset Geometry.json")
    for name in ("Theme Asset Style Key.md", "Theme Asset Fitting Checklist.md", "Theme Source Integrity.md", "Theme Asset Production Workflow.md"):
        files.add(ROOT / "Docs" / name)
    files.add(ROOT / "Tools/ThemeAssetWorkflow.md")
    files.add(ROOT / "Docs/Research_Assets/Paladin/Revision5/layouts.json")
    files.add(ROOT / "Docs/Research_Assets/ClassConceptSheets-2026-10-17/death-knight-v2.png")
    for item in json.loads((OUT / "Contracts/approved-footprints.json").read_text())["cases"].values():
        files.add(ROOT / item["druidBare"])
        files.update(ROOT / record["path"] for record in item["druidReferences"])
    inventory = {path.relative_to(ROOT).as_posix(): sha(path) for path in sorted(files)}
    checksum = OUT / "archive-files.sha256.json"
    inventory.pop(checksum.relative_to(ROOT).as_posix(), None)
    checksum.write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    files.add(checksum)
    archive = ROOT / "Docs/Research_Assets/DeathKnight/DeathKnight-EbonOath-WIP-full-sources.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(files):
            z.write(path, path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None, "ZIP CRC failure"
        for name, digest in inventory.items():
            assert hashlib.sha256(z.read(name)).hexdigest() == digest, "ZIP hash mismatch: " + name
    result = {"kind": "WIP source handoff; not production", "archive": archive.relative_to(ROOT).as_posix(),
        "sha256": sha(archive), "bytes": archive.stat().st_size, "files": len(files),
        "newPaintings": len(jobs), "caseCandidates": len(manifest["assets"]), "failingFitCandidates": report["failingCases"],
        "productionAccepted": False, "zipCrcPassed": True, "archivedFileHashesPassed": True}
    (OUT / "archive-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
