#!/usr/bin/env zsh
# Run the shell-config regression tests.
emulate -L zsh
setopt err_return

here="${0:A:h}"
zsh "$here/expand-dots.test.zsh"
zsh "$here/foundation.test.zsh"
zsh "$here/init-cache.test.zsh"
zsh "$here/keys.test.zsh"
zsh "$here/helpers.test.zsh"
zsh "$here/cargo-debug-clean.test.zsh"

# Startup budget: median of five warm interactive shells.
# Measured ~90ms after the cached-init/prompt work; was 160ms before.
zmodload zsh/datetime
typeset -a samples
typeset -F t0
typeset -i ms budget=150
zsh -i -c exit </dev/null &>/dev/null || true
for _ in 1 2 3 4 5; do
  t0=$EPOCHREALTIME
  zsh -i -c exit </dev/null &>/dev/null || true
  ms=$(( (EPOCHREALTIME - t0) * 1000 ))
  samples+=("$ms")
done
samples=(${(n)samples})
print "startup median: ${samples[3]} ms (samples: ${samples[*]}; budget ${budget} ms)"
if (( samples[3] > budget )); then
  print -u2 "FAIL: interactive startup over budget"
  exit 1
fi
print "OK validate"
