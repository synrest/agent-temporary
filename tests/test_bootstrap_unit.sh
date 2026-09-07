#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/agent-temporary-bootstrap-unit.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
BIN=$TMP/bin; WORK=$TMP/work; LOG=$TMP/log
mkdir -p "$BIN" "$WORK"
cp "$ROOT/dist/agent-temporary-0.7.3.zip" "$TMP/archive.zip"
shasum -a 256 "$TMP/archive.zip" >"$TMP/archive.zip.sha256"
printf '%s\n' '#!/bin/sh' '[ "$1" = -u ] && { echo 501; exit 0; }' 'echo 0' >"$BIN/id"
printf '%s\n' 'echo Darwin' >"$BIN/uname"
printf '%s\n' '#!/bin/sh' 'exec /usr/bin/shasum -a 256 "$@"' >"$BIN/shasum"
printf '%s\n' '#!/bin/sh' 'printf "sudo %s\\n" "$*" >>"$FAKE_LOG"' >"$BIN/sudo"
printf '%s\n' '#!/bin/sh' 'case "$1" in */install.sh) exit 0;; esac; exec /bin/sh "$@"' >"$BIN/sh"
printf '%s\n' '#!/bin/sh' 'exec /usr/bin/unzip "$@"' >"$BIN/unzip"
chmod 755 "$BIN"/*
cat >"$BIN/curl" <<'EOF'
#!/bin/sh
set -eu
out=; url=
while [ "$#" -gt 0 ]; do
    case "$1" in -o) out=$2; shift 2;; -w) shift 2;; http*) url=$1; shift;; *) shift;; esac
done
case "$url" in *latest) printf '%s' 'http://example/releases/tag/v0.7.3';; *zip.sha256) cp "$FAKE_ARCHIVE.sha256" "$out";; *zip) cp "$FAKE_ARCHIVE" "$out";; esac
EOF
chmod 755 "$BIN/curl"
sed "s#^RELEASE_BASE_URL=.*#RELEASE_BASE_URL=http://example/releases#" "$ROOT/bootstrap/install.sh" >"$TMP/bootstrap.sh"
chmod 755 "$TMP/bootstrap.sh"
run() { env PATH="$BIN:/usr/bin:/bin" TMPDIR="$WORK" FAKE_LOG="$LOG" FAKE_ARCHIVE="$TMP/archive.zip" "$TMP/bootstrap.sh"; }
run >/dev/null
[ "$(grep -c '^sudo ' "$LOG")" -eq 1 ]
: >"$LOG"; printf '%064d  agent-temporary-0.7.3.zip\n' 0 >"$TMP/archive.zip.sha256"
if run >/dev/null 2>&1; then exit 1; fi
[ ! -s "$LOG" ]
if env PATH="$BIN:/usr/bin:/bin" TMPDIR="$WORK" FAKE_LOG="$LOG" FAKE_ARCHIVE="$TMP/archive.zip" "$TMP/bootstrap.sh" >/dev/null 2>&1; then exit 1; fi
echo 'bootstrap unit tests: PASS'
