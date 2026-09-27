# fpath entries must be in place before antidote's compinit.
fpath+=("$HOME/.zfunc")

if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

() {
  local site_functions="${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh/site-functions"
  if [[ -d $site_functions ]]; then
    fpath=("$site_functions" $fpath)
  fi

  local fastanime_comps="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
  if (( $+commands[fastanime] )); then
    mkdir -p "$fastanime_comps"
    if [[ ! -s ${fastanime_comps}/_fastanime ]]; then
      fastanime completions >"${fastanime_comps}/_fastanime" 2>/dev/null \
        || rm -f "${fastanime_comps}/_fastanime"
    fi
  fi
  if [[ -d $fastanime_comps ]]; then
    fpath=("$fastanime_comps" $fpath)
  fi
}

zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' menu select

zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:complete:*:options' sort true
zstyle ':fzf-tab:complete:(cd|ls|exa|eza|bat|cat|emacs|nano|vi|vim):*' \
  fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
  fzf-preview 'echo ${(P)word}'

zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w -w'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] &&
    if [[ $OSTYPE == darwin* ]]; then
      ps -p $word -o comm="" -w -w
    elif [[ $OSTYPE == linux* ]]; then
      ps --pid=$word -o cmd --no-headers -w -w
    fi'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags '--preview-window=down:3:wrap'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'

zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
  'git diff $word | delta'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview \
  'git log --color=always $word'
zstyle ':fzf-tab:complete:git-help:*' fzf-preview \
  'git help $word | bat -plman --color=always'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview \
  'case "$group" in
  "commit tag") git show --color=always $word ;;
  *) git show --color=always $word | delta ;;
  esac'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
  'case "$group" in
  "modified file") git diff $word | delta ;;
  "recent commit object name") git show --color=always $word | delta ;;
  *) git log --color=always $word ;;
  esac'

zstyle ':fzf-tab:complete:(\\|)run-help:*' fzf-preview 'run-help $word'
zstyle ':fzf-tab:complete:(\\|*/|)man:*' fzf-preview 'man $word'
