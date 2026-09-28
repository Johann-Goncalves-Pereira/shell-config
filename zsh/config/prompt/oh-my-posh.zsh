# Oh My Posh. Apple Terminal skips the prompt; everywhere else uses a cached init.
if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]] && (( $+commands[oh-my-posh] )); then
  () {
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
    local cache_file="${cache_dir}/omp.zsh"
    local theme="$HOME/.shell-config/zsh/config/prompt/johanns.json"
    local omp_bin="${commands[oh-my-posh]}"
    local tmp
    mkdir -p "$cache_dir"
    if [[ ! -s $cache_file || $theme -nt $cache_file || ( -n $omp_bin && $omp_bin -nt $cache_file ) ]]; then
      tmp="${cache_file}.$$"
      if oh-my-posh init zsh --config "$theme" >"$tmp"; then
        mv "$tmp" "$cache_file"
      else
        rm -f "$tmp"
        return
      fi
    fi
    source "$cache_file"
  }
fi
