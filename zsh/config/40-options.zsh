# History and options previously provided by Oh My Zsh lib files.
# HISTFILE stays ~/.zsh_history so existing history is not orphaned.
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt LONG_LIST_JOBS
setopt NO_BEEP
setopt EXTENDED_GLOB
# NULL_GLOB is deliberately not global: `rm *.bak` with no matches must error.
# Helpers that want empty matches use the (N) qualifier.
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt SHARE_HISTORY

export HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
export HISTSIZE=100000
export SAVEHIST=100000

# Inline suggestions come from in-memory history: instant, and no 20-char cap.
# This runs after `atuin init`, which prepends its own per-keystroke search
# strategy; Ctrl-R already searches Atuin, so the inline ghost text stays local.
ZSH_AUTOSUGGEST_STRATEGY=(history)
# Widgets are fixed after 60-keys.zsh; skip re-wrapping every widget per prompt.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Ctrl+Backspace / Ctrl+W stop at path segments instead of eating the whole path.
WORDCHARS="${WORDCHARS//\//}"

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Zsh already knows its tty; no fork.
if [[ -n ${TTY:-} ]]; then
  export GPG_TTY="$TTY"
fi
