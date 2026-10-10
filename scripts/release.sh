#!/usr/bin/env bash
# Builds an ad-hoc signed Sylt.app and packs it into build/Sylt-<version>.dmg.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
SIGN_IDENTITY=- scripts/bundle.sh
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R build/Sylt.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG=build/Sylt-$VERSION.dmg
rm -f "$DMG"
hdiutil create -volname "Sylt $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
shasum -a 256 "$DMG"
