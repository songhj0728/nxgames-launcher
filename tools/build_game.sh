#!/bin/bash
# Build one game as a framework for the launcher, with nxnative (DM_AS_DYLIB=1).
# Usage: tools/build_game.sh <name>            full build → build/<name>.ipa   (then: tools/assemble.sh <name>=build/<name>.ipa)
#        CODE_ONLY=1 tools/build_game.sh <name> code only → build/<name>.app   (then: tools/assemble.sh <name>=build/<name>.app; the game data on the phone stays)
# nxnative's own build lock keeps two builds from running at once.
. "$(dirname "$0")/common.sh"
name=${1:?usage: build_game.sh <name>}; dir=$(row "$name" 2); [ -n "$dir" ] || die "$name: add a row to games.tsv first"
read -r -a extra <<< "$(row "$name" 3)"
export DM_AS_DYLIB=1
out=$B/$name.ipa; [ "${CODE_ONLY:-0}" = 1 ] && export DM_SKIP_PACK=1
cd "$NX"   # relative paths in the row (env/botw.txt) are the repo's
for i in "${!extra[@]}"; do [[ ${extra[$i]} == env/* ]] && extra[$i]=$R/${extra[$i]}; done
echo "[$(date +%T)] $name: building (log $B/$name.log)"
.venv/bin/python scripts/build_ipa_from_nsp.py "$dir" ${extra[@]+"${extra[@]}"} -k "$KEYS" -l "$GAME_LANG" --no-show-fps \
  --bundle-id "$BUNDLE_PREFIX.$name" -o "$out" --progress lines > "$B/$name.log" 2>&1 || { tail -5 "$B/$name.log"; die "$name: build failed"; }
echo "[$(date +%T)] $name: $(tail -1 "$B/$name.log" | cut -c1-160)"
