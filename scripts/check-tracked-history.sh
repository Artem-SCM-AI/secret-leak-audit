#!/bin/bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/redact.sh"

repo="${1:?usage: check-tracked-history.sh <repo> <gitleaks-config> [timeout-seconds]}"
cfg="${2:?usage: check-tracked-history.sh <repo> <gitleaks-config> [timeout-seconds]}"
timeout_secs="${3:-60}"

report=$(mktemp "${TMPDIR:-/tmp}/sla-report.XXXXXX.json")

# Portable timeout (no dependency on GNU coreutils' `timeout`, which stock
# macOS doesn't ship): run gitleaks in the background, race it against a
# watcher that kills it after $timeout_secs.
gitleaks git "$repo" --config "$cfg" --no-banner --report-format json --report-path "$report" >/dev/null 2>&1 &
work_pid=$!
( sleep "$timeout_secs" && kill -9 "$work_pid" 2>/dev/null ) &
watcher_pid=$!
wait "$work_pid" 2>/dev/null
work_status=$?
kill "$watcher_pid" 2>/dev/null
wait "$watcher_pid" 2>/dev/null

if [ $work_status -ge 128 ]; then
  echo "TIMEOUT"
  rm -f "$report"
  exit 0
fi

if [ -s "$report" ] && [ "$(cat "$report")" != "[]" ] && [ "$(cat "$report")" != "null" ]; then
  jq -r '.[] | "\(.File):\(.StartLine) rule=\(.RuleID)"' "$report" 2>/dev/null | while IFS= read -r line; do
    redact_line "HIT $line"
  done
fi

rm -f "$report"
