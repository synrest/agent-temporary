#!/bin/sh
set -eu

PREFIX=${PREFIX:-/usr/local/bin}
TARGET=${TARGET:-$PREFIX/agent-temporary}
RULE=${AGENT_TEMPORARY_RULE:-/etc/sudoers.d/90-temporary-agent}
CONFIG=${AGENT_TEMPORARY_CONFIG:-/etc/agent-temporary.conf}
STATE_DIR=${AGENT_TEMPORARY_STATE_DIR:-/var/lib/agent-temporary}
SYSTEMD_DIR=${AGENT_TEMPORARY_SYSTEMD_DIR:-/etc/systemd/system}
OPENRC_DIR=${AGENT_TEMPORARY_OPENRC_DIR:-/etc/init.d}
SYSTEMCTL=${SYSTEMCTL:-systemctl}
RCSERVICE=${RCSERVICE:-/sbin/rc-service}
RCUPDATE=${RCUPDATE:-/sbin/rc-update}

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
rm -f "$RULE"
if command -v "$SYSTEMCTL" >/dev/null 2>&1 && { [ -d /run/systemd/system ] || "$SYSTEMCTL" show-environment >/dev/null 2>&1; }; then
    "$SYSTEMCTL" disable --now agent-temporary-expire.timer >/dev/null 2>&1 || true
    rm -f "$SYSTEMD_DIR/agent-temporary-expire.service" "$SYSTEMD_DIR/agent-temporary-expire.timer" "$SYSTEMD_DIR/agent-temporary-boot.service"
    "$SYSTEMCTL" daemon-reload >/dev/null 2>&1 || true
elif [ -x "$RCSERVICE" ]; then
    "$RCSERVICE" agent-temporary-expire stop >/dev/null 2>&1 || true
    "$RCUPDATE" del agent-temporary-boot default >/dev/null 2>&1 || true
    "$RCUPDATE" del agent-temporary-expire default >/dev/null 2>&1 || true
    "$RCSERVICE" agent-temporary-boot stop >/dev/null 2>&1 || true
    rm -f "$OPENRC_DIR/agent-temporary-boot" "$OPENRC_DIR/agent-temporary-expire"
fi
rm -f "$CONFIG" "$TARGET"
rm -rf "$STATE_DIR"
if command -v visudo >/dev/null 2>&1; then visudo -cf /etc/sudoers >/dev/null; fi
echo "Removed agent-temporary runtime, privilege rule, service integration, and state."
