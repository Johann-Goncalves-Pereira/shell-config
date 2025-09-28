# Python convenience and fallback aliases/functions
# This file ensures `python` and `pip` commands exist even if only python3/pip3 are installed.

# If `python` not found but `python3` exists, create alias
if ! command -v python >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  alias python="python3"
fi

# Prefer using `python -m pip` pattern; create pip alias if missing
# First check if pip exists already
if ! command -v pip >/dev/null 2>&1; then
  if command -v pip3 >/dev/null 2>&1; then
    alias pip="pip3"
  elif command -v python3 >/dev/null 2>&1; then
    # Create a function so flags and arguments pass through
    pip() { python3 -m pip "$@"; }
  fi
fi

# Add user base binary directory (for pip --user installs)
# macOS + Python often installs user scripts in ~/Library/Python/<version>/bin
# Guard against nomatch error when there are no subdirectories yet.
if [ -d "$HOME/Library/Python" ]; then
  setopt local_options null_glob 2>/dev/null
  for py_dir in "$HOME/Library/Python"/*; do
    [ -d "$py_dir/bin" ] || continue
    case :$PATH: in
      *:"$py_dir/bin":*) ;; # already in PATH
      *) export PATH="$py_dir/bin:$PATH";;
    esac
  done
fi

# Ensure ~/.local/bin is on PATH (common for virtualenv / user installs)
if [ -d "$HOME/.local/bin" ]; then
  case :$PATH: in
    *:"$HOME/.local/bin":*) ;;
    *) export PATH="$HOME/.local/bin:$PATH";;
  esac
fi

# Function: pywhich - show which python and its version
pywhich() {
  echo "python -> $(command -v python || echo 'missing')"
  echo "python3 -> $(command -v python3 || echo 'missing')"
  if command -v python >/dev/null 2>&1; then
    python --version 2>&1
  fi
  if command -v pip >/dev/null 2>&1; then
    pip --version 2>&1
  fi
}

# Lightweight virtualenv helpers if python3 present
if command -v python3 >/dev/null 2>&1; then
  mkvenv() { python3 -m venv "${1:-.venv}" && echo "Created venv at ${1:-.venv}. Activate with: source ${1:-.venv}/bin/activate"; }
fi
