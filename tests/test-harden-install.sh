#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

fakehome=$(mktemp -d "${TMPDIR:-/tmp}/sla-home.XXXXXX")

# Case 1: nothing exists yet -> fresh install of all three.
out1=$(HOME="$fakehome" bash scripts/harden-install.sh)
if ! echo "$out1" | grep -q "TOML_INSTALLED"; then
  echo "FAIL: expected TOML_INSTALLED on fresh install, got: $out1"; rm -rf "$fakehome"; exit 1
fi
if ! echo "$out1" | grep -q "HOOK_INSTALLED"; then
  echo "FAIL: expected HOOK_INSTALLED on fresh install, got: $out1"; rm -rf "$fakehome"; exit 1
fi
if ! echo "$out1" | grep -q "HOOKSPATH_SET"; then
  echo "FAIL: expected HOOKSPATH_SET on fresh install, got: $out1"; rm -rf "$fakehome"; exit 1
fi
if [ ! -f "$fakehome/.gitleaks.toml" ]; then
  echo "FAIL: .gitleaks.toml was not actually written"; rm -rf "$fakehome"; exit 1
fi

# Case 2: run again — everything already exists -> must preserve, not overwrite.
echo "MY CUSTOM RULE, DO NOT TOUCH" >> "$fakehome/.gitleaks.toml"
out2=$(HOME="$fakehome" bash scripts/harden-install.sh)
if ! echo "$out2" | grep -q "TOML_PRESERVED_EXISTING"; then
  echo "FAIL: expected TOML_PRESERVED_EXISTING on second run, got: $out2"; rm -rf "$fakehome"; exit 1
fi
if ! grep -q "MY CUSTOM RULE, DO NOT TOUCH" "$fakehome/.gitleaks.toml"; then
  echo "FAIL: existing .gitleaks.toml content was destroyed"; rm -rf "$fakehome"; exit 1
fi
if ! echo "$out2" | grep -q "HOOK_PRESERVED_EXISTING"; then
  echo "FAIL: expected HOOK_PRESERVED_EXISTING on second run, got: $out2"; rm -rf "$fakehome"; exit 1
fi
# On the second run, core.hooksPath was already set by Case 1 to this same
# fakehome's .git-hooks dir — that's a match with its own prior value, not a
# foreign override, so it must report PRESERVED_EXISTING with that exact value.
if ! echo "$out2" | grep -q "HOOKSPATH_PRESERVED_EXISTING=$fakehome/.git-hooks"; then
  echo "FAIL: expected HOOKSPATH_PRESERVED_EXISTING=$fakehome/.git-hooks on second run, got: $out2"; rm -rf "$fakehome"; exit 1
fi

# Case 3: the documented README uninstall steps must actually remove all
# traces. `git config --global` resolves `~` via $HOME, so scoping HOME to
# $fakehome here keeps this fully isolated from the real machine's config.
HOME="$fakehome" git config --global --unset core.hooksPath
rm -f "$fakehome/.git-hooks/pre-commit"

remaining_hp=$(HOME="$fakehome" git config --global --get core.hooksPath 2>/dev/null || true)
if [ -n "$remaining_hp" ]; then
  echo "FAIL: core.hooksPath still set after documented uninstall: $remaining_hp"
  rm -rf "$fakehome"; exit 1
fi
if [ -f "$fakehome/.git-hooks/pre-commit" ]; then
  echo "FAIL: hook file still present after documented uninstall"
  rm -rf "$fakehome"; exit 1
fi

rm -rf "$fakehome"
echo "PASS: test-harden-install.sh"
