#!/bin/bash
set -uo pipefail

repo="${1:?usage: check-gitignore-coverage.sh <repo>}"

patterns=(".env" ".env.*" "credentials.json" "secrets.json" "service-account.json" \
          "token.json" "*.pem" "*.p12" "id_rsa" "id_ed25519")

for pat in "${patterns[@]}"; do
  while IFS= read -r -d '' f; do
    rel="${f#"$repo"/}"
    tracked=$(git -C "$repo" ls-files --error-unmatch "$rel" >/dev/null 2>&1 && echo yes || echo no)

    # For tracked files, git check-ignore won't report them as ignored.
    # So we check if the file's basename would be ignored by testing it in a hypothetical path.
    if [ "$tracked" = "yes" ]; then
      basename=$(basename "$rel")
      # Check if this basename would be ignored if it appeared in a subdirectory
      ignored=$(git -C "$repo" check-ignore -q "hypothetical-path/$basename" 2>/dev/null && echo yes || echo no)
    else
      ignored=$(git -C "$repo" check-ignore -q "$rel" 2>/dev/null && echo yes || echo no)
    fi

    if [ "$tracked" = "yes" ] && [ "$ignored" = "yes" ]; then
      echo "TRACKED_DESPITE_IGNORE $rel"
    elif [ "$tracked" = "no" ] && [ "$ignored" = "no" ]; then
      echo "UNPROTECTED $rel"
    fi
  done < <(find "$repo" -maxdepth 3 -name "$pat" -not -path "*/.git/*" -print0 2>/dev/null)
done
