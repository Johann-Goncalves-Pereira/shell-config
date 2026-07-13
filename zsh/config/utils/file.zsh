# Compress all mp3 files in the current directory and subdirectories to 64 kbps with 22.05 kHz sample rate.
# The compressed files are renamed to [original name] - compressed.mp3.
function compress_mp3() {
  if ! command -v lame >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} lame is not installed. Please install it and try again."
    return 1
  fi

  if ! command -v trash >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} trash is not installed. Please install it and try again."
    return 1
  fi

  shopt -s globstar nullglob
  for f in **/*.mp3; do
    if [ -f "$f" ]; then
      output_file="$(echo "$f" | sed 's/\(.*\)\.mp3/\1 - compressed.mp3/')"
      lame --mp3input -b 64 --resample 22.05 "$f" "$output_file" && trash "$f"
    else
      echo "${BYellow}[Warning]:${Color_Off} No mp3 files found."
    fi
  done
  shopt -u globstar nullglob
}

# Function to convert m4b audiobook files to mp3 format with chapters.
# This function uses ffmpeg to convert the audio file to mp3 format and split it into chapters.
# It also adds metadata to each chapter file using id3v2.
function convert_m4b_audiobook_to_mp3_with_chapters() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ${BICyan}ffmpeg${Color_Off} is not installed. Please install it and try again."
    return
  fi
  if ! command -v m4b-tool >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ${BICyan}m4b-tool${Color_Off} is not installed. Please install it and try again."
    return
  fi

  # Loop through all .m4b files in the current directory
  for audiobook_path in *.m4b; do
    echo -n "Converting ${BICyan}$audiobook_path${Color_Off} to mp3 format with chapters...\n"
    m4b-tool split --audio-format mp3 --audio-bitrate 96k --audio-channels 2 --audio-samplerate 22050 "$audiobook_path"
  done
}

# Convert m4a files to mp3 using libmp3lame VBR — good perceptual quality with smaller files.
# Usage: convert_m4a_to_mp3 [path] [quality]
#   path: file or directory (default: current directory, recursive)
#   quality: high (~190 kbps), balanced (~165 kbps, default), small (~130 kbps)
function convert_m4a_to_mp3() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ${BICyan}ffmpeg${Color_Off} is not installed. Please install it and try again."
    return 1
  fi

  local target="${1:-.}"
  local quality="${2:-balanced}"
  local q_value output_file input_bytes output_bytes saved_pct

  case "$quality" in
    high)     q_value=2 ;;
    balanced) q_value=4 ;;
    small)    q_value=6 ;;
    *)
      echo "${BIRed}[Error]:${Color_Off} Invalid quality '${quality}'. Use: high, balanced, or small."
      return 1
      ;;
  esac

  local -a files
  if [[ -f "$target" && "${target##*.}" == m4a ]]; then
    files=("$target")
  else
    setopt local_options null_glob
    files=("$target"/**/*.m4a(N))
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "${BYellow}[Warning]:${Color_Off} No m4a files found."
    return 1
  fi

  for f in "${files[@]}"; do
    output_file="${f:r}.mp3"

    if [[ -f "$output_file" ]]; then
      echo "${BYellow}[Skip]:${Color_Off} ${BICyan}$output_file${Color_Off} already exists."
      continue
    fi

    echo "Converting ${BICyan}$f${Color_Off} → ${BICyan}$output_file${Color_Off} (VBR q=$q_value)..."

    if ffmpeg -nostdin -hide_banner -loglevel warning -i "$f" \
      -codec:a libmp3lame -q:a "$q_value" -map_metadata 0 \
      -id3v2_version 3 "$output_file"; then

      input_bytes=$(stat -f%z "$f" 2>/dev/null)
      output_bytes=$(stat -f%z "$output_file" 2>/dev/null)
      saved_pct=$(( (input_bytes - output_bytes) * 100 / input_bytes ))
      echo "${BGreen}[Done]:${Color_Off} $(( input_bytes / 1024 )) KB → $(( output_bytes / 1024 )) KB (~${saved_pct}% smaller)"
    else
      echo "${BIRed}[Error]:${Color_Off} Failed to convert ${BICyan}$f${Color_Off}"
      rm -f "$output_file"
      return 1
    fi
  done
}

