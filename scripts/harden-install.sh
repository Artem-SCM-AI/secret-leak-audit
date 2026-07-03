#!/bin/bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_home="${HOME:?HOME must be set}"

# --- ~/.gitleaks.toml ---
if [ -f "$target_home/.gitleaks.toml" ]; then
  echo "TOML_PRESERVED_EXISTING"
  echo "  Your existing ~/.gitleaks.toml was left untouched."
  echo "  Recommended ruleset for manual reference: $here/config/default-gitleaks.toml"
else
  cp "$here/config/default-gitleaks.toml" "$target_home/.gitleaks.toml"
  echo "TOML_INSTALLED"
fi

# --- ~/.git-hooks/pre-commit ---
mkdir -p "$target_home/.git-hooks"
if [ -f "$target_home/.git-hooks/pre-commit" ]; then
  echo "HOOK_PRESERVED_EXISTING"
  echo "  Your existing ~/.git-hooks/pre-commit was left untouched."
  echo "  Add this line to it manually to get gitleaks protection:"
  echo "    gitleaks git --staged --no-banner --config ~/.gitleaks.toml || exit 1"
else
  cp "$here/hooks/pre-commit" "$target_home/.git-hooks/pre-commit"
  chmod +x "$target_home/.git-hooks/pre-commit"
  echo "HOOK_INSTALLED"
fi

# --- core.hooksPath (global) ---
existing_hp=$(git config --global --get core.hooksPath 2>/dev/null || true)
if [ -n "$existing_hp" ] && [ "$existing_hp" != "$target_home/.git-hooks" ]; then
  echo "HOOKSPATH_PRESERVED_EXISTING=$existing_hp"
  echo "  Your global core.hooksPath already points elsewhere. Not overriding it."
  echo "  Add the gitleaks line above to whatever pre-commit hook lives there instead."
elif [ -z "$existing_hp" ]; then
  git config --global core.hooksPath "$target_home/.git-hooks"
  echo "HOOKSPATH_SET"
else
  echo "HOOKSPATH_PRESERVED_EXISTING=$existing_hp"
fi
