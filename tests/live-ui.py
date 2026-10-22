#!/usr/bin/env python3
"""Exercise actual insert-mode picker refresh in an isolated terminal UI."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=12)
    assert result.returncode == 0, result.stderr + result.stdout
    return result.stdout.strip()


with tempfile.TemporaryDirectory(prefix='neon-ui-', dir='/tmp') as directory:
    root = Path(directory)
    socket = str(root / 't.sock')
    rpc = str(root / 'n.sock')
    nvim = shutil.which('nvim')

    def git(*args):
        return run('git', '-C', str(root), *args)

    def tmux(*args):
        return run('tmux', '-S', socket, *args)

    def lua(code):
        expression = 'luaeval(' + json.dumps('vim.json.encode((function() ' + code + ' end)())') + ')'
        return json.loads(run(nvim, '--server', rpc, '--remote-expr', expression))

    def wait(predicate, message):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            try:
                if predicate():
                    return
            except (AssertionError, ValueError):
                pass
            time.sleep(0.05)
        raise AssertionError(message)

    git('init', '-b', 'main')
    git('config', 'user.name', 'UI validation')
    git('config', 'user.email', 'ui@example.invalid')
    (root / 'one.txt').write_text('base\n')
    git('add', 'one.txt')
    git('commit', '-m', 'base initial')
    original = git('rev-parse', 'HEAD')
    try:
        tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'editor', '-x', '140', '-y', '40',
             '-c', str(root), nvim, '--listen', rpc, str(root / 'one.txt'))
        wait(lambda: Path(rpc).exists() and lua('return vim.v.vim_did_enter == 1'), 'Native Neovim UI starts')
        lua("vim.schedule(function() _G.live_picker = require('config.review').commits() end); return true")
        wait(lambda: lua("return _G.live_picker and _G.live_picker.shown and vim.fn.mode():sub(1,1) == 'i'"),
             'Commit picker enters actual insert mode')
        tmux('send-keys', '-t', 'editor', '-l', 'base')
        wait(lambda: lua("return _G.live_picker.input.filter.pattern == 'base' and not _G.live_picker:is_active()"),
             'Query is active')
        (root / 'one.txt').write_text('external agent commit\n')
        git('commit', '-am', 'base new agent commit')
        wait(lambda: lua('return #_G.live_picker:items() == 2 and not _G.live_picker.neon_refreshing'),
             'Picker updates while user remains in insert mode')
        state = lua("return {mode=vim.fn.mode(), query=_G.live_picker.input.filter.pattern, commit=_G.live_picker:current().commit, error=vim.v.errmsg}")
        assert state['mode'].startswith('i') and state['query'] == 'base' and original.startswith(state['commit']), state
        assert not state['error'], state
        screen = tmux('capture-pane', '-p', '-t', 'editor')
        assert 'base new agent commit' in screen and 'base initial' in screen, screen
        print('PASS: actual terminal UI preserves insert mode, query, focus and selected commit while live results update')
    finally:
        subprocess.run(['tmux', '-S', socket, 'kill-server'], capture_output=True, timeout=5)
