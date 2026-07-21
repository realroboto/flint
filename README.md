# flint

Terse prose. Minimal code. Always on.

flint makes every Claude Code session answer in terse prose and produce
minimal, lazy code. One plain-text ruleset ([`flint.md`](flint.md)), one
POSIX-sh hook ([`hooks/flint-style.sh`](hooks/flint-style.sh)), zero state:
no levels, no flag files, no config, no slash commands, no off-switch. Every
piece of state the ancestor plugins had produced real bugs
([docs/flint.md §7](docs/flint.md)); flint deletes the class.

Distilled from forensic audits of the full commit histories of
[caveman](https://github.com/JuliusBrussee/caveman) (terse prose) and
[ponytail](https://github.com/DietrichGebert/ponytail) (lazy code) — 450+
commits of benchmark-validated wording and fixed bugs, merged, deduplicated,
and pinned. The [provenance table](docs/flint.md) maps each load-bearing rule
to the upstream bug that produced it.

## Install

Requires Python 3 on PATH. Windows additionally requires
[Git for Windows](https://gitforwindows.org) (Claude Code runs shell-form
hooks via Git Bash).

```sh
git clone https://github.com/realroboto/flint.git
cd flint
./install.sh          # Windows (PowerShell): .\install.ps1
```

Registers 3 hooks in `~/.claude/settings.json` (`$CLAUDE_CONFIG_DIR`
honored), pointing at THIS clone — don't delete it. Idempotent; re-running
after moving the clone re-points the paths.

| Event | Payload |
|---|---|
| `SessionStart` | full ruleset (re-fires on compact — matcher deliberately empty) |
| `SubagentStart` | full ruleset (subagents never see parent SessionStart context) |
| `UserPromptSubmit` | one static anchor line (recency beats one-shot injection) |

- **Update**: `git pull`. Nothing else.
- **Uninstall**: `./install.sh --uninstall` (or `python3 uninstall.py`) —
  removes exactly the 3 flint entries, touches nothing else.
- **Verify**: `sh test/test.sh` (also run by CI on Linux/macOS/Windows).

A session showing `FLINT HOOK ERROR: …` means a moved clone or missing
Python — the failure is loud by design, never a silent stale ruleset.

## Claude Desktop (Chat / Cowork / Code)

The Code tab inherits the hooks automatically. Chat and Cowork have no hook
support — [`desktop/`](desktop/README.md) ships best-effort static artifacts
(custom Style, profile instructions, Project template, Cowork skill) with
paste-in instructions and honest fidelity notes.

## The one escape hatch

There is no off mode. Ask for "full prose" in plain language and the ruleset
itself honors it — that's the only switch, and it's behavioral, not
mechanical.

## Deeper docs

- [docs/flint.md](docs/flint.md) — complete reference: provenance table,
  hook invariants, recipes, test matrix.
- [docs/hook-engineering.md](docs/hook-engineering.md) — the generic trap
  catalog for Claude Code context-injection hooks (from the upstream audits).
- [docs/ruleset-design.md](docs/ruleset-design.md) — how to write injected
  rulesets LLMs actually follow.

## Credits & license

MIT. The ruleset preserves benchmark-validated wording from
[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) and
[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (both
MIT) — see the provenance table in [docs/flint.md](docs/flint.md) for the
rule-by-rule origins.
