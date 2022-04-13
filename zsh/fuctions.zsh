# Reload shell
function reload() {
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
  DEFAULT_BRANCH_NAME=$(basename $DEFAULT_BRANCH)

  echo $DEFAULT_BRANCH_NAME
}

# This func go to default branch pull/fetche everyting from base.
function gcdp() {
  get-default-branch

  echo -e "${Red}Going to $DEFAULT_BRANCH_NAME branch, and making a pull/fetch of your porject.${Color_Off}\n"
  git checkout $DEFAULT_BRANCH_NAME && git pull && git fetch origin
}

# This will purge all the git branches that are not usefull anymore.
function git-purge() {
  get-default-branch

  echo -e "${Red}Purging all branchs, except $DEFAULT_BRANCH_NAME - from your local storage.${Color_Off}\n"
  git branch | grep -v $DEFAULT_BRANCH_NAME | xargs git branch -D
  git remote prune origin
}

# Push to remote
function gps() {
  CURRENT_BRANCH=$(git branch --show-current)

  echo -e "${Cyan}Pushing to remote...\e${Color_Off}"
  git push origin $CURRENT_BRANCH
}

# Stop all docker containers and remove them.
function docker-clean() {
  echo -e "${BYellow}Stopping all containers from your local storage.${Color_Off}\n"
  docker ps -a -q | xargs docker stop
  echo -e "${BRed}Removing all containers from your local storage.${Color_Off}\n"
  docker system prune -f
}

# Clean full Docker
function docker-full-clean() {
  echo -e "${BRed}Cleaning all containers and images from your local storage.${Color_Off}\n"
  # docker rmi $(docker images -q)
  docker ps -a -q | xargs docker rm -f
  docker images -q | xargs docker rmi -f
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
