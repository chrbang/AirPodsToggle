#!/bin/zsh
# Build AirPodsToggle.app (universal) and install it into ~/Applications.
# Note: the ad-hoc signature changes on every rebuild, so macOS will ask
# for the Accessibility grant again after rebuilding.
set -euo pipefail
cd "$(dirname "$0")"

APP=AirPodsToggle
BUNDLE="build/$APP.app"

rm -rf build
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

swiftc -O -target arm64-apple-macos26.0 main.swift -o build/$APP-arm64
swiftc -O -target x86_64-apple-macos26.0 main.swift -o build/$APP-x86_64
lipo -create -output "$BUNDLE/Contents/MacOS/$APP" build/$APP-arm64 build/$APP-x86_64
rm build/$APP-arm64 build/$APP-x86_64

cp AppIcon.icns "$BUNDLE/Contents/Resources/"

cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>AirPodsToggle</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.chrbang.AirPodsToggle</string>
	<key>CFBundleName</key>
	<string>AirPodsToggle</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>26.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>© 2026 Christer Bang. MIT License.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$BUNDLE"

mkdir -p ~/Applications
rm -rf ~/Applications/$APP.app
cp -R "$BUNDLE" ~/Applications/
echo "Installed to ~/Applications/$APP.app"
