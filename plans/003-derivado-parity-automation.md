# Plan 003: Regenerate verbatim derivados by script and enforce byte parity in the test matrix

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 22a6af7..HEAD -- tools/ desktop/ test/test.sh flint.md AGENTS.md docs/flint.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. A changed `flint.md` in particular
> means the parity baseline moved — STOP.
> Known drift, already accounted for: merge `5875127` (ticket #7) added the
> 9b/9c block to `test/test.sh` and text to `docs/flint.md` §3/§5/§8 — line
> numbers below are post-#7; `flint.md` and the derivados are untouched.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/002-gitattributes-lf-pin.md (recommended, not hard — see Maintenance notes)
- **Category**: tests / tech-debt
- **Planned at**: commit `22a6af7`, 2026-07-30

## Why this matters

flint's product is the exact wording of a ruleset (`flint.md`). Two "verbatim
derivados" — `desktop/chat/project-instructions.md` and
`desktop/cowork/SKILL.md` — must carry that ruleset word-for-word (a fixed
header plus the ruleset with paragraph hard-wraps removed). Today their
integrity rests on a manual checklist (`desktop/README.md`) plus two weak
automated guards: a single grep'd canary token and byte-size budgets
(`test/test.sh` tests 13/14). A regeneration that drops or paraphrases any
other sentence ships green. Instruction drift between copies is precisely the
bug class this repo was created to kill (ADR 0001: "two editable copies would
be an instruction-drift hazard").

The audit verified that full byte parity is already true today and cheap to
check mechanically: `header + unwrap(flint.md)` equals both files exactly.
This plan makes that the enforced definition: a script regenerates the two
files, and the test matrix fails on any byte of drift. The manual checklist
shrinks; the drift class dies.

## Current state

- `flint.md` — the ruleset, hard-wrapped ~78 cols. **Do not edit it.**
- `tools/unwrap.py` — removes paragraph hard-wraps for paste-in artifacts.
  Its `unwrap(text)` function is correct (audit-verified), but the module has
  two blockers for reuse:
  - runs its file-rewriting main loop at import time (`tools/unwrap.py:52-56`):

    ```python
    for path in sys.argv[1:]:
        with open(path) as fh:
            src = fh.read()
        with open(path, "w") as fh:
            fh.write(unwrap(src))
    ```

  - opens files with the platform default encoding — on a Windows cp1252
    locale the em-dash-heavy ruleset would mojibake silently.
- `desktop/chat/project-instructions.md` — byte structure: a 2-line HTML
  comment header, then one blank line, then `unwrap(flint.md)`. Exact header
  (lines 1-2):

  ```
  <!-- Paste everything below the line into the Project instructions field
       (Claude Desktop -> Project -> instructions). Verbatim flint ruleset. -->
  ```

- `desktop/cowork/SKILL.md` — byte structure: a 9-line YAML frontmatter
  block, then one blank line, then `unwrap(flint.md)`. Exact frontmatter
  (lines 1-9):

  ```
  ---
  name: flint
  description: >
    Terse prose and minimal lazy code ruleset. Use in EVERY conversation that
    writes, reviews, or discusses code or technical answers — and whenever the
    user mentions flint, terse output, compressed replies, lazy code, minimal
    diffs, or complains about verbosity. Load at conversation start when in
    doubt: this is a standing style policy, not a task skill.
  ---
  ```

- `test/test.sh:136-139` — the current (weak) guard to be replaced:

  ```sh
  # 14: verbatim-derivado canary — both full-ruleset derivados carry the token
  grep -q 'once per lib per session' desktop/cowork/SKILL.md \
    && grep -q 'once per lib per session' desktop/chat/project-instructions.md
  ck $? "14 verbatim derivado canary"
  ```

  Note `"$PY"` is already defined at `test/test.sh:13` and points at
  `python3` or `python`.
- `desktop/README.md:61-75` — the re-sync checklist; its first two bullets
  are the manual regeneration this plan automates:

  ```
  - [ ] `chat/project-instructions.md` — regenerate (header + verbatim ruleset)
  - [ ] `cowork/SKILL.md` — regenerate (frontmatter + verbatim ruleset)
  ```

- `AGENTS.md:45-49` ("No hand-edits to derivados") ends with "(budget guards
  + canary token enforce part of it)".
- `docs/flint.md` §8 mentions "the drift-canary token `once per lib per
  session` across the verbatim derivados".
- Python floor: 3.6 (`install.py` enforces it for the installer; keep new
  code 3.6-compatible — no `newline=` kwarg on `Path.write_text`, no walrus).
- Repo code conventions: stdlib only, docstring at top, terse comments only
  where a constraint is invisible (see `install.py` as the exemplar).
- Test 12 (`test/test.sh:107-110`) greps the same canary token in the **hook
  output** — that test is about the ruleset/anchor, not derivados; leave it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full test matrix | `sh test/test.sh` | ends `ALL PASS`, exit 0 |
| Parity (after Step 2) | `python3 tools/resync.py --check` | exit 0, no output |
| No-op regeneration proof | `python3 tools/resync.py && git diff --exit-code desktop/` | exit 0 (zero diff) |
| Installer suite (unaffected, sanity) | `python3 test/install_test.py` | prints `PASS` |

## Scope

**In scope** (the only files you should modify/create):
- `tools/unwrap.py` (guard + encoding, no logic change to `unwrap()`)
- `tools/resync.py` (create)
- `test/test.sh` (replace test 14's body; label stays 14)
- `desktop/README.md` (checklist bullets)
- `AGENTS.md` (one parenthetical)
- `docs/flint.md` (§8 one clause)

**Out of scope** (do NOT touch):
- `flint.md` — the parity source. Any edit invalidates this plan's baseline.
- `desktop/chat/project-instructions.md`, `desktop/cowork/SKILL.md` — the
  regeneration must be a byte-for-byte NO-OP; if your script changes them,
  the script is wrong (see STOP conditions).
- `desktop/chat/style.md`, `desktop/chat/profile.md` — hand-derived
  (condensed) derivados, explicitly not verbatim; they stay manual.
- `hooks/flint-style.sh`, installers.

## Git workflow

- Branch: `advisor/003-derivado-parity`.
- Suggested commit: `test: enforce byte parity of verbatim derivados via tools/resync.py`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Make `tools/unwrap.py` importable and encoding-safe

Wrap the trailing loop in a main guard and pin UTF-8. Target for
`tools/unwrap.py:52-56` (the `unwrap()` function body stays untouched):

```python
if __name__ == "__main__":
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(unwrap(src))
```

**Verify**: `python3 -c "from tools.unwrap import unwrap; print(callable(unwrap))"`
run from the repo root → prints `True` (import must not rewrite anything or
require argv). Then `git diff --exit-code desktop/ flint.md` → exit 0.

### Step 2: Create `tools/resync.py`

Regenerates both verbatim derivados from `flint.md`; `--check` verifies
without writing. Byte-exact I/O (read/write bytes, normalize `\r\n` on read)
so a stray CRLF checkout can neither corrupt the files nor fake a pass.
Target content (adjust only if Step 3's no-op verification demands it):

```python
#!/usr/bin/env python3
"""Regenerate the verbatim derivados from flint.md (byte-exact).

    resync.py           rewrite desktop/chat/project-instructions.md
                        and desktop/cowork/SKILL.md
    resync.py --check   exit 1 if either differs from header + unwrap(flint.md)

The headers here are the source of truth for the derivado headers; the body
is always unwrap(flint.md). Hand-edits to either file are overwritten by
design (AGENTS.md: derivados are REGENERATED, never hand-patched).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from unwrap import unwrap  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

HEADERS = {
    ROOT / 'desktop' / 'chat' / 'project-instructions.md': (
        '<!-- Paste everything below the line into the Project instructions field\n'
        '     (Claude Desktop -> Project -> instructions). Verbatim flint ruleset. -->\n'
    ),
    ROOT / 'desktop' / 'cowork' / 'SKILL.md': (
        '---\n'
        'name: flint\n'
        'description: >\n'
        '  Terse prose and minimal lazy code ruleset. Use in EVERY conversation that\n'
        '  writes, reviews, or discusses code or technical answers — and whenever the\n'
        '  user mentions flint, terse output, compressed replies, lazy code, minimal\n'
        '  diffs, or complains about verbosity. Load at conversation start when in\n'
        '  doubt: this is a standing style policy, not a task skill.\n'
        '---\n'
    ),
}


def read_lf(path):
    return path.read_bytes().decode('utf-8').replace('\r\n', '\n')


def main(argv):
    check = '--check' in argv
    body = unwrap(read_lf(ROOT / 'flint.md'))
    stale = []
    for path, header in HEADERS.items():
        want = header + '\n' + body
        if read_lf(path) != want:
            if check:
                stale.append(str(path.relative_to(ROOT)))
            else:
                path.write_bytes(want.encode('utf-8'))
    if stale:
        print('resync needed: {}'.format(', '.join(stale)))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
```

**Verify** (all three, in order):
1. `python3 tools/resync.py --check` → exit 0, no output (parity already
   holds at `22a6af7`; the audit confirmed it by running this exact
   comparison).
2. `python3 tools/resync.py && git diff --exit-code desktop/` → exit 0 —
   regeneration is a byte-for-byte no-op.
3. Mutation probe (proves the check can fail): append a character to
   `desktop/cowork/SKILL.md`, run `python3 tools/resync.py --check` → exit 1
   printing `resync needed: desktop/cowork/SKILL.md`; then
   `python3 tools/resync.py && git diff --exit-code desktop/` → exit 0
   (regeneration repaired it). Confirm `git status` is clean for `desktop/`.

### Step 3: Replace test 14 with the parity check

In `test/test.sh:136-139`, replace the two-grep body:

```sh
# 14: verbatim derivados byte-identical to header + unwrap(flint.md) —
# byte parity subsumes the old canary-token grep (the token is in flint.md,
# and test 12 already asserts it reaches the hook output).
"$PY" tools/resync.py --check; ck $? "14 verbatim derivado parity"
```

**Verify**: `sh test/test.sh` → ends `ALL PASS`, output contains
`ok  14 verbatim derivado parity`.

### Step 4: Shrink the checklist, sync the two doc mentions

- `desktop/README.md` re-sync checklist: replace the first two bullets (the
  manual regenerate steps quoted in "Current state") with a single bullet:
  `- [ ] python3 tools/resync.py — regenerates both verbatim derivados`.
  Keep the two re-derive bullets (style.md, profile.md) and the final
  `sh test/test.sh` bullet unchanged. Also update this file's paragraph about
  regenerating "by copying the ruleset in, then `python3 tools/unwrap.py
  <file>`" (`desktop/README.md:65-67`) — that manual route applies now only
  to the hand-derived artifacts; the verbatim two go through `resync.py`.
- `AGENTS.md:48-49`: change the parenthetical "(budget guards + canary token
  enforce part of it)" to reference the byte-parity test — for example
  "(budget guards + test 14's byte parity enforce the verbatim ones)".
- `docs/flint.md` §8: replace "and the drift-canary token `once per lib per
  session` across the verbatim derivados" with "byte parity of the verbatim
  derivados against `header + unwrap(flint.md)` (`tools/resync.py --check`)";
  the token grep in test 12 (hook output) is unchanged and still worth
  mentioning where §8 lists it.

**Verify**: `sh test/test.sh` → `ALL PASS`;
`grep -n 'resync.py' desktop/README.md AGENTS.md docs/flint.md` → at least
one hit in each file.

## Test plan

- The enforced check IS the new test 14 (`tools/resync.py --check`), running
  on all three CI OSes via the existing matrix.
- The mutation probe in Step 2.3 is the "smallest thing that fails if the
  logic breaks" — perform it once and revert; it needs no permanent fixture.
- Full suite: `sh test/test.sh` → `ALL PASS`; `python3 test/install_test.py`
  → `PASS` (proves the unwrap.py refactor broke no import).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `python3 tools/resync.py --check` exits 0
- [ ] `python3 tools/resync.py; git diff --exit-code desktop/` exits 0 (no-op regeneration)
- [ ] `sh test/test.sh` exits 0, ends `ALL PASS`, prints `ok  14 verbatim derivado parity`
- [ ] `grep -c 'once per lib per session' test/test.sh` prints `2` (test 12's two lines only — `test/test.sh:107-108`; test 14's greps gone)
- [ ] `git diff --stat` touches only: `tools/unwrap.py`, `tools/resync.py`, `test/test.sh`, `desktop/README.md`, `AGENTS.md`, `docs/flint.md`, `plans/README.md`
- [ ] `desktop/chat/project-instructions.md` and `desktop/cowork/SKILL.md` are byte-identical to their state at your starting commit (`git diff --exit-code desktop/chat/project-instructions.md desktop/cowork/SKILL.md`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `python3 tools/resync.py --check` exits 1 on the UNMODIFIED repo — parity
  no longer holds (ruleset or derivados changed since `22a6af7`, or your
  header constants don't match the files byte-for-byte). Do not "fix" the
  derivados to match; report the diff.
- Regeneration (Step 2 verify #2) produces ANY diff in `desktop/` — your
  reconstruction differs by whitespace/newlines; reconcile the header
  constants against the real bytes (`xxd desktop/cowork/SKILL.md | head`),
  do not commit altered derivados.
- `flint.md` shows any diff at any point — nothing in this plan may modify it.
- You want to "improve" `unwrap()`'s logic — out of scope; its behavior
  defines the current bytes.

## Maintenance notes

- Dependency on plan 002 is soft: `read_lf()` normalizes `\r\n`, so the check
  passes even on a CRLF checkout, and writes are LF bytes regardless. With
  002's `.gitattributes` in place the question never arises. If 002 was
  skipped, note that a pre-002 Windows CRLF checkout writes LF files into a
  CRLF-autocrlf working tree — git will show them as modified until
  committed; that is expected.
- Future ruleset edits: the release recipe becomes `edit flint.md → python3
  tools/resync.py → hand-review style.md/profile.md → sh test/test.sh`. If
  someone edits a verbatim derivado by hand, test 14 reds — that is the
  feature.
- If the SKILL.md frontmatter or project-instructions header ever needs to
  change, change it in `tools/resync.py` (the declared source of truth) and
  regenerate.
- Reviewer should scrutinize: header constants in `resync.py` byte-match the
  committed files (em dash `—` in the frontmatter description, the five-space
  indent of the HTML comment's second line); test 14 uses `"$PY"`, not a bare
  `python3` (Windows Git Bash often has only `python`).
