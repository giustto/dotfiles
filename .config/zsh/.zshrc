# Enable Powerlevel10k instant prompt. Should stay close to the top of the .zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Homebrew
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  :
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Installation is explicit, atomic and pinned: run scripts/setup on a new machine.
if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  source "$ZINIT_HOME/zinit.zsh"
  source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/plugins.zsh"
  neon_plugin romkatv/powerlevel10k
  neon_plugin zsh-users/zsh-completions
fi

# Register completions before compinit, including Herdr's generated completion.
typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$ZSH_CACHE_DIR/completions"
fpath=("$ZSH_CACHE_DIR/completions" $fpath)
if (( $+commands[herdr] )); then
  if [[ ! -s "$ZSH_CACHE_DIR/completions/_herdr" || "$commands[herdr]" -nt "$ZSH_CACHE_DIR/completions/_herdr" ]]; then
    herdr completion zsh > "$ZSH_CACHE_DIR/completions/_herdr"
  fi
fi
autoload -Uz compinit
compinit -d "$ZSH_CACHE_DIR/zcompdump"
if (( $+functions[zinit] )); then
  neon_plugin zsh-users/zsh-autosuggestions
  neon_plugin Aloxaf/fzf-tab
  zinit cdreplay -q
fi

# Keybindings
bindkey -e
KEYTIMEOUT=10
# Let Ctrl-S reach Neovim instead of freezing terminal output.
[[ ! -t 0 ]] || stty -ixon
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History
HISTSIZE=100000
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt extendedhistory
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no

# fzf-tab configuration
zstyle ':fzf-tab:*' fzf-preview-size '50%'
zstyle ':fzf-tab:*' fzf-flags --height=50% --preview-window=right:50%:wrap
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -la -- ${(q)realpath}'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls -la -- ${(q)realpath}'

# Shell integrations
export EDITOR=nvim VISUAL=nvim
export PAGER=less LESS='-FR' BAT_THEME=ansi
export FZF_DEFAULT_OPTS='--layout=reverse --border=rounded --info=inline --height=60%'
# Grayscale shell text; neon picker highlights use the shared ANSI palette.
source "${XDG_CONFIG_HOME:-$HOME/.config}/theme/shell.zsh"
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=$NEON_FZF_COLORS"
export LG_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml"
source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/codex.zsh"
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
if (( $+commands[bat] )); then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
fi
(( ! $+commands[fzf] )) || eval "$(fzf --zsh)"
(( ! $+commands[zoxide] )) || eval "$(zoxide init --cmd cd zsh)"

# Clear both the viewport and terminal scrollback. Inside tmux, also discard
# the pane's saved history so old output cannot be scrolled back into view.
function clear() {
  printf '\033[H\033[2J\033[3J'

  if [[ -n "$TMUX" ]]; then
    tmux clear-history 2>/dev/null || true
  fi
}

function clear-screen-and-scrollback() {
  clear
  zle reset-prompt
}

zle -N clear-screen-and-scrollback
bindkey '^L' clear-screen-and-scrollback

# Aliases
alias c='clear'
alias la='ls -a'
alias ll='ls -l'
alias ..='cd ..'
alias ...='cd ../..'
alias v='nvim'
alias lg='lazygit'
alias h='herdr'

# tmux
alias ta='tmux attach-session'
alias tl='tmux list-sessions'

function t() {
  if [[ -n "$TMUX" ]]; then
    tmux display-popup -E -w '80%' -h '70%' "$HOME/.config/tmux/scripts/sessionizer"
  elif [[ -n "$1" ]]; then
    tmux new-session -A -s "$1"
  else
    tmux new-session -A -s main
  fi
}

# One project picker in the shell, tmux, and Herdr. Ctrl-F changes directory.
function cproj() {
  local selected
  source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/projects.sh"
  selected=$(project_pick) || return 0
  cd -- "$selected"
}
function project-directory-widget() {
  cproj
  zle reset-prompt
}
zle -N project-directory-widget
bindkey '^F' project-directory-widget

# To customize prompt, run `p10k configure` or edit "$ZDOTDIR/.p10k.zsh".
[[ ! -f "$ZDOTDIR/.p10k.zsh" ]] || source "$ZDOTDIR/.p10k.zsh"

# Python
if [[ -d /opt/homebrew/opt/python@3.14/bin ]]; then
  export PATH="/opt/homebrew/opt/python@3.14/bin:$PATH"
fi

# Highlight last so widgets installed above remain compatible.
if (( $+functions[zinit] )); then
  neon_plugin zsh-users/zsh-syntax-highlighting
fi
