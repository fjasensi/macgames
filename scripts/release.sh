#!/bin/bash
# Builds, signs, notarizes and publishes a MacGames Fork release.
# Usage: NOTARY_PROFILE=<notarytool keychain profile> scripts/release.sh <version>
#
# Needs, on this Mac (see RELEASING.md):
#   - a "Developer ID Application" identity in the keychain (or DEVELOPER_ID=<its name>)
#   - a notarytool keychain profile, named by NOTARY_PROFILE
#   - gh, signed in with push rights to the repository
# Nothing secret is read from or written to the repository.
set -euo pipefail

VERSION="${1:?usage: NOTARY_PROFILE=<profile> scripts/release.sh <version>}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to a notarytool keychain profile (xcrun notarytool store-credentials)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO="fjasensi/macgames"
BUILD="$ROOT/build/release"
APP="$BUILD/MacGames Fork.app"
DMG="$BUILD/MacGames-Fork-$VERSION.dmg"
ZIP="$BUILD/MacGames-Fork-$VERSION.zip"
step() { printf '\n==> %s\n' "$*"; }

step "Preflight"
command -v cmake >/dev/null || { echo "error: CMake is required to build x87sidecar (brew install cmake)." >&2; exit 1; }
if [ -z "${DEVELOPER_ID:-}" ]; then
  DEVELOPER_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$DEVELOPER_ID" ] || { echo "error: no Developer ID Application identity in the keychain." >&2; exit 1; }
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || { echo "error: notarytool profile '$NOTARY_PROFILE' is missing or invalid." >&2; exit 1; }
grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml || { echo "error: project.yml's MARKETING_VERSION is not $VERSION." >&2; exit 1; }
grep -q "^## $VERSION " CHANGELOG.md || { echo "error: CHANGELOG.md has no '## $VERSION' section." >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "error: commit or stash your changes first." >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "error: gh is not signed in." >&2; exit 1; }

if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
  [ "$(git rev-parse "v$VERSION^{commit}")" = "$(git rev-parse HEAD)" ] \
    || { echo "error: tag v$VERSION exists on another commit." >&2; exit 1; }
fi
BUILD_NUMBER="$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\{0,1\}\([0-9]*\)"\{0,1\}$/\1/p' project.yml | head -1)"

step "Building MacGames Fork $VERSION (Release)"
# Always the pinned runtime: a local test build of a helper never ships by accident.
scripts/fetch-runtime.sh
xcodegen generate >/dev/null
rm -rf "$BUILD" && mkdir -p "$BUILD"
xcodebuild -project MacGames.xcodeproj -scheme MacGames -configuration Release -derivedDataPath "$BUILD/DerivedData" \
  CODE_SIGN_IDENTITY=- build > "$BUILD/xcodebuild.log" 2>&1 || { tail -30 "$BUILD/xcodebuild.log"; exit 1; }
ditto "$BUILD/DerivedData/Build/Products/Release/MacGames.app" "$APP"
# The About window shows the version: check both values before notarizing.
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist")" = "$BUILD_NUMBER" ] \
  || { echo "error: the built app's CFBundleVersion is not $BUILD_NUMBER." >&2; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION" ] \
  || { echo "error: the built app's CFBundleShortVersionString is not $VERSION." >&2; exit 1; }

step "Signing inside out with the Developer ID and the hardened runtime"
sign() { codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID" "$@"; }
# Sparkle's nested helpers first, then the framework.
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
# Sparkle's XPC services carry entitlements of their own, which re-signing must keep.
for xpc in "$FW"/XPCServices/*.xpc; do [ -e "$xpc" ] && sign --preserve-metadata=entitlements "$xpc"; done
sign "$FW/Updater.app" "$FW/Autoupdate"
sign "$APP/Contents/Frameworks/Sparkle.framework"
# The source-built sidecar needs our release signature too. Wine keeps its
# shipped signature and entitlements.
sign --entitlements App/x87sidecar.entitlements "$APP/Contents/Helpers/x87sidecar"
sign --entitlements App/MacGamesBridge.entitlements "$APP/Contents/Helpers/MacGamesBridge"
sign "$APP/Contents/Helpers/RosettaProbe"
sign --entitlements App/MacGames.entitlements "$APP"
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$APP/Contents/Resources/Runtime/Engine/bin/wine" "$APP/Contents/Helpers/x87sidecar"

step "Notarizing the app"
ditto -c -k --keepParent "$APP" "$BUILD/notarize.zip"
xcrun notarytool submit "$BUILD/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl -a -t exec -vv "$APP"

step "Building the disk image"
swift scripts/render-dmg-background.swift "$BUILD"
tiffutil -cathidpicheck "$BUILD/dmg-background.png" "$BUILD/dmg-background@2x.png" -out "$BUILD/dmg-background.tiff" >/dev/null
VENV="$ROOT/build/dmgvenv"
[ -x "$VENV/bin/dmgbuild" ] || { python3 -m venv "$VENV" && "$VENV/bin/pip" install --quiet dmgbuild; }
"$VENV/bin/dmgbuild" -s scripts/dmg-settings.py -D app="$APP" -D background="$BUILD/dmg-background.tiff" "MacGames Fork" "$DMG"
codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -vv "$DMG"

step "Creating the manual-install archive"
ditto -c -k --keepParent "$APP" "$ZIP"

step "Publishing"
NOTES="$BUILD/notes.md"
awk -v v="$VERSION" '$0 ~ "^## " v " " {on=1; next} /^## / {on=0} on' CHANGELOG.md > "$NOTES"
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null || git tag -a "v$VERSION" -m "MacGames Fork $VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" "$DMG" "$ZIP" -R "$REPO" --title "MacGames Fork $VERSION" --notes-file "$NOTES" --latest
step "Released MacGames Fork $VERSION: https://github.com/$REPO/releases/tag/v$VERSION"
