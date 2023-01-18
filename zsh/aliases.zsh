# application
alias bat="batcat"
alias batcat="batcat --style=numbers,changes,grid"

# zsh-navigation-tools
alias naliases=n-aliases ncd=n-cd nenv=n-env nfunctions=n-functions nhistory=n-history
alias nkill=n-kill noptions=n-options npanelize=n-panelize nhelp=n-help

# GIT
alias gwt="git worktree"
alias glz="lazygit"

# exa
alias exag="exa -l -h -g"
alias exal="exa -l"
alias exall="exa -abghHliS"

# LS
alias l="exa"
alias ls='colorls --sd'
alias la='colorls --sd -A'
alias lx="exa -abghHliS"
alias ll="colorls --sd -A --long"
alias lt='colorls --sd --tree' # tree view

# Enable tab completion for flags
source $(dirname $(gem which colorls))/tab_complete.sh

export PATH="$PATH:$HOME/.rvm/bin"
