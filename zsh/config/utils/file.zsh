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
