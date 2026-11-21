#!/bin/bash
# Publish the static landing page to the dedicated gh-pages branch, without changing main.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPOSITORY="https://github.com/fjasensi/macgames.git"
GH="${GH:-gh}"
command -v "$GH" >/dev/null || { echo "error: GitHub CLI is required." >&2; exit 1; }
"$ROOT/scripts/build-pages.sh"
WORK="$(mktemp -d "$ROOT/build/pages-publish.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
git -C "$WORK" init -q
git -C "$WORK" remote add origin "$REPOSITORY"
identity="$("$GH" api user --jq '[.login, .id] | @tsv')"
IFS=$'\t' read -r pages_login pages_user_id <<< "$identity"
git -C "$WORK" config user.name "$pages_login"
git -C "$WORK" config user.email "$pages_user_id+$pages_login@users.noreply.github.com"
if git -C "$WORK" ls-remote --exit-code --heads origin gh-pages >/dev/null; then
    git -C "$WORK" fetch --depth=1 origin gh-pages
    git -C "$WORK" switch -c gh-pages FETCH_HEAD
    git -C "$WORK" rm -r --ignore-unmatch . >/dev/null
else
    git -C "$WORK" switch --orphan gh-pages
fi
cp -R "$ROOT/build/pages/." "$WORK/"
git -C "$WORK" add .
if git -C "$WORK" diff --cached --quiet; then
    echo "The published website already matches this source."
    exit 0
fi
git -C "$WORK" commit -m "Publish MacGames Fork website"
git -C "$WORK" -c credential.helper= -c "credential.helper=!$GH auth git-credential" push origin HEAD:gh-pages
echo "Published source: https://fjasensi.github.io/macgames/"
