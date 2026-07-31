# Plan 001: Make an empty or unreadable ruleset fire the loud marker, never silent-empty context

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 22a6af7..HEAD -- hooks/flint-style.sh test/test.sh docs/flint.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `22a6af7`, 2026-07-30

## Why this matters

flint is a Claude Code hook that injects a style ruleset (`flint.md`) into every
session. Its hard invariant #4 (documented in `docs/flint.md` §5) is: any
delivery failure must emit a loud in-session marker (`FLINT HOOK ERROR: …`),
never silently inject nothing — the upstream bug this fixed (caveman #587)
served a stale ruleset in silence for months.

There is a hole in that invariant today. The hook checks the ruleset with
`[ -f ]`, which passes for a 0-byte file, and the read stage cannot distinguish
"read produced nothing" from success. Three reachable cases produce a **valid
JSON envelope with an empty `additionalContext`** — no marker, no error:

1. A 0-byte ruleset file at any of the three resolution paths.
2. A file that passes the `-f` stat but fails the read with `EACCES` (for
   example, a root-owned `/etc/claude-docs/flint.md` with mode 600 in a
   misbuilt container — the baked-path geometry this hook explicitly supports).
3. The file being deleted between the existence check and the `head` read.

The repo's own doctrine already gestures at the fix: `docs/hook-engineering.md`
line 73 says "a build-time assert (`[ -s file ]`) beats a runtime fallback".

## Current state

Relevant files:

- `hooks/flint-style.sh` — the product's delivery script. Carries 8 invariants
  listed in `docs/flint.md` §5; **read that section before editing**. The ones
  this plan must not break: always exit 0 on every path; never read the hook's
  own stdin (the python stage reads from the `head` pipe — that is allowed and
  must stay); POSIX sh only (no `[[ ]]`, no arrays, no GNU-only flags — must
  run on macOS bash 3.2, Debian dash, and Git Bash); quote every expansion.
- `test/test.sh` — POSIX-sh test matrix, run as `sh test/test.sh` from repo
  root. Same POSIX constraints. CI runs it on ubuntu/macos/windows; **any test
  skipped on a platform must print an `ok … (skipped: reason)` line**
  (AGENTS.md rule).
- `docs/flint.md` — reference doc; §5 invariant list and §8 test-matrix
  summary must be updated in the same change ("When this file and the code
  disagree, the code is right — fix this file in the same change", its own
  header).

Ruleset resolution as it exists today, `hooks/flint-style.sh:49-59`:

```sh
RULESET='/etc/claude-docs/flint.md'
if [ ! -f "$RULESET" ]; then
    DIR="$(dirname "$0" 2>/dev/null)"
    if [ -f "$DIR/../flint.md" ] && [ ! -L "$DIR/../flint.md" ]; then
        RULESET="$DIR/../flint.md"
    elif [ -f "$DIR/../container-docs/flint.md" ] && [ ! -L "$DIR/../container-docs/flint.md" ]; then
        RULESET="$DIR/../container-docs/flint.md"
    else
        emit_marker 'ruleset not found at /etc/claude-docs/flint.md, ../flint.md, or ../container-docs/flint.md'
    fi
fi
```

Encode stage as it exists today, `hooks/flint-style.sh:69-77`:

```sh
head -c 65536 "$RULESET" 2>/dev/null | "$PYBIN" -c '
import json, sys
txt = sys.stdin.buffer.read().decode("utf-8", "replace")
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": sys.argv[1],
    "additionalContext": txt,
}}))
' "$EVENT" 2>/dev/null || emit_marker 'python JSON encoding failed'
exit 0
```

`emit_marker` (`hooks/flint-style.sh:41-44`) prints the marker JSON and ends
with `exit 0` — reusing it keeps the always-exit-0 invariant.

Test fixture flow in `test/test.sh` you will extend: `$FX` is a `mktemp -d`
copy of the hook with no ruleset. Test 8 symlinks `$FX/flint.md`, test 9 does
`rm -f "$FX/flint.md"` then writes an oversize ruleset there
(`test/test.sh:63-80`). Your new tests slot in after test 9, before test 10
(`test/test.sh:82`). Test style to match — one line, `ck $?` with a numbered
label:

```sh
sh "$FX/hooks/flint-style.sh" SessionStart | grep -q 'FLINT HOOK ERROR'; ck $? "4 missing ruleset -> loud marker"
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full test matrix | `sh test/test.sh` | ends `ALL PASS`, exit 0 |
| Shell lint (if installed) | `shellcheck hooks/flint-style.sh install.sh test/test.sh` | exit 0 (CI runs this; run locally when available) |
| Syntax check | `bash -n hooks/flint-style.sh && sh -n hooks/flint-style.sh` | exit 0, no output |

## Scope

**In scope** (the only files you should modify):
- `hooks/flint-style.sh`
- `test/test.sh`
- `docs/flint.md` (§3 item 4, §5 invariant 4, §8 — three small text edits)

**Out of scope** (do NOT touch, even though they look related):
- `flint.md` (repo root) — the ruleset text; any edit triggers derivado
  re-sync and budget churn. Nothing here requires it.
- `install.py`, `install.sh`, `install.ps1`, `uninstall.py`, `test/install_test.py`
- `desktop/` — derivados; regenerated only on ruleset changes.
- `AGENTS.md` — its invariant summary ("loud FLINT HOOK ERROR marker (never
  silent-empty)") already covers the new behavior; no edit needed.

## Git workflow

- Branch: `advisor/001-hook-silent-empty` (repo works directly on `main`; use
  a branch since this is dispatched work).
- Commit style: conventional-commit-ish, matching `git log` (for example
  `fix(test): guard the ruleset against the 10k hook-output cap, not 64 KB`).
  Suggested: `fix(hook): loud marker on empty or unreadable ruleset, never silent-empty`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Treat empty files as missing in resolution

In `hooks/flint-style.sh:49-59`, change the three `-f` tests to `-s` (file
exists AND has size > 0), and extend the marker message. Target state:

```sh
RULESET='/etc/claude-docs/flint.md'
if [ ! -s "$RULESET" ]; then
    DIR="$(dirname "$0" 2>/dev/null)"
    if [ -s "$DIR/../flint.md" ] && [ ! -L "$DIR/../flint.md" ]; then
        RULESET="$DIR/../flint.md"
    elif [ -s "$DIR/../container-docs/flint.md" ] && [ ! -L "$DIR/../container-docs/flint.md" ]; then
        RULESET="$DIR/../container-docs/flint.md"
    else
        emit_marker 'ruleset not found (or empty) at /etc/claude-docs/flint.md, ../flint.md, or ../container-docs/flint.md'
    fi
fi
```

Keep the `[ ! -L ]` symlink refusals exactly as they are (invariant #5).
Also update the header comment block at the top of the script if it mentions
the missing-paths marker, so comment and behavior match.

**Verify**: `bash -n hooks/flint-style.sh && sh -n hooks/flint-style.sh` → exit 0.

### Step 2: Guard the encode stage against an empty read

In the python snippet (`hooks/flint-style.sh:69-77`), exit non-zero when the
read produced nothing, so the existing `|| emit_marker` catches `EACCES`,
delete-after-check races, and any other silent-empty read. Update the marker
message to cover the new cause. Target state:

```sh
head -c 65536 "$RULESET" 2>/dev/null | "$PYBIN" -c '
import json, sys
txt = sys.stdin.buffer.read().decode("utf-8", "replace")
if not txt.strip():
    sys.exit(3)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": sys.argv[1],
    "additionalContext": txt,
}}))
' "$EVENT" 2>/dev/null || emit_marker 'ruleset unreadable, empty, or JSON encoding failed'
exit 0
```

Constraint check (do not deviate): the python stage keeps reading from the
`head` **pipe** — this is not the forbidden "hook reads stdin" pattern
(invariant #2 concerns the hook process's own stdin from Claude Code, which
`test/test.sh` test 6b asserts stays untouched). Every failure path still ends
in `emit_marker`, which exits 0 (invariant #1).

**Verify**: `sh test/test.sh` → ends `ALL PASS` (all existing tests still green).

### Step 3: Add regression tests

In `test/test.sh`, insert after test 9 (the `ck $? "9 64KB cap"` line at
`test/test.sh:80`) and before the `# 10: shell syntax` block:

