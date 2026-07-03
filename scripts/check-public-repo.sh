#!/bin/bash
set -uo pipefail

repo="${1:?usage: check-public-repo.sh <repo>}"

remote=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
if [ -z "$remote" ]; then
  echo "NO_REMOTE"
  exit 0
fi

case "$remote" in
  *github.com*) ;;
  *) echo "INFO_NOT_GITHUB"; exit 0 ;;
esac

if ! command -v gh >/dev/null 2>&1; then
  echo "INFO_NO_GH"
  exit 0
fi

slug=$(echo "$remote" | sed -E 's#.*github\.com[:/]##; s#\.git$##')
visibility=$(gh repo view "$slug" --json visibility -q .visibility 2>/dev/null || true)

if [ -z "$visibility" ]; then
  echo "INFO_NO_GH"
  exit 0
fi

echo "$visibility" | tr '[:lower:]' '[:upper:]'
