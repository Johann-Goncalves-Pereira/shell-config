# mise replaces asdf + fnm. direnv stays for existing .envrc files.
# asdf and fnm binaries are left installed until `mise doctor` is trusted.
#
# --shims: version switching happens when a tool runs, not on every cd.
# Full `mise activate` installs a chpwd hook-env that costs ~30ms per cd and
# can stall for seconds when auto_install would fetch a missing version.
#
# Every init script below is deterministic, so it is sourced from
# $XDG_CACHE_HOME/zsh/init-<tool>.zsh (see _source_cached_init in 00-xdg.zsh)
# instead of forking the tool on each shell. Atuin's script creates its own
# session id when sourced, so caching its text is safe.
if [[ -f "$USER_CONFIG_DIRECTORY/config/mise.toml" ]]; then
  export MISE_GLOBAL_CONFIG_FILE="$USER_CONFIG_DIRECTORY/config/mise.toml"
  export MISE_LEGACY_VERSION_FILE="${MISE_LEGACY_VERSION_FILE:-1}"
fi

if (( $+commands[mise] )); then
  _source_cached_init mise -- mise activate zsh --shims
fi

if (( $+commands[direnv] )); then
  _source_cached_init direnv -- direnv hook zsh
fi

# One zoxide init. `cd` is the jump command, same as before.
# Add to the DB in the background so direct-path cds are not blocked on I/O.
if (( $+commands[zoxide] )); then
  export _ZO_DOCTOR=0
  _source_cached_init zoxide -- zoxide init --cmd cd zsh
  __zoxide_hook() {
    \command zoxide add -- "$(__zoxide_pwd)" &>/dev/null &!
  }
fi

# One fzf init. Ctrl-T and Alt-C stay here; Ctrl-R is handed to Atuin below.
if (( $+commands[fzf] )); then
  _source_cached_init fzf -- fzf --zsh
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git || git ls-tree -r --name-only HEAD || rg --files --hidden --follow --glob '!.git' || find ."
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 90% --border}"
  export FZF_CTRL_T_OPTS="--preview '(bat --style=numbers --color=always {} || cat {} || tree -NC {}) 2> /dev/null | head -200'"
  export FZF_ALT_C_OPTS="--preview 'tree -NC {} | head -200'"
fi

# Atuin owns Ctrl-R. Up arrow stays a local prefix search (see 60-keys.zsh).
# Imported history lives in its own database.
if (( $+commands[atuin] )); then
  _source_cached_init atuin -- atuin init zsh --disable-up-arrow
fi

# Go binaries: honor an explicit GOPATH, else Go's default $HOME/go.
# Asking the go binary for GOPATH cost 20-130ms per shell through the mise shim.
() {
  local gobin="${GOPATH:-$HOME/go}/bin"
  [[ -d $gobin ]] && path=("$gobin" $path) && export PATH
  return 0
}
