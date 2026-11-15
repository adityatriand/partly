#!/bin/bash
# Overwrite the installers in the Google Drive folder. The same names are
# replaced, so the folder does not grow and version.txt keeps its id.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="$ROOT/dist/Partly.dmg"
JSON="$ROOT/dist/latest.json"
REMOTE="partly"
NAME="Partly-macos-aarch64.dmg"
RCLONE="$(command -v rclone || true)"
if [ -z "$RCLONE" ]; then
  for candidate in /opt/homebrew/bin/rclone /usr/local/bin/rclone; do
    if [ -x "$candidate" ]; then RCLONE="$candidate"; break; fi
  done
fi
test -n "$RCLONE"
test -f "$DMG"
test -f "$JSON"
"$RCLONE" copyto "$DMG" "$REMOTE:$NAME"
LISTED="$("$RCLONE" lsjson "$REMOTE:")"
FILE_ID="$(python3 -c 'import json,sys; rows=json.load(sys.stdin); print(next(row["ID"] for row in rows if row.get("Name")==sys.argv[1] or row.get("Path")==sys.argv[1]))' "$NAME" <<<"$LISTED")"
VERSION="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(str(data["version"]) + "." + str(data["build"]))' "$JSON")"
MANIFEST="$(mktemp)"
printf '%s\nmacos-aarch64=%s\n' "$VERSION" "$FILE_ID" > "$MANIFEST"
"$RCLONE" copyto "$MANIFEST" "$REMOTE:version.txt"
rm -f "$MANIFEST"
echo "Replaced Drive files with $VERSION"
