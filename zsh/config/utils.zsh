UTILS="$USER_CONFIG_DIRECTORY/config/utils"

[ -f $UTILS/docker.zsh ] && source $UTILS/docker.zsh
[ -f $UTILS/shell.zsh ] && source $UTILS/shell.zsh
[ -f $UTILS/file.zsh ] && source $UTILS/file.zsh
[ -f $UTILS/git.zsh ] && source $UTILS/git.zsh
[ -f $UTILS/audio.zsh ] && source $UTILS/audio.zsh
[ -f $UTILS/phone.zsh ] && source $UTILS/phone.zsh

function update_webui() {
  echo "\n\n${BGreen}Updating WebUI + SearXNG...${Color_Off}\n\n"

  local network_name="open-webui-net"
  local searxng_image="docker.io/searxng/searxng:latest"
  local searxng_name="searxng"
  local searxng_config="$HOME/Developer/programs/searxng"
  local webui_image="ghcr.io/open-webui/open-webui:main"
  local webui_name="open-webui"
  local image_before latest_id needs_recreate

  if ! command -v docker &>/dev/null; then
    echo "Docker is not available. Skipping WebUI/SearXNG update."
    return 1
  fi

  if ! docker info &>/dev/null; then
    echo "Docker daemon is not running. Skipping WebUI/SearXNG update."
    return 1
  fi

  if ! docker network inspect "$network_name" &>/dev/null; then
    echo "Creating Docker network $network_name..."
    docker network create "$network_name"
  fi

  # --- SearXNG ---
  echo "Updating SearXNG..."
  image_before=""
  if docker inspect "$searxng_name" &>/dev/null; then
    image_before=$(docker inspect -f '{{.Image}}' "$searxng_name" 2>/dev/null)
  fi

  docker pull "$searxng_image"
  latest_id=$(docker image inspect -f '{{.Id}}' "$searxng_image" 2>/dev/null)
  needs_recreate=false

  if ! docker inspect "$searxng_name" &>/dev/null; then
    needs_recreate=true
  elif [[ -n "$latest_id" && "$image_before" != "$latest_id" ]]; then
    needs_recreate=true
  fi

  if [[ "$needs_recreate" == true ]]; then
    echo "Starting SearXNG..."
    docker stop "$searxng_name" 2>/dev/null || true
    docker rm "$searxng_name" 2>/dev/null || true
    docker run -d \
      --name "$searxng_name" \
      --restart always \
      --network "$network_name" \
      -p 8888:8080 \
      -v "$searxng_config:/etc/searxng:rw" \
      "$searxng_image"
    echo "SearXNG started."
  elif ! docker ps -q --filter "name=^${searxng_name}$" | command grep -q .; then
    echo "SearXNG exists but is stopped. Starting..."
    docker start "$searxng_name"
    if ! docker inspect -f '{{json .NetworkSettings.Networks}}' "$searxng_name" 2>/dev/null | command grep -q "$network_name"; then
      docker network connect "$network_name" "$searxng_name" 2>/dev/null || true
    fi
    echo "SearXNG started."
  else
    if ! docker inspect -f '{{json .NetworkSettings.Networks}}' "$searxng_name" 2>/dev/null | command grep -q "$network_name"; then
      docker network connect "$network_name" "$searxng_name" 2>/dev/null || true
    fi
    echo "SearXNG is already up to date and running."
  fi

  # --- Open WebUI ---
  echo "Updating Open WebUI..."
  image_before=""
  if docker inspect "$webui_name" &>/dev/null; then
    image_before=$(docker inspect -f '{{.Image}}' "$webui_name" 2>/dev/null)
  fi

  docker pull "$webui_image"
  latest_id=$(docker image inspect -f '{{.Id}}' "$webui_image" 2>/dev/null)
  needs_recreate=false

  if ! docker inspect "$webui_name" &>/dev/null; then
    needs_recreate=true
  else
    if [[ -n "$latest_id" && "$image_before" != "$latest_id" ]]; then
      needs_recreate=true
    fi
    if ! docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$webui_name" 2>/dev/null | command grep -q '^WEB_SEARCH_ENGINE=searxng$'; then
      needs_recreate=true
    fi
    if ! docker inspect -f '{{json .NetworkSettings.Networks}}' "$webui_name" 2>/dev/null | command grep -q "$network_name"; then
      needs_recreate=true
    fi
  fi

  if [[ "$needs_recreate" == true ]]; then
    echo "Starting Open WebUI with SearXNG web search..."
    docker stop "$webui_name" 2>/dev/null || true
    docker rm "$webui_name" 2>/dev/null || true
    docker run -d \
      --name "$webui_name" \
      --restart always \
      --network "$network_name" \
      --add-host=host.docker.internal:host-gateway \
      -p 39237:8080 \
      -v open-webui:/app/backend/data \
      -e ENABLE_WEB_SEARCH=True \
      -e WEB_SEARCH_ENGINE=searxng \
      -e WEB_SEARCH_RESULT_COUNT=3 \
      -e WEB_SEARCH_CONCURRENT_REQUESTS=10 \
      -e 'SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>' \
      "$webui_image"
    echo "Open WebUI started."
  elif ! docker ps -q --filter "name=^${webui_name}$" | command grep -q .; then
    echo "Open WebUI exists but is stopped. Starting..."
    docker start "$webui_name"
    echo "Open WebUI started."
  else
    echo "Open WebUI is already up to date and running."
  fi
}

function optimize_homebrew_taps() {
  if ! command -v brew &>/dev/null; then
    return
  fi

  local did_untap=false

  if brew tap | command grep -qx "homebrew/core"; then
    echo "Untapping homebrew/core to use Homebrew API by default..."
    brew untap homebrew/core
    did_untap=true
  fi

  if brew tap | command grep -qx "homebrew/cask"; then
    echo "Untapping homebrew/cask to use Homebrew API by default..."
    brew untap homebrew/cask
    did_untap=true
  fi

  if [[ "$did_untap" == false ]]; then
    echo "Homebrew taps already optimized for API installs."
  fi
}

function update() {
  echo -e "${BGreen}Optimizing Homebrew taps...${Color_Off}\n"
  optimize_homebrew_taps

  echo -e "\n\n${BGreen}Updating with Homebrew...${Color_Off}\n"
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

  brew cleanup --prune=all && rm -f $ZSH_COMPDUMP

  echo "\n\n${BGreen}Update completed.${Color_Off}\n\n"
}



direnv_nvm() {
  vared -p "What version do you want to use? " -c version

  echo "use nodejs $version" >.envrc
  direnv allow
}

# Recursively inspect/strip image metadata in the current directory (Charm TUI).
strip_image() {
  if ! command -v go >/dev/null; then
    echo "go is required to run strip_image." >&2
    return 1
  fi
  local src="$USER_CONFIG_DIRECTORY/scripts/strip_image"
  local bindir
  go -C "$src" install ./cmd/strip_image || return
  bindir="$(go env GOBIN)"
  [[ -z "$bindir" ]] && bindir="$(go env GOPATH)/bin"
  "$bindir/strip_image" "$@"
}

clean_node_modules() {
  local target_dir
  target_dir="${1:-.}"

  echo "Searching for node_modules under: $target_dir"

  # Find and delete all node_modules directories under target_dir
  find "$target_dir" -type d -name node_modules -prune -print | while read -r dir; do
    echo "Removing: $dir"
    trash "$dir"
  done
}
