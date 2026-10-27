#!/usr/bin/env zsh
# Line editing and completion contracts: keys, LS_COLORS, fzf-tab styles.
emulate -L zsh
setopt err_return

root="${0:A:h}/.."
fail() {
  print -u2 "FAIL: $*"
  exit 1
}

export XDG_CACHE_HOME="$(mktemp -d)"
export TERM="${TERM:-xterm-256color}"
[[ $TERM == dumb ]] && export TERM=xterm-256color
USER_CONFIG_DIRECTORY="$root"

source "$root/config/00-xdg.zsh"
source "$root/config/40-options.zsh"
source "$root/config/utils/widgets.zsh"
source "$root/config/utils/shell.zsh"
source "$root/config/60-keys.zsh"

check_key() {
  local map="$1" seq="$2" want="$3" got
  got="$(bindkey -M "$map" -- "$seq")"
  [[ $got == *" $want" ]] || fail "$map $seq is '$got', want $want"
}

for map in emacs viins vicmd; do
  check_key "$map" '^[[H' beginning-of-line
  check_key "$map" '^[[F' end-of-line
  check_key "$map" '^[[3~' delete-char
  check_key "$map" '^[[1;5D' backward-word
  check_key "$map" '^[[1;5C' forward-word
  check_key "$map" '^[[A' history-beginning-search-backward
  check_key "$map" '^[OA' history-beginning-search-backward
  check_key "$map" '^[[B' history-beginning-search-forward
  check_key "$map" '^[OB' history-beginning-search-forward
  check_key "$map" '^H' backward-kill-word
done
[[ $WORDCHARS != */* ]] || fail "WORDCHARS still contains /"

# --- completion styles ---
source "$root/config/50-completions.zsh"
zstyle -s ':completion::complete:ls::' menu v
[[ $v == no ]] || fail "fzf-tab needs 'menu no', got '${v:-unset}'"
zstyle -t ':fzf-tab:complete:cd:*' use-fzf-default-opts \
  || fail "fzf-tab must honor FZF_DEFAULT_OPTS (use-fzf-default-opts yes)"
zstyle -s ':fzf-tab:complete:cd:*' fzf-min-height v
[[ $v == <1-> ]] || fail "fzf-tab fzf-min-height must be set, got '${v:-unset}'"

[[ -n $LS_COLORS ]] || fail "LS_COLORS must be generated when it is empty"
[[ -s $XDG_CACHE_HOME/zsh/ls_colors.zsh ]] || fail "LS_COLORS must be cached under XDG_CACHE_HOME/zsh"
zstyle -a ':completion::complete:ls::' list-colors colors
(( ${#colors} > 5 )) || fail "completion list-colors must come from a populated LS_COLORS"

rm -rf "$XDG_CACHE_HOME"
print "OK keys"
exit 0
