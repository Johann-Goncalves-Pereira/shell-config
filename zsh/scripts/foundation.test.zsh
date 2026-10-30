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

# --- cd must stay snappy: mise shims (no chpwd hook-env) + async zoxide add ---
mise_file="$root/config/20-mise.zsh"
grep -F -q 'mise activate zsh --shims' "$mise_file" || fail "mise must activate with --shims so cd does not run hook-env"
if grep -E -q 'mise activate zsh"[^-]|mise activate zsh$' "$mise_file"; then
  fail "full mise activate (with hook-env) would make every cd pay ~30ms"
fi
grep -F -q '_ZO_DOCTOR=0' "$mise_file" || fail "disable zoxide doctor noise (_ZO_DOCTOR=0)"
grep -E -q 'zoxide add .*\&!' "$mise_file" || fail "zoxide chpwd hook must add in the background (&!)"
grep -F -q 'auto_install = false' "$root/config/mise.toml" || fail "mise auto_install must be off so missing tools do not stall cd/prompt"

# --- startup must not fork go, and Up arrow is prefix search, not the Atuin UI ---
if grep -q 'go env' "$mise_file"; then
  fail "20-mise.zsh must not run go env on every shell (~20-130ms through the mise shim)"
fi
grep -F -q -- '--disable-up-arrow' "$mise_file" || fail "atuin init must pass --disable-up-arrow"
for tool in mise direnv zoxide fzf atuin; do
  grep -E -q "_source_cached_init $tool " "$mise_file" || fail "$tool init must go through _source_cached_init"
done

# --- the audio guard must not be restarted in the foreground on every tab ---
audio_file="$root/config/utils/audio.zsh"
grep -E -q 'fix_call_audio watch[^&]*&>/dev/null &!' "$audio_file" \
  || fail "audio.zsh must background the watch call (fix_call_audio watch &>/dev/null &!)"

# --- compinit refreshes daily and compiles the dump ---
compinit_file="$root/config/45-compinit.zsh"
grep -F -q 'mh+24' "$compinit_file" || fail "compinit must do a full scan when the dump is older than 24h"
grep -q 'zcompile' "$compinit_file" || fail "compinit must zcompile the dump"

# --- the prompt must not walk the tree or spawn rustc; versions are cached per folder ---
theme="$root/config/prompt/johanns.json"
command -v jq >/dev/null || fail "jq is required to check the prompt theme"
if grep -q 'rustc' "$theme"; then
  fail "theme must use the rust segment, not a text segment that spawns rustc"
fi
if grep -F -q '*/*/*.rs' "$theme"; then
  fail "theme must not glob three levels deep on every prompt"
fi
if jq -e '[.blocks[].segments[] | select(has("properties"))] | length > 0' "$theme" >/dev/null; then
  fail "theme uses the deprecated segment key 'properties'; use 'options'"
fi
langs='"node","pnpm","bun","php","python","ruby","go","rust","haskell","java","lua","elixir"'
jq -e "[.blocks[].segments[] | select(.type | IN($langs))] | length == 12" "$theme" >/dev/null \
  || fail "theme must keep the 12 language segments (including a real rust segment)"
jq -e "[.blocks[].segments[] | select(.type | IN($langs))] | all(.[]; .options.display_mode == \"files\")" "$theme" >/dev/null \
  || fail "every language segment must set options.display_mode = files"
jq -e "[.blocks[].segments[] | select(.type | IN($langs))] | all(.[]; .cache.strategy == \"folder\" and (.cache.duration | type) == \"string\")" "$theme" >/dev/null \
  || fail "every language segment must cache per folder (cache.strategy = folder, cache.duration set)"
jq -e '[.blocks[].segments[] | select(.type == "rust")] | all(.[]; (.options.extensions // []) | index("*.rs") == null)' "$theme" >/dev/null \
  || fail "rust segment must key off Cargo files, not *.rs globs"
jq -e '[.blocks[].segments[] | select(.type == "git")] | all(.[]; has("cache") | not)' "$theme" >/dev/null \
  || fail "git segment must stay live (no cache)"

# --- 40-options: suggestions, keys, editor, no global NULL_GLOB ---
options_file="$root/config/40-options.zsh"
if grep -q 'setopt NULL_GLOB' "$options_file"; then
  fail "NULL_GLOB must not be set globally (rm *.bak with no matches should error)"
fi
if grep -q 'BUFFER_MAX_SIZE' "$options_file"; then
  fail "drop ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE; a 20-char cap hides most suggestions"
