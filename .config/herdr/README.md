# Herdr workflow

Herdr mirrors the tmux setup. The prefix is the literal `^` key; press it
twice to send a caret to the active program. Keys below follow the prefix
unless marked global.

| Key | Action |
| --- | --- |
| `c` | New tab in the current directory without a naming prompt |
| `-` / `\|` | Split below / right in the current directory |
| `Ctrl-h/j/k/l` | Navigate Neovim windows and Herdr panes (global) |
| `h/j/k/l` or arrow keys | Focus the adjacent pane |
| `Alt-H` / `Alt-L` | Previous / next tab (global) |
| `p` / `n`, `1`–`9` | Previous / next tab, or jump to a numbered tab |
| `H/J/K/L` | Resize the active pane |
| `R` | Enter resize mode; `h/j/k/l` resize and `Esc` exits |
| `<` / `>` | Swap with the pane above / below |
| `f` | Pick or create a project workspace with fzf and zoxide |
| `s` | Browse sessions, workspaces, tabs, and panes |
| `[` | Enter copy mode; `v` selects and `y` copies |
| `z` | Zoom the active pane |
| `x` | Close the active pane |
| `,` | Rename the current tab in Herdr's naming dialog |
| `:` | Enter a Herdr CLI command in a popup, e.g. `workspace list` |
| `r` | Reload the configuration |
| `d` | Detach, leaving the session running |
| `b` | Toggle the sidebar |
| `S` | Open settings |
| `?` | Show all active shortcuts |

The neon colors match tmux and Ghostty and switch with the host terminal's
light/dark appearance. Tabs sit at the bottom, with the active directory and
clock on the right. The sidebar remains available for Herdr's workspace and
agent controls. Split panes use internal dividers without outer borders,
gaps, or scrollbars. Mouse selections copy automatically.

The project picker uses the same directories and sanitized project names as
tmux's sessionizer. An existing workspace with the selected project name is
focused; otherwise a workspace opens in that directory. It requires `fzf`
and `jq`; `zoxide` is optional. The navigation helper also requires `jq`.

In Neovim, `Ctrl-h/j/k/l` moves between editor windows before crossing into
an adjacent Herdr pane at an edge. In other programs it navigates directly.
At a shell's rightmost edge, `Ctrl-l` reaches the existing shell clear widget.
Restart existing Neovim instances to load the updated navigation mapping.

Some tmux behaviors have different equivalents: tabs replace windows and
workspaces replace project sessions. Pane swaps are directional rather than
tmux's cyclic swaps. Herdr controls resize increments, repeat timing, copy-mode
keys, and clipboard delivery; tmux's three-cell resize step, rectangular-copy
binding, synchronized panes, and `q` pane-number overlay are not reproduced.
Scrollback is limited to 10 MB per pane rather than 100,000 lines. The `:`
popup accepts Herdr CLI commands rather than tmux commands. Renaming uses
Herdr's own dialog. `clear` emits the shell's existing terminal escape sequences;
Herdr manages its own scrollback, so this is not tmux's `clear-history` command.

Validate with `herdr config check`. Apply to a running server with
`herdr server reload-config`; prefix `r` does the same from the UI.

Configuration syntax follows the [Herdr configuration docs](https://herdr.dev/docs/configuration/).
