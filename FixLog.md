# FixLog — AzeriteUI JuNNeZ Edition

**Archive Note:** Historical entries from project inception through 2026-03-03 have been archived to `FixLog_Archive_20260303.md` (14,673 lines). This fresh log starts with version 5.2.216-JuNNeZ as the baseline.

---

## 5.2.216-JuNNeZ (2026-03-03) — CURRENT RELEASE

**Status:** Shipped and released.

### Features Shipped
- Demon Hunter Devourer soul fragments 10-point display system
- 4 soul fragments display modes (Alpha, Gradient, Recolor, Stacked 5-Point)
- Show Soul Fragments visibility toggle in Options → Unit Frames → Class Power

### Bug Fixes Shipped
- Fixed ActionButton taint (`ADDON_ACTION_BLOCKED` errors from secure attribute writing)

### Libraries Updated
- Loaded LibEditModeOverride-1.0 (was bundled but not included in load order)
- Updated LibEditModeOverride-1.0 with upstream CooldownViewer slider fix (commit 39f30e5)

### Known Issues (Documented)
- **Edit Mode taint errors:** Opening/closing Edit Mode causes multiple taint errors. Deep investigation planned for next version.
- **Mana orb:** Mana orb display still under investigation for WoW 12.
- **Target castbar crop:** Some non-self target casts may show incorrect fill behavior.

### Development Notes
- **Experimental code removed before release:** All combo point position sliders, soul fragments bar adjustment sliders, texture flip/rotation/tiling controls, and debug commands (`/azdebug power refresh`) were implemented during development but removed from the final release build as they were not production-ready.
- **Release output:** `AzeriteUI-5.2.216-JuNNeZ-Retail-03-03-2026.zip` (9.87 MB)
- **Build date:** 2026-03-03 22:45

### Unreleased Fixes (In Progress)

2026-03-04 00:00 (Player power crystal size sync, rolled back)

Issue:
- Player frame power statusbar could be a different size than the power background asset.

Root Cause:
- Player power bar size and power backdrop size were driven by separate size/scale paths.

Fix:
- Initial attempt synced player statusbar to backdrop dimensions.
- Change was rolled back after testing because it altered crystal attachment/alignment behavior in player frame.
- Restored original player power sizing path to preserve legacy attachment points.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — reverted player power-size sync to restore original attachment

Testing:
1. `/reload`
2. Enter world with AzeriteUI enabled
3. Observe player frame power crystal and its background at idle/combat
4. Adjust power-related scale sliders and verify bar/backdrop remain matched

Status: Rolled Back (needs safer follow-up)

2026-03-04 00:15 (Player power crystal size match with anchor compensation)

Issue:
- Player power fill remained smaller than the backdrop art.

Root Cause:
- Raw size sync changed attachment behavior because dependent anchor offsets were tuned for the legacy bar size.

Fix:
- Player power bar now uses backdrop dimensions for width/height.
- Added anchor compensation to preserve crystal attachment behavior when size delta is applied.
- Added matching compensation for power case and power threat overlays to prevent drift.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — size/anchor compensation for player power crystal and related overlays

Testing:
1. `/reload`
2. Verify player power fill matches backdrop art dimensions
3. Verify crystal casing/threat overlays remain attached to the same visual location
4. Enter/leave combat and recheck alignment

Status: Ready for Test

2026-03-04 00:25 (Player power threat overlay alignment follow-up)

Issue:
- Power threat highlight/case-glow alignment drifted after power-size anchor compensation changes.

Root Cause:
- Threat overlay path received extra compensation offsets, effectively double-adjusting relative placement.

Fix:
- Restored original threat overlay offset path for `PowerBar` and `PowerBackdrop` threat textures.
- Kept power fill/backdrop sizing adjustments intact.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — removed extra compensation in threat overlay positioning

Testing:
1. `/reload`
2. Enter combat to trigger threat art
3. Verify power glow/case highlight align with crystal and frame art
4. Re-check out-of-combat alignment

Status: Ready for Test

2026-03-04 00:42 (Player power threat glow size correction)

Issue:
- PowerBar threat glow still misaligned with power fill after previous fixes.

Root Cause:
- PowerBar threat overlay sizing used legacy `powerBarScaleX/Y` while the power bar itself now uses `powerBackdropScaleX/Y`, causing size mismatch.

