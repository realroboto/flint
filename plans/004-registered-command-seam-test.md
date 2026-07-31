# Plan 004: Execute the registered hook command end-to-end in tests (installer → bash → hook)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 22a6af7..HEAD -- test/ install.py uninstall.py docs/flint.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.
> Known drift, already accounted for: merges `5875127` (#7), `244ff05` (#8)
> and `14e9cb4` (#9) touched `test/test.sh` (9b/9c block; 13a comment; test 14
> body), `docs/flint.md` (§3/§5/§8/§9) and `tools/` — all AFTER or OUTSIDE the
> regions this plan cites: test 7 at `test/test.sh:60-61`, `"$PY"` at `:13`,
> and §8's installer-suite parenthetical ("registration, idempotency,
> re-pointing, foreign-hook preservation, no-clobber on invalid JSON", now at
> `docs/flint.md:204-206`) are unchanged.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (independent of plans 001-003; merge-order note in `plans/README.md`)
- **Category**: tests
- **Planned at**: commit `22a6af7`, 2026-07-30

## Why this matters

flint has two well-tested halves and one untested seam between them. The
installer suite (`test/install_test.py`) asserts the **string** written into
`settings.json`; the hook tests (`test/test.sh`) run the script directly via
`sh hooks/flint-style.sh …`. Nothing ever executes the exact registered
command — `"<absolute path>/flint-style.sh" <Event>` — through `bash -c`, which
is what Claude Code actually does. On Windows that command embeds a **native
path** (`C:\…\flint-style.sh`, produced by native Python) that Git Bash must
parse inside double quotes and translate; that translation is the single path
every real Windows user takes, and it has zero coverage. A quoting or
path-shape regression in `install.py:hook_specs()` would ship green today.

Two small gaps ride along: the hook's no-argv default (legacy
registrations run without an event argument) is documented but untested, and
`uninstall.py` (a documented entry point in the README) has no test at all.

## Current state

- `install.py:32-44` — builds the registered command; the seam under test:

  ```python
  def hook_specs(hook=HOOK):
      """One (event, hook_obj, command) per event. The event travels as argv;
      the path is double-quoted so a clone under a path with spaces survives
      the shell (caveman #157 class)."""
      specs = []
      for event in EVENTS:
          cmd = '"{}" {}'.format(hook, event)
  ```

- `test/install_test.py` — the installer suite. Conventions: plain functions
  named `test_*`, plain `assert`, discovered and run by the `__main__` block
  (`test/install_test.py:107-120`), which prints `ok  <name>` per test and a
  final `PASS`. Helpers you will reuse: `run_cli(config_dir, *args)` (runs
  `install.py` with `CLAUDE_CONFIG_DIR` set), `read_settings(config_dir)`,
  `flint_commands(cfg)`, and `ROOT` / `install.EVENTS`. No pytest, stdlib only.
- `test/test.sh:60-61` — test 7 (argv injection) shows the style for hook
  stdout assertions; `"$PY"` is defined at line 13. The new no-argv test
  slots in right after test 7.
- `hooks/flint-style.sh:28` — `EVENT="${1:-SessionStart}"` is the no-argv
  default being asserted.
- `uninstall.py` — 8 lines; runs `install.main(['--uninstall'])`.
- Expected hook outputs (for assertions): all three events print one line of
  JSON `{"hookSpecificOutput": {"hookEventName": <event>, "additionalContext": <text>}}`.
  For `SessionStart`/`SubagentStart` the context is the ruleset — after
  `lstrip()` it starts with `# flint`. For `UserPromptSubmit` it is a static
  anchor line starting `FLINT ACTIVE`. A delivery failure would instead
  contain `FLINT HOOK ERROR` (still valid JSON — assert its absence).
- CI (`.github/workflows/ci.yml`) runs `sh test/test.sh` (which invokes
  `test/install_test.py` as test 11) with `shell: bash` on
  ubuntu/macos/windows — on the Windows runner, `bash` is Git Bash and is on
  PATH for subprocesses. AGENTS.md rule: any test skipped on a platform must
  print a visible `(skipped: reason)` line.
- Python style: no f-strings (repo uses `.format()`; the installer enforces
  a 3.6 floor). The test suite's effective floor is already 3.7 —
  `test/install_test.py:19` uses `capture_output=True, text=True` — so the
  same idiom in the snippets below is correct; match it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Installer suite alone | `python3 test/install_test.py` | `ok` per test, final `PASS`, exit 0 |
| Full matrix | `sh test/test.sh` | ends `ALL PASS`, exit 0 |
| Syntax | `sh -n test/test.sh` | exit 0 |

## Scope

**In scope** (the only files you should modify):
- `test/install_test.py` (two new test functions)
- `test/test.sh` (one new hook test: 7b)
- `docs/flint.md` (§8 — one clause naming the end-to-end seam test)

**Out of scope** (do NOT touch):
- `install.py`, `uninstall.py`, `hooks/flint-style.sh` — this plan only adds
  coverage. If the new test exposes a real defect in them, that is a STOP,
  not a license to fix it here.
- `.github/workflows/ci.yml` — the existing matrix already runs everything.

## Git workflow

- Branch: `advisor/004-registered-command-seam`.
- Suggested commit: `test: execute the registered hook command end-to-end (settings -> bash -> hook)`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: End-to-end seam test in `test/install_test.py`

