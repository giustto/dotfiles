#!/usr/bin/env python3
"""Verify checkpoints and review marks across independent Neovim processes."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, timeout=60, **kwargs)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout.strip()


with tempfile.TemporaryDirectory(prefix='neon-checkpoints-', dir='/tmp') as directory:
    root = Path(directory) / 'project with spaces'
    root.mkdir()

    def git(*args):
        return run('git', '-C', str(root), *args)

    git('init', '-b', 'main')
    git('config', 'user.name', 'Checkpoint validation')
    git('config', 'user.email', 'test@example.invalid')
    git('config', 'core.filemode', 'true')
    for name in ('tracked.txt', 'staged.txt', 'unstaged.txt', 'script.sh'):
        (root / name).write_text('initial\n')
    for name in ('target-a.txt', 'target-b.txt', 'target-c.txt'):
        (root / name).write_text('identical target contents\n')
    (root / 'link.txt').symlink_to('target-a.txt')
    (root / '.gitignore').write_text('ignored.txt\n')
    git('add', '.')
    git('commit', '-m', 'initial')
    head = git('rev-parse', 'HEAD')
    (root / 'staged.txt').write_text('before agent staged\n')
    git('add', 'staged.txt')
    (root / 'unstaged.txt').write_text('before agent unstaged\n')
    (root / 'untracked.txt').write_text('before agent untracked\n')
    (root / 'ignored.txt').write_text('ignored\n')
    original_status = git('status', '--porcelain')
    original_index = git('write-tree')
    env = dict(os.environ, NEON_REVIEW_TEST_ROOT=str(root), DOTFILES_ROOT=str(ROOT),
               XDG_STATE_HOME=str(Path(directory) / 'state'))

    def phase(name):
        output = run('nvim', '--headless', '--cmd',
                     'lua vim.opt.rtp:prepend(vim.env.DOTFILES_ROOT .. "/.config/nvim")',
                     '-u', str(ROOT / '.config/nvim/init.lua'),
                     '+lua vim.opt.rtp:prepend(vim.env.DOTFILES_ROOT .. "/.config/nvim")',
                     '+lua dofile(vim.env.DOTFILES_ROOT .. "/.config/nvim/tests/checkpoints.lua")',
                     env=dict(env, NEON_REVIEW_TEST_PHASE=name), cwd=root)
        if output:
            print(output)

    phase('capture')
    assert git('status', '--porcelain') == original_status
    assert git('write-tree') == original_index and git('rev-parse', 'HEAD') == head
    (root / 'tracked.txt').write_text('agent refinement\n')
    (root / 'script.sh').write_text('agent script\n')
    (root / 'link.txt').unlink()
    (root / 'link.txt').symlink_to('target-b.txt')
    phase('mark')
    phase('resume')
    assert git('write-tree') == original_index, 'Review operations must preserve the real index'
    assert git('rev-parse', 'HEAD') == head, 'Checkpoint/review must preserve branch HEAD'
    print('PASS: checkpoint and review state survives independent Neovim processes; '
          'unsaved edits, review queues, scope isolation, executable modes and symlink targets')
