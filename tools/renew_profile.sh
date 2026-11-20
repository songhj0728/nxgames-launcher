#!/bin/bash
# A fresh provisioning profile for the launcher (free teams: every 7 days), then re-sign and reinstall with: tools/assemble.sh
# Moves this app's old profiles aside so that Xcode fetches a new one, then builds the stub app for the device.
. "$(dirname "$0")/common.sh"
P="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; old=$B/old-profiles; mkdir -p "$old"
for f in "$P"/*.mobileprovision; do
  [ -e "$f" ] || continue
  security cms -D -i "$f" 2>/dev/null | grep -q "<string>$TEAM_ID.$BUNDLE_PREFIX.games</string>" && mv "$f" "$old/" && echo "moved aside $(basename "$f")"
done
UDID=$IPHONE_UDID; [ "${DEVICE:-iphone}" = ipad ] && UDID=$IPAD_UDID
cd "$R/stub" && xcodegen generate -q
xcodebuild -project Stub.xcodeproj -scheme Games -configuration Release -destination "id=$UDID" -derivedDataPath "$B/stub" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build > "$B/stub.log" 2>&1 || { grep -m5 "error" "$B/stub.log"; die "stub build failed (log $B/stub.log)"; }
prof=$B/stub/Build/Products/Release-iphoneos/Games.app/embedded.mobileprovision
echo "profile expires $(security cms -D -i "$prof" | plutil -extract ExpirationDate raw -)"
