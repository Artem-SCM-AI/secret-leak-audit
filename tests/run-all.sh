#!/bin/bash
cd "$(dirname "$0")/.."
fail=0
for t in tests/test-*.sh; do
  [ "$(basename "$t")" = "test-helpers.sh" ] && continue
  echo "── $t ──"
  if ! bash "$t"; then
    echo "❌ $t FAILED"
    fail=1
  fi
done
if [ "$fail" -eq 0 ]; then
  echo ""
  echo "✅ all tests passed"
else
  echo ""
  echo "❌ one or more tests failed"
fi
exit $fail
