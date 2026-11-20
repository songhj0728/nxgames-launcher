#!/bin/bash
# Build the launcher app (unsigned; tools/assemble.sh signs it) → build/dd/Build/Products/Release-iphoneos/NXLauncher.app
. "$(dirname "$0")/common.sh"
cd "$R/app" && xcodegen generate -q
xcodebuild -project NXLauncher.xcodeproj -scheme NXLauncher -configuration Release -destination generic/platform=iOS \
  -derivedDataPath "$B/dd" CODE_SIGNING_ALLOWED=NO build > "$B/launcher.log" 2>&1 || { grep -m5 "error:" "$B/launcher.log"; die "launcher build failed (log $B/launcher.log)"; }
echo "launcher built"
