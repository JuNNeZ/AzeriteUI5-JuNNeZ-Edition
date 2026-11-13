"""Render actual DK candidate TGAs using the original native layout export.

This is offline evidence, not a concept repaint or a client screenshot. Failing
apertures remain visible; no alpha mask repairs are performed here.
"""
from pathlib import Path
import importlib.util
import hashlib
import json

from PIL import Image, ImageDraw, ImageFont
from ThemeHealthEndcaps import align, lowest_point, terminal_coverage

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets_Draft/DeathKnight/FullSet/Review"
EXPORT = OUT.parent / "Exports"
S = Image.Resampling.LANCZOS


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", size)


def main():
    spec = importlib.util.spec_from_file_location("native_board", ROOT / "Tools/Build-ThemeConceptBase.py")
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    native_asset = base.asset
    def asset(path):
        name = path.replace("\\", "/").rsplit("/", 1)[-1]
        candidate = EXPORT / name
        if candidate.exists():
            image = Image.open(candidate).convert("RGBA")
            image.info["deathknightPainting"] = True
            return image
        return native_asset(path)
    base.asset = asset
    native_put = base.put
    def put(scene, image, rect, flip=False, tint=None):
        # Runtime media replacement makes newly painted physical casings white;
        # functional native assets retain their original colour/tint.
        if image is not None and image.info.get("deathknightPainting"):
            tint = None
        native_put(scene, image, rect, flip, tint)
    base.put = put
    diagnostics, caps = {}, {}
    contracts = json.loads((ROOT / "Docs/Research_Assets/DeathKnight/FullSet/Contracts/approved-footprints.json").read_text())["cases"]
    cap_source_path = OUT.parent / "Revisions/health-endcap-frost-v2.png"
    cap_source = Image.open(cap_source_path).convert("RGBA")
    def slot(name):
        source = Image.open(ROOT / "Assets_Draft/DeathKnight/Sources" / (name + ".png")).convert("RGBA")
        box = source.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        art = source.crop(box)
        art.thumbnail((240, 240), S)
        canvas = Image.new("RGBA", (256, 256))
        canvas.alpha_composite(art, ((256 - art.width) // 2, (256 - art.height) // 2))
        return canvas
    cast_art, badge_art = slot("cast-head-blood"), slot("resource-badge")
    def cap_candidate(name):
        if name in caps:
            return caps[name]
        contract = contracts.get(name)
        if not contract:
            return None
        native = Image.open(ROOT / contract["native"]).convert("RGBA")
        bound = contract["approvedFootprint"]
        source_box = cap_source.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
        painting = cap_source.crop(source_box)
        tx, ty = lowest_point(native)
        for height in range(int(bound[3] - bound[1]), 40, -1):
            # Diagnostic image only: the shared align gate is run below and its
            # failure is retained. This never produces an accepted cap TGA.
            art = painting.resize((round(painting.width * height / painting.height), height), S)
            px, py = lowest_point(art)
            x, y = round(tx - px), round(ty - py)
            if x < 0 or y < 0 or x + art.width > native.width or y + art.height > native.height:
                continue
            cap = Image.new("RGBA", native.size)
            cap.alpha_composite(art, (x, y))
            box = cap.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
            if box[0] < bound[0] or box[1] < bound[1] or box[2] > bound[2] or box[3] > bound[3]:
                continue
            record = {"height": height, "bounds": list(box), "insideApprovedFootprint": True,
                "sourceSha256": hashlib.sha256(cap_source_path.read_bytes()).hexdigest(),
                "nativeTerminal": terminal_coverage(native, cap), "accepted": False}
            candidate = EXPORT / (name + ".tga")
            if candidate.exists():
                record["candidateTerminal"] = terminal_coverage(Image.open(candidate), cap)
            try:
                align(cap_source, native, height, Image.open(ROOT / "Docs/Research_Assets/Templates" / (name + "-fill.png")))
                record["sharedAlignGatePassed"] = True
            except (ValueError, AssertionError) as error:
                record["sharedAlignGatePassed"] = False
                record["sharedAlignFailure"] = str(error)
            diagnostics[name] = record
            caps[name] = cap
            return cap
        diagnostics[name] = {"accepted": False, "error": "No diagnostic placement inside approved footprint"}
        return None
    def unit(kind, tier, fraction=1, resource="crystal", endcap=True):
        scene = base.unit(kind, tier, fraction, resource)
        db = dict(base.DATA[kind])
        db.update(db.get(tier, {}))
        owner = (150, 80, *base.DATA[kind]["Size"])
        name = db["HealthBackdropTexture"].replace("\\", "/").rsplit("/", 1)[-1]
        candidate = EXPORT / name
        if candidate.exists():
            # Newly painted health rails are foreground, above health and prediction.
            base.put(scene, Image.open(candidate).convert("RGBA"), base.anchor(owner, db["HealthBackdropSize"], db["HealthBackdropPosition"]), kind == "TargetFrame")
            cap = cap_candidate(name.removesuffix(".tga")) if endcap else None
            if cap is not None:
                base.put(scene, cap, base.anchor(owner, db["HealthBackdropSize"], db["HealthBackdropPosition"]), kind == "TargetFrame")
        if kind == "PlayerFrame" and resource == "crystal":
            power = base.anchor(owner, db["PowerBarSize"], db["PowerBarPosition"])
            case = base.anchor(power, db["PowerBarForegroundSize"], db["PowerBarForegroundPosition"])
            base.put(scene, badge_art, (case[0] + case[2] / 2 - 16, case[1] + case[3] * .56 - 16, 32, 32))
        return scene
    def cast(protected=False):
        db = base.DATA["PlayerCastBar"]
        scene = base.castbar(.55)
        name = "cast_back_spiked" if protected else "cast_back"
        path = EXPORT / (name + ".tga")
        if path.exists():
            bar = (190, 140, *db["CastBarSize"])
            base.put(scene, Image.open(path).convert("RGBA"), base.anchor(bar, db["CastBarBackgroundSize"], db["CastBarBackgroundPosition"]))
        # Shared FittedCastSlot at 100%, X/Y=0. Acceptance remains pending.
        base.put(scene, cast_art, (190 - 8 - 24, 140 + db["CastBarSize"][1] / 2 - 24, 48, 48))
        return scene

    board = Image.new("RGBA", (1536, 1200), "#14161a")
    draw = ImageDraw.Draw(board)
    draw.text((26, 20), "AZERITEUI / DEATH KNIGHT / ACTUAL CANDIDATE ASSEMBLIES", font=font(28), fill="#d6d1c4")
    draw.text((26, 61), "Native anchors and fills. Failed cap/casing candidates shown for review; NOT accepted or installed.", font=font(17), fill="#e7b18c")
    def place(scene, x, y, label):
        box = scene.getbbox()
        if box:
            board.alpha_composite(scene.crop(box), (x, y))
        draw.text((x, y - 26), label, font=font(16), fill="#b8c7d2")
    place(unit("PlayerFrame", "Seasoned", .55), 24, 145, "Player / Seasoned / 55%")
    place(unit("TargetFrame", "Seasoned", .55, None), 560, 145, "Target / mirrored / 55%")
    place(cast(False), 1160, 160, "Normal cast")
    place(cast(True), 1160, 250, "Protected cast")
    for index, fraction in enumerate((1, .5, 0)):
        place(base.resource("crystal", fraction), 30 + index * 150, 390, f"Crystal / {fraction:.0%}")
        place(base.resource("orb", fraction), 550 + index * 155, 390, f"Orb / {fraction:.0%}")
    place(base.points(), 1060, 390, "Shared class power / material sample")
    for index, (name, label) in enumerate((("ToTFrame", "ToT"), ("FocusFrame", "Focus"), ("PetFrame", "Pet"), ("RaidFrames", "Raid"))):
        place(base.compact(name, .65), 30 + index * 230, 650, label)
    place(base.group("PartyFrames"), 1030, 630, "Party")
    place(base.group("Raid5Frames"), 1230, 630, "Arena / raid party")
    place(base.single("portrait_frame_hi", 150), 30, 755, "Portrait")
    place(base.single("portrait_frame_lo", 150), 220, 755, "Portrait low")
    place(base.nameplate(), 430, 780, "Shared nameplate backing")
    for index in range(4):
        place(base.button(index == 0), 30 + index * 98, 1010, "Actions" if index == 0 else "")
    place(base.single("minimap-border", 270), 570, 905, "Minimap")
    place(base.single("config_button", 90), 920, 990, "Utility")
    place(base.single("icon_exit_flight", 90), 1060, 990, "Exit flight")
    draw.text((1200, 990), "See all-exports.png for", font=font(17), fill="#a4b4c3")
    draw.text((1200, 1018), "all shapes and atlas cells.", font=font(17), fill="#a4b4c3")
    OUT.mkdir(parents=True, exist_ok=True)
    board.convert("RGB").save(OUT / "assembled-candidates-1x.png")
    board.resize((3072, 2400), Image.Resampling.NEAREST).convert("RGB").save(OUT / "assembled-candidates-2x.png")

    # Complete tier pairs use a fixed whole source viewport and rail origin.
    cases = [("PlayerFrame", "Seasoned"), ("PlayerFrame", "Hardened"), ("PlayerFrame", "Novice"), ("TargetFrame", "Boss")]
    tiers = Image.new("RGBA", (1800, 1550), "#14161a")
    td = ImageDraw.Draw(tiers)
    td.text((20, 12), "FULL FIXED VIEWPORTS / NATIVE TIERS / EMPTY, PARTIAL, FULL", font=font(25), fill="#d6d1c4")
    for row, (kind, tier) in enumerate(cases):
        for column, fraction in enumerate((0, .5, 1)):
            scene = unit(kind, tier, fraction, None)
            # Uniform 2/3 display scale applies to the full fixed 900x360 viewport.
            scene = scene.resize((600, 240), S)
            x, y = column * 600, 70 + row * 360
            td.text((x + 18, y), f"{kind} {tier} {fraction:.0%}", font=font(17), fill="#b8c7d2")
            tiers.alpha_composite(scene, (x, y + 30))
    tiers.convert("RGB").save(OUT / "all-tiers-fixed.png")
    tiers.resize((3600, 3100), Image.Resampling.NEAREST).convert("RGB").save(OUT / "all-tiers-fixed-2x.png")
    pairs = Image.new("RGBA", (1800, 1540), "#14161a")
    pd = ImageDraw.Draw(pairs)
    pd.text((20, 12), "REJECTED CANDIDATE / NONE vs FROST / SAME VIEWPORT AND RAIL ORIGIN", font=font(22), fill="#e7b18c")
    for row, (kind, tier) in enumerate(cases):
        for column, enabled in enumerate((False, True)):
            scene = unit(kind, tier, .5, None, enabled)
            x, y = column * 900, 70 + row * 360
            pd.text((x + 18, y), f"{kind} {tier} / {'Frost candidate' if enabled else 'None'}", font=font(17), fill="#b8c7d2")
            pairs.alpha_composite(scene, (x, y + 20))
    pairs.convert("RGB").save(OUT / "none-frost-fixed-1x.png")
    pairs.resize((3600, 3080), Image.Resampling.NEAREST).convert("RGB").save(OUT / "none-frost-fixed-2x.png")
    (OUT / "endcap-diagnostics.json").write_text(json.dumps(diagnostics, indent=2) + "\n", encoding="utf-8")
    print(OUT / "assembled-candidates-1x.png")


if __name__ == "__main__":
    main()
