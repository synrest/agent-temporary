#!/bin/sh
set -eu

REPOSITORY=synrest/agent-temporary
RELEASE_BASE_URL=https://github.com/$REPOSITORY/releases

die() { echo "agent-temporary bootstrap: $*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die 'run as the normal user; the canonical installer owns the sudo boundary'
command -v curl >/dev/null 2>&1 || die 'curl is required'
command -v unzip >/dev/null 2>&1 || die 'unzip is required'
command -v mktemp >/dev/null 2>&1 || die 'mktemp is required'
command -v find >/dev/null 2>&1 || die 'find is required'

os=$(uname -s 2>/dev/null || true)
case "$os" in
    Darwin)
        command -v shasum >/dev/null 2>&1 || die 'shasum is required on macOS'
        checksum() { shasum -a 256 "$1" | awk '{print $1}'; }
        ;;
    Linux)
        if command -v systemctl >/dev/null 2>&1 && { [ -d /run/systemd/system ] || systemctl show-environment >/dev/null 2>&1; }; then
            :
        elif [ -e /run/openrc/softlevel ] && command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
            :
        else
            die 'Linux systemd or OpenRC is not active'
        fi
        if command -v sha256sum >/dev/null 2>&1; then
            checksum() { sha256sum "$1" | awk '{print $1}'; }
        elif command -v shasum >/dev/null 2>&1; then
            checksum() { shasum -a 256 "$1" | awk '{print $1}'; }
        else
            die 'sha256sum or shasum is required on Linux'
        fi
        ;;
    *) die "unsupported platform: $os" ;;
esac

latest_url=$(curl -fsSL -o /dev/null -w '%{url_effective}\n' "$RELEASE_BASE_URL/latest") || die 'release lookup failed'
tag=$(printf '%s\n' "$latest_url" | sed -n 's#^.*/releases/tag/\(v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$#\1#p')
[ -n "$tag" ] || die 'latest release metadata did not contain a valid semantic version'
version=${tag#v}
archive_name=agent-temporary-$version.zip

tmp=$(mktemp -d "${TMPDIR:-/tmp}/agent-temporary-bootstrap.XXXXXX") || die 'cannot create secure temporary directory'
chmod 700 "$tmp" 2>/dev/null || true
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT HUP INT TERM
archive=$tmp/$archive_name
checksum_file=$tmp/$archive_name.sha256
extract=$tmp/extracted
mkdir "$extract"

curl -fsSL "$RELEASE_BASE_URL/download/$tag/$archive_name" -o "$archive" || die 'release download failed'
curl -fsSL "$RELEASE_BASE_URL/download/$tag/$archive_name.sha256" -o "$checksum_file" || die 'release checksum download failed'
checksum_line=$(cat "$checksum_file") || die 'cannot read release checksum'
checksum=$(printf '%s\n' "$checksum_line" | awk 'NR == 1 && NF == 2 { print $1 } NR != 1 || NF != 2 { bad=1 } END { if (NR != 1 || bad) exit 1 }') || die 'malformed release checksum'
case "$checksum" in
    ''|*[!0123456789abcdef]*) die 'malformed release checksum' ;;
esac
[ "${#checksum}" -eq 64 ] || die 'malformed release checksum'
[ "$(checksum "$archive")" = "$checksum" ] || die 'release checksum mismatch'

unzip -q "$archive" -d "$extract" || die 'cannot unpack release archive'
release_dir=$(find "$extract" -type f -name agent-temporary -print | sed -n '1p')
[ -n "$release_dir" ] || die 'release archive is missing the canonical installer payload'
release_dir=$(dirname "$release_dir")
install_script=$release_dir/install.sh
[ -f "$install_script" ] || die 'release archive is missing install.sh'
[ "$(cat "$release_dir/VERSION" 2>/dev/null || true)" = "$version" ] || die 'release version mismatch'

echo "Installing agent-temporary $version system components."
echo 'The canonical installer will request administrator privileges; temporary access remains inactive.'
sh "$install_script" "$@"
