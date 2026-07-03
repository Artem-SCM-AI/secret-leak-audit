#!/bin/bash
# Usage: redact_line "some line containing a-secret-looking-token-here"
# Replaces any run of 12+ [A-Za-z0-9_-] characters with a length-tagged
# placeholder. Sourced by check scripts; never called with the raw secret
# value printed to stdout/stderr by the caller first.
redact_line() {
  local line="$1"
  echo "$line" | sed -E 's/[A-Za-z0-9_-]{12,}/<REDACTED-&LEN>/g' | \
    perl -pe 's/<REDACTED-([A-Za-z0-9_-]{12,})LEN>/"<".length($1)."-char-redacted>"/ge' 2>/dev/null || \
  echo "$line" | sed -E 's/[A-Za-z0-9_-]{12,}/<redacted>/g'
}
