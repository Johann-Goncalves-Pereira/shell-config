# Sourced by antidote after completion directories are on fpath
# and before fzf-tab, autosuggestions, and syntax highlighting.
if (( ! ${+_comps} )); then
  autoload -Uz compinit
  compinit -C -i -d "${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-${HOST}}"
fi
