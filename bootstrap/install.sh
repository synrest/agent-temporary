#!/bin/sh
set -eu

VERSION=0.7.1
REPOSITORY=synrest/agent-temporary
BASE_URL=https://github.com/$REPOSITORY/releases/download/v$VERSION
ARCHIVE_NAME=agent-temporary-$VERSION.zip

die() { echo "agent-temporary bootstrap: $*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die 'run as the normal user; the canonical installer owns the sudo boundary'
command -v curl >/dev/null 2>&1 || die 'curl is required'
command -v unzip >/dev/null 2>&1 || die 'unzip is required'
command -v shasum >/dev/null 2>&1 || die 'shasum is required'

os=$(uname -s 2>/dev/null || true)
case "$os" in
    Darwin) ;;
    Linux)
        if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            :
        elif [ -e /run/openrc/softlevel ] && command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
            :
        else
            die 'Linux systemd or OpenRC is not active'
        fi
        ;;
    *) die "unsupported platform: $os" ;;
esac

tmp=$(mktemp -d "${TMPDIR:-/tmp}/agent-temporary-bootstrap.XXXXXX") || die 'cannot create secure temporary directory'
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT HUP INT TERM
archive=$tmp/$ARCHIVE_NAME
checksum_file=$tmp/$ARCHIVE_NAME.sha256
extract=$tmp/extracted
mkdir "$extract"

curl -fsSL "$BASE_URL/$ARCHIVE_NAME" -o "$archive" || die 'release download failed'
curl -fsSL "$BASE_URL/$ARCHIVE_NAME.sha256" -o "$checksum_file" || die 'release checksum download failed'

checksum=$(awk 'NR == 1 && NF == 2 { print $1 } NR != 1 || NF != 2 { bad=1 } END { if (NR != 1 || bad) exit 1 }' "$checksum_file") || die 'malformed release checksum'
case "$checksum" in
    ''|*[!0123456789abcdef]*) die 'malformed release checksum' ;;
esac
[ "${#checksum}" -eq 64 ] || die 'malformed release checksum'
actual=$(shasum -a 256 "$archive" | awk '{print $1}')
[ "$actual" = "$checksum" ] || die 'release checksum mismatch'

unzip -q "$archive" -d "$extract" || die 'cannot unpack release archive'
release_dir=$(find "$extract" -type f -name agent-temporary -print | sed -n '1p')
[ -n "$release_dir" ] || die 'release archive is missing the canonical installer payload'
release_dir=$(dirname "$release_dir")
install_script=$release_dir/install.sh
[ -f "$install_script" ] || die 'release archive is missing install.sh'
[ "$(cat "$release_dir/VERSION" 2>/dev/null || true)" = "$VERSION" ] || die 'release version mismatch'

echo "Installing agent-temporary $VERSION system components."
echo 'The canonical installer will request administrator privileges; temporary access remains inactive.'
sh "$install_script" "$@"
