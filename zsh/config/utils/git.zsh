NOT_IN_GIT="\n ${Red}[Error]:${Color_Off} There is not a git repository in this folder!\n"

_git_var() {
  if [ -d .git ] || [ -d ../.git ]; then
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
  if [ -d .git ] || [ -d ../.git ]; then
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
  if [ -d .git ] || [ -d ../.git ]; then
    _git_var
    if [ -n "$CURRENT_BRANCH" ]; then
      local push_args=()
      local arg
      for arg in "$@"; do
        case "$arg" in
          -f|--force|--force-with-lease|-u|--set-upstream|--no-verify)
            push_args+=("$arg")
            ;;
          *)
            echo -e "\n${Red}[Error]:${Color_Off} Unknown option: $arg\n"
            echo -e "Usage: gps [-f|--force|--force-with-lease] [-u|--set-upstream] [--no-verify]\n"
            return 1
            ;;
        esac
      done
      echo -e "\n${Cyan}[Progress]:${Color_Off} Pushing to remote...\n"
      git push "${push_args[@]}" origin "$CURRENT_BRANCH"
    else
      echo -e "\n${Red}[Error]:${Color_Off} Could not determine the current branch.\n"
    fi
  else
    echo -e $NOT_IN_GIT
  fi
}

function gpo() {
  if [ -d .git ] || [ -d ../.git ]; then
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
  if [ -d .git ] || [ -d ../.git ]; then
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

# Delete every local branch except the default. Default is yes.
function git_purge() {
  if ! _git_var; then
    return 1
  fi

  echo -e "\n${BRed}Purging all branches, except $DEFAULT_BRANCH_NAME - from your local storage.${Color_Off}\n"

  echo -n "Are you sure you want to remove all branches? $DEFAULT_YES "
  read -r answer
  if [[ $answer =~ ^[nN]$ ]]; then
    echo -e "\n${Cyan}Aborted.${Color_Off}\n"
    return 0
  fi

  if [[ -n $CURRENT_BRANCH && $CURRENT_BRANCH != "$DEFAULT_BRANCH_NAME" ]]; then
    echo -e "${BYellow}[Warning]:${Color_Off} Staying on ${CURRENT_BRANCH}. It will not be deleted.\n"
  fi

  local branch
  local -a doomed
  doomed=()
  while IFS= read -r branch; do
    [[ -z $branch || $branch == "$DEFAULT_BRANCH_NAME" || $branch == "$CURRENT_BRANCH" ]] && continue
    doomed+=("$branch")
  done < <(git branch --format='%(refname:short)')

  if (( ${#doomed} )); then
    git branch -D "${doomed[@]}"
  fi
  git remote prune origin
}
