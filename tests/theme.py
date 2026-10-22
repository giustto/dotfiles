#!/usr/bin/env python3
"""Test palette propagation and validation without touching installed configs."""
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/theme"
SCOPE = {"__file__": str(SCRIPT), "__name__": "theme_generator"}
exec(compile(SCRIPT.read_text(), str(SCRIPT), "exec"), SCOPE)
PALETTES = json.loads((ROOT / ".config/theme/palette.json").read_text())


class ThemeTests(unittest.TestCase):
    def test_prompt_is_grayscale(self):
        script = '''
          setopt extended_glob
          source "$DOTFILES_ROOT/.config/theme/shell.zsh"
          source "$DOTFILES_ROOT/.config/zsh/.p10k.zsh"
          for name in ${(k)parameters}; do
            case $name in POWERLEVEL9K_*FOREGROUND)
              [[ ${(P)name} == (7|8|15) ]] || { print -u2 -- "$name is not neutral"; exit 1; } ;;
            esac
          done
          for value in "${(@v)ZSH_HIGHLIGHT_STYLES}"; do
            [[ $value == fg=(7|8|15)(|,*) ]] || exit 1
          done
          [[ $POWERLEVEL9K_DIR_FOREGROUND == 7 ]] || exit 1
          [[ $POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION == × ]] || exit 1
        '''
        result = subprocess.run(["zsh", "-f", "-c", script], capture_output=True, text=True,
                                env=dict(os.environ, DOTFILES_ROOT=str(ROOT)), timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_neutral_text_and_contrast(self):
        SCOPE["validate"](PALETTES)
        for mode, palette in PALETTES.items():
            colors = SCOPE["ansi"](palette, mode)
            self.assertEqual(len(colors), 16)
            for index in (0, 7, 8, 15):
                self.assertEqual(len(set(SCOPE["rgb"](colors[index]))), 1)
        for role, color in (("fg", PALETTES["dark"]["bg"]), ("bg", PALETTES["dark"]["blue"])):
            invalid = copy.deepcopy(PALETTES)
            invalid["dark"][role] = color
            with self.assertRaises(ValueError):
                SCOPE["validate"](invalid)

    def test_light_neon_is_separate_from_text_ink(self):
        light = PALETTES["light"]
        colors = SCOPE["ansi"](light, "light")
        for index, name in enumerate(SCOPE["ACCENTS"]):
            self.assertEqual(colors[index + 9], light["neon"][name])
            self.assertNotEqual(colors[index + 1], colors[index + 9])
        for color in light["neon"].values():
            a, b = SCOPE["luminance"](color), SCOPE["luminance"](light["fg"])
            self.assertGreaterEqual((max(a, b) + .05) / (min(a, b) + .05), 4.5,
                                    "Dark text must be readable on fluorescent backgrounds")
        invalid = copy.deepcopy(PALETTES)
        invalid["light"]["pink"] = invalid["light"]["bg"]
        with self.assertRaises(ValueError):
            SCOPE["validate"](invalid)

    def test_codex_theme_semantics(self):
        for mode, palette in PALETTES.items():
            theme = plistlib.loads(SCOPE['codex_theme'](palette, mode).encode())
            self.assertEqual(theme['name'], 'Neon ' + mode.title())
            default = theme['settings'][0]['settings']
            self.assertEqual(default['background'], palette['bg'])
            self.assertEqual(default['foreground'], palette['fg'])
            rules = {rule['name']: rule['settings'] for rule in theme['settings'][1:]}
            for name, role in [('Comments', 'muted'), ('Keywords', 'pink'), ('Functions', 'blue'),
                               ('Types', 'cyan'), ('Strings', 'green'), ('Constants', 'yellow')]:
                self.assertEqual(rules[name]['foreground'], palette[role])
            self.assertEqual(rules['Added']['background'], palette['add'])
            self.assertEqual(rules['Deleted']['background'], palette['delete'])
            self.assertEqual(default['selection'], palette.get('neon', {}).get('cyan', palette['selection']))

    def test_codex_install_is_scoped_idempotent_and_preserves_config(self):
        with tempfile.TemporaryDirectory(prefix='codex-theme-') as directory:
            home = Path(directory) / 'custom Codex home'
            home.mkdir()
            config = home / 'config.toml'
            content = '[tui]\ntheme = "ada"\n'
            config.write_text(content)
            with patch.dict(os.environ, CODEX_HOME=str(home)), contextlib.redirect_stdout(io.StringIO()):
                SCOPE['install_codex']()
                SCOPE['install_codex']()
            for mode in ('dark', 'light'):
                link = home / 'themes' / f'neon-{mode}.tmTheme'
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), (ROOT / '.config/theme/codex' / link.name).resolve())
            self.assertEqual(config.read_text(), content)

    def test_codex_install_preflights_conflicts(self):
        with tempfile.TemporaryDirectory(prefix='codex-theme-') as directory:
            home = Path(directory)
            (home / 'themes').mkdir()
            conflict = home / 'themes/neon-light.tmTheme'
            conflict.write_text('A custom theme owned by the user')
            with patch.dict(os.environ, CODEX_HOME=str(home)), self.assertRaises(ValueError):
                SCOPE['install_codex']()
            self.assertEqual(conflict.read_text(), 'A custom theme owned by the user')
            self.assertFalse((home / 'themes/neon-dark.tmTheme').exists())

    def test_regeneration_and_drift(self):
        original_root = SCOPE["ROOT"]
        try:
            with tempfile.TemporaryDirectory(prefix="theme-test-") as directory:
                root = Path(directory)
                SCOPE["ROOT"] = root
                source = root / SCOPE["SOURCE"]
                source.parent.mkdir(parents=True)
                source.write_text(json.dumps(PALETTES))
                herdr = root / ".config/herdr/config.toml"
                herdr.parent.mkdir(parents=True)
                before, after = 'onboarding = false\n\n', '\n\n[keys]\nprefix = "^"\n'
                herdr.write_text(before + SCOPE["BEGIN"] + "\nold\n" + SCOPE["END"] + after)

                def run(*args):
                    with patch.object(sys, "argv", [str(SCRIPT), *args]), \
                            contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                        return SCOPE["main"]()

                self.assertEqual(run("--check"), 1, "Missing exports must be detected")
                self.assertEqual(run(), 0)
                self.assertEqual(run("--check"), 0)
                original = (root / ".config/ghostty/themes/neon-dark").read_text()
                edited = copy.deepcopy(PALETTES)
                edited["dark"]["blue"] = "#00d2ff"
                source.write_text(json.dumps(edited))
                self.assertEqual(run("--check"), 1, "Source edits must make exports stale")
                self.assertEqual((root / ".config/ghostty/themes/neon-dark").read_text(), original,
                                 "Check must never rewrite files")
                self.assertEqual(run(), 0)
                for relative in (".config/ghostty/themes/neon-dark", ".config/nvim/lua/config/palette.lua",
                                 ".config/theme/palette.sh", ".config/herdr/config.toml",
                                 '.config/theme/codex/neon-dark.tmTheme'):
                    self.assertIn("#00d2ff", (root / relative).read_text())
                self.assertTrue(herdr.read_text().startswith(before))
                self.assertTrue(herdr.read_text().endswith(after), "Bindings must survive regeneration")
                self.assertEqual(run("--check"), 0)
        finally:
            SCOPE["ROOT"] = original_root


if __name__ == "__main__":
    unittest.main()
