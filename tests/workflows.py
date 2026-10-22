#!/usr/bin/env python3
"""Exercise project pickers against an isolated Herdr server and temporary files."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def check():
    with tempfile.TemporaryDirectory(prefix="dotfiles-test-", dir="/tmp") as tmp:
        tmp = Path(tmp)
        home = tmp / "home"
        home.mkdir()
        config = tmp / "config"
        (config / "herdr").mkdir(parents=True)
        (config / "shell").mkdir()
        shutil.copy(ROOT / ".config/shell/projects.sh", config / "shell/projects.sh")
        # Use the real keymap/theme, but keep all shells, state and sockets isolated.
        content = (ROOT / ".config/herdr/config.toml").read_text()
        content = content.replace("[terminal]", '[terminal]\ndefault_shell = "/bin/sh"')
        content += "\n[update]\nversion_check = false\nmanifest_check = false\n"
        conf = config / "herdr/config.toml"
        conf.write_text(content)
        binary = shutil.which("herdr")
        assert binary, "Install dependencies with brew bundle first"
        bindir = tmp / "bin"
        bindir.mkdir()
        fzf = bindir / "fzf"
        fzf.write_text('#!/bin/sh\ncat >/dev/null\nprintf "%s\\n" "$TEST_FZF_OUTPUT"\nexit "${TEST_FZF_STATUS:-0}"\n')
        fzf.chmod(0o755)
        env = {k: v for k, v in os.environ.items() if not k.startswith("HERDR_")}
        env.update(HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_DATA_HOME=str(tmp / "data"),
                   XDG_STATE_HOME=str(tmp / "state"), XDG_CACHE_HOME=str(tmp / "cache"),
                   HERDR_CONFIG_PATH=str(conf), HERDR_SOCKET_PATH=str(tmp / "h.sock"),
                   HERDR_BIN_PATH=binary, PATH=str(bindir) + ":" + os.environ["PATH"])

        def run(args, **overrides):
            result = subprocess.run(args, env=dict(env, **overrides), text=True,
                                    capture_output=True, timeout=15, cwd=home)
            assert result.returncode == 0, f"{args}: {result.stderr} {result.stdout}"
            return result.stdout

        def api(*args):
            return json.loads(run([binary, *args]))["result"]

        def pick(directory, typed=False):
            output = f"{directory}\nctrl-n\n" if typed else f"\n\n{directory}"
            return run(["sh", str(ROOT / ".config/herdr/scripts/sessionizer")], TEST_FZF_OUTPUT=output)

        with (tmp / "server.log").open("w+") as log:
            server = subprocess.Popen([binary, "server"], env=env, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 5
                while not (tmp / "h.sock").exists():
                    if server.poll() is not None or time.monotonic() > deadline:
                        log.seek(0)
                        raise AssertionError("Herdr test server failed: " + log.read())
                    time.sleep(0.05)
                first = home / "Projects/client one/api"
                second = home / "Projects/client two/api"
                long = home / ("long-path-" * 12) / "project"
                for directory in (first, second, long):
                    directory.mkdir(parents=True)
                pick(first)
                workspaces = api("workspace", "list")["workspaces"]
                assert len(workspaces) == 1
                first_id = workspaces[0]["workspace_id"]
                assert workspaces[0]["label"] == "api"
                api("workspace", "rename", first_id, "custom name")
                # A split in another project must not change this workspace's identity.
                anchor = next(p['pane_id'] for p in api('pane', 'list')['panes'] if p['workspace_id'] == first_id)
                api('pane', 'split', anchor, '--cwd', str(second), '--direction', 'right', '--no-focus')
                pick(second)
                pick(first)
                workspaces = api("workspace", "list")["workspaces"]
                assert len(workspaces) == 2, "Same-name projects must remain distinct"
                assert next(w for w in workspaces if w["focused"])["workspace_id"] == first_id
                third = home / "Projects/client three/api"
                third.mkdir(parents=True)
                pick(third)
                workspaces = api("workspace", "list")["workspaces"]
                assert len(workspaces) == 3 and len({w["label"] for w in workspaces}) == 3
                alias = home / "alias"
                alias.symlink_to(first, target_is_directory=True)
                pick(alias)
                assert len(api("workspace", "list")["workspaces"]) == 3, "Resolve symlink aliases"
                pick(long, typed=True)
                pick(long)
                assert len(api("workspace", "list")["workspaces"]) == 4, "Long paths remain reusable"
                # Simultaneous launches for one project serialize reuse/create decisions.
                selection = f'\n\n{long}'
                children = [subprocess.Popen(['sh', str(ROOT / '.config/herdr/scripts/sessionizer')],
                                             env=dict(env, TEST_FZF_OUTPUT=selection), stdout=subprocess.PIPE,
                                             stderr=subprocess.PIPE, text=True) for _ in range(3)]
                for child in children:
                    output, error = child.communicate(timeout=15)
                    assert child.returncode == 0, error + output
                assert len(api('workspace', 'list')['workspaces']) == 4, 'Concurrent project selection creates no duplicates'
                run(["sh", str(ROOT / ".config/herdr/scripts/sessionizer")],
                    TEST_FZF_OUTPUT="", TEST_FZF_STATUS="130")
                invalid = subprocess.run(["sh", str(ROOT / ".config/herdr/scripts/sessionizer")],
                                         env=dict(env, TEST_FZF_OUTPUT=f"{home}/missing\nctrl-n\n"),
                                         capture_output=True, text=True, timeout=5)
                assert invalid.returncode == 2 and "does not exist" in invalid.stderr
                assert len(api("workspace", "list")["workspaces"]) == 4, "Cancel/invalid paths create nothing"
                # Shared helpers must work in Zsh without clobbering its special $path array.
                script = '. "$XDG_CONFIG_HOME/shell/projects.sh"; project_paths; command -v sh'
                paths = run(["zsh", "-f", "-c", script])
                assert str(first.resolve()) in paths and "/sh" in paths
                names = run(["sh", "-c", '. "$1"; project_name "$2"; project_name "$3"',
                             "sh", str(config / "shell/projects.sh"), str(first), str(second)]).splitlines()
                assert names[0] != names[1], "tmux session names must include path identity"
                # tmux gives the real Herdr client a terminal and encodes Alt keys.
                tmux_socket = str(tmp / "t.sock")

                def tmux(*args):
                    return run(["tmux", "-S", tmux_socket, *args])

                def wait_for(predicate, message):
                    deadline = time.monotonic() + 4
                    while time.monotonic() < deadline:
                        if predicate():
                            return
                        time.sleep(0.05)
                    raise AssertionError(message)

                def focused_number():
                    return next(w["number"] for w in api("workspace", "list")["workspaces"] if w["focused"])

                try:
                    tmux("-f", "/dev/null", "new-session", "-d", "-s", "client", "-x", "140", "-y", "40", binary)
                    time.sleep(1)
                    for key, number in (("M-2", 2), ("M-1", 1), ("M-j", 2), ("M-k", 1)):
                        tmux("send-keys", "-t", "client", key)
                        wait_for(lambda: focused_number() == number, "Workspace shortcut " + key + ' expected ' + str(number))
                    tmux("send-keys", "-t", "client", "M-n")
                    time.sleep(0.2)
                    tmux("send-keys", "-t", "client", "-l", "keyboard workspace")
                    tmux("send-keys", "-t", "client", "Enter")
                    wait_for(lambda: len(api("workspace", "list")["workspaces"]) == 5,
                             "Alt-N creates a named workspace")
                    tmux("source-file", str(ROOT / ".config/tmux/tmux.conf"))
                finally:
                    subprocess.run(["tmux", "-S", tmux_socket, "kill-server"], env=env,
                                   capture_output=True, timeout=5)
                print("PASS: Herdr native keyboard creation/cycling/jumps, project reuse, duplicate names, symlinks, long/typed paths, cancellation, Zsh helpers, tmux config")
            finally:
                subprocess.run([binary, "server", "stop"], env=env, capture_output=True, timeout=5)
                if server.poll() is None:
                    server.terminate()
                server.wait(timeout=5)


if __name__ == "__main__":
    check()
