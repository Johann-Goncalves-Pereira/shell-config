# What I use today
- [ ] Bash
- [x] Zsh

## Bash Settings

My personal settings

## Zsh Settings

1. Useful plugins.
2. Cool and useful theme.
  - ![image](https://user-images.githubusercontent.com/62612685/173672501-b030f955-8995-447d-b58a-4a0c45b997e4.png)
3. Personal functions to automate tasks.
  - Clean docker.
  - Clean branch.
  - Reload shell.
  - cd just with dots.
  - Clock.
  - direnv.
  - Git shortcuts.
  - Jump to file.
4. ls cool display.
 - ![image](https://user-images.githubusercontent.com/62612685/173672089-2ee7e91f-094f-4401-ba9d-2dbebf2ae4fa.png)

## SetUp

Clone in your home directory.

```sh
git@github.com:Johann-Goncalves-Pereira/shell-config.git ~/.shell-config
```

or

```sh
https://github.com/Johann-Goncalves-Pereira/shell-config.git ~/.shell-config
```

First make the symbolic link.

```sh
ln -s .shell-config/zsh/base.zsh .zshrc
ln -s .shell-config/zsh/config/prompt/.p10k.zsh .p10k.zsh
```