Fix:
- Changed PowerBar threat glow size calculation to use `powerBackdropScaleX/Y * powerThreatBarScaleX/Y` instead of `powerBarScaleX/Y * powerThreatBarScaleX/Y`.
- PowerBackdrop threat sizing remains unchanged (already uses case scales).

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — threat sizing logic (lines ~1723-1728)

Testing:
1. `/reload`
2. Enter combat to trigger threat glow
3. Verify PowerBar threat glow matches power fill dimensions exactly
4. Re-check alignment at different scale settings if applicable

Status: Ready for Test

2026-03-04 00:50 (Player power threat case Y-offset adjustment)

Issue:
- PowerBackdrop threat case (glow) was misaligned vertically by 28 pixels.

Fix:
- Added +28 pixel Y-offset to PowerBackdrop threat positioning.

Files Touched:
- `Components/UnitFrames/Units/Player.lua` — threat case positioning (line ~1717)

Testing:
1. `/reload`
2. Enter combat to trigger threat glow
3. Verify PowerBackdrop threat case aligns properly with power crystal

Status: Ready for Test

2026-03-04 00:50 (Actionbar enable toggle now updates live)

Issue:
- Toggling actionbar "enable" option in settings didn't show/hide bars immediately; required `/reload`.

Root Cause:
- `Bar.Enable()` and `Bar.Disable()` set internal flag but didn't call `:Show()` or `:Hide()` on the bar frame.

Fix:
- Added `:Show()` call to `Bar.Enable()` and `:Hide()` call to `Bar.Disable()`.

Files Touched:
- `Components/ActionBars/Prototypes/Bar.lua` — Enable/Disable methods (lines 49-60)

Testing:
1. Open options (`/azerite`)
2. Navigate to ActionBars → Action Bar 2 (or any bar)
3. Toggle "Enable" checkbox
4. Verify bar appears/disappears immediately without `/reload`
5. Test during combat (should defer update until leaving combat)

Status: Ready for Test

2026-03-04 01:15 (ToT frame secret boolean crash fix)

Issue:
- Error when selecting targets in instances: "attempt to compare local 'shouldHide' (a secret boolean value tainted by 'AzeriteUI')"
- Occurred at ToT.lua:278 during target selection in raids/dungeons

Root Cause:
- `UnitIsUnit()` can return secret boolean values in WoW 12
- Code attempted to compare the secret `shouldHide` value directly: `if (shouldHide == self.shouldHide)`

Fix:
- Added `issecretvalue(shouldHide)` check before comparison
- Falls back to `false` (don't hide) when value is secret, preventing unnecessary frame hiding
- Comparison now safe as non-secret value

Files Touched:
- `Components/UnitFrames/Units/ToT.lua` — secret-value sanitization (lines ~278-282)

Testing:
1. `/reload`
2. Enter instance (raid/dungeon)
3. Select various targets (NPCs, players, critters)
4. Verify ToT frame shows/hides correctly
5. Check BugSack for no more secret comparison errors

Status: Ready for Test

---

## Future Work Tracking

### Planned for Next Version
- [ ] Edit Mode taint deep audit (EncounterWarnings, arena frames, party/raid frames)
- [ ] Mana orb WoW 12 investigation
- [ ] Target castbar crop fixes for non-self casts
- [ ] Dead code cleanup (2500+ lines in FixBlizzardBugs.lua disabled block)

### Under Consideration
- [ ] Combo point position sliders (refinement needed)
- [ ] Soul fragments bar styling controls (needs testing with live DH users)
- [ ] Enhanced debug menu improvements

---

## Log Format Guidelines

When adding entries:
1. **Date format:** `YYYY-MM-DD HH:MM (Brief title)`
2. **Include:** Issue description, root cause, fix applied, files touched, testing steps
3. **Version entries:** Mark with status (In Progress, Ready for Release, Shipped)
4. **Keep focused:** One issue per entry, link related entries if needed
5. **Test validation:** Always include `/reload` loop test steps

---

## Next Entry Template

```
YYYY-MM-DD HH:MM (Title)

Issue:
- What broke
- How it manifested
- Error messages if any

Root Cause:
- Why it happened
- What assumptions were wrong

Fix:
- What changed
- Why this approach
- Any tradeoffs

Files Touched:
- path/to/file.lua — what changed
- path/to/other.lua — what changed

Testing:
1. /reload
2. Reproduce scenario
3. Verify fix
4. Check for regressions

Status: [In Progress / Ready for Test / Verified / Shipped in vX.X.X]
```
