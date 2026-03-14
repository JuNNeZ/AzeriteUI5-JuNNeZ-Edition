# Version Update Checklist

**⚠️ BEFORE EVERY RELEASE BUILD:**

## 1. Determine Version Bump

- **Patch fixes (bugs):** `5.3.10` → `5.3.11`
- **Minor features:** `5.2.x` → `5.3.0`
- **Major overhauls:** `5.x.x` → `6.0.0`

Always append `-JuNNeZ` to version string.

## 2. Update These Files

### Required Updates:
- [ ] `AzeriteUI5_JuNNeZ_Edition.toc` — Line 6: `## Version: X.X.XXX-JuNNeZ`
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

**Latest:** 5.3.11-JuNNeZ
**Last Updated:** 2026-03-14
**Next Planned:** 5.3.12-JuNNeZ (future fixes)

## Quick Version History

- `5.3.11-JuNNeZ` (2026-03-14) — Big-raid priority debuff hide/size options
- `5.3.10-JuNNeZ` (2026-03-14) — Raid header click-taint/click-snippet correction and big-raid layout fix
- `5.3.9-JuNNeZ` (2026-03-14) — Minimap text visibility options cleanup, raid-frame secure header hardening
- `5.3.8-JuNNeZ` (2026-03-13) — Release metadata correction after assisted-highlight release cleanup
- `5.3.7-JuNNeZ` (2026-03-13) — Action-bar proc and assisted-highlight fixes
