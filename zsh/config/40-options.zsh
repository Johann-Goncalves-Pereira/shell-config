# History and options previously provided by Oh My Zsh lib files.
# HISTFILE stays ~/.zsh_history so existing history is not orphaned.
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt LONG_LIST_JOBS
setopt NO_BEEP
setopt EXTENDED_GLOB
setopt NULL_GLOB
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

ZSH_AUTOSUGGEST_STRATEGY=match_prev_cmd
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

if [[ -t 1 ]]; then
  export GPG_TTY="$(tty)"
fi
