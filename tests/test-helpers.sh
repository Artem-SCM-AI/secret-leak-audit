#!/bin/bash
# Shared scaffolding for test-*.sh scripts. Source this, don't execute it.

make_test_repo() {
  local dir
  dir=$(mktemp -d "${TMPDIR:-/tmp}/sla-test.XXXXXX")
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "$dir"
}

# seed_history_secret <repo> <relative-file> <content>
# --no-verify is deliberate: this machine may already have the real global
# gitleaks hook installed, and this is an intentional test fixture, not an
# accidental leak.
seed_history_secret() {
  local repo="$1" file="$2" content="$3"
  mkdir -p "$(dirname "$repo/$file")"
  printf '%s\n' "$content" > "$repo/$file"
  git -C "$repo" add "$file"
  git -C "$repo" commit --no-verify -q -m "seed"
}

seed_working_tree_file() {
  local repo="$1" file="$2" content="$3"
  mkdir -p "$(dirname "$repo/$file")"
  printf '%s\n' "$content" > "$repo/$file"
}

cleanup_test_repo() {
  local repo="$1"
  case "$repo" in
    "${TMPDIR:-/tmp}"*|/tmp/*) rm -rf "$repo" ;;
    *) echo "REFUSING to rm -rf non-temp path: $repo" >&2; return 1 ;;
  esac
}
