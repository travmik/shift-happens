#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/ShiftHappens.app"
# Stable self-signed identity: keeps the macOS Accessibility (TCC) grant valid
# across rebuilds (ad-hoc signatures change cdhash and break the grant every time).
# The identity must exist in the login keychain; override with KS_SIGN_IDENTITY="-"
# for ad-hoc if you don't have it. Release builds (CI) set both overrides —
# see scripts/make-release-artifact.sh and ADR 0002.
SIGN_IDENTITY="${KS_SIGN_IDENTITY:-keyboard-switcher-dev}"
KS_APP_VERSION="${KS_APP_VERSION:-0.1.0}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ShiftHappens</string>
    <key>CFBundleDisplayName</key><string>Shift Happens</string>
    <key>CFBundleIdentifier</key><string>com.travmik.shift-happens</string>
    <key>CFBundleExecutable</key><string>ShiftHappens</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${KS_APP_VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

cp .build/release/ShiftHappens "$APP/Contents/MacOS/ShiftHappens"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/MenuBarIconTemplate.png "$APP/Contents/Resources/MenuBarIconTemplate.png"
codesign --force --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP"
