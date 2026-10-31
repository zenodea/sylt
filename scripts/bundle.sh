#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release 2>&1 | tail -3
APP=build/Sylt.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/Sylt "$APP/Contents/MacOS/"
# SwiftPM stamps the SDK as 14.0, so AppKit would draw macOS 14 window chrome (no Liquid Glass).
vtool -set-build-version macos 14.0 "$(xcrun --show-sdk-version)" -replace \
    -output "$APP/Contents/MacOS/Sylt.stamped" "$APP/Contents/MacOS/Sylt"
mv "$APP/Contents/MacOS/Sylt.stamped" "$APP/Contents/MacOS/Sylt"
cp .build/release/libMediaRemoteAdapter.dylib "$APP/Contents/Frameworks/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Plugins "$APP/Contents/Resources/Plugins"
# Ad-hoc signing loses Accessibility grants on every rebuild; see scripts/signing-identity.sh.
IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Sylt Dev"' | head -1 | tr -d '"')}
codesign --force --deep --sign "${IDENTITY:--}" "$APP"
echo "Built $APP"
