# > Oh My Posh
# Not routed through _source_cached_init on purpose: `oh-my-posh init` already
# keeps its script in ~/.cache/oh-my-posh/init.<hash>.zsh and only emits a
# fresh POSH_SESSION_ID plus a `source` line (~6ms). Caching that output would
# make every shell share one session id and one session cache file.
if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]] && (( $+commands[oh-my-posh] )); then
  eval "$(oh-my-posh init zsh --config "$USER_CONFIG_DIRECTORY/config/prompt/johanns.json")"
fi