Add after `test_foreign_hooks_survive_install_and_uninstall` (keep the
file's alphabetical-agnostic order — the runner sorts by name anyway). Add
`import shutil` to the imports at the top (stdlib block, alphabetical).

```python
def test_registered_command_executes_end_to_end():
    # The seam real sessions take: settings.json command string -> bash ->
    # hook. On Windows the command embeds a native C:\ path that Git Bash
    # must parse inside the double quotes (caveman #157 class); asserting
    # the string alone never exercised that translation.
    if not shutil.which('bash'):
        print('     (skipped: bash not on PATH)')
        return
    with tempfile.TemporaryDirectory() as d:
        assert run_cli(d).returncode == 0
        cfg = read_settings(d)
        for event in install.EVENTS:
            cmds = [c for e in cfg['hooks'][event]
                    for c in [h['command'] for h in e['hooks']]
                    if 'flint-style.sh' in c]
            assert len(cmds) == 1
            r = subprocess.run(['bash', '-c', cmds[0]], capture_output=True,
                               text=True, timeout=15)
            assert r.returncode == 0, (event, r.returncode, r.stderr)
            out = json.loads(r.stdout)
            assert out['hookSpecificOutput']['hookEventName'] == event
            ctx = out['hookSpecificOutput']['additionalContext']
            assert 'FLINT HOOK ERROR' not in ctx
            if event == 'UserPromptSubmit':
                assert ctx.startswith('FLINT ACTIVE')
            else:
                assert ctx.lstrip().startswith('# flint')
```

Notes: `timeout=15` bounds a hang (AGENTS.md: a hung step must fail loudly,
never eat the runner). The command string comes from the settings file the
real install wrote — do not rebuild it from `hook_specs()`; the point is the
persisted artifact.

**Verify**: `python3 test/install_test.py` → prints
`ok  test_registered_command_executes_end_to_end`, final `PASS`, exit 0.

### Step 2: `uninstall.py` wrapper test in `test/install_test.py`

```python
def test_uninstall_py_wrapper_removes_entries():
    with tempfile.TemporaryDirectory() as d:
        run_cli(d)
        env = dict(os.environ, CLAUDE_CONFIG_DIR=str(d))
        r = subprocess.run([sys.executable, str(ROOT / 'uninstall.py')],
                           env=env, capture_output=True, text=True)
        assert r.returncode == 0
        assert flint_commands(read_settings(d)) == []
```

**Verify**: `python3 test/install_test.py` → both new tests `ok`, final `PASS`.

### Step 3: No-argv default test in `test/test.sh`

Insert after test 7 (`test/test.sh:61`), before the `# 8:` block:

```sh
# 7b: no argv (a legacy registration) -> defaults to SessionStart
sh hooks/flint-style.sh | "$PY" -c 'import json,sys; assert json.load(sys.stdin)["hookSpecificOutput"]["hookEventName"]=="SessionStart"'; ck $? "7b no-arg default"
```

POSIX sh only; single line matching the surrounding style.

**Verify**: `sh test/test.sh` → output contains `ok  7b no-arg default`, ends
`ALL PASS`.

### Step 4: Name the seam in the reference doc

`docs/flint.md` §8 lists what the installer suite covers ("registration,
idempotency, re-pointing, foreign-hook preservation, no-clobber on invalid
JSON"). Extend that parenthetical with: "end-to-end execution of the
registered command through bash". Keep §8's single-paragraph shape.

**Verify**: `grep -n 'end-to-end' docs/flint.md` → one match in §8.

## Test plan

The plan IS tests. Coverage added:

- Happy path per event: registered command executes, exits 0, emits the
  right envelope, right event name, non-error content (ruleset vs anchor).
- Regression net for: path quoting (spaces), Windows native-path
  translation through Git Bash (exercised on the Windows CI runner), stale
  `hook_specs` format changes.
- No-argv legacy default (`EVENT="${1:-SessionStart}"`).
- `uninstall.py` documented entry point.
- Run everything: `sh test/test.sh` → `ALL PASS` (test 11 wraps the
  installer suite; 7b runs directly).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `python3 test/install_test.py` exits 0; output contains
      `ok  test_registered_command_executes_end_to_end` and
      `ok  test_uninstall_py_wrapper_removes_entries`
- [ ] `sh test/test.sh` exits 0, ends `ALL PASS`, contains `ok  7b no-arg default`
- [ ] `sh -n test/test.sh` exits 0
- [ ] `grep -c 'f"' test/install_test.py` prints `0` (no f-strings — 3.6 floor)
- [ ] `git status --porcelain` shows changes only in `test/install_test.py`,
      `test/test.sh`, `docs/flint.md`, `plans/README.md`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The end-to-end test FAILS while the direct hook tests (1-3) pass — you
  have found a real seam defect (quoting, path translation). That is the
  most valuable possible outcome of this plan: report the exact failing
  command string, platform, `returncode`, and `stderr`. Do not patch
  `install.py` or the hook; that fix needs its own reviewed change.
- `bash -c` hangs to the 15 s timeout — report; do not raise the timeout to
  make it pass.
- The helpers named in "Current state" (`run_cli`, `read_settings`,
  `flint_commands`) don't exist as excerpted (drift).

## Maintenance notes

- This test executes the hook ~3 more times per suite run (still
  sub-second) and requires `bash` on PATH — guaranteed on all three CI
  runners; the printed skip covers exotic local environments.
- If a future plan changes the registered command shape (`hook_specs`),
  this test is the one that must red on a mistake — reviewers should treat
  a "loosen the end-to-end assertions" diff as a red flag.
- Windows reviewers: the first CI run after merge is the real payoff —
  confirm the `windows-latest` job stays green (it now proves Git Bash
  resolves the native quoted path).
- Deferred deliberately: asserting the full `bash -c` invocation matches
  Claude Code's internal exec semantics exactly — the official mechanism is
  "shell-form hooks run via Git Bash" (ADR 0002); `bash -c <command>` is the
  documented equivalent and close enough for a regression net.
