#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/redact.sh

# redact_line's contract is length-based (12+ alphanumeric/_- chars), not
# tied to any specific provider's format, so a generic long token-shaped
# string exercises it without needing a rule-format-accurate literal here.
long_token="EXAMPLE1234567890abcdefghijklmnopQRSTUV"
out=$(redact_line "token=${long_token}")
if echo "$out" | grep -q "$long_token"; then
  echo "FAIL: redact_line leaked the raw secret: $out"
  exit 1
fi
if ! echo "$out" | grep -q "redacted"; then
  echo "FAIL: redact_line did not produce a redacted marker: $out"
  exit 1
fi

short=$(redact_line "short=abc123")
if echo "$short" | grep -q "redacted"; then
  echo "FAIL: redact_line redacted a short non-secret-looking string: $short"
  exit 1
fi

echo "PASS: test-redact.sh"
