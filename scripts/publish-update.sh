#!/bin/bash
# Replace the update branch with the current local installer.
# The branch has one commit, so the next publish overwrites the previous disk image.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="$ROOT/dist/Partly.dmg"
JSON="$ROOT/dist/latest.json"
test -f "$DMG"
test -f "$JSON"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git init -q -b update "$WORK/repo"
cp "$DMG" "$WORK/repo/Partly.dmg"
cp "$JSON" "$WORK/repo/latest.json"
git -C "$WORK/repo" add Partly.dmg latest.json
git -C "$WORK/repo" commit -q -m "Replace the Partly installer."
git -C "$WORK/repo" remote add origin "https://github.com/adityatriand/partly.git"
git -C "$WORK/repo" push --force origin update
