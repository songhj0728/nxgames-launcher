#!/bin/bash
# One-time setup: fetch nxnative at the pinned commit, apply the launcher's patch to it, and make its Python venv.
# Needs: Xcode 26, brew install xcodegen zstd glslang, brew install --cask dotnet-sdk
set -euo pipefail
cd "$(dirname "$0")"
git submodule update --init nxnative
if git -C nxnative apply --reverse --check ../patches/nxnative.patch 2>/dev/null; then echo "patch already applied"
else git -C nxnative apply ../patches/nxnative.patch && echo "patch applied"; fi
[ -x nxnative/.venv/bin/python ] || { python3 -m venv nxnative/.venv && nxnative/.venv/bin/pip install -q lz4 capstone fonttools "backports.zstd; python_version < '3.14'"; }
[ -f config.sh ] || { cp config.example.sh config.sh; echo "fill in config.sh"; }
[ -f games.tsv ] || { cp games.example.tsv games.tsv; echo "fill in games.tsv"; }
