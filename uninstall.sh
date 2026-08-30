#!/bin/sh
set -eu

PREFIX=${PREFIX:-/usr/local/bin}
TARGET=${TARGET:-$PREFIX/agent-temporary}
UNAME=${UNAME:-uname}
OS=$($UNAME -s 2>/dev/null || true)
if [ "$OS" = Darwin ]; then
    RULE=${AGENT_TEMPORARY_RULE:-/etc/sudoers.d/90-agent-temporary}
    LEGACY_RULE=${AGENT_TEMPORARY_LEGACY_RULE:-/etc/sudoers.d/90-temporary-agent}
    STATE_DIR=${AGENT_TEMPORARY_STATE_DIR:-/var/db/agent-temporary}
    [ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
    [ ! -e "$LEGACY_RULE" ] || { echo "Security error: legacy sudoers authority fragment exists at $LEGACY_RULE; inspect and intentionally clean it up before uninstall" >&2; exit 1; }
    [ -x /usr/local/libexec/agent-temporary-macos ] || { [ ! -e "$RULE" ] || { echo "macOS backend is missing; refusing unsafe uninstall" >&2; exit 1; }; }
    if [ -e "$RULE" ] || [ -e "$STATE_DIR/state" ]; then
        /usr/local/libexec/agent-temporary-macos off || { echo "Could not revoke managed macOS authority" >&2; exit 1; }
    fi
    /usr/sbin/visudo -cf /etc/sudoers >/dev/null || { echo "sudoers validation failed after revoke" >&2; exit 1; }
    /bin/launchctl bootout system/com.agent-temporary.expire >/dev/null 2>&1 || true
    /bin/launchctl bootout system/com.agent-temporary.boot >/dev/null 2>&1 || true
    rm -f /Library/LaunchDaemons/com.agent-temporary.expire.plist /Library/LaunchDaemons/com.agent-temporary.boot.plist /usr/local/libexec/agent-temporary-macos /usr/local/libexec/agent-temporary-reaper "$TARGET" /etc/agent-temporary.conf
    rm -rf "$STATE_DIR"
    /usr/sbin/visudo -cf /etc/sudoers >/dev/null || { echo "sudoers validation failed after uninstall" >&2; exit 1; }
    echo "Removed macOS agent-temporary runtime, privilege rule, launchd jobs, and state."
    exit 0
fi
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