```sh
# 9b: EMPTY ruleset -> loud marker. `-f` passed a 0-byte file; `-s` must not.
: > "$FX/flint.md"
sh "$FX/hooks/flint-style.sh" SessionStart | grep -q 'FLINT HOOK ERROR'; ck $? "9b empty ruleset -> loud marker"

# 9c: UNREADABLE ruleset -> loud marker (the -s stat passes, the read fails).
# Skip where chmod 000 cannot actually revoke read: MSYS fakes POSIX modes,
# and root reads through 000.
printf '# flint\n' > "$FX/flint.md"
chmod 000 "$FX/flint.md" 2>/dev/null
if [ -r "$FX/flint.md" ]; then
    echo "ok  9c unreadable ruleset -> loud marker (skipped: chmod cannot revoke read here)"
else
    sh "$FX/hooks/flint-style.sh" SessionStart | grep -q 'FLINT HOOK ERROR'; ck $? "9c unreadable ruleset -> loud marker"
fi
chmod 644 "$FX/flint.md" 2>/dev/null
```

Notes: the `[ -r ]` probe (not a `uname` sniff) is the skip gate — this repo's
CI history (AGENTS.md) demands capability probes over OS guesses where
possible, and a printed `(skipped: reason)` line whenever a test doesn't run.
The final `chmod 644` keeps the later `rm -rf "$FX"` cleanup unsurprising.
POSIX sh only — no bashisms.

