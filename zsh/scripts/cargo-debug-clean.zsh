#!/bin/zsh
# Remove one Cargo crate's debug build tree; leave target/release alone.
# Usage: cargo-debug-clean.zsh <crate-dir>

emulate -L zsh
setopt errexit nounset pipefail

if (( $# != 1 )); then
  print -u2 -- "usage: ${0:t} <crate-dir>"
  exit 2
fi

crate="${1:A}"
if [[ ! -d "$crate" ]]; then
  print -u2 -- "cargo-debug-clean: not a directory: $1"
  exit 1
fi

target="$crate/target"
[[ -d "$target" ]] || exit 0

[[ -d "$target/debug" ]] && rm -rf -- "$target/debug"

for fly in "$target"/flycheck*(N/); do
  rm -rf -- "$fly"
done

exit 0
