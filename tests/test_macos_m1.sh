#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
proto=macos/m1/agent-temporary-m1
plist=macos/m1/com.agent-temporary.m1.plist
sh -n "$proto" macos/m1/agent-temporary-reaper-m1 macos/m1/uninstall-m1.sh
/usr/bin/plutil -lint "$plist" >/dev/null

tmp=$(mktemp -d "${TMPDIR:-/tmp}/agent-temporary-m1.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf '#!/bin/sh\necho "{ sec = 100; usec = 0 }"\n' > "$tmp/sysctl"
chmod 755 "$tmp/sysctl"
env AGENT_TEMPORARY_M1_STATE_DIR="$tmp/state" \
    AGENT_TEMPORARY_M1_MARKER="$tmp/state/test-authority" \
    SYSCTL="$tmp/sysctl" LAUNCHCTL=/usr/bin/true \
    sh "$proto" on --ttl 5m >/dev/null
[ -e "$tmp/state/test-authority" ]
before=$(sed -n 's/^expires_at=//p' "$tmp/state/state")
env AGENT_TEMPORARY_M1_STATE_DIR="$tmp/state" \
    AGENT_TEMPORARY_M1_MARKER="$tmp/state/test-authority" \
    SYSCTL="$tmp/sysctl" LAUNCHCTL=/usr/bin/true sh "$proto" on --ttl 8h --persist-reboot | grep -q "already active"
[ "$(sed -n 's/^expires_at=//p' "$tmp/state/state")" = "$before" ]
env AGENT_TEMPORARY_M1_STATE_DIR="$tmp/state" \
    AGENT_TEMPORARY_M1_MARKER="$tmp/state/test-authority" \
    SYSCTL="$tmp/sysctl" LAUNCHCTL=/usr/bin/true sh "$proto" off >/dev/null
[ ! -e "$tmp/state/test-authority" ]
if env SYSCTL="$tmp/sysctl" LAUNCHCTL=/usr/bin/true sh "$proto" on --bogus >/dev/null 2>&1; then exit 1; fi
echo 'macOS M1 prototype tests: PASS'
