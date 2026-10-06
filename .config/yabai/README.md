# yabai + skhd

Requires macOS, `jq`, and yabai **7.1.25 or newer**. SIP stays enabled; no scripting
addition is configured. Windows keep their normal floating layout.

| Shortcut | Action |
| --- | --- |
| Option+J | Previous Space on the focused display |
| Option+K | Next Space on the focused display |
| Option+Ctrl+J | Snap left; repeat to cycle ½ → ⅔ → ⅓ width |
| Option+Ctrl+K | Snap right; repeat to cycle ½ → ⅔ → ⅓ width |
| Option+Ctrl+U | Maximize the focused window within the usable screen area |
| Option+C | Center the focused window, keeping its size |
| Option+M | Move the focused window to the next display and follow it |

Space navigation includes native fullscreen apps and empty desktops, and stops
at either end like Control+Arrow. yabai's current SIP-enabled Space switching
uses high-velocity gestures to skip the transition animation. Verify the visual
result on your macOS version.

Centering uses the display's current usable frame: a visible Dock and menu bar
are excluded; an auto-hidden Dock does not reserve its normal full area. It works
with bottom, left, and right Docks and displays above or left of the main display.
Oversized windows retain their size and align to the usable area's upper/left
edge on the axis where they do not fit.

Left/right snapping fills the usable height and respects the Dock and menu bar.
Pressing the same shortcut again cycles widths; switching sides starts at half.
Moving or resizing the window manually resets the cycle when its frame no longer
matches a snap size. App minimum sizes can prevent an exact third-width fit.
For a ⅔ + ⅓ layout, press Option+Ctrl+J twice on one window, then
Option+Ctrl+K three times on the other. Native fullscreen and non-resizable
windows are skipped.

Maximizing respects the Dock and menu bar and stays on the current Space.
It skips native fullscreen and non-resizable windows; pressing it again keeps
the window maximized.

Moving cycles through macOS display order, wrapping to the first display. With
one monitor it does nothing. Exit native fullscreen before centering or moving
that window. Applications can impose their own window-position constraints.

## Setup

With this repository's `.config` linked to `~/.config`:

```sh
brew install asmvik/formulae/yabai asmvik/formulae/skhd jq
yabai --start-service
skhd --start-service
```

Enable both **yabai** and **skhd** in System Settings → Privacy & Security →
Accessibility. If they are missing from the list, click **+**, press
**Cmd+Shift+G**, and enter the binary path reported by `command -v yabai` or
`command -v skhd`. Then restart both services so they can detect existing windows:

```sh
yabai --restart-service
skhd --restart-service
```

Under Desktop & Dock → Mission Control, keep “Displays have separate Spaces”
enabled. Disable “Automatically rearrange Spaces based on most recent use” if
you want a stable left-to-right order. Secure Keyboard Entry prevents skhd from
receiving shortcuts while active.

## Check the behavior

Space switching needs at least two Spaces on the same monitor. A desktop on
another monitor is not a neighboring Space.

1. Put Chrome in native fullscreen beside a regular desktop. Use Option+J/K in
   both directions; also try an empty desktop and either end of the Space list.
2. Move a normal window off-center and press Option+C. Repeat with Dock auto-hide
   on and off; the window should keep its size.
3. Attach another monitor and press Option+M twice. Focus should follow the
   window to the other monitor and back.
4. Press Option+Ctrl+J four times: left half, left two-thirds, left third,
   left half. Repeat with Option+Ctrl+K on the right side.

Logs: `/tmp/yabai_$USER.err.log` and `/tmp/skhd_$USER.err.log`.
To stop the shortcuts and window manager:

```sh
skhd --stop-service
yabai --stop-service
```

References: [yabai changelog](https://github.com/asmvik/yabai/blob/master/CHANGELOG.md),
[yabai manual](https://github.com/asmvik/yabai/blob/master/doc/yabai.asciidoc),
[skhd setup](https://github.com/asmvik/skhd#install).