# Trim near-silent sections throughout audio, keeping a short breath where silence was.
# Usage: cut_silence [path] [min_silence] [breath] [threshold]
#   path:         file or directory (default: current directory, recursive)
#   min_silence:  minimum silence duration to trim, in seconds (default: 0.8)
#   breath:       silence to keep at each cut, in seconds (default: 0.3)
#   threshold:    silence level in dB, lower = stricter (default: -45)
function cut_silence() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ${BICyan}ffmpeg${Color_Off} is not installed. Please install it and try again."
    return 1
  fi

  local target="${1:-.}"
  local min_silence="${2:-0.8}"
  local breath="${3:-0.3}"
  local threshold="${4:--45}"
  local -a audio_exts=(mp3 m4a wav flac ogg aac opus)
  local -a files f ext tmp codec_args format_args
  local filter duration_before duration_after input_bytes output_bytes saved_pct

  filter="silenceremove=start_periods=1:start_duration=${min_silence}:start_threshold=${threshold}dB:start_silence=${breath}:stop_periods=-1:stop_duration=${min_silence}:stop_threshold=${threshold}dB:stop_silence=${breath}"

  if [[ -f "$target" ]]; then
    files=("$target")
  else
    setopt local_options null_glob
    for ext in "${audio_exts[@]}"; do
      files+=("$target"/**/*."$ext"(N))
    done
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "${BYellow}[Warning]:${Color_Off} No audio files found."
    return 1
  fi

  for f in "${files[@]}"; do
    ext="${f##*.}"
    case "$ext" in
      mp3)  codec_args=(-codec:a libmp3lame -q:a 4); format_args=(-f mp3) ;;
      m4a)  codec_args=(-codec:a aac -b:a 128k); format_args=(-f ipod) ;;
      aac)  codec_args=(-codec:a copy); format_args=(-f adts) ;;
      wav)  codec_args=(-codec:a pcm_s16le); format_args=(-f wav) ;;
      flac) codec_args=(-codec:a flac); format_args=(-f flac) ;;
      ogg)  codec_args=(-codec:a libvorbis -q:a 4); format_args=(-f ogg) ;;
      opus) codec_args=(-codec:a libopus -b:a 96k); format_args=(-f opus) ;;
      *)
        echo "${BYellow}[Skip]:${Color_Off} Unsupported format: ${BICyan}$f${Color_Off}"
        continue
        ;;
    esac

    tmp="${f:r}.cut.${RANDOM}.${ext}"
    duration_before=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null)
    input_bytes=$(stat -f%z "$f" 2>/dev/null)

    echo "Cutting silence in ${BICyan}$f${Color_Off} (≥${min_silence}s @ ${threshold}dB, breath ${breath}s)..."

    if ffmpeg -nostdin -hide_banner -loglevel warning -y -i "$f" \
      -af "$filter" "${codec_args[@]}" "${format_args[@]}" -map_metadata 0 "$tmp"; then

      duration_after=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp" 2>/dev/null)
      output_bytes=$(stat -f%z "$tmp" 2>/dev/null)
      mv "$tmp" "$f"

      if [[ -n "$duration_before" && -n "$duration_after" ]]; then
        saved_pct=$(awk -v b="$duration_before" -v a="$duration_after" 'BEGIN { printf "%.0f", (b - a) * 100 / b }')
        echo "${BGreen}[Done]:${Color_Off} ${duration_before%.*}s → ${duration_after%.*}s (~${saved_pct}% shorter), $(( input_bytes / 1024 )) KB → $(( output_bytes / 1024 )) KB"
      else
        echo "${BGreen}[Done]:${Color_Off} $(( input_bytes / 1024 )) KB → $(( output_bytes / 1024 )) KB"
      fi
    else
      echo "${BIRed}[Error]:${Color_Off} Failed to process ${BICyan}$f${Color_Off}"
      rm -f "$tmp"
      return 1
    fi
  done
}

