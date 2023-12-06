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

[ -f $USER_CONFIG_DIRECTORY/config/function.zsh ] && source $USER_CONFIG_DIRECTORY/config/function.zsh

[ -f $USER_CONFIG_DIRECTORY/config/behavior.zsh ] && source $USER_CONFIG_DIRECTORY/config/behavior.zsh

[ -f $USER_CONFIG_DIRECTORY/config/p10k-config.zsh ] && source $USER_CONFIG_DIRECTORY/config/p10k-config.zsh
