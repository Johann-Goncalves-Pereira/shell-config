#!/usr/bin/env zsh
# Contracts for the foundation rewrite. No network.
emulate -L zsh
setopt err_return

root="${0:A:h}/.."
fail() {
  print -u2 "FAIL: $*"
  exit 1
}

# --- brew guard is not inverted ---
homebrew_file="$root/config/10-homebrew.zsh"
grep -F -q 'if (( $+commands[brew] ))' "$homebrew_file" || fail "brew block must run when brew exists"
if grep -q 'if ! brew=' "$homebrew_file"; then
  fail "inverted brew guard is back"
fi

# --- plugins are antidote, not zinit ---
plugins_file="$root/plugins/zsh_plugins.txt"
grep -q 'Aloxaf/fzf-tab' "$plugins_file" || fail "fzf-tab missing from plugin list"
grep -q '45-compinit.zsh' "$plugins_file" || fail "compinit must run before fzf-tab"
grep -q 'compinit' "$root/config/45-compinit.zsh" || fail "45-compinit.zsh must call compinit"
if grep -qi 'zinit' "$plugins_file"; then
  fail "plugin list must not mention zinit"
fi
if grep -q 'zinit' "$root/base.zsh"; then
  fail "base.zsh must not source zinit"
fi

# --- pgrep is not shadowed ---
(
  emulate -L zsh
  source "$root/config/alias.zsh"
  if [[ $(alias pgrep 2>/dev/null) == *ugrep* ]]; then
    fail "pgrep must not alias to ugrep"
  fi
  if command -v ugrep >/dev/null; then
    [[ $(alias upgrep 2>/dev/null) == *ugrep* ]] || fail "upgrep should wrap ugrep -P"
  fi
)

# --- media globs are zsh, not bash shopt ---
file_zsh="$root/config/utils/file.zsh"
if grep -q 'shopt' "$file_zsh"; then
  fail "file.zsh still uses bash shopt"
fi
grep -q '\*\*/\*\.mp3(N\.)' "$file_zsh" || fail "compress_mp3 should use a zsh glob"

tmp=$(mktemp -d)
mkdir -p "$tmp/nested"
: >"$tmp/nested/a.mp3"
(
  cd "$tmp"
  files=(**/*.mp3(N.))
  [[ ${#files} -eq 1 && $files[1] == nested/a.mp3 ]] || exit 1
) || fail "zsh **/*.mp3(N.) did not find the nested file"
rm -rf "$tmp"

# --- git_purge uses _git_var and the short default-branch name ---
git_file="$root/config/utils/git.zsh"
if grep -q 'get-default-branch' "$git_file"; then
  fail "git_purge still calls get-default-branch"
fi
source "$root/config/color.zsh"
source "$git_file"
typeset -f git_purge | grep -q '_git_var' || fail "git_purge must call _git_var"
typeset -f git_purge | grep -q 'DEFAULT_BRANCH_NAME' || fail "git_purge must use DEFAULT_BRANCH_NAME"

repo=$(mktemp -d)
(
  cd "$repo"
  git init -q -b main
  git config user.email "shell-config@example.com"
  git config user.name "shell-config"
  git commit -q --allow-empty -m init
  git branch old
  git checkout -q -b feature
  git remote add origin "$repo"
  git update-ref refs/remotes/origin/main refs/heads/main
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

  _git_var
  [[ $DEFAULT_BRANCH_NAME == main ]] || exit 1
  [[ $CURRENT_BRANCH == feature ]] || exit 1

  print n | git_purge >/dev/null
  git show-ref --verify --quiet refs/heads/old || exit 1

  print y | git_purge >/dev/null
  if git show-ref --verify --quiet refs/heads/old; then
    exit 1
  fi
  git show-ref --verify --quiet refs/heads/main || exit 1
  git show-ref --verify --quiet refs/heads/feature || exit 1
) || fail "git_purge did not keep main/current and delete the other branch"
rm -rf "$repo"

# --- prompt does not shell out to rustc or glob source files ---
theme="$root/config/prompt/johanns.json"
grep -q '"type": "rust"' "$theme" || fail "prompt needs a native rust segment"
if grep -q 'rustc' "$theme"; then
  fail "prompt must not call rustc"
fi
if grep -F -q '*.rs' "$theme"; then
  fail "prompt must not glob rs files"
fi

# --- a fresh audio binary is watched in the background ---
audio_file="$root/config/utils/audio.zsh"
grep -q 'fix_call_audio watch >/dev/null 2>&1 &' "$audio_file" || fail "fresh audio watch must be backgrounded"
grep -q 'disown' "$audio_file" || fail "background audio watch must be disowned"
grep -q '_fix_call_audio_outdated' "$audio_file" || fail "rebuilds must stay in the foreground"

# --- atuin does not run a history line on enter ---
grep -q 'enter_accept = false' "$root/config/atuin.toml" || fail "atuin enter_accept must be false"

# --- homebrew does not scan every gnubin ---
if grep -F -q 'opt/*/libexec/gnubin' "$homebrew_file"; then
  fail "homebrew must not glob every gnubin"
fi
grep -q 'coreutils' "$homebrew_file" || fail "homebrew should prepend coreutils gnubin when present"

print "OK foundation"
exit 0
