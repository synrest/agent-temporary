#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/agent-temporary-m2.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fake_id() { [ "$1" = -u ] && { echo 0; return 0; }; return 0; }
fake_date() { [ "${1:-}" = +%s ] && echo "${FAKE_NOW:-1788740000}" || echo 'Sep 6, 10:24 PM'; }
fake_sysctl() { echo '{ sec = 1788047880, usec = 142950 } Sat Aug 29 18:58:00 2026'; }
fake_visudo() { return 0; }
fake_probe() { [ -e "$FAKE_RULE" ] && [ "$FAKE_PROBE_MODE" = ok ]; }
fake_launchctl() { [ "$1" = print ] && { [ "$FAKE_LAUNCH_MODE" = ok ] && echo 'state = running' || echo 'state = not running'; }; return 0; }
fake_chown() { return 0; }
fake_chmod() { return 0; }
fake_mktemp() { FAKE_MKTEMP_COUNT=$((FAKE_MKTEMP_COUNT + 1)); p=${1%XXXXXX}$FAKE_MKTEMP_COUNT; : >"$p"; echo "$p"; }

setup() {
    CASE=$TMP/$1; STATE_DIR=$CASE/state; RULE=$CASE/sudoers.d/90-agent-temporary
    SUDOERS=$CASE/sudoers; LOCK=$STATE_DIR/.lock
    mkdir -p "$STATE_DIR" "$(dirname "$RULE")"; : >"$SUDOERS"
    ID=$CASE/id; DATE=$CASE/date; SYSCTL=$CASE/sysctl; VISUDO=$CASE/visudo
    PROBE=$CASE/probe; LAUNCHCTL=$CASE/launchctl; MKTEMP=$CASE/mktemp
    CHOWN=$CASE/chown; MV=$CASE/mv; MKDIR=$CASE/mkdir
    printf '%s\n' '#!/bin/sh' '[ "$1" = -u ] && { echo 0; exit 0; }' 'exit 0' >"$ID"
    printf '%s\n' 'if [ "${1:-}" = +%s ]; then echo "${FAKE_NOW:-1788740000}"; else echo "Sep 6, 10:24 PM"; fi' >"$DATE"
    printf '%s\n' 'echo "{ sec = 1788047880, usec = 142950 } Sat Aug 29 18:58:00 2026"' >"$SYSCTL"
    printf '%s\n' '#!/bin/sh' 'exit 0' >"$CHOWN"
    printf '%s\n' '#!/bin/sh' 'exec /bin/mv "$@"' >"$MV"
    printf '%s\n' '#!/bin/sh' '[ -e "$FAKE_RULE" ] && [ "$FAKE_PROBE_MODE" = ok ]' >"$PROBE"
    printf '%s\n' '#!/bin/sh' 'exit 0' >"$VISUDO"
    printf '%s\n' '#!/bin/sh' 'case "$FAKE_LAUNCH_MODE:$1" in ok:print) echo "state = running";; not-running:print) echo "state = not running";; esac; exit 0' >"$LAUNCHCTL"
    printf '%s\n' '#!/bin/sh' 'exec /usr/bin/mktemp "$1"' >"$MKTEMP"
    printf '%s\n' '#!/bin/sh' 'if [ "$1" != -p ] && [ "$FAKE_MKDIR_FAIL_ONCE" = yes ] && [ ! -e "$FAKE_MKDIR_MARK" ]; then : >"$FAKE_MKDIR_MARK"; exit 1; fi; exec /bin/mkdir "$@"' >"$MKDIR"
    chmod 755 "$ID" "$DATE" "$SYSCTL" "$VISUDO" "$PROBE" "$LAUNCHCTL" "$MKTEMP" "$CHOWN" "$MV" "$MKDIR"
    FAKE_PROBE_MODE=ok FAKE_LAUNCH_MODE=ok FAKE_MKDIR_FAIL_ONCE=no; export FAKE_PROBE_MODE FAKE_LAUNCH_MODE FAKE_MKDIR_FAIL_ONCE
    sed 's/echo "already active; expires_at=$expires; no changes made\."; exit 0/echo "already active; expires_at=$expires; no changes made."; return 0/' "$ROOT/macos/agent-temporary-macos" >"$CASE/backend"
    sed '/^case ${1:-}/,$d; s/echo "already active; expires_at=$expires; no changes made\."; exit 0/echo "already active; expires_at=$expires; no changes made."; return 0/' "$ROOT/macos/agent-temporary-macos" >"$CASE/library"
    AGENT_TEMPORARY_USER=alice AGENT_TEMPORARY_STATE_DIR="$STATE_DIR" AGENT_TEMPORARY_RULE="$RULE" AGENT_TEMPORARY_SUDOERS="$SUDOERS" AGENT_TEMPORARY_LOCK="$LOCK"
    export AGENT_TEMPORARY_USER AGENT_TEMPORARY_STATE_DIR AGENT_TEMPORARY_RULE AGENT_TEMPORARY_SUDOERS AGENT_TEMPORARY_LOCK
    FAKE_RULE="$RULE"; export FAKE_RULE
    KICK_ATTEMPTS=2 KICK_SLEEP=0 REAPER_LOCK_ATTEMPTS=3 REAPER_LOCK_SLEEP=0
    FAKE_MKTEMP_COUNT=0
    export KICK_ATTEMPTS KICK_SLEEP REAPER_LOCK_ATTEMPTS REAPER_LOCK_SLEEP FAKE_MKTEMP_COUNT
    ID=fake_id DATE=fake_date SYSCTL=fake_sysctl VISUDO=fake_visudo PROBE=fake_probe LAUNCHCTL=fake_launchctl MKTEMP=fake_mktemp CHOWN=fake_chown CHMOD=fake_chmod
    export ID DATE SYSCTL VISUDO PROBE LAUNCHCTL MKTEMP CHOWN CHMOD
    export ID DATE SYSCTL VISUDO PROBE LAUNCHCTL MKTEMP CHOWN MV MKDIR
    . "$CASE/library"
}
run() {
    case "$1" in
        on) shift; on_cmd "$@";;
        off) off_cmd;;
        --boot-revoke) boot_reconcile_cmd;;
        *) return 2;;
    esac
    release_lock
}
run_external() {
    env AGENT_TEMPORARY_USER=alice AGENT_TEMPORARY_STATE_DIR="$STATE_DIR" AGENT_TEMPORARY_RULE="$RULE" AGENT_TEMPORARY_SUDOERS="$SUDOERS" AGENT_TEMPORARY_LOCK="$LOCK" ID="$CASE/id" DATE="$CASE/date" SYSCTL="$CASE/sysctl" VISUDO="$CASE/visudo" PROBE="$CASE/probe" LAUNCHCTL="$CASE/launchctl" MKTEMP="$CASE/mktemp" CHOWN="$CASE/chown" MV="$CASE/mv" MKDIR="$CASE/mkdir" FAKE_RULE="$RULE" FAKE_NOW="${FAKE_NOW:-1788740000}" FAKE_LAUNCH_MODE="$FAKE_LAUNCH_MODE" FAKE_PROBE_MODE="$FAKE_PROBE_MODE" FAKE_MKDIR_FAIL_ONCE="$FAKE_MKDIR_FAIL_ONCE" FAKE_MKDIR_MARK="$CASE/mkdir.mark" KICK_ATTEMPTS=2 KICK_SLEEP=0 REAPER_LOCK_ATTEMPTS=3 REAPER_LOCK_SLEEP=0 "$CASE/backend" "$@"
}
absent() { [ ! -e "$RULE" ] && [ ! -e "$STATE_DIR/state" ]; }
set_state() { awk -v k="$1" -v v="$2" 'index($0,k "=")==1 {$0=k "=" v} {print}' "$STATE_DIR/state" >"$CASE/state.new"; mv "$CASE/state.new" "$STATE_DIR/state"; }

