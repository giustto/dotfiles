# Dotfiles

A macOS development setup with Ghostty, Zsh, Herdr/tmux, Neovim and Lazygit.
Includes persistent agent-review checkpoints, TypeScript/Python language support
and focused test commands. One shared neon palette colors applications; the
shell prompt and path stay grayscale.

## Install

Requires Homebrew and Apple's command-line tools (`xcode-select --install` if missing).
Replace `<repository-url>` with this repository's Git URL:

```sh
git clone <repository-url> "$HOME/dotfiles"
cd "$HOME/dotfiles"
./scripts/setup
./scripts/doctor
```

Setup installs Brewfile dependencies and pinned plugins, generates colors, checks
for configuration conflicts and links files with GNU Stow. Preserve any conflicting
existing configs before retrying; setup stops rather than overwriting them.

Run `exec zsh -l`, restart Neovim and reload Ghostty with `Cmd-Shift-,`.
Start Herdr with `herdr`; if already running, use `herdr server reload-config`.

## Check

```sh
./scripts/check
./scripts/check --productivity # full UI, Git, language-server and test-runner checks
```

For the daily agent workflow: **Space rm** captures a checkpoint, **Space ra**
opens subsequent changes, **Space rv** marks a file reviewed, and **Space pn**
runs the test under your cursor. These are Neovim normal-mode shortcuts.

See **[SETUP.md](SETUP.md)** for the full configuration, shortcuts, Git/AI review
workflow, TypeScript/Python support, focused tests, colors and troubleshooting.
