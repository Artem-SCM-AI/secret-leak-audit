#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

# No remote at all.
repo=$(make_test_repo)
out=$(bash scripts/check-public-repo.sh "$repo")
if [ "$out" != "NO_REMOTE" ]; then
  echo "FAIL: expected NO_REMOTE, got: $out"
  cleanup_test_repo "$repo"
  exit 1
fi
cleanup_test_repo "$repo"

# Non-GitHub remote.
repo2=$(make_test_repo)
git -C "$repo2" remote add origin "https://gitlab.com/someone/somewhere.git"
out2=$(bash scripts/check-public-repo.sh "$repo2")
if [ "$out2" != "INFO_NOT_GITHUB" ]; then
  echo "FAIL: expected INFO_NOT_GITHUB, got: $out2"
  cleanup_test_repo "$repo2"
  exit 1
fi
cleanup_test_repo "$repo2"

# gh unavailable — simulate by hiding it from PATH.
repo3=$(make_test_repo)
git -C "$repo3" remote add origin "https://github.com/example/example.git"
out3=$(PATH="/usr/bin:/bin" bash scripts/check-public-repo.sh "$repo3")
if [ "$out3" != "INFO_NO_GH" ]; then
  echo "FAIL: expected INFO_NO_GH when gh is missing, got: $out3"
  cleanup_test_repo "$repo3"
  exit 1
fi
cleanup_test_repo "$repo3"

echo "PASS: test-check-public-repo.sh"
