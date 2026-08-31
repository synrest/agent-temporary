#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/agent-temporary-bootstrap-test.XXXXXX)
server_pid=
trap '[ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true; rm -rf "$TMP"' EXIT HUP INT TERM
FIXTURE=$TMP/fixture
SERVER_ROOT=$TMP/server
SERVER_LOG=$TMP/server.log
WORK=$TMP/work
FAKEBIN=$TMP/bin
LOG=$TMP/bootstrap.log
mkdir -p "$FIXTURE" "$SERVER_ROOT/releases/download/v0.7.1" "$WORK" "$FAKEBIN"
cp "$ROOT/dist/agent-temporary-0.7.1.zip" "$FIXTURE/agent-temporary-0.7.1.zip"
shasum -a 256 "$FIXTURE/agent-temporary-0.7.1.zip" >"$FIXTURE/agent-temporary-0.7.1.zip.sha256"
cp "$FIXTURE/agent-temporary-0.7.1.zip" "$SERVER_ROOT/releases/download/v0.7.1/"
cp "$FIXTURE/agent-temporary-0.7.1.zip.sha256" "$SERVER_ROOT/releases/download/v0.7.1/"
mkdir "$TMP/empty"
: >"$TMP/empty/README"
(cd "$TMP/empty" && zip -q "$FIXTURE/no-installer.zip" README)
shasum -a 256 "$FIXTURE/no-installer.zip" >"$FIXTURE/no-installer.zip.sha256"

cat >"$TMP/server.py" <<'PY'
import http.server
import os
import sys

root = sys.argv[1]
port = int(sys.argv[2])
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/releases/latest":
            self.send_response(302)
            self.send_header("Location", "/releases/tag/v0.7.1")
            self.end_headers()
            return
        if self.path == "/bad/releases/latest":
            self.send_response(302)
            self.send_header("Location", "/releases/tag/not-a-version")
            self.end_headers()
            return
        if self.path in ("/releases/tag/v0.7.1", "/releases/tag/not-a-version"):
            self.send_response(200)
            self.end_headers()
            return
        super().do_GET()
    def log_message(self, fmt, *args):
        with open(os.environ["SERVER_LOG"], "a") as log:
            log.write("%s %s\n" % (self.command, self.path))
os.chdir(root)
http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
SERVER_LOG=$SERVER_LOG python3 "$TMP/server.py" "$SERVER_ROOT" "$PORT" >/dev/null 2>&1 &
server_pid=$!

printf '%s\n' '#!/bin/sh' '[ "${1:-}" = -u ] && { [ "${FAKE_ID_ROOT:-no}" = yes ] && echo 0 || echo 501; exit 0; }' 'exit 0' >"$FAKEBIN/id"
printf '%s\n' '#!/bin/sh' 'echo "${FAKE_UNAME:-Darwin}"' >"$FAKEBIN/uname"
printf '%s\n' '#!/bin/sh' 'if [ "${1:-}" = show-environment ]; then exit 0; fi' 'exit 0' >"$FAKEBIN/systemctl"
printf '%s\n' '#!/bin/sh' 'exec /usr/bin/shasum -a 256 "$@"' >"$FAKEBIN/shasum"
printf '%s\n' '#!/bin/sh' 'exec /usr/bin/shasum -a 256 "$1"' >"$FAKEBIN/sha256sum"
cat >"$FAKEBIN/sh" <<'EOF'
#!/bin/sh
set -eu
case "${1:-}" in
    */install.sh) printf '%s\n' "$*" >>"$FAKE_LOG"; exit 0 ;;
esac
exec /bin/sh "$@"
EOF
chmod 755 "$FAKEBIN"/*

sed "s#^RELEASE_BASE_URL=.*#RELEASE_BASE_URL=http://127.0.0.1:$PORT/releases#" "$ROOT/bootstrap/install.sh" >"$TMP/bootstrap.sh"
chmod 755 "$TMP/bootstrap.sh"
run() {
    env PATH="$FAKEBIN:/usr/bin:/bin" TMPDIR="$WORK" FAKE_LOG="$LOG" SERVER_LOG="$SERVER_LOG" FAKE_UNAME="${FAKE_UNAME:-Darwin}" FAKE_ID_ROOT="${FAKE_ID_ROOT:-no}" "$TMP/bootstrap.sh" "$@"
}

run
grep -q 'GET /releases/latest' "$SERVER_LOG"
grep -q 'GET /releases/download/v0.7.1/agent-temporary-0.7.1.zip' "$SERVER_LOG"
grep -q 'GET /releases/download/v0.7.1/agent-temporary-0.7.1.zip.sha256' "$SERVER_LOG"
grep -q 'agent-temporary-release-0.7.1/install.sh' "$LOG"
[ -z "$(find "$WORK" -mindepth 1 -print -prune)" ]

printf '%064d  agent-temporary-0.7.1.zip\n' 0 >"$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip.sha256"
if run >/dev/null 2>&1; then exit 1; fi
[ -z "$(find "$WORK" -mindepth 1 -print -prune)" ]
cp "$FIXTURE/agent-temporary-0.7.1.zip.sha256" "$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip.sha256"
rm "$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip.sha256"
if run >/dev/null 2>&1; then exit 1; fi
[ -z "$(find "$WORK" -mindepth 1 -print -prune)" ]
cp "$FIXTURE/agent-temporary-0.7.1.zip.sha256" "$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip.sha256"
cp "$FIXTURE/no-installer.zip" "$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip"
cp "$FIXTURE/no-installer.zip.sha256" "$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip.sha256"
if run >/dev/null 2>&1; then exit 1; fi
cp "$FIXTURE/agent-temporary-0.7.1.zip" "$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip"
cp "$FIXTURE/agent-temporary-0.7.1.zip.sha256" "$SERVER_ROOT/releases/download/v0.7.1/agent-temporary-0.7.1.zip.sha256"

sed "s#http://127.0.0.1:$PORT/releases#http://127.0.0.1:$PORT/bad/releases#" "$TMP/bootstrap.sh" >"$TMP/bad-bootstrap.sh"
if env PATH="$FAKEBIN:/usr/bin:/bin" TMPDIR="$WORK" SERVER_LOG="$SERVER_LOG" FAKE_UNAME=Darwin "$TMP/bad-bootstrap.sh" >/dev/null 2>&1; then exit 1; fi
if env PATH="$FAKEBIN:/usr/bin:/bin" TMPDIR="$WORK" SERVER_LOG="$SERVER_LOG" FAKE_UNAME=FreeBSD "$TMP/bootstrap.sh" >/dev/null 2>&1; then exit 1; fi
if env PATH="$FAKEBIN:/usr/bin:/bin" TMPDIR="$WORK" SERVER_LOG="$SERVER_LOG" FAKE_UNAME=Darwin FAKE_ID_ROOT=yes "$TMP/bootstrap.sh" >/dev/null 2>&1; then exit 1; fi
FAKE_UNAME=Linux run
grep -q 'agent-temporary-release-0.7.1/install.sh' "$LOG"

echo 'bootstrap tests: PASS'
