#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
SIGN_IDENTITY=- scripts/bundle.sh
DMG=build/Sylt-$VERSION.dmg
scripts/dmg.sh build/Sylt.app "$DMG" "Sylt $VERSION"
shasum -a 256 "$DMG"
