#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
sh -n agent-temporary release.sh
[ "$(./agent-temporary version)" = "agent-temporary 0.3.0" ]
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
grep -q 'INIT_SYSTEM=openrc' agent-temporary
grep -q '/sbin/rc-service' agent-temporary
grep -q 'service_active' agent-temporary
! grep -q 'sh -c "$expiry_active"' agent-temporary
echo 'agent-temporary contract tests: PASS'
