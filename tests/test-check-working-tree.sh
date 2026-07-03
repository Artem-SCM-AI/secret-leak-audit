#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

# No suffix after the X-run: BSD mktemp (stock macOS) only randomizes a
# trailing X-run — see scripts/check-tracked-history.sh for the full
# writeup of the bug this avoids.
cfg=$(mktemp "${TMPDIR:-/tmp}/sla-cfg.XXXXXX")
cat > "$cfg" << 'EOF'
[[rules]]
id = "test-token"
description = "Test Token"
regex = '''TESTTOKEN_[A-Za-z0-9]{20,}'''
tags = ["test"]
EOF

repo=$(make_test_repo)
seed_history_secret "$repo" "readme.txt" "clean file, committed"
seed_working_tree_file "$repo" ".env" "SECRET=TESTTOKEN_abcdefghijklmnopqrstuvwxyz"

out=$(bash scripts/check-working-tree.sh "$repo" "$cfg")

if ! echo "$out" | grep -q "^HIT"; then
  echo "FAIL: expected a HIT for the untracked .env file, got: $out"
  cleanup_test_repo "$repo"; rm -f "$cfg"
  exit 1
fi
if echo "$out" | grep -q "TESTTOKEN_abcdefghijklmnopqrstuvwxyz"; then
  echo "FAIL: raw secret value leaked into output: $out"
  cleanup_test_repo "$repo"; rm -f "$cfg"
  exit 1
fi
if ! echo "$out" | grep -q "\.env"; then
  echo "FAIL: expected .env in output, got: $out"
  cleanup_test_repo "$repo"; rm -f "$cfg"
  exit 1
fi

cleanup_test_repo "$repo"; rm -f "$cfg"
echo "PASS: test-check-working-tree.sh"
