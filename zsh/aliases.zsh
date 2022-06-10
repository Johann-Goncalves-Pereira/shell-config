# CAT
alias bat="batcat"

# zsh-navigation-tools
alias naliases=n-aliases ncd=n-cd nenv=n-env nfunctions=n-functions nhistory=n-history
alias nkill=n-kill noptions=n-options npanelize=n-panelize nhelp=n-help

# GIT
alias gwt="git worktree"

# exa
alias exag="exa --long --header --git"
alias exal="exa -l"
alias exall="exa -abghHliS"

# LS
alias ls='colorls --group-directories-first'
alias la='colorls --group-directories-first --almost-all'
alias ll='colorls --group-directories-first --almost-all --long' # detailed list view
alias lt='colorls --group-directories-first --tree'              # tree view

# Enable tab completion for flags
source $(dirname $(gem which colorls))/tab_complete.sh

export PATH="$PATH:$HOME/.rvm/bin"
