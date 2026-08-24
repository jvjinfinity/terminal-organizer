#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
if [[ "$CONFIG" != "release" && "$CONFIG" != "debug" ]]; then
  echo "usage: package.sh [release|debug]" >&2
  exit 1
fi

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  "$ROOT/scripts/make-icon.sh"
fi

swift build -c "$CONFIG" --product TerminalOrganizer 1>&2
swift build -c "$CONFIG" --product to-notify 1>&2
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/TerminalOrganizer"
NOTIFY="$BIN_DIR/to-notify"

APP="$ROOT/dist/Terminal Organizer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Terminal Organizer"
cp "$NOTIFY" "$APP/Contents/MacOS/to-notify"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/Terminal Organizer" "$APP/Contents/MacOS/to-notify"

BUNDLE="$BIN_DIR/SwiftTerm_SwiftTerm.bundle"
if [[ -d "$BUNDLE" ]]; then
  rm -rf "$APP/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
  cp -R "$BUNDLE" "$APP/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
fi

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "$APP"
