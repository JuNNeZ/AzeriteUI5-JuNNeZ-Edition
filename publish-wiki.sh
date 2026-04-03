#!/usr/bin/env bash
# publish-wiki.sh
#
# Pushes the wiki pages to the GitHub wiki git repository.
# Run this script ONCE locally after cloning the main repo.
#
# Requirements:
#   - git
#   - Write access to the repository
#   - The wiki must be enabled on the GitHub repository settings
#     (Settings → Features → Wikis ✓)
#
# Usage:
#   chmod +x publish-wiki.sh
#   ./publish-wiki.sh
#
# After running, visit:
#   https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/wiki

set -euo pipefail

REPO="JuNNeZ/AzeriteUI5-JuNNeZ-Edition"
WIKI_REMOTE="https://github.com/${REPO}.wiki.git"
WIKI_DIR="$(mktemp -d)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/wiki"

echo "==> Cloning wiki repository..."
git clone "${WIKI_REMOTE}" "${WIKI_DIR}"

echo "==> Copying wiki pages..."
cp "${SOURCE_DIR}"/*.md "${WIKI_DIR}/"

echo "==> Committing and pushing..."
cd "${WIKI_DIR}"
git add .
git diff --cached --stat
git commit -m "Add comprehensive wiki documentation (14 pages)" || echo "(nothing to commit)"
git push origin master

echo ""
echo "Done! Your wiki is live at:"
echo "  https://github.com/${REPO}/wiki"
echo ""
echo "You can now delete publish-wiki.sh from the repository if you wish."
