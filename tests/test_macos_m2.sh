#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/agent-temporary-m2.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
STATE_DIR=$TMP/state
RULE=$TMP/sudoers.d/90-agent-temporary
SUDOERS=$TMP/sudoers
LOCK=$STATE_DIR/.lock
mkdir -p "$STATE_DIR" "$(dirname "$RULE")"
: >"$SUDOERS"
ID=$TMP/id; VISUDO=$TMP/visudo; LAUNCHCTL=$TMP/launchctl; PROBE=$TMP/probe
SYSCTL=$TMP/sysctl; MKTEMP=$TMP/mktemp; CHOWN=$TMP/chown; MV=$TMP/mv; COUNT=$TMP/count
printf '%s\n' '#!/bin/sh' '[ "$1" = -u ] && { echo 0; exit 0; }' 'exit 0' >"$ID"
printf '%s\n' '#!/bin/sh' 'echo boot-test' >"$SYSCTL"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$CHOWN"
printf '%s\n' '#!/bin/sh' '[ "$FAKE_MV_MODE" = fail ] && [ "$2" = "$FAKE_RULE" ] && exit 1' 'exec /bin/mv "$@"' >"$MV"
printf '%s\n' '#!/bin/sh' '[ -e "'"$RULE"'" ] && [ "$FAKE_PROBE_MODE" = ok ]' >"$PROBE"
printf '%s\n' '#!/bin/sh' 'case "$FAKE_VISUDO_MODE" in' 'candidate-fail) case "$2" in *90-agent-temporary.*) exit 1;; esac;;' 'full-fail) [ "$2" = "$FAKE_SUDOERS" ] && exit 1;;' 'esac' 'exit 0' >"$VISUDO"
printf '%s\n' '#!/bin/sh' 'case "$FAKE_LAUNCH_MODE:$1" in' 'not-running:print) echo "state = not running"; exit 0;;' 'ok:print) echo "state = running"; exit 0;;' '*:kickstart) exit 0;;' '*) exit 0;;' 'esac' >"$LAUNCHCTL"
printf '%s\n' '#!/bin/sh' 'count=0' '[ -f "$FAKE_COUNT" ] && count=$(cat "$FAKE_COUNT")' 'count=$((count + 1)); echo "$count" >"$FAKE_COUNT"' '[ "$FAKE_MKTEMP_FAIL_AT" = "$count" ] && exit 1' 'exec /usr/bin/mktemp "$1"' >"$MKTEMP"
chmod 755 "$ID" "$SYSCTL" "$CHOWN" "$MV" "$PROBE" "$VISUDO" "$LAUNCHCTL" "$MKTEMP"
FAKE_VISUDO_MODE=ok; FAKE_PROBE_MODE=ok; FAKE_LAUNCH_MODE=ok; FAKE_MKTEMP_FAIL_AT=0; FAKE_MV_MODE=ok
export FAKE_VISUDO_MODE FAKE_PROBE_MODE FAKE_LAUNCH_MODE FAKE_MKTEMP_FAIL_AT FAKE_MV_MODE
run() {
    env AGENT_TEMPORARY_USER=alice AGENT_TEMPORARY_STATE_DIR="$STATE_DIR" AGENT_TEMPORARY_RULE="$RULE" AGENT_TEMPORARY_SUDOERS="$SUDOERS" AGENT_TEMPORARY_LOCK="$LOCK" ID="$ID" SYSCTL="$SYSCTL" VISUDO="$VISUDO" LAUNCHCTL="$LAUNCHCTL" PROBE="$PROBE" MKTEMP="$MKTEMP" CHOWN="$CHOWN" MV="$MV" KICK_ATTEMPTS=2 KICK_SLEEP=0.01 REAPER_LOCK_ATTEMPTS="${REAPER_LOCK_ATTEMPTS:-100}" REAPER_LOCK_SLEEP="${REAPER_LOCK_SLEEP:-0.01}" FAKE_COUNT="$COUNT" FAKE_RULE="$RULE" FAKE_SUDOERS="$SUDOERS" FAKE_VISUDO_MODE="$FAKE_VISUDO_MODE" FAKE_PROBE_MODE="$FAKE_PROBE_MODE" FAKE_LAUNCH_MODE="$FAKE_LAUNCH_MODE" FAKE_MKTEMP_FAIL_AT="$FAKE_MKTEMP_FAIL_AT" FAKE_MV_MODE="$FAKE_MV_MODE" "$ROOT/macos/agent-temporary-macos" "$@"
}
assert_absent() { [ ! -e "$RULE" ] && [ ! -e "$STATE_DIR/state" ]; }
set_state_field() {
    awk -v key="$1" -v value="$2" 'BEGIN { changed=0 } index($0, key "=") == 1 { print key "=" value; changed=1; next } { print } END { if (!changed) print key "=" value }' "$STATE_DIR/state" >"$TMP/state.new"
    mv "$TMP/state.new" "$STATE_DIR/state"
}
assert_ttl() {
    run off >/dev/null
    run on --ttl "$1" >/dev/null
    activated=$(sed -n 's/^activated_at=//p' "$STATE_DIR/state")
    expires=$(sed -n 's/^expires_at=//p' "$STATE_DIR/state")
    [ "$((expires - activated))" -eq "$2" ]
}
assert_rejected() {
    run off >/dev/null
    if run on --ttl "$1" >/dev/null 2>&1; then exit 1; fi
    assert_absent
}
assert_ttl 5m 300
assert_ttl 50m 3000
assert_ttl 1h 3600
assert_ttl 8h 28800
grep -qx 'Defaults:alice !authenticate' "$RULE"
grep -qx 'alice ALL=(ALL) NOPASSWD: ALL' "$RULE"
[ "$(stat -f %Lp "$RULE" 2>/dev/null || stat -c %a "$RULE")" = 440 ]
expiry=$(sed -n 's/^expires_at=//p' "$STATE_DIR/state")
run on --ttl 8h >"$TMP/repeat"; grep -q 'already active' "$TMP/repeat"
[ "$(sed -n 's/^expires_at=//p' "$STATE_DIR/state")" = "$expiry" ]
for invalid in 4m 9h 500m 5s abc; do assert_rejected "$invalid"; done
run off >/dev/null; assert_absent
run on --ttl 5m >/dev/null
mkdir "$LOCK"
run --reaper >/dev/null 2>&1 &
reaper_pid=$!
sleep 0.1
kill -0 "$reaper_pid"
rmdir "$LOCK"
sleep 0.1
kill "$reaper_pid" 2>/dev/null || true
wait "$reaper_pid" 2>/dev/null || true
rm -f "$RULE" "$STATE_DIR/state"
mkdir "$LOCK"
if REAPER_LOCK_ATTEMPTS=2 REAPER_LOCK_SLEEP=0.01 run --reaper >/dev/null 2>&1; then exit 1; fi
rmdir "$LOCK"
run on >/dev/null; set_state_field expires_at 1; run status >/dev/null; assert_absent
printf '%s\n' 'Defaults:alice !authenticate' 'alice ALL=(ALL) NOPASSWD: ALL' >"$RULE"; run status >"$TMP/orphan"; grep -q 'state=inconsistent' "$TMP/orphan"; assert_absent
run on >/dev/null; rm -f "$RULE"; run status >"$TMP/missing"; grep -q 'state=inconsistent' "$TMP/missing"; [ ! -e "$STATE_DIR/state" ]
for mode in candidate-fail full-fail; do rm -f "$RULE" "$STATE_DIR/state" "$COUNT"; FAKE_VISUDO_MODE=$mode run on >/dev/null 2>&1 && exit 1 || true; assert_absent; done
FAKE_VISUDO_MODE=ok
rm -f "$COUNT" "$RULE" "$STATE_DIR/state"; FAKE_MKTEMP_FAIL_AT=1 run on >/dev/null 2>&1 && exit 1 || true; assert_absent
FAKE_MKTEMP_FAIL_AT=0
rm -f "$COUNT" "$RULE" "$STATE_DIR/state"; FAKE_MKTEMP_FAIL_AT=2 run on >/dev/null 2>&1 && exit 1 || true; assert_absent
FAKE_MKTEMP_FAIL_AT=0
rm -f "$COUNT" "$RULE" "$STATE_DIR/state"; FAKE_MKTEMP_FAIL_AT=3 run on >/dev/null 2>&1 && exit 1 || true; assert_absent
FAKE_MKTEMP_FAIL_AT=0
rm -f "$COUNT" "$RULE" "$STATE_DIR/state"; FAKE_MV_MODE=fail run on >/dev/null 2>&1 && exit 1 || true; assert_absent
FAKE_MV_MODE=ok
rm -f "$RULE" "$STATE_DIR/state"; FAKE_PROBE_MODE=fail run on >/dev/null 2>&1 && exit 1 || true; assert_absent
FAKE_PROBE_MODE=ok
rm -f "$RULE" "$STATE_DIR/state"; FAKE_LAUNCH_MODE=not-running run on >/dev/null 2>&1 && exit 1 || true; assert_absent
FAKE_LAUNCH_MODE=ok
run on >/dev/null; FAKE_LAUNCH_MODE=not-running run status >/dev/null; assert_absent
FAKE_LAUNCH_MODE=ok
run on >/dev/null; set_state_field boot_identity old-boot; run --boot-revoke >/dev/null; assert_absent
grep -q 'com.agent-temporary.expire' "$ROOT/macos/com.agent-temporary.expire.plist"
grep -q 'com.agent-temporary.boot' "$ROOT/macos/com.agent-temporary.boot.plist"
grep -Fq '"$SU" "$1" -c "$SUDO -k; $SUDO -n $TRUE"' "$ROOT/macos/agent-temporary-macos"
! grep -Fq '"$SU" "$1" -c "$SUDO -n $TRUE"' "$ROOT/macos/agent-temporary-macos"
! grep -Fq '"$SU" -s /bin/sh' "$ROOT/macos/agent-temporary-macos"
! grep -q '<key>RunAtLoad</key>' "$ROOT/macos/com.agent-temporary.expire.plist"
grep -q '<key>RunAtLoad</key>' "$ROOT/macos/com.agent-temporary.boot.plist"
! grep -R -q '90-temporary-agent\|com.agent-temporary.m1' "$ROOT/macos/agent-temporary-macos" "$ROOT/macos/agent-temporary-reaper" "$ROOT/macos/com.agent-temporary.expire.plist" "$ROOT/macos/com.agent-temporary.boot.plist"
! grep -q 'zero' "$ROOT/macos/agent-temporary-macos"
echo 'macOS M2 real-authority isolated tests: PASS'
