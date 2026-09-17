# ~/.zshrc — interactive shell config
# Layout: env → history → options → completion → keys → aliases → tools →
#         plugins → prompt → local overrides
# Machine-specific overrides go in ~/.zshrc.local (sourced last, git-ignored).

# ── Environment ───────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export EDITOR="${EDITOR:-vim}"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS="-R -F -i -M --mouse"
if command -v bat &>/dev/null; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt EXTENDED_HISTORY          # timestamp each entry
setopt INC_APPEND_HISTORY        # write as you go, not on exit
setopt SHARE_HISTORY             # live-share between open shells
setopt HIST_IGNORE_DUPS          # drop consecutive duplicates
setopt HIST_IGNORE_ALL_DUPS      # drop older duplicates entirely
setopt HIST_IGNORE_SPACE         # leading space = don't record (for secrets)
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY               # expand !! but let you confirm before running
setopt HIST_SAVE_NO_DUPS

# ── Shell behaviour ───────────────────────────────────────────────────────────
setopt AUTO_CD                   # `atrp` instead of `cd atrp`
setopt AUTO_PUSHD                # every cd pushes onto the dir stack
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt EXTENDED_GLOB             # ^, ~, # in globs
setopt GLOB_DOTS                 # globs match dotfiles
setopt NUMERIC_GLOB_SORT         # file10 sorts after file9
setopt NO_CASE_GLOB
setopt INTERACTIVE_COMMENTS      # allow # comments when typing
setopt LONG_LIST_JOBS
setopt NOTIFY                    # report bg job status immediately
setopt NO_BEEP
setopt NO_FLOW_CONTROL           # frees ctrl-s / ctrl-q
unsetopt CORRECT_ALL             # no aggressive "did you mean" nagging

# ── Completion ────────────────────────────────────────────────────────────────
# brew's completion functions, then a once-a-day-rebuilt compinit cache.
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
fi

