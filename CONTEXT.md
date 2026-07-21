# CONTEXT — ubiquitous language

Glossary only. No implementation details.

- **ruleset** — the product: the plain-text style policy (`flint.md`). Its
  wording is load-bearing; provenance-tracked rules are never paraphrased.
- **hook** — the delivery: the single POSIX-sh script that injects the
  ruleset into a session.
- **surface** — a place Claude runs: `chat`, `cowork`, or `code` (CLI and the
  Desktop Code tab are the same surface).
- **channel** — an injection mechanism available on a surface: hook, skill,
  Style, profile instructions, Project instructions, CLAUDE.md.
- **core** — full-fidelity delivery (ruleset via hooks). Exists only on
  surfaces with hook support.
- **derivado** — a lossy artifact derived from the ruleset for a hook-less
  channel. Two kinds: *verbatim* (regenerated copies of the ruleset) and
  *derived* (hand-condensed paraphrases). Marked, budgeted, re-synced per
  release; never a second source of truth.
- **re-sync** — the manual, checklisted regeneration of every derivado after
  a ruleset change.
- **loud marker** — the in-session `FLINT HOOK ERROR` text emitted on any
  delivery failure; the opposite of a silent stale fallback.
- **anchor** — the one static line injected per turn; reinforcement, not the
  ruleset.
- **canonical home** — this repo. Consumers vendor pinned copies and never
  edit them in place.
- **consumer** — a repo/system that vendors the ruleset + hook at a pinned
  ref (e.g. vmCODE, which bakes them into a container).
