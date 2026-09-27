# Extra binaries. Directories that are missing are skipped.
# `typeset -U path` in zshenv collapses duplicates.
_prepend_path() {
  [[ -d $1 ]] || return 0
  path=("$1" $path)
  export PATH
}

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"
_prepend_path "$BUN_INSTALL/bin"

export PNPM_HOME="$HOME/Library/pnpm"
_prepend_path "$PNPM_HOME"

_prepend_path "$HOME/.local/bin"
_prepend_path "$HOME/.lmstudio/bin"
_prepend_path /usr/local/bin

if [[ -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  _prepend_path "$ANDROID_HOME/emulator"
  _prepend_path "$ANDROID_HOME/tools/bin"
  _prepend_path "$ANDROID_HOME/tools"
  _prepend_path "$ANDROID_HOME/platform-tools"
fi

_prepend_path "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/imagemagick-full/bin"
_prepend_path "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/ffmpeg-full/bin"
_prepend_path "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/curl/bin"
if [[ -d "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/curl/lib/pkgconfig" ]]; then
  export PKG_CONFIG_PATH="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/curl/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
fi

_prepend_path "/Applications/Docker.app/Contents/Resources/bin"

[[ -d "$HOME/.emacs.d" ]] && export EMACSD="$HOME/.emacs.d"

unfunction _prepend_path
