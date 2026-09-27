#!/usr/bin/env zsh
# Run the shell-config regression tests.
emulate -L zsh
setopt err_return

here="${0:A:h}"
zsh "$here/expand-dots.test.zsh"
zsh "$here/foundation.test.zsh"
zsh "$here/cargo-debug-clean.test.zsh"
print "OK validate"
