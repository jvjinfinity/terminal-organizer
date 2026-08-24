#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pkill -x "Terminal Organizer" 2>/dev/null || true
sleep 0.2
"$ROOT/scripts/package.sh" debug >/dev/null
APP="$ROOT/dist/Terminal Organizer.app"
[[ -d "$APP" ]] || { echo "package failed: $APP missing" >&2; exit 1; }
open "$APP"
