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
