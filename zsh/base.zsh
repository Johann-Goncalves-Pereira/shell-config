# > ------------------- < #
# >  Zsh configuration  < #
# > ------------------- < #

USER_CONFIG_DIRECTORY="$HOME/.shell-config/zsh"

_source_if() {
  [[ -f $1 ]] && source "$1"
}

_source_if "$USER_CONFIG_DIRECTORY/config/color.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/00-xdg.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/10-homebrew.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/70-path.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/20-mise.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/40-options.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/50-completions.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/30-plugins.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/alias.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/alias/git.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/utils.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/60-keys.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/python.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/work.zsh"
_source_if "$USER_CONFIG_DIRECTORY/config/prompt/oh-my-posh.zsh"

unfunction _source_if