function compress_mp4() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ffmpeg is not installed. Please install it and try again."
    return 1
  fi

  local mode="default"
  local scale=""
  local target_files=()
  local usage="Usage: compress_mp4 [default|good|best|h265] [scale WxH] [file]
  Modes:
    default - ffmpeg default compression (copy audio)
    good    - h264, CRF 28, aac audio 96k (good quality, small size)
    best    - h264, CRF 23, aac audio 128k (higher quality)
    h265    - h265, CRF 28, aac audio 96k (smaller, not always compatible)
  Optionally, add a scale (e.g. 1280:720 or 1920:1080) to resize video.
  Optionally, specify a single mp4 file to compress.
  Example: compress_mp4 good 1280:720 myvideo.mp4"

  # Parse arguments
  if [[ "$1" == "help" || "$1" == "--help" ]]; then
    echo "$usage"
    return 0
  fi
  [[ "$1" =~ ^(default|good|best|h265)$ ]] && mode="$1" && shift
  [[ "$1" =~ ^[0-9]+x[0-9]+$ || "$1" =~ ^[0-9]+:[0-9]+$ ]] && scale="$1" && shift

  # If a file is provided as the last argument, use only that file
  if [[ -n "$1" && -f "$1" ]]; then
    target_files=("$1")
  else
    shopt -s globstar nullglob
    target_files=(**/*.mp4)
    shopt -u globstar nullglob
  fi

  if [[ ${#target_files[@]} -eq 0 ]]; then
    echo "${BYellow}[Warning]:${Color_Off} No mp4 files found."
    return 0
  fi

  for f in "${target_files[@]}"; do
    if [ -f "$f" ]; then
      output_file="$(echo "$f" | sed 's/\(.*\)\.mp4/\1 - compressed.mp4/')"
      local scale_opt=""
      [[ -n "$scale" ]] && scale_opt="-vf scale=$scale"

      case "$mode" in
      default)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 28 -c:a aac -b:a 96k "$output_file"
        ;;
      good)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 28 -c:a aac -b:a 96k "$output_file"
        ;;
      best)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k "$output_file"
        ;;
      h265)
        ffmpeg -i "$f" $scale_opt -c:v libx265 -preset ultrafast -crf 28 -c:a aac -b:a 96k "$output_file"
        ;;
      esac

      if [[ $? -eq 0 ]]; then
        trash "$f"
      else
        echo "${BIRed}[Error]:${Color_Off} Compression failed for $f"
      fi
    fi
  done
}

function compress_mov() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ffmpeg is not installed. Please install it and try again."
    return 1
  fi

  local mode="default"
  local scale=""
  local target_files=()
  local usage="Usage: compress_mov [default|good|best|h265] [scale WxH] [file]
  Modes:
    default - h264, CRF 28, aac audio 96k (good size/quality)
    good    - h264, CRF 24, aac audio 128k (better quality)
    best    - h264, CRF 20, aac audio 192k (highest quality, largest size)
    h265    - h265, CRF 28, aac audio 96k (smallest, less compatible)
  Optionally, add a scale (e.g. 1280:720 or 1920:1080) to resize video.
  Optionally, specify a single mov file to compress.
  Example: compress_mov good 1280:720 myvideo.mov"

  # Parse arguments
  if [[ "$1" == "help" || "$1" == "--help" ]]; then
    echo "$usage"
    return 0
  fi
  [[ "$1" =~ ^(default|good|best|h265)$ ]] && mode="$1" && shift
  [[ "$1" =~ ^[0-9]+x[0-9]+$ || "$1" =~ ^[0-9]+:[0-9]+$ ]] && scale="$1" && shift

  # If a file is provided as the last argument, use only that file
  if [[ -n "$1" && -f "$1" ]]; then
    target_files=("$1")
  else
    shopt -s globstar nullglob
    target_files=(**/*.mov)
    shopt -u globstar nullglob
  fi

  if [[ ${#target_files[@]} -eq 0 ]]; then
    echo "${BYellow}[Warning]:${Color_Off} No mov files found."
    return 0
  fi

  for f in "${target_files[@]}"; do
    if [ -f "$f" ]; then
      output_file="$(echo "$f" | sed 's/\(.*\)\.mov/\1 - compressed.mov/')"
      local scale_opt=""
      [[ -n "$scale" ]] && scale_opt="-vf scale=$scale"

      case "$mode" in
      default)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 28 -c:a aac -b:a 96k "$output_file"
        ;;
      good)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 24 -c:a aac -b:a 128k "$output_file"
        ;;
      best)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 20 -c:a aac -b:a 192k "$output_file"
        ;;
      h265)
        ffmpeg -i "$f" $scale_opt -c:v libx265 -preset ultrafast -crf 28 -c:a aac -b:a 96k "$output_file"
        ;;
      esac

      if [[ $? -eq 0 ]]; then
        trash "$f"
      else
        echo "${BIRed}[Error]:${Color_Off} Compression failed for $f"
      fi
    fi
  done
}

