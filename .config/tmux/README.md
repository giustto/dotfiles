# tmux workflow

The prefix is the literal `^` key. Press `^` twice to send a caret to the
active program. Keys shown below are pressed after the prefix unless marked as
global.

| Key | Action |
| --- | --- |
| `c` | New window in the current directory |
| `-` / `|` | Split below / right in the current directory |
| `Ctrl-h/j/k/l` | Move across Neovim windows and tmux panes (global) |
| `h/j/k/l` or arrow keys | Move between panes after pressing the prefix |
| `Alt-H` / `Alt-L` | Previous / next tmux window (global) |
| `H/J/K/L` | Resize the active pane |
| `f` | Pick or create a project session with fzf and zoxide |
| `s` | Browse sessions and windows |
| `[` | Enter vi copy mode; `v` selects and `y` copies |
| `z` | Zoom the active pane |
| `,` | Rename the current window in a centered popup |
| `:` | Enter a tmux command in a centered popup |
| `r` | Reload the configuration |

`clear`, its short alias `c`, and `Ctrl-l` clear both the screen and scrollback.
In a shell pane, `Ctrl-l` moves right when a pane exists there and clears when
already at the right edge. It remains seamless window navigation in Neovim.

The status line follows the macOS light/dark appearance whenever Ghostty
focuses the tmux client.
