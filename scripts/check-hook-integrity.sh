#!/bin/bash
set -uo pipefail

repo="${1:?usage: check-hook-integrity.sh <repo>}"

local_hp=$(git -C "$repo" config --local --get core.hooksPath 2>/dev/null || true)
global_hp=$(git -C "$repo" config --global --get core.hooksPath 2>/dev/null || true)

if [ -n "$local_hp" ] && [ -n "$global_hp" ] && [ "$local_hp" != "$global_hp" ]; then
  echo "SHADOW_OVERRIDE local=$local_hp global=$global_hp"
  exit 0
fi

if [ -z "$global_hp" ] && [ -z "$local_hp" ]; then
  echo "NO_GLOBAL_HOOK"
  exit 0
fi

echo "OK"
