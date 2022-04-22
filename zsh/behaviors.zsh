# Ctrl+Backspace: kill the word backward
bindkey -M emacs '^H' backward-kill-word
bindkey -M viins '^H' backward-kill-word
bindkey -M vicmd '^H' backward-kill-word

# Ctrl+Delete: kill the word forward
bindkey -M emacs '^[[3;5~' kill-word
bindkey -M viins '^[[3;5~' kill-word
bindkey -M vicmd '^[[3;5~' kill-word

#? Syntax Highlighting
source ~/.oh-my-zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#? LSCOLORS
# source ~/.local/share/lscolors.sh

#? Config Auto Jump
[[ -s /home/johann/.autojump/etc/profile.d/autojump.sh ]] && source /home/johann/.autojump/etc/profile.d/autojump.sh
autoload -U compinit && compinit -u

#? Config for the colorize plugin
ZSH_COLORIZE_TOOL=chroma
ZSH_COLORIZE_STYLE="colorful"
ZSH_COLORIZE_CHROMA_FORMATTER=terminal256
