export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
#? config GPG key:
export GPG_TTY=$(tty)
gpgconf --launch gpg-agent

export PATH="/opt/homebrew/opt/curl/bin:$PATH"
. /opt/homebrew/opt/asdf/libexec/asdf.sh
export DIRENV_LOG_FORMAT="" 

export PATH=$PATH:$HOME/.garden/bin

USER_CONFIG_DIRECTORY="$HOME/.shell-config/zsh"

source $USER_CONFIG_DIRECTORY/behaviors.zsh
source $USER_CONFIG_DIRECTORY/colors.zsh
source $USER_CONFIG_DIRECTORY/fuctions.zsh

#? Send cache to XDG_CACHE_HOME if set or $HOME/.cache
() {
  emulate -L zsh
  local -r cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/zsh
  autoload -Uz _store_cache compinit
  zstyle ':completion:*' use-cache true
  zstyle ':completion:*' cache-path $cache_dir/.zcompcache
  [[ -f $cache_dir/.zcompcache/.make-cache-dir ]] || _store_cache .make-cache-dir
  compinit -C -d $cache_dir/.zcompdump
}

#? Config for tab completion, tab+shift for reverse tab completion
zstyle ':completion:*' menu select
zmodload zsh/complist
bindkey '^[[Z' reverse-menu-complete

#? Config autojump
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

#? To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

# Plugin history-search-multi-word loaded with investigating.
zinit load Cloudstek/zsh-plugin-appup 
# zinit load redxtech/zsh-asdf-direnv
zinit load jspears/worktree
zinit load zsh-users/zsh-autosuggestions
zinit load zsh-users/zsh-completions
zinit load zdharma-continuum/history-search-multi-word

zinit ice wait lucid

# Two regular plugins loaded without investigating.
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k
zinit light zdharma-continuum/fast-syntax-highlighting

# A plugin with a custom tag.
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit snippet OMZ::plugins/sudo/sudo.plugin.zsh
zinit snippet OMZ::plugins/man/man.plugin.zsh
zinit snippet OMZ::plugins/gitignore/gitignore.plugin.zsh
zinit snippet OMZ::plugins/git-auto-fetch/git-auto-fetch.plugin.zsh
zinit snippet OMZ::plugins/catimg/catimg.plugin.zsh
zinit snippet OMZ::plugins/compleat/compleat.plugin.zsh
zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh
zinit snippet OMZ::plugins/command-not-found/command-not-found.plugin.zsh
zinit snippet OMZ::plugins/aliases/aliases.plugin.zsh
zinit snippet OMZ::plugins/npm/npm.plugin.zsh
zinit snippet OMZ::plugins/yarn/yarn.plugin.zsh
zinit snippet OMZ::plugins/node/node.plugin.zsh
zinit snippet OMZ::plugins/golang/golang.plugin.zsh
zinit snippet OMZ::plugins/docker/docker.plugin.zsh
zinit snippet OMZ::plugins/flutter/flutter.plugin.zsh
zinit snippet OMZ::plugins/react-native/react-native.plugin.zsh
zinit snippet OMZ::plugins/vscode/vscode.plugin.zsh
zinit snippet OMZ::plugins/torrent/torrent.plugin.zsh
zinit snippet OMZ::plugins/web-search/web-search.plugin.zsh
zinit snippet OMZ::plugins/copypath/copypath.plugin.zsh
zinit snippet OMZ::plugins/copyfile/copyfile.plugin.zsh
zinit snippet OMZ::plugins/history/history.plugin.zsh
zinit snippet OMZ::plugins/common-aliases/common-aliases.plugin.zsh

source $USER_CONFIG_DIRECTORY/aliases.zsh

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="$HOME/.bin:$PATH"
