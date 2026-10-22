# Match Ghostty's system appearance when starting an interactive Codex session.
# Keep personal Codex settings intact; explicit later -c overrides still win.
function codex() {
  local appearance mode=light codex_home=${CODEX_HOME:-$HOME/.codex}
  local -a theme_args=()
  if [[ -t 0 && -t 1 && $OSTYPE == darwin* ]] && (( $+commands[defaults] )); then
    appearance=$(command defaults read -g AppleInterfaceStyle 2>/dev/null) || appearance=''
    [[ ${appearance:l} != dark ]] || mode=dark
    if [[ -r "$codex_home/themes/neon-$mode.tmTheme" ]]; then
      theme_args=(-c "tui.theme=\"neon-$mode\"")
    fi
  fi
  command codex "${theme_args[@]}" "$@"
}
