#!/bin/bash
# Assemble only this fork's landing page; the archived upstream docs are not published.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/build/pages"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT/assets"
cp "$ROOT/website/index.html" "$ROOT/website/styles.css" "$ROOT/website/favicon.svg" "$OUTPUT/"
cp "$ROOT/docs/images/library-search.png" "$ROOT/docs/images/library-favorites.png" "$OUTPUT/assets/"
cp "$ROOT/LICENSE" "$ROOT/THIRD_PARTY_NOTICES.md" "$OUTPUT/"
touch "$OUTPUT/.nojekyll"
printf 'GitHub Pages files: %s\n' "$OUTPUT"
