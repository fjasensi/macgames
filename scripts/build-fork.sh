#!/bin/bash
# Build a local fork that shares the normal Steam library and never updates from upstream.
# Usage: scripts/build-fork.sh
# XCODEGEN can name an XcodeGen executable that is not on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/fork"
APP="$BUILD/MacGames Fork.app"
XCODEGEN="${XCODEGEN:-$(command -v xcodegen || printf '%s' "$ROOT/build/tools/xcodegen/bin/xcodegen")}"

command -v "$XCODEGEN" >/dev/null || { echo "error: XcodeGen is required (brew install xcodegen)." >&2; exit 1; }
[ -f "$ROOT/Vendor/SHA256SUMS" ] || { echo "error: Run scripts/fetch-runtime.sh first." >&2; exit 1; }
mkdir -p "$BUILD"

"$XCODEGEN" generate --spec "$ROOT/project.yml" --project "$ROOT"
echo "Building MacGames Fork…"
if ! xcodebuild -project "$ROOT/MacGames.xcodeproj" -scheme MacGames -configuration Release \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath "$BUILD/DerivedData" \
    PRODUCT_BUNDLE_IDENTIFIER=com.fjasensi.macgames CODE_SIGN_IDENTITY=- \
    build > "$BUILD/xcodebuild.log" 2>&1; then
    tail -50 "$BUILD/xcodebuild.log" >&2
    exit 1
fi

# Work on a copy; the Xcode product keeps its regular build metadata.
rm -rf "$APP"
ditto "$BUILD/DerivedData/Build/Products/Release/MacGames.app" "$APP"
python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
info = plistlib.loads(path.read_bytes())
info["CFBundleName"] = "MacGames Fork"
info["CFBundleDisplayName"] = "MacGames Fork"
info["MacGamesDisableUpdates"] = True
# Never carry a test HOME into the daily-use app.
info.pop("LSEnvironment", None)
info.pop("SUFeedURL", None)
info.pop("SUPublicEDKey", None)
path.write_bytes(plistlib.dumps(info))
PY

# Sign the app container only: Wine and its helpers keep their own entitlements.
codesign --force --sign - --entitlements "$ROOT/App/MacGames.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
printf '\nBuilt: %s\nSteam data: %s/Library/Application Support/macgames/steam\n' "$APP" "$HOME"
