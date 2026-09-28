# Ghostty shell integration first, then our binds so they win.
if [[ -n ${GHOSTTY_RESOURCES_DIR:-} && -r ${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration ]]; then
  source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
fi

# Ctrl+Backspace / Ctrl+Delete
bindkey -M emacs '^H' backward-kill-word
bindkey -M viins '^H' backward-kill-word
bindkey -M vicmd '^H' backward-kill-word
bindkey -M emacs '^[[3;5~' kill-word
bindkey -M viins '^[[3;5~' kill-word
bindkey -M vicmd '^[[3;5~' kill-word

# Esc Esc toggles a leading sudo. Ctrl-Z foregrounds an empty buffer.
if (( ${+widgets[sudo-command-line]} )); then
  bindkey -M emacs '\e\e' sudo-command-line
  bindkey -M viins '\e\e' sudo-command-line
  bindkey -M vicmd '\e\e' sudo-command-line
fi
if (( ${+widgets[fancy-ctrl-z]} )); then
  bindkey '^Z' fancy-ctrl-z
fi

# Ctrl-Right accepts the grey suggestion. Right arrow still moves one character.
if (( ${+widgets[autosuggest-accept]} )); then
  bindkey -M emacs '^[[1;5C' autosuggest-accept
  bindkey -M viins '^[[1;5C' autosuggest-accept
fi

# Plugins are already loaded. Hand Tab to fzf-tab with the dots widget underneath.
# If fzf-tab is missing, still bind the dots expander.
if (( ${+functions[enable-fzf-tab]} && ${+functions[_setup_expand_dots_with_fzf_tab]} )); then
  _setup_expand_dots_with_fzf_tab
elif (( ${+functions[_bind_expand_dots_keys]} )); then
  _bind_expand_dots_keys
fi
