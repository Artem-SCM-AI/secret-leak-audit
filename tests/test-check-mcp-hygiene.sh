#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/test-helpers.sh

repo=$(make_test_repo)
mkdir -p "$repo"
cat > "$repo/.mcp.json" << 'EOF'
{
  "example": {
    "command": "npx",
    "env": {
      "OPENAPI_MCP_HEADERS": "{\"Authorization\": \"Bearer some-inline-literal-value\"}",
      "SAFE_TOKEN": "${MY_ENV_VAR}"
    }
  }
}
EOF

out=$(bash scripts/check-mcp-hygiene.sh "$repo")
if ! echo "$out" | grep -q "^HYGIENE .mcp.json"; then
  echo "FAIL: expected a HYGIENE finding for the inline Authorization literal, got: $out"
  cleanup_test_repo "$repo"
  exit 1
fi
if echo "$out" | grep -q "some-inline-literal-value"; then
  echo "FAIL: raw value leaked into output: $out"
  cleanup_test_repo "$repo"
  exit 1
fi
if echo "$out" | grep -q "SAFE_TOKEN"; then
  echo "FAIL: SAFE_TOKEN uses \${...} correctly and should not be flagged: $out"
  cleanup_test_repo "$repo"
  exit 1
fi

cleanup_test_repo "$repo"
echo "PASS: test-check-mcp-hygiene.sh"
