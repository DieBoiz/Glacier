#!/bin/bash
#
# Signs a release zip with Sparkle and adds it to the appcast in docs/appcast.xml,
# which GitHub Pages serves as the update feed.
#
# Usage: Scripts/appcast.sh release/Glacier-1.0.0.zip
#
# The EdDSA private key is read from the login keychain (created with generate_keys).
# Set SPARKLE_BIN to the folder with Sparkle's command line tools if it is not found.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP="${1:?usage: appcast.sh <release zip>}"
REPO="${REPO:-DieBoiz/Glacier}"

BIN="${SPARKLE_BIN:-$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/Glacier-*/SourcePackages/artifacts/sparkle/Sparkle/bin 2>/dev/null | head -1)}"
[ -x "$BIN/generate_appcast" ] || { echo "error: Sparkle tools not found, set SPARKLE_BIN" >&2; exit 1; }

NAME="$(basename "${ZIP%.*}")"
VERSION="${NAME#Glacier-}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$ZIP" "$WORK/"
[ -f "$ROOT/docs/appcast.xml" ] && cp "$ROOT/docs/appcast.xml" "$WORK/appcast.xml"

"$BIN/generate_appcast" \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    "$WORK"

mkdir -p "$ROOT/docs"
cp "$WORK/appcast.xml" "$ROOT/docs/appcast.xml"
echo "==> Updated docs/appcast.xml for $VERSION"
