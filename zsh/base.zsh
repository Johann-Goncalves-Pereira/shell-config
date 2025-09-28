# > ------------------- < #
# >  Zsh configuration  < #
# > ------------------- < #

# > ----- < #
# >  Var  < #
# > ----- < #

USER_CONFIG_DIRECTORY="$HOME/.shell-config/zsh"

# > ------------------ < #
# >  Load config file  < #
# > ------------------ < #

[ -f $USER_CONFIG_DIRECTORY/config/color.zsh ] && source $USER_CONFIG_DIRECTORY/config/color.zsh

[ -f $USER_CONFIG_DIRECTORY/config/cache.zsh ] && source $USER_CONFIG_DIRECTORY/config/cache.zsh

[ -f $USER_CONFIG_DIRECTORY/config/zinit.zsh ] && source $USER_CONFIG_DIRECTORY/config/zinit.zsh

[ -f $USER_CONFIG_DIRECTORY/config/config.zsh ] && source $USER_CONFIG_DIRECTORY/config/config.zsh

[ -f $USER_CONFIG_DIRECTORY/config/alias.zsh ] && source $USER_CONFIG_DIRECTORY/config/alias.zsh

[ -f $USER_CONFIG_DIRECTORY/config/utils.zsh ] && source $USER_CONFIG_DIRECTORY/config/utils.zsh

[ -f $USER_CONFIG_DIRECTORY/config/behavior.zsh ] && source $USER_CONFIG_DIRECTORY/config/behavior.zsh

[ -f $USER_CONFIG_DIRECTORY/config/work.zsh ] && source $USER_CONFIG_DIRECTORY/config/work.zsh

# Python related fallbacks / helpers
[ -f $USER_CONFIG_DIRECTORY/config/python.zsh ] && source $USER_CONFIG_DIRECTORY/config/python.zsh

# [ -f $USER_CONFIG_DIRECTORY/config/prompt/.p10k-config.zsh ] && source $USER_CONFIG_DIRECTORY/config/prompt/.p10k-config.zsh
[ -f $USER_CONFIG_DIRECTORY/config/prompt/oh-my-posh.zsh ] && source $USER_CONFIG_DIRECTORY/config/prompt/oh-my-posh.zsh



# Added Docker CLI to PATH
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/johannpereira/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
