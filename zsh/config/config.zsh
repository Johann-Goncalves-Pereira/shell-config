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
# source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"
# load asdf direnv integration on shell oppening
# eval "$(direnv hook zsh)"

# > Bun is a JavaScript runtime
[ -s "/Users/johannpereira/.bun/_bun" ] && source "/Users/johannpereira/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# > HomeBrew GNU packages
# if ! brew="$(command -v brew)" || [[ -z $brew ]]; then
#     # HOMEBREW_NO_INSTALL_FROM_API=1
#     HOMEBREW_PREFIX=$(brew --prefix)
#     # gnubin; gnuman
#     for d in ${HOMEBREW_PREFIX}/opt/*/libexec/gnubin; do export PATH=$d:$PATH; done
#     # I actually like that man grep gives the BSD grep man page
#     #for d in ${HOMEBREW_PREFIX}/opt/*/libexec/gnuman; do export MANPATH=$d:$MANPATH; done

#     # Brew completions
#     export PATH="/opt/homebrew/opt/icu4c@76/bin:$PATH"
#     export PATH="/opt/homebrew/opt/icu4c@76/sbin:$PATH"
#     export LDFLAGS="-L/opt/homebrew/opt/icu4c@76/lib"
#     export CPPFLAGS="-I/opt/homebrew/opt/icu4c@76/include"
#     export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@76/lib/pkgconfig"
# fi

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


# > FastAnime
# if ! fastanime="$(command -v fastanime)" || [[ -z $fastanime ]]; then
# fastanime completions
# fi
