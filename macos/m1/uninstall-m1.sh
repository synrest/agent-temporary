#!/bin/sh
set -eu

STATE_DIR=${AGENT_TEMPORARY_M1_STATE_DIR:-/var/db/agent-temporary-m1}
PLIST=${AGENT_TEMPORARY_M1_PLIST:-/Library/LaunchDaemons/com.agent-temporary.m1.plist}
LABEL=com.agent-temporary.m1
REAPER=${AGENT_TEMPORARY_M1_REAPER:-/usr/local/libexec/agent-temporary-reaper-m1}
MAIN=${AGENT_TEMPORARY_M1_MAIN:-/usr/local/libexec/agent-temporary-m1}
LAUNCHCTL=${LAUNCHCTL:-/bin/launchctl}

[ "$(id -u)" -eq 0 ] || { echo 'run as root' >&2; exit 1; }
"$LAUNCHCTL" bootout system/$LABEL >/dev/null 2>&1 || true
rm -f "$PLIST" "$REAPER" "$MAIN"
rm -rf "$STATE_DIR"
echo "removed $LABEL marker prototype"
