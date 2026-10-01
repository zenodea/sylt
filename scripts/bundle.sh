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
cp -R Plugins "$APP/Contents/Resources/Plugins"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
