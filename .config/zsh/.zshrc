# Enable Powerlevel10k instant prompt. Should stay close to the top of the .zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Keybindings
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History
HISTSIZE=5000
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"
SAVEHIST=$HISTSIZE
HISTDUP=erase
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
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls $realpath'

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

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

# To customize prompt, run `p10k configure` or edit "$ZDOTDIR/.p10k.zsh".
[[ ! -f "$ZDOTDIR/.p10k.zsh" ]] || source "$ZDOTDIR/.p10k.zsh"

# Python
if [[ -d /opt/homebrew/opt/python@3.14/bin ]]; then
  export PATH="/opt/homebrew/opt/python@3.14/bin:$PATH"
fi
