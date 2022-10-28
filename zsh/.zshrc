# curl ftp://user:password@ipOrDomain/directoryPathOnServer/
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# Send cache to XDG_CACHE_HOME if set or $HOME/.cache
() {
  emulate -L zsh
  local -r cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/zsh
  autoload -Uz _store_cache compinit
  zstyle ':completion:*' use-cache true
  zstyle ':completion:*' cache-path $cache_dir/.zcompcache
  [[ -f $cache_dir/.zcompcache/.make-cache-dir ]] || _store_cache .make-cache-dir
  compinit -C -d $cache_dir/.zcompdump
}



# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"


#? To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  sudo 
  man
  
  git 
  # git-extras 
  git-auto-fetch
  # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git-flow  
  # git-flow  
  # git-flow-avh
  gitignore

  catimg
  compleat
  # timer

  # colorize
  colored-man-pages

  command-not-found
  
  # zsh-completions 
  # zsh-autosuggestions

  aliases
  common-aliases

  npm 
  yarn 
  asdf
  zsh-asdf-prompt
  # zsh-nvm 

  elm
  node 
  golang 

  # coffee

  docker 
  # https://github.com/Cloudstek/zsh-plugin-appup
  # appup
  flutter
  react-native

  vscode
  ubuntu  
  torrent
  web-search

  copypath
  copyfile
  
  history
)


#? Base of all settings
source $ZSH/oh-my-zsh.sh

#* User Config variable Path
USER_CONFIG_DIRECTORY="$HOME/.shell-config/zsh"

source $USER_CONFIG_DIRECTORY/aliases.zsh
source $USER_CONFIG_DIRECTORY/behaviors.zsh
source $USER_CONFIG_DIRECTORY/colors.zsh
source $USER_CONFIG_DIRECTORY/fuctions.zsh
# source $USER_CONFIG_DIRECTZSH_AUTOSUGGEST_STRATEGYORY/lscolor.zsh

# ? Garden
 export PATH=$PATH:$HOME/.garden/bin


###? Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"



zinit load Cloudstek/zsh-plugin-appup 
zinit ice wait lucid
zinit load redxtech/zsh-asdf-direnv

zinit load jspears/worktree

# zpl load marlonrichert/zsh-autocomplete
zinit load zsh-users/zsh-autosuggestions
zinit load zsh-users/zsh-completions

zinit light zdharma-continuum/fast-syntax-highlighting
zinit load zdharma-continuum/history-search-multi-word


ZSH_AUTOSUGGEST_STRATEGY=match_prev_cmd


source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"

# # bun completions
# [ -s "/home/johann/.bun/_bun" ] && source "/home/johann/.bun/_bun"

# # bun
# export BUN_INSTALL="$HOME/.bun"
# export PATH="$BUN_INSTALL/bin:$PATH"



#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

