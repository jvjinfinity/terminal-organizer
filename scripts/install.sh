#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Terminal Organizer.app"

if pgrep -x "Terminal Organizer" >/dev/null 2>&1; then
  echo "Replacing the running app. Live shells will not resume; folders and notes will."
  pkill -x "Terminal Organizer" 2>/dev/null || true
  sleep 0.2
fi

"$ROOT/scripts/package.sh" release
APP="$ROOT/dist/Terminal Organizer.app"
[[ -d "$APP" ]] || { echo "package failed: $APP missing" >&2; exit 1; }

rm -rf "$DEST"
cp -R "$APP" "$DEST"
# Finder/Spotlight pick up the icon more reliably after an ad-hoc sign on the installed copy.
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1 || true

echo "Installed $DEST"
open "$DEST"
