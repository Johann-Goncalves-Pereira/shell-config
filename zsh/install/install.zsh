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

check_machine

if [[ $machine == "Mac" ]] && ! command -v brew >/dev/null; then
  print "${BGreen}Installing Homebrew${Color_Off}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  print "${ICyan}Homebrew already available, or this is not a Mac${Color_Off}"
fi

if ! command -v brew >/dev/null; then
  print "${IRed}brew is required${Color_Off}"
  exit 1
fi

print "${BGreen}Installing shell tools from the Brewfile${Color_Off}"
brew bundle --file="${zsh_root}/install/Brewfile"

if ! command -v uv >/dev/null; then
  print "${BGreen}Installing uv${Color_Off}"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

if [[ -f "$HOME/.tool-versions" ]] && command -v mise >/dev/null; then
  print "${BGreen}Installing versions from ~/.tool-versions${Color_Off}"
  MISE_GLOBAL_CONFIG_FILE="${zsh_root}/config/mise.toml" mise install --yes || true
fi

print -n "Install JetBrainsMono Nerd Font? [y/N] "
read -r install_font
case "$install_font" in
  [yY] | [yY][eE][sS])
    brew install --cask font-jetbrains-mono-nerd-font || true
    ;;
  *)
    print "${ICyan}Skipping Nerd Font${Color_Off}"
    ;;
esac

link_config "${zsh_root}/zshenv.zsh" "$HOME/.zshenv"
link_config "${zsh_root}/zprofile.zsh" "$HOME/.zprofile"
link_config "${zsh_root}/base.zsh" "$HOME/.zshrc"

print "${BGreen}Shell config linked. Open a new terminal.${Color_Off}"
