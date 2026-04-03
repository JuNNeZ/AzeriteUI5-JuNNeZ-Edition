# Multi-Platform Release Automation Guide

This guide sets up automated releases to **CurseForge**, **Wago Addons**, and **WowInterface** using GitHub Actions and git tags.

## Quick Overview

1. Push a git tag → GitHub Actions automatically packages and uploads to all platforms
2. Requires one-time setup of API credentials
3. Uses the existing `.pkgmeta` packaging configuration

## One-Time Setup (5–10 minutes)

### Step 1: Create Projects on Each Platform

You need an account and active project on each platform.

**CurseForge:**
1. Go to <https://www.curseforge.com/wow/addons/create>
2. Create a new addon project (or find your existing one)
3. Note your **Project ID** from the URL: `https://www.curseforge.com/wow/addons/{PROJECT-ID}`

**Wago Addons:**
1. Go to <https://addons.wago.io>
2. Sign in or create an account
3. Submit your addon project
4. Wait for approval, then note the project slug from the URL: `https://addons.wago.io/addons/{SLUG}`

**WowInterface:**
1. Go to <https://www.wowinterface.com>
2. Sign in or create an account
3. Submit your addon in the **Add-Ons** category
4. Note your **Addon ID** from the URL: `https://www.wowinterface.com/downloads/info{ADDON-ID}.html`

### Step 2: Generate API Tokens

**CurseForge API Key:**
1. Go to <https://authors.curseforge.com/account/api-tokens>
2. Click **"Generate Token"**
3. Name it `github-actions`
4. Copy the token immediately (you won't see it again!)

**Wago API Token:**
1. Go to <https://addons.wago.io/account>
2. Navigate to **API Tokens** or **Account Settings**
3. Click **Generate New Token**
4. Copy the token

**WowInterface:**
- WowInterface does NOT have a standard API for uploads
- Instead, keep your login credentials secure and use manual uploads, OR
- Contact WowInterface support for API documentation if available

### Step 3: Add Secrets to GitHub

GitHub Secrets store sensitive tokens safely:

1. Go to your repository on GitHub
2. Click **Settings** (top-right)
3. In the sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**

Add these secrets:

| Secret Name | Value |
|---|---|
| `CF_API_KEY` | Your CurseForge API key |
| `WAGO_API_TOKEN` | Your Wago API token |
| `WOW_INTERFACE_ADDON_ID` | (Optional) Your WowInterface addon ID (e.g., `12345`) |

**Important:**
- Once saved, secrets are **masked in logs** and cannot be viewed again
- Store these securely; do NOT commit them to the repo
- If a secret is leaked, regenerate it immediately on the platform

## How to Release

Once setup is complete, releasing is simple:

### 1. Update Version Numbers

Edit these three files:

**File: `AzeriteUI5_JuNNeZ_Edition.toc`**
```lua
## Version: 5.3.47-JuNNeZ
```

**File: `build-release.ps1`**
```powershell
$Version = "5.3.47-JuNNeZ"
```

**File: `CHANGELOG.md`**
```markdown
## 5.3.47-JuNNeZ (2026-04-05)

### Highlights

- Fixed [brief description of main fix/feature]

### Access

- [Describe where players access this change, if applicable]

### Internal

- [Internal notes or file changes, if any]
```

### 2. Commit and Tag

```bash
# Stage and commit
git add AzeriteUI5_JuNNeZ_Edition.toc build-release.ps1 CHANGELOG.md
git commit -m "Release v5.3.47-JuNNeZ"

# Create and push the tag
git tag 5.3.47-JuNNeZ
git push origin main
git push origin 5.3.47-JuNNeZ
```

### 3. Watch GitHub Actions

1. Go to **Actions** tab in your repository
2. Click the "Package and Release" workflow
3. Watch for green checkmarks (success)
4. If any step fails, click it to see error details

### 4. Verify Releases

After GitHub Actions completes (usually 2–5 minutes):

**CurseForge:**
- Go to your project → **Files**
- Confirm the new version appears with proper changelog

**Wago:**
- Go to your project
- Check that the new release is listed

**WowInterface:**
- WowInterface requires manual upload via web interface if API is not configured
- Go to your project → **Control Panel** → **Upload File**
- Upload the generated ZIP file manually

**GitHub:**
- Go to **Releases** tab
- Confirm a new release was auto-created

## Troubleshooting

### Workflow doesn't run after pushing tag

**Problem:** You pushed the tag but see no workflow in the Actions tab.

**Solutions:**
- Verify the tag format matches your pattern (e.g., `5.3.47-JuNNeZ`)
- Confirm `.github/workflows/release.yml` exists in the repo
- Check that you pushed the tag: `git push origin 5.3.47-JuNNeZ`
- Wait 30 seconds; GitHub Actions can be slightly delayed

### Upload fails with "Unauthorized" or "401"

**Problem:** CurseForge or Wago upload failed due to bad credentials.

**Solutions:**
- Go to **Settings** → **Secrets and variables** → **Actions**
- Verify the token names are exact: `CF_API_KEY`, `WAGO_API_TOKEN`
- Check that the token value is correct (no extra spaces)
- If unsure, regenerate the token on the platform and update the secret:
  - Go to the platform (CurseForge, Wago)
  - Revoke the old token
  - Generate a new one
  - Update the GitHub Secret with the new value

### CurseForge upload succeeds but with wrong version

**Problem:** CurseForge shows an old or incorrect version number.

**Solutions:**
- Ensure `## Version:` in the `.toc` file matches your tag
- Rebuild and push again: `git tag 5.3.48-JuNNeZ && git push origin 5.3.48-JuNNeZ`

### Changelog doesn't appear on CurseForge

**Problem:** CurseForge release created but changelog is blank.

**Solutions:**
- Verify `CHANGELOG.md` is at the repository root (not in a folder)
- Confirm the heading format: `## 5.3.47-JuNNeZ (date)`
- Check for markdown syntax errors (unmatched brackets, broken links)
- Make sure `.pkgmeta` includes the correct `manual-changelog` config
- Re-run the workflow with a new tag

### WowInterface upload not working

**Problem:** The WowInterface automated upload step fails or doesn't exist.

**Current Status:**
- WowInterface does NOT have a stable public API for addon uploads
- Automated uploads are not yet fully integrated

**Workaround:**
1. After GitHub Actions completes, download the generated ZIP from the workflow artifacts
2. Go to your WowInterface project → **Control Panel**
3. Upload the ZIP manually
4. This takes ~30 seconds per release

**Alternative:**
- Contact WowInterface support (<https://www.wowinterface.com/contact.php>) to request API documentation for automated uploads
- Once available, the workflow can be updated to support it

## Version Numbering Scheme

Follow semantic versioning:

- **Patch (bug fix):** `5.3.46` → `5.3.47` (e.g., fixed taint issue)
- **Minor (small feature):** `5.3.x` → `5.4.0` (e.g., new UI option)
- **Major (big change):** `5.x.x` → `6.0.0` (e.g., full rewrite)

Always append `-JuNNeZ` to identify this fan edition.

## Files Modified by This Setup

- `.github/workflows/release.yml` — GitHub Actions workflow (automated packaging)
- `RELEASE_WORKFLOW.md` — Documentation (updated with full setup guide)

## Files You'll Manage Per Release

- `AzeriteUI5_JuNNeZ_Edition.toc` — Update `## Version:`
- `build-release.ps1` — Update `$Version`
- `CHANGELOG.md` — Add new top-level version entry

---

**Questions or issues?** See the troubleshooting section above or check GitHub Actions logs for error details.
