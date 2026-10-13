# Thin launcher. The gate itself lives in React-Playground/ukvdavi.

ukvdavi() {
  local app="${UKVDAVI_APP:-$HOME/Developer/personal/React-Playground/ukvdavi}"
  local cli="$app/dist/cli.js"
  if [[ ! -d $app ]]; then
    print -u2 "ukvdavi is not at $app"
    return 1
  fi
  local newest=""
  if [[ -f $cli ]]; then
    newest=$(find "$app/src" "$app/index.html" "$app/package.json" -type f -newer "$cli" -print -quit 2>/dev/null || true)
  fi
  if [[ ! -f $cli || -n $newest ]]; then
    (cd "$app" && command pnpm build) || return 1
  fi
  command node "$cli" "$@"
}
