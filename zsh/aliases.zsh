# application
alias bat="batcat"
alias batcat="batcat --style=numbers,changes,grid"
alias obs="flatpak run com.obsproject.Studio"

# zsh-navigation-tools
alias naliases=n-aliases ncd=n-cd nenv=n-env nfunctions=n-functions nhistory=n-history
alias nkill=n-kill noptions=n-options npanelize=n-panelize nhelp=n-help

# GIT
alias gwt="git worktree"

# exa
alias exag="exa -l -h -g"
alias exal="exa -l"
alias exall="exa -abghHliS"

# LS
alias l="exa"
alias ls='colorls --group-directories-first'
alias la='colorls --group-directories-first --almost-all'
alias lx="exa -abghHliS"
alias ll="colorls --group-directories-first --almost-all --long"
alias lt='colorls --group-directories-first --tree' # tree view

# Enable tab completion for flags
source $(dirname $(gem which colorls))/tab_complete.sh

export PATH="$PATH:$HOME/.rvm/bin"
