#!/bin/bash
set -uo pipefail

repo="${1:?usage: check-mcp-hygiene.sh <repo>}"

find "$repo" -maxdepth 3 -name ".mcp.json" -not -path "*/node_modules/*" -print0 2>/dev/null | \
while IFS= read -r -d '' f; do
  rel="${f#"$repo"/}"
  jq -r '
    def flatten_and_check:
      if type == "object" then
        to_entries[] |
        (
          if (.key | test("authorization|api_key|token|secret"; "i"))
             and (.value | type == "string")
             and ((.value | test("^\\$\\{[A-Za-z_][A-Za-z0-9_]*\\}$")) | not)
          then .key
          else empty
          end
        ),
        (
          if (.value | type == "string") then
            (.value | try fromjson catch null) as $p |
            if $p != null then ($p | flatten_and_check) else empty end
          else
            (.value | flatten_and_check)
          end
        )
      elif type == "array" then
        .[] | flatten_and_check
      else empty
      end;
    . | flatten_and_check
  ' "$f" 2>/dev/null | while IFS= read -r key; do
    echo "HYGIENE $rel key=$key"
  done
done
