#!/usr/bin/env zsh
# _source_cached_init: regenerate only when the binary, its path, or a stamp changes.
emulate -L zsh
setopt err_return

root="${0:A:h}/.."
fail() {
  print -u2 "FAIL: $*"
  exit 1
}

export XDG_CACHE_HOME="$(mktemp -d)"
work="$(mktemp -d)"
source "$root/config/00-xdg.zsh"
(( $+functions[_source_cached_init] )) || fail "_source_cached_init must be defined by 00-xdg.zsh"

export STUB_COUNTER="$work/counter"
print 0 >"$STUB_COUNTER"
stub="$work/stubtool"
cat >"$stub" <<'EOF'
#!/bin/sh
n=$(cat "$STUB_COUNTER"); n=$((n+1)); echo "$n" >"$STUB_COUNTER"
echo "typeset -g STUB_INIT_RUN=$n"
EOF
chmod +x "$stub"
cache="$XDG_CACHE_HOME/zsh/init-stubtool.zsh"
age() { touch -t 202001010000 "$1"; }

_source_cached_init stubtool -- "$stub" || fail "first call must succeed"
[[ ${STUB_INIT_RUN:-} == 1 ]] || fail "first call must run the generator (got '${STUB_INIT_RUN:-}')"
[[ -s $cache ]] || fail "cache file must exist after the first call"

unset STUB_INIT_RUN
_source_cached_init stubtool -- "$stub"
[[ $STUB_INIT_RUN == 1 ]] || fail "second call must hit the cache (got $STUB_INIT_RUN)"

age "$cache"
touch "$stub"
_source_cached_init stubtool -- "$stub"
[[ $STUB_INIT_RUN == 2 ]] || fail "a newer binary must regenerate (got $STUB_INIT_RUN)"

stamp="$work/stamp"
age "$cache"
: >"$stamp"
_source_cached_init stubtool -s "$stamp" -- "$stub"
[[ $STUB_INIT_RUN == 3 ]] || fail "a newer stamp must regenerate (got $STUB_INIT_RUN)"

age "$stamp"
_source_cached_init stubtool -s "$stamp" -- "$stub"
[[ $STUB_INIT_RUN == 3 ]] || fail "an older stamp must not regenerate (got $STUB_INIT_RUN)"

# Homebrew keeps bottle mtimes, so a new Cellar path must regenerate even if it is older.
mkdir -p "$work/v2"
cp "$stub" "$work/v2/stubtool"
age "$work/v2/stubtool"
_source_cached_init stubtool -- "$work/v2/stubtool"
[[ $STUB_INIT_RUN == 4 ]] || fail "a binary at a new path must regenerate (got $STUB_INIT_RUN)"

# Empty or failing output must not be cached.
empty="$work/empty"
print -l '#!/bin/sh' 'exit 0' >"$empty"
chmod +x "$empty"
if _source_cached_init emptytool -- "$empty" 2>/dev/null; then
  fail "empty output must not count as a cached init"
fi
[[ ! -e $XDG_CACHE_HOME/zsh/init-emptytool.zsh ]] || fail "empty output must not leave a cache file"

broken="$work/broken"
print -l '#!/bin/sh' 'echo partial' 'exit 3' >"$broken"
chmod +x "$broken"
if _source_cached_init brokentool -- "$broken" 2>/dev/null; then
  fail "a failing generator must not count as a cached init"
fi
[[ ! -e $XDG_CACHE_HOME/zsh/init-brokentool.zsh ]] || fail "a failing generator must not leave a cache file"

rm -rf "$XDG_CACHE_HOME" "$work"
print "OK init-cache"
exit 0
