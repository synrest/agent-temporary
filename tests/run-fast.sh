#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
TMP=$(mktemp -d /tmp/agent-temporary-fast.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
sh -n agent-temporary macos/agent-temporary-macos macos/agent-temporary-reaper bootstrap/install.sh release.sh tests/test_*.sh
git diff --check
run_one() { name=$1; shift; ("$@") >"$TMP/$name.log" 2>&1 & }
run_one contract sh tests/test_contract.sh; contract_pid=$!
run_one macos sh tests/test_macos_m2.sh; macos_pid=$!
run_one bootstrap-unit sh tests/test_bootstrap_unit.sh; bootstrap_pid=$!
status=0
for name_pid in 'contract:'"$contract_pid" 'macos:'"$macos_pid" 'bootstrap-unit:'"$bootstrap_pid"; do
    name=${name_pid%%:*}; pid=${name_pid#*:}
    if wait "$pid"; then echo "$name: PASS"; else echo "$name: FAIL"; cat "$TMP/$name.log"; status=1; fi
done
exit "$status"
