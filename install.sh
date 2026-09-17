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
lang_failed=""

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

# ── Language defaults ─────────────────────────────────────────────────────────
# Installs a default node (nvm) and python (pyenv) the first time. A default
# that's already set is left alone, so re-running never switches versions.
NODE_DEFAULT="lts/*"
PYTHON_DEFAULT="3.13"          # pyenv resolves this to the latest 3.13.x
export NVM_DIR="$HOME/.nvm"
export PYENV_ROOT="$HOME/.pyenv"

# Subshells: nvm.sh isn't written for `set -eu`, and neither leaks into this script.
# Both are invoked through run(), which shellcheck can't see (SC2329).
# shellcheck disable=SC2329
setup_node() (
  set +eu
  mkdir -p "$NVM_DIR"
  # shellcheck source=/dev/null
  . "$(brew --prefix)/opt/nvm/nvm.sh" --no-use
  nvm install "$NODE_DEFAULT" && nvm alias default "$NODE_DEFAULT"
)
# shellcheck disable=SC2329
setup_python() (
  pyenv install --skip-existing "$PYTHON_DEFAULT" &&
    pyenv global "$(pyenv latest "$PYTHON_DEFAULT")"
)

if (( WITH_BREW )); then
  if [[ -e "$NVM_DIR/alias/default" ]]; then
    echo "ok      node default ($(<"$NVM_DIR/alias/default"))"
  elif [[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
    echo "node    nvm install $NODE_DEFAULT (default)"
    run setup_node || lang_failed="$lang_failed node"
  else
    echo "skip    node default (nvm not installed)"
  fi

  if [[ -e "$PYENV_ROOT/version" ]]; then
    echo "ok      python default ($(<"$PYENV_ROOT/version"))"
  elif command -v pyenv &>/dev/null; then
    echo "python  pyenv install $PYTHON_DEFAULT (global)"
    run setup_python || lang_failed="$lang_failed python"
  else
    echo "skip    python default (pyenv not installed)"
  fi
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
fi
if [[ -n "$lang_failed" ]]; then
  echo "default version setup failed for:$lang_failed — see the output above." >&2
fi
[[ -z "$brew_failed$lang_failed" ]] || exit 1
exit 0
