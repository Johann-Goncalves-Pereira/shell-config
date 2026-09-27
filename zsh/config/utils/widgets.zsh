# Small replacements for Oh My Zsh plugins we no longer load.

extract() {
  local file="$1"
  if [[ -z $file || ! -f $file ]]; then
    print -u2 "extract: '$file' is not a valid file"
    return 1
  fi
  case "$file" in
    *.tar.bz2 | *.tbz2) tar xvjf "$file" ;;
    *.tar.gz | *.tgz) tar xvzf "$file" ;;
    *.tar.xz | *.txz) tar xvJf "$file" ;;
    *.tar.zst) tar --zstd -xvf "$file" ;;
    *.tar) tar xvf "$file" ;;
    *.bz2) bunzip2 "$file" ;;
    *.gz) gunzip "$file" ;;
    *.xz) unxz "$file" ;;
    *.zip) unzip "$file" ;;
    *.7z) 7z x "$file" ;;
    *.rar) unrar x "$file" ;;
    *.zst) unzstd "$file" ;;
    *)
      print -u2 "extract: '$file' cannot be extracted"
      return 1
      ;;
  esac
}

sudo-command-line() {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    LBUFFER="${LBUFFER#sudo }"
  elif [[ -n ${EDITOR:-} && $BUFFER == ${EDITOR}\ * ]]; then
    LBUFFER="${LBUFFER#${EDITOR} }"
  elif [[ $BUFFER == sudoedit\ * ]]; then
    LBUFFER="${LBUFFER#sudoedit }"
  else
    LBUFFER="sudo $LBUFFER"
  fi
}
zle -N sudo-command-line

fancy-ctrl-z() {
  if [[ $#BUFFER -eq 0 ]]; then
    BUFFER="fg"
    zle accept-line -w
  else
    zle push-input -w
    zle clear-screen -w
  fi
}
zle -N fancy-ctrl-z
