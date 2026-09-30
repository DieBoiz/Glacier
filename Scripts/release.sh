#!/bin/bash
#
# Builds Glacier for distribution: signs it with a Developer ID certificate,
# notarizes it with Apple and packages it as a zip and, if create-dmg is
# installed, as a disk image in ./release.
#
# Requirements:
#   - a "Developer ID Application" certificate in the login keychain
#   - notarytool credentials stored once with:
#       xcrun notarytool store-credentials glacier-notary
#
# Optional environment variables:
#   DEVELOPER_ID   signing identity, defaults to the first Developer ID Application found
#   NOTARY_PROFILE keychain profile for notarytool, defaults to glacier-notary
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${DERIVED:-/tmp/glacier-release}"
OUT="${OUT:-$ROOT/release}"
PROFILE="${NOTARY_PROFILE:-glacier-notary}"
IDENTITY="${DEVELOPER_ID:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)}"

[ -n "$IDENTITY" ] || { echo "error: no Developer ID Application certificate found" >&2; exit 1; }

echo "==> Building with $IDENTITY"
xcodebuild -project "$ROOT/Glacier.xcodeproj" -scheme Glacier -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO clean build \
    | tail -3

APP="$DERIVED/Build/Products/Release/Glacier.app"
[ -d "$APP" ] || { echo "error: no product at $APP" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
mkdir -p "$OUT"
ZIP="$OUT/Glacier-$VERSION.zip"

# Sparkle ships pre-signed binaries. Re-sign them inside out with our identity
# and a secure timestamp, then seal the app again.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
if [ -d "$SPARKLE" ]; then
    echo "==> Re-signing Sparkle"
    SIGN=(codesign --force --timestamp --options runtime --sign "$IDENTITY")
    "${SIGN[@]}" "$SPARKLE/XPCServices/Installer.xpc"
    "${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
    "${SIGN[@]}" "$SPARKLE/Autoupdate"
    "${SIGN[@]}" "$SPARKLE/Updater.app"
    "${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
    "${SIGN[@]}" --preserve-metadata=entitlements "$APP"
fi

echo "==> Verifying the signature"
codesign --verify --deep --strict "$APP"

echo "==> Notarizing"
SUBMIT="$OUT/notarize.zip"
ditto -c -k --keepParent "$APP" "$SUBMIT"
xcrun notarytool submit "$SUBMIT" --keychain-profile "$PROFILE" --wait
rm -f "$SUBMIT"
xcrun stapler staple "$APP"

echo "==> Packaging"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute --verbose "$APP"

if command -v create-dmg >/dev/null; then
    echo "==> Building the disk image"
    DMG="$OUT/Glacier-$VERSION.dmg"
    STAGE="$(mktemp -d)"
    trap 'rm -rf "$STAGE"' EXIT
    cp -R "$APP" "$STAGE/"
    rm -f "$DMG"
    create-dmg --volname "Glacier" \
        --background "$ROOT/Resources/dmg-background.png" \
        --window-size 660 400 --icon-size 112 \
        --icon "Glacier.app" 180 190 --app-drop-link 480 190 \
        --hide-extension "Glacier.app" \
        --codesign "$IDENTITY" --notarize "$PROFILE" \
        "$DMG" "$STAGE"
    shasum -a 256 "$DMG"
else
    echo "note: create-dmg not installed, skipping the disk image (brew install create-dmg)"
fi

echo "==> Done: $ZIP"
shasum -a 256 "$ZIP"
