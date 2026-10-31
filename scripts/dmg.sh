#!/usr/bin/env bash
# Finder lays the window out, so this needs a logged-in session and Automation access to Finder.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${3:?usage: scripts/dmg.sh <app> <dmg> <volume name>}"
APP=$1 DMG=$2 VOLUME=$3
NAME=$(basename "$APP")
if [ -d "/Volumes/$VOLUME" ]; then echo "/Volumes/$VOLUME is already mounted; eject it first" >&2; exit 1; fi

WORK=$(mktemp -d)
trap 'hdiutil detach -quiet "/Volumes/$VOLUME" 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stage/.background"
cp -R "$APP" "$WORK/stage/"
ln -s /Applications "$WORK/stage/Applications"
cp Resources/DMGBackground.tiff "$WORK/stage/.background/background.tiff"
cp Resources/AppIcon.icns "$WORK/stage/.VolumeIcon.icns"

hdiutil create -volname "$VOLUME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -size 200m -ov "$WORK/rw.dmg" >/dev/null
hdiutil attach -readwrite -noverify -noautoopen "$WORK/rw.dmg" >/dev/null
SetFile -a C "/Volumes/$VOLUME"

# Window size and icon positions match what scripts/make-dmg-background.swift draws.
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 840, 568}
        set options to icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 128
        set text size of options to 13
        set shows item info of options to false
        set background picture of options to file ".background:background.tiff"
        set position of item "$NAME" of container window to {180, 210}
        set position of item "Applications" of container window to {460, 210}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

for _ in $(seq 20); do [ -f "/Volumes/$VOLUME/.DS_Store" ] && break; sleep 0.5; done
rm -rf "/Volumes/$VOLUME/.fseventsd"
sync
hdiutil detach -quiet "/Volumes/$VOLUME"
rm -f "$DMG"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
