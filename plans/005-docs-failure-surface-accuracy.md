# Plan 005: Correct the troubleshooting docs — a moved clone cannot produce FLINT HOOK ERROR

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 22a6af7..HEAD -- README.md desktop/README.md docs/flint.md hooks/flint-style.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live text before proceeding; on a
> mismatch, treat it as a STOP condition.
> Known drift, already accounted for: merge `5875127` (#7) changed
> `hooks/flint-style.sh` (marker causes — excerpts below already updated) and
> `docs/flint.md` §3/§5/§8; `244ff05` (#8) changed `docs/flint.md` §9;
> `14e9cb4` (#9) changed `docs/flint.md` §8, `desktop/README.md`'s re-sync
> checklist (NOT its Code section), `AGENTS.md`, and added `tools/resync.py`.
> None touched this plan's README sentences or the §2 file map. Plans 001 and
> 003 have BOTH landed — every conditional below resolves to its landed
> branch. Later merges `1f1e84c` (#16) and `c064958` (#18) changed
> `install.py`, `test/install_test.py` and `docs/flint.md` §3's Windows
> paragraph — Step 3b below corrects an overclaim `1f1e84c` introduced there.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW (docs only)
- **Depends on**: none hard; run AFTER plans 001 and 003 if they were selected (their landing changes two details below)
- **Category**: docs
- **Planned at**: commit `22a6af7`, 2026-07-30

## Why this matters

flint's failure design has two distinct loud surfaces, and the docs conflate
them at exactly the place a confused user will read:

1. **`FLINT HOOK ERROR: …`** — emitted by the hook itself, meaning the script
   *ran* but could not deliver: `flint.md` missing at all three resolution
   paths, no `python3`/`python` on PATH, or the encode stage failed (for
   example a python2-only `python`).
2. **Claude Code's own hook-error surface** — when the registered command
   cannot run at all. A moved or deleted clone removes the script; bash exits
   127 ("No such file or directory") and the FLINT marker **cannot** fire,
   because the code that prints it is gone.

Both README.md and desktop/README.md tell users that `FLINT HOOK ERROR` means
"a moved clone" — the one cause that can never produce that marker. A user
whose clone moved will never see the string the docs told them to look for,
and a user who *does* see the marker will go looking for a moved clone instead
of the real causes. Small fix, but it corrects the product's primary
troubleshooting path. A minor docs gap rides along: `docs/flint.md` §2's file
map omits `tools/`.

## Current state

- `hooks/flint-style.sh` — ground truth for what the marker means. The marker
  is emitted by `emit_marker` only in three situations: ruleset not found (or
  empty) at any of `/etc/claude-docs/flint.md`, `../flint.md`,
  `../container-docs/flint.md` (line 59); no python on PATH (line 67);
  encode-stage failure — empty/unreadable read or a python2 `python` (line 80).
  The script must exist and run for any of these to print. Plan 001 landed in
  merge `5875127`; `grep -q 'or empty' hooks/flint-style.sh` succeeds, so every
  "(or empty)" wording variant below applies unconditionally.
- `README.md:46-47`:

  ```
  A session showing `FLINT HOOK ERROR: …` means a moved clone or missing
  Python — the failure is loud by design, never a silent stale ruleset.
  ```

- `desktop/README.md:16-18` (the "Code" section):

  ```
  Run the installer. The Code tab reads the same `settings.json` as the CLI —
  no extra steps. If a session ever shows `FLINT HOOK ERROR`, the clone moved
  or Python left the PATH; re-run `./install.sh`.
  ```

- `docs/flint.md` §2 file map (table around lines 24-31) — rows exist for
  `flint.md`, `hooks/flint-style.sh`, the installers, `desktop/`, tests, and
  `docs/flint.md`; nothing for `tools/`. `tools/unwrap.py` exists at
  `22a6af7`; `tools/resync.py` exists only if plan 003 landed.
- Register/conventions: both READMEs are terse, hard-wrapped ~78 cols,
  backticks around commands and literals. README.md:31-33 already documents
  that re-running the installer re-points a moved clone — keep consistency
  with that ("Idempotent; re-running after moving the clone re-points the
  paths").

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full test matrix (docs cannot break it — sanity) | `sh test/test.sh` | ends `ALL PASS`, exit 0 |
| Marker ground truth | `grep -n 'emit_marker' hooks/flint-style.sh` | the call sites listed above |
| Plans 001/003 landed? | `grep -n 'or empty' hooks/flint-style.sh; ls tools/resync.py 2>/dev/null` | informs wording choices below |

## Scope

**In scope** (the only files you should modify):
- `README.md` (the two-line troubleshooting sentence)
- `desktop/README.md` (the Code-section troubleshooting sentence)
- `docs/flint.md` (§2 file map — one row; §3 Windows paragraph — correct one
  falsified claim, Step 3b)

**Out of scope** (do NOT touch):
- `hooks/flint-style.sh` — docs follow code, never the reverse here.
- `flint.md`, `desktop/chat/*`, `desktop/cowork/*` — ruleset and derivados.
- `AGENTS.md`, `docs/hook-engineering.md`, `docs/ruleset-design.md` — no
  conflation exists there (verified during the audit).

## Git workflow

- Branch: `advisor/005-docs-failure-surfaces`.
- Suggested commit: `docs: FLINT HOOK ERROR means the hook ran — a moved clone surfaces as Claude Code's own hook error`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix README.md

Replace `README.md:46-47` with text carrying this exact meaning (match the
file's terse register and ~78-col wrap; adjust freely for flow, not for
meaning):

```
Failures are loud by design, never a silent stale ruleset — but they have
two surfaces. `FLINT HOOK ERROR: …` in-session means the hook ran and could
not deliver: `flint.md` missing at every known path, or `python3`/`python`
absent or unusable (a python2 `python` fails the encode into the same
marker). A moved or deleted clone shows up as Claude Code's own hook error
instead (the registered path no longer exists) — re-run `./install.sh` from
the clone's new location to re-point it.
```

Plan 001 landed — write "missing (or empty) at every known path" in the
first cause.

**Verify**: `grep -n 'moved clone or missing' README.md` → no match;
`grep -n 'hook error' README.md` → the new sentence present.

### Step 2: Fix desktop/README.md

Replace the last sentence of the Code section (`desktop/README.md:16-18`)
with the same distinction, compressed to the section's register:

```
Run the installer. The Code tab reads the same `settings.json` as the CLI —
no extra steps. `FLINT HOOK ERROR` in a session means the hook ran but could
not deliver (ruleset missing, or Python absent/unusable). A moved clone surfaces as
Claude Code's own hook error instead — re-run `./install.sh` from the new
location.
```

(Same: write "missing/empty" — plan 001 landed.)

**Verify**: `grep -n 'the clone moved' desktop/README.md` → no match.

### Step 3: Add `tools/` to the docs/flint.md file map

In the §2 table, add one row after the `desktop/` row:

Plan 003 landed — use:
`| `tools/unwrap.py` / `tools/resync.py` | Derivado tooling: unwrap paragraph hard-wraps; regenerate + verify the verbatim derivados |`

**Verify**: `grep -n 'tools/unwrap.py' docs/flint.md` → one match in §2.

### Step 3b: Correct the falsified Git Bash claim in §3

Merge `1f1e84c` added to the §3 Windows paragraph: "and writes it with forward
slashes because Git Bash treats backslashes inside the double quotes as
escape-prone (a native `C:\` path executes at rc 1)". The rc 1 attribution was
falsified by #18 — the failure was the System32 WSL bash stub, not Git Bash;
Git Bash was never shown to mishandle the backslash form. Replace that clause
with the honest rationale, e.g.: "and writes it with forward slashes — the one
form every parser on the Windows path (Git Bash, native Python, Claude Code)
reads unambiguously." Keep the spaces-in-path sentence around it intact.

**Verify**: `grep -c 'escape-prone' docs/flint.md` → `0`; `grep -n 'forward' docs/flint.md` → the corrected sentence.

### Step 4: Sweep for residual conflation

**Verify**: `grep -rn 'moved clone\|clone moved' README.md desktop/ docs/` →
every remaining hit describes the Claude Code hook-error surface or the
installer re-point behavior, none attributes a moved clone to
`FLINT HOOK ERROR`. Then `sh test/test.sh` → `ALL PASS` (nothing executable
was touched — this is a tripwire, not a real risk).

## Test plan

Docs-only; no new tests. The greps in Steps 1-4 are the machine checks, plus
the full suite as a tripwire.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -rn 'FLINT HOOK ERROR' README.md desktop/README.md` — every hit's
      surrounding sentence attributes the marker only to ruleset/python
      delivery causes, never to a moved clone
- [ ] `grep -n 'moved clone or missing' README.md` → no match
- [ ] `grep -n 'tools/unwrap.py' docs/flint.md` → one match
- [ ] `sh test/test.sh` exits 0, ends `ALL PASS`
- [ ] `git status --porcelain` shows changes only in `README.md`,
      `desktop/README.md`, `docs/flint.md`, `plans/README.md`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" are not found at the cited lines (drift).
- You find evidence the premise is wrong — that is, a code path by which a
  fully moved clone still emits `FLINT HOOK ERROR` (for example, a second
  registered copy of the hook script outside the clone). Verify against
  `hooks/flint-style.sh` and `install.py` before writing; report if found.
- Fixing the wording seems to require changing hook behavior — out of scope.

## Maintenance notes

- If the hook's marker causes ever change again (as plan 001 does), these
  two README sentences and `docs/flint.md` §3 item 4 are the places that
  must track it — consider adding that to any future hook-change checklist.
- Reviewer: read the final README sentence cold and ask "if my session shows
  the marker, do I now check the right two things?" (ruleset paths, python
  on PATH) and "if my clone moved, do I know why I *don't* see the marker?".
