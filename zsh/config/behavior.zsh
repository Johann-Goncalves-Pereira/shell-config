set -o AUTO_CD

ZSH_AUTOSUGGEST_STRATEGY=match_prev_cmd

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
# Completion styles
zstyle ':completion:*' special-dirs true
# Only run compinit if zinit isn't present (zinit manages completions)
if ! type zinit >/dev/null 2>&1; then
	autoload -Uz compinit && compinit -i 2>/dev/null || true
fi
# autoload -Uz bashcompinit && bashcompinit

# Ctrl+Backspace: kill the word backward
bindkey -M emacs '^H' backward-kill-word
bindkey -M viins '^H' backward-kill-word
bindkey -M vicmd '^H' backward-kill-word

# Ctrl+Delete: kill the word forward
bindkey -M emacs '^[[3;5~' kill-word
bindkey -M viins '^[[3;5~' kill-word
bindkey -M vicmd '^[[3;5~' kill-word

#? Config for the colorize plugin
ZSH_COLORIZE_TOOL=chroma
ZSH_COLORIZE_STYLE="colorful"
ZSH_COLORIZE_CHROMA_FORMATTER=terminal256
