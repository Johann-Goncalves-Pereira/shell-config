# mise replaces asdf + fnm. direnv stays for existing .envrc files.
# asdf and fnm binaries are left installed until `mise doctor` is trusted.
if [[ -f "$USER_CONFIG_DIRECTORY/config/mise.toml" ]]; then
  export MISE_GLOBAL_CONFIG_FILE="$USER_CONFIG_DIRECTORY/config/mise.toml"
  export MISE_LEGACY_VERSION_FILE="${MISE_LEGACY_VERSION_FILE:-1}"
fi

if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# One zoxide init. `cd` is the jump command, same as before.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init --cmd cd zsh)"
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

# Atuin owns Ctrl-R. Use the repo config only when the user has none yet.
if (( $+commands[atuin] )); then
  () {
    local user_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/atuin/config.toml"
    local repo_cfg="$USER_CONFIG_DIRECTORY/config/atuin.toml"
    if [[ ! -e $user_cfg && ! -L $user_cfg && -f $repo_cfg ]]; then
      mkdir -p "${user_cfg:h}"
      ln -s "$repo_cfg" "$user_cfg"
    fi
  }
  eval "$(atuin init zsh)"
fi

if (( $+commands[go] )); then
  () {
    local gobin
    gobin="$(go env GOPATH 2>/dev/null)/bin"
    [[ -n $gobin && -d $gobin ]] && path=("$gobin" $path) && export PATH
  }
fi
