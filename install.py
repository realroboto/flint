#!/usr/bin/env python3
"""Register flint's 3 hooks in Claude Code's settings.json (idempotent).

Run from the clone — registrations point at this clone's absolute hook path,
so updating flint is `git pull`, nothing to re-copy.

    install.py               install (or re-point after a clone move)
    install.py --uninstall   remove exactly the flint entries, nothing else

Settings file: $CLAUDE_CONFIG_DIR/settings.json, default ~/.claude/settings.json.
"""
import json
import os
import sys
from pathlib import Path

if sys.version_info < (3, 6):
    sys.exit('flint install: needs Python 3.6+')

EVENTS = ('SessionStart', 'SubagentStart', 'UserPromptSubmit')
HOOK = Path(__file__).resolve().parent / 'hooks' / 'flint-style.sh'
# Identifies a flint entry in any clone location — old paths (a moved clone,
# a vmCODE-era registration) match too and get re-pointed on install.
MARKER = 'flint-style.sh'


def settings_path():
    base = os.environ.get('CLAUDE_CONFIG_DIR') or str(Path.home() / '.claude')
    return Path(base) / 'settings.json'


def hook_specs(hook=HOOK):
    """One (event, hook_obj, command) per event. The event travels as argv;
    the path is double-quoted so a clone under a path with spaces survives
    the shell (caveman #157 class)."""
    specs = []
    for event in EVENTS:
        cmd = '"{}" {}'.format(hook, event)
        specs.append((event,
                      {'matcher': '', 'hooks': [{'type': 'command', 'command': cmd,
                                                 'timeout': 10,
                                                 'statusMessage': 'Loading flint style...'}]},
                      cmd))
    return specs


def _commands(hook_list):
    for entry in hook_list:
        for h in entry.get('hooks', []):
            yield h.get('command', '')


def _strip_flint(hook_list):
    return [entry for entry in hook_list
            if not any(MARKER in c for c in _commands([entry]))]


def apply(cfg, hook=HOOK):
    """Drop stale flint entries (old paths), register the 3 current ones."""
    hooks = cfg.setdefault('hooks', {})
    for event, hook_obj, cmd in hook_specs(hook):
        entries = hooks.get(event)
        if not isinstance(entries, list):
            entries = []
        entries = _strip_flint(entries)
        entries.append(hook_obj)
        hooks[event] = entries
    return cfg


def remove(cfg):
    """Remove flint entries from every event; foreign hooks untouched."""
    hooks = cfg.get('hooks')
    if isinstance(hooks, dict):
        for event, entries in list(hooks.items()):
            if isinstance(entries, list):
                hooks[event] = _strip_flint(entries)
    return cfg


def load(path):
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except ValueError as e:
        # Never clobber a file we can't parse — that's the user's live config.
        sys.exit('flint install: {} is not valid JSON ({}); fix it first, '
                 'nothing was changed'.format(path, e))


def save(path, cfg):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix('.json.flint-tmp')
    tmp.write_text(json.dumps(cfg, indent=2) + '\n', encoding='utf-8')
    tmp.replace(path)


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    uninstall = '--uninstall' in args
    if not uninstall and not HOOK.is_file():
        sys.exit('flint install: hook not found at {} — run from the clone'
                 .format(HOOK))
    path = settings_path()
    cfg = load(path)
    save(path, remove(cfg) if uninstall else apply(cfg))
    if uninstall:
        print('flint: hooks removed from {}'.format(path))
    else:
        print('flint: 3 hooks registered in {} -> {}'.format(path, HOOK))
    return 0


if __name__ == '__main__':
    sys.exit(main())
