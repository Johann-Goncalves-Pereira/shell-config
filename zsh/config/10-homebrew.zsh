# GNU userland from Homebrew, only when brew itself is installed.
# The previous guard was inverted (`if ! brew`) and never ran on this machine.
if [[ -z ${HOMEBREW_PREFIX:-} ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if (( $+commands[brew] )); then
  () {
    local d
    for d in "${HOMEBREW_PREFIX}"/opt/*/libexec/gnubin(N); do
      path=("$d" $path)
    done
  }
  export PATH

  # Unversioned opt/icu4c follows the current keg (78 on this machine).
  # Do not export global LDFLAGS/CPPFLAGS; they leaked into every build and
  # the curl block used to clobber the icu flags.
  if [[ -d "${HOMEBREW_PREFIX}/opt/icu4c/bin" ]]; then
    path=("${HOMEBREW_PREFIX}/opt/icu4c/bin" "${HOMEBREW_PREFIX}/opt/icu4c/sbin" $path)
  fi
  if [[ -d "${HOMEBREW_PREFIX}/opt/icu4c/lib/pkgconfig" ]]; then
    export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/opt/icu4c/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  fi
  export PATH
fi
