#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

cfg=$(mktemp "${TMPDIR:-/tmp}/sla-cfg.XXXXXX.toml")
cat > "$cfg" << 'EOF'
[[rules]]
id = "test-token"
description = "Test Token"
regex = '''TESTTOKEN_[A-Za-z0-9]{20,}'''
tags = ["test"]
EOF

repo=$(make_test_repo)
seed_history_secret "$repo" "config.txt" "api_key=TESTTOKEN_abcdefghijklmnopqrstuvwxyz"

out=$(bash scripts/check-tracked-history.sh "$repo" "$cfg")

if ! echo "$out" | grep -q "^HIT"; then
  echo "FAIL: expected a HIT line, got: $out"
  cleanup_test_repo "$repo"; rm -f "$cfg"
  exit 1
fi
if echo "$out" | grep -q "TESTTOKEN_abcdefghijklmnopqrstuvwxyz"; then
  echo "FAIL: raw secret value leaked into output: $out"
  cleanup_test_repo "$repo"; rm -f "$cfg"
  exit 1
fi
if ! echo "$out" | grep -q "config.txt"; then
  echo "FAIL: expected filename in output, got: $out"
  cleanup_test_repo "$repo"; rm -f "$cfg"
  exit 1
fi

# Clean repo — no output expected.
repo2=$(make_test_repo)
seed_history_secret "$repo2" "readme.txt" "nothing sensitive here"
out2=$(bash scripts/check-tracked-history.sh "$repo2" "$cfg")
if [ -n "$out2" ]; then
  echo "FAIL: expected no output for a clean repo, got: $out2"
  cleanup_test_repo "$repo"; cleanup_test_repo "$repo2"; rm -f "$cfg"
  exit 1
fi

cleanup_test_repo "$repo"; cleanup_test_repo "$repo2"; rm -f "$cfg"

# Timeout guard: a script that sleeps longer than the timeout must be
# reported as TIMEOUT rather than hanging the whole audit. Simulated by
# passing a 1-second timeout against a deliberately slow fake "gitleaks"
# shim placed first on PATH.
slowdir=$(mktemp -d "${TMPDIR:-/tmp}/sla-slow.XXXXXX")
cat > "$slowdir/gitleaks" << 'EOF'
#!/bin/bash
sleep 5
EOF
chmod +x "$slowdir/gitleaks"
repo3=$(make_test_repo)
seed_history_secret "$repo3" "readme.txt" "irrelevant"
out3=$(PATH="$slowdir:$PATH" bash scripts/check-tracked-history.sh "$repo3" "$cfg" 1)
if [ "$out3" != "TIMEOUT" ]; then
  echo "FAIL: expected TIMEOUT with a 1s cap against a 5s-sleeping gitleaks, got: $out3"
  cleanup_test_repo "$repo3"; rm -rf "$slowdir"
  exit 1
fi
cleanup_test_repo "$repo3"; rm -rf "$slowdir"

echo "PASS: test-check-tracked-history.sh"
