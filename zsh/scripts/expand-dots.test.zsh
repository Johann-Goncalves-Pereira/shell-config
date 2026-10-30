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

# --- fzf-tab must complete through expand-or-complete, with IN_FZF_TAB global ---
# zsh does not show fzf-tab's local IN_FZF_TAB to the completion widget started
# with `zle`. Without a global, compadd never records directory matches, and
# fzf-tab then clears the list. Tab on `cd ` looks like it did nothing.
FZFTAB=""
for candidate in \
  "$HOME/Library/Caches/antidote/github.com/Aloxaf/fzf-tab/fzf-tab.zsh" \
  "$HOME/.cache/antidote"/https-COLON--SLASH--SLASH-github.com-SLASH-Aloxaf-SLASH-fzf-tab/fzf-tab.zsh \
  "$HOME/.local/share/zinit/plugins/Aloxaf---fzf-tab/fzf-tab.zsh"
do
  if [[ -f $candidate ]]; then
    FZFTAB="$candidate"
    break
  fi
done
if [[ -n $FZFTAB ]]; then
  source "$FZFTAB"

  _setup_expand_dots_with_fzf_tab

  [[ $(bindkey '^I') == *fzf-tab-complete* ]] || {
    print -u2 "FAIL: Tab should be fzf-tab-complete after setup, got: $(bindkey '^I')"
    exit 1
  }
  [[ ${_ftb_orig_widget} == expand-or-complete ]] || {
    print -u2 "FAIL: _ftb_orig_widget should be expand-or-complete, got: ${_ftb_orig_widget-UNSET}"
    exit 1
  }
  (( ${+widgets[.fzf-tab-orig-expand-or-complete]} )) || {
    print -u2 "FAIL: missing .fzf-tab-orig-expand-or-complete"
    exit 1
  }
  [[ ${widgets[fzf-tab-complete]} == user:fzf-tab-complete ]] || {
    print -u2 "FAIL: Tab widget should call fzf-tab-complete, got: ${widgets[fzf-tab-complete]-UNSET}"
    exit 1
  }
  typeset -f fzf-tab-complete | grep -q '_expand_dots' || {
    print -u2 "FAIL: fzf-tab-complete must expand dots"
    exit 1
  }
  typeset -f fzf-tab-complete | grep -q 'typeset -g IN_FZF_TAB=1' || {
    print -u2 "FAIL: fzf-tab-complete must export IN_FZF_TAB for the completion widget"
    exit 1
  }
  typeset -f fzf-tab-complete | grep -q '_expand_dots_ftb_complete' || {
    print -u2 "FAIL: fzf-tab-complete must call the saved fzf-tab implementation"
    exit 1
  }

  # Interactive check: a highlighter-style wrapper sits on Tab, the way
  # fast-syntax-highlighting does. Setup has to take the widget back, and
  # `cd <Tab>` must compadd with IN_FZF_TAB set.
  zmodload zsh/zpty
  cap=$(mktemp)
  driver=$(mktemp)
  shell_zsh="${0:A:h}/../config/utils/shell.zsh"
  cat >"$driver" <<EOF
PS1='READY%# '
unsetopt BEEP
autoload -Uz compinit && compinit -u
source ${(q)shell_zsh}
source ${(q)FZFTAB}
functions[_saved_fzf_tab_complete]=\$functions[fzf-tab-complete]
function _hl_fzf_tab_complete() { _saved_fzf_tab_complete "\$@" }
zle -N fzf-tab-complete _hl_fzf_tab_complete
_setup_expand_dots_with_fzf_tab
functions[_real_compadd]=\$functions[compadd]
function compadd() {
  print -r -- "CADD IN=[\$IN_FZF_TAB]" >> ${(q)cap}
  _real_compadd "\$@"
}
print MARK_SETUP
EOF
  zpty -d cdtab 2>/dev/null || true
  zpty cdtab "TERM=xterm-256color zsh -f -i"
  zpty -w cdtab "source ${(q)driver}"
  seen=""
  i=0
  while (( i < 80 )); do
    line=""
    zpty -r -t cdtab line $'*\n' 2>/dev/null || true
    if [[ $line == *MARK_SETUP* ]]; then
      seen=1
      break
    fi
    i=$(( i + 1 ))
    sleep 0.05
  done
  [[ -n $seen ]] || {
    print -u2 "FAIL: setup did not finish in the tab probe"
    zpty -d cdtab 2>/dev/null || true
    exit 1
  }
  zpty -w -n cdtab 'cd '
  sleep 0.2
  zpty -w -n cdtab $'\t'
  i=0
  pty_out=""
  while (( i < 40 )); do
    [[ -s $cap ]] && grep -q 'IN=\[1\]' "$cap" && break
    line=""
    zpty -r -t cdtab line $'*\n' 2>/dev/null || true
    pty_out+="$line"
    i=$(( i + 1 ))
    sleep 0.05
  done
  if ! grep -q 'IN=\[1\]' "$cap" 2>/dev/null; then
    print -u2 "FAIL: cd Tab did not compadd with IN_FZF_TAB=1"
    print -u2 "capture: $(<$cap)"
    print -u2 "pty: $pty_out"
    zpty -d cdtab 2>/dev/null || true
    exit 1
  fi
  zpty -d cdtab 2>/dev/null || true
  rm -f "$cap" "$driver"
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
