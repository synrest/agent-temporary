#!/bin/sh
set -eu
version=$(sed -n 's/^VERSION=\([^ ]*\)$/\1/p' agent-temporary | head -n 1)
[ -n "$version" ] || { echo 'cannot determine version' >&2; exit 1; }
out="agent-temporary-release-$version"
rm -rf "$out"
mkdir -p "$out"
for file in agent-temporary agent-temporary-expire.service agent-temporary-expire.timer agent-temporary-boot.service agent-temporary-boot.openrc agent-temporary-expire.openrc; do cp "$file" "$out/$file"; done
printf '%s\n' "$version" > "$out/VERSION"
cat > "$out/install.sh" <<'EOF'
#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec env AGENT_TEMPORARY_RELEASE_DIR="$base" sh "$base/agent-temporary" install
EOF
chmod 755 "$out/install.sh" "$out/agent-temporary"
(cd "$out" && shasum -a 256 agent-temporary agent-temporary-expire.service agent-temporary-expire.timer agent-temporary-boot.service VERSION install.sh > SHA256SUMS)
printf '%s\n' "$out"
