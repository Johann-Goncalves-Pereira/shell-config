# Daily git aliases previously provided by OMZP::git.
# Branch helpers stay local so we do not depend on the Oh My Zsh plugin.

git_current_branch() {
  command git rev-parse --abbrev-ref HEAD 2>/dev/null
}

git_main_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local ref
  for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,master}; do
    if command git show-ref -q --verify "$ref"; then
      print -r -- "${ref:t}"
      return 0
    fi
  done
  print -r -- master
}

alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gcb='git checkout -b'
alias gco='git checkout'
alias gc='git commit -v'
alias gcmsg='git commit -m'
alias gcam='git commit -a -m'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git pull'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gst='git status'
alias gss='git status -s'
alias gsb='git status -sb'
alias glog='git log --oneline --decorate --graph'
alias glo='git log --oneline --decorate'
alias grb='git rebase'
alias grbi='git rebase -i'
alias grh='git reset'
alias grhh='git reset --hard'
alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsw='git switch'
alias gswc='git switch -c'
