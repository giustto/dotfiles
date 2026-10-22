# Setup and workflow guide

This is the detailed reference for the terminal, editor and Git workflow. Use
[README.md](README.md) for the short installation path. The setup targets macOS,
uses GNU Stow to link configuration files, and shares one neon palette across
applications while keeping the shell prompt and path grayscale.

## Contents

- [Components and layout](#components-and-layout)
- [Installation and configuration links](#installation-and-configuration-links)
- [Shell and project discovery](#shell-and-project-discovery)
- [Terminal and shared colors](#terminal-and-shared-colors)
  - [Codex CLI appearance](#codex-cli-colors)
- [Herdr workspaces](#herdr-workspaces)
- [tmux sessions](#tmux-sessions)
- [Neovim](#neovim)
  - [Agent review and progress](#review-an-agents-changes-and-track-progress)
  - [Review scopes](#review-scopes-and-diff-controls)
  - [Reading and scrolling](#reading-and-scrolling)
  - [TypeScript and Python](#refine-typescript-and-python)
  - [Focused tests](#validate-immediately)
  - [Live refresh](#live-refresh-and-external-edits)
- [Maintenance and troubleshooting](#maintenance-and-troubleshooting)

## Components and layout

| Component | Purpose | Configuration |
| --- | --- | --- |
| Ghostty | Terminal, font, ANSI palette and Option-key handling | `.config/ghostty/` |
| Zsh / Powerlevel10k | Prompt, history, completion and shell shortcuts | `.zshenv`, `.config/zsh/` |
| Herdr | Project workspaces, tabs, panes and agent-facing terminal UI | `.config/herdr/` |
| tmux | Alternative session/window/pane workflow | `.config/tmux/` |
| Neovim | Editing, language support, review and test navigation | `.config/nvim/` |
| Lazygit | Branches, commits, worktrees, staging and remote operations | `.config/lazygit/config.yml` |
| Codex CLI (optional) | Shared colors for code blocks and diffs | `.config/theme/codex/` |
| Shared palette | Source colors and generated application exports | `.config/theme/palette.json` |
| Shared shell helpers | Project discovery, picker and pinned plugin settings | `.config/shell/` |
| Maintenance | Installation, bootstrap, palette generation and diagnosis | `scripts/` |
| Validation | Config, UI, Git and test-runner regression checks | `tests/`, `.config/nvim/tests/` |

Use Herdr workspaces for projects, Herdr tabs for separate terminal tasks, and
Neovim tabs for editing/review views. tmux provides a similar independent
workflow; choose the multiplexer you want to use when starting a session.

The main development loop is: pick a project with **Alt-p** in Herdr, save a
checkpoint with **Space rm** in Neovim, run your agent in another pane, review
with **Space ra**, refine using language actions, then run **Space pn** or
**Space pf** to validate. **Space rv** records a reviewed file and advances;
**Space rp** shows what remains. The sections below explain each step.

## Installation and configuration links

### First installation

Install Homebrew and Apple's command-line tools first. If the command-line
tools are missing, run `xcode-select --install` and finish the installer.
Clone this repository, replacing the placeholder with its Git URL:

```sh
git clone <repository-url> "$HOME/dotfiles"
cd "$HOME/dotfiles"
./scripts/setup
./scripts/doctor
```

The setup script performs these steps:

1. Installs dependencies from `Brewfile`, including Stow, Neovim, Herdr, tmux,
   search/navigation tools, TypeScript/Python language servers, validation tools
   and JetBrainsMono Nerd Font. An existing `/Applications/Ghostty.app` is kept.
2. Installs the Zinit manager and shell plugins at the revisions recorded in
   `.config/shell/plugins.lock.json`. New clones are prepared in temporary
   directories and activated after selecting the pinned revision.
3. Installs the editor's separate TypeScript compiler API using the package
   lock in `.config/nvim/tools/`. This does not change project dependencies.
4. Regenerates application colors from the shared palette and links Codex themes
   into `$CODEX_HOME/themes` (defaults to `~/.codex/themes`).
5. Simulates Stow linking, stops on conflicts, then refreshes the actual links.
6. Restores Neovim plugins to `.config/nvim/lazy-lock.json`.

Setup needs internet access and may install Homebrew dependencies before it
reaches the Stow conflict check. Ordinary shell startup uses installed plugins
and does not clone them. Neovim's first-launch bootstrap is also available if
its plugin manager has not yet been installed.

After installation, run `exec zsh -l`, restart existing Neovim instances and
reload Ghostty with `Cmd-Shift-,`. Start Herdr with `herdr` or its alias `h`.
If a Herdr server is already running, use `herdr server reload-config` or its
prefix followed by `r`.

### How Stow maps files

The entire repository is one Stow package named `.`. Paths mirror your home
directory: `.config/nvim/init.lua` links to `~/.config/nvim/init.lua`, and
`.zshenv` links to `~/.zshenv`. `--no-folding` keeps links at file level.
Documentation, scripts, tests, tool manifests and Git metadata are excluded by
`.stow-local-ignore`.
Codex theme exports are linked separately into `$CODEX_HOME/themes` by
`scripts/theme --install-codex`; Stow does not manage that directory.

To inspect links without applying them, after Stow is installed:

```sh
stow --no-folding --simulate --verbose --dir="$HOME/dotfiles" --target="$HOME" .
```

If an existing file conflicts, preserve it outside the managed path before
retrying setup. Inspect old `~/.zshenv`, `~/.zshrc` and application config files
rather than overwriting them blindly. Do not use `stow */`: this repository
is not arranged as separate top-level Stow packages.

After adding or pulling config files, refresh links with:

```sh
stow --no-folding --restow --dir="$HOME/dotfiles" --target="$HOME" .
```

To unlink the configuration while retaining repository files:

```sh
stow --no-folding --delete --dir="$HOME/dotfiles" --target="$HOME" .
```

This removes Stow-managed links. Separately installed Codex theme links and
application state remain in place.

`.zshenv` sets `ZDOTDIR` to `${XDG_CONFIG_HOME:-$HOME/.config}/zsh`.
Setup's Stow target remains `$HOME`, so a custom `XDG_CONFIG_HOME` needs
corresponding config links arranged separately. Application data, state and
caches remain outside this repository.

## Shell and project discovery

The shell uses Powerlevel10k, autosuggestions, syntax highlighting,
case-insensitive completion and fzf-tab. Prompt text, the working directory,
Git summary, suggestions and typed commands use grayscale ANSI roles.

| Key / command | Action |
| --- | --- |
| `v` | Start Neovim |
| `h` | Start or attach Herdr |
| `lg` | Start Lazygit |
| `Ctrl-f` / `cproj` | Pick a project and change directory |
| `Ctrl-p` / `Ctrl-n` | Search backward / forward through matching history |
| `Ctrl-l`, `clear`, `c` | Clear the screen and scrollback; pane navigation can intercept `Ctrl-l` |
| `la` / `ll` | List hidden files / detailed listing |
| `..` / `...` | Move up one / two directories |
| `t`, `ta`, `tl` | Start/attach tmux, attach a tmux session, list sessions |

Zoxide supplies frequently visited directories and replaces `cd` when installed.
History is shared across shells and saved under the XDG state directory. Duplicate
commands are reduced; a leading space excludes a command from history. Ctrl-S
terminal flow control is disabled so the key can reach Neovim's save binding.

The shell, Herdr and tmux share project discovery. The picker includes the current
directory, `~/dotfiles`, projects below `~/Developer`, `~/Projects`, `~/Code` and
`~/src`, plus valid zoxide entries. Directory discovery is two levels deep and
skips hidden/dependency directories. Customize roots in `.config/zsh/.zshrc`:

```sh
export DOTFILES_PROJECT_DIRS="$HOME/work:$HOME/personal projects"
```

Inside a project picker, Enter opens the selection. Type an existing directory
and press Ctrl-N to open a path outside the discovered list; `~/...` is accepted.
Ctrl-/ toggles the preview, and Esc cancels. The picker does not create directories.

## Terminal and shared colors

Ghostty uses JetBrainsMono Nerd Font at size 14, an initial 115-by-35 window,
small balanced padding and automatic dark/light themes. Left Option acts as Alt
for navigation shortcuts; right Option remains available for special characters.
Its `minimum-contrast = 3` setting can adjust low-contrast rendered foregrounds.

Edit **`.config/theme/palette.json`** to change colors. It contains the dark and
light palettes; other color files are generated or refer to semantic roles.

```sh
./scripts/theme          # validate and regenerate native app configs
./scripts/theme --check  # detect stale exports without writing anything
```

The generator uses Python's standard library. Generated files live alongside the
configs so shells and apps start without running Python or regenerating themes.
`./scripts/setup` regenerates before linking, and `./scripts/check` detects drift.

### Visual rules

- Terminal background, ordinary text, prompt, current directory, Git summary,
  timing, suggestions, and typed commands use neutral grayscale colors.
- Applications use neon accents: cyan/blue for navigation, pink for emphasis,
  green for additions, red for errors/deletions, and yellow for warnings/constants.
- Dark mode uses fluorescent colors. Light mode has two layers: vivid text inks,
  plus a `neon` table for fluorescent ANSI bright colors and highlight backgrounds.
  Search, selected tabs, completion selection, and mode labels
  use fluorescent fills with dark foreground text.
- Herdr's light-mode workspace and agent rows use the palette's soft gray surface
  and selection colors for quieter sidebar highlights.
- Primary text and comments retain a 4.5:1 contrast target in both modes. Dark
  accents retain 4.5:1; light text accents use a 3:1 target for a brighter look.
  That lower target is a deliberate visual tradeoff for small colored text.
  Dark text on the fluorescent backgrounds is separately checked at 4.5:1.
  Borders and diff backgrounds have separate roles.
- Prompt errors use a `×` symbol rather than a red prompt.

The shell refers to ANSI 7 (foreground), 8 (muted gray), and 15 (emphasis), so
changing the terminal's appearance also changes the shell colors without a
per-prompt process or an extra appearance-detection hook.

### Generated outputs

| Consumer | Output |
| --- | --- |
| Ghostty / ANSI terminal applications | `ghostty/themes/neon-dark`, `neon-light` |
| Neovim / embedded terminal / Snacks Git UI | `nvim/lua/config/palette.lua` |
| tmux | `theme/palette.sh` |
| Zsh / fzf | `theme/shell.zsh` |
| Lazygit | `lazygit/config.yml` (ANSI roles, selected through `LG_CONFIG_FILE`) |
| Codex CLI syntax highlighting | `theme/codex/neon-dark.tmTheme`, `theme/codex/neon-light.tmTheme` |
| Herdr | Marked theme block inside `herdr/config.toml` |

Paths are relative to `.config/`. Herdr shortcuts and settings outside the marked
theme block remain editable and are preserved by regeneration.
Applications with their own hardcoded RGB themes need their own palette adapter;
the terminal palette controls applications that use ANSI colors.

After generating, reload Ghostty with **Cmd-Shift-,**, reload Herdr/tmux with
**`^ r`**, and use **Space ur** / `:ThemeReload` in Neovim. After changing the shell configuration itself, run
`exec zsh -l` once. Normal palette edits need no shell restart after Ghostty reloads.

Format references: [Ghostty themes](https://ghostty.org/docs/features/theme),
[Herdr configuration](https://herdr.dev/docs/configuration/), and
[Lazygit configuration](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md).

Neovim follows macOS appearance on startup and focus. **Space ut** selects a
manual light/dark theme that survives focus changes for the current instance;
**Space ua** resumes system appearance. Active editor split borders use an
accent, while inactive borders use the neutral palette. The statusline shows
review progress, diagnostics, test state and external-edit conflicts.

### Codex CLI colors

The generated `neon-dark` and `neon-light` themes use the same palette as the
editor and terminal. Setup installs them automatically; to install only these
themes, run:

```sh
./scripts/theme --install-codex
```

The Zsh `codex` function in `.config/shell/codex.zsh` reads macOS appearance on
each interactive terminal launch and supplies `neon-dark` or `neon-light` as a
session override. This includes `codex resume` and `codex fork`. It uses the same
system setting as the rest of this setup and requires the matching theme to be
installed. It does not rewrite your personal Codex configuration. Piped/scripted
invocations pass through unchanged, as do launches on other operating systems.

After installing or updating the shell integration, run `exec zsh -l` once.
Then launch Codex normally. To override the automatic choice for one session,
use `codex -c 'tui.theme="neon-light"'`; explicit command-line overrides take
precedence. `command codex` bypasses the function and uses your saved settings.

Appearance is selected at launch. The installed Codex version does not expose a
supported way to live-switch custom themes when macOS appearance changes during
an open session. Run `/theme` to preview and choose the matching theme in that
session, or exit and use `codex resume --last` to pick up the current appearance.
Selections through `/theme` are saved by Codex; the shell's automatic choice
applies again on the next normal interactive launch.

The installer honors `CODEX_HOME`, preserves existing personal settings and
refuses to replace conflicting theme files. It links only the two generated
themes; credentials and personal Codex configuration stay outside this repo.
Later palette edits need only `./scripts/theme` because the installed themes
link directly to these exports. Restart Codex to load regenerated colors.

These themes control syntax highlighting in code blocks and diffs. Terminal
defaults still come from Ghostty; other Codex UI colors can be controlled by
Codex itself. See [Codex themes](https://learn.chatgpt.com/docs/cli-customization#syntax-highlighting-and-themes).

## Herdr workspaces

Herdr uses tabs within project workspaces and shares the tmux navigation style.
The prefix is the literal `^` key; press it twice to send a caret to the active
program. Keys below follow the prefix unless marked global.

| Key | Action |
| --- | --- |
| `Alt-n` or `N` | Create a fresh workspace with an automatic name (Alt binding is global) |
| `Alt-w` or `w` | Workspace picker (Alt binding is global) |
| `Alt-p` | Pick/create/reuse a project workspace (global) |
| `Alt-1`–`Alt-9` | Jump to a workspace after the prefix |
| `(` / `)` | Previous / next workspace using the prefix |
| `W` | Rename workspace |
| `G` / `o` | Create / open a Git worktree |
| Backtick | Return to the last pane, across tabs/workspaces |
| `Ctrl-l` | Clear pane screen and scrollback |
| `g` | Lazygit in a popup in the active directory |
| `c` | New tab in the current directory without a naming prompt |
| `-` / `\|` | Split below / right in the current directory |
| `Alt-7` | Split below (global; horizontal divider) |
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
| `D` | Close the workspace |
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
gaps, or scrollbars. Mouse selections copy automatically. The terminal title
shows workspace and tab, and agent states use distinct symbols. Background
agent notifications appear inside Herdr after two seconds, with sounds disabled.
Ghostty forwards left Option as Alt; right Option keeps special-character input.

Left Option-j/k are left to macOS Spaces. Numbered workspace jumps require the
prefix so that direct left Option-7 can split below. The original prefix `|`
still splits right; use right Option to type symbols on layouts that need it.

New workspaces open immediately with automatic names and a fresh shell. Rename
one later with prefix `W`. The project picker instead selects a directory and
creates or reuses its project workspace; it uses the shared discovery and
controls described above.

Workspace identity is recorded by canonical project path in the XDG state
directory, scoped to the server socket/session. Creation requests are serialized,
so repeated shortcut presses reuse one workspace. A secondary pane in another
project does not change the workspace identity. Labels and symlink aliases are
supported. Same-named folders remain distinct; a path fingerprint disambiguates labels when needed.
This survives server restarts and handles long paths. Discovery is two levels
deep and skips hidden/dependency directories. It requires `fzf` and `jq`;
`zoxide` is optional. The navigation helper requires `jq`; project identity tracking uses Python 3.

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

## tmux sessions

The prefix is the literal `^` key. Press `^` twice to send a caret to the
active program. Keys shown below are pressed after the prefix unless marked as
global.

| Key | Action |
| --- | --- |
| `c` | New window in the current directory |
| `-` / `\|` | Split below / right in the current directory |
| `Ctrl-h/j/k/l` | Move across Neovim windows and tmux panes (global) |
| `h/j/k/l` or arrow keys | Move between panes after pressing the prefix |
| `Alt-H` / `Alt-L` | Previous / next tmux window (global) |
| `H/J/K/L` | Resize the active pane |
| `f` | Pick or create a project session with fzf and zoxide |
| `g` | Lazygit in a popup at the current directory |
| `Alt-k` / `Alt-j` | Previous / next session (global) |
| `(` / `)` | Previous / next session |
| Backtick | Return to the last session |
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

The project picker uses the shared discovery and controls described above.
Session names include a stable path fingerprint so same-named folders stay
separate. The sessionizer also works outside tmux and attaches to the selected
project session. Unlike Herdr's tabs/workspaces, tmux uses windows/sessions.

## Neovim

Use the Neovim version installed by the Brewfile; the workflows were tested with
0.12.6. Open a project with `nvim .`, or a specific file with `nvim path/to/file`.
With no file arguments, a visible editor opens the explorer.

`Space` is the leader: press it, release it, then press the following letters.
Most bindings below use normal mode. Press Esc to leave insert mode, pause after
Space for the shortcut menu, or use **Space ?** to search every binding. These
Neovim keys are separate from the multiplexer prefix, which is a literal `^`.

### Everyday navigation

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
| `Ctrl-h/j/k/l` | Navigate editor windows, then adjacent Herdr/tmux panes |
| `Space tn` / `Space tc` | New tab / close current tab |
| `Space th` / `Space tl` | Previous / next tab |
| `Space wv` / `Space ws` | Split window beside / below |
| `Space ww` / `Space wc` | Cycle windows / close current window |
| `Space wh/j/k/l` | Move between windows without using Ctrl |
| `Ctrl-s` | Save |

### Explore by keyboard

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

### Reading and scrolling

Long lines wrap at word boundaries with indented continuation rows marked `↳`.
This changes the display, not the file. `j/k` move by visible rows; a count such
as `5j` still moves by file lines. Ctrl-D/U center the cursor after paging;
`n/N` reveal and center search matches.

Diff panes synchronize scrolling and cursor position automatically, and their
wrap setting survives file changes and layout changes. `Space uw` toggles wrapping
for every pane in the current diff. In ordinary editing splits, `Space us` binds
scrolling while leaving the cursor independent; toggle it again to restore the
previous bindings. The status line shows `⇅ SYNC` while scrolling is bound.
Subtle indentation guides help track scope.

### Review an agent's changes and track progress

1. Save your buffers and press **Space rm** before the agent starts. Name the
   task. This captures the current disk contents, including staged, unstaged and
   non-ignored untracked files. Existing unrelated edits become the baseline.
2. Press **Space ra** to compare the current working tree against that baseline.
   New, modified, renamed and deleted paths appear here. Unchanged files from
   the baseline stay out of the review, including files still untracked by Git.
   The baseline survives editor restarts and is separate for each worktree.
3. Use **Space rv** to mark a file reviewed and advance to an unreviewed file.
   Save any refinements before marking. **Space rj** advances without marking;
   **Space rU** marks the current file as needing review again.
4. **Space rp** shows the file queue with reviewed/unreviewed indicators. The
   statusline displays `Review completed/total`. Review marks survive editor
   restarts and are separate for each review scope: a checkpoint review and a
   staged review have their own progress.
5. Use **Space pn** for the test under your cursor or **Space pf** for the file.
   **Space pr** reruns recorded failures after a fix. Staging and committing
   remain separate actions through the hunk controls or Lazygit.

A mark records the file state you inspected. Later changes to its content,
executable permissions, symlink target, compared revision or relevant index
entry invalidate that mark. Other unchanged files keep their progress.
Progress is tracked per file, rather than per hunk. Unsaved edits block marking
that file until you save it.

Baseline capture uses a temporary Git index and a snapshot commit held by a
local `refs/neon/reviews/<worktree-key>/baseline` ref. It does not commit on your
branch, stage your real index or stash your files. Checkpoint comparisons also
use a private query index, so files created after capture appear correctly
without staging them. Ignore rules are respected; tracked files remain included
even if later ignored. Capture is a disk baseline,
so it refuses to proceed with unsaved buffers in the project. The newest capture
replaces the current baseline and clears review marks for that worktree. There
is one active checkpoint per worktree; the name labels that checkpoint rather
than creating a selectable history of tasks. Standard pushes do not push these
refs; an explicit mirror/all-refs operation can include them.

This captures what changed **after the baseline**, whoever made the edits. Git
cannot attribute simultaneous manual and agent edits to separate authors in a
shared working tree. Use an isolated worktree when that distinction matters.

### Review scopes and diff controls

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

Review scopes:

| Key | Compared content |
| --- | --- |
| `Space rr` | Unstaged and staged sections, plus untracked files |
| `Space rs` | Index against HEAD; your proposed commit |
| `Space rb` | Selected branch's merge base against HEAD; committed changes only |
| `Space rB` | Same comparison with a typed branch, tag, or commit |
| `Space rc` | One commit's patch; choosing it does not check it out |
| `Space rm` / `Space ra` | Capture saved working tree / compare subsequent changes |

Branch and commit pickers are for inspection: Enter opens a review. To actually
switch branches, use Lazygit. Remote refs reflect your last fetch; fetch there
before comparing if you need the latest remote state. Run Neovim in an agent's
worktree to inspect that worktree's uncommitted files.

In a review file panel, use `j/k` and Enter or `l` to open a file. Tab/Shift-Tab
advance between files; `]c` / `[c` move between changes. **Space e** focuses the
file panel, **Space rf** toggles it, and **Space rl** cycles layouts. `s` stages
or unstages a file in an ordinary working-tree review; **Space rs** inspects the
index. `q` or **Space rq** closes the review. In history, `L` shows the full commit
message and `g?` opens the view's help.

### Refine TypeScript and Python

| Key | Action |
| --- | --- |
| `gd` / `gr` / `gi` / `gy` | Definition / references / implementation / type definition |
| `K` | Hover documentation |
| `Space cn` | Rename symbol across files |
| `Space ca` | Supported code actions and quick fixes |
| `Space cs` / `Space cS` | File / project symbols |
| `Space cd` | Explain the diagnostic at the cursor |
| `Space sd` | Project diagnostic picker |
| `Ctrl-Space` in insert mode | Request completion |
| `Ctrl-n/p`, then `Ctrl-y` | Select / accept a completion |
| `Ctrl-k` in insert mode | Signature help |

Language servers are installed through the Brewfile and start only for matching
filetypes. Python prefers `<project>/.venv/bin/python`; project Pyright settings
remain available. TypeScript prefers a project's classic `tsserver.js` when
present; otherwise it uses the pinned editor compiler API installed by setup.
Homebrew's native TypeScript 7 package lacks that classic API, so the fallback is
installed separately and does not replace your project compiler. Projects using
TypeScript 7-only syntax may need its native language server instead. The
[TypeScript server documentation](https://github.com/microsoft/TypeScript/wiki/Standalone-Server-%28tsserver%29)
describes the classic server, and [Neovim documents native LSP](https://neovim.io/doc/user/lsp/).

No save hook reformats code. `Space cf` requests formatting only if an attached
server supports it; Pyright itself does not provide a Python formatter.

### Validate immediately

| Key | Action |
| --- | --- |
| `Space pn` | Run the test containing the cursor |
| `Space pf` / `Space pa` | Run current file / whole detected test project |
| `Space pl` | Repeat last test command in this project |
| `Space pr` | Rerun failed tests from that run |
| `Space po` / `Space pq` | Show streamed output / open quickfix failures |
| `]q` / `[q` | Jump to next / previous failure |
| `Space px` | Cancel the running test process |

Python uses pytest from the project `.venv`, `uv run --no-sync` when a lockfile
and uv are available, or the current Python 3 interpreter. JavaScript/TypeScript
uses local Vitest or Jest, including an ancestor workspace's installed binary.
No framework is downloaded when invoking a test. Install the project's existing
dependencies first. Commands run as argument arrays, so paths and test names
containing spaces or shell characters are not evaluated by a shell.

Nearest-test discovery uses Python's AST or the installed TypeScript compiler
API, rather than depending on syntax parser downloads. Static nested test/suite
names are supported. Dynamic and parameterized JS names fall back to the file
with an explanation. Parameterized pytest failures retain their collected node
selectors. Vitest 5's changed name separator is handled separately from earlier
Vitest/Jest versions. Results use pytest JUnit XML and Vitest/Jest JSON for
failure navigation. Collection failures remain visible in output/quickfix;
individual failed-test reruns require a recorded test selector.

Tests use saved disk content. Save your refinements before running or repeating
tests. New Python bytecode cache writes are disabled for editor test runs to
avoid stale same-second test imports; existing project caches remain owned by
the project. Test output does not take focus automatically. `Space po` opens it
when needed. Other task/build processes are never rerun by file watchers.

### Live refresh and external edits

File buffers, Diffview file lists/content, history, explorer Git status and open
file/grep/Git pickers refresh from filesystem events with a 140 ms debounce.
Events are coalesced; inactive review tabs catch up on activation. History and
commit pickers retain selected commit identity. Explicit commit patches and
baseline hashes remain pinned; symbolic `...HEAD` comparisons follow commits.
Git metadata paths are resolved for linked worktrees. Index-buffer hashes are
checked to avoid Diffview's whole-second index timestamp cache missing rapid
staging operations.

Unmodified buffers reload. A modified buffer keeps its text and shows
**EXTERNAL CHANGE** if the disk changes. A deleted file's buffer text is retained.
Buffer/review changes are deferred during insert/replace/command-line input and
resume when you leave that mode. Open pickers still refresh while you type a query.
Parent-directory watches survive atomic save-by-rename.
Focus checks and **Space ru** / `:ProjectRefresh` provide recovery; a five-second
fallback is used when filesystem watches fail. Recursive project watching is
optimized for macOS; generated trees are filtered. Command output and quickfix
results remain associated with their original run.

### Editing and investigation

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
| `Space uw` | Toggle wrapping; changes all diff panes together |
| `Space us` | Synchronize scrolling in ordinary file splits; toggle again to restore |
| `Space wd` | Duplicate the current file in a split |
| `Space ss` | Search lines in the current buffer |
| `Space sp` | Resume the last picker |
| `Space sj` | Jump history picker |
| `Space bo` | Close other buffers |
| `saiw)` | Surround the current word with parentheses |
| `sd)` / `sr)"` | Delete parentheses / replace them with quotes |
| `Space ut` / `Space ua` | Select a manual light/dark appearance / resume system appearance |
| `Space ur` | Reload generated palette after running `scripts/theme` |

Vim basics: `i` starts inserting, `Esc` returns to navigation, `u` undoes,
`Ctrl-r` redoes, `v` selects text, `V` selects lines, and `y` copies to the system
clipboard. `%` jumps between brackets. `Ctrl-o` / `Ctrl-i` navigate jump history.
`gcc` comments a line and `gc` comments a selection. `:Tutor` is available through
Neovim's standard runtime if you want an interactive introduction.

No save hooks rewrite files. Syntax highlighting uses Neovim's built-in syntax
and available runtime parsers; this config does not install parsers. EditorConfig
files control indentation when present. Persistent undo is enabled.

### Where to change editor behavior

Paths below are inside `.config/nvim/`:

| File | Responsibility |
| --- | --- |
| `init.lua` | Startup order and module setup |
| `lua/config/options.lua` | Editing, display and diagnostic defaults |
| `lua/config/keymaps.lua` | Everyday shortcuts |
| `lua/config/review.lua` | Git review scopes and pickers |
| `lua/config/task_review.lua` | Persistent baselines and review marks |
| `lua/config/checkpoint.lua` | Accurate live checkpoint comparisons using a private index |
| `lua/config/refresh.lua` | Watchers, refresh coordination and cleanup |
| `lua/config/reading.lua` | Wrapping and synchronized split scrolling |
| `lua/config/languages.lua` | TypeScript/Python servers and semantic actions |
| `lua/config/testing.lua` | Test selection, execution and report parsing |
| `lua/config/project.lua` | Project context and state-file helpers |
| `lua/config/responsive.lua` | Terminal-size-dependent layouts |
| `lua/config/theme.lua` | Semantic highlights and system appearance |
| `lua/plugins/navigation.lua` | Explorer, pickers, shortcut menu and statusline |
| `lua/plugins/git.lua` | Diffview layouts and Git hunk controls |
| `lua/plugins/editing.lua` | Text objects, surround editing and search/replace |
| `scripts/test-context.py`, `scripts/test-context.cjs` | Static nearest-test discovery |

The generated `lua/config/palette.lua` is exported from the shared palette;
edit `.config/theme/palette.json` instead.

## Maintenance and troubleshooting

### Diagnosis and validation

Run commands from the repository root:

```sh
./scripts/doctor               # read-only installation and prerequisite report
./scripts/check                # palette, shell, Brewfile, Herdr/Ghostty config
./scripts/check --integration  # isolated Herdr, editor, live UI, Git and LSP checks
./scripts/check --productivity # also verify real focused-test runs and reruns
```

The doctor checks executable availability, configuration links, pinned plugin
revisions, the editor TypeScript API, optional Codex theme links, font installation
and clipboard tools. Critical checkpoint/review/refresh module links are checked
individually. It prints fix commands and does not install tools, relink files or
start apps.

Integration checks use temporary Git repositories and an isolated Herdr server.
They exercise actual keyboard shortcuts, workspace reuse/concurrency, wide/narrow
editor layouts, review baselines, external edits, worktree index handling and
language-server definitions, diagnostics, references and rename. A real terminal
UI check verifies that live picker updates preserve insert mode, query and the
selected commit. A separate checkpoint regression test starts independent Neovim
processes to verify that snapshots and review marks survive a real restart.
It also checks unsaved-buffer guards, mark/unmark/next and queue behavior,
review-scope and linked-worktree isolation, new/deleted untracked paths, and
invalidation after content, executable-mode or symlink-target changes. Capture
and review are checked against the original branch HEAD and real index.

The productivity suite installs/reuses pytest, Vitest and Jest **only in the
isolated `/tmp/dotfiles-productivity-fixture` directory**. These validate adapters;
they are not installed globally or added to your projects. Test execution in
Neovim uses the framework already installed by each project. Validation does not
stage or commit this dotfiles repository.

### Reload the right component

| Changed configuration | Apply it |
| --- | --- |
| Shell or pinned shell plugin settings | `exec zsh -l` |
| Neovim Lua modules or plugin specifications | Restart Neovim |
| Generated Neovim palette | `Space ur` / `:ThemeReload` |
| Generated Codex theme | Restart Codex; `/theme` selects dark or light |
| Ghostty configuration or generated theme | `Cmd-Shift-,` |
| Herdr configuration | `herdr server reload-config` or `^ r`; start Herdr if no server exists |
| tmux configuration | `^ r` |
| Added/removed Stow-managed files | Rerun `./scripts/setup` or the Stow restow command |

### Common problems

| Symptom | Check or fix |
| --- | --- |
| Stow reports conflicts | Preserve conflicting files outside managed paths, then rerun setup |
| Prompt/plugins missing | Run `./scripts/doctor`, then `./scripts/setup`; check `ZDOTDIR` and links |
| Partial shell-plugin installation | Bootstrap reports the path; preserve/move that directory aside and rerun setup |
| Neovim plugin missing or at a different revision | Use `:Lazy restore`; inspect `:Lazy` and `:messages` |
| No TypeScript/Python navigation | Check server executables with the doctor and attached clients with `:checkhealth vim.lsp` |
| Python cannot resolve project dependencies | Check the project `.venv` and Pyright configuration |
| Test runner missing | Install that project's dependencies; inspect `Space po` for command output |
| Nearest JS test falls back to its file | Static names are required; dynamic/parameterized cases need runtime collection |
| External edits conflict with local edits | Keep or reconcile the unsaved buffer deliberately; do not force a reload before reviewing it |
| Review/picker appears stale | Leave file insert/command mode and use `Space ru`; inspect `:messages` |
| Checkpoint capture or marking refuses to proceed | Save the project's modified buffers before capture, or the current file before marking |
| A reviewed file becomes pending again | Its content, mode, link target, compared revision or relevant index entry changed; review the new state |
| Review progress differs between tabs | Checkpoint, staged and other comparison scopes keep separate marks; a new checkpoint clears that worktree's marks |
| Codex starts with the wrong appearance | Run `exec zsh -l`, check `whence -w codex`, and run `./scripts/doctor`; automatic selection applies at launch |
| Palette changes do not appear | Run `./scripts/theme --check`, regenerate, then reload the relevant apps |
| Option shortcuts type symbols | Confirm Ghostty's `macos-option-as-alt = left`; use left Option |

`:checkhealth snacks`, `:checkhealth vim.lsp`, `:messages`, **Space sn** and
**Space ?** help inspect editor capabilities, notifications and active shortcuts.

### Dependencies and version updates

`Brewfile` is the list of application/tool dependencies. Shell revisions live in
`.config/shell/plugins.lock.json`; Neovim revisions live in
`.config/nvim/lazy-lock.json`. The TypeScript fallback uses the npm package lock
under `.config/nvim/tools/`. Homebrew application versions themselves are not
pinned by this repository.

For configuration updates, pull the changes, run `./scripts/setup`, inspect
`./scripts/doctor`, then reload affected applications. To change dependency pins,
update them deliberately and run the relevant checks. `:Lazy restore` returns
editor plugins to the repository's lockfile; updating a plugin can require
reviewing its integration APIs before changing that lockfile.

Application state is kept outside Git. Shell history lives under
`${XDG_STATE_HOME:-$HOME/.local/state}/zsh/`; Herdr project identity records are
under its `neon/herdr/` directory. Neovim review metadata lives under
`stdpath('state')/neon/reviews/`, while baseline contents are retained by the
local Git refs described above. Editor/plugin data lives under the XDG data
directory, and transient caches live under the XDG cache directory.

These configurations target local macOS workflows. Refresh timing depends on
repository size and filesystem behavior; local fixture timings do not guarantee
zero-latency updates for every plugin or filesystem.
