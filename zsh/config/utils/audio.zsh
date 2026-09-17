# Force high-quality Bluetooth audio: Mac mic in + Bluetooth stereo out.
# When HFP is detected (or fix_call_audio is run), temporarily hide the
# Bluetooth headset microphone for this connection so apps cannot reopen it.
# A Bluetooth disconnect/reconnect restores the mic for the next session.

: "${FIX_CALL_AUDIO_LABEL:=com.shell-config.fix-call-audio}"
: "${FIX_CALL_AUDIO_PLIST:=$HOME/Library/LaunchAgents/${FIX_CALL_AUDIO_LABEL}.plist}"
: "${FIX_CALL_AUDIO_LOG:=$HOME/Library/Logs/fix-call-audio-guard.log}"
: "${FIX_CALL_AUDIO_GUARD:=${USER_CONFIG_DIRECTORY:-$HOME/.shell-config/zsh}/scripts/fix-call-audio-guard.zsh}"
: "${FIX_CALL_AUDIO_POLL_SECS:=2}"
: "${FIX_CALL_AUDIO_RECONNECT_COOLDOWN:=20}"
: "${FIX_CALL_AUDIO_HIDE_BIN:=${USER_CONFIG_DIRECTORY:-$HOME/.shell-config/zsh}/scripts/hide-bt-input}"
: "${FIX_CALL_AUDIO_HIDE_SRC:=${USER_CONFIG_DIRECTORY:-$HOME/.shell-config/zsh}/scripts/hide-bt-input.swift}"
: "${FIX_CALL_AUDIO_SESSION:=$HOME/Library/Caches/fix-call-audio-bt-session}"
: "${FIX_CALL_AUDIO_HQ_INPUT:=HQ Call Mic}"

# cli format: name,type,id,uid
_fix_call_audio_device_exists() {
  local name="$1"
  local type="$2"
  SwitchAudioSource -a -t "$type" 2>/dev/null | command grep -Fxq "$name"
}

_fix_call_audio_is_bt_uid() {
  local uid="$1"
  [[ "$uid" =~ '^[0-9A-Fa-f]{2}(-[0-9A-Fa-f]{2}){5}:(input|output)$' ]]
}

_fix_call_audio_uid_for() {
  local name="$1"
  local type="$2"
  local line
  line=$(SwitchAudioSource -a -f cli 2>/dev/null | command grep -F "${name},${type}," | head -n1)
  [[ -z "$line" ]] && return 1
  print -r -- "${line##*,}"
}

_fix_call_audio_is_bt_device() {
  local name="$1"
  local type="$2"
  local uid
  uid=$(_fix_call_audio_uid_for "$name" "$type") || return 1
  _fix_call_audio_is_bt_uid "$uid"
}

_fix_call_audio_default_input() {
  # Prefer the Mac-mic aggregate when present (hides raw BT transport from Chromium).
  if _fix_call_audio_device_exists "$FIX_CALL_AUDIO_HQ_INPUT" input; then
    print -r -- "$FIX_CALL_AUDIO_HQ_INPUT"
    return 0
  fi
  local line
  line=$(SwitchAudioSource -a -f cli 2>/dev/null | command grep ',input,.*,BuiltInMicrophoneDevice$' | head -n1)
  if [[ -n "$line" ]]; then
    print -r -- "${line%%,*}"
    return 0
  fi
  return 1
}

