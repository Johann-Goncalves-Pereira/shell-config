#!/usr/bin/env bash
# Homebrew android-platform-tools is quarantined; macOS Gatekeeper blocks adb until cleared.
set -euo pipefail

adb_bin="$(command -v adb 2>/dev/null || true)"
[[ -n "$adb_bin" ]] || exit 0

resolve_real() {
  if [[ -L "$1" ]]; then
    readlink "$1" 2>/dev/null || true
  else
    printf '%s\n' "$1"
  fi
}

real="$(resolve_real "$adb_bin")"
[[ -n "$real" && -e "$real" ]] || exit 0
dir="$(dirname "$real")"
xattr -dr com.apple.quarantine "$dir" 2>/dev/null || true
