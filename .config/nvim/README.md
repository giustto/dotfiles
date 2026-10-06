# Neovim for agent-driven development

A small, explicit config for exploring projects and reviewing agent changes.
The neon light/dark palette matches Ghostty and tmux. macOS appearance is checked
on startup and focus. There are no completion plugins, language servers,
formatters, or automatic language downloads. Saving preserves your formatting.

Requires Neovim **0.11.3+**, Git, and ripgrep. Lazygit provides the full Git UI.
Use your existing JetBrainsMono Nerd Font in Ghostty.

```sh
brew install neovim ripgrep lazygit
cd /path/to/project
nvim .
```

This repository's `.config` is already linked to `~/.config` on this machine.
Elsewhere, link `.config/nvim` to `~/.config/nvim`. The first launch installs the
plugins with lazy.nvim; the lockfile pins the tested revisions. `:Lazy` manages
plugins, and `:Lazy restore` returns them to the lockfile versions. Restart Neovim
after changing the config. `:checkhealth snacks` checks search/explorer tools.

## Start with these keys

`Space` is the leader: press it, release it, then press the following letters.
Pause after Space to see the shortcut menu. `Space ?` searches every binding.
Most shortcuts below work in normal mode; press `Esc` to leave insert mode.

| Key | Action |
| --- | --- |
| `Space e` | Toggle the persistent explorer; focus review files inside a diff |
| `Space E` | Reveal the current file in the explorer |
| `Ctrl-p` or `Space Space` | Find project files, including dotfiles |
| `Space /` | Search project text, including dotfiles |
| `Space ,` | Switch open buffers |
| `Space :` | Search commands |
| `Space rr` | Review all uncommitted changes |
| `Space rb` | Pick a base branch and review this branch's committed changes |
| `Space rc` | Search commit messages; Enter opens that commit's diff |
| `Space rh` | History of the current file, including renames |
| `Space rH` | Repository history, with commit messages and changed files |
| `Space gg` | Lazygit: branch switching, log, worktrees, staging, commits, push/pull |
| `Ctrl-h/j/k/l` | Navigate editor windows, then adjacent tmux panes |
| `Space tn` / `Space tc` | New tab / close current tab |
| `Space th` / `Space tl` | Previous / next tab |
| `Space wv` / `Space ws` | Split window beside / below |
| `Space ww` / `Space wc` | Cycle windows / close current window |
| `Space wh/j/k/l` | Move between windows without using Ctrl |
| `Ctrl-s` | Save |

## Review an agent's work

1. Open the project with `nvim .`. Explore directories on the left and keep your
   agent in a neighboring tmux pane.
2. Optionally press `Space rm` **before** starting the agent to record HEAD.
3. Keep Neovim open while the agent edits. An open review checks for external
   changes every three seconds, and the explorer watches the file tree.
   Unmodified buffers reload from disk; locally edited buffers keep Neovim's
   conflict prompt. `Space ru` forces an immediate review refresh.
4. Press `Space rr` for the working tree, `Space ra` for changes since the
   checkpoint, or `Space rb` for committed changes against another branch.
5. In the review panel, move with `j/k` and press Enter or `l` to open a file
   and move into its diff. Press `Ctrl-h` to return to the file list. Use Tab and
   Shift-Tab to advance through files, and `]c` / `[c` for individual changes.
   `Space e` focuses the file panel, `Space rf` hides it, and `q` returns to editing.
6. In the file panel, `s` stages or unstages the selected file. `Space rs` reviews
   exactly what's staged. `Space gg` opens Lazygit to inspect branches or commit
   with a message. These operations run only when you invoke them.

Diffs open in their own tab. The original editing layout stays available. The
review switches between side-by-side and stacked diffs as the terminal changes
size. Below 100 columns, its file list closes to leave room for the diff; press
`Space e` to focus it temporarily. The list returns when the terminal widens.
`Space rl` still cycles layouts manually.
Winbars identify each revision. In the history panel, `L` shows the full commit
message, and `g?` opens the view's help. The top tab bar uses short file names,
`Review` or `History` labels, and `Workspace` for a tab without an open file;
`Space th` and `Space tl` move between tabs.

A tab is a workspace containing one or more windows. Use `Space tn` to create a
tab and `Space tc` to close one. Use `Space wv` for a side-by-side window, `Space ws`
for a window below, and `Space wc` to close one. `:tabedit path/to/file` also
opens a file in a new tab.

**Review scopes matter:**

| Key | Compared content |
| --- | --- |
| `Space rr` | Unstaged and staged sections, plus untracked files |
| `Space rs` | Index against HEAD; your proposed commit |
| `Space rb` | Selected branch's merge base against HEAD; committed changes only |
| `Space rB` | Same comparison with a typed branch, tag, or commit |
| `Space rc` | One commit's patch; choosing it does not check it out |
| `Space rm` / `Space ra` | Remember HEAD / compare that commit to the current working tree |

