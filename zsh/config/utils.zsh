UTILS="$USER_CONFIG_DIRECTORY/config/utils"

[ -f $UTILS/docker.zsh ] && source $UTILS/docker.zsh
[ -f $UTILS/shell.zsh ] && source $UTILS/shell.zsh
[ -f $UTILS/file.zsh ] && source $UTILS/file.zsh
[ -f $UTILS/git.zsh ] && source $UTILS/git.zsh

function update() {
  echo -e "${BGreen}Updating Homebrew...${Color_Off}\n"
  brew update
  brew upgrade
  brew cleanup
  echo "\n\n${BGreen}Updating Zinit...${Color_Off}\n\n"

  zinit update --parallel

  echo "\n\n${BGreen}Updating Javascript...${Color_Off}\n\n"

  npm install -g npm@latest
  npm install -g yarn@latest
  # pnpm self-update

  echo "\n\n${BGreen}Updating Asdf...${Color_Off}\n\n"

  asdf update
  asdf plugin update --all
}

direnv_nvm() {
  vared -p "What version do you want to use? " -c version

  echo "use nodejs $version" >.envrc
  direnv allow
}
