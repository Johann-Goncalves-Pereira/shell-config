# > -------------------------- < #
# >  Docker CLI Configuration  < #
# > -------------------------- < #

# Docker CLI path is added from config/70-path.zsh.
# Completions are added from config/50-completions.zsh.

# > --------------- < #
# >  Docker Utils  < #
# > --------------- < #

# Ensure a Docker daemon is reachable (macOS: Colima, Docker Desktop, or OrbStack).
function docker_ensure_running() {
  if docker info &>/dev/null; then
    return 0
  fi

  echo "${BYellow}Docker daemon is not running. Trying to start it...${Color_Off}"

  if command -v colima &>/dev/null; then
    if ! colima status 2>/dev/null | command grep -q 'Running'; then
      colima start
    fi
    docker context use colima &>/dev/null || true
  elif [[ -d /Applications/Docker.app ]]; then
    open -ga Docker
  elif command -v orbctl &>/dev/null; then
    orbctl start
  else
    echo "No Docker runtime found. Install Colima (brew install colima) or Docker Desktop."
    return 1
  fi

  local i=0
  while (( i < 90 )); do
    if docker info &>/dev/null; then
      return 0
    fi
    sleep 2
    (( i += 2 ))
  done

  echo "Docker daemon did not become ready in time."
  return 1
}

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
