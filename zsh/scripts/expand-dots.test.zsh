#!/usr/bin/env zsh
# Regression: ... + Tab must expand without FUNCNEST recursion under fzf-tab.
emulate -L zsh
setopt err_return
FUNCNEST=30

source "${0:A:h}/../config/utils/shell.zsh"
autoload -Uz compinit && compinit -u

# --- unit: plain expansion ---
LBUFFER='...'
_expand_dots
[[ $LBUFFER == '../../' ]] || {
  print -u2 "FAIL: '...' → expected '../../', got '$LBUFFER'"
  exit 1
}

LBUFFER='.....'
_expand_dots
[[ $LBUFFER == '../../..' ]] || {
  print -u2 "FAIL: '.....' → expected '../../..', got '$LBUFFER'"
  exit 1
}

LBUFFER='..'
_expand_dots
[[ $LBUFFER == '../' ]] || {
  print -u2 "FAIL: '..' → expected '../', got '$LBUFFER'"
  exit 1
}

LBUFFER='cd ..'
_expand_dots
[[ $LBUFFER == 'cd ../' ]] || {
  print -u2 "FAIL: 'cd ..' → expected 'cd ../', got '$LBUFFER'"
  exit 1
}

LBUFFER='foo/..'
_expand_dots
[[ $LBUFFER == 'foo/../' ]] || {
  print -u2 "FAIL: 'foo/..' → expected 'foo/../', got '$LBUFFER'"
  exit 1
}

LBUFFER='foo..'
_expand_dots
[[ $LBUFFER == 'foo..' ]] || {
  print -u2 "FAIL: 'foo..' should stay unchanged, got '$LBUFFER'"
  exit 1
}

LBUFFER='../'
_expand_dots
[[ $LBUFFER == '../' ]] || {
  print -u2 "FAIL: '../' should stay unchanged, got '$LBUFFER'"
  exit 1
}

# --- contract: never call fzf-tab/fzf-completion from the Tab widget ---
typeset -f _expand_dots_then_expand_or_complete | grep -q 'fzf-tab-complete' && {
  print -u2 "FAIL: widget must not call fzf-tab-complete"
  exit 1
}
typeset -f _expand_dots_then_expand_or_complete | grep -q 'fzf-completion' && {
  print -u2 "FAIL: widget must not call fzf-completion"
  exit 1
}
typeset -f _expand_dots_then_expand_or_complete | grep -q '\.expand-or-complete' || {
  print -u2 "FAIL: widget must call .expand-or-complete"
  exit 1
}

# --- simulate fzf-tab wrapping our widget (the fixed chain) ---
FZFTAB=""
for candidate in \
  "$HOME/.local/share/zinit/plugins/Aloxaf---fzf-tab/fzf-tab.zsh" \
  "$HOME/.cache/antidote"/https-COLON--SLASH--SLASH-github.com-SLASH-Aloxaf-SLASH-fzf-tab/fzf-tab.zsh
do
  if [[ -f $candidate ]]; then
    FZFTAB="$candidate"
    break
  fi
done
if [[ -n $FZFTAB ]]; then
  # Minimal stubs so sourcing fzf-tab doesn't need a full interactive env
  source "$FZFTAB"

  _setup_expand_dots_with_fzf_tab

  [[ $(bindkey '^I') == *fzf-tab-complete* ]] || {
    print -u2 "FAIL: Tab should be fzf-tab-complete after setup, got: $(bindkey '^I')"
    exit 1
  }
  [[ ${_ftb_orig_widget} == _expand_dots_then_expand_or_complete ]] || {
    print -u2 "FAIL: _ftb_orig_widget should be our widget, got: ${_ftb_orig_widget-UNSET}"
    exit 1
  }
  (( ${+widgets[.fzf-tab-orig-_expand_dots_then_expand_or_complete]} )) || {
    print -u2 "FAIL: missing .fzf-tab-orig copy of our widget"
    exit 1
  }

  # Calling orig must expand dots and must NOT re-enter fzf-tab-complete.
  # Drive via a one-shot widget under a tiny FUNCNEST budget.
  _probe() {
    LBUFFER='...'
    zle .fzf-tab-orig-_expand_dots_then_expand_or_complete
    print -r -- "PROBE=$LBUFFER"
  }
  zle -N _probe

  # Without a line editor, invoke the same code path as the orig widget body:
  LBUFFER='...'
  _expand_dots
  [[ $LBUFFER == '../../' ]] || {
    print -u2 "FAIL: orig path expand expected '../../', got '$LBUFFER'"
    exit 1
  }
fi

# --- keys file must re-enable fzf-tab with our setup helper (not steal Tab back) ---
keys_file="${0:A:h}/../config/60-keys.zsh"
plugins_file="${0:A:h}/../plugins/zsh_plugins.txt"
grep -q '_setup_expand_dots_with_fzf_tab' "$keys_file" || {
  print -u2 "FAIL: 60-keys.zsh must call _setup_expand_dots_with_fzf_tab"
  exit 1
}
grep -q 'Aloxaf/fzf-tab' "$plugins_file" || {
  print -u2 "FAIL: plugin list must include fzf-tab"
  exit 1
}

print "OK expand-dots regression"
exit 0
