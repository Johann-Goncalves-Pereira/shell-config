function reload() {
  exec zsh
}

ollama() {
  if [[ $1 == serve ]]; then
    shift
    command ollama serve "$@" &>/dev/null &
    disown
  else
    command ollama "$@"
  fi
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

# Expand dot runs in the current buffer (mutates LBUFFER).
# Keep this a plain function — do not `zle -N` it.
#
#   ..     → ../
#   ...    → ../../
#   .....  → ../../..
# A run of three or more dots is rewritten first. Exactly two dots only become
# `../` when they are their own path segment (`..`, `cd ..`, `foo/..`), so
# names like `foo..` are left alone.
function _expand_dots() {
  if [[ $LBUFFER =~ '\.\.\.+' ]]; then
    LBUFFER=$LBUFFER:fs%\.\.\.%../../%
  elif [[ $LBUFFER =~ '(^|[^[:alnum:]_])\.\.$' ]]; then
    LBUFFER+='/'
  fi
}

# Tab without fzf-tab: expand ... → ../.. then run real completion.
# With fzf-tab, Tab goes through the wrapper installed by
# `_setup_expand_dots_with_fzf_tab` instead. This widget must not call
# `fzf-tab-complete` or `fzf-completion`: fzf-tab invokes whatever it saved as
# `_ftb_orig_widget`, and calling it again recurses until FUNCNEST blows up.
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

# Tab binding lives in config/60-keys.zsh, after plugins load.
# Calling this early steals Tab back from fzf-tab.
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

# Expand dots, then let fzf-tab complete through the real completion widget.
# Called once from config/60-keys.zsh after the plugin bundle is sourced.
#
# Two separate bugs both make `cd <Tab>` draw nothing:
#
# 1. If `_ftb_orig_widget` is a user widget that runs `zle .expand-or-complete`,
#    completion happens in a nested editor command. fzf-tab records no matches
#    and `_fzf-tab-apply` then clears the list the nested command just built.
#    The orig widget has to be `expand-or-complete` itself.
#
# 2. fzf-tab sets `local IN_FZF_TAB=1` and then starts that widget with `zle`.
#    The completion widget does not see that local, so its compadd hook ignores
#    the matches. A global is visible across that boundary. Unset it afterwards
#    so ordinary compadd is left alone.
#
# fast-syntax-highlighting rebinds the `fzf-tab-complete` widget to a saved
# copy of the original function. `zle -N` points Tab back at the wrapper.
#
# enable-fzf-tab restores whatever Tab widget it captured at load time before
# it reads the key again. Overwrite that memory first.
_setup_expand_dots_with_fzf_tab() {
  (( ${+functions[enable-fzf-tab]} )) || return 0
  if (( ! $+functions[_expand_dots_ftb_complete] )); then
    functions[_expand_dots_ftb_complete]=${functions[fzf-tab-complete]}
    function fzf-tab-complete() {
      _expand_dots
      typeset -g IN_FZF_TAB=1
      {
        _expand_dots_ftb_complete "$@"
      } always {
        unset IN_FZF_TAB
      }
    }
  fi
  typeset -g _ftb_orig_widget=expand-or-complete
  bindkey '^I' expand-or-complete
  bindkey '^M' _expand_dots_then_accept_line
  enable-fzf-tab
  zle -N fzf-tab-complete
}

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