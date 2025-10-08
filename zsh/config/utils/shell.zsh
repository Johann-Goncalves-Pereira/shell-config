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

# Expand ... to ../../ in the current buffer.
#
# The function is meant to be bound to a key and called
# interactively. It will expand ... to ../../ if it finds
# a sequence of dots in the current buffer.
#
# The function does not modify the buffer if it doesn't find
# a sequence of dots.
function _expand_dots() {
  local MATCH
  if [[ $LBUFFER =~ '\.\.\.+' ]]; then
    LBUFFER=$LBUFFER:fs%\.\.\.%../../%
  fi
}

# Expand ... to ../../ in the current buffer and then expand or complete the
# current buffer.
function _expand_dots_then_expand_or_complete() {
  zle _expand_dots
  zle expand-or-complete
}
# This function first expands a sequence of dots ('...') to '../../' in the current
# buffer using the _expand_dots function, and then accepts the current line as if
# the Enter key was pressed.
function _expand_dots_then_accept_line() {
  zle _expand_dots
  zle accept-line
}

# Create a custom widget to expand ... to ../../ in the current buffer.
zle -N _expand_dots

# Create a custom widget to expand ... to ../../ in the current buffer, and then
# either expand or complete the current buffer.
zle -N _expand_dots_then_expand_or_complete

# Create a custom widget to expand ... to ../../ in the current buffer, and then
# accept the current line as if the Enter key was pressed.
zle -N _expand_dots_then_accept_line

# Bind the widgets to keys.
# - '^I' is the Tab key.
# - '^M' is the Enter key.
bindkey '^I' _expand_dots_then_expand_or_complete
bindkey '^M' _expand_dots_then_accept_line

# ${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration


# Function to search torrents using magnetfinder without needing quotes
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

  magnetfinder --all --query "$wrapped"
}