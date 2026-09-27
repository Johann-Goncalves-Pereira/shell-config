# Completion cache lives under XDG. $ZSH was never set, so the old
# $ZSH/cache dump path collapsed to /cache and was never reused.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

() {
  emulate -L zsh
  local cache_dir="${XDG_CACHE_HOME}/zsh"
  mkdir -p "$cache_dir"
  export ZSH_COMPDUMP="${cache_dir}/.zcompdump-${HOST}"
  zstyle ':completion:*' use-cache true
  zstyle ':completion:*' cache-path "${cache_dir}/.zcompcache"
}
