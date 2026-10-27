# mise replaces asdf + fnm. direnv stays for existing .envrc files.
# asdf and fnm binaries are left installed until `mise doctor` is trusted.
#
# --shims: version switching happens when a tool runs, not on every cd.
# Full `mise activate` installs a chpwd hook-env that costs ~30ms per cd and
# can stall for seconds when auto_install would fetch a missing version.
if [[ -f "$USER_CONFIG_DIRECTORY/config/mise.toml" ]]; then
  export MISE_GLOBAL_CONFIG_FILE="$USER_CONFIG_DIRECTORY/config/mise.toml"
  export MISE_LEGACY_VERSION_FILE="${MISE_LEGACY_VERSION_FILE:-1}"
fi

if (( $+commands[mise] )); then
  eval "$(mise activate zsh --shims)"
fi

if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# One zoxide init. `cd` is the jump command, same as before.
# Add to the DB in the background so direct-path cds are not blocked on I/O.
if (( $+commands[zoxide] )); then
  export _ZO_DOCTOR=0
  eval "$(zoxide init --cmd cd zsh)"
  __zoxide_hook() {
    \command zoxide add -- "$(__zoxide_pwd)" &>/dev/null &!
  }
fi

# One fzf init. Ctrl-T and Alt-C stay here; Ctrl-R is handed to Atuin below.
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git || git ls-tree -r --name-only HEAD || rg --files --hidden --follow --glob '!.git' || find ."
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 90% --border}"
  export FZF_CTRL_T_OPTS="--preview '(bat --style=numbers --color=always {} || cat {} || tree -NC {}) 2> /dev/null | head -200'"
  export FZF_ALT_C_OPTS="--preview 'tree -NC {} | head -200'"
fi

# Atuin owns Ctrl-R. Imported history lives in its own database.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh)"
fi

if (( $+commands[go] )); then
  () {
    local gobin
    gobin="$(go env GOPATH 2>/dev/null)/bin"
    [[ -n $gobin && -d $gobin ]] && path=("$gobin" $path) && export PATH
  }
fi
