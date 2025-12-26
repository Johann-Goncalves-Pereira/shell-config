UTILS="$USER_CONFIG_DIRECTORY/config/utils"

[ -f $UTILS/docker.zsh ] && source $UTILS/docker.zsh
[ -f $UTILS/shell.zsh ] && source $UTILS/shell.zsh
[ -f $UTILS/file.zsh ] && source $UTILS/file.zsh
[ -f $UTILS/git.zsh ] && source $UTILS/git.zsh

function update_webui() {
  echo "\n\n${BGreen}Updating WebUI...${Color_Off}\n\n"
  # Check if Open WebUI container exists
  if docker ps -q --filter "name=open-webui" | grep -q .; then
    # Container exists, proceed with update
    current_image=$(docker inspect open-webui 2>/dev/null | jq -r '.[0].Image')
    latest_image="ghcr.io/open-webui/open-webui:main"

    if [[ "$current_image" == "$latest_image" ]]; then
      echo "Open WebUI is already up to date."
    else
      echo "Updating Open WebUI..."
      docker pull "$latest_image"
      docker stop open-webui
      docker rm open-webui
      docker run -d -p 39237:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always "$latest_image"
      echo "Open WebUI updated."
    fi
  else
    # Container doesn't exist, inform the user
    echo "Open WebUI container not found. Please run it first."
    echo "You can start it with: docker run -d -p 39237:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main"
  fi
}

function update() {
  echo -e "${BGreen}Updating with Homebrew...${Color_Off}\n"
  brew update
  brew upgrade
  brew cleanup
  echo "\n\n${BGreen}Updating Zinit...${Color_Off}\n\n"

  echo -e "${BGreen}Updating apps with MAS...${Color_Off}\n"
  mas upgrade


  zinit update --parallel

  echo "\n\n${BGreen}Updating Javascript...${Color_Off}\n\n"

  corepack install -g npm@latest
  corepack install -g pnpm@latest
  corepack up

  echo "\n\n${BGreen}Updating Asdf...${Color_Off}\n\n"

  # asdf update
  asdf plugin update --all

  update_webui

  brew cleanup && rm -f $ZSH_COMPDUMP

  echo "\n\n${BGreen}Update completed.${Color_Off}\n\n"
}

direnv_nvm() {
  vared -p "What version do you want to use? " -c version

  echo "use nodejs $version" >.envrc
  direnv allow
}
