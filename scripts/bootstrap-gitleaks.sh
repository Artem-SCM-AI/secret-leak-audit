#!/bin/bash
set -uo pipefail

check_only=false
[ "${1:-}" = "--check-only" ] && check_only=true

if command -v gitleaks >/dev/null 2>&1; then
  echo "GITLEAKS_OK $(gitleaks version 2>/dev/null | head -1)"
  exit 0
fi

if $check_only; then
  echo "GITLEAKS_MISSING"
  exit 1
fi

os="$(uname -s)"
case "$os" in
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      echo "gitleaks not found — installing via Homebrew..."
      brew install gitleaks
      if command -v gitleaks >/dev/null 2>&1; then
        echo "GITLEAKS_OK $(gitleaks version 2>/dev/null | head -1)"
        exit 0
      fi
    fi
    echo "GITLEAKS_MISSING — install manually: brew install gitleaks"
    exit 1
    ;;
  Linux)
    echo "GITLEAKS_MISSING — no automatic installer for Linux in v1."
    echo "Install manually: https://github.com/gitleaks/gitleaks/releases"
    echo "(download the binary for your architecture, place it on PATH)"
    exit 1
    ;;
  *)
    echo "GITLEAKS_MISSING — unsupported OS for auto-install ($os)."
    echo "Install manually: https://github.com/gitleaks/gitleaks/releases"
    exit 1
    ;;
esac
