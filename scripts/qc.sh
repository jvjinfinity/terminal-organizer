#!/bin/zsh
set -eu
# pipefail is off: `open`/`ps|awk` can raise SIGPIPE under this environment.
# This script does not write ~/Library/Application Support/Terminal Organizer.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "QC FAIL: $*" >&2; exit 1; }
pass() { echo "QC PASS: $*"; }

echo "== build =="
swift build -c debug --product TerminalOrganizer

echo "== CWDProbe =="
cat > /tmp/cwdprobe-main.c <<'EOF'
#include "CWDProbe.h"
#include <stdio.h>
#include <unistd.h>
int main(void) {
    char buf[1024];
    if (cwd_probe_pid(getpid(), buf, sizeof(buf)) != 0) return 1;
    printf("%s\n", buf);
    return 0;
}
EOF
cc -o /tmp/cwdprobe-main /tmp/cwdprobe-main.c \
  -I "$ROOT/Sources/CWDProbe/include" \
  "$ROOT/Sources/CWDProbe/CWDProbe.c"
PROBE_CWD="$(/tmp/cwdprobe-main)"
[[ -n "$PROBE_CWD" && "$PROBE_CWD" == /* ]] || fail "CWDProbe returned '$PROBE_CWD'"
pass "CWDProbe -> $PROBE_CWD"

echo "== GitStatus =="
GIT_TMP="$(mktemp -d /tmp/to-git-XXXX)"
git -C "$GIT_TMP" init -q -b feat-qc
swiftc -o /tmp/git-check \
  "$ROOT/Sources/TerminalOrganizer/Terminal/GitStatus.swift" \
  "$ROOT/scripts/git-check.swift"
BRANCH="$(/tmp/git-check "$GIT_TMP")"
[[ "$BRANCH" == "feat-qc" ]] || fail "GitStatus expected feat-qc, got '$BRANCH'"
pass "GitStatus branch feat-qc"
rm -rf "$GIT_TMP"

echo "== XTVERSION sanitizer =="
swiftc -o /tmp/xtversion-check \
  "$ROOT/Sources/TOSupport/QueryReplySanitizer.swift" \
  "$ROOT/scripts/xtversion-check.swift"
/tmp/xtversion-check || fail "XTVERSION sanitizer"
pass "XTVERSION sanitizer"

echo "== OSC scanner =="
swiftc -o /tmp/osc-check \
  "$ROOT/Sources/TerminalOrganizer/Terminal/OSCNotificationScanner.swift" \
  "$ROOT/scripts/osc-check.swift"
/tmp/osc-check || fail "OSC scanner"
pass "OSC scanner"

echo
echo "All QC checks passed."
