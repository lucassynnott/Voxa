#!/bin/bash
# Publish Sparkle update artifacts to GitHub Pages (gh-pages branch)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPDATES_DIR="${ROOT_DIR}/.build/updates"
REMOTE_URL="$(git -C "${ROOT_DIR}" remote get-url origin)"

if [ ! -d "$UPDATES_DIR" ] || [ ! -f "${UPDATES_DIR}/appcast.xml" ]; then
    echo "Error: update artifacts missing at ${UPDATES_DIR}"
    echo "Run ./scripts/generate-appcast.sh first"
    exit 1
fi

# Make sure auth is valid up front.
gh auth status >/dev/null

CANONICAL_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
if [ -n "$CANONICAL_REPO" ] && [[ "$CANONICAL_REPO" == */* ]]; then
    OWNER="${CANONICAL_REPO%/*}"
    REPO="${CANONICAL_REPO#*/}"
    REMOTE_URL="https://github.com/${OWNER}/${REPO}.git"
elif [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo "Error: could not resolve GitHub owner/repo from origin remote: ${REMOTE_URL}"
    exit 1
fi

PAGES_BASE_URL="https://${OWNER}.github.io/${REPO}"
PAGES_FEED_URL="${PAGES_BASE_URL}/updates/appcast.xml"

echo "Publishing Sparkle updates to GitHub Pages for ${OWNER}/${REPO}"

TEMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

cd "$TEMP_DIR"
git init -q
git remote add origin "$REMOTE_URL"

if git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
    git fetch origin gh-pages --depth 1
    git checkout -q -b gh-pages origin/gh-pages
else
    git checkout -q --orphan gh-pages
fi

# Preserve existing non-update files (if any), replace /updates.
rm -rf updates
mkdir -p updates
cp -R "${UPDATES_DIR}/"* updates/
# Sparkle appcasts may reference archives at repository root. Mirror ZIPs at root for compatibility.
find updates -maxdepth 1 -type f -name "*.zip" -exec cp -f {} . \;

# Keep a minimal index page for diagnostics.
cat > index.html <<HTML
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Voxa Updates</title></head>
<body>
  <h1>Voxa Sparkle Updates</h1>
  <p>Feed URL: <a href="./updates/appcast.xml">./updates/appcast.xml</a></p>
</body>
</html>
HTML

touch .nojekyll

git add -A
if git diff --cached --quiet; then
    echo "No GitHub Pages changes to publish"
else
    git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
        commit -m "Publish Sparkle updates"
    git push origin gh-pages
    echo "✅ Published updates to gh-pages"
fi

# Ensure GitHub Pages is enabled and sourced from gh-pages root.
if gh api "repos/${OWNER}/${REPO}/pages" >/dev/null 2>&1; then
    gh api --method PUT "repos/${OWNER}/${REPO}/pages" \
        -f source[branch]=gh-pages \
        -f source[path]="/" >/dev/null || true
else
    if ! gh api --method POST "repos/${OWNER}/${REPO}/pages" \
        -f source[branch]=gh-pages \
        -f source[path]="/" >/dev/null 2>&1; then
        # Repo may already have pages configured but inaccessible via GET (permissions/API behavior).
        gh api --method PUT "repos/${OWNER}/${REPO}/pages" \
            -f source[branch]=gh-pages \
            -f source[path]="/" >/dev/null || true
    fi
fi

echo "✅ GitHub Pages configured"
echo "Pages URL: ${PAGES_BASE_URL}"
echo "Sparkle feed URL: ${PAGES_FEED_URL}"
