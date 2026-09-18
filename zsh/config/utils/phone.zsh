# > ---------------------- < #
# >  Phone lab (Rust CLI)  < #
# > ---------------------- < #
# Thin wrapper — all logic in scripts/phone (Rust).

phone() {
  if ! command -v cargo >/dev/null; then
    echo -e "${BRed}Error:${Color_Off} cargo is required for the phone CLI." >&2
    return 1
  fi
  local src="$USER_CONFIG_DIRECTORY/scripts/phone"
  local bin="$src/target/release/phone"
  export CARGO_HOME="${CARGO_HOME:-$src/.cargo-home}"
  export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$src/target}"
  local need_build=false
  if [[ ! -x "$bin" || "$src/Cargo.toml" -nt "$bin" ]]; then
    need_build=true
  else
    local f
    for f in "$src"/src/*.rs; do
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

alias pm='phone mirror'
alias pstatus='phone status'
alias pshell='phone shell'
alias pconnect='phone connect'
alias ptcpip='phone tcpip'
alias pusb='phone usb'
alias plock='phone lock'
alias pharden='phone harden'
alias pprep='phone prep'
alias ppersist='phone persist'
alias pwatch='phone watch'
alias punwatch='phone unwatch'
alias pwan='phone wan'
alias ptscale='phone tailscale'
alias pscreen='phone screen'
alias pscreenoff='phone screen off'
alias pscreenon='phone screen on'
alias pscreenguard='phone screen guard'
alias pshot='phone shot'
alias pui='phone ui'
alias ptap='phone tap'
alias ptype='phone type'
alias pkey='phone key'
alias plaunch='phone launch'
alias pcurrent='phone current'
