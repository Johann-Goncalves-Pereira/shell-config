# shell-config

Personal zsh setup. The prompt, `...` completion, and the git/media/phone helpers are the same shell as before. The foundation underneath is antidote, mise, and Atuin.

## What loads

`~/.zshenv` and `~/.zprofile` are symlinks into this repo. `~/.zshrc` points at `zsh/base.zsh`.

1. Homebrew and extra paths
2. [mise](https://mise.jdx.dev/) shims for language versions (reads `~/.tool-versions` and `zsh/config/mise.toml`; no per-`cd` hook)
3. direnv, for existing `.envrc` files
4. zoxide (`cd`), fzf (Ctrl-T, Alt-C), Atuin (Ctrl-R)
5. A small [antidote](https://antidote.sh/) plugin list: completions, fzf-tab, autosuggestions, syntax highlighting, autopair, wakatime
6. oh-my-posh, theme file `zsh/config/prompt/johanns.json` (skipped in Apple Terminal)

asdf and fnm are not sourced anymore. Their binaries can stay installed until you trust `mise doctor`.

## Set up

macOS only. Clone **exactly** to `~/.shell-config` (paths are hardcoded). Needs [GitHub SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone git@github.com:Johann-Goncalves-Pereira/shell-config.git ~/.shell-config
cd ~/.shell-config && ./setup
```

`./setup` installs Homebrew (if missing), the Brewfile stack (shell + media + phone/audio), uv, Rust via rustup, Node from `zsh/config/mise.toml`, optionally JetBrainsMono Nerd Font, then links:

```sh
ln -sfn ~/.shell-config/zsh/zshenv.zsh ~/.zshenv
ln -sfn ~/.shell-config/zsh/zprofile.zsh ~/.zprofile
ln -sfn ~/.shell-config/zsh/base.zsh ~/.zshrc
```

Non-interactive font: `INSTALL_NERD_FONT=1 ./setup` or `INSTALL_NERD_FONT=0 ./setup`.

After the first new terminal: Atuin history is separate (`atuin login` / `atuin import`). Extra languages are optional, for example:

```sh
mise use -g go@latest python@3.13 ruby@3.2
```

## Day to day

- `...` then Tab still walks up directories, through fzf-tab
- `gps`, `gpo`, `gcdp`, `git_purge` are unchanged in spirit
- `update` refreshes Homebrew, Mac App Store, antidote, mise, and the local web UI
- `direnv_nvm` asks for a Node version and runs `mise use --path . node@<version>`

## Check the config

```sh
zsh ~/.shell-config/zsh/scripts/validate.zsh
```
