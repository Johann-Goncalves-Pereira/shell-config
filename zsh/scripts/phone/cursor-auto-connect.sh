#!/usr/bin/env bash
# Cursor sessionStart: unquarantine adb, ensure phone CLI, warm ADB transport (best-effort).
set -euo pipefail

if [[ -t 0 ]]; then
  cat >/dev/null || true
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
"$script_dir/adb-unquarantine.sh" || true

phone_src="${PHONE_CLI_SRC:-$HOME/.shell-config/zsh/scripts/phone}"
bin="$phone_src/target/release/phone"
export CARGO_HOME="${CARGO_HOME:-$phone_src/.cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$phone_src/target}"

if [[ ! -x "$bin" ]]; then
  if ! command -v cargo >/dev/null; then
    exit 0
  fi
  cargo build --release --manifest-path "$phone_src/Cargo.toml" --quiet 2>/dev/null || exit 0
fi

"$bin" status >/dev/null 2>&1 || true
exit 0
