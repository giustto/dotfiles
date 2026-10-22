# Revisions live in plugins.lock.json; scripts/setup installs them before startup.
typeset -gA NEON_PLUGIN_REVISIONS
if (( $+commands[jq] )); then
  while IFS=$'\t' read -r neon_repo neon_revision; do
    NEON_PLUGIN_REVISIONS[$neon_repo]=$neon_revision
  done < <(jq -r '.plugins[] | [.repo, .commit] | @tsv' "${XDG_CONFIG_HOME:-$HOME/.config}/shell/plugins.lock.json")
fi
function neon_plugin() {
  local repo=$1
  [[ -d "${ZINIT_HOME:h}/plugins/${repo//\//---}/.git" ]] || return 0
  [[ -n "${NEON_PLUGIN_REVISIONS[$repo]}" ]] || return 0
  zinit ice ver="${NEON_PLUGIN_REVISIONS[$repo]}"
  zinit light "$repo"
}
