#!/bin/zsh
# Background guard: restore A2DP when HFP is detected, then hide the Bluetooth
# mic for the rest of this connection. Fresh BT connects leave the mic alone.

emulate -L zsh

USER_CONFIG_DIRECTORY="${USER_CONFIG_DIRECTORY:-$HOME/.shell-config/zsh}"
AUDIO_ZSH="$USER_CONFIG_DIRECTORY/config/utils/audio.zsh"

: "${BRed:=}"
: "${BGreen:=}"
: "${BYellow:=}"
: "${BCyan:=}"
: "${UGreen:=}"
: "${Color_Off:=}"

if [[ ! -f "$AUDIO_ZSH" ]]; then
  print -u2 -- "fix-call-audio-guard: missing $AUDIO_ZSH"
  exit 1
fi

FIX_CALL_AUDIO_DISABLE=1
source "$AUDIO_ZSH"

POLL_SECS="${FIX_CALL_AUDIO_POLL_SECS:-2}"
COOLDOWN="${FIX_CALL_AUDIO_RECONNECT_COOLDOWN:-20}"
last_reconnect=0
last_bt_uid=""

_log() {
  print -- "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

_fix_call_audio_guard_tick() {
  if ! command -v SwitchAudioSource &>/dev/null; then
    return 0
  fi

  local output input current_in current_out now uid

  # Track connection identity: new UID → clear hide session (mic available again).
  uid=$(_fix_call_audio_bt_output_uid 2>/dev/null) || uid=""
  if [[ -n "$last_bt_uid" && -n "$uid" && "$uid" != "$last_bt_uid" ]]; then
    _log "new BT connection ($uid) — mic available until HFP / fix_call_audio"
    _fix_call_audio_session_clear
  fi
  if [[ -z "$uid" && -n "$last_bt_uid" ]]; then
    _log "BT output gone — clearing hide session"
    _fix_call_audio_session_clear
  fi
  last_bt_uid="$uid"

  _fix_call_audio_session_sync

  output=$(_fix_call_audio_default_output 2>/dev/null) || return 0
  input=$(_fix_call_audio_default_input 2>/dev/null) || return 0

  current_in=$(SwitchAudioSource -t input -c 2>/dev/null)
  current_out=$(SwitchAudioSource -t output -c 2>/dev/null)

  if _fix_call_audio_hfp_active; then
    now=$(date +%s)
    if (( now - last_reconnect < COOLDOWN )); then
      SwitchAudioSource -t input -s "$input" >/dev/null 2>&1 || true
      _fix_call_audio_hide_bt_mic true >/dev/null 2>&1 || true
      return 0
    fi

    _log "HFP detected (input=$current_in) → hide BT mic + reconnect $output"
    if _fix_call_audio_enforce true true "$input" "$output" true >/dev/null 2>&1; then
      last_reconnect=$now
      if _fix_call_audio_hfp_active; then
        _log "reconnected but still HFP — re-hiding BT mic"
        _fix_call_audio_hide_bt_mic true >/dev/null 2>&1 || true
      else
        _log "restored A2DP; BT mic hidden for this connection"
      fi
    else
      _log "enforce failed while recovering from HFP"
    fi
    return 0
  fi

  # If this connection already hid the mic, keep HQ Call Mic / Mac as input.
  if _fix_call_audio_session_should_hide; then
    if [[ "$current_in" != "$input" ]]; then
      _log "session hide active — input $current_in → $input"
      SwitchAudioSource -t input -s "$input" >/dev/null 2>&1 || true
    fi
    # Re-assert stream hide periodically in case CoreAudio recreates BT input.
    _fix_call_audio_hide_bt_mic true >/dev/null 2>&1 || true
  elif [[ "$current_in" != "$input" ]] && ! _fix_call_audio_is_bt_device "$current_in" input; then
    # Don't auto-steal away from a deliberate non-BT mic unless HFP.
    :
  fi

  if [[ "$current_out" != "$output" ]]; then
    _log "output drifted to '$current_out' → $output"
    SwitchAudioSource -t output -s "$output" >/dev/null 2>&1 || true
  fi
}

_log "started (poll=${POLL_SECS}s cooldown=${COOLDOWN}s mode=hide-bt-mic-on-hfp)"

while true; do
  _fix_call_audio_guard_tick
  sleep "$POLL_SECS"
done
