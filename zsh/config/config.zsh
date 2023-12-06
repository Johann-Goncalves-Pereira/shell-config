# > Config GPG key
export GPG_TTY=$(tty)
gpgconf --launch gpg-agent

# > Autojump command -> J
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh
autoload -U compinit && compinit -u

# > Languages Manager Asdf
ASDF_DIR="$HOME/.asdf"

# > Direnv for Asdf
source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"
# load asdf direnv integration on shell oppening
eval "$(direnv hook zsh)"

# > Bun is a JavaScript runtime
[ -s "/Users/johannpereira/.bun/_bun" ] && source "/Users/johannpereira/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# > HomeBrew GNU packages
if ! brew="$(command -v brew)" || [[ -z $brew ]]; then
    HOMEBREW_PREFIX=$(brew --prefix)
    # gnubin; gnuman
    for d in ${HOMEBREW_PREFIX}/opt/*/libexec/gnubin; do export PATH=$d:$PATH; done
    # I actually like that man grep gives the BSD grep man page
    #for d in ${HOMEBREW_PREFIX}/opt/*/libexec/gnuman; do export MANPATH=$d:$MANPATH; done
fi

# > Emacs
EMACSD=$HOME/.emacs.d

# // # > Yarn bin path
# // export PATH="$PATH:$(yarn global bin)"

# // #   > Homebrew completion
# // if ! type "$brew" >/dev/null; then
# //     FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
# //     autoload -Uz compinit
# //     compinit
# // fi

# // > Node Nvm
# // export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
# // [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# // > HomeBrew Path
# // eval "$(/opt/homebrew/bin/brew shellenv)"

# // Asdf Golang GOPATH config
# // . ~/.asdf/plugins/golang/set-env.zsh

# // Colors LS
# // source $(dirname $(gem which colorls))/tab_complete.sh
