# Version Update Checklist

**⚠️ BEFORE EVERY RELEASE BUILD:**

## 1. Determine Version Bump

- **Patch fixes (bugs):** `5.2.211` → `5.2.212`
- **Minor features:** `5.2.x` → `5.3.0`
- **Major overhauls:** `5.x.x` → `6.0.0`

Always append `-JuNNeZ` to version string.

## 2. Update These Files

### Required Updates:
- [ ] `AzeriteUI.toc` — Line 6: `## Version: X.X.XXX-JuNNeZ`
- [ ] `AzeriteUI_Vanilla.toc` — Line 6: `## Version: X.X.XXX-JuNNeZ`
- [ ] `build-release.ps1` — Line 14: `$Version = "X.X.XXX-JuNNeZ"`

### Optional Updates:
- [ ] `FixLog.md` — Add new version entry at top
- [ ] `AGENTS.md` — Update "Current version tracking" section

## 3. Build & Verify

```powershell
.\build-release.ps1
```

- [ ] Verify filename includes correct version number
- [ ] Check file size is reasonable (~5.4 MB)
- [ ] Test `/reload` in-game with new build

## Current Version

**Latest:** 5.2.211-JuNNeZ  
**Last Updated:** 2026-03-02  
**Next Planned:** 5.2.212-JuNNeZ (combo point sliders + BG crash fixes)

## Quick Version History

- `5.2.211-JuNNeZ` (2026-03-02) — Combo point sliders, arena forbidden table fix, castbar crash guard
- `5.2.210-JuNNeZ` (previous) — [add description]
- `5.2.209-JuNNeZ` (previous) — [add description]
