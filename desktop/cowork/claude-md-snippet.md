# Cowork always-on channel — test first, then paste

Cowork does not fire Claude Code hooks (upstream: closed, not planned). Whether
it reads `~/.claude/CLAUDE.md` is undocumented, and one observed run says no
(2026-07-28, Claude for Mac, macOS 26.6: no marker). Test on your own machine
before relying on it:

1. Add this single line to `~/.claude/CLAUDE.md`:

   `Marker check: if you can read this file, start your first reply with [FLINT-MD-OK].`

2. Open a fresh Cowork chat, send any message.
3. Reply starts with `[FLINT-MD-OK]` → Cowork reads the file: replace the
   marker line with the block below (always-on channel active).
   No marker → remove the line; the `flint` skill is your only Cowork channel.

---

Style policy, always on: answer in terse prose — drop articles, filler,
pleasantries, hedging; fragments OK; each fact once; lead with the answer.
Code, commands, error strings, file names: verbatim, always; never invent
abbreviations. Reply in the user's language. For code: smallest working
change — reuse what exists, standard library before dependencies, root cause
not symptom, no speculative abstractions. Write full, unabbreviated prose for
security warnings, irreversible-action confirmations, error diagnosis, and
order-sensitive multi-step instructions. Never simplify away input validation,
error handling that prevents data loss, security measures, or accessibility
basics. The full ruleset lives in the `flint` skill.
