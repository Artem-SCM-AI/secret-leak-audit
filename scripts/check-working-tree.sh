#!/bin/bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/redact.sh"

repo="${1:?usage: check-working-tree.sh <repo> <gitleaks-config>}"
cfg="${2:?usage: check-working-tree.sh <repo> <gitleaks-config>}"

git -C "$repo" status --porcelain --untracked-files=all -z 2>/dev/null | \
while IFS= read -r -d '' entry; do
  status="${entry:0:2}"
  file="${entry:3}"
  case "$status" in
    "??")
      full="$repo/$file"
      [ -f "$full" ] || continue
      # No suffix after the X-run: BSD mktemp (stock macOS) only randomizes
      # a trailing X-run — a suffix like ".json" after it makes mktemp
      # return the literal template path unrandomized every time, so
      # concurrent invocations collide ("File exists"), mktemp fails, and —
      # since nothing checked the failure — the script would silently
      # report a clean scan for a file that actually had a secret.
      # gitleaks doesn't care that the path lacks a .json extension;
      # --report-format json controls the content, not the path.
      report=$(mktemp "${TMPDIR:-/tmp}/sla-wt.XXXXXX")
      if [ -z "$report" ] || [ ! -f "$report" ]; then
        echo "ERROR: mktemp failed to create a report file" >&2
        continue
      fi
      gitleaks detect --no-git --source="$full" --config "$cfg" --no-banner \
        --report-format json --report-path "$report" >/dev/null 2>&1
      if [ -s "$report" ] && [ "$(cat "$report")" != "[]" ] && [ "$(cat "$report")" != "null" ]; then
        jq -r --arg f "$file" '.[] | "\($f):\(.StartLine) rule=\(.RuleID)"' "$report" 2>/dev/null | \
        while IFS= read -r line; do
          redact_line "HIT $line"
        done
      fi
      rm -f "$report"
      ;;
  esac
done