_fix_call_audio_default_output() {
  local line name uid current
  local -a candidates=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=${line%%,*}
    uid=${line##*,}
    if _fix_call_audio_is_bt_uid "$uid"; then
      candidates+=("$name")
    fi
  done < <(SwitchAudioSource -a -f cli 2>/dev/null | command grep ',output,')

  if (( ${#candidates} == 0 )); then
    return 1
  fi

  if (( ${#candidates} == 1 )); then
    print -r -- "${candidates[1]}"
    return 0
  fi

  current=$(SwitchAudioSource -t output -c 2>/dev/null)
  if [[ -n "$current" ]] && (( ${candidates[(Ie)$current]} )); then
    print -r -- "$current"
    return 0
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    if SwitchAudioSource -a -f cli 2>/dev/null | command grep -Fq "${candidate},input,"; then
      print -r -- "$candidate"
      return 0
    fi
  done

  print -r -- "${candidates[1]}"
}

_fix_call_audio_bt_address() {
  local name="$1"
  local uid
  uid=$(_fix_call_audio_uid_for "$name" output) || return 1
  _fix_call_audio_is_bt_uid "$uid" || return 1
  print -r -- "${uid%%:*}"
}

_fix_call_audio_bt_output_uid() {
  local name
  name=$(_fix_call_audio_default_output 2>/dev/null) || return 1
  _fix_call_audio_uid_for "$name" output
}

_fix_call_audio_wait_output() {
  local name="$1"
  local timeout="${2:-15}"
  local elapsed=0
  while (( elapsed < timeout )); do
    if _fix_call_audio_device_exists "$name" output; then
      return 0
    fi
    sleep 1
    (( elapsed++ ))
  done
  return 1
}

_fix_call_audio_ensure_tools() {
  local need_blueutil="${1:-true}"

  if ! command -v SwitchAudioSource &>/dev/null; then
    if ! command -v brew &>/dev/null; then
      echo -e "${BRed}Error:${Color_Off} SwitchAudioSource not found and Homebrew is unavailable." >&2
      return 1
    fi
    echo -e "${BYellow}Installing switchaudio-osx...${Color_Off}" >&2
    brew install switchaudio-osx || return 1
  fi

  if [[ "$need_blueutil" == true ]] && ! command -v blueutil &>/dev/null; then
    if ! command -v brew &>/dev/null; then
      echo -e "${BRed}Error:${Color_Off} blueutil not found and Homebrew is unavailable." >&2
      return 1
    fi
    echo -e "${BYellow}Installing blueutil...${Color_Off}" >&2
    brew install blueutil || return 1
  fi
}

_fix_call_audio_ensure_hide_bin() {
  if [[ -x "$FIX_CALL_AUDIO_HIDE_BIN" ]]; then
    return 0
  fi
  if [[ ! -f "$FIX_CALL_AUDIO_HIDE_SRC" ]]; then
    echo -e "${BRed}Error:${Color_Off} Missing $FIX_CALL_AUDIO_HIDE_SRC" >&2
    return 1
  fi
  if ! command -v swiftc &>/dev/null; then
    echo -e "${BRed}Error:${Color_Off} swiftc not found (install Xcode Command Line Tools)." >&2
    return 1
  fi
  echo -e "${BYellow}Compiling hide-bt-input...${Color_Off}" >&2
  swiftc -O -o "$FIX_CALL_AUDIO_HIDE_BIN" "$FIX_CALL_AUDIO_HIDE_SRC" || return 1
  chmod +x "$FIX_CALL_AUDIO_HIDE_BIN"
}

# True when Bluetooth audio is in Hands-Free Profile (tinny mono).
_fix_call_audio_hfp_active() {
  local current_in
  current_in=$(SwitchAudioSource -t input -c 2>/dev/null)
  if [[ -n "$current_in" ]] && _fix_call_audio_is_bt_device "$current_in" input; then
    return 0
  fi

  system_profiler SPAudioDataType 2>/dev/null | command awk '
    function flush() {
      if (in_bt && has_out && (out_ch == 1 || (rate > 0 && rate <= 24000))) exit 0
      in_bt=0; out_ch=0; rate=0; has_out=0
    }
    /^        [^ ].*:$/ { flush(); next }
    /Transport: Bluetooth/ { in_bt=1 }
    /Output Channels:/ {
      has_out=1
      for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { out_ch = $i + 0; break }
    }
    /Current SampleRate:/ {
      for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { rate = $i + 0; break }
    }
    END { flush(); exit 1 }
  '
}

_fix_call_audio_session_uid() {
  [[ -f "$FIX_CALL_AUDIO_SESSION" ]] || return 1
  <"$FIX_CALL_AUDIO_SESSION"
}

_fix_call_audio_session_mark_hidden() {
  local uid="$1"
  mkdir -p "$(dirname "$FIX_CALL_AUDIO_SESSION")"
  print -r -- "$uid" >"$FIX_CALL_AUDIO_SESSION"
}

_fix_call_audio_session_clear() {
  rm -f "$FIX_CALL_AUDIO_SESSION"
}

# When the BT output UID changes (new connection), clear hide session so the
# mic is available again until the next HFP / fix_call_audio.
_fix_call_audio_session_sync() {
  local current marked
  current=$(_fix_call_audio_bt_output_uid 2>/dev/null) || {
    _fix_call_audio_session_clear
    return 0
  }
  marked=$(_fix_call_audio_session_uid 2>/dev/null) || return 0
  if [[ "$marked" != "$current" ]]; then
    _fix_call_audio_session_clear
  fi
}

_fix_call_audio_session_should_hide() {
  local current marked
  current=$(_fix_call_audio_bt_output_uid 2>/dev/null) || return 1
  marked=$(_fix_call_audio_session_uid 2>/dev/null) || return 1
  [[ "$marked" == "$current" ]]
}

# Best-effort: who is holding / recently used the mic.
_fix_call_audio_report_offender() {
  local quiet="$1"
  [[ "$quiet" == true ]] && return 0

  echo -e "${BYellow}Looking for what's using the mic...${Color_Off}"

  if [[ -x "$FIX_CALL_AUDIO_HIDE_BIN" ]]; then
    "$FIX_CALL_AUDIO_HIDE_BIN" --status 2>/dev/null | while IFS= read -r line; do
      echo "  $line"
    done
  fi

  local front
  front=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null) || true
  [[ -n "$front" ]] && echo -e "  Frontmost app: ${BCyan}$front${Color_Off}"

  # Recent TCC microphone activity (best-effort; may be empty without Full Disk Access).
  local tcc
  tcc=$(log show --last 2m --style compact --predicate 'subsystem == "com.apple.TCC" AND composedMessage CONTAINS[c] "Microphone"' 2>/dev/null \
    | command tail -n 8) || true
  if [[ -n "$tcc" ]]; then
    echo "  Recent microphone TCC log:"
    print -r -- "$tcc" | while IFS= read -r line; do
      echo "    $line"
    done
  fi
}

_fix_call_audio_hide_bt_mic() {
  local quiet="${1:-false}"
  _fix_call_audio_ensure_hide_bin || return 1

  [[ "$quiet" == true ]] || echo -e "${BGreen}Hiding Bluetooth mic for this connection...${Color_Off}"
  if [[ "$quiet" == true ]]; then
    "$FIX_CALL_AUDIO_HIDE_BIN" >/dev/null 2>&1 || return 1
  else
    "$FIX_CALL_AUDIO_HIDE_BIN" || return 1
  fi

  local uid
  uid=$(_fix_call_audio_bt_output_uid 2>/dev/null) || true
  [[ -n "$uid" ]] && _fix_call_audio_session_mark_hidden "$uid"
  return 0
}

# Apply Mac mic (+ HQ Call Mic aggregate) + BT out.
# Reconnect when HFP / force_reset; always hide BT mic after a recovery.
# Returns: 0 applied/ok, 1 error, 2 nothing to do (no BT headset).
_fix_call_audio_enforce() {
  local quiet="${1:-false}"
  local force_reset="${2:-false}"
  local input="${3:-}"
  local output="${4:-}"
  local do_hide="${5:-}"

  _fix_call_audio_ensure_tools true || return 1
  _fix_call_audio_session_sync

  if [[ -z "$output" ]]; then
    output=$(_fix_call_audio_default_output) || {
      return 2
    }
  fi

  local hfp_active=false
  if _fix_call_audio_hfp_active; then
    hfp_active=true
  fi

  local need_reset=false
  if [[ "$force_reset" == true || "$hfp_active" == true ]]; then
    need_reset=true
  fi

  # Hide BT mic when recovering from bad audio, or when this connection already
  # had a hide session (HFP came back mid-call).
  if [[ -z "$do_hide" ]]; then
    if [[ "$need_reset" == true ]] || _fix_call_audio_session_should_hide; then
      do_hide=true
    else
      do_hide=false
    fi
  fi

  if [[ -z "$input" ]]; then
    # Ensure aggregate exists before resolving preferred input name.
    if [[ "$do_hide" == true || "$need_reset" == true ]]; then
      _fix_call_audio_hide_bt_mic true || true
    fi
    input=$(_fix_call_audio_default_input) || {
      [[ "$quiet" == true ]] || echo -e "${BRed}Error:${Color_Off} Could not find the built-in Mac microphone." >&2
      return 1
    }
  fi

  if ! _fix_call_audio_device_exists "$output" output; then
    [[ "$quiet" == true ]] || {
      echo -e "${BRed}Error:${Color_Off} Output device not found: $output" >&2
      echo "Available outputs:" >&2
      SwitchAudioSource -a -t output >&2
    }
    return 1
  fi

  # Prefer HQ Call Mic / Mac mic even if caller passed a stale name.
  if ! _fix_call_audio_device_exists "$input" input; then
    input=$(_fix_call_audio_default_input) || return 1
  fi

  local current_in current_out
  current_in=$(SwitchAudioSource -t input -c 2>/dev/null)
  current_out=$(SwitchAudioSource -t output -c 2>/dev/null)
  local already_ok=false
  if [[ "$current_in" == "$input" && "$current_out" == "$output" && "$hfp_active" == false ]]; then
    already_ok=true
  fi

  # Nothing left to do (and hide already applied above when requested).
  if [[ "$need_reset" == false && "$already_ok" == true ]]; then
    if [[ "$do_hide" == true && "$quiet" != true ]]; then
      echo -e "${UGreen}Done:${Color_Off}"
      echo -e "  Input:  ${BCyan}$current_in${Color_Off}"
      echo -e "  Output: ${BCyan}$current_out${Color_Off}"
      echo -e "  Bluetooth mic hidden for this connection (reconnect restores it)."
    fi
    return 0
  fi

  if [[ "$need_reset" == true && "$quiet" != true ]]; then
    _fix_call_audio_report_offender false
  fi

  [[ "$quiet" == true ]] || echo -e "${BGreen}Setting input →${Color_Off} $input"
  SwitchAudioSource -t input -s "$input" >/dev/null 2>&1 || true

  if [[ "$need_reset" == true ]]; then
    local bt_addr
    bt_addr=$(_fix_call_audio_bt_address "$output") || {
      [[ "$quiet" == true ]] || echo -e "${BRed}Error:${Color_Off} $output is not a Bluetooth device (cannot reconnect)." >&2
      return 1
    }

    [[ "$quiet" == true ]] || echo -e "${BGreen}Reconnecting Bluetooth →${Color_Off} $output ($bt_addr)"
    blueutil --disconnect "$bt_addr" >/dev/null 2>&1 || true
    sleep 2
    blueutil --connect "$bt_addr" >/dev/null 2>&1 || {
      [[ "$quiet" == true ]] || echo -e "${BRed}Error:${Color_Off} Failed to reconnect $output" >&2
      return 1
    }

    [[ "$quiet" == true ]] || echo -e "${BYellow}Waiting for $output to reappear...${Color_Off}"
    if ! _fix_call_audio_wait_output "$output" 15; then
      [[ "$quiet" == true ]] || echo -e "${BRed}Error:${Color_Off} Timed out waiting for $output after reconnect." >&2
      return 1
    fi

    # Mic comes back after reconnect — hide it again for this connection.
    _fix_call_audio_hide_bt_mic "$quiet" || true
    input=$(_fix_call_audio_default_input) || input="$FIX_CALL_AUDIO_HQ_INPUT"
    SwitchAudioSource -t input -s "$input" >/dev/null 2>&1 || true
  elif [[ "$do_hide" == true ]]; then
    _fix_call_audio_hide_bt_mic "$quiet" || true
    input=$(_fix_call_audio_default_input) || input="$FIX_CALL_AUDIO_HQ_INPUT"
    SwitchAudioSource -t input -s "$input" >/dev/null 2>&1 || true
  fi

  [[ "$quiet" == true ]] || echo -e "${BGreen}Setting output →${Color_Off} $output"
  SwitchAudioSource -t output -s "$output" >/dev/null || return 1

  current_in=$(SwitchAudioSource -t input -c)
  current_out=$(SwitchAudioSource -t output -c)

  if [[ "$quiet" != true ]]; then
    echo
    echo -e "${UGreen}Done:${Color_Off}"
    echo -e "  Input:  ${BCyan}$current_in${Color_Off}"
    echo -e "  Output: ${BCyan}$current_out${Color_Off}"
    if _fix_call_audio_hfp_active; then
      echo -e "${BYellow}Warning:${Color_Off} Bluetooth still looks like HFP. An app may still be holding the headset mic."
    else
      echo -e "  Bluetooth mic hidden for this connection (reconnect restores it)."
    fi
  fi

  if [[ "$current_out" != "$output" ]]; then
    [[ "$quiet" == true ]] || echo -e "${BYellow}Warning:${Color_Off} Final output does not match the requested device." >&2
    return 1
  fi
}

_fix_call_audio_watch_loaded() {
  launchctl print "gui/$(id -u)/${FIX_CALL_AUDIO_LABEL}" >/dev/null 2>&1
}

_fix_call_audio_write_plist() {
  mkdir -p "$HOME/Library/LaunchAgents" "$(dirname "$FIX_CALL_AUDIO_LOG")"
  cat >"$FIX_CALL_AUDIO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${FIX_CALL_AUDIO_LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>${FIX_CALL_AUDIO_GUARD}</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>${FIX_CALL_AUDIO_LOG}</string>
	<key>StandardErrorPath</key>
	<string>${FIX_CALL_AUDIO_LOG}</string>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
		<key>USER_CONFIG_DIRECTORY</key>
		<string>${USER_CONFIG_DIRECTORY:-$HOME/.shell-config/zsh}</string>
		<key>HOME</key>
		<string>${HOME}</string>
	</dict>
</dict>
</plist>
EOF
}

_fix_call_audio_watch() {
  if [[ ! -f "$FIX_CALL_AUDIO_GUARD" ]]; then
    echo -e "${BRed}Error:${Color_Off} Guard script missing: $FIX_CALL_AUDIO_GUARD" >&2
    return 1
  fi
  _fix_call_audio_ensure_tools true || return 1
  _fix_call_audio_ensure_hide_bin || return 1
  _fix_call_audio_write_plist || return 1

  if _fix_call_audio_watch_loaded; then
    launchctl bootout "gui/$(id -u)/${FIX_CALL_AUDIO_LABEL}" >/dev/null 2>&1 || true
  fi
  launchctl bootstrap "gui/$(id -u)" "$FIX_CALL_AUDIO_PLIST" || return 1
  echo -e "${UGreen}Watching:${Color_Off} ${FIX_CALL_AUDIO_LABEL} (log: $FIX_CALL_AUDIO_LOG)"
}

_fix_call_audio_unwatch() {
  if _fix_call_audio_watch_loaded; then
    launchctl bootout "gui/$(id -u)/${FIX_CALL_AUDIO_LABEL}" >/dev/null 2>&1 || true
  fi
  [[ -f "$FIX_CALL_AUDIO_PLIST" ]] && rm -f "$FIX_CALL_AUDIO_PLIST"
  echo -e "${UGreen}Stopped:${Color_Off} ${FIX_CALL_AUDIO_LABEL}"
}

_fix_call_audio_autoload() {
  [[ "$(uname -s)" == "Darwin" ]] || return 0
  [[ -o interactive ]] || return 0
  [[ "${FIX_CALL_AUDIO_DISABLE:-0}" == "1" ]] && return 0

  if ! _fix_call_audio_watch_loaded; then
    _fix_call_audio_watch >/dev/null 2>&1 || true
  fi

  # Quiet: only re-hide if this BT connection already had a hide session, or HFP.
  _fix_call_audio_enforce true false >/dev/null 2>&1 || true
}

fix_call_audio() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${BRed}Error:${Color_Off} fix_call_audio only works on macOS."
    return 1
  fi

  local quiet=false
  local reset=true
  local watch=false
  local unwatch=false
  local -a positional=()
  local arg

  for arg in "$@"; do
    case "$arg" in
      --quiet) quiet=true ;;
      --no-reset) reset=false ;;
      --watch) watch=true ;;
      --unwatch) unwatch=true ;;
      -h|--help)
        cat <<'EOF'
Usage: fix_call_audio [input] [output] [options]

  Restores high-quality Bluetooth audio when something opens the headset mic
  (HFP / tinny mono). Finds the offender, reconnects for A2DP stereo, then
  temporarily hides the Bluetooth microphone for this connection so apps
  cannot pick it again. Disconnect + reconnect the headphones to bring the
  mic back.

  Defaults (auto-detected when omitted):
    input:  HQ Call Mic / built-in Mac microphone
    output: connected Bluetooth headset

  Options:
    --quiet      Apply without banners
    --no-reset   Skip Bluetooth reconnect (still hides BT mic)
    --watch      Install/start the background LaunchAgent guard
    --unwatch    Stop and remove the LaunchAgent guard

  Env:
    FIX_CALL_AUDIO_DISABLE=1   Skip autoload on interactive shells
EOF
        return 0
        ;;
      -*)
        echo -e "${BRed}Error:${Color_Off} Unknown option: $arg"
        return 1
        ;;
      *)
        positional+=("$arg")
        ;;
    esac
  done

  if [[ "$unwatch" == true ]]; then
    _fix_call_audio_unwatch
    return $?
  fi

  if [[ "$watch" == true ]]; then
    _fix_call_audio_watch
    return $?
  fi

  local input="${positional[1]:-${AUDIO_INPUT_DEVICE:-}}"
  local output="${positional[2]:-${AUDIO_OUTPUT_DEVICE:-}}"
  local rc

  # Manual run always means quality is bad → hide BT mic for this connection.
  _fix_call_audio_enforce "$quiet" "$reset" "$input" "$output" true
  rc=$?

  if (( rc == 2 )); then
    [[ "$quiet" == true ]] || {
      echo -e "${BRed}Error:${Color_Off} No connected Bluetooth audio output found."
      echo "Available outputs:"
      SwitchAudioSource -a -t output
    }
    return 1
  fi
  return $rc
}

_fix_call_audio_autoload
