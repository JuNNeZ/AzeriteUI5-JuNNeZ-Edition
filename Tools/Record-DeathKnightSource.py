"""Record a completed built-in imagegen request without changing source pixels."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
path = ROOT / "Docs/Research_Assets/DeathKnight/FullSet/jobs.json"
data = json.loads(path.read_text(encoding="utf-8"))
name, original_arg = sys.argv[1:3]
original = Path(original_arg).resolve(strict=True)
allowed = Path("C:/Users/Jonas/.codex/generated_images").resolve()
if not original.is_relative_to(allowed) or original.suffix.lower() != ".png":
    raise ValueError("Expected an original built-in generated PNG")
job = next(job for job in data["jobs"] if job["name"] == name)
target = ROOT / "Assets_Draft/DeathKnight/FullSet/Sources" / (name + ".png")
target.parent.mkdir(parents=True, exist_ok=True)
if target.exists() and target.read_bytes() != original.read_bytes():
    raise ValueError("Existing source differs; retain/revise explicitly rather than overwrite")
shutil.copy2(original, target)
digest = hashlib.sha256(target.read_bytes()).hexdigest()
assert digest == hashlib.sha256(original.read_bytes()).hexdigest()
job.update(status="done", original=str(original), originalSha256=digest, source=target.relative_to(ROOT).as_posix(), sourceSha256=digest)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(name + ": intact source saved; " + str(sum(j["status"] == "done" for j in data["jobs"])) + "/" + str(len(data["jobs"])))
