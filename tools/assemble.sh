#!/bin/bash
# NX Games: the launcher app + one framework per game (built by tools/build_game.sh). Each game's large data
# (romfs.img, pso, aoc) is copied once into the app's data container (Library/NXRes/<game bundle ID>), which a reinstall of the same app keeps,
# so re-signing or a code update installs only code, tables and shader libraries.
# Usage: tools/assemble.sh [name=build/name.ipa | name=build/name.app ...]   no arguments: re-sign and reinstall what is there (fresh profile: tools/renew_profile.sh first)
#   name=x.app: a code update (CODE_ONLY=1 build): only the game's code and tables change, its data on the device stays
#   A game given here also has its data sent to the device.
#   DEVICE=ipad (or a UDID): install there. NOINSTALL=1 builds and signs only; PUSHONLY=1 only sends the game data still waiting in build/res/
. "$(dirname "$0")/common.sh"
case "${DEVICE:-iphone}" in iphone) UDID=$IPHONE_UDID;; ipad) UDID=$IPAD_UDID;; *) UDID=$DEVICE;; esac
PROF=$B/stub/Build/Products/Release-iphoneos/Games.app/embedded.mobileprovision
LAPP=$B/dd/Build/Products/Release-iphoneos/NXLauncher.app
APP=$B/NXGames.app; RES=$B/res
[ -f "$PROF" ] || die "no provisioning profile: run tools/renew_profile.sh"
[ -d "$LAPP" ] || die "no launcher build: run tools/build_launcher.sh"
mkdir -p "$APP/Frameworks"
rsync -a --exclude Frameworks "$LAPP/" "$APP/"
for arg in "$@"; do
  name=${arg%%=*}; ipa=${arg#*=}; fw=$APP/Frameworks/$name.framework
  [ -n "$(row "$name" 2)" ] || die "$name: add a row to games.tsv first"
  if [ -d "$ipa" ]; then   # a code update: code, tables and icon replaced, the framework's shader libraries kept, nothing sent to the device
    [ -d "$fw/msl" ] || die "$name: no framework with shader libraries to update; build its full IPA"
    echo "[$(date +%T)] $name: code update from $ipa"
    rsync -a --delete --exclude msl --exclude '*.lproj' "$ipa/" "$fw/"
  else
    echo "[$(date +%T)] $name: unpack $ipa"
    rm -rf "$B/work" "$fw" "$RES/$name"; mkdir -p "$B/work" "$RES/$name"
    ditto -x -k "$ipa" "$B/work"
    mv "$B/work/Payload/DmIOS.app" "$fw"; rm -rf "$B/work"
  fi
  file "$fw/DmIOS" | grep -q "dynamically linked shared library" || die "$name: DmIOS is not a dylib (build with tools/build_game.sh)"
  for d in romfs.img pso aoc; do [ -e "$fw/$d" ] && mv "$fw/$d" "$RES/$name/"; done   # the large files go to the data container; the shader libraries (thousands of small files) stay in the bundle
  [ -d "$fw/romfs" ] && die "$name: RomFS is a folder, not an image (not supported here)"
  plutil -replace CFBundlePackageType -string FMWK "$fw/Info.plist"
  plutil -remove UIApplicationSceneManifest "$fw/Info.plist" 2>/dev/null || true
done
# Every game framework: its own game's code (verify_fw.py), its name in each language (game_names.py), signed
for fw in "$APP"/Frameworks/*.framework; do
  [ -d "$fw" ] || continue; name=$(basename "$fw" .framework)
  p=$(patched_dir "$name"); [ -d "$p" ] || die "$name: no patched build folder found in its game folder"
  python3 "$R/tools/verify_fw.py" "$fw" "$p" || die "stopping: $name holds the wrong code"
  for d in romfs.img pso aoc; do [ ! -e "$fw/$d" ] || die "$name: $d is still in the bundle"; done
  python3 "$R/tools/game_names.py" "$fw" "$(nacp_of "$name")"
  codesign -f -s "$SIGN_ID" --timestamp=none "$fw"
done
cp "$PROF" "$APP/embedded.mobileprovision"
security cms -D -i "$PROF" > "$B/prof.plist"; plutil -extract Entitlements xml1 -o "$B/ent.plist" "$B/prof.plist"
echo "[$(date +%T)] sign the app ($(du -sh "$APP" | cut -f1))"
codesign -f -s "$SIGN_ID" --timestamp=none --entitlements "$B/ent.plist" "$APP"
codesign --verify --deep --strict "$APP" && echo "signature ok"
rm -f "$B/prof.plist" "$B/ent.plist"
[ "${NOINSTALL:-0}" = 1 ] && exit 0
if [ "${PUSHONLY:-0}" != 1 ]; then   # retried: the connection to the device sometimes drops ("Connection interrupted")
  ok=0; for i in 1 2 3; do
    echo "[$(date +%T)] install (try $i)"
    if xcrun devicectl device install app --device "$UDID" "$APP" > "$B/install.log" 2>&1; then ok=1; break; fi
    grep -m1 -E "ERROR|Connection" "$B/install.log" || true; sleep 10
  done
  [ $ok = 1 ] || die "install failed, log $B/install.log"
fi
# One file or folder to the data container: retried, and a folder that keeps timing out goes one entry at a time
send() {
  local src=$1 dst=$2 i
  for i in 1 2 3; do
    xcrun devicectl device copy to --device "$UDID" --domain-type appDataContainer --domain-identifier "$BUNDLE_PREFIX.games" --source "$src" --destination "$dst" > /dev/null 2>"$B/send.err" && return 0
    echo "    retry $i: $(grep -m1 -o 'timed out[^.]*' "$B/send.err" || head -c 200 "$B/send.err")"; sleep 5
  done
  [ -d "$src" ] || { cat "$B/send.err"; return 1; }
  echo "    $(basename "$src"): sending its $(ls "$src" | wc -l | tr -d ' ') entries one by one"
  local e; for e in "$src"/*; do send "$e" "$dst/$(basename "$e")" || return 1; done
}
# Game data waiting in build/res: sent to Library/NXRes/<game bundle ID>, then removed here
for d in "$RES"/*/; do
  [ -d "$d" ] || continue; name=$(basename "$d"); fw=$APP/Frameworks/$name.framework
  bid=$(plutil -extract CFBundleIdentifier raw "$fw/Info.plist")
  for item in "$d"*; do
    [ -e "$item" ] || continue
    echo "[$(date +%T)] $name: send $(basename "$item") ($(du -sh "$item" | cut -f1))"
    send "$item" "Library/NXRes/$bid/$(basename "$item")"
  done
  rm -rf "$d"; echo "[$(date +%T)] $name: data installed"
done
echo "[$(date +%T)] done"
