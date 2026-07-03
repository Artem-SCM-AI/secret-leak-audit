#!/bin/bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_home="${HOME:?HOME must be set}"

# Fail-fast: if any write operation fails, report it clearly and stop rather
# than continuing to attempt (and possibly falsely report success for) the
# remaining targets. A user relying on this installer's printed output to
# confirm protection is active must never see a false *_INSTALLED/*_SET.

# --- ~/.gitleaks.toml ---
if [ -f "$target_home/.gitleaks.toml" ]; then
  echo "TOML_PRESERVED_EXISTING"
  echo "  Your existing ~/.gitleaks.toml was left untouched."
  echo "  Recommended ruleset for manual reference: $here/config/default-gitleaks.toml"
else
  if ! err=$(cp "$here/config/default-gitleaks.toml" "$target_home/.gitleaks.toml" 2>&1); then
    echo "TOML_INSTALL_FAILED: $err" >&2
    exit 1
  fi
  echo "TOML_INSTALLED"
fi

# --- ~/.git-hooks/pre-commit ---
if ! err=$(mkdir -p "$target_home/.git-hooks" 2>&1); then
  echo "HOOK_INSTALL_FAILED: $err" >&2
  exit 1
fi
if [ -f "$target_home/.git-hooks/pre-commit" ]; then
  echo "HOOK_PRESERVED_EXISTING"
  echo "  Your existing ~/.git-hooks/pre-commit was left untouched."
  echo "  Add this line to it manually to get gitleaks protection:"
  echo "    gitleaks git --staged --no-banner --config ~/.gitleaks.toml || exit 1"
else
  if ! err=$(cp "$here/hooks/pre-commit" "$target_home/.git-hooks/pre-commit" 2>&1); then
    echo "HOOK_INSTALL_FAILED: $err" >&2
    exit 1
  fi
  if ! err=$(chmod +x "$target_home/.git-hooks/pre-commit" 2>&1); then
    echo "HOOK_INSTALL_FAILED: $err" >&2
    exit 1
  fi
  echo "HOOK_INSTALLED"
fi

# --- core.hooksPath (global) ---
existing_hp=$(git config --global --get core.hooksPath 2>/dev/null || true)
if [ -n "$existing_hp" ] && [ "$existing_hp" != "$target_home/.git-hooks" ]; then
  echo "HOOKSPATH_PRESERVED_EXISTING=$existing_hp"
  echo "  Your global core.hooksPath already points elsewhere. Not overriding it."
  echo "  Add the gitleaks line above to whatever pre-commit hook lives there instead."
elif [ -z "$existing_hp" ]; then
  if ! err=$(git config --global core.hooksPath "$target_home/.git-hooks" 2>&1); then
    echo "HOOKSPATH_SET_FAILED: $err" >&2
    exit 1
  fi
  echo "HOOKSPATH_SET"
else
  echo "HOOKSPATH_PRESERVED_EXISTING=$existing_hp"
fi
