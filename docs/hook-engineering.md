# Claude Code hook engineering — trap catalog

How to build context-injection hooks that don't ship the bugs others already
fixed. Source: forensic audits (2026-07) of the full commit histories of
[caveman](https://github.com/JuliusBrussee/caveman) (252 commits) and
[ponytail](https://github.com/DietrichGebert/ponytail) (206 commits) — every
rule below maps to a bug somebody already shipped and fixed. Reference
implementation: [`hooks/flint-style.sh`](../hooks/flint-style.sh); the
flint-specific invariant list is [`docs/flint.md`](flint.md) §5. Companion:
[ruleset-design.md](ruleset-design.md) for the TEXT a hook injects.

## Event semantics (the non-obvious parts)

- **SessionStart context is parent-thread only.** Task-spawned subagents NEVER
  see it. If subagents need the instruction, register `SubagentStart` too
  (ponytail #252). Conversely: main-session-only content should deliberately
  NOT have SubagentStart.
- **SubagentStart silently drops raw stdout.** It requires the
  `{"hookSpecificOutput":{"hookEventName":...,"additionalContext":...}}` JSON
  form — wrong shape = context lost, no error. Official docs: raw
  SubagentStart stdout is "shown to the user only; Claude doesn't see it".
  Use the JSON form uniformly on ALL events; don't special-case.
- **Hook output over 10,000 characters is replaced by a preview + file path.**
  Official docs (`/en/hooks`): "Hook output strings, including
  `additionalContext`, `systemMessage`, and plain stdout, are capped at 10,000
  characters. Output that exceeds this limit is saved to a file and replaced
  with a preview and file path, the same way large tool results are handled."
  Not truncation and not an error: an oversize ruleset reaches the model as a
  pointer, silently, and no loud-marker invariant fires — those cover a MISSING
  file, not one the platform swallows. Budget the whole JSON envelope, not the
  ruleset file, and measure a CRLF checkout: escaped `\r\n` costs double on
  Windows runners — or pin `eol=lf` in `.gitattributes` and delete the class.
  A script-internal read cap (invariant 7 below; `flint.md`
  §5.6) is a different guard and much looser; don't mistake one for the other.
- **Compaction prunes injected context.** A SessionStart hook must re-fire on
  `compact` or the injected rules silently die mid-session (caveman
  `80a317e`). Empty matcher `''` = catch-all (startup|resume|clear|compact).
  Neither upstream ever tuned a matcher in 450+ commits; omit it.
- **One-shot injection loses attention to per-turn injections.** "Recency and
  repetition win in LLM attention — a one-shot injection loses to per-turn
  reinforcement" (caveman `3ed7b73`). Pattern: full ruleset at
  SessionStart/SubagentStart + ONE short static line at UserPromptSubmit (an
  attention anchor, not the ruleset).
- **Full rules WITH examples anchor better than summaries** (caveman
  `80a317e`: "The old 2-sentence summary was too weak — models drifted back").
- **Hooks run under non-interactive `/bin/sh`** — PATH is narrower than the
  login shell (ponytail #57-class: `node: command not found` on nvm/Nix
  setups). Guard every interpreter with `command -v X || <loud marker>`.
- **UserPromptSubmit exit 2 rejects and erases the user's prompt** (official
  docs) — a stronger reason than the failure banner to exit 0 on every path.

## Script invariants (each one is a shipped bug)

1. **Always exit 0, every path.** Non-zero = hook failure banner every turn
   (caveman #538). `trap '' PIPE` + `|| :` after prints (EPIPE on closed
   stdout crashed ponytail, #149/#152).
2. **Never read stdin.** Claude Code writes the event payload to hook stdin;
   ponytail read it and `stdin 'end' never fires` froze whole sessions
   (#443/#477). Take parameters from argv — one script, N events, event name
   in `$1`, with a default for legacy registrations. Waiting on stdin EOF is
   the same bug in slow motion: caveman #729 measured 48 of 2,076
   `UserPromptSubmit` runs killed at the timeout — 2.3%, against 0.4% for the
   sibling hook that reads no stdin — because the work sat in stdin's `end`
   event. **A hook killed at the timeout emits no loud marker**: the script
   never runs, so invariant 3 cannot fire. Assert termination with stdin held
   OPEN, not just the EPIPE case; they are opposite failures. If you must read
   a payload, act on the first complete parse and release stdin — do not exit
   outright, or stdout truncates.
3. **Loud marker on failure, never silent-empty.** caveman #587: a wrong
   relative path silently served a stale ruleset for months; #592: a missing
   binary coerced to success. On missing file/interpreter emit
   `<NAME> HOOK ERROR: ...` as additionalContext so the failure is visible
   in-session. When the file is baked into an image, a build-time assert
   (`[ -s file ]`) beats a runtime fallback.
4. **Whitelist `$1`** before interpolating into hand-built JSON (injection).
5. **Quote every expansion.** caveman #157: an unquoted plugin root broke for
   any user with a space in their home path
   (`Cannot find module '/Users/Tyler'`).
6. **Symlink-refuse user-writable read paths.** caveman `5ad8f6d`: a symlinked
   flag file injected secret-file bytes into model context. Root-owned baked
   paths don't need the check; user-writable fallbacks do (`[ -L ]`).
7. **Cap reads** (`head -c 65536`) — an oversized file must not eat the
   context window — and decode with `errors="replace"`: a byte-cap can split
   a UTF-8 sequence, and a UnicodeDecodeError would mean empty context.
8. **POSIX sh over node/deps.** Node hooks inherited ESM/CJS breakage
   (`"type": "module"` in any ancestor package.json → `require is not
   defined`, caveman `b50aa6d`) and Windows/exec issues. A short sh script
   with python-for-JSON (guarded) has none of these — and Git Bash runs it on
   Windows unchanged.
9. **No hand-synced copies.** Point registrations at the source file (this
   repo's installer registers the clone's absolute path). Copied files go
   stale in silence — same class as marketplace clones drifting (an installed
   plugin observed 35 commits behind upstream; marketplace clones never
   auto-update).
10. **Old-artifact guard when a script gains argv behavior.** Re-registering
    new hook args against an OLD deployed script means the script ignores
    argv and does the wrong thing. Gate the new registration on the deployed
    script actually containing the new behavior.

## Plugin vs hook vs skill — decision rule

- **Plugin/marketplace**: only for distributing to third parties with
  versioned installs. For your own always-on use it is overhead: clone drift,
  install bootstrap, per-plugin state machinery. The caveman+ponytail pair
  carried ~1,141 lines of JS whose ONLY job was state (levels, flags,
  commands, badges) — and that state was the bug factory
  (→ [ruleset-design.md](ruleset-design.md)).
- **Hook + plain text file**: the right shape for always-on instruction
  injection. A fixed point (no levels, no state) deletes whole bug classes:
  natural-language trigger misfires (caveman #598: "'turn caveman mode off'
  used to ACTIVATE caveman"), mode filters swallowing rule bullets (ponytail
  #571, twice), arg-parsing state clobbering (#314), flag-file attack surface.
- **Skill**: model-invoked, non-deterministic loading — wrong for always-on
  behavior; right for on-demand procedures.

## Process learning

Before writing OR replacing a plugin/hook: **clone the upstream repos with
full history and mine `git log` for fixed bugs.** Two parallel research
agents, one per repo, prompted with the new design as the audit criterion,
returned a complete trap catalog (~30 findings) in minutes — every one became
a design requirement or a documented deliberate trade. Highest-leverage step
of the whole build: the first draft violated 7 of the findings.
