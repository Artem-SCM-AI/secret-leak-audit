#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

root=$(mktemp -d "${TMPDIR:-/tmp}/sla-discover.XXXXXX")
repoA="$root/project a/repoA"
repoB="$root/repoB"
noisyDir="$root/repoB/node_modules/fake-pkg"
mkdir -p "$repoA" "$repoB" "$noisyDir"
git -C "$repoA" init -q
git -C "$repoB" init -q
git -C "$noisyDir" init -q   # should be pruned, lives under node_modules

found=$(bash scripts/discover-repos.sh "$root")

if ! echo "$found" | grep -qF "$repoA"; then
  echo "FAIL: did not find repoA ($repoA)"
  echo "found: $found"
  rm -rf "$root"
  exit 1
fi
if ! echo "$found" | grep -qF "$repoB"; then
  echo "FAIL: did not find repoB"
  rm -rf "$root"
  exit 1
fi
if echo "$found" | grep -qF "node_modules"; then
  echo "FAIL: discovered a repo inside node_modules — prune failed"
  rm -rf "$root"
  exit 1
fi

count=$(echo "$found" | grep -c .)
if [ "$count" -ne 2 ]; then
  echo "FAIL: expected exactly 2 repos, found $count: $found"
  rm -rf "$root"
  exit 1
fi

# Worktrees, bare repos, and submodules must be excluded — not by special
# casing, but as a natural consequence of matching only a real .git
# *directory*: a linked worktree's .git is a file, a bare repo has no .git
# subdirectory at all, and a submodule's .git is also a file. This proves
# that claim rather than just asserting it.
git -C "$repoA" worktree add "$root/repoA-wt" -b test-wt-branch -q 2>/dev/null || true
git init --bare -q "$root/bare-repo.git"
mkdir -p "$root/repoB/vendored-lib"
echo "gitdir: ../.git/modules/vendored-lib" > "$root/repoB/vendored-lib/.git"

found2=$(bash scripts/discover-repos.sh "$root")
if echo "$found2" | grep -qF "repoA-wt"; then
  echo "FAIL: linked worktree was discovered as its own repo"
  git -C "$repoA" worktree remove "$root/repoA-wt" --force -q 2>/dev/null || true
  rm -rf "$root"
  exit 1
fi
if echo "$found2" | grep -qF "bare-repo.git"; then
  echo "FAIL: bare repo was discovered (it has no .git subdirectory to match)"
  git -C "$repoA" worktree remove "$root/repoA-wt" --force -q 2>/dev/null || true
  rm -rf "$root"
  exit 1
fi
if echo "$found2" | grep -qF "vendored-lib"; then
  echo "FAIL: submodule-shaped path (file .git, not dir) was discovered as its own repo"
  git -C "$repoA" worktree remove "$root/repoA-wt" --force -q 2>/dev/null || true
  rm -rf "$root"
  exit 1
fi
git -C "$repoA" worktree remove "$root/repoA-wt" --force -q 2>/dev/null || true

rm -rf "$root"
echo "PASS: test-discover-repos.sh"
