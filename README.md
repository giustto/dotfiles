# My dotfiles

My terminal and editor setup, managed with GNU Stow. Includes tmux and Herdr
project pickers, Neovim, Ghostty themes, Zsh with Powerlevel10k, and optional
skhd/yabai window shortcuts.

## Layout

```text
~/dotfiles/
├── .config/
│   ├── tmux/       # tmux.conf and tmux-specific scripts
│   ├── herdr/      # config.toml and Herdr-specific scripts
│   ├── nvim/
│   ├── ghostty/    # config and themes
│   ├── zsh/        # .zshrc and .p10k.zsh
│   ├── skhd/       # optional window shortcuts
│   └── yabai/      # optional window management and scripts
├── .zshenv
├── .stow-local-ignore
├── Brewfile
└── README.md
```

The entire `dotfiles` directory is one Stow package, selected as `.`. Its paths mirror your
home directory: `.config/tmux` maps to `~/.config/tmux`, and `.zshenv` maps to
`~/.zshenv`. Scripts with the same name stay inside their application's folder.
`.stow-local-ignore` excludes the root README, Brewfile, Git metadata, and Zsh's
completion cache from linking.

## Setup on another machine

1. Install Git, Zsh, GNU Stow, and the applications you want to use through
   your machine's package manager. If you use Homebrew, the included Brewfile
   installs the command-line dependencies. On macOS, install Apple's command
   line tools with `xcode-select --install` if needed.
2. Clone this repository to `~/dotfiles`, replacing the placeholder URL below
   with this repository's URL. Alternatively, copy the entire folder, including
   hidden files and directories.

   ```sh
   git clone <repository-url> "$HOME/dotfiles"
   cd "$HOME/dotfiles"
   ```

   With Homebrew, install dependencies using `brew bundle --file=Brewfile`.
   The Brewfile installs Stow, Neovim, tmux, Herdr, fzf, zoxide, and jq.
   Install Ghostty and JetBrainsMono Nerd Font separately to use the terminal
   appearance in these configs. The optional skhd/yabai window shortcuts are
   specific to macOS; install those tools separately if you want to use them.
   See their configuration README below.

3. Preview the links before applying them:

   ```sh
   stow --no-folding --simulate --verbose --dir="$HOME/dotfiles" --target="$HOME" .
   ```

   Existing files can cause conflicts. Back up conflicting paths outside
   `~/.config` before retrying, particularly `~/.zshenv`, `~/.zshrc`, and any
   existing application config directories. For example, if these files exist:

   ```sh
   backup="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
   mkdir -p "$backup"
   mv "$HOME/.zshenv" "$backup/"
   mv "$HOME/.zshrc" "$backup/"
   ```

   Move only paths that exist, and back up each conflicting application
   directory similarly. Review any old links pointing into this repository:
   links to the previous top-level config folders need replacing too.

4. Once the preview succeeds, create the links:

   ```sh
   stow --no-folding --verbose --dir="$HOME/dotfiles" --target="$HOME" .
   exec zsh -l
   ```

   `.zshenv` sets `ZDOTDIR` to `~/.config/zsh` (or `$XDG_CONFIG_HOME/zsh` if
   you set that variable). These Stow commands target `~/.config`; if you use
   a custom `XDG_CONFIG_HOME`, arrange the corresponding config links yourself.
   On first shell startup, Zinit downloads its plugins and Powerlevel10k.
   Neovim installs its plugins on first launch, so internet access is needed.
   Restart Ghostty to load its config. Validate Herdr with `herdr config check`.

Use `.` as the package name with `~/dotfiles` as the Stow directory. `stow */` inside
the repository is for a different layout with one package per top-level folder.

## Updating and removing links

After pulling or copying updates, refresh links with:

```sh
stow --no-folding --restow --dir="$HOME/dotfiles" --target="$HOME" .
```

To remove Stow-managed links while keeping the repository files:

```sh
stow --no-folding --delete --dir="$HOME/dotfiles" --target="$HOME" .
```

## Configuration guides

- [tmux keybindings and workflow](.config/tmux/README.md)
- [Herdr keybindings and workflow](.config/herdr/README.md)
- [Neovim setup and shortcuts](.config/nvim/README.md)
- [yabai and skhd window shortcuts](.config/yabai/README.md)

Review the configs before using them: shell aliases, keybindings, project
search directories, fonts, and window shortcuts reflect my preferences.
