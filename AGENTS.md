# Agent guide: dotfiles

This repo holds Abhinav's command-line config. When you're asked to "set up
this machine" or "sync my dotfiles", follow these steps.

## Set up a new machine

1. Clone the repo to `~/.dotfiles`. The links point to wherever the checkout
   lives, so don't clone it into a temp or project directory.
   `git clone https://github.com/abhinavlal/dotfiles.git ~/.dotfiles`
2. Check Homebrew with `command -v brew`. If it's missing, ask the user before
   installing it, because the installer needs sudo and asks questions.
3. Run `./install.sh --dry-run` and show the user what would be backed up or
   linked.
4. Run `./install.sh --brew`. Use `--extras` only if the user wants the apps.
   Don't install Brewfile.extras without asking.
5. Verify:
   - `zsh -i -c exit` runs with no errors
   - `readlink ~/.zshrc` points into `~/.dotfiles/home/`
   - `starship --version`, `eza --version` and `bat --version` all work
6. Ask the user whether this machine needs a different git email. If it does,
   write it to `~/.gitconfig.local`, not to the tracked `.gitconfig`:
   ```
   [user]
       email = someone@example.com
   ```
7. Tell the user to open a new terminal or run `exec zsh`. For Ghostty
   changes, reload with cmd+shift+,.

## Sync changes

- **Pull:** `git -C ~/.dotfiles pull --rebase`. After that, run `./install.sh`
  only if new files were added under `home/`. Existing links pick up changes
  automatically.
- **Push:** the files in `$HOME` are symlinks into the repo, so edits already
  show up in `git -C ~/.dotfiles status`. Commit with a short imperative
  message and push to `m`, the default branch.
- **Add a new config file:** move it into `home/` at the same relative path
  (`~/.config/foo/bar` becomes `home/.config/foo/bar`), then run
  `./install.sh` to link it back. If the file needs a new tool, add that
  tool to `Brewfile`.

## Rules

- **The repo is public.** Never commit tokens, passwords, auth files,
  private keys, SSH host lists, internal hostnames/IPs, or `.npmrc`
  credentials. Before every commit, grep the diff for `token`, `secret`,
  `password`, `_authToken`, `BEGIN .* PRIVATE KEY`, and IP addresses. Put
  machine-specific or secret values in `~/.zshrc.local` or
  `~/.gitconfig.local`, which aren't tracked.
- Never touch `archive/`, which is a frozen reference copy.
- Keep `home/.zshrc` guarded. Wrap any tool integration in
  `command -v <tool>` so a machine without the tool still gets a working
  shell.
- `install.sh` has to keep working on macOS's stock bash 3.2 (no associative
  arrays, no `mapfile`). Check it with `shellcheck install.sh`.
- Don't force-push or rewrite history on `m`.
