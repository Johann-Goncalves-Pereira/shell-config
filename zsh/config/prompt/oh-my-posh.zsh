# > Oh My Posh
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  eval "$(oh-my-posh init zsh --config $HOME/.shell-config/zsh/config/prompt/johanns.json)"
  # eval "$(oh-my-posh init zsh)"
  # eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/1_shell.omp.json)"
fi

# {
#   "type": "npm",
#   "style": "powerline",
#   "foreground": "#AA2901",
#   "template": "<#cc7eda> \u00bb </><#CB0200></> {{ .Full }}",
#   "display_mode": "files",
#   "extensions": ["package-lock.json"]
# },
# {
#   "type": "yarn",
#   "style": "powerline",
#   "foreground": "#3B2D62",
#   "template": "<#cc7eda> \u00bb </><#5955D1></> {{ .Full }}",
#   "display_mode": "files",
#   "extensions": ["yarn.lock"]
# },
