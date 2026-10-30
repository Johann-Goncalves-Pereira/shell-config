#!/usr/bin/env bash
# Poll until lab phone ADB appears, then arm never-touch-screen profile.
# Safe to leave running; exits after successful arm.
set -euo pipefail

phone_src="$(cd "$(dirname "$0")" && pwd)"
bin="$phone_src/target/release/phone"
log="${PHONE_BOOTSTRAP_LOG:-$HOME/.config/phone-adb/bootstrap-always-on.log}"
mkdir -p "$(dirname "$log")"

export CARGO_HOME="${CARGO_HOME:-$phone_src/.cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$phone_src/target}"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$log"; }

"$phone_src/adb-unquarantine.sh" || true

if [[ ! -x "$bin" ]]; then
  command -v cargo >/dev/null || {
    log "error: cargo missing and phone binary not built"
    exit 1
  }
  cargo build --release --manifest-path "$phone_src/Cargo.toml" --quiet
fi

log "waiting for ADB device (USB mtp/adb or wireless :5555)..."
attempt=0
while true; do
  attempt=$((attempt + 1))
  # Prefer USB; also poke saved wireless hosts (short timeout).
  adb start-server >/dev/null 2>&1 || true
  for host in $(
    { cat "$HOME/.config/phone-adb/host" 2>/dev/null
      cat "$HOME/.config/phone-adb/wan-host" 2>/dev/null; } | sed '/^$/d'
  ); do
    timeout 3 adb connect "$host" >/dev/null 2>&1 || true
  done

  state="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}')"
  if [[ -n "$state" ]]; then
    log "ADB device online: $state — arming persist + watch + screen off"
    "$bin" persist 2>&1 | tee -a "$log"
    "$bin" watch 2>&1 | tee -a "$log"
    "$bin" screen off 2>&1 | tee -a "$log" || true
    "$bin" --json status 2>&1 | tee -a "$log"
    log "done — phone should stay reachable without the panel"
    exit 0
  fi

  if (( attempt % 12 == 0 )); then
    product="$(
      ioreg -p IOService -n SAMSUNG_Android -r 2>/dev/null |
        awk -F'= ' '/idProduct/ {print $2; exit}'
    )"
    log "still waiting (attempt $attempt, usb idProduct=${product:-none})"
  fi
  sleep 5
done
