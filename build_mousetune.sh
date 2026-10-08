#!/bin/bash
# Build this OpenSnek fork as "MouseTune.app" and install it to /Applications.
# Leaves no second copy on disk (same bundle id copies confuse macOS permissions).
set -euo pipefail
cd "$(dirname "$0")"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
OpenSnek/scripts/build_local.sh --configuration release --sign-identity adhoc --version 1.3.0-mousetune
cd OpenSnek/.dist
rm -rf MouseTune.app
mv OpenSnek.app MouseTune.app
plutil -replace CFBundleName -string MouseTune MouseTune.app/Contents/Info.plist
plutil -replace CFBundleDisplayName -string MouseTune MouseTune.app/Contents/Info.plist
codesign --force --sign - --requirements '=designated => identifier "io.opensnek.OpenSnek"' MouseTune.app
codesign --verify --deep --strict MouseTune.app
osascript -e 'tell application id "io.opensnek.OpenSnek" to quit' 2>/dev/null || true
sleep 2
pkill -x OpenSnek 2>/dev/null || true
sleep 1
rm -rf /Applications/MouseTune.app
mv MouseTune.app /Applications/MouseTune.app
"$LSR" -f /Applications/MouseTune.app
open /Applications/MouseTune.app
echo "INSTALLED"
