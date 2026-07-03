#!/bin/bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/redact.sh"

repo="${1:?usage: check-tracked-history.sh <repo> <gitleaks-config> [timeout-seconds]}"
cfg="${2:?usage: check-tracked-history.sh <repo> <gitleaks-config> [timeout-seconds]}"
timeout_secs="${3:-60}"

# No suffix after the X-run: BSD mktemp (stock macOS) only randomizes a
# trailing X-run — a suffix like ".json" after it makes mktemp return the
# literal template path unrandomized every time, so concurrent invocations
# collide ("File exists"), mktemp fails, and — since nothing checked the
# failure — the script used to silently report a clean scan for a repo that
# actually had a secret. gitleaks doesn't care that the path lacks a .json
# extension; --report-format json controls the content, not the path.
report=$(mktemp "${TMPDIR:-/tmp}/sla-report.XXXXXX")
if [ -z "$report" ] || [ ! -f "$report" ]; then
  echo "ERROR: mktemp failed to create a report file" >&2
  exit 1
fi

# Portable timeout (no dependency on GNU coreutils' `timeout`, which stock
# macOS doesn't ship): run gitleaks in the background, race it against a
# watcher that kills it after $timeout_secs. `set -m` puts each backgrounded
# job in its own process group so the kills below (negative PID = kill the
# whole group) reap the work/watcher process *and* any children it spawned
# (gitleaks subprocesses, the watcher's own `sleep`), instead of leaving
# them as orphans reparented to pid 1.
set -m
gitleaks git "$repo" --config "$cfg" --no-banner --report-format json --report-path "$report" >/dev/null 2>&1 &
work_pid=$!
( sleep "$timeout_secs" && kill -KILL -- "-$work_pid" 2>/dev/null ) &
watcher_pid=$!
wait "$work_pid" 2>/dev/null
work_status=$?
kill -TERM -- "-$watcher_pid" 2>/dev/null
wait "$watcher_pid" 2>/dev/null
set +m

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
