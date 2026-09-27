# Always sourced, including scripts. Keep this file tiny.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Collapse duplicate PATH and fpath entries.
typeset -U path PATH fpath FPATH

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
