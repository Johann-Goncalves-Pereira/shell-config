# Antidote static bundle: regenerate only when the plugin list changes.
_antidote_script() {
  local prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
  local candidate
  for candidate in \
    "${prefix}/opt/antidote/share/antidote/antidote.zsh" \
    "${prefix}/share/antidote/antidote.zsh"
  do
    if [[ -f $candidate ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

() {
  local plugins_txt="$USER_CONFIG_DIRECTORY/plugins/zsh_plugins.txt"
  local static="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zsh_plugins.zsh"
  local antidote_script
  mkdir -p "${static:h}"

  if ! antidote_script="$(_antidote_script)"; then
    print -u2 "antidote is not installed; skipping plugins"
    autoload -Uz compinit
    compinit -C -i -d "${ZSH_COMPDUMP}"
    return 0
  fi

  source "$antidote_script"
  if [[ ! -s $static || $plugins_txt -nt $static ]]; then
    antidote bundle <"$plugins_txt" >|"$static"
  fi
  source "$static"
}
unfunction _antidote_script 2>/dev/null || true
