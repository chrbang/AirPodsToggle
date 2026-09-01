#!/bin/zsh
# Build and zip AirPodsToggle for sending to friends (ad-hoc signed,
# so receivers must use "Open Anyway" — see the bundled install notes).
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

rm -rf dist
mkdir -p dist/AirPodsToggle
cp -R build/AirPodsToggle.app dist/AirPodsToggle/

cat > "dist/AirPodsToggle/How to install.txt" <<'EOF'
AirPodsToggle
=============
Toggle AirPods between Noise Cancellation and Transparency with a hotkey
(default: Option+Command+A).

Requirements: macOS 26 (Tahoe) or newer, and AirPods with noise control
(AirPods Pro, AirPods Max, or AirPods 4 with ANC).

Install
-------
1. Drag AirPodsToggle.app into your Applications folder and double-click it.

2. macOS will refuse to open it ("Apple could not verify..."). That is
   expected — the app isn't notarized. Go to:
     System Settings > Privacy & Security, scroll down, click "Open Anyway",
   then confirm. This is needed only once.

3. On first launch the app asks for Accessibility permission (it works by
   clicking the Sound menu for you — that's the only way Apple allows).
   Enable it under:
     System Settings > Privacy & Security > Accessibility > AirPodsToggle

4. If asked, let the app make the Sound icon always visible in the menu
   bar — it needs that menu to exist.

Use
---
* Press Option+Command+A to toggle Noise Cancellation / Transparency.
* Click the AirPods icon in the menu bar to toggle from a menu, change
  the shortcut, or quit.
* To start it automatically: System Settings > General > Login Items,
  add AirPodsToggle.

The Sound menu flashes briefly on each toggle — that's normal.
EOF

ditto -c -k dist/AirPodsToggle dist/AirPodsToggle.zip
rm -rf dist/AirPodsToggle
echo "Package ready: dist/AirPodsToggle.zip"
