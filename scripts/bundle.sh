#!/usr/bin/env bash
# Builds a release binary and wraps it in ControlIsland.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release 2>&1 | tail -3
APP=build/ControlIsland.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/ControlIsland "$APP/Contents/MacOS/"
cp .build/release/libMediaRemoteAdapter.dylib "$APP/Contents/Frameworks/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Plugins "$APP/Contents/Resources/Plugins"
# A stable identity keeps Accessibility and other grants across rebuilds; see scripts/signing-identity.sh.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Control Island Dev"' | head -1 | tr -d '"')
codesign --force --deep --sign "${IDENTITY:--}" "$APP"
echo "Built $APP"
