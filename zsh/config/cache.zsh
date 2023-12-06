# > ------- < #
# >  Cache  < #
# > ------- < #
# Send cache to XDG_CACHE_HOME if set or $HOME/.cache
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
() {
  emulate -L zsh
  local -r cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/zsh
  autoload -Uz _store_cache compinit
  zstyle ':completion:*' use-cache true
  zstyle ':completion:*' cache-path $cache_dir/.zcompcache
  [[ -f $cache_dir/.zcompcache/.make-cache-dir ]] || _store_cache .make-cache-dir
  compinit -C -d $cache_dir/.zcompdump
}
