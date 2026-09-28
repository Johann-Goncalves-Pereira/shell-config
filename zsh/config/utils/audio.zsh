# > ------------------------------- < #
# >  fix-call-audio (Rust + Swift)  < #
# > ------------------------------- < #
# Thin wrapper — all logic in scripts/fix-call-audio.

fix_call_audio() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${BRed}Error:${Color_Off} fix_call_audio only works on macOS." >&2
    return 1
  fi
  if ! command -v cargo >/dev/null; then
    echo -e "${BRed}Error:${Color_Off} cargo is required for fix-call-audio." >&2
    return 1
  fi

  local src="$USER_CONFIG_DIRECTORY/scripts/fix-call-audio"
  local bin="$src/target/release/fix-call-audio"
  export CARGO_HOME="${CARGO_HOME:-$src/.cargo-home}"
  export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$src/target}"

  local need_build=false
  if [[ ! -x "$bin" || "$src/Cargo.toml" -nt "$bin" ]]; then
    need_build=true
  else
    local f
    for f in "$src"/src/*.rs "$src"/swift/*.swift; do
      [[ -e "$f" && "$f" -nt "$bin" ]] && need_build=true && break
    done
  fi

  if [[ "$need_build" == true ]]; then
    cargo build --release --manifest-path "$src/Cargo.toml" --quiet \
      || cargo build --release --manifest-path "$src/Cargo.toml" \
      || return
  fi

  "$bin" "$@"
}

# True when the release binary is missing or older than its sources.
_fix_call_audio_outdated() {
  local src="$USER_CONFIG_DIRECTORY/scripts/fix-call-audio"
  local bin="${src}/target/release/fix-call-audio"
  local f
  [[ ! -x $bin || "$src/Cargo.toml" -nt $bin ]] && return 0
  for f in "$src"/src/*.rs "$src"/swift/*.swift; do
    [[ -e $f && $f -nt $bin ]] && return 0
  done
  return 1
}

# Ensure the LaunchAgent guard is loaded. A fresh binary runs in the
# background so the prompt is not blocked. A rebuild stays in the foreground
# so two shells do not compile at once.
if [[ "$(uname -s)" == "Darwin" && -o interactive && "${FIX_CALL_AUDIO_DISABLE:-0}" != "1" ]]; then
  if _fix_call_audio_outdated; then
    fix_call_audio watch >/dev/null 2>&1 || true
  else
    fix_call_audio watch >/dev/null 2>&1 &
    disown
  fi
fi
