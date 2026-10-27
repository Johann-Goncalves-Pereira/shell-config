# Sourced by antidote after completion directories are on fpath
# and before fzf-tab, autosuggestions, and syntax highlighting.
#
# -C skips the fpath scan, which is why a tool installed by brew used to get no
# completion until `update` deleted the dump. Do one full scan a day instead,
# and keep a compiled .zwc next to the dump so the next startup loads that.
if (( ! ${+_comps} )); then
  () {
    emulate -L zsh
    setopt extended_glob
    local dump="${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-${HOST}}"
    autoload -Uz compinit
    if [[ ! -s $dump || -n $dump(#qN.mh+24) ]]; then
      compinit -i -d "$dump"
      # compinit leaves an unchanged dump untouched; mark the daily scan done.
      [[ -s $dump ]] && touch "$dump"
    else
      compinit -C -i -d "$dump"
    fi
    if [[ -s $dump && ( ! -s $dump.zwc || $dump -nt $dump.zwc ) ]]; then
      { zcompile "$dump" } &>/dev/null &!
    fi
  }
fi