autoload -Uz compinit
_zcompdump="$HOME/.zcompdump"
if [[ -n "$_zcompdump"(#qN.mh+24) ]]; then
  compinit -d "$_zcompdump"          # full rebuild if older than 24h
else
  compinit -C -d "$_zcompdump"       # otherwise trust the cache (fast startup)
fi
unset _zcompdump

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose true
zstyle ':completion:*:descriptions' format '%F{blue}── %d ──%f'
zstyle ':completion:*:warnings'     format '%F{red}no matches%f'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true

# ── Key bindings ──────────────────────────────────────────────────────────────
bindkey -e                                    # emacs keys

# Up/Down search history for what you've typed so far — the single biggest
# day-to-day win. Type "uv run" then ↑ to walk only matching commands.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^P'   up-line-or-beginning-search
bindkey '^N'   down-line-or-beginning-search

bindkey '^[[1;5C' forward-word                # ctrl+→
bindkey '^[[1;5D' backward-word               # ctrl+←
bindkey '^[[1;3C' forward-word                # alt+→
bindkey '^[[1;3D' backward-word               # alt+←
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[^?' backward-kill-word
bindkey '^U' backward-kill-line               # ctrl+u kills to start, not whole line

# ctrl+x ctrl+e — open the current command line in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ── Aliases ───────────────────────────────────────────────────────────────────
# Listing (eza) — guarded so a fresh machine without eza keeps a working `ls`.
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first --icons=auto'
  alias l='eza -lbF --git --icons=auto --group-directories-first'
  alias ll='eza -lbGF --git --icons=auto --group-directories-first'
  alias la='eza -labgF --git --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
  alias ltt='eza --tree --level=3 --icons=auto --group-directories-first'
  alias lr='eza -lbF --git --icons=auto --sort=modified --reverse'
fi

# Files.  NOTE: find/grep/less are deliberately NOT aliased to fd/rg/bat —
# the flags aren't compatible and it breaks the moment you type `find -name`.
# Use fd / rg / bat by name. `cat` is safe to alias: bat detects a pipe and
# falls back to plain passthrough.
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
  alias catp='bat --plain --paging=never'
  alias bathelp='bat --plain --language=help'
fi

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# Safety
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -p'

# Git
alias g='git'
alias gs='git status --short --branch'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gca='git commit --amend'
alias gp='git push'
alias gpl='git pull --rebase'
alias gco='git checkout'
alias gb='git branch --sort=-committerdate'
alias gl="git log --graph --abbrev-commit --date=relative --pretty=format:'%C(auto)%h%d %s %C(dim)· %an, %ar'"
alias gll='git log --oneline --graph --all -30'
alias gst='git stash'
alias gstp='git stash pop'

# Project (this repo's stack)
alias py='uv run python'
alias pt='uv run pytest'
alias ptq='uv run pytest -q'

# Misc
alias reload='exec zsh'
alias path='echo $PATH | tr ":" "\n"'
alias ports='lsof -iTCP -sTCP:LISTEN -P -n'
alias zshrc='$EDITOR ~/.zshrc'
alias starshiprc='$EDITOR ~/.config/starship.toml'

# ── Functions ─────────────────────────────────────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }           # make a dir and enter it

extract() {                                     # unpack anything
  [[ -f "$1" ]] || { echo "extract: '$1' is not a file" >&2; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar)            tar xf  "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.gz)             gunzip  "$1" ;;
    *.zip)            unzip   "$1" ;;
    *.7z)             7z x    "$1" ;;
    *) echo "extract: don't know how to unpack '$1'" >&2; return 1 ;;
  esac
}

# ── Tool integrations ─────────────────────────────────────────────────────────
# fzf: ctrl+r fuzzy history, ctrl+t fuzzy file insert, alt+c fuzzy cd
if command -v fzf &>/dev/null; then
  source <(fzf --zsh) 2>/dev/null
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  export FZF_DEFAULT_OPTS="
    --height 45% --layout=reverse --border=rounded --info=inline
    --preview-window=right:55%:wrap
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#a6e3a1,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
    --color=border:#45475a"
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons=always --color=always {}'"
fi

# zoxide: `z atrp` jumps to the dir you visit most matching "atrp"
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# bat theme
export BAT_THEME="Catppuccin Mocha"

# OpenClaw completion (pre-existing)
[[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]] && \
  source "$HOME/.openclaw/completions/openclaw.zsh"

# ── Plugins ───────────────────────────────────────────────────────────────────
# Order matters: autosuggestions before syntax-highlighting, highlighting LAST.
_zsh_plugins="$(brew --prefix 2>/dev/null)/share"

if [[ -f "$_zsh_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$_zsh_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
  bindkey '^[[C' forward-char                 # → accepts one char
  bindkey '^F'   autosuggest-accept           # ctrl+f accepts the whole line
fi

if [[ -f "$_zsh_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$_zsh_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
  typeset -gA ZSH_HIGHLIGHT_STYLES
  ZSH_HIGHLIGHT_STYLES[command]='fg=#a6e3a1'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=#a6e3a1'
  ZSH_HIGHLIGHT_STYLES[function]='fg=#a6e3a1'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=#a6e3a1'
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f38ba8,bold'
  ZSH_HIGHLIGHT_STYLES[path]='fg=#89b4fa,underline'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#f9e2af'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#f9e2af'
  ZSH_HIGHLIGHT_STYLES[comment]='fg=#6c7086'
fi
unset _zsh_plugins

# ── Prompt ────────────────────────────────────────────────────────────────────
command -v starship &>/dev/null && eval "$(starship init zsh)"

# NOTE: starship 1.26 does not implement transient prompts for zsh (fish/nu/
# pwsh only), so there is nothing to enable here. Ghostty's cmd+↑/↓
# jump-to-prompt covers the same "find my last command" need.

# ── Local overrides ───────────────────────────────────────────────────────────
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
