#!/bin/sh
set -eu
version=$(sed -n 's/^VERSION=\([^ ]*\)$/\1/p' agent-temporary | head -n 1)
[ -n "$version" ] || { echo 'cannot determine version' >&2; exit 1; }
out="agent-temporary-release-$version"
archive_dir="dist"
archive="$archive_dir/agent-temporary-$version.zip"
rm -rf "$out"
mkdir -p "$archive_dir"
rm -f "$archive" "$archive.sha256"
mkdir -p "$out"
for file in agent-temporary agent-temporary-expire.service agent-temporary-expire.timer agent-temporary-boot.service agent-temporary-boot.openrc agent-temporary-expire.openrc uninstall.sh; do cp "$file" "$out/$file"; done
mkdir -p "$out/macos"
for file in macos/agent-temporary-macos macos/agent-temporary-reaper macos/com.agent-temporary.expire.plist macos/com.agent-temporary.boot.plist; do cp "$file" "$out/$file"; done
printf '%s\n' "$version" > "$out/VERSION"
cat > "$out/install.sh" <<'EOF'
#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec env AGENT_TEMPORARY_RELEASE_DIR="$base" sh "$base/agent-temporary" install "$@"
EOF
chmod 755 "$out/install.sh" "$out/uninstall.sh" "$out/agent-temporary"
(cd "$out" && shasum -a 256 agent-temporary agent-temporary-expire.service agent-temporary-expire.timer agent-temporary-boot.service agent-temporary-boot.openrc agent-temporary-expire.openrc macos/agent-temporary-macos macos/agent-temporary-reaper macos/com.agent-temporary.expire.plist macos/com.agent-temporary.boot.plist VERSION install.sh uninstall.sh > SHA256SUMS)
command -v zip >/dev/null 2>&1 || { echo 'zip is required to build the production archive' >&2; exit 1; }
zip -qr -X "$archive" "$out"
shasum -a 256 "$archive" > "$archive.sha256"
printf '%s\n' "$archive"
