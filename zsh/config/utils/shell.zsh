function reload() {
  exec zsh
}

function killport() {
  local port="$1"

  if [[ -z "$port" ]]; then
    echo -e "${BRed}Error:${Color_Off} Port is NULL"
    return 1
  fi

  lsof -t -i:$port >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "${BRed}Error:${Color_Off} No process is using port: $port"
    return 1
  fi

  kill $(lsof -t -i:$port)
  if [ $? -eq 0 ]; then
    echo -e "${UGreen}Success:${Color_Off} Killed process on port: $port\n"
  else
    echo -e "${BRed}Error:${Color_Off} Failed to kill process on port: $port"
    return 1
  fi
}

# This function displays the top N most frequently used shell commands
# from the history. It takes one argument, 'amount', which specifies
# the number of top commands to display. The commands are sorted by
# frequency, and each command's occurrence percentage is shown.
# Commands starting with "./" are excluded from the results.
top_history() {
  local amount="$1"

  if [ -z "$amount" ]; then
    echo -e "${BRed}Error:${Color_Off} No amount provided"
    return 1
  fi

  if ! history >/dev/null 2>&1; then
    echo -e "${BRed}Error:${Color_Off} Could not access the command history"
    return 1
  fi

  history | grep -v "./" | awk '{CMD[$2]++;count++;}END {for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' |
    sort -nr | nl | head -n"$amount"
}

# Expand ... to ../../ in the current buffer (mutates LBUFFER).
# Keep this a plain function — do not `zle -N` it.
function _expand_dots() {
  if [[ $LBUFFER =~ '\.\.\.+' ]]; then
    LBUFFER=$LBUFFER:fs%\.\.\.%../../%
  fi
}

# Tab: expand ... → ../.. then run real completion.
#
# Only call `.expand-or-complete` — never `fzf-tab-complete` or `fzf-completion`.
# fzf-tab saves whatever is on Tab as `_ftb_orig_widget` and invokes it from
# `fzf-tab-complete`. If we rebind Tab to ourselves after fzf-tab loads and then
# call `fzf-tab-complete`, we recurse until FUNCNEST blows up.
#
# Final chain: Tab → fzf-tab-complete → (orig) this widget → .expand-or-complete
function _expand_dots_then_expand_or_complete() {
  _expand_dots
  zle .expand-or-complete
}

# Enter: expand dots then accept the line.
function _expand_dots_then_accept_line() {
  _expand_dots
  zle .accept-line
}

zle -N _expand_dots_then_expand_or_complete
zle -N _expand_dots_then_accept_line

# Bind before fzf-tab so enable-fzf-tab can capture THIS as _ftb_orig_widget.
# After fzf-tab is active, keep Tab on fzf-tab-complete (do not steal it back).
_bind_expand_dots_keys() {
  bindkey '^M' _expand_dots_then_accept_line
  if [[ ${_ftb_orig_widget:-} == _expand_dots_then_expand_or_complete ]] &&
    (( ${+widgets[fzf-tab-complete]} )); then
    bindkey '^I' fzf-tab-complete
  else
    bindkey '^I' _expand_dots_then_expand_or_complete
  fi
  if [[ ${fzf_default_completion:-} == _expand_dots_then_expand_or_complete ]]; then
    fzf_default_completion='.expand-or-complete'
  fi
}
_bind_expand_dots_keys

# Called from fzf-tab's atload: force our widget to be the wrapped orig, then
# give Tab back to fzf-tab. Survives zinit turbo load-order races.
_setup_expand_dots_with_fzf_tab() {
  (( ${+functions[enable-fzf-tab]} )) || return 0
  bindkey '^I' _expand_dots_then_expand_or_complete
  bindkey '^M' _expand_dots_then_accept_line
  enable-fzf-tab
}

# ${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration


# Function to search torrents using magnetfinder with safer provider handling
# The search query will be passed wrapped in " or ' so the program receives the quotes.
torrent() {
  if [ $# -eq 0 ]; then
    echo -e "${BRed}Error:${Color_Off} No search query provided"
    return 1
  fi

  local q="$*"
  local wrapped

  # If the query contains a double quote, wrap with single quotes; otherwise wrap with double quotes.
  if [[ "$q" == *'"'* ]]; then
    wrapped="'$q'"
  else
    wrapped="\"$q\""
  fi

  if ! command -v magnetfinder >/dev/null 2>&1; then
    echo -e "${BRed}Error:${Color_Off} magnetfinder not found in PATH"
    return 1
  fi

  # Try scraping all providers first. If it fails due to YTS DNS issues,
  # retry without the YTS provider (explicit provider flags).
  local output exitcode
  output=$(magnetfinder --all --query "$wrapped" 2>&1)
  exitcode=$?

  # If output contains YTS/DNS related errors, magnetfinder may still exit 0.
  # Detect those messages in the output and retry without YTS provider.
  if printf "%s" "$output" | grep -qiE "Error requesting data from yts|yts\.mx|resolve dns name|failed to lookup|nodename nor servname"; then
    echo -e "${BRed}Warning:${Color_Off} YTS lookup failed, retrying without YTS provider"
    magnetfinder --piratebay --nyaa --query "$wrapped"
    return $?
  fi

  # Otherwise, return magnetfinder's output and exit code.
  printf "%s\n" "$output"
  return $exitcode
}