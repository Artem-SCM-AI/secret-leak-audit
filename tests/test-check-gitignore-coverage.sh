#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

# Case 1: secret-shaped file present, not gitignored, not tracked -> UNPROTECTED
repo=$(make_test_repo)
seed_working_tree_file "$repo" "credentials.json" '{"type":"fake"}'
out=$(bash scripts/check-gitignore-coverage.sh "$repo")
if ! echo "$out" | grep -q "^UNPROTECTED credentials.json"; then
  echo "FAIL: expected UNPROTECTED credentials.json, got: $out"
  cleanup_test_repo "$repo"
  exit 1
fi
cleanup_test_repo "$repo"

# Case 2: file is gitignored but already tracked -> TRACKED_DESPITE_IGNORE
repo2=$(make_test_repo)
seed_history_secret "$repo2" "credentials.json" '{"type":"fake"}'
echo "credentials.json" >> "$repo2/.gitignore"
git -C "$repo2" add .gitignore
git -C "$repo2" commit --no-verify -q -m "add gitignore"
out2=$(bash scripts/check-gitignore-coverage.sh "$repo2")
if ! echo "$out2" | grep -q "^TRACKED_DESPITE_IGNORE credentials.json"; then
  echo "FAIL: expected TRACKED_DESPITE_IGNORE credentials.json, got: $out2"
  cleanup_test_repo "$repo2"
  exit 1
fi
cleanup_test_repo "$repo2"

echo "PASS: test-check-gitignore-coverage.sh"
