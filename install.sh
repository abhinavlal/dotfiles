#!/usr/bin/env bash
# install.sh — symlink every file under home/ into $HOME.
#
# Idempotent: correct links are left alone; anything else already at a target
# path is moved to ~/.dotfiles-backup/<path>.<timestamp> before linking.
# Written for macOS's stock bash 3.2 — no bash 4 features.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/home"
BACKUP_DIR="$HOME/.dotfiles-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
WITH_BREW=0
WITH_EXTRAS=0
brew_failed=""

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  -n, --dry-run   show what would change, touch nothing
      --audit     report how this Mac's apps line up with the Brewfiles, then exit
      --brew      also run 'brew bundle' on Brewfile (core CLI tools)
      --extras    also run 'brew bundle' on Brewfile.extras (apps; implies --brew)
  -h, --help      show this help

brew bundle never upgrades what is already installed here, and adopts apps
that were installed by hand. To skip casks that ask for an admin password:
  HOMEBREW_BUNDLE_CASK_SKIP="zoom expressvpn" ./install.sh --extras
EOF
}

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    --audit)      exec "$DOTFILES/scripts/audit.sh" ;;
    --brew)       WITH_BREW=1 ;;
    --extras)     WITH_BREW=1; WITH_EXTRAS=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "install.sh: unknown option '$arg'" >&2; usage >&2; exit 2 ;;
  esac
done

# Actions are always logged by the caller; this only decides whether they happen.
run() {
  (( DRY_RUN )) || "$@"
}

tilde() { printf '~%s' "${1#"$HOME"}"; }

# ── Packages ──────────────────────────────────────────────────────────────────
if (( WITH_BREW )); then
  if ! command -v brew &>/dev/null; then
    echo "install.sh: Homebrew not found — install it from https://brew.sh first" >&2
    exit 1
  fi
  # --no-upgrade: installing dotfiles shouldn't upgrade tools as a side effect.
  # A failed entry doesn't stop the config links below; it's reported at the end.
  brewfiles=(Brewfile)
  (( WITH_EXTRAS )) && brewfiles+=(Brewfile.extras)
  for brewfile in "${brewfiles[@]}"; do
    echo "brew    $brewfile"
    run brew bundle install --no-upgrade --file="$DOTFILES/$brewfile" || brew_failed="$brew_failed $brewfile"
  done
fi

# ── Links ─────────────────────────────────────────────────────────────────────
linked=0 unchanged=0 backed_up=0

while IFS= read -r -d '' src; do
  rel="${src#"$SRC"/}"
  target="$HOME/$rel"

  if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
    printf 'ok      %s\n' "$(tilde "$target")"
    unchanged=$((unchanged + 1))
    continue
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup="$BACKUP_DIR/$rel.$STAMP"
    printf 'backup  %s -> %s\n' "$(tilde "$target")" "$(tilde "$backup")"
    run mkdir -p "$(dirname "$backup")"
    run mv "$target" "$backup"
    backed_up=$((backed_up + 1))
  fi

  printf 'link    %s\n' "$(tilde "$target")"
  run mkdir -p "$(dirname "$target")"
  run ln -s "$src" "$target"
  linked=$((linked + 1))
done < <(find "$SRC" \( -type f -o -type l \) ! -name .DS_Store -print0 | sort -z)

echo
(( DRY_RUN )) && echo "Dry run — nothing changed."
echo "$linked linked, $unchanged already linked, $backed_up backed up."
(( linked )) && ! (( DRY_RUN )) && echo "Open a new shell (or run: exec zsh) to pick up changes."
if [[ -n "$brew_failed" ]]; then
  echo "brew bundle reported failures in:$brew_failed — see the output above, or run ./install.sh --audit." >&2
  exit 1
fi
exit 0
