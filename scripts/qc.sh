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
GIT_OUT="$(/tmp/git-check "$GIT_TMP")"
echo "$GIT_OUT"
echo "$GIT_OUT" | grep -qx "branch feat-qc" || fail "GitStatus expected branch feat-qc, got '$GIT_OUT'"
echo "$GIT_OUT" | grep -qx "worktree NONE" || fail "main checkout should not be a worktree"
pass "GitStatus branch feat-qc"

WT_TMP="$(mktemp -d /tmp/to-wt-XXXX)"
git -C "$GIT_TMP" worktree add -q -b wt-qc "$WT_TMP"
WT_OUT="$(/tmp/git-check "$WT_TMP")"
echo "$WT_OUT"
echo "$WT_OUT" | grep -qx "branch wt-qc" || fail "worktree branch expected wt-qc, got '$WT_OUT'"
echo "$WT_OUT" | grep -qx "worktree $(basename "$WT_TMP")" || fail "worktree name expected $(basename "$WT_TMP")"
echo "$WT_OUT" | grep -qx "repo $(basename "$GIT_TMP")" || fail "worktree repo expected $(basename "$GIT_TMP")"
pass "GitStatus worktree $(basename "$WT_TMP")"

mkdir -p "$GIT_TMP/.grok/worktrees"
NEST_A="$GIT_TMP/.grok/worktrees/esign-qc"
NEST_B="$GIT_TMP/.grok/worktrees/incident-qc"
git -C "$GIT_TMP" worktree add -q -b esign-qc "$NEST_A"
git -C "$GIT_TMP" worktree add -q -b incident-qc "$NEST_B"
NEST_OUT="$(/tmp/git-check "$NEST_B")"
echo "$NEST_OUT"
echo "$NEST_OUT" | grep -qx "branch incident-qc" || fail "nested worktree branch expected incident-qc, got '$NEST_OUT'"
echo "$NEST_OUT" | grep -qx "worktree incident-qc" || fail "nested worktree name expected incident-qc"
echo "$NEST_OUT" | grep -qx "repo $(basename "$GIT_TMP")" || fail "nested worktree repo expected $(basename "$GIT_TMP")"
pass "GitStatus nested .grok/worktrees/incident-qc"

echo "== Grok overlay =="
swiftc -o /tmp/overlay-check \
  "$ROOT/Sources/TerminalOrganizer/Terminal/GitStatus.swift" \
  "$ROOT/Sources/TerminalOrganizer/Terminal/GrokWorktreeOverlay.swift" \
  "$ROOT/scripts/overlay-check.swift"
REPO="$(basename "$GIT_TMP")"
SESS="$(mktemp -d /tmp/to-ovl-XXXX)"
mkdir -p "$SESS/terminal"
cat > "$SESS/hunk_records.jsonl" <<EOF
{"filePath":"$NEST_A/foo.php","timestamp":"2026-01-01T00:00:00.000Z"}
{"filePath":"$NEST_B/bar.php","timestamp":"2026-01-02T12:00:00.000Z"}
EOF
OVL="$(/tmp/overlay-check "$GIT_TMP" "$SESS")"
echo "$OVL"
echo "$OVL" | grep -qx "branch incident-qc" || fail "overlay should follow newest hunk branch, got '$OVL'"
echo "$OVL" | grep -qx "worktree incident-qc" || fail "overlay should follow newest hunk worktree"
echo "$OVL" | grep -qx "repo $REPO" || fail "overlay repo expected $REPO"
pass "overlay newest hunk wins"

cat > "$SESS/hunk_records.jsonl" <<EOF
{"filePath":"$GIT_TMP/README","timestamp":"2026-06-01T00:00:00.000Z"}
EOF
MAIN_OVL="$(/tmp/overlay-check "$GIT_TMP" "$SESS")"
echo "$MAIN_OVL"
echo "$MAIN_OVL" | grep -qx "worktree NONE" || fail "main checkout hunks must not overlay, got '$MAIN_OVL'"
pass "overlay ignores main checkout paths"

OTHER="$(mktemp -d /tmp/to-ovl-other-XXXX)"
git -C "$OTHER" init -q -b main
git -C "$OTHER" -c user.email=qc@example.com -c user.name=qc commit --allow-empty -m qc -q
git -C "$OTHER" worktree add -q -b other-wt "$OTHER/wt"
cat > "$SESS/hunk_records.jsonl" <<EOF
{"filePath":"$OTHER/wt/x.php","timestamp":"2026-06-02T00:00:00.000Z"}
EOF
FOREIGN="$(/tmp/overlay-check "$GIT_TMP" "$SESS")"
echo "$FOREIGN"
echo "$FOREIGN" | grep -qx "worktree NONE" || fail "foreign repo must not overlay, got '$FOREIGN'"
pass "overlay ignores other repositories"

printf '%s\n' "Preparing worktree (new branch 'incident-qc')" ".grok/worktrees/incident-qc" \
  > "$SESS/terminal/call-create.log"
rm -f "$SESS/hunk_records.jsonl"
REL="$(/tmp/overlay-check "$GIT_TMP" "$SESS")"
echo "$REL"
echo "$REL" | grep -qx "worktree incident-qc" || fail "relative log path should overlay, got '$REL'"
echo "$REL" | grep -qx "branch incident-qc" || fail "relative log path branch expected incident-qc"
pass "overlay relative .grok/worktrees path in terminal log"

OPEN_OUT="$(/tmp/overlay-check open-path "/Users/x/.grok/sessions/%2FUsers%2Fx%2Fproj/01a03fef-fbc4-7533-a32d-4e73e5015c8a/hunk_records.jsonl")"
echo "$OPEN_OUT"
echo "$OPEN_OUT" | grep -qx "/Users/x/.grok/sessions/%2FUsers%2Fx%2Fproj/01a03fef-fbc4-7533-a32d-4e73e5015c8a" \
  || fail "open-path session dir parse, got '$OPEN_OUT'"
BAD_OPEN="$(/tmp/overlay-check open-path "/Users/x/.grok/hooks/terminal-organizer.json")"
echo "$BAD_OPEN" | grep -qx "NONE" || fail "non-session open path should be NONE"
pass "overlay grok session dir from open path"

git -C "$GIT_TMP" worktree remove --force "$WT_TMP" >/dev/null 2>&1 || rm -rf "$WT_TMP"
git -C "$GIT_TMP" worktree remove --force "$NEST_A" >/dev/null 2>&1 || true
git -C "$GIT_TMP" worktree remove --force "$NEST_B" >/dev/null 2>&1 || true
rm -rf "$GIT_TMP" "$WT_TMP" "$SESS" "$OTHER"

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
