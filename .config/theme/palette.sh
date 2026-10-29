#!/bin/sh
# Generated from .config/theme/palette.json; edit the palette, then run ./scripts/theme.
# Variables are consumed by the script sourcing this file.
# shellcheck disable=SC2034
neon_palette() {
  case ${1:-dark} in
    dark)
      bg='#000000'
      bg_alt='#191919'
      surface='#303030'
      border='#6b6b6b'
      fg='#eeeeee'
      muted='#a3a3a3'
      blue='#00c8ff'
      magenta='#ff27d8'
      ;;
    light)
      bg='#fafafa'
      bg_alt='#efefef'
      surface='#dedede'
      border='#858585'
      fg='#171717'
      muted='#5c5c5c'
      blue='#005cff'
      magenta='#f000b8'
      ;;
    *) return 2 ;;
  esac
}
