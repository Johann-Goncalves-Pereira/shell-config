# > -------------------------- < #
# >  Docker CLI Configuration  < #
# > -------------------------- < #

# Docker CLI path is added from config/70-path.zsh.
# Completions are added from config/50-completions.zsh.

# > --------------- < #
# >  Docker Utils  < #
# > --------------- < #

# Stop all docker containers and remove them.
function docker_clean() {
  echo -e "${BYellow}Stopping all containers from your local storage.${Color_Off}\n"
  local -a ids
  ids=("${(@f)$(docker ps -aq)}")
  ids=("${ids[@]:#}")
  (( ${#ids} )) && docker stop "${ids[@]}"

  echo -n "\nAre you sure you want to remove all containers? $DEFAULT_YES "
  read -r answer
  if [[ $answer =~ ^[nN]$ ]]; then
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
    local -a ids images
    ids=("${(@f)$(docker ps -aq)}")
    ids=("${ids[@]:#}")
    images=("${(@f)$(docker images -q)}")
    images=("${images[@]:#}")
    (( ${#ids} )) && docker rm -f "${ids[@]}"
    (( ${#images} )) && docker rmi -f "${images[@]}"
  else
    echo -e "${Cyan}Process canceled.${Color_Off}\n"
  fi
}
