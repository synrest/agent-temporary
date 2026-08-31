#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/agent-temporary-bootstrap-test.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
FIXTURE=$TMP/fixture
WORK=$TMP/work
FAKEBIN=$TMP/bin
LOG=$TMP/log
mkdir -p "$FIXTURE" "$WORK" "$FAKEBIN"
cp "$ROOT/dist/agent-temporary-0.7.1.zip" "$FIXTURE/agent-temporary-0.7.1.zip"
shasum -a 256 "$FIXTURE/agent-temporary-0.7.1.zip" >"$FIXTURE/agent-temporary-0.7.1.zip.sha256"
mkdir "$TMP/empty"
(cd "$TMP/empty" && : > README)
(cd "$TMP/empty" && zip -q "$FIXTURE/no-installer.zip" README)
shasum -a 256 "$FIXTURE/no-installer.zip" >"$FIXTURE/no-installer.zip.sha256"

printf '%s\n' '#!/bin/sh' '[ "${1:-}" = -u ] && { echo 501; exit 0; }' 'exit 0' >"$FAKEBIN/id"
printf '%s\n' '#!/bin/sh' 'echo "${FAKE_UNAME:-Darwin}"' >"$FAKEBIN/uname"
cat >"$FAKEBIN/curl" <<'EOF'
#!/bin/sh
set -eu
printf 'curl %s\n' "$*" >>"$FAKE_LOG"
previous=
out=
for arg in "$@"; do
    [ "$previous" = -o ] && out=$arg
    previous=$arg
done
[ -n "$out" ]
case "${FAKE_CURL_MODE:-ok}:$out" in
    missing:*.sha256) exit 22 ;;
    no-installer:*.zip) cp "$FAKE_FIXTURE/no-installer.zip" "$out" ;;
    no-installer:*.sha256) cp "$FAKE_FIXTURE/no-installer.zip.sha256" "$out" ;;
    *.sha256) cp "$FAKE_FIXTURE/agent-temporary-0.7.1.zip.sha256" "$out" ;;
    *) cp "$FAKE_FIXTURE/agent-temporary-0.7.1.zip" "$out" ;;
esac
EOF
cat >"$FAKEBIN/sh" <<'EOF'
#!/bin/sh
set -eu
case "${1:-}" in
    */install.sh) printf '%s\n' "$*" >>"$FAKE_LOG"; exit 0 ;;
esac
exec /bin/sh "$@"
EOF
chmod 755 "$FAKEBIN/id" "$FAKEBIN/uname" "$FAKEBIN/curl" "$FAKEBIN/sh"

run() {
    env PATH="$FAKEBIN:/usr/bin:/bin" TMPDIR="$WORK" FAKE_FIXTURE="$FIXTURE" FAKE_LOG="$LOG" FAKE_CURL_MODE="${FAKE_CURL_MODE:-ok}" "$ROOT/bootstrap/install.sh" "$@"
}

run
grep -q 'releases/download/v0.7.1/agent-temporary-0.7.1.zip' "$LOG"
grep -q 'agent-temporary-release-0.7.1/install.sh' "$LOG"
[ -z "$(find "$WORK" -mindepth 1 -print -prune)" ]

printf '%064d  agent-temporary-0.7.1.zip\n' 0 >"$FIXTURE/agent-temporary-0.7.1.zip.sha256"
if run >/dev/null 2>&1; then exit 1; fi
[ -z "$(find "$WORK" -mindepth 1 -print -prune)" ]
shasum -a 256 "$FIXTURE/agent-temporary-0.7.1.zip" >"$FIXTURE/agent-temporary-0.7.1.zip.sha256"
FAKE_CURL_MODE=missing run >/dev/null 2>&1 && exit 1 || true
[ -z "$(find "$WORK" -mindepth 1 -print -prune)" ]
FAKE_CURL_MODE=no-installer run >/dev/null 2>&1 && exit 1 || true
[ -z "$(find "$WORK" -mindepth 1 -print -prune)" ]

if env PATH="$FAKEBIN:/usr/bin:/bin" TMPDIR="$WORK" FAKE_FIXTURE="$FIXTURE" FAKE_LOG="$LOG" FAKE_UNAME=FreeBSD "$ROOT/bootstrap/install.sh" >/dev/null 2>&1; then exit 1; fi

echo 'bootstrap tests: PASS'
