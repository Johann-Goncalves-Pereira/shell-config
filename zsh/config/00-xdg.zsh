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

# Source the output of `<tool> init` from a cache instead of forking the tool
# on every shell, the same way antidote keeps a static bundle.
#
#   _source_cached_init <name> [-s <stamp-file>]... -- <command> [args...]
#
# The cache is regenerated when the resolved binary path changes (Homebrew
# keeps bottle mtimes, so a new Cellar path can be older than the cache), when
# the binary is newer than the cache, or when any stamp file is newer.
# Empty or failing output is never cached.
_source_cached_init() {
  # Sourcing happens here, outside any `emulate -L`, so a script that sets
  # options at top level (atuin does) keeps them in the interactive shell.
  local _cached_init_file
  _cached_init_refresh "$@" || return 1
  source "$_cached_init_file"
}

_cached_init_refresh() {
  emulate -L zsh
  local name="$1"
  shift
  local -a stamps
  while [[ $1 == -s ]]; do
    stamps+=("$2")
    shift 2
  done
  [[ $1 == -- ]] && shift
  local cmd="$1"
  local bin="${commands[$cmd]:-$cmd}"
  bin="${bin:A}"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init-${name}.zsh"
  local header="# bin=${bin}"
  local regen=0 first stamp
  _cached_init_file="$cache"

  if [[ ! -s $cache || $bin -nt $cache ]]; then
    regen=1
  else
    IFS= read -r first <"$cache"
    [[ $first == "$header" ]] || regen=1
    for stamp in "${stamps[@]}"; do
      [[ $stamp -nt $cache ]] && regen=1
    done
  fi
  (( regen )) || return 0

  local tmp="${cache}.$$"
  mkdir -p "${cache:h}"
  if { print -r -- "$header"; "$@"; } >| "$tmp" 2>/dev/null \
    && (( $(wc -c <"$tmp") > ${#header} + 1 )); then
    mv -f "$tmp" "$cache"
  else
    rm -f "$tmp"
    return 1
  fi
}
