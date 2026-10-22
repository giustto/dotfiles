#!/usr/bin/env python3
"""Exercise the Codex shell entry point with isolated homes and real PTYs."""
import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CodexLaunchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='codex-launch-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.codex_home = self.root / 'custom Codex home'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.home.mkdir()
        (self.codex_home / 'themes').mkdir(parents=True)
        for mode in ('dark', 'light'):
            (self.codex_home / f'themes/neon-{mode}.tmTheme').write_text('installed fixture')
        self.config = self.codex_home / 'config.toml'
        self.config.write_text('[tui]\ntheme = "ada"\n')
        self.record = self.root / 'argv.json'
        self.probes = self.root / 'appearance-probes'
        defaults = self.bin / 'defaults'
        defaults.write_text('#!/bin/sh\nprintf called >> "$TEST_PROBES"\n'
                            'printf "%s" "$TEST_APPEARANCE"\nexit "$TEST_DEFAULTS_STATUS"\n')
        defaults.chmod(0o755)
        codex = self.bin / 'codex'
        codex.write_text(f'#!{sys.executable}\nimport json, os, pathlib, sys\n'
                         'pathlib.Path(os.environ["TEST_RECORD"]).write_text(json.dumps(sys.argv[1:]))\n'
                         'sys.exit(int(os.environ.get("TEST_EXIT", "0")))\n')
        codex.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), CODEX_HOME=str(self.codex_home),
                        PATH=str(self.bin) + ':' + os.environ['PATH'], TEST_RECORD=str(self.record),
                        TEST_PROBES=str(self.probes), TEST_APPEARANCE='Dark', TEST_DEFAULTS_STATUS='0')

    def launch(self, *args, terminal=True, platform='darwin', **env):
        environment = dict(self.env, **env)
        # OSTYPE is local to this test shell; no real appearance preferences change.
        code = 'OSTYPE=$1; source "$2"; shift 2; codex "$@"'
        command = [shutil.which('zsh'), '-f', '-c', code, 'zsh', platform,
                   str(ROOT / '.config/shell/codex.zsh'), *args]
        if terminal:
            master, slave = pty.openpty()
            try:
                result = subprocess.run(command, env=environment, stdin=slave, stdout=slave,
                                        stderr=subprocess.PIPE, timeout=5)
            finally:
                os.close(master)
                os.close(slave)
        else:
            result = subprocess.run(command, env=environment, input=b'', capture_output=True, timeout=5)
        self.assertEqual(self.config.read_text(), '[tui]\ntheme = "ada"\n')
        self.assertEqual(result.stderr, b'')
        return result.returncode, json.loads(self.record.read_text())

    def test_dark_and_light_appearance(self):
        for appearance, status, expected in [('Dark', '0', 'dark'), ('', '1', 'light')]:
            with self.subTest(mode=expected):
                result, args = self.launch('resume', '--last', TEST_APPEARANCE=appearance,
                                           TEST_DEFAULTS_STATUS=status)
                self.assertEqual(result, 0)
                self.assertEqual(args, ['-c', f'tui.theme="neon-{expected}"', 'resume', '--last'])

    def test_arguments_status_and_explicit_override_survive(self):
        original = ['-c', 'tui.theme="ada"', '--cd', '/tmp/project with spaces',
                    '--', 'Refine this code\nKeep $variables and `literals` intact']
        result, args = self.launch(*original, TEST_EXIT='37')
        self.assertEqual(result, 37)
        self.assertEqual(args, ['-c', 'tui.theme="neon-dark"', *original])

    def test_missing_theme_preserves_native_settings(self):
        (self.codex_home / 'themes/neon-dark.tmTheme').unlink()
        result, args = self.launch('fork', '--last')
        self.assertEqual((result, args), (0, ['fork', '--last']))

    def test_default_codex_home(self):
        themes = self.home / '.codex/themes'
        themes.mkdir(parents=True)
        (themes / 'neon-dark.tmTheme').write_text('installed fixture')
        result, args = self.launch(CODEX_HOME='')
        self.assertEqual((result, args), (0, ['-c', 'tui.theme="neon-dark"']))

    def test_piped_invocations_do_not_probe_or_override(self):
        result, args = self.launch('exec', '--json', 'check code', terminal=False)
        self.assertEqual((result, args), (0, ['exec', '--json', 'check code']))
        self.assertFalse(self.probes.exists())

    def test_other_operating_systems_pass_through(self):
        result, args = self.launch('--version', platform='linux-gnu')
        self.assertEqual((result, args), (0, ['--version']))
        self.assertFalse(self.probes.exists())


if __name__ == '__main__':
    unittest.main()
