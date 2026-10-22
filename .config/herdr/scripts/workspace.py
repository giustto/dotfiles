#!/usr/bin/env python3
"""Select projects by durable identity, serializing creation on each server."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = str(Path(sys.argv[1]).resolve(strict=True))
binary = os.environ.get('HERDR_BIN_PATH', 'herdr')
scope = os.environ.get('HERDR_SOCKET_PATH', 'default') + '\n' + os.environ.get('HERDR_SESSION', 'default')
state_dir = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'neon/herdr'
state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
registry = state_dir / (hashlib.sha256(scope.encode()).hexdigest()[:24] + '.json')


def api(*args):
    result = subprocess.run([binary, *args], capture_output=True, text=True, check=True)
    data = json.loads(result.stdout)
    if data.get('error'):
        raise RuntimeError(str(data['error']))
    return data['result']


with registry.with_suffix('.lock').open('a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    try:
        records = json.loads(registry.read_text())
    except (FileNotFoundError, ValueError):
        records = {}
    workspaces = api('workspace', 'list')['workspaces']
    panes = api('pane', 'list')['panes']
    ids = {w['workspace_id'] for w in workspaces}
    records = {path: entry for path, entry in records.items() if entry['workspace'] in ids}
    entry = records.get(root)
    if entry:
        anchor = next((p for p in panes if p['pane_id'] == entry['pane'] and p['workspace_id'] == entry['workspace']), None)
        # Validate against launch cwd to avoid reusing IDs belonging to a restarted server.
        if anchor and str(Path(anchor['cwd']).resolve()) == root:
            api('workspace', 'focus', entry['workspace'])
            sys.exit(0)
    # Adopt existing workspaces only via their first pane, never an incidental split.
    target = None
    for workspace in workspaces:
        if any(path != root and record['workspace'] == workspace['workspace_id'] for path, record in records.items()):
            continue
        first = next((p for p in panes if p['workspace_id'] == workspace['workspace_id']), None)
        if first and str(Path(first['cwd']).resolve()) == root:
            target = workspace['workspace_id']
            break
    if target is None:
        label = Path(root).name
        if any(w['label'] == label for w in workspaces):
            label += '-' + hashlib.sha256(root.encode()).hexdigest()[:8]
        api('workspace', 'create', '--cwd', root, '--label', label, '--env', 'DOTFILES_PROJECT_ROOT=' + root, '--focus')
        workspaces = api('workspace', 'list')['workspaces']
        panes = api('pane', 'list')['panes']
        target = next(w['workspace_id'] for w in workspaces if w['workspace_id'] not in ids and
                      any(p['workspace_id'] == w['workspace_id'] and str(Path(p['cwd']).resolve()) == root for p in panes))
    else:
        api('workspace', 'focus', target)
    first = next(p for p in panes if p['workspace_id'] == target)
    records[root] = {'workspace': target, 'pane': first['pane_id']}
    temp = registry.with_suffix('.tmp')
    temp.write_text(json.dumps(records))
    temp.chmod(0o600)
    temp.replace(registry)
