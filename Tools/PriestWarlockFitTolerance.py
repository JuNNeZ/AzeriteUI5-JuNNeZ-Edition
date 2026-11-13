"""Hash-bound, maintainer-authorized 10px fit acceptance for these two packs only.

Strict reports remain intact. This neither edits pixels nor grants live approval.
"""
import argparse
import hashlib
import json

import numpy as np
from PIL import Image, ImageFilter

from PriestWarlockAssetContracts import ROOT, LONG, record, underlay, native_tint
from ThemeHealthEndcaps import align

AUTHORIZATION = "Hvis det er inden for 10px, så går det nok forresten."
LIMIT = 10


def edge_distance(reference, query):
    """Exact Euclidean pixel-centre distance, fail closed outside the limit."""
    worst = 0.0
    for y, x in zip(*np.where(query)):
        y0, x0 = max(0, y-LIMIT), max(0, x-LIMIT)
        yy, xx = np.where(reference[y0:y+LIMIT+1, x0:x+LIMIT+1])
        assert len(yy), "Deviation extends beyond the authorized 10px edge band"
        distance = float(np.sqrt(((yy+y0-y)**2+(xx+x0-x)**2).min()))
        assert distance <= LIMIT, "Deviation exceeds 10px"
        worst = max(worst, distance)
    return worst


def component_span(mask):
    points = set(zip(*np.where(mask)))
    largest = 0
    while points:
        pending = [points.pop()]; component = []
        while pending:
            y, x = pending.pop(); component.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    neighbour = (y+dy, x+dx)
                    if neighbour in points:
                        points.remove(neighbour); pending.append(neighbour)
        yy, xx = zip(*component)
        largest = max(largest, max(yy)-min(yy)+1, max(xx)-min(xx)+1)
    return int(largest)


def measure(theme):
    assert theme in ("Priest", "Warlock")
    folder = ROOT / "Assets_Draft" / theme / "FullSet"
    docs = ROOT / "Docs/Research_Assets" / theme / "FullSet"
    contracts_path = docs / "Contracts/functional-fields.json"
    contracts = json.loads(contracts_path.read_text())
    caps_path = folder / "Endcaps/fit-report.json"
    caps = json.loads(caps_path.read_text())
    metrics, prefixes = {}, []
    for name in LONG:
        case = caps["cases"][name]
        painting = Image.open(folder / "Composed" / (name+"-over.tga")).convert("RGBA")
        cap = Image.open(ROOT / case["export"]["path"]).convert("RGBA")
        required = np.asarray(Image.open(ROOT / case["frozenTerminal"]["mask"]["path"])) > 0
        opaque = np.asarray(cap)[:, :, 3] >= 240
        max_distance = edge_distance(opaque, required & ~opaque)
        expanded = np.asarray(Image.fromarray(opaque.astype("uint8")*255).filter(ImageFilter.MaxFilter(3))) > 0
        exposed = Image.fromarray((required & ~expanded).astype("uint8")*255)
        fill = Image.open(ROOT / contracts["clearance"][name]["path"])
        # Retain every shared toe, single-tip, source-replay and fill gate.
        align(Image.open(ROOT / case["source"]["path"]), painting,
            case["best"]["height"], fill, source_transform=case["best"]["transform"],
            approved_terminal_exposure=exposed)
        assert case["best"]["combinedFillOcclusion"] <= .20
        metrics[name] = {"maximumTerminalEdgeDeviationPx": max_distance,
            "strictExposedPixels": case["best"]["paintedTerminal"]["exposedTerminalPixelsBeyondAA"],
            "exactExposedMaskSha256": hashlib.sha256(exposed.tobytes()).hexdigest()}
        prefixes.append(name+" endcap: cap leaves terminal metal exposed:")
    name = "hp_boss_case"
    mask = np.asarray(Image.open(ROOT / contracts["clearance"][name]["path"]).convert("L")) > 128
    interior = np.asarray(Image.fromarray(mask.astype("uint8")*255).filter(ImageFilter.MinFilter(3))) > 128
    painting = np.asarray(Image.open(folder / "Exports" / (name+".tga")).convert("RGBA"))
    intrudes = (painting[:, :, 3] > 200) & interior
    metrics["bossOpening"] = {"solidIntrusionPixels": int(intrudes.sum()),
        "maximumEdgeDeviationPx": edge_distance(~mask, intrudes)}
    prefixes.append("hp_boss_case: SOURCE APERTURE: undeclared solid paint covers functional fill")
    for name in ("orb_case_hi", "orb_case_low"):
        field = Image.open(ROOT / contracts["nativePanes"][name]["path"])
        expected = np.asarray(underlay(name, field, native_tint(name))).astype(int)
        actual = np.asarray(Image.open(folder / "Composed" / (name+".tga")).convert("RGBA")).astype(int)
        changed = np.any(actual != expected, axis=2) & (np.asarray(field) > 0)
        delta = actual[changed] - expected[changed]
        # Existing isolated export rounding is alpha-only, exactly 1/255.
        # A painted pane, changed RGB or opaque intrusion cannot use this path.
        assert not delta.size or (not delta[:, :3].any() and abs(delta[:, 3]).max() <= 1), "Orb glass altered beyond isolated alpha rounding"
        span = component_span(changed)
        assert span <= LIMIT, "Orb rounding defect exceeds 10px"
        metrics[name] = {"changedNativeGlassPixels": int(changed.sum()),
            "maximumConnectedDefectSpanPx": span, "rgbUnchanged": True,
            "maximumAlphaDelta255": int(abs(delta[:, 3]).max()) if delta.size else 0}
        prefixes.append(name+": composed RGBA changes exact native glass")
    return {"schema": 1, "theme": theme, "authorization": AUTHORIZATION,
        "maximumDeviationPx": LIMIT, "pixelSpace": "native exported texture pixels",
        "numericAcceptedUnderMaintainerTolerance": True, "metrics": metrics,
        "allowedFailurePrefixes": prefixes,
        "bindings": {"sourceManifest": record(folder/"manifest.json"),
            "composedManifest": record(folder/"Composed/manifest.json"),
            "capReport": record(caps_path), "functionalContracts": record(contracts_path)},
        "liveRetailValidated": False, "liveForeverValidated": False}


def accepted(theme):
    path = ROOT / "Docs/Research_Assets" / theme / "FullSet/maintainer-fit-tolerance.json"
    if not path.exists():
        return None
    expected = measure(theme)
    assert json.loads(path.read_text(encoding="utf-8")) == expected, "Stale maintainer tolerance evidence"
    return {"record": record(path), **expected}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", choices=("Priest", "Warlock", "Both"))
    parser.add_argument("--record", action="store_true")
    args = parser.parse_args()
    for theme in ("Priest", "Warlock") if args.theme == "Both" else (args.theme,):
        result = measure(theme)
        if args.record:
            path = ROOT / "Docs/Research_Assets" / theme / "FullSet/maintainer-fit-tolerance.json"
            path.write_text(json.dumps(result, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
        print(theme+": 10px fit gate PASS; maximum terminal deviation "+str(max(v["maximumTerminalEdgeDeviationPx"] for k,v in result["metrics"].items() if k in LONG)))
