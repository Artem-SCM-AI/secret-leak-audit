#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

cfg="config/default-gitleaks.toml"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sla-toml.XXXXXX")

# Built from two halves concatenated at runtime rather than one literal
# string, so this source file itself never contains a byte-for-byte
# contiguous match for any rule it's testing (this file is tracked in a
# repo protected by the very same class of hook this tool installs).
declare -a prefix=(
  "sk-ant-api03-"
  "AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ"
  "123456789:AAExampleTelegramBotTokenValueHere"
  "ghp_abcdefghijklmnopqrstuvwxyz"
  "AKIA"
  "-----BEGIN RSA PRIVATE"
  "secret_abcdefghijklmnopqrstuvwxyz"
  "ntn_FAKEFAKEFAKEFAKEFAKEFAKEFAKE"
  "xoxb-123"
  "Authorization: Bearer abcdefghijklmnop"
  "sk-abcdefghij"
  "sk_live_abcdefghij"
)
declare -a suffix=(
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"
  "abcdefghi"
  "ABC"
  "ABCDEFGHIJ"
  "ABCDEFGHIJKLMNOP"
  " KEY-----"
  "FGHIJKLMNOPQRSTUV"
  "FAKEFAKEFAKEFAKE"
  "4567890-abcdefghijklmnop"
  "qrstuvwxyz123456"
  "ABCDEFGHIJKLMNOP"
  "klmnopqrstuvwx"
)
declare -a samples=()
for idx in "${!prefix[@]}"; do
  samples+=("${prefix[$idx]}${suffix[$idx]}")
done

fail=0
i=0
for s in "${samples[@]}"; do
  i=$((i+1))
  f="$tmp/sample-$i.txt"
  echo "$s" > "$f"
  report="$tmp/report-$i.json"
  gitleaks detect --no-git --source="$f" --config "$cfg" --no-banner \
    --report-format json --report-path "$report" >/dev/null 2>&1
  if [ ! -s "$report" ] || [ "$(cat "$report")" = "[]" ] || [ "$(cat "$report")" = "null" ]; then
    echo "FAIL: rule did not match sample $i: $s"
    fail=1
  fi
done

# False-positive sanity: plain English + code-shaped text with no secrets should not match.
clean="$tmp/clean.txt"
cat > "$clean" << 'EOF'
function calculateTotal(items) {
  return items.reduce((sum, item) => sum + item.price, 0);
}
const userName = "artem";
const isActive = true;
EOF
report_clean="$tmp/report-clean.json"
gitleaks detect --no-git --source="$clean" --config "$cfg" --no-banner \
  --report-format json --report-path "$report_clean" >/dev/null 2>&1
if [ -s "$report_clean" ] && [ "$(cat "$report_clean")" != "[]" ] && [ "$(cat "$report_clean")" != "null" ]; then
  echo "FAIL: false positive on clean sample code"
  fail=1
fi

rm -rf "$tmp"
if [ $fail -eq 0 ]; then
  echo "PASS: test-default-gitleaks-toml.sh"
fi
exit $fail
