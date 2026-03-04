# AzeriteUI JuNNeZ Edition — March 2, 2026 Release (v5.2.212)

**This release (v5.2.212) includes only changes since v5.2.211.** 🎉

## What's New

### In-Game Combo Point Sliders
Fine-tune class point positions live without editing Lua files.

**New option**: `/az` → Unit Frames → Player → "Class Power Point Positions"

**Includes:**
- 14 sliders total (Point 1-7 X/Y)
- Live updates while testing in combat
- Persistent SavedVariables
- One-click reset for all point offsets

### Combo Point Visual Polish
- Point 7 now uses diamond backdrop
- Remaining points use plate backdrops

### Secret Tribute Command
Type `/goldpaw` in-game for a gold-themed tribute to the original AzeriteUI creator.

##  Download & Install

**File:** `AzeriteUI-5.2.212-JuNNeZ-Retail-02-03-2026.zip` (5.41 MB)

**Installation:**
1. **Exit WoW completely**
2. Extract `AzeriteUI` folder to `Interface\AddOns\`
3. **Overwrite** existing files if upgrading
4. Launch WoW and `/reload`
5. Configure with `/az`

## 🔧 Technical Details

**Version:** 5.2.212-JuNNeZ

**Credits Updated:**
- TOC now shows "**JuNNeZ Edition**" in green
- "Updated and Maintained by JuNNeZ"
- Original design by Daniel Troko & Lars Norberg

**Modified Files:**
```
AzeriteUI.toc
AzeriteUI_Vanilla.toc
build-release.ps1
Components/Auras/Auras.lua
Core/Debugging.lua
Libs/oUF/blizzard.lua
Libs/oUF_Classic/blizzard.lua
Libs/oUF/elements/castbar.lua
Layouts/Data/PlayerClassPower.lua
Components/UnitFrames/Units/PlayerClassPower.lua
Options/OptionsPages/UnitFrames.lua
```

**Compatibility:**
- ✅ WoW 12.0.0+ (Midnight/Retail)
- ✅ All Ace3 libraries included
- ✅ Zero known regressions

## 🧪 Quick Test

After installing:
```
1. /reload
2. /az → Unit Frames → Player
3. Adjust class point sliders and verify live movement
4. Build to 7 combo points and verify point 7 uses diamond
5. Type /goldpaw for tribute effect
6. Join a battleground and verify no aura/forbidden-table spam
```

## 📋 Release Notes Changelog (Delta from v5.2.211)

**Features:**
- In-game class power point slider system (14 sliders)
- Point 7 diamond + plate alignment for other points
- Secret `/goldpaw` tribute command

**Fixes:**
- Aura taint fix (`expirationTime` secret value propagation)
- Arena forbidden table iteration fix (`CompactArenaFrame.memberUnitFrames` guard)
- Castbar empowered stages nil-guard (`UpdatePips`)
- 7th combo point style-selection path correction

**Policy:**
- This section is delta-only per release.
- Do not include older fixes from previous versions.

---

## 🐛 Bug Reports

If you encounter any issues, please report them with:

**🧩 What happened?** (brief description)

**🔁 How to reproduce it** (step-by-step if possible)

**📍 Where did it happen?** (player/target frames, nameplates, combat, etc.)

**⚙️ Game version** (Retail / Classic / Anniversary + patch number)

**🧱 Other addons enabled?** (especially UI or unitframe addons)

**📜 Lua error message** (paste the full error from `/bugsack`)

**🖼️ Screenshot or clip** (optional, but extremely helpful)

Even partial reports help! Don't worry if you can't provide everything. 🙂

---

**Enjoying the changes?** Share your class point layout and `/goldpaw` reaction! 🎉

**Special thanks** to the original AzeriteUI team for their incredible foundation. This JuNNeZ Edition builds on years of excellent work. 💙
