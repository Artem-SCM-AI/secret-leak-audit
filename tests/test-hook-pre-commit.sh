#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

repo=$(make_test_repo)
cfg="$(pwd)/config/default-gitleaks.toml"
hook="$(pwd)/hooks/pre-commit"

# Case 1: staged secret must be blocked. Built from two halves so this
# source file itself never contains a contiguous match (see the same
# pattern used in tests/test-default-gitleaks-toml.sh, Task 10).
key_prefix="sk-ant-api03-"
key_suffix="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"
echo "token=${key_prefix}${key_suffix}" > "$repo/bad.txt"
git -C "$repo" add bad.txt
( cd "$repo" && GITLEAKS_CONFIG="$cfg" bash "$hook" )
status1=$?
if [ $status1 -eq 0 ]; then
  echo "FAIL: hook allowed a commit containing a known secret pattern"
  cleanup_test_repo "$repo"
  exit 1
fi
git -C "$repo" reset -q

# Case 2: clean staged content must be allowed.
echo "nothing sensitive" > "$repo/good.txt"
git -C "$repo" add good.txt
( cd "$repo" && GITLEAKS_CONFIG="$cfg" bash "$hook" )
status2=$?
if [ $status2 -ne 0 ]; then
  echo "FAIL: hook blocked a clean commit"
  cleanup_test_repo "$repo"
  exit 1
fi
git -C "$repo" reset -q

# Case 3: fail-closed — gitleaks config missing entirely must block, not silently pass.
git -C "$repo" add good.txt
( cd "$repo" && GITLEAKS_CONFIG="/nonexistent/path.toml" bash "$hook" )
status3=$?
if [ $status3 -eq 0 ]; then
  echo "FAIL: hook allowed a commit when its own config was missing (should fail closed)"
  cleanup_test_repo "$repo"
  exit 1
fi
git -C "$repo" reset -q

# Case 4: fail-closed — gitleaks binary itself missing must also block, not
# just a broken config. Hide it from PATH entirely.
git -C "$repo" add good.txt
( cd "$repo" && PATH="/usr/bin:/bin" GITLEAKS_CONFIG="$cfg" bash "$hook" )
status4=$?
if [ $status4 -eq 0 ]; then
  echo "FAIL: hook allowed a commit when the gitleaks binary itself was missing (should fail closed)"
  cleanup_test_repo "$repo"
  exit 1
fi

cleanup_test_repo "$repo"
echo "PASS: test-hook-pre-commit.sh"