fi
if grep -F -q '$(tty)' "$options_file"; then
  fail "GPG_TTY must use \$TTY, not a tty fork"
fi
(
  emulate -L zsh
  source "$options_file"
  [[ ${(j: :)ZSH_AUTOSUGGEST_STRATEGY} == history ]] || fail "ZSH_AUTOSUGGEST_STRATEGY must be (history), got '${(j: :)ZSH_AUTOSUGGEST_STRATEGY}'"
  [[ ${ZSH_AUTOSUGGEST_MANUAL_REBIND:-} == 1 ]] || fail "ZSH_AUTOSUGGEST_MANUAL_REBIND must be 1"
  [[ $WORDCHARS != */* ]] || fail "WORDCHARS must not contain / (Ctrl+Backspace should stop at path segments)"
  [[ $EDITOR == nvim && $VISUAL == nvim ]] || fail "EDITOR and VISUAL must be nvim"
  [[ -o NULL_GLOB ]] && fail "NULL_GLOB is on after sourcing 40-options.zsh"
  exit 0
) || exit 1

# --- colored messages are real escapes, and echo interprets \n without -e ---
(
  emulate -L zsh
  source "$root/config/color.zsh"
  [[ $BGreen == $'\e['* ]] || fail "BGreen must start with a literal ESC, got ${(q)BGreen}"
  [[ $Color_Off == $'\e[0m' ]] || fail "Color_Off must be a real reset sequence"
  out=$(echo 'a\nb'); [[ $out == $'a\nb' ]] || fail "echo must interpret \\n without -e, got ${(q)out}"
  out=$(echo -e 'a\nb'); [[ $out == $'a\nb' ]] || fail "echo -e must keep working"
  out=$(echo -n x; echo y); [[ $out == xy ]] || fail "echo -n must suppress the newline"
  out=$(echo "~40% smaller"); [[ $out == "~40% smaller" ]] || fail "echo must not prompt-expand %, got ${(q)out}"
  out=$(echo "${BGreen}ok${Color_Off}"); [[ $out == $'\e[1;32mok\e[0m' ]] || fail "colored echo must emit escapes"
  exit 0
) || exit 1

# --- safety globs and guards ---
grep -F -q '*.m4b(N)' "$root/config/utils/file.zsh" \
  || fail "the m4b loop needs (N) once NULL_GLOB is no longer global"
grep -F -q 'Library/Python"/*(N)' "$root/config/python.zsh" || fail "python.zsh user-bin loop needs (N)"
grep -E -q '\-f .*\.local/bin/env' "$root/base.zsh" || fail "base.zsh must guard the uv env source with -f"

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

# --- pgrep is not shadowed; eza la flags stay eza-0.23-safe ---
(
  emulate -L zsh
  source "$root/config/alias.zsh"
  if [[ $(alias pgrep 2>/dev/null) == *ugrep* ]]; then
    fail "pgrep must not alias to ugrep"
  fi
  if command -v ugrep >/dev/null; then
    [[ $(alias upgrep 2>/dev/null) == *ugrep* ]] || fail "upgrep should wrap ugrep -P"
  fi
  if alias open-cli >/dev/null 2>&1; then
    fail "open-cli must be a PATH binary, not a zsh alias"
  fi
  if (( $+commands[eza] )); then
    (( $+aliases[la] )) || fail "la alias missing when eza is installed"
    [[ $aliases[la] == *'-laFh'* ]] && fail "la must not glue flags after -F (eza parses -laFh as --classify=h)"
    [[ $aliases[la] == *'--classify='* ]] || fail "la should set --classify=… explicitly"
    # Smoke the resolved argv so a glued -F regresses here, not only on the new Mac.
    eval "$aliases[la]" >/dev/null || fail "la alias must run successfully"
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

# --- git helpers work from a nested directory and a worktree, like git does ---
(
  cd "$repo"
  mkdir -p sub/deep
  cd sub/deep
  _git_var >/dev/null 2>&1 || exit 1
  [[ $CURRENT_BRANCH == feature ]] || exit 1
  [[ $DEFAULT_BRANCH_NAME == main ]] || exit 1
) || fail "_git_var must work two directories below the repo root"
(
  cd "$repo"
  git worktree add -q "$repo-wt" main 2>/dev/null || exit 1
  cd "$repo-wt"
  _git_var >/dev/null 2>&1 || exit 1
  [[ $CURRENT_BRANCH == main ]] || exit 1
) || fail "_git_var must work inside a worktree (.git is a file there)"
rm -rf "$repo-wt"
rm -rf "$repo"

print "OK foundation"
exit 0
