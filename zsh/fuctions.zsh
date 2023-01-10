# Reload shell
function reload() {
  clear
  echo -e "${Cyan}Reloading."
  sleep .5s
  clear
  echo -e "${Cyan}Reloading.."
  sleep .5s
  clear
  echo -e "${Cyan}Reloading...${Color_Off}"
  sleep .5s
  source ~/.zshrc
  clear
}

function get-default-branch() {
  DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD)
  status_simbolic=$?

  if [ $status_simbolic -eq 0 ]; then
    DEFAULT_BRANCH_NAME=$(basename $DEFAULT_BRANCH)
  else
    echo -e "\n"
    echo "${Red}[Error]:${Color_Off} could not find your default branch automatically!"
    echo -n "Type your default branch name: "
    read opt
    # echo "$opt"

    DEFAULT_BRANCH_NAME=$opt
  fi
}

# This func go to default branch pull/fetche everyting from base.
function gcdp() {
  get-default-branch

  echo -e "${BPurple}Going to the branch \"$DEFAULT_BRANCH_NAME\", and making a pull/fetch of your porject.${Color_Off}\n"
  git checkout $DEFAULT_BRANCH_NAME
  gpo
  git fetch origin
}

DEFAULT_NO="[${Green}y${Color_Off}/${Red}N${Color_Off}]"
DEFAULT_YES="[${Green}Y${Color_Off}/${Red}n${Color_Off}]"

# This will purge all the git branches that are not usefull anymore.
function git-purge() {
  get-default-branch

  echo -e "${BRed}Purging all branchs, except $DEFAULT_BRANCH_NAME - from your local storage.${Color_Off}\n"

  echo -n "Are you sure you want to remove all containers? $DEFAULT_YES "
  read -r answer
  if [[ $answer =~ ^([nN]|[nN])$ ]]; then
    echo -e "${Cyan}Aborted.${Color_Off}\n"
  else
    git branch | grep -v $DEFAULT_BRANCH_NAME | xargs git branch -D
    git remote prune origin
  fi
}

# Push to remote
function gps() {
  CURRENT_BRANCH=$(git branch --show-current)

  echo -e "${Cyan}Pushing to remote...\n${Color_Off}"
  git push origin $CURRENT_BRANCH
}

function gpo() {
  CURRENT_BRANCH=$(git branch --show-current)

  echo -e "${Cyan}Pull from remote origin ${CURRENT_BRANCH} \n${Color_Off}"
  git pull origin $CURRENT_BRANCH
}

# Stop all docker containers and remove them.
function docker-clean() {
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
function docker-full-clean() {
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

# Config the auto cd path
function expand-dots() {
  local MATCH
  if [[ $LBUFFER =~ '\.\.\.+' ]]; then
    LBUFFER=$LBUFFER:fs%\.\.\.%../..%
  fi
}

function expand-dots-then-expand-or-complete() {
  zle expand-dots
  zle expand-or-complete
}

function expand-dots-then-accept-line() {
  zle expand-dots
  zle accept-line
}

zle -N expand-dots
zle -N expand-dots-then-expand-or-complete
zle -N expand-dots-then-accept-line
bindkey '^I' expand-dots-then-expand-or-complete
bindkey '^M' expand-dots-then-accept-line

if [ -d "$HOME/.local/bin" ]; then
  PATH="$HOME/.local/bin:$PATH"
fi

# Fun
function fun-clock() {
  while true; do
    # Toilet make colors
    echo "$(date '+%D %T' | toilet -f term -F border --gay)"
    sleep 1
    clear
  done

}

function killport() {
  vared -p "What port do you want to kill? " -c port

  kill $(lsof -t -i:$port)
  status_simbolic=$?

  if [ $status_simbolic -eq 0 ]; then
    echo -e "${White}Killing port ${UGreen}$port${Color_Off}\n"
  else
    echo -e "${BRed}Fail to kill port"
  fi

  # kill -9 $(lsof -t -i:8080)
}
