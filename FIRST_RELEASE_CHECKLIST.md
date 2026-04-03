# First-Time Setup Checklist

Follow this checklist to enable automated multi-platform releases.

## Pre-Flight Checklist

- [ ] All three projects created and approved on each platform:
  - [ ] CurseForge project exists (note the Project ID)
  - [ ] Wago project exists and is approved
  - [ ] WowInterface project exists (note the Addon ID)

## GitHub Secrets Setup

- [ ] Navigate to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**
- [ ] Added `CF_API_KEY` secret with CurseForge API token
- [ ] Added `WAGO_API_TOKEN` secret with Wago API token
- [ ] (Optional) Added `WOW_INTERFACE_ADDON_ID` secret with your WowInterface addon ID

## Version Files Ready

Before your first release tag:

- [ ] `AzeriteUI5_JuNNeZ_Edition.toc` has the correct version (e.g., `## Version: 5.3.47-JuNNeZ`)
- [ ] `build-release.ps1` has matching version in `$Version` variable
- [ ] `CHANGELOG.md` has a new top-level entry with the version and date
- [ ] All three files have been committed to `main` branch

## First Test Release

Follow these steps for your first automated release:

1. **Create a test tag:**
   ```bash
   git tag 5.3.47-JuNNeZ
   git push origin 5.3.47-JuNNeZ
   ```

2. **Monitor GitHub Actions:**
   - Go to **Actions** tab
   - Click "Package and Release" workflow
   - Watch for green checkmarks
   - If any step fails, click it for error details

3. **Expected workflow steps:**
   - ✅ Checkout repository
   - ✅ Create Package (BigWigsMods packager)
   - ✅ Upload to WowInterface (skipped if secret not set)

4. **Verify on each platform (allow 1–2 minutes):**

   **CurseForge:**
   - Go to your project → **Files**
   - New version should appear
   - Click it and verify changelog displays correctly

   **Wago:**
   - Go to your project page
   - New release should appear in the release history

   **WowInterface:**
   - If automated upload worked: version appears in updates
   - If not: download the ZIP from GitHub and upload manually via Control Panel

   **GitHub:**
   - Go to **Releases** tab
   - Auto-created release should have the tag name

## What's Automated

Once setup is complete, pushing a tag automatically:

✅ Packages the addon (excludes dev files per `.pkgmeta`)  
✅ Uploads to CurseForge (if `CF_API_KEY` is set)  
✅ Uploads to Wago (if `WAGO_API_TOKEN` is set)  
✅ Attempts WowInterface upload (if `WOW_INTERFACE_ADDON_ID` is set)  
✅ Creates a GitHub Release  

## Future Releases (after first test)

For every new release:

1. Update version in three files
2. Commit to main
3. Push a new tag
4. GitHub Actions handles the rest

Example:
```bash
git add AzeriteUI5_JuNNeZ_Edition.toc build-release.ps1 CHANGELOG.md
git commit -m "Release v5.3.48-JuNNeZ"
git tag 5.3.48-JuNNeZ
git push origin main
git push origin 5.3.48-JuNNeZ
# Wait ~2 minutes, then verify on each platform
```

## Need Help?

- **Workflow not running?** Check that you properly pushed the tag: `git push origin 5.3.47-JuNNeZ`
- **Upload failed?** Go to Actions → click the workflow → check the error step
- **Token issues?** Verify secret names are exact (`CF_API_KEY`, `WAGO_API_TOKEN`, `WOW_INTERFACE_ADDON_ID`)
- **WowInterface manual fallback:** Download the ZIP artifact from the completed workflow and upload manually

---

**You're all set!** Your addon is now ready for one-command multi-platform releases.
