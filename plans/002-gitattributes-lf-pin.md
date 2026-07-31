# Plan 002: Pin LF line endings with .gitattributes, reclaim the CRLF envelope tax

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 22a6af7..HEAD -- .gitattributes AGENTS.md docs/flint.md docs/hook-engineering.md test/test.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.
> Known drift, already accounted for: merge `5875127` (ticket #7) touched
> `docs/flint.md` (§3/§5/§8 text) and `test/test.sh` (new 9b/9c block) — the
> line numbers below are post-#7; the quoted passages are unchanged.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (docs churn) / MED only in that Windows CI must confirm the checkout behavior
- **Depends on**: none
- **Category**: dx / tech-debt
- **Planned at**: commit `22a6af7`, 2026-07-30

## Why this matters

flint's hook injects `flint.md` into Claude Code sessions as a JSON envelope.
Claude Code caps hook output at 10,000 characters; past the cap the ruleset is
silently replaced by a preview + file path. The repo guards the envelope at
9,000 chars (test 13a). On an LF checkout the envelope measures **7,801**
characters; on a CRLF checkout (the Windows CI runner, and typical Git for
Windows user clones with `autocrlf=true`) every newline JSON-escapes to `\r\n`
and the envelope measures **8,107** — 306 characters of the budget spent on
carriage returns. Both numbers were re-measured against `22a6af7` during the
audit and match the repo's documented values.

Consequences today: (1) ~34% of the remaining rule-writing budget
(893 chars CRLF vs 1,199 LF) is burned by line endings; (2) contributors hit a
documented trap — a new rule passes 13a locally on LF and fails only on the
Windows runner (AGENTS.md: "the LF one passes locally and reds Windows").

There is no `.gitattributes`. Pinning `eol=lf` makes every checkout —
including the Windows runner and fresh Windows user clones — LF: the envelope
is 7,801 everywhere, local results predict CI, and the CRLF double-cost class
dies. All 26 tracked files are already stored LF in the index (verified:
`git ls-files --eol` reports `i/lf` for every file), so this is a pure
checkout-side change with zero content churn.

## Current state

- No `.gitattributes` exists (`ls -a` at repo root: absent).
- `git ls-files --eol` → every tracked file `i/lf w/lf`.
- Three places quote the CRLF numbers and the trap; all must be updated
  consistently:

`AGENTS.md:25-33` (the "10,000 CHARACTERS" bullet) currently ends:

```
  a CRLF checkout** — every escaped `\r\n` costs double, and the Windows
  runner checks out with `autocrlf`. Against test 13a's 9,000 guard a new rule
  spends from **~893 characters**, not 58 KB. Quote the CRLF number; the LF
  one passes locally and reds Windows.
```

`docs/flint.md` §9 (Hard don'ts, the "Don't grow the hook's stdout past
10,000 characters" bullet, lines ~217-224) currently says:

```
  9,000: 7,801 today on LF, 8,107 on a CRLF checkout, so quote **~893
  characters** of headroom — the CRLF number binds, because the Windows runner
  checks out with `autocrlf`.
```

`test/test.sh:112-127` — test 13a's comment block ends with:

```
# ... binary read on stdin so a CRLF checkout is counted as the Windows runner
# will emit it.
```

`docs/hook-engineering.md:31-33` (generic guidance for hook authors) says:

```
  Budget the whole JSON envelope, not the ruleset file, and measure a CRLF
  checkout: escaped `\r\n` costs double on Windows runners.
```

- Repo conventions: Markdown docs are hard-wrapped ~78 cols; keep that. The
  AGENTS.md entry is a **trap catalog** — traps get marked neutralized, never
  deleted (the file's premise: "Every trap below is a bug that already
  shipped").

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full test matrix | `sh test/test.sh` | ends `ALL PASS`, exit 0 |
| EOL state | `git ls-files --eol \| grep -v 'i/lf'` | empty output (binaries aside; repo has none) |
| Renormalize probe | `git add --renormalize . && git status --porcelain` | only `.gitattributes` (and files this plan edits) listed |
| Envelope (LF) | `python3 -c 'import json,sys;t=open("flint.md","rb").read().decode("utf-8","replace");print(max(len(json.dumps({"hookSpecificOutput":{"hookEventName":e,"additionalContext":t}}))+1 for e in ("SessionStart","SubagentStart")))'` | `7801` |

## Scope

**In scope** (the only files you should modify):
- `.gitattributes` (create)
- `AGENTS.md` (one bullet)
- `docs/flint.md` (one bullet in §9)
- `docs/hook-engineering.md` (one sentence)
- `test/test.sh` (comment text of 13a only — no executable change)

**Out of scope** (do NOT touch):
- `flint.md` — content unchanged; the point is representation, not text.
- `hooks/flint-style.sh` — the hook already does a binary-safe read; nothing to change.
- The 13a threshold (`-le 9000`) — keep the guard where it is; headroom simply grows.
- `desktop/` derivados, installers.

## Git workflow

- Branch: `advisor/002-gitattributes-lf-pin`.
- Commit style: conventional-commit-ish per `git log`; suggested:
  `ci: pin LF checkouts via .gitattributes — retire the CRLF envelope tax`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create `.gitattributes`

Repo root, exact content:

```
* text=auto eol=lf
```

(`text=auto` lets git keep detecting binaries; `eol=lf` forces LF on checkout
for everything it treats as text. The repo tracks only text files today.)

**Verify**: `git add --renormalize . && git status --porcelain` → the only
entry is `A  .gitattributes` (nothing renormalized — the index was already
LF). Then `git ls-files --eol .gitattributes flint.md hooks/flint-style.sh`
→ each line shows `i/lf` (the `attr:` column now shows `text=auto eol=lf`).

### Step 2: Update AGENTS.md — mark the trap neutralized, fix the budget number

Rewrite the tail of the 10k bullet (`AGENTS.md:25-33`). Keep the trap's
history; state the new invariant. Target sense (match the file's terse
register and ~78-col wrap):

- Envelope on LF: 7,458 chars of ruleset emit 7,801.
- `.gitattributes` pins `eol=lf` on every checkout, including the Windows
  runner — the CRLF double-cost (8,107; each escaped `\r\n` costs double) is
  dead **as long as the pin stays**; deleting `.gitattributes` reopens ~306
  chars of Windows-only spend that no local LF run will catch.
- Against test 13a's 9,000 guard a new rule now spends from **~1,199
  characters**.

Remove the now-false instruction "Quote the CRLF number; the LF one passes
locally and reds Windows."

**Verify**: `grep -n '1,199' AGENTS.md` → one match; `grep -n '~893' AGENTS.md`
→ no match.

### Step 3: Update docs/flint.md §9 in the same sense

Same substitution in the "Don't grow the hook's stdout past 10,000
characters" bullet: 7,801 on every checkout now that `.gitattributes` pins
LF; ~1,199 chars of headroom against the 9,000 guard; keep the sentence that
`head -c 65536` is a different guard. Mention that the 8,107 CRLF figure was
the pre-pin Windows number (historical context, one clause — this file is the
complete reference).

**Verify**: `grep -n '1,199' docs/flint.md` → one match; `grep -n '~893' docs/flint.md` → no match.

### Step 4: Update the 13a comment and hook-engineering.md

- `test/test.sh` 13a comment block: replace the final sentence ("binary read
  on stdin so a CRLF checkout is counted as the Windows runner will emit it")
  with one saying the binary read stays as belt-and-braces, but
  `.gitattributes` pins LF so no checkout should be CRLF anymore. Do not
  change any executable line of 13a.
- `docs/hook-engineering.md:31-33`: after "measure a CRLF checkout: escaped
  `\r\n` costs double on Windows runners", append " — or pin `eol=lf` in
  `.gitattributes` and delete the class" (this file is generic guidance for
  other hook authors; both options belong there).

**Verify**: `sh test/test.sh` → ends `ALL PASS` (13a still passes at 7,801 ≤ 9,000).

## Test plan

No new tests: 13a already measures whatever the checkout produces, which is
the property being pinned. The real assertion happens on the Windows CI
runner after merge — 13a there should now measure 7,801, not 8,107. That is a
reviewer/CI observation, not a local command; note it in your completion
report.

- Local: `sh test/test.sh` → `ALL PASS`.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.gitattributes` exists with exactly `* text=auto eol=lf`
- [ ] `git add --renormalize .` stages nothing beyond this plan's files
- [ ] `sh test/test.sh` exits 0, ends `ALL PASS`
- [ ] `grep -rn '~893' AGENTS.md docs/ test/` → no matches
- [ ] `grep -rln '1,199' AGENTS.md docs/flint.md` → both files listed
- [ ] `git status --porcelain` shows changes only in the in-scope files plus `plans/README.md`
- [ ] `plans/README.md` status row updated (note "Windows CI observation pending" if you cannot see CI)

## STOP conditions

Stop and report back (do not improvise) if:

- `git add --renormalize .` stages any tracked file you did not edit — the
  index was not all-LF after all; the "pure checkout-side change" premise is
  false.
- `git ls-files --eol` shows any `i/crlf` or `i/mixed` entry before your change.
- The quoted AGENTS.md / docs/flint.md passages are not found where cited
  (doc drift since `22a6af7`).
- You are tempted to change the 13a threshold or its measurement command —
  out of scope; report why instead.

## Maintenance notes

- Reviewer: check the first Windows CI run after merge — the job must stay
  green and (if inspecting) 13a's measured envelope drops to 7,801. If the
  Windows job reds on 13a after this change, the runner ignored the
  attribute; that finding goes back to the advisor, not into a workaround.
- Existing Windows clones keep their CRLF working copy of `flint.md` until
  the file next changes (git renormalizes lazily); their envelope stays 8,107,
  which still passes the 9,000 guard. No action needed.
- Consumers (vmCODE) vendor blob content, which was LF before and after —
  no consumer impact.
- If anyone ever adds a binary file (image, zip) to the repo, `text=auto`
  protects it; do not switch the attribute to a bare `* text eol=lf`.
- Plan 003's byte-parity check reads files raw; it assumes LF checkouts —
  this plan is why that assumption holds on Windows CI. Keep the pin.
