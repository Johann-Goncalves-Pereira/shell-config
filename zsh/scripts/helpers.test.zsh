#!/usr/bin/env zsh
# Helper functions: killport, top_history, cp wrapper, strip_image, gpo, update.
emulate -L zsh
setopt err_return

root="${0:A:h}/.."
fail() {
  print -u2 "FAIL: $*"
  exit 1
}

USER_CONFIG_DIRECTORY="$root"
source "$root/config/color.zsh"
source "$root/config/utils.zsh"

# --- killport only targets the listener ---
typeset -f killport | grep -q 'sTCP:LISTEN' || fail "killport must filter on -sTCP:LISTEN"
typeset -f killport | grep -q 'iTCP' || fail "killport must use -iTCP:<port>"
if command -v nc >/dev/null; then
  port=48611
  nc -l 127.0.0.1 "$port" </dev/null >/dev/null 2>&1 &
  ncpid=$!
  sleep 0.3
  if ! killport "$port" >/dev/null 2>&1; then
    kill "$ncpid" 2>/dev/null
    fail "killport $port failed against a live listener"
  fi
  sleep 0.2
  if kill -0 "$ncpid" 2>/dev/null; then
    kill "$ncpid" 2>/dev/null
    fail "killport left the listener alive"
  fi
fi

# --- top_history uses Atuin's stats, not the 16-line history builtin ---
typeset -f top_history | grep -q 'atuin stats' || fail "top_history must use atuin stats"
if typeset -f top_history | grep -q 'grep -v'; then
  fail "top_history must not filter with grep -v \"./\" (that drops every path)"
fi

# --- cp -r stays filtered but says what it skipped ---
tmp="$(mktemp -d)"
mkdir -p "$tmp/src/.git" "$tmp/src/node_modules/pkg" "$tmp/src/lib"
: >"$tmp/src/a.txt"
: >"$tmp/src/.git/HEAD"
: >"$tmp/src/lib/b.txt"
out="$(cd "$tmp" && cp -r src dest 2>&1)" || fail "cp -r failed: $out"
[[ -f $tmp/dest/a.txt && -f $tmp/dest/lib/b.txt ]] || fail "cp -r must copy regular files"
[[ ! -e $tmp/dest/.git && ! -e $tmp/dest/node_modules ]] || fail "cp -r must still exclude junk"
[[ $out == *".git"* && $out == *"node_modules"* ]] || fail "cp -r must name the entries it skipped, got: $out"
[[ $out == *"--no-ignore"* ]] || fail "cp -r must mention the --no-ignore escape hatch"
out="$(cd "$tmp" && cp -r --no-ignore src full 2>&1)" || fail "cp -r --no-ignore failed: $out"
[[ -e $tmp/full/.git/HEAD ]] || fail "cp -r --no-ignore must copy everything"
rm -rf "$tmp"

# --- strip_image rebuilds only when sources changed ---
typeset -f strip_image | grep -E -q -- '-newer|-nt' || fail "strip_image must skip go install when the binary is fresh"

# --- gpo pulls once ---
(( $(typeset -f gpo | grep -c 'git fetch') == 0 )) || fail "gpo must not fetch again after pull"

# --- update: WebUI is opt-in, cleanup runs once ---
typeset -f update | grep -F -q -- '--webui' || fail "update must take --webui to opt in to the Docker step"
(( $(typeset -f update | grep -c 'brew cleanup') == 1 )) || fail "update must run brew cleanup once"
grep -E -q '^node = "24"$' "$root/config/mise.toml" || fail "mise.toml must pin node to the 24 line, not an exact patch"

print "OK helpers"
exit 0
