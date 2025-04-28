#!/usr/bin/env zsh

# > ------------ < #
# >  Zsh Colors  < #
# > ------------ < #
Color_Off='\033[0m'      # Text Reset
BGreen='\033[1;32m'      # Green
IRed='\033[0;91m'        # Red
ICyan='\033[0;96m'       # Cyan
On_IPurple='\033[0;105m' # Purple

# Current machine type
check_machine() {
    unameOut="$(uname -s)"
    case "${unameOut}" in
    Linux*) machine=Linux ;;
    Darwin*) machine=Mac ;;
    CYGWIN*) machine=Cygwin ;;
    MINGW*) machine=MinGw ;;
    MSYS_NT*) machine=MSys ;;
    *) machine="UNKNOWN:${unameOut}" ;;
    esac

    echo $machine
}

set -e

# > -------- < #
# >  Basics  < #
# > -------- < #

if [[ "$machine" == "Mac" ]] && ! brew="$(command -v brew)" || [[ -z $brew ]]; then
    echo "${BGreen}Installing Homebrew${Color_Off}"
    sleep 5
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        echo "${IRed}Homebrew installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Homebrew installation${Color_Off}\n"
fi

if ! git="$(command -v git)" || [[ -z $git ]]; then
    echo -e "${BGreen}Installing Git${Color_Off}"
    sleep 5
    brew install coreutils git || {
        echo "${IRed}Git installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Git installation${Color_Off}\n"
fi

if ! curl="$(command -v curl)" || [[ -z $curl ]]; then
    echo -e "${BGreen}Installing Curl${Color_Off}"
    sleep 5
    brew install coreutils curl || {
        echo "${IRed}Curl installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Curl installation${Color_Off}\n"
fi

# > ------------------- < #
# >  Languages Manager  < #
# > ------------------- < #

# if ! nvm="$(type -p nvm)" || [[ -z $nvm ]] && ! [ -d "$HOME/.nvm" ]; then
#     echo -e "${BGreen}Installing NVM${Color_Off}"
#     sleep 5
#     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.6/install.sh | bash || {
#         echo "${IRed}NVM installation failed${Color_Off}"
#         exit 1
#     }
# else
#     echo -n "\n${ICyan}Skipping NVM installation${Color_Off}\n"
# fi

if ! asdf="$(type -p asdf)" || [[ -z $asdf ]]; then
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
    asdf update
fi

# > ----------- < #
# >  Languages  < #
# > ----------- < #

# if ! node="$(command -v node)" || [[ -z $node ]]; then
#     echo -e "${BGreen}Installing Node.js${Color_Off}"
#     sleep 5
#     nvm install --lts || {
#         echo "${IRed}Node.js installation failed${Color_Off}"
#         exit 1
#     }
#     nvm alias default node || {
#         echo "${IRed}Setting Node.js version failed${Color_Off}"
#         exit 1
#     }
# else
#     echo -n "\n${ICyan}Skipping Node.js installation${Color_Off}\n"
# fi

if ! direnv="$(command -v direnv)" || [[ -z $direnv ]]; then
    echo -e "${BGreen}Installing Direnv${Color_Off}"
    sleep 5
    asdf plugin-add direnv || {
        echo "${IRed}Direnv plugin addition failed${Color_Off}"
        exit 1
    }
    asdf install direnv latest || {
        echo "${IRed}Direnv installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Direnv installation${Color_Off}\n"
fi

if ! go="$(command -v go)" || [[ -z $go ]]; then
    echo -e "${BGreen}Installing Golang${Color_Off}"
    sleep 5
    asdf plugin add golang https://github.com/asdf-community/asdf-golang.git || {
        echo "${IRed}Golang plugin addition failed${Color_Off}"
        exit 1
    }
    asdf install golang latest || {
        echo "${IRed}Golang installation failed${Color_Off}"
        exit 1
    }
    asdf global golang latest || {
        echo "${IRed}Setting Golang version failed${Color_Off}"
        exit 1
    }

else
    echo -n "\n${ICyan}Skipping Golang installation${Color_Off}\n"
fi

if ! elm="$(command -v elm)" || [[ -z $elm ]]; then
    echo -e "${BGreen}Installing Elm${Color_Off}"
    sleep 5
    asdf plugin-add elm https://github.com/asdf-community/asdf-elm.git || {
        echo "${IRed}Elm plugin addition failed${Color_Off}"
        exit 1
    }
    asdf install elm latest || {
        echo "${IRed}Elm installation failed${Color_Off}"
        exit 1
    }
    asdf global elm latest || {
        echo "${IRed}Setting Elm version failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Elm installation${Color_Off}\n"
fi

if ! python="$(command -v python)" || [[ -z $python ]]; then
    echo -e "${BGreen}Installing Python${Color_Off}"
    sleep 5
    asdf plugin-add python || {
        echo "${IRed}Python plugin addition failed${Color_Off}"
        exit 1
    }
    asdf install python latest || {
        echo "${IRed}Python installation failed${Color_Off}"
        exit 1
    }
    asdf global python latest || {
        echo "${IRed}Setting Python version failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Python installation${Color_Off}\n"
fi

if ! ruby="$(command -v ruby)" || [[ -z $ruby ]] && ! [ -d "$HOME/.asdf/shims/ruby" ]; then
    echo -e "${BGreen}Installing Ruby${Color_Off}"
    sleep 5
    asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git || {
        echo "${IRed}Ruby plugin addition failed${Color_Off}"
        exit 1
    }
    asdf install ruby latest || {
        echo "${IRed}Ruby installation failed${Color_Off}"
        exit 1
    }
    asdf global ruby latest || {
        echo "${IRed}Setting Ruby version failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Ruby installation${Color_Off}\n"
fi

# Python UV
if ! uv="$(command -v uv)" || [[ -z $uv ]]; then
    echo -e "${BGreen}Installing UV${Color_Off}"
    sleep 5
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo -n "\n${ICyan}Skipping UV installation${Color_Off}\n"
fi

# > ------- < #
# >  Fonts  < #
# > ------- < #
echo -n "${On_IPurple}Do you want to install nerd-fonts? (yY/n): ${Color_Off}"
read install_nerd_fonts
case $install_nerd_fonts in
[yY] | [yY][eE][sS] | [yY][eE][aA] | [yY][uU][pP])
    brew tap homebrew/cask-fonts
    brew search '/font-.*-nerd-font/' | awk '{ print $1 }' | xargs -I{} brew install --cask {} || true
    ;;
*)
    echo -n "\n${ICyan}Skipping nerd-fonts installation${Color_Off}\n"
    ;;
esac

# > ------- < #
# >  Utils  < #
# > ------- < #

if ! lazygit="$(command -v lazygit)" || [[ -z $lazygit ]]; then
    echo -e "${BGreen}Installing Lazygit${Color_Off}"
    sleep 5
    brew install jesseduffield/lazygit/lazygit || {
        echo "${IRed}Lazygit installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Lazygit installation${Color_Off}\n"
fi

if ! bat="$(command -v bat)" || [[ -z $bat ]]; then
    echo -e "${BGreen}Installing Bat${Color_Off}"
    sleep 5
    brew install bat || {
        echo "${IRed}Bat installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Bat installation${Color_Off}\n"
fi

if ! yarn="$(command -v yarn)" || [[ -z $yarn ]]; then
    echo -e "${BGreen}Installing Yarn${Color_Off}"
    sleep 5
    npm install -g yarn || {
        echo "${IRed}Yarn installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Yarn installation${Color_Off}\n"
fi

if ! pnpm="$(command -v pnpm)" || [[ -z $pnpm ]]; then
    echo -e "${BGreen}Installing Pnpm${Color_Off}"
    sleep 5
    npm install -g pnpm || {
        echo "${IRed}Pnpm installation failed${Color_Off}"
        exit 1
    }
else
    echo -n "\n${ICyan}Skipping Pnpm installation${Color_Off}\n"
fi
