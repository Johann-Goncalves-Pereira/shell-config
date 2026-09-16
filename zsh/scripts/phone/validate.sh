#!/usr/bin/env bash
# Xin-ji-style validate: fmt + clippy -D warnings + nextest (or cargo test).
set -euo pipefail
cd "$(dirname "$0")"

export CARGO_HOME="${CARGO_HOME:-$PWD/.cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$PWD/target}"

cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
if command -v cargo-nextest >/dev/null 2>&1; then
  cargo nextest run --profile fast
else
  cargo test
fi
