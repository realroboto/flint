# AGENTS.md — traps for anyone (human or LLM) editing this repo

Read this before touching anything. Every trap below is a bug that already
shipped somewhere — upstream, or in this repo's own CI history.

## The two files that ARE the product

- **`flint.md` wording is load-bearing.** Many rules were benchmark-validated
  or bug-fixed upstream. Check the provenance table (`docs/flint.md` §4)
  before changing ANY existing rule — if the rule is in the table, "tightening"
  or paraphrasing it silently discards the fix. Adding a new rule is cheap;
  editing an old one needs a reason stronger than style.
- **`hooks/flint-style.sh` carries 8 invariants** (`docs/flint.md` §5), each a
  fixed upstream bug: always exit 0 · never read stdin · whitelist `$1` ·
  loud `FLINT HOOK ERROR` marker (never silent-empty) · symlink-refuse
  user-writable fallbacks · `head -c 65536` cap + `decode(...,"replace")` ·
  quote every expansion · POSIX sh only. Breaking one reintroduces the bug.
  Full trap catalog: `docs/hook-engineering.md`.

## Hard don'ts

- **No state. Ever.** No levels, flags, config files, slash commands, badges,
  or any sentence in `flint.md` implying an off-switch. Upstream's state
  machinery (~1,141 lines of JS) was the bug factory (`docs/flint.md` §7).
- **The ruleset's real ceiling is 10,000 CHARACTERS, not 64 KB.** Claude Code
  caps hook output strings there and past it swaps the text for a preview +
  file path — the ruleset arrives as a pointer, no error, no loud marker
  (official docs `/en/hooks`; `docs/hook-engineering.md`). Budget the JSON
  envelope, not `flint.md`: 7,458 chars of ruleset emit 7,801, and **8,107 on
  a CRLF checkout** — every escaped `\r\n` costs double, and the Windows
  runner checks out with `autocrlf`. Against test 13a's 9,000 guard a new rule
  spends from **~893 characters**, not 58 KB. Quote the CRLF number; the LF
  one passes locally and reds Windows.
- **No matcher on any hook registration** — the empty matcher is what re-fires
  the ruleset after compact; a matcher kills the style mid-session silently.
- **No raw stdout on SubagentStart** — silently dropped. All three events emit
  the `hookSpecificOutput` JSON shape, uniformly.
- **No bashisms.** macOS `/bin/sh` (bash 3.2), Debian dash, and Git Bash must
  all run the hook and `test/test.sh`: no `[[ ]]`, no arrays, no
  `${var:0:5}`, no GNU-only flags, no `mapfile`.
- **No second hook implementation.** Windows = Git Bash required (ADR 0002);
  `install.ps1` stays a thin validator. A PowerShell port duplicates every
  invariant — the drift between two copies is the bug class flint exists to
  kill.
- **No hand-edits to derivados.** `desktop/chat/project-instructions.md` and
  `desktop/cowork/SKILL.md` are REGENERATED (header + verbatim ruleset);
  the others are re-derived via the checklist in `desktop/README.md`. Ruleset
  changed → run the whole checklist, then `sh test/test.sh` (budget guards +
  canary token enforce part of it).

## CI traps already hit in this repo (don't re-learn them)

- **Native Windows python cannot resolve Git Bash POSIX paths** — a
  `python -c 'open("/tmp/...")'` fixture works on unix runners and throws
  `FileNotFoundError` on Windows. Build test fixtures with shell tools
  (`printf`/`dd`/`tr`), pass content via pipes, not paths.
- **Never put an UNBOUNDED producer in a fixture pipeline** — `yes x | tr -d
  '\n' | head -c 5242880` hung `matrix (macos-latest)` for the full 6h Actions
  timeout on every run from 2026-07-21 to 2026-07-29, while ubuntu, Windows and
  shellcheck stayed green. The log stops after `ok  8 symlink refused`; cleanup
  reports `Terminate orphan process: pid (1237) (tr)`. The runner ignores
  `SIGPIPE` and children inherit it, so `tr` takes `EPIPE` instead of dying and
  spins on `yes` forever. A developer Mac has the default disposition and
  passes in under a second — this is CI-only. Use a bounded producer (`dd
  if=/dev/zero count=N`) so every stage reaches EOF on its own. **A 6h
  cancellation is a skipped test with no `(skipped: reason)` line printed.**
- **`env -i` is not faithful on MSYS** — stripping SYSTEMROOT breaks process
  spawning entirely, so the "interpreter missing" probe false-fails. Gate
  such probes on `uname -s` (`MINGW*|MSYS*|CYGWIN*` → skip with an `ok …
  (skipped)` line).
- **`ln -s` on Windows Git Bash may silently copy instead of symlink** — any
  symlink-behavior test must first verify `[ -L ]` actually holds and skip
  otherwise.
- **Writing "through" a leftover test symlink follows it** — a fixture that
  symlinked `/etc/hosts` must be `rm -f`'d before a later step opens the same
  path for writing.
- **`Path.home()` ignores `$HOME` on Windows** — tests that fake a home set
  both `HOME` and `USERPROFILE`; the real default branch (no
  `CLAUDE_CONFIG_DIR`) has its own test — keep it.

## Consumers — edits here propagate

vmCODE (and possibly other consumers) vendor `hooks/flint-style.sh` and
`flint.md` byte-for-byte at a pinned tag, with a parity check on their side.
- Keep the hook's THREE-geometry ruleset resolution (`/etc/claude-docs` →
  `../flint.md` → `../container-docs/flint.md`) — dropping the last one
  breaks the vmCODE vendored layout.
- Changed hook or ruleset → tag a release; consumers bump the pin. Never
  assume a consumer pulls `main`.
- The UserPromptSubmit anchor line is hardcoded in the hook, separate from
  `flint.md` — core-rule changes need a manual anchor re-sync (and the
  installed-clone model means users get hook changes on `git pull` with no
  re-install).

## Before shipping anything

```sh
sh test/test.sh        # must end ALL PASS — hook contract, installer seam,
                       # budgets, canary
```

CI runs the same matrix on ubuntu/macos/windows + shellcheck. The Windows
runner is the only Windows coverage this project has — never skip a test
there without a printed `(skipped: reason)` line.
