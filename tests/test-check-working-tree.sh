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

[[rules]]
id = "aws-access-key"
description = "AWS Access Key (test copy, real rule id length: 14 chars)"
regex = '''AKIA[A-Z0-9]{16}'''
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

# Regression: a rule ID of 12+ chars must reach the output intact, not get
# mangled by redact_line's generic heuristic (see check-tracked-history.sh's
# matching test for the full writeup — same bug, same fix, both scripts).
repo_aws=$(make_test_repo)
aws_key_prefix="AKIA"
aws_key_suffix="IOSFODNN7EXAMPLE"
seed_working_tree_file "$repo_aws" "settings.py" "AWS_KEY=${aws_key_prefix}${aws_key_suffix}"
out_aws=$(bash scripts/check-working-tree.sh "$repo_aws" "$cfg")
if ! echo "$out_aws" | grep -q "rule=aws-access-key$"; then
  echo "FAIL: expected the rule id 'aws-access-key' intact in output, got: $out_aws"
  cleanup_test_repo "$repo"; cleanup_test_repo "$repo_aws"; rm -f "$cfg"
  exit 1
fi
cleanup_test_repo "$repo_aws"

cleanup_test_repo "$repo"; rm -f "$cfg"
echo "PASS: test-check-working-tree.sh"
