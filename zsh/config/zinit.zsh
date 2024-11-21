
# > --------------- < #
# >  Plugins Zinit  < #
# > --------------- < #
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
	print -P "%F{33}▓▒░ %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
	command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
	command git clone --depth=1 https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
		print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
			print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

#? Load a few important annexes, without Turbo (this is currently required for annexes)
zinit light-mode depth"1" for \
	  zdharma-continuum/zinit-annex-bin-gem-node \
	  zdharma-continuum/zinit-annex-patch-dl

# : End of Zinit's installer chunk

zi ice as'null' from"gh-r" sbin
zi light ajeetdsouza/zoxide		

# : Oh My Zsh
zinit for \
	OMZL::correction.zsh \
	OMZL::directories.zsh \
	OMZL::history.zsh \
	OMZL::key-bindings.zsh \
	OMZL::theme-and-appearance.zsh \
	OMZP::common-aliases

zinit wait lucid for \
	OMZP::colored-man-pages \
	OMZP::cp \
	OMZP::extract \
	OMZP::fancy-ctrl-z \
	OMZP::git \
	OMZP::sudo \
	OMZP::man \
	OMZP::gitignore \
	OMZP::git-auto-fetch \
	OMZP::catimg \
	OMZP::compleat \
	OMZP::command-not-found \
	OMZP::npm \
	OMZP::yarn \
	OMZP::node \
	OMZP::golang \
	OMZP::flutter \
	OMZP::react-native \
	OMZP::vscode \
	OMZP::torrent \
	OMZP::web-search \
	OMZP::copypath \
	OMZP::copyfile \
	OMZP::asdf \
	OMZP::brew \
	  
# : Completion enhancements
zinit wait lucid depth"1" for \
	  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
	  zdharma-continuum/fast-syntax-highlighting \
	  blockf \
	  zsh-users/zsh-completions \
	  atload"!_zsh_autosuggest_start" \
	  zsh-users/zsh-autosuggestions \
	  zdharma-continuum/history-search-multi-word \
	  jspears/worktree \
	  lukechilds/zsh-nvm 
		# \ unixorn/fzf-zsh-plugin



zinit wait lucid light-mode depth"1" for \
	  zsh-users/zsh-history-substring-search \
	  hlissner/zsh-autopair \
    sobolevn/wakatime-zsh-plugin

zinit ice wait lucid

# > --------- < #
# > Utilities < #
# > --------- < #

# : Git extras
zinit ice wait lucid as"program" pick"$ZPFX/bin/git-*" src"etc/git-extras-completion.zsh" make"PREFIX=$ZPFX" if'(( $+commands[make] ))'
zinit light tj/git-extras

# : Git UI
zinit ice wait lucid as"null" from"gh-r" sbin"**/gitui"
zinit light extrawurst/gitui

# : Prettify ls
if (( $+commands[eza] )); then
	alias ls='eza --icons --time-style=long-iso --group-directories-first'
elif (( $+commands[gls] )); then
	alias ls='gls --color=tty --group-directories-first'
else
	alias ls='ls --color=tty --group-directories-first'
fi