function compress_mkv() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ffmpeg is not installed. Please install it and try again."
    return 1
  fi

  local mode="default"
  local scale=""
  local target_files=()
  local usage="Usage: compress_mkv [default|good|best|h265] [scale WxH] [file]
  Modes:
    default - h264, CRF 28, aac audio 96k (good size/quality)
    good    - h264, CRF 24, aac audio 128k (better quality)
    best    - h264, CRF 20, aac audio 192k (highest quality, largest size)
    h265    - h265, CRF 28, aac audio 96k (smallest, less compatible)
  Optionally, add a scale (e.g. 1280:720 or 1920:1080) to resize video.
  Optionally, specify a single mkv file to compress.
  Example: compress_mkv good 1280:720 myvideo.mkv"

  # Parse arguments
  if [[ "$1" == "help" || "$1" == "--help" ]]; then
    echo "$usage"
    return 0
  fi
  [[ "$1" =~ ^(default|good|best|h265)$ ]] && mode="$1" && shift
  [[ "$1" =~ ^[0-9]+x[0-9]+$ || "$1" =~ ^[0-9]+:[0-9]+$ ]] && scale="$1" && shift

  # If a file is provided as the last argument, use only that file
  if [[ -n "$1" && -f "$1" ]]; then
    target_files=("$1")
  else
    shopt -s globstar nullglob
    target_files=(**/*.mkv)
    shopt -u globstar nullglob
  fi

  if [[ ${#target_files[@]} -eq 0 ]]; then
    echo "${BYellow}[Warning]:${Color_Off} No mkv files found."
    return 0
  fi

  for f in "${target_files[@]}"; do
    if [ -f "$f" ]; then
      output_file="$(echo "$f" | sed 's/\(.*\)\.mkv/\1 - compressed.mkv/')"
      local scale_opt=""
      [[ -n "$scale" ]] && scale_opt="-vf scale=$scale"

      case "$mode" in
      default)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 28 -c:a aac -b:a 96k "$output_file"
        ;;
      good)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 24 -c:a aac -b:a 128k "$output_file"
        ;;
      best)
        ffmpeg -i "$f" $scale_opt -c:v libx264 -preset medium -crf 20 -c:a aac -b:a 192k "$output_file"
        ;;
      h265)
        ffmpeg -i "$f" $scale_opt -c:v libx265 -preset ultrafast -crf 28 -c:a aac -b:a 96k "$output_file"
        ;;
      esac

      if [[ $? -eq 0 ]]; then
        trash "$f"
      else
        echo "${BIRed}[Error]:${Color_Off} Compression failed for $f"
      fi
    fi
  done
}

function compress_mp4_to_webm() {
  if ! command -v ffmpeg >/dev/null; then
    echo "${BIRed}[Error]:${Color_Off} ffmpeg is not installed. Please install it and try again."
    return 1
  fi

  local codec="both"
  local scale=""
  local target_files=()
  local usage="Usage: compress_mp4_to_webm [av1|vp9|both] [scale WxH] [file]
  Codecs:
    av1  - libsvtav1, CRF 36, Opus audio 96k (best compression, slowest encode)
    vp9  - libvpx-vp9, CRF 32, Opus audio 96k (faster encode, broad support)
    both - generate both AV1 and VP9 outputs (default)
  Optionally, add a scale (e.g. 1280:720 or 1920:1080) to resize video.
  Optionally, specify a single mp4 file to compress.
  Example: compress_mp4_to_webm both 1280:720 myvideo.mp4"

  if [[ "$1" == "help" || "$1" == "--help" ]]; then
    echo "$usage"
    return 0
  fi

  [[ "$1" =~ ^(av1|vp9|both)$ ]] && codec="$1" && shift
  [[ "$1" =~ ^[0-9]+x[0-9]+$ || "$1" =~ ^[0-9]+:[0-9]+$ ]] && scale="$1" && shift

  if [[ -n "$1" && -f "$1" ]]; then
    target_files=("$1")
  else
    shopt -s globstar nullglob
    target_files=(**/*.mp4)
    shopt -u globstar nullglob
  fi

  if [[ ${#target_files[@]} -eq 0 ]]; then
    echo "${BYellow}[Warning]:${Color_Off} No mp4 files found."
    return 0
  fi

  for f in "${target_files[@]}"; do
    if [[ ! -f "$f" ]]; then
      continue
    fi

    local scale_opt=()
    if [[ -n "$scale" ]]; then
      local scale_filter="${scale//x/:}"
      scale_opt=(-vf "scale=${scale_filter}:force_original_aspect_ratio=decrease")
    fi

    if [[ "$codec" == "av1" || "$codec" == "both" ]]; then
      local output_av1="${f%.mp4} - browser-av1.webm"
      ffmpeg -i "$f" "${scale_opt[@]}" -c:v libsvtav1 -preset 8 -crf 36 -g 240 -pix_fmt yuv420p -row-mt 1 -c:a libopus -b:a 96k "$output_av1"
      if [[ $? -ne 0 ]]; then
        echo "${BIRed}[Error]:${Color_Off} AV1 compression failed for $f"
      fi
    fi

    if [[ "$codec" == "vp9" || "$codec" == "both" ]]; then
      local output_vp9="${f%.mp4} - browser-vp9.webm"
      ffmpeg -i "$f" "${scale_opt[@]}" -c:v libvpx-vp9 -row-mt 1 -threads 8 -b:v 0 -crf 32 -g 240 -pix_fmt yuv420p -c:a libopus -b:a 96k "$output_vp9"
      if [[ $? -ne 0 ]]; then
        echo "${BIRed}[Error]:${Color_Off} VP9 compression failed for $f"
      fi
    fi
  done
}
