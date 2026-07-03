#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

# Real gitleaks should already be present on the dev/CI machine for the
# rest of the suite to work at all, so --check-only should succeed here.
out=$(bash scripts/bootstrap-gitleaks.sh --check-only)
status=$?
if [ $status -ne 0 ]; then
  echo "FAIL: --check-only exited non-zero with gitleaks present on PATH: $out"
  exit 1
fi
if ! echo "$out" | grep -q "^GITLEAKS_OK"; then
  echo "FAIL: expected GITLEAKS_OK line, got: $out"
  exit 1
fi

# Simulate gitleaks missing by hiding PATH.
out2=$(PATH="/usr/bin:/bin" bash scripts/bootstrap-gitleaks.sh --check-only 2>&1)
status2=$?
if [ $status2 -eq 0 ]; then
  echo "FAIL: --check-only should exit non-zero when gitleaks is not on PATH"
  exit 1
fi
if ! echo "$out2" | grep -q "GITLEAKS_MISSING"; then
  echo "FAIL: expected GITLEAKS_MISSING, got: $out2"
  exit 1
fi

echo "PASS: test-bootstrap-gitleaks.sh"
