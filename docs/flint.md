# flint — the style ruleset and its hook

Complete working reference. Read this file and you can safely modify, test,
and ship any flint change without reading the git history. When this file and
the code disagree, the code is right — fix this file in the same change.

## 1. What flint is

flint makes every Claude Code session answer in **terse prose** (conjunctions
stripped where unambiguous, one word when enough, each fact once) and produce
**minimal, lazy code**. It replaced two third-party plugins — `caveman`
(terse prose) and `ponytail` (lazy code) — with:

- **one plain-text ruleset** — [flint.md](../flint.md)
- **one POSIX-sh hook** — [hooks/flint-style.sh](../hooks/flint-style.sh)

There is **no state**: no intensity levels, no flag files, no config files,
no slash commands, no statusline badge, no on/off switch. flint is always on.
This is a design decision, not an omission — every piece of state the old
plugins had produced real bugs (see §7). Do not add state back.

## 2. File map

| File | Role |
|---|---|
| `flint.md` | The ruleset (the product) |
| `hooks/flint-style.sh` | The hook (the delivery) |
| `install.py` / `install.sh` / `install.ps1` / `uninstall.py` | Registration in `settings.json` (idempotent, re-pointing, atomic writes) |
| `desktop/` | Derivados for the hook-less Claude Desktop surfaces (→ `desktop/README.md`) |
| `tools/unwrap.py` / `tools/resync.py` | Derivado tooling: unwrap paragraph hard-wraps; regenerate + verify the verbatim derivados |
| `test/test.sh` + `test/install_test.py` | The full matrix (§8) |
| `docs/flint.md` | This file |