Branch and commit pickers are for inspection: Enter opens a review. To actually
switch branches, use Lazygit. Remote refs reflect your last fetch; fetch there
before comparing if you need the latest remote state. Run Neovim in an agent's
worktree to inspect that worktree's uncommitted files.

Checkpoints live in memory per repository/worktree and reset when Neovim exits.
They record a **commit**, not a dirty-tree snapshot: pre-existing uncommitted
changes are also included. Save your edits before reviewing disk changes.

## Explore by keyboard

`nvim` with no arguments and `nvim .` open the explorer. Opening a specific file
starts in the editor; press `Space e` when you want the sidebar.

| Explorer key | Action |
| --- | --- |
| `j/k`, `h/l`, Enter | Move, collapse, expand/open |
| `Ctrl-l` / `Ctrl-h` | Move to the editor / return to the explorer |
| `/` | Filter the file tree |
| `P` | Toggle file preview |
| `H` | Toggle hidden files (visible by default) |
| `I` | Toggle Git-ignored files (visible by default) |
| `]g` / `[g` | Next / previous Git-changed entry |
| `a` | Create file; end the name with `/` for a directory |
| `r` | Rename |
| `y` / `p` | Copy path / paste file |
| `Tab`, then `m` or `c` | Select files, navigate, then move or copy |
| `d` | Delete selected files (confirmation) |
| `u` | Refresh tree |
| `Z` | Collapse all directories |
| `Backspace` | Go to parent directory |
| `.` | Make selected directory the explorer root |

The `.git` database is excluded from browsing/search. Dotfiles such as `.github`
and `.env.example`, plus ignored hidden folders, are visible in the explorer.
Press `I` to hide ignored files if a project tree gets too large.
`Space fF` searches ignored files too. File paths and Git status stay visible in
the explorer, and the status line shows the current branch and file path.
On a narrow terminal, the explorer becomes a temporary floating view so the
editor keeps its width. Search pickers use a compact list without a preview
when there is not room for both.

## Editing and investigation

| Key | Action |
| --- | --- |
| `]h` / `[h` | Next / previous changed hunk in a file |
| `Space gp` | Preview current hunk |
| `Space gs` | Stage/unstage hunk; in visual mode, stage selected lines |
| `Space gR` | Discard current hunk after confirmation |
| `Space gb` / `Space gB` | Blame line with full message / blame entire file |
| `Space ub` | Toggle inline blame |
| `Space gd` | Quick changed-file picker with diff previews |
| `Space fy` | Copy `relative/path:line` to clipboard for agent feedback |
| `Space sw` | Search current word or visual selection |
| `Space sr` | Project search/replace using grug-far; preview matches before replacing |
| `Space fr` | Recent files in the current directory |
| `Shift-h` / `Shift-l` | Previous / next buffer |
| `Space bd` | Close buffer while keeping the window layout |
| `Space tt` | Project terminal; double Esc returns to normal mode |
| `Space uz` | Zoom current editor window |
| `Space uw` | Toggle wrapping |
| `Space ut` | Toggle light/dark until the next macOS focus sync |

Vim basics: `i` starts inserting, `Esc` returns to navigation, `u` undoes,
`Ctrl-r` redoes, `v` selects text, `V` selects lines, and `y` copies to the system
clipboard. `%` jumps between brackets. `Ctrl-o` / `Ctrl-i` navigate jump history.
`gcc` comments a line and `gc` comments a selection. `:Tutor` is available through
Neovim's standard runtime if you want an interactive introduction.

No save hooks rewrite files. Syntax highlighting uses Neovim's built-in syntax
and any parsers already available in the runtime. No parsers are installed by
this config. EditorConfig files still control indentation through Neovim.

## Configuration and checks

- `lua/config/keymaps.lua`: everyday shortcuts.
- `lua/config/review.lua`: Git review scopes and agent checkpoints.
- `lua/config/responsive.lua`: terminal size based layouts.
- `lua/config/theme.lua`: neon palette and macOS appearance sync.
- `lua/plugins/navigation.lua`: explorer, search, shortcut menu, status line.
- `lua/plugins/git.lua`: diff layouts and hunk controls.
- `lua/plugins/editing.lua`: text objects and project search/replace.

The integration check creates temporary Git repositories and tests actual
Diffview results, layout changes from wide to narrow terminals, file history,
the explorer, search pickers, and both color palettes:

```sh
nvim --headless '+luafile ~/.config/nvim/tests/review.lua'
```

Plugin references: [Snacks explorer](https://github.com/folke/snacks.nvim/blob/main/docs/explorer.md),
[Diffview](https://github.com/sindrets/diffview.nvim),
[Gitsigns](https://github.com/lewis6991/gitsigns.nvim), and
[Lazygit](https://github.com/jesseduffield/lazygit).
