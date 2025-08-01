# > Config GPG key export GPG_TTY=$(tty) gpgconf --launch gpg-agent

# > Autojump command -> J
# [ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh
# autoload -U compinit && compinit -u

# > Env
# Load local environment variables
if [[ -f "$HOME/.local/bin/env" ]]; then
    . "$HOME/.local/bin/env"
fi

# > Zoxide
typeset -A ZEC
eval "$(zoxide init --cmd cd zsh)"
# eval "$(zoxide init zsh)"

source <(fzf --zsh)

# > Languages Manager Asdf
ASDF_DIR="$HOME/.asdf"

# > Direnv for Asdf
source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"
# load asdf direnv integration on shell opening
eval "$(direnv hook zsh)"

# > Bun is a JavaScript runtime
[ -s "/Users/johannpereira/.bun/_bun" ] && source "/Users/johannpereira/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# > HomeBrew GNU packages
if ! brew="$(command -v brew)" || [[ -z $brew ]]; then
    # HOMEBREW_NO_INSTALL_FROM_API=1
    HOMEBREW_PREFIX=$(brew --prefix)
    # gnubin; gnuman
    for d in ${HOMEBREW_PREFIX}/opt/*/libexec/gnubin; do export PATH=$d:$PATH; done
    # I actually like that man grep gives the BSD grep man page
    #for d in ${HOMEBREW_PREFIX}/opt/*/libexec/gnuman; do export MANPATH=$d:$MANPATH; done

    # Brew completions
    export PATH="/opt/homebrew/opt/icu4c@76/bin:$PATH"
    export PATH="/opt/homebrew/opt/icu4c@76/sbin:$PATH"
    export LDFLAGS="-L/opt/homebrew/opt/icu4c@76/lib"
    export CPPFLAGS="-I/opt/homebrew/opt/icu4c@76/include"
    export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@76/lib/pkgconfig"
fi

# > PNPM
export PNPM_HOME="/Users/johannpereira/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

# > Emacs
EMACSD=$HOME/.emacs.d

# > GOROOT
# export GOROOT="$(brew --prefix golang)/libexec"
export ASDF_GOLANG_MOD_VERSION_ENABLED=true

# > FastAnime
if ! fastanime="$(command -v fastanime)" || [[ -z $fastanime ]]; then
    fastanime completions
fi

# > Languages
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# > Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/johannpereira/.lmstudio/bin"

# > Python
# export PATH="$(brew --prefix python)/libexec/bin:$PATH"

# if [ -f .venv/bin/activate ]; then
#     source .venv/bin/activate
# fi


# Android SDK Configuration
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/emulator:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/johannpereira/.lmstudio/bin"
# End of LM Studio CLI section