setup activation
run on --ttl 50m >"$CASE/on"; grep -qx 'phase=active' "$STATE_DIR/state"; grep -qx 'persist_reboot=no' "$STATE_DIR/state"
grep -qx 'Temporary access enabled for alice for 50m.' "$CASE/on"
grep -qx 'Expires: Sep 6, 10:24 PM' "$CASE/on"
grep -qx 'Reboot:  revoke' "$CASE/on"
! grep -q 'until epoch' "$CASE/on"
issued=$(sed -n 's/^issued_at=//p' "$STATE_DIR/state"); expires=$(sed -n 's/^expires_at=//p' "$STATE_DIR/state")
run on --ttl 8h >"$CASE/repeat"; grep -q 'already active' "$CASE/repeat"
[ "$(sed -n 's/^issued_at=//p' "$STATE_DIR/state")" = "$issued" ]; [ "$(sed -n 's/^expires_at=//p' "$STATE_DIR/state")" = "$expires" ]
if run_external on --ttl 8h --persist-reboot >/dev/null 2>&1; then exit 1; fi
run off >"$CASE/off"; grep -qx 'Temporary access revoked.' "$CASE/off"; absent

setup persistence
run on --ttl 50m --persist-reboot >/dev/null; expires=$(sed -n 's/^expires_at=//p' "$STATE_DIR/state")
run --boot-revoke >/dev/null; grep -qx 'persist_reboot=yes' "$STATE_DIR/state"; grep -qx "expires_at=$expires" "$STATE_DIR/state"
rm -f "$RULE"; run --boot-revoke >/dev/null; [ -e "$RULE" ]
set_state expires_at 1; run --boot-revoke >/dev/null 2>&1 || true; absent
run on --ttl 50m --persist-reboot >/dev/null; set_state issued_at 9999999999; run --boot-revoke >/dev/null 2>&1 || true; absent
run on --ttl 5m >/dev/null; run --boot-revoke >/dev/null; absent

setup rollback
FAKE_PROBE_MODE=fail; if run_external on --ttl 5m >/dev/null 2>&1; then exit 1; fi; absent
FAKE_PROBE_MODE=ok; FAKE_LAUNCH_MODE=not-running; if run_external on --ttl 5m >/dev/null 2>&1; then exit 1; fi; absent

echo 'macOS M2 deterministic tests: PASS'
