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

cleanup() {
  rm -rf "${WIKI_DIR}"
}
trap cleanup EXIT

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but was not found in PATH." >&2
  exit 1
fi

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Error: source directory not found: ${SOURCE_DIR}" >&2
  echo "Create a 'wiki/' folder next to this script and add .md files." >&2
  exit 1
fi

shopt -s nullglob
pages=("${SOURCE_DIR}"/*.md)
shopt -u nullglob

if [[ ${#pages[@]} -eq 0 ]]; then
  echo "Error: no markdown pages found in ${SOURCE_DIR}" >&2
  exit 1
fi
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
