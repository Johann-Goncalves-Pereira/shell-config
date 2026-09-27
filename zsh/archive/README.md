# Archived on purpose

These files are the previous foundation. They are not sourced.

- `zinit.zsh` — zinit and Oh My Zsh plugin list, replaced by `plugins/zsh_plugins.txt`
- `config.zsh` — environment block, including the inverted Homebrew guard
- `behavior.zsh` — completion styles and keybinds, now split across `40-options.zsh`, `50-completions.zsh`, and `60-keys.zsh`
- `cache.zsh` — compdump path that depended on an unset `$ZSH`
- `prompt/.p10k.zsh` and `prompt/.p10k-config.zsh` — Powerlevel10k, unused once oh-my-posh became the prompt. The files now live in this directory under `prompt/`.

Rollback is `git checkout` of `zsh/base.zsh` plus moving the file you need back under `zsh/config/`.
