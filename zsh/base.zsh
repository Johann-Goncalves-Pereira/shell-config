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

# [ -f $USER_CONFIG_DIRECTORY/config/prompt/.p10k-config.zsh ] && source $USER_CONFIG_DIRECTORY/config/prompt/.p10k-config.zsh
[ -f $USER_CONFIG_DIRECTORY/config/prompt/oh-my-posh.zsh ] && source $USER_CONFIG_DIRECTORY/config/prompt/oh-my-posh.zsh

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/johannpereira/.lmstudio/bin"
# End of LM Studio CLI section

