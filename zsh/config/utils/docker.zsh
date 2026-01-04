# > -------------------------- < #
# >  Docker CLI Configuration  < #
# > -------------------------- < #

# Added Docker CLI to PATH
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# Docker CLI completions
fpath=(/Users/johannpereira/.docker/completions $fpath)
if ! type zinit >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i 2>/dev/null || true
fi

# > --------------- < #
# >  Docker Utils  < #
# > --------------- < #

# Stop all docker containers and remove them.
function docker_clean() {
  echo -e "${BYellow}Stopping all containers from your local storage.${Color_Off}\n"
  docker ps -a -q | xargs docker stop

  echo -n "\nAre you sure you want to remove all containers? $DEFAULT_YES "
  read -r answer
  if [[ $answer =~ ^([nN]|[nN])$ ]]; then
    echo -e "${Cyan}Process canceled.${Color_Off}\n"
  else
    echo -e "${BRed}Removing all containers from your local storage.${Color_Off}\n"
    docker system prune -f
  fi
}

# Clean full Docker
function docker_full_clean() {
  echo -e "${BRed}This will clean all containers and images from your local storage.${Color_Off}\n"

  echo -n "Are you sure you want to remove all containers? $DEFAULT_NO "
  read -r answer
  if [[ $answer =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # docker rmi $(docker images -q)
    docker ps -a -q | xargs docker rm -f
    docker images -q | xargs docker rmi -f
  else
    echo -e "${Cyan}Process canceled.${Color_Off}\n"
  fi
}
