#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

cfg=$(mktemp "${TMPDIR:-/tmp}/sla-cfg.XXXXXX")
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

# Regression test: concurrent invocations against different repos must not
# collide on their report tmpfile (BSD mktemp only randomizes a trailing
# X-run; a template ending in a suffix like ".json" used to make mktemp
# return the same literal path every time, so parallel scans would race,
# one would fail with "File exists", and a repo with a real secret would
# silently report nothing — indistinguishable from a clean repo).
cfg4=$(mktemp "${TMPDIR:-/tmp}/sla-cfg4.XXXXXX")
cat > "$cfg4" << 'EOF'
[[rules]]
id = "test-token"
description = "Test Token"
regex = '''TESTTOKEN_[A-Za-z0-9]{20,}'''
tags = ["test"]
EOF
repoA=$(make_test_repo)
seed_history_secret "$repoA" "a.txt" "api_key=TESTTOKEN_abcdefghijklmnopqrstuvwxyzAAAA"
repoB=$(make_test_repo)
seed_history_secret "$repoB" "b.txt" "api_key=TESTTOKEN_abcdefghijklmnopqrstuvwxyzBBBB"

concurrent_fail=0
for i in 1 2 3 4 5; do
  bash scripts/check-tracked-history.sh "$repoA" "$cfg4" > "${TMPDIR:-/tmp}/sla-concurrent-a-$i.out" 2>&1 &
  bash scripts/check-tracked-history.sh "$repoB" "$cfg4" > "${TMPDIR:-/tmp}/sla-concurrent-b-$i.out" 2>&1 &
done
wait

for i in 1 2 3 4 5; do
  a_out=$(cat "${TMPDIR:-/tmp}/sla-concurrent-a-$i.out")
  b_out=$(cat "${TMPDIR:-/tmp}/sla-concurrent-b-$i.out")
  if ! echo "$a_out" | grep -q "^HIT.*a\.txt"; then
    echo "FAIL: concurrent run $i against repoA expected a HIT for a.txt, got: $a_out"
    concurrent_fail=1
  fi
  if ! echo "$b_out" | grep -q "^HIT.*b\.txt"; then
    echo "FAIL: concurrent run $i against repoB expected a HIT for b.txt, got: $b_out"
    concurrent_fail=1
  fi
  rm -f "${TMPDIR:-/tmp}/sla-concurrent-a-$i.out" "${TMPDIR:-/tmp}/sla-concurrent-b-$i.out"
done

cleanup_test_repo "$repoA"; cleanup_test_repo "$repoB"; rm -f "$cfg4"

if [ "$concurrent_fail" -ne 0 ]; then
  rm -f "$cfg"
  exit 1
fi

rm -f "$cfg"
echo "PASS: test-check-tracked-history.sh"
