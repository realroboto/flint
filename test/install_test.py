#!/usr/bin/env python3
"""Installer seam tests: end state of settings.json only, no internals.
Run: python3 test/install_test.py  (expect: PASS)"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
import install  # noqa: E402


def run_cli(config_dir, *args):
    env = dict(os.environ, CLAUDE_CONFIG_DIR=str(config_dir))
    return subprocess.run([sys.executable, str(ROOT / 'install.py'), *args],
                          env=env, capture_output=True, text=True)


def read_settings(config_dir):
    return json.loads((Path(config_dir) / 'settings.json').read_text())


def flint_commands(cfg):
    out = []
    for entries in cfg.get('hooks', {}).values():
        for entry in entries:
            for h in entry.get('hooks', []):
                if 'flint-style.sh' in h.get('command', ''):
                    out.append(h['command'])
    return out


def test_install_registers_3_events_with_quoted_path_and_event_argv():
    with tempfile.TemporaryDirectory() as d:
        assert run_cli(d).returncode == 0
        cfg = read_settings(d)
        assert set(cfg['hooks']) >= set(install.EVENTS)
        for event in install.EVENTS:
            cmds = [c for e in cfg['hooks'][event] for c in
                    [h['command'] for h in e['hooks']] if 'flint-style.sh' in c]
            assert cmds == ['"{}" {}'.format(install.HOOK, event)]
            assert cfg['hooks'][event][0]['matcher'] == ''  # re-fires on compact


def test_install_is_idempotent_across_reruns():
    with tempfile.TemporaryDirectory() as d:
        run_cli(d)
        run_cli(d)
        assert len(flint_commands(read_settings(d))) == 3


def test_install_repoints_a_stale_clone_path():
    with tempfile.TemporaryDirectory() as d:
        stale = {'hooks': {'SessionStart': [
            {'matcher': '', 'hooks': [{'type': 'command',
             'command': '/old/vmCODE/scripts/flint-style.sh SessionStart'}]}]}}
        p = Path(d) / 'settings.json'
        p.write_text(json.dumps(stale))
        run_cli(d)
        cmds = flint_commands(read_settings(d))
        assert len(cmds) == 3
        assert not any('/old/vmCODE' in c for c in cmds)


def test_foreign_hooks_survive_install_and_uninstall():
    foreign = {'matcher': '', 'hooks': [{'type': 'command',
               'command': '/usr/local/bin/other-hook.sh'}]}
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / 'settings.json'
        p.write_text(json.dumps({'hooks': {'SessionStart': [foreign]},
                                 'model': 'opus'}))
        run_cli(d)
        run_cli(d, '--uninstall')
        cfg = read_settings(d)
        assert cfg['hooks']['SessionStart'] == [foreign]
        assert cfg['model'] == 'opus'
        assert flint_commands(cfg) == []


def test_default_home_branch_without_claude_config_dir():
    # The branch real installs hit: no CLAUDE_CONFIG_DIR, settings under
    # ~/.claude. HOME (POSIX) and USERPROFILE (Windows) both point at the tmp.
    with tempfile.TemporaryDirectory() as d:
        env = {k: v for k, v in os.environ.items() if k != 'CLAUDE_CONFIG_DIR'}
        env['HOME'] = d
        env['USERPROFILE'] = d
        r = subprocess.run([sys.executable, str(ROOT / 'install.py')],
                           env=env, capture_output=True, text=True)
        assert r.returncode == 0
        cfg = json.loads((Path(d) / '.claude' / 'settings.json').read_text())
        assert len(flint_commands(cfg)) == 3


def test_invalid_settings_json_aborts_without_clobber():
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / 'settings.json'
        p.write_text('{broken')
        r = run_cli(d)
        assert r.returncode != 0
        assert 'nothing was changed' in r.stderr
        assert p.read_text() == '{broken'


if __name__ == '__main__':
    failed = 0
    for name, fn in sorted(globals().items()):
        if name.startswith('test_') and callable(fn):
            try:
                fn()
                print('ok  {}'.format(name))
            except AssertionError:
                failed += 1
                import traceback
                traceback.print_exc()
                print('FAIL {}'.format(name))
    print('PASS' if not failed else 'FAIL ({})'.format(failed))
    sys.exit(1 if failed else 0)
