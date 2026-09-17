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

`--brew` also sets up default language versions the first time: the latest
node LTS with nvm, and the latest Python 3.13 with pyenv. If a default is
already set, it's left alone. To change the versions for new machines, edit
`NODE_DEFAULT` and `PYTHON_DEFAULT` in `install.sh`. On a machine that's
already set up, use `nvm alias default <version>` or
`pyenv global <version>`.

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
installers and every app being adopted, because Homebrew may need `sudo` to
fix the permissions of an app you installed by hand. To install everything
else unattended, skip them. The audit prints both commands:

```sh
HOMEBREW_BUNDLE_CASK_SKIP="chatgpt expressvpn google-chrome" ./install.sh --extras
brew install --cask --adopt chatgpt expressvpn google-chrome   # in your own terminal
```

Keep `--adopt` in the second command. `brew bundle` adds it for you, but a
plain `brew install --cask` refuses to install over an existing app.

Vendor-installer casks such as `expressvpn` also need your terminal app
allowed in System Settings > Privacy & Security > App Management. Without
that, the installer fails partway with "Failed to send install request to
install helper" and leaves a broken, root-owned app in `/Applications`.

Adopting is safe: an app is only taken over if it updates itself or its
version matches exactly, and settings in `~/Library` aren't touched. Never
add `--force`, which deletes the existing app. `install.sh` never upgrades
what's already installed.

## What's here

| Path in repo                   | Linked to                       | What it is |
|--------------------------------|---------------------------------|------------|
| `home/.zshrc`                  | `~/.zshrc`                      | history, options, completion, keys, aliases, fzf/zoxide, nvm/pyenv, plugins, prompt |
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