# Modern Unix commands
# See https://github.com/ibraheemdev/modern-unix
zinit wait as"null" lucid from"gh-r" for \
	  atload"alias ls='eza --color=auto --group-directories-first'; alias la='ls -laFh'" sbin"**/eza" if'[[ $OSTYPE != darwin* ]] && (( $+commands[unzip] ))' eza-community/eza \
	  atload"alias cat='bat -p --wrap character'" cp"**/bat.1 -> $ZPFX/share/man/man1" mv"**/autocomplete/bat.zsh -> _bat" completions sbin"**/bat" @sharkdp/bat \
	  cp"**/fd.1 -> $ZPFX/share/man/man1" completions sbin"**/fd" @sharkdp/fd \
	  cp"**/hyperfine.1 -> $ZPFX/share/man/man1" completions sbin"**/hyperfine" @sharkdp/hyperfine \
	  cp"**/doc/rg.1 -> $ZPFX/share/man/man1" completions sbin"**/rg" BurntSushi/ripgrep \
	  atload"alias top=btm" completions sbin"**/btm" ClementTsang/bottom \
	  atload"alias diff=delta" sbin"**/delta" dandavison/delta \
	  atload"alias df=duf" bpick"*(.zip|tar.gz)" sbin muesli/duf \
	  atload"alias du=dust" sbin"**/dust" bootandy/dust \
	  atload"alias ping=gping" sbin"**/gping" orf/gping \
	  atload"alias la='ls --long --icons --all'; ll='la --header'" \
	  atload"alias lt='eza -T -L=3 --icons'" \
	  bpick"*.zip" sbin"**/procs" if'(( $+commands[unzip] )) && [[ $CPUTYPE != aarch* ]]' dalance/procs	
	  # atload"alias help=tldr" mv"tealdeer* -> tldr" dl'https://github.com/dbrgn/tealdeer/releases/latest/download/completions_zsh -> _tldr;' completions sbin"tldr" dbrgn/tealdeer \

# FZF: fuzzy finderls
zinit ice wait lucid as"null" from"gh-r" src'key-bindings.zsh' completions sbin'**/fzf' \
	  dl'https://raw.githubusercontent.com/junegunn/fzf/master/shell/key-bindings.zsh;
		 https://raw.githubusercontent.com/junegunn/fzf/master/shell/completion.zsh -> _fzf;
		 https://raw.githubusercontent.com/junegunn/fzf/master/man/man1/fzf.1 -> $ZPFX/share/man/man1/fzf.1;
		 https://raw.githubusercontent.com/junegunn/fzf/master/man/man1/fzf-tmux.1 -> $ZPFX/share/man/man1/fzf-tmux.1;'
zinit light junegunn/fzf

zinit ice wait lucid depth"1" atload"zicompinit; zicdreplay" blockf
zinit light Aloxaf/fzf-tab

zstyle ':fzf-tab:*' switch-group ',' '.'

zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:complete:*:options' sort true
zstyle ':fzf-tab:complete:(cd|ls|exa|eza|bat|cat|emacs|nano|vi|vim):*' \
	   fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
	   fzf-preview 'echo ${(P)word}'

# Preivew `kill` and `ps` commands
zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w -w'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
	   '[[ $group == "[process ID]" ]] &&
		if [[ $OSTYPE == darwin* ]]; then
		   ps -p $word -o comm="" -w -w
		elif [[ $OSTYPE == linux* ]]; then
		   ps --pid=$word -o cmd --no-headers -w -w
		fi'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags '--preview-window=down:3:wrap'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'

# Preivew `git` commands
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
	   'git diff $word | delta'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview \
	   'git log --color=always $word'
zstyle ':fzf-tab:complete:git-help:*' fzf-preview \
	   'git help $word | bat -plman --color=always'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview \
	   'case "$group" in
	"commit tag") git show --color=always $word ;;
	*) git show --color=always $word | delta ;;
	esac'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
	   'case "$group" in
	"modified file") git diff $word | delta ;;
	"recent commit object name") git show --color=always $word | delta ;;
	*) git log --color=always $word ;;
	esac'

# Privew help
zstyle ':fzf-tab:complete:(\\|)run-help:*' fzf-preview 'run-help $word'
zstyle ':fzf-tab:complete:(\\|*/|)man:*' fzf-preview 'man $word'

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git || git ls-tree -r --name-only HEAD || rg --files --hidden --follow --glob '!.git' || find ."
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 90% --border'
export FZF_CTRL_T_OPTS="--preview '(bat --style=numbers --color=always {} || cat {} || tree -NC {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:5:hidden:wrap --bind '?:toggle-preview' --exact"
export FZF_ALT_C_OPTS="--preview 'tree -NC {} | head -200'"
