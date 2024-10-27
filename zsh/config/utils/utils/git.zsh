NOT_IN_GIT="\n ${Red}[Error]:${Color_Off} There is not a git repository in this folder!\n"

_git_var() {
  if [ -d .git ]; then
    CURRENT_BRANCH=$(git branch --show-current)

    if [ -z "$CURRENT_BRANCH" ]; then
      echo "\n${Red}[Error]:${Color_Off} Could not determine the current branch.\n"
      return 1
    fi

    DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    status_simbolic=$?

    if [ $status_simbolic -ne 0 ] || [ -z "$DEFAULT_BRANCH" ]; then
      echo -e "\n${BYellow}[Warning]:${Color_Off} Trying to fix HEAD reference...\n"
      git_fix_head_ref
      DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    fi

    if [ -n "$DEFAULT_BRANCH" ]; then
      DEFAULT_BRANCH_NAME=$(basename "$DEFAULT_BRANCH")
    else
      echo -e "\n${BYellow}[Warning]:${Color_Off} Could not find your default branch automatically!\n"
      echo -n "Please enter the default branch name: "
      read -r DEFAULT_BRANCH_NAME
      if [ -z "$DEFAULT_BRANCH_NAME" ]; then
        echo "\n${Red}[Error]:${Color_Off} No branch name provided.\n"
        return 1
      fi
    fi
  else
    echo -e "\n${Red}[Error]:${Color_Off} This is not a git repository.\n"
    return 1
  fi
}

git_fix_head_ref() {
  # Fetch the origin to make sure we have all remote refs
  if ! git fetch origin &>/dev/null; then
    echo "\n${Red}[Error]:${Color_Off} Could not fetch HEAD refs from origin.\n"
    return 1
  fi

  # Determine the default branch name (usually 'main' or 'master')
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')

  # Check if we have found a default branch
  if [ -z "$default_branch" ]; then
    echo -e "\n${BYellow}[Warning]:${Color_Off} Could not determine the default branch. Please check the remote settings.\n"
    return 1
  fi

  # If we have found a default branch, set it as the symbolic ref for origin/HEAD
  if ! git remote set-head origin "$default_branch" &>/dev/null; then
    echo -e "\n${BYellow}[Warning]:${Color_Off} Could not set origin/HEAD to point to $default_branch.\n"
    return 1
  fi

  echo "\nSet origin/HEAD to point to $default_branch.\n"
}

git_squash_all_commits() {
  local message="$1"
  if [ -z "$message" ]; then
    echo "\nPlease provide a commit message.\n"
    return 1
  fi
  git reset --soft $(git rev-list --max-parents=0 HEAD) && git commit --amend -m "$message"
  echo "\nAll commits squashed into one with message: '$message'\n"
}

function print_default_branch() {
  if [ -d .git ]; then
    if ! _git_var; then
      echo -e "\n${Red}[Error]:${Color_Off} Could not determine the default branch. Please check the remote settings.\n"
      return 1
    fi

    echo -e "\nYour default branch is: ${UGreen}$DEFAULT_BRANCH_NAME${Color_Off}\n"
  else
    echo -e $NOT_IN_GIT
  fi
}

# Push to remote
function gps() {
  if [ -d .git ]; then
    _git_var
    if [ -n "$CURRENT_BRANCH" ]; then
      echo -e "\n${Cyan}[Progress]:${Color_Off} Pushing to remote...\n"
      git push origin "$CURRENT_BRANCH"
    else
      echo -e "\n${Red}[Error]:${Color_Off} Could not determine the current branch.\n"
    fi
  else
    echo -e $NOT_IN_GIT
  fi
}

function gpo() {
  if [ -d .git ]; then
    _git_var
    if [ -n "$CURRENT_BRANCH" ]; then
      echo -e "\n${Cyan}[Progress]:${Color_Off} Pulling from remote origin ${UGreen}$CURRENT_BRANCH${Color_Off}\n"
      git pull origin "$CURRENT_BRANCH"
      git fetch origin
    else
      echo -e "\n${Red}[Error]:${Color_Off} Could not determine the current branch.\n"
    fi
  else
    echo -e $NOT_IN_GIT
  fi
}

function gcdp() {
  if [ -d .git ]; then
    if ! _git_var; then
      echo -e "\n${Red}[Error]:${Color_Off} Failed to retrieve git variables.\n"
      return 1
    fi
    if [ -z "$DEFAULT_BRANCH_NAME" ]; then
      echo -e "\n${Red}[Error]:${Color_Off} Default branch name is empty.\n"
      return 1
    fi
    echo -e "\n${Cyan}[Progress]:${Color_Off} Trying to check out to the branch ${UGreen}$DEFAULT_BRANCH_NAME${Color_Off}\n"
    if ! git checkout "$DEFAULT_BRANCH_NAME"; then
      echo -e "\n${Red}[Error]:${Color_Off} Failed to checkout to $DEFAULT_BRANCH_NAME.\n"
      return 1
    fi
    gpo
  else
    echo -e $NOT_IN_GIT
  fi
}

# This will purge all the git branches that are not useful anymore.
function git_purge() {
  get-default-branch

  echo -e "\n${BRed}Purging all branches, except $DEFAULT_BRANCH - from your local storage.${Color_Off}\n"

  echo -n "Are you sure you want to remove all branches? $DEFAULT_YES "
  read -r answer
  if [[ $answer =~ ^([nN]|[nN])$ ]]; then
    echo -e "\n${Cyan}Aborted.${Color_Off}\n"
  else
    git branch | grep -v "$DEFAULT_BRANCH" | xargs git branch -D
    git remote prune origin
  fi
}
