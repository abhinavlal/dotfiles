# dotfiles

Command-line setup for macOS: zsh, the starship prompt, the Ghostty terminal,
git and gh, all in Catppuccin colors.

## Quick start

```sh
git clone https://github.com/abhinavlal/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run      # preview
./install.sh --brew         # install core tools, then link config
exec zsh
```

`install.sh` symlinks each file in `home/` to the same path under `$HOME`.
Before it replaces an existing file, it moves that file to
`~/.dotfiles-backup/`. You can run it again at any time. `--extras` also
installs the apps in `Brewfile.extras`.

## What's here

| Path in repo                   | Linked to                       | What it is |
|--------------------------------|---------------------------------|------------|
| `home/.zshrc`                  | `~/.zshrc`                      | history, options, completion, keys, aliases, fzf/zoxide, plugins, prompt |
| `home/.zprofile`               | `~/.zprofile`                   | Homebrew shellenv, OrbStack |
| `home/.gitconfig`              | `~/.gitconfig`                  | identity; includes `~/.gitconfig.local` |
| `home/.config/git/ignore`      | `~/.config/git/ignore`          | global gitignore |
| `home/.config/gh/config.yml`   | `~/.config/gh/config.yml`       | gh settings and aliases (no auth) |
| `home/.config/starship.toml`   | `~/.config/starship.toml`       | two-line prompt |
| `home/.config/ghostty/config`  | `~/.config/ghostty/config`      | font, theme, splits, keybinds |
| `Brewfile`                     | —                               | tools the config above depends on |
| `Brewfile.extras`              | —                               | optional apps and dev tools |
| `archive/legacy-2018/`         | — (never linked)                | old bash/vim dotfiles, for reference |

## Per-machine settings

These files are loaded if they exist. They aren't tracked, so keep secrets
and machine-specific settings in them:

- `~/.zshrc.local`: sourced at the end of `.zshrc`
- `~/.gitconfig.local`: for example, a different `user.email` on a work
  machine

These are deliberately **not** in this repo because it's public: `~/.npmrc`
(registry token), `~/.config/gh/hosts.yml` (gh auth) and `~/.ssh/`.

## Making changes

Because the files are symlinked, editing `~/.zshrc` edits the repo copy. Commit
and push from `~/.dotfiles`, then `git pull` on the other machines.
