UTILS="$USER_CONFIG_DIRECTORY/config/utils"

[ -f $UTILS/widgets.zsh ] && source $UTILS/widgets.zsh
[ -f $UTILS/docker.zsh ] && source $UTILS/docker.zsh
[ -f $UTILS/shell.zsh ] && source $UTILS/shell.zsh
[ -f $UTILS/file.zsh ] && source $UTILS/file.zsh
[ -f $UTILS/git.zsh ] && source $UTILS/git.zsh
[ -f $UTILS/audio.zsh ] && source $UTILS/audio.zsh
[ -f $UTILS/phone.zsh ] && source $UTILS/phone.zsh
[ -f $UTILS/ukvdavi.zsh ] && source $UTILS/ukvdavi.zsh

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

  if ! docker_ensure_running; then
    echo "Skipping WebUI/SearXNG update."
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

# update [--webui]
# The WebUI/SearXNG step starts Docker and pulls two images, so it is opt-in.
function update() {
  local with_webui=0 arg
  for arg in "$@"; do
    case "$arg" in
      --webui) with_webui=1 ;;
      *)
        echo -e "${BRed}Error:${Color_Off} Unknown option: $arg"
        echo "Usage: update [--webui]"
        return 1
        ;;
    esac
  done

  echo -e "${BGreen}Optimizing Homebrew taps...${Color_Off}\n"
  optimize_homebrew_taps

  echo -e "\n\n${BGreen}Updating with Homebrew...${Color_Off}\n"
  brew update
  brew upgrade
  if command -v mas >/dev/null; then
    echo -e "${BGreen}Updating apps with MAS...${Color_Off}\n"
    mas upgrade
  fi

  if (( $+functions[antidote] )); then
    echo "\n\n${BGreen}Updating plugins...${Color_Off}\n\n"
    antidote update
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zsh_plugins.zsh"
  fi

  echo "\n\n${BGreen}Updating Javascript...${Color_Off}\n\n"

  if command -v corepack >/dev/null; then
    corepack install -g npm@latest
    corepack install -g pnpm@latest
    corepack up
  fi

  if command -v mise >/dev/null; then
    echo "\n\n${BGreen}Updating mise tools...${Color_Off}\n\n"
    mise upgrade
  fi

  if command -v atuin >/dev/null; then
    local atuin_comp="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
    mkdir -p "$atuin_comp"
    atuin gen-completions --shell zsh >"${atuin_comp}/_atuin" 2>/dev/null || true
  fi

  if (( with_webui )); then
    update_webui
  else
    echo "\n${BGreen}Skipping WebUI/SearXNG (run \`update --webui\` to include it).${Color_Off}\n"
  fi

  # One cleanup at the end. Dropping the compdump and the cached init scripts
  # makes the next shell pick up new completions and upgraded tools.
  brew cleanup --prune=all
  rm -f "$ZSH_COMPDUMP" "$ZSH_COMPDUMP.zwc" "${XDG_CACHE_HOME:-$HOME/.cache}"/zsh/init-*.zsh(N)

  echo "\n\n${BGreen}Update completed.${Color_Off}\n\n"
}



direnv_nvm() {
  local version=""
  vared -p "What node version do you want to use? " -c version
  if [[ -z $version ]]; then
    echo "No version given."
    return 1
  fi
  if ! command -v mise >/dev/null; then
    echo "mise is not installed."
    return 1
  fi
  mise use --path . "node@${version}" || return
  if [[ ! -f .envrc ]] || ! grep -q 'use mise' .envrc; then
    print 'use mise' >> .envrc
  fi
  if command -v direnv >/dev/null; then
    direnv allow
  fi
}

# Recursively inspect/strip image metadata in the current directory (Charm TUI).
strip_image() {
  if ! command -v go >/dev/null; then
    echo "go is required to run strip_image." >&2
    return 1
  fi
  local src="$USER_CONFIG_DIRECTORY/scripts/strip_image"
  local bindir bin newest
  bindir="$(go env GOBIN)"
  [[ -z "$bindir" ]] && bindir="$(go env GOPATH)/bin"
  bin="$bindir/strip_image"
  # Rebuild only when a source file is newer than the installed binary,
  # the same check phone and ukvdavi use.
  newest=""
  if [[ -x $bin ]]; then
    newest=$(find "$src" -type f \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' \) -newer "$bin" -print -quit 2>/dev/null)
  fi
  if [[ ! -x $bin || -n $newest ]]; then
    go -C "$src" install ./cmd/strip_image || return
  fi
  "$bin" "$@"
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
