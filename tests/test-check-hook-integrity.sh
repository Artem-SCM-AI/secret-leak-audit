#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

repo=$(make_test_repo)

# Case 1: no local override — should reflect whatever global is (OK or NO_GLOBAL_HOOK,
# both acceptable outcomes here since we don't control the test machine's global config;
# we only assert it's NOT a SHADOW_OVERRIDE).
out1=$(bash scripts/check-hook-integrity.sh "$repo")
if echo "$out1" | grep -q "SHADOW_OVERRIDE"; then
  echo "FAIL: fresh repo with no local override reported as SHADOW_OVERRIDE: $out1"
  cleanup_test_repo "$repo"
  exit 1
fi

# Case 2: set a local override pointing somewhere that differs from global — must detect it.
git -C "$repo" config core.hooksPath "$repo/.git/hooks"
out2=$(bash scripts/check-hook-integrity.sh "$repo")
if ! echo "$out2" | grep -q "SHADOW_OVERRIDE"; then
  echo "FAIL: expected SHADOW_OVERRIDE for local-vs-global mismatch, got: $out2"
  cleanup_test_repo "$repo"
  exit 1
fi

cleanup_test_repo "$repo"
echo "PASS: test-check-hook-integrity.sh"
