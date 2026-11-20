# Sourced by the other tools: repo paths, config.sh, and the games.tsv lookups
set -euo pipefail
R=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NX=$R/nxnative; B=$R/build
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
[ -f "$R/config.sh" ] || { echo "config.sh missing: cp config.example.sh config.sh and fill it in"; exit 1; }
. "$R/config.sh"; export TEAM_ID BUNDLE_PREFIX
mkdir -p "$B"
die() { echo "$*" >&2; exit 1; }
# Row fields of a game in games.tsv: 2 = its game folder, 3 = extra build arguments
row() { [ -f "$R/games.tsv" ] || die "games.tsv missing: cp games.example.tsv games.tsv"; awk -F'\t' -v n="$1" -v c="$2" '$1 == n && $1 !~ /^#/ {print $c}' "$R/games.tsv"; }
# The game's build folder from nxnative (<title ID>_build/patched_v<version>): the version given with -p in its row, else the newest
patched_dir() {
  local dir v; dir=$(row "$1" 2); [ -n "$dir" ] || die "$1: add a row to games.tsv first"
  v=$(row "$1" 3 | sed -n 's/.*-p \(v[0-9]*\).*/\1/p')
  if [ -n "$v" ]; then ls -d "$dir"/*_build/patched_$v 2>/dev/null | head -1
  else ls -d "$dir"/*_build/patched_v*/ 2>/dev/null | sed 's:/$::' | awk -F_v '{print $NF "\t" $0}' | sort -n | tail -1 | cut -f2; fi
}
nacp_of() { local p; p=$(patched_dir "$1"); echo "$(dirname "$p")/extract/${p##*patched_}/control.nacp"; }
