# Ghostty shell integration first, then our binds so they win.
if [[ -n ${GHOSTTY_RESOURCES_DIR:-} && -r ${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration ]]; then
  source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
fi

# Bind a key in all three keymaps.
_bind_all() {
  local key="$1" widget="$2" map
  for map in emacs viins vicmd; do
    bindkey -M "$map" -- "$key" "$widget"
  done
}

# Ctrl+Backspace / Ctrl+Delete (WORDCHARS without "/" stops at path segments).
_bind_all '^H' backward-kill-word
_bind_all '^[[3;5~' kill-word

# Home / End / Delete / Ctrl+Left / Ctrl+Right, as Ghostty and most xterm-likes send them.
_bind_all '^[[H' beginning-of-line
_bind_all '^[[F' end-of-line
_bind_all '^[[1~' beginning-of-line
_bind_all '^[[4~' end-of-line
_bind_all '^[[3~' delete-char
_bind_all '^[[1;5D' backward-word
_bind_all '^[[1;5C' forward-word

# Up / Down: cycle only history entries that start with what is typed.
# `atuin init --disable-up-arrow` leaves these free; Ctrl-R stays Atuin.
_bind_all '^[[A' history-beginning-search-backward
_bind_all '^[OA' history-beginning-search-backward
_bind_all '^[[B' history-beginning-search-forward
_bind_all '^[OB' history-beginning-search-forward

# Esc Esc toggles a leading sudo. Ctrl-Z foregrounds an empty buffer.
if (( ${+widgets[sudo-command-line]} )); then
  _bind_all '\e\e' sudo-command-line
fi
unfunction _bind_all
if (( ${+widgets[fancy-ctrl-z]} )); then
  bindkey '^Z' fancy-ctrl-z
fi

# Plugins are already loaded. Expand dots inside fzf-tab, then complete for real.
# If fzf-tab is missing, still bind the dots expander.
if (( ${+functions[enable-fzf-tab]} && ${+functions[_setup_expand_dots_with_fzf_tab]} )); then
  _setup_expand_dots_with_fzf_tab
elif (( ${+functions[_bind_expand_dots_keys]} )); then
  _bind_expand_dots_keys
fi
