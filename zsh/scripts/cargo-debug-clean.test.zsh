#!/bin/zsh
# Temp-tree test for cargo-debug-clean.zsh
emulate -L zsh
setopt errexit nounset pipefail

here="${0:A:h}"
clean="$here/cargo-debug-clean.zsh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/cargo-debug-clean.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT

mkdir -p "$tmp/crate/target/debug/deps" \
  "$tmp/crate/target/flycheck0" \
  "$tmp/crate/target/release"
print -n junk >"$tmp/crate/target/debug/deps/x.o"
print -n junk >"$tmp/crate/target/flycheck0/stdout"
print -n keep >"$tmp/crate/target/release/bin"

"$clean" "$tmp/crate"

[[ ! -e "$tmp/crate/target/debug" ]] || {
  print -u2 -- "FAIL: target/debug still present"
  exit 1
}
[[ ! -e "$tmp/crate/target/flycheck0" ]] || {
  print -u2 -- "FAIL: target/flycheck0 still present"
  exit 1
}
[[ -f "$tmp/crate/target/release/bin" ]] || {
  print -u2 -- "FAIL: target/release/bin missing"
  exit 1
}
got="$(<"$tmp/crate/target/release/bin")"
[[ "$got" == keep ]] || {
  print -u2 -- "FAIL: target/release/bin contents changed ($got)"
  exit 1
}

# Missing target/ is a no-op success.
"$clean" "$tmp/crate"
mkdir -p "$tmp/empty"
"$clean" "$tmp/empty"

print -- "ok: cargo-debug-clean"
