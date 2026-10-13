#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/agent-temporary-safety.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
STATE_DIR=$TMP/state
RULE=$TMP/sudoers.d/90-temporary-agent
STATE=$STATE_DIR/state
LOCK=$STATE_DIR/.lock
CONFIG=$TMP/agent-temporary.conf
SUDOERS=$TMP/sudoers
mkdir -p "$STATE_DIR" "$(dirname "$RULE")"
: >"$SUDOERS"
printf 'AGENT_USER=alice\n' >"$CONFIG"

grep -q '^OnBootSec=1s$' "$ROOT/agent-temporary-expire.timer"
grep -q '^OnUnitActiveSec=1s$' "$ROOT/agent-temporary-expire.timer"
grep -q '^After=agent-temporary-boot.service$' "$ROOT/agent-temporary-expire.service"

sed '/^if \[ "$OS" = Darwin \]; then/,$d' "$ROOT/agent-temporary" >"$TMP/library"
cat >"$TMP/harness" <<'EOF'
#!/bin/sh
set -eu
. "$LIBRARY"
need_root() { :; }
validate_platform() { INIT_SYSTEM=systemd; }
load_user() { AGENT_USER=alice; }
validate_sudoers() { return 0; }
service_start() { return 0; }
service_stop() { return 0; }
service_active() { return 0; }
effective_unrestricted() { [ -n "${1:-}" ] && [ "${FAKE_AUTH:-no}" = yes ]; }
write_rule() { printf '%s\n' 'alice ALL=(ALL) NOPASSWD: ALL' >"$RULE"; }
date() { [ "${1:-}" = +%s ] && { echo "${FAKE_NOW:-1789000000}"; return; }; /bin/date "$@"; }
chown() { :; }
rm() { [ "${FAKE_RM_FAIL:-no}" = yes ] && return 1; /bin/rm "$@"; }
flock() { [ "${FAKE_LOCK_BUSY:-no}" = yes ] && [ "${1:-}" = -n ] && return 1; return 0; }
case "$1" in
    on) shift; do_on "$@";;
    expire) do_expire;;
    boot) do_boot_revoke;;
    *) exit 2;;
esac
EOF
chmod 755 "$TMP/harness"
printf '%s\n' '#!/bin/sh' 'echo Linux' >"$TMP/uname"
chmod 755 "$TMP/uname"
run() {
    env LIBRARY="$TMP/library" AGENT_TEMPORARY_STATE_DIR="$STATE_DIR" AGENT_TEMPORARY_STATE="$STATE" AGENT_TEMPORARY_LOCK="$LOCK" AGENT_TEMPORARY_RULE="$RULE" AGENT_TEMPORARY_CONFIG="$CONFIG" AGENT_TEMPORARY_SUDOERS="$SUDOERS" UNAME="$TMP/uname" FLOCK=flock FAKE_NOW="${FAKE_NOW:-1789000000}" FAKE_AUTH="${FAKE_AUTH:-yes}" FAKE_RM_FAIL="${FAKE_RM_FAIL:-no}" FAKE_LOCK_BUSY="${FAKE_LOCK_BUSY:-no}" "$TMP/harness" "$@"
}

run on --ttl 5m
first_expires=$(sed -n 's/^expires_at_epoch=//p' "$STATE")
first_activated=$(sed -n 's/^activated_at_epoch=//p' "$STATE")
FAKE_NOW=1789000001 run on --ttl 8h >"$TMP/repeat"
grep -q 'already active; expires_at_epoch=' "$TMP/repeat"
[ "$(sed -n 's/^expires_at_epoch=//p' "$STATE")" = "$first_expires" ]

if FAKE_LOCK_BUSY=yes run on --ttl 5m >/dev/null 2>&1; then exit 1; fi
FAKE_LOCK_BUSY=no

FAKE_NOW=$((first_expires + 1)) FAKE_AUTH=no run expire
[ ! -e "$RULE" ] && [ ! -e "$STATE" ]

FAKE_AUTH=yes run on --ttl 5m >/dev/null
clock_back_activated=$(sed -n 's/^activated_at_epoch=//p' "$STATE")
FAKE_NOW=$((clock_back_activated - 1)) FAKE_AUTH=no run expire
[ ! -e "$RULE" ] && [ ! -e "$STATE" ]
printf '%s\n' orphan >"$RULE"
FAKE_AUTH=no run expire
[ ! -e "$RULE" ] && [ ! -e "$STATE" ]

FAKE_AUTH=yes run on --ttl 5m >/dev/null
expires=$(sed -n 's/^expires_at_epoch=//p' "$STATE")
if FAKE_NOW=$((expires + 1)) FAKE_RM_FAIL=yes run expire >/dev/null 2>&1; then exit 1; fi
[ -e "$RULE" ] && [ -e "$STATE" ]
FAKE_NOW=$((expires + 1)) FAKE_AUTH=no FAKE_RM_FAIL=no run expire
[ ! -e "$RULE" ] && [ ! -e "$STATE" ]

FAKE_AUTH=yes run on --ttl 5m >/dev/null
FAKE_AUTH=no run boot
[ ! -e "$RULE" ] && [ ! -e "$STATE" ]
echo 'hard-stop nonpersistent: authority=revoked state=absent rule=absent'

FAKE_AUTH=yes run on --ttl 5m --persist-reboot >/dev/null
persistent_expires=$(sed -n 's/^expires_at_epoch=//p' "$STATE")
run boot
[ -e "$RULE" ] && [ -e "$STATE" ]
[ "$(sed -n 's/^expires_at_epoch=//p' "$STATE")" = "$persistent_expires" ]
echo "hard-stop persistent: authority=restored expires_at=$persistent_expires"
FAKE_NOW=$((persistent_expires + 1)) run boot
[ ! -e "$RULE" ] && [ ! -e "$STATE" ]
echo 'hard-stop persistent-after-deadline: authority=revoked state=absent rule=absent'

FAKE_AUTH=yes run on --ttl 5m >/dev/null
rm -f "$RULE"
run boot
[ ! -e "$RULE" ] && [ ! -e "$STATE" ]
FAKE_AUTH=yes run on --ttl 5m >/dev/null
[ -e "$RULE" ] && [ -e "$STATE" ]
echo 'boot orphan recovery: inactive then subsequent grant succeeds'

echo 'lifecycle safety tests: PASS'
