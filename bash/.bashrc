#!/bin/bash

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# The /path/to/your/blerc will be used
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach --rcfile ~/.ble.sh/blerc

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# append to the history file, don't overwrite it
shopt -s histappend

# Alias folder confg.
[[ $- == *i* ]] && source ~/.shell-config/bash/bash_alias

# Software folder confg.
[[ $- == *i* ]] && source ~/.shell-config/bash/bash_software

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
# shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
# force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

# colored GCC warnings and errors
# export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
  ;;
*) ;;

esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
    fiddgr
  fi
fi

export GIT_PS1_SHOWDIRTYSTATE=true
export PS1="\n"'$(date)'"\n\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w \[\033[1;31m\]"'$(__git_ps1 "- on branch [%s]")'"\[\033[m\]\n\$ "

[[ $- == *i* ]] && source ~/.shell-config/bash/bash_ls

# Add this line at the end of .bashrc:
[[ ${BLE_VERSION-} ]] && ble-attach
export ANDROID_SDK=/home/johann/Android/Sdk
export ANDROID_SDK=/home/johann/Android/Sdk

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
export ANDROID_SDK=/home/johann/Android/Sdk
export ANDROID_SDK=/home/johann/Android/Sdk
export ANDROID_SDK=/home/johann/Android/Sdk
export ANDROID_SDK=/home/johann/Android/Sdk
export ANDROID_SDK=/home/johann/Android/Sdk
. "$HOME/.cargo/env"
export ANDROID_SDK=/Users/johannpereira/Android/Sdk
source ~/.local/share/blesh/ble.sh
export ANDROID_SDK=/Users/johannpereira/Android/Sdk
export ANDROID_SDK=/Users/johannpereira/Android/Sdk

. "$HOME/.local/bin/env"
export ANDROID_SDK=/Users/johannpereira/Library/Android/sdk
export ANDROID_SDK=/Users/johannpereira/Library/Android/sdk

# > Languages
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
