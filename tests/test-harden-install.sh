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

# Case 4: $HOME exists but is not writable (e.g. permission-denied) -> the
# script must fail loudly (non-zero exit, *_FAILED message) rather than
# silently reporting success while every write actually failed underneath it.
permhome=$(mktemp -d "${TMPDIR:-/tmp}/sla-perm.XXXXXX")
chmod 555 "$permhome"
out4=$(HOME="$permhome" bash scripts/harden-install.sh 2>&1)
exit4=$?
chmod 755 "$permhome"
if [ "$exit4" -eq 0 ]; then
  echo "FAIL: expected non-zero exit on permission-denied HOME, got exit 0. Output: $out4"
  rm -rf "$permhome"; rm -rf "$fakehome"; exit 1
fi
if ! echo "$out4" | grep -q "TOML_INSTALL_FAILED"; then
  echo "FAIL: expected TOML_INSTALL_FAILED on permission-denied HOME, got: $out4"
  rm -rf "$permhome"; rm -rf "$fakehome"; exit 1
fi
if echo "$out4" | grep -qE "TOML_INSTALLED|HOOK_INSTALLED|HOOKSPATH_SET"; then
  echo "FAIL: script falsely reported success on permission-denied HOME: $out4"
  rm -rf "$permhome"; rm -rf "$fakehome"; exit 1
fi
if [ -f "$permhome/.gitleaks.toml" ]; then
  echo "FAIL: .gitleaks.toml should not exist after a failed write"
  rm -rf "$permhome"; rm -rf "$fakehome"; exit 1
fi
rm -rf "$permhome"

# Case 5: global core.hooksPath is already set to a genuinely foreign
# location (not the one this tool would install) -> the Non-Destructive
# Install Principle requires the script to explain it's pointing elsewhere
# and stop, never overriding it. This is distinct from Case 2, where the
# pre-existing value happened to equal the tool's own target.
foreignhome=$(mktemp -d "${TMPDIR:-/tmp}/sla-foreign.XXXXXX")
foreign_hp="/some/genuinely/foreign/hooks/dir"
HOME="$foreignhome" git config --global core.hooksPath "$foreign_hp"

out5=$(HOME="$foreignhome" bash scripts/harden-install.sh)
if ! echo "$out5" | grep -q "HOOKSPATH_PRESERVED_EXISTING=$foreign_hp"; then
  echo "FAIL: expected HOOKSPATH_PRESERVED_EXISTING=$foreign_hp on foreign hooksPath, got: $out5"
  rm -rf "$foreignhome"; rm -rf "$fakehome"; exit 1
fi

remaining_foreign_hp=$(HOME="$foreignhome" git config --global --get core.hooksPath 2>/dev/null || true)
if [ "$remaining_foreign_hp" != "$foreign_hp" ]; then
  echo "FAIL: foreign core.hooksPath was overwritten. Expected '$foreign_hp', got: '$remaining_foreign_hp'"
  rm -rf "$foreignhome"; rm -rf "$fakehome"; exit 1
fi

rm -rf "$foreignhome"

rm -rf "$fakehome"
echo "PASS: test-harden-install.sh"
