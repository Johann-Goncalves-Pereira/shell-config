#!/data/data/com.termux/files/usr/bin/bash
# Lab S23: keep USB on File transfer (MTP) via localhost adbd (shell UID).
# Started by Termux:Boot + nohup. Survives until process death; Boot restarts it.
# Self-heals: sshd watchdog + wireless debugging auto-connect + tcpip 5555 re-arm.
set -u
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_T="${HOME:-/data/data/com.termux/files/home}"
LOG="${HOME_T}/.phone-lab/usb-lab-guard.log"
HB=/sdcard/phone-lab/guard-heartbeat.txt
ADB_KEYS="${HOME_T}/.android"
mkdir -p "$(dirname "$LOG")" "$ADB_KEYS" /sdcard/phone-lab
export PATH="$PREFIX/bin:$PATH"
export HOME="$HOME_T"

log() {
  local line
  line="$(printf '%s %s\n' "$(date '+%F %T')" "$*")"
  printf '%s\n' "$line" >>"$LOG"
  printf '%s\n' "$line" >>"$HB" 2>/dev/null || true
}

ensure_wake_lock() {
  if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock >/dev/null 2>&1 || true
  fi
}

ensure_sshd() {
  if command -v sshd >/dev/null 2>&1; then
    if ! pidof sshd >/dev/null 2>&1; then
      log "sshd not running; starting on port 8022"
      sshd -p 8022 >/dev/null 2>&1 || true
    fi
  fi
}

ensure_keys() {
  if [[ -f /sdcard/phone-lab/adbkey && ! -s "$ADB_KEYS/adbkey" ]]; then
    cp /sdcard/phone-lab/adbkey "$ADB_KEYS/adbkey"
    cp /sdcard/phone-lab/adbkey.pub "$ADB_KEYS/adbkey.pub" 2>/dev/null || true
    chmod 600 "$ADB_KEYS/adbkey"
  fi
}

find_wireless_debug_port() {
  if ! command -v python >/dev/null 2>&1; then
    return 1
  fi
  python -c '
import socket
for p in range(35000, 48000):
    s = socket.socket()
    s.settimeout(0.002)
    if s.connect_ex(("127.0.0.1", p)) == 0:
        print(p)
    s.close()
' 2>/dev/null
}

adb_ready() {
  command -v adb >/dev/null 2>&1 || return 1
  ensure_keys
  adb start-server >/dev/null 2>&1 || true
  adb connect 127.0.0.1:5555 >/dev/null 2>&1 || true
  adb connect localhost:5555 >/dev/null 2>&1 || true

  if adb devices 2>/dev/null | grep -q $'\tdevice$'; then
    return 0
  fi

  # Port 5555 may not be listening after a cold reboot.
  # Scan for Android 11+ TLS Wireless Debugging port on loopback:
  local ports
  ports="$(find_wireless_debug_port)"
  for p in $ports; do
    [[ "$p" == "5555" || "$p" == "8022" ]] && continue
    adb connect "127.0.0.1:$p" >/dev/null 2>&1 || true
    if adb -s "127.0.0.1:$p" get-state 2>/dev/null | grep -q 'device'; then
      log "connected via wireless debug port $p; re-arming tcpip 5555"
      adb -s "127.0.0.1:$p" tcpip 5555 >/dev/null 2>&1 || true
      sleep 1
      adb connect 127.0.0.1:5555 >/dev/null 2>&1 || true
      break
    fi
  done

  adb devices 2>/dev/null | grep -q $'\tdevice$'
}

shell_adbd() {
  # Prefer loopback; emulator-5554 is adbd alias for the same device.
  local s
  s="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}')"
  [[ -n "$s" ]] || return 1
  adb -s "$s" shell "$@" 2>/dev/null
}

force_mtp() {
  ensure_wake_lock
  ensure_sshd

  if ! adb_ready; then
    log "adb not ready (is tcpip :5555 up?)"
    return 1
  fi

  # Keep tcpip and developer settings asserted
  shell_adbd 'setprop service.adb.tcp.port 5555' >/dev/null
  shell_adbd 'settings put global adb_wifi_enabled 1' >/dev/null
  shell_adbd 'settings put global stay_on_while_plugged_in 7' >/dev/null
  shell_adbd 'settings put global protect_battery 1' >/dev/null
  shell_adbd 'svc usb setScreenUnlockedFunctions mtp' >/dev/null
  shell_adbd 'svc usb setFunctions mtp' >/dev/null
  sleep 2
  adb connect 127.0.0.1:5555 >/dev/null 2>&1 || true
  local funcs
  funcs="$(shell_adbd 'svc usb getFunctions' | tr -d '\r' | tail -1)"
  log "usb functions=${funcs:-ok-empty}"
}

ensure_wake_lock
ensure_sshd
log "usb-lab-guard start pid=$$"
force_mtp || true

while true; do
  force_mtp || true
  sleep 20
done
