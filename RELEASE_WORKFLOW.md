# Release Workflow Setup

This document explains how to set up automated releases to CurseForge and Wago using GitHub Actions.

## Prerequisites

1. **GitHub Repository** — Your code must be on GitHub
2. **CurseForge Project** — Create your addon project on CurseForge
3. **Wago Project** (Optional) — Create your addon project on Wago Addons
4. **API Keys** — Get API tokens from each platform

## Step 1: Get API Keys

### CurseForge API Key
1. Go to https://authors.curseforge.com/account/api-tokens
2. Click "Generate Token"
3. Give it a name (e.g., "GitHub Actions")
4. Copy the token (you won't see it again!)

### Wago API Token (Optional)
1. Go to https://addons.wago.io/account
2. Navigate to API Token section
3. Generate a new token
4. Copy the token

## Step 2: Add Secrets to GitHub

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add these secrets:
   - Name: `CF_API_KEY` / Value: Your CurseForge API token
   - Name: `WAGO_API_TOKEN` / Value: Your Wago API token (optional)

## Step 3: Create a Release

### Using Git Tags

The workflow triggers automatically when you push a tag:

```bash
# Make sure all changes are committed
git add .
git commit -m "Ready for release"

# Create and push a tag
git tag 5.2.213-JuNNeZ
git push origin 5.2.213-JuNNeZ
```

### The Workflow Will:
1. ✅ Checkout your code
2. ✅ Package the addon using BigWigsMods packager
3. ✅ Upload to CurseForge (if CF_API_KEY is set)
4. ✅ Upload to Wago (if WAGO_API_TOKEN is set)
5. ✅ Create a GitHub Release

## Files Used in Packaging

### `.pkgmeta`
Controls what gets included/excluded in the release package:
- Excludes: `.github`, `.vscode`, development docs, build scripts
- Includes: All addon code, assets, libs, locales

### `CHANGELOG.md`
Used as the release description on CurseForge and Wago. **Keep it updated!**

### TOC Files
Version numbers in `AzeriteUI5_JuNNeZ_Edition.toc` — update before each release.

## Version Numbering

Follow semantic versioning with JuNNeZ suffix:
- **Patch:** `5.2.212-JuNNeZ` → `5.2.213-JuNNeZ` (bug fixes)
- **Minor:** `5.2.x-JuNNeZ` → `5.3.0-JuNNeZ` (new features)
- **Major:** `5.x.x-JuNNeZ` → `6.0.0-JuNNeZ` (breaking changes)

## Release Checklist

Before pushing a tag:

- [ ] Update version in `AzeriteUI5_JuNNeZ_Edition.toc`
- [ ] Update `CHANGELOG.md` with changes since last release (delta only!)
- [ ] Test in-game with `/reload`
- [ ] Commit all changes
- [ ] Create and push git tag
- [ ] Wait for GitHub Actions to complete
- [ ] Verify release on CurseForge/Wago

## Troubleshooting

### Workflow fails to upload to CurseForge
- Verify `CF_API_KEY` secret is set correctly
- Check that your CurseForge project exists
- Ensure the API key has upload permissions

### Package contains unwanted files
- Edit `.pkgmeta` ignore list
- Test locally before pushing tag

### Changelog not showing on CurseForge
- Ensure `CHANGELOG.md` is at the root level
- Check `.pkgmeta` has `manual-changelog` configured
- Verify markdown formatting is correct

## Manual Testing (Optional)

You can test the packager locally:

```bash
# Install packager (requires bash/WSL on Windows)
curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash
```

---

**Note:** The first release requires manual setup of your CurseForge/Wago project. Subsequent releases are fully automated.
