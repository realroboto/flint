# Designing injected rulesets LLMs actually follow

Rules for writing the TEXT a hook injects (persona/policy/style rulesets).
Source: the prose-rule fix history of
[caveman](https://github.com/JuliusBrussee/caveman) and
[ponytail](https://github.com/DietrichGebert/ponytail) (2026-07 forensic
audits). Reference artifact: [`flint.md`](../flint.md); the rule-by-rule
provenance table is [`docs/flint.md`](flint.md) §4. Companion:
[hook-engineering.md](hook-engineering.md) for the delivery mechanism.

## Wording is load-bearing — treat it like code

- **Benchmark-validated directives must stay verbatim.** ponytail #245
  ("Dangerously lazy"): on a shared-helper bug-fix trap, baseline fixed the
  root cause 1/6, ponytail 6/6 — and the commit is explicit that "Plain prose
  ('trace the flow') did not move it; the actionable, lazy-framed directive
  did." Paraphrasing a rule that was tuned against a benchmark silently
  discards the tuning. Ship a provenance table (rule → upstream bug/benchmark)
  precisely so future editors — human or LLM — don't "simplify" the
  load-bearing text.
- **Keep the REASON inside the rule.** caveman `dc95e91` removed prescribed
  abbreviations/arrows with the measured reason ("tokenizer splits them the
  same as the full word: zero tokens saved"). A bare prohibition invites
  re-derivation; the reason inoculates.
- **Compressing the ruleset text is where ambiguity bugs come from.** caveman
  `fbfe83b` squeezed its ruleset ~40% — and EVERY subsequent prose fix
  (#238/#239/#445/#468/#322) re-expanded it. Simplify the STRUCTURE (duplicate
  sections, levels, meta), preserve the WORDING of rules that cost a bug to
  find.

## Rules about rules (fix patterns that repeat)

- **Exclusions inline, not in a distant section.** caveman #238:
  "abbreviation applies to prose only, never to code symbols" had to be
  written INSIDE the compression rule — the model rendered literal `fn` in
  code while the exclusion sat in a far-away Boundaries section.
- **Never advertise a mechanism that doesn't exist.** ponytail #161/#162: the
  persistence prose ("Off only: 'stop ponytail'") plus prompt parsing meant
  "add a normal mode toggle" silently deactivated the mode. A fixed-point
  ruleset must contain zero switch/level/command language.
- **No self-reference, and disambiguate lookalikes.** caveman #469: the model
  announced the mode and double-answered. If the ruleset ALSO defines a code
  marker with the same name (flint's `flint:` comment), say explicitly that
  the marker is source-comment-only, or the model drops one of the two rules.
- **Scope markers narrowly.** ponytail #120: "mark intentional
  simplifications" → over-applied to trivial code for ~6 months; the fix
  narrows to "cuts a real corner with a known ceiling" + names the ceiling
  and upgrade path + adds the explicit negative ("Ordinary simple code is not
  a corner cut. Do not mark it."). Positive rule + explicit negative beats
  positive rule alone.
- **Name the behaviors you ban.** caveman #322: generic terseness did not
  stop tool-call narration, decorative tables, or log dumps — each had to be
  named. And #714: banning a behavior alone is not enough — state the
  positive default (call the tool directly when safe) plus the explicit
  exceptions, or the model keeps hedging around the ban.
- **Language preservation must be explicit.** caveman #445: the model
  answered Portuguese users in English until "Compress the style, not the
  language" landed.
- **Safety carve-outs need pinning.** ponytail `99139a2` put the
  never-simplify carve-outs (trust-boundary validation, data-loss error
  handling, security, accessibility) in a drift canary because they "could
  drift silently". Auto-clarity triggers (security warnings, irreversible
  confirmations, ambiguous multi-step sequences) stay a LIST with a concrete
  example ("migrate table drop column backup first" — order unclear), caveman
  #239.
- **Positional details matter.** ponytail #217/#281: the "reuse what's in
  this codebase" ladder rung was originally MISSING; the fix put it at rung
  2, BEFORE stdlib, with "look before you write" concreteness — and pinned it
  as a CI invariant.

## Structure of a good injected ruleset (the flint shape)

1. One-line identity ("Terse prose. Minimal code. Always on.")
2. Prose rules — with inline exclusions and one Not/Yes example pair
3. Code rules — actionable ladder, root-cause directive, marker rule with
   explicit negative, one worked example
4. Never-compress/never-simplify carve-outs — a pinned list
5. Escape hatch phrased as behavior, not mechanism ("User insists on the full
   version? Build it. No re-arguing.")

No Persistence/Boundaries/Intensity sections, no meta about the mode itself.
~7 KB replaced ~12 KB of two competing rulesets whose contradictions (one
banned `→`, the other used it in its Pattern) were themselves an
instruction-following hazard.

## Per-turn anchor line (companion to the ruleset)

Short, static, hardcoded in the hook — never read from the ruleset file (a
file problem must not kill the anchor). Content = the most-violated rules +
the safety boundary. Re-sync it BY HAND when the ruleset's core rules change;
document that in the release checklist.
