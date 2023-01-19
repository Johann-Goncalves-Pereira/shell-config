eval "$(direnv hook zsh)"

PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"

zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
autoload -Uz compinit && compinit

set -o AUTO_CD

ZSH_AUTOSUGGEST_STRATEGY=match_prev_cmd

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

#go configuration
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOPATH/bin

[[ -s "/home/johann/.gvm/scripts/gvm" ]] && source "/home/johann/.gvm/scripts/gvm"

# Ctrl+Backspace: kill the word backward
bindkey -M emacs '^H' backward-kill-word
bindkey -M viins '^H' backward-kill-word
bindkey -M vicmd '^H' backward-kill-word

# Ctrl+Delete: kill the word forward
bindkey -M emacs '^[[3;5~' kill-word
bindkey -M viins '^[[3;5~' kill-word
bindkey -M vicmd '^[[3;5~' kill-word

#? Syntax Highlighting
# source ~/.oh-my-zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#? LSCOLORS
# source ~/.local/share/lscolors.sh

#? Config Auto Jump
[[ -s /home/johann/.autojump/etc/profile.d/autojump.sh ]] && source /home/johann/.autojump/etc/profile.d/autojump.sh
autoload -U compinit && compinit -u

#? Config for the colorize plugin
ZSH_COLORIZE_TOOL=chroma
ZSH_COLORIZE_STYLE="colorful"
ZSH_COLORIZE_CHROMA_FORMATTER=terminal256

# noisetorch
if [ -d "$HOME/.local/bin" ]; then
  PATH="$HOME/.local/bin:$PATH"
fi
