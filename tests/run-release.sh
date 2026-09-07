#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
tests/run-check.sh
if command -v plutil >/dev/null 2>&1; then plutil -lint macos/com.agent-temporary.expire.plist macos/com.agent-temporary.boot.plist >/dev/null; fi
CACHE=$(mktemp -d /tmp/agent-temporary-release-cache.XXXXXX)
trap 'rm -rf "$CACHE"' EXIT HUP INT TERM
NPM_CONFIG_CACHE="$CACHE" ./release.sh >/dev/null
shasum -a 256 dist/agent-temporary-0.7.3.zip >"$CACHE/zip.sha256"
cmp -s "$CACHE/zip.sha256" dist/agent-temporary-0.7.3.zip.sha256
unzip -tq dist/agent-temporary-0.7.3.zip
tar -tzf dist/agent-temporary-0.7.3.tgz | grep -qx 'package/payload/install.sh'
sh tests/test_bootstrap.sh >/dev/null
echo 'release validation: PASS'