**Verify**: `sh test/test.sh` → output contains `ok  9b empty ruleset -> loud marker`
and either `ok  9c unreadable ruleset -> loud marker` or its `(skipped: …)`
form, and ends `ALL PASS`.

### Step 4: Sync the reference doc

In `docs/flint.md` (its header requires doc and code to change together):

- §3 resolution list, item 4 ("None exists → **loud error marker** as
  `additionalContext`"): update the lead to "None exists (or the file is
  empty/unreadable) →" so the resolution table matches the new `-s` behavior.
- §5 invariant list, item 4 ("Loud marker on failure, never silent-empty."):
  append one sentence stating that empty/unreadable counts as failure —
  resolution uses `-s`, and the encode stage exits into the marker on empty
  input, so a 0-byte file, an `EACCES` read, or a delete-after-check race all
  produce the marker instead of empty context.
- §8 (test matrix summary): in the parenthetical list of hook-contract tests,
  add "empty/unreadable ruleset markers" alongside the existing entries.

**Verify**: `grep -n 'empty/unreadable' docs/flint.md` shows the §3 and §5 edits;
`sh test/test.sh` still ends `ALL PASS`.

## Test plan

- New tests: `test/test.sh` 9b (empty file → marker) and 9c (unreadable file →
  marker, capability-gated skip), as specified in Step 3. Modeled structurally
  on existing tests 4 and 8.
- Full suite: `sh test/test.sh` → `ALL PASS`. There is no other test runner.
- If `shellcheck` is installed locally, run
  `shellcheck hooks/flint-style.sh install.sh test/test.sh` → exit 0. CI runs
  it regardless.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `sh test/test.sh` exits 0 and ends `ALL PASS`
- [ ] Output includes `ok  9b` and `ok  9c` lines (9c may be the skipped form)
- [ ] `grep -c '\[ -f ' hooks/flint-style.sh` prints `0` (all ruleset checks are `-s` now)
- [ ] `grep -q 'sys.exit(3)' hooks/flint-style.sh` succeeds
- [ ] `bash -n hooks/flint-style.sh && sh -n hooks/flint-style.sh && sh -n test/test.sh` exits 0
- [ ] `git status --porcelain` shows changes only in `hooks/flint-style.sh`, `test/test.sh`, `docs/flint.md`, `plans/README.md`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" don't match `hooks/flint-style.sh` at the
  cited lines (drift since `22a6af7`).
- Any pre-existing test (1 through 14) fails after your change — especially
  6b (stdin held open) or 4/4b (marker path) — and a second look at your edit
  doesn't explain it.
- You find yourself wanting to add a bash-only construct, read the hook's own
  stdin, or exit non-zero on any path — these violate documented invariants;
  the plan is wrong, not the invariant.
- A machine you test on has `/etc/claude-docs/flint.md` present (the baked
  container path) — the `$FX` fixtures assume it is absent; report instead of
  working around it.

## Maintenance notes

- Reviewer should scrutinize: the three `-s` swaps keep their `! -L` partners
  intact; the python snippet still takes input only from the pipe; both new
  marker messages still contain the literal `FLINT HOOK ERROR` prefix (via
  `emit_marker`), which README and tests grep for.
- Future interaction: if the hook ever gains a fourth resolution path, it must
  use `-s` + `! -L` like the others, and the marker message string must list it.
- Deferred deliberately: parent-directory symlink detection (a symlinked
  directory containing a real `flint.md` bypasses `[ -L ]` on the file). A
  POSIX-portable path-component walk was judged disproportionate to the
  marginal threat — recorded as rejected in `plans/README.md`; do not add it here.
