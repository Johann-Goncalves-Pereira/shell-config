# Force high-quality Bluetooth audio: Mac mic in + Bluetooth stereo out.
# Reconnects the headset so CoreAudio drops HFP and restores A2DP.

fix_call_audio() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${BRed}Error:${Color_Off} fix_call_audio only works on macOS."
    return 1
  fi

  local reset=true
  local -a positional=()
  local arg

  for arg in "$@"; do
    case "$arg" in
      --no-reset) reset=false ;;
      -h|--help)
        cat <<'EOF'
Usage: fix_call_audio [input] [output] [--no-reset]

  Forces system input to the Mac microphone and output to Bluetooth
  headphones, then reconnects Bluetooth so A2DP stereo comes back.

  Defaults:
    input:  MacBook Pro Microphone  (or $AUDIO_INPUT_DEVICE)
    output: Pretinho Laranjinha     (or $AUDIO_OUTPUT_DEVICE)

  --no-reset  Skip Bluetooth disconnect/reconnect (device switch only)
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

  local input="${positional[1]:-${AUDIO_INPUT_DEVICE:-MacBook Pro Microphone}}"
  local output="${positional[2]:-${AUDIO_OUTPUT_DEVICE:-Pretinho Laranjinha}}"

  if ! command -v SwitchAudioSource &>/dev/null; then
    if ! command -v brew &>/dev/null; then
      echo -e "${BRed}Error:${Color_Off} SwitchAudioSource not found and Homebrew is unavailable."
      return 1
    fi
    echo -e "${BYellow}Installing switchaudio-osx...${Color_Off}"
    brew install switchaudio-osx || return 1
  fi

  if [[ "$reset" == true ]] && ! command -v blueutil &>/dev/null; then
    if ! command -v brew &>/dev/null; then
      echo -e "${BRed}Error:${Color_Off} blueutil not found and Homebrew is unavailable."
      return 1
    fi
    echo -e "${BYellow}Installing blueutil...${Color_Off}"
    brew install blueutil || return 1
  fi

  _fix_call_audio_device_exists() {
    local name="$1"
    local type="$2"
    SwitchAudioSource -a -t "$type" 2>/dev/null | command grep -Fxq "$name"
  }

  _fix_call_audio_bt_address() {
    local name="$1"
    local line uid
    # cli format: name,type,id,uid
    line=$(SwitchAudioSource -a -f cli 2>/dev/null | command grep -F "${name},output," | head -n1)
    [[ -z "$line" ]] && return 1
    uid=${line##*,}
    [[ -z "$uid" || "$uid" != *:* ]] && return 1
    print -r -- "${uid%%:*}"
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

  if ! _fix_call_audio_device_exists "$input" input; then
    echo -e "${BRed}Error:${Color_Off} Input device not found: $input"
    echo "Available inputs:"
    SwitchAudioSource -a -t input
    return 1
  fi

  if ! _fix_call_audio_device_exists "$output" output; then
    echo -e "${BRed}Error:${Color_Off} Output device not found: $output"
    echo "Available outputs:"
    SwitchAudioSource -a -t output
    return 1
  fi

  echo -e "${BGreen}Setting input →${Color_Off} $input"
  SwitchAudioSource -t input -s "$input" >/dev/null || return 1

  if [[ "$reset" == true ]]; then
    local bt_addr
    bt_addr=$(_fix_call_audio_bt_address "$output") || {
      echo -e "${BRed}Error:${Color_Off} Could not read Bluetooth address for: $output"
      return 1
    }

    echo -e "${BGreen}Reconnecting Bluetooth →${Color_Off} $output ($bt_addr)"
    blueutil --disconnect "$bt_addr" >/dev/null 2>&1 || true
    sleep 2
    blueutil --connect "$bt_addr" >/dev/null 2>&1 || {
      echo -e "${BRed}Error:${Color_Off} Failed to reconnect $output"
      return 1
    }

    echo -e "${BYellow}Waiting for $output to reappear...${Color_Off}"
    if ! _fix_call_audio_wait_output "$output" 15; then
      echo -e "${BRed}Error:${Color_Off} Timed out waiting for $output after reconnect."
      return 1
    fi

    echo -e "${BGreen}Re-applying input →${Color_Off} $input"
    SwitchAudioSource -t input -s "$input" >/dev/null || return 1
  fi

  echo -e "${BGreen}Setting output →${Color_Off} $output"
  SwitchAudioSource -t output -s "$output" >/dev/null || return 1

  local current_in current_out
  current_in=$(SwitchAudioSource -t input -c)
  current_out=$(SwitchAudioSource -t output -c)

  echo
  echo -e "${UGreen}Done:${Color_Off}"
  echo -e "  Input:  ${BCyan}$current_in${Color_Off}"
  echo -e "  Output: ${BCyan}$current_out${Color_Off}"

  if [[ "$current_in" != "$input" || "$current_out" != "$output" ]]; then
    echo -e "${BYellow}Warning:${Color_Off} Final devices do not match the requested ones."
    return 1
  fi
}
