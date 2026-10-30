#!/usr/bin/env zsh
# Fresh-machine installer for this shell config.
# Does not uninstall asdf or fnm. Does not install every Nerd Font.

setopt err_exit nounset pipefail

repo_root="${0:A:h:h:h}"
zsh_root="${repo_root}/zsh"

Color_Off='\033[0m'
BGreen='\033[1;32m'
IRed='\033[0;91m'
ICyan='\033[0;96m'

check_machine() {
  local uname_out
  uname_out="$(uname -s)"
  case "$uname_out" in
    Linux*) machine=Linux ;;
    Darwin*) machine=Mac ;;
    CYGWIN*) machine=Cygwin ;;
    MINGW*) machine=MinGw ;;
    MSYS_NT*) machine=MSys ;;
    *) machine="UNKNOWN:${uname_out}" ;;
  esac
  print -r -- "$machine"
}

ensure_brew_on_path() {
  if command -v brew >/dev/null; then
    return 0
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

link_config() {
  local src="$1" dest="$2"
  if [[ -L $dest ]]; then
    ln -sfn "$src" "$dest"
    return 0
  fi
  if [[ -e $dest ]]; then
    local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    print "Backing up ${dest} -> ${backup}"
    mv "$dest" "$backup"
  fi
  ln -s "$src" "$dest"
}

maybe_install_nerd_font() {
  local answer="${INSTALL_NERD_FONT:-}"
  if [[ -z $answer ]]; then
    if [[ ! -t 0 ]]; then
      print "${ICyan}Non-interactive: skipping Nerd Font (set INSTALL_NERD_FONT=1 to install)${Color_Off}"
      return 0
    fi
    print -n "Install JetBrainsMono Nerd Font? [y/N] "
    read -r answer
  fi
  case "$answer" in
    1 | [yY] | [yY][eE][sS])
      brew install --cask font-jetbrains-mono-nerd-font || true
      ;;
    *)
      print "${ICyan}Skipping Nerd Font${Color_Off}"
      ;;
  esac
}

check_machine

if [[ $machine != "Mac" ]]; then
  print "${IRed}This installer targets macOS. On Linux, install Homebrew first, then re-run.${Color_Off}"
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  print "${IRed}Xcode Command Line Tools are required (swiftc for fix-call-audio).${Color_Off}"
  print "Run: xcode-select --install"
  print "Then re-run ./setup"
  exit 1
fi

ensure_brew_on_path

if ! command -v brew >/dev/null; then
  print "${BGreen}Installing Homebrew${Color_Off}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ensure_brew_on_path
fi

if ! command -v brew >/dev/null; then
  print "${IRed}brew is required but was not found on PATH after install${Color_Off}"
  print "Open a new terminal or eval \"\$(/opt/homebrew/bin/brew shellenv)\" and re-run ./setup"
  exit 1
fi

# Homebrew 7+ refuses third-party taps until trusted.
if brew trust --help >/dev/null 2>&1; then
  brew trust --tap jandedobbeleer/oh-my-posh >/dev/null 2>&1 || true
fi

print "${BGreen}Installing shell tools from the Brewfile${Color_Off}"
brew bundle --file="${zsh_root}/install/Brewfile"

if [[ -x "${zsh_root}/scripts/phone/adb-unquarantine.sh" ]]; then
  "${zsh_root}/scripts/phone/adb-unquarantine.sh" || true
fi

if ! command -v uv >/dev/null; then
  print "${BGreen}Installing uv${Color_Off}"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Astral installs to ~/.local/bin
  [[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path) && export PATH
fi

if ! command -v cargo >/dev/null; then
  print "${BGreen}Installing Rust (rustup)${Color_Off}"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
if [[ -f "$HOME/.cargo/env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
fi

if command -v mise >/dev/null; then
  print "${BGreen}Installing versions from mise.toml${Color_Off}"
  MISE_GLOBAL_CONFIG_FILE="${zsh_root}/config/mise.toml" mise install --yes || true
fi

maybe_install_nerd_font

link_config "${zsh_root}/zshenv.zsh" "$HOME/.zshenv"
link_config "${zsh_root}/zprofile.zsh" "$HOME/.zprofile"
link_config "${zsh_root}/base.zsh" "$HOME/.zshrc"

if command -v cargo >/dev/null && command -v swiftc >/dev/null; then
  print "${BGreen}Best-effort: register fix_call_audio watch${Color_Off}"
  FIX_CALL_AUDIO_DISABLE=0 zsh -c '
    emulate -L zsh
    source "'"$HOME"'/.zshrc"
    fix_call_audio watch
  ' >/dev/null 2>&1 || print "${ICyan}fix_call_audio watch skipped (build later with: fix_call_audio watch)${Color_Off}"
fi

print "${BGreen}Shell config linked. Open a new terminal.${Color_Off}"
print "${ICyan}Optional: atuin login / atuin import; mise use -g go@latest python@3.13 ruby@3.2${Color_Off}"
