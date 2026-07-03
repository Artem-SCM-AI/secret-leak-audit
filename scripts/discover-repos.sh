#!/bin/bash
set -uo pipefail

root="${1:?usage: discover-repos.sh <root-dir>}"

find "$root" \
  \( -name node_modules -o -name venv -o -name .venv -o -name __pycache__ \) -prune -o \
  -type d -name .git -print 2>/dev/null | \
while IFS= read -r gitdir; do
  dirname "$gitdir"
done
