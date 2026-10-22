#!/bin/sh
# Shared by Herdr and tmux. Roots are colon-separated; spaces are supported.

project_paths() {
  {
    printf '%s\n' "$HOME/dotfiles" "${HERDR_ACTIVE_PANE_CWD:-$PWD}"
    printf '%s\n' "${DOTFILES_PROJECT_DIRS:-$HOME/Developer:$HOME/Projects:$HOME/Code:$HOME/src}" |
      tr ':' '\n' | while IFS= read -r root; do
        [ -d "$root" ] || continue
        find "$root" -mindepth 1 -maxdepth 2 -type d \
          \( -name '.*' -o -name node_modules -o -name vendor \) -prune -o -type d -print 2>/dev/null
      done
    if command -v zoxide >/dev/null 2>&1; then zoxide query --list 2>/dev/null; fi
  } | while IFS= read -r project_dir; do
    [ -d "$project_dir" ] && (cd -P -- "$project_dir" && pwd -P)
  done | awk '!seen[$0]++'
}

project_pick() {
  command -v fzf >/dev/null 2>&1 || { printf 'Project picker requires fzf\n' >&2; return 2; }
  choice=$(project_paths | fzf --print-query --expect=ctrl-n \
    --prompt='project  ' --height=100% --layout=reverse --border=rounded --info=inline \
    --header='Enter: open project · Ctrl-N: open a typed directory · Esc: cancel' \
    --preview='ls -la {}' --preview-window='right:50%:wrap:hidden' \
    --bind='ctrl-/:toggle-preview') || return $?
  key=$(printf '%s\n' "$choice" | sed -n '2p')
  if [ "$key" = ctrl-n ]; then
    selected=$(printf '%s\n' "$choice" | sed -n '1p')
  else
    selected=$(printf '%s\n' "$choice" | sed -n '3p')
  fi
  case $selected in \~) selected=$HOME ;; \~/*) selected=$HOME/${selected#\~/} ;; esac
  [ -n "$selected" ] || return 1
  if [ ! -d "$selected" ]; then printf 'Directory does not exist: %s\n' "$selected" >&2; return 2; fi
  (cd -P -- "$selected" && pwd -P)
}

project_name() {
  base=$(basename "$1" | tr '.:' '__' | tr -cd '[:alnum:]_-')
  [ -n "$base" ] || base=project
  # A stable path fingerprint keeps api/ in two different repositories distinct.
  fingerprint=$(printf '%s' "$1" | cksum | awk '{printf "%08x", $1}')
  printf '%s-%s\n' "$base" "$fingerprint"
}
