#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/agent-temporary-npm-test.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ARCHIVE=$ROOT/dist/agent-temporary-0.7.1.tgz
[ -f "$ARCHIVE" ] || { echo "missing $ARCHIVE" >&2; exit 1; }
tar -xzf "$ARCHIVE" -C "$TMP"
PKG=$TMP/package
SETUP=$PKG/bin/agent-temporary-setup.js
NODE=$(command -v node)
FAKEBIN=$TMP/bin
LOG=$TMP/sudo.log
VERSION_FILE=$TMP/system-version
mkdir -p "$FAKEBIN"

cat >"$FAKEBIN/agent-temporary" <<'EOF'
#!/bin/sh
set -eu
[ -f "$FAKE_VERSION_FILE" ] || exit 127
version=$(cat "$FAKE_VERSION_FILE")
case "${1:-}" in
    version) echo "agent-temporary $version" ;;
    status) printf 'version=%s\nstate=inactive\neffective_authority=false\n' "$version" ;;
    *) exit 2 ;;
esac
EOF
cat >"$FAKEBIN/sudo" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$FAKE_LOG"
if [ "${1:-}" = sh ]; then
    case "${2:-}" in
        *uninstall.sh) rm -f "$FAKE_VERSION_FILE" ;;
    *) echo 0.7.1 >"$FAKE_VERSION_FILE" ;;
    esac
    exit 0
fi
if [ "${1:-}" = agent-temporary ] && [ "${2:-}" = status ]; then
    printf 'version=0.7.1\nstate=inactive\neffective_authority=false\n'
    exit 0
fi
exit 2
EOF
chmod 755 "$FAKEBIN/agent-temporary" "$FAKEBIN/sudo"

run_setup() {
    env PATH="$FAKEBIN:/usr/bin:/bin" FAKE_LOG="$LOG" FAKE_VERSION_FILE="$VERSION_FILE" "$NODE" "$SETUP" "$@"
}

"$NODE" -e 'const p=require(process.argv[1]); const keys=Object.keys(p.bin||{}); if(keys.length!==1 || keys[0]!=="agent-temporary-setup" || p.bin["agent-temporary"] || p.version!=="0.7.1") process.exit(1)' "$PKG/package.json"
[ "$(cat "$PKG/payload/VERSION")" = 0.7.1 ]
tar -tzf "$ARCHIVE" | grep -qx 'package/payload/macos/agent-temporary-macos'
tar -tzf "$ARCHIVE" | grep -qx 'package/payload/agent-temporary-expire.service'
! tar -tzf "$ARCHIVE" | grep -q 'package/agent-temporary$'
run_setup --help >"$TMP/help"
grep -q 'agent-temporary-setup install' "$TMP/help"
run_setup --version >"$TMP/version"
grep -qx 'agent-temporary-setup 0.7.1' "$TMP/version"
run_setup status >"$TMP/status"
grep -q 'system components=absent/unknown' "$TMP/status"

: >"$LOG"
run_setup install >/dev/null
grep -q 'sh .*payload/install.sh' "$LOG"
grep -q 'agent-temporary status' "$LOG"
run_setup status >"$TMP/status"
grep -q 'installed system version=0.7.1' "$TMP/status"

: >"$LOG"
run_setup update >"$TMP/update"
grep -q 'already current' "$TMP/update"
[ ! -s "$LOG" ]
echo 0.6.0 >"$VERSION_FILE"
: >"$LOG"
run_setup update >/dev/null
grep -q 'sh .*payload/install.sh' "$LOG"
echo 0.8.0 >"$VERSION_FILE"
: >"$LOG"
if run_setup update >/dev/null 2>&1; then exit 1; fi
[ ! -s "$LOG" ]

cp -R "$PKG" "$TMP/tampered"
printf '\ntampered\n' >>"$TMP/tampered/payload/agent-temporary"
: >"$LOG"
if env PATH="$FAKEBIN:/usr/bin:/bin" FAKE_LOG="$LOG" FAKE_VERSION_FILE="$VERSION_FILE" "$NODE" "$TMP/tampered/bin/agent-temporary-setup.js" install >/dev/null 2>&1; then exit 1; fi
[ ! -s "$LOG" ]

postinstall=$(env PATH="$FAKEBIN:/usr/bin:/bin" "$NODE" "$PKG/bin/postinstall.js")
echo "$postinstall" | grep -q 'System components are not installed automatically.'
echo "$postinstall" | grep -q 'agent-temporary-setup install'
! grep -q 'preuninstall\|postuninstall' "$PKG/package.json"
echo 0.7.1 >"$VERSION_FILE"
: >"$LOG"
run_setup uninstall-system >/dev/null
grep -q 'sh .*payload/uninstall.sh' "$LOG"
[ ! -f "$VERSION_FILE" ]
echo 'npm/setup focused tests: PASS'
