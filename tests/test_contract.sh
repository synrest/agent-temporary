#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
sh -n agent-temporary release.sh
[ "$(./agent-temporary version)" = "agent-temporary 0.5.0" ]
for ttl in 5m 30m 1h 8h; do ./agent-temporary --validate-ttl "$ttl" >/dev/null; done
for ttl in 0 4m 9h -1m forever 30x; do
    if ./agent-temporary --validate-ttl "$ttl" >/dev/null 2>&1; then exit 1; fi
done
grep -q 'DEFAULT_TTL=5m' agent-temporary
grep -q 'persist_reboot' agent-temporary
grep -q -- '--persist-reboot' agent-temporary
grep -q 'agent-temporary-boot.service' agent-temporary
grep -q 'agent-temporary-expire.timer' agent-temporary
grep -q 'agent-temporary-expire.openrc' release.sh
grep -q 'uninstall.sh' release.sh
grep -q 'INIT_SYSTEM=openrc' agent-temporary
grep -q '/sbin/rc-service' agent-temporary
grep -q 'service_active' agent-temporary
grep -q 'true_command=' agent-temporary
grep -q 'supervisor="supervise-daemon"' agent-temporary-expire.openrc
grep -q 'respawn_delay=30' agent-temporary-expire.openrc
! grep -q 'sudo -n -l -U' agent-temporary
grep -q 'status.*--json' agent-temporary
grep -q 'install.*--user' agent-temporary
test -x uninstall.sh
! grep -q 'respawn_delay=60' agent-temporary-expire.openrc
legacy_tmp=$(mktemp -d /tmp/agent-temporary-uninstall.XXXXXX)
trap 'rm -rf "$legacy_tmp"' EXIT HUP INT TERM
mkdir -p "$legacy_tmp/bin"
printf '%s\n' '#!/bin/sh' 'echo Darwin' > "$legacy_tmp/bin/uname"
chmod 755 "$legacy_tmp/bin/uname"
printf '%s\n' '#!/bin/sh' '[ "$1" = -u ] && { echo 0; exit 0; }' 'exit 0' > "$legacy_tmp/bin/id"
chmod 755 "$legacy_tmp/bin/id"
touch "$legacy_tmp/legacy-rule"
if PATH="$legacy_tmp/bin:$PATH" AGENT_TEMPORARY_LEGACY_RULE="$legacy_tmp/legacy-rule" sh uninstall.sh >"$legacy_tmp/output" 2>&1; then
    exit 1
fi
grep -q 'legacy sudoers authority fragment exists' "$legacy_tmp/output"
echo 'agent-temporary contract tests: PASS'