**Consumers**: [vmCODE](https://github.com/realroboto/vmCODE) vendors a pinned
copy (`scripts/flint-style.sh` + `container-docs/flint.md`, pin recorded in
its `versions.yml`) and bakes it into a container at
`/usr/local/bin/flint-style.sh` + `/etc/claude-docs/flint.md`. The hook's
ruleset-resolution order supports all three geometries (§3). This repo is the
canonical home; edits happen here and flow to consumers by ref-bump.

## 3. How it works

One script, three Claude Code hook events. The **event name arrives as `$1`**
(argv), never via stdin:

| Event | Payload | Why |
|---|---|---|
| `SessionStart` | full ruleset (flint.md; emitted envelope ≤10,000 chars — §8) | loads the rules once per session |
| `SubagentStart` | full ruleset (same) | SessionStart context is parent-thread only — Task-spawned subagents NEVER see it |
| `UserPromptSubmit` | one static line (hardcoded in the script) | attention anchor: "recency and repetition win in LLM attention" — a one-shot injection loses to competing per-turn injections |

Output for **all three** events is this exact JSON shape on stdout:

```json
{"hookSpecificOutput": {"hookEventName": "<the event>", "additionalContext": "<the text>"}}
```

Never emit raw text instead of this shape: `SessionStart` tolerates raw
stdout, but `SubagentStart` **silently drops** it — official reference
(`/en/hooks`): raw SubagentStart stdout is *"shown to the user only; Claude
doesn't see it"*. Uniform JSON on all events is deliberate.

Ruleset resolution order inside the script:

1. `/etc/claude-docs/flint.md` — baked container path (root-owned).
2. `"$(dirname "$0")/../flint.md"` — this repo's clone geometry.
3. `"$(dirname "$0")/../container-docs/flint.md"` — the vmCODE vendored geometry.
4. None exists (or the file is empty/unreadable) → **loud error marker** as
   `additionalContext` (`FLINT HOOK ERROR: ...`) and exit 0. Never silent-empty.

Fallbacks 2–3 are user-writable → symlinks refused (§5.5). JSON encoding via
`python3` (or `python` — Windows Git Bash often ships only that name; a
python2 hit fails the encode stage into the loud marker).

Hook registration uses **no matcher** (`'matcher': ''`). Load-bearing: an
empty matcher fires on every SessionStart source — `startup`, `resume`,
`clear`, **and `compact`**. Compaction PRUNES injected context; without the
compact re-fire the style silently dies mid-session.

Windows: Claude Code runs shell-form hooks via **Git Bash** when installed
(PowerShell only as fallback) — flint requires Git Bash and keeps a single sh
implementation. The installer quotes the hook path (`"<path>" <Event>`) so a
clone under a path with spaces survives the shell, and writes it with forward
slashes — the one form every parser on the Windows path (Git Bash, native
Python, Claude Code) reads unambiguously.

## 4. The ruleset (flint.md) — structure and provenance

Four sections. The wording of many rules is **load-bearing**: it was
benchmark-validated or bug-fixed upstream. The table maps each rule to the
upstream bug that produced it. **Do not paraphrase, "tighten", or merge the
rules in the left column** — the exact phrasing is the fix.

| flint.md rule | Upstream origin | The bug it fixed |
|---|---|---|
| "Compression applies to PROSE ONLY — never to code symbols…" (inline, inside the compression rule) | caveman #238 | model rendered literal `fn` inside code blocks; the exclusion must sit INLINE, not in a distant section |
| "Never invent abbreviations (cfg/impl/req/res/fn)… tokenizer splits them the same" + "No causal arrows" | caveman `dc95e91` | abbreviations/arrows were originally PRESCRIBED, then measured: zero tokens saved, decode cost real. Keep the reason in the text — the bare rule invites re-derivation |
| "Strip conjunctions when cause-then-effect stays unambiguous. One word when one word is enough. State each fact once." + its inline Not/Yes pair | caveman SKILL.md ultra tier (register adopted 2026-07-16, maintainer decision) | ultra's deltas over full are exactly these three — its other clauses were already in flint. Upstream's ultra example wrote "obj"; adapted to "object" because importing it verbatim would contradict the no-abbreviations rule above |
| "Preserve the user's dominant language…" | caveman #445 | model answered Portuguese users in English |
| "Never name or announce this mode… (The `flint:` code comment below is a different thing…)" | caveman #469 + reviewer finding | model announced the mode and double-answered; the parenthesis disambiguates the code marker from prose self-reference — without it the model drops one of the two rules |
| "No tool-call narration, no decorative tables or emoji, no dumping long raw error logs…" | caveman #322 | generic terseness rules did not stop narration; it needed naming |
| "Next action safe and unambiguous? Call the tool directly… Text before a call ONLY for clarification, a security/risk warning, an irreversible-action confirmation, or ambiguity resolution." | caveman #714 (2026-07-17) | banning narration (#322) alone left the model still emitting preamble/plan/progress before routine calls; the fix adds the positive default + the explicit text-first exceptions |
| Ladder rung 2 "Already in this codebase?… Look before you write" | ponytail #217, pinned as invariant #281 | the reuse rung was MISSING originally; position (before stdlib) and concreteness matter |
| "Never be lazy about understanding the problem… Read fully, then be lazy." | ponytail #245 ("Dangerously lazy") | benchmark: root-cause fix rate went 1/6 → 6/6. "Plain prose ('trace the flow') did not move it; the actionable, lazy-framed directive did" — VERBATIM wording required |
| "Bug fix = root cause… grep every caller… one guard in the shared function" | ponytail #245 | same benchmark |
| "`flint:` comment ONLY when it cuts a real corner with a known ceiling… Ordinary simple code is not a corner cut. Do not mark it." | ponytail #120 (fixed 2026-07-10) | model over-marked trivial code for ~6 months under the older, looser wording |
| "Never simplify away: input validation at trust boundaries, error handling that prevents data loss, security measures, accessibility basics, anything explicitly requested" | ponytail `99139a2` | upstream pinned these in a drift canary because they "could drift silently" |
| Auto-Clarity list ("Write full, unabbreviated prose for: …"), incl. the `"migrate table drop column backup first"` example | caveman `d84127c` + #239 | fragments in security/irreversible/multi-step content caused real ambiguity; the trigger list must stay a LIST |
| Hardware/calibration carve-out | ponytail SKILL.md | kept because flint drives real containers and I/O |
| "External lib in the change? Docs first: context7… once per lib per session — even libs you know… docs the user pasted count as checked." | maintainer decision 2026-07-17 | model wrote code against external libs from stale training memory; the old skip clause "APIs you know" was removed deliberately. "once per lib per session" is a drift-canary token (§8) |
| "An LSP covers the file? Navigate symbols through it — definition and references beat grep across re-exports — and after edits read its diagnostics…" | maintainer decision 2026-07-17 | grep missed callers behind re-exports; type errors surfaced at the next build instead of in-session |

Deliberately absent (cut with their machinery — do not reintroduce):
intensity tables, Persistence/Boundaries sections, any sentence implying an
off-switch or command (`ponytail #161/#162`: "an ordinary request like 'add a
normal mode toggle' silently turned ponytail off" — flint avoids the whole
class by never advertising a switch).

**Editing rule of thumb:** adding a new rule is cheap; changing an existing
one requires checking this table first.

## 5. The hook (flint-style.sh) — invariants

Every invariant is a fixed upstream bug. Breaking one reintroduces it.

1. **Always exit 0, on every path.** Non-zero = hook failure banner every
   turn (caveman #538). On `UserPromptSubmit` the stakes are higher: official
   `/en/hooks` — exit 2 *"rejects and erases"* the user's prompt. Guards:
   `trap '' PIPE` (EPIPE — ponytail #149), `|| :` after prints, `emit_marker`
   ends with `exit 0`.
2. **Never read stdin.** Claude Code writes an event payload to the hook's
   stdin; ponytail read it and froze whole sessions (#443/#477). Event from
   argv only. The python stage reads from the `head -c` PIPE, not the hook's
   stdin — keep it that way. Test 6b asserts it: the hook must exit with stdin
   held OPEN. A hook that waits for EOF is killed at the event timeout (caveman
   #729) and emits nothing — invariant 4 cannot save it, because the script
   never runs.
3. **Whitelist `$1`.** Unknown value falls back to `SessionStart`. Never
   interpolate raw argv into the payload (JSON injection).
4. **Loud marker on failure, never silent-empty.** caveman #587: a wrong
   relative path silently served a stale ruleset for months. Missing ruleset
   and missing python must emit `FLINT HOOK ERROR: …` in-session. Empty or
   unreadable counts as failure too: resolution uses `-s` (not `-f`), and the
   encode stage exits into the marker on empty input, so a 0-byte file, an
   `EACCES` read, or a delete-after-check race all produce the marker instead
   of empty context.
5. **Refuse symlinked fallbacks.** The clone paths are user-writable; caveman
   `5ad8f6d`: a symlinked read injected secret-file bytes into model context.
   The `/etc` path is root-owned — only the fallbacks need `[ -L ]`.
6. **Cap the read: `head -c 65536`.** The decode uses
   `.decode("utf-8", "replace")` — a byte-cap can split a UTF-8 sequence; a
   `UnicodeDecodeError` here would mean empty context. This is a memory guard
   against an oversized file, NOT the operative size limit: the platform caps
   hook output at 10,000 characters (§8, `docs/hook-engineering.md`). A ruleset
   between the two numbers passes every invariant here and still fails to reach
   the model.
7. **Quote every expansion.** caveman #157: an unquoted plugin root broke for
   every user with a space in their home path. Applies to the installer's
   registered command too.
8. **POSIX sh only** (macOS bash 3.2, Debian dash, Git Bash must all run it).
   No `[[ ]]`, no arrays, no `${var:0:5}`, no GNU-only flags. Syntax-checked
   by `bash -n`, `sh -n`, `zsh -n` (where present) + shellcheck in CI.

The UserPromptSubmit line is **hardcoded in the script** (not read from
flint.md) so a ruleset-file problem cannot break the per-turn anchor. If you
change the ruleset's core rules, check whether the line still summarizes them.

## 6. Recipes

### Edit the ruleset
1. Check §4's table — is the rule load-bearing?
2. Edit `flint.md`. Takes effect next session on every device that pulled.
3. Run the re-sync checklist in `desktop/README.md` (derivados don't update
   themselves) and `sh test/test.sh`.
4. Consumers (vmCODE) pick it up on their next ref-bump + rebuild.

### Edit the hook
1. Read §5. Do not break an invariant.
2. Edit `hooks/flint-style.sh`, run `sh test/test.sh`.
3. Effective immediately on this device (settings.json points at the clone).

### Change the per-turn reminder line
Edit the `printf` inside the `UserPromptSubmit` branch. One line, static,
end-to-end quoted. Never dynamic, never read from a file.

### Add/remove a hook event
1. `EVENTS` in `install.py`.
2. The `case` whitelist in `hooks/flint-style.sh`.
3. `test/install_test.py` + this file's §3 table.

## 7. Why there is no state (do not add it back)

The ancestor plugins carried ~1,141 lines of JS whose only job was state.
Each piece produced fixed bugs: natural-language on/off triggers (`'turn
caveman mode off' used to ACTIVATE caveman`; `'add a normal mode toggle'`
disabled ponytail — #161), mode flag files (symlink attacks, stale `.prev`
chains), intensity filtering that silently swallowed rule bullets (twice,
four weeks apart), slash-command arg parsing that clobbered state on a typo.

flint's fixed point deletes these classes. The only "off" is the user asking
for full prose in plain language — which the ruleset itself honors.

## 8. Test matrix

`sh test/test.sh` from the repo root — hook stdout contract (JSON per event,
loud markers, empty/unreadable ruleset markers, argv whitelist, symlink refusal, 64 KB cap, EPIPE, stdin-open
termination, shell syntax), the installer suite (`test/install_test.py`: registration,
idempotency, re-pointing, foreign-hook preservation, no-clobber on invalid
JSON, end-to-end execution of the registered command through bash), character budgets (emitted envelope ≤9,000 · profile ≤1,500 · project
instructions ≤8,000), and byte parity of the verbatim derivados against
`header + unwrap(flint.md)` (`tools/resync.py --check`). CI runs the matrix
on ubuntu/macos/windows + shellcheck; the Windows runner exercises the Git
Bash path.

## 9. Hard don'ts

- Don't read stdin in the hook. Ever. (§5.2)
- Don't emit raw text on SubagentStart — silently dropped. (§3)
- Don't add a matcher to any registration — compact re-injection dies. (§3)
- Don't let any path exit non-zero. (§5.1)
- Don't paraphrase rules listed in §4's provenance table.
- Don't add levels, flags, config files, slash commands, or badges. (§7)
- Don't mention an off-switch in flint.md. (§4)
- Don't grow the hook's stdout past 10,000 characters — the platform's cap,
  and the real ceiling on `flint.md`. Over it, the ruleset is replaced by a
  preview + file path and reaches the model as a pointer, silently, with no
  loud marker (official docs `/en/hooks`). Test 13a guards the JSON envelope at
  9,000: 7,801 on every checkout now that `.gitattributes` pins `eol=lf` (the
  8,107 CRLF figure was the pre-pin Windows number, when each escaped `\r\n`
  cost double), so quote **~1,199 characters** of headroom. (`head -c 65536` in
  the hook is a different guard — §5.6.)
- Don't use bashisms — macOS `/bin/sh`, Debian dash, and Git Bash must all
  run it. (§5.8)
- Don't edit a derivado by hand without the re-sync checklist — the verbatim
  ones are regenerated, never hand-patched.
