#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
tests/run-fast.sh
TMP=$(mktemp -d /tmp/agent-temporary-check.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
if sh tests/test_npm.sh >"$TMP/npm.log" 2>&1; then echo 'npm: PASS'; else cat "$TMP/npm.log"; exit 1; fi
