
# Homebrew: Apple Silicon, Intel, then Linuxbrew — whichever exists.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [[ -x "$_brew" ]] && { eval "$("$_brew" shellenv zsh)"; break; }
done
unset _brew

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
