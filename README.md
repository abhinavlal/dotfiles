# dotfiles

Command-line setup for macOS: zsh, the starship prompt, the Ghostty terminal,
git and gh, all in Catppuccin colors.

## Quick start

```sh
git clone https://github.com/abhinavlal/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run      # preview the config links
./install.sh --audit        # preview what Homebrew would do with your apps
./install.sh --brew         # install core tools, then link config
exec zsh
```

`install.sh` symlinks each file in `home/` to the same path under `$HOME`.
Before it replaces an existing file, it moves that file to
`~/.dotfiles-backup/`. You can run it again at any time. `--extras` also
installs the apps in `Brewfile.extras`.

## Apps installed without Homebrew

`./install.sh --audit` is read-only. For each Brewfile entry it predicts
what `brew bundle` will do:

| Status      | Meaning |
|-------------|---------|
| `brew`      | already managed by Homebrew |
| `new`       | not on this Mac; will be installed |
| `adopt`     | installed by hand; Homebrew takes over the existing app without reinstalling it |
| `mismatch`  | installed by hand, but the version differs; the install would fail and leave the app alone. Update the app or delete it first. |
| `app-store` | an App Store copy exists; use a `mas` entry instead, or delete it first |
| `installer` | installed by hand with a vendor installer; Homebrew runs the installer again over it |
| `untrusted` | from a third-party tap that Homebrew 7 ignores until it's trusted; add `trusted: true` to that Brewfile line |

It also lists what's on the Mac but not in any Brewfile, and suggests the
matching `cask` or `mas` line.

Entries marked `[password]` ask for an admin password. That covers vendor
installers, and also adopting most apps you installed by hand, because
macOS doesn't let other programs modify those app bundles without admin
rights. To install everything else unattended, skip them and install those
in a terminal afterwards:

```sh
HOMEBREW_BUNDLE_CASK_SKIP="expressvpn zoom netbird-ui" ./install.sh --extras
```

Adopting is safe: an app is only taken over if it updates itself or its
version matches exactly, and settings in `~/Library` aren't touched. Never
add `--force`, which deletes the existing app. `install.sh` never upgrades
what's already installed.

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
| `scripts/audit.sh`             | —                               | the `--audit` report |
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
