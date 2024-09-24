# > ------------ < #
# > Reload shell < #
# > ------------ < #

function reload() {
  exec zsh
}
alias re='reload'

# > --------------- < #
# >  Git Functions  < #
# > --------------- < #

NOT_IN_GIT="\n ${Red}[Error]:${Color_Off} There is not a git repository in this folder!"
_git_var() {
  if [ -d .git ]; then
    CURRENT_BRANCH=$(git branch --show-current)
    DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD)
    status_simbolic=$?

    if [ $status_simbolic -eq 0 ]; then
      DEFAULT_BRANCH_NAME=$(basename $DEFAULT_BRANCH)
    else
      echo -e "\n"
      echo "${Red}[Error]:${Color_Off} could not find your default branch automatically!"
      echo -n "Type your default branch name: "
      read opt
      DEFAULT_BRANCH_NAME=$opt
    fi

  fi
}

function print-default-branch() {
  if [ -d .git ]; then
    _git_var
    echo -e "Your default branch is: ${UGreen}$DEFAULT_BRANCH_NAME${Color_Off}\n"
  else
    echo -e $NOT_IN_GIT
  fi
}

# Push to remote
function gps() {
  if [ -d .git ]; then
    _git_var
    echo -e "${Cyan}Pushing to remote...\n${Color_Off}"
    git push origin "$CURRENT_BRANCH"
  else
    echo -e $NOT_IN_GIT
  fi
}

function gpo() {
  if [ -d .git ]; then
    _git_var
    echo -e "${Cyan}Pulling from remote origin $CURRENT_BRANCH \n${Color_Off}"
    git pull origin "$CURRENT_BRANCH"
    git fetch origin
  else
    echo -e $NOT_IN_GIT
  fi
}

# This func goes to the default branch, pulls/fetches everything from the base.
function gcdp() {
  if [ -d .git ]; then
    _git_var
    echo -e "${BPurple}Checking out to the branch $DEFAULT_BRANCH_NAME${Color_Off}"
    git checkout "$DEFAULT_BRANCH_NAME"
    gpo
  else
    echo -e $NOT_IN_GIT
  fi
}

# This will purge all the git branches that are not useful anymore.
function git-purge() {
  get-default-branch

  echo -e "${BRed}Purging all branches, except $DEFAULT_BRANCH - from your local storage.${Color_Off}\n"

  echo -n "Are you sure you want to remove all branches? $DEFAULT_YES "
  read -r answer
  if [[ $answer =~ ^([nN]|[nN])$ ]]; then
    echo -e "${Cyan}Aborted.${Color_Off}\n"
  else
    git branch | grep -v "$DEFAULT_BRANCH" | xargs git branch -D
    git remote prune origin
  fi
}

# > ------------------ < #
# >  Docker Functions  < #
# > ------------------ < #

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

# > ------- < #
# >  Utils  < #
# > ------- < #

# Config the auto cd path
function expand-dots() {
  local MATCH
  if [[ $LBUFFER =~ '\.\.\.+' ]]; then
    LBUFFER=$LBUFFER:fs%\.\.\.%../../%
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

function compress_mp3() {
  for f in **/*.mp3; do
    lame --mp3input -b 64 --resample 22.50 "$f" "$(echo "$f" | sed 's/\(.*\)\.mp3/\1 - compressed.mp3/')" && trash "$f"
  done
}

# Function to convert m4b audiobook files to mp3 format with chapters.
# This function uses ffmpeg to convert the audio file to mp3 format and split it into chapters.
# It also adds metadata to each chapter file using id3v2.
function convert_m4b_audiobook_to_mp3_with_chapters() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ${BICyan}ffmpeg${Color_Off} is not installed. Please install it and try again."
    return
  fi
  if ! command -v m4b-tool >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ${BICyan}m4b-tool${Color_Off} is not installed. Please install it and try again."
    return
  fi

  # Loop through all .m4b files in the current directory
  for audiobook_path in *.m4b; do
    echo -n "Converting ${BICyan}$audiobook_path${Color_Off} to mp3 format with chapters...\n"
    m4b-tool split --audio-format mp3 --audio-bitrate 96k --audio-channels 2 --audio-samplerate 22050 "$audiobook_path"
  done
}

direnv-nvm() {
  vared -p "What version do you want to use? " -c version

  echo "use nodejs $version" >.envrc
  direnv allow
}
